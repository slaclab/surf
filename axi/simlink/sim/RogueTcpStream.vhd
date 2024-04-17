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

entity RogueTcpStream is port (
      clock        : in    std_logic;
      reset        : in    std_logic;
      portNum      : in    std_logic_vector(15 downto 0);
      ssi          : in    std_logic;

      obValid      : out   std_logic;
      obReady      : in    std_logic;
      obDataLow    : out   std_logic_vector(31 downto 0);
      obDataHigh   : out   std_logic_vector(31 downto 0);
      obUserLow    : out   std_logic_vector(31 downto 0);
      obUserHigh   : out   std_logic_vector(31 downto 0);
      obKeep       : out   std_logic_vector(7  downto 0);
      obLast       : out   std_logic;

      ibValid      : in    std_logic;
      ibReady      : out   std_logic;
      ibDataLow    : in    std_logic_vector(31 downto 0);
      ibDataHigh   : in    std_logic_vector(31 downto 0);
      ibUserLow    : in    std_logic_vector(31 downto 0);
      ibUserHigh   : in    std_logic_vector(31 downto 0);
      ibKeep       : in    std_logic_vector(7  downto 0);
      ibLast       : in    std_logic
   );
end RogueTcpStream;

-- Define architecture
architecture RogueTcpStream of RogueTcpStream is
   Attribute FOREIGN of RogueTcpStream: architecture is
      "vhpi:AxiSim:VhpiGenericElab:RogueTcpStreamInit:RogueTcpStream";
begin
end RogueTcpStream;

