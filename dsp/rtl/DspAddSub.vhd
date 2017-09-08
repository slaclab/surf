-------------------------------------------------------------------------------
-- File       : DspAddSub.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-07-12
-- Last update: 2013-07-12
-------------------------------------------------------------------------------
-- Description: Example of VHDL inferred DSP resources for Adder/Subtracter
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
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;

entity DspAddSub is
   generic (
      TPD_G     : time                  := 1 ns;
      LATENCY_G : integer range 0 to 2  := 0;
      -- Port A parameters
      A_WIDTH_G : integer range 2 to 48 := 2;
      A_TYPE_G  : string                := "unsigned";
      -- Port B parameters
      B_WIDTH_G : integer range 2 to 48 := 2;
      B_TYPE_G  : string                := "unsigned";
      -- Port S parameters
      S_WIDTH_G : integer range 2 to 48 := 2;
      S_TYPE_G  : string                := "unsigned");
   port (
      clk : in  sl;
      add : in  sl                          := '1';
      a   : in  slv((A_WIDTH_G-1) downto 0) := (others => '0');
      b   : in  slv((B_WIDTH_G-1) downto 0) := (others => '0');
      s   : out slv((S_WIDTH_G-1) downto 0));
end DspAddSub;

architecture rtl of DspAddSub is

   -- Constants
   constant A_FORMAT_C : sl := ite((A_TYPE_G = "signed"), '1', '0');
   constant B_FORMAT_C : sl := ite((B_TYPE_G = "signed"), '1', '0');
   constant S_FORMAT_C : sl := ite((S_TYPE_G = "signed"), '1', '0');

   -- Types
   type OutputArray is array(0 to LATENCY_G) of slv((S_WIDTH_G-1) downto 0);

   -- Signals
   signal aIn  : slv((A_WIDTH_G-1) downto 0) := (others => '0');
   signal bIn  : slv((B_WIDTH_G-1) downto 0) := (others => '0');
   signal sOut : slv((S_WIDTH_G-1) downto 0) := (others => '0');
   signal qOut : OutputArray                 := (others => (others => '0'));

   -- Attribute for XST
   attribute use_dsp48         : string;
   attribute use_dsp48 of sOut : signal is "yes";
   
begin

   -- A_TYPE_G check
   assert ((A_TYPE_G = "unsigned") or (A_TYPE_G = "signed"))
      report "A_TYPE_G must be either unsigned or signed"
      severity failure;
   -- B_TYPE_G check
   assert ((B_TYPE_G = "unsigned") or (B_TYPE_G = "signed"))
      report "B_TYPE_G must be either unsigned or signed"
      severity failure;
   -- S_TYPE_G check
   assert ((S_TYPE_G = "unsigned") or (S_TYPE_G = "signed"))
      report "S_TYPE_G must be either unsigned or signed"
      severity failure;
   -- S_WIDTH_G range check
   assert ((S_WIDTH_G = A_WIDTH_G) or (S_WIDTH_G = (A_WIDTH_G+1)) or (S_WIDTH_G = B_WIDTH_G) or (S_WIDTH_G = (B_WIDTH_G+1)))
      report "S_WIDTH_G must be A_WIDTH_G, A_WIDTH_G+1, B_WIDTH_G, or B_WIDTH_G+1"
      severity failure;
      
   --force the input A to be unsigned 
   aIn(A_WIDTH_G-1) <= a(A_WIDTH_G-1) xor A_FORMAT_C;
   Input_A_Mapping_Gen :
   for i in 0 to (A_WIDTH_G-2) generate
      aIn(i) <= a(i);
   end generate Input_A_Mapping_Gen;

   --force the input B to be unsigned 
   bIn(B_WIDTH_G-1) <= b(B_WIDTH_G-1) xor B_FORMAT_C;
   Input_B_Mapping_Gen :
   for i in 0 to (B_WIDTH_G-2) generate
      bIn(i) <= b(i);
   end generate Input_B_Mapping_Gen;

   -- zero latency DSP48 process 
   process(aIn, add, bIn)
   begin
      -- S = A + B
      if add = '1' then
         sOut <= aIn + bIn;
         -- S = A - B
      else
         sOut <= aIn - bIn;
      end if;
   end process;

   --convert output S to desired unsigned or signed format
   qOut(0)(S_WIDTH_G-1) <= sOut(S_WIDTH_G-1) xor S_FORMAT_C;
   Output_S_Mapping_Gen :
   for i in 0 to (A_WIDTH_G-2) generate
      qOut(0)(i) <= sOut(i);
   end generate Output_S_Mapping_Gen;

   --check if we need to generate registers
   Latency_Gen : if LATENCY_G /= 0 generate
      process(clk)
         variable i : integer;
      begin
         if rising_edge(clk) then
            for i in 0 to (LATENCY_G-1) loop
               qOut(i+1) <= qOut(i) after TPD_G;
            end loop;
         end if;
      end process;
   end generate Latency_Gen;

   --map the output S with respect to LATENCY_G
   s <= qOut(LATENCY_G);
   
end rtl;
