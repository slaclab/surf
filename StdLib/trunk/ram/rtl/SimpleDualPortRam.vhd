-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : SimpleDualPortRam.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-07-11
-- Last update: 2013-11-21
-- Platform   : ISE 14.5
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: This will infer this module as either Block RAM or distributed RAM
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

use work.StdRtlPkg.all;

entity SimpleDualPortRam is
   generic (
      TPD_G          : time                       := 1 ns;
      RST_POLARITY_G : sl                         := '1';  -- '1' for active high rst, '0' for active low      
      BRAM_EN_G      : boolean                    := true;
      ALTERA_SYN_G   : boolean                    := false;
      ALTERA_RAM_G   : string                     := "M9K";
      DATA_WIDTH_G   : integer range 1 to (2**24) := 16;
      ADDR_WIDTH_G   : integer range 1 to (2**24) := 4;
      INIT_G         : slv                        := "0");
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
      rstb  : in  sl                           := not(RST_POLARITY_G);
      addrb : in  slv(ADDR_WIDTH_G-1 downto 0) := (others => '0');
      doutb : out slv(DATA_WIDTH_G-1 downto 0));
end SimpleDualPortRam;

architecture rtl of SimpleDualPortRam is

   constant INIT_C : slv(DATA_WIDTH_G-1 downto 0) := ite(INIT_G = "0", slvZero(DATA_WIDTH_G), INIT_G);

   constant XST_BRAM_STYLE_C    : string := ite(BRAM_EN_G, "block", "distributed");
   constant ALTERA_BRAM_STYLE_C : string := ite(BRAM_EN_G, ALTERA_RAM_G, "MLAB");

   -- Shared memory 
   type mem_type is array ((2**ADDR_WIDTH_G)-1 downto 0) of slv(DATA_WIDTH_G-1 downto 0);
   shared variable mem : mem_type := (others => INIT_C);

   -- Attribute for XST (Xilinx Synthesis)
   attribute ram_style        : string;
   attribute ram_style of mem : variable is XST_BRAM_STYLE_C;

   attribute ram_extract        : string;
   attribute ram_extract of mem : variable is "TRUE";

   -- Attribute for Synplicity Synthesizer 
   attribute syn_ramstyle        : string;
   attribute syn_ramstyle of mem : variable is XST_BRAM_STYLE_C;

   attribute syn_keep        : string;
   attribute syn_keep of mem : variable is "TRUE";

   -- Attribute for Altera Synthesizer
   attribute ramstyle        : string;
   attribute ramstyle of mem : variable is ALTERA_BRAM_STYLE_C;
   
begin

   -- ALTERA_RAM_G check
   assert ((ALTERA_RAM_G = "M512")
           or (ALTERA_RAM_G = "M4K")
           or (ALTERA_RAM_G = "M9K")
           or (ALTERA_RAM_G = "M10K")
           or (ALTERA_RAM_G = "M20K")
           or (ALTERA_RAM_G = "M144K")
           or (ALTERA_RAM_G = "M-RAM"))
      report "Invalid ALTERA_RAM_G string"
      severity failure;
      
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

   
   XILINX_BUILD : if (ALTERA_SYN_G = false) generate   
      -- Port B
      process(clkb)
      begin
         if rising_edge(clkb) then
            if rstb = RST_POLARITY_G then
               doutb <= INIT_C after TPD_G;
            elsif enb = '1' then
               doutb <= mem(conv_integer(addrb)) after TPD_G;
            end if;
         end if;
      end process;
   end generate; 
   
   ---------------------------------------------------------------
   --NOTE: rstb and enb not supported in Altera when inferring RAM
   ---------------------------------------------------------------
   ALTERA_BUILD : if (ALTERA_SYN_G = true) generate
      -- Port B
      process(clkb)
      begin
         if rising_edge(clkb) then
            doutb <= mem(conv_integer(addrb)) after TPD_G;
         end if;
      end process;
   end generate;    
   
end rtl;
