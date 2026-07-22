-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Provenance : HAND-WRITTEN integration package (not BSV-derived). Extended
--              from style/examples/RocePkg.vhd (SLAC, old blue-rdma design)
--              to match the structs emitted by THIS project's transpile.
-- Struct refs: src-bsv/DataTypes.bsv (WorkReq:525-543, RecvReq:578-586,
--              DmaReadReq:265-272, DmaReadResp:274-280, DmaWriteReq:282-293,
--              DmaWriteResp:295-300, DataStream), src-bsv/MetaData.bsv
--              (ReqPD/RespPD:253-263, ReqMR/RespMR:163-177, MetaDataReq/
--              Resp:661-671), src-bsv/Controller.bsv (ReqQP/RespQP:60-76).
-------------------------------------------------------------------------------
-- Conventions:
--   * One record type per BSV struct, fields in BSV declaration order
--     (deriving(Bits) packs first-field-at-MSB in the flat slv).
--   * <X>ToSlv / SlvTo<X>  : record <-> flat slv (TransportLayer port format).
--   * <X>ToAxiStream / AxiStreamTo<X> : record <-> single-beat AXI-Stream,
--     struct LSB-justified in tData, tLast='1' per beat.
--   * DataStream (the RoCE wire stream) is BYTE-SWAPPED on AXIS: BSV puts the
--     first wire byte in the data MSBs / byteEn bit 31; AXI-Stream puts it in
--     tData lane 0 / tKeep(0). isLast -> tLast, isFirst -> SSI SOF (tUser).
--   * The dataStream fields EMBEDDED in DmaReadResp/DmaWriteReq stay in raw
--     BSV format (slv(289:0), first byte at MSBs) inside tData - only the
--     network-facing stream is lane-swapped.
--   * Changes vs the old style/examples/RocePkg.vhd: mrIdx is slv(6:0)
--     (IndexMR = 7b here, DmaReadReq = 176b not 170b); RecvReq / DmaWrite
--     types added; metadata AXIS helpers dropped (metadata is AXI-Lite now,
--     see RoceMetaDataAxil.vhd).
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
use ieee.numeric_std.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;
use surf.SsiPkg.all;

package RocePkg is

   ---------------------------------------------------------------------------
   -- Stream configurations
   ---------------------------------------------------------------------------
   constant TDATA_ROCE_NUM_BYTES_C : natural range 1 to 128 := 32;
   constant TDATA_UDP_NUM_BYTES_C  : natural range 1 to 128 := 16;

   constant BLUE_DATA_STREAM_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(
      dataBytes => TDATA_ROCE_NUM_BYTES_C,
      tDestBits => 0);

   constant SURF_DATA_STREAM_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(
      dataBytes => TDATA_UDP_NUM_BYTES_C,
      tDestBits => 0);

   ---------------------------------------------------------------------------
   -- Flat struct widths (TransportLayer port formats)
   ---------------------------------------------------------------------------
   constant ROCE_DATA_STREAM_W_C   : positive := 290;
   constant ROCE_WORK_REQ_W_C      : positive := 601;
   constant ROCE_RECV_REQ_W_C      : positive := 216;
   constant ROCE_WORK_COMP_W_C     : positive := 222;
   constant ROCE_DMA_RD_REQ_W_C    : positive := 176;
   constant ROCE_DMA_RD_RESP_W_C   : positive := 383;
   constant ROCE_DMA_WR_REQ_W_C    : positive := 419;
   constant ROCE_DMA_WR_RESP_W_C   : positive := 53;
   constant ROCE_MD_REQ_W_C        : positive := 303;
   constant ROCE_MD_RESP_W_C       : positive := 276;

   -- MetaDataReq/Resp union tags (MetaData.bsv:661-671, first member = 0)
   constant ROCE_MD_TAG_PD_C : slv(1 downto 0) := "00";
   constant ROCE_MD_TAG_MR_C : slv(1 downto 0) := "01";
   constant ROCE_MD_TAG_QP_C : slv(1 downto 0) := "10";

   ---------------------------------------------------------------------------
   -- DataStream (raw RoCE wire beat; DataTypes.bsv DataStream)
   --   flat: data[289:34] byteEn[33:2] isFirst[1] isLast[0]
   --   first wire byte = data(255 downto 248) = byteEn bit 31
   ---------------------------------------------------------------------------
   type RoceDataStreamMasterType is record
      valid   : sl;
      data    : slv(255 downto 0);
      byteEn  : slv(31 downto 0);
      isFirst : sl;
      isLast  : sl;
   end record RoceDataStreamMasterType;

   constant ROCE_DATA_STREAM_MASTER_INIT_C : RoceDataStreamMasterType := (
      valid   => '0',
      data    => (others => '0'),
      byteEn  => (others => '0'),
      isFirst => '0',
      isLast  => '0');

   type RoceDataStreamSlaveType is record
      ready : sl;
   end record RoceDataStreamSlaveType;

   constant ROCE_DATA_STREAM_SLAVE_INIT_C  : RoceDataStreamSlaveType := (ready => '0');
   constant ROCE_DATA_STREAM_SLAVE_FORCE_C : RoceDataStreamSlaveType := (ready => '1');

   ---------------------------------------------------------------------------
   -- WorkReq (DataTypes.bsv:525-543; 601b)
   ---------------------------------------------------------------------------
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
      comp      : slv(64 downto 0);     -- Maybe#(Long),  tag at MSB
      swap      : slv(64 downto 0);     -- Maybe#(Long)
      immDt     : slv(32 downto 0);     -- Maybe#(IMM)
      rKeyToInv : slv(32 downto 0);     -- Maybe#(RKEY)
      srqn      : slv(24 downto 0);     -- Maybe#(QPN)
      dQpn      : slv(24 downto 0);     -- Maybe#(QPN)
      qKey      : slv(32 downto 0);     -- Maybe#(QKEY)
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
      qKey      => (others => '0'));

   type RoceWorkReqSlaveType is record
      ready : sl;
   end record RoceWorkReqSlaveType;

   constant ROCE_WORK_REQ_SLAVE_INIT_C  : RoceWorkReqSlaveType := (ready => '0');
   constant ROCE_WORK_REQ_SLAVE_FORCE_C : RoceWorkReqSlaveType := (ready => '1');

   ---------------------------------------------------------------------------
   -- RecvReq (DataTypes.bsv:578-586; 216b)
   ---------------------------------------------------------------------------
   type RoceRecvReqMasterType is record
      valid : sl;
      id    : slv(63 downto 0);
      len   : slv(31 downto 0);
      lAddr : slv(63 downto 0);
      lKey  : slv(31 downto 0);
      sQpn  : slv(23 downto 0);
   end record RoceRecvReqMasterType;

   constant ROCE_RECV_REQ_MASTER_INIT_C : RoceRecvReqMasterType := (
      valid => '0',
      id    => (others => '0'),
      len   => (others => '0'),
      lAddr => (others => '0'),
      lKey  => (others => '0'),
      sQpn  => (others => '0'));

   type RoceRecvReqSlaveType is record
      ready : sl;
   end record RoceRecvReqSlaveType;

   constant ROCE_RECV_REQ_SLAVE_INIT_C  : RoceRecvReqSlaveType := (ready => '0');
   constant ROCE_RECV_REQ_SLAVE_FORCE_C : RoceRecvReqSlaveType := (ready => '1');

   ---------------------------------------------------------------------------
   -- WorkComp (DataTypes.bsv WorkComp; 222b)
   ---------------------------------------------------------------------------
   type RoceWorkCompMasterType is record
      valid     : sl;
      id        : slv(63 downto 0);
      opCode    : slv(7 downto 0);
      flags     : slv(6 downto 0);
      status    : slv(4 downto 0);
      len       : slv(31 downto 0);
      pKey      : slv(15 downto 0);
      qpn       : slv(23 downto 0);
      immDt     : slv(32 downto 0);     -- Maybe#(IMM)
      rKeyToInv : slv(32 downto 0);     -- Maybe#(RKEY)
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
      rKeyToInv => (others => '0'));

   type RoceWorkCompSlaveType is record
      ready : sl;
   end record RoceWorkCompSlaveType;

   constant ROCE_WORK_COMP_SLAVE_INIT_C  : RoceWorkCompSlaveType := (ready => '0');
   constant ROCE_WORK_COMP_SLAVE_FORCE_C : RoceWorkCompSlaveType := (ready => '1');

   ---------------------------------------------------------------------------
   -- DmaReadReq (DataTypes.bsv:265-272; 176b — IndexMR mrIdx is 7b here)
   ---------------------------------------------------------------------------
   type RoceDmaReadReqMasterType is record
      valid     : sl;
      initiator : slv(3 downto 0);
      sQpn      : slv(23 downto 0);
      wrId      : slv(63 downto 0);
      startAddr : slv(63 downto 0);
      len       : slv(12 downto 0);
      mrIdx     : slv(6 downto 0);
   end record RoceDmaReadReqMasterType;

   constant ROCE_DMA_READ_REQ_MASTER_INIT_C : RoceDmaReadReqMasterType := (
      valid     => '0',
      initiator => (others => '0'),
      sQpn      => (others => '0'),
      wrId      => (others => '0'),
      startAddr => (others => '0'),
      len       => (others => '0'),
      mrIdx     => (others => '0'));

   type RoceDmaReadReqSlaveType is record
      ready : sl;
   end record RoceDmaReadReqSlaveType;

   constant ROCE_DMA_READ_REQ_SLAVE_INIT_C  : RoceDmaReadReqSlaveType := (ready => '0');
   constant ROCE_DMA_READ_REQ_SLAVE_FORCE_C : RoceDmaReadReqSlaveType := (ready => '1');

   ---------------------------------------------------------------------------
   -- DmaReadResp (DataTypes.bsv:274-280; 383b; dataStream in raw BSV format)
   ---------------------------------------------------------------------------
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
      dataStream => (others => '0'));

   type RoceDmaReadRespSlaveType is record
      ready : sl;
   end record RoceDmaReadRespSlaveType;

   constant ROCE_DMA_READ_RESP_SLAVE_INIT_C  : RoceDmaReadRespSlaveType := (ready => '0');
   constant ROCE_DMA_READ_RESP_SLAVE_FORCE_C : RoceDmaReadRespSlaveType := (ready => '1');

   ---------------------------------------------------------------------------
   -- DmaWriteReq (DataTypes.bsv:282-293; 419b = DmaWriteMetaData(129) + DataStream(290))
   ---------------------------------------------------------------------------
   type RoceDmaWriteReqMasterType is record
      valid      : sl;
      initiator  : slv(3 downto 0);
      sQpn       : slv(23 downto 0);
      startAddr  : slv(63 downto 0);
      len        : slv(12 downto 0);
      psn        : slv(23 downto 0);
      dataStream : slv(289 downto 0);
   end record RoceDmaWriteReqMasterType;

   constant ROCE_DMA_WRITE_REQ_MASTER_INIT_C : RoceDmaWriteReqMasterType := (
      valid      => '0',
      initiator  => (others => '0'),
      sQpn       => (others => '0'),
      startAddr  => (others => '0'),
      len        => (others => '0'),
      psn        => (others => '0'),
      dataStream => (others => '0'));

   type RoceDmaWriteReqSlaveType is record
      ready : sl;
   end record RoceDmaWriteReqSlaveType;

   constant ROCE_DMA_WRITE_REQ_SLAVE_INIT_C  : RoceDmaWriteReqSlaveType := (ready => '0');
   constant ROCE_DMA_WRITE_REQ_SLAVE_FORCE_C : RoceDmaWriteReqSlaveType := (ready => '1');

   ---------------------------------------------------------------------------
   -- DmaWriteResp (DataTypes.bsv:295-300; 53b)
   ---------------------------------------------------------------------------
   type RoceDmaWriteRespMasterType is record
      valid     : sl;
      initiator : slv(3 downto 0);
      sQpn      : slv(23 downto 0);
      psn       : slv(23 downto 0);
      isRespErr : sl;
   end record RoceDmaWriteRespMasterType;

   constant ROCE_DMA_WRITE_RESP_MASTER_INIT_C : RoceDmaWriteRespMasterType := (
      valid     => '0',
      initiator => (others => '0'),
      sQpn      => (others => '0'),
      psn       => (others => '0'),
      isRespErr => '0');

   type RoceDmaWriteRespSlaveType is record
      ready : sl;
   end record RoceDmaWriteRespSlaveType;

   constant ROCE_DMA_WRITE_RESP_SLAVE_INIT_C  : RoceDmaWriteRespSlaveType := (ready => '0');
   constant ROCE_DMA_WRITE_RESP_SLAVE_FORCE_C : RoceDmaWriteRespSlaveType := (ready => '1');

   ---------------------------------------------------------------------------
   -- Conversion functions
   ---------------------------------------------------------------------------
   -- generic AXIS slave helper
   function ToAxiStreamSlave (ready : sl) return AxiStreamSlaveType;

   -- DataStream (network-facing; BYTE-SWAPPED on AXIS)
   function DataStreamToSlv (ds : RoceDataStreamMasterType) return slv;
   function SlvToDataStream (valid : sl; d : slv(289 downto 0)) return RoceDataStreamMasterType;
   function DataStreamToAxiStream (ds : RoceDataStreamMasterType) return AxiStreamMasterType;
   function AxiStreamToDataStream (axis : AxiStreamMasterType) return RoceDataStreamMasterType;

   -- WorkReq
   function WorkReqToSlv (wr : RoceWorkReqMasterType) return slv;
   function SlvToWorkReq (valid : sl; d : slv(600 downto 0)) return RoceWorkReqMasterType;
   function WorkReqToAxiStream (wr : RoceWorkReqMasterType) return AxiStreamMasterType;
   function AxiStreamToWorkReq (axis : AxiStreamMasterType) return RoceWorkReqMasterType;

   -- RecvReq
   function RecvReqToSlv (rr : RoceRecvReqMasterType) return slv;
   function SlvToRecvReq (valid : sl; d : slv(215 downto 0)) return RoceRecvReqMasterType;
   function RecvReqToAxiStream (rr : RoceRecvReqMasterType) return AxiStreamMasterType;
   function AxiStreamToRecvReq (axis : AxiStreamMasterType) return RoceRecvReqMasterType;

   -- WorkComp
   function WorkCompToSlv (wc : RoceWorkCompMasterType) return slv;
   function SlvToWorkComp (valid : sl; d : slv(221 downto 0)) return RoceWorkCompMasterType;
   function WorkCompToAxiStream (wc : RoceWorkCompMasterType) return AxiStreamMasterType;
   function AxiStreamToWorkComp (axis : AxiStreamMasterType) return RoceWorkCompMasterType;

   -- DmaReadReq
   function DmaReadReqToSlv (req : RoceDmaReadReqMasterType) return slv;
   function SlvToDmaReadReq (valid : sl; d : slv(175 downto 0)) return RoceDmaReadReqMasterType;
   function DmaReadReqToAxiStream (req : RoceDmaReadReqMasterType) return AxiStreamMasterType;
   function AxiStreamToDmaReadReq (axis : AxiStreamMasterType) return RoceDmaReadReqMasterType;

   -- DmaReadResp
   function DmaReadRespToSlv (resp : RoceDmaReadRespMasterType) return slv;
   function SlvToDmaReadResp (valid : sl; d : slv(382 downto 0)) return RoceDmaReadRespMasterType;
   function DmaReadRespToAxiStream (resp : RoceDmaReadRespMasterType) return AxiStreamMasterType;
   function AxiStreamToDmaReadResp (axis : AxiStreamMasterType) return RoceDmaReadRespMasterType;

   -- DmaWriteReq
   function DmaWriteReqToSlv (req : RoceDmaWriteReqMasterType) return slv;
   function SlvToDmaWriteReq (valid : sl; d : slv(418 downto 0)) return RoceDmaWriteReqMasterType;
   function DmaWriteReqToAxiStream (req : RoceDmaWriteReqMasterType) return AxiStreamMasterType;
   function AxiStreamToDmaWriteReq (axis : AxiStreamMasterType) return RoceDmaWriteReqMasterType;

   -- DmaWriteResp
   function DmaWriteRespToSlv (resp : RoceDmaWriteRespMasterType) return slv;
   function SlvToDmaWriteResp (valid : sl; d : slv(52 downto 0)) return RoceDmaWriteRespMasterType;
   function DmaWriteRespToAxiStream (resp : RoceDmaWriteRespMasterType) return AxiStreamMasterType;
   function AxiStreamToDmaWriteResp (axis : AxiStreamMasterType) return RoceDmaWriteRespMasterType;

end package RocePkg;

package body RocePkg is

   function ToAxiStreamSlave (ready : sl) return AxiStreamSlaveType is
      variable ret : AxiStreamSlaveType;
   begin
      ret.tReady := ready;
      return ret;
   end function ToAxiStreamSlave;

   ---------------------------------------------------------------------------
   -- DataStream
   ---------------------------------------------------------------------------
   function DataStreamToSlv (ds : RoceDataStreamMasterType) return slv is
   begin
      return ds.data & ds.byteEn & ds.isFirst & ds.isLast;
   end function DataStreamToSlv;

   function SlvToDataStream (valid : sl; d : slv(289 downto 0)) return RoceDataStreamMasterType is
      variable ret : RoceDataStreamMasterType;
   begin
      ret.valid   := valid;
      ret.data    := d(289 downto 34);
      ret.byteEn  := d(33 downto 2);
      ret.isFirst := d(1);
      ret.isLast  := d(0);
      return ret;
   end function SlvToDataStream;

   -- BSV DataStream: first wire byte = data(255:248), byteEn(31).
   -- AXI-Stream:     first wire byte = tData(7:0),     tKeep(0).
   function DataStreamToAxiStream (ds : RoceDataStreamMasterType) return AxiStreamMasterType is
      variable ret : AxiStreamMasterType;
   begin
      ret        := axiStreamMasterInit(BLUE_DATA_STREAM_CONFIG_C);
      ret.tValid := ds.valid;
      for j in 0 to 31 loop
         ret.tData(8*j+7 downto 8*j) := ds.data(255-8*j downto 248-8*j);
         ret.tKeep(j)                := ds.byteEn(31-j);
      end loop;
      ret.tLast := ds.isLast;
      ssiSetUserSof(BLUE_DATA_STREAM_CONFIG_C, ret, ds.isFirst);
      return ret;
   end function DataStreamToAxiStream;

   function AxiStreamToDataStream (axis : AxiStreamMasterType) return RoceDataStreamMasterType is
      variable ret : RoceDataStreamMasterType;
   begin
      ret.valid := axis.tValid;
      for j in 0 to 31 loop
         ret.data(255-8*j downto 248-8*j) := axis.tData(8*j+7 downto 8*j);
         ret.byteEn(31-j)                 := axis.tKeep(j);
      end loop;
      ret.isFirst := ssiGetUserSof(BLUE_DATA_STREAM_CONFIG_C, axis);
      ret.isLast  := axis.tLast;
      return ret;
   end function AxiStreamToDataStream;

   ---------------------------------------------------------------------------
   -- WorkReq (601b): id[600:537] opCode[536:533] flags[532:528] rAddr[527:464]
   --   rKey[463:432] len[431:400] lAddr[399:336] lKey[335:304] sQpn[303:280]
   --   solicited[279] comp[278:214] swap[213:149] immDt[148:116]
   --   rKeyToInv[115:83] srqn[82:58] dQpn[57:33] qKey[32:0]
   ---------------------------------------------------------------------------
   function WorkReqToSlv (wr : RoceWorkReqMasterType) return slv is
   begin
      return wr.id & wr.opCode & wr.flags & wr.rAddr & wr.rKey & wr.len &
             wr.lAddr & wr.lKey & wr.sQpn & wr.solicited & wr.comp & wr.swap &
             wr.immDt & wr.rKeyToInv & wr.srqn & wr.dQpn & wr.qKey;
   end function WorkReqToSlv;

   function SlvToWorkReq (valid : sl; d : slv(600 downto 0)) return RoceWorkReqMasterType is
      variable ret : RoceWorkReqMasterType;
   begin
      ret.valid     := valid;
      ret.id        := d(600 downto 537);
      ret.opCode    := d(536 downto 533);
      ret.flags     := d(532 downto 528);
      ret.rAddr     := d(527 downto 464);
      ret.rKey      := d(463 downto 432);
      ret.len       := d(431 downto 400);
      ret.lAddr     := d(399 downto 336);
      ret.lKey      := d(335 downto 304);
      ret.sQpn      := d(303 downto 280);
      ret.solicited := d(279);
      ret.comp      := d(278 downto 214);
      ret.swap      := d(213 downto 149);
      ret.immDt     := d(148 downto 116);
      ret.rKeyToInv := d(115 downto 83);
      ret.srqn      := d(82 downto 58);
      ret.dQpn      := d(57 downto 33);
      ret.qKey      := d(32 downto 0);
      return ret;
   end function SlvToWorkReq;

   function WorkReqToAxiStream (wr : RoceWorkReqMasterType) return AxiStreamMasterType is
      variable ret : AxiStreamMasterType;
   begin
      ret                     := AXI_STREAM_MASTER_INIT_C;
      ret.tValid              := wr.valid;
      ret.tData(600 downto 0) := WorkReqToSlv(wr);
      ret.tLast               := '1';
      return ret;
   end function WorkReqToAxiStream;

   function AxiStreamToWorkReq (axis : AxiStreamMasterType) return RoceWorkReqMasterType is
   begin
      return SlvToWorkReq(axis.tValid, axis.tData(600 downto 0));
   end function AxiStreamToWorkReq;

   ---------------------------------------------------------------------------
   -- RecvReq (216b): id[215:152] len[151:120] lAddr[119:56] lKey[55:24] sQpn[23:0]
   ---------------------------------------------------------------------------
   function RecvReqToSlv (rr : RoceRecvReqMasterType) return slv is
   begin
      return rr.id & rr.len & rr.lAddr & rr.lKey & rr.sQpn;
   end function RecvReqToSlv;

   function SlvToRecvReq (valid : sl; d : slv(215 downto 0)) return RoceRecvReqMasterType is
      variable ret : RoceRecvReqMasterType;
   begin
      ret.valid := valid;
      ret.id    := d(215 downto 152);
      ret.len   := d(151 downto 120);
      ret.lAddr := d(119 downto 56);
      ret.lKey  := d(55 downto 24);
      ret.sQpn  := d(23 downto 0);
      return ret;
   end function SlvToRecvReq;

   function RecvReqToAxiStream (rr : RoceRecvReqMasterType) return AxiStreamMasterType is
      variable ret : AxiStreamMasterType;
   begin
      ret                     := AXI_STREAM_MASTER_INIT_C;
      ret.tValid              := rr.valid;
      ret.tData(215 downto 0) := RecvReqToSlv(rr);
      ret.tLast               := '1';
      return ret;
   end function RecvReqToAxiStream;

   function AxiStreamToRecvReq (axis : AxiStreamMasterType) return RoceRecvReqMasterType is
   begin
      return SlvToRecvReq(axis.tValid, axis.tData(215 downto 0));
   end function AxiStreamToRecvReq;

   ---------------------------------------------------------------------------
   -- WorkComp (222b): id[221:158] opCode[157:150] flags[149:143] status[142:138]
   --   len[137:106] pKey[105:90] qpn[89:66] immDt[65:33] rKeyToInv[32:0]
   ---------------------------------------------------------------------------
   function WorkCompToSlv (wc : RoceWorkCompMasterType) return slv is
   begin
      return wc.id & wc.opCode & wc.flags & wc.status & wc.len & wc.pKey &
             wc.qpn & wc.immDt & wc.rKeyToInv;
   end function WorkCompToSlv;

   function SlvToWorkComp (valid : sl; d : slv(221 downto 0)) return RoceWorkCompMasterType is
      variable ret : RoceWorkCompMasterType;
   begin
      ret.valid     := valid;
      ret.id        := d(221 downto 158);
      ret.opCode    := d(157 downto 150);
      ret.flags     := d(149 downto 143);
      ret.status    := d(142 downto 138);
      ret.len       := d(137 downto 106);
      ret.pKey      := d(105 downto 90);
      ret.qpn       := d(89 downto 66);
      ret.immDt     := d(65 downto 33);
      ret.rKeyToInv := d(32 downto 0);
      return ret;
   end function SlvToWorkComp;

   function WorkCompToAxiStream (wc : RoceWorkCompMasterType) return AxiStreamMasterType is
      variable ret : AxiStreamMasterType;
   begin
      ret                     := AXI_STREAM_MASTER_INIT_C;
      ret.tValid              := wc.valid;
      ret.tData(221 downto 0) := WorkCompToSlv(wc);
      ret.tLast               := '1';
      return ret;
   end function WorkCompToAxiStream;

   function AxiStreamToWorkComp (axis : AxiStreamMasterType) return RoceWorkCompMasterType is
   begin
      return SlvToWorkComp(axis.tValid, axis.tData(221 downto 0));
   end function AxiStreamToWorkComp;

   ---------------------------------------------------------------------------
   -- DmaReadReq (176b): initiator[175:172] sQpn[171:148] wrId[147:84]
   --   startAddr[83:20] len[19:7] mrIdx[6:0]
   ---------------------------------------------------------------------------
   function DmaReadReqToSlv (req : RoceDmaReadReqMasterType) return slv is
   begin
      return req.initiator & req.sQpn & req.wrId & req.startAddr & req.len & req.mrIdx;
   end function DmaReadReqToSlv;

   function SlvToDmaReadReq (valid : sl; d : slv(175 downto 0)) return RoceDmaReadReqMasterType is
      variable ret : RoceDmaReadReqMasterType;
   begin
      ret.valid     := valid;
      ret.initiator := d(175 downto 172);
      ret.sQpn      := d(171 downto 148);
      ret.wrId      := d(147 downto 84);
      ret.startAddr := d(83 downto 20);
      ret.len       := d(19 downto 7);
      ret.mrIdx     := d(6 downto 0);
      return ret;
   end function SlvToDmaReadReq;

   function DmaReadReqToAxiStream (req : RoceDmaReadReqMasterType) return AxiStreamMasterType is
      variable ret : AxiStreamMasterType;
   begin
      ret                     := AXI_STREAM_MASTER_INIT_C;
      ret.tValid              := req.valid;
      ret.tData(175 downto 0) := DmaReadReqToSlv(req);
      ret.tLast               := '1';
      return ret;
   end function DmaReadReqToAxiStream;

   function AxiStreamToDmaReadReq (axis : AxiStreamMasterType) return RoceDmaReadReqMasterType is
   begin
      return SlvToDmaReadReq(axis.tValid, axis.tData(175 downto 0));
   end function AxiStreamToDmaReadReq;

   ---------------------------------------------------------------------------
   -- DmaReadResp (383b): initiator[382:379] sQpn[378:355] wrId[354:291]
   --   isRespErr[290] dataStream[289:0]
   ---------------------------------------------------------------------------
   function DmaReadRespToSlv (resp : RoceDmaReadRespMasterType) return slv is
   begin
      return resp.initiator & resp.sQpn & resp.wrId & resp.isRespErr & resp.dataStream;
   end function DmaReadRespToSlv;

   function SlvToDmaReadResp (valid : sl; d : slv(382 downto 0)) return RoceDmaReadRespMasterType is
      variable ret : RoceDmaReadRespMasterType;
   begin
      ret.valid      := valid;
      ret.initiator  := d(382 downto 379);
      ret.sQpn       := d(378 downto 355);
      ret.wrId       := d(354 downto 291);
      ret.isRespErr  := d(290);
      ret.dataStream := d(289 downto 0);
      return ret;
   end function SlvToDmaReadResp;

   function DmaReadRespToAxiStream (resp : RoceDmaReadRespMasterType) return AxiStreamMasterType is
      variable ret : AxiStreamMasterType;
   begin
      ret                     := AXI_STREAM_MASTER_INIT_C;
      ret.tValid              := resp.valid;
      ret.tData(382 downto 0) := DmaReadRespToSlv(resp);
      ret.tLast               := '1';
      return ret;
   end function DmaReadRespToAxiStream;

   function AxiStreamToDmaReadResp (axis : AxiStreamMasterType) return RoceDmaReadRespMasterType is
   begin
      return SlvToDmaReadResp(axis.tValid, axis.tData(382 downto 0));
   end function AxiStreamToDmaReadResp;

   ---------------------------------------------------------------------------
   -- DmaWriteReq (419b): initiator[418:415] sQpn[414:391] startAddr[390:327]
   --   len[326:314] psn[313:290] dataStream[289:0]
   ---------------------------------------------------------------------------
   function DmaWriteReqToSlv (req : RoceDmaWriteReqMasterType) return slv is
   begin
      return req.initiator & req.sQpn & req.startAddr & req.len & req.psn & req.dataStream;
   end function DmaWriteReqToSlv;

   function SlvToDmaWriteReq (valid : sl; d : slv(418 downto 0)) return RoceDmaWriteReqMasterType is
      variable ret : RoceDmaWriteReqMasterType;
   begin
      ret.valid      := valid;
      ret.initiator  := d(418 downto 415);
      ret.sQpn       := d(414 downto 391);
      ret.startAddr  := d(390 downto 327);
      ret.len        := d(326 downto 314);
      ret.psn        := d(313 downto 290);
      ret.dataStream := d(289 downto 0);
      return ret;
   end function SlvToDmaWriteReq;

   function DmaWriteReqToAxiStream (req : RoceDmaWriteReqMasterType) return AxiStreamMasterType is
      variable ret : AxiStreamMasterType;
   begin
      ret                     := AXI_STREAM_MASTER_INIT_C;
      ret.tValid              := req.valid;
      ret.tData(418 downto 0) := DmaWriteReqToSlv(req);
      ret.tLast               := '1';
      return ret;
   end function DmaWriteReqToAxiStream;

   function AxiStreamToDmaWriteReq (axis : AxiStreamMasterType) return RoceDmaWriteReqMasterType is
   begin
      return SlvToDmaWriteReq(axis.tValid, axis.tData(418 downto 0));
   end function AxiStreamToDmaWriteReq;

   ---------------------------------------------------------------------------
   -- DmaWriteResp (53b): initiator[52:49] sQpn[48:25] psn[24:1] isRespErr[0]
   ---------------------------------------------------------------------------
   function DmaWriteRespToSlv (resp : RoceDmaWriteRespMasterType) return slv is
   begin
      return resp.initiator & resp.sQpn & resp.psn & resp.isRespErr;
   end function DmaWriteRespToSlv;

   function SlvToDmaWriteResp (valid : sl; d : slv(52 downto 0)) return RoceDmaWriteRespMasterType is
      variable ret : RoceDmaWriteRespMasterType;
   begin
      ret.valid     := valid;
      ret.initiator := d(52 downto 49);
      ret.sQpn      := d(48 downto 25);
      ret.psn       := d(24 downto 1);
      ret.isRespErr := d(0);
      return ret;
   end function SlvToDmaWriteResp;

   function DmaWriteRespToAxiStream (resp : RoceDmaWriteRespMasterType) return AxiStreamMasterType is
      variable ret : AxiStreamMasterType;
   begin
      ret                    := AXI_STREAM_MASTER_INIT_C;
      ret.tValid             := resp.valid;
      ret.tData(52 downto 0) := DmaWriteRespToSlv(resp);
      ret.tLast              := '1';
      return ret;
   end function DmaWriteRespToAxiStream;

   function AxiStreamToDmaWriteResp (axis : AxiStreamMasterType) return RoceDmaWriteRespMasterType is
   begin
      return SlvToDmaWriteResp(axis.tValid, axis.tData(52 downto 0));
   end function AxiStreamToDmaWriteResp;

end package body RocePkg;
