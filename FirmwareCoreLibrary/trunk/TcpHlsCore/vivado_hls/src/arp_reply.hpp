#ifndef ARP_REPLY_H_
#define ARP_REPLY_H_

#define noOfArpTableEntries 8

const uint16_t REQUEST = 0x0100;
const uint16_t REPLY = 0x0200;
const ap_uint<32> replyTimeOut = 4000000000;

const ap_uint<48> MY_MAC_ADDR = 0xAB9078563412;  // LSB first
const ap_uint<48> BROADCAST_MAC = 0xFFFFFFFFFFFF; // Broadcast MAC Address
const uint32_t MY_IP_ADDR = 0x01010101;

struct arpTableEntry
{
   ap_uint<32> ipAddress;
   ap_uint<48> macAddress;
   ap_uint<1> valid;
};

class cam {
   public:
      arpTableEntry filterEntries[noOfArpTableEntries];
      cam();
      bool write(arpTableEntry writeEntry); // Returns true if write completed successfully, else false
      bool clear(ap_uint<32> clearAddress); // Returns true if read completed successfully, else false
      arpTableEntry compare(ap_uint<32> searchAddress); // Compares the provided data with the contents of the filter and returns true if the entry should be blocked, false if not
};

void arp_server(
      stream<axiWord> &inData,
      stream<ap_uint<32> > &queryIP,
      stream<axiWord> &outData,
      stream<ap_uint<48> > &returnMAC
      );

#endif // ARP_REPLY_H_ not defined

