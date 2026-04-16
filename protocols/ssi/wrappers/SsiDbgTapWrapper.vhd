-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing wrapper for SsiDbgTap traffic smoke testing
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

entity SsiDbgTapWrapper is
   generic (
      DATA_BYTES_G : positive := 2);
   port (
      axisClk     : in sl;
      axisRst     : in sl;
      axisTValid  : in sl;
      axisTData   : in slv(63 downto 0);
      axisTKeep   : in slv(7 downto 0);
      axisTLast   : in sl;
      axisTDest   : in slv(3 downto 0);
      axisSof     : in sl;
      axisEofe    : in sl;
      axisTReady  : in sl);
end entity SsiDbgTapWrapper;

architecture rtl of SsiDbgTapWrapper is

   constant AXIS_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(
      dataBytes => DATA_BYTES_G,
      tKeepMode => TKEEP_NORMAL_C,
      tUserMode => TUSER_FIRST_LAST_C,
      tDestBits => 4,
      tUserBits => 2);
   constant DATA_WIDTH_C  : positive := 8*DATA_BYTES_G;

   signal axisMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal axisSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;

begin

   axisComb : process (axisEofe, axisSof, axisTData, axisTDest, axisTKeep, axisTLast, axisTValid) is
      variable v : AxiStreamMasterType;
   begin
      v := AXI_STREAM_MASTER_INIT_C;
      v.tValid := axisTValid;
      v.tData(DATA_WIDTH_C-1 downto 0) := axisTData(DATA_WIDTH_C-1 downto 0);
      v.tKeep(DATA_BYTES_G-1 downto 0) := axisTKeep(DATA_BYTES_G-1 downto 0);
      v.tLast := axisTLast;
      v.tDest(3 downto 0) := axisTDest;
      ssiSetUserSof(AXIS_CONFIG_C, v, axisSof);
      ssiSetUserEofe(AXIS_CONFIG_C, v, axisEofe);
      axisMaster <= v;
   end process axisComb;

   axisSlave.tReady <= axisTReady;

   U_DUT : entity surf.SsiDbgTap
      generic map (
         TPD_G        => 1 ns,
         CNT_WIDTH_G  => 16,
         AXI_CONFIG_G => AXIS_CONFIG_C)
      port map (
         axisClk    => axisClk,
         axisRst    => axisRst,
         axisMaster => axisMaster,
         axisSlave  => axisSlave);

end architecture rtl;
