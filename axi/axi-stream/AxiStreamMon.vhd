-------------------------------------------------------------------------------
-- File       : AxiStreamMon.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-07-14
-- Last update: 2017-11-16
-------------------------------------------------------------------------------
-- Description: AXI Stream Monitor Module
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

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;

entity AxiStreamMon is
   generic (
      TPD_G           : time                := 1 ns;
      COMMON_CLK_G    : boolean             := false;  -- true if axisClk = statusClk
      AXIS_CLK_FREQ_G : real                := 156.25E+6;  -- units of Hz
      AXIS_CONFIG_G   : AxiStreamConfigType := AXI_STREAM_CONFIG_INIT_C);
   port (
      -- AXIS Stream Interface
      axisClk      : in  sl;
      axisRst      : in  sl;
      axisMaster   : in  AxiStreamMasterType;
      axisSlave    : in  AxiStreamSlaveType;
      -- Status Interface
      statusClk    : in  sl;
      statusRst    : in  sl;
      frameRate    : out slv(31 downto 0);             -- units of Hz
      frameRateMax : out slv(31 downto 0);             -- units of Hz
      frameRateMin : out slv(31 downto 0);             -- units of Hz
      bandwidth    : out slv(63 downto 0);             -- units of Byte/s
      bandwidthMax : out slv(63 downto 0);             -- units of Byte/s
      bandwidthMin : out slv(63 downto 0));            -- units of Byte/s
end AxiStreamMon;

architecture rtl of AxiStreamMon is

   constant TKEEP_C   : natural := AXIS_CONFIG_G.TDATA_BYTES_C;
   constant TIMEOUT_C : natural := getTimeRatio(AXIS_CLK_FREQ_G, 1.0)-1;

   type RegType is record
      armed        : sl;
      frameSent    : sl;
      tValid       : sl;
      tKeep        : slv(15 downto 0);
      updated      : sl;
      updateStat   : sl;
      timer        : natural range 0 to TIMEOUT_C;
      accum        : slv(39 downto 0);
      bandwidth    : slv(39 downto 0);
      bandwidthMax : slv(39 downto 0);
      bandwidthMin : slv(39 downto 0);
   end record;

   constant REG_INIT_C : RegType := (
      armed        => '0',
      frameSent    => '0',
      tValid       => '0',
      tKeep        => (others => '0'),
      updated      => '0',
      updateStat   => '0',
      timer        => 0,
      accum        => (others => '0'),
      bandwidth    => (others => '0'),
      bandwidthMax => (others => '0'),
      bandwidthMin => (others => '0'));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal bw    : slv(39 downto 0);
   signal bwMax : slv(39 downto 0);
   signal bwMin : slv(39 downto 0);

   signal frameRateUpdate  : sl;
   signal frameRateSync    : slv(31 downto 0);
   signal frameRateMaxSync : slv(31 downto 0);
   signal frameRateMinSync : slv(31 downto 0);

   -- attribute dont_touch          : string;
   -- attribute dont_touch of r     : signal is "true";   

begin

   U_packetRate : entity work.SyncTrigRate
      generic map (
         TPD_G          => TPD_G,
         COMMON_CLK_G   => true,
         REF_CLK_FREQ_G => AXIS_CLK_FREQ_G,  -- units of Hz
         REFRESH_RATE_G => 1.0,              -- units of Hz
         CNT_WIDTH_G    => 32)               -- Counters' width
      port map (
         -- Trigger Input (locClk domain)
         trigIn          => r.frameSent,
         -- Trigger Rate Output (locClk domain)
         trigRateUpdated => frameRateUpdate,
         trigRateOut     => frameRateSync,
         trigRateOutMax  => frameRateMaxSync,
         trigRateOutMin  => frameRateMinSync,
         -- Clocks
         locClk          => axisClk,
         locRst          => axisRst,
         refClk          => axisClk,
         refRst          => axisRst);

   SyncOut_frameRate : entity work.SynchronizerFifo
      generic map (
         TPD_G        => TPD_G,
         COMMON_CLK_G => COMMON_CLK_G,
         DATA_WIDTH_G => 32)
      port map (
         wr_clk => axisClk,
         wr_en  => frameRateUpdate,
         din    => frameRateSync,
         rd_clk => statusClk,
         dout   => frameRate);

   SyncOut_frameRateMax : entity work.SynchronizerFifo
      generic map (
         TPD_G        => TPD_G,
         COMMON_CLK_G => COMMON_CLK_G,
         DATA_WIDTH_G => 32)
      port map (
         wr_clk => axisClk,
         wr_en  => frameRateUpdate,
         din    => frameRateMaxSync,
         rd_clk => statusClk,
         dout   => frameRateMax);

   SyncOut_frameRateMin : entity work.SynchronizerFifo
      generic map (
         TPD_G        => TPD_G,
         COMMON_CLK_G => COMMON_CLK_G,
         DATA_WIDTH_G => 32)
      port map (
         wr_clk => axisClk,
         wr_en  => frameRateUpdate,
         din    => frameRateMinSync,
         rd_clk => statusClk,
         dout   => frameRateMin);

   comb : process (axisMaster, axisRst, axisSlave, r) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Reset strobing signals
      v.tValid     := '0';
      v.updated    := '0';
      v.updateStat := '0';

      -- Check for end of frame
      v.frameSent := axisMaster.tValid and axisMaster.tLast and axisSlave.tReady;

      -- Check for data moving
      if (axisMaster.tValid = '1') and (axisSlave.tReady = '1') then
         -- Set the flag
         v.tValid                    := '1';
         -- Sample the tKeep
         v.tKeep(TKEEP_C-1 downto 0) := axisMaster.tKeep(TKEEP_C-1 downto 0);
      end if;

      -- Check if last cycle had data moving
      if r.tValid = '1' then
         -- Update the accumulator 
         v.accum := r.accum + getTKeep(r.tKeep);
      end if;

      -- Increment the timer
      v.timer := r.timer + 1;

      -- Check for timeout 
      if r.timer = TIMEOUT_C then
         -- Reset the timer
         v.timer     := 0;
         -- Update the bandwidth measurement
         v.updated   := '1';
         v.bandwidth := r.accum;
         -- Reset the accumulator
         if r.tValid = '0' then
            v.accum := (others => '0');
         else
            v.accum := toSlv(getTKeep(r.tKeep), 40);
         end if;
      end if;

      -- Check for update previous clock cycle
      if (r.updated = '1') then
         -- Set the flag
         v.updateStat := '1';
         -- Check if first time after reset
         if (r.armed = '0') then
            -- Set the flag
            v.armed        := '1';
            -- Pass the current values to the statistics measurements
            v.bandwidthMax := r.bandwidth;
            v.bandwidthMin := r.bandwidth;
         else
            -- Compare for max. value
            if (r.bandwidth > r.bandwidthMax) then
               -- Update the statistics measurement
               v.bandwidthMax := r.accum;
            end if;
            -- Compare for min. value
            if (r.bandwidth < r.bandwidthMin) then
               -- Update the statistics measurement
               v.bandwidthMin := r.bandwidth;
            end if;
         end if;
      end if;

      -- Reset
      if axisRst = '1' then
         -- Re-arm and reset statistics measurements only
         v.armed        := '0';
         v.bandwidthMax := r.bandwidth;
         v.bandwidthMin := r.bandwidth;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

   end process comb;

   seq : process (axisClk) is
   begin
      if rising_edge(axisClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   SyncOut_bandwidth : entity work.SynchronizerFifo
      generic map (
         TPD_G        => TPD_G,
         COMMON_CLK_G => COMMON_CLK_G,
         DATA_WIDTH_G => 40)
      port map (
         wr_clk => axisClk,
         wr_en  => r.updated,
         din    => r.bandwidth,
         rd_clk => statusClk,
         dout   => bw);

   SyncOut_bandwidthMax : entity work.SynchronizerFifo
      generic map (
         TPD_G        => TPD_G,
         COMMON_CLK_G => COMMON_CLK_G,
         DATA_WIDTH_G => 40)
      port map (
         wr_clk => axisClk,
         wr_en  => r.updateStat,
         din    => r.bandwidthMax,
         rd_clk => statusClk,
         dout   => bwMax);

   SyncOut_bandwidthMin : entity work.SynchronizerFifo
      generic map (
         TPD_G        => TPD_G,
         COMMON_CLK_G => COMMON_CLK_G,
         DATA_WIDTH_G => 40)
      port map (
         wr_clk => axisClk,
         wr_en  => r.updateStat,
         din    => r.bandwidthMin,
         rd_clk => statusClk,
         dout   => bwMin);

   bandwidth    <= x"000000" & bw;
   bandwidthMax <= x"000000" & bwMax;
   bandwidthMin <= x"000000" & bwMin;

end rtl;
