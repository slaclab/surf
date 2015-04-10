#include "globals.hpp"

#define WORKAROUND

void merge(stream<axiWord> inData[NUM_MERGE_STREAMS], stream<axiWord> &outData)
{
#pragma HLS INLINE off
#pragma HLS pipeline II=1 enable_flush

    static enum mState{M_IDLE = 0, M_STREAM} mergeState;
    static ap_uint<LOG2CEIL_NUM_MERGE_STREAMS>rrCtr           = 0; // Counter used to ensure fair access to all the queues in the idle state
    static ap_uint<LOG2CEIL_NUM_MERGE_STREAMS>streamSource    = 0; // Denotes the stream from which the data will be read. 0 = ARP, 1 = ICMP, 2 = Loopback
    axiWord             inputWord       = {0, 0, 0, 0};

    switch(mergeState)
    {
        case M_IDLE:
        {
            // store all input stream empty states
            bool stream_empty[NUM_MERGE_STREAMS];
#pragma HLS ARRAY_PARTITION variable=stream_empty complete
            for (uint8_t i=0;i<NUM_MERGE_STREAMS;++i) {
                stream_empty[i] = inData[i].empty();
            }
            // Scan for non-empty stream in circular fashion w/ round-robin
            // start point -- r-r increment merged w/ tmpCtr to reduce
            // combinational logic depth
            for (uint8_t i=0;i<NUM_MERGE_STREAMS;++i)
            {
                uint8_t tempCtr = streamSource + 1 + i;
                if (tempCtr >= NUM_MERGE_STREAMS)
                    tempCtr -= NUM_MERGE_STREAMS;
                if(!stream_empty[tempCtr])
                {
                    streamSource = tempCtr;
                    inputWord = inData[streamSource].read();
                    outData.write(inputWord);
                    if (inputWord.last == 0)
                        mergeState = M_STREAM;
                    break;
                }
            }
            break;
        }
        case M_STREAM:
        {
            if (!inData[streamSource].empty()) {
                inData[streamSource].read(inputWord);
                outData.write(inputWord);
                if (inputWord.last == 1) {
                    mergeState = M_IDLE;
                }
            }
            break;
        }
    }
}

