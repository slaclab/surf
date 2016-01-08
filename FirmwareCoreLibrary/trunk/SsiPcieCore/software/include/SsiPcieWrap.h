//-----------------------------------------------------------------------------
// Title      : SSI PCIe Core
//-----------------------------------------------------------------------------
// File       : SsiPcieWrap.h
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

#ifndef __SSI_PCIE_WRAP_G3_H__
#define __SSI_PCIE_WRAP_G3_H__

#include <linux/types.h>
#include "SsiPcieMod.h"

/////////////////////////////////////////////////////////////////////////////
// Send Frame, size in dwords
// int ssipcie_send(int fd, void *buf, size_t count, uint lane, uint vc);

// Receive Frame, size in dwords, return in dwords
// int ssipcie_recv(int fd, void *buf, size_t maxSize, uint *lane, uint *vc, uint *error);

// Read Status
// int ssipcie_status(int fd, PgpCardStatus *status);

// Reset Counters
// int ssipcie_rstCount(int fd);

// Set Loopback for DMA Lanes
// int ssipcie_setLoop(int fd, uint lane);

// Clear Loopback for DMA Lanes
// int ssipcie_clrLoop(int fd, uint lane);

// Set debug
// int ssipcie_setDebug(int fd, uint level);

// Dump Debug
// int ssipcie_dumpDebug(int fd);
/////////////////////////////////////////////////////////////////////////////

// Send Frame, size in dwords
inline int ssipcie_send(int fd, void *buf, size_t size, uint lane, uint vc) {
   SsiPcieTx ssiPcieTx;

   ssiPcieTx.model = (sizeof(buf));
   ssiPcieTx.cmd   = IOCTL_Normal_Write;
   ssiPcieTx.vc    = vc;
   ssiPcieTx.lane  = lane;
   ssiPcieTx.size  = size;
   ssiPcieTx.data  = (__u32*)buf;

   return(write(fd,&ssiPcieTx,sizeof(SsiPcieTx)));
}

// Receive Frame, size in dwords, return in dwords
inline int ssipcie_recv(int fd, void *buf, size_t maxSize, uint *lane, uint *vc, uint *error) {
   SsiPcieRx ssiPcieRx;
   int       ret;

   ssiPcieRx.maxSize = maxSize;
   ssiPcieRx.data    = (__u32*)buf;
   ssiPcieRx.model   = sizeof(buf);

   ret = read(fd,&ssiPcieRx,sizeof(SsiPcieRx));

   *lane      = ssiPcieRx.lane;
   *vc        = ssiPcieRx.vc;
   *error     = ssiPcieRx.error;

   return(ret);
}

// Read Status
inline int ssipcie_status(int fd, SsiPcieStatus *status) {
   // the buffer is a SsiPcieTx on the way in and a SsiPcieStatus on the way out
   __u8*      c = (__u8*) status;  // this adheres to strict aliasing rules
   SsiPcieTx* p = (SsiPcieTx*) c;

   p->model = sizeof(p);
   p->cmd   = IOCTL_Read_Status;
   p->data  = (__u32*)status;
   return(write(fd, p, sizeof(SsiPcieStatus)));
}

// Reset Counters
inline int ssipcie_rstCount(int fd) {
   SsiPcieTx  t;

   t.model = sizeof(SsiPcieTx*);
   t.cmd   = IOCTL_Count_Reset;
   t.data  = (__u32*)0;
   return(write(fd, &t, sizeof(SsiPcieTx)));
}

// Set Loopback for DMA Lanes
inline int ssipcie_setLoop(int fd, uint lane) {
   SsiPcieTx  t;

   t.model = sizeof(SsiPcieTx*);
   t.cmd   = IOCTL_Set_Loop;
   t.data  = (__u32*) lane;
   return(write(fd, &t, sizeof(SsiPcieTx)));
}

// Clear Loopback for DMA Lanes
inline int ssipcie_clrLoop(int fd, uint lane) {
   SsiPcieTx  t;

   t.model = sizeof(SsiPcieTx*);
   t.cmd   = IOCTL_Clr_Loop;
   t.data  = (__u32*) lane;
   return(write(fd, &t, sizeof(SsiPcieTx)));
}

// Set debug
inline int ssipcie_setDebug(int fd, uint level) {
   SsiPcieTx  t;

   t.model = sizeof(SsiPcieTx*);
   t.cmd   = IOCTL_Set_Debug;
   t.data  = (__u32*) level;
   return(write(fd, &t, sizeof(SsiPcieTx)));
}

// Dump Debug
inline int ssipcie_dumpDebug(int fd) {
   SsiPcieTx  t;

   t.model = sizeof(SsiPcieTx*);
   t.cmd   = IOCTL_Dump_Debug;
   return(write(fd, &t, sizeof(SsiPcieTx)));
}

#endif
