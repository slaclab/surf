-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Thin servo numerical and command-lifecycle verification adapter
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
use ieee.numeric_std.all;

library surf;
use surf.StdRtlPkg.all;
use surf.PtpPkg.all;

entity PtpServoWrapper is
   port (
      clk           : in  sl;
      rst           : in  sl;
      cancel        : in  sl;
      ticks         : in  slv(63 downto 0);
      sampleTicks   : in  slv(63 downto 0);
      isDelay       : in  sl;
      forwardValue  : in  slv(127 downto 0);
      delayValue    : in  slv(127 downto 0);
      ratio         : in  slv(63 downto 0);
      inputValid    : in  sl;
      inputReady    : out sl;
      commandValid  : out sl;
      commandReady  : in  sl;
      commandAck    : in  sl;
      commandError  : in  sl;
      commandKind   : out slv(2 downto 0);
      commandRate   : out slv(63 downto 0);
      cancelCommand : out sl;
      expireTime    : out sl;
      servoState    : out slv(2 downto 0);
      filteredDelay : out slv(127 downto 0);
      offsetValue   : out slv(127 downto 0);
      ratePpb       : out slv(63 downto 0);
      filterCount   : out slv(2 downto 0);
      rejectedCount : out slv(31 downto 0));
end entity PtpServoWrapper;

architecture rtl of PtpServoWrapper is

   signal config      : PtpConfigType := PTP_CONFIG_INIT_C;
   signal status      : PtpPhcStatusType := PTP_PHC_STATUS_INIT_C;
   signal measurement : PtpMeasurementType := PTP_MEASUREMENT_INIT_C;
   signal command     : PtpPhcCommandType;

begin

   config.servoEnable        <= '1';
   config.syncTimeout        <= x"7FFFFFFFFFFFFFFF";
   config.maxDelayAge        <= x"7FFFFFFFFFFFFFFF";
   config.holdoverTimeout    <= x"000000000EE6B280";
   config.associationTimeout <= x"7FFFFFFFFFFFFFFF";
   config.minSampleTicks     <= x"0000000000000001";
   config.maxSampleTicks     <= x"7FFFFFFFFFFFFFFF";
   status.ticks              <= ticks;
   status.timeValid          <= '1';
   measurement.ticks         <= sampleTicks;
   measurement.isDelay       <= isDelay;
   measurement.forward       <= forwardValue;
   measurement.delayValue    <= delayValue;
   measurement.ratio         <= ratio;
   measurement.ratioValid    <= '1';
   commandKind               <= command.kind;
   commandRate               <= command.rate;

   U_DUT : entity surf.PtpServo
      generic map (
         CLK_FREQ_G => 125000000)
      port map (
         clk              => clk,             -- [in]
         rst              => rst,             -- [in]
         cancel           => cancel,          -- [in]
         config           => config,          -- [in]
         phcStatus        => status,          -- [in]
         measurement      => measurement,     -- [in]
         measurementValid => inputValid,      -- [in]
         measurementReady => inputReady,      -- [out]
         command          => command,         -- [out]
         commandValid     => commandValid,    -- [out]
         commandReady     => commandReady,    -- [in]
         commandAck       => commandAck,      -- [in]
         commandError     => commandError,    -- [in]
         cancelCommand    => cancelCommand,   -- [out]
         expireTime       => expireTime,      -- [out]
         servoState       => servoState,      -- [out]
         filteredDelay    => filteredDelay,   -- [out]
         offsetValue      => offsetValue,     -- [out]
         ratePpb          => ratePpb,         -- [out]
         filterCount      => filterCount,     -- [out]
         rejectedCount    => rejectedCount);  -- [out]

end architecture rtl;
