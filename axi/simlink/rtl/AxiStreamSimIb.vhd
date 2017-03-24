-------------------------------------------------------------------------------
-- File       : AxiStreamSimIb.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-04-18
-- Last update: 2014-04-18
-------------------------------------------------------------------------------
-- Description: AXI Stream Inbound Simulation Module
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

entity AxiStreamSimIb is port (
      ibClk        : in    std_logic;
      ibReset      : in    std_logic;
      ibValid      : in    std_logic;
      ibDest       : in    std_logic_vector(3 downto 0);
      ibEof        : in    std_logic;
      ibEofe       : in    std_logic;
      ibData       : in    std_logic_vector(31 downto 0);
      streamId     : in    std_logic_vector(7  downto 0)
   );
end AxiStreamSimIb;

-- Define architecture
architecture AxiStreamSimIb of AxiStreamSimIb is
   Attribute FOREIGN of AxiStreamSimIb: architecture is 
      "vhpi:AxiSim:VhpiGenericElab:AxiStreamSimIbInit:AxiStreamSimIb";
begin
end AxiStreamSimIb;

