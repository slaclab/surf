-------------------------------------------------------------------------------
-- Title      : CXP Over Fiber Protocol: http://jiia.org/wp-content/themes/jiia/pdf/standard_dl/coaxpress/CXPR-008-2021.pdf
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: CoaXPress Over Fiber TX Bridge
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
      clk        : in  sl;
      rst        : in  sl;
      -- XGMII interface
      xgmiiTxd   : out slv(31 downto 0);
      xgmiiTxc   : out slv(3 downto 0);
      -- TX PHY Interface
      txLsValid  : in  sl;
      txLsData   : in  slv(7 downto 0);
      txLsDataK  : in  sl;
      txLsRate   : in  sl;
      txLsLaneEn : in  slv(3 downto 0);
      txHsEnable : in  sl;
      txHsData   : in  slv(31 downto 0);
      txHsDataK  : in  slv(3 downto 0));
end entity CoaXPressOverFiberBridgeTx;

architecture rtl of CoaXPressOverFiberBridgeTx is

   type StateType is (
      IDLE_S,
      LS_SOP_S,
      HS_SOP_S,
      LS_PAYLOAD_S,
      HS_PAYLOAD_S,
      HS_TRIG_IPG_S,
      HS_TRIG_SOP_S,
      HS_TRIG_WORD_S);

   type RegType is record
      update     : sl;
      cnt        : natural range 0 to 3;
      txLsLaneEn : slv(3 downto 0);
      txLsRate   : sl;
      txHsEnable : sl;
      txLsData   : slv(7 downto 0);
      txLsDataK  : sl;
      txHsData   : slv(31 downto 0);
      xgmiiTxd   : slv(31 downto 0);
      xgmiiTxc   : slv(3 downto 0);
      state      : StateType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      update     => '1',
      cnt        => 0,
      txLsLaneEn => (others => '0'),
      txLsRate   => '0',
      txHsEnable => '0',
      txLsData   => (others => '0'),
      txLsDataK  => '0',
      txHsData   => (others => '0'),
      xgmiiTxd   => CXPOF_IDLE_WORD_C,
      xgmiiTxc   => x"F",
      state      => IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   attribute dont_touch      : string;
   attribute dont_touch of r : signal is "TRUE";

begin

   comb : process (r, rst, txHsData, txHsDataK, txHsEnable, txLsData,
                   txLsDataK, txLsLaneEn, txLsRate, txLsValid) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Check for change in low speed rate
      v.txLsRate := txLsRate;
      if (r.txLsRate /= v.txLsRate) then
         v.update := '1';
      end if;

      -- Check for change in low speed rate
      v.txLsLaneEn := txLsLaneEn;
      if (r.txLsLaneEn /= v.txLsLaneEn) then
         v.update := '1';
      end if;

      -- Check for change in high speed enable
      v.txHsEnable := txHsEnable;
      if (r.txHsEnable /= v.txHsEnable) then
         v.update := '1';
      end if;

      -- State Machine
      case r.state is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Send the start word
            v.xgmiiTxc := x"F";
            v.xgmiiTxd := CXPOF_IDLE_WORD_C;

            -- Check for low speed packet
            if (r.update = '1') or (r.txHsEnable = '0') then

               -- Check for new low speed byte
               if (txLsValid = '1') then
                  -- Save copy of data
                  v.txLsData  := txLsData;
                  v.txLsDataK := txLsDataK;
                  -- Next State
                  v.state     := LS_SOP_S;
               end if;

            -- Check high speed packet
            else

               -- Check for Start of packet indication
               if (txHsDataK = x"F") and ((txHsData = CXP_SOP_C) or (txHsData = CXP_TRIG_C)) then
                  -- Save delayed copy
                  v.txHsData := txHsData;
                  -- Next State
                  v.state    := HS_SOP_S;
               end if;

            end if;
         ----------------------------------------------------------------------
         when LS_SOP_S =>
            -- Set the char marker
            v.xgmiiTxc := "0001";

            -- Lane[0] = Start[7:0]
            v.xgmiiTxd(0+7 downto 0+0) := CXPOF_START_C;

            -- Reset the flag
            v.update := '0';

            -- Lane[1] = SopCtrl[7] - Packet type: "0" => Low-speed packet
            v.xgmiiTxd(8+7) := '0';

            -- Lane[1] = SopCtrl[6:4] - Reserved
            v.xgmiiTxd(8+6 downto 8+4) := "000";

            -- Lane[1] = SopCtrl[3] - Update flag
            v.xgmiiTxd(8+3) := r.update;

            -- Lane[1] = SopCtrl[2] - Reserved
            v.xgmiiTxd(8+2) := '0';

            -- Lane[1] = SopCtrl[1] - Low-speed rate: When '0'=> 20.83 Mbps, When '1'=> 41.6 Mbps
            v.xgmiiTxd(8+1) := r.txLsRate;

            -- Lane[1] = SopCtrl[0] - High-speed upconnection state
            v.xgmiiTxd(8+0) := r.txHsEnable;

            -- Lane[2] = SopData0[7:0] - reserved
            v.xgmiiTxd(16+7 downto 16+0) := x"00";

            -- Lane[3] = SopData1[7:0] - reserved
            v.xgmiiTxd(24+7 downto 24+0) := x"00";

            -- Next State
            v.state := LS_PAYLOAD_S;
         ----------------------------------------------------------------------
         when HS_SOP_S =>
            -- Set the char marker
            v.xgmiiTxc := "0001";

            -- Lane[0] = Start[7:0]
            v.xgmiiTxd(0+7 downto 0+0) := CXPOF_START_C;

            -- Lane[1] = SopCtrl[7] - Packet type: "1" => High-speed packet
            v.xgmiiTxd(8+7) := '1';

            -- Lane[1] = SopCtrl[6:1] - Reserved
            v.xgmiiTxd(8+6 downto 8+1) := "000000";

            -- Lane[1] = SopCtrl[0] - Next word type: When "0" => HDP, When "1" => HKP
            v.xgmiiTxd(8+0) := txHsDataK(0);

            -- Lane[2] = SopData0[7:0] - Embedded K-code (replaces a CoaXPress K-code replicated four times)
            v.xgmiiTxd(16+7 downto 16+0) := r.txHsData(7 downto 0);  -- use delayed copy

            -- Lane[3] = SopData1[7:0]- Embedded Data (replaces a CoaXPress byte replicated four times)
            v.xgmiiTxd(24+7 downto 24+0) := txHsData(7 downto 0);

            -- Next State
            v.state := HS_PAYLOAD_S;
         ----------------------------------------------------------------------
         when LS_PAYLOAD_S =>
            -- Increment the counter
            v.cnt := r.cnt + 1;

            -- Reset the data and char bus
            v.xgmiiTxc := (others => '0');
            v.xgmiiTxd := (others => '0');

            -- Check for LS Stream
            if (r.cnt < 2) then

               -- Loop through the channels
               for i in 0 to 1 loop

                  -- Check if LS Stream is enabled
                  if (r.txLsLaneEn(2*r.cnt+i) = '1') then

                     -- LS CTRL
                     if (r.txLsDataK = '0') then
                        v.xgmiiTxd(16*i+7 downto 16*i) := x"01";  -- data
                     else
                        v.xgmiiTxd(16*i+7 downto 16*i) := x"02";  -- k-code
                     end if;

                     -- LS Char
                     v.xgmiiTxd(16*i+15 downto 16*i+8) := r.txLsData;

                  end if;

               end loop;

            else
               -- Reset the counter
               v.cnt := 0;

               -- Set the char marker
               v.xgmiiTxc := "1100";

               -- Lane[0] = Reserved
               v.xgmiiTxd(7 downto 0) := x"00";

               -- Lane[1] = Reserved
               v.xgmiiTxd(15 downto 8) := x"00";

               -- Lane[2] = Terminate
               v.xgmiiTxd(23 downto 16) := CXPOF_TERM_C;

               -- Lane[3] = Terminate
               v.xgmiiTxd(31 downto 24) := CXPOF_IDLE_C;

               -- Next State
               v.state := IDLE_S;

            end if;
         ----------------------------------------------------------------------
         when HS_PAYLOAD_S =>
            -- Check if moving payload data
            if (txHsDataK = x"0") then
               -- Move the data
               v.xgmiiTxd := txHsData;
               v.xgmiiTxc := x"0";
            else
               -- Set the char marker
               v.xgmiiTxc := "1100";

               -- Lane[0] = EopData0[7:0]
               if (txHsData = CXP_EOP_C) then
                  v.xgmiiTxd(0+7 downto 0+0) := txHsData(7 downto 0);
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
               if (txHsData = CXP_TRIG_C) then
                  -- Save delayed copy
                  v.txHsData := txHsData;
                  -- Next State
                  v.state    := HS_TRIG_IPG_S;
               else
                  -- Next State
                  v.state := IDLE_S;
               end if;

            end if;
         ----------------------------------------------------------------------
         when HS_TRIG_IPG_S =>
            -- Send the start word
            v.xgmiiTxc := x"F";
            v.xgmiiTxd := CXPOF_IDLE_WORD_C;
            -- Save the delay word
            v.txHsData := txHsData;
            -- Next State
            v.state    := HS_TRIG_SOP_S;
         ----------------------------------------------------------------------
         when HS_TRIG_SOP_S =>
            -- Send the SOP
            v.xgmiiTxc := "0001";
            v.xgmiiTxd := r.txHsData(7 downto 0) & CXP_TRIG_C(7 downto 0) & x"80" & CXPOF_START_C;
            -- Save the TrgN word
            v.txHsData := txHsData;
            -- Next State
            v.state    := HS_TRIG_WORD_S;
         ----------------------------------------------------------------------
         when HS_TRIG_WORD_S =>
            -- Send the TrgN word
            v.xgmiiTxc := "0000";
            v.xgmiiTxd := r.txHsData;
            -- Next State
            v.state    := HS_PAYLOAD_S;
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
