-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Provenance : HAND-WRITTEN integration wrapper (not BSV-derived). Wraps the
--              Stage-5-verified out/04-vhdl/TransportLayer.vhd (BSV
--              mkTransportLayer, src-bsv/TransportLayer.bsv:76-185) with:
--                * standard SURF AXI-Stream on the network-facing dataStream
--                  in/out (BYTE-SWAPPED to AXI lane order: first wire byte =
--                  tData lane 0 / tKeep(0); isFirst -> SSI SOF on tUser;
--                  isLast -> tLast). External beats are 16-byte
--                  EMAC_AXIS_CONFIG_C format, directly connectable to the
--                  server/client stream ports of surf.UdpEngineWrapper
--                  (surf/ethernet/UdpEngine/rtl/UdpEngineWrapper.vhd):
--                  sAxisDataStream* <- obServerMasters/obServerSlaves,
--                  mAxisDataStream* -> ibServerMasters/ibServerSlaves.
--                  Two surf.AxiStreamResize instances convert 16 <-> 32
--                  bytes to/from the internal BLUE_DATA_STREAM_CONFIG_C
--                  32-byte RoCE beat;
--                * RocePkg TYPED RECORD ports on every other stream interface
--                  (RoceWorkReqMasterType/SlaveType etc., valid/ready
--                  handshake per record pair — style/examples/RocePkg.vhd
--                  lineage);
--                * AXI-Lite on the MetaData server interface, one register
--                  per struct field (see RoceMetaDataAxil.vhd for the map).
-------------------------------------------------------------------------------
-- Conventions:
--   * The typed-record ports carry the BSV-faithful structs; to attach an
--     AXI-Stream fabric to one of them, use the RocePkg conversion functions
--     OUTSIDE this entity (<X>ToAxiStream / AxiStreamTo<X>).
--   * Pure combinational mapping - no FIFOs (the DUT already buffers) -
--     except the two AxiStreamResize width converters on the wire streams
--     (one register stage each, ready/valid flow control preserved).
--   * The DUT's dataStreamOut/workComp*/dmaReadReq/dmaWriteReq FWFT faces:
--     master.valid/tValid <= DUT valid (never a function of ready);
--     DUT rdEn <= slave.ready/tReady.
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
use surf.AxiLitePkg.all;
use surf.EthMacPkg.all;

use surf.RocePkg.all;

entity RoceEngineWrapper is
   generic (
      TPD_G          : time     := 1 ns;
      RST_POLARITY_G : sl       := '1';  -- '1' active HIGH reset, '0' active LOW
      RST_ASYNC_G    : boolean  := false;
      MAX_QP_G       : positive := 4;    -- power of 2, >= 1 (TransportLayer proviso)
      MAX_QP_WR_G    : positive := 4;    -- max pending work requests per QP
                                         -- (Settings.bsv MAX_QP_WR, BSV default
                                         -- 32; effective in-flight window is
                                         -- MAX_QP_WR_G-1). Power of 2.
      -- Resource-pruning generics (pass-through to TransportLayer; all true =
      -- full engine, identical to the verified netlist; at least one of
      -- EN_TX_G/EN_RX_G must be true):
      --  EN_TX_G=false   : no requester (SQ) — engine cannot originate RDMA
      --                    requests; sWorkReq is refused (ready stays '0');
      --                    mWorkCompSq never fires.
      --  EN_RX_G=false   : no responder (RQ) — engine cannot serve incoming
      --                    remote requests (they are dropped at the packet
      --                    buffer); sRecvReq is refused; mWorkCompRq never
      --                    fires. ACK/NAK reception for the engine's own
      --                    requests is NOT affected.
      --  EN_READ_G=false : no RDMA READ / atomic support on either side.
      --                    SOFTWARE CONTRACT: never post READ or atomic work
      --                    requests; incoming READ/atomic requests get NAK
      --                    (invalid request). RDMA WRITE / WRITE_WITH_IMM /
      --                    SEND are unaffected.
      -- Target config for a pure RDMA-WRITE requester:
      --   EN_TX_G=true, EN_RX_G=false, EN_READ_G=false.
      EN_TX_G        : boolean  := true;
      EN_RX_G        : boolean  := true;
      EN_READ_G      : boolean  := true);
   port (
      clk                 : in  sl;
      rst                 : in  sl := not RST_POLARITY_G;
      -- RoCE wire stream in (RX; 16-byte EMAC_AXIS_CONFIG_C beats,
      -- byte-swapped lane order; connect to UdpEngineWrapper obServer*)
      sAxisDataStreamMaster : in  AxiStreamMasterType;
      sAxisDataStreamSlave  : out AxiStreamSlaveType;
      -- RoCE wire stream out (TX; 16-byte EMAC_AXIS_CONFIG_C beats,
      -- byte-swapped lane order; connect to UdpEngineWrapper ibServer*)
      mAxisDataStreamMaster : out AxiStreamMasterType;
      mAxisDataStreamSlave  : in  AxiStreamSlaveType;
      -- WorkReq / RecvReq inputs
      sWorkReqMaster      : in  RoceWorkReqMasterType;
      sWorkReqSlave       : out RoceWorkReqSlaveType;
      sRecvReqMaster      : in  RoceRecvReqMasterType;
      sRecvReqSlave       : out RoceRecvReqSlaveType;
      -- Work completion outputs
      mWorkCompRqMaster   : out RoceWorkCompMasterType;
      mWorkCompRqSlave    : in  RoceWorkCompSlaveType;
      mWorkCompSqMaster   : out RoceWorkCompMasterType;
      mWorkCompSqSlave    : in  RoceWorkCompSlaveType;
      -- DMA read client
      mDmaReadReqMaster   : out RoceDmaReadReqMasterType;
      mDmaReadReqSlave    : in  RoceDmaReadReqSlaveType;
      sDmaReadRespMaster  : in  RoceDmaReadRespMasterType;
      sDmaReadRespSlave   : out RoceDmaReadRespSlaveType;
      -- DMA write client
      mDmaWriteReqMaster  : out RoceDmaWriteReqMasterType;
      mDmaWriteReqSlave   : in  RoceDmaWriteReqSlaveType;
      sDmaWriteRespMaster : in  RoceDmaWriteRespMasterType;
      sDmaWriteRespSlave  : out RoceDmaWriteRespSlaveType;
      -- MetaData server as AXI-Lite registers (RoceMetaDataAxil map)
      axilReadMaster      : in  AxiLiteReadMasterType;
      axilReadSlave       : out AxiLiteReadSlaveType;
      axilWriteMaster     : in  AxiLiteWriteMasterType;
      axilWriteSlave      : out AxiLiteWriteSlaveType;
      -- metadata completion interrupt (1-cycle pulse on DONE)
      mdDoneIrq           : out sl);
end entity RoceEngineWrapper;

architecture rtl of RoceEngineWrapper is

   -- flat DUT ports
   signal dataStreamInReady  : sl;
   signal workReqInReady     : sl;
   signal recvReqInReady     : sl;
   signal dataStreamOutValid : sl;
   signal dataStreamOutData  : slv(ROCE_DATA_STREAM_W_C-1 downto 0);
   signal workCompRqValid    : sl;
   signal workCompRqData     : slv(ROCE_WORK_COMP_W_C-1 downto 0);
   signal workCompSqValid    : sl;
   signal workCompSqData     : slv(ROCE_WORK_COMP_W_C-1 downto 0);
   signal mdSrvReqValid      : sl;
   signal mdSrvReqData       : slv(ROCE_MD_REQ_W_C-1 downto 0);
   signal mdSrvReqReady      : sl;
   signal mdSrvRespValid     : sl;
   signal mdSrvRespData      : slv(ROCE_MD_RESP_W_C-1 downto 0);
   signal mdSrvRespReady     : sl;
   signal dmaReadReqValid    : sl;
   signal dmaReadReqData     : slv(ROCE_DMA_RD_REQ_W_C-1 downto 0);
   signal dmaReadRespReady   : sl;
   signal dmaWriteReqValid   : sl;
   signal dmaWriteReqData    : slv(ROCE_DMA_WR_REQ_W_C-1 downto 0);
   signal dmaWriteRespReady  : sl;

   -- typed view of the DUT-side wire streams (RocePkg records)
   signal dataStreamIn  : RoceDataStreamMasterType;
   signal dataStreamOut : RoceDataStreamMasterType;

   -- internal 32-byte (BLUE_DATA_STREAM_CONFIG_C) side of the width converters
   signal roceRxAxisMaster : AxiStreamMasterType;
   signal roceRxAxisSlave  : AxiStreamSlaveType;
   signal roceTxAxisMaster : AxiStreamMasterType;
   signal roceTxAxisSlave  : AxiStreamSlaveType;

begin

   ---------------------------------------------------------------------------
   -- Wire stream RX: 16-byte UDP beats -> 32-byte RoCE beat -> raw DataStream
   ---------------------------------------------------------------------------
   U_RxResize : entity surf.AxiStreamResize
      generic map (
         TPD_G               => TPD_G,
         RST_POLARITY_G      => RST_POLARITY_G,
         RST_ASYNC_G         => RST_ASYNC_G,
         SLAVE_AXI_CONFIG_G  => EMAC_AXIS_CONFIG_C,
         MASTER_AXI_CONFIG_G => BLUE_DATA_STREAM_CONFIG_C)
      port map (
         axisClk     => clk,
         axisRst     => rst,
         sAxisMaster => sAxisDataStreamMaster,
         sAxisSlave  => sAxisDataStreamSlave,
         mAxisMaster => roceRxAxisMaster,
         mAxisSlave  => roceRxAxisSlave);

   dataStreamIn    <= AxiStreamToDataStream(roceRxAxisMaster);
   roceRxAxisSlave <= ToAxiStreamSlave(dataStreamInReady);

   ---------------------------------------------------------------------------
   -- Wire stream TX: raw DataStream -> 32-byte RoCE beat -> 16-byte UDP beats
   ---------------------------------------------------------------------------
   dataStreamOut    <= SlvToDataStream(dataStreamOutValid, dataStreamOutData);
   roceTxAxisMaster <= DataStreamToAxiStream(dataStreamOut);

   U_TxResize : entity surf.AxiStreamResize
      generic map (
         TPD_G               => TPD_G,
         RST_POLARITY_G      => RST_POLARITY_G,
         RST_ASYNC_G         => RST_ASYNC_G,
         SLAVE_AXI_CONFIG_G  => BLUE_DATA_STREAM_CONFIG_C,
         MASTER_AXI_CONFIG_G => EMAC_AXIS_CONFIG_C)
      port map (
         axisClk     => clk,
         axisRst     => rst,
         sAxisMaster => roceTxAxisMaster,
         sAxisSlave  => roceTxAxisSlave,
         mAxisMaster => mAxisDataStreamMaster,
         mAxisSlave  => mAxisDataStreamSlave);

   ---------------------------------------------------------------------------
   -- Typed-record <-> flat conversions (pure wiring via RocePkg functions)
   ---------------------------------------------------------------------------
   sWorkReqSlave      <= (ready => workReqInReady);
   sRecvReqSlave      <= (ready => recvReqInReady);
   sDmaReadRespSlave  <= (ready => dmaReadRespReady);
   sDmaWriteRespSlave <= (ready => dmaWriteRespReady);

   mWorkCompRqMaster <= SlvToWorkComp(workCompRqValid, workCompRqData);
   mWorkCompSqMaster <= SlvToWorkComp(workCompSqValid, workCompSqData);
   mDmaReadReqMaster <= SlvToDmaReadReq(dmaReadReqValid, dmaReadReqData);
   mDmaWriteReqMaster <= SlvToDmaWriteReq(dmaWriteReqValid, dmaWriteReqData);

   ---------------------------------------------------------------------------
   -- U_MetaDataAxil : AXI-Lite register bank <-> mdSrv server pair
   ---------------------------------------------------------------------------
   U_MetaDataAxil : entity surf.RoceMetaDataAxil
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G,
         MAX_QP_G       => MAX_QP_G)
      port map (
         clk             => clk,
         rst             => rst,
         axilReadMaster  => axilReadMaster,
         axilReadSlave   => axilReadSlave,
         axilWriteMaster => axilWriteMaster,
         axilWriteSlave  => axilWriteSlave,
         mdSrvReqValid   => mdSrvReqValid,
         mdSrvReqData    => mdSrvReqData,
         mdSrvReqReady   => mdSrvReqReady,
         mdSrvRespValid  => mdSrvRespValid,
         mdSrvRespData   => mdSrvRespData,
         mdSrvRespReady  => mdSrvRespReady,
         mdDoneIrq       => mdDoneIrq);

   ---------------------------------------------------------------------------
   -- U_TransportLayer : the verified BSV-derived core
   ---------------------------------------------------------------------------
   U_TransportLayer : entity surf.TransportLayer
      generic map (
         TPD_G       => TPD_G,
         MAX_QP_G    => MAX_QP_G,
         MAX_QP_WR_G => MAX_QP_WR_G,
         EN_TX_G     => EN_TX_G,
         EN_RX_G     => EN_RX_G,
         EN_READ_G   => EN_READ_G)
      port map (
         clk                => clk,
         rst                => rst,
         dataStreamInValid  => dataStreamIn.valid,
         dataStreamInData   => DataStreamToSlv(dataStreamIn),
         dataStreamInReady  => dataStreamInReady,
         workReqInValid     => sWorkReqMaster.valid,
         workReqInData      => WorkReqToSlv(sWorkReqMaster),
         workReqInReady     => workReqInReady,
         recvReqInValid     => sRecvReqMaster.valid,
         recvReqInData      => RecvReqToSlv(sRecvReqMaster),
         recvReqInReady     => recvReqInReady,
         dataStreamOutValid => dataStreamOutValid,
         dataStreamOutData  => dataStreamOutData,
         dataStreamOutRdEn  => roceTxAxisSlave.tReady,
         workCompRqValid    => workCompRqValid,
         workCompRqData     => workCompRqData,
         workCompRqRdEn     => mWorkCompRqSlave.ready,
         workCompSqValid    => workCompSqValid,
         workCompSqData     => workCompSqData,
         workCompSqRdEn     => mWorkCompSqSlave.ready,
         mdSrvReqValid      => mdSrvReqValid,
         mdSrvReqData       => mdSrvReqData,
         mdSrvReqReady      => mdSrvReqReady,
         mdSrvRespValid     => mdSrvRespValid,
         mdSrvRespData      => mdSrvRespData,
         mdSrvRespReady     => mdSrvRespReady,
         dmaReadReqValid    => dmaReadReqValid,
         dmaReadReqData     => dmaReadReqData,
         dmaReadReqRd       => mDmaReadReqSlave.ready,
         dmaReadRespValid   => sDmaReadRespMaster.valid,
         dmaReadRespData    => DmaReadRespToSlv(sDmaReadRespMaster),
         dmaReadRespReady   => dmaReadRespReady,
         dmaWriteReqValid   => dmaWriteReqValid,
         dmaWriteReqData    => dmaWriteReqData,
         dmaWriteReqRd      => mDmaWriteReqSlave.ready,
         dmaWriteRespValid  => sDmaWriteRespMaster.valid,
         dmaWriteRespData   => DmaWriteRespToSlv(sDmaWriteRespMaster),
         dmaWriteRespReady  => dmaWriteRespReady);

end architecture rtl;
