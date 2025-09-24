-------------------------------------------------------------------------------
-- Title      : HTSP: https://confluence.slac.stanford.edu/x/pQmODw
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: HTPS RX FIFO wrapper for the Application Side
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

entity HtspRxFifo is
   generic (
      TPD_G                 : time     := 1 ns;
      TX_MAX_PAYLOAD_SIZE_G : positive := 8192;
      NUM_VC_G              : positive);
   port (
      -- Application Interface (appClk domain)
      appClks       : in  slv(NUM_VC_G-1 downto 0);
      appRsts       : in  slv(NUM_VC_G-1 downto 0);
      appRxMasters  : out AxiStreamMasterArray(NUM_VC_G-1 downto 0);
      appRxSlaves   : in  AxiStreamSlaveArray(NUM_VC_G-1 downto 0);
      -- HTSP Interface (htspClk domain)
      htspClk       : in  sl;
      htspRst       : in  sl;
      rxlinkReady   : in  sl;
      htspRxMasters : in  AxiStreamMasterArray(NUM_VC_G-1 downto 0);
      htspRxCtrl    : out AxiStreamCtrlArray(NUM_VC_G-1 downto 0));
end HtspRxFifo;

architecture mapping of HtspRxFifo is

   signal htspMasters : AxiStreamMasterArray(NUM_VC_G-1 downto 0);
   signal rxMasters   : AxiStreamMasterArray(NUM_VC_G-1 downto 0);
   signal rxSlaves    : AxiStreamSlaveArray(NUM_VC_G-1 downto 0);
   signal disableSel  : slv(NUM_VC_G-1 downto 0);

   signal rxMaster : AxiStreamMasterType;
   signal rxSlave  : AxiStreamSlaveType;

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

   GEN_APP_RST_PIPES : for i in NUM_VC_G-1 downto 0 generate
      U_appRst : entity surf.RstPipeline
         generic map (
            TPD_G => TPD_G)
         port map (
            clk    => appClks(i),
            rstIn  => appRsts(i),
            rstOut => appResets(i));
   end generate GEN_APP_RST_PIPES;

   BLOWOFF_FILTER : process (htspRxMasters, rxlinkReady) is
      variable tmp : AxiStreamMasterArray(NUM_VC_G-1 downto 0);
      variable i   : natural;
   begin
      tmp := htspRxMasters;
      for i in NUM_VC_G-1 downto 0 loop
         if (rxlinkReady = '0') then
            tmp(i).tValid := '0';
         end if;
      end loop;
      htspMasters <= tmp;
   end process;

   GEN_VEC :
   for i in NUM_VC_G-1 downto 0 generate

      U_FIFO : entity surf.AxiStreamFifoV2
         generic map (
            -- General Configurations
            TPD_G               => TPD_G,
            INT_PIPE_STAGES_G   => 1,
            PIPE_STAGES_G       => 1,
            SLAVE_READY_EN_G    => false,
            VALID_THOLD_G       => (TX_MAX_PAYLOAD_SIZE_G/64),  -- Hold until enough to burst into the interleaving MUX
            VALID_BURST_MODE_G  => true,
            -- FIFO configurations
            SYNTH_MODE_G        => "xpm",
            MEMORY_TYPE_G       => "uram",
            GEN_SYNC_FIFO_G     => true,
            FIFO_ADDR_WIDTH_G   => 12,  -- 4k URAM,
            FIFO_FIXED_THRESH_G => true,
            FIFO_PAUSE_THRESH_G => 1024,  -- 1/4 of buffer
            -- AXI Stream Port Configurations
            SLAVE_AXI_CONFIG_G  => HTSP_AXIS_CONFIG_C,
            MASTER_AXI_CONFIG_G => HTSP_AXIS_CONFIG_C)
         port map (
            -- Slave Port
            sAxisClk    => htspClk,
            sAxisRst    => htspReset,
            sAxisMaster => htspMasters(i),
            sAxisCtrl   => htspRxCtrl(i),
            -- Master Port
            mAxisClk    => htspClk,
            mAxisRst    => htspReset,
            mAxisMaster => rxMasters(i),
            mAxisSlave  => rxSlaves(i));

      ASYNC_FIFO : entity surf.AxiStreamFifoV2
         generic map (
            -- General Configurations
            TPD_G               => TPD_G,
            INT_PIPE_STAGES_G   => 1,
            PIPE_STAGES_G       => 1,
            SLAVE_READY_EN_G    => true,
            VALID_THOLD_G       => 1,
            -- FIFO configurations
            MEMORY_TYPE_G       => "block",
            GEN_SYNC_FIFO_G     => false,
            FIFO_ADDR_WIDTH_G   => 9,
            -- AXI Stream Port Configurations
            SLAVE_AXI_CONFIG_G  => HTSP_AXIS_CONFIG_C,
            MASTER_AXI_CONFIG_G => HTSP_AXIS_CONFIG_C)
         port map (
            -- Slave Port
            sAxisClk    => htspClk,
            sAxisRst    => htspReset,
            sAxisMaster => rxMasters(i),
            sAxisSlave  => rxSlaves(i),
            -- Master Port
            mAxisClk    => appClks(i),
            mAxisRst    => appRsts(i),
            mAxisMaster => appRxMasters(i),
            mAxisSlave  => appRxSlaves(i));

   end generate GEN_VEC;

end mapping;
