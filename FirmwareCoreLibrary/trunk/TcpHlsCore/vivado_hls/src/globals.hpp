#ifndef GLOBALS_HPP_
#define GLOBALS_HPP_

#include <stdio.h>
#include <iostream>
#include <fstream>
#include <string>
#include <math.h>
#include <stdint.h>
#include <cstdlib>

#include <hls_stream.h>
#include <ap_int.h>

using namespace hls;

#define NUM_MERGE_STREAMS 3
#define LOG2CEIL_NUM_MERGE_STREAMS 2

struct axiWord
{
   ap_uint<64>  data;
   ap_uint<8>   keep;
   ap_uint<128> user;
   ap_uint<1>   last;
};

void TcpHlsCore(
   stream<axiWord> &sXMac, 
   stream<ap_uint<32> > &queryIP, 
   stream<axiWord> &mXMac, 
   stream<ap_uint<48> > &returnMAC,
   ap_uint<48> myMacAddr,
   uint32_t myIpAddr);

#endif // GLOBALS_H_ not defined

