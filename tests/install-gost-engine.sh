#!/bin/sh

openssl version

git clone https://github.com/gost-engine/engine.git
cd engine
#cmake -DOPENSSL_INCLUDE_DIR=/usr/local/include/openssl -DOPENSSL_SSL_LIBRARY=/usr/local/lib64/libss.so -DOPENSSL_CRYPTO_LIBRARY=/usr/local/lib64/libcrypto.so -DOPENSSL_ENGINES_DIR=/usr/local/lib64/engines-1.1 .
cmake .
sudo make install
cd ..
