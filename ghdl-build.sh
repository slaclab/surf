#!/bin/sh
#-----------------------------------------------------------------------------
# This file is part of 'SLAC Firmware Standard Library'.
# It is subject to the license terms in the LICENSE.txt file found in the
# top-level directory of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of 'SLAC Firmware Standard Library', including this file,
# may be copied, modified, propagated, or distributed except according to
# the terms contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

# Note: The manually installing of ghdl v3.0.0 until supported in Github Action's Ubuntu LTS

echo 'Installing GHDL ...'
sudo apt update
sudo apt install -y git make gnat zlib1g-dev
git clone https://github.com/ghdl/ghdl ghdl-build -b v3.0.0
cd ghdl-build
./configure --prefix=/usr/local
make -j$(nproc)
sudo make install
cd ../
echo 'Done!'
