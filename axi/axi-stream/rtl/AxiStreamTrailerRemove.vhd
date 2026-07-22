-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
-- Removes bytes from end of a AXI stream frame
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

entity AxiStreamTrailerRemove is
   generic (
      TPD_G          : time    := 1 ns;
      RST_POLARITY_G : sl      := '1';  -- '1' for active HIGH reset, '0' for active LOW reset
      RST_ASYNC_G    : boolean := false;
      PIPE_STAGES_G  : natural := 0;
      BYTES_TO_RM_G  : integer := 4;
      AXI_CONFIG_G   : AxiStreamConfigType);
   port (
      -- Clock and Reset
      axisClk     : in  sl;
      axisRst     : in  sl;
      -- Inbound AXI Stream
      sAxisMaster : in  AxiStreamMasterType;
      sAxisSlave  : out AxiStreamSlaveType;
      -- Inbound AXI Stream
      mAxisMaster : out AxiStreamMasterType;
      mAxisSlave  : in  AxiStreamSlaveType);
end entity AxiStreamTrailerRemove;

architecture rtl of AxiStreamTrailerRemove is

   constant BYTES_C : positive := AXI_CONFIG_G.TDATA_BYTES_C;

   -- The trailer can spill across a beat boundary, so the stream is delayed by
   -- one beat in r.held: when the tLast beat arrives its tKeep count tells
   -- whether the buffered beat must be shortened and become the new tLast.
   -- Both the delay buffer and the output register are advanced by a single
   -- ready/valid handshake (a beat is consumed from the slave port in exactly
   -- the cycle sAxisSlave.tReady is asserted).
   type RegType is record
      obMaster : AxiStreamMasterType;
      held     : AxiStreamMasterType;
      ibSlave  : AxiStreamSlaveType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      obMaster => axiStreamMasterInit(AXI_CONFIG_G),
      held     => axiStreamMasterInit(AXI_CONFIG_G),
      ibSlave  => AXI_STREAM_SLAVE_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal pipeAxisMaster : AxiStreamMasterType;
   signal pipeAxisSlave  : AxiStreamSlaveType;

begin

   -- Make sure data widths are appropriate
   assert (BYTES_C >= BYTES_TO_RM_G)
      report "Axi-Stream data widths must be greater or equal than trailer" severity failure;

   comb : process (axisRst, pipeAxisSlave, r, sAxisMaster) is
      variable v       : RegType;
      variable count   : integer range 0 to AXI_CONFIG_G.TDATA_BYTES_C;
      variable heldCnt : integer range 0 to AXI_CONFIG_G.TDATA_BYTES_C;
      variable toRm    : integer range 0 to BYTES_TO_RM_G;
   begin  -- process comb
      v := r;

      -- Init ready
      v.ibSlave.tReady := '0';

      -- Clear valid once the output register has been consumed
      if (pipeAxisSlave.tReady = '1') then
         v.obMaster.tValid := '0';
      end if;

      -- Move data when the output register is free
      if v.obMaster.tValid = '0' then

         if sAxisMaster.tValid = '1' then
            -- Accept the input beat
            v.ibSlave.tReady := '1';
            count            := getTKeep(sAxisMaster.tKeep, AXI_CONFIG_G);

            if r.held.tValid = '1' then
               -- Drain the delay buffer into the output register
               v.obMaster := r.held;
               if (sAxisMaster.tLast = '1') and (count <= BYTES_TO_RM_G) then
                  -- Trailer spills into the buffered beat: shorten it,
                  -- terminate the frame and drop the all-trailer input beat
                  toRm                                        := BYTES_TO_RM_G - count;
                  heldCnt                                     := getTKeep(r.held.tKeep, AXI_CONFIG_G);
                  v.obMaster.tLast                            := '1';
                  v.obMaster.tKeep                            := (others => '0');
                  v.obMaster.tKeep((heldCnt-toRm)-1 downto 0) := (others => '1');
                  v.held.tValid                               := '0';
               else
                  v.held := sAxisMaster;
                  if sAxisMaster.tLast = '1' then
                     -- Trailer fits inside the last beat: shorten it
                     v.held.tKeep                                   := (others => '0');
                     v.held.tKeep((count-BYTES_TO_RM_G)-1 downto 0) := (others => '1');
                  end if;
               end if;

            else
               -- Delay buffer empty (start of frame)
               if (sAxisMaster.tLast = '1') and (count <= BYTES_TO_RM_G) then
                  -- Degenerate frame no longer than the trailer: drop it
                  null;
               else
                  v.held := sAxisMaster;
                  if sAxisMaster.tLast = '1' then
                     -- Single-beat frame: shorten it
                     v.held.tKeep                                   := (others => '0');
                     v.held.tKeep((count-BYTES_TO_RM_G)-1 downto 0) := (others => '1');
                  end if;
               end if;
            end if;

         elsif (r.held.tValid = '1') and (r.held.tLast = '1') then
            -- Frame already terminated inside the delay buffer: drain it
            v.obMaster    := r.held;
            v.held.tValid := '0';
         end if;

      end if;

      -- Outputs
      sAxisSlave     <= v.ibSlave;
      pipeAxisMaster <= r.obMaster;

      -- Reset
      if (RST_ASYNC_G = false and axisRst = RST_POLARITY_G) then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
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

   -- Optional output pipeline registers to ease timing
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
