-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : AxiStreamDepacketizer
-- Author     : Benjamin Reese  <bareese@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-09-29
-- Last update: 2016-02-02
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Formats an AXI-Stream for a transport link.
-- Sideband fields are placed into the data stream in a header.
-- Long frames are broken into smaller packets.
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

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;

entity AxiStreamDepacketizer is

   generic (
      TPD_G                : time    := 1 ns;
      INPUT_PIPE_STAGES_G  : integer := 0;
      OUTPUT_PIPE_STAGES_G : integer := 0);

   port (
      -- AXI-Lite Interface for local registers 
      axisClk : in sl;
      axisRst : in sl;

      sAxisMaster : in  AxiStreamMasterType;
      sAxisSlave  : out AxiStreamSlaveType;

      mAxisMaster : out AxiStreamMasterType;
      mAxisSlave  : in  AxiStreamSlaveType);

end entity AxiStreamDepacketizer;

architecture rtl of AxiStreamDepacketizer is

   -- TODO: Define ID and TDEST properly!
   constant AXIS_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(8);

   constant VERSION_C : slv(3 downto 0) := "0000";

   type StateType is (HEADER_S, BLEED_S, MOVE_S);

   type RegType is record
      state            : StateType;
      frameNumber      : slv(11 downto 0);
      packetNumber     : slv(23 downto 0);
      sof              : sl;
      startup          : sl;
      inputAxisSlave   : AxiStreamSlaveType;
      outputAxisMaster : AxiStreamMasterArray(1 downto 0);
   end record RegType;

   constant REG_INIT_C : RegType := (
      state            => HEADER_S,
      frameNumber      => (others => '0'),
      packetNumber     => (others => '0'),
      sof              => '1',
      startup          => '1',
      inputAxisSlave   => AXI_STREAM_SLAVE_INIT_C,
      outputAxisMaster => (others => axiStreamMasterInit(AXIS_CONFIG_C)));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal inputAxisMaster  : AxiStreamMasterType;
   signal inputAxisSlave   : AxiStreamSlaveType;
   signal outputAxisMaster : AxiStreamMasterType;
   signal outputAxisSlave  : AxiStreamSlaveType;

begin

   -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
   -- Input pipeline
   -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
   U_AxiStreamPipeline_Input : entity work.AxiStreamPipeline
      generic map (
         TPD_G         => TPD_G,
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
   U_AxiStreamPipeline_Output : entity work.AxiStreamPipeline
      generic map (
         TPD_G         => TPD_G,
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
   comb : process (axisRst, inputAxisMaster, outputAxisSlave, r) is
      variable v : RegType;

   begin
      v := r;

      if (outputAxisSlave.tReady = '1') then
         v.outputAxisMaster(1).tValid := '0';
         v.outputAxisMaster(0).tValid := '0';
      end if;

      case r.state is
         when HEADER_S =>
            v.inputAxisSlave.tready := '1';
            v.outputAxisMaster(1)   := axiStreamMasterInit(AXIS_CONFIG_C);

            if (inputAxisMaster.tValid = '1' and v.outputAxisMaster(1).tValid = '0') then
               v.outputAxisMaster(0) := r.outputAxisMaster(1);
            end if;

            -- Process the header
            if (inputAxisMaster.tValid = '1' and v.outputAxisMaster(1).tValid = '0') then
               v.state := MOVE_S;

               -- Assign sideband fields
               v.outputAxisMaster(1).tDest(7 downto 0) := inputAxisMaster.tData(47 downto 40);
               v.outputAxisMaster(1).tId(7 downto 0)   := inputAxisMaster.tData(55 downto 48);
               v.outputAxisMaster(1).tUser(7 downto 0) := inputAxisMaster.tData(63 downto 56);

               -- Assert SOF if starting a new frame
               axiStreamSetUserBit(AXIS_CONFIG_C, v.outputAxisMaster(1), SSI_SOF_C, r.sof, 0);  -- SOF
               v.sof := '0';

               -- Check frame and packet number
               if (r.sof = '1') then
                  v.frameNumber := inputAxisMaster.tData(15 downto 4);
                  v.packetNumber := (others => '0');
                  if ((r.startup = '0' and inputAxisMaster.tData(15 downto 4) /= r.frameNumber+1) or
                      inputAxisMaster.tData(39 downto 16) /= 0) then
                     v.state := BLEED_S;  -- Error - Missing frames
                  end if;
               else
                  v.packetNumber := inputAxisMaster.tData(39 downto 16);
                  if (inputAxisMaster.tData(15 downto 4) /= r.frameNumber or
                      inputAxisMaster.tData(39 downto 16) /= r.packetNumber+1) then
                     v.outputAxisMaster(1).tvalid := '1';
                     v.outputAxisMaster(1).tlast  := '1';
                     axiStreamSetUserBit(AXIS_CONFIG_C, v.outputAxisMaster(1), SSI_EOFE_C, '1', 0);
                     v.state                      := BLEED_S;
                  end if;
               end if;
               v.startup := '0';

            end if;

         when BLEED_S =>
            -- Blead an entire packet
            -- Set startup and sof true when done
            v.inputAxisSlave.tReady      := outputAxisSlave.tReady;
            v.outputAxisMaster(1).tvalid := '0';
            v.sof                        := '1';
            v.startup                    := '1';
            if (inputAxisMaster.tLast = '1') then
               v.state := HEADER_S;
            end if;

         when MOVE_S =>
            v.inputAxisSlave.tReady := outputAxisSlave.tReady;

            if (inputAxisMaster.tValid = '1' and v.outputAxisMaster(1).tValid = '0') then
               -- Send data through
               v.outputAxisMaster(1) := inputAxisMaster;
               v.outputAxisMaster(0) := r.outputAxisMaster(1);

               -- End of frame
               if (inputAxisMaster.tLast = '1') then
                  -- Check tkeep to find tail byte (and strip it out)
                  v.state                     := HEADER_S;
                  v.outputAxisMaster(1).tKeep := '0' & inputAxisMaster.tKeep(14 downto 0);

                  case (inputAxisMaster.tKeep(7 downto 0)) is
                     when X"01" =>
                        -- Single byte tail, append tUser to previous txn which has been held
--                        v.outputAxisMaster(0)                     := r.outputAxisMaster;
                        v.outputAxisMaster(1).tValid              := '0';
                        v.outputAxisMaster(0).tUser(63 downto 56) := '0' & inputAxisMaster.tData(6 downto 0);
                        v.outputAxisMaster(0).tLast               := inputAxisMaster.tData(7);
                        v.sof                                     := inputAxisMaster.tData(7);
                     when X"03" =>
                        v.outputAxisMaster(1).tUser(7 downto 0) := '0' & inputAxisMaster.tUser(14 downto 8);
                        v.sof                                   := inputAxisMaster.tData(15);
                     when X"07" =>
                        v.outputAxisMaster(1).tUser(15 downto 8) := '0' & inputAxisMaster.tUser(22 downto 16);
                        v.sof                                    := inputAxisMaster.tData(23);
                     when X"0F" =>
                        v.outputAxisMaster(1).tUser(23 downto 16) := '0' & inputAxisMaster.tUser(30 downto 24);
                        v.sof                                     := inputAxisMaster.tData(31);
                     when X"1F" =>
                        v.outputAxisMaster(1).tUser(31 downto 24) := '0' & inputAxisMaster.tUser(38 downto 32);
                        v.sof                                     := inputAxisMaster.tData(39);
                     when X"3F" =>
                        v.outputAxisMaster(1).tUser(39 downto 32) := '0' & inputAxisMaster.tUser(46 downto 40);
                        v.sof                                     := inputAxisMaster.tData(47);
                     when X"7F" =>
                        v.outputAxisMaster(1).tUser(47 downto 40) := '0' & inputAxisMaster.tUser(54 downto 48);
                        v.sof                                     := inputAxisMaster.tData(55);
                     when X"FF" =>
                        v.outputAxisMaster(1).tUser(55 downto 48) := '0' & inputAxisMaster.tUser(62 downto 56);
                        v.sof                                     := inputAxisMaster.tData(63);
                     when others =>
                        null;
                  end case;
                  v.outputAxisMaster(1).tLast := v.sof;
               end if;
            end if;

      end case;

      ----------------------------------------------------------------------------------------------
      -- Reset and output assignment
      ----------------------------------------------------------------------------------------------
      if (axisRst = '1') then
         v := REG_INIT_C;
      end if;

      rin <= v;

      inputAxisSlave <= v.inputAxisSlave;

      -- Hold each out tvalid until next in tvalid arrives
      outputAxisMaster <= r.outputAxisMaster(0);
--       outputAxisMaster.tValid <= r.outputAxisMaster.tValid and
--                                  inputAxisMaster.tValid and
--                                  not inputAxisMaster.tLast;
--       outputAxisMaster.tData <= r.outputAxisMaster.tData;
--       outputAxisMaster.tStrb <= r.outputAxisMaster.tStrb;
--       outputAxisMaster.tKeep <= r.outputAxisMaster.tKeep;
--       outputAxisMaster.tLast <= r.outputAxisMaster.tLast;
--       outputAxisMaster.tDest <= r.outputAxisMaster.tDest;
--       outputAxisMaster.tId   <= r.outputAxisMaster.tId;
--       outputAxisMaster.tUser <= r.outputAxisMaster.tUser;

   end process comb;

   seq : process (axisClk) is
   begin
      if (rising_edge(axisClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end architecture rtl;

