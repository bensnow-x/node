#!/bin/bash
set -euo pipefail

#&& export ERL_COMPILER_OPTIONS=bin_opt_info \
CORES=$(nproc)
#-C codegen-units=$CORES
#&& export MAKEFLAGS='-j$CORES' \

podman run -it --rm \
  -v ../.:/root/node \
  --entrypoint bash \
  erlang_builder \
  -c "
    set -euxo pipefail

    echo '=== BUILDING AMADEUS ==='
    cd /root/node/ex

    export MIX_ENV=prod

    export CC='clang-19'
    export CXX='clang++-19'
    export CFLAGS='-march=haswell -pipe'
    export CXXFLAGS='-march=haswell -pipe'

    export RUSTFLAGS='-C target-cpu=haswell -C opt-level=3 -C link-arg=-fuse-ld=mold'

    export LLVM_CONFIG_PATH=/usr/bin/llvm-config-19
    export LIBCLANG_PATH=/usr/lib/llvm-19/lib

    export OPENSSL_ROOT_DIR=/root/openssl-3.6.3

    export ERLANG_ROCKSDB_OPTS='-DOPENSSL_USE_STATIC_LIBS=TRUE -DWITH_LZ4=OFF -DWITH_SNAPPY=OFF -DWITH_BZ2=OFF -DWITH_ZLIB=OFF -DWITH_ZSTD=ON -DWITH_BUNDLE_ZSTD=ON'

    echo '=== MIX DEPS GET ==='
    mix deps.get

    echo '=== MIX RELEASE ==='
    mix release

    echo '=== CHECK BAKEWARE OUTPUT ==='
    ls -lah _build/prod/rel/bakeware/

    test -f _build/prod/rel/bakeware/ama

    echo '=== COPYING AMADEUS BINARY ==='
    cp _build/prod/rel/bakeware/ama amadeusd

    chmod +x amadeusd
  "

echo '=== BUILD FINISHED ==='

if [ ! -f amadeusd ]; then
  echo 'ERROR: amadeusd was not created'
  exit 1
fi

echo '=== FINAL BINARY ==='
ls -lh amadeusd
file amadeusd
sha256sum amadeusd

echo '=== SIGN R