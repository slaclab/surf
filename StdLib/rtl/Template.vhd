-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : 
-- Author     : Benjamin Reese  <bareese@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2012-05-16
-- Last update: 2012-05-16
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:
-------------------------------------------------------------------------------
-- Copyright (c) 2012 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use work.StdRtlPkg.all;

entity Template is
  
  generic (
    DELAY_G : time := 1 ns);

  port (
    clk : in sl;
    rst : in sl
);

end entity Template;

architecture rtl of Template is

   type RegType is record

  end record;

   signal r, rin : RegType;

begin

  sync: process (clk, rst) is
  begin
    if (rst = '1') then

    elsif (rising_edge(sysClk)) then
      r <= rin;
    end if;
  end process sync;

  comb: process (r, ) is
    variable rVar : RegType;
  begin
    rVar := r;

    rin <= rVar;
  end process comb;

end architecture rtl;
