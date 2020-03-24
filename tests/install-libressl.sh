#!/bin/sh

set -ex
git clone https://github.com/libressl-portable/portable.git
cd portable
./autogen.sh
autoreconf -i && ./configure --prefix=/opt/libressl --enable-nc
make -j$(nproc) && make install
mv /opt/libressl/lib/pkgconfig/libcrypto.pc /opt/libressl/lib/pkgconfig/libressl-libcrypto.pc
echo "mv libcrypto result: $?"
cd ..
