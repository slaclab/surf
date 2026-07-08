-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
-- Packs non-full AXI-Stream beats into fully-utilised output words.
-- Simplification assumed: tKeep is always a contiguous mask from bit 0
-- (e.g. 0x00FF is legal, 0x0FF0 is not).
-- Master bus width must be >= slave bus width.
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
use ieee.numeric_std.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;

entity AxiStreamCompact is
   generic (
      TPD_G               : time    := 1 ns;
      RST_POLARITY_G      : sl      := '1';  -- '1' for active HIGH reset, '0' for active LOW reset
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

   constant SLV_BYTES_C : positive := SLAVE_AXI_CONFIG_G.TDATA_BYTES_C;
   constant MST_BYTES_C : positive := MASTER_AXI_CONFIG_G.TDATA_BYTES_C;

   -- accData / accKeep are double-wide so we can always shift new bytes in
   -- at offset r.count without overflow (count < MST_BYTES_C, new bytes
   -- <= SLV_BYTES_C, MST_BYTES_C >= SLV_BYTES_C).
   type RegType is record
      accData     : slv(2*MST_BYTES_C*8 - 1 downto 0);
      accKeep     : slv(2*MST_BYTES_C - 1 downto 0);
      count       : natural range 0 to MST_BYTES_C - 1;  -- buffered byte count
      pendingLast : boolean;  -- a tLast beat overflowed; remainder still in acc
      obMaster    : AxiStreamMasterType;
      ibSlave     : AxiStreamSlaveType;
      tUserSet    : boolean;
   end record RegType;

   constant REG_INIT_C : RegType := (
      accData     => (others => '0'),
      accKeep     => (others => '0'),
      count       => 0,
      pendingLast => false,
      obMaster    => axiStreamMasterInit(MASTER_AXI_CONFIG_G),
      ibSlave     => AXI_STREAM_SLAVE_INIT_C,
      tUserSet    => false);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal pipeAxisMaster : AxiStreamMasterType;
   signal pipeAxisSlave  : AxiStreamSlaveType;

   -- True when the low SLV_BYTES_C of tKeep form a contiguous run of valid
   -- bytes starting at bit 0 (e.g. 0x0F ok, 0xF0 / 0x0D not). This block only
   -- supports that framing; feeding a non-contiguous/high-offset mask is a
   -- design error and is flagged by the assertion below.
   function tKeepContiguousFromZero (
      tKeep : slv;
      bytes : positive)
      return boolean is
      variable seenZero : boolean;
   begin
      seenZero := false;
      for i in 0 to bytes-1 loop
         if tKeep(i) = '0' then
            seenZero := true;
         elsif seenZero then
            return false;
         end if;
      end loop;
      return true;
   end function tKeepContiguousFromZero;

begin

   assert (MST_BYTES_C >= SLV_BYTES_C)
      report "Master data width must be >= slave data width" severity failure;

   -- Enforce the contiguous-from-bit-0 tKeep contract at simulation time
   assert (sAxisMaster.tValid = '0')
      or tKeepContiguousFromZero(sAxisMaster.tKeep(SLV_BYTES_C-1 downto 0), SLV_BYTES_C)
      report "AxiStreamCompact: tKeep must be a contiguous mask from bit 0 (e.g. 0x0F legal, 0xF0/0x0D not)"
      severity failure;

   comb : process (axisRst, pipeAxisSlave, r, sAxisMaster) is
      variable v        : RegType;
      variable newBytes : natural range 0 to SLV_BYTES_C;
      variable total    : natural range 0 to MST_BYTES_C + SLV_BYTES_C;
   begin
      v := r;

      -- Default: block input
      v.ibSlave.tReady := '0';

      -- Free the output slot when downstream consumes the beat
      if pipeAxisSlave.tReady = '1' then
         v.obMaster.tValid := '0';
      end if;

      -- Output slot is free – we can do work
      if v.obMaster.tValid = '0' then

         -- Case A: a previous tLast beat overflowed; flush the remainder first
         if r.pendingLast then
            v.obMaster.tData := (others => '0');
            v.obMaster.tData(MST_BYTES_C*8-1 downto 0) :=
               r.accData(MST_BYTES_C*8-1 downto 0);
            v.obMaster.tKeep := (others => '0');
            v.obMaster.tKeep(MST_BYTES_C-1 downto 0) :=
               r.accKeep(MST_BYTES_C-1 downto 0);
            v.obMaster.tValid := '1';
            v.obMaster.tLast  := '1';
            -- Clear accumulator
            v.accData         := (others => '0');
            v.accKeep         := (others => '0');
            v.count           := 0;
            v.pendingLast     := false;
            v.tUserSet        := false;
            -- Do NOT accept new input this cycle
            v.ibSlave.tReady  := '0';

         -- Case B: normal operation – accept input
         else
            v.ibSlave.tReady := '1';

            if sAxisMaster.tValid = '1' then

               newBytes := conv_integer(onesCount(sAxisMaster.tKeep(SLV_BYTES_C-1 downto 0)));

               -- Latch tUser from the first beat of each packet
               if not r.tUserSet then
                  v.obMaster.tUser := sAxisMaster.tUser;
                  v.obMaster.tDest := sAxisMaster.tDest;
                  v.obMaster.tId   := sAxisMaster.tId;
                  v.tUserSet       := true;
               end if;

               -- Insert new bytes into accumulator at bit-offset r.count
               v.accData := r.accData;
               v.accData(r.count*8 + SLV_BYTES_C*8 - 1 downto r.count*8) :=
                  sAxisMaster.tData(SLV_BYTES_C*8-1 downto 0);

               v.accKeep := r.accKeep;
               v.accKeep(r.count + SLV_BYTES_C - 1 downto r.count) :=
                  sAxisMaster.tKeep(SLV_BYTES_C-1 downto 0);

               total := r.count + newBytes;

               -- Enough bytes to fill an output word?
               if total >= MST_BYTES_C then

                  -- Emit the lower MST_BYTES_C bytes
                  v.obMaster.tData := (others => '0');
                  v.obMaster.tData(MST_BYTES_C*8-1 downto 0) :=
                     v.accData(MST_BYTES_C*8-1 downto 0);
                  v.obMaster.tKeep                         := (others => '0');
                  v.obMaster.tKeep(MST_BYTES_C-1 downto 0) := (others => '1');
                  v.obMaster.tValid                        := '1';
                  v.obMaster.tLast                         := '0';

                  -- Shift the remainder down
                  v.accData := std_logic_vector(
                     shift_right(unsigned(v.accData), MST_BYTES_C*8));
                  v.accKeep := std_logic_vector(
                     shift_right(unsigned(v.accKeep), MST_BYTES_C));

                  v.count := total - MST_BYTES_C;

                  if sAxisMaster.tLast = '1' then
                     if total = MST_BYTES_C then
                        -- Exact fit: tLast goes on this beat, nothing left over
                        v.obMaster.tLast := '1';
                        v.count          := 0;
                        v.tUserSet       := false;
                        v.accData        := (others => '0');
                        v.accKeep        := (others => '0');
                     else
                        -- Overflow: remainder must go out next cycle
                        v.pendingLast := true;
                     end if;
                  end if;

               -- Not enough bytes yet, but this is the last beat – flush partial
               elsif sAxisMaster.tLast = '1' then

                  v.obMaster.tData := (others => '0');
                  v.obMaster.tData(MST_BYTES_C*8-1 downto 0) :=
                     v.accData(MST_BYTES_C*8-1 downto 0);
                  v.obMaster.tKeep := (others => '0');
                  v.obMaster.tKeep(MST_BYTES_C-1 downto 0) :=
                     v.accKeep(MST_BYTES_C-1 downto 0);
                  v.obMaster.tValid := '1';
                  v.obMaster.tLast  := '1';
                  v.count           := 0;
                  v.tUserSet        := false;
                  v.accData         := (others => '0');
                  v.accKeep         := (others => '0');

               -- Still accumulating
               else
                  v.count := total;
               end if;

            end if;  -- sAxisMaster.tValid
         end if;  -- pendingLast / normal
      end if;  -- output slot free

      -- Drive registered outputs to pipeline stage
      sAxisSlave <= v.ibSlave;

      pipeAxisMaster.tData <= (others => '0');
      pipeAxisMaster.tData(MST_BYTES_C*8-1 downto 0) <=
         r.obMaster.tData(MST_BYTES_C*8-1 downto 0);
      pipeAxisMaster.tKeep <= (others => '0');
      pipeAxisMaster.tKeep(MST_BYTES_C-1 downto 0) <=
         r.obMaster.tKeep(MST_BYTES_C-1 downto 0);
      pipeAxisMaster.tValid <= r.obMaster.tValid;
      pipeAxisMaster.tUser  <= r.obMaster.tUser;
      pipeAxisMaster.tLast  <= r.obMaster.tLast;
      pipeAxisMaster.tDest  <= r.obMaster.tDest;
      pipeAxisMaster.tId    <= r.obMaster.tId;

      -- Synchronous reset
      if (RST_ASYNC_G = false and axisRst = RST_POLARITY_G) then
         v := REG_INIT_C;
      end if;

      rin <= v;

   end process comb;

   seq : process (axisClk, axisRst) is
   begin
      if RST_ASYNC_G and (axisRst = RST_POLARITY_G) then
         r <= REG_INIT_C after TPD_G;
      elsif rising_edge(axisClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   AxiStreamPipeline_1 : entity surf.AxiStreamPipeline
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G,
         PIPE_STAGES_G  => PIPE_STAGES_G)
      port map (
         axisClk     => axisClk,
         axisRst     => axisRst,
         sAxisMaster => pipeAxisMaster,
         sAxisSlave  => pipeAxisSlave,
         mAxisMaster => mAxisMaster,
         mAxisSlave  => mAxisSlave);

end architecture rtl;
