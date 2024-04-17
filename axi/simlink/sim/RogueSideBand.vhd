-------------------------------------------------------------------------------
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
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity RogueSideBand is port (
      clock        : in    std_logic;
      reset        : in    std_logic;
      portNum      : in    std_logic_vector(15 downto 0);

      txOpCode   : in  std_logic_vector(7 downto 0);
      txOpCodeEn : in  std_logic;
      txRemData  : in  std_logic_vector(7 downto 0);
      rxOpCode   : out std_logic_vector(7 downto 0);
      rxOpCodeEn : out std_logic;
      rxRemData  : out std_logic_vector(7 downto 0)
   );
end RogueSideBand;

-- Define architecture
architecture RogueSideBand of RogueSideBand is
   Attribute FOREIGN of RogueSideBand: architecture is
      "vhpi:AxiSim:VhpiGenericElab:RogueSideBandInit:RogueSideBand";
begin
end RogueSideBand;

