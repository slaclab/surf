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

package RoCEv2Pkg is

   -- Types
   constant TDATA_ROCE_NUM_BYTES_C : natural range 1 to 128 := 32;
   constant TDATA_UDP_NUM_BYTES_C  : natural range 1 to 128 := 16;

   constant BLUE_DATA_STREAM_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(
      dataBytes => TDATA_ROCE_NUM_BYTES_C,
      tDestBits => 0
      );

   constant ROCEV2_AXIS_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(
      dataBytes => TDATA_UDP_NUM_BYTES_C,
      tKeepMode => TKEEP_NORMAL_C,
      tDestBits => 0
      );

   type RoCEv2WorkReqMasterType is record
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
   end record RoCEv2WorkReqMasterType;

   constant ROCE_WORK_REQ_MASTER_INIT_C : RoCEv2WorkReqMasterType := (
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

   type RoCEv2WorkReqSlaveType is record
      ready : sl;
   end record RoCEv2WorkReqSlaveType;

   constant ROCE_WORK_REQ_SLAVE_INIT_C : RoCEv2WorkReqSlaveType := (
      ready => '0');

   constant ROCE_WORK_REQ_SLAVE_FORCE_C : RoCEv2WorkReqSlaveType := (
      ready => '1');

   type RoCEv2WorkCompMasterType is record
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
   end record RoCEv2WorkCompMasterType;

   constant ROCE_WORK_COMP_MASTER_INIT_C : RoCEv2WorkCompMasterType := (
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

   type RoCEv2WorkCompSlaveType is record
      ready : sl;
   end record RoCEv2WorkCompSlaveType;

   constant ROCE_WORK_COMP_SLAVE_INIT_C : RoCEv2WorkCompSlaveType := (
      ready => '0');

   constant ROCE_WORK_COMP_SLAVE_FORCE_C : RoCEv2WorkCompSlaveType := (
      ready => '1');

   type RoCEv2DmaReadReqMasterType is record
      valid     : sl;
      initiator : slv(3 downto 0);
      sQpn      : slv(23 downto 0);
      wrId      : slv(63 downto 0);
      startAddr : slv(63 downto 0);
      len       : slv(12 downto 0);
      mrIdx     : sl;
   end record RoCEv2DmaReadReqMasterType;

   constant ROCE_DMA_READ_REQ_MASTER_INIT_C : RoCEv2DmaReadReqMasterType := (
      valid     => '0',
      initiator => (others => '0'),
      sQpn      => (others => '0'),
      wrId      => (others => '0'),
      startAddr => (others => '0'),
      len       => (others => '0'),
      mrIdx     => '0'
      );

   type RoCEv2DmaReadReqSlaveType is record
      ready : sl;
   end record RoCEv2DmaReadReqSlaveType;

   constant ROCE_DMA_READ_REQ_SLAVE_INIT_C : RoCEv2DmaReadReqSlaveType := (
      ready => '0');

   constant ROCE_DMA_READ_REQ_SLAVE_FORCE_C : RoCEv2DmaReadReqSlaveType := (
      ready => '1');

   type RoCEv2DmaReadRespMasterType is record
      valid      : sl;
      initiator  : slv(3 downto 0);
      sQpn       : slv(23 downto 0);
      wrId       : slv(63 downto 0);
      isRespErr  : sl;
      dataStream : slv(289 downto 0);
   end record RoCEv2DmaReadRespMasterType;

   constant ROCE_DMA_READ_RESP_MASTER_INIT_C : RoCEv2DmaReadRespMasterType := (
      valid      => '0',
      initiator  => (others => '0'),
      sQpn       => (others => '0'),
      wrId       => (others => '0'),
      isRespErr  => '0',
      dataStream => (others => '0')
      );

   type RoCEv2DmaReadRespSlaveType is record
      ready : sl;
   end record RoCEv2DmaReadRespSlaveType;

   constant ROCE_DMA_READ_RESP_SLAVE_INIT_C : RoCEv2DmaReadRespSlaveType := (
      ready => '0');

   constant ROCE_DMA_READ_RESP_SLAVE_FORCE_C : RoCEv2DmaReadRespSlaveType := (
      ready => '1');

   -- Functions
   function ToRoCEv2WorkReqMasterType (
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
      return RoCEv2WorkReqMasterType;

   function toRoCEv2WorkCompSlaveType (
      ready : sl)
      return RoCEv2WorkCompSlaveType;

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
      return RoCEv2DmaReadRespMasterType;

   function ToDmaReadReqSlaveType (
      ready : sl)
      return RoCEv2DmaReadReqSlaveType;

   function DmaReadReqToAxiStreamMaster (
      wrIn : RoCEv2DmaReadReqMasterType)
      return AxiStreamMasterType;

   function DmaReadReqToAxiStreamSlave (
      wrIn : RoCEv2DmaReadReqSlaveType)
      return AxiStreamSlaveType;

   function AxiStreamToDmaReadReqMaster (
      wrIn : AxiStreamMasterType)
      return RoCEv2DmaReadReqMasterType;

   function AxiStreamToDmaReadReqSlave (
      wrIn : AxiStreamSlaveType)
      return RoCEv2DmaReadReqSlaveType;

   -- function WorkReqToAxiStreamMaster (
   --   wrIn : RoCEv2WorkReqMasterType)
   --   return AxiStreamMasterType;

   -- function AxiStreamToWorkReqMaster (
   --   wrIn : AxiStreamMasterType)
   --   return RoCEv2WorkReqMasterType;

   -- function WorkReqToAxiStreamSlave (
   --   wrIn : RoCEv2WorkReqSlaveType)
   --   return AxiStreamSlaveType;

   -- function AxiStreamToWorkReqSlave (
   --   wrIn : AxiStreamSlaveType)
   --   return RoCEv2WorkReqSlaveType;

   -- function FromRoCEv2WorkReqSlaveType (
   --   roceWorkReqSlave : RoCEv2WorkReqSlaveType)
   --   return sl;

   -- function ToRoCEv2WorkCompMasterType (
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
   --   return RoCEv2WorkCompMasterType;

end package RoCEv2Pkg;

package body RoCEv2Pkg is

   function ToRoCEv2WorkReqMasterType (
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
      return RoCEv2WorkReqMasterType is
      variable ret : RoCEv2WorkReqMasterType;
   begin  -- function ToRoCEv2WorkReqMasterType
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
   end function ToRoCEv2WorkReqMasterType;

   function ToRoCEv2WorkCompSlaveType (
      ready : sl)
      return RoCEv2WorkCompSlaveType is
      variable ret : RoCEv2WorkCompSlaveType;
   begin
      ret.ready := ready;
      return ret;
   end function ToRoCEv2WorkCompSlaveType;

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
      return RoCEv2DmaReadRespMasterType is
      variable ret : RoCEv2DmaReadRespMasterType;
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
      return RoCEv2DmaReadReqSlaveType is
      variable ret : RoCEv2DmaReadReqSlaveType;
   begin
      ret.ready := ready;
      return ret;
   end function ToDmaReadReqSlaveType;

   function DmaReadReqToAxiStreamMaster (
      wrIn : RoCEv2DmaReadReqMasterType)
      return AxiStreamMasterType is
      variable ret : AxiStreamMasterType;
   begin  -- function DmaReadReqToAxiStreamMaster
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
      wrIn : RoCEv2DmaReadReqSlaveType)
      return AxiStreamSlaveType is
      variable ret : AxiStreamSlaveType;
   begin  -- function DmaReadReqToAxiStreamSlave
      ret.tReady := wrIn.ready;
      return ret;
   end function DmaReadReqToAxiStreamSlave;

   function AxiStreamToDmaReadReqMaster (
      wrIn : AxiStreamMasterType)
      return RoCEv2DmaReadReqMasterType is
      variable ret : RoCEv2DmaReadReqMasterType;
   begin  -- function AxiStreamToDmaReadReqMaster
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
      return RoCEv2DmaReadReqSlaveType is
      variable ret : RoCEv2DmaReadReqSlaveType;
   begin  -- function AxiStreamToDmaReadReqSlave
      ret.ready := wrIn.tReady;
      return ret;
   end function AxiStreamToDmaReadReqSlave;

   -- function FromRoCEv2WorkReqSlaveType (
   --   roceWorkReqSlave : RoCEv2WorkReqSlaveType)
   --   return sl is
   -- begin
   --   return roceWorkReqSlave.tReady;
   -- end function FromRoCEv2WorkReqSlaveType;

   -- function ToRoCEv2WorkCompMasterType (
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
   --   return RoCEv2WorkCompMasterType is
   --   variable ret : RoCEv2WorkCompMasterType;
   -- begin  -- function ToRoCEv2WorkCompMasterType
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
   -- end function ToRoCEv2WorkCompMasterType;


end package body RoCEv2Pkg;
