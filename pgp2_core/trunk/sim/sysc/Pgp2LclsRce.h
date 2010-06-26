//----------------------------------------------------------------------------------------
// Title         : PGP Virtual Channel, SystemC LCLS RCE Model
// Project       : PGP Version 2
//----------------------------------------------------------------------------------------
// File          : Pgp2LclsRce.h
// Author        : Ryan Herbst, rherbst@slac.stanford.edu
// Created       : 12/02/2009
//----------------------------------------------------------------------------------------
// Description:
// Class to model LCLS RCE operations
//----------------------------------------------------------------------------------------
// Copyright (c) 2009 by SLAC National Accelerator Laboratory. All rights reserved.
//----------------------------------------------------------------------------------------
// Modification history:
// 12/02/2009: created.
//----------------------------------------------------------------------------------------
#ifndef __PGP2_LCLS_RCE_H__
#define __PGP2_LCLS_RCE_H__
#include <systemc.h>
#include "Pgp2VcReg.h"
#include "Pgp2VcCmd.h"
using namespace std;

// Module declaration
SC_MODULE(Pgp2LclsRce) {

   // Verilog interface signals
   sc_in    <sc_logic  >  pgpClk;
   sc_in    <sc_logic  >  pgpRst;
   sc_out   <sc_logic  >  vc0TxValid;
   sc_in    <sc_logic  >  vc0TxReady;
   sc_out   <sc_logic  >  vc0TxSOF;
   sc_out   <sc_logic  >  vc0TxEOF;
   sc_out   <sc_logic  >  vc0TxEOFE;
   sc_out   <sc_lv<32> >  vc0TxDataLow;
   sc_out   <sc_lv<32> >  vc0TxDataHigh;
   sc_in    <sc_logic  >  vc0RemBuffAFull;
   sc_in    <sc_logic  >  vc0RemBuffFull;
   sc_in    <sc_logic  >  vc0RxValid;
   sc_in    <sc_logic  >  vc0RxSOF;
   sc_in    <sc_logic  >  vc0RxEOF;
   sc_in    <sc_logic  >  vc0RxEOFE;
   sc_in    <sc_lv<32> >  vc0RxDataLow;
   sc_in    <sc_lv<32> >  vc0RxDataHigh;
   sc_out   <sc_logic  >  vc0LocBuffAFull;
   sc_out   <sc_logic  >  vc0LocBuffFull;
   sc_in    <sc_lv<2>  >  vc0Num;
   sc_out   <sc_logic  >  vc1TxValid;
   sc_in    <sc_logic  >  vc1TxReady;
   sc_out   <sc_logic  >  vc1TxSOF;
   sc_out   <sc_logic  >  vc1TxEOF;
   sc_out   <sc_logic  >  vc1TxEOFE;
   sc_out   <sc_lv<32> >  vc1TxDataLow;
   sc_out   <sc_lv<32> >  vc1TxDataHigh;
   sc_in    <sc_logic  >  vc1RemBuffAFull;
   sc_in    <sc_logic  >  vc1RemBuffFull;
   sc_in    <sc_logic  >  vc1RxValid;
   sc_in    <sc_logic  >  vc1RxSOF;
   sc_in    <sc_logic  >  vc1RxEOF;
   sc_in    <sc_logic  >  vc1RxEOFE;
   sc_in    <sc_lv<32> >  vc1RxDataLow;
   sc_in    <sc_lv<32> >  vc1RxDataHigh;
   sc_out   <sc_logic  >  vc1LocBuffAFull;
   sc_out   <sc_logic  >  vc1LocBuffFull;
   sc_in    <sc_lv<2>  >  vc1Num;
   sc_out   <sc_logic  >  vc2TxValid;
   sc_in    <sc_logic  >  vc2TxReady;
   sc_out   <sc_logic  >  vc2TxSOF;
   sc_out   <sc_logic  >  vc2TxEOF;
   sc_out   <sc_logic  >  vc2TxEOFE;
   sc_out   <sc_lv<32> >  vc2TxDataLow;
   sc_out   <sc_lv<32> >  vc2TxDataHigh;
   sc_in    <sc_logic  >  vc2RemBuffAFull;
   sc_in    <sc_logic  >  vc2RemBuffFull;
   sc_in    <sc_logic  >  vc2RxValid;
   sc_in    <sc_logic  >  vc2RxSOF;
   sc_in    <sc_logic  >  vc2RxEOF;
   sc_in    <sc_logic  >  vc2RxEOFE;
   sc_in    <sc_lv<32> >  vc2RxDataLow;
   sc_in    <sc_lv<32> >  vc2RxDataHigh;
   sc_out   <sc_logic  >  vc2LocBuffAFull;
   sc_out   <sc_logic  >  vc2LocBuffFull;
   sc_in    <sc_lv<2>  >  vc2Num;
   sc_in    <sc_logic  >  pgpLinkReady;
   sc_in    <sc_lv<2>  >  vcWidth;

   // Virtual Channels
   Pgp2VcCmd     cmdModel;
   Pgp2VcReg     intRegModel;
   Pgp2VcReg     extRegModel;

   // Run thread
   void runThread();

   // Constructor
   SC_CTOR(Pgp2LclsRce):
      pgpClk("pgpClk"),
      pgpRst("pgpRst"),
      vc0TxValid("vc0TxValid"),
      vc0TxReady("vc0TxReady"),
      vc0TxSOF("vc0TxSOF"),
      vc0TxEOF("vc0TxEOF"),
      vc0TxEOFE("vc0TxEOFE"),
      vc0TxDataLow("vc0TxDataLow"),
      vc0TxDataHigh("vc0TxDataHigh"),
      vc0RemBuffAFull("vc0RemBuffAFull"),
      vc0RemBuffFull("vc0RemBuffFull"),
      vc0RxValid("vc0RxValid"),
      vc0RxSOF("vc0RxSOF"),
      vc0RxEOF("vc0RxEOF"),
      vc0RxEOFE("vc0RxEOFE"),
      vc0RxDataLow("vc0RxDataLow"),
      vc0RxDataHigh("vc0RxDataHigh"),
      vc0LocBuffAFull("vc0LocBuffAFull"),
      vc0LocBuffFull("vc0LocBuffFull"),
      vc0Num("vc0Num"),
      vc1TxValid("vc1TxValid"),
      vc1TxReady("vc1TxReady"),
      vc1TxSOF("vc1TxSOF"),
      vc1TxEOF("vc1TxEOF"),
      vc1TxEOFE("vc1TxEOFE"),
      vc1TxDataLow("vc1TxDataLow"),
      vc1TxDataHigh("vc1TxDataHigh"),
      vc1RemBuffAFull("vc1RemBuffAFull"),
      vc1RemBuffFull("vc1RemBuffFull"),
      vc1RxValid("vc1RxValid"),
      vc1RxSOF("vc1RxSOF"),
      vc1RxEOF("vc1RxEOF"),
      vc1RxEOFE("vc1RxEOFE"),
      vc1RxDataLow("vc1RxDataLow"),
      vc1RxDataHigh("vc1RxDataHigh"),
      vc1LocBuffAFull("vc1LocBuffAFull"),
      vc1LocBuffFull("vc1LocBuffFull"),
      vc1Num("vc1Num"),
      vc2TxValid("vc2TxValid"),
      vc2TxReady("vc2TxReady"),
      vc2TxSOF("vc2TxSOF"),
      vc2TxEOF("vc2TxEOF"),
      vc2TxEOFE("vc2TxEOFE"),
      vc2TxDataLow("vc2TxDataLow"),
      vc2TxDataHigh("vc2TxDataHigh"),
      vc2RemBuffAFull("vc2RemBuffAFull"),
      vc2RemBuffFull("vc2RemBuffFull"),
      vc2RxValid("vc2RxValid"),
      vc2RxSOF("vc2RxSOF"),
      vc2RxEOF("vc2RxEOF"),
      vc2RxEOFE("vc2RxEOFE"),
      vc2RxDataLow("vc2RxDataLow"),
      vc2RxDataHigh("vc2RxDataHigh"),
      vc2LocBuffAFull("vc2LocBuffAFull"),
      vc2LocBuffFull("vc2LocBuffFull"),
      vc2Num("vc2Num"),
      pgpLinkReady("pgpLinkReady"),
      vcWidth("vcWidth"),
      cmdModel("cmdModel"),
      intRegModel("intRegModel"),
      extRegModel("extRegModel")
   {

      // Start thread
      SC_THREAD(runThread);

      // CMD Model
      cmdModel.pgpTxClk(pgpClk);
      cmdModel.pgpTxRst(pgpRst);
      cmdModel.vcTxValid(vc0TxValid);
      cmdModel.vcTxReady(vc0TxReady);
      cmdModel.vcTxSOF(vc0TxSOF);
      cmdModel.vcTxEOF(vc0TxEOF);
      cmdModel.vcTxEOFE(vc0TxEOFE);
      cmdModel.vcTxDataLow(vc0TxDataLow);
      cmdModel.vcTxDataHigh(vc0TxDataHigh);
      cmdModel.vcRemBuffAFull(vc0RemBuffAFull);
      cmdModel.vcRemBuffFull(vc0RemBuffFull);
      cmdModel.pgpRxClk(pgpClk);
      cmdModel.pgpRxRst(pgpRst);
      cmdModel.vcRxValid(vc0RxValid);
      cmdModel.vcRxSOF(vc0RxSOF);
      cmdModel.vcRxEOF(vc0RxEOF);
      cmdModel.vcRxEOFE(vc0RxEOFE);
      cmdModel.vcRxDataLow(vc0RxDataLow);
      cmdModel.vcRxDataHigh(vc0RxDataHigh);
      cmdModel.vcLocBuffAFull(vc0LocBuffAFull);
      cmdModel.vcLocBuffFull(vc0LocBuffFull);
      cmdModel.pgpLinkReady(pgpLinkReady);
      cmdModel.vcWidth(vcWidth);
      cmdModel.vcNum(vc0Num);

      // External Reg Model
      extRegModel.pgpTxClk(pgpClk);
      extRegModel.pgpTxRst(pgpRst);
      extRegModel.vcTxValid(vc1TxValid);
      extRegModel.vcTxReady(vc1TxReady);
      extRegModel.vcTxSOF(vc1TxSOF);
      extRegModel.vcTxEOF(vc1TxEOF);
      extRegModel.vcTxEOFE(vc1TxEOFE);
      extRegModel.vcTxDataLow(vc1TxDataLow);
      extRegModel.vcTxDataHigh(vc1TxDataHigh);
      extRegModel.vcRemBuffAFull(vc1RemBuffAFull);
      extRegModel.vcRemBuffFull(vc1RemBuffFull);
      extRegModel.pgpRxClk(pgpClk);
      extRegModel.pgpRxRst(pgpRst);
      extRegModel.vcRxValid(vc1RxValid);
      extRegModel.vcRxSOF(vc1RxSOF);
      extRegModel.vcRxEOF(vc1RxEOF);
      extRegModel.vcRxEOFE(vc1RxEOFE);
      extRegModel.vcRxDataLow(vc1RxDataLow);
      extRegModel.vcRxDataHigh(vc1RxDataHigh);
      extRegModel.vcLocBuffAFull(vc1LocBuffAFull);
      extRegModel.vcLocBuffFull(vc1LocBuffFull);
      extRegModel.pgpLinkReady(pgpLinkReady);
      extRegModel.vcWidth(vcWidth);
      extRegModel.vcNum(vc1Num);

      // Internal Reg Model
      intRegModel.pgpTxClk(pgpClk);
      intRegModel.pgpTxRst(pgpRst);
      intRegModel.vcTxValid(vc2TxValid);
      intRegModel.vcTxReady(vc2TxReady);
      intRegModel.vcTxSOF(vc2TxSOF);
      intRegModel.vcTxEOF(vc2TxEOF);
      intRegModel.vcTxEOFE(vc2TxEOFE);
      intRegModel.vcTxDataLow(vc2TxDataLow);
      intRegModel.vcTxDataHigh(vc2TxDataHigh);
      intRegModel.vcRemBuffAFull(vc2RemBuffAFull);
      intRegModel.vcRemBuffFull(vc2RemBuffFull);
      intRegModel.pgpRxClk(pgpClk);
      intRegModel.pgpRxRst(pgpRst);
      intRegModel.vcRxValid(vc2RxValid);
      intRegModel.vcRxSOF(vc2RxSOF);
      intRegModel.vcRxEOF(vc2RxEOF);
      intRegModel.vcRxEOFE(vc2RxEOFE);
      intRegModel.vcRxDataLow(vc2RxDataLow);
      intRegModel.vcRxDataHigh(vc2RxDataHigh);
      intRegModel.vcLocBuffAFull(vc2LocBuffAFull);
      intRegModel.vcLocBuffFull(vc2LocBuffFull);
      intRegModel.pgpLinkReady(pgpLinkReady);
      intRegModel.vcWidth(vcWidth);
      intRegModel.vcNum(vc2Num);
   }
};

#endif
