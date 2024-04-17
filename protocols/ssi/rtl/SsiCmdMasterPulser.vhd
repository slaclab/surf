-------------------------------------------------------------------------------
-- Title      : SSI Protocol: https://confluence.slac.stanford.edu/x/0oyfD
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: SSI Command Master Pulser Module
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
use ieee.numeric_std.all;

library surf;
use surf.StdRtlPkg.all;
use surf.SsiCmdMasterPkg.all;

entity SsiCmdMasterPulser is
   generic (
      TPD_G          : time     := 1 ns;  -- Simulation FF output delay
      RST_ASYNC_G    : boolean  := false;
      OUT_POLARITY_G : sl       := '1';
      PULSE_WIDTH_G  : positive := 1);
   port (
      -- Local command signal
      cmdSlaveOut : in  SsiCmdMasterType;
      --addressed cmdOpCode
      opCode      : in  slv(7 downto 0);
      -- output pulse to sync module
      syncPulse   : out sl;
      -- Local clock and reset
      locClk      : in  sl;
      locRst      : in  sl);
end SsiCmdMasterPulser;

architecture rtl of SsiCmdMasterPulser is

   signal pulse : sl                                    := '0';
   signal cnt   : positive range 1 to (PULSE_WIDTH_G+1) := 1;

begin

   syncPulse <= pulse;

   process(locClk, locRst)
   begin
      if (RST_ASYNC_G and locRst = '1') then
         pulse <= not(OUT_POLARITY_G) after TPD_G;
         cnt   <= 1                   after TPD_G;
      elsif rising_edge(locClk) then
         if (RST_ASYNC_G = false and locRst = '1') then
            pulse <= not(OUT_POLARITY_G) after TPD_G;
            cnt   <= 1                   after TPD_G;
         else
            if pulse = OUT_POLARITY_G then
               cnt <= cnt + 1 after TPD_G;
               if cnt = PULSE_WIDTH_G then
                  pulse <= not(OUT_POLARITY_G) after TPD_G;
                  cnt   <= 1                   after TPD_G;
               end if;
            elsif cmdSlaveOut.valid = '1' then
               if cmdSlaveOut.opCode = opCode then
                  pulse <= OUT_POLARITY_G after TPD_G;
               end if;
            end if;
         end if;
      end if;
   end process;

end rtl;
