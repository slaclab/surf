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
#include "RogueStreamSim.h"
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
void zmqRestart(RogueStreamSimData *data) {
   char buffer[100];
   uint32_t ibPort;
   uint32_t obPort;

   ibPort = IB_PORT_BASE + data->dest;
   obPort = OB_PORT_BASE + data->dest;

   if ( data->zmqIbSrv != NULL ) zmq_close(data->zmqIbSrv);
   if ( data->zmqObSrv != NULL ) zmq_close(data->zmqObSrv);
   if ( data->zmqCtx   != NULL ) zmq_term(data->zmqCtx);

   data->zmqIbSrv = NULL;
   data->zmqObSrv = NULL;
   data->zmqCtx   = NULL;
 
   data->zmqCtx = zmq_ctx_new();
   data->zmqIbSrv = zmq_socket(data->zmqCtx,ZMQ_REQ);
   data->zmqObSrv = zmq_socket(data->zmqCtx,ZMQ_REP);

   sprintf(buffer,"tcp://*:%i",ibPort);
   zmq_bind(data->zmqIbSrv,buffer);

   sprintf(buffer,"tcp://*:%i",obPort);
   zmq_bind(data->zmqObSrv,buffer);

   vhpi_printf("zmqRestart: Destination %i listening at inbound port %i and outbound port %i\n",
         data->dest,ibPort,obPort);
}


// Send a message
void zmqSend ( RogueStreamSimData *data ) {
   zmq_msg_t msgA;
   zmq_msg_t msgB;
   zmq_msg_t msgC;
   zmq_msg_t msgR;
   int32_t   retA;
   int32_t   retB;
   int32_t   retC;

   zmq_msg_init_size(&msgA,1);
   zmq_msg_init_size(&msgB,1);
   zmq_msg_init_size(&msgC,data->ibSize);

   ((uint8_t *)zmq_msg_data(&msgA))[0] = data->ibFuser;
   ((uint8_t *)zmq_msg_data(&msgB))[0] = data->ibLuser;
   memcpy(zmq_msg_data(&msgC),data->ibData,data->ibSize);

   retA = zmq_msg_send(&msgA,data->zmqIbSrv,ZMQ_SNDMORE);
   retB = zmq_msg_send(&msgB,data->zmqIbSrv,ZMQ_SNDMORE);
   retC = zmq_msg_send(&msgC,data->zmqIbSrv,0);

   zmq_msg_close(&msgA);
   zmq_msg_close(&msgB);
   zmq_msg_close(&msgC);

   data->ibSize  = 0;

   if ( retA > 0 && retB >> 0 && retC >> 0 ) data->txCount++;
   else data->errCount++;

   zmq_msg_init(&msgR);
   zmq_msg_recv(&msgR,data->zmqIbSrv,0);
   zmq_msg_close(&msgR);
}

// Receive data if it is available
int zmqRecv ( RogueStreamSimData *data ) {
   int64_t   more;
   size_t    more_size = sizeof(more);
   uint32_t  cnt;
   uint32_t  err;
   uint8_t * rd;
   uint32_t  rsize;
   zmq_msg_t msg;

   rsize = 0;
   cnt   = 0;
   err   = 0;

   data->obSize  = 0;
   data->obCount = 0;

   do {

      zmq_msg_init(&msg);
      if ( zmq_msg_recv(&msg,data->zmqObSrv,ZMQ_DONTWAIT) < 0 ) {
         zmq_msg_close(&msg);
         return(0);
      }

      rd    = zmq_msg_data(&msg);
      rsize = zmq_msg_size(&msg);

      switch (cnt) {
         case 0:
            if ( rsize != 1 ) err++;
            else data->obFuser = rd[0];
            break;
         case 1:
            if ( rsize != 1 ) err++;
            else data->obLuser = rd[0];
            break;
         case 2:
            if ( rsize > MAX_FRAME ) err++;
            else memcpy(data->obData,rd,rsize);
            break;
         default:
            err++;
            break;
      }

      zmq_getsockopt(data->zmqObSrv,ZMQ_RCVMORE,&more,&more_size);
      zmq_msg_close(&msg);
      cnt++;

   } while (more);

   if ( cnt != 3 || err != 0 ) {
      //zmqRestart(data);
      return(-1);
   }
   else {
      data->obSize  = rsize;
      data->obCount = 0;
      data->rxCount++;
      return(rsize);
   }
}

// Ack received data
void zmqAck ( RogueStreamSimData *data ) {
   zmq_msg_t msg;
   int32_t   ret;

   zmq_msg_init_size(&msg,1);
   ((uint8_t *)zmq_msg_data(&msg))[0] = 0xFF;
   ret = zmq_msg_send(&msg,data->zmqObSrv,0);
   zmq_msg_close(&msg);
   if ( ret < 0 ) data->errCount++;
}

// Init function
void RogueStreamSimInit(vhpiHandleT compInst) { 

   // Create new port data structure
   portDataT          *portData  = (portDataT *)          malloc(sizeof(portDataT));
   RogueStreamSimData *data      = (RogueStreamSimData *) malloc(sizeof(RogueStreamSimData));

   // Get port count
   portData->portCount = 19;

   // Set port directions
   portData->portDir[s_clock]      = vhpiIn; 
   portData->portDir[s_reset]      = vhpiIn; 
   portData->portDir[s_dest]       = vhpiIn; 

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
   portData->portWidth[s_dest]       = 8;

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
   portData->stateUpdate = *RogueStreamSimUpdate;

   // Init data structure
   data->currClk   = 0;
   data->obSize    = 0;
   data->ibSize    = 0;
   data->obCount   = 0;
   data->zmqCtx    = NULL;
   data->zmqIbSrv  = NULL;
   data->zmqObSrv  = NULL;
   data->dest      = 256;

   time(&(data->ltime));
   data->rxCount = 0;
   data->txCount = 0;
   data->errCount = 0;
   data->ackCount = 0;

   // Call generic Init
   VhpiGenericInit(compInst,portData);
}


// User function to update state based upon a signal change
void RogueStreamSimUpdate ( void *userPtr ) {
   uint32_t x;
   uint32_t keep;
   uint32_t dLow;
   uint32_t dHigh;
   uint32_t uLow;
   uint32_t uHigh;
   time_t   ctime;

   portDataT *portData = (portDataT*) userPtr;
   RogueStreamSimData *data = (RogueStreamSimData*)(portData->stateData);

   time(&ctime);
   if ( ctime != data->ltime ) {
      data->ltime = ctime;
      vhpi_printf("update: RxCount = %i, TxCount = %i, errCount = %i\n",
            data->rxCount,data->txCount,data->errCount);
   }

   // Port not yet assigned
   if ( data->dest == 256 ) {
      data->dest = getInt(s_dest);
      zmqRestart(data);
   }

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
               if ( getInt(s_ibLast) ) zmqSend(data);
            }

            // Not in frame
            if ( data->obSize == 0 ) zmqRecv(data);

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
                     if ( (data->obCount+1) == data->obSize ) 
                         setInt(s_obUserLow,(data->obLuser << (x*8)));
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
                  zmqAck(data);
               }
            }

            // Output valid
            setInt(s_obValid,data->obValid);
         }
      }
   }
}

