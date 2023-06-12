-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: General PGP TX Virtual Channel FIFO
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

entity PgpTxVcFifo is
   generic (
      TPD_G              : time     := 1 ns;
      RST_ASYNC_G        : boolean  := false;
      INT_PIPE_STAGES_G  : natural  := 0;
      PIPE_STAGES_G      : natural  := 1;
      VALID_THOLD_G      : positive := 1;
      VALID_BURST_MODE_G : boolean  := false;
      SYNTH_MODE_G       : string   := "inferred";
      MEMORY_TYPE_G      : string   := "block";
      GEN_SYNC_FIFO_G    : boolean  := false;
      FIFO_ADDR_WIDTH_G  : positive := 9;
      CASCADE_SIZE_G     : positive := 1;
      APP_AXI_CONFIG_G   : AxiStreamConfigType;
      PHY_AXI_CONFIG_G   : AxiStreamConfigType);
   port (
      -- AXIS Interface (axisClk domain)
      axisClk     : in  sl;
      axisRst     : in  sl;
      axisMaster  : in  AxiStreamMasterType;
      axisSlave   : out AxiStreamSlaveType;
      -- PGP Interface (pgpClk domain)
      pgpClk      : in  sl;
      pgpRst      : in  sl;
      rxlinkReady : in  sl;
      txlinkReady : in  sl;
      pgpTxMaster : out AxiStreamMasterType;
      pgpTxSlave  : in  AxiStreamSlaveType);
end PgpTxVcFifo;

architecture mapping of PgpTxVcFifo is

   signal sMaster : AxiStreamMasterType;
   signal sSlave  : AxiStreamSlaveType;

   signal master : AxiStreamMasterType;
   signal ctrl   : AxiStreamCtrlType;

   signal linkReady : sl;
   signal flushEn   : sl;

   signal axisReset : sl;
   signal pgpReset  : sl;

begin

   linkReady <= txlinkReady and rxlinkReady;

   U_FlushSync : entity surf.Synchronizer
      generic map (
         TPD_G          => TPD_G,
         RST_ASYNC_G    => RST_ASYNC_G,
         OUT_POLARITY_G => '0')
      port map (
         clk     => axisClk,
         rst     => axisRst,
         dataIn  => linkReady,
         dataOut => flushEn);

   U_axisRst : entity surf.RstPipeline
      generic map (
         TPD_G => TPD_G)
      port map (
         clk    => axisClk,
         rstIn  => axisRst,
         rstOut => axisReset);

   U_pgpRst : entity surf.RstPipeline
      generic map (
         TPD_G => TPD_G)
      port map (
         clk    => pgpClk,
         rstIn  => pgpRst,
         rstOut => pgpReset);

   -- Adding Pipelining to help with making timing between SLRs
   U_AxiStreamPipeline : entity surf.AxiStreamPipeline
      generic map (
         TPD_G         => TPD_G,
         RST_ASYNC_G   => RST_ASYNC_G,
         PIPE_STAGES_G => 1)
      port map (
         axisClk     => axisClk,
         axisRst     => axisReset,
         sAxisMaster => axisMaster,
         sAxisSlave  => axisSlave,
         mAxisMaster => sMaster,
         mAxisSlave  => sSlave);

   U_Flush : entity surf.AxiStreamFlush
      generic map (
         TPD_G         => TPD_G,
         RST_ASYNC_G   => RST_ASYNC_G,
         AXIS_CONFIG_G => APP_AXI_CONFIG_G,
         SSI_EN_G      => true)
      port map (
         axisClk     => axisClk,
         axisRst     => axisReset,
         flushEn     => flushEn,
         sAxisMaster => sMaster,
         sAxisSlave  => sSlave,
         mAxisMaster => master,
         mAxisCtrl   => ctrl);

   U_Fifo : entity surf.AxiStreamFifoV2
      generic map (
         -- General Configurations
         TPD_G               => TPD_G,
         RST_ASYNC_G         => RST_ASYNC_G,
         INT_PIPE_STAGES_G   => INT_PIPE_STAGES_G,
         PIPE_STAGES_G       => PIPE_STAGES_G,
         SLAVE_READY_EN_G    => false,
         VALID_THOLD_G       => VALID_THOLD_G,
         VALID_BURST_MODE_G  => VALID_BURST_MODE_G,
         -- FIFO configurations
         SYNTH_MODE_G        => SYNTH_MODE_G,
         MEMORY_TYPE_G       => MEMORY_TYPE_G,
         GEN_SYNC_FIFO_G     => GEN_SYNC_FIFO_G,
         FIFO_ADDR_WIDTH_G   => FIFO_ADDR_WIDTH_G,
         FIFO_PAUSE_THRESH_G => (2**FIFO_ADDR_WIDTH_G)-4,
         CASCADE_PAUSE_SEL_G => CASCADE_SIZE_G-1,
         CASCADE_SIZE_G      => CASCADE_SIZE_G,
         -- AXI Stream Port Configurations
         SLAVE_AXI_CONFIG_G  => APP_AXI_CONFIG_G,
         MASTER_AXI_CONFIG_G => PHY_AXI_CONFIG_G)
      port map (
         -- Slave Port
         sAxisClk    => axisClk,
         sAxisRst    => axisReset,
         sAxisMaster => master,
         sAxisCtrl   => ctrl,
         -- Master Port
         mAxisClk    => pgpClk,
         mAxisRst    => pgpReset,
         mAxisMaster => pgpTxMaster,
         mAxisSlave  => pgpTxSlave);

end mapping;
