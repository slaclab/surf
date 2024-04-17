-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Rogue Stream Module
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

entity RogueTcpMemory is port (
      clock        : in    std_logic;
      reset        : in    std_logic;
      portNum      : in    std_logic_vector(15 downto 0);

      -- axiReadMaster
      araddr       : out   std_logic_vector(31 downto 0);
      arprot       : out   std_logic_vector(2 downto 0);
      arvalid      : out   std_logic;
      rready       : out   std_logic;

      -- axiReadSlave
      arready      : in    std_logic;
      rdata        : in    std_logic_vector(31 downto 0);
      rresp        : in    std_logic_vector(1 downto 0);
      rvalid       : in    std_logic;

      -- axiWriteMaster
      awaddr       : out   std_logic_vector(31 downto 0);
      awprot       : out   std_logic_vector(2 downto 0);
      awvalid      : out   std_logic;
      wdata        : out   std_logic_vector(31 downto 0);
      wstrb        : out   std_logic_vector(3 downto 0);
      wvalid       : out   std_logic;
      bready       : out   std_logic;

      -- axiWriteSlave
      awready      : in    std_logic;
      wready       : in    std_logic;
      bresp        : in    std_logic_vector(1 downto 0);
      bvalid       : in    std_logic
   );
end RogueTcpMemory;

-- Define architecture
architecture RogueTcpMemory of RogueTcpMemory is
   Attribute FOREIGN of RogueTcpMemory: architecture is
      "vhpi:AxiSim:VhpiGenericElab:RogueTcpMemoryInit:RogueTcpMemory";
begin
end RogueTcpMemory;

