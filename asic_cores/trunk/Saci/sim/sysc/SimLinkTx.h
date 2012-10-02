//----------------------------------------------------------------------------------------
// Title         : Simulation Frame Transmit
// Project       : Generic
//----------------------------------------------------------------------------------------
// File          : SimLinkTx.h
// Author        : Ryan Herbst, rherbst@slac.stanford.edu
// Created       : 09/07/2012
//----------------------------------------------------------------------------------------
// Description:
// Class to transmit frame in simulation.
//----------------------------------------------------------------------------------------
// Copyright (c) 2012 by SLAC National Accelerator Laboratory. All rights reserved.
//----------------------------------------------------------------------------------------
// Modification history:
// 09/07/2012: created.
//----------------------------------------------------------------------------------------
#ifndef __SIM_LINK_TX_H__
#define __SIM_LINK_TX_H__
#include <systemc.h>
#include <sys/types.h>
#include <sys/mman.h>
#include <fcntl.h>  
#include "SimLinkTx.h"
using namespace std;

// Constant
#define SIM_LINK_TX_BUFF_SIZE 1000000

// Shared memory structure
typedef struct {

   // Upstream
   uint        usReqCount;
   uint        usAckCount;
   uint        usData[SIM_LINK_TX_BUFF_SIZE];
   uint        usSize;
   uint        usVc;
   uint        usEofe;
   uint        usEthMode;
   
   // Downstream
   uint        dsReqCount;
   uint        dsAckCount;
   uint        dsData[SIM_LINK_TX_BUFF_SIZE];
   uint        dsSize;
   uint        dsVc;
   uint        dsEthMode;

} SimLinkTxMemory;


// Module declaration
SC_MODULE(SimLinkTx) {

   // Verilog interface signals
   sc_in    <sc_logic  >  txClk;
   sc_in    <sc_logic  >  txReset;
   sc_in    <sc_logic  >  vc0FrameTxValid;
   sc_out   <sc_logic  >  vc0FrameTxReady;
   sc_in    <sc_logic  >  vc0FrameTxSOF;
   sc_in    <sc_logic  >  vc0FrameTxEOF;
   sc_in    <sc_logic  >  vc0FrameTxEOFE;
   sc_in    <sc_lv<16> >  vc0FrameTxData;
   sc_in    <sc_logic  >  vc1FrameTxValid;
   sc_out   <sc_logic  >  vc1FrameTxReady;
   sc_in    <sc_logic  >  vc1FrameTxSOF;
   sc_in    <sc_logic  >  vc1FrameTxEOF;
   sc_in    <sc_logic  >  vc1FrameTxEOFE;
   sc_in    <sc_lv<16> >  vc1FrameTxData;
   sc_in    <sc_logic  >  vc2FrameTxValid;
   sc_out   <sc_logic  >  vc2FrameTxReady;
   sc_in    <sc_logic  >  vc2FrameTxSOF;
   sc_in    <sc_logic  >  vc2FrameTxEOF;
   sc_in    <sc_logic  >  vc2FrameTxEOFE;
   sc_in    <sc_lv<16> >  vc2FrameTxData;
   sc_in    <sc_logic  >  vc3FrameTxValid;
   sc_out   <sc_logic  >  vc3FrameTxReady;
   sc_in    <sc_logic  >  vc3FrameTxSOF;
   sc_in    <sc_logic  >  vc3FrameTxEOF;
   sc_in    <sc_logic  >  vc3FrameTxEOFE;
   sc_in    <sc_lv<16> >  vc3FrameTxData;
   sc_in    <sc_logic  >  ethMode;

   // Thread to process data
   void vcThread(void);

   // Shared memory
   uint            smemFd_;
   SimLinkTxMemory *smem_;
   string          smemFile_;

   // Constructor
   SC_CTOR(SimLinkTx):
      txClk("txClk"),
      txReset("txReset"),
      vc0FrameTxValid("vc0FrameTxValid"),
      vc0FrameTxReady("vc0FrameTxReady"),
      vc0FrameTxSOF("vc0FrameTxSOF"),
      vc0FrameTxEOF("vc0FrameTxEOF"),
      vc0FrameTxEOFE("vc0FrameTxEOFE"),
      vc0FrameTxData("vc0FrameTxData"),
      vc1FrameTxValid("vc1FrameTxValid"),
      vc1FrameTxReady("vc1FrameTxReady"),
      vc1FrameTxSOF("vc1FrameTxSOF"),
      vc1FrameTxEOF("vc1FrameTxEOF"),
      vc1FrameTxEOFE("vc1FrameTxEOFE"),
      vc1FrameTxData("vc1FrameTxData"),
      vc2FrameTxValid("vc2FrameTxValid"),
      vc2FrameTxReady("vc2FrameTxReady"),
      vc2FrameTxSOF("vc2FrameTxSOF"),
      vc2FrameTxEOF("vc2FrameTxEOF"),
      vc2FrameTxEOFE("vc2FrameTxEOFE"),
      vc2FrameTxData("vc2FrameTxData"),
      vc3FrameTxValid("vc3FrameTxValid"),
      vc3FrameTxReady("vc3FrameTxReady"),
      vc3FrameTxSOF("vc3FrameTxSOF"),
      vc3FrameTxEOF("vc3FrameTxEOF"),
      vc3FrameTxEOFE("vc3FrameTxEOFE"),
      vc3FrameTxData("vc3FrameTxData"),
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
         ftruncate(smemFd_, sizeof(SimLinkTxMemory));

         // Map the shared memory
         if((smem_ = (SimLinkTxMemory *)mmap(0, sizeof(SimLinkTxMemory),
                   (PROT_READ | PROT_WRITE), MAP_SHARED, smemFd_, 0)) == MAP_FAILED) {
            smemFd_ = -1;
            smem_   = NULL;
         }

         // Init records
         if ( smem_ != NULL ) {
            smem_->usReqCount = 0;
            smem_->usAckCount = 0;
         }
      }

      if ( smem_ != NULL ) cout << "SimLinkTx::SimLinkTx -> Opened shared memory file: " << smemFile_ << endl;
      else cout << "SimLinkTx::SimLinkTx -> Failed to open shared memory file: " << smemFile_ << endl;

      // Setup threads
      SC_CTHREAD(vcThread,txClk.pos());
   }
};

#endif
