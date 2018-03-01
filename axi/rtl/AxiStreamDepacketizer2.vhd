-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
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
use work.AxiStreamPacketizer2Pkg.all;

entity AxiStreamDepacketizer2 is

   generic (
      TPD_G                : time             := 1 ns;
      BRAM_EN_G            : boolean          := false;
      CRC_MODE_G           : string           := "DATA";  -- or "NONE" or "FULL"
      CRC_POLY_G           : slv(31 downto 0) := x"04C11DB7";
      INPUT_PIPE_STAGES_G  : integer          := 0;
      OUTPUT_PIPE_STAGES_G : integer          := 1);
   port (
      -- AXI-Lite Interface for local registers 
      axisClk : in sl;
      axisRst : in sl;

      sAxisMaster : in  AxiStreamMasterType;
      sAxisSlave  : out AxiStreamSlaveType;

      linkGood : in  sl;
      debug    : out Packetizer2DebugType;

      mAxisMaster : out AxiStreamMasterType;
      mAxisSlave  : in  AxiStreamSlaveType);

end entity AxiStreamDepacketizer2;

architecture rtl of AxiStreamDepacketizer2 is

   constant CRC_EN_C        : boolean := CRC_MODE_G = "DATA" or CRC_MODE_G = "FULL";
   constant CRC_HEAD_TAIL_C : boolean := CRC_MODE_G = "FULL";

   constant AXIS_CONFIG_C : AxiStreamConfigType := (
      TSTRB_EN_C    => false,
      TDATA_BYTES_C => 8,
      TDEST_BITS_C  => 8,
      TID_BITS_C    => 8,
      TKEEP_MODE_C  => TKEEP_COMP_C,
      TUSER_BITS_C  => 8,
      TUSER_MODE_C  => TUSER_FIRST_LAST_C);

   type StateType is (
      IDLE_S,
      HEADER_S,
      MOVE_S,
      TERMINATE_S,
      CRC_S);

   type RegType is record
      state            : StateType;
      activeTDest      : slv(7 downto 0);
      packetSeq        : slv(15 downto 0);
      packetActive     : sl;
      sentEofe         : sl;
      ramWe            : sl;
      sideband         : sl;
      crcDataValid     : sl;
      crcDataWidth     : slv(2 downto 0);
      crcInit          : slv(31 downto 0);
      crcReset         : sl;
      linkGoodDly      : sl;
      debug            : Packetizer2DebugType;
      inputAxisSlave   : AxiStreamSlaveType;
      outputAxisMaster : AxiStreamMasterArray(1 downto 0);
   end record RegType;

   constant REG_INIT_C : RegType := (
      state            => TERMINATE_S,
      activeTDest      => (others => '0'),
      packetSeq        => (others => '0'),
      packetActive     => '0',
      sentEofe         => '0',
      ramWe            => '0',
      sideband         => '0',
      crcDataValid     => '0',
      crcDataWidth     => (others => '1'),
      crcInit          => (others => '1'),
      crcReset         => '1',
      linkGoodDly      => '0',
      debug            => PACKETIZER2_DEBUG_INIT_C,
      inputAxisSlave   => AXI_STREAM_SLAVE_INIT_C,
      outputAxisMaster => (others => axiStreamMasterInit(AXIS_CONFIG_C)));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal ramPacketSeqOut    : slv(15 downto 0);
   signal ramPacketActiveOut : sl;
   signal ramSentEofeOut     : sl;
   signal ramCrcOut          : slv(31 downto 0) := (others => '0');

   signal crcIn  : slv(63 downto 0) := (others => '0');
   signal crcOut : slv(31 downto 0) := (others => '0');


   signal inputAxisMaster  : AxiStreamMasterType;
   signal inputAxisSlave   : AxiStreamSlaveType;
   signal outputAxisMaster : AxiStreamMasterType;
   signal outputAxisSlave  : AxiStreamSlaveType;

   -- attribute dont_touch                     : string;
   -- attribute dont_touch of r                : signal is "TRUE";
   -- attribute dont_touch of crcOut           : signal is "TRUE";
   -- attribute dont_touch of ramPacketSeqOut  : signal is "TRUE";
   -- attribute dont_touch of ramPacketActiveOut  : signal is "TRUE";
   -- attribute dont_touch of ramSentEofeOut      : signal is "TRUE";
   -- attribute dont_touch of inputAxisMaster  : signal is "TRUE";
   -- attribute dont_touch of inputAxisSlave   : signal is "TRUE";
   -- attribute dont_touch of outputAxisMaster : signal is "TRUE";
   -- attribute dont_touch of outputAxisSlave  : signal is "TRUE";   

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
   -- Output kinda stutters awkwardly without this
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
   -- track current frame number, packet count and physical channel for each tDest
   -------------------------------------------------------------------------------------------------
   U_DualPortRam_1 : entity work.DualPortRam
      generic map (
         TPD_G        => TPD_G,
         BRAM_EN_G    => BRAM_EN_G,
         REG_EN_G     => false,
         DOA_REG_G    => false,
         DOB_REG_G    => false,
         BYTE_WR_EN_G => false,
         DATA_WIDTH_G => 18+32,
         ADDR_WIDTH_G => 8)
      port map (
         clka                => axisClk,             -- [in]
         rsta                => axisRst,             -- [in]
         wea                 => rin.ramWe,           -- [in]
         addra               => rin.activeTDest,     -- [in]
         dina(15 downto 0)   => rin.packetSeq,       -- [in]
         dina(16)            => rin.packetActive,    -- [in]
         dina(17)            => rin.sentEofe,        -- [in]
         dina(49 downto 18)  => crcOut,              -- [in]
         douta(15 downto 0)  => ramPacketSeqOut,     -- [out]
         douta(16)           => ramPacketActiveOut,  -- [out]
         douta(17)           => ramSentEofeOut,      -- [out]
         douta(49 downto 18) => ramCrcOut);          -- [out]

   crcIn <= endianSwap(inputAxisMaster.tData(63 downto 0));

   GEN_CRC : if (CRC_EN_G) generate

      ETH_CRC : if (CRC_POLY_G = x"04C11DB7") generate
         U_Crc32 : entity work.Crc32Parallel
            generic map (
               TPD_G            => TPD_G,
               INPUT_REGISTER_G => false,
               BYTE_WIDTH_G     => 8,
               CRC_INIT_G       => X"FFFFFFFF")
            port map (
               crcOut       => crcOut,
               crcClk       => axisClk,
               crcDataValid => rin.crcDataValid,
               crcDataWidth => rin.crcDataWidth,
               crcIn        => crcIn,
               crcInit      => rin.crcInit,
               crcReset     => rin.crcReset);
      end generate;

      GENERNAL_CRC : if (CRC_POLY_G /= x"04C11DB7") generate
         U_Crc32 : entity work.Crc32
            generic map (
               TPD_G            => TPD_G,
               INPUT_REGISTER_G => false,
               BYTE_WIDTH_G     => 8,
               CRC_INIT_G       => X"FFFFFFFF",
               CRC_POLY_G       => CRC_POLY_G)
            port map (
               crcOut       => crcOut,
               crcClk       => axisClk,
               crcDataValid => rin.crcDataValid,
               crcDataWidth => rin.crcDataWidth,
               crcIn        => crcIn,
               crcInit      => rin.crcInit,
               crcReset     => rin.crcReset);
      end generate;

   end generate;

   comb : process (axisRst, crcOut, ramCrcOut, inputAxisMaster, linkGood,
                   outputAxisSlave, ramPacketActiveOut, ramPacketSeqOut, r,
                   ramSentEofeOut) is
      variable v         : RegType;
      variable sof       : sl;
      variable lastBytes : integer;
   begin
      -- Latch the current value
      v := r;

      -- Set default debug value
      v.debug := PACKETIZER2_DEBUG_INIT_C;

      -- Don't write new packet number by default
      v.ramWe := '0';

      -- Default CRC variable values
      v.crcDataValid := '0';
      v.crcReset     := '0';
      v.crcDataWidth := "111";          -- 64-bit transfer  

      -- Check if data accepted
      if (outputAxisSlave.tReady = '1') then
         v.outputAxisMaster(1).tValid := '0';
         v.outputAxisMaster(0).tValid := '0';
      end if;

      case r.state is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Update the RAM address
            v.activeTDest := inputAxisMaster.tData(PACKETIZER2_HDR_TDEST_FIELD_C);

            -- Halt incoming data
            v.inputAxisSlave.tReady := '0';

            -- Advance the output pipeline
            if (r.outputAxisMaster(1).tValid = '1' and v.outputAxisMaster(0).tValid = '0') then
               v.outputAxisMaster(0) := r.outputAxisMaster(1);
            end if;

            -- Check for data
            if (inputAxisMaster.tValid = '1') then
               v.state := HEADER_S;
            end if;
         ----------------------------------------------------------------------
         when HEADER_S =>
            -- The header data won't be pushed to the output this cycle, so accept by default
            v.inputAxisSlave.tready := '1';
            v.outputAxisMaster(1)   := axiStreamMasterInit(AXIS_CONFIG_C);

            -- Reset the CRC for the next packet
            v.crcReset := '1';
            v.crcInit  := ramCrcOut;

            -- Update the RAM address
            v.activeTDest := inputAxisMaster.tData(PACKETIZER2_HDR_TDEST_FIELD_C);

            -- Assign sideband fields
            v.outputAxisMaster(1).tDest(7 downto 0) := inputAxisMaster.tData(PACKETIZER2_HDR_TDEST_FIELD_C);
            v.outputAxisMaster(1).tId(7 downto 0)   := inputAxisMaster.tData(PACKETIZER2_HDR_TID_FIELD_C);
            v.outputAxisMaster(1).tUser(7 downto 0) := inputAxisMaster.tData(PACKETIZER2_HDR_TUSER_FIELD_C);
            sof                                     := inputAxisMaster.tData(PACKETIZER2_HDR_SOF_BIT_C);
            v.packetSeq                             := inputAxisMaster.tData(PACKETIZER2_HDR_SEQ_FIELD_C);

            -- Advance the output pipeline
            if (r.outputAxisMaster(1).tValid = '1' and v.outputAxisMaster(0).tValid = '0') then
               v.outputAxisMaster(0) := r.outputAxisMaster(1);
            end if;

            -- Process an incoming transaction
            if (inputAxisMaster.tValid = '1' and v.outputAxisMaster(1).tValid = '0') then
               -- Calculate CRC on head of enabled to do so
               v.crcDataValid := toSl(CRC_HEAD_TAIL_C);

               -- Check for BRAM configuration
               if BRAM_EN_G then
                  -- Default next state if v.state=MOVE_S not applied later in the combinatorial chain
                  v.state := IDLE_S;
               end if;

               -- Must be an SSI SOF
               -- If txn is not a header, data will be dumped by doing nothing here
               -- This is all we can do, since we don't know which tdest the data belongs to
               if (ssiGetuserSof(AXIS_CONFIG_C, inputAxisMaster) = '1') then

                  -- Assert SSI SOF if SOF header bit set
                  ssiSetUserSof(AXIS_CONFIG_C, v.outputAxisMaster(1), sof);

                  if (sof = '1') then
                     -- Reset the CRC on new frames
                     -- Do this on EOF instead maybe?
                     v.crcInit := (others => '1');
                  end if;


                  if (sof = not ramPacketActiveOut) and
                     (v.packetSeq = ramPacketSeqOut) and
                     (inputAxisMaster.tData(PACKETIZER2_HDR_VERSION_FIELD_C) = PACKETIZER2_VERSION_C) and
                     (inputAxisMaster.tData(PACKETIZER2_HDR_CRC_TYPE_FIELD_C) = toSl(CRC_HEAD_TAIL_C)) then
                     -- Header metadata as expected
                     v.state    := MOVE_S;
                     v.sideband := '1';

                     -- Set packetActive in ram for this tdest
                     -- v.packetSeq is already correct
                     v.packetActive := '1';
                     v.sentEofe     := '0';                   -- Clear any frame error
                     v.ramWe        := '1';
                     v.debug.sop    := '1';
                     v.debug.sof    := sof;
                  else
                     -- There was a missing packet!
                     if (ramSentEofeOut = '0') then
                        -- Haven't yet sent an EOFE for this frame. Do so now.
                        ssiSetUserEofe(AXIS_CONFIG_C, v.outputAxisMaster(1), '1');
                        v.outputAxisMaster(1).tLast  := '1';
                        v.outputAxisMaster(1).tValid := '1';
                        v.debug.eof                  := '1';
                        v.debug.eofe                 := '1';
                     end if;
                     v.packetSeq         := (others => '0');
                     v.packetActive      := '0';
                     v.sentEofe          := '1';
                     v.ramWe             := '1';
                     v.debug.packetError := '1';
                     v.crcInit           := (others => '1');  -- Is might be unnecessary
                  end if;

               end if;
            end if;
         ----------------------------------------------------------------------
         when MOVE_S =>
            v.inputAxisSlave.tReady      := outputAxisSlave.tReady;
            v.outputAxisMaster(1).tvalid := r.outputAxisMaster(1).tvalid;

            if (inputAxisMaster.tValid = '1' and v.outputAxisMaster(0).tValid = '0') then
               -- Advance the pipeline
               v.outputAxisMaster(1)       := inputAxisMaster;
               -- Keep sideband data from header
               v.outputAxisMaster(1).tDest := r.outputAxisMaster(1).tDest;
               v.outputAxisMaster(1).tId   := r.outputAxisMaster(1).tId;
               if (r.sideband = '1') then
                  -- But tUser only for first output txn
                  v.outputAxisMaster(1).tUser := r.outputAxisMaster(1).tUser;
                  v.sideband                  := '0';
               end if;
               v.crcDataValid := toSl(CRC_HEAD_TAIL_C);

               v.outputAxisMaster(0) := r.outputAxisMaster(1);

               -- End of packet
               if (inputAxisMaster.tLast = '1') then
                  v.state                      := CRC_S;
                  v.outputAxisMaster(0).tValid := '0';
                  v.outputAxisMaster(1).tValid := '0';
                  v.crcDataWidth               := "011";  -- 32-bit transfer
                  -- Append EOF metadata to previous txn which has been held
                  lastBytes                    := conv_integer(inputAxisMaster.tData(PACKETIZER2_TAIL_BYTES_FIELD_C));
                  v.outputAxisMaster(0).tLast  := inputAxisMaster.tData(PACKETIZER2_TAIL_EOF_BIT_C);
                  v.outputAxisMaster(0).tKeep  := genTkeep(conv_integer(inputAxisMaster.tData(PACKETIZER2_TAIL_BYTES_FIELD_C)));
                  axiStreamSetUserField(AXIS_CONFIG_C, v.outputAxisMaster(0), inputAxisMaster.tData(PACKETIZER2_TAIL_TUSER_FIELD_C), -1);  -- -1 = last
                  -- Update flag
                  v.debug.packetError          := ssiGetUserEofe(AXIS_CONFIG_C, inputAxisMaster);
               end if;
            end if;
         ----------------------------------------------------------------------
         when CRC_S =>
            -- Do not accept new frame during this cycle
            v.inputAxisSlave.tReady      := '0';
            -- Move the data (Note: v.outputAxisMaster(0).tValid = '0' in previous state)
            v.outputAxisMaster(0).tValid := '1';
            -- Check for packetError or CRC error
            if (r.debug.packetError = '1') or (crcOut /= r.outputAxisMaster(1).tData(PACKETIZER2_TAIL_CRC_FIELD_C) and CRC_EN_C) then
               -- EOP with error, do EOFE
               ssiSetUserEofe(AXIS_CONFIG_C, v.outputAxisMaster(0), '1');
               v.outputAxisMaster(0).tLast := '1';
               v.packetActive              := '0';
               v.packetSeq                 := (others => '0');
               v.sentEofe                  := '1';
               v.crcInit                   := (others => '1');
               v.crcReset                  := '1';        -- Reset CRC in ram to 0xFFFFFFFF
               v.ramWe                     := '1';
               v.debug.eof                 := '1';
               v.debug.eofe                := '1';
               v.debug.eop                 := '1';
            elsif (r.outputAxisMaster(1).tData(PACKETIZER2_TAIL_EOF_BIT_C) = '1') then
               -- If EOF, reset packetActive and packetSeq                     
               v.packetActive := '0';
               v.packetSeq    := (others => '0');
               v.sentEofe     := '0';
               v.crcInit      := (others => '1');
               v.crcReset     := '1';   -- Reset CRC in ram to 0xFFFFFFFF
               v.ramWe        := '1';
               v.debug.eof    := '1';
               v.debug.eop    := '1';
            else
               -- else increment packetSeq and set packetActive
               v.packetActive := '1';
               v.packetSeq    := r.packetSeq + 1;
               v.sentEofe     := '0';
               v.ramWe        := '1';
               v.debug.eop    := '1';
            end if;
            -- Next state
            v.state := ite(BRAM_EN_G, IDLE_S, HEADER_S);
            
         ----------------------------------------------------------------------
         when TERMINATE_S =>
            -- Halt incoming data
            v.inputAxisSlave.tReady := '0';

            -- Advance the output pipeline
            if (r.outputAxisMaster(1).tValid = '1' and v.outputAxisMaster(0).tValid = '0') then
               v.outputAxisMaster(0) := r.outputAxisMaster(1);
            end if;

            -- Reset the values in the RAM
            v.packetActive := '0';
            v.sentEofe     := '0';      -- Clear any frame error
            v.packetSeq    := (others => '0');
            v.crcInit      := (others => '1');
            v.crcReset     := '1';      -- Reset CRC in ram to 0xFFFFFFFF
            -- Check for max index
            if (r.activeTDest = x"FF") then
               -- Wait for link to come back up
               if (linkGood = '1') then
                  v.state := ite(BRAM_EN_G, IDLE_S, HEADER_S);
               end if;
            else
               -- Check if ready to move data
               if (v.outputAxisMaster(1).tValid = '0') then
                  -- Write to the RAM
                  v.activeTDest                           := r.activeTDest + 1;
                  -- Increment the index
                  v.ramWe                                 := '1';
                  -- Terminate any open frames with EOFE
                  ssiSetUserEofe(AXIS_CONFIG_C, v.outputAxisMaster(1), '1');
                  v.outputAxisMaster(1).tLast             := '1';
                  v.outputAxisMaster(1).tValid            := ramPacketActiveOut;
                  v.outputAxisMaster(1).tDest(7 downto 0) := v.activeTDest;
                  v.debug.eof                             := ramPacketActiveOut;
                  v.debug.eofe                            := ramPacketActiveOut;
               end if;
            end if;
      ----------------------------------------------------------------------
      end case;

      -- Keep a delayed copy
      v.linkGoodDly := linkGood;

      -- Check for link drop event
      if (r.linkGoodDly = '1') and (linkGood = '0') then
         -- Reset the index
         v.activeTDest := x"00";
         -- Next state
         v.state       := TERMINATE_S;
      end if;

      -- Combinatorial outputs before the reset
      inputAxisSlave <= v.inputAxisSlave;

      -- Reset
      if (axisRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Registered Outputs
      outputAxisMaster <= r.outputAxisMaster(0);
      debug            <= r.debug;

   end process comb;

   seq : process (axisClk) is
   begin
      if (rising_edge(axisClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end architecture rtl;
