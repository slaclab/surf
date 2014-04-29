
#ifndef __AXI_SIM_MASTER_H__
#define __AXI_SIM_MASTER_H__

#include <vhpi_user.h>
#include "AxiSharedMem.h"

#define SYS "SimAxiMaster"

// Signals
#define axiClk    0
#define masterId  1
#define arvalid   2
#define arready   3
#define araddr    4
#define arid      5
#define arlen     6
#define arsize    7
#define arburst   8
#define arlock    9
#define arprot    10
#define arcache   11
#define rready    12
#define rdataH    13
#define rdataL    14
#define rlast     15
#define rvalid    16
#define rid       17
#define rresp     18
#define awvalid   19
#define awready   20
#define awaddr    21
#define awid      22
#define awlen     23
#define awsize    24
#define awburst   25
#define awlock    26
#define awcache   27
#define awprot    28
#define wready    29
#define wdataH    30
#define wdataL    31
#define wlast     32
#define wvalid    33
#define wid       34
#define wstrb     35
#define bready    36
#define bresp     37
#define bvalid    38
#define bid       39

// Structure to track state
typedef struct {

   // Shared memory
   AxiSharedMem *smem;

   // Current state
   uint currClk;

} AxiSimMasterData;

// Init function
void AxiSimMasterInit(vhpiHandleT compInst);

// Callback function for updating
void AxiSimMasterUpdate ( void *userPtr );

#endif

