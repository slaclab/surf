#include "globals.hpp"

void loopback(stream<axiWord> &parser2loopback, stream<axiWord> &loopback2merge)
{
#pragma HLS pipeline II=1 enable_flush
   axiWord inputWord = {0, 0, 0, 0};
   if (!parser2loopback.empty()) {
      parser2loopback.read(inputWord);
      loopback2merge.write(inputWord);
   }
}
