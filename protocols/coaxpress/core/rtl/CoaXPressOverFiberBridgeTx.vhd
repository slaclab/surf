-------------------------------------------------------------------------------
-- Title      : CXP Over Fiber Protocol: http://jiia.org/wp-content/themes/jiia/pdf/standard_dl/coaxpress/CXPR-008-2021.pdf
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: CoaXPress TX FSM
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

entity CoaXPressOverFiberBridgeTx is
   generic (
      TPD_G : time := 1 ns);
   port (
      -- Clock and Reset
      clk      : in  sl;
      rst      : in  sl;
      -- XGMII interface
      xgmiiTxd : out slv(31 downto 0);
      xgmiiTxc : out slv(3 downto 0);
      -- TX PHY Interface
      txData   : in  slv(31 downto 0);
      txDataK  : in  slv(3 downto 0));
end entity CoaXPressOverFiberBridgeTx;

architecture rtl of CoaXPressOverFiberBridgeTx is

   type StateType is (
      IDLE_S,
      SOP_S,
      PAYLOAD_S,
      TRIG_IPG_S,
      TRIG_SOP_S,
      TRIG_WORD_S);

   type RegType is record
      txData   : slv(31 downto 0);
      xgmiiTxd : slv(31 downto 0);
      xgmiiTxc : slv(3 downto 0);
      state    : StateType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      txData   => (others => '0'),
      xgmiiTxd => CXPOF_IDLE_WORD_C,
      xgmiiTxc => x"F",
      state    => IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   comb : process (r, rst, txData, txDataK) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- State Machine
      case r.state is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Send the start word
            v.xgmiiTxc := x"F";
            v.xgmiiTxd := CXPOF_IDLE_WORD_C;

            -- Check for Start of packet indication
            if (txDataK = x"F") and ((txData = CXP_SOP_C) or (txData = CXP_TRIG_C)) then
               -- Save delayed copy
               v.txData := txData;
               -- Next State
               v.state  := SOP_S;
            end if;
         ----------------------------------------------------------------------
         when SOP_S =>
            -- Set the char marker
            v.xgmiiTxc := "0001";

            -- Lane[0] = Start[7:0]
            v.xgmiiTxd(0+7 downto 0+0) := CXPOF_START_C;

            -- Lane[1] = SopCtrl[7] - Packet type: “1” => High-speed packet
            v.xgmiiTxd(8+7) := '1';

            -- Lane[1] = SopCtrl[6:1] - Reserved
            v.xgmiiTxd(8+6 downto 8+4) := "000000";

            -- Lane[1] = SopCtrl[0] - Next word type: When "0" => HDP, When "1" => HKP
            v.xgmiiTxd(8+0) := txDataK(0);

            -- Lane[2] = SopData0[7:0]
            v.xgmiiTxd(16+7 downto 16+0) := r.txData(7 downto 0);  -- use delayed copy

            -- Lane[3] = SopData1[7:0]
            v.xgmiiTxd(24+7 downto 24+0) := txData(7 downto 0);

            -- Next State
            v.state := PAYLOAD_S;
         ----------------------------------------------------------------------
         when PAYLOAD_S =>
            -- Check if moving payload data
            if (txDataK = x"0") then
               -- Move the data
               v.xgmiiTxd := txData;
               v.xgmiiTxc := x"0";
            else
               -- Set the char marker
               v.xgmiiTxc := "1100";

               -- Lane[0] = EopData0[7:0]
               if (txData = CXP_EOP_C) then
                  v.xgmiiTxd(0+7 downto 0+0) := txData(7 downto 0);
               else
                  v.xgmiiTxd(0+7 downto 0+0) := x"00";
               end if;

               -- Lane[1] = Reserved
               v.xgmiiTxd(8+7 downto 8+0) := x"00";

               -- Lane[2] = Terminate
               v.xgmiiTxd(16+7 downto 16+0) := CXPOF_TERM_C;

               -- Lane[3] = Terminate
               v.xgmiiTxd(24+7 downto 24+0) := CXPOF_IDLE_C;

               -- Check for end of packet
               if (txData = CXP_TRIG_C) then
                  -- Save delayed copy of the byte
                  v.txData := txData(7 downto 0);
                  -- Next State
                  v.state  := TRIG_IPG_S;
               else
                  -- Next State
                  v.state := IDLE_S;
               end if;

            end if;
         ----------------------------------------------------------------------
         when TRIG_IPG_S =>
            -- Send the start word
            v.xgmiiTxc := x"F";
            v.xgmiiTxd := CXPOF_IDLE_WORD_C;
            -- Save the delay word
            v.txData   := txData;
            -- Next State
            v.state    := TRIG_SOP_S;
         ----------------------------------------------------------------------
         when TRIG_SOP_S =>
            -- Send the SOP
            v.xgmiiTxc := "0001";
            v.xgmiiTxd := r.txData(7 downto 0) & CXP_TRIG_C(7 downto 0) & x"80" & CXPOF_START_C;
            -- Save the TrgN word
            v.txData   := txData;
            -- Next State
            v.state    := TRIG_WORD_S;
         ----------------------------------------------------------------------
         when TRIG_WORD_S =>
            -- Send the TrgN word
            v.xgmiiTxc := "0000";
            v.xgmiiTxd := r.txData;
            -- Next State
            v.state    := PAYLOAD_S;
      ----------------------------------------------------------------------
      end case;

      -- Outputs
      xgmiiTxd <= r.xgmiiTxd;
      xgmiiTxc <= r.xgmiiTxc;

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
