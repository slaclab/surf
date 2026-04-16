-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing wrapper for SsiIncrementingTx
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

entity SsiIncrementingTxWrapper is
   port (
      axisClk      : in  sl;
      axisRst      : in  sl;
      trig         : in  sl;
      packetLength : in  slv(31 downto 0);
      busy         : out sl;
      tDest        : in  slv(7 downto 0);
      tId          : in  slv(7 downto 0);
      mAxisTValid  : out sl;
      mAxisTData   : out slv(63 downto 0);
      mAxisTKeep   : out slv(7 downto 0);
      mAxisTLast   : out sl;
      mAxisTDest   : out slv(7 downto 0);
      mAxisTId     : out slv(7 downto 0);
      mAxisSof     : out sl;
      mAxisEofe    : out sl;
      mAxisTReady  : in  sl);
end entity SsiIncrementingTxWrapper;

architecture rtl of SsiIncrementingTxWrapper is

   constant AXIS_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(
      dataBytes => 4,
      tKeepMode => TKEEP_NORMAL_C,
      tUserMode => TUSER_FIRST_LAST_C,
      tDestBits => 8,
      tIdBits   => 8,
      tUserBits => 2);

   signal mAxisMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal mAxisSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;

begin

   mAxisSlave.tReady <= mAxisTReady;

   mAxisView : process (mAxisMaster) is
      variable dataV : slv(63 downto 0);
      variable keepV : slv(7 downto 0);
   begin
      dataV := (others => '0');
      keepV := (others => '0');

      dataV(31 downto 0) := mAxisMaster.tData(31 downto 0);
      keepV(3 downto 0) := mAxisMaster.tKeep(3 downto 0);

      mAxisTValid <= mAxisMaster.tValid;
      mAxisTData <= dataV;
      mAxisTKeep <= keepV;
      mAxisTLast <= mAxisMaster.tLast;
      mAxisTDest <= mAxisMaster.tDest(7 downto 0);
      mAxisTId <= mAxisMaster.tId(7 downto 0);
      mAxisSof <= ssiGetUserSof(AXIS_CONFIG_C, mAxisMaster);
      mAxisEofe <= ssiGetUserEofe(AXIS_CONFIG_C, mAxisMaster);
   end process mAxisView;

   U_DUT : entity surf.SsiIncrementingTx
      generic map (
         TPD_G                      => 1 ns,
         MEMORY_TYPE_G              => "distributed",
         GEN_SYNC_FIFO_G            => true,
         FIFO_ADDR_WIDTH_G          => 4,
         FIFO_PAUSE_THRESH_G        => 1,
         MASTER_AXI_STREAM_CONFIG_G => AXIS_CONFIG_C,
         MASTER_AXI_PIPE_STAGES_G   => 0)
      port map (
         mAxisClk     => axisClk,
         mAxisRst     => axisRst,
         mAxisSlave   => mAxisSlave,
         mAxisMaster  => mAxisMaster,
         locClk       => axisClk,
         locRst       => axisRst,
         trig         => trig,
         packetLength => packetLength,
         busy         => busy,
         tDest        => tDest,
         tId          => tId);

end architecture rtl;
