-------------------------------------------------------------------------------
-- Title      : CXP Over Fiber Protocol: http://jiia.org/wp-content/themes/jiia/pdf/standard_dl/coaxpress/CXPR-008-2021.pdf
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: CoaXPress Over Fiber RX Bridge
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
      PAYLOAD_S);

   type RegType is record
      errDet  : sl;
      rxData  : Slv32Array(1 downto 0);
      rxDataK : Slv4Array(1 downto 0);
      state   : StateType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      errDet  => '0',
      rxData  => (others => CXP_IDLE_C),
      rxDataK => (others => CXP_IDLE_K_C),
      state   => IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   -- attribute dont_touch      : string;
   -- attribute dont_touch of r : signal is "TRUE";

begin

   comb : process (r, rst, xgmiiRxc, xgmiiRxd) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Reset strobe
      v.errDet := '0';

      -- Update shift register
      v.rxDataK(1) := CXP_IDLE_K_C;
      v.rxDataK(0) := r.rxDataK(1);
      v.rxData(1)  := CXP_IDLE_C;
      v.rxData(0)  := r.rxData(1);

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

                  -- Check if data is being overwritten
                  if (v.rxDataK(0) /= CXP_IDLE_K_C) or (v.rxData(0) /= CXP_IDLE_C) then
                     -- Set the flag
                     v.errDet := '1';
                  end if;

                  -- Check for SOP
                  if (xgmiiRxd(23 downto 16) = CXP_SOP_C(7 downto 0)) then

                     -- Send SOP
                     v.rxDataK(0) := x"F";
                     v.rxData(0)  := CXP_SOP_C;

                     -- Send type
                     v.rxDataK(1) := x"0";
                     v.rxData(1)  := xgmiiRxd(31 downto 24) & xgmiiRxd(31 downto 24) & xgmiiRxd(31 downto 24) & xgmiiRxd(31 downto 24);

                  -- Check for I/O ACK
                  elsif (xgmiiRxd(23 downto 16) = CXP_IO_ACK_C(7 downto 0)) then

                     -- Send I/O ACK inductor
                     v.rxDataK(1) := x"F";
                     v.rxData(1)  := CXP_IO_ACK_C;

                  end if;

                  -- Next State
                  v.state := PAYLOAD_S;

               end if;

            elsif (xgmiiRxc /= x"F") or (xgmiiRxd /= x"07_07_07_07") then
               -- Set the flag
               v.errDet := '1';
            end if;
         ----------------------------------------------------------------------
         when HKP_S =>
            -- Send HKP
            v.rxDataK(1) := x"F";
            v.rxData(1)  := xgmiiRxd;
            -- Check for EOP
            if (xgmiiRxd = CXP_EOP_C) then
               -- Next State
               v.state := IDLE_S;
            else
               -- Next State
               v.state := PAYLOAD_S;
            end if;
         ----------------------------------------------------------------------
         when PAYLOAD_S =>
            -- Check for data word
            if (xgmiiRxc = "0000") then
               -- Send Type
               v.rxDataK(1) := x"0";
               v.rxData(1)  := xgmiiRxd;

            -- Check for EOP
            elsif (xgmiiRxc = "1100") and (xgmiiRxd(31 downto 8) = x"07_FD_00") then

               -- Check for non-zero value
               if (xgmiiRxd(7 downto 0) /= 0) then
                  -- Send EOP
                  v.rxDataK(1) := x"F";
                  v.rxData(1)  := xgmiiRxd(7 downto 0) & xgmiiRxd(7 downto 0) & xgmiiRxd(7 downto 0) & xgmiiRxd(7 downto 0);

               else
                  -- Send IDLE
                  v.rxDataK(1) := CXP_IDLE_K_C;
                  v.rxData(1)  := CXP_IDLE_C;
               end if;

               -- Next State
               v.state := IDLE_S;

            -- Undefined state
            else
               -- Set the flag
               v.errDet := '1';
               -- Next State
               v.state  := IDLE_S;
            end if;
      ----------------------------------------------------------------------
      end case;

      -- Outputs
      rxDataK <= r.rxDataK(0);
      rxData  <= r.rxData(0);

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
