#!/bin/bash

git diff
git ci -am 'travis-ci: bumped the NGINX core to 1.19.2.'
git ph jiahao travis-1.19.2.x
hub prn --no-edit
