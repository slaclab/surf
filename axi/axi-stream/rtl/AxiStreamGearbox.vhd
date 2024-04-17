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

entity AxiStreamGearbox is
   generic (
      -- General Configurations
      TPD_G               : time     := 1 ns;
      RST_ASYNC_G         : boolean  := false;
      READY_EN_G          : boolean  := true;
      PIPE_STAGES_G       : natural  := 0;
      SIDE_BAND_WIDTH_G   : positive := 1;  -- General purpose sideband
      -- AXI Stream Port Configurations
      SLAVE_AXI_CONFIG_G  : AxiStreamConfigType;
      MASTER_AXI_CONFIG_G : AxiStreamConfigType);
   port (
      -- Clock and reset
      axisClk     : in  sl;
      axisRst     : in  sl;
      -- Slave Port
      sAxisMaster : in  AxiStreamMasterType;
      sSideBand   : in  slv(SIDE_BAND_WIDTH_G-1 downto 0) := (others => '0');
      sAxisSlave  : out AxiStreamSlaveType;
      -- Master Port
      mAxisMaster : out AxiStreamMasterType;
      mSideBand   : out slv(SIDE_BAND_WIDTH_G-1 downto 0);
      mAxisSlave  : in  AxiStreamSlaveType);
end AxiStreamGearbox;

architecture rtl of AxiStreamGearbox is

   constant SLV_BYTES_C : positive := SLAVE_AXI_CONFIG_G.TDATA_BYTES_C;
   constant MST_BYTES_C : positive := MASTER_AXI_CONFIG_G.TDATA_BYTES_C;

   constant SLV_USER_C : positive := ite(SLAVE_AXI_CONFIG_G.TUSER_BITS_C /= 0, SLAVE_AXI_CONFIG_G.TUSER_BITS_C, 1);
   constant MST_USER_C : positive := ite(MASTER_AXI_CONFIG_G.TUSER_BITS_C /= 0, MASTER_AXI_CONFIG_G.TUSER_BITS_C, 1);

   constant WORD_MULTIPLE_C : boolean := (SLV_BYTES_C >= MST_BYTES_C and SLV_BYTES_C mod MST_BYTES_C = 0)
                                         or (MST_BYTES_C >= SLV_BYTES_C and MST_BYTES_C mod SLV_BYTES_C = 0);

   constant TSTRB_EN_C : boolean := SLAVE_AXI_CONFIG_G.TSTRB_EN_C and MASTER_AXI_CONFIG_G.TSTRB_EN_C;
   constant TDEST_EN_C : boolean := (SLAVE_AXI_CONFIG_G.TDEST_BITS_C > 0) and (MASTER_AXI_CONFIG_G.TDEST_BITS_C > 0);
   constant TID_EN_C   : boolean := (SLAVE_AXI_CONFIG_G.TID_BITS_C > 0) and (MASTER_AXI_CONFIG_G.TID_BITS_C > 0);
   constant TUSER_EN_C : boolean := (SLAVE_AXI_CONFIG_G.TUSER_BITS_C > 0) and (MASTER_AXI_CONFIG_G.TUSER_BITS_C > 0)
                                    and (SLAVE_AXI_CONFIG_G.TUSER_MODE_C /= TUSER_NONE_C) and (MASTER_AXI_CONFIG_G.TUSER_MODE_C /= TUSER_NONE_C);

   constant TDEST_BITS_C : natural := ite(TDEST_EN_C, minimum(SLAVE_AXI_CONFIG_G.TDEST_BITS_C, MASTER_AXI_CONFIG_G.TDEST_BITS_C), 1);
   constant TID_BITS_C   : natural := ite(TID_EN_C, minimum(SLAVE_AXI_CONFIG_G.TID_BITS_C, MASTER_AXI_CONFIG_G.TID_BITS_C), 1);
   constant TUSER_BITS_C : natural := ite(TUSER_EN_C, minimum(SLAVE_AXI_CONFIG_G.TUSER_BITS_C, MASTER_AXI_CONFIG_G.TUSER_BITS_C), 1);

   constant MAX_C : positive := maximum(MST_BYTES_C, SLV_BYTES_C);
   constant MIN_C : positive := minimum(MST_BYTES_C, SLV_BYTES_C);

   constant SHIFT_WIDTH_C : positive := wordCount(MAX_C, MIN_C) * MIN_C + MIN_C;

   type RegType is record
      writeIndex : natural range 0 to SHIFT_WIDTH_C-1;
      tValid     : sl;
      tData      : slv(8*SHIFT_WIDTH_C-1 downto 0);
      tStrb      : slv(1*SHIFT_WIDTH_C-1 downto 0);
      tKeep      : slv(1*SHIFT_WIDTH_C-1 downto 0);
      tLast      : sl;
      tLastDly   : sl;
      tDest      : slv(TDEST_BITS_C-1 downto 0);
      tId        : slv(TID_BITS_C-1 downto 0);
      tUser      : slv(TUSER_BITS_C*SHIFT_WIDTH_C-1 downto 0);
      sideBand   : slv(SIDE_BAND_WIDTH_G-1 downto 0);
      sAxisSlave : AxiStreamSlaveType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      writeIndex => 0,
      tValid     => '0',
      tData      => (others => '0'),
      tStrb      => (others => '0'),
      tKeep      => (others => '0'),
      tLast      => '0',
      tLastDly   => '0',
      tDest      => (others => '0'),
      tId        => (others => '0'),
      tUser      => (others => '0'),
      sideBand   => (others => '0'),
      sAxisSlave => AXI_STREAM_SLAVE_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal pipeAxisMaster : AxiStreamMasterType;
   signal pipeSideBand   : slv(SIDE_BAND_WIDTH_G-1 downto 0);
   signal pipeAxisSlave  : AxiStreamSlaveType;

begin

   -- When going from a large bus to a small bus, ready is necessary
   assert (SLV_BYTES_C <= MST_BYTES_C or READY_EN_G = true)
      report "READY_EN_G must be true if slave width is great than master" severity failure;

   -- Cant use tkeep_fixed on master side when resizing or if not on slave side
   assert (not (MASTER_AXI_CONFIG_G.TKEEP_MODE_C = TKEEP_FIXED_C and
                SLAVE_AXI_CONFIG_G.TKEEP_MODE_C /= TKEEP_FIXED_C))
      report "AxiStreamGearbox: Can't have TKEEP_MODE = TKEEP_FIXED on master side if not on slave side"
      severity error;

   ---------------------------------------------------------
   -- Use AxiStreamResize if word multiple because less LUTs
   ---------------------------------------------------------
   GEN_RESIZE : if (WORD_MULTIPLE_C = true) generate

      U_Resize : entity surf.AxiStreamResize
         generic map (
            -- General Configurations
            TPD_G               => TPD_G,
            RST_ASYNC_G         => RST_ASYNC_G,
            READY_EN_G          => READY_EN_G,
            PIPE_STAGES_G       => PIPE_STAGES_G,
            SIDE_BAND_WIDTH_G   => SIDE_BAND_WIDTH_G,
            -- AXI Stream Port Configurations
            SLAVE_AXI_CONFIG_G  => SLAVE_AXI_CONFIG_G,
            MASTER_AXI_CONFIG_G => MASTER_AXI_CONFIG_G)
         port map (
            -- Clock and reset
            axisClk     => axisClk,
            axisRst     => axisRst,
            -- Slave Port
            sAxisMaster => sAxisMaster,
            sSideBand   => sSideBand,
            sAxisSlave  => sAxisSlave,
            -- Master Port
            mAxisMaster => mAxisMaster,
            mSideBand   => mSideBand,
            mAxisSlave  => mAxisSlave);

   end generate;

   GEN_GEARBOX : if (WORD_MULTIPLE_C = false) generate

      comb : process (axisRst, pipeAxisSlave, r, sAxisMaster, sSideBand) is
         variable v : RegType;
      begin
         -- Latch the current value
         v := r;

         -- Flow Control
         v.sAxisSlave.tReady := '0';
         if (pipeAxisSlave.tReady = '1') or (READY_EN_G = false) then

            v.tValid := '0';
            v.tLast  := '0';

            -- Check if previous word terminated the frame
            if (r.tLast = '1') then

               -- Reset the sequence
               v.writeIndex := 0;
               v.tStrb      := (others => '0');
               v.tKeep      := (others => '0');

            end if;

         end if;

         -- Only do anything if ready for data output
         if (v.tValid = '0') then

            -- If current write index (assigned last cycle) is greater than output width, then we have to shift down before assigning an new input
            if (v.writeIndex >= MST_BYTES_C) then

               -- Decrement the counter
               v.writeIndex := v.writeIndex - MST_BYTES_C;

               -- Shift TDATA with zero padding
               v.tData := slvZero(8*MST_BYTES_C) & r.tData(8*SHIFT_WIDTH_C-1 downto 8*MST_BYTES_C);

               -- Check if TSTRB enabled
               if(TSTRB_EN_C) then
                  -- Shift TSTRB with zero padding
                  v.tStrb := slvZero(1*MST_BYTES_C) & r.tStrb(1*SHIFT_WIDTH_C-1 downto 1*MST_BYTES_C);
               end if;

               -- Shift TKEEP with zero padding
               v.tKeep := slvZero(1*MST_BYTES_C) & r.tKeep(1*SHIFT_WIDTH_C-1 downto 1*MST_BYTES_C);

               -- Check if TUSER enabled
               if (TUSER_EN_C) then
                  -- Shift TUSER with zero padding
                  v.tUser := slvZero(TUSER_BITS_C*MST_BYTES_C) & r.tUser(TUSER_BITS_C*SHIFT_WIDTH_C-1 downto TUSER_BITS_C*MST_BYTES_C);
               end if;

               -- If write index still greater than output width after shift, then we have a valid word to output
               if (v.writeIndex >= MST_BYTES_C) or (r.tLastDly = '1') then

                  -- Set the flags
                  v.tValid   := '1';
                  if (v.writeIndex <= MST_BYTES_C) then
                     v.tLast    := r.tLastDly;
                     v.tLastDly := '0';
                  end if;

               end if;

            end if;
         end if;

         -- Accept new data if ready to output and shift above did not create an output valid or terminate the frame
         if (sAxisMaster.tValid = '1') and (v.tValid = '0') and (v.tLast = '0') then

            -- Accept the input word
            v.sAxisSlave.tReady := '1';

            -- Assign incoming sideband
            v.sideBand := sSideBand;

            -- Assign incoming TDATA
            v.tData(8*v.writeIndex+8*SLV_BYTES_C-1 downto 8*v.writeIndex) := sAxisMaster.tData(8*SLV_BYTES_C-1 downto 0);

            -- Check if TSTRB enabled
            if(TSTRB_EN_C) then
               -- Assign incoming TSTRB
               v.tStrb(1*v.writeIndex+1*SLV_BYTES_C-1 downto 1*v.writeIndex) := sAxisMaster.tStrb(1*SLV_BYTES_C-1 downto 0);
            end if;

            -- Assign incoming TKEEP
            if (SLAVE_AXI_CONFIG_G.TKEEP_MODE_C = TKEEP_COUNT_C) then
               v.tKeep(1*v.writeIndex+1*SLV_BYTES_C-1 downto 1*v.writeIndex) := genTKeep(conv_integer(sAxisMaster.tKeep(bitSize(SLV_BYTES_C)-1 downto 0)));
            else
               v.tKeep(1*v.writeIndex+1*SLV_BYTES_C-1 downto 1*v.writeIndex) := sAxisMaster.tKeep(1*SLV_BYTES_C-1 downto 0);
            end if;

            -- Check if TDEST enabled
            if(TDEST_EN_C) then
               v.tDest := sAxisMaster.tDest(TDEST_BITS_C-1 downto 0);
            end if;

            -- Check if TID enabled
            if(TID_EN_C) then
               v.tId := sAxisMaster.tId(TID_BITS_C-1 downto 0);
            end if;

            if (TUSER_EN_C) then
               for i in 0 to SLV_BYTES_C-1 loop
                  v.tUser(
                     (TUSER_BITS_C*v.writeIndex)+(i*TUSER_BITS_C)+(TUSER_BITS_C-1) downto
                     (TUSER_BITS_C*v.writeIndex)+(i*TUSER_BITS_C)) :=
                     sAxisMaster.tUser((i*SLV_USER_C)+(TUSER_BITS_C-1) downto (i*SLV_USER_C));
               end loop;
            end if;

            -- Increment writeIndex
            v.writeIndex := v.writeIndex + getTKeep(resize(sAxisMaster.tKeep(1*SLV_BYTES_C-1 downto 0), AXI_STREAM_MAX_TKEEP_WIDTH_C), SLAVE_AXI_CONFIG_G);

            -- Assert tValid
            if (v.writeIndex >= MST_BYTES_C) or (sAxisMaster.tLast = '1') then

               -- Set the flags
               v.tValid   := '1';
               v.tLast    := '0';
               v.tLastDly := '0';

               -- Check if spans frame termination two cycles
               if (v.writeIndex > MST_BYTES_C) then
                  v.tLastDly := sAxisMaster.tLast;
               else
                  v.tLast := sAxisMaster.tLast;
               end if;

            end if;

         end if;

         -- Outputs
         sAxisSlave   <= v.sAxisSlave;
         pipeSideBand <= r.sideBand;

         pipeAxisMaster.tValid <= r.tValid;

         pipeAxisMaster.tData                           <= (others => '0');
         pipeAxisMaster.tData(8*MST_BYTES_C-1 downto 0) <= r.tData(8*MST_BYTES_C-1 downto 0);

         pipeAxisMaster.tStrb <= (others => '0');
         if(TSTRB_EN_C) then
            pipeAxisMaster.tStrb(1*MST_BYTES_C-1 downto 0) <= r.tData(1*MST_BYTES_C-1 downto 0);
         else
            pipeAxisMaster.tStrb(1*MST_BYTES_C-1 downto 0) <= (others => '1');
         end if;

         if (MASTER_AXI_CONFIG_G.TKEEP_MODE_C = TKEEP_COUNT_C) then
            pipeAxisMaster.tKeep <= toSlv(getTKeep(resize(r.tKeep(1*MST_BYTES_C-1 downto 0), AXI_STREAM_MAX_TKEEP_WIDTH_C), MASTER_AXI_CONFIG_G), AXI_STREAM_MAX_TKEEP_WIDTH_C);
         else
            pipeAxisMaster.tKeep                           <= (others => '0');
            pipeAxisMaster.tKeep(1*MST_BYTES_C-1 downto 0) <= r.tKeep(1*MST_BYTES_C-1 downto 0);
         end if;

         pipeAxisMaster.tLast <= r.tLast;

         pipeAxisMaster.tDest <= (others => '0');
         if(TDEST_EN_C) then
            pipeAxisMaster.tDest(TDEST_BITS_C-1 downto 0) <= r.tDest;
         end if;

         pipeAxisMaster.tId <= (others => '0');
         if(TID_EN_C) then
            pipeAxisMaster.tId(TID_BITS_C-1 downto 0) <= r.tId;
         end if;

         pipeAxisMaster.tUser <= (others => '0');
         if (TUSER_EN_C) then
            for i in 0 to MST_BYTES_C-1 loop
               pipeAxisMaster.tUser((i*MST_USER_C)+(TUSER_BITS_C-1) downto (i*MST_USER_C)) <=
                  r.tUser((i*TUSER_BITS_C)+(TUSER_BITS_C-1) downto (i*TUSER_BITS_C));
            end loop;
         end if;

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

      ----------------------------------------------------
      -- Optional output pipeline registers to ease timing
      ----------------------------------------------------
      U_Pipeline : entity surf.AxiStreamPipeline
         generic map (
            TPD_G             => TPD_G,
            RST_ASYNC_G       => RST_ASYNC_G,
            SIDE_BAND_WIDTH_G => SIDE_BAND_WIDTH_G,
            PIPE_STAGES_G     => PIPE_STAGES_G)
         port map (
            -- Clock and Reset
            axisClk     => axisClk,
            axisRst     => axisRst,
            -- Slave Port
            sAxisMaster => pipeAxisMaster,
            sSideBand   => pipeSideBand,
            sAxisSlave  => pipeAxisSlave,
            -- Master Port
            mAxisMaster => mAxisMaster,
            mSideBand   => mSideBand,
            mAxisSlave  => mAxisSlave);

   end generate;

end rtl;

