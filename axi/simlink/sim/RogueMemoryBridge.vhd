-------------------------------------------------------------------------------
-- File       : RogueMemoryBridge.vhd
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Rogue Stream Bridge Module
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Firmware Standard Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'SLAC Firmware Standard Library', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

LIBRARY ieee;
USE work.ALL;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity RogueMemoryBridge is port (
      clock        : in    std_logic;
      reset        : in    std_logic;
      portNum      : in    std_logic_vector(15 downto 0);

      -- axiReadMaster
      araddr       : out   std_logic_vector(31 downto 0);
      arprot       : out   std_logic_vector(2 downto 0);
      arvalid      : out   std_logic;
      rready       : out   std_logic;

      -- axiReadSlave
      arready      : out   std_logic;
      rdata        : out   std_logic_vector(31 downto 0);
      rresp        : out   std_logic_vector(1 downto 0);
      rvalid       : out   std_logic;

      -- axiWriteMaster
      awaddr       : std_logic_vector(31 downto 0);
      awprot       : std_logic_vector(2 downto 0);
      awvalid      : std_logic;
      wdata        : std_logic_vector(31 downto 0);
      wstrb        : std_logic_vector(3 downto 0);
      wvalid       : std_logic;
      bready       : std_logic;

      -- axiWriteSlave
      awready      : std_logic;
      wready       : std_logic;
      bresp        : std_logic_vector(1 downto 0);
      bvalid       : std_logic
   );
end RogueMemoryBridge;

-- Define architecture
architecture RogueMemoryBridge of RogueMemoryBridge is
   Attribute FOREIGN of RogueMemoryBridge: architecture is 
      "vhpi:AxiSim:VhpiGenericElab:RogueMemoryBridgeInit:RogueMemoryBridge";
begin
end RogueMemoryBridge;

