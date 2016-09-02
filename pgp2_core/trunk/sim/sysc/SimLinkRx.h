//----------------------------------------------------------------------------------------
// Title         : Simulation Frame Receive
// Project       : Generic
//----------------------------------------------------------------------------------------
// File          : SimLinkRx.h
// Author        : Ryan Herbst, rherbst@slac.stanford.edu
// Created       : 09/07/2012
//----------------------------------------------------------------------------------------
// Description:
// Class to receive frame in simulation.
//----------------------------------------------------------------------------------------
// This file is part of 'SLAC PGP2 Core'.
// It is subject to the license terms in the LICENSE.txt file found in the 
// top-level directory of this distribution and at: 
//    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
// No part of 'SLAC PGP2 Core', including this file, 
// may be copied, modified, propagated, or distributed except according to 
// the terms contained in the LICENSE.txt file.
//----------------------------------------------------------------------------------------
// Modification history:
// 09/07/2012: created.
//----------------------------------------------------------------------------------------
#ifndef __SIM_LINK_RX_H__
#define __SIM_LINK_RX_H__
#include <systemc.h>
#include <sys/types.h>
#include <sys/mman.h>
#include <fcntl.h>  
#include "SimLinkRx.h"
using namespace std;

// Constant
#define SIM_LINK_RX_BUFF_SIZE 1000000

// Shared memory structure
typedef struct {

   // Upstream
   uint        usReqCount;
   uint        usAckCount;
   uint        usData[SIM_LINK_RX_BUFF_SIZE];
   uint        usSize;
   uint        usVc;
   uint        usEofe;
   uint        usEthMode;
   
   // Downstream
   uint        dsReqCount;
   uint        dsAckCount;
   uint        dsData[SIM_LINK_RX_BUFF_SIZE];
   uint        dsSize;
   uint        dsVc;
   uint        dsEthMode;

} SimLinkRxMemory;


// Module declaration
SC_MODULE(SimLinkRx) {

   // Verilog interface signals
   sc_in    <sc_logic  >  rxClk;
   sc_in    <sc_logic  >  rxReset;
   sc_out   <sc_logic  >  vcFrameRxSOF;
   sc_out   <sc_logic  >  vcFrameRxEOF;
   sc_out   <sc_logic  >  vcFrameRxEOFE;
   sc_out   <sc_lv<16> >  vcFrameRxData;
   sc_out   <sc_logic  >  vc0FrameRxValid;
   sc_in    <sc_logic  >  vc0LocBuffAFull;
   sc_out   <sc_logic  >  vc1FrameRxValid;
   sc_in    <sc_logic  >  vc1LocBuffAFull;
   sc_out   <sc_logic  >  vc2FrameRxValid;
   sc_in    <sc_logic  >  vc2LocBuffAFull;
   sc_out   <sc_logic  >  vc3FrameRxValid;
   sc_in    <sc_logic  >  vc3LocBuffAFull;
   sc_in    <sc_logic  >  ethMode;

   // Thread to process data
   void vcThread(void);

   // Shared memory
   uint            smemFd_;
   SimLinkRxMemory *smem_;
   string          smemFile_;

   // Constructor
   SC_CTOR(SimLinkRx):
      rxClk("rxClk"),
      rxReset("rxReset"),
      vcFrameRxSOF("vcFrameRxSOF"),
      vcFrameRxEOF("vcFrameRxEOF"),
      vcFrameRxEOFE("vcFrameRxEOFE"),
      vcFrameRxData("vcFrameRxData"),
      vc0FrameRxValid("vc0FrameRxValid"),
      vc0LocBuffAFull("vc0LocBuffAFull"),
      vc1FrameRxValid("vc1FrameRxValid"),
      vc1LocBuffAFull("vc1LocBuffAFull"),
      vc2FrameRxValid("vc2FrameRxValid"),
      vc2LocBuffAFull("vc2LocBuffAFull"),
      vc3FrameRxValid("vc3FrameRxValid"),
      vc3LocBuffAFull("vc3LocBuffAFull"),
      ethMode("ethMode")
   {

      // Create filename
      stringstream tmp;
      tmp.str("");
      tmp << "simlink_" << getlogin() << "_" << dec << SHM_ID;
      smemFile_ = tmp.str();

      // Open shared memory
      smemFd_ = shm_open(smemFile_.c_str(), (O_CREAT | O_RDWR), (S_IRUSR | S_IWUSR | S_IRGRP | S_IWGRP | S_IROTH | S_IWOTH));
      smem_ = NULL;

      // Failed to open shred memory
      if ( smemFd_ > 0 ) {
  
         // Force permissions regardless of umask
         fchmod(smemFd_, (S_IRUSR | S_IWUSR | S_IRGRP | S_IWGRP | S_IROTH | S_IWOTH));
 
         // Set the size of the shared memory segment
         ftruncate(smemFd_, sizeof(SimLinkRxMemory));

         // Map the shared memory
         if((smem_ = (SimLinkRxMemory *)mmap(0, sizeof(SimLinkRxMemory),
                   (PROT_READ | PROT_WRITE), MAP_SHARED, smemFd_, 0)) == MAP_FAILED) {
            smemFd_ = -1;
            smem_   = NULL;
         }

         // Init records
         if ( smem_ != NULL ) {
            smem_->dsReqCount = 0;
            smem_->dsAckCount = 0;
         }
      }

      if ( smem_ != NULL ) cout << "SimLinkRx::SimLinkRx -> Opened shared memory file: " << smemFile_ << endl;
      else cout << "SimLinkRx::SimLinkRx -> Failed to open shared memory file: " << smemFile_ << endl;

      // Setup threads
      SC_CTHREAD(vcThread,rxClk.pos());
   }
};

#endif
