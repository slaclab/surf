#include "globals.hpp"
#include "ip_handler.hpp"
#include "arp_reply.hpp"
#include "icmp_server.hpp"
#include "loopback.hpp"
#include "merge.hpp"

void TcpHlsCore(
   stream<axiWord> &sXMac, 
   stream<ap_uint<32> > &queryIP, 
   stream<axiWord> &mXMac, 
   stream<ap_uint<48> > &returnMAC,
   ap_uint<48> myMacAddr,
   uint32_t myIpAddr) {
   
   // Allow parallel loops to convert data arrays into FIFOs interfaces
   #pragma HLS dataflow interval=1

   // Set the XMAC's input and output ports as AXI4-Stream   
   #pragma HLS INTERFACE port=sXMac axis
   #pragma HLS INTERFACE port=mXMac axis

   static stream<axiWord> parser2arp("parser2arp");
   static stream<axiWord> parser2icmp("parser2icmp");
   static stream<axiWord> parser2loopback("parser2loopback");

   #pragma HLS STREAM variable=parser2arp       depth=16
   #pragma HLS STREAM variable=parser2icmp      depth=16
   #pragma HLS STREAM variable=parser2loopback  depth=16

   static stream<axiWord> mod2merge[NUM_MERGE_STREAMS];
#pragma HLS STREAM variable=mod2merge depth=16

   parser(sXMac, parser2arp, parser2icmp, parser2loopback);
   arp_server(parser2arp, queryIP, mod2merge[0], returnMAC,myMacAddr,myIpAddr);
   icmp_server(parser2icmp, mod2merge[1]);
   loopback(parser2loopback, mod2merge[2]);
   merge(mod2merge, mXMac);
}

