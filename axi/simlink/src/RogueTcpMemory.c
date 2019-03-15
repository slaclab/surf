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
#include "RogueTcpMemory.h"
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
void RogueTcpMemoryRestart(RogueTcpMemoryData *data, portDataT *portData) {
   char buffer[100];

   if ( data->zmqPush  != NULL ) zmq_close(data->zmqPull);
   if ( data->zmqPull  != NULL ) zmq_close(data->zmqPush);
   if ( data->zmqCtx   != NULL ) zmq_term(data->zmqCtx);

   data->zmqCtx   = NULL;
   data->zmqPull  = NULL;
   data->zmqPush  = NULL;
 
   data->zmqCtx = zmq_ctx_new();
   data->zmqPull  = zmq_socket(data->zmqCtx,ZMQ_PULL);
   data->zmqPush  = zmq_socket(data->zmqCtx,ZMQ_PUSH);

   vhpi_printf("RogueTcpMemory: Listening on ports %i & %i\n",data->port,data->port+1);

   sprintf(buffer,"tcp://*:%i",data->port);
   if ( zmq_bind(data->zmqPull,buffer) ) {
      vhpi_assert("RogueTcpMemory: Failed to bind pull port",vhpiFatal);
      return;
   }

   sprintf(buffer,"tcp://*:%i",data->port+1);
   if ( zmq_bind(data->zmqPush,buffer) ) {
      vhpi_assert("RogueTcpMemory: Failed to bind push port",vhpiFatal);
      return;
   }
}


// Send a message
void RogueTcpMemorySend ( RogueTcpMemoryData *data, portDataT *portData ) {
   uint32_t  x;
   zmq_msg_t msg[6];

   if ( (zmq_msg_init_size(&(msg[0]),4) < 0) ||  // ID
        (zmq_msg_init_size(&(msg[1]),8) < 0) ||  // Addr   
        (zmq_msg_init_size(&(msg[2]),4) < 0) ||  // Size 
        (zmq_msg_init_size(&(msg[3]),4) < 0) ||  // type 
        (zmq_msg_init_size(&(msg[5]),4) < 0) ) { // result
      vhpi_assert("RogueTcpMemory: Failed to init message header",vhpiFatal);
      return;
   }

   if ( zmq_msg_init_size (&(msg[4]), data->size) < 0 ) {
      vhpi_assert("RogueTcpMemory: Failed to init message",vhpiFatal);
      return;
   }

   memcpy(zmq_msg_data(&(msg[0])), &(data->id),     4);
   memcpy(zmq_msg_data(&(msg[1])), &(data->addr),   8);
   memcpy(zmq_msg_data(&(msg[2])), &(data->size),   4);
   memcpy(zmq_msg_data(&(msg[3])), &(data->type),   4);
   memcpy(zmq_msg_data(&(msg[5])), &(data->result), 4);

   // Copy data
   memcpy(zmq_msg_data(&(msg[4])),data->data,data->size);
    
   // Send data
   for (x=0; x < 6; x++) {
      if ( zmq_sendmsg(data->zmqPush,&(msg[x]),(x==5)?0:ZMQ_SNDMORE) < 0 )
         vhpi_assert("RogueTcpMemory: Failed to send message",vhpiFatal);
   }
   data->state = 0;
   data->curr  = 0;

   vhpi_printf("%lu RogueTcpMemory: Send Tran: Id %i, Addr 0x%x, Size %i, Type %i, Resp 0x%x\n", portData->simTime,data->id,data->addr,data->size,data->type,data->result);

}

// Receive data if it is available
int RogueTcpMemoryRecv ( RogueTcpMemoryData *data, portDataT *portData ) {
   uint64_t  more;
   size_t    moreSize;
   uint32_t  x;
   uint32_t  msgCnt;
   zmq_msg_t msg[5];

   for (x=0; x < 5; x++) zmq_msg_init(&(msg[x]));
   msgCnt = 0;
   x = 0;

   // Get message
   do {

      // Get the message
      if ( zmq_recvmsg(data->zmqPull,&(msg[x]),ZMQ_DONTWAIT) > 0 ) {
         if ( x != 4 ) x++;
         msgCnt++;

         // Is there more data?
         more = 0;
         moreSize = 8;
         zmq_getsockopt(data->zmqPull, ZMQ_RCVMORE, &more, &moreSize);
      } else more = 0;
   } while ( more );

   // Proper message received
   if ( msgCnt == 4 || msgCnt == 5) {

      // Check sizes
      if ( (zmq_msg_size(&(msg[0])) != 4) || (zmq_msg_size(&(msg[1])) != 8) ||
           (zmq_msg_size(&(msg[2])) != 4) || (zmq_msg_size(&(msg[3])) != 4) ) {
         vhpi_assert("RogueTcpMemory: Bad message size",vhpiFatal);
         for (x=0; x < msgCnt; x++) zmq_msg_close(&(msg[x]));
         return 0;
      }

      // Get fields
      memcpy(&(data->id),   zmq_msg_data(&(msg[0])), 4);
      memcpy(&(data->addr), zmq_msg_data(&(msg[1])), 8);
      memcpy(&(data->size), zmq_msg_data(&(msg[2])), 4);
      memcpy(&(data->type), zmq_msg_data(&(msg[3])), 4);

      // Write data is expected
      if ( (data->type == T_WRITE) || (data->type == T_POST) ) {
         if ((msgCnt != 5) || (zmq_msg_size(&(msg[4])) != data->size) ) {
            vhpi_assert("RogueTcpMemory: Transaction write data error",vhpiFatal);
            for (x=0; x < msgCnt; x++) zmq_msg_close(&(msg[x]));
            return 0;
         }
      }

      // Data pointer
      memcpy(data->data, zmq_msg_data(&(msg[4])),data->size);
      data->state  = ST_START;
      data->curr   = 0;
      data->result = 0;

      vhpi_printf("%lu RogueTcpMemory: Got Tran: Id %i, Addr 0x%x, Size %i, Type %i\n", portData->simTime, data->id, data->addr,data->size,data->type);

      return(data->size);
   }
   return (0);
}

// Init function
void RogueTcpMemoryInit(vhpiHandleT compInst) { 

   // Create new port data structure
   portDataT             *portData  = (portDataT *)             malloc(sizeof(portDataT));
   RogueTcpMemoryData *data      = (RogueTcpMemoryData *) malloc(sizeof(RogueTcpMemoryData));

   // Get port count
   portData->portCount = PORT_COUNT;

   // Set port directions
   portData->portDir[s_clock]      = vhpiIn; 
   portData->portDir[s_reset]      = vhpiIn; 
   portData->portDir[s_port]       = vhpiIn; 

   portData->portDir[s_araddr]     = vhpiOut;
   portData->portDir[s_arprot]     = vhpiOut;
   portData->portDir[s_arvalid]    = vhpiOut;
   portData->portDir[s_rready]     = vhpiOut;

   portData->portDir[s_arready]    = vhpiIn;
   portData->portDir[s_rdata]      = vhpiIn;
   portData->portDir[s_rresp]      = vhpiIn;
   portData->portDir[s_rvalid]     = vhpiIn;

   portData->portDir[s_awaddr]     = vhpiOut;
   portData->portDir[s_awprot]     = vhpiOut;
   portData->portDir[s_awvalid]    = vhpiOut;
   portData->portDir[s_wdata]      = vhpiOut;
   portData->portDir[s_wstrb]      = vhpiOut;
   portData->portDir[s_wvalid]     = vhpiOut;
   portData->portDir[s_bready]     = vhpiOut;

   portData->portDir[s_awready]    = vhpiIn;
   portData->portDir[s_wready]     = vhpiIn;
   portData->portDir[s_bresp]      = vhpiIn;
   portData->portDir[s_bvalid]     = vhpiIn;

   // Set port widths
   portData->portWidth[s_clock]    = 1; 
   portData->portWidth[s_reset]    = 1; 
   portData->portWidth[s_port]     = 16; 

   portData->portWidth[s_araddr]   = 32;
   portData->portWidth[s_arprot]   = 3;
   portData->portWidth[s_arvalid]  = 1;
   portData->portWidth[s_rready]   = 1;

   portData->portWidth[s_arready]  = 1;
   portData->portWidth[s_rdata]    = 32;
   portData->portWidth[s_rresp]    = 2;
   portData->portWidth[s_rvalid]   = 1;

   portData->portWidth[s_awaddr]   = 32;
   portData->portWidth[s_awprot]   = 3;
   portData->portWidth[s_awvalid]  = 1;
   portData->portWidth[s_wdata]    = 32;
   portData->portWidth[s_wstrb]    = 4;
   portData->portWidth[s_wvalid]   = 1;
   portData->portWidth[s_bready]   = 1;

   portData->portWidth[s_awready]  = 1;
   portData->portWidth[s_wready]   = 1;
   portData->portWidth[s_bresp]    = 2;
   portData->portWidth[s_bvalid]   = 1;

   // Create data structure to hold state
   portData->stateData = data;

   // State update function
   portData->stateUpdate = *RogueTcpMemoryUpdate;

   // Init
   memset(data,0, sizeof(RogueTcpMemoryData));

   // Call generic Init
   VhpiGenericInit(compInst,portData);
}


// User function to update state based upon a signal change
void RogueTcpMemoryUpdate ( void *userPtr ) {
   uint32_t data32;

   portDataT *portData = (portDataT*) userPtr;
   RogueTcpMemoryData *data = (RogueTcpMemoryData*)(portData->stateData);

   // Detect clock edge
   if ( data->currClk != getInt(s_clock) ) {
      data->currClk = getInt(s_clock);

      // Rising edge
      if ( data->currClk ) {

         // Reset is asserted
         if ( getInt(s_reset) == 1 ) {
            data->state = ST_IDLE;
            setInt(s_arvalid,0);
            setInt(s_rready,1);
            setInt(s_awvalid,0);
            setInt(s_bready,1);
         } 

         // Data movement
         else {

            // Port not yet assigned
            if ( data->port == 0 ) {
               data->port = getInt(s_port);
               RogueTcpMemoryRestart(data,portData);
            }

            switch (data->state) {

               // Idle get new data
               case ST_IDLE:
                  RogueTcpMemoryRecv(data,portData);
                  break;

               // Start, present transaction
               case ST_START:

                  // Write
                  if ( data->type == T_WRITE || data->type == T_POST ) {
                     setInt(s_awaddr,(data->addr+data->curr));
                     setInt(s_awprot,0);
                     setInt(s_awvalid,1);
                     setInt(s_bready,1);

                     data32  = data->data[data->curr++]         & 0x000000FF;
                     data32 |= (data->data[data->curr++] <<  8) & 0x0000FF00;
                     data32 |= (data->data[data->curr++] << 16) & 0x00FF0000;
                     data32 |= (data->data[data->curr++] << 24) & 0xFF000000;

                     setInt(s_wdata,data32);
                     setInt(s_wstrb,0xF);
                     setInt(s_wvalid,1);
                     data->state = ST_WRESP;
                  }

                  // Read
                  else {
                     setInt(s_araddr,(data->addr+data->curr));
                     setInt(s_arprot,0);
                     setInt(s_arvalid,1);
                     setInt(s_rready,1);
                     data->state = ST_RADDR;
                  }
                  break;

               // Write response
               case ST_WRESP:

                  if ( getInt(s_awready) ) setInt(s_awvalid,0);
                  if ( getInt(s_wready)  ) setInt(s_wvalid,0);

                  if ( getInt(s_bvalid) ) {
                    //setInt(s_bready,0);
                     data->result = getInt(s_bresp);

                     if (data->curr == data->size) {
                        RogueTcpMemorySend(data,portData); // state goes to idle
                     }
                     else data->state = ST_PAUSE;
                  }
                  break;

               // Read address
               case ST_RADDR:
                  if ( getInt(s_arready) ) {
                     setInt(s_arvalid,0);
                     setInt(s_rready,1);
                     data->state = ST_RDATA;
                  }
                  break;

               // Read data
               case ST_RDATA:
                  if ( getInt(s_rvalid) ) {
                     data32 = getInt(s_rdata);
                     data->result = getInt(s_rresp);

                     data->data[data->curr++] = data32 & 0xFF;
                     data->data[data->curr++] = (data32 >>  8) & 0xFF;
                     data->data[data->curr++] = (data32 >> 16) & 0xFF;
                     data->data[data->curr++] = (data32 >> 24) & 0xFF;

                     //setInt(s_rready,0);

                     if (data->curr == data->size) {
                        RogueTcpMemorySend(data,portData); // state goes to idle
                     }
                     else data->state = ST_PAUSE;
                  }
                  break;

               // Wait for RVALID and BVALID to fall
               case ST_PAUSE:
                 if ( getInt(s_rvalid) == 0 && getInt(s_bvalid) == 0 ) {
                   data->state = ST_START;
                   break;
                 }
            }
         }
      }
   }
}

