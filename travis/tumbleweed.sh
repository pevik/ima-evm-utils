#!/bin/sh
# Copyright (c) 2020 Petr Vorel <pvorel@suse.cz>
set -ex

if [ -z "$CC" ]; then
	echo "missing \$CC!" >&2
	exit 1
fi

case "$TSS" in
ibmtss) TSS="ibmtss-devel";;
tpm2-tss) TSS="tpm2-0-tss-devel";;
'') echo "Missing TSS!" >&2; exit 1;;
*) echo "Unsupported TSS: '$TSS'!" >&2; exit 1;;
esac

zypper --non-interactive install --force-resolution --no-recommends \
	$CC $TSS \
	asciidoc \
	attr \
	autoconf \
	automake \
	docbook_5 \
	docbook5-xsl-stylesheets \
	ibmswtpm2 \
	keyutils-devel \
	libattr-devel \
	libopenssl-devel \
	libtool \
	make \
	openssl \
	pkg-config \
	procps \
	sudo \
	vim \
	wget \
	which \
	xsltproc
