//////////////////////////////////////////////////////////////////////////////
// This file is part of 'SLAC Firmware Standard Library'.
// It is subject to the license terms in the LICENSE.txt file found in the 
// top-level directory of this distribution and at: 
//    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
// No part of 'SLAC Firmware Standard Library', including this file, 
// may be copied, modified, propagated, or distributed except according to 
// the terms contained in the LICENSE.txt file.
//////////////////////////////////////////////////////////////////////////////
#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <string>
#include <unistd.h>
#include <sys/mman.h>
#include <sys/types.h>
#include <iostream>
#include <iomanip>
#include <queue>
#include "AxiSlaveSim.h"
using namespace std;
 
AxiSlaveSim::AxiSlaveSim (unsigned char *memSpace, uint memSize, uint addrMask) {
   _memorySize  = memSize;
   _memorySpace = (uint *)memSpace;
   _smem        = NULL;
   _verbose     = false;
   _addrMask    = addrMask;
}

AxiSlaveSim::~AxiSlaveSim () {
   this->close();
}

// Open the port
bool AxiSlaveSim::open (uint id) {

   // Open shared memory
   _smem = sim_open(SLAVE_TYPE,id);

   if (_smem == NULL ) {
      cout << "AxiSlaveSim::open -> Failed to open shared memory" << endl;
      return(false);
   }

   printf("Opened shared memory %s\n",_smem->_path);

   _runEnable = true;

   // Start threads
   pthread_create(&_writeThread,NULL,staticWriteRun,this);
   pthread_create(&_readThread,NULL,staticReadRun,this);

   // Sucess
   return(true);
}

// Close the port
void AxiSlaveSim::close () {
   _runEnable = false;
   usleep(1000);

   pthread_join(_writeThread, NULL);
   pthread_join(_readThread, NULL);

   sim_close(_smem);
}

void AxiSlaveSim::setVerbose(bool v) {
   _verbose = v;
}

void * AxiSlaveSim::staticReadRun(void *t) {
   AxiSlaveSim *ti;
   ti = (AxiSlaveSim *)t;
   ti->readRun();
   pthread_exit(NULL);
}

void AxiSlaveSim::readRun() {
   AxiReadData            readData;
   AxiReadAddr          * nextAddr;
   AxiReadAddr          * currAddr;
   queue<AxiReadAddr *>   readQueue;
   uint                   length;
   uint                   addr;
   uint                   x;

   if (_smem == NULL ) return;

   nextAddr = (AxiReadAddr *)malloc(sizeof(AxiReadAddr));
   memset(nextAddr,0,sizeof(AxiReadAddr));

   while (_runEnable) {

      // Wait for read address
      if ( getReadAddr(_smem,nextAddr) ) {

         if ( _verbose ) {
            cout << "Read Start,  " 
                 << " System=" << _smem->_path
                 << " Addr=0x" << hex << setw(8) << setfill('0') << nextAddr->araddr
                 << " Length=" << dec << setw(0) << setfill('0') << ((nextAddr->arlen+1) * 2)
                 << endl;
         }

         readQueue.push(nextAddr);
         nextAddr = (AxiReadAddr *)malloc(sizeof(AxiReadAddr));
         memset(nextAddr,0,sizeof(AxiReadAddr));
      }

      // Queue has an entry
      if ( ! readQueue.empty() ) {

         // Get entry
         currAddr = readQueue.front();

         // Extract address and length
         length = (currAddr->arlen + 1) * 2;
         addr   = currAddr->araddr & _addrMask;

         if ( (addr + (length*4)) >= (_memorySize-1) ) {
            cout << "!!!!!!!!!!! Error Memory read space overrun, "
                 << " System=" << _smem->_path
                 << " Addr=0x" << hex << setw(8) << setfill('0') << addr
                 << " Size=" << dec << (length*8)
                 << " MemSize=0x" << hex << setw(8) << setfill('0') << _memorySize
                 << " Mask=0x" << hex << setw(8) << setfill('0') << _addrMask
                 << endl;
            return;
         }

         // Send out data
         for (x=0; x < length;) {

            // Verify hardware is ready
            while ( !readyReadData(_smem) ) usleep(1);

            // Format and output data
            readData.rdataL = _memorySpace[addr/4];

            if (_verbose) {
               cout << "Memory read, " 
                    << " System=" << _smem->_path
                    << " Addr=0x" << hex << setw(8) << setfill('0') << addr
                    << " Data=0x" << hex << setw(8) << setfill('0') << readData.rdataL
                    << endl;
            }

            addr += 4;
            x++;

            readData.rdataH = _memorySpace[addr/4];

            if (_verbose) {
               cout << "Memory read, " 
                    << " System=" << _smem->_path
                    << " Addr=0x" << hex << setw(8) << setfill('0') << addr
                    << " Data=0x" << hex << setw(8) << setfill('0') << readData.rdataH
                    << endl;
            }

            addr += 4;
            x++;

            readData.rlast  = (x == length);
            readData.rid    = currAddr->arid;
            readData.rresp  = 0;

            setReadData(_smem,&readData);
         }

         readQueue.pop();
         free(currAddr);
      }
      else usleep(10);
   }
}


void * AxiSlaveSim::staticWriteRun(void *t) {
   AxiSlaveSim *ti;
   ti = (AxiSlaveSim *)t;
   ti->writeRun();
   pthread_exit(NULL);
}


// Memory write
void AxiSlaveSim::writeRun() {
   AxiWriteAddr          * nextAddr;
   AxiWriteAddr          * currAddr;
   queue<AxiWriteAddr *>   writeQueue[8];
   AxiWriteData            writeData;
   AxiWriteComp            writeComp;
   uint                    aid;
   uint                    id;
   uint                    length;
   uint                    addr[8];
   bool                    valid[8];
   uint                    x;
   uint                    temp;
   uint                    tempMask;
   uint                    writeMask;

   if (_smem == NULL ) return;

   nextAddr = (AxiWriteAddr *)malloc(sizeof(AxiWriteAddr));
   memset(nextAddr,0,sizeof(AxiWriteAddr));
   currAddr = NULL;

   for (x=0; x < 8; x++) valid[x] = false;

   cout << "Slave Write Thread Start, " 
        << " System=" << _smem->_path
        << endl;

   while (_runEnable) {

      // Wait for read address
      while ( getWriteAddr(_smem,nextAddr) ) {
         aid = nextAddr->awid;

         if (_verbose) {
            cout << "Write Start, " 
                 << " System=" << _smem->_path
                 << " Id=" << aid
                 << " Addr=0x" << hex << setw(8) << setfill('0') << nextAddr->awaddr
                 << endl;
         }

         writeQueue[aid].push(nextAddr);
         nextAddr = (AxiWriteAddr *)malloc(sizeof(AxiWriteAddr));
         memset(nextAddr,0,sizeof(AxiWriteAddr));
      }

      // Wait for write data
      if ( getWriteData(_smem,&writeData) ) {
         id = writeData.wid;

         // ID is not valid, search for record
         if ( !valid[id] ) {
            if ( writeQueue[id].empty() ) {
               cout << "!!!!!!!!!!! Error Bad Write ID, "
                    << " System=" << _smem->_path
                    << " Id=" << id
                    << endl;
               return;
            }
            else {

               // Get entry
               currAddr = writeQueue[id].front();

               // Extract values
               id        = currAddr->awid;
               length    = (currAddr->awlen + 1) * 2;
               addr[id]  = currAddr->awaddr & _addrMask;
               valid[id] = true;

               if ( (addr[id] + (length*4)) >= (_memorySize-1) ) {
                  cout << "!!!!!!!!!!! Error Memory write space overrun, "
                       << " System=" << _smem->_path
                       << " Addr=0x" << hex << setw(8) << setfill('0') << addr[id]
                       << " Size=" << dec << (length*4)
                       << " MemSize=0x" << hex << setw(8) << setfill('0') << _memorySize
                       << " Mask=0x" << hex << setw(8) << setfill('0') << _addrMask
                       << endl;
                  return;
               }

               writeQueue[id].pop();
               free(currAddr);
            }
         }

         tempMask  = 0xFFFFFFFF;
         writeMask = 0x0;
         if ( writeData.wstrb & 0x1 ) { tempMask &= 0xFFFFFF00; writeMask |= 0x000000FF; }
         if ( writeData.wstrb & 0x2 ) { tempMask &= 0xFFFF00FF; writeMask |= 0x0000FF00; }
         if ( writeData.wstrb & 0x4 ) { tempMask &= 0xFF00FFFF; writeMask |= 0x00FF0000; }
         if ( writeData.wstrb & 0x8 ) { tempMask &= 0x00FFFFFF; writeMask |= 0xFF000000; }

         temp = _memorySpace[addr[id]/4] & tempMask;
         _memorySpace[addr[id]/4] = temp | (writeData.wdataL & writeMask);

         if (_verbose) {
            cout << "Memory write," 
                 << " System=" << _smem->_path
                 << " Addr=0x" << hex << setw(8) << setfill('0') << addr[id]
                 << " Data=0x" << hex << setw(8) << setfill('0') << writeData.wdataL
                 << " Mask=0x" << hex << setw(1) << setfill('0') << (writeData.wstrb & 0xF)
                 << endl;
         }

         addr[id] += 4;

         tempMask  = 0xFFFFFFFF;
         writeMask = 0x0;
         if ( writeData.wstrb & 0x10 ) { tempMask &= 0xFFFFFF00; writeMask |= 0x000000FF; }
         if ( writeData.wstrb & 0x20 ) { tempMask &= 0xFFFF00FF; writeMask |= 0x0000FF00; }
         if ( writeData.wstrb & 0x40 ) { tempMask &= 0xFF00FFFF; writeMask |= 0x00FF0000; }
         if ( writeData.wstrb & 0x80 ) { tempMask &= 0x00FFFFFF; writeMask |= 0xFF000000; }

         temp = _memorySpace[addr[id]/4] & tempMask;
         _memorySpace[addr[id]/4] = temp | (writeData.wdataH & writeMask); 

         if (_verbose) {
            cout << "Memory write," 
                 << " System=" << _smem->_path
                 << " Addr=0x" << hex << setw(8) << setfill('0') << addr[id]
                 << " Data=0x" << hex << setw(8) << setfill('0') << writeData.wdataH
                 << " Mask=0x" << hex << setw(1) << setfill('0') << ((writeData.wstrb >> 4) & 0xF)
                 << endl;
         }

         addr[id] += 4;

         // Last
         if ( writeData.wlast ) {

            // Verify hardware is ready
            while ( !readyWriteComp(_smem) ) usleep(1);

            // Continue
            writeComp.bresp = 0;
            writeComp.bid = id;
            setWriteComp(_smem,&writeComp);
            valid[id] = false;
         } 
      } else usleep(1);
   }
}

