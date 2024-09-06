-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
-- Block to compact AXI-Streams if tKeep bits are not contiguous
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
-- use ieee.std_logic_arith.all;
use ieee.numeric_std.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;

entity AxiStreamCompact is

   generic (
      TPD_G               : time    := 1 ns;
      RST_ASYNC_G         : boolean := false;
      PIPE_STAGES_G       : natural := 0;
      SLAVE_AXI_CONFIG_G  : AxiStreamConfigType;
      MASTER_AXI_CONFIG_G : AxiStreamConfigType);
   port (
      -- Clock and Reset
      axisClk     : in  sl;
      axisRst     : in  sl;
      -- Slave Port
      sAxisMaster : in  AxiStreamMasterType;
      sAxisSlave  : out AxiStreamSlaveType;
      -- Master Port
      mAxisMaster : out AxiStreamMasterType;
      mAxisSlave  : in  AxiStreamSlaveType);
end entity AxiStreamCompact;

architecture rtl of AxiStreamCompact is

   function getTKeepMin (
      tKeep      : slv;
      axisConfig : AxiStreamConfigType
      )
      return natural is
      variable tKeepFull : slv(AXI_STREAM_MAX_TKEEP_WIDTH_C-1 downto 0);
      variable i         : natural;
   begin  -- function getTKeepRange
      tKeepFull := resize(tKeep, AXI_STREAM_MAX_TKEEP_WIDTH_C);
      for i in 0 to axisConfig.TDATA_BYTES_C-1 loop
         if tKeepFull(i) = '1' then
            return i;
         end if;
      end loop;  -- i
   end function getTKeepMin;

   function getTKeepMax (
      tKeep      : slv;
      axisConfig : AxiStreamConfigType
      )
      return natural is
      variable tKeepFull : slv(AXI_STREAM_MAX_TKEEP_WIDTH_C-1 downto 0);
      variable i         : natural;
   begin  -- function getTKeepRange
      tKeepFull := resize(tKeep, AXI_STREAM_MAX_TKEEP_WIDTH_C);
      for i in axisConfig.TDATA_BYTES_C-1 downto 0 loop
         if tKeepFull(i) = '1' then
            return i;
         end if;
      end loop;  -- i
   end function getTKeepMax;

   constant SLV_BYTES_C : positive := SLAVE_AXI_CONFIG_G.TDATA_BYTES_C;
   constant MST_BYTES_C : positive := MASTER_AXI_CONFIG_G.TDATA_BYTES_C;

   type RegType is record
      -- count            : slv(bitSize(MST_BYTES_C)-1 downto 0);
      count       : natural;
      obMaster    : AxiStreamMasterType;
      ibSlave     : AxiStreamSlaveType;
      tLastDet    : boolean;
      tLastOnNext : boolean;
      tUserSet    : boolean;
      fullBus     : boolean;
   end record RegType;

   constant REG_INIT_C : RegType := (
      -- count            => (others => '0'),
      count       => 0,
      obMaster    => axiStreamMasterInit(MASTER_AXI_CONFIG_G),
      ibSlave     => AXI_STREAM_SLAVE_INIT_C,
      tLastDet    => false,
      tLastOnNext => false,
      tUserSet    => false,
      fullBus     => false
      );

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal pipeAxisMaster : AxiStreamMasterType;
   signal pipeAxisSlave  : AxiStreamSlaveType;

begin  -- architecture rtl

   -- Make sure data widths are the same
   assert (MST_BYTES_C >= SLV_BYTES_C)
      report "Master data widths must be greater or equal than slave" severity failure;

   comb : process (axisRst, pipeAxisSlave, r, sAxisMaster) is
      variable v          : RegType;
      variable tKeepMin   : natural;
      variable tKeepWidth : natural;
      variable tDataWidth : natural;
      variable tDataMin   : natural;
      variable tDataCount : natural;
      variable tDataVar   : slv(sAxisMaster.tData'range);
   begin  -- process
      -- Latch current value
      v := r;

      -- Init ready
      v.ibSlave.tReady := '0';
      v.fullBus        := false;
      v.tLastDet       := false;
      v.tLastOnNext    := false;

      -- Choose ready source and clear valid
      if (pipeAxisSlave.tReady = '1') then
         v.obMaster.tValid := '0';
      end if;

      -- Accept input data
      if v.obMaster.tValid = '0' and not r.tLastOnNext then

         -- Ready to accept
         v.ibSlave.tReady := '1';

         -- Input data is valid
         if sAxisMaster.tValid = '1' then

            -- get tKeet boundaries
            tKeepMin   := getTKeepMin(sAxisMaster.tKeep, SLAVE_AXI_CONFIG_G);
            tKeepWidth := getTKeep(sAxisMaster.tKeep, SLAVE_AXI_CONFIG_G);
            tDataWidth := to_integer(shift_left(to_unsigned(tKeepWidth, SLV_BYTES_C), 3));
            tDataCount := to_integer(shift_left(to_unsigned(r.count, SLV_BYTES_C), 3));
            tDataMin   := to_integer(shift_left(to_unsigned(tKeepMin, SLV_BYTES_C), 3));

            -- Checks
            -- -- Overflow
            if tKeepWidth + r.count >= MASTER_AXI_CONFIG_G.TDATA_BYTES_C then
               v.fullBus := true;
            end if;
            -- -- tLast
            v.tLastDet := false;
            -- v.tLastDet := r.tLastOnNext;
            if sAxisMaster.tLast = '1' then
               v.tLastDet := true;
               if tKeepWidth + r.count > MST_BYTES_C then
                  v.tLastDet    := false;
                  v.tLastOnNext := true;
               end if;
            end if;

            -- Gen bus
            -- Shift if bus was full
            if r.fullBus and not r.tLastOnNext then
               v.obMaster.tData := std_logic_vector(shift_right(unsigned(r.obMaster.tData), MST_BYTES_C*8));
            end if;
            ---- Remove initial bits
            tDataVar                                                                 := std_logic_vector(shift_right(unsigned(sAxisMaster.tData), tDataMin));
            v.obMaster.tData(v.obMaster.tData'length-1 downto tDataCount+tDataWidth) := (others => '0');
            v.obMaster.tData(tDataCount+tDataWidth-1 downto tDataCount)              := tDataVar(tDataWidth-1 downto 0);
            v.obMaster.tKeep                                                         := (others => '0');
            v.obMaster.tKeep(r.count+tKeepWidth-1 downto 0)                          := (others => '1');
            if not r.tUserSet then
               v.obMaster.tUser := sAxisMaster.tUser;
               v.tUserSet       := true;
            end if;

            -- Update counter
            v.count := r.count + tKeepWidth;

         end if;
      end if;

      -- Bus is full
      if v.fullBus or v.tLastDet or r.tLastOnNext then
         -- Set tValid
         v.obMaster.tValid := '1';
         -- Update bit counter and shift data
         if v.fullBus then
            v.count := r.count + tKeepWidth - MST_BYTES_C;
         else
            v.count := 0;
         end if;
         -- Set tLast
         if v.tLastDet and not v.tLastOnNext then
            v.obMaster.tLast := '1';
         else
            v.obMaster.tLast := '0';
         end if;
         -- Set tData in case of forced tLast
         if r.tLastOnNext then
            v.obMaster.tData := std_logic_vector(shift_right(unsigned(r.obMaster.tData), MST_BYTES_C*8));
            v.obMaster.tKeep := std_logic_vector(shift_right(unsigned(r.obMaster.tKeep), MST_BYTES_C));
            v.obMaster.tLast := '1';
         end if;
         v.tUserSet := false;
      end if;

      -- Outputs
      sAxisSlave                                                               <= v.ibSlave;
      pipeAxisMaster.tData(pipeAxisMaster.tData'length-1 downto MST_BYTES_C*8) <= (others => '0');
      pipeAxisMaster.tData((MST_BYTES_C*8)-1 downto 0)                         <= r.obMaster.tData((MST_BYTES_C*8)-1 downto 0);
      pipeAxisMaster.tKeep(pipeAxisMaster.tKeep'length-1 downto MST_BYTES_C)   <= (others => '0');
      pipeAxisMaster.tKeep((MST_BYTES_C)-1 downto 0)                           <= r.obMaster.tKeep((MST_BYTES_C)-1 downto 0);
      pipeAxisMaster.tValid                                                    <= r.obMaster.tValid;
      pipeAxisMaster.tUser                                                     <= r.obMaster.tUser;
      pipeAxisMaster.tLast                                                     <= r.obMaster.tLast;

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
   AxiStreamPipeline_1 : entity surf.AxiStreamPipeline
      generic map (
         TPD_G         => TPD_G,
         RST_ASYNC_G   => RST_ASYNC_G,
         -- SIDE_BAND_WIDTH_G => SIDE_BAND_WIDTH_G,
         PIPE_STAGES_G => PIPE_STAGES_G)
      port map (
         axisClk     => axisClk,
         axisRst     => axisRst,
         sAxisMaster => pipeAxisMaster,
         -- sSideBand   => pipeSideBand,
         sAxisSlave  => pipeAxisSlave,
         mAxisMaster => mAxisMaster,
         -- mSideBand   => mSideBand,
         mAxisSlave  => mAxisSlave);

end architecture rtl;
