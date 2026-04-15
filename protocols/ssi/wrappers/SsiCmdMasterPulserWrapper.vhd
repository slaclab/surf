-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing wrapper for SsiCmdMasterPulser
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
use surf.SsiCmdMasterPkg.all;

entity SsiCmdMasterPulserWrapper is
   generic (
      PULSE_WIDTH_G : positive := 3);
   port (
      locClk    : in  sl;
      locRst    : in  sl;
      cmdValid  : in  sl;
      cmdOpCode : in  slv(7 downto 0);
      cmdCtx    : in  slv(23 downto 0);
      opCode    : in  slv(7 downto 0);
      syncPulse : out sl);
end entity SsiCmdMasterPulserWrapper;

architecture rtl of SsiCmdMasterPulserWrapper is

   signal cmdMaster : SsiCmdMasterType := SSI_CMD_MASTER_INIT_C;

begin

   cmdMaster.valid  <= cmdValid;
   cmdMaster.opCode <= cmdOpCode;
   cmdMaster.ctx    <= cmdCtx;

   U_DUT : entity surf.SsiCmdMasterPulser
      generic map (
         TPD_G         => 1 ns,
         PULSE_WIDTH_G => PULSE_WIDTH_G)
      port map (
         cmdSlaveOut => cmdMaster,
         opCode      => opCode,
         syncPulse   => syncPulse,
         locClk      => locClk,
         locRst      => locRst);

end architecture rtl;
