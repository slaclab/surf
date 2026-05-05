-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing status wrapper for CoaXPressOverFiberBridgeRx
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

library surf;
use surf.StdRtlPkg.all;
use surf.CoaXPressPkg.all;

entity CoaXPressOverFiberBridgeRxStatusWrapper is
   port (
      -- Clock and Reset
      clk              : in  sl;
      rst              : in  sl;
      -- XGMII interface
      xgmiiRxd         : in  slv(31 downto 0);
      xgmiiRxc         : in  slv(3 downto 0);
      -- Rx PHY Interface
      rxData           : out slv(31 downto 0);
      rxDataK          : out slv(3 downto 0);
      -- Flattened Status Interface
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
end entity CoaXPressOverFiberBridgeRxStatusWrapper;

architecture mapping of CoaXPressOverFiberBridgeRxStatusWrapper is

   signal rxStatus : CxpofRxStatusType := CXPOF_RX_STATUS_INIT_C;

begin

   rxError          <= rxStatus.rxError;
   rxAbort          <= rxStatus.rxAbort;
   rxErrorCode      <= rxStatus.rxErrorCode;
   seqValid         <= rxStatus.seqValid;
   seqData          <= rxStatus.seqData;
   seqError         <= rxStatus.seqError;
   seqExpected      <= rxStatus.seqExpected;
   seqErrorExpected <= rxStatus.seqErrorExpected;
   hkpValid         <= rxStatus.hkpValid;
   hkpData          <= rxStatus.hkpData;
   hkpEop           <= rxStatus.hkpEop;
   hkpSof           <= rxStatus.hkpSof;
   hkpError         <= rxStatus.hkpError;
   hkpWordCount     <= rxStatus.hkpWordCount;
   hkpKCodeMask     <= rxStatus.hkpKCodeMask;
   hkpKCodeValid    <= rxStatus.hkpKCodeValid;
   hkpType          <= rxStatus.hkpType;

   U_DUT : entity surf.CoaXPressOverFiberBridgeRx
      generic map (
         TPD_G => 1 ns)
      port map (
         -- Clock and Reset
         clk      => clk,
         rst      => rst,
         -- XGMII interface
         xgmiiRxd => xgmiiRxd,
         xgmiiRxc => xgmiiRxc,
         -- Rx PHY Interface
         rxData   => rxData,
         rxDataK  => rxDataK,
         -- Status Interface
         rxStatus => rxStatus);

end architecture mapping;
