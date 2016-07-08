#include "ssi_printf.h"
#include "printf.h"
#include "xil_types.h"
#include "xil_io.h"

static struct ssi_printf_type ssi_printf_data;

void ssi_putc ( void* p, char c) {
   struct ssi_printf_type * pp = (struct ssi_printf_type *)p;

   // pack into 32-bits
   pp->tmp += (c << (pp->tmpCnt*8));
   pp->tmpCnt += 1;

   // 32-bit value ready or newline
   if ( pp->tmpCnt == 4 || c == '\n' ) {

      // Axi-stream, send tlast if newline
      putfsl(pp->tmp,0);
      if ( c == '\n' ) cputfsl(0,0);

      pp->tmp = 0;
      pp->tmpCnt = 0;
   }
   
   // Dual port ram buffer if enabled
   if ( pp->buffSize > 0 ) {
      Xil_Out8(pp->buffBase+4+pp->buffPtr, c);

      // Adjust pointer
      pp->buffPtr++;
      if ( pp->buffPtr == (pp->buffSize*4-4) ) 
         pp->buffPtr = 0;

      // Adjust total
      if ( pp->buffTot < (pp->buffSize*4-4) ) 
         pp->buffTot++;

      // Update tracking
      Xil_Out32(pp->buffBase, pp->buffTot << 16 | pp->buffPtr);
   }
   
}

void ssi_printf_init(uint32_t buffBase, uint16_t buffSize) {
   ssi_printf_data.tmpCnt   = 0;
   ssi_printf_data.tmp      = 0;
   ssi_printf_data.buffBase = buffBase;
   ssi_printf_data.buffSize = buffSize;
   ssi_printf_data.buffPtr  = 0;
   ssi_printf_data.buffTot  = 0;

   cputfsl(0,0);

   if ( buffSize > 0 ) {
      Xil_Out32(buffBase, 0);
      memset((void*)buffBase, 0, buffSize*4);
   }

   init_printf(&ssi_printf_data,ssi_putc);
}

