-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Use to limit the max AXI stream frame rate
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
use surf.AxiStreamPkg.all;
use surf.AxiLitePkg.all;

entity AxiStreamFrameRateLimiter is
   generic (
      TPD_G              : time     := 1 ns;
      RST_ASYNC_G        : boolean  := false;
      PIPE_STAGES_G      : natural  := 0;
      COMMON_CLK_G       : boolean  := false;  -- True if axisClk and axilClk are the same clock
      BACKPRESSURE_G     : boolean  := false;  -- Set the default for the back pressure register
      AXIS_CLK_FREQ_G    : real     := 156.25E+6;  -- Units of Hz
      REFRESH_RATE_G     : real     := 1.0E+0;     -- units of Hz
      DEFAULT_MAX_RATE_G : positive := 1);     -- Units of 'REFRESH_RATE_G'
   port (
      -- AXI Stream Interface (axisClk domain)
      axisClk         : in  sl;
      axisRst         : in  sl;
      sAxisMaster     : in  AxiStreamMasterType;
      sAxisSlave      : out AxiStreamSlaveType;
      mAxisMaster     : out AxiStreamMasterType;
      mAxisSlave      : in  AxiStreamSlaveType;
      -- Optional: AXI Lite Interface (axilClk domain)
      axilClk         : in  sl                     := '0';
      axilRst         : in  sl                     := '0';
      axilReadMaster  : in  AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
      axilWriteSlave  : out AxiLiteWriteSlaveType);
end AxiStreamFrameRateLimiter;

architecture rtl of AxiStreamFrameRateLimiter is

   constant TIMEOUT_C : natural := getTimeRatio(AXIS_CLK_FREQ_G, REFRESH_RATE_G)-1;

   constant BACKPRESSURE_C : slv(31 downto 0) := ite(BACKPRESSURE_G, x"0000_0001", x"0000_0000");
   constant INI_WRITE_REG_C : Slv32Array(1 downto 0) := (
      0 => toSlv(DEFAULT_MAX_RATE_G, 32),
      1 => BACKPRESSURE_C);

   type StateType is (
      IDLE_S,
      MOVE_S);

   type RegType is record
      tValid     : sl;
      rateLimit  : slv(31 downto 0);
      frameCnt   : slv(31 downto 0);
      timer      : natural range 0 to TIMEOUT_C;
      sAxisSlave : AxiStreamSlaveType;
      txMaster   : AxiStreamMasterType;
      state      : StateType;
   end record RegType;
   constant REG_INIT_C : RegType := (
      tValid     => '0',
      rateLimit  => (others => '0'),
      frameCnt   => (others => '0'),
      timer      => 0,
      sAxisSlave => AXI_STREAM_SLAVE_INIT_C,
      txMaster   => AXI_STREAM_MASTER_INIT_C,
      state      => IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal txSlave : AxiStreamSlaveType;

   signal readReg  : Slv32Array(2 downto 0);
   signal writeReg : Slv32Array(1 downto 0);

   signal rateLimit    : slv(31 downto 0);
   signal backpressure : sl;

begin

   readReg(0) <= toSlv(getTimeRatio(AXIS_CLK_FREQ_G, 1.0), 32);
   readReg(1) <= toSlv(getTimeRatio(REFRESH_RATE_G, 1.0), 32);
   readReg(2) <= toSlv(DEFAULT_MAX_RATE_G, 32);

   U_AxiLiteRegs : entity surf.AxiLiteRegs
      generic map (
         TPD_G           => TPD_G,
         RST_ASYNC_G     => RST_ASYNC_G,
         NUM_WRITE_REG_G => 2,
         INI_WRITE_REG_G => INI_WRITE_REG_C,
         NUM_READ_REG_G  => 3)
      port map (
         -- AXI-Lite Bus
         axiClk         => axilClk,
         axiClkRst      => axilRst,
         axiReadMaster  => axilReadMaster,
         axiReadSlave   => axilReadSlave,
         axiWriteMaster => axilWriteMaster,
         axiWriteSlave  => axilWriteSlave,
         -- User Read/Write registers
         writeRegister  => writeReg,
         readRegister   => readReg);

   U_rateLimit : entity surf.SynchronizerVector
      generic map (
         TPD_G         => TPD_G,
         BYPASS_SYNC_G => COMMON_CLK_G,
         WIDTH_G       => 32)
      port map (
         clk     => axisClk,
         dataIn  => writeReg(0),
         dataOut => rateLimit);

   U_backpressure : entity surf.Synchronizer
      generic map (
         TPD_G         => TPD_G,
         BYPASS_SYNC_G => COMMON_CLK_G)
      port map (
         clk     => axisClk,
         dataIn  => writeReg(1)(0),
         dataOut => backpressure);

   comb : process (axisRst, backpressure, r, rateLimit, sAxisMaster, txSlave) is
      variable v : RegType;
      variable i : natural;
   begin
      -- Latch the current value
      v := r;

      -- Keep a delayed copy
      v.rateLimit := rateLimit;

      -- Reset the flags
      v.sAxisSlave := AXI_STREAM_SLAVE_INIT_C;
      if txSlave.tReady = '1' then
         v.txMaster.tValid := '0';
      end if;

      -- State Machine
      case r.state is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Update the variable
            if (r.rateLimit = 0) or (r.rateLimit /= r.frameCnt) then
               v.tValid := '1';
            else
               v.tValid := '0';
            end if;

            -- Check if ready to move data
            if (v.txMaster.tValid = '0') and (sAxisMaster.tValid = '1') then

               -- Check if not limiting
               if (r.rateLimit = 0) or (r.rateLimit /= r.frameCnt) or (backpressure = '0') then

                  -- Check for non-zero case
                  if (r.rateLimit /= 0) and (v.tValid = '1') then
                     -- Increment the counter
                     v.frameCnt := r.frameCnt + 1;
                  end if;

                  -- Accept the data
                  v.sAxisSlave.tReady := '1';

                  -- Move the data
                  v.txMaster := sAxisMaster;

                  -- Update TVALID
                  v.txMaster.tValid := v.tValid;

                  -- Check for no EOF
                  if (sAxisMaster.tLast = '0') then
                     -- Next state
                     v.state := MOVE_S;
                  end if;

               end if;

            end if;
         ----------------------------------------------------------------------
         when MOVE_S =>
            -- Check if ready to move data
            if (v.txMaster.tValid = '0') and (sAxisMaster.tValid = '1') then

               -- Accept the data
               v.sAxisSlave.tReady := '1';

               -- Move the data
               v.txMaster := sAxisMaster;

               -- Update TVALID
               v.txMaster.tValid := r.tValid;

               -- Check for EOF
               if (sAxisMaster.tLast = '1') then
                  -- Next state
                  v.state := IDLE_S;
               end if;

            end if;
      ----------------------------------------------------------------------
      end case;

      -- Check for change in configuration event or timeout event
      if (r.rateLimit /= v.rateLimit) or (r.timer = TIMEOUT_C) then

         -- Reset the counter
         v.frameCnt := (others => '0');

         -- Reset the timer
         v.timer := 0;

      else

         -- Increment the timer
         v.timer := r.timer + 1;

      end if;

      -- Outputs
      sAxisSlave <= v.sAxisSlave;

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

   -- Optional output pipeline registers to ease timing
   U_AxiStreamPipeline : entity surf.AxiStreamPipeline
      generic map (
         TPD_G         => TPD_G,
         RST_ASYNC_G   => RST_ASYNC_G,
         PIPE_STAGES_G => PIPE_STAGES_G)
      port map (
         axisClk     => axisClk,
         axisRst     => axisRst,
         sAxisMaster => r.txMaster,
         sAxisSlave  => txSlave,
         mAxisMaster => mAxisMaster,
         mAxisSlave  => mAxisSlave);

end rtl;
