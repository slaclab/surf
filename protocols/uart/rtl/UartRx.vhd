-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: UART Receiver
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
use ieee.std_logic_unsigned.all;


library surf;
use surf.StdRtlPkg.all;

entity UartRx is
   generic (
      TPD_G        : time                  := 1 ns;
      PARITY_G     : string                := "NONE";  -- "NONE" "ODD" "EVEN"
      BAUD_MULT_G  : integer range 2 to 16 := 16;
      DATA_WIDTH_G : integer range 5 to 8  := 8);
   port (
      clk         : in  sl;
      rst         : in  sl;
      baudClkEn   : in  sl;
      rdData      : out slv(DATA_WIDTH_G-1 downto 0);
      rdValid     : out sl;
      parityError : out sl;
      rdReady     : in  sl;
      rx          : in  sl);
end entity UartRx;

architecture rtl of UartRx is

   type StateType is (WAIT_START_BIT_S, WAIT_HALF_S, WAIT_FULL_S, SAMPLE_RX_S, PARITY_S, WAIT_STOP_S, WRITE_OUT_S);

   type RegType is
   record
      rdValid        : sl;
      rdData         : slv(DATA_WIDTH_G-1 downto 0);
      rxState        : StateType;
      waitState      : StateType;
      rxShiftReg     : slv(DATA_WIDTH_G-1 downto 0);
      rxShiftCount   : slv(3 downto 0);
      baudClkEnCount : slv(3 downto 0);
      parity         : sl;
      parityError    : sl;
   end record regType;

   constant REG_INIT_C : RegType := (
      rdValid        => '0',
      rdData         => (others => '0'),
      rxState        => WAIT_START_BIT_S,
      waitState      => SAMPLE_RX_S,
      rxShiftReg     => (others => '0'),
      rxShiftCount   => (others => '0'),
      baudClkEnCount => (others => '0'),
      parity         => '0',
      parityError    => '0');

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal rxSync : sl;
   signal rxFall : sl;


begin

   U_SynchronizerEdge_1 : entity surf.SynchronizerEdge
      generic map (
         TPD_G    => TPD_G,
         STAGES_G => 3,
         INIT_G   => "111")
      port map (
         clk         => clk,            -- [in]
         rst         => rst,            -- [in]
         dataIn      => rx,             -- [in]
         dataOut     => rxSync,         -- [out]
         risingEdge  => open,           -- [out]
         fallingEdge => rxFall);        -- [out]

   comb : process (baudClkEn, r, rdReady, rst, rxFall, rxSync) is
      variable v : RegType;
   begin
      v := r;

      if (rdReady = '1') then
         v.rdValid     := '0';
         v.parityError := '0';
      end if;

      if (PARITY_G = "ODD") then
         v.parity := evenParity(r.rxShiftReg);
      elsif (PARITY_G = "EVEN") then
         v.parity := oddParity(r.rxShiftReg);
      else
         v.parity := '0';
      end if;

      case r.rxState is

         -- Wait for RX to drop to indicate start bit
         when WAIT_START_BIT_S =>
            if (rxFall = '1') then
               v.rxState        := WAIT_HALF_S;
               v.baudClkEnCount := (others => '0');
               v.rxShiftCount   := (others => '0');
            end if;

         -- Wait BAUD_MULT_G/2 baudClkEn counts to find center of start bit
         -- Every rx bit is BAUD_MULT_G baudClkEn pulses apart
         when WAIT_HALF_S =>
            if (baudClkEn = '1') then
               v.baudClkEnCount := r.baudClkEnCount + 1;
               if (r.baudClkEnCount = (BAUD_MULT_G/2-1)) then
                  v.baudClkEnCount := (others => '0');
                  v.rxState        := WAIT_FULL_S;
               end if;
            end if;

         -- Wait BAUD_MULT_G baudClkEn counts (center of next bit)
         when WAIT_FULL_S =>
            if (baudClkEn = '1') then
               v.baudClkEnCount := r.baudClkEnCount + 1;
               if (r.baudClkEnCount = (BAUD_MULT_G-2)) then
                  v.baudClkEnCount := (others => '0');
                  v.rxState        := r.waitState;
               end if;
            end if;

         -- Sample the rx line and shift it in.
         -- Go back and wait 16 for the next bit unless last bit
         when SAMPLE_RX_S =>
            if (baudClkEn = '1') then
               v.rxShiftReg   := rxSync & r.rxShiftReg(DATA_WIDTH_G-1 downto 1);
               v.rxShiftCount := r.rxShiftCount + 1;
               v.rxState      := WAIT_FULL_S;
               v.waitState    := SAMPLE_RX_S;
               if (r.rxShiftCount = DATA_WIDTH_G-1) then
                  if(PARITY_G /= "NONE") then
                     v.waitState := PARITY_S;
                  else
                     v.waitState := WAIT_STOP_S;
                  end if;
               end if;
            end if;

         -- Samples parity bit on rx line and compare it to the calculated parity
         -- raises a parityError flag if it does not match
         when PARITY_S =>
            if (baudClkEn = '1') then
               v.rxState     := WAIT_FULL_S;
               v.waitState   := WAIT_STOP_S;
               v.parityError := toSl(r.parity = rxSync);
            end if;

         -- Wait for the stop bit
         when WAIT_STOP_S =>
            if (rxSync = '1') then
               v.rxState := WRITE_OUT_S;
            end if;

         -- Put the parallel rx data on the output port.
         when WRITE_OUT_S =>
            v.rdData    := r.rxShiftReg;
            v.rdValid   := '1';
            v.rxState   := WAIT_START_BIT_S;
            v.waitState := SAMPLE_RX_S;

      end case;

      if (rst = '1') then
         v := REG_INIT_C;
      end if;

      rin         <= v;
      rdData      <= r.rdData;
      rdValid     <= r.rdValid;
      parityError <= r.parityError;

   end process comb;

   sync : process (clk) is
   begin
      if (rising_edge(clk)) then
         r <= rin after TPD_G;
      end if;
   end process;

end architecture RTL;
