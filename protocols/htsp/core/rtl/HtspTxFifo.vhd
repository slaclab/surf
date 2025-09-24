-------------------------------------------------------------------------------
-- Title      : HTSP: https://confluence.slac.stanford.edu/x/pQmODw
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: HTPS TX FIFO wrapper for the Application Side
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
use surf.HtspPkg.all;

entity HtspTxFifo is
   generic (
      TPD_G                 : time     := 1 ns;
      TX_MAX_PAYLOAD_SIZE_G : positive := 8192;
      NUM_VC_G              : positive);
   port (
      -- APP Interface (appClks domain)
      appClks       : in  slv(NUM_VC_G-1 downto 0);
      appRsts       : in  slv(NUM_VC_G-1 downto 0);
      appTxMasters  : in  AxiStreamMasterArray(NUM_VC_G-1 downto 0);
      appTxSlaves   : out AxiStreamSlaveArray(NUM_VC_G-1 downto 0);
      -- HTSP Interface (htspClk domain)
      htspClk       : in  sl;
      htspRst       : in  sl;
      rxlinkReady   : in  sl;
      txlinkReady   : in  sl;
      htspTxMasters : out AxiStreamMasterArray(NUM_VC_G-1 downto 0);
      htspTxSlaves  : in  AxiStreamSlaveArray(NUM_VC_G-1 downto 0));
end HtspTxFifo;

architecture mapping of HtspTxFifo is

   signal flushedTxMasters : AxiStreamMasterArray(NUM_VC_G-1 downto 0);
   signal flushedTxCtrl    : AxiStreamCtrlArray(NUM_VC_G-1 downto 0);

   signal fifoTxMasters : AxiStreamMasterArray(NUM_VC_G-1 downto 0);
   signal fifoTxSlaves  : AxiStreamSlaveArray(NUM_VC_G-1 downto 0);

   signal linkReady : sl;
   signal flushEn   : slv(NUM_VC_G-1 downto 0);

   signal htspReset : sl;
   signal appResets : slv(NUM_VC_G-1 downto 0);

begin

   U_htspRst : entity surf.RstPipeline
      generic map (
         TPD_G => TPD_G)
      port map (
         clk    => htspClk,
         rstIn  => htspRst,
         rstOut => htspReset);

   GEN_RST_PIPES : for vc in NUM_VC_G-1 downto 0 generate
      U_appRst : entity surf.RstPipeline
         generic map (
            TPD_G => TPD_G)
         port map (
            clk    => appClks(vc),
            rstIn  => appRsts(vc),
            rstOut => appResets(vc));
   end generate GEN_RST_PIPES;

   linkReady <= txlinkReady and rxlinkReady;

   GEN_FLUSH_SYNCS : for vc in NUM_VC_G-1 downto 0 generate
      U_FlushSync : entity surf.Synchronizer
         generic map (
            TPD_G          => TPD_G,
            OUT_POLARITY_G => '0')
         port map (
            clk     => appClks(vc),
            rst     => appResets(vc),
            dataIn  => linkReady,
            dataOut => flushEn(vc));
   end generate GEN_FLUSH_SYNCS;

   GEN_TX_FIFOS : for vc in NUM_VC_G-1 downto 0 generate

      U_Flush : entity surf.AxiStreamFlush
         generic map (
            TPD_G         => TPD_G,
            AXIS_CONFIG_G => HTSP_AXIS_CONFIG_C,
            SSI_EN_G      => true)
         port map (
            axisClk     => appClks(vc),
            axisRst     => appResets(vc),
            flushEn     => flushEn(vc),
            sAxisMaster => appTxMasters(vc),
            sAxisSlave  => appTxSlaves(vc),
            mAxisMaster => flushedTxMasters(vc),
            mAxisCtrl   => flushedTxCtrl(vc));

      U_RESIZE : entity surf.AxiStreamFifoV2
         generic map (
            -- General Configurations
            TPD_G               => TPD_G,
            INT_PIPE_STAGES_G   => 1,
            PIPE_STAGES_G       => 1,
            SLAVE_READY_EN_G    => false,
            VALID_THOLD_G       => (TX_MAX_PAYLOAD_SIZE_G/64),
            VALID_BURST_MODE_G  => true,
            -- FIFO configurations
            MEMORY_TYPE_G       => "block",
            GEN_SYNC_FIFO_G     => false,
            FIFO_ADDR_WIDTH_G   => 9,
            FIFO_PAUSE_THRESH_G => 256,
            -- AXI Stream Port Configurations
            SLAVE_AXI_CONFIG_G  => HTSP_AXIS_CONFIG_C,
            MASTER_AXI_CONFIG_G => HTSP_AXIS_CONFIG_C)
         port map (
            -- Slave Port
            sAxisClk    => appClks(vc),
            sAxisRst    => appResets(vc),
            sAxisMaster => flushedTxMasters(vc),
            sAxisCtrl   => flushedTxCtrl(vc),
            -- Master Port
            mAxisClk    => htspClk,
            mAxisRst    => htspReset,
            mAxisMaster => fifoTxMasters(vc),
            mAxisSlave  => fifoTxSlaves(vc));

      U_SOF : entity surf.SsiInsertSof
         generic map (
            TPD_G               => TPD_G,
            COMMON_CLK_G        => true,
            SLAVE_FIFO_G        => false,
            MASTER_FIFO_G       => false,
            SLAVE_AXI_CONFIG_G  => HTSP_AXIS_CONFIG_C,
            MASTER_AXI_CONFIG_G => HTSP_AXIS_CONFIG_C)
         port map (
            -- Slave Port
            sAxisClk    => htspClk,
            sAxisRst    => htspReset,
            sAxisMaster => fifoTxMasters(vc),
            sAxisSlave  => fifoTxSlaves(vc),
            -- Master Port
            mAxisClk    => htspClk,
            mAxisRst    => htspReset,
            mAxisMaster => htspTxMasters(vc),
            mAxisSlave  => htspTxSlaves(vc));

   end generate GEN_TX_FIFOS;

end mapping;
