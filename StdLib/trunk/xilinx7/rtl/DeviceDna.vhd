-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : DeviceDna.vhd
-- Author     : Benjamin Reese  <bareese@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-09-25
-- Last update: 2014-01-13
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Wrapper for the DNA_PORT
-------------------------------------------------------------------------------
-- Copyright (c) 2014 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

library unisim;
use unisim.vcomponents.all;

use work.StdRtlPkg.all;

entity DeviceDna is
   generic (
      TPD_G           : time       := 1 ns;
      IN_POLARITY_G   : sl         := '1';
      SIM_DNA_VALUE_G : bit_vector := X"000000000000000");
   port (
      -- Clock & Reset Signals
      clk      : in  sl;
      rst      : in  sl;
      dnaValue : out slv(63 downto 0);
      dnaValid : out sl);
end DeviceDna;

architecture rtl of DeviceDna is

   type StateType is (READ_S, SHIFT_S, DONE_S);

   type RegType is record
      state    : StateType;
      divCnt   : slv(3 downto 0);
      bitCount : slv(bitSize(64)-1 downto 0);
      dnaValue : slv(63 downto 0);
      dnaValid : sl;
      dnaClk   : sl;
      dnaRead  : sl;
      dnaShift : sl;
   end record RegType;

   constant REG_INIT_C : RegType := (
      state    => READ_S,
      divCnt   => (others => '0'),
      bitCount => (others => '0'),
      dnaValue => (others => '0'),
      dnaValid => '0',
      dnaClk   => '0',
      dnaRead  => '0',
      dnaShift => '0');

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal dnaDout : sl;

begin

   comb : process (r, rst, dnaDout) is
      variable v : RegType;
   begin
      v := r;

      v.dnaClk := not r.dnaClk;

      case (r.state) is
         when READ_S =>
            if (r.dnaClk = '1') then    -- Falling edge of dnaClk next
               v.dnaRead := '1';
               v.state   := SHIFT_S;
            end if;

         when SHIFT_S =>
            if (r.dnaClk = '1') then    -- Falling edge of dnaClk next
               v.dnaRead  := '0';
               v.dnaShift := '1';
               if (r.dnaShift = '1') then
                  v.dnaValue := r.dnaValue(62 downto 0) & dnaDout;  -- Shift in right
                  v.bitCount := r.bitCount + 1;
                  if (r.bitCount = 63) then
                     v.state := DONE_S;
                  end if;
               end if;
            end if;

         when DONE_S =>
            v.dnaClk   := '0';
            v.dnaShift := '0';
            v.dnaRead  := '0';
            v.dnaValid := '1';
            
         when others => null;
      end case;

      if (rst = IN_POLARITY_G) then
         v := REG_INIT_C;
      end if;

      rin <= v;

      dnaValue <= r.dnaValue;
      dnaValid <= r.dnaValid;
      
   end process comb;

   sync : process (clk) is
   begin
      if (rising_edge(clk)) then
         r <= rin after TPD_G;
      end if;
   end process sync;

   DNA_PORT_I : DNA_PORT
      port map (
         CLK   => r.dnaClk,
         READ  => r.dnaRead,
         SHIFT => r.dnaShift,
         DIN   => '0',
         DOUT  => dnaDout);

end rtl;
