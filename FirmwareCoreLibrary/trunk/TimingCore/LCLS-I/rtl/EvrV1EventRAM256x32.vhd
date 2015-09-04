-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : EvrV1EventRAM256x32.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-02-17
-- Last update: 2015-02-17
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2015 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;

entity EvrV1EventRAM256x32 is
   generic (
      TPD_G : time := 1 ns);
   port (
      -- Port A     
      clka  : in  sl;
      ena   : in  sl;
      wea   : in  sl;
      addra : in  slv(7 downto 0);
      dina  : in  slv(31 downto 0);
      douta : out slv(31 downto 0);
      -- Port B
      clkb  : in  sl;
      enb   : in  sl;
      web   : in  sl;
      addrb : in  slv(7 downto 0);
      dinb  : in  slv(31 downto 0);
      doutb : out slv(31 downto 0));   
end EvrV1EventRAM256x32;

architecture mapping of EvrV1EventRAM256x32 is

begin
   
   TrueDualPortRam_Inst : entity work.TrueDualPortRam
      generic map (
         TPD_G        => TPD_G,
         MODE_G       => "read-first",
         DATA_WIDTH_G => 32,
         ADDR_WIDTH_G => 8)
      port map (
         -- Port A     
         clka  => clka,
         ena   => ena,
         wea   => wea,
         addra => addra,
         dina  => dina,
         douta => douta,
         -- Port B
         clkb  => clkb,
         enb   => enb,
         web   => web,
         addrb => addrb,
         dinb  => dinb,
         doutb => doutb);   

end mapping;
