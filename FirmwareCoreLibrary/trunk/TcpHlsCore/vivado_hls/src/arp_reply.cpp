#include "globals.hpp"
#include "arp_reply.hpp"

cam::cam(){
   for (uint8_t i=0;i<noOfArpTableEntries;++i) // Go through all the entries in the filter
      this->filterEntries[i].valid = 0;  // And mark them as invalid
}

bool cam::write(arpTableEntry writeEntry)
{
   for (uint8_t i=0;i<noOfArpTableEntries;++i) // Go through all the entries in the filter
   {
      if (this->filterEntries[i].valid == 0) // Check if the entry must be free
      {
         this->filterEntries[i].ipAddress = writeEntry.ipAddress;
         this->filterEntries[i].macAddress = writeEntry.macAddress;
         this->filterEntries[i].valid = 1; // If all these conditions are met then return true;
         return true;
      }
   }
   return false;
}

bool cam::clear(ap_uint<32> clearAddress)
{
   for (uint8_t i=0;i<noOfArpTableEntries;++i) // Go through all the entries in the filter
   {
      if (this->filterEntries[i].valid == 1 && clearAddress == this->filterEntries[i].ipAddress) // Check if the entry is valid and if the addresses match
      {
         this->filterEntries[i].valid = 0; // If so delete the entry (mark as invalid)
         return true;
      }
   }
   return false;
}

arpTableEntry cam::compare(ap_uint<32> searchAddress)
{
   for (uint8_t i=0;i<noOfArpTableEntries;++i) // Go through all the entries in the filter
   {
      if (this->filterEntries[i].valid == 1 && searchAddress == this->filterEntries[i].ipAddress) // Check if the entry is valid and if the addresses match
         return this->filterEntries[i]; // If all these conditions are met then return the entry;
   }
   arpTableEntry temp = {0, 0, 0};
   return temp;
}

void arp_server(stream<axiWord> &inData, stream<ap_uint<32> > &queryIP, stream<axiWord> &outData, stream<ap_uint<48> > &returnMAC)
{
#pragma HLS INLINE region
#pragma HLS pipeline II=1 enable_flush

   static enum myState {ARP_IDLE, ARP_PARSE, ARP_QUERY, ARP_REPLY, ARP_SENTRQ, ARP_W8REPLY, ARP_RETURNVALUE} arpState;

   axiWord currWord;
   axiWord sendWord = {0, 0xFF, 0 ,0};
   static ap_uint<32> replyCounter 	= 0;
   static uint16_t wordCount  = 0;
   static uint16_t sendCount  = 0;
   static bool sendReply  	= false;
   static bool reading  = true;

   static cam  arpTable;
   arpTableEntry queryResult;
#pragma HLS array_partition variable=arpTable.filterEntries complete

   static ap_uint<48>  MAC_DST;
   static ap_uint<48>  MAC_SRC;
   static ap_uint<16> ethType;
   static ap_uint<16> hwType;
   static ap_uint<16> protoType;
   static ap_uint<8> hwLen;
   static ap_uint<8> protoLen;
   static ap_uint<16> opCode;
   static ap_uint<48> hwAddrSrc;
   static ap_uint<32> protoAddrSrc;
   static ap_uint<48> hwAddrDst;
   static ap_uint<32> protoAddrDst;
   static ap_uint<32> inputIP;
   static bool		  requestEnabled;

   switch(arpState)
   {
      case ARP_IDLE:
         {
            inputIP = 0;
            sendCount = 0;
			requestEnabled = false;
            if (!inData.empty())
               arpState = ARP_PARSE;
            else if (!queryIP.empty())
            {	
				queryIP.read(inputIP);
				arpState = ARP_QUERY;
            }
            break;
         }
      case ARP_QUERY:
         {
            queryResult = arpTable.compare(inputIP);
            if (queryResult.valid == 1)
            {
               returnMAC.write(queryResult.macAddress);
               arpState  = ARP_IDLE;
            }
            else if (queryResult.valid == 0)
               arpState  = ARP_SENTRQ;
            break;
         }
      case ARP_SENTRQ:
         {
            switch(sendCount)
            {
               case 0:
                  sendWord.data.range(47, 0)  = BROADCAST_MAC;
                  sendWord.data.range(63, 48) = MY_MAC_ADDR.range(15, 0);
                  break;
               case 1:
                  sendWord.data.range(31, 0)  = MY_MAC_ADDR.range(47, 16);
                  sendWord.data.range(47, 32) = 0x0608;
                  sendWord.data.range(63, 48) = 0x0100;
                  break;
               case 2:
                  sendWord.data.range(15, 0)  = 0x0008; // IP Address
                  sendWord.data.range(23, 16) = 6; // HW Address Length
                  sendWord.data.range(31, 24) = 4; // Protocol Address Length
                  sendWord.data.range(47, 32) = REQUEST;
                  sendWord.data.range(63, 48) = MY_MAC_ADDR.range(15, 0);
                  break;
               case 3:
                  sendWord.data.range(31, 0)  = MY_MAC_ADDR.range(47, 16);
                  sendWord.data.range(63, 32) = MY_IP_ADDR;
                  break;
               case 4:
                  sendWord.data.range(47, 0)  = 0; // Sought-after MAC pt.1
                  sendWord.data.range(63, 48) = inputIP.range(15, 0);
                  break;
               case 5:
                  sendWord.data.range(63, 16) = 0; // Sought-after MAC pt.1
                  sendWord.data.range(15, 0)  = inputIP.range(31, 16);
                  sendWord.strb = 0x03;
                  sendWord.last = 1;
                  arpState = ARP_W8REPLY;
                  break;
            } //switch
            outData.write(sendWord);
            sendCount++;
            break;
         }
      case ARP_W8REPLY: // Wait for reply to the ARP request
         {
        	sendCount = 0;
			requestEnabled = true;
            if (!inData.empty()) 	// Check if the input Q is empty
               arpState = ARP_PARSE; // If not go and parse the message
            else // if so
            {
               if (replyCounter == replyTimeOut) // Check if the time out counter has expired
               {
                  replyCounter = 0; // if so reset it
                  arpState = ARP_IDLE; // and go to idle
               }
               else
                  replyCounter++; // if not increment it and stay in this state
            }
            break;
         }
      case ARP_RETURNVALUE:
         {
            if (inputIP == protoAddrSrc)
            {
               arpTableEntry tempEntry = {protoAddrSrc ,hwAddrSrc, 1};
               returnMAC.write(hwAddrSrc);
               arpTable.write(tempEntry);
            }
            arpState = ARP_IDLE;
            break;
         }
      case ARP_PARSE:
         {
            if (!inData.empty()) {
               inData.read(currWord);
               switch(wordCount)
               {
                  case 0:
                     sendCount = 0; // Reset the set counter
                     MAC_DST = currWord.data.range(47, 0);
                     MAC_SRC.range(15, 0) = currWord.data.range(63, 48);
                     break;
                  case 1:
                     MAC_SRC.range(47 ,16) = currWord.data.range(31, 0);
                     ethType = currWord.data.range(47, 32);
                     hwType = currWord.data.range(63, 48);
                     break;
                  case 2:
                     protoType = currWord.data.range(15, 0);
                     hwLen = currWord.data.range(23, 16);
                     protoLen = currWord.data.range(31, 24);
                     opCode = currWord.data.range(47, 32);
                     hwAddrSrc.range(15,0) = currWord.data.range(63, 48);
                     break;
                  case 3:
                     hwAddrSrc.range(47, 16) = currWord.data.range(31, 0);
                     protoAddrSrc = currWord.data.range(62, 32);
                     break;
                  case 4:
                     hwAddrDst = currWord.data.range(47, 0);
                     protoAddrDst.range(31, 16) = currWord.data.range(63, 48);
                     break;
                  case 5:
                     protoAddrDst.range(15, 0) = currWord.data.range(15, 0);
                     break;
                  default:
                     break;
               }
               if (currWord.last == 1) {
					if (opCode == REQUEST && protoAddrDst == MY_IP_ADDR && requestEnabled == false)
						arpState = ARP_REPLY;
					else if (opCode == REPLY && protoAddrDst == MY_IP_ADDR && requestEnabled == true)
						arpState = ARP_RETURNVALUE;
					else 
						arpState = ARP_IDLE;
                  wordCount = 0;
               }
               else
                  wordCount++;
            }
            break;
         }
      case ARP_REPLY:
         {
            switch(sendCount)
            {
               case 0:
                  sendWord.data.range(47, 0) = MAC_SRC;
                  sendWord.data.range(63, 48) = MY_MAC_ADDR.range(15, 0);
                  break;
               case 1:
                  sendWord.data.range(31, 0) = MY_MAC_ADDR.range(47, 16);
                  sendWord.data.range(47, 32) = ethType;
                  sendWord.data.range(63, 48) = hwType;
                  break;
               case 2:
                  sendWord.data.range(15, 0) = protoType;
                  sendWord.data.range(23, 16) = hwLen;
                  sendWord.data.range(31, 24) = protoLen;
                  sendWord.data.range(47, 32) = REPLY;
                  sendWord.data.range(63, 48) = MY_MAC_ADDR.range(15, 0);
                  break;
               case 3:
                  sendWord.data.range(31, 0) = MY_MAC_ADDR.range(47, 16);
                  sendWord.data.range(63, 32) = MY_IP_ADDR;
                  break;
               case 4:
                  sendWord.data.range(47, 0) = hwAddrSrc;
                  sendWord.data.range(63, 48) = protoAddrSrc.range(15, 0);
                  break;
               case 5:
                  sendWord.data.range(63, 16) = 0;
                  sendWord.data.range(15, 0) = protoAddrSrc.range(31, 16);
                  sendWord.strb = 0x03;
                  sendWord.last = 1;
                  arpState = ARP_IDLE;
                  break;
            }
            outData.write(sendWord);
            sendCount++;
            break;
         }
   }
}
