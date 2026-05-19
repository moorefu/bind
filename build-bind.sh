#!/bin/bash
set -e

# Usage: ./build-bind.sh <version> [openssl-ver] [arch]
# Example: ./build-bind.sh 9.18.48 3.0.15 x86_64

BIND_VERSION="${1:?Usage: $0 <version> [openssl-ver] [arch]}"
OS_VER="${2:-1.1.1w}"
ARCH="${3:-$(uname -m)}"
PREFIX=/usr/local/bind

CACHE_DIR="${CACHE_DIR:-$(pwd)/cache}"
mkdir -p "$CACHE_DIR"

download() {
  local url="$1"
  local out="${2:-$(basename "$url")}"
  local cache_file="$CACHE_DIR/$out"
  if [ -f "$cache_file" ]; then
    echo "==> Cache hit: $cache_file"
    cp "$cache_file" "$out"
  else
    echo "==> Downloading $url"
    curl -fsSL "$url" -o "$cache_file" && cp "$cache_file" "$out"
  fi
}

echo "==> Building BIND ${BIND_VERSION} for ${ARCH}"

# Enable devtoolset (manylinux2014 ships devtoolset-10)
for dts in /opt/rh/devtoolset-*/enable; do
  [ -f "$dts" ] && source "$dts" && break
done

# Install build dependencies
yum install -y epel-release

yum groupinstall -y "Development Tools"
yum install -y \
  curl pkgconfig perl-core perl-devel zlib-devel \
  libuv-devel libcap-devel \
  xz autoconf automake libtool

yum install -y \
  jemalloc-devel json-c-devel libxml2-devel \
  libevent-devel \
  || true

# Build OpenSSL (system 1.0.2 lacks Ed25519/Ed448 and modern APIs)
# OpenSSL 1.1.x uses www.openssl.org; 3.x uses GitHub releases
OPENSSL_URL="https://www.openssl.org/source/openssl-${OS_VER}.tar.gz"
[ "${OS_VER%%.*}" = "3" ] && \
  OPENSSL_URL="https://github.com/openssl/openssl/releases/download/openssl-${OS_VER}/openssl-${OS_VER}.tar.gz"
download "$OPENSSL_URL"
tar xzf "openssl-${OS_VER}.tar.gz"
cd "openssl-${OS_VER}"
./config --prefix="$PREFIX" --openssldir="$PREFIX/ssl" --libdir="$PREFIX/lib"
make -j$(nproc)
make install_sw
cd ..

export PATH="$PREFIX/bin:$PATH"
export PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig:$PKG_CONFIG_PATH"

# Build protobuf from source (EPEL only has 2.5, protobuf-c needs >= 2.6.1)
PB_VER=3.20.3
download "https://github.com/protocolbuffers/protobuf/releases/download/v${PB_VER}/protobuf-cpp-${PB_VER}.tar.gz"
tar xzf "protobuf-cpp-${PB_VER}.tar.gz"
cd "protobuf-${PB_VER}"
./configure --prefix="$PREFIX" --disable-shared --with-pic
make -j$(nproc)
make install
cd ..

# Build protobuf-c
PBC_VER=1.4.1
download "https://github.com/protobuf-c/protobuf-c/releases/download/v${PBC_VER}/protobuf-c-${PBC_VER}.tar.gz"
tar xzf "protobuf-c-${PBC_VER}.tar.gz"
cd "protobuf-c-${PBC_VER}"
./configure --prefix="$PREFIX" --disable-shared --with-pic
make -j$(nproc)
make install
cd ..

# Build libfstrm
FS_VER=0.6.1
download "https://dl.farsightsecurity.com/dist/fstrm/fstrm-${FS_VER}.tar.gz"
tar xzf "fstrm-${FS_VER}.tar.gz"
cd "fstrm-${FS_VER}"
./configure --prefix="$PREFIX" --disable-shared --with-pic
make -j$(nproc)
make install
cd ..

# Download BIND
download "https://downloads.isc.org/isc/bind9/${BIND_VERSION}/bind-${BIND_VERSION}.tar.xz"
tar xJf "bind-${BIND_VERSION}.tar.xz"
cd "bind-${BIND_VERSION}"

LDFLAGS="-L$PREFIX/lib -Wl,-rpath,$PREFIX/lib" \
./configure \
  --prefix="$PREFIX" \
  --sysconfdir=/etc/bind \
  --localstatedir=/var \
  --with-openssl="$PREFIX" \
  --with-json-c \
  --with-libxml2 \
  --with-jemalloc \
  --enable-dnstap \
  --disable-doh

make -j$(nproc)
make install DESTDIR="$(pwd)/install"

# Bundle OpenSSL shared libs into the package
mkdir -p "$(pwd)/install$PREFIX/lib"
cp -a "$PREFIX/lib"/libssl.so* "$PREFIX/lib"/libcrypto.so* "$(pwd)/install$PREFIX/lib/"

find "$(pwd)/install" -type f -executable -exec strip --strip-all {} \; 2>/dev/null || true

DIST="bind-${BIND_VERSION}-linux-glibc2.17-${ARCH}-openssl-${OS_VER}"
cd install
tar -cJf "../${DIST}.tar.xz" usr/local/bind etc/bind
cd ..
sha256sum "${DIST}.tar.xz" > "${DIST}.tar.xz.sha256"

echo "==> Done: $(pwd)/${DIST}.tar.xz"
