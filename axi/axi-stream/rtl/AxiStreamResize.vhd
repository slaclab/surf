-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
-- Block to resize AXI Streams. Re-sizing is always little endian.
-- Resizer should not be used when interleaving tDests
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

entity AxiStreamResize is
   generic (

      -- General Configurations
      TPD_G             : time     := 1 ns;
      READY_EN_G        : boolean  := true;
      PIPE_STAGES_G     : natural  := 0;
      SIDE_BAND_WIDTH_G : positive := 1;  -- General purpose sideband

      -- AXI Stream Port Configurations
      SLAVE_AXI_CONFIG_G  : AxiStreamConfigType;
      MASTER_AXI_CONFIG_G : AxiStreamConfigType);
   port (

      -- Clock and reset
      axisClk : in sl;
      axisRst : in sl;

      -- Slave Port
      sAxisMaster : in  AxiStreamMasterType;
      sSideBand   : in  slv(SIDE_BAND_WIDTH_G-1 downto 0) := (others => '0');
      sAxisSlave  : out AxiStreamSlaveType;

      -- Master Port
      mAxisMaster : out AxiStreamMasterType;
      mSideBand   : out slv(SIDE_BAND_WIDTH_G-1 downto 0);
      mAxisSlave  : in  AxiStreamSlaveType);
end AxiStreamResize;

architecture rtl of AxiStreamResize is

   constant SLV_BYTES_C : positive := SLAVE_AXI_CONFIG_G.TDATA_BYTES_C;
   constant MST_BYTES_C : positive := MASTER_AXI_CONFIG_G.TDATA_BYTES_C;

   constant SLV_USER_C : positive := ite(SLAVE_AXI_CONFIG_G.TUSER_BITS_C /= 0, SLAVE_AXI_CONFIG_G.TUSER_BITS_C, 1);
   constant MST_USER_C : positive := ite(MASTER_AXI_CONFIG_G.TUSER_BITS_C /= 0, MASTER_AXI_CONFIG_G.TUSER_BITS_C, 1);

   constant COUNT_C : positive := ite(SLV_BYTES_C > MST_BYTES_C, SLV_BYTES_C / MST_BYTES_C, MST_BYTES_C / SLV_BYTES_C);

   type RegType is record
      count    : slv(bitSize(COUNT_C)-1 downto 0);
      obMaster : AxiStreamMasterType;
      sideBand : slv(SIDE_BAND_WIDTH_G-1 downto 0);
      ibSlave  : AxiStreamSlaveType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      count    => (others => '0'),
      obMaster => axiStreamMasterInit(MASTER_AXI_CONFIG_G),
      sideBand => (others => '0'),
      ibSlave  => AXI_STREAM_SLAVE_INIT_C
      );

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal pipeAxisMaster : AxiStreamMasterType;
   signal pipeSideBand   : slv(SIDE_BAND_WIDTH_G-1 downto 0);
   signal pipeAxisSlave  : AxiStreamSlaveType;

begin

   -- Make sure data widths are appropriate.
   assert ((SLV_BYTES_C >= MST_BYTES_C and SLV_BYTES_C mod MST_BYTES_C = 0) or
           (MST_BYTES_C >= SLV_BYTES_C and MST_BYTES_C mod SLV_BYTES_C = 0))
      report "Data widths must be even number multiples of each other" severity failure;

   -- When going from a large bus to a small bus, ready is necessary
   assert (SLV_BYTES_C <= MST_BYTES_C or READY_EN_G = true)
      report "READY_EN_G must be true if slave width is great than master" severity failure;

   -- Cant use tkeep_fixed on master side when resizing or if not on slave side
   assert (not (MASTER_AXI_CONFIG_G.TKEEP_MODE_C = TKEEP_FIXED_C and
                SLAVE_AXI_CONFIG_G.TKEEP_MODE_C /= TKEEP_FIXED_C))
      report "AxiStreamResize: Can't have TKEEP_MODE = TKEEP_FIXED on master side if not on slave side"
      severity error;

   comb : process (pipeAxisSlave, r, sAxisMaster, sSideBand) is
      variable v       : RegType;
      variable ibM     : AxiStreamMasterType;
      variable ibSide  : slv(SIDE_BAND_WIDTH_G-1 downto 0);
      variable idx     : integer;       -- index version of counter
      variable byteCnt : integer;  -- Number of valid bytes in incoming bus
      variable bytes   : integer;       -- byte version of counter
   begin
      v     := r;
      idx   := conv_integer(r.count);
      bytes := (idx+1) * MST_BYTES_C;
      if (SLAVE_AXI_CONFIG_G.TKEEP_MODE_C = TKEEP_COUNT_C) then
         byteCnt := conv_integer(sAxisMaster.tKeep(bitSize(SLAVE_AXI_CONFIG_G.TDATA_BYTES_C)-1 downto 0));
      else
         byteCnt := getTKeep(sAxisMaster.tKeep, SLAVE_AXI_CONFIG_G);
      end if;

      -- Init ready
      v.ibSlave.tReady := '0';

      -- Choose ready source and clear valid
      if READY_EN_G = false or pipeAxisSlave.tReady = '1' then
         v.obMaster.tValid := '0';
      end if;

      -- Inbound data with normalized user bits (8 user bits)
      ibM       := sAxisMaster;
      ibSide    := sSideBand;
      ibM.tUser := (others => '0');
      if (SLAVE_AXI_CONFIG_G.TKEEP_MODE_C = TKEEP_COUNT_C) then
         ibM.tKeep := genTKeep(byteCnt);
      end if;

      -- Check that both master and slave using tUser
      if (SLAVE_AXI_CONFIG_G.TUSER_BITS_C /= 0) and
         (MASTER_AXI_CONFIG_G.TUSER_BITS_C /= 0) and
         (SLAVE_AXI_CONFIG_G.TUSER_MODE_C /= TUSER_NONE_C) and
         (MASTER_AXI_CONFIG_G.TUSER_MODE_C /= TUSER_NONE_C) then
         -- Loop through the tUser bit field
         for i in 0 to AXI_STREAM_MAX_TKEEP_WIDTH_C-1 loop
            ibM.tUser((i*8)+(SLV_USER_C-1) downto (i*8)) := sAxisMaster.tUser((i*SLV_USER_C)+(SLV_USER_C-1) downto (i*SLV_USER_C));
         end loop;
      end if;

      -- Pipeline advance
      if v.obMaster.tValid = '0' then

         -- Increasing size
         if MST_BYTES_C > SLV_BYTES_C then
            v.ibSlave.tReady := '1';

            -- init when count = 0
            if (r.count = 0) then
               v.obMaster       := axiStreamMasterInit(MASTER_AXI_CONFIG_G);
               v.obMaster.tKeep := (others => '0');
               v.obMaster.tStrb := (others => '0');
            end if;

            v.obMaster.tData((SLV_BYTES_C*8*idx)+((SLV_BYTES_C*8)-1) downto (SLV_BYTES_C*8*idx)) := ibM.tData((SLV_BYTES_C*8)-1 downto 0);
            v.obMaster.tUser((SLV_BYTES_C*8*idx)+((SLV_BYTES_C*8)-1) downto (SLV_BYTES_C*8*idx)) := ibM.tUser((SLV_BYTES_C*8)-1 downto 0);
            v.obMaster.tStrb((SLV_BYTES_C*idx)+(SLV_BYTES_C-1) downto (SLV_BYTES_C*idx))         := ibM.tStrb(SLV_BYTES_C-1 downto 0);
            v.obMaster.tKeep((SLV_BYTES_C*idx)+(SLV_BYTES_C-1) downto (SLV_BYTES_C*idx))         := ibM.tKeep(SLV_BYTES_C-1 downto 0);

            v.obMaster.tId   := ibM.tId;
            v.obMaster.tDest := ibM.tDest;
            v.obMaster.tLast := ibM.tLast;
            v.sideBand       := ibSide;

            -- Determine if we move data
            if ibM.tValid = '1' then
               if r.count = (COUNT_C-1) or ibM.tLast = '1' then
                  v.obMaster.tValid := '1';
                  v.count           := (others => '0');
               else
                  v.count := r.count + 1;
               end if;
            end if;

         -- Decreasing size
         else

            v.obMaster := axiStreamMasterInit(MASTER_AXI_CONFIG_G);

            v.obMaster.tData((MST_BYTES_C*8)-1 downto 0) := ibM.tData((MST_BYTES_C*8*idx)+((MST_BYTES_C*8)-1) downto (MST_BYTES_C*8*idx));
            v.obMaster.tUser((MST_BYTES_C*8)-1 downto 0) := ibM.tUser((MST_BYTES_C*8*idx)+((MST_BYTES_C*8)-1) downto (MST_BYTES_C*8*idx));
            v.obMaster.tStrb(MST_BYTES_C-1 downto 0)     := ibM.tStrb((MST_BYTES_C*idx)+(MST_BYTES_C-1) downto (MST_BYTES_C*idx));
            v.obMaster.tKeep(MST_BYTES_C-1 downto 0)     := ibM.tKeep((MST_BYTES_C*idx)+(MST_BYTES_C-1) downto (MST_BYTES_C*idx));

            v.obMaster.tId   := ibM.tId;
            v.obMaster.tDest := ibM.tDest;
            v.sideBand       := ibSide;

            -- Determine if we move data
            if ibM.tValid = '1' then
               if (r.count = (COUNT_C-1)) or ((bytes >= byteCnt) and (ibM.tLast = '1')) then
                  v.count          := (others => '0');
                  v.ibSlave.tReady := '1';
                  v.obMaster.tLast := ibM.tLast;
               else
                  v.count          := r.count + 1;
                  v.ibSlave.tReady := '0';
                  v.obMaster.tLast := '0';
               end if;
            end if;

            -- Drop transfers with no tKeep bits set, except on tLast
            v.obMaster.tValid := ibM.tValid and (uOr(v.obMaster.tKeep(COUNT_C-1 downto 0)) or v.obMaster.tLast);

         end if;
      end if;

      -- Resize disabled
      if SLV_BYTES_C = MST_BYTES_C then
         sAxisSlave     <= pipeAxisSlave;
         pipeAxisMaster <= sAxisMaster;
         pipeSideBand   <= sSideBand;

         -- Check for TKEEP_COUNT_C mode on either side
         if (SLAVE_AXI_CONFIG_G.TKEEP_MODE_C = TKEEP_COUNT_C) or (MASTER_AXI_CONFIG_G.TKEEP_MODE_C = TKEEP_COUNT_C) then

            -- Check for TKEEP_COUNT_C mode on slave side only
            if (SLAVE_AXI_CONFIG_G.TKEEP_MODE_C = TKEEP_COUNT_C) and (MASTER_AXI_CONFIG_G.TKEEP_MODE_C /= TKEEP_COUNT_C) then
               pipeAxisMaster.tkeep <= genTKeep(conv_integer(sAxisMaster.tkeep(bitSize(SLAVE_AXI_CONFIG_G.TDATA_BYTES_C)-1 downto 0)));

            -- Check for TKEEP_COUNT_C mode on master side only
            elsif (SLAVE_AXI_CONFIG_G.TKEEP_MODE_C /= TKEEP_COUNT_C) and (MASTER_AXI_CONFIG_G.TKEEP_MODE_C = TKEEP_COUNT_C) then
               pipeAxisMaster.tkeep <= toSlv(getTKeep(sAxisMaster.tKeep, SLAVE_AXI_CONFIG_G), AXI_STREAM_MAX_TKEEP_WIDTH_C);

            -- Else both sides are TKEEP_COUNT_C mode
            else
               null;
            end if;
         end if;

         -- Outbound data with proper user bits
         pipeAxisMaster.tUser <= (others => '0');
         for i in 0 to AXI_STREAM_MAX_TKEEP_WIDTH_C-1 loop
            if (SLV_USER_C > MST_USER_C) then
               pipeAxisMaster.tUser((i*MST_USER_C)+(MST_USER_C-1) downto (i*MST_USER_C)) <= ibM.tUser((i*8)+(MST_USER_C-1) downto (i*8));
            else
               pipeAxisMaster.tUser((i*MST_USER_C)+(SLV_USER_C-1) downto (i*MST_USER_C)) <= ibM.tUser((i*8)+(SLV_USER_C-1) downto (i*8));
            end if;
         end loop;

      else
         sAxisSlave <= v.ibSlave;

         -- Outbound data with proper user bits
         pipeAxisMaster       <= r.obMaster;
         pipeSideBand         <= r.sideBand;
         pipeAxisMaster.tUser <= (others => '0');
         if (MASTER_AXI_CONFIG_G.TKEEP_MODE_C = TKEEP_COUNT_C) then
            pipeAxisMaster.tKeep <= toSlv(getTKeep(r.obMaster.tKeep, MASTER_AXI_CONFIG_G), AXI_STREAM_MAX_TKEEP_WIDTH_C);
         end if;

         for i in 0 to AXI_STREAM_MAX_TKEEP_WIDTH_C-1 loop
            pipeAxisMaster.tUser((i*MST_USER_C)+(MST_USER_C-1) downto (i*MST_USER_C)) <= r.obMaster.tUser((i*8)+(MST_USER_C-1) downto (i*8));
         end loop;
      end if;

      rin <= v;

   end process comb;

   seq : process (axisClk) is
   begin
      if (rising_edge(axisClk)) then
         if axisRst = '1' or (SLV_BYTES_C = MST_BYTES_C) then
            r <= REG_INIT_C after TPD_G;
         else
            r <= rin after TPD_G;
         end if;
      end if;
   end process seq;

   -- Optional output pipeline registers to ease timing
   AxiStreamPipeline_1 : entity surf.AxiStreamPipeline
      generic map (
         TPD_G             => TPD_G,
         SIDE_BAND_WIDTH_G => SIDE_BAND_WIDTH_G,
         PIPE_STAGES_G     => PIPE_STAGES_G)
      port map (
         axisClk     => axisClk,
         axisRst     => axisRst,
         sAxisMaster => pipeAxisMaster,
         sSideBand   => pipeSideBand,
         sAxisSlave  => pipeAxisSlave,
         mAxisMaster => mAxisMaster,
         mSideBand   => mSideBand,
         mAxisSlave  => mAxisSlave);

end rtl;

