-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Example Arbiter Module
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Firmware Standard Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'SLAC Firmware Standard Library', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;


library surf;
use surf.StdRtlPkg.all;
use surf.ArbiterPkg.all;

entity Arbiter is
   generic (
      TPD_G          : time     := 1 ns;
      RST_POLARITY_G : sl       := '1';  -- '1' for active high rst, '0' for active low
      RST_ASYNC_G    : boolean  := false;  -- Reset is asynchronous
      REQ_SIZE_G     : positive := 16);
   port (
      clk : in sl;
      rst : in sl := not RST_POLARITY_G;   -- Optional reset

      req      : in  slv(REQ_SIZE_G-1 downto 0);
      selected : out slv(bitSize(REQ_SIZE_G-1)-1 downto 0);
      valid    : out sl;
      ack      : out slv(REQ_SIZE_G-1 downto 0));
end entity Arbiter;

architecture rtl of Arbiter is

   constant SELECTED_SIZE_C : integer := bitSize(REQ_SIZE_G-1);

   type RegType is record
      lastSelected : slv(SELECTED_SIZE_C-1 downto 0);
      valid        : sl;
      ack          : slv(REQ_SIZE_G-1 downto 0);
   end record RegType;

   constant REG_RESET_C : RegType :=
      (lastSelected => (others => '0'), valid => '0', ack => (others => '0'));

   signal r   : RegType := REG_RESET_C;
   signal rin : RegType;
   
begin

   comb : process (r, req, rst) is
      variable v    : RegType;
   begin
      v    := r;

      if (req(conv_integer(r.lastSelected)) = '0' or r.valid = '0') then
         arbitrate(req, r.lastSelected, v.lastSelected, v.valid, v.ack);
      end if;

      if (RST_ASYNC_G = false and rst = RST_POLARITY_G) then
         v := REG_RESET_C;
      end if;

      rin      <= v;
      ack      <= r.ack;
      valid    <= r.valid;
      selected <= slv(r.lastSelected);
      
   end process comb;

   seq : process (clk, rst) is
   begin
      if (rising_edge(clk)) then
         r <= rin after TPD_G;
      end if;
      if (RST_ASYNC_G and rst = RST_POLARITY_G) then
         r <= REG_RESET_C after TPD_G;
      end if;
   end process seq;

end architecture rtl;
