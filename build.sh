#!/bin/sh
# Copyright (c) 2020 Petr Vorel <pvorel@suse.cz>

set -e

CC="${CC:-gcc}"
CFLAGS="${CFLAGS:--Wformat -Werror=format-security -Werror=implicit-function-declaration -Werror=return-type -fno-common}"
PREFIX="${PREFIX:-$HOME/ima-evm-utils-install}"

export LD_LIBRARY_PATH="$PREFIX/lib64:$PREFIX/lib:/usr/local/lib64:/usr/local/lib"
export PATH="$PREFIX/bin:/usr/local/bin:$PATH"

print_log_exit()
{
	local ret=$?
	local log="$1"

	echo "== $log =="
	cat $log
	exit $ret
}

cd `dirname $0`

case "$VARIANT" in
	i386)
		echo "32-bit compilation"
		export CFLAGS="-m32 $CFLAGS" LDFLAGS="-m32 $LDFLAGS"
		;;
	cross-compile)
		host="${CC%-gcc}"
		export CROSS_COMPILE="${host}-"
		host="--host=$host"
		echo "cross compilation: $host"
		echo "CROSS_COMPILE: '$CROSS_COMPILE'"
		;;
	*)
		if [ "$VARIANT" ]; then
			echo "Wrong VARIANT: '$VARIANT'" >&2
			exit 1
		fi
		echo "native build"
		;;
esac

echo "=== compiler version ==="
$CC --version
echo "CFLAGS: '$CFLAGS'"
echo "LDFLAGS: '$LDFLAGS'"
echo "PREFIX: '$PREFIX'"

echo "=== configure ==="
autoreconf -i
./configure --prefix=$PREFIX $host || print_log_exit config.log

echo "=== make ==="
make -j$(nproc)
make install

echo "=== test ==="
VERBOSE=1 make check || print_log_exit tests/test-suite.log

echo "=== logs ==="
tail -3 tests/ima_hash.log
tail -3 tests/sign_verify.log
tail -20 tests/boot_aggregate.log
