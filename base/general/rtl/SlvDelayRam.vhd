-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : UserRealign.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-07-10
-- Last update: 2019-11-18
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- This module produces a realigned timing header and expt bus.
-------------------------------------------------------------------------------
-- This file is part of 'LCLS2 DAQ Software'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'LCLS2 DAQ Software', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

-- surf

library surf;
use surf.StdRtlPkg.all;

library unisim;
use unisim.vcomponents.all;

entity SlvDelayRam is
   generic (
      TPD_G            : time    := 1 ns;
      VECTOR_WIDTH_G   : integer := 1;
      BASE_DELAY_G     : integer := 100;
      RAM_ADDR_WIDTH_G : integer := 7;
      MEMORY_TYPE_G    : string := "block");
   port (
      rst          : in  sl;
      clk          : in  sl;
      delay        : in  slv(RAM_ADDR_WIDTH_G-1 downto 0) := (others => '0');
      inputValid   : in  sl;
      inputVector  : in  slv(VECTOR_WIDTH_G-1 downto 0);
      inputAddr    : in  slv(RAM_ADDR_WIDTH_G-1 downto 0);
      outputValid  : out sl;
      outputVector : out slv(VECTOR_WIDTH_G-1 downto 0));
end SlvDelayRam;

architecture rtl of SlvDelayRam is

   type RegType is record
      rden        : sl;
      rdaddr      : slv(6 downto 0);
      outputValid : slv(3 downto 0);
   end record;

   constant REG_INIT_C : RegType := (
      rden        => '0',
      rdaddr      => (others => '0'),
      outputValid => (others => '0'));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   U_Ram : entity surf.SimpleDualPortRam
      generic map (
         MEMORY_TYPE_G => MEMORY_TYPE_G,
         DATA_WIDTH_G  => VECTOR_WIDTH_G,
         ADDR_WIDTH_G  => RAM_ADDR_WIDTH_G)
      port map (
         clka  => clk,
         ena   => '1',
         wea   => inputValid,
         addra => inputAddr,
         dina  => inputVector,
         clkb  => clk,
         rstb  => rst,
         enb   => r.rden,
         addrb => r.rdaddr,
         doutb => outputVector);

   comb : process(delay, inputAddr, inputValid, r, rst) is
      variable v : RegType;
   begin
      v := r;

      v.rden := '0';

      v.outputValid := '0' & r.outputValid(3 downto 1);

      if inputValid = '1' then
         v.outputValid(3) := '1';
         v.rden           := '1';
         v.rdaddr         := inputAddr - BASE_DELAY_G + delay;
      end if;

      if rst = '1' then
         v := REG_INIT_C;
      end if;

      -- Delay output valid by 4 cycles to allow for worst case ram read latency
      outputValid <= r.outputValid(0);

      rin <= v;
   end process;

   seq : process (clk) is
   begin
      if rising_edge(clk) then
         r <= rin after TPD_G;
      end if;
   end process;

end rtl;
