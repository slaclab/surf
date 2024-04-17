-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
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

library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;

entity AxiStreamMon is
   generic (
      TPD_G           : time    := 1 ns;
      RST_ASYNC_G     : boolean := false;
      COMMON_CLK_G    : boolean := false;  -- true if axisClk = statusClk
      AXIS_CLK_FREQ_G : real    := 156.25E+6;  -- units of Hz
      AXIS_CONFIG_G   : AxiStreamConfigType);
   port (
      -- AXIS Stream Interface
      axisClk      : in  sl;
      axisRst      : in  sl;
      axisMaster   : in  AxiStreamMasterType;
      axisSlave    : in  AxiStreamSlaveType;
      -- Status Interface
      statusClk    : in  sl;
      statusRst    : in  sl;
      frameCnt     : out slv(63 downto 0);             -- units of frames
      frameSize    : out slv(31 downto 0);             -- units of Byte
      frameSizeMax : out slv(31 downto 0);             -- units of Byte
      frameSizeMin : out slv(31 downto 0);             -- units of Byte
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
      frameSent  : sl;
      sizeValid  : sl;
      armed      : sl;
      tValid     : sl;
      tKeep      : slv(AXI_STREAM_MAX_TKEEP_WIDTH_C-1 downto 0);
      updated    : sl;
      timer      : natural range 0 to TIMEOUT_C;
      accum      : slv(39 downto 0);
      bandwidth  : slv(39 downto 0);
      frameAccum : slv(31 downto 0);
      frameSize  : slv(31 downto 0);
      frameCnt   : slv(63 downto 0);
   end record;

   constant REG_INIT_C : RegType := (
      frameSent  => '0',
      sizeValid  => '0',
      armed      => '0',
      tValid     => '0',
      tKeep      => (others => '0'),
      updated    => '0',
      timer      => 0,
      accum      => (others => '0'),
      bandwidth  => (others => '0'),
      frameAccum => (others => '0'),
      frameSize  => (others => '0'),
      frameCnt   => (others => '0'));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal bw    : slv(39 downto 0);
   signal bwMax : slv(39 downto 0);
   signal bwMin : slv(39 downto 0);

   signal frameRateReset   : sl;
   signal frameRateUpdate  : sl;
   signal frameRateSync    : slv(31 downto 0);
   signal frameRateMaxSync : slv(31 downto 0);
   signal frameRateMinSync : slv(31 downto 0);

   -- attribute dont_touch          : string;
   -- attribute dont_touch of r     : signal is "true";

begin

   U_RstSync : entity surf.RstSync
      generic map (
         TPD_G => TPD_G)
      port map (
         clk      => axisClk,
         asyncRst => statusRst,
         syncRst  => frameRateReset);

   U_packetRate : entity surf.SyncTrigRate
      generic map (
         TPD_G          => TPD_G,
         RST_ASYNC_G    => RST_ASYNC_G,
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
         locRst          => frameRateReset,
         refClk          => axisClk,
         refRst          => axisRst);

   SyncOut_frameRate : entity surf.SynchronizerFifo
      generic map (
         TPD_G        => TPD_G,
         RST_ASYNC_G  => RST_ASYNC_G,
         COMMON_CLK_G => COMMON_CLK_G,
         DATA_WIDTH_G => 32)
      port map (
         wr_clk => axisClk,
         wr_en  => frameRateUpdate,
         din    => frameRateSync,
         rd_clk => statusClk,
         dout   => frameRate);

   SyncOut_frameRateMax : entity surf.SynchronizerFifo
      generic map (
         TPD_G        => TPD_G,
         RST_ASYNC_G  => RST_ASYNC_G,
         COMMON_CLK_G => COMMON_CLK_G,
         DATA_WIDTH_G => 32)
      port map (
         wr_clk => axisClk,
         wr_en  => frameRateUpdate,
         din    => frameRateMaxSync,
         rd_clk => statusClk,
         dout   => frameRateMax);

   SyncOut_frameRateMin : entity surf.SynchronizerFifo
      generic map (
         TPD_G        => TPD_G,
         RST_ASYNC_G  => RST_ASYNC_G,
         COMMON_CLK_G => COMMON_CLK_G,
         DATA_WIDTH_G => 32)
      port map (
         wr_clk => axisClk,
         wr_en  => frameRateUpdate,
         din    => frameRateMinSync,
         rd_clk => statusClk,
         dout   => frameRateMin);

   SyncOut_frameCnt : entity surf.SynchronizerFifo
      generic map (
         TPD_G        => TPD_G,
         RST_ASYNC_G  => RST_ASYNC_G,
         COMMON_CLK_G => COMMON_CLK_G,
         DATA_WIDTH_G => 64)
      port map (
         wr_clk => axisClk,
         din    => r.frameCnt,
         rd_clk => statusClk,
         dout   => frameCnt);

   comb : process (axisMaster, axisRst, axisSlave, r) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Reset strobing signals
      v.tValid    := '0';
      v.updated   := '0';
      v.sizeValid := '0';

      -- Check for end of frame
      v.frameSent := axisMaster.tValid and axisMaster.tLast and axisSlave.tReady;

      -- Increment frame counter if end of frame detected
      if (r.frameSent = '1') then
         v.frameCnt := r.frameCnt + 1;
      end if;

      -- Check for data moving
      if (axisMaster.tValid = '1') and (axisSlave.tReady = '1') then
         -- Set the flag
         v.tValid                    := '1';
         -- Sample the tKeep
         v.tKeep(TKEEP_C-1 downto 0) := axisMaster.tKeep(TKEEP_C-1 downto 0);
      end if;

      -- Check if last cycle had data moving
      if (r.tValid = '1') then

         -- Update the accumulator
         if (AXIS_CONFIG_G.TKEEP_MODE_C = TKEEP_COUNT_C) then
            v.accum      := r.accum + conv_integer(r.tKeep(bitSize(AXIS_CONFIG_G.TDATA_BYTES_C)-1 downto 0));
            v.frameAccum := r.frameAccum + conv_integer(r.tKeep(bitSize(AXIS_CONFIG_G.TDATA_BYTES_C)-1 downto 0));
         else
            v.accum      := r.accum + getTKeep(r.tKeep, AXIS_CONFIG_G);
            v.frameAccum := r.frameAccum + getTKeep(r.tKeep, AXIS_CONFIG_G);
         end if;

         -- Check for end of frame
         if (r.frameSent = '1') then
            -- Set the flag
            v.sizeValid  := r.armed;
            v.frameSize  := v.frameAccum;
            -- Reset the accumulator
            v.frameAccum := (others => '0');
            -- Confirmed that not in the middle of a frame since reset
            v.armed      := '1';
         end if;

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
            if (AXIS_CONFIG_G.TKEEP_MODE_C = TKEEP_COUNT_C) then
               v.accum := resize(r.tKeep(bitSize(AXIS_CONFIG_G.TDATA_BYTES_C)-1 downto 0), 40);
            else
               v.accum := toSlv(getTKeep(r.tKeep, AXIS_CONFIG_G), 40);
            end if;
         end if;
      end if;

      -- Reset
      if (RST_ASYNC_G = false and axisRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

   end process comb;

   seq : process (axisClk, axisRst) is
   begin
      if (RST_ASYNC_G) and (axisRst = '1') then
         r <= REG_INIT_C after TPD_G;
      elsif rising_edge(axisClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   Sync_frameSize : entity surf.SyncMinMax
      generic map (
         TPD_G        => TPD_G,
         RST_ASYNC_G  => RST_ASYNC_G,
         COMMON_CLK_G => COMMON_CLK_G,
         WIDTH_G      => 32)
      port map (
         -- ASYNC statistics reset
         rstStat => statusRst,
         -- Write Interface (wrClk domain)
         wrClk   => axisClk,
         wrEn    => r.sizeValid,
         dataIn  => r.frameSize,
         -- Read Interface (rdClk domain)
         rdClk   => statusClk,
         dataOut => frameSize,
         dataMin => frameSizeMin,
         dataMax => frameSizeMax);

   Sync_bandwidth : entity surf.SyncMinMax
      generic map (
         TPD_G        => TPD_G,
         RST_ASYNC_G  => RST_ASYNC_G,
         COMMON_CLK_G => COMMON_CLK_G,
         WIDTH_G      => 40)
      port map (
         -- ASYNC statistics reset
         rstStat => statusRst,
         -- Write Interface (wrClk domain)
         wrClk   => axisClk,
         wrEn    => r.updated,
         dataIn  => r.bandwidth,
         -- Read Interface (rdClk domain)
         rdClk   => statusClk,
         dataOut => bw,
         dataMin => bwMin,
         dataMax => bwMax);

   bandwidth    <= x"000000" & bw;
   bandwidthMax <= x"000000" & bwMax;
   bandwidthMin <= x"000000" & bwMin;

end rtl;
