#!/bin/sh
set -ex

version=1637

wget --no-check-certificate https://sourceforge.net/projects/ibmswtpm2/files/ibmtpm${version}.tar.gz/download
mkdir ibmtpm$version
cd ibmtpm$version
tar -xvzf ../download
cd src

CC="${CC:-gcc}"
for i in /usr/*/include/; do
	CFLAGS="-I$i $CFLAGS"
done

for i in /usr/*/lib*/; do
	LDFLAGS="-L$i $LDFLAGS"
done

if [ "$VARIANT" = "i386" ]; then
	echo "32-bit compilation"
	CFLAGS="-m32 $CFLAGS" LDFLAGS="-m32 $LDFLAGS"
fi

export CC CFLAGS LDFLAGS

# FIXME: debug
echo "debug: find openssl/opensslconf.h"
find /usr/ | grep -e openssl/opensslconf.h -e openssl/aes.h || true
# FIXME: debug

echo "=== compiler version ==="
$CC --version
echo "CFLAGS: '$CFLAGS'"
echo "LDFLAGS: '$LDFLAGS'"
echo "PREFIX: '$PREFIX'"

echo "=== make ==="
make -j$(nproc)
sudo cp tpm_server /usr/local/bin/
