-------------------------------------------------------------------------------
-- File       : UartTx.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-05-13
-- Last update: 2016-06-28
-------------------------------------------------------------------------------
-- Description: Uart Transmitter
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Firmware Standard Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'SLAC Firmware Standard Library', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library IEEE;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;

entity UartTx is
   generic (
      TPD_G : time := 1 ns);
   port (
      clk     : in  sl;
      rst     : in  sl;
      baud16x : in  sl;
      wrData  : in  slv(7 downto 0);
      wrValid : in  sl;
      wrReady : out sl;
      tx      : out sl);
end entity UartTx;

architecture RTL of UartTx is

   type StateType is (WAIT_DATA_S, SYNC_EN_16_S, WAIT_16_S, TX_BIT_S);

   type RegType is record
      wrReady      : sl;
      holdReg      : slv(7 downto 0);
      txState      : StateType;
      baud16xCount : slv(3 downto 0);
      shiftReg     : slv(9 downto 0);
      shiftCount   : slv(3 downto 0);
   end record RegType;

   constant REG_INIT_C : RegType := (
      wrReady      => '0',
      holdReg      => (others => '0'),
      txState      => WAIT_DATA_S,
      baud16xCount => (others => '0'),
      shiftReg     => (others => '1'),
      shiftCount   => (others => '0'));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin  -- architecture RTL


   comb : process (baud16x, r, rst, wrData, wrValid) is
      variable v : RegType;
   begin
      v := r;

      case r.txState is
         -- Wait for new data to send
         when WAIT_DATA_S =>
            v.wrReady := '1';
            if (wrValid = '1' and r.wrReady = '1') then
               v.wrReady := '0';                     
               v.holdReg := wrData;
               v.txState := SYNC_EN_16_S;
            end if;

         -- Wait for next baud16x to synchronize
         -- Then load the shift reg
         -- Bit 0 is the start bit, bit 9 is the stop bit
         when SYNC_EN_16_S =>
            if (baud16x = '1') then
               v.baud16xCount := (others => '0');
               v.shiftReg     := '1' & r.holdReg & '0';
               v.shiftCount   := (others => '0');
               v.txState      := WAIT_16_S;
            end if;

         -- Wait 16 baud_16x counts (the baud rate)
         -- When shifted all bits, wait for next tx data
         when WAIT_16_S =>
            if (baud16x = '1') then
               v.baud16xCount := r.baud16xCount + 1;
               if (r.baud16xCount = 15) then
                  v.txState := TX_BIT_S;
                  if (r.shiftCount = 9) then
                     v.txState := WAIT_DATA_S;
                  end if;
               end if;
            end if;

         -- Shift to TX next bit, increment shift count
         when TX_BIT_S =>
            v.shiftReg   := '0' & r.shiftReg(9 downto 1);
            v.shiftCount := r.shiftCount + 1;
            v.txState    := WAIT_16_S;

      end case;

      if (rst = '1') then
         v := REG_INIT_C;
      end if;

      rin     <= v;
      wrReady <= r.wrReady;
      tx      <= r.shiftReg(0);

   end process;

   seq : process (clk) is
   begin
      if (rising_edge(clk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;


end architecture RTL;
