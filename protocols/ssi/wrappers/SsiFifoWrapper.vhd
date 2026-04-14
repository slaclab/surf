-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing wrapper for SsiFifo
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

library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;
use surf.SsiPkg.all;

entity SsiFifoWrapper is
   generic (
      DATA_BYTES_G      : positive range 1 to 8 := 2;
      FIFO_ADDR_WIDTH_G : positive range 1 to 16 := 4;
      VALID_THOLD_G     : natural               := 1;
      GEN_SYNC_FIFO_G   : boolean               := false;
      SLAVE_READY_EN_G  : boolean               := true);
   port (
      axisClk         : in  sl;
      axisRst         : in  sl;
      sAxisTValid     : in  sl;
      sAxisTData      : in  slv(63 downto 0);
      sAxisTKeep      : in  slv(7 downto 0);
      sAxisTLast      : in  sl;
      sAxisTDest      : in  slv(3 downto 0);
      sAxisSof        : in  sl;
      sAxisEofe       : in  sl;
      sAxisTReady     : out sl;
      sAxisPause      : out sl;
      fifoPauseThresh : in  slv(15 downto 0);
      fifoWrCnt       : out slv(15 downto 0);
      sAxisDropWord   : out sl;
      sAxisDropFrame  : out sl;
      mAxisDropWord   : out sl;
      mAxisDropFrame  : out sl;
      lockupRstEvent  : out sl;
      mAxisTValid     : out sl;
      mAxisTData      : out slv(63 downto 0);
      mAxisTKeep      : out slv(7 downto 0);
      mAxisTLast      : out sl;
      mAxisTDest      : out slv(3 downto 0);
      mAxisSof        : out sl;
      mAxisEofe       : out sl;
      mAxisTReady     : in  sl);
end entity SsiFifoWrapper;

architecture rtl of SsiFifoWrapper is

   constant AXIS_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(
      dataBytes => DATA_BYTES_G,
      tKeepMode => TKEEP_NORMAL_C,
      tUserMode => TUSER_FIRST_LAST_C,
      tDestBits => 4,
      tUserBits => 2);
   constant DATA_WIDTH_C  : positive := 8*DATA_BYTES_G;

   signal sAxisMasterInt : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal sAxisSlaveInt  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;
   signal sAxisCtrlInt   : AxiStreamCtrlType   := AXI_STREAM_CTRL_INIT_C;
   signal mAxisMasterInt : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal mAxisSlaveInt  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;
   signal fifoWrCntInt   : slv(FIFO_ADDR_WIDTH_G-1 downto 0) := (others => '0');
   signal pauseThreshInt : slv(FIFO_ADDR_WIDTH_G-1 downto 0) := (others => '1');

begin

   sAxisComb : process (sAxisEofe, sAxisSof, sAxisTData, sAxisTDest, sAxisTKeep, sAxisTLast, sAxisTValid) is
      variable v : AxiStreamMasterType;
   begin
      v := AXI_STREAM_MASTER_INIT_C;
      v.tValid := sAxisTValid;
      v.tData(DATA_WIDTH_C-1 downto 0) := sAxisTData(DATA_WIDTH_C-1 downto 0);
      v.tKeep(DATA_BYTES_G-1 downto 0) := sAxisTKeep(DATA_BYTES_G-1 downto 0);
      v.tLast := sAxisTLast;
      v.tDest(3 downto 0) := sAxisTDest;
      ssiSetUserSof(AXIS_CONFIG_C, v, sAxisSof);
      ssiSetUserEofe(AXIS_CONFIG_C, v, sAxisEofe);
      sAxisMasterInt <= v;
   end process sAxisComb;

   sAxisTReady <= sAxisSlaveInt.tReady;
   sAxisPause <= sAxisCtrlInt.pause;
   pauseThreshInt <= fifoPauseThresh(FIFO_ADDR_WIDTH_G-1 downto 0);
   fifoWrCnt <= resize(fifoWrCntInt, fifoWrCnt'length);
   mAxisSlaveInt.tReady <= mAxisTReady;

   mAxisView : process (mAxisMasterInt) is
      variable dataV : slv(63 downto 0);
      variable keepV : slv(7 downto 0);
   begin
      dataV := (others => '0');
      keepV := (others => '0');

      dataV(DATA_WIDTH_C-1 downto 0) := mAxisMasterInt.tData(DATA_WIDTH_C-1 downto 0);
      keepV(DATA_BYTES_G-1 downto 0) := mAxisMasterInt.tKeep(DATA_BYTES_G-1 downto 0);

      mAxisTValid <= mAxisMasterInt.tValid;
      mAxisTData <= dataV;
      mAxisTKeep <= keepV;
      mAxisTLast <= mAxisMasterInt.tLast;
      mAxisTDest <= mAxisMasterInt.tDest(3 downto 0);
      mAxisSof <= ssiGetUserSof(AXIS_CONFIG_C, mAxisMasterInt);
      mAxisEofe <= ssiGetUserEofe(AXIS_CONFIG_C, mAxisMasterInt);
   end process mAxisView;

   U_DUT : entity surf.SsiFifo
      generic map (
         TPD_G               => 1 ns,
         INT_PIPE_STAGES_G   => 0,
         PIPE_STAGES_G       => 0,
         SLAVE_READY_EN_G    => SLAVE_READY_EN_G,
         VALID_THOLD_G       => VALID_THOLD_G,
         GEN_SYNC_FIFO_G     => GEN_SYNC_FIFO_G,
         FIFO_ADDR_WIDTH_G   => FIFO_ADDR_WIDTH_G,
         FIFO_FIXED_THRESH_G => false,
         FIFO_PAUSE_THRESH_G => 1,
         MEMORY_TYPE_G       => "distributed",
         SLAVE_AXI_CONFIG_G  => AXIS_CONFIG_C,
         MASTER_AXI_CONFIG_G => AXIS_CONFIG_C)
      port map (
         sAxisClk        => axisClk,
         sAxisRst        => axisRst,
         sAxisMaster     => sAxisMasterInt,
         sAxisSlave      => sAxisSlaveInt,
         sAxisCtrl       => sAxisCtrlInt,
         fifoPauseThresh => pauseThreshInt,
         fifoWrCnt       => fifoWrCntInt,
         sAxisDropWord   => sAxisDropWord,
         sAxisDropFrame  => sAxisDropFrame,
         mAxisDropWord   => mAxisDropWord,
         mAxisDropFrame  => mAxisDropFrame,
         lockupRstEvent  => lockupRstEvent,
         mAxisClk        => axisClk,
         mAxisRst        => axisRst,
         mAxisMaster     => mAxisMasterInt,
         mAxisSlave      => mAxisSlaveInt);

end architecture rtl;
