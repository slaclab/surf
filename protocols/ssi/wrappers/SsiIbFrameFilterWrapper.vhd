-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing wrapper for SsiIbFrameFilter
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

entity SsiIbFrameFilterWrapper is
   generic (
      DATA_BYTES_G     : positive range 1 to 8 := 2;
      SLAVE_READY_EN_G : boolean               := true);
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
      sAxisDropWord   : out sl;
      sAxisDropFrame  : out sl;
      mAxisTValid     : out sl;
      mAxisTData      : out slv(63 downto 0);
      mAxisTKeep      : out slv(7 downto 0);
      mAxisTLast      : out sl;
      mAxisTDest      : out slv(3 downto 0);
      mAxisSof        : out sl;
      mAxisEofe       : out sl;
      mAxisTReady     : in  sl);
end entity SsiIbFrameFilterWrapper;

architecture rtl of SsiIbFrameFilterWrapper is

   constant AXIS_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(
      dataBytes => DATA_BYTES_G,
      tKeepMode => TKEEP_NORMAL_C,
      tUserMode => TUSER_FIRST_LAST_C,
      tDestBits => 4,
      tUserBits => 2);
   constant DATA_WIDTH_C  : positive := 8*DATA_BYTES_G;

   signal sAxisMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal sAxisSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;
   signal sAxisCtrl   : AxiStreamCtrlType   := AXI_STREAM_CTRL_INIT_C;
   signal mAxisMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal mAxisSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;

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
      sAxisMaster <= v;
   end process sAxisComb;

   sAxisTReady <= sAxisSlave.tReady;
   mAxisSlave.tReady <= mAxisTReady;

   mAxisView : process (mAxisMaster) is
      variable dataV : slv(63 downto 0);
      variable keepV : slv(7 downto 0);
   begin
      dataV := (others => '0');
      keepV := (others => '0');

      dataV(DATA_WIDTH_C-1 downto 0) := mAxisMaster.tData(DATA_WIDTH_C-1 downto 0);
      keepV(DATA_BYTES_G-1 downto 0) := mAxisMaster.tKeep(DATA_BYTES_G-1 downto 0);

      mAxisTValid <= mAxisMaster.tValid;
      mAxisTData <= dataV;
      mAxisTKeep <= keepV;
      mAxisTLast <= mAxisMaster.tLast;
      mAxisTDest <= mAxisMaster.tDest(3 downto 0);
      mAxisSof <= ssiGetUserSof(AXIS_CONFIG_C, mAxisMaster);
      mAxisEofe <= ssiGetUserEofe(AXIS_CONFIG_C, mAxisMaster);
   end process mAxisView;

   U_DUT : entity surf.SsiIbFrameFilter
      generic map (
         TPD_G            => 1 ns,
         SLAVE_READY_EN_G => SLAVE_READY_EN_G,
         AXIS_CONFIG_G    => AXIS_CONFIG_C)
      port map (
         sAxisMaster    => sAxisMaster,
         sAxisSlave     => sAxisSlave,
         sAxisCtrl      => sAxisCtrl,
         sAxisDropWord  => sAxisDropWord,
         sAxisDropFrame => sAxisDropFrame,
         mAxisMaster    => mAxisMaster,
         mAxisSlave     => mAxisSlave,
         mAxisCtrl      => AXI_STREAM_CTRL_UNUSED_C,
         axisClk        => axisClk,
         axisRst        => axisRst);

end architecture rtl;
