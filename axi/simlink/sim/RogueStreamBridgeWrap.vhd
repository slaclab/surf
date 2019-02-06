-------------------------------------------------------------------------------
-- File       : RogueStringBridgeWrap.vhd
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Wrapper for Rogue Stream Simulation Module
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
use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;

entity RogueStringBridgeWrap is
   generic (
      TPD_G               : time                     := 1 ns;
      PORT_NUM_G          : integer range 0 to 65535 := 1;
      SSI_EN_G            : boolean                  := true;
      CHAN_COUNT_G        : integer range 1 to 32    := 1;
      COMMON_MASTER_CLK_G : boolean                  := false;
      COMMON_SLAVE_CLK_G  : boolean                  := false;
      AXIS_CONFIG_G       : AxiStreamConfigType      := AXI_STREAM_CONFIG_INIT_C
   );
   port (

      -- Main Clock and reset used internally
      clk : in sl;
      rst : in sl;

      -- Slave
      sAxisClk    : in  sl;             -- Set COMMON_SLAVE_CLK_G if same as clk input
      sAxisRst    : in  sl;
      sAxisMaster : in  AxiStreamMasterType;
      sAxisSlave  : out AxiStreamSlaveType;

      -- Master
      mAxisClk    : in  sl;             -- Set COMMON_MASTER_CLK_G if same as clk input
      mAxisRst    : in  sl;
      mAxisMaster : out AxiStreamMasterType;
      mAxisSlave  : in  AxiStreamSlaveType
   );
end RogueStringBridgeWrap;

-- Define architecture
architecture RogueStringBridgeWrap of RogueStringBridgeWrap is

   -- Internal configuration
   constant INT_CONFIG_C : AxiStreamConfigType := (
      TSTRB_EN_C    => false,
      TDATA_BYTES_C => 8,
      TDEST_BITS_C  => 8,
      TID_BITS_C    => 0,
      TKEEP_MODE_C  => TKEEP_NORMAL_C,
      TUSER_BITS_C  => 8,
      TUSER_MODE_C  => TUSER_NORMAL_C);

   -- Local Signals
   signal dmMaster : AxiStreamMasterArray(CHAN_COUNT_G-1 downto 0);
   signal dmSlave  : AxiStreamSlaveArray(CHAN_COUNT_G-1 downto 0);
   signal ibMaster : AxiStreamMasterArray(CHAN_COUNT_G-1 downto 0);
   signal ibSlave  : AxiStreamSlaveArray(CHAN_COUNT_G-1 downto 0);
   signal obMaster : AxiStreamMasterArray(CHAN_COUNT_G-1 downto 0);
   signal obSlave  : AxiStreamSlaveArray(CHAN_COUNT_G-1 downto 0);
   signal mxMaster : AxiStreamMasterType(CHAN_COUNT_G-1 downto 0);
   signal mxSlave  : AxiStreamSlaveType(CHAN_COUNT_G-1 downto 0);

begin

   ------------------------------------
   -- Inbound Demux
   ------------------------------------
   U_DeMux: entity work.AxiStreamDeMux
      generic map (
         TPD_G          => 1 ns,
         NUM_MASTERS_G  => CHAN_COUNT_G
      ) port map (
         -- Clock and reset
         axisClk      => sAxisClk,
         axisRst      => sAxisRst,
         sAxisMaster  => sAxisMaster,
         sAxisSlave   => sAxisSlave,
         mAxisMasters => dmMaster,
         mAxisSlaves  => dmSlave);

   -- Channels
   U_ChanGen: for i in 0 to CHAN_COUNT_G-1 generate

      ------------------------------------
      -- Inbound FIFOs
      ------------------------------------
      U_IbFifo : entity work.AxiStreamFifoV2
         generic map (
            TPD_G               => TPD_G,
            GEN_SYNC_FIFO_G     => COMMON_SLAVE_CLK_G,
            SLAVE_AXI_CONFIG_G  => AXIS_CONFIG_G,
            MASTER_AXI_CONFIG_G => INT_CONFIG_C)
         port map (
            sAxisClk    => sAxisClk,
            sAxisRst    => sAxisRst,
            sAxisMaster => dmMaster(i),
            sAxisSlave  => dmSlave(i),
            mAxisClk    => clk,
            mAxisRst    => rst,
            mAxisMaster => ibMaster(i),
            mAxisSlave  => ibSlave(i));

      ------------------------------------
      -- Sim Core
      ------------------------------------
      U_RogueStringBridge : entity work.RogueStringBridge
         port map(
            clock      => clk,
            reset      => rst,
            portNum    => toSlv(PORT_NUM_G + i*2, 16),
            ssi        => toSl(SSI_EN_G),
            obValid    => obMaster(i).tValid,
            obReady    => obSlave(i).tReady,
            obDataLow  => obMaster(i).tData(31 downto 0),
            obDataHigh => obMaster(i).tData(63 downto 32),
            obUserLow  => obMaster(i).tUser(31 downto 0),
            obUserHigh => obMaster(i).tUser(63 downto 32),
            obKeep     => obMaster(i).tKeep(7 downto 0),
            obLast     => obMaster(i).tLast,
            ibValid    => ibMaster(i).tValid,
            ibReady    => ibSlave(i).tReady,
            ibDataLow  => ibMaster(i).tData(31 downto 0),
            ibDataHigh => ibMaster(i).tData(63 downto 32),
            ibUserLow  => ibMaster(i).tUser(31 downto 0),
            ibUserHigh => ibMaster(i).tUser(63 downto 32),
            ibKeep     => ibMaster(i).tKeep(7 downto 0),
            ibLast     => ibMaster(i).tLast);

      obMaster(i).tStrb <= (others => '1');
      obMaster(i).tDest <= (others => '0');
      obMaster(i).tId   <= (others => '0');

      obMaster(i).tKeep(AXI_STREAM_MAX_TKEEP_WIDTH_C-1 downto 8)  <= (others => '0');
      obMaster(i).tData(AXI_STREAM_MAX_TDATA_WIDTH_C-1 downto 64) <= (others => '0');
      obMaster(i).tUser(AXI_STREAM_MAX_TDATA_WIDTH_C-1 downto 64) <= (others => '0');

      ------------------------------------
      -- Outbound FIFOs
      ------------------------------------
      U_ObFifo : entity work.AxiStreamFifoV2
         generic map (
            TPD_G               => TPD_G,
            GEN_SYNC_FIFO_G     => COMMON_MASTER_CLK_G,
            SLAVE_AXI_CONFIG_G  => INT_CONFIG_C,
            MASTER_AXI_CONFIG_G => AXIS_CONFIG_G)
         port map (
            sAxisClk    => clk,
            sAxisRst    => rst,
            sAxisMaster => obMaster(i),
            sAxisSlave  => obSlave(i),
            mAxisClk    => mAxisClk,
            mAxisRst    => mAxisRst,
            mAxisMaster => mxMaster(i),
            mAxisSlave  => mxSlave(i));

   end generate;

   ------------------------------------
   -- Outbound Mux
   ------------------------------------
   U_Mux: entity work.AxiStreamMux
      generic map (
         TPD_G        => 1 ns,
         NUM_SLAVES_G => CHAN_COUNT_G
      ) port map (
         axisClk      => mAxisClk,
         axisRst      => mAxisRst,
         sAxisMasters => mxMaster,
         sAxisSlaves  => mxSlave);
         mAxisMaster  => mAxisMaster,
         mAxisSlave   => mAxisSlave);

end RogueStringBridgeWrap;

