-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: General PGP RX Virtual Channel FIFO
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

entity PgpRxVcFifo is
   generic (
      TPD_G               : time     := 1 ns;
      RST_ASYNC_G         : boolean  := false;
      ROGUE_SIM_EN_G      : boolean  := false;
      INT_PIPE_STAGES_G   : natural  := 0;
      PIPE_STAGES_G       : natural  := 1;
      VALID_THOLD_G       : positive := 1;
      VALID_BURST_MODE_G  : boolean  := false;
      SYNTH_MODE_G        : string   := "inferred";
      MEMORY_TYPE_G       : string   := "block";
      GEN_SYNC_FIFO_G     : boolean  := false;
      FIFO_ADDR_WIDTH_G   : positive := 9;
      FIFO_PAUSE_THRESH_G : positive := 256;
      PHY_AXI_CONFIG_G    : AxiStreamConfigType;
      APP_AXI_CONFIG_G    : AxiStreamConfigType);
   port (
      -- PGP Interface (pgpClk domain)
      pgpClk      : in  sl;
      pgpRst      : in  sl;
      rxlinkReady : in  sl;
      pgpRxMaster : in  AxiStreamMasterType;
      pgpRxCtrl   : out AxiStreamCtrlType;
      pgpRxSlave  : out AxiStreamSlaveType;
      -- AXIS Interface (axisClk domain)
      axisClk     : in  sl;
      axisRst     : in  sl;
      axisMaster  : out AxiStreamMasterType;
      axisSlave   : in  AxiStreamSlaveType);
end PgpRxVcFifo;

architecture mapping of PgpRxVcFifo is

   signal pgpMaster : AxiStreamMasterType;

   signal axisReset : sl;
   signal pgpReset  : sl;

begin

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

   BLOWOFF_FILTER : process (pgpRxMaster, rxlinkReady) is
      variable tmp : AxiStreamMasterType;
   begin
      tmp := pgpRxMaster;
      if (rxlinkReady = '0') then
         tmp.tValid := '0';
      end if;
      pgpMaster <= tmp;
   end process;

   U_Fifo : entity surf.AxiStreamFifoV2
      generic map (
         -- General Configurations
         TPD_G               => TPD_G,
         RST_ASYNC_G         => RST_ASYNC_G,
         INT_PIPE_STAGES_G   => INT_PIPE_STAGES_G,
         PIPE_STAGES_G       => PIPE_STAGES_G,
         VALID_THOLD_G       => VALID_THOLD_G,
         VALID_BURST_MODE_G  => VALID_BURST_MODE_G,
         SLAVE_READY_EN_G    => ROGUE_SIM_EN_G,
         -- FIFO configurations
         SYNTH_MODE_G        => SYNTH_MODE_G,
         MEMORY_TYPE_G       => MEMORY_TYPE_G,
         GEN_SYNC_FIFO_G     => GEN_SYNC_FIFO_G,
         FIFO_ADDR_WIDTH_G   => FIFO_ADDR_WIDTH_G,
         FIFO_PAUSE_THRESH_G => FIFO_PAUSE_THRESH_G,
         -- AXI Stream Port Configurations
         SLAVE_AXI_CONFIG_G  => PHY_AXI_CONFIG_G,
         MASTER_AXI_CONFIG_G => APP_AXI_CONFIG_G)
      port map (
         -- Slave Port
         sAxisClk    => pgpClk,
         sAxisRst    => pgpReset,
         sAxisMaster => pgpMaster,
         sAxisCtrl   => pgpRxCtrl,
         sAxisSlave  => pgpRxSlave,
         -- Master Port
         mAxisClk    => axisClk,
         mAxisRst    => axisReset,
         mAxisMaster => axisMaster,
         mAxisSlave  => axisSlave);

end mapping;
