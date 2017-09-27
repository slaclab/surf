-------------------------------------------------------------------------------
-- File       : AxiStreamDmaV2Mux.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-08-04
-- Last update: 2017-09-27
-------------------------------------------------------------------------------
-- Description: 
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

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;

entity AxiStreamDmaV2Mux is
   generic (
      TPD_G               : time                := 1 ns;
      DMA_SIZE_G          : positive            := 1;
      TDEST_ROUTES_G      : Slv8Array           := (0 => "--------");  -- Only used in ROUTED mode
      SLAVE_AXI_CONFIG_G  : AxiStreamConfigType := DMA_AXIS_CONFIG_G;
      MASTER_AXI_CONFIG_G : AxiStreamConfigType := APP_AXIS_CONFIG_G);
   port (
      -- Clock and Reset
      clk          : in  sl;
      rst          : in  sl;
      -- Single DMA Interface
      dmaObMaster  : in  AxiStreamMasterType;
      dmaObSlave   : out AxiStreamSlaveType;
      dmaIbMaster  : out AxiStreamMasterType;
      dmaIbSlave   : in  AxiStreamSlaveType;
      -- Multiple APP Interfaces
      appObMasters : out AxiStreamMasterArray(DMA_SIZE_G-1 downto 0);
      appObSlaves  : in  AxiStreamSlaveArray(DMA_SIZE_G-1 downto 0);
      appIbMasters : in  AxiStreamMasterArray(DMA_SIZE_G-1 downto 0);
      appIbSlaves  : out AxiStreamSlaveArray(DMA_SIZE_G-1 downto 0));
end AxiStreamDmaV2Mux;

architecture mapping of AxiStreamDmaV2Mux is

   signal ibMasters : AxiStreamMasterArray(DMA_SIZE_G-1 downto 0);
   signal ibSlaves  : AxiStreamSlaveArray(DMA_SIZE_G-1 downto 0);

begin

   GEN_VEC :
   for i in DMA_SIZE_G-1 downto 0 generate

      U_IbFifo : entity work.AxiStreamFifoV2
         generic map (
            -- General Configurations
            TPD_G               => TPD_G,
            INT_PIPE_STAGES_G   => 1,
            PIPE_STAGES_G       => 1,
            VALID_THOLD_G       => 128,  -- Hold until enough to burst into the interleaving MUX
            VALID_BURST_MODE_G  => true,
            -- FIFO configurations
            BRAM_EN_G           => true,
            GEN_SYNC_FIFO_G     => true,
            CASCADE_SIZE_G      => 1,
            FIFO_ADDR_WIDTH_G   => 9,
            -- AXI Stream Port Configurations
            SLAVE_AXI_CONFIG_G  => APP_AXIS_CONFIG_G,
            MASTER_AXI_CONFIG_G => DMA_AXIS_CONFIG_G)
         port map (
            -- Slave Port
            sAxisClk    => clk,
            sAxisRst    => rst,
            sAxisMaster => appIbMasters(i),
            sAxisSlave  => appIbSlaves(i),
            -- Master Port
            mAxisClk    => clk,
            mAxisRst    => rst,
            mAxisMaster => ibMasters(i),
            mAxisSlave  => ibSlaves(i));

   end generate GEN_VEC;

   --------------
   -- MUX Module
   --------------               
   U_Mux : entity work.AxiStreamMux
      generic map (
         TPD_G          => TPD_G,
         NUM_SLAVES_G   => DMA_SIZE_G,
         MODE_G         => "ROUTED",
         TDEST_ROUTES_G => TDEST_ROUTES_G,
         ILEAVE_EN_G    => true,        -- Using interleaving MUX
         ILEAVE_REARB_G => 0,
         PIPE_STAGES_G  => 1)
      port map (
         -- Clock and reset
         axisClk      => clk,
         axisRst      => rst,
         -- Slaves
         sAxisMasters => ibMasters,
         sAxisSlaves  => ibSlaves,
         -- Master
         mAxisMaster  => dmaIbMaster,
         mAxisSlave   => dmaIbSlave);

   ---------------       
   -- DEMUX Module
   ---------------       
   U_AxiStreamDeMux : entity work.AxiStreamDeMux
      generic map (
         TPD_G          => TPD_G,
         NUM_MASTERS_G  => DMA_SIZE_G,
         MODE_G         => "ROUTED",
         TDEST_ROUTES_G => TDEST_ROUTES_G,
         PIPE_STAGES_G  => 1)
      port map (
         -- Clock and reset
         axisClk      => clk,
         axisRst      => rst,
         -- Slaves
         sAxisMaster  => dmaObMaster,
         sAxisSlave   => dmaObSlave,
         -- Master
         mAxisMasters => appObMasters,
         mAxisSlaves  => appObSlaves);

end mapping;
