-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : SimpleDualPortRam.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-07-09
-- Last update: 2013-07-11
-- Platform   : ISE 14.5
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: XST will infer this module as either Block RAM or distributed RAM
-------------------------------------------------------------------------------
-- Copyright (c) 2013 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;

entity SimpleDualPortRam is
   generic (
      TPD_G        : time                       := 1 ns;
      BRAM_EN_G    : boolean                    := false;
      DATA_WIDTH_G : integer range 1 to (2**24) := 18;
      ADDR_WIDTH_G : integer range 1 to (2**24) := 4);
   port (
      -- Port A     
      clka  : in  sl                           := '0';
      ena   : in  sl                           := '1';
      wea   : in  sl                           := '0';
      addra : in  slv(ADDR_WIDTH_G-1 downto 0) := (others => '0');
      dina  : in  slv(DATA_WIDTH_G-1 downto 0) := (others => '0');
      -- Port B
      clkb  : in  sl                           := '0';
      enb   : in  sl                           := '1';
      addrb : in  slv(ADDR_WIDTH_G-1 downto 0) := (others => '0');
      doutb : out slv(DATA_WIDTH_G-1 downto 0));
end SimpleDualPortRam;

architecture rtl of SimpleDualPortRam is
   constant BRAM_STYLE_C : string := ite(BRAM_EN_G, "block", "distributed");

   -- Shared memory 
   type mem_type is array ((2**ADDR_WIDTH_G)-1 downto 0) of slv(DATA_WIDTH_G-1 downto 0);
   shared variable mem : mem_type := (others => (others => '0'));

   -- Attribute for XST
   attribute ram_style        : string;
   attribute ram_style of mem : variable is BRAM_STYLE_C;

   attribute ram_extract        : string;
   attribute ram_extract of mem : variable is "TRUE";

   attribute keep        : string;
   attribute keep of mem : variable is "TRUE";
   
begin
   -- Port A
   process(clka)
   begin
      if rising_edge(clka) then
         if ena = '1' then
            if wea = '1' then
               mem(conv_integer(addra)) := dina;
            end if;
         end if;
      end if;
   end process;

   -- Port B
   process(clkb)
   begin
      if rising_edge(clkb) then
         if enb = '1' then
            doutb <= mem(conv_integer(addrb)) after TPD_G;
         end if;
      end if;
   end process;
end rtl;
