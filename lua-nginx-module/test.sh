export LUAJIT_PREFIX=/opt/luajit21
export LUAJIT_LIB=$LUAJIT_PREFIX/lib
export LD_LIBRARY_PATH=$LUAJIT_LIB:$LD_LIBRARY_PATH
export LD_LIBRARY_PATH=$PWD/../mockeagain:$LD_LIBRARY_PATH

# export TEST_NGINX_CHECK_LEAK=1
export PATH=$PWD/work/nginx/sbin:$PATH
export TEST_NGINX_NO_CLEAN=1 \
# export TEST_NGINX_CHECK_LEAK=1
# export TEST_NGINX_RANDOMIZE=1
# export TEST_NGINX_USE_VALGRIND=1
export TEST_NGINX_USE_HUP=1
export TEST_NGINX_VERBOSE=1

nginx -V

prove -I../test-nginx/lib -I. \
    t/162-*.t
