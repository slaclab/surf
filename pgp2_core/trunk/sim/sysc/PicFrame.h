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
// Copyright (c) 2009 by SLAC National Accelerator Laboratory. All rights reserved.
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
