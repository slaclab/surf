//----------------------------------------------------------------------------------------
// Title         : PIC SystemC Frame Container
// Project       : General
//----------------------------------------------------------------------------------------
// File          : PicFrame.cpp
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
#include "PicFrame.h"
#include <stdlib.h>
using namespace std;


// Constructor
PicFrame::PicFrame() {
   data       = NULL;
   size       = 0;
   buffer     = 0;
   status     = 0;
   freeList   = 0;
}


// DeConstructor
PicFrame::~PicFrame() {
   if ( data != NULL ) free(data);
}


// Method to add data
void PicFrame::addData(unsigned char data) {
   unsigned char *newData;
   unsigned int  x;

   if ( size == buffer ) {
      buffer += sizeIncrement;
      newData = (unsigned char *) malloc(buffer);
      for ( x=0; x < size; x++ ) newData[x] = this->data[x];
      free(this->data);
      this->data = newData;
   }
   this->data[size] = data;
   size++;
}


