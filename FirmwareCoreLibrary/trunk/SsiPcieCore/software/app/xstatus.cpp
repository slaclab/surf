//////////////////////////////////////////////////////////////////////////////
// This file is part of 'SLAC SSI PCI-E Core'.
// It is subject to the license terms in the LICENSE.txt file found in the 
// top-level directory of this distribution and at: 
//    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
// No part of 'SLAC SSI PCI-E Core', including this file, 
// may be copied, modified, propagated, or distributed except according to 
// the terms contained in the LICENSE.txt file.
//////////////////////////////////////////////////////////////////////////////

#include <sys/types.h>
#include <sys/ioctl.h>
#include <unistd.h>
#include <stdio.h>
#include <termios.h>
#include <fcntl.h>
#include <sstream>
#include <string>
#include <iomanip>
#include <iostream>
#include <string.h>
#include <stdlib.h>

#include "../include/SsiPcieMod.h"
#include "../include/SsiPcieWrap.h"
#define DEVNAME "/dev/SsiPcie0"

using namespace std;

int main (int argc, char **argv) {
   SsiPcieStatus status;
   int           s;
   int           ret;
   int           x;
   int           DmaSize;

   if ( (s = open(DEVNAME, O_RDWR)) <= 0 ) {
      cout << "Error opening file" << endl;
      return(1);
   }

   cout << "Setting debug level" << endl;
   ssipcie_setDebug(s, 5);

   memset(&status,0,sizeof(SsiPcieStatus));
   ret = ssipcie_status(s, &status);   
   DmaSize = (int) status.DmaSize;
   
   cout << endl;
   cout << "Read SSI PCIe Card Status:" << hex << uppercase << endl << endl;
   
   __u64 SerialNumber = status.SerialNumber[0];
   SerialNumber = SerialNumber << 32;
   SerialNumber |= status.SerialNumber[1];  
   
   cout << "           Version: 0x" << setw(8) << setfill('0') << status.Version << endl;
   cout << "      SerialNumber: 0x" << setw(16)<< setfill('0') << SerialNumber << endl;
   cout << "        BuildStamp: "   << string((char *)status.BuildStamp)  << endl;  
   cout << "        CountReset: 0x" << setw(1) << setfill('0') << status.CountReset << endl;   
   cout << "         CardReset: 0x" << setw(1) << setfill('0') << status.CardReset << endl;   
   cout << "        ScratchPad: 0x" << setw(8) << setfill('0') << status.ScratchPad << endl;
   cout << "           DmaSize: 0x" << setw(1) << setfill('0') << status.DmaSize << endl;
   cout << "       DmaLoopback: 0x" << setw(4) << setfill('0') << status.DmaLoopback << endl; 
   cout << "           BarSize: 0x" << setw(1) << setfill('0') << status.BarSize << endl;
   for(x=0;x<(int)status.BarSize;x++){
      cout << "        BarMask["<<x<<"]: 0x" << setw(8) << setfill('0') << status.BarMask[x] << endl; 
   }      
   cout << endl;
   
   cout << "        TxDmaAFull["<<DmaSize-1<<":0]: ";        
   for(x=0;x<DmaSize;x++){
      cout << setw(1) << setfill('0') << status.TxDmaAFull[15-x];            
      if(x!=DmaSize-1) cout << ", "; else cout << endl;
   }
   cout << "         TxDmaReadReady: 0x" << setw(1) << setfill('0') << status.TxReadReady << endl;
   cout << "      TxDmaRetFifoCount: 0x" << setw(3) << setfill('0') << status.TxRetFifoCount << endl;
   cout << "             TxDmaCount: 0x" << setw(8) << setfill('0') << status.TxCount << endl;
   cout << "             TxDmaWrite: 0x" << setw(2) << setfill('0') << status.TxWrite << endl;
   cout << "              TxDmaRead: 0x" << setw(2) << setfill('0') << status.TxRead  << endl;
   cout << endl;   
   
   cout << "     RxDmaFreeFull["<<DmaSize-1<<":0]: ";  
   for(x=0;x<DmaSize;x++){
      cout << setw(1) << setfill('0') << status.RxFreeFull[15-x];           
      if(x!=DmaSize-1) cout << ", "; else cout << endl;
   }
   
   cout << "    RxDmaFreeValid["<<DmaSize-1<<":0]: ";  
   for(x=0;x<DmaSize;x++){
      cout << setw(1) << setfill('0') << status.RxFreeValid[15-x];             
      if(x!=DmaSize-1) cout << ", "; else cout << endl;
   }
   
   cout << "RxDmaFreeFifoCount["<<DmaSize-1<<":0]: ";  
   for(x=0;x<DmaSize;x++){
      cout << "0x" << setw(1) << setfill('0') << status.RxFreeFifoCount[15-x];            
      if(x!=DmaSize-1) cout << ", "; else cout << endl;
   }       
   cout << "         RxDmaReadReady: 0x" << setw(1) << setfill('0') << status.RxReadReady << endl;
   cout << "      RxDmaRetFifoCount: 0x" << setw(3) << setfill('0') << status.RxRetFifoCount << endl;   
   cout << "             RxDmaCount: 0x" <<  setw(8) << setfill('0') << status.RxCount << endl;
   cout << "             RxDmaWrite: 0x" <<  setw(2) << setfill('0') << status.RxWrite << endl;
   cout << "              RxDmaRead: 0x" <<  setw(2) << setfill('0') << status.RxRead  << endl;   
   cout << endl;   
     
   cout << "          PciCommand: 0x" << setw(4) << setfill('0') << status.PciCommand << endl;
   cout << "           PciStatus: 0x" << setw(4) << setfill('0') << status.PciStatus << endl;
   cout << "         PciDCommand: 0x" << setw(4) << setfill('0') << status.PciDCommand << endl;
   cout << "          PciDStatus: 0x" << setw(4) << setfill('0') << status.PciDStatus << endl;
   cout << "         PciLCommand: 0x" << setw(4) << setfill('0') << status.PciLCommand << endl;
   cout << "          PciLStatus: 0x" << setw(4) << setfill('0') << status.PciLStatus << endl;
   cout << "        PciLinkState: 0x" << setw(1) << setfill('0') << status.PciLinkState << endl;
   cout << "         PciFunction: 0x" << setw(1) << setfill('0') << status.PciFunction << endl;
   cout << "           PciDevice: 0x" << setw(1) << setfill('0') << status.PciDevice << endl;
   cout << "              PciBus: 0x" << setw(2) << setfill('0') << status.PciBus << endl;
   cout << "         PciBaseAddr: 0x" << setw(8) << setfill('0') << status.PciBaseHdwr << endl;
   cout << "       PciBaseLength: 0x" << setw(8) << setfill('0') << status.PciBaseLen << endl;     
   cout << endl;   
      
   ssipcie_dumpDebug(s);

   cout << "Clearing debug level" << endl;
   ssipcie_setDebug(s, 0);

   close(s);
}
