-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Runtime-configurable delay line for std_logic_vector data.
--
--              SlvDelayRam stores each accepted din sample in an inferred
--              single-port RAM and reads back the sample located at the
--              current circular address.  The RAM is used in read-before-write
--              mode, so the visible output is the sample captured on an
--              earlier visit to the same address.  The address counter wraps
--              when it reaches the registered maxCount value, which sets the
--              requested delay depth.  The en input freezes the address
--              counter, maxCount register, RAM write, and output update.
--
--              DO_REG_G adds an output register after the RAM read data.
--              With the current implementation, the observable delay is:
--
--                 delay = maxCount + ite(DO_REG_G, 3, 2)
--
--              maxCount is sampled while en is asserted and is intended to be
--              programmed during initialization or while the module is held in
--              reset.  If maxCount is changed while traffic is flowing, the
--              circular address phase is not automatically realigned.  The
--              transition samples are therefore undefined, and shrinking
--              maxCount below the current address can violate the internal
--              counter range in simulation.  Software or firmware that changes
--              maxCount at runtime must assert rst afterward and should discard
--              any pre-reset output history before relying on dout again.  In
--              practice, allow at least one newly configured delay interval
--              after reset release before treating dout as aligned to the new
--              maxCount setting.
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
use ieee.numeric_std.all;

library surf;
use surf.StdRtlPkg.all;

entity SlvDelayRam is
   generic (
      TPD_G          : time                       := 1 ns;
      RST_POLARITY_G : sl                         := '1';  -- '1' for active high rst, '0' for active low
      MEMORY_TYPE_G  : string                     := "block";
      DO_REG_G       : boolean                    := true;
      DELAY_G        : integer range 3 to (2**24) := 3;  --max number of clock cycle delays. MAX delay stages when using
      WIDTH_G        : positive                   := 1);
   port (
      clk      : in  sl;
      rst      : in  sl                                                    := not(RST_POLARITY_G);
      en       : in  sl                                                    := '1';  -- Optional clock enable
      maxCount : in  slv(log2(DELAY_G - ite(DO_REG_G, 2, 1)) - 1 downto 0) := toSlv(DELAY_G - ite(DO_REG_G, 3, 2), log2(DELAY_G - ite(DO_REG_G, 2, 1)));  -- Optional runtime configurable
      din      : in  slv(WIDTH_G - 1 downto 0);
      dout     : out slv(WIDTH_G - 1 downto 0));
end entity SlvDelayRam;

architecture rtl of SlvDelayRam is

   constant XST_BRAM_STYLE_C : string := MEMORY_TYPE_G;

   constant INIT_C : slv(WIDTH_G-1 downto 0) := slvZero(WIDTH_G);

   type MemType is array (DELAY_G - 1 - ite(DO_REG_G, 2, 1) downto 0) of slv(WIDTH_G - 1 downto 0);
   signal mem : MemType := (others => (others => '0'));

   type RegType is record
      addr     : integer range 0 to DELAY_G - ite(DO_REG_G, 2, 1);
      maxCount : integer range 0 to DELAY_G - ite(DO_REG_G, 2, 1);
      doutReg  : slv(WIDTH_G - 1 downto 0);
   end record RegType;

   constant REG_INIT_C : RegType := (
      addr     => 0,
      maxCount => 0,
      doutReg  => INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal doutInt : slv(WIDTH_G - 1 downto 0);

   -- Attribute for XST (Xilinx Synthesis)
   attribute ram_style        : string;
   attribute ram_style of mem : signal is XST_BRAM_STYLE_C;

   attribute ram_extract        : string;
   attribute ram_extract of mem : signal is "TRUE";

   -- Attribute for Synplicity Synthesizer
   attribute syn_ramstyle        : string;
   attribute syn_ramstyle of mem : signal is XST_BRAM_STYLE_C;

   attribute syn_keep        : string;
   attribute syn_keep of mem : signal is "TRUE";

begin

   comb : process (doutInt, en, maxCount, r, rst) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      if rst = RST_POLARITY_G then
         v := REG_INIT_C;

      elsif en = '1' then
         v.maxCount := to_integer(unsigned(maxCount));
         v.doutReg  := doutInt;
         if r.addr = r.maxCount then
            v.addr := 0;
         else
            v.addr := r.addr + 1;
         end if;

      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      if DO_REG_G then
         dout <= r.doutReg;
      else
         dout <= doutInt;
      end if;

   end process comb;

   seq : process (clk) is
   begin
      if rising_edge(clk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   -- read before write single port RAM
   MEM_PROC : process(clk)
   begin
      if rising_edge(clk) then
         if en = '1' then
            mem(r.addr) <= din after TPD_G;
            if rst = RST_POLARITY_G then
               doutInt <= INIT_C after TPD_G;
            else
               doutInt <= mem(r.addr) after TPD_G;
            end if;
         end if;
      end if;
   end process;

end rtl;
