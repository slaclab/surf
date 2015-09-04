-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : EvrV1HeartBeat.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-02-18
-- Last update: 2015-02-18
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: EvrHeartBeat LED output
-------------------------------------------------------------------------------
-- Copyright (c) 2015 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;

entity EvrV1HeartBeat is
   generic (
      TPD_G : time := 1 ns);
   port (
      reset            : in  sl;
      uSecDividerReg   : in  slv(31 downto 0);
      eventCode        : in  slv(7 downto 0);
      eventClk         : in  sl;
      heartBeatTimeOut : out sl);
end entity EvrV1HeartBeat;

architecture rtl of EvrV1HeartBeat is

   type RegType is record
      cnt : slv(31 downto 0);
   end record RegType;
   constant REG_INIT_C : RegType := (
      cnt => (others => '0'));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   heartBeatTimeOut <= '1' when(r.cnt = 0) else '0';

   comb : process (eventCode, r, reset, uSecDividerReg) is
      variable v : RegType;
   begin
      v := r;

      if eventCode = x"7A" then
         v.cnt := uSecDividerReg;
      else
         v.cnt := r.cnt - 1;
      end if;

      if (reset = '1') then
         v := REG_INIT_C;
      end if;

      rin <= v;
   end process comb;

   seq : process (eventClk) is
   begin
      if (rising_edge(eventClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end architecture rtl;
