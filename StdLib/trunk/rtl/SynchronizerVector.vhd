-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : SynchronizerVector.vhd
-- Author     : Benjamin Reese  <bareese@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-07-10
-- Last update: 2013-12-03
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
      RST_POLARITY_G : sl       := '1';        -- '1' for active high rst, '0' for active low
      RST_ASYNC_G    : boolean  := false;
      STAGES_G       : positive := 2;
      WIDTH_G        : integer  := 16;
      INIT_G         : slv      := "0"
      );
   port (
      clk     : in  sl;                        -- clock to be sync'ed to
      rst     : in  sl := not RST_POLARITY_G;  -- Optional reset
      dataIn  : in  slv(WIDTH_G-1 downto 0);   -- Data to be 'synced'
      dataOut : out slv(WIDTH_G-1 downto 0)    --synced data
      );
begin
   assert (STAGES_G >= 2) report "STAGES_G must be >= 2" severity failure;
   assert (INIT_G = "0" or INIT_G'length = WIDTH_G) report
      "INIT_G must either be ""0"" or the same length as WIDTH_G" severity failure;
end SynchronizerVector;

architecture rtl of SynchronizerVector is
   constant INIT_C : slv(WIDTH_G-1 downto 0) := ite(INIT_G = "0", slvZero(WIDTH_G), INIT_G);

   type RegArray is array (STAGES_G-1 downto 0) of slv(WIDTH_G-1 downto 0);
   signal crossDomainSyncReg : RegArray := (others => INIT_C);
   signal rin                : RegArray;

   -------------------------------
   -- XST/Synplify Attributes
   -------------------------------
   -- These attributes will stop Vivado translating the desired flip-flops into an
   -- SRL based shift register. (Breaks XST for some reason so keep commented for now).
   attribute ASYNC_REG                       : string;
   attribute ASYNC_REG of crossDomainSyncReg : signal is "TRUE";

   -- Synplify Pro: disable shift-register LUT (SRL) extraction
   attribute syn_srlstyle                       : string;
   attribute syn_srlstyle of crossDomainSyncReg : signal is "registers";

   -- These attributes will stop timing errors being reported on the target flip-flop during back annotated SDF simulation.
   attribute MSGON                       : string;
   attribute MSGON of crossDomainSyncReg : signal is "FALSE";

   -- These attributes will stop XST translating the desired flip-flops into an
   -- SRL based shift register.
   attribute shreg_extract                       : string;
   attribute shreg_extract of crossDomainSyncReg : signal is "no";

   -- Don't let register balancing move logic between the register chain
   attribute register_balancing                       : string;
   attribute register_balancing of crossDomainSyncReg : signal is "no";

   -------------------------------
   -- Altera Attributes 
   ------------------------------- 
   attribute altera_attribute                       : string;
   attribute altera_attribute of crossDomainSyncReg : signal is "-name AUTO_SHIFT_REGISTER_RECOGNITION OFF";
   
begin

   comb : process (dataIn, crossDomainSyncReg, rst) is
      variable i : integer;
   begin
      for i in STAGES_G-2 downto 0 loop
         rin(i+1) <= crossDomainSyncReg(i);
      end loop;
      rin(0) <= dataIn;
      -- Synchronous Reset
      if (RST_ASYNC_G = false and rst = RST_POLARITY_G) then
         rin <= (others => INIT_C);
      end if;

      dataOut <= crossDomainSyncReg(STAGES_G-1);
   end process comb;

   seq : process (clk, rst) is
   begin
      if (rising_edge(clk)) then
         crossDomainSyncReg <= rin after TPD_G;
      end if;
      if (RST_ASYNC_G and rst = RST_POLARITY_G) then
         crossDomainSyncReg <= (others => INIT_C) after TPD_G;
      end if;
   end process seq;

end architecture rtl;
