//////////////////////////////////////////////////////////////////////////////
// This file is part of 'SLAC Firmware Standard Library'.
// It is subject to the license terms in the LICENSE.txt file found in the 
// top-level directory of this distribution and at: 
//    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
// No part of 'SLAC Firmware Standard Library', including this file, 
// may be copied, modified, propagated, or distributed except according to 
// the terms contained in the LICENSE.txt file.
//////////////////////////////////////////////////////////////////////////////

#ifndef __ROGUE_STREAM_SIM_H__
#define __ROGUE_STREAM_SIM_H__

#include <vhpi_user.h>
#include <stdint.h>
#include <time.h>

// Signals
#define s_clock        0
#define s_reset        1
#define s_dest         2

#define s_obValid      3
#define s_obReady      4
#define s_obDataLow    5
#define s_obDataHigh   6
#define s_obUserLow    7
#define s_obUserHigh   8
#define s_obKeep       9
#define s_obLast       10

#define s_ibValid      11
#define s_ibReady      12
#define s_ibDataLow    13
#define s_ibDataHigh   14
#define s_ibUserLow    15
#define s_ibUserHigh   16
#define s_ibKeep       17
#define s_ibLast       18

#define MAX_FRAME 2000000
#define IB_PORT_BASE 5000
#define OB_PORT_BASE 6000

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
   uint32_t  dest;
   time_t    ltime;

   uint32_t  rxCount;
   uint32_t  txCount;
   uint32_t  ackCount;
   uint32_t  errCount;

   void *    zmqCtx;
   void *    zmqIbSrv;
   void *    zmqObSrv;
  
} RogueStreamSimData;

// Init function
void RogueStreamSimInit(vhpiHandleT compInst);

// Callback function for updating
void RogueStreamSimUpdate ( void *userPtr );

// Start/resetart zeromq server
void zmqRestart(RogueStreamSimData *data);

// Send a message
void zmqSend ( RogueStreamSimData *data );

// Receive data if it is available
int zmqRecv ( RogueStreamSimData *data );

#endif

