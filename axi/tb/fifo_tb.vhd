-------------------------------------------------------------------------------
-- File       : fifo_tb.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-05-02
-- Last update: 2016-09-06
-------------------------------------------------------------------------------
-- Description: Simulation Testbed for FIFO module
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Firmware Standard Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'SLAC Firmware Standard Library', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
------------------------------------------------------------------------------

LIBRARY ieee;
USE work.ALL;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
Library unisim;
use unisim.vcomponents.all;

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;

entity fifo_tb is end fifo_tb;

-- Define architecture
architecture fifo_tb of fifo_tb is

   constant SRC_CONFIG_C : AxiStreamConfigType := (
      TSTRB_EN_C    => false,
      TDATA_BYTES_C => 2,
      TDEST_BITS_C  => 8,
      TID_BITS_C    => 8,
      TKEEP_MODE_C  => TKEEP_COMP_C,
      TUSER_BITS_C  => 2,
      TUSER_MODE_C  => TUSER_FIRST_LAST_C
   );

   constant FIFO_CONFIG_C : AxiStreamConfigType := (
      TSTRB_EN_C    => false,
      TDATA_BYTES_C => 8,
      TDEST_BITS_C  => 4,
      TID_BITS_C    => 0,
      TKEEP_MODE_C  => TKEEP_COMP_C,
      TUSER_BITS_C  => 2,
      TUSER_MODE_C  => TUSER_FIRST_LAST_C
   );

   -- Number of end points
   constant EP_COUNT_C : integer := 4;
   constant TPD_C      : time    := 1 ns;

   signal axiClk         : sl;
   signal axiClkRst      : sl;

   signal prbsMaster     : AxiStreamMasterArray(EP_COUNT_C-1 downto 0);
   signal prbsSlave      : AxiStreamSlaveArray(EP_COUNT_C-1 downto 0);
   signal wideMaster     : AxiStreamMasterArray(EP_COUNT_C-1 downto 0);
   signal wideSlave      : AxiStreamSlaveArray(EP_COUNT_C-1 downto 0);
   signal muxMaster      : AxiStreamMasterType;
   signal muxSlave       : AxiStreamSlaveType;
   signal fifoMaster     : AxiStreamMasterType;
   signal fifoSlave      : AxiStreamSlaveType;
   signal demuxMaster    : AxiStreamMasterArray(EP_COUNT_C-1 downto 0);
   signal demuxSlave     : AxiStreamSlaveArray(EP_COUNT_C-1 downto 0);

   signal updated        : slv(EP_COUNT_C-1 downto 0);
   signal errorDet       : slv(EP_COUNT_C-1 downto 0);

begin

   process begin
      axiClk <= '1';
      wait for 5 ns;
      axiClk <= '0';
      wait for 5 ns;
   end process;

   process begin
      axiClkRst <= '1';
      wait for (100 ns);
      axiClkRst <= '0';
      wait;
   end process;

   GEN_SRC: for i in 0 to EP_COUNT_C-1 generate
      PrbsTx : entity work.SsiPrbsTx
         generic map (
            TPD_G                      => TPD_C,
            GEN_SYNC_FIFO_G            => true,
            FIFO_ADDR_WIDTH_G          => 9,
            FIFO_PAUSE_THRESH_G        => 500,
            MASTER_AXI_STREAM_CONFIG_G => SRC_CONFIG_C,
            MASTER_AXI_PIPE_STAGES_G   => 1
         ) port map (
            mAxisClk     => axiClk,
            mAxisRst     => axiClkRst,
            mAxisMaster  => prbsMaster(i),
            mAxisSlave   => prbsSlave(i),
            locClk       => axiClk,
            locRst       => axiClkRst,
            trig         => '1',
            packetLength => x"00000801",
            busy         => open,
            tDest        => (others => '0'),
            tId          => (others => '0')
         );     

      U_AxiStreamFifo: entity work.AxiStreamFifo 
         generic map (
            TPD_G                  => TPD_C,
            FIFO_ADDR_WIDTH_G      => 9,
            SLAVE_AXI_CONFIG_G     => SRC_CONFIG_C,
            VALID_THOLD_G          => 16,
            MASTER_AXI_CONFIG_G    => FIFO_CONFIG_C,
            INT_PIPE_STAGES_G      => 1,
            PIPE_STAGES_G          => 1
         ) port map (
            sAxisClk    => axiClk,
            sAxisRst    => axiClkRst,
            sAxisMaster => prbsMaster(i),
            sAxisSlave  => prbsSlave(i),
            mAxisClk    => axiClk,
            mAxisRst    => axiClkRst,
            mAxisMaster => wideMaster(i),
            mAxisSlave  => wideSlave(i)
         );
   end generate GEN_SRC;

   U_Mux: entity work.AxiStreamMux 
      generic map (
         TPD_G          => TPD_C,
         NUM_SLAVES_G   => EP_COUNT_C,
         MODE_G         => "INDEXED",
         ILEAVE_EN_G    => true
      ) port map (
         sAxisMasters => wideMaster,
         sAxisSlaves  => wideSlave,
         mAxisMaster  => muxMaster,
         mAxisSlave   => muxSlave,
         axisClk      => axiClk,
         axisRst      => axiClkRst
      );

   U_AxiStreamFifo: entity work.AxiStreamFifo 
      generic map (
         TPD_G                  => TPD_C,
         INT_PIPE_STAGES_G      => 1,
         PIPE_STAGES_G          => 0,
         SLAVE_READY_EN_G       => true,
         VALID_THOLD_G          => 1,
         BRAM_EN_G              => true,
         XIL_DEVICE_G           => "7SERIES",
         USE_BUILT_IN_G         => false,
         GEN_SYNC_FIFO_G        => true,
         ALTERA_SYN_G           => false,
         ALTERA_RAM_G           => "M9K",
         CASCADE_SIZE_G         => 1,
         FIFO_ADDR_WIDTH_G      => 9,
         FIFO_FIXED_THRESH_G    => true,
         FIFO_PAUSE_THRESH_G    => 1,
         FIFO_USE_WIDER_G       => true,
         LAST_FIFO_ADDR_WIDTH_G => 0,  
         CASCADE_PAUSE_SEL_G    => 0,
         SLAVE_AXI_CONFIG_G     => FIFO_CONFIG_C,
         MASTER_AXI_CONFIG_G    => FIFO_CONFIG_C
      ) port map (
         sAxisClk    => axiClk,
         sAxisRst    => axiClkRst,
         sAxisMaster => muxMaster,
         sAxisSlave  => muxSlave,
         mAxisClk    => axiClk,
         mAxisRst    => axiClkRst,
         mAxisMaster => fifoMaster,
         mAxisSlave  => fifoSlave
      );

   U_DeMux: entity work.AxiStreamDeMux 
      generic map (
         TPD_G         => TPD_C,
         NUM_MASTERS_G => EP_COUNT_C,
         MODE_G        => "INDEXED"
      ) port map (
         axisClk       => axiClk,
         axisRst       => axiClkRst,
         sAxisMaster   => fifoMaster,
         sAxisSlave    => fifoSlave,
         mAxisMasters  => demuxMaster,
         mAxisSlaves   => demuxSlave
      );

   GEN_DST: for i in 0 to EP_COUNT_C-1 generate
      SsiPrbsRx_Inst : entity work.SsiPrbsRx
         generic map (
            -- General Configurations
            TPD_G                      => TPD_C,
            STATUS_CNT_WIDTH_G         => 32,
            GEN_SYNC_FIFO_G            => true,
            FIFO_ADDR_WIDTH_G          => 9,
            FIFO_PAUSE_THRESH_G        => 500,
            SLAVE_AXI_STREAM_CONFIG_G  => FIFO_CONFIG_C
         ) port map (
            sAxisClk       => axiClk,
            sAxisRst       => axiClkRst,
            sAxisMaster    => demuxMaster(i),
            sAxisSlave     => demuxSlave(i),
            mAxisClk       => axiClk,
            mAxisRst       => axiClkRst,
            updatedResults => updated(i),
            errorDet       => errorDet(i)
         );     
   end generate;

end fifo_tb;

