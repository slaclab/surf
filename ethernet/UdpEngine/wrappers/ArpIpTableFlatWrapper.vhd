-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing wrapper for ArpIpTable
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

entity ArpIpTableFlatWrapper is
   generic (
      TPD_G          : time                    := 1 ns;
      RST_POLARITY_G : sl                      := '1';
      RST_ASYNC_G    : boolean                 := false;
      CLK_FREQ_G     : real                    := 4.0;
      COMM_TIMEOUT_G : positive                := 2;
      ENTRIES_G      : positive range 1 to 255 := 4);
   port (
      clk                  : in  sl;
      rst                  : in  sl;
      ipAddrIn             : in  slv(31 downto 0);
      pos                  : in  slv(7 downto 0);
      found                : out sl;
      macAddr              : out slv(47 downto 0);
      ipAddrOut            : out slv(31 downto 0);
      clientRemoteDetIp    : in  slv(31 downto 0);
      clientRemoteDetValid : in  sl;
      ipWrEn               : in  sl;
      ipWrAddr             : in  slv(31 downto 0);
      macWrEn              : in  sl;
      macWrAddr            : in  slv(47 downto 0));
end entity ArpIpTableFlatWrapper;

architecture rtl of ArpIpTableFlatWrapper is

begin

   U_DUT : entity surf.ArpIpTable
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G,
         CLK_FREQ_G     => CLK_FREQ_G,
         COMM_TIMEOUT_G => COMM_TIMEOUT_G,
         ENTRIES_G      => ENTRIES_G)
      port map (
         clk                  => clk,
         rst                  => rst,
         ipAddrIn             => ipAddrIn,
         pos                  => pos,
         found                => found,
         macAddr              => macAddr,
         ipAddrOut            => ipAddrOut,
         clientRemoteDetIp    => clientRemoteDetIp,
         clientRemoteDetValid => clientRemoteDetValid,
         ipWrEn               => ipWrEn,
         ipWrAddr             => ipWrAddr,
         macWrEn              => macWrEn,
         macWrAddr            => macWrAddr);

end architecture rtl;
