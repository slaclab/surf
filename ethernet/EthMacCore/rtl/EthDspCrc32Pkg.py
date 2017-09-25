#!/usr/bin/env python3
#-----------------------------------------------------------------------------
# File       : EthDspCrc32Pkg.py
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

def PrintXorVhdl(                
    lfsrPolySize,
    numDataBits,
    LfsrMatrix,
    ):      

    for i in range(lfsrPolySize):
        firstBit = True
        printStr = ('    newcrc(%d) := ' % i)
              
        for j in range( (numDataBits-1), -1, -1 ):
            if(LfsrMatrix[(lfsrPolySize*lfsrPolySize)+(j*lfsrPolySize)+i]):
                if (firstBit):
                    firstBit = False
                    printStr += ('d(%d)' % j)
                else:
                    printStr += (' xor d(%d)' % j)        
        
        for j in range(lfsrPolySize):
            if(LfsrMatrix[j*lfsrPolySize+i]):
                if (firstBit):
                    firstBit = False
                    printStr += ('c(%d)' % j)
                else:
                    printStr += (' xor c(%d)' % j)
                   
        printStr += (';')
        print (printStr)  
        
##################################################################################################
# CRC32 Ethernet/AAL5:
# x^32 + x^26 + x^23 + x^22 + x^16 + x^12 + x^11 + x^10 + x^8 + x^7 + x^5 + x^4 + x^2 + x^1 + 1
##################################################################################################

lfsrPolySize = 32
lfsrPoly     = [1,1,1,0,1,1,0,1, # x^7 + x^5 + x^4 + x^2 + x^1 + 1
                1,0,1,1,1,0,0,0, # x^12 + x^11 + x^10 + x^8
                1,0,0,0,0,0,1,1, # x^23 + x^22 + x^16
                0,0,1,0,0,0,0,0] # x^32 + x^26 (doesn’t include highest degree coefficient in polynomial representation)
# for i in range(lfsrPolySize): 
    # print ('lfsrPoly[%d] = %d' % (i,lfsrPoly[i]) )
    
##################################################################################################
numDataBits  = 128



LfsrMatrix = BuildMatrix (
    lfsrPolySize = lfsrPolySize,
    lfsrPoly     = lfsrPoly,    
    numDataBits  = numDataBits,
    )
    
PrintXorVhdl (
    lfsrPolySize = lfsrPolySize,
    numDataBits  = numDataBits,
    LfsrMatrix   = LfsrMatrix,    
    )

        
                
                
                
                