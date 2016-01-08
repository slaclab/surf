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
#include "AxiSimMaster.h"
#include "AxiSharedMem.h"
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/mman.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdio.h>

// Init function
void AxiSimMasterInit(vhpiHandleT compInst) { 

   // Create new port data structure
   portDataT        *portData  = (portDataT *)        malloc(sizeof(portDataT));
   AxiSimMasterData *asPtr     = (AxiSimMasterData *) malloc(sizeof(AxiSimMasterData));

   // Get port count
   portData->portCount = 40;

   // Set port directions
   portData->portDir[s_axiClk]     = vhpiIn;
   portData->portDir[s_masterId]   = vhpiIn;
   portData->portDir[s_arvalid]    = vhpiOut;
   portData->portDir[s_arready]    = vhpiIn;
   portData->portDir[s_araddr]     = vhpiOut;
   portData->portDir[s_arid]       = vhpiOut;
   portData->portDir[s_arlen]      = vhpiOut;
   portData->portDir[s_arsize]     = vhpiOut;
   portData->portDir[s_arburst]    = vhpiOut;
   portData->portDir[s_arlock]     = vhpiOut;
   portData->portDir[s_arprot]     = vhpiOut;
   portData->portDir[s_arcache]    = vhpiOut;
   portData->portDir[s_rready]     = vhpiOut;
   portData->portDir[s_rdataH]     = vhpiIn;
   portData->portDir[s_rdataL]     = vhpiIn;
   portData->portDir[s_rlast]      = vhpiIn;
   portData->portDir[s_rvalid]     = vhpiIn;
   portData->portDir[s_rid]        = vhpiIn;
   portData->portDir[s_rresp]      = vhpiIn;
   portData->portDir[s_awvalid]    = vhpiOut;
   portData->portDir[s_awready]    = vhpiIn;
   portData->portDir[s_awaddr]     = vhpiOut;
   portData->portDir[s_awid]       = vhpiOut;
   portData->portDir[s_awlen]      = vhpiOut;
   portData->portDir[s_awsize]     = vhpiOut;
   portData->portDir[s_awburst]    = vhpiOut;
   portData->portDir[s_awlock]     = vhpiOut;
   portData->portDir[s_awcache]    = vhpiOut;
   portData->portDir[s_awprot]     = vhpiOut;
   portData->portDir[s_wready]     = vhpiIn;
   portData->portDir[s_wdataH]     = vhpiOut;
   portData->portDir[s_wdataL]     = vhpiOut;
   portData->portDir[s_wlast]      = vhpiOut;
   portData->portDir[s_wvalid]     = vhpiOut;
   portData->portDir[s_wid]        = vhpiOut;
   portData->portDir[s_wstrb]      = vhpiOut;
   portData->portDir[s_bready]     = vhpiOut;
   portData->portDir[s_bresp]      = vhpiIn;
   portData->portDir[s_bvalid]     = vhpiIn;
   portData->portDir[s_bid]        = vhpiIn;

   // Set port and widths
   portData->portWidth[s_axiClk]     = 1;
   portData->portWidth[s_masterId]   = 8;
   portData->portWidth[s_arvalid]    = 1;
   portData->portWidth[s_arready]    = 1;
   portData->portWidth[s_araddr]     = 32;
   portData->portWidth[s_arid]       = 12;
   portData->portWidth[s_arlen]      = 4;
   portData->portWidth[s_arsize]     = 3;
   portData->portWidth[s_arburst]    = 2;
   portData->portWidth[s_arlock]     = 2;
   portData->portWidth[s_arprot]     = 3;
   portData->portWidth[s_arcache]    = 4;
   portData->portWidth[s_rready]     = 1;
   portData->portWidth[s_rdataH]     = 32;
   portData->portWidth[s_rdataL]     = 32;
   portData->portWidth[s_rlast]      = 1;
   portData->portWidth[s_rvalid]     = 1;
   portData->portWidth[s_rid]        = 12;
   portData->portWidth[s_rresp]      = 2;
   portData->portWidth[s_awvalid]    = 1;
   portData->portWidth[s_awready]    = 1;
   portData->portWidth[s_awaddr]     = 32;
   portData->portWidth[s_awid]       = 12;
   portData->portWidth[s_awlen]      = 4;
   portData->portWidth[s_awsize]     = 3;
   portData->portWidth[s_awburst]    = 2;
   portData->portWidth[s_awlock]     = 2;
   portData->portWidth[s_awcache]    = 4;
   portData->portWidth[s_awprot]     = 3;
   portData->portWidth[s_wready]     = 1;
   portData->portWidth[s_wdataH]     = 32;
   portData->portWidth[s_wdataL]     = 32;
   portData->portWidth[s_wlast]      = 1;
   portData->portWidth[s_wvalid]     = 1;
   portData->portWidth[s_wid]        = 12;
   portData->portWidth[s_wstrb]      = 8;
   portData->portWidth[s_bready]     = 1;
   portData->portWidth[s_bresp]      = 2;
   portData->portWidth[s_bvalid]     = 1;
   portData->portWidth[s_bid]        = 12;

   // Create data structure to hold state
   portData->stateData = asPtr;

   // State update function
   portData->stateUpdate = *AxiSimMasterUpdate;

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
void AxiSimMasterUpdate ( void *userPtr ) {
   AxiWriteAddr writeAddr;
   AxiWriteData writeData;
   AxiWriteComp writeComp;
   AxiReadAddr  readAddr;
   AxiReadData  readData;

   portDataT *portData     = (portDataT*) userPtr;
   AxiSimMasterData *asPtr = (AxiSimMasterData*)(portData->stateData);

   // Not yet open
   if ( asPtr->smem == NULL ) {

      // Get ID
      uint id = getInt(s_masterId);
      asPtr->smem = sim_open(SHM_TYPE,id);

      if ( asPtr->smem != NULL ) vhpi_printf("AxiSimMaster: Opened shared memory: %s\n",asPtr->smem->_path);
      else vhpi_printf("AxiSimMaster: Failed to open shared memory file. Id=%i\n",id);
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

         // Wait for ready
         if ( asPtr->writeAddrBusy ) {

            // ready is asserted
            if ( getInt(s_awready) == 1 ) {
               asPtr->writeAddrBusy = 0;
               setInt(s_awvalid,0);
            }
         }

         // Ready for next transaction
         else {

            // Software has posted a transaction
            if ( getWriteAddr(asPtr->smem,&writeAddr) ) {
               setInt(s_awvalid,1);
               setInt(s_awaddr,writeAddr.awaddr);
               setInt(s_awid,writeAddr.awid);
               setInt(s_awlen,writeAddr.awlen);
               setInt(s_awsize,writeAddr.awsize);
               setInt(s_awburst,writeAddr.awburst);
               setInt(s_awlock,writeAddr.awlock);
               setInt(s_awcache,writeAddr.awcache);
               setInt(s_awprot,writeAddr.awprot);
               asPtr->writeAddrBusy = 1;
            }
         }

         //---------------------------------
         // Write Data
         //---------------------------------

         // Wait for ready
         if ( asPtr->writeDataBusy ) {

            // ready is asserted
            if ( getInt(s_wready) == 1 ) {
               asPtr->writeDataBusy = 0;
               setInt(s_wvalid,0);
            }
         }

         // Ready for next transaction
         else {

            // Software has posted a transaction
            if ( getWriteData(asPtr->smem,&writeData) ) {
               setInt(s_wvalid,1);
               setInt(s_wdataH,writeData.wdataH);
               setInt(s_wdataL,writeData.wdataL);
               setInt(s_wlast,writeData.wlast);
               setInt(s_wid,writeData.wid);
               setInt(s_wstrb,writeData.wstrb);
               asPtr->writeDataBusy = 1;
            }
         }

         //---------------------------------
         // Write Completion
         //---------------------------------

         // Valid is asserted
         if ( !asPtr->writeCompBusy && getInt(s_bvalid) == 1 ) {
            writeComp.bresp = getInt(s_bresp);
            writeComp.bid   = getInt(s_bid);
            setWriteComp(asPtr->smem,&writeComp);
            asPtr->writeCompBusy = 1;
         }

         //---------------------------------
         // Read Address
         //---------------------------------

         // Wait for ready
         if ( asPtr->readAddrBusy ) {

            // ready is asserted
            if ( getInt(s_arready) == 1 ) {
               asPtr->readAddrBusy = 0;
               setInt(s_arvalid,0);
            }
         }

         // Ready for next transaction
         else {

            // Software has posted a transaction
            if ( getReadAddr(asPtr->smem,&readAddr) ) {
               setInt(s_arvalid,1);
               setInt(s_araddr,readAddr.araddr);
               setInt(s_arid,readAddr.arid);
               setInt(s_arlen,readAddr.arlen);
               setInt(s_arsize,readAddr.arsize);
               setInt(s_arburst,readAddr.arburst);
               setInt(s_arlock,readAddr.arlock);
               setInt(s_arprot,readAddr.arprot);
               setInt(s_arcache,readAddr.arcache);
               asPtr->readAddrBusy = 1;
            }
         }

         //---------------------------------
         // Read Data
         //---------------------------------

         // Valid is asserted
         if ( !asPtr->readDataBusy && getInt(s_rvalid) == 1 ) {
            readData.rdataH = getInt(s_rdataH);
            readData.rdataL = getInt(s_rdataL);
            readData.rlast  = getInt(s_rlast);
            readData.rid    = getInt(s_rid);
            readData.rresp  = getInt(s_rresp);
            setReadData(asPtr->smem,&readData);
            asPtr->readDataBusy = 1;
         }

         //---------------------------------
         // Handshaking
         //---------------------------------
         usleep(1000);

         if ( readyWriteComp(asPtr->smem) ) {
            setInt(s_bready,1);
            asPtr->writeCompBusy = 0;
         }
         else setInt(s_bready,0);

         if ( readyReadData(asPtr->smem)  ) {
            setInt(s_rready,1);
            asPtr->readDataBusy = 0;
         }
         else setInt(s_rready,0);
      }
   }
}

