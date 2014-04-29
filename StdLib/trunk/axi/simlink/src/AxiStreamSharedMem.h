#ifndef __AXI_STREAM_SHARED_MEM_H__
#define __AXI_STREAM_SHARED_MEM_H__

// Shared memory structure, matches structure in general DAQ
// in generic/SimLink.h (redefined here for simplicity)

#define SIM_LINK_BUFF_SIZE 1000000

#define SHM_NAME "axiStream"
#define SHM_ID   1

typedef struct {

   // Upstream or Inbound
   uint        usReqCount;
   uint        usAckCount;
   uint        usData[SIM_LINK_BUFF_SIZE];
   uint        usSize;
   uint        usVc;
   uint        usEofe;
   uint        usBigEndian;
   
   // Downstream or outbound
   uint        dsReqCount;
   uint        dsAckCount;
   uint        dsData[SIM_LINK_BUFF_SIZE];
   uint        dsSize;
   uint        dsVc;
   uint        dsBigEndian;

} AxiStreamSharedMem;

#endif
