-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Flat Memory leaf harness for simulator relaunch tests
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Firmware Standard Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the
-- top-level directory of this distribution and at:
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
-- No part of 'SLAC Firmware Standard Library', including this file,
-- may be copied, modified, propagated, or distributed except according to
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------
-- Test methodology:
-- - Present the production RogueTcpMemory leaf as a flat, simulator-neutral
--   AXI-Lite master with a runtime-driven port number.
-- - Put all stimulus and checking in the external cocotb relaunch scenario;
--   this harness adds no transaction or lifecycle behavior.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity RogueSimLinkMemoryRelaunchHarness is
   port (
      clock   : in  std_logic;
      reset   : in  std_logic;
      portNum : in  std_logic_vector(15 downto 0);
      araddr  : out std_logic_vector(31 downto 0);
      arvalid : out std_logic;
      arready : in  std_logic;
      rdata   : in  std_logic_vector(31 downto 0);
      rresp   : in  std_logic_vector(1 downto 0);
      rvalid  : in  std_logic;
      awaddr  : out std_logic_vector(31 downto 0);
      awvalid : out std_logic;
      wdata   : out std_logic_vector(31 downto 0);
      wvalid  : out std_logic;
      awready : in  std_logic;
      wready  : in  std_logic;
      bresp   : in  std_logic_vector(1 downto 0);
      bvalid  : in  std_logic;
      bready  : out std_logic);
end entity RogueSimLinkMemoryRelaunchHarness;

architecture harness of RogueSimLinkMemoryRelaunchHarness is

begin

   U_DUT : entity work.RogueTcpMemory
      port map (
         clock   => clock,             -- [in]
         reset   => reset,             -- [in]
         portNum => portNum,           -- [in]
         araddr  => araddr,            -- [out]
         arprot  => open,              -- [out]
         arvalid => arvalid,           -- [out]
         rready  => open,              -- [out]
         arready => arready,           -- [in]
         rdata   => rdata,             -- [in]
         rresp   => rresp,             -- [in]
         rvalid  => rvalid,            -- [in]
         awaddr  => awaddr,            -- [out]
         awprot  => open,              -- [out]
         awvalid => awvalid,           -- [out]
         wdata   => wdata,             -- [out]
         wstrb   => open,              -- [out]
         wvalid  => wvalid,            -- [out]
         bready  => bready,            -- [out]
         awready => awready,           -- [in]
         wready  => wready,            -- [in]
         bresp   => bresp,             -- [in]
         bvalid  => bvalid);           -- [in]

end architecture harness;
