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
#include "RogueTcpStream.h"
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
#include <errno.h>

// Start/resetart zeromq server
void RogueTcpStreamRestart(RogueTcpStreamData *data, portDataT *portData) {
   char buffer[100];

   if ( data->zmqPush != NULL ) zmq_close(data->zmqPush );
   if ( data->zmqPull != NULL ) zmq_close(data->zmqPull );
   if ( data->zmqCtx  != NULL ) zmq_term(data->zmqCtx);

   data->zmqCtx   = NULL;
   data->zmqPush  = NULL;
   data->zmqPull  = NULL;
 
   data->zmqCtx = zmq_ctx_new();
   data->zmqPull  = zmq_socket(data->zmqCtx,ZMQ_PULL);
   data->zmqPush  = zmq_socket(data->zmqCtx,ZMQ_PUSH);

   vhpi_printf("RogueTcpStream: Listening on ports %i & %i\n",data->port,data->port+1);

   sprintf(buffer,"tcp://*:%i",data->port);
   if ( zmq_bind(data->zmqPull,buffer) ) {
      vhpi_assert("RogueTcpStream: Failed to bind pull port",vhpiFatal);
      return;
   }

   sprintf(buffer,"tcp://*:%i",data->port+1);
   if ( zmq_bind(data->zmqPush,buffer) ) {
      vhpi_assert("RogueTcpStream: Failed to bind push port",vhpiFatal);
      return;
   }
}


// Send a message
void RogueTcpStreamSend ( RogueTcpStreamData *data, portDataT *portData ) {
   zmq_msg_t msg[4];
   uint16_t  flags;
   uint8_t   chan;
   uint8_t   err;
   uint32_t  x;
   int error;

   if ( (zmq_msg_init_size(&(msg[0]),2) < 0) ||  // Flags
        (zmq_msg_init_size(&(msg[1]),1) < 0) ||  // Channel
        (zmq_msg_init_size(&(msg[2]),1) < 0) ) { // Error
      vhpi_assert("RogueTcpStream: Failed to init message header",vhpiFatal);
      return;
   }

   if ( zmq_msg_init_size (&(msg[3]), data->ibSize) < 0 ) {
      vhpi_assert("RogueTcpStream: Failed to init message",vhpiFatal);
      return;
   }

   if ( data->ssi ) {
      flags  = (data->ibFuser & 0xFF);
      flags |= ((data->ibLuser << 8) & 0xFF00);
      err    = data->ibLuser & 0x1;
   } else {
      flags = 0;
      err   = 0;
   }
   chan = 0;

   memcpy(zmq_msg_data(&(msg[0])), &flags, 2);
   memcpy(zmq_msg_data(&(msg[1])), &chan,  1);
   memcpy(zmq_msg_data(&(msg[2])), &err,   1);

   // Copy data
   memcpy(zmq_msg_data(&(msg[3])),data->ibData,data->ibSize);
    
   // Send data
   for (x=0; x < 4; x++) {
     if ( zmq_msg_send(&(msg[x]), data->zmqPush, (x==3)?0:ZMQ_SNDMORE) < 0 ) {
       error = errno;
       vhpi_printf("Failed to send message on port %i - x: %i - err: %i\n", data->port+1, x, error);
       vhpi_printf("Error: %s\n", strerror(error));
       vhpi_assert("RogueTcpStream: Failed to send message",vhpiFatal);
     }
   }
   vhpi_printf("%lu RogueTcpStream: Send data: Size: %i, flags: %x, chan: %x, err: %x, port: %i\n", portData->simTime, data->ibSize, flags, chan, err, data->port+1);
   data->ibSize = 0;
}


// Receive data if it is available
int RogueTcpStreamRecv ( RogueTcpStreamData *data, portDataT *portData ) {
   int64_t   more;
   size_t    moreSize;
   uint32_t  size;
   zmq_msg_t msg[4];
   uint32_t  msgCnt;
   uint16_t  flags;
   uint8_t   chan;
   uint8_t   err;
   uint32_t  x;

   for (x=0; x < 4; x++) zmq_msg_init(&(msg[x]));
   msgCnt = 0;
   x = 0;

   // Get message
   do {

      // Get the message
      if ( zmq_recvmsg(data->zmqPull,&(msg[x]),ZMQ_DONTWAIT) > 0 ) {
         if ( x != 3 ) x++;
         msgCnt++;

         // Is there more data?
         more = 0;
         moreSize = 8;
         zmq_getsockopt(data->zmqPull, ZMQ_RCVMORE, &more, &moreSize);
      } else more = 0;
   } while ( more );

   // Proper message received
   if ( msgCnt == 4 ) {

      // Check sizes
      if ( (zmq_msg_size(&(msg[0])) != 2) || (zmq_msg_size(&(msg[1])) != 1) ||
           (zmq_msg_size(&(msg[2])) != 1) ) {
         vhpi_assert("RogueTcpStream: Bad message sizes",vhpiFatal);
         for (x=0; x < msgCnt; x++) zmq_msg_close(&(msg[x]));
         return 0;
      }

      // Get fields
      memcpy(&flags, zmq_msg_data(&(msg[0])), 2);
      memcpy(&chan,  zmq_msg_data(&(msg[1])), 1);
      memcpy(&err,   zmq_msg_data(&(msg[2])), 1);

      // Get message info
      size = zmq_msg_size(&(msg[3]));

      // Set data
      memcpy(data->obData,zmq_msg_data(&(msg[3])), size);
      data->obSize  = size;
      data->obFuser = flags & 0xFF;
      data->obLuser = (flags >> 8) & 0xFF;

      if ( data->ssi ) {
         data->obFuser |= 0x02;
         if ( err ) data->obLuser |= 0x01;
      }

      vhpi_printf("%lu RogueTcpStream: Recv data: Size: %i, flags: %x, chan: %i, err: %i, port: %i\n", portData->simTime, data->obSize, flags, chan, err, data->port);

   } else size = 0;

   for (x=0; x < 4; x++) zmq_msg_close(&(msg[x]));

   return(size);
}


// Init function
void RogueTcpStreamInit(vhpiHandleT compInst) { 

   // Create new port data structure
   portDataT             *portData  = (portDataT *)             malloc(sizeof(portDataT));
   RogueTcpStreamData *data      = (RogueTcpStreamData *) malloc(sizeof(RogueTcpStreamData));

   // Get port count
   portData->portCount = PORT_COUNT;

   // Set port directions
   portData->portDir[s_clock]      = vhpiIn; 
   portData->portDir[s_reset]      = vhpiIn; 
   portData->portDir[s_port]       = vhpiIn; 
   portData->portDir[s_ssi]        = vhpiIn; 

   portData->portDir[s_obValid]    = vhpiOut;
   portData->portDir[s_obReady]    = vhpiIn;
   portData->portDir[s_obDataLow]  = vhpiOut;
   portData->portDir[s_obDataHigh] = vhpiOut;
   portData->portDir[s_obUserLow]  = vhpiOut;
   portData->portDir[s_obUserHigh] = vhpiOut;
   portData->portDir[s_obKeep]     = vhpiOut;
   portData->portDir[s_obLast]     = vhpiOut;

   portData->portDir[s_ibValid]    = vhpiIn; 
   portData->portDir[s_ibReady]    = vhpiOut;
   portData->portDir[s_ibDataLow]  = vhpiIn;
   portData->portDir[s_ibDataHigh] = vhpiIn;
   portData->portDir[s_ibUserLow]  = vhpiIn;
   portData->portDir[s_ibUserHigh] = vhpiIn;
   portData->portDir[s_ibKeep]     = vhpiIn;
   portData->portDir[s_ibLast]     = vhpiIn;

   // Set port widths
   portData->portWidth[s_clock]      = 1;
   portData->portWidth[s_reset]      = 1;
   portData->portWidth[s_port]       = 16;
   portData->portWidth[s_ssi]        = 1;

   portData->portWidth[s_obValid]    = 1;
   portData->portWidth[s_obReady]    = 1;
   portData->portWidth[s_obDataLow]  = 32;
   portData->portWidth[s_obDataHigh] = 32;
   portData->portWidth[s_obUserLow]  = 32;
   portData->portWidth[s_obUserHigh] = 32;
   portData->portWidth[s_obKeep]     = 8;
   portData->portWidth[s_obLast]     = 1;

   portData->portWidth[s_ibValid]    = 1;
   portData->portWidth[s_ibReady]    = 1;
   portData->portWidth[s_ibDataLow]  = 32;
   portData->portWidth[s_ibDataHigh] = 32;
   portData->portWidth[s_ibUserLow]  = 32;
   portData->portWidth[s_ibUserHigh] = 32;
   portData->portWidth[s_ibKeep]     = 8;
   portData->portWidth[s_ibLast]     = 1;

   // Create data structure to hold state
   portData->stateData = data;

   // State update function
   portData->stateUpdate = *RogueTcpStreamUpdate;

   // Init
   memset(data,0, sizeof(RogueTcpStreamData));
   time(&(data->ltime));

   // Call generic Init
   VhpiGenericInit(compInst,portData);
}


// User function to update state based upon a signal change
void RogueTcpStreamUpdate ( void *userPtr ) {
   uint32_t x;
   uint32_t keep;
   uint32_t dLow;
   uint32_t dHigh;
   uint32_t uLow;
   uint32_t uHigh;

   portDataT *portData = (portDataT*) userPtr;
   RogueTcpStreamData *data = (RogueTcpStreamData*)(portData->stateData);

   // Detect clock edge
   if ( data->currClk != getInt(s_clock) ) {
      data->currClk = getInt(s_clock);

      // Rising edge
      if ( data->currClk ) {

         // Reset is asserted
         if ( getInt(s_reset) == 1 ) {
            data->obCount = 0;
            data->obSize  = 0;
            data->ibSize  = 0;
            data->obValid = 0;
            setInt(s_obValid,0);
            setInt(s_ibReady,1);
            setInt(s_obDataLow,0);
            setInt(s_obDataHigh,0);
            setInt(s_obUserLow,0);
            setInt(s_obUserHigh,0);
            setInt(s_obKeep,0);
            setInt(s_obLast,0);
         } 

         // Data movement
         else {

            // Port not yet assigned
            if ( data->port == 0 ) {
               data->port = getInt(s_port);
               data->ssi  = getInt(s_ssi);
               RogueTcpStreamRestart(data,portData);
            }

            // Inbound
            if (getInt(s_ibValid)) {
               keep  = getInt(s_ibKeep);
               dLow  = getInt(s_ibDataLow);
               dHigh = getInt(s_ibDataHigh);
               uLow  = getInt(s_ibUserLow);
               uHigh = getInt(s_ibUserHigh);

               // First
               if ( data->ibSize == 0 ) data->ibFuser = uLow & 0xFF;

               // Get data
               for (x=0; x< 8; x++) {
                  if ( x < 4 ) {
                     data->ibData[data->ibSize] = (dLow >> (x*8)) & 0xFF;
                     if ( (keep >> x) && 1 ) data->ibLuser = (uLow >> (x*8)) & 0xFF;
                  }
                  else {
                     data->ibData[data->ibSize] = (dHigh >> ((x-4)*8)) & 0xFF;
                     if ( (keep >> x) && 1 ) data->ibLuser = (uHigh >> ((x-4)*8)) & 0xFF;
                  }
                  if ( (keep >> x) && 1 ) data->ibSize++;
               }

               // Last
               if ( getInt(s_ibLast) ) RogueTcpStreamSend(data,portData);
            }

            // Not in frame
            if ( data->obSize == 0 ) RogueTcpStreamRecv(data,portData);

            // Data accepted
            if ( getInt(s_obReady) ) {
               data->obValid = 0;
               setInt(s_obLast,0);
            }

            // Valid not asserted and data is ready
            if ( data->obValid == 0 && data->obSize > 0 ) {

               // First user
               if ( data->obCount == 0 ) setInt(s_obUserLow,data->obFuser);
               else setInt(s_obUserLow,0);
               setInt(s_obUserHigh,0);
              
               // Get data
               dHigh = 0;
               dLow  = 0;
               keep  = 0;

               // Set data
               for (x=0; x< 8; x++) {
                  if ( x < 4 ) {
                     dLow |= (data->obData[data->obCount] << (x*8));
                     if ( (data->obCount+1) == data->obSize ) {
                       if (data->obCount < 4) {
                         setInt(s_obUserLow,(data->obLuser << (x*8))|(data->obFuser));
                       }
                       else {
                         setInt(s_obUserLow,(data->obLuser << (x*8)));
                       }
                     }
                  }
                  else {
                     dHigh |= (data->obData[data->obCount] << ((x-4)*8));
                     if ( (data->obCount+1) == data->obSize ) 
                         setInt(s_obUserHigh,(data->obLuser << ((x-4)*8)));
                  }

                  data->obCount++;
                  if ( data->obCount <= data->obSize ) keep |= (1 << x);
               }
               setInt(s_obDataLow,dLow);
               setInt(s_obDataHigh,dHigh);
               setInt(s_obKeep,keep);
               data->obValid = 1;

               // Done
               if ( data->obCount >= data->obSize ) {
                  setInt(s_obLast,1);
                  data->obSize  = 0;
                  data->obCount = 0;
               }
            }

            // Output valid
            setInt(s_obValid,data->obValid);
         }
      }
   }
}

