-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : Synchronizer.vhd
-- Author     : Benjamin Reese  <bareese@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-05-13
-- Last update: 2013-05-23
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: A simple multi Flip FLop synchronization module.
--              Sets attributes to keep synthesis for mucking with FF chain.
-------------------------------------------------------------------------------
-- Copyright (c) 2013 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use work.StdRtlPkg.all;

entity SynchronizerEdge is
   generic (
      TPD_G          : time     := 1 ns;
      RST_POLARITY_G : sl       := '1';            -- '1' for active high rst, '0' for active low
      STAGES_G       : positive := 3;
      INIT_G         : slv      := "0"
      );
   port (
      clk         : in  sl;                        -- clock to be sync'ed to
      aRst        : in  sl := not RST_POLARITY_G;  -- Optional async reset
      sRst        : in  sl := not RST_POLARITY_G;  -- Optional synchronous reset
      dataIn      : in  sl;                        -- Data to be 'synced'
      dataOut     : out sl;                        -- synced data
      risingEdge  : out sl;                        -- Rising edge detected
      fallingEdge : out sl                         -- Falling edge detected
      );
begin
   assert (STAGES_G >= 3) report "STAGES_G must be >= 3" severity failure;
end SynchronizerEdge;

architecture rtl of SynchronizerEdge is
   constant INIT_C : slv(STAGES_G-1 downto 0) := ite(INIT_G="0", slvZero(STAGES_G), INIT_G);

   -- r(STAGES_G-1) used for edge detection.
   -- Optimized out if edge detection not used.
   signal r, rin : slv(STAGES_G-1 downto 0) := INIT_C;


   -- These attributes will stop Vivado translating the desired flip-flops into an
   -- SRL based shift register. (Breaks XST for some reason so keep commented for now).
   attribute ASYNC_REG      : string;
   attribute ASYNC_REG of r : signal is "TRUE";

   -- Synplify Pro: disable shift-register LUT (SRL) extraction
   attribute syn_srlstyle      : string;
   attribute syn_srlstyle of r : signal is "registers";

   -- These attributes will stop timing errors being reported on the target flip-flop during back annotated SDF simulation.
   attribute MSGON      : string;
   attribute MSGON of r : signal is "FALSE";

   -- These attributes will stop XST translating the desired flip-flops into an
   -- SRL based shift register.
   attribute shreg_extract      : string;
   attribute shreg_extract of r : signal is "no";

   -- Don't let register balancing move logic between the register chain
   attribute register_balancing      : string;
   attribute register_balancing of r : signal is "no";
   
begin

   comb : process (dataIn, sRst, r) is
   begin
      rin <= r(STAGES_G-2 downto 0) & dataIn;

      -- Synchronous Reset
      if (sRst = RST_POLARITY_G) then
         rin <= INIT_C;
      end if;

      dataOut     <= r(STAGES_G-2);
      risingEdge  <= r(STAGES_G-2) and not r(STAGES_G-1);
      fallingEdge <= not r(STAGES_G-2) and r(STAGES_G-1);
   end process comb;

   seq : process (clk, aRst) is
   begin
      if (rising_edge(clk)) then
         r <= rin after TPD_G;
      end if;
      if (aRst = RST_POLARITY_G) then
         r <= INIT_C after TPD_G;
      end if;
   end process seq;

end architecture rtl;
