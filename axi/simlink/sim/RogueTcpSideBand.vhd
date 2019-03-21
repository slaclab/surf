-------------------------------------------------------------------------------
-- File       : RogueTcpSideBand.vhd
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Rogue Side Band Simulation Module
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
use work.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity RogueTcpSideBand is port (
   clock      : in  std_logic;
   reset      : in  std_logic;
   portNum    : in  std_logic_vector(15 downto 0);
   -- Outboard Sideband
   obOpCode   : out std_logic_vector(7 downto 0);
   obOpCodeEn : out std_logic;
   obRemData  : out std_logic_vector(7 downto 0);
   -- Inbound Sideband
   ibOpCode   : in  std_logic_vector(7 downto 0);
   ibOpCodeEn : in  std_logic;
   ibRemData  : in  std_logic_vector(7 downto 0));
end RogueTcpSideBand;

-- Define architecture
architecture RogueTcpSideBand of RogueTcpSideBand is
   attribute FOREIGN of RogueTcpSideBand : architecture is
      "vhpi:AxiSim:VhpiGenericElab:RogueTcpSideBandInit:RogueTcpSideBand";
begin
end RogueTcpSideBand;

