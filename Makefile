UPSTREAM_REPO := github.com/gilbertchen/duplicacy
UPLOADTAG := latest

GOCMD := go
GOBUILD := $(GOCMD) build
GOGET := $(GOCMD) get
GOTEST := $(GOCMD) test
GOLIST := $(GOCMD) list

GOSRC := $(shell cd $$(go env GOPATH) && pwd)/src
GOBIN := $(shell cd $$(go env GOPATH) && pwd)/bin

REPODIR := $(shell pwd)
UPSTREAM_REPODIR := $(GOSRC)/$(UPSTREAM_REPO)

REPO := $(shell echo $(REPODIR) | sed -e s@^$(GOSRC)/@@)

MAINPKG := $(shell grep -R -s --include="*.go" "package main" $(REPODIR) | sed -e s@:.*@@ -e s@^$(REPODIR)/@$(REPO)/@ | xargs -n 1 dirname | uniq)
ifneq ($(words $(MAINPKG)),1)
$(error Unable to find the main package.)
endif

TESTPKGS := $(shell find $(REPODIR) -type f -and -name "*_test.go" | xargs -n 1 dirname | sed -e s@^$(REPODIR)/@$(REPO)/@ | uniq)

ALLSRCS := $(shell find $(REPODIR) -type f -and -name "*.go" -and ! -name "*_test.go" | sed -e s@^$(REPODIR)/@@)

BUILDDEPS := $(shell $(GOLIST) -deps $(MAINPKG) | grep -v "$(REPO)" | grep -v "$(UPSTREAM_REPO)")

BINARY := $(shell basename $(MAINPKG))$(shell go env GOEXE)

GITREVISION := $(shell git rev-parse --short=12 HEAD)
ifneq ("$(shell git status --porcelain)","")
GITSTATUS := -dirty
endif

define logvar
  @echo "$(1) = '$($(1))'"
endef

show-vars:
	$(call logvar,GOSRC)
	@echo ""
	$(call logvar,REPO)
	$(call logvar,UPSTREAM_REPO)
	@echo ""
	$(call logvar,REPODIR)
	$(call logvar,UPSTREAM_REPODIR)
	@echo ""
	$(call logvar,MAINPKG)
	$(call logvar,TESTPKGS)
	@echo ""
	$(call logvar,BINARY)
	@echo "CHANGESET = '$(GITREVISION)$(GITSTATUS)'"

echo-var-%:
	$(call logvar,$*)


all: build

upload: notdirty build
	git push --delete origin $(UPLOADTAG)
	git tag -f $(UPLOADTAG)
	git push origin master --tags

build: setup build-deps $(GOBIN)/$(BINARY)

$(GOBIN)/$(BINARY): setup $(ALLSRCS)
	@echo "Building $(MAINPKG)..."
	@$(GOGET) -ldflags "-X main.GitCommit=$(GITREVISION)$(GITSTATUS)" $(MAINPKG)

test: setup
	@echo "Running tests..."
	@$(GOTEST) $(TESTPKGS)

build-deps: setup
	@echo "Building dependencies..."
	@$(GOGET) $(BUILDDEPS)

update-deps: setup
	@echo "Downloading updated dependencies..."
	@$(GOGET) -u -d $(MAINPKG)

clean:
	@echo "Deleting binary..."
	@rm -f $(GOBIN)/$(BINARY)
	@echo "Deleting upstream..."
	@rm -rf $(UPSTREAM_REPODIR)

notdirty:
ifneq ("$(GITSTATUS)","")
	@echo "This tree is dirty."
	@exit 1
endif

setup: link-upstream


UPSTREAMSRCS = $(foreach s,$(ALLSRCS),$(UPSTREAM_REPODIR)/$(s))

link-upstream: $(UPSTREAMSRCS)

$(UPSTREAM_REPODIR)/%:
	@mkdir -p $(shell dirname $@)
ifeq ($(go env GOHOSTOS),windows)
	@ln -s $(subst $(UPSTREAM_REPODIR),$(REPODIR) $@
else
	@cp $(subst $(UPSTREAM_REPODIR),$(REPODIR),$@) $@
endif
