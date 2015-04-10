#include "globals.hpp"
#include "icmp_server.hpp"

/*
 * Creates Reply message
 * Determines if input message valid
 * Extracts checksums
 */
void createReply(stream<axiWord> &inData, stream<axiWord> &outData, stream<ap_uint<1> > &validBuffer, stream<ap_uint<16> > &checksumBuffer) {
#pragma HLS pipeline II=1 enable_flush

   static  axiWord crCurrWord;
   axiWord sendWord = {0, 0xFF, 0, 0};
   static enum rState {R_IDLE = 0, R_READ1, R_READ2, R_READ3, R_READ4, R_STREAM, R_LASTWORD, R_CS1, R_CS2, R_CS3, R_CS4, R_CS5, R_CS6} replyState;

   static uint8_t oldTTL;
   static uint8_t newTTL = 0x40;
   static ap_uint<8> ipProto;
   static ap_uint<8> protoLen;
   static ap_uint<8> icmpType;
   static ap_uint<8> icmpCode;
   static ap_uint<16> icmpID;

   static ap_uint<18> ipChecksum;
   static ap_uint<18> icmpChecksum;

   switch(replyState) {
      case R_IDLE:
      {
         if(!inData.empty()) {
            inData.read(crCurrWord);
            icmpChecksum = 0xFFFFFFFF;
            replyState = R_READ1;
         }
         break;
      }
      case R_READ1:
      {
         if(!inData.empty()) {
            ap_uint<32> buffer  = crCurrWord.data.range(47, 16);
            sendWord.data.range(15, 0)  = crCurrWord.data.range(63, 48);
            sendWord.data.range(63, 48) = crCurrWord.data.range(15, 0);
            inData.read(crCurrWord);
            sendWord.data.range(47, 16) = crCurrWord.data.range(31, 0);
            crCurrWord.data.range(31, 0)  = buffer;
            outData.write(sendWord);
            replyState = R_READ2;
         }
         break;
      }
      case R_READ2:
      {
         if(!inData.empty()) {
            outData.write(crCurrWord);
            inData.read(crCurrWord);
            oldTTL  = crCurrWord.data.range(55, 48); // store old Time To Live
            ipProto  = crCurrWord.data.range(63, 56);  // 0x01 for ICMP
            replyState  = R_READ3;
         }
         break;
      }
      case R_READ3:
      {
         if(!inData.empty()) {
            outData.write(crCurrWord);
            inData.read(crCurrWord);
            ipChecksum.range(15, 0)  = crCurrWord.data.range(15, 0); // Get IP Checksum
            ipChecksum.range(17, 16)  = 0x3;
            ipChecksum  = ~ipChecksum;
            replyState  = R_READ4;
         }
         break;
      }
      case R_READ4:
      {
         if(!inData.empty()) {
            ap_uint<16> buffer  = crCurrWord.data.range(47, 32);
            sendWord.data.range(15, 0)  = crCurrWord.data.range(15, 0); // IP checksum
            sendWord.data.range(31, 16) = crCurrWord.data.range(63, 48); // IP Addr DST
            sendWord.data.range(63, 48) = crCurrWord.data.range(31, 16); // IP Addr Src
            inData.read(crCurrWord);
            // Get ICMP type & code
            icmpType  = crCurrWord.data.range(23, 16);
            icmpCode  = crCurrWord.data.range(31, 24);
            crCurrWord.data.range(23, 16) = ECHO_REPLY;

            // Get ICMP checksum
            icmpChecksum.range(15, 0)  = crCurrWord.data.range(47, 32);
            icmpChecksum.range(17, 16)  = 0x3;
            icmpChecksum  = ~icmpChecksum;

            sendWord.data.range(47, 32) = crCurrWord.data.range(15, 0); // IP Addr DST
            crCurrWord.data.range(15, 0)  = buffer;
            outData.write(sendWord); //3
            if (crCurrWord.last == 1)
               replyState = R_LASTWORD;
            else {
               if (ipProto == ICMP_PROTOCOL && icmpType == ECHO_REQUEST && icmpCode == 0) { 	// Check if this is an ICMP Request message.
                  replyState = R_CS1;
                  validBuffer.write(1);
               }
               else {
                  validBuffer.write(0);
                  replyState = R_STREAM;
               }
            }
         }
         break;
      }
      case R_STREAM:
      {
         if(!inData.empty()) {
            outData.write(crCurrWord);
            inData.read(crCurrWord);
            if (crCurrWord.last == 1)
               replyState = R_LASTWORD;
         }
         break;
      }
      case R_LASTWORD:
      {
         outData.write(crCurrWord);
         replyState = R_IDLE;
         break;
      }
      case R_CS1:
      {
         ipChecksum -= oldTTL;
         replyState = R_CS2;
         break;
      }
      case R_CS2:
      {
         ipChecksum += newTTL;
         replyState = R_CS3;
         break;
      }
      case R_CS3:
      {
         ipChecksum += ipChecksum.range(17,16);
         icmpChecksum -= ECHO_REQUEST;
         replyState = R_CS4;
         break;
      }
      case R_CS4:
      {
         ipChecksum = ~ipChecksum;
         icmpChecksum += icmpChecksum.range(17,16);
         replyState = R_CS5;
         break;
      }
      case R_CS5:
         {
            checksumBuffer.write(ipChecksum);
            icmpChecksum = ~icmpChecksum;
            replyState = R_CS6;
            break;
         }
      case R_CS6:
      {
         checksumBuffer.write(icmpChecksum);
         replyState = R_STREAM;
         break;
      }
   }
}

/*
 * Reads valid bit from validBufffer, if package is invalid it is dropped otherwise it is forwarded
 */
void dropper(stream<axiWord>& inData, stream<ap_uint<1> >& validBuffer, stream<axiWord>& outData) {
#pragma HLS pipeline II=1 enable_flush

   static enum dState {D_IDLE = 0, D_STREAM, D_DROP} dropState;
   axiWord  currWord = {0, 0, 0, 0};

   switch(dropState) {
      case D_IDLE:
      {
         if (!inData.empty()) {
            if (!validBuffer.empty()) {
               ap_uint<1>  valid;
               validBuffer.read(valid);
               inData.read(currWord);
               if (valid) {
                  outData.write(currWord);
                  dropState = D_STREAM;
               }
               else
                  dropState = D_DROP;
            }
         }
         break;
      }
      case D_STREAM:
      {
         if (!inData.empty()) {
            inData.read(currWord);
            outData.write(currWord);
            if (currWord.last)
               dropState = D_IDLE;
         }
         break;
      }
      case D_DROP:
      {
         if (!inData.empty()) {
            inData.read(currWord);
            if (currWord.last)
               dropState = D_IDLE;
         }
         break;
      }
   }
}

/*
 * Inserts IP & ICMP checksum at the correct position
 */
void insertChecksum(stream<axiWord>& inData, stream<ap_uint<16> >& checksumBuffer, stream<axiWord>& outData) {
#pragma HLS pipeline II=1 enable_flush

   static uint16_t ic_wordCount = 0;
   ap_uint<16>  ic_checksum;
   axiWord  ic_tempWord = {0, 0, 0, 0};

   if(!inData.empty()) {
      switch (ic_wordCount) {
         case WORD_3:
         {
            if(!checksumBuffer.empty()) {
               inData.read(ic_tempWord);
               checksumBuffer.read(ic_checksum);
               ic_tempWord.data.range(15, 0) = ic_checksum;
               outData.write(ic_tempWord);
               ic_wordCount++;
            }
            break;
         }
         case WORD_4:
         {
            if(!checksumBuffer.empty()) {
               inData.read(ic_tempWord);
               checksumBuffer.read(ic_checksum);
               ic_tempWord.data.range(47, 32) = ic_checksum;
               outData.write(ic_tempWord);
               ic_wordCount++;
            }
            break;
         }
         default:
         {
            inData.read(ic_tempWord);
            outData.write(ic_tempWord);
            ic_wordCount++;
            break;
         }
      }
   }
   if (ic_tempWord.last == 1)
      ic_wordCount = 0;
}

/*
 * Main function
 */
void icmp_server(stream<axiWord> &inData, stream<axiWord> &outData)
{
#pragma HLS dataflow interval=1
#pragma HLS INLINE

   static stream<axiWord> cr2dropper("cr2dropper");
   static stream<axiWord> drop2checksum("drop2checksum");
   static stream<ap_uint<1> > validBuffer("validBuffer");
   static stream<ap_uint<16> > cr2checksum("cr2checksum");
#pragma HLS stream variable=cr2dropper 		depth=16
#pragma HLS stream variable=drop2checksum 	depth=16
#pragma HLS stream variable=validBuffer    	depth=16
#pragma HLS stream variable=cr2checksum	 	depth=16

   createReply(inData, cr2dropper, validBuffer, cr2checksum);
   dropper(cr2dropper, validBuffer, drop2checksum);
   insertChecksum(drop2checksum, cr2checksum, outData);
}
