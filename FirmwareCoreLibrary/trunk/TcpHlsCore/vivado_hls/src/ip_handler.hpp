#ifndef IP_HANDLER_HPP_
#define IP_HANDLER_HPP_

const uint16_t ARP  = 0x0806;
const uint16_t IPv4 = 0x0800;

const uint8_t UDP    = 0x11;
const uint8_t TCP    = 0x06;
const uint8_t ICMP   = 0x01;

void parser(
      stream<axiWord> &inData,
      stream<axiWord> &parser2arp,
      stream<axiWord>& parser2icmp,
      stream<axiWord>& parser2loopback
      );

#endif // IP_HANDLER_HPP_ not defined

