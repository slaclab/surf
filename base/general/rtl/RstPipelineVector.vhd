-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Wrapper for multiple RstPipeline modules
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

entity RstPipelineVector is
   generic (
      TPD_G         : time     := 1 ns;
      INV_RST_G     : boolean  := false;
      PIPE_STAGES_G : positive := 3;
      MAX_FANOUT_G  : positive := 16384;
      INIT_G        : slv      := "1";
      WIDTH_G       : positive := 16);
   port (
      clk    : in  sl;
      rstIn  : in  slv(WIDTH_G-1 downto 0);
      rstOut : out slv(WIDTH_G-1 downto 0));
end RstPipelineVector;

architecture mapping of RstPipelineVector is

begin

   GEN_VEC :
   for i in (WIDTH_G-1) downto 0 generate

      U_RstPipeline : entity surf.RstPipeline
         generic map (
            TPD_G         => TPD_G,
            INV_RST_G     => INV_RST_G,
            PIPE_STAGES_G => PIPE_STAGES_G,
            MAX_FANOUT_G  => MAX_FANOUT_G,
            INIT_G        => INIT_G)
         port map (
            clk    => clk,
            rstIn  => rstIn(i),
            rstOut => rstOut(i));

   end generate GEN_VEC;

end architecture mapping;
