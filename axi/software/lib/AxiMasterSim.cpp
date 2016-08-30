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
#include "AxiMasterSim.h"
using namespace std;
 
AxiMasterSim::AxiMasterSim () {
   _readReq    = 0;
   _readAck    = 0;
   _readAddr   = 0;
   _readData   = 0;
   _writeReq   = 0;
   _writeAck   = 0;
   _writeAddr  = 0;
   _writeData  = 0;
   _verbose    = false;
   _smem       = NULL;
}

AxiMasterSim::~AxiMasterSim () {
   this->close();
}

// Open the port
bool AxiMasterSim::open (uint id) {

   // Open shared memory
   _smem = sim_open(MAST_TYPE,id);

   if (_smem == NULL ) {
      cout << "AxiMasterSim::open -> Failed to open shared memory" << endl;
      return(false);
   }

   printf("Opened shared memory %s\n",_smem->_path);

   _runEnable = true;

   // Start threads
   pthread_create(&_thread,NULL,staticRun,this);

   // Sucess
   return(true);
}

// Close the port
void AxiMasterSim::close () {
   _runEnable = false;
   usleep(1000);

   pthread_join(_thread, NULL);

   sim_close(_smem);
}

void * AxiMasterSim::staticRun(void *t) {
   AxiMasterSim *ti;
   ti = (AxiMasterSim *)t;
   ti->run();
   pthread_exit(NULL);
}

// Write config register
void AxiMasterSim::write ( uint addr, uint value ) {
   _writeAddr = addr;
   _writeData = value;
   _writeReq++;

   while ( _writeReq != _writeAck ) usleep(100);
}

// Read config register
uint AxiMasterSim::read ( uint addr ) {
   _readAddr  = addr;
   _readReq++;

   while ( _readReq != _readAck ) usleep(100);
   return(_readData);
}

void AxiMasterSim::setVerbose(bool v) {
   _verbose = v;
}

void AxiMasterSim::run() {
   AxiWriteAddr writeAddr;
   AxiWriteData writeData;
   AxiWriteComp writeComp;
   AxiReadAddr  readAddr;
   AxiReadData  readData;

   if (_smem == NULL ) return;

   cout << "Master Thread Start, " 
        << " System=" << _smem->_path
        << endl;

   while (_runEnable) {

      // New write request
      if ( _writeReq != _writeAck ) {

         if ( _verbose ) {
            cout << "Master write," 
                 << " System=" << _smem->_path
                 << " Addr=0x" << hex << setw(8) << setfill('0') << _writeAddr
                 << " Data=0x" << hex << setw(8) << setfill('0') << _writeData
                 << endl;
         }

         // Generate write address
         writeAddr.awaddr  = _writeAddr;
         writeAddr.awid    = 0;
         writeAddr.awlen   = 0;
         writeAddr.awsize  = 2;
         writeAddr.awburst = 0;
         writeAddr.awlock  = 0;
         writeAddr.awcache = 0;
         writeAddr.awprot  = 0;

         // Post addr
         setWriteAddr (_smem, &writeAddr );

         // Wait for ack
         while ( !readyWriteAddr(_smem) ) usleep(1);

         // Post write data
         writeData.wdataH = 0;
         writeData.wdataL = _writeData;
         writeData.wlast  = 1;
         writeData.wid    = 0;
         writeData.wstrb  = 0xF;

         // Post data
         setWriteData (_smem, &writeData );

         // Wait for ack
         while ( !readyWriteData(_smem) ) usleep(1);

         // Wait for completion
         while ( !getWriteComp (_smem, &writeComp ) ) usleep(1);

         _writeAck = _writeReq;
      }

      // New read request
      else if ( _readReq != _readAck ) {

         if ( _verbose ) {
            cout << "Master read," 
                 << " System=" << _smem->_path
                 << " Addr=0x" << hex << setw(8) << setfill('0') << _readAddr
                 << endl;
         }

         // Generate read address
         readAddr.araddr  = _readAddr;
         readAddr.arid    = 0;
         readAddr.arlen   = 0;
         readAddr.arsize  = 2;
         readAddr.arburst = 0;
         readAddr.arlock  = 0;
         readAddr.arprot  = 0;
         readAddr.arcache = 0;

         // Post addr
         setReadAddr (_smem, &readAddr );

         // Wait for ack
         while ( !readyReadAddr(_smem) ) usleep(1);

         // Wait for read to finish
         while ( !getReadData (_smem, &readData ) ) usleep(1);

         if ( ! readData.rlast ) cout << "!!!!!!!!!!! Error: Invalid last value on read !!!!!!!!!!" << endl;

         _readData = readData.rdataL;

         if ( _verbose ) {
            cout << "Master read done," 
                 << " System=" << _smem->_path
                 << " Addr=0x" << hex << setw(8) << setfill('0') << _readAddr
                 << " Data=0x" << hex << setw(8) << setfill('0') << _readData
                 << endl;
         }
         _readAck = _readReq;
      }
      else usleep(10);
   }
}

