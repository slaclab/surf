-------------------------------------------------------------------------------
-- Title      : Source Synchronous Scrambler
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
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

library surf;
use surf.StdRtlPkg.all;

entity Scrambler is

   generic (
      TPD_G             : time         := 1 ns;
      DIRECTION_G       : string       := "SCRAMBLER";  -- or DESCRAMBLER
      DATA_WIDTH_G      : integer      := 64;
      SIDEBAND_WIDTH_G  : integer      := 2;
      BIT_REVERSE_IN_G  : boolean      := false;
      BIT_REVERSE_OUT_G : boolean      := false;
      TAPS_G            : IntegerArray := (0 => 39, 1 => 58));

   port (
      clk            : in  sl;
      rst            : in  sl;
      inputValid     : in  sl := '1';
      inputReady     : out sl;
      inputData      : in  slv(DATA_WIDTH_G-1 downto 0);
      inputSideband  : in  slv(SIDEBAND_WIDTH_G-1 downto 0);
      outputValid    : out sl;
      outputReady    : in  sl := '1';
      outputData     : out slv(DATA_WIDTH_G-1 downto 0);
      outputSideband : out slv(SIDEBAND_WIDTH_G-1 downto 0));

end entity Scrambler;

architecture rtl of Scrambler is

   constant SCRAMBLER_WIDTH_C : integer := maximum(TAPS_G);

   type RegType is record
      inputReady     : sl;
      outputValid    : sl;
      scrambler      : slv(SCRAMBLER_WIDTH_C-1 downto 0);
      outputData     : slv(DATA_WIDTH_G-1 downto 0);
      outputSideband : slv(SIDEBAND_WIDTH_G-1 downto 0);
   end record RegType;

   constant REG_INIT_C : RegType := (
      inputReady     => '0',
      outputValid    => '0',
      scrambler      => (others => '0'),
      outputData     => (others => '0'),
      outputSideband => (others => '0'));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   comb : process (inputData, inputSideband, inputValid, outputReady, r, rst) is
      variable v                 : RegType;
      variable inputDataReversed : slv(DATA_WIDTH_G-1 downto 0);
   begin
      -- Latch the current value
      v := r;

      -- Update the variable
      inputDataReversed := bitReverse(inputData);

      -- Default flow control values
      v.inputReady := '0';
      if (outputReady = '1') then
         v.outputValid := '0';
      end if;

      -- Advance pipeline
      if (inputValid = '1' and v.outputValid = '0') then
         v.outputValid := '1';
         v.inputReady  := '1';

         if BIT_REVERSE_IN_G then
            v.outputSideband := bitReverse(inputSideband);
         else
            v.outputSideband := inputSideband;
         end if;

         for i in 0 to DATA_WIDTH_G-1 loop

            if BIT_REVERSE_IN_G then
               v.outputData(i) := inputDataReversed(i);
            else
               v.outputData(i) := inputData(i);
            end if;

            for j in TAPS_G'range loop
               v.outputData(i) := v.outputData(i) xor v.scrambler(TAPS_G(j)-1);
            end loop;

            if (DIRECTION_G = "SCRAMBLER") then
               v.scrambler := v.scrambler(SCRAMBLER_WIDTH_C-2 downto 0) & v.outputData(i);

            elsif (DIRECTION_G = "DESCRAMBLER") then

               if BIT_REVERSE_IN_G then
                  v.scrambler := v.scrambler(SCRAMBLER_WIDTH_C-2 downto 0) & inputDataReversed(i);
               else
                  v.scrambler := v.scrambler(SCRAMBLER_WIDTH_C-2 downto 0) & inputData(i);
               end if;

            end if;

         end loop;

      end if;

      -- Combinatorial outputs before the reset
      inputReady <= v.inputReady;

      -- Reset
      if (rst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Registered Outputs 
      outputValid <= r.outputValid;
      if BIT_REVERSE_OUT_G then
         outputData     <= bitReverse(r.outputData);
         outputSideband <= bitReverse(r.outputSideband);
      else
         outputData     <= r.outputData;
         outputSideband <= r.outputSideband;
      end if;

   end process comb;

   seq : process (clk) is
   begin
      if (rising_edge(clk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;
