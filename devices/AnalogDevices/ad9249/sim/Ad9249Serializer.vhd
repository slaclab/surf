-------------------------------------------------------------------------------
-- File       : Ad9249Serializer.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-02-22
-- Last update: 2016-11-30
-------------------------------------------------------------------------------
-- Description: 14 bit DDR deserializer using 7 series IDELAYE2 and ISERDESE2.
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
use work.StdRtlPkg.all;
library UNISIM;
use UNISIM.vcomponents.all;

entity Ad9249Serializer is
   
   port (
      clk    : in sl;                   -- Serial High speed clock
      clkDiv     : in sl;               -- Parallel low speed clock
      rst      : in sl;                 -- Reset

      iData : in  slv(13 downto 0);
      oData : out sl);

end entity Ad9249Serializer;

architecture rtl of Ad9249Serializer is

   signal shift1 : sl;
   signal shift2 : sl;
   
begin

    oserdese2_master : OSERDESE2
       generic map (
         DATA_RATE_OQ   => "DDR",
         DATA_RATE_TQ   => "SDR",
         DATA_WIDTH     => 14,
 
         TRISTATE_WIDTH => 1,
         SERDES_MODE    => "MASTER")
       port map (
         D1             => iData(13),
         D2             => iData(12),
         D3             => iData(11),
         D4             => iData(10),
         D5             => iData(9),
         D6             => iData(8),
         D7             => iData(7),
         D8             => iData(6),
         T1             => '0',
         T2             => '0',
         T3             => '0',
         T4             => '0',
         SHIFTIN1       => shift1,
         SHIFTIN2       => shift2,
         SHIFTOUT1      => open,
         SHIFTOUT2      => open,
         OCE            => '1',
         CLK            => clk,
         CLKDIV         => clkDiv,
         OQ             => oData,
         TQ             => open,
         OFB            => open,
         TBYTEIN        => '0',
         TBYTEOUT       => open,
         TFB            => open,
         TCE            => '0',
         RST            => rst);
    
    oserdese2_slave : OSERDESE2
       generic map (
         DATA_RATE_OQ   => "DDR",
         DATA_RATE_TQ   => "SDR",
         DATA_WIDTH     => 14,
         TRISTATE_WIDTH => 1,
         SERDES_MODE    => "SLAVE")
       port map (
         D1             => '0', 
         D2             => '0',
         D3             => iData(5),
         D4             => iData(4),
         D5             => iData(3),
         D6             => iData(2),
         D7             => iData(1),
         D8             => iData(0),
         T1             => '0',
         T2             => '0',
         T3             => '0',
         T4             => '0',
         SHIFTOUT1      => shift1,
         SHIFTOUT2      => shift2,
         SHIFTIN1       => '0',
         SHIFTIN2       => '0',
         OCE            => '1',
         CLK            => clk,
         CLKDIV         => clkDiv,
         OQ             => open,
         TQ             => open,
         OFB            => open,
         TFB            => open,
         TBYTEIN       => '0',
         TBYTEOUT      => open,
         TCE            => '0',
         RST            => rst);
    
end architecture rtl;
