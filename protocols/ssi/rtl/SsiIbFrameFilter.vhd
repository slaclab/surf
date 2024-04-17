-------------------------------------------------------------------------------
-- Title      : SSI Protocol: https://confluence.slac.stanford.edu/x/0oyfD
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Inbound AXI Stream FIFO SSI Filter ....
--              Tags frames with EOFE on double SOFs
--              Drops frames that are missing SOF frame marker
--              Tags frames with EOFE on change in TDEST during move
--              Generates the overflow FIFO signal for user logic
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

entity SsiIbFrameFilter is
   generic (
      TPD_G            : time    := 1 ns;
      RST_ASYNC_G      : boolean := false;
      SLAVE_READY_EN_G : boolean := true;
      AXIS_CONFIG_G    : AxiStreamConfigType);
   port (
      -- Slave Interface (User Application Interface)
      sAxisMaster    : in  AxiStreamMasterType;
      sAxisSlave     : out AxiStreamSlaveType;
      sAxisCtrl      : out AxiStreamCtrlType;
      sAxisDropWord  : out sl;          -- Word dropped status output
      sAxisDropFrame : out sl;          -- Frame dropped status output
      -- Master Interface (AXIS FIFO Write Interface)
      mAxisMaster    : out AxiStreamMasterType;
      mAxisSlave     : in  AxiStreamSlaveType;
      mAxisCtrl      : in  AxiStreamCtrlType;
      -- Clock and Reset
      axisClk        : in  sl;
      axisRst        : in  sl);
end SsiIbFrameFilter;

architecture rtl of SsiIbFrameFilter is

   constant SLAVE_INIT_C : AxiStreamSlaveType := ite(SLAVE_READY_EN_G, AXI_STREAM_SLAVE_INIT_C, AXI_STREAM_SLAVE_FORCE_C);

   constant CHECK_TDEST_C : boolean := AXIS_CONFIG_G.TDEST_BITS_C > 0;
   constant TDEST_BITS_C  : natural := ite(CHECK_TDEST_C, AXIS_CONFIG_G.TDEST_BITS_C, 1);

   type StateType is (
      IDLE_S,
      BLOWOFF_S,
      MOVE_S,
      INSERT_EOFE_S);

   type RegType is record
      overflow     : sl;
      wordDropped  : sl;
      frameDropped : sl;
      tDest        : slv(TDEST_BITS_C-1 downto 0);
      master       : AxiStreamMasterType;
      slave        : AxiStreamSlaveType;
      state        : StateType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      overflow     => '0',
      wordDropped  => '0',
      frameDropped => '0',
      tDest        => (others => '0'),
      master       => AXI_STREAM_MASTER_INIT_C,
      slave        => SLAVE_INIT_C,
      state        => IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

--   assert (AXIS_CONFIG_G.TDEST_INTERLEAVE_C = false)
--      report "SsiIbFrameFilter does NOT support interleaved TDEST" severity failure;

   assert (AXIS_CONFIG_G.TUSER_BITS_C >= 2)
      report "SsiIbFrameFilter:  AXIS_CONFIG_G.TUSER_BITS_C must be >= 2" severity failure;

   comb : process (axisRst, mAxisCtrl, mAxisSlave, r, sAxisMaster) is
      variable v   : RegType;
      variable sof : sl;
   begin
      -- Latch the current value
      v := r;

      -- Reset strobe Signals
      v.overflow     := '0';
      v.wordDropped  := '0';
      v.frameDropped := '0';

      -- Flow Control Signals
      v.slave := SLAVE_INIT_C;
      if (mAxisSlave.tReady = '1') then
         v.master.tValid := '0';
      end if;

      -- Get the SOF status
      sof := ssiGetUserSof(AXIS_CONFIG_G, sAxisMaster);

      -- State Machine
      case (r.state) is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Check for new inbound data
            if (sAxisMaster.tValid = '1') then

               -- Check for overflow
               if (v.master.tValid = '1') and not(SLAVE_READY_EN_G) then

                  -- Accept the data
                  v.slave.tReady := '1';

                  -- Set the flag
                  v.overflow := '1';

                  -- Strobe the error flags
                  v.wordDropped  := sAxisMaster.tValid;
                  v.frameDropped := sAxisMaster.tLast;

               -- Else ready to accept new data
               elsif (v.master.tValid = '0') then

                  -- Accept the data
                  v.slave.tReady := '1';

                  -- Check for SOF
                  if (sof = '1') then

                     -- Move the data bus
                     v.master := sAxisMaster;

                     -- Latch tDest
                     v.tDest := sAxisMaster.tDest(TDEST_BITS_C-1 downto 0);

                     -- Check for no EOF
                     if (sAxisMaster.tLast = '0') then
                        -- Next state
                        v.state := MOVE_S;
                     end if;

                  -- No SOF frame maker detected
                  else

                     -- Strobe the error flags
                     v.wordDropped  := sAxisMaster.tValid;
                     v.frameDropped := sAxisMaster.tLast;

                     -- Check for non-EOF
                     if (sAxisMaster.tLast = '0') then
                        -- Next state
                        v.state := BLOWOFF_S;
                     end if;

                  end if;

               end if;
            end if;
         ----------------------------------------------------------------------
         when BLOWOFF_S =>
            -- Blow-off the data
            v.slave.tReady := '1';

            -- Strobe the error flags
            v.wordDropped  := sAxisMaster.tValid;
            v.frameDropped := sAxisMaster.tLast;

            -- Check for EOF
            if (sAxisMaster.tValid = '1') and (sAxisMaster.tLast = '1') then
               -- Next state
               v.state := IDLE_S;
            end if;
         ----------------------------------------------------------------------
         when MOVE_S =>
            -- Check for new inbound data
            if (sAxisMaster.tValid = '1') then

               -- Check for overflow
               if (v.master.tValid = '1') and not(SLAVE_READY_EN_G) then

                  -- Accept the data
                  v.slave.tReady := '1';

                  -- Set the flag
                  v.overflow := '1';

                  -- Strobe the error flags
                  v.wordDropped  := sAxisMaster.tValid;
                  v.frameDropped := sAxisMaster.tLast;

                  -- Next state
                  v.state := INSERT_EOFE_S;

               -- Else ready to accept new data
               elsif (v.master.tValid = '0') then

                  -- Accept the data
                  v.slave.tReady := '1';

                  -- Move the data bus
                  v.master := sAxisMaster;

                  -- Check for EOF
                  if (sAxisMaster.tLast = '1') then
                     -- Next state
                     v.state := IDLE_S;
                  end if;

                  -- Check for SSI framing errors (repeated SOF or interleaved frame)
                  if (sof = '1') or (CHECK_TDEST_C and (r.tDest /= sAxisMaster.tDest(TDEST_BITS_C-1 downto 0))) then

                     -- Set the EOF flag
                     v.master.tLast := '1';

                     -- Set the EOFE flag
                     ssiSetUserEofe(AXIS_CONFIG_G, v.master, '1');

                     -- Override SOF flag
                     ssiSetUserSof(AXIS_CONFIG_G, v.master, '0');

                     -- Strobe the error flags
                     v.wordDropped  := sAxisMaster.tValid;
                     v.frameDropped := sAxisMaster.tLast;

                     -- Check for non-EOF
                     if (sAxisMaster.tLast = '0') then
                        -- Next state
                        v.state := BLOWOFF_S;
                     end if;

                  end if;
               end if;
            end if;
         ----------------------------------------------------------------------
         when INSERT_EOFE_S =>
            -- Blow-off the data
            v.slave.tReady := '1';

            -- Set the flag
            v.overflow := sAxisMaster.tValid;

            -- Strobe the error flags
            v.wordDropped  := sAxisMaster.tValid;
            v.frameDropped := sAxisMaster.tLast;

            -- Check if AXI stream FIFO can be written into
            if (v.master.tValid = '0') then

               -- Write to FIFO
               v.master.tValid := '1';

               -- Set the EOF flag
               v.master.tLast := '1';

               -- Set the EOFE flag
               ssiSetUserEofe(AXIS_CONFIG_G, v.master, '1');

               -- Override SOF flag
               ssiSetUserSof(AXIS_CONFIG_G, v.master, '0');

               -- Next state
               v.state := IDLE_S;

            end if;
      ----------------------------------------------------------------------
      end case;

      -- Slave Outputs
      sAxisSlave         <= v.slave;
      sAxisCtrl          <= mAxisCtrl;
      sAxisCtrl.overflow <= r.overflow or mAxisCtrl.overflow;
      sAxisDropWord      <= r.wordDropped;
      sAxisDropFrame     <= r.frameDropped;

      -- Master Outputs
      mAxisMaster <= r.master;

      -- Synchronous Reset
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

end rtl;
