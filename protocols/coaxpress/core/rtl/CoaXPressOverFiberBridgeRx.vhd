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
      rxError          : out sl;
      rxAbort          : out sl;
      rxErrorCode      : out slv(3 downto 0);
      seqValid         : out sl;
      seqData          : out slv(23 downto 0);
      seqError         : out sl;
      seqExpected      : out slv(23 downto 0);
      seqErrorExpected : out slv(23 downto 0);
      hkpValid         : out sl;
      hkpData          : out slv(31 downto 0);
      hkpEop           : out sl;
      hkpSof           : out sl;
      hkpError         : out sl;
      hkpWordCount     : out slv(7 downto 0);
      hkpKCodeMask     : out slv(3 downto 0);
      hkpKCodeValid    : out sl;
      hkpType          : out slv(3 downto 0));
end entity CoaXPressOverFiberBridgeRx;

architecture rtl of CoaXPressOverFiberBridgeRx is

   type StateType is (
      IDLE_S,
      HKP_S,
      PAYLOAD_S);

   type RegType is record
      errDet  : sl;
      rxAbort : sl;
      rxErrorCode : slv(3 downto 0);
      seqValid : sl;
      seqData : slv(23 downto 0);
      seqLocked : sl;
      seqError : sl;
      seqExpected : slv(23 downto 0);
      seqErrorExpected : slv(23 downto 0);
      hkpValid : sl;
      hkpData : slv(31 downto 0);
      hkpEop  : sl;
      hkpSof  : sl;
      hkpError : sl;
      hkpWordCount : slv(7 downto 0);
      hkpKCodeMask : slv(3 downto 0);
      hkpKCodeValid : sl;
      hkpType : slv(3 downto 0);
      rxData  : Slv32Array(1 downto 0);
      rxDataK : Slv4Array(1 downto 0);
      state   : StateType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      errDet  => '0',
      rxAbort => '0',
      rxErrorCode => CXPOF_RX_ERR_NONE_C,
      seqValid => '0',
      seqData => (others => '0'),
      seqLocked => '0',
      seqError => '0',
      seqExpected => (others => '0'),
      seqErrorExpected => (others => '0'),
      hkpValid => '0',
      hkpData => (others => '0'),
      hkpEop  => '0',
      hkpSof  => '0',
      hkpError => '0',
      hkpWordCount => (others => '0'),
      hkpKCodeMask => (others => '0'),
      hkpKCodeValid => '0',
      hkpType => CXPOF_HKP_TYPE_NONE_C,
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
      v.errDet   := '0';
      v.rxAbort  := '0';
      v.rxErrorCode := CXPOF_RX_ERR_NONE_C;
      v.seqValid := '0';
      v.seqError := '0';
      v.hkpValid := '0';
      v.hkpEop   := '0';
      v.hkpSof   := '0';
      v.hkpError := '0';

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
                  v.hkpWordCount := (others => '0');
                  -- Next State
                  v.state := HKP_S;
               else

                  -- Check if data is being overwritten
                  if (v.rxDataK(0) /= CXP_IDLE_K_C) or (v.rxData(0) /= CXP_IDLE_C) then
                     -- Set the flag
                     v.errDet      := '1';
                     v.rxErrorCode := CXPOF_RX_ERR_OVERWRITE_C;
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
               v.seqValid := '1';
               v.seqData  := xgmiiRxd(31 downto 8);
               if (r.seqLocked = '1') and (xgmiiRxd(31 downto 8) /= r.seqExpected) then
                  v.errDet      := '1';
                  v.seqError    := '1';
                  v.seqErrorExpected := r.seqExpected;
                  v.rxErrorCode := CXPOF_RX_ERR_SEQ_MISMATCH_C;
               end if;
               v.seqLocked   := '1';
               v.seqExpected := xgmiiRxd(31 downto 8) + 1;

            -- Check for lane-0 error ordered set while idle
            elsif (xgmiiRxc = CXPOF_XGMII_LANE0_CTRL_C) and (xgmiiRxd(7 downto 0) = CXPOF_ERROR_C) then

               -- Publish an error pulse even when no packet payload is active.
               v.errDet      := '1';
               v.rxAbort     := '1';
               v.rxErrorCode := CXPOF_RX_ERR_IDLE_ERROR_C;

            elsif (xgmiiRxc /= CXPOF_XGMII_ALL_CTRL_C) or (xgmiiRxd /= CXPOF_IDLE_WORD_C) then
               -- Set the flag
               v.errDet      := '1';
               v.rxErrorCode := CXPOF_RX_ERR_BAD_CONTROL_C;
            end if;
         ----------------------------------------------------------------------
         when HKP_S =>
            -- Send HKP
            v.rxDataK(1) := CXP_ALL_CTRL_K_C;
            v.rxData(1)  := xgmiiRxd;
            v.hkpValid   := '1';
            v.hkpData    := xgmiiRxd;
            v.hkpSof     := '1';
            v.hkpWordCount := r.hkpWordCount + 1;
            v.hkpKCodeMask := cxpKCodeMask(xgmiiRxd);
            v.hkpType      := cxpHkpType(xgmiiRxd);
            if (v.hkpKCodeMask = CXP_ALL_CTRL_K_C) then
               v.hkpKCodeValid := '1';
            else
               v.hkpKCodeValid := '0';
            end if;
            if (xgmiiRxc /= CXPOF_XGMII_ALL_DATA_C) then
               v.errDet      := '1';
               v.hkpError    := '1';
               v.rxErrorCode := CXPOF_RX_ERR_HKP_MALFORMED_C;
            elsif (v.hkpKCodeValid = '0') then
               v.errDet      := '1';
               v.hkpError    := '1';
               v.rxErrorCode := CXPOF_RX_ERR_HKP_BAD_K_CODE_C;
            end if;
            -- Check for EOP
            if (xgmiiRxd = CXP_EOP_C) then
               v.hkpEop := '1';
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
               v.errDet      := '1';
               v.rxAbort     := '1';
               v.rxErrorCode := CXPOF_RX_ERR_PAYLOAD_ABORT_C;
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
               v.errDet      := '1';
               v.rxErrorCode := CXPOF_RX_ERR_BAD_CONTROL_C;
               -- Next State
               v.state  := IDLE_S;
            end if;
      ----------------------------------------------------------------------
      end case;

      -- Outputs
      rxDataK <= r.rxDataK(0);
      rxData  <= r.rxData(0);
      rxError <= r.errDet;
      rxAbort <= r.rxAbort;
      rxErrorCode <= r.rxErrorCode;
      seqValid <= r.seqValid;
      seqData  <= r.seqData;
      seqError <= r.seqError;
      seqExpected <= r.seqExpected;
      seqErrorExpected <= r.seqErrorExpected;
      hkpValid <= r.hkpValid;
      hkpData  <= r.hkpData;
      hkpEop   <= r.hkpEop;
      hkpSof   <= r.hkpSof;
      hkpError <= r.hkpError;
      hkpWordCount <= r.hkpWordCount;
      hkpKCodeMask <= r.hkpKCodeMask;
      hkpKCodeValid <= r.hkpKCodeValid;
      hkpType <= r.hkpType;

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
