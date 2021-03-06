#!/bin/bash
# Environment variables
#  TS_BUILDDIR : Build root directory. Default to current working directory
#  TS_INSTALLDIR : Installation directory. Default to ${TS_BUILDDIR}
#
set -e
CD=`pwd`
OS=`uname`
FETCH_CMD="curl -OL"

if [ "${OS}" != "Darwin" ] && [ "${OS}" != "Linux" ] && [ "$OS" != "FreeBSD" ]; then
  echo "Error: ${OS} is not a currently supported platform."
  exit 1
fi

[[ "${OS}" == "FreeBSD" ]] && FETCH_CMD="fetch"

[[ -z "${TS_BUILDDIR}" ]] && BUILDDIR="${CD}" || BUILDDIR="${TS_BUILDDIR}"

echo ">>> Build DIR: ${BUILDDIR}"
BUILDDIR=${BUILDDIR}/ts-build-root

# remove build dirs
test -d ${BUILDDIR}/build && rm -rf ${BUILDDIR}/build/*

test -z ${BUILDDIR} || /bin/mkdir -p ${BUILDDIR}
test -z ${BUILDDIR}/downloads || /bin/mkdir -p ${BUILDDIR}/downloads
test -z ${BUILDDIR}/build || /bin/mkdir -p ${BUILDDIR}/build

[[ -z "${TS_INSTALLDIR}" ]] && OUTDIR="${BUILDDIR}" || OUTDIR="${TS_INSTALLDIR}"

echo ">>> Install DIR: ${OUTDIR}"
export PKG_CONFIG_PATH=${OUTDIR}/lib/pkgconfig

OPENSSL_VERSION="1.0.2-chacha"
LIBEVENT_VERSION="2.1.8-stable"
ZLIB_VERSION="zlib-1.2.11"

FILE="${BUILDDIR}/downloads/${OPENSSL_VERSION}.zip"
if [ ! -f $FILE ]; then
  echo "Downloading $FILE.."
  cd ${BUILDDIR}/downloads
  $FETCH_CMD https://github.com/PeterMosmans/openssl/archive/${OPENSSL_VERSION}.zip
fi

cd ${BUILDDIR}/build

unzip ${BUILDDIR}/downloads/${OPENSSL_VERSION}.zip
mv openssl-${OPENSSL_VERSION} openssl-x86_64

if [ ! -f "${BUILDDIR}/lib/libcrypto.a" ]; then
cd openssl-x86_64

if [ "${OS}" == "Darwin" ]; then
  ./Configure darwin64-x86_64-cc enable-static-engine enable-ec_nistp_64_gcc_128 enable-gost enable-idea enable-md2 enable-rc2 enable-rc5 enable-rfc3779 enable-ssl-trace enable-ssl2 enable-ssl3 enable-zlib experimental-jpake --prefix=${OUTDIR} --openssldir=${OUTDIR}/ssl
else
  cd ${BUILDDIR}/downloads
  if [ ! -f ${BUILDDIR}/downloads/${ZLIB_VERSION}.tar.gz ]; then
    $FETCH_CMD http://www.zlib.net/${ZLIB_VERSION}.tar.gz
  fi

  if [ ! -f "${BUILDDIR}/lib/libz.a" ]; then
    cd ${BUILDDIR}/build
    tar -zxvf ${BUILDDIR}/downloads/${ZLIB_VERSION}.tar.gz
    mv ${ZLIB_VERSION} zlib-x86_64
    cd zlib-x86_64

    ./configure  --prefix=${OUTDIR} --static -64
    make
    make install

    echo ">>> ZLIB complete"
  fi

  cd ${BUILDDIR}/build/openssl-x86_64
  ./config enable-static-engine enable-ec_nistp_64_gcc_128 enable-gost enable-idea enable-md2 enable-rc2 enable-rc5 enable-rfc3779 enable-ssl-trace enable-ssl2 enable-ssl3 enable-zlib experimental-jpake --prefix=${OUTDIR} --openssldir=${OUTDIR}/ssl -I${OUTDIR}/include -L${OUTDIR}/lib --with-zlib-lib=${OUTDIR}/lib --with-zlib-include=${OUTDIR}/include
fi

make
make install prefix=${OUTDIR}
fi

FILE="${BUILDDIR}/downloads/libevent-${LIBEVENT_VERSION}.tar.gz"
if [ ! -f $FILE ]; then
  echo "Downloading $FILE.."
  cd ${BUILDDIR}/downloads
  $FETCH_CMD https://github.com/libevent/libevent/releases/download/release-${LIBEVENT_VERSION}/libevent-${LIBEVENT_VERSION}.tar.gz
fi

cd ${BUILDDIR}/build
tar -zxvf ${BUILDDIR}/downloads/libevent-${LIBEVENT_VERSION}.tar.gz
mv libevent-${LIBEVENT_VERSION} libevent-x86_64

if [ ! -f "${BUILDDIR}/lib/libevent.a" ]; then
cd libevent-x86_64
./autogen.sh

if [ "${OS}" == "Darwin" ]; then
  ./configure --enable-shared=no --enable-static CFLAGS="-I${OUTDIR}/include -arch x86_64" LIBS="-L${OUTDIR}/lib -lssl -L${OUTDIR}/lib -lcrypto -ldl -L${OUTDIR}/lib -lz"
elif [ "${OS}" == "FreeBSD" ]; then
  ./configure --enable-shared=no --enable-static CFLAGS="-I${OUTDIR}/include" LIBS="-L${OUTDIR}/lib -lssl -L${OUTDIR}/lib -lcrypto -L${OUTDIR}/lib -lz"
else
  ./configure --enable-shared=no OPENSSL_CFLAGS=-I${OUTDIR}/include OPENSSL_LIBS="-L${OUTDIR}/lib -lssl -L${OUTDIR}/lib -lcrypto" CFLAGS="-I${OUTDIR}/include" LIBS="-L${OUTDIR}/lib -ldl -lz"
fi

make
make install prefix=${OUTDIR}
fi

FILE="${BUILDDIR}/downloads/master.zip"
if [ ! -f $FILE ]; then
  echo "Downloading $FILE.."
  cd ${BUILDDIR}/downloads
  $FETCH_CMD https://github.com/0xfab-ri/tls-scan/archive/master.zip
fi

cd ${BUILDDIR}/build
unzip ${BUILDDIR}/downloads/master.zip
cd tls-scan-master
export TS_DEPDIR=${OUTDIR}
if [ "${OS}" == "FreeBSD" ]; then
gmake 
export PREFIX=${OUTDIR}
gmake install
else
make
export PREFIX=${OUTDIR}
make install
fi
echo '>>> Complete'

