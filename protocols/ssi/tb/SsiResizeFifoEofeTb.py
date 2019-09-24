#!/usr/bin/env python3
#-----------------------------------------------------------------------------
# This file is part of the 'SLAC Firmware Standard Library'. It is subject to 
# the license terms in the LICENSE.txt file found in the top-level directory 
# of this distribution and at: 
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
# No part of the 'SLAC Firmware Standard Library', including this file, may be 
# copied, modified, propagated, or distributed except according to the terms 
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

import sys

ofd = open('temp.txt', 'w')
ofd.write('   constant AXI_STREAM_CONFIG_C : AxiStreamConfigVectorArray(0 to SIZE_C-1, 0 to 1) := (\n')

#-----------------------------------------------------------------------------
#   function ssiAxiStreamConfig (
#      dataBytes : positive;
#      tKeepMode : TKeepModeType         := TKEEP_COMP_C;
#      tUserMode : TUserModeType         := TUSER_FIRST_LAST_C;
#      tDestBits : natural range 0 to 8  := 4;
#      tUserBits : positive range 2 to 8 := 2)
#-----------------------------------------------------------------------------
dataBytesConfig = [1,64]
tUserConfig     = [2,3,4,5,6,7,8]
cnt = -1
for dataBytesIn in range(len(dataBytesConfig)):
    for dataBytesOut in range(len(dataBytesConfig)):
        for tUserIn in range(len(tUserConfig)):
            for tUserOut in range(len(tUserConfig)):
                cnt = cnt + 1
                ofd.write(f"""
      {cnt}    => (                         
         0 => ssiAxiStreamConfig({dataBytesConfig[dataBytesIn]}, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, {tUserConfig[tUserIn]}),
         1 => ssiAxiStreamConfig({dataBytesConfig[dataBytesOut]}, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 4, {tUserConfig[tUserOut]})),""")   
