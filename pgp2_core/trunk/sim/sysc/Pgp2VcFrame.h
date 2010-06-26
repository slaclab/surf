//----------------------------------------------------------------------------------------
// Title         : PGP Virtual Channel, Frame Container
// Project       : PGP Version 2
//----------------------------------------------------------------------------------------
// File          : Pgp2VcFrame.h
// Author        : Ryan Herbst, rherbst@slac.stanford.edu
// Created       : 04/16/2009
//----------------------------------------------------------------------------------------
// Description:
// Class to contain vritual channel frames for transmit and receive.
//----------------------------------------------------------------------------------------
// Copyright (c) 2009 by SLAC National Accelerator Laboratory. All rights reserved.
//----------------------------------------------------------------------------------------
// Modification history:
// 04/16/2009: created.
//----------------------------------------------------------------------------------------
#ifndef __PGP2_VC_FRAME_H__
#define __PGP2_VC_FRAME_H__
using namespace std;

// Module declaration
class Pgp2VcFrame {

      // Initial size at creation and increment size
      static const unsigned int sizeIncrement = 512;

      // Data container
      unsigned char  *data;
      unsigned int   size;
      unsigned int   buffer;

      // EOFE Flag
      bool eofE;

      // Frame error
      bool frameError;

      // Tx Flag
      bool tx;

   public:

      // Constructor
      Pgp2VcFrame();

      // DeConstructor
      ~Pgp2VcFrame();

      // Method to init frame
      void init();

      // Methods to set/get frame data
      void addData(unsigned char data);
      unsigned char getData(unsigned int pos);

      // Methods to set/get EOFE
      void setEofE();
      bool getEofE();

      // Methods to set/get error flag
      void setFrameError();
      bool getFrameError();

      // Method to get frame size
      unsigned int getSize();

      // Set/Get tx flag
      void setTx();
      bool getTx();
};

#endif
