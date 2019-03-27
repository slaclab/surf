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

#define s_txOpCode       3
#define s_txOpCodeEn     4
#define s_txRemData      5

#define s_rxOpCode       6
#define s_rxOpCodeEn     7
#define s_rxRemData      8

#define PORT_COUNT     9

// Structure to track state
typedef struct {

   uint32_t  currClk;
   uint16_t  port;
  
   uint8_t   rxRemData;
   uint8_t   rxOpCode;
   uint8_t   rxOpCodeEn;

   uint8_t   txRemData;
   uint8_t   txRemDataChanged;  
   uint8_t   txOpCode;
   uint8_t   txOpCodeEn;

   void *    zmqCtx;
   void *    zmqPull;
   void *    zmqPush;  
  
} RogueSideBandData;

// Init function
void RogueSideBandInit(vhpiHandleT compInst);

// Callback function for updating
void RogueSideBandUpdate ( void *userPtr );

// Restart the zmq link
void RogueSideBandRestart(RogueSideBandData *data, portDataT *portData);

// Send data
void RogueSideBandSend ( RogueSideBandData *data, portDataT *portData );

// Receive data if it is available
int RogueSideBandRecv ( RogueSideBandData *data, portDataT *portData );



#endif

