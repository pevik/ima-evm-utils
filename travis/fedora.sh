#!/bin/sh
# Copyright (c) 2020 Petr Vorel <pvorel@suse.cz>
set -e

if [ -z "$CC" ]; then
	echo "missing \$CC!" >&2
	exit 1
fi

case "$TSS" in
ibmtss) TSS="tss2-devel";;
tpm2-tss) TSS="tpm2-tss-devel";;
'') echo "Missing TSS!" >&2; exit 1;;
*) echo "Unsupported TSS: '$TSS'!" >&2; exit 1;;
esac

# ibmswtpm2 requires gcc
[ "$CC" = "gcc" ] || CC="gcc $CC"

yum -y install \
	$CC $TSS \
	asciidoc \
	attr \
	autoconf \
	automake \
	diffutils \
	docbook-xsl \
	gzip \
	keyutils-libs-devel \
	libattr-devel \
	libtool \
	libxslt \
	make \
	openssl \
	openssl-devel \
	pkg-config \
	procps \
	sudo \
	vim-common \
	wget \
	which

yum -y install docbook5-style-xsl || true

# FIXME: debug
echo "find /tss2_esys.h"
find /usr/ 2>/dev/null |grep /tss2_esys.h || true
echo "cat /usr/include/tss2/tss2_esys.h"
cat /usr/include/tss2/tss2_esys.h || true
