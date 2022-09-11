-------------------------------------------------------------------------------
-- Title      : CXP Over Fiber Protocol: http://jiia.org/wp-content/themes/jiia/pdf/standard_dl/coaxpress/CXPR-008-2021.pdf
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: CoaXPress RX FSM
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
use ieee.std_logic_arith.all;

library surf;
use surf.StdRtlPkg.all;
use surf.CoaXPressPkg.all;

entity CoaXPressOverFiberBridgeRx is
   generic (
      TPD_G : time := 1 ns);
   port (
      -- Clock and Reset
      clk      : in  sl;
      rst      : in  sl;
      -- XGMII interface
      xgmiiRxd : in  slv(31 downto 0);
      xgmiiRxc : in  slv(3 downto 0);
      -- Rx PHY Interface
      rxData   : out slv(31 downto 0);
      rxDataK  : out slv(3 downto 0));
end entity CoaXPressOverFiberBridgeRx;

architecture rtl of CoaXPressOverFiberBridgeRx is

   type StateType is (
      IDLE_S,
      HKP_S,
      DELAY_S,
      PAYLOAD_S);

   type RegType is record
      armed   : sl;
      rxData  : slv(63 downto 0);
      rxDataK : slv(7 downto 0);
      state   : StateType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      armed   => '0',
      rxData  => CXP_IDLE_C & CXP_IDLE_C,
      rxDataK => CXP_IDLE_K_C & CXP_IDLE_K_C,
      state   => IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   comb : process (r, rst, xgmiiRxc, xgmiiRxd) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Update shift register
      v.rxDataK := CXP_IDLE_K_C & r.rxDataK(7 downto 4);
      v.rxData  := CXP_IDLE_C & r.rxData(63 downto 32);

      -- State Machine
      case r.state is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Check for SOP
            if (xgmiiRxc = "0001") and (xgmiiRxd(15 downto 9) = "1000000") and (xgmiiRxd(7 downto 0) = CXPOF_START_C) then

               -- Check for HKP condition
               if (xgmiiRxd(8) = '1') then
                  -- Next State
                  v.state := HKP_S;
               else

                  -- Check for SOP
                  if (xgmiiRxd(23 downto 16) = CXP_SOP_C(7 downto 0)) then

                     -- Set flag
                     v.armed := '1';

                     -- Send SOP
                     v.rxDataK(3 downto 0) := x"F";
                     v.rxData(31 downto 0) := CXP_SOP_C;

                     -- Send type
                     v.rxDataK(7 downto 4)  := x"0";
                     v.rxData(63 downto 32) := xgmiiRxd(31 downto 24) & xgmiiRxd(31 downto 24) & xgmiiRxd(31 downto 24) & xgmiiRxd(31 downto 24);

                  end if;

                  -- Check for I/O ACK
                  if (xgmiiRxd(7 downto 0) = x"DC") and (r.armed = '1') then
                     -- Next State
                     v.state := DELAY_S;
                  else
                     -- Next State
                     v.state := PAYLOAD_S;
                  end if;

               end if;

            end if;
         ----------------------------------------------------------------------
         when HKP_S =>
            -- Send HKP
            v.rxDataK(7 downto 4)  := x"F";
            v.rxData(63 downto 32) := xgmiiRxd;
            -- Check for EOP
            if (xgmiiRxd = CXP_EOP_C) then
               -- Reset flag
               v.armed := '0';
               -- Next State
               v.state := IDLE_S;
            else
               -- Next State
               v.state := PAYLOAD_S;
            end if;
         ----------------------------------------------------------------------
         when DELAY_S =>
            -- Next State
            v.state := PAYLOAD_S;
         ----------------------------------------------------------------------
         when PAYLOAD_S =>
            -- Check for data word
            if (xgmiiRxc = "0000") then
               -- Send Type
               v.rxDataK(7 downto 4)  := x"0";
               v.rxData(63 downto 32) := xgmiiRxd;

            -- Check for EOP
            elsif (xgmiiRxc = "1100") and (xgmiiRxd(31 downto 8) = x"07_FD_00") then

               -- Check for non-zero value
               if (xgmiiRxd(7 downto 0) /= 0) then

                  -- Check for EOP
                  if (xgmiiRxd(7 downto 0) = CXP_EOP_C(7 downto 0)) then
                     -- Reset flag
                     v.armed := '0';
                  end if;

                  -- Send EOP
                  v.rxDataK(7 downto 4)  := x"F";
                  v.rxData(63 downto 32) := xgmiiRxd(7 downto 0) & xgmiiRxd(7 downto 0) & xgmiiRxd(7 downto 0) & xgmiiRxd(7 downto 0);

               else
                  -- Send IDLE
                  v.rxDataK(7 downto 4)  := CXP_IDLE_K_C;
                  v.rxData(63 downto 32) := CXP_IDLE_C;
               end if;

               -- Next State
               v.state := IDLE_S;

            -- Undefined state
            else
               -- Next State
               v.state := IDLE_S;
            end if;
      ----------------------------------------------------------------------
      end case;

      -- Outputs
      rxDataK <= r.rxDataK(3 downto 0);
      rxData  <= r.rxData(31 downto 0);

      -- Reset
      if (rst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

   end process comb;

   seq : process (clk) is
   begin
      if (rising_edge(clk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;
