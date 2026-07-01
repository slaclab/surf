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
      CASCADE_SIZE_G        : positive := 1;
      FIFO_ADDR_WIDTH_G     : positive := 12;
      FIFO_PAUSE_THRESH_G   : positive := 256;
      TX_MAX_PAYLOAD_SIZE_G : positive := 8192;
      ROGUE_SIM_EN_G        : boolean  := false;
      GEN_SYNC_FIFO_G       : boolean  := false;
      MEMORY_TYPE_G         : string   := "uram";
      NUM_VC_G              : positive;
      APP_AXI_CONFIG_G      : AxiStreamConfigType);
   port (
      -- HTSP Interface (htspClk domain)
      htspClk       : in  sl;
      htspRst       : in  sl;
      rxlinkReady   : in  sl;
      htspRxMasters : in  AxiStreamMasterArray(NUM_VC_G-1 downto 0);
      htspRxSlaves  : out AxiStreamSlaveArray(NUM_VC_G-1 downto 0);
      htspRxCtrl    : out AxiStreamCtrlArray(NUM_VC_G-1 downto 0);
      -- Application Interface (appClk domain)
      appClks       : in  slv(NUM_VC_G-1 downto 0);
      appRsts       : in  slv(NUM_VC_G-1 downto 0);
      appRxMasters  : out AxiStreamMasterArray(NUM_VC_G-1 downto 0);
      appRxSlaves   : in  AxiStreamSlaveArray(NUM_VC_G-1 downto 0));
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

      -------------------------------------------------------------------------------------
      -- Note: The reason why we don't combine the U_FIFO with GEN_ASYNC_FIFO.ASYNC_FIFO is
      -- because "READY_EN_G must be true if slave width is great than master"
      -- and common for APP_AXI_CONFIG_G to be less than HTSP_AXIS_CONFIG_C
      -------------------------------------------------------------------------------------
      U_FIFO : entity surf.AxiStreamFifoV2
         generic map (
            -- General Configurations
            TPD_G               => TPD_G,
            INT_PIPE_STAGES_G   => 1,
            PIPE_STAGES_G       => 1,
            SLAVE_READY_EN_G    => ROGUE_SIM_EN_G,
            VALID_THOLD_G       => (TX_MAX_PAYLOAD_SIZE_G/64),  -- Hold until enough to burst into the interleaving MUX
            VALID_BURST_MODE_G  => true,
            -- FIFO configurations
            SYNTH_MODE_G        => "xpm",
            MEMORY_TYPE_G       => MEMORY_TYPE_G,
            GEN_SYNC_FIFO_G     => true,
            FIFO_ADDR_WIDTH_G   => FIFO_ADDR_WIDTH_G,
            FIFO_PAUSE_THRESH_G => FIFO_PAUSE_THRESH_G,
            CASCADE_SIZE_G      => CASCADE_SIZE_G,
            -- AXI Stream Port Configurations
            SLAVE_AXI_CONFIG_G  => HTSP_AXIS_CONFIG_C,
            MASTER_AXI_CONFIG_G => HTSP_AXIS_CONFIG_C)
         port map (
            -- Slave Port
            sAxisClk    => htspClk,
            sAxisRst    => htspReset,
            sAxisMaster => htspMasters(i),
            sAxisCtrl   => htspRxCtrl(i),
            sAxisSlave  => htspRxSlaves(i),
            -- Master Port
            mAxisClk    => htspClk,
            mAxisRst    => htspReset,
            mAxisMaster => rxMasters(i),
            mAxisSlave  => rxSlaves(i));

      GEN_ASYNC_FIFO : if not GEN_SYNC_FIFO_G generate
         ASYNC_FIFO : entity surf.AxiStreamFifoV2
            generic map (
               -- General Configurations
               TPD_G               => TPD_G,
               INT_PIPE_STAGES_G   => 1,
               PIPE_STAGES_G       => 1,
               SLAVE_READY_EN_G    => true,
               VALID_THOLD_G       => 1,
               -- FIFO configurations
               MEMORY_TYPE_G       => "distributed",
               GEN_SYNC_FIFO_G     => false,
               FIFO_ADDR_WIDTH_G   => 4,
               INT_WIDTH_SELECT_G  => "NARROW",
               -- AXI Stream Port Configurations
               SLAVE_AXI_CONFIG_G  => HTSP_AXIS_CONFIG_C,
               MASTER_AXI_CONFIG_G => APP_AXI_CONFIG_G)
            port map (
               -- Slave Port
               sAxisClk    => htspClk,
               sAxisRst    => htspReset,
               sAxisMaster => rxMasters(i),
               sAxisSlave  => rxSlaves(i),
               -- Master Port
               mAxisClk    => appClks(i),
               mAxisRst    => appResets(i),
               mAxisMaster => appRxMasters(i),
               mAxisSlave  => appRxSlaves(i));
      end generate;

      GEN_SYNC_FIFO : if GEN_SYNC_FIFO_G generate
         U_Gearbox : entity surf.AxiStreamGearbox
            generic map (
               TPD_G               => TPD_G,
               SLAVE_AXI_CONFIG_G  => HTSP_AXIS_CONFIG_C,
               MASTER_AXI_CONFIG_G => APP_AXI_CONFIG_G)
            port map (
               -- Clock and reset
               axisClk     => htspClk,
               axisRst     => htspReset,
               -- Inbound Stream
               sAxisMaster => rxMasters(i),
               sAxisSlave  => rxSlaves(i),
               -- Outbound Stream
               mAxisMaster => appRxMasters(i),
               mAxisSlave  => appRxSlaves(i));
      end generate;

   end generate GEN_VEC;

end mapping;
