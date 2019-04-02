//////////////////////////////////////////////////////////////////////////////
// This file is part of 'SLAC Firmware Standard Library'.
// It is subject to the license terms in the LICENSE.txt file found in the 
// top-level directory of this distribution and at: 
//    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
// No part of 'SLAC Firmware Standard Library', including this file, 
// may be copied, modified, propagated, or distributed except according to 
// the terms contained in the LICENSE.txt file.
//////////////////////////////////////////////////////////////////////////////

#include "VhpiGeneric.h"
#include "RogueSideBand.h"
#include <vhpi_user.h>
#include <stdlib.h>
#include <time.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <string.h>
#include <unistd.h>
#include <stdio.h>
#include <sys/mman.h>
#include <zmq.h>
#include <time.h>

// Start/resetart zeromq server
void RogueSideBandRestart(RogueSideBandData *data, portDataT *portData) {
   char buffer[100];

   if ( data->zmqPush != NULL ) zmq_close(data->zmqPush );   
   if ( data->zmqPull != NULL ) zmq_close(data->zmqPull);
   if ( data->zmqCtx  != NULL ) zmq_term(data->zmqCtx);

   data->zmqCtx  = NULL;
   data->zmqPush  = NULL;
   data->zmqPull = NULL;
 
   data->zmqCtx = zmq_ctx_new();
   data->zmqPull = zmq_socket(data->zmqCtx,ZMQ_PULL);
   data->zmqPush  = zmq_socket(data->zmqCtx,ZMQ_PUSH);   

   vhpi_printf("RogueSideBand: Listening on ports %i & %i\n",data->port, data->port+1);

   sprintf(buffer,"tcp://*:%i",data->port+1);
   if ( zmq_bind(data->zmqPull,buffer) ) {
      vhpi_assert("RogueSideBand: Failed to bind sideband port",vhpiFatal);
      return;
   }

   sprintf(buffer,"tcp://*:%i",data->port);
   if ( zmq_bind(data->zmqPush,buffer) ) {
      vhpi_assert("RogueSideBand: Failed to bind push port",vhpiFatal);
      return;
   }
   
}

// Send a message
void RogueSideBandSend ( RogueSideBandData *data, portDataT *portData ) {
   zmq_msg_t msg;
   uint8_t  ba[4];

   if ( (zmq_msg_init_size(&msg,4) < 0) ) {  
      vhpi_assert("RogueSideBand: Failed to init message",vhpiFatal);
      return;
   }

   ba[0] = data->txOpCodeEn;
   ba[1] = data->txOpCode;
   ba[2] = data->txRemDataChanged;
   ba[3] = data->txRemData;

   memcpy(zmq_msg_data(&msg), ba, 4);

   // Send data
   if ( zmq_msg_send(&msg,data->zmqPush,ZMQ_DONTWAIT) < 0 ) {
         vhpi_assert("RogueSideBand: Failed to send message",vhpiFatal);
   }
   if (data->txOpCodeEn) {
     vhpi_printf("%lu RogueSideBand: Sent Opcode: %x\n", portData->simTime, data->txOpCode);
   }
   if (data->txRemDataChanged) {
     vhpi_printf("%lu RogueSideBand: Sent remData: %x\n", portData->simTime, data->txRemData);
   }
}

// Receive side data if it is available
int RogueSideBandRecv ( RogueSideBandData *data, portDataT *portData ) {
   uint8_t * rd;
   uint32_t  rsize;
   zmq_msg_t rMsg;

   zmq_msg_init(&rMsg);
   if ( zmq_msg_recv(&rMsg,data->zmqPull,ZMQ_DONTWAIT) <= 0 ) {
      zmq_msg_close(&rMsg);
      return(0);
   }

   rd    = zmq_msg_data(&rMsg);
   rsize = zmq_msg_size(&rMsg);

   if ( rsize == 4 ) {

      if ( rd[0] == 0x01 ) {
         data->rxOpCode   = rd[1];
         data->rxOpCodeEn = 1;
         vhpi_printf("%lu RogueSideBand: Got opcode 0x%0.2x\n",portData->simTime,data->rxOpCode);
      }
      if ( rd[2] == 0x01 ) {
         data->rxRemData = rd[3];
         vhpi_printf("%lu RogueSideBand: Got data 0x%0.2x\n",portData->simTime,data->rxRemData);
      }

   }
   zmq_msg_close(&rMsg);
   return(rsize);
}

// Init function
void RogueSideBandInit(vhpiHandleT compInst) { 

   // Create new port data structure
   portDataT         *portData  = (portDataT *)         malloc(sizeof(portDataT));
   RogueSideBandData *data      = (RogueSideBandData *) malloc(sizeof(RogueSideBandData));

   // Get port count
   portData->portCount = PORT_COUNT;

   // Set port directions
   portData->portDir[s_clock]      = vhpiIn;
   portData->portDir[s_reset]      = vhpiIn;
   portData->portDir[s_port]       = vhpiIn;

   portData->portDir[s_txOpCode]     = vhpiIn;
   portData->portDir[s_txOpCodeEn]   = vhpiIn;
   portData->portDir[s_txRemData]    = vhpiIn;

   portData->portDir[s_rxOpCode]     = vhpiOut;
   portData->portDir[s_rxOpCodeEn]   = vhpiOut;
   portData->portDir[s_rxRemData]    = vhpiOut;

   // Set port widths
   portData->portWidth[s_clock]      = 1;
   portData->portWidth[s_reset]      = 1;
   portData->portWidth[s_port]       = 16;

   portData->portWidth[s_txOpCode]     = 8;
   portData->portWidth[s_txOpCodeEn]   = 1;
   portData->portWidth[s_txRemData]    = 8;

   portData->portWidth[s_rxOpCode]     = 8;
   portData->portWidth[s_rxOpCodeEn]   = 1;
   portData->portWidth[s_rxRemData]    = 8;

   // Create data structure to hold state
   portData->stateData = data;

   // State update function
   portData->stateUpdate = *RogueSideBandUpdate;

   // Init
   memset(data,0, sizeof(RogueSideBandData));

   // Call generic Init
   VhpiGenericInit(compInst,portData);
}


// User function to update state based upon a signal change
void RogueSideBandUpdate ( void *userPtr ) {

   portDataT *portData = (portDataT*) userPtr;
   RogueSideBandData *data = (RogueSideBandData*)(portData->stateData);
   uint8_t send = 0;

   // Detect clock edge
   if ( data->currClk != getInt(s_clock) ) {
      data->currClk = getInt(s_clock);

      // Rising edge
      if ( data->currClk ) {

         // Reset is asserted
         if ( getInt(s_reset) == 1 ) {
            data->rxRemData  = 0x00;
            data->rxOpCode   = 0x00;
            data->rxOpCodeEn = 0;
            data->txRemData  = 0x00;
            data->txRemDataChanged  = 0x00;            
            data->txOpCode   = 0x00;
            data->txOpCodeEn = 0;
            setInt(s_rxOpCodeEn,0);
            setInt(s_rxOpCode, 0);
            setInt(s_rxRemData, 0);
         }

         // Out of reset
         else {

            // Port not yet assigned
            if ( data->port == 0 ) {
               data->port = getInt(s_port);
               RogueSideBandRestart(data,portData);
            }

            // TX OpCode
            if (getInt(s_txOpCodeEn)) {
              data->txOpCode = getInt(s_txOpCode);
              data->txOpCodeEn = getInt(s_txOpCodeEn);
              send = 1;
            }

            //TX RemData
            if (getInt(s_txRemData) != data->txRemData) {
              data->txRemData = getInt(s_txRemData);
              data->txRemDataChanged = 1;
              send = 1;
            }

            if (send) {
              RogueSideBandSend(data, portData);
            }

            // Rx Data
            RogueSideBandRecv(data,portData);
            setInt(s_rxRemData,data->rxRemData);
            setInt(s_rxOpCode,data->rxOpCode);
            setInt(s_rxOpCodeEn,data->rxOpCodeEn);
            data->rxOpCodeEn = 0; // Only for one clock
         }
      }
   }
}

