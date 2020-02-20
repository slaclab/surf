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

cnt = -1
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
tUserConfig = [2,8]
tKeepModeType = ['TKEEP_COMP_C']
tUserModeType = ['TUSER_FIRST_LAST_C']
for dataBytesIn in range(len(dataBytesConfig)):
    for dataBytesOut in range(len(dataBytesConfig)):
        for tKeepModeIn in range(len(tKeepModeType)):
            for tKeepModeOut in range(len(tKeepModeType)):
                for tUserModeIn in range(len(tUserModeType)):
                    for tUserModeOut in range(len(tUserModeType)):
                        for tUserIn in range(len(tUserConfig)):
                            for tUserOut in range(len(tUserConfig)):
                                cnt = cnt + 1
                                ofd.write(f"""
      {cnt}    => (
         0 => ssiAxiStreamConfig({dataBytesConfig[dataBytesIn]}, {tKeepModeType[tKeepModeIn]}, {tUserModeType[tUserModeIn]}, 4, {tUserConfig[tUserIn]}),
         1 => ssiAxiStreamConfig({dataBytesConfig[dataBytesOut]}, {tKeepModeType[tKeepModeOut]}, {tUserModeType[tUserModeOut]}, 4, {tUserConfig[tUserOut]})),""")
#-----------------------------------------------------------------------------
dataBytesConfig = [8]
tUserConfig = [4]
tKeepModeType = ['TKEEP_NORMAL_C','TKEEP_COMP_C','TKEEP_COUNT_C']
tUserModeType = ['TUSER_NORMAL_C','TUSER_FIRST_LAST_C','TUSER_LAST_C','TUSER_NONE_C']
for dataBytesIn in range(len(dataBytesConfig)):
    for dataBytesOut in range(len(dataBytesConfig)):
        for tKeepModeIn in range(len(tKeepModeType)):
            for tKeepModeOut in range(len(tKeepModeType)):
                for tUserModeIn in range(len(tUserModeType)):
                    for tUserModeOut in range(len(tUserModeType)):
                        for tUserIn in range(len(tUserConfig)):
                            for tUserOut in range(len(tUserConfig)):
                                cnt = cnt + 1
                                ofd.write(f"""
      {cnt}    => (
         0 => ssiAxiStreamConfig({dataBytesConfig[dataBytesIn]}, {tKeepModeType[tKeepModeIn]}, {tUserModeType[tUserModeIn]}, 4, {tUserConfig[tUserIn]}),
         1 => ssiAxiStreamConfig({dataBytesConfig[dataBytesOut]}, {tKeepModeType[tKeepModeOut]}, {tUserModeType[tUserModeOut]}, 4, {tUserConfig[tUserOut]})),""")
#-----------------------------------------------------------------------------

