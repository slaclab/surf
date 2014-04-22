
LIBRARY ieee;
USE work.ALL;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity Vc64SimLinkOb is port (
      obClk            : in    std_logic;
      obReset          : in    std_logic;
      obDataValid      : out   std_logic;
      obDataSize       : out   std_logic;
      obDataVc         : out   std_logic_vector(3 downto 0);
      obDataSof        : out   std_logic;
      obDataEof        : out   std_logic;
      obDataEofe       : out   std_logic;
      obDataDataHigh   : out   std_logic_vector(31 downto 0);
      obDataDataLow    : out   std_logic_vector(31 downto 0);
      obReady          : in    std_logic_vector(15 downto 0);
      littleEndian     : in    std_logic;
      vcWidth          : in    std_logic_vector(6  downto 0)
   );
end Vc64SimLinkOb;

-- Define architecture
architecture Vc64SimLinkOb of Vc64SimLinkOb is
   Attribute FOREIGN of Vc64SimLinkOb: architecture is 
      "vhpi:SimSw_lib:VhpiGenericElab:Vc64SimLinkObInit:Vc64SimLinkOb";
begin
end Vc64SimLinkOb;

