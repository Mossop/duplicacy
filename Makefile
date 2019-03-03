UPSTREAM_REPO := github.com/gilbertchen/duplicacy
ifeq ("$(BUILDTAG)","")
RELEASETAG := latest
else
RELEASETAG := $(BUILDTAG)
endif
RELEASEBUCKET := fractalbrew-builds

GOCMD := go
GOINSTALL := $(GOCMD) install
GOGET := $(GOCMD) get
GOTEST := $(GOCMD) test
GOLIST := $(GOCMD) list
GOCLEAN := $(GOCMD) clean

GOHOSTOS := $(shell go env GOHOSTOS)
GOHOSTARCH := $(shell go env GOHOSTARCH)

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
UPSTREAMSRCS = $(foreach s,$(ALLSRCS),$(UPSTREAM_REPODIR)/$(s))

BUILDDEPPKGS = $(shell $(GOLIST) -deps $(MAINPKG) | grep -v "$(REPO)" | grep -v "$(UPSTREAM_REPO)")

BINARY := $(shell basename $(MAINPKG))$(shell go env GOEXE)

GITREVISION := $(shell git rev-parse --short=12 HEAD)
ifneq ("$(shell git status --porcelain)","")
GITSTATUS := -dirty
endif

all: build

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


build: $(GOBIN)/$(BINARY)

$(GOBIN)/$(BINARY): $(UPSTREAMSRCS) $(ALLSRCS)
	@echo "Building $(MAINPKG)..."
	@$(GOINSTALL) -v -ldflags "-X main.GitCommit=$(GITREVISION)$(GITSTATUS)" $(MAINPKG)

test: $(UPSTREAMSRCS)
	@echo "Running tests..."
	@$(GOTEST) $(TESTPKGS)

build-deps: $(UPSTREAMSRCS)
	@$(GOGET) -d $(MAINPKG)
	@echo "Building dependencies..."
	@$(GOGET) -v $(BUILDDEPPKGS)

update-deps: $(UPSTREAMSRCS)
	@$(GOGET) -u -d $(MAINPKG)
	@echo "Updating dependencies..."
	@$(GOGET) -v $(BUILDDEPPKGS)

clean:
	@echo "Cleaning binaries and packages..."
	@$(GOCLEAN) -i -r -cache -testcache $(MAINPKG) || true
	@echo "Deleting upstream..."
	@rm -rf $(UPSTREAM_REPODIR)

notdirty:
ifneq ("$(GITSTATUS)","")
	@echo "This tree is dirty."
	@exit 1
endif


start-release: notdirty
	git push --delete origin $(RELEASETAG)
	git tag -f $(RELEASETAG)
	git push origin master --tags

upload-release: notdirty
	@b2 upload-file --noProgress $(RELEASEBUCKET) $(GOBIN)/$(BINARY) $(shell basename $(MAINPKG))/$(RELEASETAG)/$(GOHOSTOS)/$(BINARY)


$(UPSTREAM_REPODIR)/%: $(REPODIR)/%
	@mkdir -p $(shell dirname $@)
ifeq ($(GOHOSTOS),windows)
	@cp $< $@
else
	@ln -s $< $@
endif
