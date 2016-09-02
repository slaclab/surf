//----------------------------------------------------------------------------------------
// Title         : PGP Virtual Channel, SystemC VC Link Test
// Project       : PGP Version 2
//----------------------------------------------------------------------------------------
// File          : Pgp2VcTest.h
// Author        : Ryan Herbst, rherbst@slac.stanford.edu
// Created       : 04/16/2009
//----------------------------------------------------------------------------------------
// Description:
// Class to generate and receive traffic over a VC link
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
#ifndef __PGP2_VC_TEST_H__
#define __PGP2_VC_TEST_H__
#include <systemc.h>
#include "Pgp2VcTest.h"
#include "Pgp2VcRxModel.h"
#include "Pgp2VcTxModel.h"
using namespace std;

// Module declaration
SC_MODULE(Pgp2VcTest) {

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
   sc_in    <sc_logic  >  pgpLinkReady;
   sc_in    <sc_lv<2>  >  vcWidth;
   sc_in    <sc_lv<2>  >  vcNum;

   // Transmit/Receive Module
   Pgp2VcRxModel rxModel;
   Pgp2VcTxModel txModel;

   // FIFOs pending frame pointers
   sc_fifo<unsigned long> frameFifo;

   // Transmit/Receive Thread
   void txThread(void);
   void rxThread(void);

   // Constructor
   SC_CTOR(Pgp2VcTest):
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
      pgpLinkReady("pgpLinkReady"),
      vcWidth("vcWidth"),
      vcNum("vcNum"),
      frameFifo(64),
      txModel("txModel"),
      rxModel("rxModel")
   {

      // Setup threads
      SC_THREAD(rxThread);
      SC_THREAD(txThread);

      // Connect Transmit Module
      txModel.pgpTxClk(pgpTxClk);
      txModel.pgpTxRst(pgpTxRst);
      txModel.vcTxValid(vcTxValid);
      txModel.vcTxReady(vcTxReady);
      txModel.vcTxSOF(vcTxSOF);
      txModel.vcTxEOF(vcTxEOF);
      txModel.vcTxEOFE(vcTxEOFE);
      txModel.vcTxDataLow(vcTxDataLow);
      txModel.vcTxDataHigh(vcTxDataHigh);
      txModel.vcRemBuffAFull(vcRemBuffAFull);
      txModel.vcRemBuffFull(vcRemBuffFull);
      txModel.vcWidth(vcWidth);

      // Connect Receive Module
      rxModel.pgpRxClk(pgpRxClk);
      rxModel.pgpRxRst(pgpRxRst);
      rxModel.vcRxValid(vcRxValid);
      rxModel.vcRxSOF(vcRxSOF);
      rxModel.vcRxEOF(vcRxEOF);
      rxModel.vcRxEOFE(vcRxEOFE);
      rxModel.vcRxDataLow(vcRxDataLow);
      rxModel.vcRxDataHigh(vcRxDataHigh);
      rxModel.vcLocBuffAFull(vcLocBuffAFull);
      rxModel.vcLocBuffFull(vcLocBuffFull);
      rxModel.vcWidth(vcWidth);
   }
};

#endif
