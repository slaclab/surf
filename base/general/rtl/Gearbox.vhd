-------------------------------------------------------------------------------
-- Title      : Gearbox
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: A generic gearbox
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

entity Gearbox is

   generic (
      TPD_G                : time := 1 ns;
      SLAVE_BIT_REVERSE_G  : boolean := false;
      SLAVE_WIDTH_G        : positive;
      MASTER_BIT_REVERSE_G : boolean := false;
      MASTER_WIDTH_G       : positive);

   port (
      clk : in sl;
      rst : in sl;

      -- input side data and flow control
      slaveData  : in  slv(SLAVE_WIDTH_G-1 downto 0);
      slaveValid : in  sl := '1';
      slaveReady : out sl;

      -- sequencing and slip
      startOfSeq : in sl := '0';
      slip       : in sl := '0';

      -- output side data and flow control
      masterData  : out slv(MASTER_WIDTH_G-1 downto 0);
      masterValid : out sl;
      masterReady : in  sl := '1');

end entity Gearbox;

architecture rtl of Gearbox is

   constant MAX_C : integer := maximum(MASTER_WIDTH_G, SLAVE_WIDTH_G);
   constant MIN_C : integer := minimum(MASTER_WIDTH_G, SLAVE_WIDTH_G);

   -- Don't need the +1 if slip is not used.
   constant SHIFT_WIDTH_C : integer := wordCount(MAX_C, MIN_C) * MIN_C + MIN_C + 1;

   type RegType is record
      masterValid : sl;
      shiftReg    : slv(SHIFT_WIDTH_C-1 downto 0);
      writeIndex  : integer range 0 to SHIFT_WIDTH_C-1;
      slaveReady  : sl;
      slip        : sl;
   end record;

   constant REG_INIT_C : RegType := (
      masterValid => '0',
      shiftReg    => (others => '0'),
      writeIndex  => 0,
      slaveReady  => '0',
      slip        => '0');

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   comb : process (slaveData, r, masterReady, rst, slip, startOfSeq, slaveValid) is
      variable v : RegType;
   begin
      v := r;

      -- Flow control defaults
      v.slaveReady := '0';

      if (masterReady = '1') then
         v.masterValid := '0';
      end if;

      -- Slip input by incrementing the writeIndex
      v.slip := slip;
      if (slip = '1') and (r.slip = '0') and (rst = '0') then
         v.writeIndex := r.writeIndex - 1;
      end if;


      -- Only do anything if ready for data output
      if (v.masterValid = '0') then

         -- If current write index (assigned last cycle) is greater than output width,
         -- then we have to shift down before assinging an new input
         if (v.writeIndex >= MASTER_WIDTH_G) then
            v.shiftReg   := slvZero(MASTER_WIDTH_G) & r.shiftReg(SHIFT_WIDTH_C-1 downto MASTER_WIDTH_G);
            v.writeIndex := v.writeIndex - MASTER_WIDTH_G;

            -- If write index still greater than output width after shift,
            -- then we have a valid word to output
            if (v.writeIndex >= MASTER_WIDTH_G) then
               v.masterValid := '1';
            end if;
         end if;
      end if;

      -- Accept new data if ready to output and shift above did not create an output valid
      if (slaveValid = '1' and v.masterValid = '0') then

         -- Reset the sequence if requested
         if (startOfSeq = '1') then
            v.writeIndex  := 0;
            v.masterValid := '0';
         end if;

         -- Accept the input word
         v.slaveReady := '1';

         -- Assign incomming data at proper location in shift reg
         if SLAVE_BIT_REVERSE_G then
            v.shiftReg(v.writeIndex+SLAVE_WIDTH_G-1 downto v.writeIndex) := bitReverse(slaveData);
         else
            v.shiftReg(v.writeIndex+SLAVE_WIDTH_G-1 downto v.writeIndex) := slaveData;
         end if;

         -- Increment writeIndex
         v.writeIndex := v.writeIndex + SLAVE_WIDTH_G;

         -- Assert masterValid
         if (v.writeIndex >= MASTER_WIDTH_G) then
            v.masterValid := '1';
         end if;

      end if;

      slaveReady <= v.slaveReady;

      if (rst = '1') then
         v := REG_INIT_C;
      end if;

      rin <= v;

      masterValid <= r.masterValid;
      if MASTER_BIT_REVERSE_G then
         masterData  <= bitReverse(r.shiftReg(MASTER_WIDTH_G-1 downto 0));
      else
         masterData  <= r.shiftReg(MASTER_WIDTH_G-1 downto 0);
      end if;

   end process comb;

   sync : process (clk) is
   begin
      if (rising_edge(clk)) then
         r <= rin after TPD_G;
      end if;
   end process sync;

end  rtl;
