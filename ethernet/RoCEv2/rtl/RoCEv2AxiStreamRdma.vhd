-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: RoCEv2 engine + DCQCN congestion-control composing wrapper.
--   Instantiates surf.RoceEngineWrapper (the RoCEv2 transport engine) and
--   surf.Dcqcn (DCQCN rate limiter). A 1->2 AXI-Lite crossbar fans the single
--   AXI-Lite slave to the engine's MetaData bank (slot 0, 0x0000) and the Dcqcn
--   register file (slot 1, 0x1000). The engine's per-QP CNP output is OR-reduced
--   into Dcqcn's scalar cnp; Dcqcn paces the wire-facing TX stream. DCQCN_EN_G
--   gates it end-to-end (bypass = stream passthrough, Dcqcn slot returns DECERR).
--   Reuses the name of the pre-migration wrapper that bundled engine + DCQCN.
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Firmware Standard Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the
-- top-level directory of this distribution and at:
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
-- No part of 'SLAC Firmware Standard Library', including this file, may be
-- copied, modified, propagated, or distributed except according to the terms
-- contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;
use surf.AxiLitePkg.all;
use surf.EthMacPkg.all;
use surf.RocePkg.all;

entity RoCEv2AxiStreamRdma is
   generic (
      TPD_G            : time             := 1 ns;
      RST_POLARITY_G   : sl               := '1';
      RST_ASYNC_G      : boolean          := false;
      MAX_QP_G         : positive         := 4;
      MAX_QP_WR_G      : positive         := 4;
      EN_TX_G          : boolean          := true;
      EN_RX_G          : boolean          := true;
      EN_READ_G        : boolean          := true;
      DCQCN_EN_G       : boolean          := true;                    -- gate the DCQCN block (ONLY valid with MAX_QP_G=1; see assertion below)
      AXIL_BASE_ADDR_G : slv(31 downto 0) := (others => '0'));  -- absolute AXI-Lite base of this window
   port (
      clk                 : in  sl;
      rst                 : in  sl := not RST_POLARITY_G;
      -- RoCE wire streams (16-byte EMAC_AXIS_CONFIG_C beats)
      sAxisDataStreamMaster : in  AxiStreamMasterType;
      sAxisDataStreamSlave  : out AxiStreamSlaveType;
      mAxisDataStreamMaster : out AxiStreamMasterType;
      mAxisDataStreamSlave  : in  AxiStreamSlaveType;
      -- WorkReq / RecvReq
      sWorkReqMaster      : in  RoceWorkReqMasterType;
      sWorkReqSlave       : out RoceWorkReqSlaveType;
      sRecvReqMaster      : in  RoceRecvReqMasterType;
      sRecvReqSlave       : out RoceRecvReqSlaveType;
      -- Work completions
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
      -- AXI-Lite (fanned to MetaData @0x0000 and DCQCN @0x1000)
      axilReadMaster      : in  AxiLiteReadMasterType;
      axilReadSlave       : out AxiLiteReadSlaveType;
      axilWriteMaster     : in  AxiLiteWriteMasterType;
      axilWriteSlave      : out AxiLiteWriteSlaveType;
      -- metadata completion interrupt
      mdDoneIrq           : out sl;
      -- per-QP CNP pulses from the engine (observation; also feeds the
      -- internal Dcqcn when DCQCN_EN_G=true)
      cnp                 : out slv(MAX_QP_G-1 downto 0));
end entity RoCEv2AxiStreamRdma;

architecture rtl of RoCEv2AxiStreamRdma is

   constant NUM_AXIL_C : positive := 2;
   constant MD_C       : natural  := 0;   -- MetaData  @ base + 0x0000
   constant DCQCN_C    : natural  := 1;   -- Dcqcn     @ base + 0x1000
   constant XBAR_CONFIG_C : AxiLiteCrossbarMasterConfigArray(NUM_AXIL_C-1 downto 0) :=
      genAxiLiteConfig(NUM_AXIL_C, AXIL_BASE_ADDR_G, 16, 12);

   signal axilWriteMastersX : AxiLiteWriteMasterArray(NUM_AXIL_C-1 downto 0);
   signal axilWriteSlavesX  : AxiLiteWriteSlaveArray(NUM_AXIL_C-1 downto 0) := (others => AXI_LITE_WRITE_SLAVE_EMPTY_SLVERR_C);
   signal axilReadMastersX  : AxiLiteReadMasterArray(NUM_AXIL_C-1 downto 0);
   signal axilReadSlavesX   : AxiLiteReadSlaveArray(NUM_AXIL_C-1 downto 0)  := (others => AXI_LITE_READ_SLAVE_EMPTY_SLVERR_C);

   signal cnpVec        : slv(MAX_QP_G-1 downto 0);
   signal cnpReceived   : sl;
   signal engineTxMaster : AxiStreamMasterType;   -- engine TX -> Dcqcn ingress
   signal engineTxSlave  : AxiStreamSlaveType;

begin

   cnp <= cnpVec;

   ----------------------------------------------------------------------------
   -- DCQCN uses ONE shared reaction point: a single Dcqcn on the merged egress
   -- stream, driven by cnp = uOr of the per-QP CNP vector. That is only coherent
   -- for a single flow, so DCQCN may be enabled ONLY when MAX_QP_G = 1. For
   -- MAX_QP_G > 1 the instantiator MUST set DCQCN_EN_G => false.
   -- (Elaboration-time check; fires in Questa/cocotb elaboration.)
   ----------------------------------------------------------------------------
   assert (not DCQCN_EN_G) or (MAX_QP_G = 1)
      report "RoCEv2AxiStreamRdma: DCQCN_EN_G=true requires MAX_QP_G=1 (single " &
             "shared DCQCN reaction point). Set DCQCN_EN_G=false for MAX_QP_G>1."
      severity failure;

   U_XBAR : entity surf.AxiLiteCrossbar
      generic map (
         TPD_G              => TPD_G,
         NUM_SLAVE_SLOTS_G  => 1,
         NUM_MASTER_SLOTS_G => NUM_AXIL_C,
         MASTERS_CONFIG_G   => XBAR_CONFIG_C)
      port map (
         axiClk              => clk,
         axiClkRst           => rst,
         sAxiWriteMasters(0) => axilWriteMaster,
         sAxiWriteSlaves(0)  => axilWriteSlave,
         sAxiReadMasters(0)  => axilReadMaster,
         sAxiReadSlaves(0)   => axilReadSlave,
         mAxiWriteMasters    => axilWriteMastersX,
         mAxiWriteSlaves     => axilWriteSlavesX,
         mAxiReadMasters     => axilReadMastersX,
         mAxiReadSlaves      => axilReadSlavesX);

   U_Engine : entity surf.RoceEngineWrapper
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G,
         MAX_QP_G       => MAX_QP_G,
         MAX_QP_WR_G    => MAX_QP_WR_G,
         EN_TX_G        => EN_TX_G,
         EN_RX_G        => EN_RX_G,
         EN_READ_G      => EN_READ_G)
      port map (
         clk                   => clk,
         rst                   => rst,
         sAxisDataStreamMaster => sAxisDataStreamMaster,
         sAxisDataStreamSlave  => sAxisDataStreamSlave,
         mAxisDataStreamMaster => engineTxMaster,       -- into Dcqcn
         mAxisDataStreamSlave  => engineTxSlave,
         sWorkReqMaster        => sWorkReqMaster,
         sWorkReqSlave         => sWorkReqSlave,
         sRecvReqMaster        => sRecvReqMaster,
         sRecvReqSlave         => sRecvReqSlave,
         mWorkCompRqMaster     => mWorkCompRqMaster,
         mWorkCompRqSlave      => mWorkCompRqSlave,
         mWorkCompSqMaster     => mWorkCompSqMaster,
         mWorkCompSqSlave      => mWorkCompSqSlave,
         mDmaReadReqMaster     => mDmaReadReqMaster,
         mDmaReadReqSlave      => mDmaReadReqSlave,
         sDmaReadRespMaster    => sDmaReadRespMaster,
         sDmaReadRespSlave     => sDmaReadRespSlave,
         mDmaWriteReqMaster    => mDmaWriteReqMaster,
         mDmaWriteReqSlave     => mDmaWriteReqSlave,
         sDmaWriteRespMaster   => sDmaWriteRespMaster,
         sDmaWriteRespSlave    => sDmaWriteRespSlave,
         axilReadMaster        => axilReadMastersX(MD_C),
         axilReadSlave         => axilReadSlavesX(MD_C),
         axilWriteMaster       => axilWriteMastersX(MD_C),
         axilWriteSlave        => axilWriteSlavesX(MD_C),
         mdDoneIrq             => mdDoneIrq,
         cnp                   => cnpVec);

   GEN_DCQCN : if DCQCN_EN_G generate
      cnpReceived <= uOr(cnpVec);          -- single shared Dcqcn (matches old cnp_received)
      U_Dcqcn : entity surf.Dcqcn
         generic map (
            TPD_G          => TPD_G,
            AXIS_CONFIG_G  => EMAC_AXIS_CONFIG_C,
            RST_ASYNC_G    => RST_ASYNC_G,
            RST_POLARITY_G => RST_POLARITY_G)
         port map (
            axisClk         => clk,
            axisRst         => rst,
            cnp             => cnpReceived,
            axilReadMaster  => axilReadMastersX(DCQCN_C),
            axilReadSlave   => axilReadSlavesX(DCQCN_C),
            axilWriteMaster => axilWriteMastersX(DCQCN_C),
            axilWriteSlave  => axilWriteSlavesX(DCQCN_C),
            sAxisMaster     => engineTxMaster,
            sAxisSlave      => engineTxSlave,
            mAxisMaster     => mAxisDataStreamMaster,
            mAxisSlave      => mAxisDataStreamSlave);
   end generate GEN_DCQCN;

   BYPASS_DCQCN : if not DCQCN_EN_G generate
      mAxisDataStreamMaster          <= engineTxMaster;
      engineTxSlave                  <= mAxisDataStreamSlave;
      axilReadSlavesX(DCQCN_C)       <= AXI_LITE_READ_SLAVE_EMPTY_DECERR_C;
      axilWriteSlavesX(DCQCN_C)      <= AXI_LITE_WRITE_SLAVE_EMPTY_DECERR_C;
   end generate BYPASS_DCQCN;

end architecture rtl;
