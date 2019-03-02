#! /bin/bash

if [ "${TRAVIS_OS_NAME}" == "win" ]; then
  cp ${GOPATH}/bin/duplicacy.exe ${GOPATH}/bin/duplicacy-${TRAVIS_OS_NAME}.exe
else
  cp ${GOPATH}/bin/duplicacy ${GOPATH}/bin/duplicacy-${TRAVIS_OS_NAME}
fi
