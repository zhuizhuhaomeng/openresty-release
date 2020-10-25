#!/bin/bash

VER=1.19.3.1rc1
PRE_RELEASE=1
WORKDIR=$PWD/../openresty

if [ -n "$PRE_RELEASE" ]; then
    hub_opt="--prerelease"
fi

if [ ! -f "$VER/openresty-$VER.tar.gz" ] || \
    [ ! -f "$VER/openresty-$VER-win32.zip" ] || \
    [ ! -f "$VER/openresty-$VER-win64.zip" ]
then
    echo >&2 "ERROR: check the release file under '$VER/'"
    exit 1
fi

if [ ! -d $WORKDIR ]; then
    echo >&2 "ERROR: openresty repo not found"
    exit 1
fi

repo_clean="$(git -C $WORKDIR status -s -u no)"

if [ -n "$repo_clean" ]; then
    echo >&2 "repo is not clean: '$repo_clean'"
    exit 1
fi

branch="$(git -C $WORKDIR branch --show-current)"

if [ "$branch" != "master" ]; then
    echo >&2 "openresty/ repo branch mismatch '$branch'"
    exit 1
fi

hub -C $WORKDIR \
    release create -a $VER/openresty-$VER.tar.gz \
    -a $VER/openresty-$VER-win32.zip \
    -a $VER/openresty-$VER-win64.zip \
    --draft \
    $hub_opt \
    -e \
    -m v$VER \
    v$VER
