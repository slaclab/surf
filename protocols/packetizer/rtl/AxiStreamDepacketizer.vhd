-------------------------------------------------------------------------------
-- Title      : AxiStreamPackerizerV0 Protocol: https://confluence.slac.stanford.edu/x/1oyfD
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: AXI stream DePacketerizer Module (non-interleave only)
--    Formats an AXI-Stream for a transport link.
--    Sideband fields are placed into the data stream in a header.
--    Long frames are broken into smaller packets.
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
use surf.SsiPkg.all;

entity AxiStreamDepacketizer is
   generic (
      TPD_G                : time    := 1 ns;
      RST_ASYNC_G          : boolean := false;
      INPUT_PIPE_STAGES_G  : integer := 0;
      OUTPUT_PIPE_STAGES_G : integer := 0);
   port (
      -- AXI-Lite Interface for local registers
      axisClk : in sl;
      axisRst : in sl;

      restart : in sl := '0';  -- Reset the expected frame number back to 0

      sAxisMaster : in  AxiStreamMasterType;
      sAxisSlave  : out AxiStreamSlaveType;

      mAxisMaster : out AxiStreamMasterType;
      mAxisSlave  : in  AxiStreamSlaveType);
end entity AxiStreamDepacketizer;

architecture rtl of AxiStreamDepacketizer is

   constant AXIS_CONFIG_C : AxiStreamConfigType := (
      TSTRB_EN_C    => false,
      TDATA_BYTES_C => 8,
      TDEST_BITS_C  => 8,
      TID_BITS_C    => 8,
      TKEEP_MODE_C  => TKEEP_NORMAL_C,
      TUSER_BITS_C  => 8,
      TUSER_MODE_C  => TUSER_FIRST_LAST_C);

   constant VERSION_C : slv(3 downto 0) := "0000";

   type StateType is (HEADER_S, BLEED_S, MOVE_S, DONE_S);

   type RegType is record
      state            : StateType;
      frameNumber      : slv(11 downto 0);
      packetNumber     : slv(23 downto 0);
      sof              : sl;
      startup          : sl;
      sideband         : sl;
      inputAxisSlave   : AxiStreamSlaveType;
      outputAxisMaster : AxiStreamMasterArray(1 downto 0);
   end record RegType;

   constant REG_INIT_C : RegType := (
      state            => HEADER_S,
      frameNumber      => (others => '0'),
      packetNumber     => (others => '0'),
      sof              => '1',
      startup          => '1',
      sideband         => '0',
      inputAxisSlave   => AXI_STREAM_SLAVE_INIT_C,
      outputAxisMaster => (others => axiStreamMasterInit(AXIS_CONFIG_C)));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal inputAxisMaster  : AxiStreamMasterType;
   signal inputAxisSlave   : AxiStreamSlaveType;
   signal outputAxisMaster : AxiStreamMasterType;
   signal outputAxisSlave  : AxiStreamSlaveType;

   -- attribute dont_touch                     : string;
   -- attribute dont_touch of r                : signal is "TRUE";
   -- attribute dont_touch of inputAxisMaster  : signal is "TRUE";
   -- attribute dont_touch of inputAxisSlave   : signal is "TRUE";
   -- attribute dont_touch of outputAxisMaster : signal is "TRUE";
   -- attribute dont_touch of outputAxisSlave  : signal is "TRUE";

begin

   -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
   -- Input pipeline
   -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
   U_AxiStreamPipeline_Input : entity surf.AxiStreamPipeline
      generic map (
         TPD_G         => TPD_G,
         RST_ASYNC_G   => RST_ASYNC_G,
         PIPE_STAGES_G => INPUT_PIPE_STAGES_G)
      port map (
         axisClk     => axisClk,          -- [in]
         axisRst     => axisRst,          -- [in]
         sAxisMaster => sAxisMaster,      -- [in]
         sAxisSlave  => sAxisSlave,       -- [out]
         mAxisMaster => inputAxisMaster,  -- [out]
         mAxisSlave  => inputAxisSlave);  -- [in]

   -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
   -- Output pipeline
   -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
   U_AxiStreamPipeline_Output : entity surf.AxiStreamPipeline
      generic map (
         TPD_G         => TPD_G,
         RST_ASYNC_G   => RST_ASYNC_G,
         PIPE_STAGES_G => OUTPUT_PIPE_STAGES_G)
      port map (
         axisClk     => axisClk,           -- [in]
         axisRst     => axisRst,           -- [in]
         sAxisMaster => outputAxisMaster,  -- [in]
         sAxisSlave  => outputAxisSlave,   -- [out]
         mAxisMaster => mAxisMaster,       -- [out]
         mAxisSlave  => mAxisSlave);       -- [in]

   -------------------------------------------------------------------------------------------------
   -- Accumulation sequencing, DMA ring buffer, and AXI-Lite logic
   -------------------------------------------------------------------------------------------------
   comb : process (axisRst, inputAxisMaster, outputAxisSlave, r, restart) is
      variable v : RegType;

   begin
      -- Latch the current value
      v := r;

      -- Check for restart
      if (restart = '1') then
         v.startup := '1';
         v.sof     := '1';
      end if;

      -- Reset tready by default
      v.inputAxisSlave.tready := '0';

      -- Check if data accepted
      if (outputAxisSlave.tReady = '1') then
         v.outputAxisMaster(1).tValid := '0';
         v.outputAxisMaster(0).tValid := '0';
      end if;

      case r.state is
         ----------------------------------------------------------------------
         when HEADER_S =>
            -- Accept new data
            v.inputAxisSlave.tready := '1';

            -- Initialize the AXIS[1] buffer
            v.outputAxisMaster(1) := axiStreamMasterInit(AXIS_CONFIG_C);

            -- Advance the output pipeline
            if (r.outputAxisMaster(1).tValid = '1' and v.outputAxisMaster(0).tValid = '0') then
               v.outputAxisMaster(0) := r.outputAxisMaster(1);
            end if;

            -- Process an incoming transaction (which should be the header)
            if (inputAxisMaster.tValid = '1' and v.outputAxisMaster(1).tValid = '0') then

               -- Default next state if v.state=MOVE_S not applied later in the combinatorial chain
               v.state := MOVE_S;

               -- Assign sideband fields
               v.outputAxisMaster(1).tDest(7 downto 0) := inputAxisMaster.tData(47 downto 40);
               v.outputAxisMaster(1).tId(7 downto 0)   := inputAxisMaster.tData(55 downto 48);
               v.outputAxisMaster(1).tUser(7 downto 0) := inputAxisMaster.tData(63 downto 56);

               -- Assert SOF if starting a new frame
               axiStreamSetUserBit(AXIS_CONFIG_C, v.outputAxisMaster(1), SSI_SOF_C, r.sof, 0);  -- SOF

               -- Reset the SOF flag
               v.sof := '0';

               -- Check for SOF
               if (r.sof = '1') then
                  -- Update local copy of frame number
                  v.frameNumber  := inputAxisMaster.tData(15 downto 4);
                  -- Check the packet number because SOF
                  v.packetNumber := (others => '0');
                  -- Check for errors
                  if ((r.startup = '0' and inputAxisMaster.tData(15 downto 4) /= r.frameNumber+1) or  -- not first value after startup and misalignment in frame number
                      inputAxisMaster.tData(39 downto 16) /= 0) then  -- packet number != 0
                     -- Next state
                     v.state := BLEED_S;  -- Error - Missing frames
                  end if;
               -- Else this is a continuation
               else
                  -- Update local copy of packet number
                  v.packetNumber := inputAxisMaster.tData(39 downto 16);
                  -- Check for errors
                  if (inputAxisMaster.tData(15 downto 4) /= r.frameNumber or  -- new frame number != local copy of frame number
                      inputAxisMaster.tData(39 downto 16) /= r.packetNumber+1) then  -- packet number increment by 1 with respect to local copy of packet number
                     -- Terminate the packet
                     v.outputAxisMaster(1).tvalid := '1';
                     v.outputAxisMaster(1).tlast  := '1';
                     -- Set the EOFE flag
                     axiStreamSetUserBit(AXIS_CONFIG_C, v.outputAxisMaster(1), SSI_EOFE_C, '1', 0);
                     -- Next state
                     v.state                      := BLEED_S;
                  end if;
               end if;
               -- Update the flags
               v.startup  := '0';
               v.sideband := '1';
            end if;
         ----------------------------------------------------------------------
         when BLEED_S =>
            -- Blow off the data
            v.inputAxisSlave.tready      := '1';
            v.outputAxisMaster(1).tvalid := '0';
            -- Set startup and SOF true
            v.sof                        := '1';
            v.startup                    := '1';
            -- Check for EOF
            if (inputAxisMaster.tLast = '1') then
               v.state := HEADER_S;
            end if;
         ----------------------------------------------------------------------
         when MOVE_S =>
            -- Keep the caches copy
            v.outputAxisMaster(1).tvalid := r.outputAxisMaster(1).tvalid;
            -- Check if we can move data
            if (inputAxisMaster.tValid = '1' and v.outputAxisMaster(0).tValid = '0') then
               -- Accept the data
               v.inputAxisSlave.tReady     := '1';
               -- Advance the pipeline
               v.outputAxisMaster(1)       := inputAxisMaster;
               v.outputAxisMaster(0)       := r.outputAxisMaster(1);
               -- Keep sideband data from header
               v.outputAxisMaster(1).tDest := r.outputAxisMaster(1).tDest;
               v.outputAxisMaster(1).tId   := r.outputAxisMaster(1).tId;
               -- Check for sideband
               if (r.sideband = '1') then
                  -- But tUser only for first output txn
                  v.outputAxisMaster(1).tUser := r.outputAxisMaster(1).tUser;
                  -- Reset the flag
                  v.sideband                  := '0';
               end if;
               -- End of frame
               if (inputAxisMaster.tLast = '1') then
                  -- Check tkeep to find tail byte (and strip it out)
                  v.outputAxisMaster(1).tKeep(15 downto 0) := '0' & inputAxisMaster.tKeep(15 downto 1);
                  case (inputAxisMaster.tKeep(7 downto 0)) is
                     when X"01" =>
                        -- Single byte tail, append tUser to previous txn which has been held
                        v.outputAxisMaster(1).tValid              := '0';
                        v.outputAxisMaster(0).tUser(63 downto 56) := '0' & inputAxisMaster.tData(6 downto 0);
                        v.outputAxisMaster(0).tLast               := inputAxisMaster.tData(7);
                        v.sof                                     := inputAxisMaster.tData(7);
                     when X"03" =>
                        v.outputAxisMaster(1).tUser(7 downto 0) := '0' & inputAxisMaster.tData(14 downto 8);
                        v.sof                                   := inputAxisMaster.tData(15);
                     when X"07" =>
                        v.outputAxisMaster(1).tUser(15 downto 8) := '0' & inputAxisMaster.tData(22 downto 16);
                        v.sof                                    := inputAxisMaster.tData(23);
                     when X"0F" =>
                        v.outputAxisMaster(1).tUser(23 downto 16) := '0' & inputAxisMaster.tData(30 downto 24);
                        v.sof                                     := inputAxisMaster.tData(31);
                     when X"1F" =>
                        v.outputAxisMaster(1).tUser(31 downto 24) := '0' & inputAxisMaster.tData(38 downto 32);
                        v.sof                                     := inputAxisMaster.tData(39);
                     when X"3F" =>
                        v.outputAxisMaster(1).tUser(39 downto 32) := '0' & inputAxisMaster.tData(46 downto 40);
                        v.sof                                     := inputAxisMaster.tData(47);
                     when X"7F" =>
                        v.outputAxisMaster(1).tUser(47 downto 40) := '0' & inputAxisMaster.tData(54 downto 48);
                        v.sof                                     := inputAxisMaster.tData(55);
                     when X"FF" =>
                        v.outputAxisMaster(1).tUser(55 downto 48) := '0' & inputAxisMaster.tData(62 downto 56);
                        v.sof                                     := inputAxisMaster.tData(63);
                     when others =>
                        null;
                  end case;
                  v.outputAxisMaster(1).tLast := v.sof;
                  v.state                     := DONE_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when DONE_S =>
            -- Keep the caches copy
            v.outputAxisMaster(1).tvalid := r.outputAxisMaster(1).tvalid;
            -- Check if we can move data
            if (v.outputAxisMaster(0).tValid = '0') then
               -- Advance the pipeline
               v.outputAxisMaster(1).tValid := '0';
               v.outputAxisMaster(0)        := r.outputAxisMaster(1);
               v.state                      := HEADER_S;
            end if;
      ----------------------------------------------------------------------
      end case;

      -- Combinatorial outputs before the reset
      inputAxisSlave <= v.inputAxisSlave;

      -- Reset
      if (RST_ASYNC_G = false and axisRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Hold each out tvalid until next in tvalid arrives
      outputAxisMaster <= r.outputAxisMaster(0);

   end process comb;

   seq : process (axisClk, axisRst) is
   begin
      if (RST_ASYNC_G and axisRst = '1') then
         r <= REG_INIT_C after TPD_G;
      elsif rising_edge(axisClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end architecture rtl;
