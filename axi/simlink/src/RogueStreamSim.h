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
#define s_uid          3

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

#define s_opCode       20
#define s_opCodeEn     21
#define s_remData      22

#define MAX_FRAME 2000000
#define IB_PORT_BASE 5000
#define OB_PORT_BASE 6000
#define OC_PORT_BASE 7000
#define SB_PORT_BASE 8000

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
   uint32_t  uid;
   time_t    ltime;
  
   uint32_t  rxCount;
   uint32_t  txCount;
   uint32_t  ackCount;
   uint32_t  errCount;
   uint32_t  ocCount;
   uint32_t  sbCount;

   uint32_t  lRxCount;
   uint32_t  lTxCount;
   uint32_t  lOcCount;
   uint32_t  lSbCount;
   uint32_t  lAckCount;
   uint32_t  lErrCount; 

   uint8_t   sbData;
   uint8_t   ocData;
   uint8_t   ocDataEn;

   void *    zmqCtx;
   void *    zmqIbSrv;
   void *    zmqObSrv;
   void *    zmqSbSrv;
   void *    zmqOcSrv;
  
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
int zmqRecvData ( RogueStreamSimData *data );

// Ack received data
void zmqAckData ( RogueStreamSimData *data );

// Receive opcode if it is available
int zmqRecvOcData ( RogueStreamSimData *data );

// Receive side data if it is available
int zmqRecvSbData ( RogueStreamSimData *data );

#endif

