-------------------------------------------------------------------------------
-- File       : AxiStreamPacketizer
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-09-29
-- Last update: 2016-04-30
-------------------------------------------------------------------------------
-- Description: Formats an AXI-Stream for a transport link.
-- Sideband fields are placed into the data stream in a header.
-- Long frames are broken into smaller packets.  (non-interleave only)
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
use work.ArbiterPkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;

entity AxiStreamPacketizerMux is

   generic (
      TPD_G                : time                  := 1 ns;
      MAX_PACKET_BYTES_G   : integer               := 1440;  -- Must be a multiple of 8
      MIN_TKEEP_G          : slv(15 downto 0)      := X"0001";
      INPUT_PIPE_STAGES_G  : integer               := 0;
      OUTPUT_PIPE_STAGES_G : integer               := 0;
      NUM_SLAVES_G         : integer range 1 to 32 := 4;
      TDEST_HIGH_G         : integer range 0 to 7  := 7;
      TDEST_LOW_G          : integer range 0 to 7  := 0;
      KEEP_TDEST_G         : boolean               := true);


   port (
      -- AXI-Lite Interface for local registers 
      axisClk : in sl;
      axisRst : in sl;

      sAxisMasters : in  AxiStreamMasterArray(NUM_SLAVES_G-1 downto 0);
      sAxisSlaves  : out AxiStreamSlaveArray(NUM_SLAVES_G-1 downto 0);
      disableSel   : in  slv(NUM_SLAVES_G-1 downto 0) := (others => '0');

      mAxisMaster : out AxiStreamMasterType;
      mAxisSlave  : in  AxiStreamSlaveType);

end entity AxiStreamPacketizerMux;

architecture rtl of AxiStreamPacketizerMux is

   -- Packetizer constants
   constant MAX_WORD_COUNT_C : integer             := (MAX_PACKET_BYTES_G / 8) - 3;
   constant AXIS_CONFIG_C    : AxiStreamConfigType := ssiAxiStreamConfig(8, TKEEP_NORMAL_C);
   constant VERSION_C        : slv(3 downto 0)     := "0000";

   -- Mux arbiter constants
   constant DEST_SIZE_C : integer := bitSize(NUM_SLAVES_G-1);
   constant ARB_BITS_C  : integer := 2**DEST_SIZE_C;

   type StateType is (ARBITRATE_S, HEADER_S, MOVE_S, TAIL_S);

   type RegType is record
      state            : StateType;
      frameNumber      : slv(11 downto 0);
      packetNumber     : slv(23 downto 0);
      packetNumberWe   : sl;
      wordCount        : slv(bitSize(MAX_WORD_COUNT_C)-1 downto 0);
      eof              : sl;
      tUserLast        : slv(7 downto 0);
      acks             : slv(ARB_BITS_C-1 downto 0);
      ackNum           : slv(DEST_SIZE_C-1 downto 0);
      valid            : sl;
      selDest          : slv(7 downto 0);
      inputAxisSlaves  : AxiStreamSlaveArray(NUM_SLAVES_G-1 downto 0);
      outputAxisMaster : AxiStreamMasterType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      state            => ARBITRATE_S,
      frameNumber      => (others => '0'),
      packetNumber     => (others => '0'),
      packetNumberWe   => '0',
      wordCount        => (others => '0'),
      eof              => '0',
      tUserLast        => (others => '0'),
      acks             => (others => '0'),
      ackNum           => (others => '1'),
      valid            => '0',
      selDest          => (others => '0'),
      inputAxisSlaves  => (others => AXI_STREAM_SLAVE_INIT_C),
      outputAxisMaster => axiStreamMasterInit(AXIS_CONFIG_C));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal packetNumberOut : slv(23 downto 0);

   signal inputAxisMasters : AxiStreamMasterArray(NUM_SLAVES_G-1 downto 0);
   signal inputAxisSlaves  : AxiStreamSlaveArray(NUM_SLAVES_G-1 downto 0);
   signal outputAxisMaster : AxiStreamMasterType;
   signal outputAxisSlave  : AxiStreamSlaveType;

begin

   assert ((MAX_PACKET_BYTES_G rem 8) = 0)
      report "MAX_PACKET_BYTES_G must be a multiple of 8" severity error;

   -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
   -- Input pipeline
   -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
   INPUT_PIPELINES : for i in NUM_SLAVES_G-1 downto 0 generate
      U_AxiStreamPipeline_Input : entity work.AxiStreamPipeline
         generic map (
            TPD_G         => TPD_G,
            PIPE_STAGES_G => INPUT_PIPE_STAGES_G)
         port map (
            axisClk     => axisClk,              -- [in]
            axisRst     => axisRst,              -- [in]
            sAxisMaster => sAxisMasters(i),      -- [in]
            sAxisSlave  => sAxisSlaves(i),       -- [out]
            mAxisMaster => inputAxisMasters(i),  -- [out]
            mAxisSlave  => inputAxisSlaves(i));  -- [in]
   end generate;

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
   -- Packet Count ram
   -- track current packet count for each tDest
   -------------------------------------------------------------------------------------------------
   U_QuadPortRam_1 : entity work.QuadPortRam
      generic map (
         TPD_G        => TPD_G,
         REG_EN_G     => false,
         BYTE_WR_EN_G => false,
         DATA_WIDTH_G => 24,
         ADDR_WIDTH_G => 8)
      port map (
         clka  => axisClk,              -- [in]
         wea   => r.packetNumberWe,     -- [in]
         rsta  => axisRst,              -- [in]
         addra => r.selDest,            -- [in]
         dina  => r.packetNumber,       -- [in]
         douta => packetNumberOut);     -- [out]

   -------------------------------------------------------------------------------------------------
   -- Accumulation sequencing, DMA ring buffer, and AXI-Lite logic
   -------------------------------------------------------------------------------------------------
   comb : process (axisRst, disableSel, outputAxisSlave, packetNumberOut, r, sAxisMasters) is
      variable v        : RegType;
      variable requests : slv(ARB_BITS_C-1 downto 0);
      variable selData  : AxiStreamMasterType;
   begin
      v := r;

      if (outputAxisSlave.tReady = '1') then
         v.outputAxisMaster.tValid := '0';
      end if;

      -- input tReadys 0 by default
      for i in 0 to NUM_SLAVES_G-1 loop
         v.inputAxisSlaves(i).tReady := '0';
      end loop;

      -- Select source
      selData := sAxisMasters(conv_integer(r.ackNum));

      -- Assign tdest
      if (KEEP_TDEST_G = false) then
         selData.tDest(7 downto TDEST_LOW_G)                         := (others => '0');
         selData.tDest(DEST_SIZE_C+TDEST_LOW_G-1 downto TDEST_LOW_G) := r.ackNum;
      end if;

      -- Format requests
      requests := (others => '0');
      for i in 0 to (NUM_SLAVES_G-1) loop
         requests(i) := sAxisMasters(i).tValid and not disableSel(i);
      end loop;

      -- Don't write new packet number by default
      v.packetNumberWe := '0';

      case r.state is
         when ARBITRATE_S =>
            -- Arbitrate between requesters
            if r.valid = '0' then
               arbitrate(requests, r.ackNum, v.ackNum, v.valid, v.acks);
            else
               -- Reset the Arbitration flag
               -- Register the selected tDest
               -- Go to header state
               v.valid   := '0';
               v.selDest := selData.tDest;
               v.state   := HEADER_S;
            end if;

         when HEADER_S =>
            v.wordCount := (others => '0');

            -- Place header on output when new data arrived and previous output clear                           
            if (selData.tValid = '1' and v.outputAxisMaster.tValid = '0') then
               v.outputAxisMaster                     := axiStreamMasterInit(AXIS_CONFIG_C);
               v.outputAxisMaster.tValid              := selData.tValid;
               v.outputAxisMaster.tData(3 downto 0)   := VERSION_C;
               v.outputAxisMaster.tData(15 downto 4)  := r.frameNumber;
               v.outputAxisMaster.tData(39 downto 16) := packetNumberOut;
               v.outputAxisMaster.tData(47 downto 40) := selData.tDest(7 downto 0);
               v.outputAxisMaster.tData(55 downto 48) := selData.tId(7 downto 0);
               v.outputAxisMaster.tData(63 downto 56) := selData.tUser(7 downto 0);
               axiStreamSetUserBit(AXIS_CONFIG_C, v.outputAxisMaster, SSI_SOF_C, '1', 0);  -- SOF
               v.state                                := MOVE_S;
               v.packetNumber                         := packetNumberOut + 1;
            end if;

         when MOVE_S =>

            -- Check if clear to move data
            if (v.outputAxisMaster.tValid = '0') then

               -- Accept the data
               v.inputAxisSlaves(conv_integer(r.ackNum)).tReady := '1';

               -- Send data through
               v.outputAxisMaster       := selData;
               v.outputAxisMaster.tUser := (others => '0');
               v.outputAxisMaster.tDest := (others => '0');
               v.outputAxisMaster.tId   := (others => '0');

               -- Increment word count with each txn
               v.wordCount := r.wordCount + 1;

               -- Reach max packet size. Append tail.
               if (r.wordCount = MAX_WORD_COUNT_C) then
                  v.state := TAIL_S;
               end if;

               -- End of frame
               if (selData.tLast = '1') then
                  -- Increment frame number, clear packetNumber
                  v.frameNumber  := r.frameNumber + 1;
                  v.packetNumber := (others => '0');
                  v.state        := ARBITRATE_S;

                  -- Need to either append tail to current txn or put tail on next txn (TAIL_S)
                  -- depending on tKeep
                  v.outputAxisMaster.tKeep := MIN_TKEEP_G or (selData.tKeep(14 downto 0) & '1');

                  case (selData.tKeep) is
                     when X"0000" =>
                        v.outputAxisMaster.tData(7 downto 0) := '1' & selData.tUser(6 downto 0);
                     when X"0001" =>
                        v.outputAxisMaster.tData(15 downto 8) := '1' & selData.tUser(14 downto 8);
                     when X"0003" =>
                        v.outputAxisMaster.tData(23 downto 16) := '1' & selData.tUser(22 downto 16);
                     when X"0007" =>
                        v.outputAxisMaster.tData(31 downto 24) := '1' & selData.tUser(30 downto 24);
                     when X"000F" =>
                        v.outputAxisMaster.tData(39 downto 32) := '1' & selData.tUser(38 downto 32);
                     when X"001F" =>
                        v.outputAxisMaster.tData(47 downto 40) := '1' & selData.tUser(46 downto 40);
                     when X"003F" =>
                        v.outputAxisMaster.tData(55 downto 48) := '1' & selData.tUser(54 downto 48);
                     when X"007F" =>
                        v.outputAxisMaster.tData(63 downto 56) := '1' & selData.tUser(62 downto 56);
                     when others =>     --X"0FFF" or anything else
                        -- Full tkeep. Add new word for tail
                        v.outputAxisMaster.tKeep := selData.tKeep;
                        v.state                  := TAIL_S;
                        v.tUserLast              := selData.tUser(7 downto 0);
                        v.eof                    := '1';
                        v.outputAxisMaster.tLast := '0';
                  end case;

               end if;
            end if;

         when TAIL_S =>
            -- Hold off slave side while inserting tail
            v.inputAxisSlaves(conv_integer(r.ackNum)).tReady := '0';

            -- Insert tail when master side is ready for it
            if (v.outputAxisMaster.tValid = '0') then
               v.outputAxisMaster.tValid            := '1';
               v.outputAxisMaster.tKeep             := MIN_TKEEP_G;  --X"0001";
               v.outputAxisMaster.tData             := (others => '0');
               v.outputAxisMaster.tData(7)          := r.eof;
               v.outputAxisMaster.tData(6 downto 0) := r.tUserLast(6 downto 0);
               v.outputAxisMaster.tUser             := (others => '0');
               v.outputAxisMaster.tLast             := '1';
               v.eof                                := '0';          -- Clear EOF for next frame
               v.tUserLast                          := (others => '0');
               v.packetNumberWe                     := '1';
               v.state                              := ARBITRATE_S;  -- Go to idle and wait for new data
            end if;

      end case;

      ----------------------------------------------------------------------------------------------
      -- Reset and output assignment
      ----------------------------------------------------------------------------------------------
      if (axisRst = '1') then
         v := REG_INIT_C;
      end if;

      rin <= v;

      inputAxisSlaves   <= v.inputAxisSlaves;
      outputAxisMaster <= r.outputAxisMaster;

   end process comb;

   seq : process (axisClk) is
   begin
      if (rising_edge(axisClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end architecture rtl;

