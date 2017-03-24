-------------------------------------------------------------------------------
-- File       : AxiStreamPacketizer
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-09-29
-- Last update: 2016-08-30
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

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;

entity AxiStreamPacketizer is

   generic (
      TPD_G                : time             := 1 ns;
      MAX_PACKET_BYTES_G   : integer          := 1440;  -- Must be a multiple of 8
      MIN_TKEEP_G          : slv(15 downto 0) := X"0001";
      OUTPUT_SSI_G         : boolean          := true;  -- SSI compliant output (SOF on tuser)
      INPUT_PIPE_STAGES_G  : integer          := 0;
      OUTPUT_PIPE_STAGES_G : integer          := 0);

   port (
      -- AXI-Lite Interface for local registers 
      axisClk : in sl;
      axisRst : in sl;

      sAxisMaster : in  AxiStreamMasterType;
      sAxisSlave  : out AxiStreamSlaveType;

      mAxisMaster : out AxiStreamMasterType;
      mAxisSlave  : in  AxiStreamSlaveType);

end entity AxiStreamPacketizer;

architecture rtl of AxiStreamPacketizer is

   constant MAX_WORD_COUNT_C : integer := (MAX_PACKET_BYTES_G / 8) - 3;

   constant AXIS_CONFIG_C : AxiStreamConfigType := (
      TSTRB_EN_C    => false,
      TDATA_BYTES_C => 8,
      TDEST_BITS_C  => 0,
      TID_BITS_C    => 0,
      TKEEP_MODE_C  => TKEEP_NORMAL_C,
      TUSER_BITS_C  => ite(OUTPUT_SSI_G, 2, 0),
      TUSER_MODE_C  => TUSER_FIRST_LAST_C);


   constant VERSION_C : slv(3 downto 0) := "0000";

   type StateType is (IDLE_S, MOVE_S, TAIL_S);

   type RegType is record
      state            : StateType;
      frameNumber      : slv(11 downto 0);
      packetNumber     : slv(23 downto 0);
      wordCount        : slv(bitSize(MAX_WORD_COUNT_C)-1 downto 0);
      eof              : sl;
      tUserLast        : slv(7 downto 0);
      inputAxisSlave   : AxiStreamSlaveType;
      outputAxisMaster : AxiStreamMasterType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      state            => IDLE_S,
      frameNumber      => (others => '0'),
      packetNumber     => (others => '0'),
      wordCount        => (others => '0'),
      eof              => '0',
      tUserLast        => (others => '0'),
      inputAxisSlave   => AXI_STREAM_SLAVE_INIT_C,
      outputAxisMaster => axiStreamMasterInit(AXIS_CONFIG_C));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal inputAxisMaster  : AxiStreamMasterType;
   signal inputAxisSlave   : AxiStreamSlaveType;
   signal outputAxisMaster : AxiStreamMasterType;
   signal outputAxisSlave  : AxiStreamSlaveType;

begin

   assert ((MAX_PACKET_BYTES_G rem 8) = 0)
      report "MAX_PACKET_BYTES_G must be a multiple of 8" severity error;

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
         v.outputAxisMaster.tValid := '0';
      end if;

      case r.state is
         when IDLE_S =>
            v.wordCount := (others => '0');

            -- Will need to insert header, so hold off tReady
            v.inputAxisSlave.tReady := '0';

            -- Place header on output when new data arrived and previous output clear                           
            if (inputAxisMaster.tValid = '1' and v.outputAxisMaster.tValid = '0') then
               v.outputAxisMaster                     := axiStreamMasterInit(AXIS_CONFIG_C);
               v.outputAxisMaster.tValid              := inputAxisMaster.tValid;
               v.outputAxisMaster.tData(3 downto 0)   := VERSION_C;
               v.outputAxisMaster.tData(15 downto 4)  := r.frameNumber;
               v.outputAxisMaster.tData(39 downto 16) := r.packetNumber;
               v.outputAxisMaster.tData(47 downto 40) := inputAxisMaster.tDest(7 downto 0);
               v.outputAxisMaster.tData(55 downto 48) := inputAxisMaster.tId(7 downto 0);
               v.outputAxisMaster.tData(63 downto 56) := inputAxisMaster.tUser(7 downto 0);
               if (OUTPUT_SSI_G) then
                  axiStreamSetUserBit(AXIS_CONFIG_C, v.outputAxisMaster, SSI_SOF_C, '1', 0);  -- SOF
               end if;
               v.state        := MOVE_S;
               v.packetNumber := r.packetNumber + 1;
            end if;

         when MOVE_S =>
            v.inputAxisSlave.tReady := '0';  --outputAxisSlave.tReady;

            if (inputAxisMaster.tValid = '1' and v.outputAxisMaster.tValid = '0') then
               -- Send data through
               v.inputAxisSlave.tReady   := '1';
               v.outputAxisMaster        := inputAxisMaster;
               v.outputAxisMaster.tUser  := (others => '0');
               v.outputAxisMaster.tDest  := (others => '0');
               v.outputAxisMaster.tId    := (others => '0');

               -- Increment word count with each txn
               v.wordCount := r.wordCount + 1;

               -- Reach max packet size. Append tail.
               if (r.wordCount = MAX_WORD_COUNT_C) then
                  v.state := TAIL_S;
               end if;

               -- End of frame
               if (inputAxisMaster.tLast = '1') then
                  -- Increment frame number, clear packetNumber
                  v.frameNumber  := r.frameNumber + 1;
                  v.packetNumber := (others => '0');
                  v.state        := IDLE_S;

                  -- Need to either append tail to current txn or put tail on next txn (TAIL_S)
                  -- depending on tKeep
                  v.outputAxisMaster.tKeep := MIN_TKEEP_G or (inputAxisMaster.tKeep(14 downto 0) & '1');

                  case (inputAxisMaster.tKeep) is
                     when X"0000" =>
                        v.outputAxisMaster.tData(7 downto 0) := '1' & inputAxisMaster.tUser(6 downto 0);
                     when X"0001" =>
                        v.outputAxisMaster.tData(15 downto 8) := '1' & inputAxisMaster.tUser(14 downto 8);
                     when X"0003" =>
                        v.outputAxisMaster.tData(23 downto 16) := '1' & inputAxisMaster.tUser(22 downto 16);
                     when X"0007" =>
                        v.outputAxisMaster.tData(31 downto 24) := '1' & inputAxisMaster.tUser(30 downto 24);
                     when X"000F" =>
                        v.outputAxisMaster.tData(39 downto 32) := '1' & inputAxisMaster.tUser(38 downto 32);
                     when X"001F" =>
                        v.outputAxisMaster.tData(47 downto 40) := '1' & inputAxisMaster.tUser(46 downto 40);
                     when X"003F" =>
                        v.outputAxisMaster.tData(55 downto 48) := '1' & inputAxisMaster.tUser(54 downto 48);
                     when X"007F" =>
                        v.outputAxisMaster.tData(63 downto 56) := '1' & inputAxisMaster.tUser(62 downto 56);
                     when others =>     --X"0FFF" or anything else
                        -- Full tkeep. Add new word for tail
                        v.outputAxisMaster.tKeep := inputAxisMaster.tKeep;
                        v.state                  := TAIL_S;
                        v.tUserLast              := inputAxisMaster.tUser(7 downto 0);
                        v.eof                    := '1';
                        v.outputAxisMaster.tLast := '0';
                  end case;

               end if;
            end if;

         when TAIL_S =>
            -- Hold off slave side while inserting tail
            v.inputAxisSlave.tReady := '0';

            -- Insert tail when master side is ready for it
            if (v.outputAxisMaster.tValid = '0') then
               v.outputAxisMaster.tValid            := '1';
               v.outputAxisMaster.tKeep             := MIN_TKEEP_G;  --X"0001";
               v.outputAxisMaster.tData             := (others => '0');
               v.outputAxisMaster.tData(7)          := r.eof;
               v.outputAxisMaster.tData(6 downto 0) := r.tUserLast(6 downto 0);
               v.outputAxisMaster.tUser             := (others => '0');
               v.outputAxisMaster.tLast             := '1';
               v.eof                                := '0';     -- Clear EOF for next frame
               v.tUserLast                          := (others => '0');
               v.state                              := IDLE_S;  -- Go to idle and wait for new data
            end if;

      end case;

      v.outputAxisMaster.tStrb := v.outputAxisMaster.tKeep;

      ----------------------------------------------------------------------------------------------
      -- Reset and output assignment
      ----------------------------------------------------------------------------------------------
      if (axisRst = '1') then
         v := REG_INIT_C;
      end if;

      rin <= v;

      inputAxisSlave   <= v.inputAxisSlave;
      outputAxisMaster <= r.outputAxisMaster;

   end process comb;

   seq : process (axisClk) is
   begin
      if (rising_edge(axisClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end architecture rtl;

