-------------------------------------------------------------------------------
-- Title      : Gearbox
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: A generic gearbox
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

entity Gearbox is

   generic (
      TPD_G          : time    := 1 ns;
      INPUT_WIDTH_G  : natural := 12;
      OUTPUT_WIDTH_G : natural := 16);

   port (
      clk : in sl;
      rst : in sl;

      -- input side data and flow control
      dataIn  : in  slv(INPUT_WIDTH_G-1 downto 0);
      validIn : in  sl := '1';
      readyIn : out sl;

      -- sequencing and slip
      startOfSeq  : in  sl := '0';
      slip          : in  sl := '0';

      -- output side data and flow control
      dataOut  : out slv(OUTPUT_WIDTH_G-1 downto 0);
      validOut : out sl;
      readyOut : in  sl := '1');

end entity Gearbox;

architecture rtl of Gearbox is

   constant SHIFT_WIDTH_C : integer := OUTPUT_WIDTH_G + INPUT_WIDTH_G;

   type RegType is record
      validOut   : sl;
      shiftReg   : slv(SHIFT_WIDTH_C-1 downto 0);
      writeIndex : integer range 0 to SHIFT_WIDTH_C-1;
      readyIn    : sl;
      slip       : sl;
   end record;

   constant REG_INIT_C : RegType := (
      validOut   => '0',
      shiftReg   => (others => '0'),
      writeIndex => 0,
      readyIn    => '0',
      slip       => '0');

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   comb : process (dataIn, r, readyOut, rst, slip, startOfSeq, validIn) is
      variable v : RegType;
   begin
      v := r;

      -- Flow control defaults
      v.readyIn := '0';

      if (readyOut = '1') then
         v.validOut := '0';
      end if;

      -- Slip input by incrementing the writeIndex
      v.slip := slip;
      if (slip = '1' and r.slip = '0') then
         v.writeIndex := r.writeIndex + 1;
      end if;


      -- Only do anything if ready for data output
      if (v.validOut = '0') then

         -- If current write index (assigned last cycle) is greater than output width,
         -- then we have to shift down before assinging an new input
         if (v.writeIndex >= OUTPUT_WIDTH_G) then
            v.shiftReg   := slvZero(OUTPUT_WIDTH_G) & r.shiftReg(SHIFT_WIDTH_C-1 downto OUTPUT_WIDTH_G);
            v.writeIndex := v.writeIndex - OUTPUT_WIDTH_G;

            -- If write index still greater than output width after shift,
            -- then we have a valid word to output
            if (v.writeIndex >= OUTPUT_WIDTH_G) then
               v.validOut := '1';
            end if;
         end if;
      end if;

      -- Accept new data if ready to output and shift above did not create an output valid
      if (validIn = '1' and v.validOut = '0') then

         -- Reset the sequence if requested
         if (startOfSeq = '1') then
            v.writeIndex := 0;
            v.validOut   := '0';
         end if;

         -- Accept the input word
         v.readyIn := '1';

         -- Assign incomming data at proper location in shift reg
         v.shiftReg(v.writeIndex+INPUT_WIDTH_G-1 downto v.writeIndex) := dataIn;

         -- Increment writeIndex
         v.writeIndex := v.writeIndex + INPUT_WIDTH_G;

         -- Assert validOut
         if (v.writeIndex >= OUTPUT_WIDTH_G) then
            v.validOut := '1';
         end if;

      end if;

      readyIn <= v.readyIn;

      if (rst = '1') then
         v := REG_INIT_C;
      end if;

      rin <= v;

      validOut <= r.validOut;
      dataOut  <= r.shiftReg(OUTPUT_WIDTH_G-1 downto 0);


   end process comb;

   sync : process (clk) is
   begin
      if (rising_edge(clk)) then
         r <= rin after TPD_G;
      end if;
   end process sync;


end architecture rtl;
