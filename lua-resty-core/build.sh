#!/bin/bash

set -e

# export NGINX_VERSION=1.19.2
# export OPENSSL_VER=1.0.2u
# export OPENSSL_PATCH_VER=1.0.2h
export NGINX_VERSION=1.19.3
export OPENSSL_VER=1.1.1i
export OPENSSL_PATCH_VER=1.1.1f
# export OPENSSL_VER=1.1.1i
# export OPENSSL_PATCH_VER=1.1.0d
# export CC=clang
export CC=gcc

# LUAJIT_RELEASE=-old

export JOBS=16
export NGX_BUILD_JOBS=$JOBS
export LUAJIT_PREFIX=/opt/luajit21$LUAJIT_RELEASE
export LUAJIT_LIB=$LUAJIT_PREFIX/lib
export LUAJIT_INC=$LUAJIT_PREFIX/include/luajit-2.1
export LUA_INCLUDE_DIR=$LUAJIT_INC
export LUA_CMODULE_DIR=/lib
export PCRE_VER=8.40
export PCRE_PREFIX=/opt/pcre
export PCRE_LIB=$PCRE_PREFIX/lib
export PCRE_INC=$PCRE_PREFIX/include
export OPENSSL_PREFIX=/opt/ssl
export OPENSSL_LIB=$OPENSSL_PREFIX/lib
export OPENSSL_INC=$OPENSSL_PREFIX/include
export LD_LIBRARY_PATH=$LUAJIT_LIB:$LD_LIBRARY_PATH
export TEST_NGINX_SLEEP=0.005
# export TEST_NGINX_RANDOMIZE=1
export LUACHECK_VER=0.21.1

export LD_LIBRARY_PATH=$PWD/mockeagain:$LD_LIBRARY_PATH
export PATH=$PWD/work/nginx/sbin:$PWD/../openresty-devel-utils:$PATH

# openssl
if [ ! -f ~/openssl-$OPENSSL_VER.tar.gz ]; then
    wget -P $HOME https://www.openssl.org/source/openssl-$OPENSSL_VER.tar.gz || wget -P $HOME https://www.openssl.org/source/old/${OPENSSL_VER//[a-z]/}/openssl-$OPENSSL_VER.tar.gz;
fi
if [ ! -d ../openssl-$OPENSSL_VER ]; then
    tar zxf $HOME/openssl-$OPENSSL_VER.tar.gz -C ../
    pushd ../openssl-$OPENSSL_VER
    patch -p1 < ../openresty/patches/openssl-$OPENSSL_PATCH_VER-sess_set_get_cb_yield.patch
    popd
fi
pushd ../openssl-$OPENSSL_VER
./config no-threads shared enable-ssl3 enable-ssl3-method -g --prefix=$OPENSSL_PREFIX -DPURIFY > build.log 2>&1 || (cat build.log && exit 1)
make -j$JOBS > build.log 2>&1 || (cat build.log && exit 1)
sudo make PATH=$PATH install_sw > build.log 2>&1 || (cat build.log && exit 1)
popd

# mockeagain
if [ ! -d ../mockeagain ]; then
    git clone https://github.com/openresty/mockeagain.git ../mockeagain
fi
pushd ../mockeagain/
make CC=$CC -j$JOBS
popd

export LD_PRELOAD=$PWD/../mockeagain/mockeagain.so

pushd ../luajit2$LUAJIT_RELEASE/
make -j$JOBS CCDEBUG=-g Q= PREFIX=$LUAJIT_PREFIX CC=$CC XCFLAGS='-DLUA_USE_APICHECK -DLUA_USE_ASSERT -msse4.2' > build.log 2>&1 || (cat build.log && exit 1)
sudo make install PREFIX=$LUAJIT_PREFIX > build.log 2>&1 || (cat build.log && exit 1)
popd

if [ ! -d ../lua-cjson ]; then
    git clone https://github.com/openresty/lua-cjson.git ../lua-cjson
fi
pushd ../lua-cjson/
make -j$JOBS && sudo make install
popd

# pcre
if [ ! -f ../pcre-$PCRE_VER.tar.gz ]; then wget -P .. http://ftp.cs.stanford.edu/pub/exim/pcre/pcre-$PCRE_VER.tar.gz; fi
if [ ! -d ../pcre-$PCRE_VER ]; then
    tar zxf ../pcre-$PCRE_VER.tar.gz -C ../
fi
pushd ../pcre-$PCRE_VER/
./configure --prefix=$PCRE_PREFIX --enable-jit --enable-utf --enable-unicode-properties > build.log 2>&1 || (cat build.log && exit 1)
make -j$JOBS > build.log 2>&1 || (cat build.log && exit 1)
sudo PATH=$PATH make install > build.log 2>&1 || (cat build.log && exit 1)
popd

ngx-build $NGINX_VERSION --with-ipv6 --with-http_realip_module --with-http_ssl_module --with-pcre-jit --with-cc-opt="-I$OPENSSL_INC -I$PCRE_INC" --with-ld-opt="-L$OPENSSL_LIB -Wl,-rpath,$OPENSSL_LIB -L$PCRE_LIB -Wl,-rpath,$PCRE_LIB" --add-module=../ndk-nginx-module --add-module=../echo-nginx-module --add-module=../set-misc-nginx-module --add-module=../headers-more-nginx-module --add-module=../lua-nginx-module --with-debug --with-stream_ssl_module --with-stream --with-ipv6 --add-module=../stream-lua-nginx-module > build.log 2>&1 || (cat build.log && exit 1)
