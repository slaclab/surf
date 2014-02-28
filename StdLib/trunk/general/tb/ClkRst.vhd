-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : ClkRst.vhd
-- Author     : Benjamin Reese  <bareese@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2012-09-18
-- Last update: 2013-03-27
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
    CLK_PERIOD_G      : time    := 10 ns;
    CLK_DELAY_G       : time    := 0 ns;
    RST_START_DELAY_G : time    := 1 ns;  -- Wait this long into simulation before asserting reset
    RST_HOLD_TIME_G   : time    := 6 us;  -- Hold reset for this long
    SYNC_RESET_G      : boolean := false);  
  port (
    clkP : out sl := '0';
    clkN : out sl := '1';                        -- Inverted clock
    rst  : out sl := '1';
    rstL : out sl := '0');

end entity ClkRst;

architecture ClkRst of ClkRst is

  signal clkFb : sl := '0';
  signal rstFb : sl := '0';
  
begin

  process is
  begin
    wait for CLK_DELAY_G;
    while (true) loop
      clkFb <= not clkFb;
      wait for CLK_PERIOD_G/2.0;
    end loop;
  end process;

  process is
  begin
    rstFb <= '0';
    wait for RST_START_DELAY_G;
    if (SYNC_RESET_G) then
      wait until clkFb = '1';
    end if;
    rstFb <= '1';
    wait for RST_HOLD_TIME_G;
    if (SYNC_RESET_G) then
      wait until clkFb = '1';
    end if;
    rstFb <= '0';
    wait;
  end process;

  clkP <= clkFb;
  clkN <= not clkFb;
  rst  <= rstFb;
  rstL <= not rstFb;

end architecture ClkRst;
