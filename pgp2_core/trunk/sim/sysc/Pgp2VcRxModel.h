//----------------------------------------------------------------------------------------
// Title         : PGP Virtual Channel, SystemC Interface Model
// Project       : PGP Version 2
//----------------------------------------------------------------------------------------
// File          : Pgp2VcRxModel.h
// Author        : Ryan Herbst, rherbst@slac.stanford.edu
// Created       : 04/16/2009
//----------------------------------------------------------------------------------------
// Description:
// Class to model an entitiy which interfaces to a PGP virtual channel receive interface.
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
// 04/16/2009: created.
//----------------------------------------------------------------------------------------
#ifndef __PGP2_VC_RX_MODEL_H__
#define __PGP2_VC_RX_MODEL_H__
#include <systemc.h>
#include "Pgp2VcFrame.h"
using namespace std;

// Module declaration
SC_MODULE(Pgp2VcRxModel) {

   // Verilog interface signals
   sc_in    <sc_logic  >  pgpRxClk;
   sc_in    <sc_logic  >  pgpRxRst;
   sc_in    <sc_logic  >  vcRxValid;
   sc_in    <sc_logic  >  vcRxSOF;
   sc_in    <sc_logic  >  vcRxEOF;
   sc_in    <sc_logic  >  vcRxEOFE;
   sc_in    <sc_lv<32> >  vcRxDataLow;
   sc_in    <sc_lv<32> >  vcRxDataHigh;
   sc_out   <sc_logic  >  vcLocBuffAFull;
   sc_out   <sc_logic  >  vcLocBuffFull;
   sc_in    <sc_lv<2>  >  vcWidth;

   // FIFOs for RX data, Used to pass data pointer
   sc_fifo<unsigned long> frameFifo;

   // Thread to recive data
   void vcRxThread(void);

   // Method to read recived frame. 
   // Returns pointer to received frame, should be deleted
   Pgp2VcFrame *rxFrame(void);

   // Flow control state
   bool locBuffAFull;
   bool locBuffFull;

   // Methods to set state of flow control
   void setLocBuffAFull(bool state);
   void setLocBuffFull(bool state);

   // Constructor
   SC_CTOR(Pgp2VcRxModel):
      pgpRxClk("pgpRxClk"),
      pgpRxRst("pgpRxRst"),
      vcRxValid("vcRxValid"),
      vcRxSOF("vcRxSOF"),
      vcRxEOF("vcRxEOF"),
      vcRxEOFE("vcRxEOFE"),
      vcRxDataLow("vcRxDataLow"),
      vcRxDataHigh("vcRxDataHigh"),
      vcLocBuffAFull("vcLocBuffAFull"),
      vcLocBuffFull("vcLocBuffFull"),
      vcWidth("vcWidth"),
      frameFifo(32)
   {

      // Setup threads
      SC_CTHREAD(vcRxThread,pgpRxClk.pos());

      // Init Flow Control
      locBuffAFull = false;
      locBuffFull  = false;
   }
};

#endif
