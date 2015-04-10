#ifndef ICMP_SERVER_H_
#define ICMP_SERVER_H_

const uint8_t ECHO_REQUEST = 0x08;
const uint8_t ECHO_REPLY = 0x00;
const uint8_t ICMP_PROTOCOL = 0x01;

enum { WORD_0, WORD_1, WORD_2, WORD_3, WORD_4, WORD_5};
enum { ADAPT_CS_0, ADAPT_CS_1, ADAPT_CS_2, ADAPT_CS_3, ADAPT_CS_4, ADAPT_CS_5 };

void icmp_server(
      stream<axiWord> &inData,
      stream<axiWord> &outData
      );

#endif // ICMP_SERVER_H_ not defined

