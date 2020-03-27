-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:   Reset pipeline register stages
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

entity RstPipeline is
   generic (
      TPD_G         : time     := 1 ns;
      INV_RST_G     : boolean  := false;
      PIPE_STAGES_G : positive := 3;
      MAX_FANOUT_G  : positive := 16384;
      INIT_G        : slv      := "1");
   port (
      clk    : in  sl;
      rstIn  : in  sl;
      rstOut : out sl);
end RstPipeline;

architecture rtl of RstPipeline is

   constant INIT_C : slv(PIPE_STAGES_G-1 downto 0) := ite(INIT_G = "1", slvOne(PIPE_STAGES_G), INIT_G);

   type RegType is record
      shift : slv(PIPE_STAGES_G-1 downto 0);
   end record RegType;
   constant REG_INIT_C : RegType := (
      shift => INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   attribute shreg_extract      : string;
   attribute shreg_extract of r : signal is "NO";

   attribute max_fanout      : integer;
   attribute max_fanout of r : signal is MAX_FANOUT_G;

begin

   comb : process (r, rstIn) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Shift the LSB
      if (INV_RST_G = false) then
         v.shift(0) := rstIn;
      else
         v.shift(0) := not(rstIn);
      end if;

      -- Check for multi-stage delay
      if (PIPE_STAGES_G > 1) then
         -- Shift old data
         v.shift(PIPE_STAGES_G-1 downto 1) := r.shift(PIPE_STAGES_G-2 downto 0);
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs        
      rstOut <= r.shift(PIPE_STAGES_G-1);

   end process comb;

   seq : process (clk) is
   begin
      if rising_edge(clk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;
