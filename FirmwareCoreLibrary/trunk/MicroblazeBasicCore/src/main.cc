
#include <stdio.h>
#include "xparameters.h"
#include "xil_cache.h"
int main() 
{
   // HERE!!!!

   Xil_ICacheEnable();
   Xil_DCacheEnable();
   Xil_DCacheDisable();
   Xil_ICacheDisable();
   return 0;
}
