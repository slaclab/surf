-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Consolidated RoCEv2 AXI-Stream RDMA payload module.
--
--   Thin integration wrapper: instantiates the RoCEv2AxiStreamRdmaCore host logic
--   (FIFO/FILL/SERVE/DISPATCH/COMPLETION + register file) and the surf RoCEv2Engine,
--   wiring the work/DMA/comp records between them and exposing only the UDP-port
--   datapath + a single AXI-Lite slave. A 3-master crossbar fans the AXI-Lite slave
--   out to the engine (0x0_000), the RoCEv2Dcqcn block (0x1_000), and the core
--   register file (0x2_000).
--
--   See RoCEv2AxiStreamRdmaCore.vhd for the datapath/flow-control description; the
--   core is verified in isolation against its work/DMA/comp ports in cocotb.
-------------------------------------------------------------------------------
-- This file is part of 'Simple-10GbE-RUDP-KCU105-Example'.
-- It is subject to the license terms in the LICENSE.txt file found in the
-- top-level directory of this distribution and at:
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
-- No part of 'Simple-10GbE-RUDP-KCU105-Example', including this file,
-- may be copied, modified, propagated, or distributed except according to
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;
use surf.SsiPkg.all;
use surf.AxiLitePkg.all;
use surf.RoCEv2Pkg.all;

entity RoCEv2AxiStreamRdma is
   generic (
      TPD_G                   : time               := 1 ns;       -- simulation propagation delay
      RST_ASYNC_G             : boolean            := false;      -- true = asynchronous reset
      DCQCN_EN_G              : boolean            := true;       -- forwarded to the internal RoCEv2Engine
      AXIL_BASE_ADDR_G        : slv(31 downto 0);                 -- AXI-Lite crossbar base address
      AXIS_CONFIG_G           : AxiStreamConfigType;              -- inbound payload stream config
      RING_SLOTS_G            : positive           := 16;         -- replay-ring SEND slots (forwarded to core)
      ROCE_CLK_FREQ_G         : real               := 156.25E+6;  -- roceClk freq (Hz) for AxiStreamMon counters
      DISPATCH_COUNTER_BITS_G : positive           := 24);        -- monotonic pointer / counter width
   port (
      roceClk         : in  sl;
      roceRst         : in  sl;
      -- Inbound AXI-Stream payload
      sAxisMaster     : in  AxiStreamMasterType;
      sAxisSlave      : out AxiStreamSlaveType;
      -- RoCEv2 UDP port-4791 interface (forwarded to/from the internal RoCEv2Engine).
      -- Directions mirror the engine's UDP ports so the wrapper just passes them through.
      obUdpMaster     : in  AxiStreamMasterType;
      obUdpSlave      : out AxiStreamSlaveType;
      ibUdpMaster     : out AxiStreamMasterType;
      ibUdpSlave      : in  AxiStreamSlaveType;
      -- AXI-Lite slave (single merged register file)
      axilReadMaster  : in  AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
      axilWriteSlave  : out AxiLiteWriteSlaveType);
end entity RoCEv2AxiStreamRdma;

architecture rtl of RoCEv2AxiStreamRdma is

   ----------------------------------------------------------------------------
   -- Wrapper AXI-Lite crossbar: one slave slot (the entity AXI-Lite port) fanned
   -- out to three masters with addrBits=12 => slot stride 2^12 = 0x1000.
   -- Slot 0 (0x0_000) drives the internal RoCEv2Engine (RoceConfigurator regs).
   -- Slot 1 (0x1_000) drives RoCEv2Dcqcn. Slot 2 (0x2_000) is the core register
   -- file. Final flat map: Engine 0x0_000 / Dcqcn 0x1_000 / Rdma 0x2_000.
   ----------------------------------------------------------------------------
   constant NUM_AXIL_MASTERS_C : positive := 3;
   constant XBAR_ENGINE_C      : natural  := 0;
   constant XBAR_DCQCN_C       : natural  := 1;
   constant XBAR_RDMA_C        : natural  := 2;
   constant XBAR_CONFIG_C      : AxiLiteCrossbarMasterConfigArray(NUM_AXIL_MASTERS_C-1 downto 0) :=
      genAxiLiteConfig(NUM_AXIL_MASTERS_C, AXIL_BASE_ADDR_G, 16, 12);

   signal axilWriteMastersX : AxiLiteWriteMasterArray(NUM_AXIL_MASTERS_C-1 downto 0);
   signal axilWriteSlavesX  : AxiLiteWriteSlaveArray(NUM_AXIL_MASTERS_C-1 downto 0) := (others => AXI_LITE_WRITE_SLAVE_EMPTY_SLVERR_C);
   signal axilReadMastersX  : AxiLiteReadMasterArray(NUM_AXIL_MASTERS_C-1 downto 0);
   signal axilReadSlavesX   : AxiLiteReadSlaveArray(NUM_AXIL_MASTERS_C-1 downto 0)  := (others => AXI_LITE_READ_SLAVE_EMPTY_SLVERR_C);

   -- Inbound-UDP stream out of the engine (pre-Dcqcn) and the engine's CNP pulse.
   signal ibUdpMasterRoce : AxiStreamMasterType;
   signal ibUdpSlaveRoce  : AxiStreamSlaveType;
   signal cnpReceived     : sl;

   -- Work/DMA/comp records wired between the core host logic and the RoCEv2Engine.
   signal dmaReadReqMaster  : RoCEv2DmaReadReqMasterType  := ROCE_DMA_READ_REQ_MASTER_INIT_C;
   signal dmaReadReqSlave   : RoCEv2DmaReadReqSlaveType   := ROCE_DMA_READ_REQ_SLAVE_INIT_C;
   signal dmaReadRespMaster : RoCEv2DmaReadRespMasterType := ROCE_DMA_READ_RESP_MASTER_INIT_C;
   signal dmaReadRespSlave  : RoCEv2DmaReadRespSlaveType  := ROCE_DMA_READ_RESP_SLAVE_INIT_C;
   signal workReqMaster     : RoCEv2WorkReqMasterType     := ROCE_WORK_REQ_MASTER_INIT_C;
   signal workReqSlave      : RoCEv2WorkReqSlaveType      := ROCE_WORK_REQ_SLAVE_INIT_C;
   signal workCompMaster    : RoCEv2WorkCompMasterType    := ROCE_WORK_COMP_MASTER_INIT_C;
   signal workCompSlave     : RoCEv2WorkCompSlaveType     := ROCE_WORK_COMP_SLAVE_INIT_C;

begin  -- architecture rtl

   ----------------------------------------------------------------------------
   -- AXI-Lite crossbar: 1 slave slot (entity AXI-Lite) -> 3 masters
   -- (slot 0 = engine @ 0x0_000, slot 1 = Dcqcn @ 0x1_000, slot 2 = core
   -- regfile @ 0x2_000).
   ----------------------------------------------------------------------------
   U_XBAR : entity surf.AxiLiteCrossbar
      generic map (
         TPD_G              => TPD_G,
         NUM_SLAVE_SLOTS_G  => 1,
         NUM_MASTER_SLOTS_G => NUM_AXIL_MASTERS_C,
         MASTERS_CONFIG_G   => XBAR_CONFIG_C)
      port map (
         axiClk              => roceClk,
         axiClkRst           => roceRst,
         sAxiWriteMasters(0) => axilWriteMaster,
         sAxiWriteSlaves(0)  => axilWriteSlave,
         sAxiReadMasters(0)  => axilReadMaster,
         sAxiReadSlaves(0)   => axilReadSlave,
         mAxiWriteMasters    => axilWriteMastersX,
         mAxiWriteSlaves     => axilWriteSlavesX,
         mAxiReadMasters     => axilReadMastersX,
         mAxiReadSlaves      => axilReadSlavesX);

   ----------------------------------------------------------------------------
   -- Internal RoCEv2Engine. Outbound UDP forwarded straight to the wrapper
   -- entity port; inbound UDP routed through the Dcqcn instance below; work/DMA
   -- records wired by name to the core host logic; AXI-Lite from crossbar slot 0.
   ----------------------------------------------------------------------------
   U_RoceEngine : entity surf.RoCEv2Engine
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => '1')
      port map (
         clk               => roceClk,
         rst               => roceRst,
         -- Work Requests and Comps (internal nets)
         workReqMaster     => workReqMaster,
         workReqSlave      => workReqSlave,
         workCompMaster    => workCompMaster,
         workCompSlave     => workCompSlave,
         -- Interface to UDP Engine (ob fwd to entity; ib goes to Dcqcn below)
         obUdpMaster       => obUdpMaster,
         obUdpSlave        => obUdpSlave,
         ibUdpMaster       => ibUdpMasterRoce,
         ibUdpSlave        => ibUdpSlaveRoce,
         -- AXI-Lite interface (crossbar slot 0 = engine window)
         axilReadMaster    => axilReadMastersX(XBAR_ENGINE_C),
         axilReadSlave     => axilReadSlavesX(XBAR_ENGINE_C),
         axilWriteMaster   => axilWriteMastersX(XBAR_ENGINE_C),
         axilWriteSlave    => axilWriteSlavesX(XBAR_ENGINE_C),
         -- DMA Interface (internal nets)
         dmaReadRespMaster => dmaReadRespMaster,
         dmaReadRespSlave  => dmaReadRespSlave,
         dmaReadReqMaster  => dmaReadReqMaster,
         dmaReadReqSlave   => dmaReadReqSlave,
         -- CNP (feeds the Dcqcn instance below)
         cnp_received      => cnpReceived);

   ----------------------------------------------------------------------------
   -- DCQCN Congestion Control: sits on the engine's inbound-UDP path and the
   -- crossbar's Dcqcn slot (0x1_000). DCQCN_EN_G gates it end-to-end; when
   -- disabled the stream bypasses Dcqcn and its crossbar slot returns DECERR.
   ----------------------------------------------------------------------------
   GEN_DCQCN : if DCQCN_EN_G generate
      U_Dcqcn : entity surf.RoCEv2Dcqcn
         generic map (
            TPD_G         => TPD_G,
            AXIS_CONFIG_G => ROCEV2_AXIS_CONFIG_C)
         port map (
            axisClk         => roceClk,
            axisRst         => roceRst,
            cnp             => cnpReceived,
            axilReadMaster  => axilReadMastersX(XBAR_DCQCN_C),
            axilReadSlave   => axilReadSlavesX(XBAR_DCQCN_C),
            axilWriteMaster => axilWriteMastersX(XBAR_DCQCN_C),
            axilWriteSlave  => axilWriteSlavesX(XBAR_DCQCN_C),
            sAxisMaster     => ibUdpMasterRoce,
            sAxisSlave      => ibUdpSlaveRoce,
            mAxisMaster     => ibUdpMaster,
            mAxisSlave      => ibUdpSlave);
   end generate GEN_DCQCN;

   BYPASS_DCQCN : if not DCQCN_EN_G generate
      ibUdpMaster                   <= ibUdpMasterRoce;
      ibUdpSlaveRoce                <= ibUdpSlave;
      axilReadSlavesX(XBAR_DCQCN_C)  <= AXI_LITE_READ_SLAVE_EMPTY_DECERR_C;
      axilWriteSlavesX(XBAR_DCQCN_C) <= AXI_LITE_WRITE_SLAVE_EMPTY_DECERR_C;
   end generate BYPASS_DCQCN;

   ----------------------------------------------------------------------------
   -- Host-logic core: inbound payload stream in, work/DMA/comp to the engine,
   -- AXI-Lite from crossbar slot 1 (core register file @ 0x2_000).
   ----------------------------------------------------------------------------
   U_Core : entity surf.RoCEv2AxiStreamRdmaCore
      generic map (
         TPD_G                   => TPD_G,
         RST_ASYNC_G             => RST_ASYNC_G,
         AXIS_CONFIG_G           => AXIS_CONFIG_G,
         RING_SLOTS_G            => RING_SLOTS_G,
         ROCE_CLK_FREQ_G         => ROCE_CLK_FREQ_G,
         DISPATCH_COUNTER_BITS_G => DISPATCH_COUNTER_BITS_G)
      port map (
         roceClk           => roceClk,
         roceRst           => roceRst,
         -- Inbound AXI-Stream payload
         sAxisMaster       => sAxisMaster,
         sAxisSlave        => sAxisSlave,
         -- Work Requests / Comps (internal nets to engine)
         workReqMaster     => workReqMaster,
         workReqSlave      => workReqSlave,
         workCompMaster    => workCompMaster,
         workCompSlave     => workCompSlave,
         -- DMA Interface (internal nets to engine)
         dmaReadReqMaster  => dmaReadReqMaster,
         dmaReadReqSlave   => dmaReadReqSlave,
         dmaReadRespMaster => dmaReadRespMaster,
         dmaReadRespSlave  => dmaReadRespSlave,
         -- AXI-Lite (crossbar slot 1 = core register file)
         axilReadMaster    => axilReadMastersX(XBAR_RDMA_C),
         axilReadSlave     => axilReadSlavesX(XBAR_RDMA_C),
         axilWriteMaster   => axilWriteMastersX(XBAR_RDMA_C),
         axilWriteSlave    => axilWriteSlavesX(XBAR_RDMA_C));

end architecture rtl;
