-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Reusable simulation-time payload bandwidth pacer for AXI Stream
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
use surf.AxiStreamPkg.all;

entity RogueTcpStreamPacer is
   generic (
      TPD_G               : time                := 1 ns;
      RST_POLARITY_G      : sl                  := '1';
      RST_ASYNC_G         : boolean             := false;
      AXIS_CONFIG_G       : AxiStreamConfigType;
      AXIS_CLK_FREQ_G     : real                := 0.0;  -- Units of Hz; required when pacing is enabled
      PAYLOAD_RATE_G      : real                := 0.0);  -- Payload bits/s; zero bypasses pacing
   port (
      -- Clock and reset
      axisClk     : in  sl;
      axisRst     : in  sl;
      -- Slave port
      sAxisMaster : in  AxiStreamMasterType;
      sAxisSlave  : out AxiStreamSlaveType;
      -- Master port
      mAxisMaster : out AxiStreamMasterType;
      mAxisSlave  : in  AxiStreamSlaveType);
end entity RogueTcpStreamPacer;

architecture rtl of RogueTcpStreamPacer is

   -- Fractional-byte credit avoids real-valued runtime state.  At the maximum
   -- supported 128-byte width this scale keeps all arithmetic within the
   -- minimum VHDL integer range while providing approximately kilobit/s rate
   -- resolution at typical simulation clocks.
   constant CREDIT_SCALE_C : positive := 2**20;
   constant MAX_CREDIT_C   : positive := AXIS_CONFIG_G.TDATA_BYTES_C*CREDIT_SCALE_C;

   function rateIncrement return natural is
      variable scaled : real;
   begin
      if (PAYLOAD_RATE_G <= 0.0) or (AXIS_CLK_FREQ_G <= 0.0) then
         return 0;
      end if;

      scaled := (PAYLOAD_RATE_G*CREDIT_SCALE_C)/(8.0*AXIS_CLK_FREQ_G);
      if (scaled >= real(MAX_CREDIT_C)) then
         return MAX_CREDIT_C;
      end if;

      return natural(integer(scaled+0.5));
   end function rateIncrement;

   constant RATE_INCREMENT_C : natural := rateIncrement;

   type RegType is record
      credit : natural range 0 to MAX_CREDIT_C;
   end record RegType;

   constant REG_INIT_C : RegType := (
      credit => MAX_CREDIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   assert (PAYLOAD_RATE_G >= 0.0)
      report "RogueTcpStreamPacer: PAYLOAD_RATE_G must be nonnegative"
      severity failure;

   assert (PAYLOAD_RATE_G = 0.0) or (AXIS_CLK_FREQ_G > 0.0)
      report "RogueTcpStreamPacer: AXIS_CLK_FREQ_G must be positive when pacing is enabled"
      severity failure;

   assert (PAYLOAD_RATE_G = 0.0) or
          (PAYLOAD_RATE_G <= 8.0*real(AXIS_CONFIG_G.TDATA_BYTES_C)*AXIS_CLK_FREQ_G)
      report "RogueTcpStreamPacer: PAYLOAD_RATE_G exceeds the AXI Stream interface ceiling"
      severity failure;

   assert (PAYLOAD_RATE_G = 0.0) or (RATE_INCREMENT_C > 0)
      report "RogueTcpStreamPacer: PAYLOAD_RATE_G is below the fixed-point resolution"
      severity failure;

   comb : process (axisRst, mAxisSlave, r, sAxisMaster) is
      variable v         : RegType;
      variable available : natural range 0 to MAX_CREDIT_C;
      variable byteCount : natural;
      variable cost      : natural range 0 to MAX_CREDIT_C;
   begin
      v := r;

      -- The payload and sidebands remain combinationally connected.  Gating
      -- TVALID/TREADY delays handshakes in simulated time while retaining the
      -- AXI Stream requirement that a stalled transfer remain stable.
      mAxisMaster        <= sAxisMaster;
      mAxisMaster.tValid <= '0';
      sAxisSlave         <= AXI_STREAM_SLAVE_INIT_C;

      if (PAYLOAD_RATE_G = 0.0) then
         mAxisMaster        <= sAxisMaster;
         sAxisSlave         <= mAxisSlave;
         v.credit           := MAX_CREDIT_C;
      else
         available := minimum(MAX_CREDIT_C, r.credit+RATE_INCREMENT_C);
         byteCount := 0;
         cost      := 0;
         v.credit  := available;

         if (sAxisMaster.tValid = '1') then
            byteCount := getTKeep(sAxisMaster.tKeep, AXIS_CONFIG_G);
            assert (byteCount <= AXIS_CONFIG_G.TDATA_BYTES_C)
               report "RogueTcpStreamPacer: TKEEP byte count exceeds the configured data width"
               severity failure;
            if (byteCount <= AXIS_CONFIG_G.TDATA_BYTES_C) then
               cost := byteCount*CREDIT_SCALE_C;
            end if;
         end if;

         if (cost <= available) then
            mAxisMaster.tValid <= sAxisMaster.tValid;
            sAxisSlave.tReady  <= mAxisSlave.tReady;

            if (sAxisMaster.tValid = '1') and (mAxisSlave.tReady = '1') then
               v.credit := available-cost;
            end if;
         end if;
      end if;

      if (RST_ASYNC_G = false) and (axisRst = RST_POLARITY_G) then
         v := REG_INIT_C;
      end if;

      rin <= v;
   end process comb;

   seq : process (axisClk, axisRst) is
   begin
      if (RST_ASYNC_G) and (axisRst = RST_POLARITY_G) then
         r <= REG_INIT_C after TPD_G;
      elsif rising_edge(axisClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end architecture rtl;
