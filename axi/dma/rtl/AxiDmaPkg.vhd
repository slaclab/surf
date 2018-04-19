-------------------------------------------------------------------------------
-- File       : AxiStreamDmaRead.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-05-06
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:
-- Package file for AXI DMA Controller
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Firmware Standard Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'SLAC Firmware Standard Library', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;

package AxiDmaPkg is

   -------------------------------------
   -- Write DMA Axi-Stream Configuration
   -------------------------------------
   constant AXIS_WRITE_DMA_CONFIG_C : AxiStreamConfigType := (
      TSTRB_EN_C    => false,
      TDATA_BYTES_C => 8,
      TDEST_BITS_C  => 8,
      TID_BITS_C    => 0,
      TKEEP_MODE_C  => TKEEP_COMP_C,
      TUSER_BITS_C  => 8,
      TUSER_MODE_C  => TUSER_FIRST_LAST_C);

   -------------------------------------
   -- Write DMA Request (AxiStreamDmaWrite)
   -------------------------------------

   -- Base Record
   type AxiWriteDmaReqType is record
      request : sl;
      drop    : sl;
      address : slv(63 downto 0);
      maxSize : slv(31 downto 0);
   end record;

   -- Initialization constants
   constant AXI_WRITE_DMA_REQ_INIT_C : AxiWriteDmaReqType := ( 
      request => '0',
      drop    => '0',
      address => (others=>'0'),
      maxSize => (others=>'0')
   );

   -- Array
   type AxiWriteDmaReqArray is array (natural range<>) of AxiWriteDmaReqType;

   -------------------------------------
   -- Write DMA Acknowledge (AxiStreamDmaWrite)
   -------------------------------------

   -- Base Record
   type AxiWriteDmaAckType is record
      idle       : sl;
      done       : sl;
      size       : slv(31 downto 0);
      overflow   : sl;
      writeError : sl;
      errorValue : slv(1 downto 0);
      firstUser  : slv(7 downto 0);
      lastUser   : slv(7 downto 0);
      dest       : slv(7 downto 0);
      id         : slv(7 downto 0);
   end record;

   -- Initialization constants
   constant AXI_WRITE_DMA_ACK_INIT_C : AxiWriteDmaAckType := ( 
      idle       => '1',
      done       => '0',
      size       => (others=>'0'),
      overflow   => '0',
      writeError => '0',
      errorValue => "00",
      firstUser  => (others=>'0'),
      lastUser   => (others=>'0'),
      dest       => (others=>'0'),
      id         => (others=>'0')
   );

   -- Array
   type AxiWriteDmaAckArray is array (natural range<>) of AxiWriteDmaAckType;

   -------------------------------------
   -- Read DMA Request (AxiStreamDmaRead)
   -------------------------------------

   -- Base Record
   type AxiReadDmaReqType is record
      request   : sl;
      address   : slv(63 downto 0);
      size      : slv(31 downto 0);
      firstUser : slv(7 downto 0);
      lastUser  : slv(7 downto 0);
      dest      : slv(7 downto 0);
      id        : slv(7 downto 0);
   end record;

   -- Initialization constants
   constant AXI_READ_DMA_REQ_INIT_C : AxiReadDmaReqType := ( 
      request   => '0',
      address   => (others=>'0'),
      size      => (others=>'0'),
      firstUser => (others=>'0'),
      lastUser  => (others=>'0'),
      dest      => (others=>'0'),
      id        => (others=>'0')
   );

   -- Array
   type AxiReadDmaReqArray is array (natural range<>) of AxiReadDmaReqType;

   -------------------------------------
   -- Read DMA Acknowledge (AxiStreamDmaRead)
   -------------------------------------

   -- Base Record
   type AxiReadDmaAckType is record
      idle       : sl;
      done       : sl;
      readError  : sl;
      errorValue : slv(1 downto 0);
   end record;

   -- Initialization constants
   constant AXI_READ_DMA_ACK_INIT_C : AxiReadDmaAckType := ( 
      idle       => '1',
      done       => '0',
      readError  => '0',
      errorValue => "00"
   );

   -- Array
   type AxiReadDmaAckArray is array (natural range<>) of AxiReadDmaAckType;


   -------------------------------------
   -- DMA Write Descriptor Request (AxiStreamDmaV2)
   -- Issued from dma write engine to request a free 
   -- descriptor from the pool.
   -------------------------------------

   type AxiWriteDmaDescReqType is record
      valid      : sl;
      dest       : slv(7 downto 0);
   end record;

   constant AXI_WRITE_DMA_DESC_REQ_INIT_C : AxiWriteDmaDescReqType := ( 
      valid      => '0',
      dest       => (others=>'0')
   );

   type AxiWriteDmaDescReqArray is array (natural range<>) of AxiWriteDmaDescReqType;

   constant AXI_WRITE_DMA_DESC_REQ_SIZE_C : integer := 8;

   function toSlv (r : AxiWriteDmaDescReqType ) return slv;
   function toAxiWriteDmaDescReq (din : slv; valid : sl) return AxiWriteDmaDescReqType;


   -------------------------------------
   -- DMA Write Descriptor Ack (AxiStreamDmaV2)
   -- Returned to dma write engine in response to
   -- AxiWriteDescReqType.
   -------------------------------------

   type AxiWriteDmaDescAckType is record
      valid      : sl;
      address    : slv(63 downto 0);
      dropEn     : sl;              
      maxSize    : slv(31 downto 0);
      contEn     : sl;              
      buffId     : slv(15 downto 0);
   end record;

   constant AXI_WRITE_DMA_DESC_ACK_INIT_C : AxiWriteDmaDescAckType := ( 
      valid      => '0',
      address    => (others=>'0'),
      dropEn     => '0',
      maxSize    => (others=>'0'),
      contEn     => '0',
      buffId     => (others=>'0')
   );

   type AxiWriteDmaDescAckArray is array (natural range<>) of AxiWriteDmaDescAckType;

   constant AXI_WRITE_DMA_DESC_ACK_SIZE_C : integer := 114;

   function toSlv (r : AxiWriteDmaDescAckType ) return slv;
   function toAxiWriteDmaDescAck (din : slv; valid : sl) return AxiWriteDmaDescAckType;

   -------------------------------------
   -- DMA Write Descriptor Return (AxiStreamDmaV2)
   -- Returned from dma engine when frame is complete
   -------------------------------------

   type AxiWriteDmaDescRetType is record
      valid      : sl;
      buffId     : slv(15 downto 0); 
      firstUser  : slv(7  downto 0);
      lastUser   : slv(7  downto 0);
      size       : slv(31 downto 0);
      continue   : sl;
      result     : slv(2  downto 0);
      dest       : slv(7  downto 0);
      id         : slv(7  downto 0);
   end record;

   constant AXI_WRITE_DMA_DESC_RET_INIT_C : AxiWriteDmaDescRetType := ( 
      valid      => '0',
      buffId     => (others=>'0'),
      firstUser  => (others=>'0'),
      lastUser   => (others=>'0'),
      size       => (others=>'0'),
      continue   => '0',
      result     => (others=>'0'),
      dest       => (others=>'0'),
      id         => (others=>'0')
   );

   type AxiWriteDmaDescRetArray is array (natural range<>) of AxiWriteDmaDescRetType;

   constant AXI_WRITE_DMA_DESC_RET_SIZE_C : integer := 84;

   function toSlv (r : AxiWriteDmaDescRetType ) return slv;
   function toAxiWriteDmaDescRet (din : slv; valid : sl) return AxiWriteDmaDescRetType;

   -------------------------------------
   -- DMA Write Tracking (AxiStreamDmaV2)
   -- Memory entry for tracking an in progress transaction.
   -------------------------------------

   type AxiWriteDmaTrackType is record
      dest       : slv(7  downto 0);
      inUse      : sl;
      address    : slv(63 downto 0);
      maxSize    : slv(31 downto 0);
      size       : slv(31 downto 0);
      firstUser  : slv(7 downto 0);  
      contEn     : sl;
      dropEn     : sl;
      id         : slv(7  downto 0);
      buffId     : slv(15 downto 0);
      overflow   : sl;
   end record;

   constant AXI_WRITE_DMA_TRACK_INIT_C : AxiWriteDmaTrackType := ( 
      dest       => (others=>'0'),
      inUse      => '0',
      address    => (others=>'0'),
      maxSize    => (others=>'0'),
      size       => (others=>'0'),
      firstUser  => (others=>'0'),
      contEn     => '0',
      dropEn     => '0',
      id         => (others=>'0'),
      buffId     => (others=>'0'),
      overflow   => '0'
   );

   type AxiWriteDmaTrackArray is array (natural range<>) of AxiWriteDmaTrackType;

   constant AXI_WRITE_DMA_TRACK_SIZE_C : integer := 172;

   function toSlv (r : AxiWriteDmaTrackType ) return slv;
   function toAxiWriteDmaTrack (din : slv ) return AxiWriteDmaTrackType;

   -------------------------------------
   -- DMA Read Descriptor Request (AxiStreamDmaV2)
   -- Passed to DMA engine to initiate a read.
   -------------------------------------

   type AxiReadDmaDescReqType is record
      valid      : sl;
      address    : slv(63 downto 0);
      buffId     : slv(15 downto 0); 
      firstUser  : slv(7  downto 0);
      lastUser   : slv(7  downto 0);
      size       : slv(31 downto 0);
      continue   : sl;
      id         : slv(7  downto 0);
      dest       : slv(7  downto 0);
   end record;

   constant AXI_READ_DMA_DESC_REQ_INIT_C : AxiReadDmaDescReqType := ( 
      valid      => '0',
      address    => (others=>'0'),
      buffId     => (others=>'0'),
      firstUser  => (others=>'0'),
      lastUser   => (others=>'0'),
      size       => (others=>'0'),
      continue   => '0',
      id         => (others=>'0'),
      dest       => (others=>'0')
   );

   type AxiReadDmaDescReqArray is array (natural range<>) of AxiReadDmaDescReqType;

   constant AXI_READ_DMA_DESC_REQ_SIZE_C : integer := 145;

   function toSlv (r : AxiReadDmaDescReqType ) return slv;
   function toAxiReadDmaDescReq (din : slv; valid : sl) return AxiReadDmaDescReqType;

   -------------------------------------
   -- DMA Read Descriptor Return (AxiStreamDmaV2)
   -- Returned from dma engine when frame is complete
   -------------------------------------

   type AxiReadDmaDescRetType is record
      valid      : sl;
      buffId     : slv(15 downto 0); 
      result     : slv(2  downto 0);
   end record;

   constant AXI_READ_DMA_DESC_RET_INIT_C : AxiReadDmaDescRetType := ( 
      valid      => '0',
      buffId     => (others=>'0'),
      result     => (others=>'0')
   );

   type AxiReadDmaDescRetArray is array (natural range<>) of AxiReadDmaDescRetType;

   constant AXI_READ_DMA_DESC_RET_SIZE_C : integer := 19;

   function toSlv (r : AxiReadDmaDescRetType ) return slv;
   function toAxiReadDmaDescRet (din : slv; valid : sl) return AxiReadDmaDescRetType;

end package AxiDmaPkg;

package body AxiDmaPkg is

   function toSlv (r : AxiWriteDmaDescReqType ) return slv is
      variable retValue : slv(AXI_WRITE_DMA_DESC_REQ_SIZE_C-1 downto 0) := (others => '0');
      variable i        : integer := 0;
   begin
      assignSlv(i, retValue, r.dest);
      return(retValue);
   end function;

   function toAxiWriteDmaDescReq (din : slv; valid : sl) return AxiWriteDmaDescReqType is
      variable desc : AxiWriteDmaDescReqType := AXI_WRITE_DMA_DESC_REQ_INIT_C;
      variable i    : integer := 0;
   begin
      desc.valid := valid;
      assignRecord(i, din, desc.dest);
      return(desc);
   end function;

   function toSlv (r : AxiWriteDmaDescAckType ) return slv is
      variable retValue : slv(AXI_WRITE_DMA_DESC_ACK_SIZE_C-1 downto 0) := (others => '0');
      variable i        : integer := 0;
   begin
      assignSlv(i, retValue, r.address);
      assignSlv(i, retValue, r.dropEn);
      assignSlv(i, retValue, r.maxSize);
      assignSlv(i, retValue, r.contEn);
      assignSlv(i, retValue, r.buffId);
      return(retValue);
   end function;

   function toAxiWriteDmaDescAck (din : slv; valid : sl) return AxiWriteDmaDescAckType is
      variable desc : AxiWriteDmaDescAckType := AXI_WRITE_DMA_DESC_ACK_INIT_C;
      variable i    : integer := 0;
   begin
      desc.valid := valid;
      assignRecord(i, din, desc.address);
      assignRecord(i, din, desc.dropEn);
      assignRecord(i, din, desc.maxSize);
      assignRecord(i, din, desc.contEn);
      assignRecord(i, din, desc.buffId);
      return(desc);
   end function;

   function toSlv (r : AxiWriteDmaDescRetType ) return slv is
      variable retValue : slv(AXI_WRITE_DMA_DESC_RET_SIZE_C-1 downto 0) := (others => '0');
      variable i        : integer := 0;
   begin
      assignSlv(i, retValue, r.buffId);
      assignSlv(i, retValue, r.firstUser);
      assignSlv(i, retValue, r.lastUser);
      assignSlv(i, retValue, r.size);
      assignSlv(i, retValue, r.continue);
      assignSlv(i, retValue, r.result);
      assignSlv(i, retValue, r.dest);
      assignSlv(i, retValue, r.id);
      return(retValue);
   end function;

   function toAxiWriteDmaDescRet (din : slv; valid : sl) return AxiWriteDmaDescRetType is
      variable desc : AxiWriteDmaDescRetType := AXI_WRITE_DMA_DESC_RET_INIT_C;
      variable i    : integer := 0;
   begin
      desc.valid := valid;
      assignRecord(i, din, desc.buffId);
      assignRecord(i, din, desc.firstUser);
      assignRecord(i, din, desc.lastUser);
      assignRecord(i, din, desc.size);
      assignRecord(i, din, desc.continue);
      assignRecord(i, din, desc.result);
      assignRecord(i, din, desc.dest);
      assignRecord(i, din, desc.id);
      return(desc);
   end function;

   function toSlv (r : AxiWriteDmaTrackType ) return slv is
      variable retValue : slv(AXI_WRITE_DMA_TRACK_SIZE_C-1 downto 0) := (others => '0');
      variable i        : integer := 0;
   begin
      assignSlv(i, retValue, r.dest);
      assignSlv(i, retValue, r.inUse);
      assignSlv(i, retValue, r.address);
      assignSlv(i, retValue, r.maxSize);
      assignSlv(i, retValue, r.size);
      assignSlv(i, retValue, r.firstUser);
      assignSlv(i, retValue, r.contEn);
      assignSlv(i, retValue, r.dropEn);
      assignSlv(i, retValue, r.id);
      assignSlv(i, retValue, r.buffId);
      assignSlv(i, retValue, r.overflow);
      return(retValue);
   end function;

   function toAxiWriteDmaTrack (din : slv) return AxiWriteDmaTrackType is
      variable desc : AxiWriteDmaTrackType := AXI_WRITE_DMA_TRACK_INIT_C;
      variable i    : integer := 0;
   begin
      assignRecord(i, din, desc.dest);
      assignRecord(i, din, desc.inUse);
      assignRecord(i, din, desc.address);
      assignRecord(i, din, desc.maxSize);
      assignRecord(i, din, desc.size);
      assignRecord(i, din, desc.firstUser);
      assignRecord(i, din, desc.contEn);
      assignRecord(i, din, desc.dropEn);
      assignRecord(i, din, desc.id);
      assignRecord(i, din, desc.buffId);
      assignRecord(i, din, desc.overflow);
      return(desc);
   end function;

   function toSlv (r : AxiReadDmaDescReqType ) return slv is
      variable retValue : slv(AXI_READ_DMA_DESC_REQ_SIZE_C-1 downto 0) := (others => '0');
      variable i        : integer := 0;
   begin
      assignSlv(i, retValue, r.address);
      assignSlv(i, retValue, r.buffId);
      assignSlv(i, retValue, r.firstUser);
      assignSlv(i, retValue, r.lastUser);
      assignSlv(i, retValue, r.size);
      assignSlv(i, retValue, r.continue);
      assignSlv(i, retValue, r.id);
      assignSlv(i, retValue, r.dest);
      return(retValue);
   end function;

   function toAxiReadDmaDescReq (din : slv; valid : sl) return AxiReadDmaDescReqType is
      variable desc : AxiReadDmaDescReqType := AXI_READ_DMA_DESC_REQ_INIT_C;
      variable i    : integer := 0;
   begin
      desc.valid := valid;
      assignRecord(i, din, desc.address);
      assignRecord(i, din, desc.buffId);
      assignRecord(i, din, desc.firstUser);
      assignRecord(i, din, desc.lastUser);
      assignRecord(i, din, desc.size);
      assignRecord(i, din, desc.continue);
      assignRecord(i, din, desc.id);
      assignRecord(i, din, desc.dest);
      return(desc);
   end function;

   function toSlv (r : AxiReadDmaDescRetType ) return slv is
      variable retValue : slv(AXI_READ_DMA_DESC_RET_SIZE_C-1 downto 0) := (others => '0');
      variable i        : integer := 0;
   begin
      assignSlv(i, retValue, r.buffId);
      assignSlv(i, retValue, r.result);
      return(retValue);
   end function;

   function toAxiReadDmaDescRet (din : slv; valid : sl) return AxiReadDmaDescRetType is
      variable desc : AxiReadDmaDescRetType := AXI_READ_DMA_DESC_RET_INIT_C;
      variable i    : integer := 0;
   begin
      desc.valid := valid;
      assignRecord(i, din, desc.buffId);
      assignRecord(i, din, desc.result);
      return(desc);
   end function;

end package body AxiDmaPkg;

