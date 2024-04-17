-------------------------------------------------------------------------------
-- Title      : SSI Protocol: https://confluence.slac.stanford.edu/x/0oyfD
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Outbound AXI Stream FIFO SSI Filter ....
--              Tags frames with EOFE on double SOFs
--              Drops frames that are EOFE frame marker when VALID_THOLD_G = 0
--              Tags frames with EOFE on change in TDEST during move
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

entity SsiObFrameFilter is
   generic (
      TPD_G         : time    := 1 ns;
      RST_ASYNC_G   : boolean := false;
      VALID_THOLD_G : natural := 1;
      PIPE_STAGES_G : natural := 1;
      AXIS_CONFIG_G : AxiStreamConfigType);
   port (
      -- Slave Port (AXIS FIFO Read Interface)
      sAxisMaster    : in  AxiStreamMasterType;
      sTLastTUser    : in  slv(7 downto 0);
      sAxisSlave     : out AxiStreamSlaveType;
      -- Master Port
      mAxisMaster    : out AxiStreamMasterType;
      mAxisSlave     : in  AxiStreamSlaveType;
      mAxisDropWord  : out sl;          -- Word dropped status output
      mAxisDropFrame : out sl;          -- Frame dropped status output
      -- Clock and Reset
      axisClk        : in  sl;
      axisRst        : in  sl);
end SsiObFrameFilter;

architecture rtl of SsiObFrameFilter is

   type StateType is (
      IDLE_S,
      BLOWOFF_S,
      MOVE_S);

   type RegType is record
      sof          : sl;
      eofe         : sl;
      wordDropped  : sl;
      frameDropped : sl;
      tDest        : slv(7 downto 0);
      master       : AxiStreamMasterType;
      slave        : AxiStreamSlaveType;
      state        : StateType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      sof          => '0',
      eofe         => '0',
      wordDropped  => '0',
      frameDropped => '0',
      tDest        => x"00",
      master       => AXI_STREAM_MASTER_INIT_C,
      slave        => AXI_STREAM_SLAVE_INIT_C,
      state        => IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal axisMaster : AxiStreamMasterType;
   signal axisSlave  : AxiStreamSlaveType;

begin

   assert (AXIS_CONFIG_G.TUSER_BITS_C >= 2)
      report "SsiObFrameFilter:  AXIS_CONFIG_G.TUSER_BITS_C must be >= 2" severity failure;

   comb : process (axisRst, axisSlave, r, sAxisMaster, sTLastTUser) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Reset strobe Signals
      v.wordDropped  := '0';
      v.frameDropped := '0';

      -- Flow Control Signals
      v.slave := AXI_STREAM_SLAVE_INIT_C;
      if (axisSlave.tReady = '1') then
         v.master.tValid := '0';
      end if;

      -- Get the SOF status
      v.sof := ssiGetUserSof(AXIS_CONFIG_G, sAxisMaster);

      -- Check for FIFO caching
      if (VALID_THOLD_G = 0) then
         -- Get the EOFE status
         v.eofe := sTLastTUser(SSI_EOFE_C);
      else
         -- Reset the flag
         v.eofe := '0';
      end if;

      -- State Machine
      case (r.state) is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Check if ready to move data
            if (v.master.tValid = '0') and (sAxisMaster.tValid = '1') then

               -- Accept the data
               v.slave.tReady := '1';

               -- Check of no-SOF or  EOFE detected in the FIFO
               if (v.sof = '0') or (v.eofe = '1') then

                  -- Strobe the error flags
                  v.wordDropped  := sAxisMaster.tValid;
                  v.frameDropped := sAxisMaster.tLast;

                  -- Check for non-EOF
                  if (sAxisMaster.tLast = '0') then
                     -- Next state
                     v.state := BLOWOFF_S;
                  end if;

               -- Else normal framing detected
               else

                  -- Move the data bus
                  v.master := sAxisMaster;

                  -- Latch tDest
                  v.tDest := sAxisMaster.tDest;

                  -- Check for no EOF
                  if (sAxisMaster.tLast = '0') then
                     -- Next state
                     v.state := MOVE_S;
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
            -- Check if ready to move data
            if (v.master.tValid = '0') and (sAxisMaster.tValid = '1') then

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
               if (v.sof = '1') or (r.tDest /= sAxisMaster.tDest) then

                  -- Set the EOF flag
                  v.master.tLast := '1';

                  -- Set the EOFE flag
                  ssiSetUserEofe(AXIS_CONFIG_G, v.master, '1');

                  -- Override SOF flag
                  ssiSetUserSof(AXIS_CONFIG_G, v.master, '0');

                  -- Strobe the error flags
                  v.wordDropped  := sAxisMaster.tValid;
                  v.frameDropped := sAxisMaster.tLast;

                  -- Next state
                  v.state := IDLE_S;

               end if;

            end if;
      ----------------------------------------------------------------------
      end case;

      -- Slave Outputs
      sAxisSlave <= v.slave;

      -- Master Outputs
      axisMaster     <= r.master;
      mAxisDropWord  <= r.wordDropped;
      mAxisDropFrame <= r.frameDropped;

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

   U_Pipe : entity surf.AxiStreamPipeline
      generic map (
         TPD_G         => TPD_G,
         RST_ASYNC_G   => RST_ASYNC_G,
         PIPE_STAGES_G => PIPE_STAGES_G)
      port map (
         -- Clock and Reset
         axisClk     => axisClk,
         axisRst     => axisRst,
         -- Slave Port
         sAxisMaster => axisMaster,
         sAxisSlave  => axisSlave,
         -- Master Port
         mAxisMaster => mAxisMaster,
         mAxisSlave  => mAxisSlave);

end rtl;
