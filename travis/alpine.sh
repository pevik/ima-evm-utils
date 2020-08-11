#!/bin/sh
# Copyright (c) 2020 Petr Vorel <pvorel@suse.cz>
set -ex

if [ -z "$CC" ]; then
	echo "missing \$CC!" >&2
	exit 1
fi

case "$TSS" in
ibmtss) echo "No IBM TSS package, will be installed from git" >&2; TSS=;;
tpm2-tss) TSS="tpm2-tss-dev";;
'') echo "Missing TSS!" >&2; exit 1;;
*) echo "Unsupported TSS: '$TSS'!" >&2; exit 1;;
esac

apk update

apk add \
	$CC $TSS \
	asciidoc \
	attr \
	attr-dev \
	autoconf \
	automake \
	docbook-xml \
	docbook-xsl \
	keyutils-dev \
	libtool \
	libxslt \
	linux-headers \
	make \
	musl-dev \
	openssl \
	openssl-dev \
	pkgconfig \
	procps \
	sudo \
	wget \
	which \
	xxd

cat /etc/os-release

# FIXME: debug
ls -R /etc/xml/catalog* || true
grep -r /usr/share/xml/docbook/stylesheet/nwalsh/current /etc/xml/catalog* || true
xmlcatalog /etc/xml/catalog http://docbook.sourceforge.net/release/xsl/current/manpages/docbook.xsl || true
# FIXME: debug

if [ ! "$TSS" ]; then
	apk add git
	../tests/install-tss.sh
fi
