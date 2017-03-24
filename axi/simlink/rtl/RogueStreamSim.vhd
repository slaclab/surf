-------------------------------------------------------------------------------
-- File       : RogueStreamSim.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-12-05
-- Last update: 2017-02-02
-------------------------------------------------------------------------------
-- Description: Rogue Stream Simulation Module
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

entity RogueStreamSim is port (
      clock        : in    std_logic;
      reset        : in    std_logic;
      dest         : in    std_logic_vector(7  downto 0);
      uid          : in    std_logic_vector(5  downto 0);

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
      ibLast       : in    std_logic;

      opCode       : out   std_logic_vector(7 downto 0);
      opCodeEn     : out   std_logic;
      remData      : out   std_logic_vector(7 downto 0)
   );
end RogueStreamSim;

-- Define architecture
architecture RogueStreamSim of RogueStreamSim is
   Attribute FOREIGN of RogueStreamSim: architecture is 
      "vhpi:AxiSim:VhpiGenericElab:RogueStreamSimInit:RogueStreamSim";
begin
end RogueStreamSim;

