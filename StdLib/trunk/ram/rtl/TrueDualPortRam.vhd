-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : TrueDualPortRam.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-07-11
-- Last update: 2015-09-11
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: This will infer this module as Block RAM only
--
-- NOTE: TDP ram with read enable logic is not supported.
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
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;

entity TrueDualPortRam is
   -- MODE_G = {"no-change","read-first","write-first"}
   generic (
      TPD_G          : time                       := 1 ns;
      RST_POLARITY_G : sl                         := '1';  -- '1' for active high rst, '0' for active low
      ALTERA_RAM_G   : string                     := "M9K";
      MODE_G         : string                     := "write-first";
      DATA_WIDTH_G   : integer range 1 to (2**24) := 18;
      ADDR_WIDTH_G   : integer range 1 to (2**24) := 4;
      INIT_G         : slv                        := "0");
   port (
      -- Port A     
      clka  : in  sl                           := '0';
      ena   : in  sl                           := '1';
      wea   : in  sl                           := '0';
      rsta  : in  sl                           := not(RST_POLARITY_G);
      addra : in  slv(ADDR_WIDTH_G-1 downto 0) := (others => '0');
      dina  : in  slv(DATA_WIDTH_G-1 downto 0) := (others => '0');
      douta : out slv(DATA_WIDTH_G-1 downto 0);
      -- Port B
      clkb  : in  sl                           := '0';
      enb   : in  sl                           := '1';
      web   : in  sl                           := '0';
      rstb  : in  sl                           := not(RST_POLARITY_G);
      addrb : in  slv(ADDR_WIDTH_G-1 downto 0) := (others => '0');
      dinb  : in  slv(DATA_WIDTH_G-1 downto 0) := (others => '0');
      doutb : out slv(DATA_WIDTH_G-1 downto 0));
end TrueDualPortRam;

architecture rtl of TrueDualPortRam is

   constant INIT_C : slv(DATA_WIDTH_G-1 downto 0) := ite(INIT_G = "0", slvZero(DATA_WIDTH_G), INIT_G);

   -- Shared memory 
   type mem_type is array ((2**ADDR_WIDTH_G)-1 downto 0) of slv(DATA_WIDTH_G-1 downto 0);
   signal mem : mem_type := (others => INIT_C);

   -- Attribute for XST (Xilinx Synthesizer)
   attribute ram_style        : string;
   attribute ram_style of mem : signal is "block";

   attribute ram_extract        : string;
   attribute ram_extract of mem : signal is "TRUE";

   attribute keep        : boolean;         --"keep" is same for XST and Altera
   attribute keep of mem : signal is true;  --"keep" is same for XST and Altera

   -- Attribute for Synplicity Synthesizer 
   attribute syn_ramstyle        : string;
   attribute syn_ramstyle of mem : signal is "block";

   attribute syn_keep        : string;
   attribute syn_keep of mem : signal is "TRUE";

   -- Attribute for Altera Synthesizer
   attribute ramstyle        : string;
   attribute ramstyle of mem : signal is ALTERA_RAM_G;
   
begin

   -- MODE_G check
   assert (MODE_G = "no-change") or (MODE_G = "read-first") or (MODE_G = "write-first")
      report "MODE_G must be either no-change, read-first, or write-first"
      severity failure;
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
   
   NO_CHANGE_MODE : if MODE_G = "no-change" generate
      -- Port A
      process(clka)
      begin
         if rising_edge(clka) then
            if rsta = RST_POLARITY_G then
               douta <= INIT_C after TPD_G;
            else
               if (wea = '1') and (ena = '1') then
                  mem(conv_integer(addra)) <= dina after TPD_G;
               else
                  douta <= mem(conv_integer(addra)) after TPD_G;
               end if;
            end if;
         end if;
      end process;

      -- Port B
      process(clkb)
      begin
         if rising_edge(clkb) then
            if rstb = RST_POLARITY_G then
               doutb <= INIT_C after TPD_G;
            else
               if (web = '1') and (enb = '1') then
                  mem(conv_integer(addrb)) <= dinb after TPD_G;
               else
                  doutb <= mem(conv_integer(addrb)) after TPD_G;
               end if;
            end if;
         end if;
      end process;
      
   end generate;

   READ_FIRST_MODE : if MODE_G = "read-first" generate
      -- Port A
      process(clka)
      begin
         if rising_edge(clka) then
            if rsta = RST_POLARITY_G then
               douta <= INIT_C after TPD_G;
            else
               douta <= mem(conv_integer(addra)) after TPD_G;
               if (wea = '1') and (ena = '1') then
                  mem(conv_integer(addra)) <= dina after TPD_G;
               end if;
            end if;
         end if;
      end process;

      -- Port B
      process(clkb)
      begin
         if rising_edge(clkb) then
            if rstb = RST_POLARITY_G then
               doutb <= INIT_C after TPD_G;
            else
               doutb <= mem(conv_integer(addrb)) after TPD_G;
               if (web = '1') and (enb = '1') then
                  mem(conv_integer(addrb)) <= dinb after TPD_G;
               end if;
            end if;
         end if;
      end process;
      
   end generate;

   WRITE_FIRST_MODE : if MODE_G = "write-first" generate
      -- Port A
      process(clka)
      begin
         if rising_edge(clka) then
            if rsta = RST_POLARITY_G then
               douta <= INIT_C after TPD_G;
            else
               if (wea = '1') and (ena = '1') then
                  mem(conv_integer(addra)) <= dina after TPD_G;
                  douta                    <= dina after TPD_G;
               end if;
               douta <= mem(conv_integer(addra)) after TPD_G;
            end if;
         end if;
      end process;

      -- Port B
      process(clkb)
      begin
         if rising_edge(clkb) then
            if rstb = RST_POLARITY_G then
               doutb <= INIT_C after TPD_G;
            else
               if (web = '1') and (enb = '1') then
                  mem(conv_integer(addrb)) <= dinb after TPD_G;
                  doutb                    <= dinb after TPD_G;
               end if;
               doutb <= mem(conv_integer(addrb)) after TPD_G;
            end if;
         end if;
      end process;
      
   end generate;
   
end rtl;
