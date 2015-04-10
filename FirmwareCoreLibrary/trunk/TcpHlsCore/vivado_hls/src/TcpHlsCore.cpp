#include "globals.hpp"
#include "ip_handler.hpp"
#include "arp_reply.hpp"
#include "icmp_server.hpp"
#include "loopback.hpp"
#include "merge.hpp"

void TcpHlsCore(stream<axiWord> &inData, stream<ap_uint<32> > &queryIP, stream<axiWord> &outData, stream<ap_uint<48> > &returnMAC) {
	#pragma HLS dataflow interval=1

	#pragma HLS INTERFACE port=inData axis
	#pragma HLS INTERFACE port=outData axis

   static stream<axiWord> parser2arp("parser2arp");
   static stream<axiWord> parser2icmp("parser2icmp");
   static stream<axiWord> parser2loopback("parser2loopback");

	#pragma HLS STREAM variable=parser2arp 		depth=16
	#pragma HLS STREAM variable=parser2icmp 	depth=16
	#pragma HLS STREAM variable=parser2loopback depth=16

   static stream<axiWord> mod2merge[NUM_MERGE_STREAMS];
#pragma HLS STREAM variable=mod2merge depth=16

   parser(inData, parser2arp, parser2icmp, parser2loopback);
   arp_server(parser2arp, queryIP, mod2merge[0], returnMAC);
   icmp_server(parser2icmp, mod2merge[1]);
   loopback(parser2loopback, mod2merge[2]);
   merge(mod2merge, outData);
}

