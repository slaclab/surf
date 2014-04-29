#ifndef __AXI_SHARED_MEM_H__
#define __AXI_SHARED_MEM_H__

#include <sys/types.h>
#include <string>

// Write address record
class AxiWriteAddr {
   public:
      uint awaddr;
      uint awid;
      uint awlen;
      uint awsize;
      uint awburst;
      uint awlock;
      uint awcache;
      uint awprot;
      uint awqos;
      uint awuser;   
};

// Write data record
class AxiWriteData {
   public:
      uint wdataH;
      uint wdataL;
      uint wlast;
      uint wid;
      uint wstrb;
};

// Write completion record
class AxiWriteComp {
   public:
      uint bresp;
      uint bid;
};

// Read address record
class AxiReadAddr {
   public:
      uint araddr;
      uint arid;
      uint arlen;
      uint arsize;
      uint arburst;
      uint arlock;
      uint arprot;
      uint arcache;
      uint arqos;
      uint aruser;
};

// Read data record
class AxiReadData {
   public:
      uint rdataH;
      uint rdataL;
      uint rlast;
      uint rid;
      uint rresp;
};

// Shared memory record
class AxiSharedMem {

   protected:

      // Tracking objects
      char _smemPath[200];
      int  _smemId;

   private:

      // Clock counter
      uint _clkCnt;

      // Write records
      AxiWriteAddr _writeAddr;
      uint         _writeAddrReq;
      uint         _writeAddrAck;
      AxiWriteData _writeData;
      uint         _writeDataReq;
      uint         _writeDataAck;
      AxiWriteComp _writeComp;
      uint         _writeCompReq;
      uint         _writeCompAck;

      // Read records
      AxiReadAddr  _readAddr;
      uint         _readAddrReq;
      uint         _readAddrAck;
      AxiReadData  _readData;
      uint         _readDataReq;
      uint         _readDataAck;

   public:

      // Map and create shared memory object
      static AxiSharedMem * open ( std::string system, uint id, int uid = -1 );

      // close shared memory object
      static void close ( AxiSharedMem *smem );

      // Constructor
      AxiSharedMem ();

      // Destructor
      ~AxiSharedMem ();

      // Init variables
      void init();

      // Increment clock count
      void incrClkCnt();

      // Read clock count
      uint getClkCnt();

      // Set write addr
      void setWriteAddr ( AxiWriteAddr *writeAddr );

      // Get write addr
      bool getWriteAddr ( AxiWriteAddr *writeAddr );

      // Get write addr Ready
      bool readyWriteAddr ();

      // Set write data
      void setWriteData ( AxiWriteData *writeData );

      // Get write data
      bool getWriteData ( AxiWriteData *writeData );

      // Get write data Ready
      bool readyWriteData ();

      // Set write comp
      void setWriteComp ( AxiWriteComp *writeComp );

      // Get write comp
      bool getWriteComp ( AxiWriteComp *writeComp );

      // Get write comp Ready
      bool readyWriteComp ();

      // Set read addr
      void setReadAddr ( AxiReadAddr *readAddr );

      // Get read addr
      bool getReadAddr ( AxiReadAddr *readAddr );

      // Get read addr Ready
      bool readyReadAddr ();

      // Set read data
      void setReadData ( AxiReadData *readData );

      // Get read data
      bool getReadData ( AxiReadData *readData );

      // Get read data Ready
      bool readyReadData ();
   };

#endif
