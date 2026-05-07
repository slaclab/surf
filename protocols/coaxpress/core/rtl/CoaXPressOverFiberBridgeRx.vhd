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
      rxDataK  : out slv(3 downto 0);
      -- Status Interface
      rxStatus : out CxpofRxStatusType);
end entity CoaXPressOverFiberBridgeRx;

architecture rtl of CoaXPressOverFiberBridgeRx is

   type StateType is (
      IDLE_S,
      HKP_S,
      PAYLOAD_S);

   type RegType is record
      status : CxpofRxStatusType;
      seqLocked : sl;
      rxData  : Slv32Array(1 downto 0);
      rxDataK : Slv4Array(1 downto 0);
      state   : StateType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      status    => CXPOF_RX_STATUS_INIT_C,
      seqLocked => '0',
      rxData    => (others => CXP_IDLE_C),
      rxDataK   => (others => CXP_IDLE_K_C),
      state     => IDLE_S);

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
      v.status.rxError   := '0';
      v.status.rxAbort  := '0';
      v.status.rxErrorCode := CXPOF_RX_ERR_NONE_C;
      v.status.seqValid := '0';
      v.status.seqError := '0';
      v.status.hkpValid := '0';
      v.status.hkpEop   := '0';
      v.status.hkpSof   := '0';
      v.status.hkpError := '0';

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
            if (xgmiiRxc = CXPOF_XGMII_LANE0_CTRL_C) and (xgmiiRxd(15 downto 9) = CXPOF_SOP_CTRL_HS_PREFIX_C) and (xgmiiRxd(7 downto 0) = CXPOF_START_C) then

               -- Check for HKP condition
               if (xgmiiRxd(8 + CXPOF_SOP_CTRL_HKP_BIT_C) = '1') then
                  v.status.hkpWordCount := (others => '0');
                  -- Next State
                  v.state := HKP_S;
               else

                  -- Check if data is being overwritten
                  if (v.rxDataK(0) /= CXP_IDLE_K_C) or (v.rxData(0) /= CXP_IDLE_C) then
                     -- Set the flag
                     v.status.rxError      := '1';
                     v.status.rxErrorCode := CXPOF_RX_ERR_OVERWRITE_C;
                  end if;

                  -- Check for SOP
                  if (xgmiiRxd(23 downto 16) = CXP_SOP_C(7 downto 0)) then

                     -- Send SOP
                     v.rxDataK(0) := CXP_ALL_CTRL_K_C;
                     v.rxData(0)  := CXP_SOP_C;

                     -- Send type
                     v.rxDataK(1) := CXP_ALL_DATA_K_C;
                     v.rxData(1)  := xgmiiRxd(31 downto 24) & xgmiiRxd(31 downto 24) & xgmiiRxd(31 downto 24) & xgmiiRxd(31 downto 24);

                  -- Check for I/O ACK
                  elsif (xgmiiRxd(23 downto 16) = CXP_IO_ACK_C(7 downto 0)) then

                     -- Send I/O ACK inductor
                     v.rxDataK(1) := CXP_ALL_CTRL_K_C;
                     v.rxData(1)  := CXP_IO_ACK_C;

                  end if;

                  -- Next State
                  v.state := PAYLOAD_S;

               end if;

            -- Check for lane-0 sequence ordered set
            elsif (xgmiiRxc = CXPOF_XGMII_LANE0_CTRL_C) and (xgmiiRxd(7 downto 0) = CXPOF_SEQ_C) then

               -- Publish the sequence data without reconstructing a CXP word.
               v.status.seqValid := '1';
               v.status.seqData  := xgmiiRxd(31 downto 8);
               if (r.seqLocked = '1') and (xgmiiRxd(31 downto 8) /= r.status.seqExpected) then
                  v.status.rxError      := '1';
                  v.status.seqError    := '1';
                  v.status.seqErrorExpected := r.status.seqExpected;
                  v.status.rxErrorCode := CXPOF_RX_ERR_SEQ_MISMATCH_C;
               end if;
               v.seqLocked   := '1';
               v.status.seqExpected := xgmiiRxd(31 downto 8) + 1;

            -- Check for lane-0 error ordered set while idle
            elsif (xgmiiRxc = CXPOF_XGMII_LANE0_CTRL_C) and (xgmiiRxd(7 downto 0) = CXPOF_ERROR_C) then

               -- Publish an error pulse even when no packet payload is active.
               v.status.rxError      := '1';
               v.status.rxAbort     := '1';
               v.status.rxErrorCode := CXPOF_RX_ERR_IDLE_ERROR_C;

            elsif (xgmiiRxc /= CXPOF_XGMII_ALL_CTRL_C) or (xgmiiRxd /= CXPOF_IDLE_WORD_C) then
               -- Set the flag
               v.status.rxError      := '1';
               v.status.rxErrorCode := CXPOF_RX_ERR_BAD_CONTROL_C;
            end if;
         ----------------------------------------------------------------------
         when HKP_S =>
            -- Send HKP
            v.rxDataK(1) := CXP_ALL_CTRL_K_C;
            v.rxData(1)  := xgmiiRxd;
            v.status.hkpValid   := '1';
            v.status.hkpData    := xgmiiRxd;
            v.status.hkpSof     := '1';
            v.status.hkpWordCount := r.status.hkpWordCount + 1;
            v.status.hkpKCodeMask := cxpKCodeMask(xgmiiRxd);
            v.status.hkpType      := cxpHkpType(xgmiiRxd);
            if (v.status.hkpKCodeMask = CXP_ALL_CTRL_K_C) then
               v.status.hkpKCodeValid := '1';
            else
               v.status.hkpKCodeValid := '0';
            end if;
            if (xgmiiRxc /= CXPOF_XGMII_ALL_DATA_C) then
               v.status.rxError      := '1';
               v.status.hkpError    := '1';
               v.status.rxErrorCode := CXPOF_RX_ERR_HKP_MALFORMED_C;
            elsif (v.status.hkpKCodeValid = '0') then
               v.status.rxError      := '1';
               v.status.hkpError    := '1';
               v.status.rxErrorCode := CXPOF_RX_ERR_HKP_BAD_K_CODE_C;
            end if;
            -- Check for EOP
            if (xgmiiRxd = CXP_EOP_C) then
               v.status.hkpEop := '1';
               -- Next State
               v.state := IDLE_S;
            else
               -- Next State
               v.state := PAYLOAD_S;
            end if;
         ----------------------------------------------------------------------
         when PAYLOAD_S =>
            -- Check for data word
            if (xgmiiRxc = CXPOF_XGMII_ALL_DATA_C) then
               -- Send Type
               v.rxDataK(1) := CXP_ALL_DATA_K_C;
               v.rxData(1)  := xgmiiRxd;

            -- Check for error ordered set
            elsif (xgmiiRxc = CXPOF_XGMII_LANE0_CTRL_C) and (xgmiiRxd(7 downto 0) = CXPOF_ERROR_C) then

               -- Abort the active packet without synthesizing a CXP EOP.
               v.status.rxError      := '1';
               v.status.rxAbort     := '1';
               v.status.rxErrorCode := CXPOF_RX_ERR_PAYLOAD_ABORT_C;
               v.state       := IDLE_S;

            -- Check for EOP
            elsif (xgmiiRxc = CXPOF_XGMII_LANE2_3_CTRL_C) and (xgmiiRxd(31 downto 8) = CXPOF_TERM_SUFFIX_C) then

               -- Check for non-zero value
               if (xgmiiRxd(7 downto 0) /= CXPOF_RESERVED_BYTE_C) then
                  -- Send EOP
                  v.rxDataK(1) := CXP_ALL_CTRL_K_C;
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
               v.status.rxError      := '1';
               v.status.rxErrorCode := CXPOF_RX_ERR_BAD_CONTROL_C;
               -- Next State
               v.state  := IDLE_S;
            end if;
      ----------------------------------------------------------------------
      end case;

      -- Outputs
      rxDataK <= r.rxDataK(0);
      rxData  <= r.rxData(0);
      rxStatus <= r.status;

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
