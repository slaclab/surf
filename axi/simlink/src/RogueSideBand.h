//////////////////////////////////////////////////////////////////////////////
// This file is part of 'SLAC Firmware Standard Library'.
// It is subject to the license terms in the LICENSE.txt file found in the 
// top-level directory of this distribution and at: 
//    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
// No part of 'SLAC Firmware Standard Library', including this file, 
// may be copied, modified, propagated, or distributed except according to 
// the terms contained in the LICENSE.txt file.
//////////////////////////////////////////////////////////////////////////////

#ifndef __ROGUE_SIDE_BAND_H__
#define __ROGUE_SIDE_BAND_H__

#include <vhpi_user.h>
#include <stdint.h>
#include <time.h>

// Signals
#define s_clock      0
#define s_reset      1
#define s_port       2

#define s_obOpCode   3
#define s_obOpCodeEn 4
#define s_obRemData  5

#define s_ibOpCode   6
#define s_ibOpCodeEn 7
#define s_ibRemData  8

#define PORT_COUNT   9

// Structure to track state
typedef struct {

   uint32_t  currClk;
   uint16_t  port;
  
   uint8_t   obRemData;
   uint8_t   obOcData;
   uint8_t   obOcDataEn;
   
   uint8_t   ibRemData;
   uint8_t   ibOcData;
   uint8_t   ibOcDataEn;   

   void *    zmqCtx;
   void *    zmqPull;
  
} RogueSideBandData;

// Init function
void RogueSideBandInit(vhpiHandleT compInst);

// Callback function for updating
void RogueSideBandUpdate ( void *userPtr );

// Restart the zmq link
void RogueSideBandRestart(RogueSideBandData *data, portDataT *portData);

// Send a message
void RogueSideBandSend ( RogueSideBandData *data, portDataT *portData );

// Receive data if it is available
int RogueSideBandRecv ( RogueSideBandData *data, portDataT *portData );

#endif

