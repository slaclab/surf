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
#define s_clock        0
#define s_reset        1
#define s_port         2

#define s_opCode       3
#define s_opCodeEn     4
#define s_remData      5

#define PORT_COUNT     6

// Structure to track state
typedef struct {

   uint32_t  currClk;
   uint16_t  port;
   time_t    ltime;
  
   uint8_t   remData;
   uint8_t   ocData;
   uint8_t   ocDataEn;

   void *    zmqCtx;
   void *    zmqSbSrv;
  
} RogueSideBandData;

// Init function
void RogueSideBandInit(vhpiHandleT compInst);

// Callback function for updating
void RogueSideBandUpdate ( void *userPtr );

// Restart the zmq link
void zmqRestart(RogueSideBandData *data, portDataT *portData) {

// Receive data if it is available
int zmqRecvSbData ( RogueSideBandData *data, portDataT *portData );

#endif

