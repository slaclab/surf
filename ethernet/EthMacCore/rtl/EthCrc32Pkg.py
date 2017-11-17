#!/usr/bin/env python3
#-----------------------------------------------------------------------------
# File       : EthCrc32Pkg.py
# Created    : 2017-09-25
# Last update: 2017-09-25
#-----------------------------------------------------------------------------
# Description:
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

##################################################################################################

def Lfsr(
    numBitsToShift,
    lfsrPolySize,
    lfsrPoly,
    lfsrCur,
    dataCur):
    
    lfsrNext = []
    for i in range(lfsrPolySize):
        lfsrNext.append(0)    
    
    for i in range(lfsrPolySize):
        lfsrNext[i] = lfsrCur[i]
        
    for j in range(numBitsToShift):
        lfsrUpperBit = lfsrNext[lfsrPolySize-1]
        
        for i in range( (lfsrPolySize-1), 0, -1 ):
        
            if (lfsrPoly[i]):
                lfsrNext[i] = lfsrNext[i-1] ^ lfsrUpperBit ^ dataCur[j]
            else:
                lfsrNext[i] = lfsrNext[i-1]
                
        lfsrNext[0] = lfsrUpperBit ^ dataCur[j]
        
    return lfsrNext
    
##################################################################################################

def BuildMatrix (
    lfsrPolySize,
    lfsrPoly,    
    numDataBits,
    ):
    
    LfsrMatrix = []
    for i in range((numDataBits+lfsrPolySize)*lfsrPolySize):
        LfsrMatrix.append(0)    
    
    lfsrCur = []
    for i in range(lfsrPolySize):
        lfsrCur.append(0)
        
    dataCur = []
    for i in range(numDataBits):
        dataCur.append(0)

    ######################################
    # LFSR-2-LFSR matrix[NxN], dataCur=0
    ######################################
    for i in range(lfsrPolySize):
        lfsrCur[i] = 1
        
        if (i!=0):
            lfsrCur[i-1] = 0
            
        lfsrNext = Lfsr(
            numBitsToShift = numDataBits,
            lfsrPolySize   = lfsrPolySize,
            lfsrPoly       = lfsrPoly,
            lfsrCur        = lfsrCur,
            dataCur        = dataCur,
        )
        
        for j in range(lfsrPolySize):
            
            if (lfsrNext[j]):
                LfsrMatrix[(i*lfsrPolySize)+j] = 1
        
    for i in range(lfsrPolySize):
        lfsrCur[i] = 0
        
    for i in range(numDataBits):
        dataCur[i] = 0     
        
    ######################################
    # Data-2-LFSR matrix[MxN], lfsrCur=0
    ######################################
    for i in range(numDataBits):
        dataCur[i] = 1
        
        if(i!=0):
            dataCur[i-1] = 0
            
        lfsrNext = Lfsr(
            numBitsToShift = numDataBits,
            lfsrPolySize   = lfsrPolySize,
            lfsrPoly       = lfsrPoly,
            lfsrCur        = lfsrCur,
            dataCur        = dataCur,
        )            
            
        for j in range(lfsrPolySize):
            
            if (lfsrNext[j]):
                LfsrMatrix[(lfsrPolySize*lfsrPolySize) + ((numDataBits-i-1)*lfsrPolySize) + j] = 1

    return LfsrMatrix
    
##################################################################################################

def GetXorTaps (                
    lfsrPolySize,
    numDataBits,
    LfsrMatrix,
    ): 

    dXorTaps = [([0] * numDataBits) for i in range(lfsrPolySize)]
    cXorTaps = [([0] * lfsrPolySize) for i in range(lfsrPolySize)]
       
    for i in range(lfsrPolySize):
              
        for j in range(numDataBits):
            if(LfsrMatrix[(lfsrPolySize*lfsrPolySize)+(j*lfsrPolySize)+i]):
                dXorTaps[i][j] = 1
                
        for j in range(lfsrPolySize):
            if(LfsrMatrix[j*lfsrPolySize+i]):
                cXorTaps[i][j] = 1
                
    return dXorTaps, cXorTaps
    
##################################################################################################
# CRC32 Ethernet/AAL5:
# x^32 + x^26 + x^23 + x^22 + x^16 + x^12 + x^11 + x^10 + x^8 + x^7 + x^5 + x^4 + x^2 + x^1 + 1
##################################################################################################

lfsrPolySize = 32
lfsrPoly     = [1,1,1,0,1,1,0,1, # x^7 + x^5 + x^4 + x^2 + x^1 + 1
                1,0,1,1,1,0,0,0, # x^12 + x^11 + x^10 + x^8
                1,0,0,0,0,0,1,1, # x^23 + x^22 + x^16
                0,0,1,0,0,0,0,0] # x^32 + x^26 (doesn’t include highest degree coefficient in polynomial representation)
   
##################################################################################################

ofd = open('EthCrc32Pkg.vhd', 'w')

ofd.write(""" -------------------------------------------------------------------------------
-- File       : EthCrc32Pkg.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2017-09-25
-- Last update: 2017-09-25
-------------------------------------------------------------------------------
-- Description: Ethernet CRC32 Ethernet/AAL5 Package File
-- Polynomial: x^32 + x^26 + x^23 + x^22 + x^16 + x^12 + x^11 + x^10 + x^8 + x^7 + x^5 + x^4 + x^2 + x^1 + 1
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Firmware Standard Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'SLAC Firmware Standard Library', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;

package EthCrc32Pkg is

""")

for i in range(1,16+1,1):
    ofd.write("   function crc32Parallel%dByte (crcCur : slv(31 downto 0); data : slv(%d downto 0)) return slv;\n" % (i,(i*8)-1) )

ofd.write("\n")
    
for i in range(1,8+1,1):
    ofd.write("   procedure xorBitMap%dByte (\n" % i )
    ofd.write("      xorBitMap   : inout Slv96Array(31 downto 0);\n")
    ofd.write("      previousCrc : in    slv(31 downto 0);\n")
    ofd.write("      currentData : in    slv(%d downto 0));\n\n" % ((i*8)-1))

    
for i in range(1,16+1,1):
    ofd.write("   procedure xorBitMap%dByte (\n" % i )
    ofd.write("      xorBitMap   : inout Slv192Array(31 downto 0);\n")    
    ofd.write("      previousCrc : in    slv(31 downto 0);\n")
    ofd.write("      currentData : in    slv(%d downto 0));\n\n" % ((i*8)-1))
    
ofd.write("""end package EthCrc32Pkg;

package body EthCrc32Pkg is

""")

for i in range(1,16+1,1):
    numDataBits = i*8

    LfsrMatrix = BuildMatrix (
        lfsrPolySize = lfsrPolySize,
        lfsrPoly     = lfsrPoly,    
        numDataBits  = numDataBits,
        )
        
    dXorTaps, cXorTaps = GetXorTaps (
        lfsrPolySize = lfsrPolySize,
        numDataBits  = numDataBits,
        LfsrMatrix   = LfsrMatrix,    
        )  
        
    ofd.write("   function crc32Parallel%dByte (crcCur : slv(31 downto 0); data : slv(%d downto 0)) return slv is\n" % (i,(i*8)-1) )
    ofd.write("      variable retVar : slv(31 downto 0) := (others => '0');\n")
    ofd.write("   begin\n")
    for i in range(lfsrPolySize):
        firstBit = True
        printStr = ('      retVar(%d) := ' % i)
              
        # for j in range( (numDataBits-1), -1, -1 ):
        for j in range(numDataBits):
            if (dXorTaps[i][j]):
                if (firstBit):
                    firstBit = False
                    printStr += ('data(%d)' % j)
                else:
                    printStr += (' xor data(%d)' % j)        
        
        for j in range(lfsrPolySize):
            if (cXorTaps[i][j]):
                if (firstBit):
                    firstBit = False
                    printStr += ('crcCur(%d)' % j)
                else:
                    printStr += (' xor crcCur(%d)' % j)
                   
        printStr += (';\n')
        ofd.write(printStr)        
    ofd.write("""      return retVar;\n   end function;\n\n""")
        
for i in range(1,8+1,1):
    numDataBits = i*8

    LfsrMatrix = BuildMatrix (
        lfsrPolySize = lfsrPolySize,
        lfsrPoly     = lfsrPoly,    
        numDataBits  = numDataBits,
        )
        
    dXorTaps, cXorTaps = GetXorTaps (
        lfsrPolySize = lfsrPolySize,
        numDataBits  = numDataBits,
        LfsrMatrix   = LfsrMatrix,    
        )  
        
    ofd.write("   procedure xorBitMap%dByte (\n" % i )
    
    ofd.write("      xorBitMap   : inout Slv96Array(31 downto 0);\n")
    ofd.write("      previousCrc : in    slv(31 downto 0);\n")
    ofd.write("      currentData : in    slv(%d downto 0)) is \n" % ((i*8)-1))    
    ofd.write("   begin\n")       
       
    for x in range(lfsrPolySize):  
        ofd.write("      ")
        for y in range( (numDataBits-1), -1, -1 ):
            if (dXorTaps[x][y]):
                ofd.write("xorBitMap(%d)(%d) := currentData(%d); " % (x,y,y) ) 
        for y in range(lfsrPolySize):
            if (cXorTaps[x][y]):
                ofd.write("xorBitMap(%d)(%d) := previousCrc(%d); " % (x,(y+64),y) )
        ofd.write("\n")
    ofd.write("   end procedure;\n\n")
    
for i in range(1,16+1,1):
    numDataBits = i*8

    LfsrMatrix = BuildMatrix (
        lfsrPolySize = lfsrPolySize,
        lfsrPoly     = lfsrPoly,    
        numDataBits  = numDataBits,
        )
        
    dXorTaps, cXorTaps = GetXorTaps (
        lfsrPolySize = lfsrPolySize,
        numDataBits  = numDataBits,
        LfsrMatrix   = LfsrMatrix,    
        )  
        
    ofd.write("   procedure xorBitMap%dByte (\n" % i )
    ofd.write("      xorBitMap   : inout Slv192Array(31 downto 0);\n")        
    ofd.write("      previousCrc : in    slv(31 downto 0);\n")
    ofd.write("      currentData : in    slv(%d downto 0)) is \n" % ((i*8)-1))   
    
    ofd.write("   begin\n")       
       
    for x in range(lfsrPolySize):  
        ofd.write("      ")
        for y in range( (numDataBits-1), -1, -1 ):
            if (dXorTaps[x][y]):
                ofd.write("xorBitMap(%d)(%d) := currentData(%d); " % (x,y,y) ) 
        for y in range(lfsrPolySize):
            if (cXorTaps[x][y]):
                ofd.write("xorBitMap(%d)(%d) := previousCrc(%d); " % (x,(y+160),y) )
        ofd.write("\n")
    ofd.write("   end procedure;\n\n")

ofd.write("end package body EthCrc32Pkg;\n\n")
