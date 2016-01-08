//-----------------------------------------------------------------------------
// Title      : SSI PCIe Core
//-----------------------------------------------------------------------------
// File       : SsiPcie.h
// Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
// Company    : SLAC National Accelerator Laboratory
// Created    : 2015-05-06
// Last update: 2015-05-06
// Platform   : 
// Standard   : 
//-----------------------------------------------------------------------------
// Description: SSI PCIe Linux Driver
//-----------------------------------------------------------------------------
// This file is part of 'SLAC SSI PCI-E Core'.
// It is subject to the license terms in the LICENSE.txt file found in the 
// top-level directory of this distribution and at: 
//    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
// No part of 'SLAC SSI PCI-E Core', including this file, 
// may be copied, modified, propagated, or distributed except according to 
// the terms contained in the LICENSE.txt file.
//----------------------------------------------------------------------------

#include <linux/init.h>
#include <linux/module.h>
#include <linux/pci.h>
#include <linux/interrupt.h>
#include <linux/fs.h>
#include <linux/poll.h>
#include <linux/cdev.h>
#include <linux/types.h>
#include <asm/uaccess.h>

// DMA Buffer Size, Bytes
#define DEF_RX_BUF_SIZE 2097152//0x200000
#define DEF_TX_BUF_SIZE 2097152//0x200000

// Number of RX & TX Buffers
#define DEF_RX_BUF_CNT 32
#define DEF_TX_BUF_CNT 32

// PCI IDs
#define PCI_VENDOR_ID_SLAC           0x1A4A
#define PCI_DEVICE_ID_SLAC_SSIPCIE   0x2030

// Max number of PCIe devices to support
#define MAX_PCI_DEVICES 8

// Module Name
#define MOD_NAME "SsiPcie"

enum MODELS {SmallMemoryModel=4, LargeMemoryModel=8};

// Address Map, offset from base
struct SsiPcieReg {
   // SsiPcieSysReg.vhd  
   __u32 version;       // Software_Addr = 0x000
   __u32 serNumUpper;   // Software_Addr = 0x004
   __u32 serNumLower;   // Software_Addr = 0x008
   __u32 scratch;       // Software_Addr = 0x00C
   __u32 cardRstStat;   // Software_Addr = 0x010
   __u32 irq;           // Software_Addr = 0x014
   __u32 dmaSize;       // Software_Addr = 0x018
   __u32 dmaLoopback;   // Software_Addr = 0x01C
   __u32 pciStat[4];    // Software_Addr = 0x02C:0x020
   __u32 barMask[4];    // Software_Addr = 0x03C:0x030   
   __u32 barSize;       // Software_Addr = 0x040   
   __u32 sysSpare[175]; // Software_Addr = 0x2FC:0x044   
   __u32 BuildStamp[64];// Software_Addr = 0x3FC:0x300
   
   // SsiPcieRxDesc.vhd   
   __u32 rxFree[16];    // Software_Addr = 0x43C:0x400
   __u32 rxFreeStat[16];// Software_Addr = 0x47C:0x440
   __u32 rxSpare0[32];  // Software_Addr = 0x4FC:0x480
   __u32 rxMaxFrame;    // Software_Addr = 0x500
   __u32 rxCount;       // Software_Addr = 0x504
   __u32 rxStatus;      // Software_Addr = 0x508
   __u32 rxRead[2];     // Software_Addr = 0x510:0x50C
   __u32 rxSpare1[187]; // Software_Addr = 0x77C:0x514
   
   // SsiPcieTxDesc.vhd
   __u32 txWrA[16];    // Software_Addr = 0x83C:0x800
   __u32 txWrB[16];    // Software_Addr = 0x87C:0x840
   __u32 txFifoCnt[16];// Software_Addr = 0x8BC:0x880
   __u32 txSpare[16];  // Software_Addr = 0x8FC:0x8C0
   __u32 txStat[2];    // Software_Addr = 0x904:0x900
   __u32 txCount;      // Software_Addr = 0x908
   __u32 txRead;       // Software_Addr = 0x90C
};

// Structure for TX buffers
struct TxBuffer {
   dma_addr_t dma;
   unchar*    buffer;
   __u32      lane;
   __u32      vc;
   __u32      length;
};

// Structure for RX buffers
struct RxBuffer {
   dma_addr_t dma;
   unchar*    buffer;
   __u32      error;
   __u32      lane;
   __u32      vc;
   __u32      length;
};

// Device structure
struct SsiDevice {

   // PCI address regions
   ulong             baseHdwr;
   ulong             baseLen;
   __u32             dmaSize;
   __u32             barSize;
   struct SsiPcieReg *reg;

   // Device structure
   int         major;
   struct cdev cdev;
   
   // Async queue
   struct fasync_struct *async_queue;     

   // Device is already open
   __u32 isOpen;

   // Debug flag
   __u32 debug;

   // IRQ
   int irq;

   // RX/TX Buffer Structures
   __u32            rxBuffCnt;
   __u32            rxBuffSize;
   struct RxBuffer **rxBuffer;
   __u32            txBuffCnt;
   __u32            txBuffSize;
   struct TxBuffer **txBuffer;

   // Top pointer for rx queue, 2 entries larger than rxBuffCnt
   struct RxBuffer **rxQueue;
   __u32            rxRead;
   __u32            rxWrite;

   // Top pointer for tx queue, 2 entries larger than txBuffCnt
   struct TxBuffer **txQueue;
   __u32            txRead;
   __u32            txWrite;

   // Queues
   wait_queue_head_t inq;
   wait_queue_head_t outq;
};

// TX32 Structure
typedef struct {
   __u32 model; // large=8, small=4
   __u32 cmd; // ioctl commands
   __u32 data;
   __u32 lane;
   __u32 vc;
   __u32 size;  // dwords
} SsiPcieTx32;

// RX32 Structure
typedef struct {
   __u32 model; // large=8, small=4
   __u32 maxSize; // dwords
   __u32 data;
   __u32 lane;
   __u32 vc;
   __u32 rxSize;  // dwords
   __u32 error;
} SsiPcieRx32;

// Function prototypes
int SsiPcie_Open(struct inode *inode, struct file *filp);
int SsiPcie_Release(struct inode *inode, struct file *filp);
ssize_t SsiPcie_Write(struct file *filp, const char *buf, size_t count, loff_t *f_pos);
ssize_t SsiPcie_Read(struct file *filp, char *buf, size_t count, loff_t *f_pos);
int SsiPcie_Ioctl(struct inode *inode, struct file *filp, unsigned int cmd, unsigned long arg);
int my_Ioctl(struct file *filp, __u32 cmd, __u64 argument);
static irqreturn_t SsiPcie_IRQHandler(int irq, void *dev_id, struct pt_regs *regs);
static unsigned int SsiPcie_Poll(struct file *filp, poll_table *wait );
static int SsiPcie_Probe(struct pci_dev *pcidev, const struct pci_device_id *dev_id);
static void SsiPcie_Remove(struct pci_dev *pcidev);
static int SsiPcie_Init(void);
static void SsiPcie_Exit(void);
int SsiPcie_Mmap(struct file *filp, struct vm_area_struct *vma);
int SsiPcie_Fasync(int fd, struct file *filp, int mode);
void SsiPcie_VmOpen(struct vm_area_struct *vma);
void SsiPcie_VmClose(struct vm_area_struct *vma);

// PCI device IDs
static struct pci_device_id SsiPcie_Ids[] = {
   { PCI_DEVICE(PCI_VENDOR_ID_SLAC,   PCI_DEVICE_ID_SLAC_SSIPCIE)   },
   { 0, }
};

// PCI driver structure
static struct pci_driver SsiPcieDriver = {
  .name     = MOD_NAME,
  .id_table = SsiPcie_Ids,
  .probe    = SsiPcie_Probe,
  .remove   = SsiPcie_Remove,
};

// Define interface routines
struct file_operations SsiPcie_Intf = {
   read:    SsiPcie_Read,
   write:   SsiPcie_Write,
   ioctl:   SsiPcie_Ioctl,
   open:    SsiPcie_Open,
   release: SsiPcie_Release,
   poll:    SsiPcie_Poll,
   fasync:  SsiPcie_Fasync,
   mmap:    SsiPcie_Mmap,      
};

// Virtual memory operations
static struct vm_operations_struct SsiPcie_VmOps = {
  open:  SsiPcie_VmOpen,
  close: SsiPcie_VmClose,
};
