-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Initial lane alignment sequence Generator
--              Adds A na R characters at the LMFC borders.
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

library surf;
use surf.StdRtlPkg.all;
use surf.Jesd204bpkg.all;

entity JesdIlasGen is
   generic (
      TPD_G : time     := 1 ns;
      F_G   : positive := 2);
   port (
      clk : in sl;
      rst : in sl;

      -- Enable counter
      enable_i : in sl;

      -- Increase counter
      ilas_i : in sl;

      -- Increase counter
      lmfc_i : in sl;

      -- Outs
      ilasData_o : out slv(GT_WORD_SIZE_C*8-1 downto 0);
      ilasK_o    : out slv(GT_WORD_SIZE_C-1 downto 0));
end entity JesdIlasGen;

architecture rtl of JesdIlasGen is

   type RegType is record
      lmfcD1 : sl;
      lmfcD2 : sl;
   end record RegType;

   constant REG_INIT_C : RegType := (
      lmfcD1 => '0',
      lmfcD2 => '0');

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   comb : process (enable_i, ilas_i, lmfc_i, r, rst) is
      variable v         : RegType;
      variable vIlasData : slv(ilasData_o'range);
      variable vIlasK    : slv(ilasK_o'range);
   begin
      v := r;

      -- Delay LMFC for 2 c-c
      v.lmfcD1 := lmfc_i;
      v.lmfcD2 := r.lmfcD1;

      -- Combinatorial logic
      vIlasData := (others => '0');
      vIlasK    := (others => '0');

      if enable_i = '1' and ilas_i = '1' then
         -- Send A character
         if r.lmfcD1 = '1' then
            vIlasData(vIlasData'high downto vIlasData'high-7) := A_CHAR_C;
            vIlasK(vIlasK'high)                               := '1';
         end if;
         -- Send R character
         if r.lmfcD2 = '1' then
            vIlasData (7 downto 0) := R_CHAR_C;
            vIlasK(0)              := '1';
         end if;
      end if;

      if (rst = '1') then
         v := REG_INIT_C;
      end if;

      rin <= v;

      -- Output assignment
      ilasData_o <= vIlasData;
      ilasK_o    <= vIlasK;
   end process comb;

   seq : process (clk) is
   begin
      if (rising_edge(clk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end architecture rtl;
