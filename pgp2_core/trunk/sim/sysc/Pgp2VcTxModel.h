//----------------------------------------------------------------------------------------
// Title         : PGP Simulation Frame Receive
// Project       : PGP Version 2
//----------------------------------------------------------------------------------------
// File          : PgpRxSim.h
// Author        : Ryan Herbst, rherbst@slac.stanford.edu
// Created       : 09/07/2012
//----------------------------------------------------------------------------------------
// Description:
// Class to receive PGP frame in simulation.
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
#ifndef __PGP2_RX_SIM_H__
#define __PGP2_RX_SIM_H__
#include <systemc.h>
#include "PgpRxSim.h"
using namespace std;

// Module declaration
SC_MODULE(PgpRxSim) {

   // Verilog interface signals
   sc_in    <sc_logic  >  pgpRxClk;
   sc_in    <sc_logic  >  pgpRxReset;
   sc_out   <sc_logic  >  vcFrameRxSOF;
   sc_out   <sc_logic  >  vcFrameRxEOF;
   sc_out   <sc_logic  >  vcFrameRxEOFE;
   sc_out   <sc_lv<16> >  vcFrameRxData;
   sc_out   <sc_logic  >  vc0FrameRxValid;
   sc_in    <sc_logic  >  vc0RemBuffAFull;
   sc_in    <sc_logic  >  vc0RemBuffFull;
   sc_out   <sc_logic  >  vc1FrameRxValid;
   sc_in    <sc_logic  >  vc1RemBuffAFull;
   sc_in    <sc_logic  >  vc1RemBuffFull;
   sc_out   <sc_logic  >  vc2FrameRxValid;
   sc_in    <sc_logic  >  vc2RemBuffAFull;
   sc_in    <sc_logic  >  vc2RemBuffFull;
   sc_out   <sc_logic  >  vc3FrameRxValid;
   sc_in    <sc_logic  >  vc3RemBuffAFull;
   sc_in    <sc_logic  >  vc3RemBuffFull;

   // Thread to process data
   void vcThread(void);

   // Constructor
   SC_CTOR(PgpRxSim):
      pgpTxClk("pgpRxClk"),
      pgpTxRst("pgpRxReset"),
      vcFrameRxSOF("vcFrameRxSOF"),
      vcFrameRxEOF("vcFrameRxEOF"),
      vcFrameRxEOFE("vcFrameRxEOFE"),
      vcFrameRxData("vcFrameRxData"),
      vc0FrameRxValid("vc0FrameRxValid"),
      vc0RemBuffAFull("vc0RemBuffAFull"),
      vc0RemBuffFull("vc0RemBuffFull"),
      vc1FrameRxValid("vc1FrameRxValid"),
      vc1RemBuffAFull("vc1RemBuffAFull"),
      vc1RemBuffFull("vc1RemBuffFull"),
      vc2FrameRxValid("vc2FrameRxValid"),
      vc2RemBuffAFull("vc2RemBuffAFull"),
      vc2RemBuffFull("vc2RemBuffFull"),
      vc3FrameRxValid("vc3FrameRxValid"),
      vc3RemBuffAFull("vc3RemBuffAFull"),
      vc3RemBuffFull("vc3RemBuffFull")
   {

      // Setup threads
      SC_CTHREAD(vcThread,pgpRxClk.pos());
   }
};

#endif
