#!/bin/sh

git clone https://github.com/tpm2-software/tpm2-tss.git
cd tpm2-tss
./bootstrap
./configure
make -j$(nproc)
sudo make install
sudo ldconfig
cd ..
rm -rf tpm2-tss
