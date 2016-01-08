//-----------------------------------------------------------------------------
// Title      : SSI PCIe Core
//-----------------------------------------------------------------------------
// File       : SsiPcie.c
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
#include <linux/compat.h>
#include <asm/uaccess.h>
#include <linux/cdev.h>
#include <linux/types.h>

#include "SsiPcie.h"
#include "../include/SsiPcieMod.h"

#define CORE_BAR 4

MODULE_LICENSE("GPL");
MODULE_DEVICE_TABLE(pci, SsiPcie_Ids);
module_init(SsiPcie_Init);
module_exit(SsiPcie_Exit);

// Global Variable
struct SsiDevice gSsiDevices[MAX_PCI_DEVICES];

// Open Returns 0 on success, error code on failure
int SsiPcie_Open(struct inode *inode, struct file *filp) {
   struct SsiDevice *ssiDevice;

   // Extract structure for card
   ssiDevice = container_of(inode->i_cdev, struct SsiDevice, cdev);
   filp->private_data = ssiDevice;

   // File is already open
   if ( ssiDevice->isOpen != 0 ) {
      printk(KERN_WARNING"%s: Open: module open failed. Device is already open. Maj=%i\n",MOD_NAME,ssiDevice->major);
      return ERROR;
   } else {
      ssiDevice->isOpen = 1;
      return SUCCESS;
   }
}


// SsiPcie_Release
// Called when the device is closed
// Returns 0 on success, error code on failure
int SsiPcie_Release(struct inode *inode, struct file *filp) {
   struct SsiDevice *ssiDevice = (struct SsiDevice *)filp->private_data;

   // File is not open
   if ( ssiDevice->isOpen == 0 ) {
      printk(KERN_WARNING"%s: Release: module close failed. Device is not open. Maj=%i\n",MOD_NAME,ssiDevice->major);
      return ERROR;
   } else {
      ssiDevice->isOpen = 0;
      return SUCCESS;
   }
}

// SsiPcie_Write
// Called when the device is written to
// Returns write count on success. Error code on failure.
ssize_t SsiPcie_Write(struct file *filp, const char* buffer, size_t count, loff_t* f_pos) {
   __u32       descA;
   __u32       descB;
   SsiPcieTx*  ssiPcieTx;
   SsiPcieTx   mySsiPcieTx;
   __u32        buf[count / sizeof(__u32)];
   __u32       theRightWriteSize = sizeof(SsiPcieTx);
   __u32       largeMemoryModel;

   struct SsiDevice* ssiDevice = (struct SsiDevice *)filp->private_data;

   // Copy command structure from user space
   if ( copy_from_user(buf, buffer, count) ) {
     printk(KERN_WARNING "%s: Write: failed to copy command structure from user(%p) space. Maj=%i\n",
         MOD_NAME,
         buffer,
         ssiDevice->major);
     return ERROR;
   }

   largeMemoryModel = buf[0] == LargeMemoryModel;

   if (!largeMemoryModel) {
     SsiPcieTx32* p    = (SsiPcieTx32*)buf;
     ssiPcieTx         = &mySsiPcieTx;
     ssiPcieTx->cmd    = p->cmd;
     ssiPcieTx->lane   = p->lane;
     ssiPcieTx->vc     = p->vc;
     ssiPcieTx->size   = p->size;
     ssiPcieTx->data   = (__u32*)(0LL | p->data);
     theRightWriteSize = sizeof(SsiPcieTx32);
   } else {
     ssiPcieTx = (SsiPcieTx *)buf;
   }

   switch (ssiPcieTx->cmd) {
      case IOCTL_Normal_Write :
         if (count != theRightWriteSize) {
            printk(KERN_WARNING "%s: Write(%u) passed size is not expected(%u) size(%u). Maj=%i\n",
                  MOD_NAME,
                  ssiPcieTx->cmd,
                  (unsigned)sizeof(SsiPcieTx),
                  (unsigned)count, ssiDevice->major);
         }
         if ( (ssiPcieTx->size*4) > ssiDevice->txBuffSize ) {
            printk(KERN_WARNING"%s: Write: passed size is too large for TX buffer. Maj=%i\n",MOD_NAME,ssiDevice->major);
            return(ERROR);
         }

         // No buffers are available
         while ( ssiDevice->txRead == ssiDevice->txWrite ) {
            if ( filp->f_flags & O_NONBLOCK ) return(-EAGAIN);
            if ( ssiDevice->debug > 2 ) printk(KERN_DEBUG"%s: Write: going to sleep. Maj=%i\n",MOD_NAME,ssiDevice->major);
            if (wait_event_interruptible(ssiDevice->outq,(ssiDevice->txRead != ssiDevice->txWrite))) return (-ERESTARTSYS);
            if ( ssiDevice->debug > 2 ) printk(KERN_DEBUG"%s: Write: woke up. Maj=%i\n",MOD_NAME,ssiDevice->major);
         }

            // Copy data from user space
            if ( copy_from_user(ssiDevice->txQueue[ssiDevice->txRead]->buffer,ssiPcieTx->data,(ssiPcieTx->size*4)) ) {
               printk(KERN_WARNING "%s: Write: failed to copy from user(%p) space. Maj=%i\n",
                     MOD_NAME,
                     ssiPcieTx->data,
                     ssiDevice->major);
               return ERROR;
            }

         // Fields for tracking purpose
         ssiDevice->txQueue[ssiDevice->txRead]->lane   = ssiPcieTx->lane;
         ssiDevice->txQueue[ssiDevice->txRead]->vc     = ssiPcieTx->vc;
         ssiDevice->txQueue[ssiDevice->txRead]->length = ssiPcieTx->size;

         // Generate Tx descriptor
         descA  = (ssiPcieTx->lane << 28) & 0xF0000000; // Bits 31:28 = Lane
         descA += (ssiPcieTx->vc   << 24) & 0x0F000000; // Bits 27:24 = VC
         descA += (ssiPcieTx->size <<  0) & 0x00FFFFFF; // Bits 23:00 = Length
         descB = ssiDevice->txQueue[ssiDevice->txRead]->dma;

         // Debug
         if ( ssiDevice->debug > 1 ) {
            printk(KERN_DEBUG"%s: Write: Words=%i, Lane=%i, VC=%i, Addr=%p, Map=%p. Maj=%d\n",
                  MOD_NAME, ssiPcieTx->size, ssiPcieTx->lane, ssiPcieTx->vc,
                  (ssiDevice->txQueue[ssiDevice->txRead]->buffer), (void*)(ssiDevice->txQueue[ssiDevice->txRead]->dma),
                  ssiDevice->major);
         }

         // Write descriptor
         if(ssiPcieTx->lane < ssiDevice->dmaSize) {
            ssiDevice->reg->txWrA[ssiPcieTx->lane] = descA;
            asm("nop");//no operation function to force sequential MEM IO read (first txWrA then txWrB)
            ssiDevice->reg->txWrB[ssiPcieTx->lane] = descB;   
         } else {
            printk(KERN_DEBUG "%s: Write: Invalid ssiPcieTx->lane: %i\n", MOD_NAME, ssiPcieTx->lane);
            return ERROR;
         }

         // Increment read pointer
         ssiDevice->txRead = (ssiDevice->txRead + 1) % (ssiDevice->txBuffCnt+2);
         return(ssiPcieTx->size);
         break;
      default :
         return my_Ioctl(filp, ssiPcieTx->cmd, (__u64)ssiPcieTx->data);
         break;
   }
}

// SsiPcie_Read
// Called when the device is read from
// Returns read count on success. Error code on failure.
ssize_t SsiPcie_Read(struct file *filp, char *buffer, size_t count, loff_t *f_pos) {
   int           ret;
   __u32         buf[count / sizeof(__u32)];
   SsiPcieRx*    p64 = (SsiPcieRx *)buf;
   SsiPcieRx32*  p32 = (SsiPcieRx32*)buf;
   __u32       __user *     dp;
   __u32         maxSize;
   __u32         copyLength;
   __u32         largeMemoryModel;

   struct SsiDevice *ssiDevice = (struct SsiDevice *)filp->private_data;

   // Copy command structure from user space
   if ( copy_from_user(buf, buffer, count) ) {
     printk(KERN_WARNING "%s: Write: failed to copy command structure from user(%p) space. Maj=%i\n",
         MOD_NAME,
         buffer,
         ssiDevice->major);
     return ERROR;
   }

   largeMemoryModel = buf[0] == LargeMemoryModel;

   // Verify that size of passed structure and get variables from the correct structure.
   if ( !largeMemoryModel ) {
     // small memory model
     if ( count != sizeof(SsiPcieRx32) ) {
       printk(KERN_WARNING"%s: Read: passed size is not expected(%u) size(%u). Maj=%i\n",MOD_NAME, (unsigned)sizeof(SsiPcieRx32), (unsigned)count, ssiDevice->major);
       return(ERROR);
     } else {
       dp      = (__u32*)(0LL | p32->data);
       maxSize = p32->maxSize;
     }
   } else {
     // large memory model
     if ( count != sizeof(SsiPcieRx) ) {
       printk(KERN_WARNING"%s: Read: passed size is not expected(%u) size(%u). Maj=%i\n",MOD_NAME, (unsigned)sizeof(SsiPcieRx), (unsigned)count, ssiDevice->major);
       return(ERROR);
     } else {
       dp      = p64->data;
       maxSize = p64->maxSize;
     }
   }

   // No data is ready
   while ( ssiDevice->rxRead == ssiDevice->rxWrite ) {
      if ( filp->f_flags & O_NONBLOCK ) return(-EAGAIN);
      if ( ssiDevice->debug > 2 ) printk(KERN_DEBUG"%s: Read: going to sleep. Maj=%i\n",MOD_NAME,ssiDevice->major);
      if (wait_event_interruptible(ssiDevice->inq,(ssiDevice->rxRead != ssiDevice->rxWrite))) return (-ERESTARTSYS);
      if ( ssiDevice->debug > 2 ) printk(KERN_DEBUG"%s: Read: woke up. Maj=%i\n",MOD_NAME,ssiDevice->major);
   }

   // Report frame error
   if (ssiDevice->rxQueue[ssiDevice->rxRead]->error) {
      printk(KERN_WARNING "%s: Read: error encountered\n",MOD_NAME);
   }

   // User buffer is short
   if ( maxSize < ssiDevice->rxQueue[ssiDevice->rxRead]->length ) {
      printk(KERN_WARNING"%s: Read: user buffer is too small. Rx=%i, User=%i. Maj=%i\n",
         MOD_NAME, ssiDevice->rxQueue[ssiDevice->rxRead]->length, maxSize, ssiDevice->major);
      copyLength = maxSize;
      ssiDevice->rxQueue[ssiDevice->rxRead]->error |= 1;
   }
   else copyLength = ssiDevice->rxQueue[ssiDevice->rxRead]->length;

   // Copy to user
   if ( copy_to_user(dp, ssiDevice->rxQueue[ssiDevice->rxRead]->buffer, copyLength*4) ) {
      printk(KERN_WARNING"%s: Read: failed to copy to user. Maj=%i\n",MOD_NAME,ssiDevice->major);
      ret = ERROR;
   }
   else ret = copyLength;

   // Copy associated data
   if (largeMemoryModel) {
      p64->rxSize    = ssiDevice->rxQueue[ssiDevice->rxRead]->length;
      p64->lane      = ssiDevice->rxQueue[ssiDevice->rxRead]->lane;
      p64->vc        = ssiDevice->rxQueue[ssiDevice->rxRead]->vc;
      p64->error     = ssiDevice->rxQueue[ssiDevice->rxRead]->error;
      if ( ssiDevice->debug > 1 ) {
         printk(KERN_DEBUG"%s: Read: Words=%i, Lane=%i, VC=%i, error=%i, Addr=%p, Map=%p, Maj=%i\n",
               MOD_NAME, p64->rxSize, p64->lane, p64->vc, p64->error, (ssiDevice->rxQueue[ssiDevice->rxRead]->buffer),
               (void*)(ssiDevice->rxQueue[ssiDevice->rxRead]->dma),(unsigned)ssiDevice->major);
      }
   } else {
      p32->rxSize    = ssiDevice->rxQueue[ssiDevice->rxRead]->length;
      p32->lane      = ssiDevice->rxQueue[ssiDevice->rxRead]->lane;
      p32->vc        = ssiDevice->rxQueue[ssiDevice->rxRead]->vc;
      p32->error      = ssiDevice->rxQueue[ssiDevice->rxRead]->error;
      if ( ssiDevice->debug > 1 ) {
         printk(KERN_DEBUG"%s: Read: Words=%i, Lane=%i, VC=%i, error=%i, Addr=%p, Map=%p, Maj=%i\n",
               MOD_NAME, p32->rxSize, p32->lane, p32->vc, p32->error, (ssiDevice->rxQueue[ssiDevice->rxRead]->buffer),
               (void*)(ssiDevice->rxQueue[ssiDevice->rxRead]->dma),(unsigned)ssiDevice->major);
      }
   }

   // Copy command structure to user space
   if ( copy_to_user(buffer, buf, count) ) {
      printk(KERN_WARNING "%s: Write: failed to copy command structure to user(%p) space. Maj=%i\n",
            MOD_NAME,
            buffer,
            ssiDevice->major);
      return ERROR;
   }

   // Return entry to RX queue
   ssiDevice->reg->rxFree[ssiDevice->rxQueue[ssiDevice->rxRead]->lane] = ssiDevice->rxQueue[ssiDevice->rxRead]->dma; 

   if ( ssiDevice->debug > 1 ) printk(KERN_DEBUG"%s: Read: Added buffer %.8x to RX queue. Maj=%i\n",
      MOD_NAME,(__u32)(ssiDevice->rxQueue[ssiDevice->rxRead]->dma),ssiDevice->major);

   // Increment read pointer
   ssiDevice->rxRead = (ssiDevice->rxRead + 1) % (ssiDevice->rxBuffCnt+2);

   return(ret);
}

// SsiPcie_Ioctl
// Called when ioctl is called on the device
// Returns success.
int SsiPcie_Ioctl(struct inode *inode, struct file *filp, __u32 cmd, unsigned long arg) {
  printk(KERN_WARNING "%s: warning Ioctl is deprecated and no longer supported\n", MOD_NAME);
  return SUCCESS;
}

int my_Ioctl(struct file *filp, __u32 cmd, __u64 argument) {
   SsiPcieStatus  status;
   SsiPcieStatus *stat = &status;
   __u32          tmp;
   __u32          mask;
   __u32          x, y;
   __u32          found;
   __u32          bcnt;
   __u32          read;
   __u32          arg = argument & 0xffffffffLL;

   struct SsiDevice *ssiDevice = (struct SsiDevice *)filp->private_data;
   if (ssiDevice->debug > 1) printk(KERN_DEBUG "%s: entering my_Ioctl, arg(%llu)\n", MOD_NAME, argument);

   // Determine command
   switch ( cmd ) {

      // Status read
      case IOCTL_Read_Status:
        if (ssiDevice->debug > 0) printk(KERN_DEBUG "%s IOCTL_ReadStatus\n", MOD_NAME);

         // Write scratchpad
         ssiDevice->reg->scratch = SPAD_WRITE;

         // Read Values
         stat->Version = ssiDevice->reg->version;
         stat->ScratchPad = ssiDevice->reg->scratch;
         
         stat->SerialNumber[0] = ssiDevice->reg->serNumUpper;
         stat->SerialNumber[1] = ssiDevice->reg->serNumLower;
         
         for (x=0; x < 64; x++) {
            stat->BuildStamp[x] = ssiDevice->reg->BuildStamp[x];
         }          
         
         stat->CountReset = (ssiDevice->reg->cardRstStat >> 0) & 0x1;
         stat->CardReset  = (ssiDevice->reg->cardRstStat >> 1) & 0x1;
         
         stat->DmaSize = ssiDevice->dmaSize;
         stat->DmaLoopback = ssiDevice->reg->dmaLoopback;
         
         tmp = ssiDevice->reg->pciStat[0];
         stat->PciCommand = (tmp >> 16)&0xFFFF;
         stat->PciStatus  = tmp & 0xFFFF;

         tmp = ssiDevice->reg->pciStat[1];
         stat->PciDCommand = (tmp >> 16)&0xFFFF;
         stat->PciDStatus  = tmp & 0xFFFF;

         tmp = ssiDevice->reg->pciStat[2];
         stat->PciLCommand = (tmp >> 16)&0xFFFF;
         stat->PciLStatus  = tmp & 0xFFFF;

         tmp = ssiDevice->reg->pciStat[3];
         stat->PciLinkState = (tmp >> 24)&0x7;
         stat->PciFunction  = (tmp >> 16)&0x3;
         stat->PciDevice    = (tmp >>  8)&0x1F;
         stat->PciBus       = tmp&0xFF;   
         
         stat->BarSize    = ssiDevice->reg->barSize;
         stat->BarMask[0] = ssiDevice->reg->barMask[0];         
         stat->BarMask[1] = ssiDevice->reg->barMask[1];         
         stat->BarMask[2] = ssiDevice->reg->barMask[2];         
         stat->BarMask[3] = ssiDevice->reg->barMask[3];         

         stat->PciBaseHdwr  = ssiDevice->baseHdwr;
         stat->PciBaseLen   = ssiDevice->baseLen;         

         for (x=0; x <16; x++) { 
            tmp = ssiDevice->reg->rxFreeStat[x];
            stat->RxFreeFull[x]      = (tmp >> 31) & 0x1;
            stat->RxFreeValid[x]     = (tmp >> 30) & 0x1;
            stat->RxFreeFifoCount[x] = (tmp >> 0)  & 0x3FF;         
         }         
         
         stat->RxCount = ssiDevice->reg->rxCount;
         stat->RxWrite = ssiDevice->rxWrite;
         stat->RxRead  = ssiDevice->rxRead;
         
         tmp = ssiDevice->reg->rxStatus;
         stat->RxReadReady    = (tmp >> 31) & 0x1;
         stat->RxRetFifoCount = (tmp >> 0)  & 0x3FF;         
         
         tmp = ssiDevice->reg->txStat[0];
         for (x=0; x <16; x++) { 
            stat->TxDmaAFull[x] = (tmp >> x) & 0x1;
         }          
         
         tmp = ssiDevice->reg->txStat[1];
         stat->TxReadReady    = (tmp >> 31) & 0x1;
         stat->TxRetFifoCount = (tmp >> 0)  & 0x3FF;

         stat->TxCount = ssiDevice->reg->txCount;
         stat->TxWrite = ssiDevice->txWrite;
         stat->TxRead  = ssiDevice->txRead;

         // Copy to user
         if ((read = copy_to_user((__u32*)argument, stat, sizeof(SsiPcieStatus)))) {
            printk(KERN_WARNING "%s: Read Status: failed to copy %u to user. Maj=%i\n",
                MOD_NAME,
                read,
                ssiDevice->major);
            return ERROR;
         }

         return(SUCCESS);
         break;   
         
      // Count Reset
      case IOCTL_Count_Reset:         
         ssiDevice->reg->cardRstStat |= 0x1;//set the reset counter bit
         ssiDevice->reg->cardRstStat &= 0xFFFFFFFE;//clear the reset counter bit
         if (ssiDevice->debug > 0) printk(KERN_DEBUG "%s: Count reset\n", MOD_NAME);
         return(SUCCESS);
         break;         

      // Set Loopback
      case IOCTL_Set_Loop:
         ssiDevice->reg->dmaLoopback |= (0x1 << (arg&0xF));         
         if (ssiDevice->debug > 0) printk(KERN_DEBUG "%s: Set loopback for %u\n", MOD_NAME, arg);
         return(SUCCESS);
         break;

      // Clr Loopback
      case IOCTL_Clr_Loop:
         mask = 0xFFFFFFFF ^ (0x1 << (arg&0xF));  
         ssiDevice->reg->dmaLoopback &= mask;
         if (ssiDevice->debug > 0) printk(KERN_DEBUG "%s: Clr loopback for %u\n", MOD_NAME, arg);
         return(SUCCESS);
         break;
          
      // Set Debug
      case IOCTL_Set_Debug:
         ssiDevice->debug = arg;
         printk(KERN_WARNING "%s: debug set to %u\n", MOD_NAME, arg);
         return(SUCCESS);
         break;         

      // Dump Debug
      case IOCTL_Dump_Debug:

        if (ssiDevice->debug > 0) {
          printk(KERN_DEBUG "%s IOCTL_Dump_Debug\n", MOD_NAME);

          // Rx Buffers
          if ( ssiDevice->rxRead > ssiDevice->rxWrite )
            bcnt = (__u32)((int)(ssiDevice->rxWrite - ssiDevice->rxRead) + ssiDevice->rxBuffCnt + 2);
          else bcnt = (ssiDevice->rxWrite - ssiDevice->rxRead);
          printk(KERN_DEBUG"%s: Ioctl: Rx Queue contains %i out of %i buffers. Maj=%i.\n",MOD_NAME,bcnt,ssiDevice->rxBuffCnt,ssiDevice->major);

         // Rx Fifo 
         bcnt = 0;
         for (x=0; x < ssiDevice->dmaSize; x++) { 
            // Get the register
            tmp = ssiDevice->reg->rxFreeStat[x];
            // Check for FWFT valid
            if( ((tmp >> 30) & 0x1) == 0x1) bcnt++;
            // Check the FIFO fill count
            bcnt += ((tmp >> 0) & 0x3FF);       
         }           
         printk(KERN_DEBUG"%s: Ioctl: Rx Fifo contains %i out of %i buffers. Maj=%i.\n",MOD_NAME,bcnt,ssiDevice->rxBuffCnt,ssiDevice->major);

          // Tx Buffers
          if ( ssiDevice->txRead > ssiDevice->txWrite )
            bcnt = (__u32)((int)(ssiDevice->txWrite - ssiDevice->txRead) + ssiDevice->txBuffCnt + 2);
          else bcnt = (ssiDevice->txWrite - ssiDevice->txRead);
          printk(KERN_DEBUG"%s: Ioctl: Tx Queue contains %i out of %i buffers. Maj=%i.\n",MOD_NAME,bcnt,ssiDevice->txBuffCnt,ssiDevice->major);

          // Attempt to find missing tx buffers
          for (x=0; x < ssiDevice->txBuffCnt; x++) {
            found = 0;
            read  = ssiDevice->txRead;
            for (y=0; y < bcnt && read != ssiDevice->txWrite; y++) {
              if ( ssiDevice->txQueue[read] == ssiDevice->txBuffer[x] ) {
                found = 1;
                break;
              }
              read = (read+1)%(ssiDevice->txBuffCnt+2);
            }
            if ( ! found ) 
              printk(KERN_DEBUG"%s: Ioctl: Tx Buffer %p is missing! Lane=%i, Vc=%i, Length=%i, Maj=%i\n",MOD_NAME,
                  ssiDevice->txBuffer[x]->buffer, ssiDevice->txBuffer[x]->lane, ssiDevice->txBuffer[x]->vc,
                  ssiDevice->txBuffer[x]->length, ssiDevice->major);
            else
              printk(KERN_DEBUG"%s: Ioctl: Tx Buffer %p found. Maj=%i\n",MOD_NAME,ssiDevice->txBuffer[x]->buffer,ssiDevice->major);
          }

          // Queue dump
          read  = ssiDevice->txRead;
          for (y=0; y < bcnt && read != ssiDevice->txWrite; y++) {
            printk(KERN_DEBUG"%s: Ioctl: Tx Queue Entry %p. Maj=%i\n",MOD_NAME, ssiDevice->txQueue[y]->buffer,ssiDevice->major);
            read = (read+1)%(ssiDevice->txBuffCnt+2);
          }
        } else {
          printk(KERN_WARNING "%s: attempt to dump debug with debug level of zero\n", MOD_NAME);
        }
        return(SUCCESS);
         break;

      // No Operation
      case IOCTL_NOP:
         asm("nop");//no operation function
         if (ssiDevice->debug > 0) printk(KERN_WARNING "%s: NOP to %u\n", MOD_NAME, arg);
         return(SUCCESS);
         break;            
         
      default:
         return(ERROR);
         break;
   }
}

// IRQ Handler
static irqreturn_t SsiPcie_IRQHandler(int irq, void *dev_id, struct pt_regs *regs) {
   __u32        stat;
   __u32        descA;
   __u32        descB;
   __u32        idx;
   __u32        next;
   irqreturn_t ret;

   struct SsiDevice *ssiDevice = (struct SsiDevice *)dev_id;

   // Read IRQ Status
   stat = ssiDevice->reg->irq;

   // Is this the source
   if ( (stat & 0x2) != 0 ) {

      if ( ssiDevice->debug > 0 ) printk(KERN_DEBUG"%s: Irq: IRQ Called. Maj=%i\n", MOD_NAME,ssiDevice->major);

      // Disable interrupts
      ssiDevice->reg->irq = 0;

      // Read Tx completion status
      stat = ssiDevice->reg->txStat[1];

      // Tx Data is ready
      if ( (stat & 0x80000000) != 0 ) {

         do {

            // Read dma value
            stat = ssiDevice->reg->txRead;
            
            if( (stat & 0x1) == 0x1 ) {

               if ( ssiDevice->debug > 0 ) printk(KERN_DEBUG"%s: Irq: Return TX Status Value %.8x. Maj=%i\n",MOD_NAME,stat,ssiDevice->major);
            
               // Find TX buffer entry
               for ( idx=0; idx < ssiDevice->txBuffCnt; idx++ ) {
                  if ( ssiDevice->txBuffer[idx]->dma == (stat & 0xFFFFFFFC) ) break;
               }

               // Entry was found
               if ( idx < ssiDevice->txBuffCnt ) {

                  // Return to queue
                  next = (ssiDevice->txWrite+1) % (ssiDevice->txBuffCnt+2);
                  if ( next == ssiDevice->txRead ) printk(KERN_WARNING"%s: Irq: Tx queue pointer collision. Maj=%i\n",MOD_NAME,ssiDevice->major);
                  ssiDevice->txQueue[ssiDevice->txWrite] = ssiDevice->txBuffer[idx];
                  //printk(KERN_WARNING"%s: Irq: ssiDevice->txWrite = next=%i\n",MOD_NAME,next);
                  ssiDevice->txWrite = next;

                  // Wake up any writers
                  wake_up_interruptible(&(ssiDevice->outq));
               }
               else printk(KERN_WARNING"%s: Irq: Failed to locate TX descriptor %.8x. Maj=%i\n",MOD_NAME,(__u32)(stat&0xFFFFFFFC),ssiDevice->major);
            }
            
         // Repeat while next valid flag is set
         } while ( (stat & 0x1) == 0x1 );
      }

      // Read Rx completion status
      stat = ssiDevice->reg->rxStatus;

      // Data is ready
      if ( (stat & 0x80000000) != 0 ) {

         do {
            
            // Read descriptor
            descA = ssiDevice->reg->rxRead[0];
            asm("nop");//no operation function to force sequential MEM IO read (first rxRead[0] then rxRead[1])
            descB = ssiDevice->reg->rxRead[1];
            
            if( (descB & 0x1) == 0x1 ) {            
            
               // Find RX buffer entry
               for ( idx=0; idx < ssiDevice->rxBuffCnt; idx++ ) {
                  if ( ssiDevice->rxBuffer[idx]->dma == (descB & 0xFFFFFFFC) ) break;
               }

               // Entry was found
               if ( idx < ssiDevice->rxBuffCnt ) {

                  // Drop data if device is not open
                  if ( ssiDevice->isOpen ) {

                     // Setup descriptor
                     ssiDevice->rxBuffer[idx]->lane   = (descA & 0xF0000000) >> 28;// Bits 31:28 = Lane
                     ssiDevice->rxBuffer[idx]->vc     = (descA & 0x0F000000) >> 24;// Bits 27:24 = VC
                     ssiDevice->rxBuffer[idx]->length = (descA & 0x00FFFFFF) >> 0; // Bits 23:00 = Length
                     ssiDevice->rxBuffer[idx]->error  = (descB & 0x00000002) >> 1; // Bits 01:01 = error
                     
                     if ( ssiDevice->debug > 0 ) {
                        printk(KERN_DEBUG "%s: Irq: Rx Words=%i, Lane=%i, VC=%i, error=%i, Addr=%p, Map=%p\n",
                           MOD_NAME, ssiDevice->rxBuffer[idx]->length, ssiDevice->rxBuffer[idx]->lane, ssiDevice->rxBuffer[idx]->vc, 
                           ssiDevice->rxBuffer[idx]->error, ssiDevice->rxBuffer[idx]->buffer, (void*)(ssiDevice->rxBuffer[idx]->dma));
                     }

                     // Return to Queue
                     next = (ssiDevice->rxWrite+1) % (ssiDevice->rxBuffCnt+2);
                     if ( next == ssiDevice->rxRead ) printk(KERN_WARNING"%s: Irq: Rx queue pointer collision. Maj=%i\n",MOD_NAME,ssiDevice->major);
                     ssiDevice->rxQueue[ssiDevice->rxWrite] = ssiDevice->rxBuffer[idx];
                     ssiDevice->rxWrite = next;

                     // Wake up any readers
                     wake_up_interruptible(&(ssiDevice->inq));
                  }
                  
                  // Return entry to FPGA if device is not open
                  else ssiDevice->reg->rxFree[(descA >> 28) & 0xF] = (descB & 0xFFFFFFFC); 

               } else printk(KERN_WARNING "%s: Irq: Failed to locate RX descriptor %.8x. Maj=%i\n",MOD_NAME,(__u32)(descA&0xFFFFFFFC),ssiDevice->major);
            }
         // Repeat while next valid flag is set
         } while ( (descB & 0x1) == 0x1 );
      }

      // Enable interrupts
      if ( ssiDevice->debug > 0 ) printk(KERN_DEBUG"%s: Irq: Done. Maj=%i\n", MOD_NAME,ssiDevice->major);
      ssiDevice->reg->irq = 1;
      ret = IRQ_HANDLED;
   }
   else ret = IRQ_NONE;
   return(ret);
}

// Poll/Select
static __u32 SsiPcie_Poll(struct file *filp, poll_table *wait ) {
   __u32 mask    = 0;
   __u32 readOk  = 0;
   __u32 writeOk = 0;

   struct SsiDevice *ssiDevice = (struct SsiDevice *)filp->private_data;

   poll_wait(filp,&(ssiDevice->inq),wait);
   poll_wait(filp,&(ssiDevice->outq),wait);

   if ( ssiDevice->rxWrite != ssiDevice->rxRead ) {
      mask |= POLLIN | POLLRDNORM; // Readable
      readOk = 1;
   }
   if ( ssiDevice->txWrite != ssiDevice->txRead ) {
      mask |= POLLOUT | POLLWRNORM; // Writable
      writeOk = 1;
   }

   //if ( ssiDevice->debug > 3 ) printk(KERN_DEBUG"%s: Poll: ReadOk=%i, WriteOk=%i Maj=%i\n", MOD_NAME,readOk,writeOk,ssiDevice->major);
   return(mask);
}

// Probe device
static int SsiPcie_Probe(struct pci_dev *pcidev, const struct pci_device_id *dev_id) {
   int i, res, idx;
   dev_t chrdev = 0;
   struct SsiDevice *ssiDevice;
   struct pci_device_id *id = (struct pci_device_id *) dev_id;

   // We keep device instance number in id->driver_data
   id->driver_data = -1;

   // Find empty structure
   for (i = 0; i < MAX_PCI_DEVICES; i++) {
      if (gSsiDevices[i].baseHdwr == 0) {
         id->driver_data = i;
         break;
      }
   }

   // Overflow
   if (id->driver_data < 0) {
      printk(KERN_WARNING "%s: Probe: Too Many Devices.\n", MOD_NAME);
      return -EMFILE;
   }
   ssiDevice = &gSsiDevices[id->driver_data];

   // Allocate device numbers for character device.
   res = alloc_chrdev_region(&chrdev, 0, 1, MOD_NAME);
   if (res < 0) {
      printk(KERN_WARNING "%s: Probe: Cannot register char device\n", MOD_NAME);
      return res;
   }

   // Init device
   cdev_init(&ssiDevice->cdev, &SsiPcie_Intf);

   // Initialize device structure
   ssiDevice->major         = MAJOR(chrdev);
   ssiDevice->cdev.owner    = THIS_MODULE;
   ssiDevice->cdev.ops      = &SsiPcie_Intf;
   ssiDevice->debug         = 0;
   ssiDevice->isOpen        = 0;

   // Add device
   if ( cdev_add(&ssiDevice->cdev, chrdev, 1) ) 
      printk(KERN_WARNING "%s: Probe: Error adding device Maj=%i\n", MOD_NAME,ssiDevice->major);

   // Enable devices
   pci_enable_device(pcidev);

   // Get Base Address of registers from pci structure.
   ssiDevice->baseHdwr = pci_resource_start (pcidev, CORE_BAR);
   ssiDevice->baseLen  = pci_resource_len (pcidev, CORE_BAR);

   // Remap the I/O register block so that it can be safely accessed.
   ssiDevice->reg = (struct SsiPcieReg *)ioremap_nocache(ssiDevice->baseHdwr, ssiDevice->baseLen);
   if (! ssiDevice->reg ) {
      printk(KERN_WARNING"%s: Init: Could not remap memory Maj=%i.\n", MOD_NAME,ssiDevice->major);
      return (ERROR);
   }

   // Try to gain exclusive control of memory
   if (check_mem_region(ssiDevice->baseHdwr, ssiDevice->baseLen) < 0 ) {
      printk(KERN_WARNING"%s: Init: Memory in use Maj=%i.\n", MOD_NAME,ssiDevice->major);
      return (ERROR);
   }

   // Remove card reset, bit 1 of cardRstStat register
   ssiDevice->reg->cardRstStat &= 0xFFFFFFFD;
   asm("nop");
   idx = ssiDevice->reg->cardRstStat;
   if( (idx & 0x2) == 0x2 ){
      printk(KERN_WARNING"%s: Init: Card Reset Status Register error. cardRstStat=%0x%x\n",MOD_NAME,ssiDevice->reg->cardRstStat);
      return ERROR;
   }  
   
   // Poll the firmware register to get number of DMA channels
   ssiDevice->dmaSize = ssiDevice->reg->dmaSize;
   if( (ssiDevice->dmaSize < 1) || (ssiDevice->dmaSize > 16) ){
      printk(KERN_WARNING"%s: Init: Invalid DMA Size. dmaSize=%i\n",MOD_NAME,ssiDevice->dmaSize);
      return ERROR;
   }

   request_mem_region(ssiDevice->baseHdwr, ssiDevice->baseLen, MOD_NAME);
   printk(KERN_INFO "%s: Probe: Found card. Version=0x%x, Maj=%i\n", MOD_NAME,ssiDevice->reg->version,ssiDevice->major);

   // Get IRQ from pci_dev structure. 
   ssiDevice->irq = pcidev->irq;
   printk(KERN_INFO "%s: Init: IRQ %d Maj=%i\n", MOD_NAME, ssiDevice->irq,ssiDevice->major);

   // Request IRQ from OS.
   if (request_irq(
       ssiDevice->irq,
       SsiPcie_IRQHandler,
       IRQF_SHARED,
       MOD_NAME,
       (void*)ssiDevice) < 0 ) {
      printk(KERN_WARNING"%s: Init: Unable to allocate IRQ. Maj=%i",MOD_NAME,ssiDevice->major);
      return (ERROR);
   }

   // Init TX Buffers
   ssiDevice->txBuffSize = DEF_TX_BUF_SIZE;
   ssiDevice->txBuffCnt  = DEF_TX_BUF_CNT;
   ssiDevice->txBuffer   = (struct TxBuffer **)kmalloc(ssiDevice->txBuffCnt * sizeof(struct TxBuffer *),GFP_KERNEL);
   ssiDevice->txQueue    = (struct TxBuffer **)kmalloc((ssiDevice->txBuffCnt+2) * sizeof(struct TxBuffer *),GFP_KERNEL);

   for ( idx=0; idx < ssiDevice->txBuffCnt; idx++ ) {
      ssiDevice->txBuffer[idx] = (struct TxBuffer *)kmalloc(sizeof(struct TxBuffer ),GFP_KERNEL);
      if ((ssiDevice->txBuffer[idx]->buffer = pci_alloc_consistent(pcidev,ssiDevice->txBuffSize,&(ssiDevice->txBuffer[idx]->dma))) == NULL ) {
         printk(KERN_WARNING"%s: Init: unable to allocate tx buffer. Maj=%i\n",MOD_NAME,ssiDevice->major);
         return ERROR;
      }
      ssiDevice->txQueue[idx] = ssiDevice->txBuffer[idx];
   }
   ssiDevice->txWrite = ssiDevice->txBuffCnt;
   ssiDevice->txRead  = 0;

   // Set max frame size, clear rx buffer reset
   ssiDevice->rxBuffSize = DEF_RX_BUF_SIZE;
   ssiDevice->reg->rxMaxFrame = ssiDevice->rxBuffSize | 0x80000000;

   // Init RX Buffers
   ssiDevice->rxBuffCnt  = DEF_RX_BUF_CNT;
   ssiDevice->rxBuffer   = (struct RxBuffer **)kmalloc(ssiDevice->rxBuffCnt * sizeof(struct RxBuffer *),GFP_KERNEL);
   ssiDevice->rxQueue    = (struct RxBuffer **)kmalloc((ssiDevice->rxBuffCnt+2) * sizeof(struct RxBuffer *),GFP_KERNEL);

   for ( idx=0; idx < ssiDevice->rxBuffCnt; idx++ ) {
      ssiDevice->rxBuffer[idx] = (struct RxBuffer *)kmalloc(sizeof(struct RxBuffer ),GFP_KERNEL);
      if ((ssiDevice->rxBuffer[idx]->buffer = pci_alloc_consistent(pcidev,ssiDevice->rxBuffSize,&(ssiDevice->rxBuffer[idx]->dma))) == NULL ) {
         printk(KERN_WARNING"%s: Init: unable to allocate tx buffer. Maj=%i\n",MOD_NAME,ssiDevice->major);
         return ERROR;
      };

      // Add to RX queue (evenly distributed to all free list RX FIFOs)
      ssiDevice->reg->rxFree[idx % ssiDevice->dmaSize] = ssiDevice->rxBuffer[idx]->dma;     
   }
   ssiDevice->rxRead  = 0;
   ssiDevice->rxWrite = 0;

   // Init queues
   init_waitqueue_head(&ssiDevice->inq);
   init_waitqueue_head(&ssiDevice->outq);

   // Enable interrupts
   ssiDevice->reg->irq = 1;

   printk(KERN_INFO"%s: Init: Driver is loaded. Maj=%i\n", MOD_NAME,ssiDevice->major);
   return SUCCESS;
}

// Remove
static void SsiPcie_Remove(struct pci_dev *pcidev) {
   __u32 idx;
   int  i;
   struct SsiDevice *ssiDevice = NULL;

   // Look for matching device
   for (i = 0; i < MAX_PCI_DEVICES; i++) {
      if ( gSsiDevices[i].baseHdwr == pci_resource_start(pcidev, 0)) {
         ssiDevice = &gSsiDevices[i];
         break;
      }
   }

   // Device not found
   if (ssiDevice == NULL) {
      printk(KERN_WARNING "%s: Remove: Device Not Found.\n", MOD_NAME);
   }
   else {

      // Disable interrupts
      ssiDevice->reg->irq = 0;

      // Clear RX buffer
      ssiDevice->reg->rxMaxFrame = 0;

      // Free TX Buffers
      for ( idx=0; idx < ssiDevice->txBuffCnt; idx++ ) {
         pci_free_consistent(pcidev,ssiDevice->txBuffSize,ssiDevice->txBuffer[idx]->buffer,ssiDevice->txBuffer[idx]->dma);
         kfree(ssiDevice->txBuffer[idx]);
      }
      kfree(ssiDevice->txBuffer);
      kfree(ssiDevice->txQueue);

      // Free RX Buffers
      for ( idx=0; idx < ssiDevice->rxBuffCnt; idx++ ) {
         pci_free_consistent(pcidev,ssiDevice->rxBuffSize,ssiDevice->rxBuffer[idx]->buffer,ssiDevice->rxBuffer[idx]->dma);
         kfree(ssiDevice->rxBuffer[idx]);
      }
      kfree(ssiDevice->rxBuffer);
      kfree(ssiDevice->rxQueue);

      // Set card reset, bit 1 of cardRstStat register
      ssiDevice->reg->cardRstStat |= 0x00000002;

      // Release memory region
      release_mem_region(ssiDevice->baseHdwr, ssiDevice->baseLen);

      // Release IRQ
      free_irq(ssiDevice->irq, ssiDevice);

      // Unmap
      iounmap(ssiDevice->reg);

      // Unregister Device Driver
      cdev_del(&ssiDevice->cdev);
      unregister_chrdev_region(MKDEV(ssiDevice->major,0), 1);

      // Disable device
      pci_disable_device(pcidev);
      ssiDevice->baseHdwr = 0;
      printk(KERN_INFO"%s: Remove: Driver is unloaded. Maj=%i\n", MOD_NAME,ssiDevice->major);
   }
}

// Init Kernel Module
static int SsiPcie_Init(void) {

   /* Allocate and clear memory for all devices. */
   memset(gSsiDevices, 0, sizeof(struct SsiDevice)*MAX_PCI_DEVICES);

   printk(KERN_INFO"%s: Init: SsiPcie Init.\n", MOD_NAME);

   // Register driver
   return(pci_register_driver(&SsiPcieDriver));
}

// Exit Kernel Module
static void SsiPcie_Exit(void) {
   printk(KERN_INFO"%s: Exit: SsiPcie Exit.\n", MOD_NAME);
   pci_unregister_driver(&SsiPcieDriver);
}

// Memory map
int SsiPcie_Mmap(struct file *filp, struct vm_area_struct *vma) {

   struct SsiDevice *ssiDevice = (struct SsiDevice *)filp->private_data;

   unsigned long offset = vma->vm_pgoff << PAGE_SHIFT;
   unsigned long physical = ((unsigned long) ssiDevice->baseHdwr) + offset;
   unsigned long vsize = vma->vm_end - vma->vm_start;
   int result;

   // Check bounds of memory map
   if (vsize > ssiDevice->baseLen) {
      printk(KERN_WARNING"%s: Mmap: mmap vsize %08x, baseLen %08x. Maj=%i\n", MOD_NAME,
         (unsigned int) vsize, (unsigned int) ssiDevice->baseLen,ssiDevice->major);
      return -EINVAL;
   }

   result = io_remap_pfn_range(vma, vma->vm_start, physical >> PAGE_SHIFT,
            vsize, vma->vm_page_prot);

   if (result) return -EAGAIN;
  
   vma->vm_ops = &SsiPcie_VmOps;
   SsiPcie_VmOpen(vma);
   return 0;  
}

void SsiPcie_VmOpen(struct vm_area_struct *vma) { }

void SsiPcie_VmClose(struct vm_area_struct *vma) { }

// Flush queue
int SsiPcie_Fasync(int fd, struct file *filp, int mode) {
   struct SsiDevice *ssiDevice = (struct SsiDevice *)filp->private_data;
   return fasync_helper(fd, filp, mode, &(ssiDevice->async_queue));
}
