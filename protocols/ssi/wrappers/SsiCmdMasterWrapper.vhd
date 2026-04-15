-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing wrapper for SsiCmdMaster
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
use surf.SsiCmdMasterPkg.all;

entity SsiCmdMasterWrapper is
   port (
      axisClk     : in  sl;
      axisRst     : in  sl;
      sAxisTValid : in  sl;
      sAxisTData  : in  slv(63 downto 0);
      sAxisTKeep  : in  slv(7 downto 0);
      sAxisTLast  : in  sl;
      sAxisSof    : in  sl;
      sAxisEofe   : in  sl;
      sAxisTReady : out sl;
      cmdValid    : out sl;
      cmdOpCode   : out slv(7 downto 0);
      cmdCtx      : out slv(23 downto 0));
end entity SsiCmdMasterWrapper;

architecture rtl of SsiCmdMasterWrapper is

   constant AXIS_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(
      dataBytes => 4,
      tKeepMode => TKEEP_NORMAL_C,
      tUserMode => TUSER_FIRST_LAST_C,
      tUserBits => 2);

   signal sAxisMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal sAxisSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;
   signal cmdMaster   : SsiCmdMasterType    := SSI_CMD_MASTER_INIT_C;

begin

   sAxisComb : process (sAxisEofe, sAxisSof, sAxisTData, sAxisTKeep, sAxisTLast, sAxisTValid) is
      variable v : AxiStreamMasterType;
   begin
      v := AXI_STREAM_MASTER_INIT_C;
      v.tValid := sAxisTValid;
      v.tData(31 downto 0) := sAxisTData(31 downto 0);
      v.tKeep(3 downto 0) := sAxisTKeep(3 downto 0);
      v.tLast := sAxisTLast;
      ssiSetUserSof(AXIS_CONFIG_C, v, sAxisSof);
      ssiSetUserEofe(AXIS_CONFIG_C, v, sAxisEofe);
      sAxisMaster <= v;
   end process sAxisComb;

   sAxisTReady <= sAxisSlave.tReady;
   cmdValid <= cmdMaster.valid;
   cmdOpCode <= cmdMaster.opCode;
   cmdCtx <= cmdMaster.ctx;

   U_DUT : entity surf.SsiCmdMaster
      generic map (
         TPD_G               => 1 ns,
         SLAVE_READY_EN_G    => true,
         MEMORY_TYPE_G       => "distributed",
         GEN_SYNC_FIFO_G     => true,
         FIFO_ADDR_WIDTH_G   => 4,
         FIFO_PAUSE_THRESH_G => 1,
         AXI_STREAM_CONFIG_G => AXIS_CONFIG_C)
      port map (
         axisClk     => axisClk,
         axisRst     => axisRst,
         sAxisMaster => sAxisMaster,
         sAxisSlave  => sAxisSlave,
         sAxisCtrl   => open,
         cmdClk      => axisClk,
         cmdRst      => axisRst,
         cmdMaster   => cmdMaster);

end architecture rtl;
