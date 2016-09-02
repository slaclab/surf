-------------------------------------------------------------------------------
-- Title         : AXI-4 DMA Controller Package File
-- File          : AxiDmaPkg.vhd
-- Author        : Ryan Herbst, rherbst@slac.stanford.edu
-- Created       : 05/06/2013
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

package AxiDmaPkg is

   -------------------------------------
   -- Write DMA Request
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
   -- Write DMA Acknowledge
   -------------------------------------

   -- Base Record
   type AxiWriteDmaAckType is record
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
   -- Read DMA Request
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
   -- Read DMA Acknowledge
   -------------------------------------

   -- Base Record
   type AxiReadDmaAckType is record
      done       : sl;
      readError  : sl;
      errorValue : slv(1 downto 0);
   end record;

   -- Initialization constants
   constant AXI_READ_DMA_ACK_INIT_C : AxiReadDmaAckType := ( 
      done       => '0',
      readError  => '0',
      errorValue => "00"
   );

   -- Array
   type AxiReadDmaAckArray is array (natural range<>) of AxiReadDmaAckType;


   -------------------------------------
   -- DMA Write Descriptor Request 
   -------------------------------------

   type AxiWriteDescReqType is record
      valid      : sl;
      dest       : slv(7 downto 0);
   end record;

   constant AXI_WRITE_DESC_REQ_INIT_C : AxiWriteDescReqType := ( 
      valid      => '0',
      dest       => (others=>'0')
   );

   type AxiWriteDescReqArray is array (natural range<>) of AxiWriteDescReqType;

   constant AXI_WRITE_DESC_REQ_SIZE_C : integer := 8;

   function toSlv (r : AxiWriteDescReqType ) return slv;
   function toAxiWriteDescReq (din : slv; valid : sl) return AxiWriteDescReqType;


   -------------------------------------
   -- DMA Write Descriptor Ack
   -------------------------------------

   type AxiWriteDescAckType is record
      valid      : sl;
      address    : slv(63 downto 0);
      drop       : sl;
      maxSize    : slv(31 downto 0);
      contEn     : sl;
      buffId     : slv(7 downto 0);
   end record;

   constant AXI_WRITE_DESC_ACK_INIT_C : AxiWriteDescAckType := ( 
      valid      => '0',
      address    => (others=>'0'),
      drop       => '0',
      maxSize    => (others=>'0'),
      contEn     => '0',
      buffId     => (others=>'0')
   );

   type AxiWriteDescAckArray is array (natural range<>) of AxiWriteDescAckType;

   constant AXI_WRITE_DESC_ACK_SIZE_C : integer := 106;

   function toSlv (r : AxiWriteDescAckType ) return slv;
   function toAxiWriteDescAck (din : slv; valid : sl) return AxiWriteDescAckType;


   -------------------------------------
   -- DMA Write Descriptor Return
   -------------------------------------

   type AxiWriteDescRetType is record
      valid      : sl;
      buffId     : slv(7 downto 0);
      firstUser  : slv(7 downto 0);
      lastUser   : slv(7 downto 0);
      size       : slv(31 downto 0);
      id         : slv(7 downto 0);
      errDet     : sl;
      errValue   : slv(1 downto 0);
      continue   : sl;
      overflow   : sl;
      dest       : slv(7 downto 0);
      reqCount   : slv(31 downto 0);
   end record;

   constant AXI_WRITE_DESC_RET_INIT_C : AxiWriteDescRetType := ( 
      valid      => '0',
      buffId     => (others=>'0'),
      firstUser  => (others=>'0'),
      lastUser   => (others=>'0'),
      size       => (others=>'0'),
      id         => (others=>'0'),
      errDet     => '0',
      errValue   => (others=>'0'),
      continue   => '0',
      overflow   => '0',
      dest       => (others=>'0'),
      reqCount   => (others=>'0')
   );

   type AxiWriteDescRetArray is array (natural range<>) of AxiWriteDescRetType;

   constant AXI_WRITE_DESC_RET_SIZE_C : integer := 109;

   function toSlv (r : AxiWriteDescRetType ) return slv;
   function toAxiWriteDescRet (din : slv; valid : sl) return AxiWriteDescRetType;


   -------------------------------------
   -- DMA Write Tracking 
   -------------------------------------

   type AxiWriteTrackType is record
      address    : slv(63 downto 0);
      maxSize    : slv(31 downto 0);
      size       : slv(31 downto 0);
      firstUser  : slv(7 downto 0);
      lastUser   : slv(7 downto 0);
      id         : slv(7 downto 0);
      contEn     : sl;
      inUse      : sl;
      buffId     : slv(7 downto 0);
   end record;

   constant AXI_WRITE_TRACK_INIT_C : AxiWriteTrackType := ( 
      address    => (others=>'0'),
      maxSize    => (others=>'0'),
      size       => (others=>'0'),
      firstUser  => (others=>'0'),
      lastUser   => (others=>'0'),
      id         => (others=>'0'),
      contEn     => '0',
      inUse      => '0',
      buffId     => (others=>'0')
   );

   type AxiWriteTrackArray is array (natural range<>) of AxiWriteTrackType;

   constant AXI_WRITE_TRACK_SIZE_C : integer := 162;

   function toSlv (r : AxiWriteTrackType ) return slv;
   function toAxiWriteTrack (din : slv; valid : sl) return AxiWriteTrackType;

end package AxiDmaPkg;

package body AxiDmaPkg is

   function toSlv (r : AxiWriteDescReqType ) return slv is
      variable retValue : slv(AXI_WRITE_DESC_REQ_SIZE_C-1 downto 0) := (others => '0');
      variable i        : integer := 0;
   begin
      assignSlv(i, retValue, r.dest);
      return(retValue);
   end function;

   function toAxiWriteDescReq (din : slv; valid : sl) return AxiWriteDescReqType is
      variable desc : AxiWriteDescReqType := AXI_WRITE_DESC_REQ_INIT_C;
      variable i    : integer := 0;
   begin
      desc.valid := valid;
      assignRecord(i, din, desc.dest);
      return(desc);
   end function;

   function toSlv (r : AxiWriteDescAckType ) return slv is
      variable retValue : slv(AXI_WRITE_DESC_ACK_SIZE_C-1 downto 0) := (others => '0');
      variable i        : integer := 0;
   begin
      assignSlv(i, retValue, r.address);
      assignSlv(i, retValue, r.drop);
      assignSlv(i, retValue, r.maxSize);
      assignSlv(i, retValue, r.contEn);
      assignSlv(i, retValue, r.buffId);
      return(retValue);
   end function;

   function toAxiWriteDescAck (din : slv; valid : sl) return AxiWriteDescAckType is
      variable desc : AxiWriteDescAckType := AXI_WRITE_DESC_ACK_INIT_C;
      variable i    : integer := 0;
   begin
      desc.valid := valid;
      assignRecord(i, din, desc.address);
      assignRecord(i, din, desc.drop);
      assignRecord(i, din, desc.maxSize);
      assignRecord(i, din, desc.contEn);
      assignRecord(i, din, desc.buffId);
      return(desc);
   end function;

   function toSlv (r : AxiWriteDescRetType ) return slv is
      variable retValue : slv(AXI_WRITE_DESC_RET_SIZE_C-1 downto 0) := (others => '0');
      variable i        : integer := 0;
   begin
      assignSlv(i, retValue, r.buffId);
      assignSlv(i, retValue, r.firstUser);
      assignSlv(i, retValue, r.lastUser);
      assignSlv(i, retValue, r.size);
      assignSlv(i, retValue, r.id);
      assignSlv(i, retValue, r.errDet);
      assignSlv(i, retValue, r.errValue);
      assignSlv(i, retValue, r.continue);
      assignSlv(i, retValue, r.overflow);
      assignSlv(i, retValue, r.dest);
      assignSlv(i, retValue, r.reqCount);
      return(retValue);
   end function;

   function toAxiWriteDescRet (din : slv; valid : sl) return AxiWriteDescRetType is
      variable desc : AxiWriteDescRetType := AXI_WRITE_DESC_RET_INIT_C;
      variable i    : integer := 0;
   begin
      desc.valid := valid;
      assignRecord(i, din, desc.buffId);
      assignRecord(i, din, desc.firstUser);
      assignRecord(i, din, desc.lastUser);
      assignRecord(i, din, desc.size);
      assignRecord(i, din, desc.id);
      assignRecord(i, din, desc.errDet);
      assignRecord(i, din, desc.errValue);
      assignRecord(i, din, desc.continue);
      assignRecord(i, din, desc.overflow);
      assignRecord(i, din, desc.dest);
      assignRecord(i, din, desc.reqCount);
      return(desc);
   end function;

   function toSlv (r : AxiWriteTrackType ) return slv is
      variable retValue : slv(AXI_WRITE_TRACK_SIZE_C-1 downto 0) := (others => '0');
      variable i        : integer := 0;
   begin
      assignSlv(i, retValue, r.address);
      assignSlv(i, retValue, r.maxSize);
      assignSlv(i, retValue, r.size);
      assignSlv(i, retValue, r.firstUser);
      assignSlv(i, retValue, r.lastUser);
      assignSlv(i, retValue, r.id);
      assignSlv(i, retValue, r.contEn);
      assignSlv(i, retValue, r.inUse);
      assignSlv(i, retValue, r.buffId);
      return(retValue);
   end function;

   function toAxiWriteTrack (din : slv; valid : sl) return AxiWriteTrackType is
      variable desc : AxiWriteTrackType := AXI_WRITE_TRACK_INIT_C;
      variable i    : integer := 0;
   begin
      assignRecord(i, din, desc.address);
      assignRecord(i, din, desc.maxSize);
      assignRecord(i, din, desc.size);
      assignRecord(i, din, desc.firstUser);
      assignRecord(i, din, desc.lastUser);
      assignRecord(i, din, desc.id);
      assignRecord(i, din, desc.contEn);
      assignRecord(i, din, desc.inUse);
      assignRecord(i, din, desc.buffId);
      return(desc);
   end function;

end package body AxiDmaPkg;

