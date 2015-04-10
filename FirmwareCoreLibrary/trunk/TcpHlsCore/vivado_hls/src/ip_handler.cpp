#include "globals.hpp"
#include "ip_handler.hpp"
#include <ap_shift_reg.h>

using namespace hls;

void ethernetDetection(
      stream<axiWord> &inData,
      stream<axiWord> &parser2arp,
      stream<axiWord> &macDetect2lengthCut)
{
#pragma HLS pipeline II=1 enable_flush

   static enum adState { ARPDETECT_IDLE = 0, ARPDETECT_CHECK,
      ARPDETECT_STREAM, ARPDETECT_RESIDUE} arpDetectState;
   static ap_uint<16> dmp_macType;
   static axiWord dmp_prevWord;
   static bool dmp_wasLast = false;
   axiWord currWord = {0, 0, 0, 0};

   switch (arpDetectState)
   {
      case ARPDETECT_IDLE:
         {
            if (!inData.empty()) {
               inData.read(currWord);
               dmp_prevWord = currWord;
               arpDetectState = ARPDETECT_CHECK;
            }
            break;
         }
            case ARPDETECT_CHECK:
         {
           if (!inData.empty()) {
               inData.read(currWord);
               dmp_macType(7, 0) = currWord.data(47, 40);
               dmp_macType(15,8) = currWord.data(39, 32);
               if (dmp_macType == ARP)
                  parser2arp.write(dmp_prevWord);
               else if (dmp_macType == IPv4)
                  macDetect2lengthCut.write(dmp_prevWord);
               dmp_prevWord = currWord;
               arpDetectState = ARPDETECT_STREAM;
            }
            break;
         }
            case ARPDETECT_STREAM:
         {
            if (!inData.empty()) {
               inData.read(currWord);
               if (dmp_macType == ARP)
                  parser2arp.write(dmp_prevWord);
               else if (dmp_macType == IPv4)
                  macDetect2lengthCut.write(dmp_prevWord);
               dmp_prevWord = currWord;
               if (currWord.last)
                  arpDetectState = ARPDETECT_RESIDUE;
            }
            break;
         }
            case ARPDETECT_RESIDUE:
         {
            if (dmp_macType == ARP)
               parser2arp.write(dmp_prevWord);
            else if (dmp_macType == IPv4)
               macDetect2lengthCut.write(dmp_prevWord);
            arpDetectState = ARPDETECT_IDLE;
            break;
         }
   }
}

void icmpDetection(stream<axiWord> &cutLength2ipDetect, stream<axiWord> &parser2icmp, stream<axiWord> &parser2loopback) {
#pragma HLS pipeline II=1 enable_flush

   static enum ipState {IPDETECT_IDLE = 0, IPDETECT_ID, IPDETECT_STREAM} ipDetectState;
   static ap_uint<8> dip_ipProtocol;
   static ap_uint<2> dip_wordCount = 0;
   static ap_uint<2> dip_leftToWrite = 0;
   axiWord currWord;
   static ap_shift_reg<axiWord, 2> wordBuffer;
   axiWord temp;

   if (dip_leftToWrite == 0) {
	   	if (!cutLength2ipDetect.empty()) {
	   		cutLength2ipDetect.read(currWord);
			switch (ipDetectState) {
				case IPDETECT_IDLE:
					wordBuffer.shift(currWord);
					if (dip_wordCount == 1)
						ipDetectState = IPDETECT_ID;
					dip_wordCount++;
					break;
				case IPDETECT_ID:
					dip_ipProtocol = currWord.data(63, 56);
					temp = wordBuffer.shift(currWord);
					if (dip_ipProtocol == ICMP)
						parser2icmp.write(temp);
				    else
				    	parser2loopback.write(temp);
					ipDetectState = IPDETECT_STREAM;
					break;
				case IPDETECT_STREAM:
					temp = wordBuffer.shift(currWord);
					if (dip_ipProtocol == ICMP)
						parser2icmp.write(temp);
					else
						parser2loopback.write(temp);
					break;
			 }
			 if (currWord.last) {
				dip_wordCount 	= 0;
				dip_leftToWrite = 2;
				ipDetectState 	= IPDETECT_IDLE;
			 }
	   	}
   }
   else if (dip_leftToWrite != 0) {
      axiWord nullAxiWord = {0, 0, 0, 0};
      temp = wordBuffer.shift(nullAxiWord);
      if (dip_ipProtocol == ICMP)
         parser2icmp.write(temp);
      else
         parser2loopback.write(temp);
      dip_leftToWrite--;
   }
}

void lengthAdjust(stream<axiWord> &macDetect2lengthCut, stream<axiWord> &cutLength2ipDetect) {
#pragma HLS pipeline II=1 enable_flush

   static enum cState {CUT_IDLE = 0, CUT_SKIP, CUT_LENGTH, CUT_COUNT, CUT_CONSUME} cutState;
   static ap_uint<16>    ih_wordCount    = 0;
   static ap_uint<16>    ih_totalLength    = 0;

   axiWord    currWord   = {0, 0, 0, 0};

   if (!macDetect2lengthCut.empty()) {
      macDetect2lengthCut.read(currWord);
      switch (cutState)
      {
         case CUT_IDLE:
        	cutLength2ipDetect.write(currWord);
            cutState = CUT_SKIP;
            break;
         case CUT_SKIP:
        	cutLength2ipDetect.write(currWord);
            cutState = CUT_LENGTH;
            break;
         case CUT_LENGTH:
            ih_totalLength(7, 0)   = currWord.data(15, 8);
            ih_totalLength(15, 8)   = currWord.data(7, 0);
            ih_totalLength    += 0x0E; 							// +14 for Ethernet header
            cutLength2ipDetect.write(currWord);
            cutState = CUT_COUNT;
            break;
         case CUT_COUNT:
            if (((ih_wordCount+1)*8) >= ih_totalLength) { 		//last real word
               if (currWord.last == 0)
                  cutState = CUT_CONSUME;
               currWord.last    = 1;
               ap_uint<4> remainingLength   = ih_totalLength - (ih_wordCount*8);
               if (remainingLength != 0)
                  currWord.strb.range(remainingLength-1, 0) = 1;
            }
            else {
               if (currWord.last == 1)
                  cutState = CUT_IDLE;
            }
            cutLength2ipDetect.write(currWord);
            break;
         case CUT_CONSUME:
            if (currWord.last)
               cutState = CUT_IDLE;
            break;
      }
   }
}

void parser(stream<axiWord> &inData,
      stream<axiWord> &parser2arp,
      stream<axiWord>& parser2icmp,
      stream<axiWord>& parser2loopback) {
#pragma HLS INLINE

   static stream<axiWord> macDetect2lengthCut("macDetect2lengthCut");
   static stream<axiWord> cutLength2ipDetect("cutLength2ipDetect");
#pragma HLS STREAM variable=macDetect2lengthCut depth=16
#pragma HLS STREAM variable=cutLength2ipDetect  depth=16

   ethernetDetection(inData, parser2arp, macDetect2lengthCut);
   lengthAdjust(macDetect2lengthCut, cutLength2ipDetect);
   icmpDetection(cutLength2ipDetect, parser2icmp, parser2loopback);
}
