
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
   portData->portDir[axiClk]     = vhpiIn;
   portData->portDir[masterId]   = vhpiIn;
   portData->portDir[arvalid]    = vhpiOut;
   portData->portDir[arready]    = vhpiIn;
   portData->portDir[araddr]     = vhpiOut;
   portData->portDir[arid]       = vhpiOut;
   portData->portDir[arlen]      = vhpiOut;
   portData->portDir[arsize]     = vhpiOut;
   portData->portDir[arburst]    = vhpiOut;
   portData->portDir[arlock]     = vhpiOut;
   portData->portDir[arprot]     = vhpiOut;
   portData->portDir[arcache]    = vhpiOut;
   portData->portDir[rready]     = vhpiOut;
   portData->portDir[rdataH]     = vhpiIn;
   portData->portDir[rdataL]     = vhpiIn;
   portData->portDir[rlast]      = vhpiIn;
   portData->portDir[rvalid]     = vhpiIn;
   portData->portDir[rid]        = vhpiIn;
   portData->portDir[rresp]      = vhpiIn;
   portData->portDir[awvalid]    = vhpiOut;
   portData->portDir[awready]    = vhpiIn;
   portData->portDir[awaddr]     = vhpiOut;
   portData->portDir[awid]       = vhpiOut;
   portData->portDir[awlen]      = vhpiOut;
   portData->portDir[awsize]     = vhpiOut;
   portData->portDir[awburst]    = vhpiOut;
   portData->portDir[awlock]     = vhpiOut;
   portData->portDir[awcache]    = vhpiOut;
   portData->portDir[awprot]     = vhpiOut;
   portData->portDir[wready]     = vhpiIn;
   portData->portDir[wdataH]     = vhpiOut;
   portData->portDir[wdataL]     = vhpiOut;
   portData->portDir[wlast]      = vhpiOut;
   portData->portDir[wvalid]     = vhpiOut;
   portData->portDir[wid]        = vhpiOut;
   portData->portDir[wstrb]      = vhpiOut;
   portData->portDir[bready]     = vhpiOut;
   portData->portDir[bresp]      = vhpiIn;
   portData->portDir[bvalid]     = vhpiIn;
   portData->portDir[bid]        = vhpiIn;

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
   asPtr->smem = NULL;

   // Call generic Init
   VhpiGenericInit(compInst,portData);

}


// User function to update state based upon a signal change
void AxiSimMasterUpdate ( void *userPtr ) {

   portDataT *portData     = (portDataT*) userPtr;
   AxiSimMasterData *asPtr = (AxiSimMasterData*)(portData->stateData);

   // Not yet open
   if ( asPtr->smem == NULL ) {

      // Get ID
      uint id = getInt(masterId);
      asPtr->smem = sim_open(SYS,id,-1);

      if ( asPtr->smem != NULL ) vhpi_printf("AxiSimMaster: Opened shared memory. System=%s, Id=%i\n",SYS,id);
      else vhpi_printf("AxiSimMaster: Failed to open shared memory file. System=%s, Id=%i\n",SYS,id);
   }

   // Detect clock edge
   if ( asPtr->currClk != getInt(axiClk) ) {
      asPtr->currClk = getInt(axiClk);

      // Rising edge
      if ( asPtr->currClk ) {




      }
   }
}

