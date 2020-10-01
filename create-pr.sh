#!/bin/bash

name=$1

if [ -z "$name" ]; then
    name=$(basename $PWD)
fi

gh repo fork --remote=false
git remote add jiahao git@github.com:xiaocang/$name.git
git checkout -b travis-1.19.2.x
