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
#if 0
   char buffer[100];

   if ( data->zmqPull != NULL ) zmq_close(data->zmqPull);
   if ( data->zmqCtx  != NULL ) zmq_term(data->zmqCtx);

   data->zmqCtx  = NULL;
   data->zmqPull = NULL;
 
   data->zmqCtx = zmq_ctx_new();
   data->zmqPull = zmq_socket(data->zmqCtx,ZMQ_REP);

   vhpi_printf("RogueSideBand: Listening on port %i\n",data->port);

   sprintf(buffer,"tcp://*:%i",data->port);
   if ( zmq_bind(data->zmqPull,buffer) ) {
      vhpi_assert("RogueSideBand: Failed to bind sideband port",vhpiFatal);
      return;
   }
#endif
}

// Receive side data if it is available
int RogueSideBandRecv ( RogueSideBandData *data, portDataT *portData ) {
   uint8_t * rd;
   uint32_t  rsize;
   zmq_msg_t rMsg;
   zmq_msg_t tMsg;

   zmq_msg_init(&rMsg);
   if ( zmq_msg_recv(&rMsg,data->zmqPull,ZMQ_DONTWAIT) <= 0 ) {
      zmq_msg_close(&rMsg);
      return(0);
   }

   rd    = zmq_msg_data(&rMsg);
   rsize = zmq_msg_size(&rMsg);

   if ( rsize == 2 ) {

      if ( rd[0] == 0xAA ) {
         data->ocData   = rd[1];
         data->ocDataEn = 1;
         vhpi_printf("%lu RogueSideBand: Got opcode 0x%0.2x\n",portData->simTime,data->ocData);
      }
      else if ( rd[0] == 0xBB ) {
         data->remData = rd[1];
         vhpi_printf("%lu RogueSideBand: Got data 0x%0.2x\n",portData->simTime,data->remData);
      }

      // Ack
      zmq_msg_init_size(&tMsg,1);
      ((uint8_t *)zmq_msg_data(&tMsg))[0] = 0xFF;
      zmq_msg_send(&tMsg,data->zmqPull,0);
      zmq_msg_close(&tMsg);
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

   portData->portDir[s_opCode]     = vhpiOut;
   portData->portDir[s_opCodeEn]   = vhpiOut;
   portData->portDir[s_remData]    = vhpiOut;

   // Set port widths
   portData->portWidth[s_clock]      = 1;
   portData->portWidth[s_reset]      = 1;
   portData->portWidth[s_port]       = 16;

   portData->portWidth[s_opCode]     = 8;
   portData->portWidth[s_opCodeEn]   = 1;
   portData->portWidth[s_remData]    = 8;

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

   // Detect clock edge
   if ( data->currClk != getInt(s_clock) ) {
      data->currClk = getInt(s_clock);

      // Rising edge
      if ( data->currClk ) {

         // Reset is asserted
         if ( getInt(s_reset) == 1 ) {
            data->remData  = 0x00;
            data->ocData   = 0x00;
            data->ocDataEn = 0;
            setInt(s_opCodeEn,0);
         }

         // Out of reset
         else {

            // Port not yet assigned
            if ( data->port == 0 ) {
               data->port = getInt(s_port);
               RogueSideBandRestart(data,portData);
            }

            // Sideband update
            RogueSideBandRecv(data,portData);
            setInt(s_remData,data->remData);
            setInt(s_opCode,data->ocData);
            setInt(s_opCodeEn,data->ocDataEn);
            data->ocDataEn = 0; // Only for one clock
         }
      }
   }
}

