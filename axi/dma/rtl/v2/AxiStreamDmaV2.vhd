-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
-- Generic AXI Stream DMA block for frame at a time transfers.
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
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;


library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;
use surf.AxiLitePkg.all;
use surf.AxiPkg.all;
use surf.AxiDmaPkg.all;

entity AxiStreamDmaV2 is
   generic (
      TPD_G              : time                     := 1 ns;
      SIMULATION_G       : boolean                  := false;
      DESC_AWIDTH_G      : positive range 4 to 12   := 12;
      DESC_ARB_G         : boolean                  := true;
      DESC_SYNTH_MODE_G  : string                   := "inferred";
      DESC_MEMORY_TYPE_G : string                   := "block";
      AXIL_BASE_ADDR_G   : slv(31 downto 0)         := x"00000000";
      AXI_READY_EN_G     : boolean                  := false;
      AXIS_READY_EN_G    : boolean                  := false;
      AXIS_CONFIG_G      : AxiStreamConfigType;
      AXI_DMA_CONFIG_G   : AxiConfigType;
      CHAN_COUNT_G       : positive range 1 to 16   := 1;
      BURST_BYTES_G      : positive range 1 to 4096 := 4096;
      WR_PIPE_STAGES_G   : natural                  := 1;
      RD_PIPE_STAGES_G   : natural                  := 1;
      RD_PEND_THRESH_G   : positive                 := 1);  -- In units of bytes
   port (
      -- Clock/Reset
      axiClk          : in  sl;
      axiRst          : in  sl;
      -- Register Access & Interrupt
      axilReadMaster  : in  AxiLiteReadMasterType;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType;
      axilWriteSlave  : out AxiLiteWriteSlaveType;
      interrupt       : out sl;
      online          : out slv(CHAN_COUNT_G-1 downto 0);
      acknowledge     : out slv(CHAN_COUNT_G-1 downto 0);
      buffGrpPause    : out slv(7 downto 0);
      -- AXI Stream Interface
      sAxisMasters    : in  AxiStreamMasterArray(CHAN_COUNT_G-1 downto 0);
      sAxisSlaves     : out AxiStreamSlaveArray(CHAN_COUNT_G-1 downto 0);
      mAxisMasters    : out AxiStreamMasterArray(CHAN_COUNT_G-1 downto 0);
      mAxisSlaves     : in  AxiStreamSlaveArray(CHAN_COUNT_G-1 downto 0);
      mAxisCtrl       : in  AxiStreamCtrlArray(CHAN_COUNT_G-1 downto 0);
      -- AXI Interfaces, 0 = Desc, 1-CHAN_COUNT_G = DMA
      axiReadMasters  : out AxiReadMasterArray(CHAN_COUNT_G downto 0);
      axiReadSlaves   : in  AxiReadSlaveArray(CHAN_COUNT_G downto 0);
      axiWriteMasters : out AxiWriteMasterArray(CHAN_COUNT_G downto 0);
      axiWriteSlaves  : in  AxiWriteSlaveArray(CHAN_COUNT_G downto 0);
      axiWriteCtrl    : in  AxiCtrlArray(CHAN_COUNT_G downto 0));
end AxiStreamDmaV2;

architecture structure of AxiStreamDmaV2 is

   signal dmaWrDescReq    : AxiWriteDmaDescReqArray(CHAN_COUNT_G-1 downto 0);
   signal dmaWrDescAck    : AxiWriteDmaDescAckArray(CHAN_COUNT_G-1 downto 0);
   signal dmaWrDescRet    : AxiWriteDmaDescRetArray(CHAN_COUNT_G-1 downto 0);
   signal dmaWrDescRetAck : slv(CHAN_COUNT_G-1 downto 0);

   signal dmaRdDescReq    : AxiReadDmaDescReqArray(CHAN_COUNT_G-1 downto 0);
   signal dmaRdDescAck    : slv(CHAN_COUNT_G-1 downto 0);
   signal dmaRdDescRet    : AxiReadDmaDescRetArray(CHAN_COUNT_G-1 downto 0);
   signal dmaRdDescRetAck : slv(CHAN_COUNT_G-1 downto 0);

   signal descWriteMasters : AxiWriteMasterArray(CHAN_COUNT_G-1 downto 0);
   signal descWriteSlaves  : AxiWriteSlaveArray(CHAN_COUNT_G-1 downto 0);

   signal dataWriteMasters : AxiWriteMasterArray(CHAN_COUNT_G-1 downto 0);
   signal dataWriteSlaves  : AxiWriteSlaveArray(CHAN_COUNT_G-1 downto 0);
   signal dataWriteCtrl    : AxiCtrlArray(CHAN_COUNT_G-1 downto 0);

   signal axiRdCache : slv(3 downto 0);
   signal axiWrCache : slv(3 downto 0);

   signal axiReset : slv(CHAN_COUNT_G-1 downto 0);

   attribute dont_touch             : string;
   attribute dont_touch of axiReset : signal is "true";

begin

   assert (AXI_DMA_CONFIG_G.DATA_BYTES_C >= 8)
      report "AxiPcieDma: AXI STREAM DMA must have a byte width of >= 8Bytes (64-bits)" severity failure;

   assert (isPowerOf2(BURST_BYTES_G) = true)
      report "BURST_BYTES_G must be power of 2" severity failure;

   U_DmaDesc : entity surf.AxiStreamDmaV2Desc
      generic map (
         TPD_G              => TPD_G,
         CHAN_COUNT_G       => CHAN_COUNT_G,
         AXIL_BASE_ADDR_G   => AXIL_BASE_ADDR_G,
         AXI_CONFIG_G       => AXI_DMA_CONFIG_G,
         DESC_AWIDTH_G      => DESC_AWIDTH_G,
         DESC_ARB_G         => DESC_ARB_G,
         DESC_SYNTH_MODE_G  => DESC_SYNTH_MODE_G,
         DESC_MEMORY_TYPE_G => DESC_MEMORY_TYPE_G)
      port map (
         -- Clock/Reset
         axiClk          => axiClk,
         axiRst          => axiRst,
         axilReadMaster  => axilReadMaster,
         axilReadSlave   => axilReadSlave,
         axilWriteMaster => axilWriteMaster,
         axilWriteSlave  => axilWriteSlave,
         interrupt       => interrupt,
         online          => online,
         acknowledge     => acknowledge,
         dmaWrDescReq    => dmaWrDescReq,
         dmaWrDescAck    => dmaWrDescAck,
         dmaWrDescRet    => dmaWrDescRet,
         dmaWrDescRetAck => dmaWrDescRetAck,
         dmaRdDescReq    => dmaRdDescReq,
         dmaRdDescAck    => dmaRdDescAck,
         dmaRdDescRet    => dmaRdDescRet,
         dmaRdDescRetAck => dmaRdDescRetAck,
         axiRdCache      => axiRdCache,
         axiWrCache      => axiWrCache,
         axiWriteMasters => descWriteMasters,
         axiWriteSlaves  => descWriteSlaves,
         buffGrpPause    => buffGrpPause);

   -- Read/Write channel 0 unused.
   axiReadMasters(0)  <= AXI_READ_MASTER_INIT_C;
   axiWriteMasters(0) <= AXI_WRITE_MASTER_INIT_C;

   U_ChanGen : for i in 0 to CHAN_COUNT_G-1 generate

      -- Help with timing
      U_AxisRst : entity surf.RstPipeline
         generic map (
            TPD_G     => TPD_G,
            INV_RST_G => false)
         port map (
            clk    => axiClk,
            rstIn  => axiRst,
            rstOut => axiReset(i));

      U_DmaRead : entity surf.AxiStreamDmaV2Read
         generic map (
            TPD_G           => TPD_G,
            AXIS_READY_EN_G => AXIS_READY_EN_G,
            AXIS_CONFIG_G   => AXIS_CONFIG_G,
            AXI_CONFIG_G    => AXI_DMA_CONFIG_G,
            PIPE_STAGES_G   => RD_PIPE_STAGES_G,
            BURST_BYTES_G   => BURST_BYTES_G,
            PEND_THRESH_G   => RD_PEND_THRESH_G)
         port map (
            axiClk          => axiClk,
            axiRst          => axiReset(i),
            dmaRdDescReq    => dmaRdDescReq(i),
            dmaRdDescAck    => dmaRdDescAck(i),
            dmaRdDescRet    => dmaRdDescRet(i),
            dmaRdDescRetAck => dmaRdDescRetAck(i),
            dmaRdIdle       => open,
            axiCache        => axiRdCache,
            -- Streaming Interface
            axisMaster      => mAxisMasters(i),
            axisSlave       => mAxisSlaves(i),
            axisCtrl        => mAxisCtrl(i),
            axiReadMaster   => axiReadMasters(i+1),
            axiReadSlave    => axiReadSlaves(i+1));

      U_DmaWrite : entity surf.AxiStreamDmaV2Write
         generic map (
            TPD_G             => TPD_G,
            AXI_READY_EN_G    => AXI_READY_EN_G,
            AXIS_CONFIG_G     => AXIS_CONFIG_G,
            AXI_CONFIG_G      => AXI_DMA_CONFIG_G,
            PIPE_STAGES_G     => WR_PIPE_STAGES_G,
            BURST_BYTES_G     => BURST_BYTES_G,
            ACK_WAIT_BVALID_G => false)
         port map (
            axiClk          => axiClk,
            axiRst          => axiReset(i),
            dmaWrDescReq    => dmaWrDescReq(i),
            dmaWrDescAck    => dmaWrDescAck(i),
            dmaWrDescRet    => dmaWrDescRet(i),
            dmaWrDescRetAck => dmaWrDescRetAck(i),
            dmaWrIdle       => open,
            axiCache        => axiWrCache,
            axisMaster      => sAxisMasters(i),
            axisSlave       => sAxisSlaves(i),
            axiWriteMaster  => dataWriteMasters(i),
            axiWriteSlave   => dataWriteSlaves(i),
            axiWriteCtrl    => dataWriteCtrl(i));

      -----------------------------------------------------------------------------------------
      -- This MUX is used to make sure that the write descriptor is sent after the data is sent
      -----------------------------------------------------------------------------------------
      U_DmaWriteMux : entity surf.AxiStreamDmaV2WriteMux
         generic map (
            TPD_G          => TPD_G,
            AXI_CONFIG_G   => AXI_DMA_CONFIG_G,
            AXI_READY_EN_G => AXI_READY_EN_G)
         port map (
            -- Clock and reset
            axiClk          => axiClk,
            axiRst          => axiReset(i),
            -- DMA Data Write Path
            dataWriteMaster => dataWriteMasters(i),
            dataWriteSlave  => dataWriteSlaves(i),
            dataWriteCtrl   => dataWriteCtrl(i),
            -- DMA Descriptor Write Path
            descWriteMaster => descWriteMasters(i),
            descWriteSlave  => descWriteSlaves(i),
            -- MUX Write Path
            mAxiWriteMaster => axiWriteMasters(i+1),
            mAxiWriteSlave  => axiWriteSlaves(i+1),
            mAxiWriteCtrl   => axiWriteCtrl(i+1));

   end generate;

end structure;

