-------------------------------------------------------------------------------
-- Title      : Source Synchronous Scrambler
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:
-- A source synchronous (multiplicative) scrambler with paramatized data width
-- and scrambling polynomial.
-------------------------------------------------------------------------------
-- This file is part of SURF. It is subject to
-- the license terms in the LICENSE.txt file found in the top-level directory
-- of this distribution and at:
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
-- No part of SURF, including this file, may be
-- copied, modified, propagated, or distributed except according to the terms
-- contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use work.StdRtlPkg.all;

entity Scrambler is

   generic (
      TPD_G            : time         := 1 ns;
      DIRECTION_G      : string       := "SCRAMBLER";  -- or DESCRAMBLER
      DATA_WIDTH_G     : integer      := 64;
      SIDEBAND_WIDTH_G : integer      := 2;
      TAPS_G           : IntegerArray := (0 => 39, 1 => 58));

   port (
      clk         : in  sl;
      rst         : in  sl;
      inputEn     : in  sl := '1';
      dataIn      : in  slv(DATA_WIDTH_G-1 downto 0);
      sidebandIn  : in  slv(SIDEBAND_WIDTH_G-1 downto 0);
      outputValid : out sl;
      dataOut     : out slv(DATA_WIDTH_G-1 downto 0);
      sidebandOut : out slv(SIDEBAND_WIDTH_G-1 downto 0));

end entity Scrambler;

architecture rtl of Scrambler is

   constant SCRAMBLER_WIDTH_C : integer := maximum(TAPS_G);

   type RegType is record
      scrambler   : slv(SCRAMBLER_WIDTH_C-1 downto 0);
      outputValid : sl;
      dataOut     : slv(DATA_WIDTH_G-1 downto 0);
      sidebandOut : slv(SIDEBAND_WIDTH_G-1 downto 0);
   end record RegType;

   constant REG_INIT_C : RegType := (
      scrambler   => (others => '0'),
      outputValid => '0',
      dataOut     => (others => '0'),
      sidebandOut => (others => '0'));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   comb : process (dataIn, inputEn, r, rst, sidebandIn) is
      variable v : RegType;
   begin
      v             := r;
      v.outputValid := '0';
      if (inputEn = '1') then
         v.outputValid := '1';
         v.sidebandOut := sidebandIn;

         for i in 0 to DATA_WIDTH_G-1 loop
            v.dataOut(i) := dataIn(i);
            for j in TAPS_G'range loop
               v.dataOut(i) := v.dataOut(i) xor v.scrambler(TAPS_G(j)-1);
            end loop;
            if (DIRECTION_G = "SCRAMBLER") then
               v.scrambler := v.scrambler(SCRAMBLER_WIDTH_C-2 downto 0) & v.dataOut(i);
            elsif (DIRECTION_G = "DESCRAMBLER") then
               v.scrambler := v.scrambler(SCRAMBLER_WIDTH_C-2 downto 0) & dataIn(i);
            end if;

         end loop;
      end if;

      if (rst = '1') then
         v := REG_INIT_C;
      end if;

      rin         <= v;
      outputValid <= r.outputValid;
      dataOut     <= r.dataOut;
      sidebandOut <= r.sidebandOut;

   end process comb;

   seq : process (clk) is
   begin
      if (rising_edge(clk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end architecture rtl;
