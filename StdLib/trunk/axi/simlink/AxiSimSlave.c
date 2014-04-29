
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

// Elab function
void AxiStreamSimIbElab(vhpiHandleT compInst) { 
   VhpiGenericElab(compInst);
}

// Init function
void AxiStreamSimIbInit(vhpiHandleT compInst) { 

   // Create new port data structure
   portDataT       *portData  = (portDataT *)       malloc(sizeof(portDataT));
   AxiSimSlaveData *asPtr     = (AxiSimSlaveData *) malloc(sizeof(AxiSimSlaveData));

   // Get port count
   portData->portCount = 40;

   // Set port directions
   portData->portDir[axiClk]  = vhpiIn;
   portData->portDir[slaveId] = vhpiIn;
   portData->portDir[arvalid] = vhpiIn;
   portData->portDir[arready] = vhpiOut;
   portData->portDir[araddr]  = vhpiIn;
   portData->portDir[arid]    = vhpiIn;
   portData->portDir[arlen]   = vhpiIn;
   portData->portDir[arsize]  = vhpiIn;
   portData->portDir[arburst] = vhpiIn;
   portData->portDir[arlock]  = vhpiIn;
   portData->portDir[arprot]  = vhpiIn;
   portData->portDir[arcache] = vhpiIn;
   portData->portDir[rready]  = vhpiIn;
   portData->portDir[rdataH]  = vhpiOut;
   portData->portDir[rdataL]  = vhpiOut;
   portData->portDir[rlast]   = vhpiOut;
   portData->portDir[rvalid]  = vhpiOut;
   portData->portDir[rid]     = vhpiOut;
   portData->portDir[rresp]   = vhpiOut;
   portData->portDir[awvalid] = vhpiIn;
   portData->portDir[awready] = vhpiOut;
   portData->portDir[awaddr]  = vhpiIn;
   portData->portDir[awid]    = vhpiIn;
   portData->portDir[awlen]   = vhpiIn;
   portData->portDir[awsize]  = vhpiIn;
   portData->portDir[awburst] = vhpiIn;
   portData->portDir[awlock]  = vhpiIn;
   portData->portDir[awcache] = vhpiIn;
   portData->portDir[awprot]  = vhpiIn;
   portData->portDir[wready]  = vhpiOut;
   portData->portDir[wdataH]  = vhpiIn;
   portData->portDir[wdataL]  = vhpiIn;
   portData->portDir[wlast]   = vhpiIn;
   portData->portDir[wvalid]  = vhpiIn;
   portData->portDir[wid]     = vhpiIn;
   portData->portDir[wstrb]   = vhpiIn;
   portData->portDir[bready]  = vhpiIn;
   portData->portDir[bresp]   = vhpiOut;
   portData->portDir[bvalid]  = vhpiOut;
   portData->portDir[bid]     = vhpiOut;

   // Set port widths
   portData->portWidth[axiClk]  = 1;
   portData->portWidth[slaveId] = 8;
   portData->portWidth[arvalid] = 1;
   portData->portWidth[arready] = 1;
   portData->portWidth[araddr]  = 32;
   portData->portWidth[arid]    = 12;
   portData->portWidth[arlen]   = 4;
   portData->portWidth[arsize]  = 3;
   portData->portWidth[arburst] = 2;
   portData->portWidth[arlock]  = 2;
   portData->portWidth[arprot]  = 3;
   portData->portWidth[arcache] = 4;
   portData->portWidth[rready]  = 1;
   portData->portWidth[rdataH]  = 32;
   portData->portWidth[rdataL]  = 32;
   portData->portWidth[rlast]   = 1;
   portData->portWidth[rvalid]  = 1;
   portData->portWidth[rid]     = 12;
   portData->portWidth[rresp]   = 2;
   portData->portWidth[awvalid] = 1;
   portData->portWidth[awready] = 1;
   portData->portWidth[awaddr]  = 32;
   portData->portWidth[awid]    = 12;
   portData->portWidth[awlen]   = 4;
   portData->portWidth[awsize]  = 3;
   portData->portWidth[awburst] = 2;
   portData->portWidth[awlock]  = 2;
   portData->portWidth[awcache] = 4;
   portData->portWidth[awprot]  = 3;
   portData->portWidth[wready]  = 1;
   portData->portWidth[wdataH]  = 32;
   portData->portWidth[wdataL]  = 32;
   portData->portWidth[wlast]   = 1;
   portData->portWidth[wvalid]  = 1;
   portData->portWidth[wid]     = 12;
   portData->portWidth[wstrb]   = 8;
   portData->portWidth[bready]  = 1;
   portData->portWidth[bresp]   = 2;
   portData->portWidth[bvalid]  = 1;
   portData->portWidth[bid]     = 12;

   // Create data structure to hold state
   portData->stateData = asPtr;

   // State update function
   portData->stateUpdate = *AxiSimSlaveUpdate;

   // Init data structure
   asPtr->currClk = 0;

   // Call generic Init
   VhpiGenericInit(compInst,portData);

   // Get ID
   uint id = getInt(masterId);
   asPtr->smem = AxiSharedMem::open(SYS,id);

   if ( asPtr->smem != NULL ) vhpi_printf("AxiSimSlave: Opened shared memory. System=%s, Id=%i\n",SYS,id);
   else vhpi_printf("AxiSimSlave: Failed to open shared memory file. System=%s, Id=%i\n",SYS,id);
}


// User function to update state based upon a signal change
void AxiStreamSimIbUpdate ( void *userPtr ) {

   portDataT       *portData = (portDataT*) userPtr;
   AxiSimSlaveData *asPtr    = (AxiSimSlavemData*)(portData->stateData);

   // Detect clock edge
   if ( asPtr->currClk != getInt(axiClk) ) {
      asPtr->currClk = getInt(axiClk);

      // Rising edge
      if ( asPtr->currClk ) {





















      }
   }
}

