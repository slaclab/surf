-------------------------------------------------------------------------------
-- File       : Encoder8b10b.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-10-12
-- Last update: 2016-10-12
-------------------------------------------------------------------------------
-- Description: 8B10B Encoder Module
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
use work.StdRtlPkg.all;
use work.Code8b10bPkg.all;

entity Encoder8b10b is
   
   generic (
      TPD_G          : time     := 1 ns;
      NUM_BYTES_G    : positive := 2;
      RST_POLARITY_G : sl       := '0';
      RST_ASYNC_G    : boolean  := true);
   port (
      clk     : in  sl;
      clkEn   : in  sl := '1';  -- Optional Clock Enable
      rst     : in  sl := not RST_POLARITY_G;  -- Optional Reset
      dataIn  : in  slv(NUM_BYTES_G*8-1 downto 0);
      dataKIn : in  slv(NUM_BYTES_G-1 downto 0);
      dataOut : out slv(NUM_BYTES_G*10-1 downto 0));

end entity Encoder8b10b;

architecture rtl of Encoder8b10b is

   type RegType is record
      runDisp : sl;
      dataOut : slv(NUM_BYTES_G*10-1 downto 0);
   end record RegType;

   constant REG_INIT_C : RegType := (
      runDisp => '0',
      dataOut => (others => '0'));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   comb : process (dataIn, dataKIn, r, rst) is
      variable v            : RegType;
      variable dispChainVar : sl;
   begin
      v            := r;
      dispChainVar := r.runDisp;
      for i in 0 to NUM_BYTES_G-1 loop
         encode8b10b(dataIn  => dataIn(i*8+7 downto i*8),
                     dataKIn => dataKIn(i),
                     dispIn  => dispChainVar,
                     dataOut => v.dataOut(i*10+9 downto i*10),
                     dispOut => dispChainVar);
      end loop;
      v.runDisp := dispChainVar;

      -- Synchronous reset
      if (RST_ASYNC_G = false and rst = RST_POLARITY_G) then
         v := REG_INIT_C;
      end if;

      rin     <= v;
      dataOut <= r.dataOut;
   end process comb;

   seq : process (clk, rst) is
   begin
      if (rst = RST_POLARITY_G) then
         r <= REG_INIT_C after TPD_G;
      elsif (rising_edge(clk)) then
         if clkEn = '1' then
            r <= rin after TPD_G;
         end if;
      end if;
   end process seq;

end architecture rtl;
