//-----------------------------------------------------------------------------
// Title      : SSI PCIe Core
//-----------------------------------------------------------------------------
// File       : SsiPcieMod.h
// Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
// Company    : SLAC National Accelerator Laboratory
// Created    : 2015-05-06
// Last update: 2015-05-06
// Platform   : 
// Standard   : 
//-----------------------------------------------------------------------------
// Description: SSI PCIe Structures and IOCTL definitions 
//-----------------------------------------------------------------------------
// This file is part of 'SLAC SSI PCI-E Core'.
// It is subject to the license terms in the LICENSE.txt file found in the 
// top-level directory of this distribution and at: 
//    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
// No part of 'SLAC SSI PCI-E Core', including this file, 
// may be copied, modified, propagated, or distributed except according to 
// the terms contained in the LICENSE.txt file.
//----------------------------------------------------------------------------

#ifndef __SSI_PCIE_MOD_H__
#define __SSI_PCIE_MOD_H__

#include <linux/types.h>

// Return values
#define SUCCESS 0
#define ERROR   -1

// Scratchpad write value
#define SPAD_WRITE 0x55441122

// TX Structure
typedef struct {
   __u32  model; // large=8, small=4
   __u32  cmd; // ioctl commands
   __u32* data;
   __u32  lane;
   __u32  vc;
   __u32  size;  // dwords
} SsiPcieTx;

// RX Structure
typedef struct {
   __u32   model; // large=8, small=4
   __u32   maxSize; // dwords
   __u32*  data;
   __u32   lane;
   __u32   vc;
   __u32   rxSize;  // dwords
   __u32   error;
} SsiPcieRx;

// Status Structure
typedef struct {
   // General Status
   __u32 Version;
   __u32 SerialNumber[2];
   __u32 ScratchPad;
   __u32 BuildStamp[64];
   __u32 CountReset;
   __u32 CardReset;
   __u32 DmaSize;   
   __u32 DmaLoopback;   
   __u32 BarSize;   
   __u32 BarMask[4];      

   // PCI Status & Control Registers
   __u32 PciCommand;
   __u32 PciStatus;
   __u32 PciDCommand;
   __u32 PciDStatus;
   __u32 PciLCommand;
   __u32 PciLStatus;
   __u32 PciLinkState;
   __u32 PciFunction;
   __u32 PciDevice;
   __u32 PciBus;
   __u32 PciBaseHdwr;
   __u32 PciBaseLen;   
   
   // RX Descriptor Status
   __u32 RxFreeFull[16];
   __u32 RxFreeValid[16];
   __u32 RxFreeFifoCount[16];
   __u32 RxReadReady;
   __u32 RxRetFifoCount;   
   __u32 RxCount;
   __u32 RxWrite;
   __u32 RxRead;
 
   // TX Descriptor Status
   __u32 TxDmaAFull[16];
   __u32 TxReadReady;
   __u32 TxRetFifoCount;
   __u32 TxCount;
   __u32 TxWrite;
   __u32 TxRead;   

} SsiPcieStatus;

//////////////////////
// IO Control Commands
//////////////////////

// Normal Write command
#define IOCTL_Normal_Write 0x00

// Read Status, Pass PgpCardStatus as arg
#define IOCTL_Read_Status 0x01

// Reset counters
#define IOCTL_Count_Reset 0x02

// Set/Clear Loopback, Pass PGP Channel As Arg
#define IOCTL_Set_Loop 0x10
#define IOCTL_Clr_Loop 0x11

// Set Debug, Pass Debug Value As Arg
#define IOCTL_Set_Debug 0xFD

// Dump debug
#define IOCTL_Dump_Debug 0xFE

// No Operation
#define IOCTL_NOP 0xFF

#endif
