#! /bin/bash

TAG=latest

git push --delete origin ${TAG}
git tag -f ${TAG}
git push origin master --tags
