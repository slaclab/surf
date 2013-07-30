-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : SynchronizerVector.vhd
-- Author     : Benjamin Reese  <bareese@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-07-10
-- Last update: 2013-07-30
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
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
      WIDTH_G        : integer  := 16;
      INIT_G         : slv      := "0"
      );
   port (
      clk     : in  sl;                 -- clock to be sync'ed to
      aRst    : in  sl := not RST_POLARITY_G;  -- Optional async reset
      sRst    : in  sl := not RST_POLARITY_G;  -- Optional synchronous reset
      dataIn  : in  slv(WIDTH_G-1 downto 0);   -- Data to be 'synced'
      dataOut : out slv(WIDTH_G-1 downto 0)    --synced data
      );
begin
   assert (STAGES_G >= 2) report "STAGES_G must be >= 2" severity failure;
end SynchronizerVector;

architecture rtl of SynchronizerVector is
   constant INIT_C : slv(WIDTH_G-1 downto 0) := ite(INIT_G = "0", slvZero(WIDTH_G), INIT_G);

   type   RegArray is array (STAGES_G-1 downto 0) of slv(WIDTH_G-1 downto 0);
   signal r, rin : RegArray := (others => INIT_C);

   -------------------------------
   -- XST/Synplify Attributes
   -------------------------------
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

   -------------------------------
   -- Altera Attributes 
   -- NOTE: These attributes have not been tested yet!!!
   ------------------------------- 
   attribute altera_attribute : string;

   -- Disable Auto Shift Register Recognition logic option
   -- Optimize for metastability
   -- Don't let register balancing move logic between the register chain
   attribute altera_attribute of r : signal is "-name AUTO_SHIFT_REGISTER_RECOGNITION OFF -name OPTIMIZE_FOR_METASTABILITY ON -name USE_LOGICLOCK_CONSTRAINTS_IN_BALANCING OFF";

   -- This attribute will stop timing errors
   attribute altera_attribute of rin : signal is "-name CUT ON -from dataIn -to rin";
   
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
         rin <= (others => INIT_C);
      end if;

      dataOut <= r(STAGES_G-1);
   end process comb;

   seq : process (aRst, clk) is
   begin
      if (rising_edge(clk)) then
         r <= rin after TPD_G;
      end if;
      if (aRst = RST_POLARITY_G) then
         r <= (others => INIT_C) after TPD_G;
      end if;
   end process seq;

end architecture rtl;
