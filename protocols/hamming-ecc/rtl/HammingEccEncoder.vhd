-------------------------------------------------------------------------------
-- Title      : Hamming-ECC: https://en.wikipedia.org/wiki/Hamming_code
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Hamming-ECC Encoder Module
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

library surf;
use surf.StdRtlPkg.all;
use surf.HammingEccPkg.all;

entity HammingEccEncoder is
   generic (
      TPD_G          : time     := 1 ns;
      RST_POLARITY_G : sl       := '1';
      RST_ASYNC_G    : boolean  := false;
      FLOW_CTRL_EN_G : boolean  := false;
      DATA_WIDTH_G   : positive := 8);
   port (
      -- Clock and Reset
      clk     : in  sl;
      clkEn   : in  sl := '1';          -- Optional Clock Enable
      rst     : in  sl := not RST_POLARITY_G;  -- Optional Reset
      -- Inbound Interface
      ibValid : in  sl := '1';
      ibReady : out sl;
      ibData  : in  slv(DATA_WIDTH_G-1 downto 0);
      -- Outbound Interface
      obValid : out sl;
      obReady : in  sl := '1';
      obData  : out slv(hammingEccDataWidth(DATA_WIDTH_G) downto 0));  -- +1 for the "extended parity bit"
end entity HammingEccEncoder;

architecture rtl of HammingEccEncoder is

   constant OB_DATA_WIDTH_C : positive := hammingEccDataWidth(DATA_WIDTH_G);

   type RegType is record
      ibReady : sl;
      obValid : sl;
      obData  : slv(OB_DATA_WIDTH_C downto 0);
   end record RegType;

   constant REG_INIT_C : RegType := (
      ibReady => '0',
      obValid => '0',
      obData  => (others => '0'));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   comb : process (ibData, ibValid, obReady, r, rst) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Flow control
      v.ibReady := obReady;
      if (obReady = '1' and FLOW_CTRL_EN_G) then
         v.obValid := '0';
      end if;

      -- Check if ready to move data
      if (v.obValid = '0') or (FLOW_CTRL_EN_G = false) then

         -- Set the flag
         v.obValid := ibValid;

         -- Set the output encoded data bus
         v.obData := hammingEccEncode(ibData);

      end if;

      -- Outputs
      ibReady <= v.ibReady;
      obValid <= r.obValid;
      obData  <= r.obData;

      -- Synchronous reset
      if (RST_ASYNC_G = false and rst = RST_POLARITY_G) then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

   end process comb;

   seq : process (clk, rst) is
   begin
      if (RST_ASYNC_G and rst = RST_POLARITY_G) then
         r <= REG_INIT_C after TPD_G;
      elsif (rising_edge(clk)) then
         if clkEn = '1' then
            r <= rin after TPD_G;
         end if;
      end if;
   end process seq;

end architecture rtl;
