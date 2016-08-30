//-----------------------------------------------------------------------------
// Title         : Pretty Good Protocol, VHPI Library Generic Interface
// Project       : General Purpose Core
//-----------------------------------------------------------------------------
// File          : VhpiGeneric.h
// Author        : Ryan Herbst, rherbst@slac.stanford.edu
// Created       : 04/03/2007
//-----------------------------------------------------------------------------
// Description:
// This is a generic block of code to handle the low level interface to the
// VHDL simulator. 
//-----------------------------------------------------------------------------
// This file is part of 'SLAC Firmware Standard Library'.
// It is subject to the license terms in the LICENSE.txt file found in the 
// top-level directory of this distribution and at: 
//    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
// No part of 'SLAC Firmware Standard Library', including this file, 
// may be copied, modified, propagated, or distributed except according to 
// the terms contained in the LICENSE.txt file.
//-----------------------------------------------------------------------------
// Modification history:
// 04/03/2007: created.
// 05/11/2007: Added ability to tri-state outputs.
//-----------------------------------------------------------------------------

#ifndef __VHPI_GENERIC_H__
#define __VHPI_GENERIC_H__

#include <vhpi_user.h>

// Port count for interface
#define MAX_PORT_COUNT 48

// Macros for set/get ints
#define getInt(idx)     (portData->intValue[idx])
#define setInt(idx,val) (portData->intValue[idx] = val)

// Structure to hold data related to signal interface
typedef struct portDataS {

   // Number of ports
   int portCount;

   // Array to hold port handles
   vhpiHandleT portHandle[MAX_PORT_COUNT];

   // Array to hold port values
   vhpiValueT *portValue[MAX_PORT_COUNT];

   // Array to hold value converted to int, -1 for tri-state
   unsigned int intValue[MAX_PORT_COUNT];
   unsigned int outEnable[MAX_PORT_COUNT];

   // Array to hold port directions
   vhpiIntT portDir[MAX_PORT_COUNT];

   // Array to hold port width
   vhpiIntT portWidth[MAX_PORT_COUNT];

   // Current simulation time
   vhpiTimeT simTime;
   
   // Name of block
   char *blockName;

   // State update function
   void (*stateUpdate)(void *);

   // Pointer to hold state information
   void *stateData;

} portDataT;


// Function that is called as the module is initialized. 
// Check ports and setup functions to handle clock changes
void VhpiGenericInit(vhpiHandleT compInst, portDataT *portData );


#endif
