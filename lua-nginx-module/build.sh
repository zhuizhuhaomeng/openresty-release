set -e

export NGINX_VER=1.19.3
export CC=gcc
export JOBS=$(nproc)
export NGX_BUILD_JOBS=$JOBS
export LUAJIT_PREFIX=/opt/luajit21
export LUAJIT_LIB=$LUAJIT_PREFIX/lib
export LUAJIT_INC=$LUAJIT_PREFIX/include/luajit-2.1
export LUA_INCLUDE_DIR=$LUAJIT_INC
export PCRE_VER=8.44
export PCRE_PREFIX=/opt/pcre
export PCRE_LIB=$PCRE_PREFIX/lib
export PCRE_INC=$PCRE_PREFIX/include
export OPENSSL_PREFIX=/opt/ssl
export OPENSSL_LIB=$OPENSSL_PREFIX/lib
export OPENSSL_INC=$OPENSSL_PREFIX/include
export LIBDRIZZLE_PREFIX=/opt/drizzle
export LIBDRIZZLE_INC=$LIBDRIZZLE_PREFIX/include/libdrizzle-1.0
export LIBDRIZZLE_LIB=$LIBDRIZZLE_PREFIX/lib
export LD_LIBRARY_PATH=$LUAJIT_LIB:$LD_LIBRARY_PATH
export DRIZZLE_VER=2011.07.21
export TEST_NGINX_SLEEP=0.006
export OPENSSL_VER=1.1.1i
export OPENSSL_PATCH_VER=1.1.1f

set_python2() {
    rm -f $HOME/.local/bin/python
    ln -s /usr/bin/python2 $HOME/.local/bin/python
}

unset_python2() {
    rm -f $HOME/.local/bin/python
}

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

# drizzle
if [ ! -f ~/drizzle7-$DRIZZLE_VER.tar.gz ]; then
    wget -P $HOME http://openresty.org/download/drizzle7-$DRIZZLE_VER.tar.gz;
    tar xzf $HOME/drizzle7-$DRIZZLE_VER.tar.gz -C ../
fi
pushd ../drizzle7-$DRIZZLE_VER
./configure --prefix=$LIBDRIZZLE_PREFIX --without-server > build.log 2>&1 || (cat build.log && exit 1)
set_python2
make libdrizzle-1.0 -j$JOBS > build.log 2>&1 || (cat build.log && exit 1)
sudo bash -c "PATH=$PATH make install-libdrizzle-1.0" > build.log 2>&1 || (cat build.log && exit 1)
unset_python2
popd

# mockeagain
if [ ! -d ../mockeagain ]; then
    git clone https://github.com/openresty/mockeagain.git ../mockeagain
fi
pushd ../mockeagain/
make CC=$CC -j$JOBS
popd

if [ ! -d ../lua-cjson ]; then
    git clone https://github.com/openresty/lua-cjson.git ../lua-cjson
fi
pushd ../lua-cjson/
make -j$JOBS && sudo make install
popd

rm -f  buildroot/nginx-$NGINX_VER/Makefile
bash util/build.sh $NGINX_VER
