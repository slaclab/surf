//////////////////////////////////////////////////////////////////////////////
// This file is part of 'SLAC Firmware Standard Library'.
// It is subject to the license terms in the LICENSE.txt file found in the 
// top-level directory of this distribution and at: 
//    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
// No part of 'SLAC Firmware Standard Library', including this file, 
// may be copied, modified, propagated, or distributed except according to 
// the terms contained in the LICENSE.txt file.
//////////////////////////////////////////////////////////////////////////////

#ifndef __ROGUE_TCP_STREAM_H__
#define __ROGUE_TCP_STREAM_H__

#include <vhpi_user.h>
#include <stdint.h>
#include <time.h>

// Signals
#define s_clock        0
#define s_reset        1
#define s_port         2
#define s_ssi          3

#define s_obValid      4
#define s_obReady      5
#define s_obDataLow    6
#define s_obDataHigh   7
#define s_obUserLow    8
#define s_obUserHigh   9
#define s_obKeep       10
#define s_obLast       11

#define s_ibValid      12
#define s_ibReady      13
#define s_ibDataLow    14
#define s_ibDataHigh   15
#define s_ibUserLow    16
#define s_ibUserHigh   17
#define s_ibKeep       18
#define s_ibLast       19

#define PORT_COUNT     20

#define MAX_FRAME 20000000

// Structure to track state
typedef struct {

   uint8_t   obFuser;
   uint8_t   obLuser;
   uint32_t  obSize;
   uint32_t  obCount;
   uint8_t   obData[MAX_FRAME];
   uint32_t  obValid;

   uint8_t   ibFuser;
   uint8_t   ibLuser;
   uint32_t  ibSize;
   uint8_t   ibData[MAX_FRAME];

   uint32_t  currClk;
   uint16_t  port;
   uint8_t   ssi;
   time_t    ltime;
  
   void *    zmqCtx;
   void *    zmqPush;
   void *    zmqPull;
  
} RogueTcpStreamData;

// Init function
void RogueTcpStreamInit(vhpiHandleT compInst);

// Callback function for updating
void RogueTcpStreamUpdate ( void *userPtr );

// Start/resetart zeromq server
void RogueTcpStreamRestart(RogueTcpStreamData *data, portDataT *portData);

// Send a message
void RogueTcpStreamSend ( RogueTcpStreamData *data, portDataT *portData );

// Receive data if it is available
int RogueTcpStreamRecv ( RogueTcpStreamData *data, portDataT *portData );

#endif

