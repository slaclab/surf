//////////////////////////////////////////////////////////////////////////////
// This file is part of 'SLAC Firmware Standard Library'.
// It is subject to the license terms in the LICENSE.txt file found in the 
// top-level directory of this distribution and at: 
//    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
// No part of 'SLAC Firmware Standard Library', including this file, 
// may be copied, modified, propagated, or distributed except according to 
// the terms contained in the LICENSE.txt file.
//////////////////////////////////////////////////////////////////////////////

#ifndef __AXI_SIM_SLAVE_H__
#define __AXI_SIM_SLAVE_H__

#include <vhpi_user.h>
#include "AxiSharedMem.h"

#define SHM_TYPE "slave"

// Signals
#define s_axiClk   0
#define s_slaveId  1
#define s_arvalid  2
#define s_arready  3
#define s_araddr   4
#define s_arid     5
#define s_arlen    6
#define s_arsize   7
#define s_arburst  8
#define s_arlock   9
#define s_arprot   10
#define s_arcache  11
#define s_rready   12
#define s_rdataH   13
#define s_rdataL   14
#define s_rlast    15
#define s_rvalid   16
#define s_rid      17
#define s_rresp    18
#define s_awvalid  19
#define s_awready  20
#define s_awaddr   21
#define s_awid     22
#define s_awlen    23
#define s_awsize   24
#define s_awburst  25
#define s_awlock   26
#define s_awcache  27
#define s_awprot   28
#define s_wready   29
#define s_wdataH   30
#define s_wdataL   31
#define s_wlast    32
#define s_wvalid   33
#define s_wid      34
#define s_wstrb    35
#define s_bready   36
#define s_bresp    37
#define s_bvalid   38
#define s_bid      39

// Structure to track state
typedef struct {

   // Shared memory
   AxiSharedMem *smem;

   // Current state
   uint currClk;
   uint writeAddrBusy;
   uint writeDataBusy;
   uint writeCompBusy;
   uint readAddrBusy;
   uint readDataBusy;

} AxiSimSlaveData;

// Init function
void AxiSimSlaveInit(vhpiHandleT compInst);

// Callback function for updating
void AxiSimSlaveUpdate ( void *userPtr );

#endif

