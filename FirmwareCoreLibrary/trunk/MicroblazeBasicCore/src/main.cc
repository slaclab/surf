#include <stdio.h>
#include <string.h>

#include "xil_types.h"
#include "xil_io.h"

#define BUS_OFFSET  0x80000000
#define AXI_VERSION (BUS_OFFSET+0x00000000)
#define AXI_MEMORY  (BUS_OFFSET+0x00020000)

int main() {
   
   u32 i;
   u32 value;
   char myString[64] = "hello world";

   // Copy the "hello world" string to memory via memcpy()
   u32 *memAddr = (u32 *)(BUS_OFFSET+AXI_MEMORY);
   memcpy(memAddr,(u32 *)myString,sizeof(myString));
   
   // Read/write via xil_io.h's functions
   for(i=0;i<64;i++){
      // Get the build string from the AXI Version module
      value = Xil_In32(AXI_MEMORY + 0x800 + (i*4));
      // Echo the build string into the generic AXI-Lite memory
      Xil_Out32( (AXI_MEMORY + 0x800 + (i*4)), value);
   }
   
   return 0;
}
