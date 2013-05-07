-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : Arbiter.vhd
-- Author     : Benjamin Reese  <bareese@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-04-30
-- Last update: 2013-05-06
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2013 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
--use ieee.std_logic_unsigned.all;
use work.StdRtlPkg.all;
use work.ArbiterPkg.all;

entity Arbiter is
   generic (
      TPD_G      : time     := 1 ns;
      USE_SRST_G : boolean  := true;
      USE_ARST_G : boolean  := false;
      REQ_SIZE_G : positive := 16);
   port (
      clk  : in sl;
      aRst : in sl := '0';
      sRst : in sl := '0';

      req      : in  slv(REQ_SIZE_G-1 downto 0);
      selected : out slv(bitSize(REQ_SIZE_G)-1 downto 0);
      valid    : out sl;
      ack      : out slv(REQ_SIZE_G-1 downto 0));
end entity Arbiter;

architecture rtl of Arbiter is

   constant SELECTED_SIZE_C : integer := bitSize(REQ_SIZE_G);

   type RegType is record
      lastSelected : unsigned(SELECTED_SIZE_C-1 downto 0);
      valid        : sl;
      ack          : slv(REQ_SIZE_G-1 downto 0);
   end record RegType;

   constant REG_RESET_C : RegType :=
      (lastSelected => (others => '0'), valid => '0', ack => (others => '0'));

   signal r, rin : RegType := REG_RESET_C;
   
begin

   comb : process (r, req, sRst) is
      variable v : RegType;
   begin
      v := r;

      if (req(to_integer(r.lastSelected)) = '0') then
         arbitrate(req, r.lastSelected, v.lastSelected, v.valid, v.ack);
      end if;

      

      if (USE_SRST_G and sRst = '1') then
         v := REG_RESET_C;
      end if;

      rin      <= v;
      ack      <= r.ack;
      valid    <= r.valid;
      selected <= slv(r.lastSelected);
      
   end process comb;

   seq : process (clk, aRst) is
   begin
      if (rising_edge(clk)) then
         r <= rin after TPD_G;
      end if;
      if (USE_ARST_G and aRst = '1') then
         r <= REG_RESET_C after TPD_G;
      end if;
   end process seq;

end architecture rtl;
