-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
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

library surf;
use surf.StdRtlPkg.all;

entity UartTx is
   generic (
      TPD_G        : time                  := 1 ns;
      STOP_BITS_G  : integer range 1 to 2  := 1;
      PARITY_G     : string                := "NONE";  -- "NONE" "ODD" "EVEN"
      BAUD_MULT_G  : integer range 2 to 16 := 16;
      DATA_WIDTH_G : integer range 5 to 8  := 8);
   port (
      clk       : in  sl;
      rst       : in  sl;
      baudClkEn : in  sl;
      wrData    : in  slv(DATA_WIDTH_G-1 downto 0);
      wrValid   : in  sl;
      wrReady   : out sl;
      tx        : out sl);
end entity UartTx;

architecture RTL of UartTx is
   constant PARITY_BITS_C     : integer := ite(PARITY_G = "NONE", 0, 1);
   constant START_BIT_C       : integer := 1;
   constant SHIFT_REG_WIDTH_C : integer := START_BIT_C + DATA_WIDTH_G + PARITY_BITS_C + STOP_BITS_G;

   type StateType is (WAIT_DATA_S, SYNC_EN_S, WAIT_S, TX_BIT_S);

   type RegType is record
      wrReady        : sl;
      holdReg        : slv(DATA_WIDTH_G-1 downto 0);
      parity         : sl;
      txState        : StateType;
      baudClkEnCount : slv(3 downto 0);
      shiftReg       : slv(SHIFT_REG_WIDTH_C-1 downto 0);
      shiftCount     : slv(3 downto 0);
   end record RegType;

   constant REG_INIT_C : RegType := (
      wrReady        => '0',
      holdReg        => (others => '0'),
      parity         => '0',
      txState        => WAIT_DATA_S,
      baudClkEnCount => (others => '0'),
      shiftReg       => (others => '1'),
      shiftCount     => (others => '0'));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin  -- architecture RTL


   comb : process (baudClkEn, r, rst, wrData, wrValid) is
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
               v.txState := SYNC_EN_S;
               v.parity  := oddParity(wrData);  -- returns 1 if wrData is odd, 0 if even
            end if;

         -- Wait for next baudClkEn to synchronize
         -- Then load the shift reg
         -- LSB is the start bit, MSB is stop bit, MSB-1 is parity/stop
         when SYNC_EN_S =>
            if (baudClkEn = '1') then
               if(STOP_BITS_G = 1 and PARITY_G = "NONE") then
                  v.shiftReg := '1' & r.holdReg & '0';
               elsif(STOP_BITS_G = 1 and PARITY_G = "EVEN") then
                  v.shiftReg := '1' & r.parity & r.holdReg & '0';
               elsif(STOP_BITS_G = 1 and PARITY_G = "ODD") then
                  v.shiftReg := '1' & not(r.parity) & r.holdReg & '0';
               elsif(STOP_BITS_G = 2 and PARITY_G = "NONE") then
                  v.shiftReg := '1' & '1' & r.holdReg & '0';
               else
                  assert (not(STOP_BITS_G = 2 and PARITY_G /= "NONE"))
                     report "Invalid stopbit:parity combination" severity failure;
               end if;

               v.baudClkEnCount := (others => '0');
               v.shiftCount     := (others => '0');
               v.txState        := WAIT_S;
            end if;

         -- Wait BAUD_MULT_G-1 counts (the baud rate)
         -- When shifted all bits, wait for next tx data
         when WAIT_S =>
            if (baudClkEn = '1') then
               v.baudClkEnCount := r.baudClkEnCount + 1;
               if (r.baudClkEnCount = (BAUD_MULT_G-2)) then
                  v.baudClkEnCount := (others => '0');
                  v.txState        := TX_BIT_S;
                  if (r.shiftCount = SHIFT_REG_WIDTH_C-1) then
                     v.txState := WAIT_DATA_S;
                  end if;
               end if;
            end if;

         -- Shift to TX next bit, increment shift count
         when TX_BIT_S =>
            if (baudClkEn = '1') then
               v.shiftReg   := '0' & r.shiftReg(SHIFT_REG_WIDTH_C-1 downto 1);
               v.shiftCount := r.shiftCount + 1;
               v.txState    := WAIT_S;
            end if;

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
