-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : DsciSlaveRam.vhd
-- Author     : Benjamin Reese  <bareese@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2012-09-19
-- Last update: 2012-10-05
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:
-- 
-------------------------------------------------------------------------------
-- Copyright (c) 2012 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use ieee.numeric_std.all;
use work.StdRtlPkg.all;

entity DsciSlaveRam is
  
  port (
    dsciClkOut : in  sl;
    exec       : in  sl;
    ack        : out sl;
    readL      : in  sl;
    cmd        : in  slv(6 downto 0);
    addr       : in  slv(11 downto 0);
    wrData     : in  slv(31 downto 0);
    rdData     : out slv(31 downto 0));

end entity DsciSlaveRam;

architecture rtl of DsciSlaveRam is

  type RamType is array (0 to 2**19) of slv(31 downto 0);
  signal ram : RamType;

begin

  p : process is
    variable addrV  : slv(18 downto 0);
    variable indexV : integer;
  begin
    wait until dsciClkOut = '1';
    ack  <= '0';
    -- Transaction rx'd
    if (exec = '1') then
      addrV  := cmd & addr;
      indexV := to_integer(unsigned(addrV));
      if (readL = '0') then
        rdData <= ram(indexV);
        wait until dsciClkOut = '1';
        ack  <= '1';
        wait until exec = '0';
        ack  <= '0';
      else
        ram(indexV) <= wrData;
        wait until dsciClkOut = '1';
        ack         <= '1';
        wait until exec = '0';
        ack         <= '0';
      end if;
    end if;
  end process p;

end architecture rtl;
