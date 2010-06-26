//----------------------------------------------------------------------------------------
// Title         : PGP Virtual Channel, SystemC Interface Model
// Project       : PGP Version 2
//----------------------------------------------------------------------------------------
// File          : Pgp2VcTxModel.h
// Author        : Ryan Herbst, rherbst@slac.stanford.edu
// Created       : 04/16/2009
//----------------------------------------------------------------------------------------
// Description:
// Class to model an entitiy which interfaces to a PGP virtual channel transmit interface.
//----------------------------------------------------------------------------------------
// Copyright (c) 2009 by SLAC National Accelerator Laboratory. All rights reserved.
//----------------------------------------------------------------------------------------
// Modification history:
// 04/16/2009: created.
//----------------------------------------------------------------------------------------
#ifndef __PGP2_VC_TX_MODEL_H__
#define __PGP2_VC_TX_MODEL_H__
#include <systemc.h>
#include "Pgp2VcFrame.h"
using namespace std;

// Module declaration
SC_MODULE(Pgp2VcTxModel) {

   // Verilog interface signals
   sc_in    <sc_logic  >  pgpTxClk;
   sc_in    <sc_logic  >  pgpTxRst;
   sc_out   <sc_logic  >  vcTxValid;
   sc_in    <sc_logic  >  vcTxReady;
   sc_out   <sc_logic  >  vcTxSOF;
   sc_out   <sc_logic  >  vcTxEOF;
   sc_out   <sc_logic  >  vcTxEOFE;
   sc_out   <sc_lv<32> >  vcTxDataLow;
   sc_out   <sc_lv<32> >  vcTxDataHigh;
   sc_in    <sc_logic  >  vcRemBuffAFull;
   sc_in    <sc_logic  >  vcRemBuffFull;
   sc_in    <sc_lv<2>  >  vcWidth;

   // FIFOs for RX data, Used to pass data pointer
   sc_fifo<unsigned long> frameFifo;

   // Thread to recive data
   void vcTxThread(void);

   // Method to check number of free slots
   unsigned int free();

   // Method to transmit frame
   void txFrame(Pgp2VcFrame *frame);

   // Flow control state
   bool remBuffAFull;
   bool remBuffFull;

   // Methods to get state of flow control
   bool getRemBuffAFull(void);
   bool getRemBuffFull(void);

   // Flag to enable random pauses
   unsigned int pauseMask;

   // Method to enable random pauses
   void setPauseMask(unsigned int mask);

   // Constructor
   SC_CTOR(Pgp2VcTxModel):
      pgpTxClk("pgpTxClk"),
      pgpTxRst("pgpTxRst"),
      vcTxValid("vcTxValid"),
      vcTxReady("vcTxReady"),
      vcTxSOF("vcTxSOF"),
      vcTxEOF("vcTxEOF"),
      vcTxEOFE("vcTxEOFE"),
      vcTxDataLow("vcTxDataLow"),
      vcTxDataHigh("vcTxDataHigh"),
      vcRemBuffAFull("vcRemBuffAFull"),
      vcRemBuffFull("vcRemBuffFull"),
      vcWidth("vcWidth"),
      frameFifo(32)
   {

      // Setup threads
      SC_CTHREAD(vcTxThread,pgpTxClk.pos());

      // Init Flow Control
      remBuffAFull = false;
      remBuffFull  = false;
      pauseMask    = 0;
   }
};

#endif
