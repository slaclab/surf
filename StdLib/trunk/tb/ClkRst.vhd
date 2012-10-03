-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : ClkRst.vhd
-- Author     : Benjamin Reese  <bareese@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2012-09-18
-- Last update: 2012-10-02
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Provides a clocks and reset signal to UUT in simulation.
--              Assumes active high reset.
-------------------------------------------------------------------------------
-- Copyright (c) 2012 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.StdRtlPkg.all;

entity ClkRst is
  generic (
    CLK_PERIOD_G      : time := 10 ns;
    RST_START_DELAY_G : time := 1 ns;   -- Wait this long into simulation before asserting reset
    RST_HOLD_TIME_G   : time := 6 us);  -- Hold reset for this long
  port (
    clkP : out sl;
    clkN : out sl;                      -- Inverted clock
    rst  : out sl;
    rstL : out sl);

end entity CkRst;

architecture ClkRst of ClkRst is

  signal clkFb : sl := '0';
  signal rstFb : sl := '0';
  
begin

  clkFb <= not clkFb after CLK_PERIOD_C/2.0;

  process is
  begin
    rstFb <= '0';
    wait for RST_START_DELAY_G;
    rstFb <= '1';
    wait for RST_HOLD_TIME_G;
    rstFb <= '0';
    wait;
  end process;

  clkP <= clkFb;
  clkN <= not clkFb;
  rst  <= rstFb;
  rstL <= not rstFb;

end architecture ClkRst;
