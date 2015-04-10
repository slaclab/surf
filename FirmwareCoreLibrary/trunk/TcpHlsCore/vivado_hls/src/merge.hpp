#ifndef MERGE_H_
#define MERGE_H_

/*void merge(
      stream<axiWord> &arp2merge,
      stream<axiWord> &icmp2merge,
      stream<axiWord> &loopback2merge,
      stream<axiWord> &outData
      ); */

void merge(stream<axiWord> inData[NUM_MERGE_STREAMS], stream<axiWord> &outData);

#endif // MERGE_H_ not defined

