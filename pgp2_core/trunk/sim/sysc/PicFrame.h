//----------------------------------------------------------------------------------------
// Title         : PIC SystemC Frame Container
// Project       : General
//----------------------------------------------------------------------------------------
// File          : PicFrame.h
// Author        : Ryan Herbst, rherbst@slac.stanford.edu
// Created       : 08/26/2009
//----------------------------------------------------------------------------------------
// Description:
// Class to contain a PIC frame.
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
// 08/26/2009: created.
//----------------------------------------------------------------------------------------
#ifndef __PIC_FRAME_H__
#define __PIC_FRAME_H__
using namespace std;

// Module declaration
class PicFrame {

   public:

      // Initial size at creation and increment size
      static const unsigned int sizeIncrement = 512;

      // Data container
      unsigned char *data;
      unsigned int  size;
      unsigned int  buffer;

      // Status Value
      unsigned int status;
      unsigned int freeList;

      // Constructor
      PicFrame();

      // DeConstructor
      ~PicFrame();

      // Method to add data
      void addData(unsigned char data);
};

#endif
