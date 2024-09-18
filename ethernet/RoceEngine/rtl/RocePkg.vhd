-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: RoCEv2 Package File
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
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;
use surf.SsiPkg.all;

package RocePkg is

   -- Types
   constant TDATA_ROCE_NUM_BYTES_C : natural range 1 to 128 := 32;
   constant TDATA_UDP_NUM_BYTES_C  : natural range 1 to 128 := 16;

   constant BLUE_DATA_STREAM_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(
      dataBytes => TDATA_ROCE_NUM_BYTES_C,
      tDestBits => 0
      );

   constant SURF_DATA_STREAM_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(
      dataBytes => TDATA_UDP_NUM_BYTES_C,
      tDestBits => 0
      );

   type RoceWorkReqMasterType is record
      valid     : sl;
      id        : slv(63 downto 0);
      opCode    : slv(3 downto 0);
      flags     : slv(4 downto 0);
      rAddr     : slv(63 downto 0);
      rKey      : slv(31 downto 0);
      len       : slv(31 downto 0);
      lAddr     : slv(63 downto 0);
      lKey      : slv(31 downto 0);
      sQpn      : slv(23 downto 0);
      solicited : sl;
      comp      : slv(64 downto 0);
      swap      : slv(64 downto 0);
      immDt     : slv(32 downto 0);
      rKeyToInv : slv(32 downto 0);
      srqn      : slv(24 downto 0);
      dQpn      : slv(24 downto 0);
      qKey      : slv(32 downto 0);
   end record RoceWorkReqMasterType;

   constant ROCE_WORK_REQ_MASTER_INIT_C : RoceWorkReqMasterType := (
      valid     => '0',
      id        => (others => '0'),
      opCode    => (others => '0'),
      flags     => (others => '0'),
      rAddr     => (others => '0'),
      rKey      => (others => '0'),
      len       => (others => '0'),
      lAddr     => (others => '0'),
      lKey      => (others => '0'),
      sQpn      => (others => '0'),
      solicited => '0',
      comp      => (others => '0'),
      swap      => (others => '0'),
      immDt     => (others => '0'),
      rKeyToInv => (others => '0'),
      srqn      => (others => '0'),
      dQpn      => (others => '0'),
      qKey      => (others => '0')
      );

   type RoceWorkReqSlaveType is record
      ready : sl;
   end record RoceWorkReqSlaveType;

   constant ROCE_WORK_REQ_SLAVE_INIT_C : RoceWorkReqSlaveType := (
      ready => '0');

   constant ROCE_WORK_REQ_SLAVE_FORCE_C : RoceWorkReqSlaveType := (
      ready => '1');

   type RoceWorkCompMasterType is record
      valid     : sl;
      id        : slv(63 downto 0);
      opCode    : slv(7 downto 0);
      flags     : slv(6 downto 0);
      status    : slv(4 downto 0);
      len       : slv(31 downto 0);
      pKey      : slv(15 downto 0);
      qpn       : slv(23 downto 0);
      immDt     : slv(32 downto 0);
      rKeyToInv : slv(32 downto 0);
   end record RoceWorkCompMasterType;

   constant ROCE_WORK_COMP_MASTER_INIT_C : RoceWorkCompMasterType := (
      valid     => '0',
      id        => (others => '0'),
      opCode    => (others => '0'),
      flags     => (others => '0'),
      status    => (others => '0'),
      len       => (others => '0'),
      pKey      => (others => '0'),
      qpn       => (others => '0'),
      immDt     => (others => '0'),
      rKeyToInv => (others => '0')
      );

   type RoceWorkCompSlaveType is record
      ready : sl;
   end record RoceWorkCompSlaveType;

   constant ROCE_WORK_COMP_SLAVE_INIT_C : RoceWorkCompSlaveType := (
      ready => '0');

   constant ROCE_WORK_COMP_SLAVE_FORCE_C : RoceWorkCompSlaveType := (
      ready => '1');

   type RoceDmaReadReqMasterType is record
      valid     : sl;
      initiator : slv(3 downto 0);
      sQpn      : slv(23 downto 0);
      wrId      : slv(63 downto 0);
      startAddr : slv(63 downto 0);
      len       : slv(12 downto 0);
      mrIdx     : sl;
   end record RoceDmaReadReqMasterType;

   constant ROCE_DMA_READ_REQ_MASTER_INIT_C : RoceDmaReadReqMasterType := (
      valid     => '0',
      initiator => (others => '0'),
      sQpn      => (others => '0'),
      wrId      => (others => '0'),
      startAddr => (others => '0'),
      len       => (others => '0'),
      mrIdx     => '0'
      );

   type RoceDmaReadReqSlaveType is record
      ready : sl;
   end record RoceDmaReadReqSlaveType;

   constant ROCE_DMA_READ_REQ_SLAVE_INIT_C : RoceDmaReadReqSlaveType := (
      ready => '0');

   constant ROCE_DMA_READ_REQ_SLAVE_FORCE_C : RoceDmaReadReqSlaveType := (
      ready => '1');

   type RoceDmaReadRespMasterType is record
      valid      : sl;
      initiator  : slv(3 downto 0);
      sQpn       : slv(23 downto 0);
      wrId       : slv(63 downto 0);
      isRespErr  : sl;
      dataStream : slv(289 downto 0);
   end record RoceDmaReadRespMasterType;

   constant ROCE_DMA_READ_RESP_MASTER_INIT_C : RoceDmaReadRespMasterType := (
      valid      => '0',
      initiator  => (others => '0'),
      sQpn       => (others => '0'),
      wrId       => (others => '0'),
      isRespErr  => '0',
      dataStream => (others => '0')
      );

   type RoceDmaReadRespSlaveType is record
      ready : sl;
   end record RoceDmaReadRespSlaveType;

   constant ROCE_DMA_READ_RESP_SLAVE_INIT_C : RoceDmaReadRespSlaveType := (
      ready => '0');

   constant ROCE_DMA_READ_RESP_SLAVE_FORCE_C : RoceDmaReadRespSlaveType := (
      ready => '1');

   -- Functions
   function ToRoceWorkReqMasterType (
      valid     : sl;
      id        : slv(63 downto 0);
      opCode    : slv(3 downto 0);
      flags     : slv(4 downto 0);
      rAddr     : slv(63 downto 0);
      rKey      : slv(31 downto 0);
      len       : slv(31 downto 0);
      lAddr     : slv(63 downto 0);
      lKey      : slv(31 downto 0);
      sQpn      : slv(23 downto 0);
      solicited : sl;
      comp      : slv(64 downto 0);
      swap      : slv(64 downto 0);
      immDt     : slv(32 downto 0);
      rKeyToInv : slv(32 downto 0);
      srqn      : slv(24 downto 0);
      dQpn      : slv(24 downto 0);
      qKey      : slv(32 downto 0))
      return RoceWorkReqMasterType;

   function toRoceWorkCompSlaveType (
      ready : sl)
      return RoceWorkCompSlaveType;

   function ToAxisMetadataMasterType (
      valid : sl;
      data  : slv(302 downto 0))
      return AxiStreamMasterType;

   function ToAxisMetadataSlaveType (
      ready : sl)
      return AxiStreamSlaveType;

   function ToDmaReadRespMasterType (
      valid      : sl;
      initiator  : slv(3 downto 0);
      sqpn       : slv(23 downto 0);
      wrId       : slv(63 downto 0);
      isRespErr  : sl;
      dataStream : slv(289 downto 0))
      return RoceDmaReadRespMasterType;

   function ToDmaReadReqSlaveType (
      ready : sl)
      return RoceDmaReadReqSlaveType;

   function DmaReadReqToAxiStreamMaster (
      wrIn : RoceDmaReadReqMasterType)
      return AxiStreamMasterType;

   function DmaReadReqToAxiStreamSlave (
      wrIn : RoceDmaReadReqSlaveType)
      return AxiStreamSlaveType;

   function AxiStreamToDmaReadReqMaster (
      wrIn : AxiStreamMasterType)
      return RoceDmaReadReqMasterType;

   function AxiStreamToDmaReadReqSlave (
      wrIn : AxiStreamSlaveType)
      return RoceDmaReadReqSlaveType;

   -- function WorkReqToAxiStreamMaster (
   --   wrIn : RoceWorkReqMasterType)
   --   return AxiStreamMasterType;

   -- function AxiStreamToWorkReqMaster (
   --   wrIn : AxiStreamMasterType)
   --   return RoceWorkReqMasterType;

   -- function WorkReqToAxiStreamSlave (
   --   wrIn : RoceWorkReqSlaveType)
   --   return AxiStreamSlaveType;

   -- function AxiStreamToWorkReqSlave (
   --   wrIn : AxiStreamSlaveType)
   --   return RoceWorkReqSlaveType;

   -- function FromRoceWorkReqSlaveType (
   --   roceWorkReqSlave : RoceWorkReqSlaveType)
   --   return sl;

   -- function ToRoceWorkCompMasterType (
   --   valid     : sl;
   --   id        : slv(63 downto 0);
   --   opCode    : slv(7 downto 0);
   --   flags     : slv(6 downto 0);
   --   status    : slv(4 downto 0);
   --   len       : slv(31 downto 0);
   --   pKey      : slv(15 downto 0);
   --   qpn       : slv(23 downto 0);
   --   immDt     : slv(32 downto 0);
   --   rKeyToInv : slv(32 downto 0))
   --   return RoceWorkCompMasterType;

end package RocePkg;

package body RocePkg is

   function ToRoceWorkReqMasterType (
      valid     : sl;
      id        : slv(63 downto 0);
      opCode    : slv(3 downto 0);
      flags     : slv(4 downto 0);
      rAddr     : slv(63 downto 0);
      rKey      : slv(31 downto 0);
      len       : slv(31 downto 0);
      lAddr     : slv(63 downto 0);
      lKey      : slv(31 downto 0);
      sQpn      : slv(23 downto 0);
      solicited : sl;
      comp      : slv(64 downto 0);
      swap      : slv(64 downto 0);
      immDt     : slv(32 downto 0);
      rKeyToInv : slv(32 downto 0);
      srqn      : slv(24 downto 0);
      dQpn      : slv(24 downto 0);
      qKey      : slv(32 downto 0))
      return RoceWorkReqMasterType is
      variable ret : RoceWorkReqMasterType;
   begin  -- function ToRoceWorkReqMasterType
      ret.valid     := valid;
      ret.id        := id;
      ret.opCode    := opCode;
      ret.flags     := flags;
      ret.rAddr     := rAddr;
      ret.rKey      := rKey;
      ret.len       := len;
      ret.lAddr     := lAddr;
      ret.lKey      := lKey;
      ret.sQpn      := sQpn;
      ret.solicited := solicited;
      ret.comp      := comp;
      ret.swap      := swap;
      ret.immDt     := immDt;
      ret.rKeyToInv := rKeyToInv;
      ret.srqn      := srqn;
      ret.dQpn      := dQpn;
      ret.qKey      := qKey;
      return ret;
   end function ToRoceWorkReqMasterType;

   function ToRoceWorkCompSlaveType (
      ready : sl)
      return RoceWorkCompSlaveType is
      variable ret : RoceWorkCompSlaveType;
   begin
      ret.ready := ready;
      return ret;
   end function ToRoceWorkCompSlaveType;

   function ToAxisMetadataMasterType (
      valid : sl;
      data  : slv(302 downto 0))
      return AxiStreamMasterType is
      variable ret : AxiStreamMasterType;
   begin
      ret                     := AXI_STREAM_MASTER_INIT_C;
      ret.tValid              := valid;
      ret.tData(302 downto 0) := data;
      return ret;
   end function ToAxisMetadataMasterType;

   function ToAxisMetadataSlaveType (
      ready : sl)
      return AxiStreamSlaveType is
      variable ret : AxiStreamSlaveType;
   begin
      ret.tReady := ready;
      return ret;
   end function ToAxisMetadataSlaveType;

   function ToDmaReadRespMasterType (
      valid      : sl;
      initiator  : slv(3 downto 0);
      sqpn       : slv(23 downto 0);
      wrId       : slv(63 downto 0);
      isRespErr  : sl;
      dataStream : slv(289 downto 0))
      return RoceDmaReadRespMasterType is
      variable ret : RoceDmaReadRespMasterType;
   begin
      ret.valid      := valid;
      ret.initiator  := initiator;
      ret.sqpn       := sqpn;
      ret.wrId       := wrId;
      ret.isRespErr  := isRespErr;
      ret.dataStream := dataStream;
      return ret;
   end function ToDmaReadRespMasterType;

   function ToDmaReadReqSlaveType (
      ready : sl)
      return RoceDmaReadReqSlaveType is
      variable ret : RoceDmaReadReqSlaveType;
   begin
      ret.ready := ready;
      return ret;
   end function ToDmaReadReqSlaveType;

   function DmaReadReqToAxiStreamMaster (
      wrIn : RoceDmaReadReqMasterType)
      return AxiStreamMasterType is
      variable ret : AxiStreamMasterType;
   begin  -- function RoceWorkReqToAxiStream
      ret                     := AXI_STREAM_MASTER_INIT_C;
      ret.tValid              := wrIn.valid;
      ret.tData(169 downto 0) := wrIn.initiator &
                                 wrIn.sQpn &
                                 wrIn.wrId &
                                 wrIn.startAddr &
                                 wrIn.len &
                                 wrIn.mrIdx;
      return ret;
   end function DmaReadReqToAxiStreamMaster;

   function DmaReadReqToAxiStreamSlave (
      wrIn : RoceDmaReadReqSlaveType)
      return AxiStreamSlaveType is
      variable ret : AxiStreamSlaveType;
   begin  -- function RoceWorkReqToAxiStream
      ret.tReady := wrIn.ready;
      return ret;
   end function DmaReadReqToAxiStreamSlave;

   function AxiStreamToDmaReadReqMaster (
      wrIn : AxiStreamMasterType)
      return RoceDmaReadReqMasterType is
      variable ret : RoceDmaReadReqMasterType;
   begin  -- function AxiStreamToRoceWorkReq
      ret.valid     := wrIn.tValid;
      ret.mrIdx     := wrIn.tData(0);
      ret.len       := wrIn.tData(13 downto 1);
      ret.startAddr := wrIn.tData(77 downto 14);
      ret.wrId      := wrIn.tData(141 downto 78);
      ret.sQpn      := wrIn.tData(165 downto 142);
      ret.initiator := wrIn.tData(169 downto 166);
      return ret;
   end function AxiStreamToDmaReadReqMaster;

   function AxiStreamToDmaReadReqSlave (
      wrIn : AxiStreamSlaveType)
      return RoceDmaReadReqSlaveType is
      variable ret : RoceDmaReadReqSlaveType;
   begin  -- function AxiStreamToRoceWorkReq
      ret.ready := wrIn.tReady;
      return ret;
   end function AxiStreamToDmaReadReqSlave;

   -- function FromRoceWorkReqSlaveType (
   --   roceWorkReqSlave : RoceWorkReqSlaveType)
   --   return sl is
   -- begin
   --   return roceWorkReqSlave.tReady;
   -- end function FromRoceWorkReqSlaveType;

   -- function ToRoceWorkCompMasterType (
   --   valid     : sl;
   --   id        : slv(63 downto 0);
   --   opCode    : slv(7 downto 0);
   --   flags     : slv(6 downto 0);
   --   status    : slv(4 downto 0);
   --   len       : slv(31 downto 0);
   --   pKey      : slv(15 downto 0);
   --   qpn       : slv(23 downto 0);
   --   immDt     : slv(32 downto 0);
   --   rKeyToInv : slv(32 downto 0))
   --   return RoceWorkCompMasterType is
   --   variable ret : RoceWorkCompMasterType;
   -- begin  -- function ToRoceWorkCompMasterType
   --   ret.valid     := valid;
   --   ret.id        := id;
   --   ret.opCode    := opCode;
   --   ret.flags     := flags;
   --   ret.status    := status;
   --   ret.len       := len;
   --   ret.pKey      := pKey;
   --   ret.qpn       := qpn;
   --   ret.immDt     := immDt;
   --   ret.rKeyToInv := rKeyToInv;
   --   return ret;
   -- end function ToRoceWorkCompMasterType;


end package body RocePkg;
