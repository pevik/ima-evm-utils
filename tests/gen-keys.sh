#!/bin/bash
#
# Generate keys for the tests
#
# Copyright (C) 2019 Vitaly Chikunov <vt@altlinux.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2, or (at your option)
# any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

cd $(dirname $0)
PATH=../src:$PATH
type openssl

log() {
  echo - "$*"
  eval "$@"
}

if [ ! -e test-ca.conf ]; then
cat > test-ca.conf <<- EOF
	[ req ]
	distinguished_name = req_distinguished_name
	prompt = no
	string_mask = utf8only
	x509_extensions = v3_ca

	[ req_distinguished_name ]
	O = IMA-CA
	CN = IMA/EVM certificate signing key
	emailAddress = ca@ima-ca

	[ v3_ca ]
	basicConstraints=CA:TRUE
	subjectKeyIdentifier=hash
	authorityKeyIdentifier=keyid:always,issuer
EOF
fi

# RSA
# Second key will be used for wrong key tests.
for m in 1024 2048; do
  if [ ! -e test-rsa$m.key ]; then
    log openssl req -verbose -new -nodes -utf8 -sha1 -days 10000 -batch -x509 \
      -config test-ca.conf \
      -newkey rsa:$m \
      -out test-rsa$m.cer -outform DER \
      -keyout test-rsa$m.key
  fi
done

# EC-RDSA
for m in \
  gost2012_256:A \
  gost2012_256:B \
  gost2012_256:C \
  gost2012_512:A \
  gost2012_512:B; do
    IFS=':' read -r algo param <<< "$m"
    [ -e test-$algo-$param.key ] && continue
    log openssl req -nodes -x509 -utf8 -days 10000 -batch \
      -config test-ca.conf \
      -newkey $algo \
      -pkeyopt paramset:$param \
      -out    test-$algo-$param.cer -outform DER \
      -keyout test-$algo-$param.key
    log openssl pkey -in test-$algo-$param.key -out test-$algo-$param.pub -pubout
done
