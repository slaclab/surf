-------------------------------------------------------------------------------
-- File       : RogueStreamSim.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-12-05
-- Last update: 2017-02-02
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

entity RogueStreamSimWrap is
   generic (
      TPD_G               : time                   := 1 ns;
      DEST_ID_G           : integer range 0 to 255 := 1;
      USER_ID_G           : integer range 0 to 100 := 1;
      COMMON_MASTER_CLK_G : boolean                := false;
      COMMON_SLAVE_CLK_G  : boolean                := false;
      AXIS_CONFIG_G       : AxiStreamConfigType    := AXI_STREAM_CONFIG_INIT_C
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
      mAxisSlave  : in  AxiStreamSlaveType;

      -- Sideband Clock and reset, clocked with clk and rst
      opCode      : out slv(7 downto 0);
      opCodeEn    : out sl;
      remData     : out slv(7 downto 0)
      );
end RogueStreamSimWrap;

-- Define architecture
architecture RogueStreamSimWrap of RogueStreamSimWrap is

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
   signal ibMaster : AxiStreamMasterType;
   signal ibSlave  : AxiStreamSlaveType;
   signal obMaster : AxiStreamMasterType;
   signal obSlave  : AxiStreamSlaveType;

begin

   ------------------------------------
   -- Inbound
   ------------------------------------
   U_IbFifo : entity work.AxiStreamFifo
      generic map (
         TPD_G               => TPD_G,
         GEN_SYNC_FIFO_G     => COMMON_SLAVE_CLK_G,
         SLAVE_AXI_CONFIG_G  => AXIS_CONFIG_G,
         MASTER_AXI_CONFIG_G => INT_CONFIG_C)
      port map (
         sAxisClk    => sAxisClk,
         sAxisRst    => sAxisRst,
         sAxisMaster => sAxisMaster,
         sAxisSlave  => sAxisSlave,
         mAxisClk    => clk,
         mAxisRst    => rst,
         mAxisMaster => ibMaster,
         mAxisSlave  => ibSlave);

   ------------------------------------
   -- Sim Core
   ------------------------------------
   U_RogueStreamSim : entity work.RogueStreamSim
      port map(
         clock      => clk,
         reset      => rst,
         dest       => toSlv(DEST_ID_G, 8),
         uid        => toSlv(USER_ID_G, 6),
         obValid    => obMaster.tValid,
         obReady    => obSlave.tReady,
         obDataLow  => obMaster.tData(31 downto 0),
         obDataHigh => obMaster.tData(63 downto 32),
         obUserLow  => obMaster.tUser(31 downto 0),
         obUserHigh => obMaster.tUser(63 downto 32),
         obKeep     => obMaster.tKeep(7 downto 0),
         obLast     => obMaster.tLast,
         ibValid    => ibMaster.tValid,
         ibReady    => ibSlave.tReady,
         ibDataLow  => ibMaster.tData(31 downto 0),
         ibDataHigh => ibMaster.tData(63 downto 32),
         ibUserLow  => ibMaster.tUser(31 downto 0),
         ibUserHigh => ibMaster.tUser(63 downto 32),
         ibKeep     => ibMaster.tKeep(7 downto 0),
         ibLast     => ibMaster.tLast,
         opCode     => opCode,
         opCodeEn   => opCodeEn,
         remData    => remData);

   obMaster.tStrb <= (others => '1');
   obMaster.tDest <= toSlv(DEST_ID_G, 8);
   obMaster.tId   <= (others => '0');

   obMaster.tKeep(15 downto 8)   <= (others => '0');
   obMaster.tData(127 downto 64) <= (others => '0');
   obMaster.tUser(127 downto 64) <= (others => '0');

   ------------------------------------
   -- Outbound
   ------------------------------------
   U_ObFifo : entity work.AxiStreamFifo
      generic map (
         TPD_G               => TPD_G,
         GEN_SYNC_FIFO_G     => COMMON_MASTER_CLK_G,
         SLAVE_AXI_CONFIG_G  => INT_CONFIG_C,
         MASTER_AXI_CONFIG_G => AXIS_CONFIG_G)
      port map (
         sAxisClk    => clk,
         sAxisRst    => rst,
         sAxisMaster => obMaster,
         sAxisSlave  => obSlave,
         mAxisClk    => mAxisClk,
         mAxisRst    => mAxisRst,
         mAxisMaster => mAxisMaster,
         mAxisSlave  => mAxisSlave);

end RogueStreamSimWrap;

