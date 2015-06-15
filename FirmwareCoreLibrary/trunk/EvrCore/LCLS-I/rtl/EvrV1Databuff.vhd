-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : EvrV1Databuff.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-02-17
-- Last update: 2015-06-11
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2015 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;

entity EvrV1Databuff is
   generic (
      TPD_G : time := 1 ns);
   port (
      -- Port A     
      clka  : in  sl;
      wea   : in  slv(0 downto 0);
      addra : in  slv(10 downto 0);
      dina  : in  slv(7 downto 0);
      -- Port B
      clkb  : in  sl;
      addrb : in  slv(8 downto 0);
      doutb : out slv(31 downto 0));   
end EvrV1Databuff;

architecture mapping of EvrV1Databuff is

   signal wrEn : slv(3 downto 0);

begin
   
   GEN_RAM :
   for i in 3 downto 0 generate
      
      SimpleDualPortRam_Inst : entity work.SimpleDualPortRam
         generic map (
            TPD_G        => TPD_G,
            DATA_WIDTH_G => 8,
            ADDR_WIDTH_G => 9)
         port map (
            -- Port A     
            clka  => clka,
            wea   => wrEn(i),
            addra => addra(10 downto 2),
            dina  => dina,
            -- Port B
            clkb  => clkb,
            addrb => addrb,
            doutb => doutb((8*i)+7 downto (8*i)));  

      wrEn(i) <= wea(0) when(addra(1 downto 0) = toSlv(i, 2)) else '0';
      
   end generate GEN_RAM;
   
end mapping;
