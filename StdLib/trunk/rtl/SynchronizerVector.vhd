-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : SynchronizerVector.vhd
-- Author     : Benjamin Reese  <bareese@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-07-10
-- Last update: 2013-07-10
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

entity SynchronizerVector is
   generic (
      TPD_G          : time     := 1 ns;
      RST_POLARITY_G : sl       := '1';  -- '1' for active high rst, '0' for active low
      STAGES_G       : positive := 2;
--    INIT_G         : slv      := x"0000";
      WIDTH_G        : integer  := 16
      );
   port (
      clk     : in  sl;                        -- clock to be sync'ed to
      aRst    : in  sl := not RST_POLARITY_G;  -- Optional async reset
      sRst    : in  sl := not RST_POLARITY_G;  -- Optional synchronous reset
      dataIn  : in  slv(WIDTH_G-1 downto 0);   -- Data to be 'synced'
      dataOut : out slv(WIDTH_G-1 downto 0)    --synced data
      );
begin
   assert (STAGES_G >= 2) report "STAGES_G must be >= 2" severity failure;
-- assert (INIT_G'length = WIDTH_G) report "Size of INIT_G must equal STAGES_G" severity failure;
end SynchronizerVector;

architecture rtl of SynchronizerVector is
   type   RegArray is array (STAGES_G-1 downto 0) of slv(WIDTH_G-1 downto 0);
-- signal r, rin : RegArray := (others => INIT_G);
   signal r, rin : RegArray := (others => (others => '0'));

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

   comb : process (dataIn, r, sRst) is
      variable i : integer;
   begin
      for i in STAGES_G-2 downto 0 loop
         rin(i+1) <= r(i);
      end loop;
      rin(0) <= dataIn;
      -- Synchronous Reset
      if (sRst = RST_POLARITY_G) then
--       rin <= (others => INIT_G);
         rin <= (others => (others => '0'));
      end if;

      dataOut <= r(STAGES_G-1);
   end process comb;

   seq : process (aRst, clk) is
   begin
      if (rising_edge(clk)) then
         r <= rin after TPD_G;
      end if;
      if (aRst = RST_POLARITY_G) then
--       r <= (others => INIT_G) after TPD_G;
         r <= (others => (others => '0')) after TPD_G;
      end if;
   end process seq;

end architecture rtl;
