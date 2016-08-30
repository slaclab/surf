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
#include <vhpi_user.h>
#include <stdlib.h>
#include <time.h>
#include "AxiSimSlave.h"
#include "AxiSharedMem.h"
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/mman.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdio.h>

// Init function
void AxiSimSlaveInit(vhpiHandleT compInst) { 

   // Create new port data structure
   portDataT       *portData  = (portDataT *)       malloc(sizeof(portDataT));
   AxiSimSlaveData *asPtr     = (AxiSimSlaveData *) malloc(sizeof(AxiSimSlaveData));

   // Get port count
   portData->portCount = 40;

   // Set port directions
   portData->portDir[s_axiClk]  = vhpiIn;
   portData->portDir[s_slaveId] = vhpiIn;
   portData->portDir[s_arvalid] = vhpiIn;
   portData->portDir[s_arready] = vhpiOut;
   portData->portDir[s_araddr]  = vhpiIn;
   portData->portDir[s_arid]    = vhpiIn;
   portData->portDir[s_arlen]   = vhpiIn;
   portData->portDir[s_arsize]  = vhpiIn;
   portData->portDir[s_arburst] = vhpiIn;
   portData->portDir[s_arlock]  = vhpiIn;
   portData->portDir[s_arprot]  = vhpiIn;
   portData->portDir[s_arcache] = vhpiIn;
   portData->portDir[s_rready]  = vhpiIn;
   portData->portDir[s_rdataH]  = vhpiOut;
   portData->portDir[s_rdataL]  = vhpiOut;
   portData->portDir[s_rlast]   = vhpiOut;
   portData->portDir[s_rvalid]  = vhpiOut;
   portData->portDir[s_rid]     = vhpiOut;
   portData->portDir[s_rresp]   = vhpiOut;
   portData->portDir[s_awvalid] = vhpiIn;
   portData->portDir[s_awready] = vhpiOut;
   portData->portDir[s_awaddr]  = vhpiIn;
   portData->portDir[s_awid]    = vhpiIn;
   portData->portDir[s_awlen]   = vhpiIn;
   portData->portDir[s_awsize]  = vhpiIn;
   portData->portDir[s_awburst] = vhpiIn;
   portData->portDir[s_awlock]  = vhpiIn;
   portData->portDir[s_awcache] = vhpiIn;
   portData->portDir[s_awprot]  = vhpiIn;
   portData->portDir[s_wready]  = vhpiOut;
   portData->portDir[s_wdataH]  = vhpiIn;
   portData->portDir[s_wdataL]  = vhpiIn;
   portData->portDir[s_wlast]   = vhpiIn;
   portData->portDir[s_wvalid]  = vhpiIn;
   portData->portDir[s_wid]     = vhpiIn;
   portData->portDir[s_wstrb]   = vhpiIn;
   portData->portDir[s_bready]  = vhpiIn;
   portData->portDir[s_bresp]   = vhpiOut;
   portData->portDir[s_bvalid]  = vhpiOut;
   portData->portDir[s_bid]     = vhpiOut;

   // Set port widths
   portData->portWidth[s_axiClk]  = 1;
   portData->portWidth[s_slaveId] = 8;
   portData->portWidth[s_arvalid] = 1;
   portData->portWidth[s_arready] = 1;
   portData->portWidth[s_araddr]  = 32;
   portData->portWidth[s_arid]    = 12;
   portData->portWidth[s_arlen]   = 4;
   portData->portWidth[s_arsize]  = 3;
   portData->portWidth[s_arburst] = 2;
   portData->portWidth[s_arlock]  = 2;
   portData->portWidth[s_arprot]  = 3;
   portData->portWidth[s_arcache] = 4;
   portData->portWidth[s_rready]  = 1;
   portData->portWidth[s_rdataH]  = 32;
   portData->portWidth[s_rdataL]  = 32;
   portData->portWidth[s_rlast]   = 1;
   portData->portWidth[s_rvalid]  = 1;
   portData->portWidth[s_rid]     = 12;
   portData->portWidth[s_rresp]   = 2;
   portData->portWidth[s_awvalid] = 1;
   portData->portWidth[s_awready] = 1;
   portData->portWidth[s_awaddr]  = 32;
   portData->portWidth[s_awid]    = 12;
   portData->portWidth[s_awlen]   = 4;
   portData->portWidth[s_awsize]  = 3;
   portData->portWidth[s_awburst] = 2;
   portData->portWidth[s_awlock]  = 2;
   portData->portWidth[s_awcache] = 4;
   portData->portWidth[s_awprot]  = 3;
   portData->portWidth[s_wready]  = 1;
   portData->portWidth[s_wdataH]  = 32;
   portData->portWidth[s_wdataL]  = 32;
   portData->portWidth[s_wlast]   = 1;
   portData->portWidth[s_wvalid]  = 1;
   portData->portWidth[s_wid]     = 12;
   portData->portWidth[s_wstrb]   = 8;
   portData->portWidth[s_bready]  = 1;
   portData->portWidth[s_bresp]   = 2;
   portData->portWidth[s_bvalid]  = 1;
   portData->portWidth[s_bid]     = 12;

   // Create data structure to hold state
   portData->stateData = asPtr;

   // State update function
   portData->stateUpdate = *AxiSimSlaveUpdate;

   // Init data structure
   asPtr->currClk       = 0;
   asPtr->smem          = NULL;
   asPtr->writeAddrBusy = 0;
   asPtr->writeDataBusy = 0;
   asPtr->writeCompBusy = 0;
   asPtr->readAddrBusy  = 0;
   asPtr->readDataBusy  = 0;

   // Call generic Init
   VhpiGenericInit(compInst,portData);

}


// User function to update state based upon a signal change
void AxiSimSlaveUpdate ( void *userPtr ) {
   AxiWriteAddr writeAddr;
   AxiWriteData writeData;
   AxiWriteComp writeComp;
   AxiReadAddr  readAddr;
   AxiReadData  readData;

   portDataT       *portData = (portDataT*) userPtr;
   AxiSimSlaveData *asPtr    = (AxiSimSlaveData*)(portData->stateData);

   // Not yet open
   if ( asPtr->smem == NULL ) {

      // Get ID
      uint id = getInt(s_slaveId);
      asPtr->smem = sim_open(SHM_TYPE,id);

      if ( asPtr->smem != NULL ) vhpi_printf("AxiSimSlave: Opened shared memory: %s\n",asPtr->smem->_path);
      else vhpi_printf("AxiSimSlave: Failed to open shared memory file. Id=%i\n",id);
   }

   // Detect clock edge
   if ( asPtr->currClk != getInt(s_axiClk) ) {
      asPtr->currClk = getInt(s_axiClk);

      // Rising edge
      if ( asPtr->currClk ) {
         incrClkCnt(asPtr->smem);

         //---------------------------------
         // Write Address
         //---------------------------------

         // Valid is asserted
         if ( (!asPtr->writeAddrBusy) && getInt(s_awvalid) == 1 ) {
            writeAddr.awaddr  = getInt(s_awaddr);
            writeAddr.awid    = getInt(s_awid);
            writeAddr.awlen   = getInt(s_awlen);
            writeAddr.awsize  = getInt(s_awsize);
            writeAddr.awburst = getInt(s_awburst);
            writeAddr.awlock  = getInt(s_awlock);
            writeAddr.awcache = getInt(s_awcache);
            writeAddr.awprot  = getInt(s_awprot);
            setWriteAddr(asPtr->smem,&writeAddr);
            asPtr->writeAddrBusy = 1;
         }

         //---------------------------------
         // Write Data
         //---------------------------------

         // Valid is asserted
         if ( (!asPtr->writeDataBusy) && getInt(s_wvalid) == 1 ) {
            writeData.wdataH = getInt(s_wdataH);
            writeData.wdataL = getInt(s_wdataL);
            writeData.wlast  = getInt(s_wlast);
            writeData.wid    = getInt(s_wid);
            writeData.wstrb  = getInt(s_wstrb);
            setWriteData(asPtr->smem,&writeData);
            asPtr->writeDataBusy = 1;
         }

         //---------------------------------
         // Write Completion
         //---------------------------------

         // Wait for ready
         if ( asPtr->writeCompBusy ) {

            // ready is asserted
            if ( getInt(s_bready) == 1 ) {
               asPtr->writeCompBusy = 0;
               setInt(s_bvalid,0);
            }
         }

         // Ready for next transaction
         if ( asPtr->writeCompBusy == 0 ) {

            // Software has posted a transaction
            if ( getWriteComp(asPtr->smem,&writeComp) ) {
               setInt(s_bvalid,1);
               setInt(s_bresp,writeComp.bresp);
               setInt(s_bid,writeComp.bid);
               asPtr->writeCompBusy = 1;
            }
         }

         //---------------------------------
         // Read Address
         //---------------------------------

         // Valid is asserted
         if ( (!asPtr->readAddrBusy) && getInt(s_arvalid) == 1 ) {
            readAddr.araddr  = getInt(s_araddr);
            readAddr.arid    = getInt(s_arid);
            readAddr.arlen   = getInt(s_arlen);
            readAddr.arsize  = getInt(s_arsize);
            readAddr.arburst = getInt(s_arburst);
            readAddr.arlock  = getInt(s_arlock);
            readAddr.arcache = getInt(s_arcache);
            readAddr.arprot  = getInt(s_arprot);
            setReadAddr(asPtr->smem,&readAddr);
            asPtr->readAddrBusy = 1;
         }

         //---------------------------------
         // Read Data   
         //---------------------------------

         // Wait for ready
         if ( asPtr->readDataBusy ) {

            // ready is asserted
            if ( getInt(s_rready) == 1 ) {
               asPtr->readDataBusy = 0;
               setInt(s_rvalid,0);
            }
         }

         // Ready for next transaction
         if ( asPtr->readDataBusy == 0 ) {

            // Software has posted a transaction
            if ( getReadData(asPtr->smem,&readData) ) {
               setInt(s_rvalid,1);
               setInt(s_rdataH,readData.rdataH);
               setInt(s_rdataL,readData.rdataL);
               setInt(s_rlast,readData.rlast);
               setInt(s_rid,readData.rid);
               setInt(s_rresp,readData.rresp);
               asPtr->readDataBusy = 1;
            }
         }

         //---------------------------------
         // Handshaking
         //---------------------------------
         usleep(1000);

         if ( readyWriteAddr(asPtr->smem) ) {
            setInt(s_awready,1);
            asPtr->writeAddrBusy = 0;
         }
         else setInt(s_awready,0);

         if ( readyWriteData(asPtr->smem) ) {
            setInt(s_wready,1);
            asPtr->writeDataBusy = 0;
         } else setInt(s_wready,0);

         if ( readyReadAddr(asPtr->smem) ) {
            setInt(s_arready,1);
            asPtr->readAddrBusy = 0;
         } else setInt(s_arready,0);
      }
   }
}

