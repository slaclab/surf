-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Wrapper for XPM Simple Dual Port RAM
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


library surf;
use surf.StdRtlPkg.all;

entity SimpleDualPortRamAlteraMf is
   generic (
      TPD_G          : time                       := 1 ns;
      COMMON_CLK_G   : boolean                    := false;
      RST_POLARITY_G : sl                         := '1';  -- '1' for active high rst, '0' for active low       
      MEMORY_TYPE_G  : string                     := "block";
      READ_LATENCY_G : natural range 0 to 100     := 1;
      DATA_WIDTH_G   : integer range 1 to (2**24) := 16;
      BYTE_WR_EN_G   : boolean                    := false;
      BYTE_WIDTH_G   : integer range 8 to 9       := 8;  -- If BRAM, should be multiple or 8 or 9
      ADDR_WIDTH_G   : integer range 1 to (2**24) := 4);
   port (
      -- Port A     
      clka   : in  sl                                                                          := '0';
      ena    : in  sl                                                                          := '1';
      wea    : in  slv(ite(BYTE_WR_EN_G, wordCount(DATA_WIDTH_G, BYTE_WIDTH_G), 1)-1 downto 0) := (others => '0');
      addra  : in  slv(ADDR_WIDTH_G-1 downto 0)                                                := (others => '0');
      dina   : in  slv(DATA_WIDTH_G-1 downto 0)                                                := (others => '0');
      -- Port B
      clkb   : in  sl                                                                          := '0';
      enb    : in  sl                                                                          := '1';
      regceb : in  sl                                                                          := '1';
      rstb   : in  sl                                                                          := not(RST_POLARITY_G);
      addrb  : in  slv(ADDR_WIDTH_G-1 downto 0)                                                := (others => '0');
      doutb  : out slv(DATA_WIDTH_G-1 downto 0)                                                := (others => '0'));
end SimpleDualPortRamAlteraMf;

architecture rtl of SimpleDualPortRamAlteraMf is

begin

end rtl;
