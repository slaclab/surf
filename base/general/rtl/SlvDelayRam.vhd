-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Shift Register Delay module for std_logic_vector
--              Uses a counter and single port RAM (distributed, block, ultra)
--              Single port RAM setup in read first mode
--              Counter counts 0...maxCount
--              Optional data out register (DO_REG_G) on the RAM
--             
--              delay = maxCount + ite(DO_REG_G, 3, 2)
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
      TPD_G          : time      := 1 ns;
      MEMORY_TYPE_G  : string    := "block";
      DO_REG_G       : boolean   := true;
      DELAY_G        : integer range 3 to (2**24) := 512;  --max number of clock cycle delays. MAX delay stages when using
      WIDTH_G        : positive  := 16);
   port (
      clk      : in  sl;
      en       : in  sl      := '1';                 -- Optional clock enable
      maxCount : in  slv(log2(DELAY_G) - 1 downto 0) := toSlv(DELAY_G - ite(DO_REG_G, 3, 2), log2(DELAY_G)); -- Optional runtime configurable
      din      : in  slv(WIDTH_G - 1 downto 0);
      dout     : out slv(WIDTH_G - 1 downto 0));
end entity SlvDelayRam;


architecture rtl of SlvDelayRam is

   constant XST_BRAM_STYLE_C    : string := MEMORY_TYPE_G;

   type mem_type is array (DELAY_G - 1 - ite(DO_REG_G, 2, 1) downto 0) of slv(WIDTH_G - 1 downto 0);
   signal mem : mem_type := (others => (others => '0'));


   signal doutInt     : slv(WIDTH_G - 1 downto 0);
   signal maxCountInt : integer;
   signal addr        : integer; 

   -- Attribute for XST (Xilinx Synthesis)
   attribute ram_style        : string;
   attribute ram_style of mem : signal is XST_BRAM_STYLE_C;

   attribute ram_extract        : string;
   attribute ram_extract of mem : signal is "TRUE";

   -- Attribute for Synplicity Synthesizer
   attribute syn_ramstyle        : string;
   attribute syn_ramstyle of mem : signal is XST_BRAM_STYLE_C;

   attribute syn_keep            : string;
   attribute syn_keep of mem     : signal is "TRUE"; 

begin

      -- count limited counter
   ADDR_PROC : process(clk)
      variable cnt     : integer range 0 to DELAY_G;
   begin
      if rising_edge(clk) then
         maxCountInt <= to_integer(unsigned(maxCount)) after TPD_G;
         if en = '1' then 
            if cnt = maxCountInt then
               cnt := 0;
            else
               cnt := cnt + 1;
            end if;
          end if;
      end if;
      addr <= cnt after TPD_G;
   end process; 

   -- read before write single port RAM
   MEM_PROC : process(clk)
   begin
      if rising_edge(clk) then
         if en = '1' then
            mem(addr) <= din after TPD_G;
            doutInt   <= mem(addr) after TPD_G;
         end if;
      end if;
   end process;

   NO_REG : if (not DO_REG_G) generate
      dout <= doutInt(WIDTH_G-1 downto 0);
   end generate NO_REG;

   REG : if (DO_REG_G) generate
      process (clk)
      begin
         if (rising_edge(clk)) then
            dout <= doutInt(WIDTH_G-1 downto 0) after TPD_G;
         end if;
      end process;
   end generate REG;
   

end rtl;
