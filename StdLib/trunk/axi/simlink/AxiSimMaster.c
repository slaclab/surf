
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

// Elab function
void AxiStreamSimIbElab(vhpiHandleT compInst) { 
   VhpiGenericElab(compInst);
}

// Init function
void AxiStreamSimIbInit(vhpiHandleT compInst) { 

   // Create new port data structure
   portDataT        *portData  = (portDataT *)        malloc(sizeof(portDataT));
   AxiSimMasterData *asPtr     = (AxiSimMasterData *) malloc(sizeof(AxiSimMasterData));

   // Get port count
   portData->portCount = 40;

   // Set port directions
   portData->portDir[axiClk]     = vhdiIn;
   portData->portDir[masterId]   = vhdiIn;
   portData->portDir[arvalid]    = vhdiOut;
   portData->portDir[arready]    = vhdiIn;
   portData->portDir[araddr]     = vhdiOut;
   portData->portDir[arid]       = vhdiOut;
   portData->portDir[arlen]      = vhdiOut;
   portData->portDir[arsize]     = vhdiOut;
   portData->portDir[arburst]    = vhdiOut;
   portData->portDir[arlock]     = vhdiOut;
   portData->portDir[arprot]     = vhdiOut;
   portData->portDir[arcache]    = vhdiOut;
   portData->portDir[rready]     = vhdiOut;
   portData->portDir[rdataH]     = vhdiIn;
   portData->portDir[rdataL]     = vhdiIn;
   portData->portDir[rlast]      = vhdiIn;
   portData->portDir[rvalid]     = vhdiIn;
   portData->portDir[rid]        = vhdiIn;
   portData->portDir[rresp]      = vhdiIn;
   portData->portDir[awvalid]    = vhdiOut;
   portData->portDir[awready]    = vhdiIn;
   portData->portDir[awaddr]     = vhdiOut;
   portData->portDir[awid]       = vhdiOut;
   portData->portDir[awlen]      = vhdiOut;
   portData->portDir[awsize]     = vhdiOut;
   portData->portDir[awburst]    = vhdiOut;
   portData->portDir[awlock]     = vhdiOut;
   portData->portDir[awcache]    = vhdiOut;
   portData->portDir[awprot]     = vhdiOut;
   portData->portDir[wready]     = vhdiIn;
   portData->portDir[wdataH]     = vhdiOut;
   portData->portDir[wdataL]     = vhdiOut;
   portData->portDir[wlast]      = vhdiOut;
   portData->portDir[wvalid]     = vhdiOut;
   portData->portDir[wid]        = vhdiOut;
   portData->portDir[wstrb]      = vhdiOut;
   portData->portDir[bready]     = vhdiOut;
   portData->portDir[bresp]      = vhdiIn;
   portData->portDir[bvalid]     = vhdiIn;
   portData->portDir[bid]        = vhdiIn;

   // Set port and widths
   portData->portWidth[axiClk]     = 1;
   portData->portWidth[masterId]   = 8;
   portData->portWidth[arvalid]    = 1;
   portData->portWidth[arready]    = 1;
   portData->portWidth[araddr]     = 32;
   portData->portWidth[arid]       = 12;
   portData->portWidth[arlen]      = 4;
   portData->portWidth[arsize]     = 3;
   portData->portWidth[arburst]    = 2;
   portData->portWidth[arlock]     = 2;
   portData->portWidth[arprot]     = 3;
   portData->portWidth[arcache]    = 4;
   portData->portWidth[rready]     = 1;
   portData->portWidth[rdataH]     = 32;
   portData->portWidth[rdataL]     = 32;
   portData->portWidth[rlast]      = 1;
   portData->portWidth[rvalid]     = 1;
   portData->portWidth[rid]        = 12;
   portData->portWidth[rresp]      = 2;
   portData->portWidth[awvalid]    = 1;
   portData->portWidth[awready]    = 1;
   portData->portWidth[awaddr]     = 32;
   portData->portWidth[awid]       = 12;
   portData->portWidth[awlen]      = 4;
   portData->portWidth[awsize]     = 3;
   portData->portWidth[awburst]    = 2;
   portData->portWidth[awlock]     = 2;
   portData->portWidth[awcache]    = 4;
   portData->portWidth[awprot]     = 3;
   portData->portWidth[wready]     = 1;
   portData->portWidth[wdataH]     = 32;
   portData->portWidth[wdataL]     = 32;
   portData->portWidth[wlast]      = 1;
   portData->portWidth[wvalid]     = 1;
   portData->portWidth[wid]        = 12;
   portData->portWidth[wstrb]      = 8;
   portData->portWidth[bready]     = 1;
   portData->portWidth[bresp]      = 2;
   portData->portWidth[bvalid]     = 1;
   portData->portWidth[bid]        = 12;

   // Create data structure to hold state
   portData->stateData = asPtr;

   // State update function
   portData->stateUpdate = *AxiSimMasterUpdate;

   // Init data structure
   asPtr->currClk = 0;

   // Call generic Init
   VhpiGenericInit(compInst,portData);

   // Get ID
   uint id = getInt(masterId);
   asPtr->smem = AxiSharedMem::open(SYS,id);

   if ( asPtr->smem != NULL ) vhpi_printf("AxiSimMaster: Opened shared memory. System=%s, Id=%i\n",SYS,id);
   else vhpi_printf("AxiSimMaster: Failed to open shared memory file. System=%s, Id=%i\n",SYS,id);
}


// User function to update state based upon a signal change
void AxiStreamSimIbUpdate ( void *userPtr ) {

   portDataT *portData = (portDataT*) userPtr;
   AxiStreamSimIbData *asPtr = (AxiStreamSimIbData*)(portData->stateData);

   // Detect clock edge
   if ( asPtr->currClk != getInt(axiClk) ) {
      asPtr->currClk = getInt(axiClk);

      // Rising edge
      if ( asPtr->currClk ) {




      }
   }
}

