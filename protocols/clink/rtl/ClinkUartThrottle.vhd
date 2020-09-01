-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: CameraLink UART TX Throttle
-- Used when the camera cannot accept new bytes until the previous command processed
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
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;
use surf.SsiPkg.all;

entity ClinkUartThrottle is
   generic (
      TPD_G : time := 1 ns);
   port (
      -- Clock and reset, 200Mhz
      intClk      : in  sl;
      intRst      : in  sl;
      -- Throttle Config (units of us)
      throttle    : in  slv(15 downto 0);
      -- Data In/Out
      sUartMaster : in  AxiStreamMasterType;
      sUartSlave  : out AxiStreamSlaveType;
      mUartMaster : out AxiStreamMasterType;
      mUartSlave  : in  AxiStreamSlaveType);
end ClinkUartThrottle;

architecture rtl of ClinkUartThrottle is

   constant TIMEOUT_C : integer := 199;  -- (200 MHz x 1 us) - 1

   constant INT_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(dataBytes => 4, tDestBits => 0);

   type RegType is record
      heartbeat   : sl;
      cnt         : natural range 0 to TIMEOUT_C;
      timeout     : sl;
      timer       : slv(15 downto 0);
      sUartSlave  : AxiStreamSlaveType;
      mUartMaster : AxiStreamMasterType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      heartbeat   => '0',
      cnt         => 0,
      timeout     => '0',
      timer       => (others => '0'),
      sUartSlave  => AXI_STREAM_SLAVE_INIT_C,
      mUartMaster => AXI_STREAM_MASTER_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : Regtype;

begin

   comb : process (intRst, mUartSlave, r, sUartMaster, throttle) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Reset the flags
      v.heartbeat  := '0';
      v.timeout    := '0';
      v.sUartSlave := AXI_STREAM_SLAVE_INIT_C;
      if mUartSlave.tReady = '1' then
         v.mUartMaster.tValid := '0';
      end if;

      -- Update the 1us heartbeat timer
      if r.cnt = 0 then
         -- Set the flag
         v.heartbeat := '1';
         -- Reset the timer
         v.cnt       := TIMEOUT_C;
      else
         -- Decrement the counter
         v.cnt := r.cnt -1;
      end if;

      -- Check the heartbeat
      if (r.heartbeat = '1') then
         -- Check for timeout
         if (r.timer = 0) then
            -- Set the flag
            v.timeout := '1';
            -- Reset the timer
            v.timer   := throttle;
         else
            -- Decrement the counter
            v.timer := r.timer - 1;
         end if;
      end if;

      -- Check if ready to move data and timeout
      if (v.mUartMaster.tValid = '0') and (sUartMaster.tValid = '1') and (r.timeout = '1') then
         -- Accept the data
         v.sUartSlave.tReady := '1';
         -- Move the data
         v.mUartMaster       := sUartMaster;
      end if;

      -- Outputs
      sUartSlave  <= v.sUartSlave;
      mUartMaster <= r.mUartMaster;

      -- Reset
      if (intRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

   end process comb;

   seq : process (intClk) is
   begin
      if rising_edge(intClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;
