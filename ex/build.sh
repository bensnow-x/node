#!/bin/bash
set -euo pipefail

CORES=$(nproc)

podman run -it --rm \
  -v ../.:/root/node \
  --entrypoint bash \
  erlang_builder \
  -c "
set -euxo pipefail

echo '=== BUILDING AMADEUS ARM64 ==='

cd /root/node/ex

export MIX_ENV=prod

export CC='clang-19'
export CXX='clang++-19'

export CFLAGS='-march=armv8-a -pipe'
export CXXFLAGS='-march=armv8-a -pipe'

export RUSTFLAGS='-C target-cpu=generic -C opt-level=3 -C link-arg=-fuse-ld=mold'

export LLVM_CONFIG_PATH=/usr/bin/llvm-config-19
export LIBCLANG_PATH=/usr/lib/llvm-19/lib

export OPENSSL_ROOT_DIR=/root/openssl-3.6.3

export ERLANG_ROCKSDB_OPTS='-DOPENSSL_USE_STATIC_LIBS=TRUE -DWITH_LZ4=OFF -DWITH_SNAPPY=OFF -DWITH_BZ2=OFF -DWITH_ZLIB=OFF -DWITH_ZSTD=ON -DWITH_BUNDLE_ZSTD=ON'

echo '=== CLEAN OLD BUILD ==='

rm -rf _build/prod/lib/blake3_ex
rm -rf _build/prod/lib/blake3
rm -rf _build/prod/rel

mix deps.clean blake3_ex --build
mix deps.get

echo '=== BUILD BLAKE3 ==='

mix deps.compile blake3_ex --force

echo '=== BUILD RELEASE ==='

mix release

echo '=== CHECK BAKEWARE OUTPUT ==='

ls -lah _build/prod/rel/bakeware/

test -f _build/prod/rel/bakeware/ama

echo '=== COPYING AMADEUS BINARY ==='

cp _build/prod/rel/bakeware/ama amadeusd

chmod +x amadeusd
"

echo '=== BUILD FINISHED ==='

test -f amadeusd

echo '=== FINAL BINARY ==='

ls -lh amadeusd
file amadeusd
sha256sum amadeusd

echo '=== SIGN RELEASE ==='

./sign_release.sh