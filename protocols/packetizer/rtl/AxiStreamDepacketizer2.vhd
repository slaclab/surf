-------------------------------------------------------------------------------
-- Title      : AxiStreamPackerizerV2 Protocol: https://confluence.slac.stanford.edu/x/3nh4DQ
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Formats an AXI-Stream for a transport link.
-- Sideband fields are placed into the data stream in a header.
-- Smaller packets are combined together to make a long frame
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
use surf.AxiStreamPacketizer2Pkg.all;

entity AxiStreamDepacketizer2 is
   generic (
      TPD_G                : time                  := 1 ns;
      RST_ASYNC_G          : boolean               := false;
      MEMORY_TYPE_G        : string                := "distributed";
      REG_EN_G             : boolean               := false;
      CRC_MODE_G           : string                := "DATA";  -- or "NONE" or "FULL"
      CRC_POLY_G           : slv(31 downto 0)      := x"04C11DB7";
      SEQ_CNT_SIZE_G       : natural range 0 to 16 := 16;
      TDEST_BITS_G         : natural               := 8;
      INPUT_PIPE_STAGES_G  : natural               := 0;
      OUTPUT_PIPE_STAGES_G : natural               := 1);
   port (
      -- Clock and Reset
      axisClk     : in  sl;
      axisRst     : in  sl;
      -- Link Status monitoring and debug interfaces
      linkGood    : in  sl;
      debug       : out Packetizer2DebugType;
      -- AXIS Interfaces
      sAxisMaster : in  AxiStreamMasterType;
      sAxisSlave  : out AxiStreamSlaveType;
      mAxisMaster : out AxiStreamMasterType;
      mAxisSlave  : in  AxiStreamSlaveType);
end entity AxiStreamDepacketizer2;

architecture rtl of AxiStreamDepacketizer2 is

   constant CRC_EN_C         : boolean  := (CRC_MODE_G /= "NONE");
   constant CRC_HEAD_TAIL_C  : boolean  := (CRC_MODE_G = "FULL");
   constant ADDR_WIDTH_C     : positive := ite((TDEST_BITS_G = 0), 1, TDEST_BITS_G);
   constant SEQ_CNT_SIZE_C   : positive := ite((SEQ_CNT_SIZE_G = 0), 1, SEQ_CNT_SIZE_G);
   constant RAM_DATA_WIDTH_C : positive := 32+2+SEQ_CNT_SIZE_C;

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
      WAIT_S,
      HEADER_S,
      MOVE_S,
      TERMINATE_S,
      CRC_S);

   type RegType is record
      state            : StateType;
      activeTDest      : slv(ADDR_WIDTH_C-1 downto 0);
      packetSeq        : slv(SEQ_CNT_SIZE_C-1 downto 0);
      packetActive     : sl;
      sentEofe         : sl;
      ramWe            : sl;
      sideband         : sl;
      crcDataValid     : sl;
      crcDataWidth     : slv(2 downto 0);
      crcInit          : slv(31 downto 0);
      crcReset         : sl;
      linkGoodDly      : sl;
      rdLat            : natural range 0 to 2;
      debug            : Packetizer2DebugType;
      inputAxisSlave   : AxiStreamSlaveType;
      outputAxisMaster : AxiStreamMasterArray(1 downto 0);
   end record RegType;

   constant REG_INIT_C : RegType := (
      state            => TERMINATE_S,
      activeTDest      => (others => '1'),
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
      rdLat            => 2,
      debug            => PACKETIZER2_DEBUG_INIT_C,
      inputAxisSlave   => AXI_STREAM_SLAVE_INIT_C,
      outputAxisMaster => (others => axiStreamMasterInit(AXIS_CONFIG_C)));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal inputAxisMaster  : AxiStreamMasterType;
   signal inputAxisSlave   : AxiStreamSlaveType;
   signal outputAxisMaster : AxiStreamMasterType;
   signal outputAxisSlave  : AxiStreamSlaveType;

   signal ramDin             : slv(RAM_DATA_WIDTH_C-1 downto 0);
   signal ramDout            : slv(RAM_DATA_WIDTH_C-1 downto 0);
   signal ramPacketSeqOut    : slv(SEQ_CNT_SIZE_C-1 downto 0);
   signal ramPacketActiveOut : sl;
   signal ramSentEofeOut     : sl;
   signal ramCrcRem          : slv(31 downto 0) := (others => '1');
   signal ramAddrr           : slv(ADDR_WIDTH_C-1 downto 0);

   signal crcIn  : slv(63 downto 0) := (others => '1');
   signal crcOut : slv(31 downto 0) := (others => '1');
   signal crcRem : slv(31 downto 0) := (others => '1');

   -- attribute dont_touch                        : string;
   -- attribute dont_touch of r                   : signal is "TRUE";
   -- attribute dont_touch of crcOut              : signal is "TRUE";
   -- attribute dont_touch of ramPacketSeqOut     : signal is "TRUE";
   -- attribute dont_touch of ramPacketActiveOut  : signal is "TRUE";
   -- attribute dont_touch of ramSentEofeOut      : signal is "TRUE";
   -- attribute dont_touch of inputAxisMaster     : signal is "TRUE";
   -- attribute dont_touch of inputAxisSlave      : signal is "TRUE";
   -- attribute dont_touch of outputAxisMaster    : signal is "TRUE";
   -- attribute dont_touch of outputAxisSlave     : signal is "TRUE";

begin

   assert ((CRC_MODE_G = "NONE") or (CRC_MODE_G = "DATA") or (CRC_MODE_G = "FULL"))
      report "CRC_MODE_G must be NONE or DATA or FULL" severity error;

   assert (TDEST_BITS_G <= 8)
      report "TDEST_BITS_G must be less than or equal to 8" severity error;

   -----------------
   -- Input pipeline
   -----------------
   U_Input : entity surf.AxiStreamPipeline
      generic map (
         TPD_G         => TPD_G,
         RST_ASYNC_G   => RST_ASYNC_G,
         PIPE_STAGES_G => INPUT_PIPE_STAGES_G)
      port map (
         axisClk     => axisClk,
         axisRst     => axisRst,
         sAxisMaster => sAxisMaster,
         sAxisSlave  => sAxisSlave,
         mAxisMaster => inputAxisMaster,
         mAxisSlave  => inputAxisSlave);

   -------------------------------------------------------------------------------
   -- Packet Count ram
   -- track current frame number, packet count and physical channel for each tDest
   -------------------------------------------------------------------------------
   ramDin(31 downto 0)                   <= crcRem;
   ramDin(32)                            <= rin.packetActive;
   ramDin(33)                            <= rin.sentEofe;
   ramDin(34+SEQ_CNT_SIZE_C-1 downto 34) <= rin.packetSeq;

   ramCrcRem          <= ramDout(31 downto 0);
   ramPacketActiveOut <= ramDout(32);
   ramSentEofeOut     <= ramDout(33);
   ramPacketSeqOut    <= ramDout(34+SEQ_CNT_SIZE_C-1 downto 34);
   GEN_SEQ : if (SEQ_CNT_SIZE_G > 0) generate
      U_DualPortRam_1 : entity surf.DualPortRam
         generic map (
            TPD_G         => TPD_G,
            RST_ASYNC_G   => RST_ASYNC_G,
            MEMORY_TYPE_G => MEMORY_TYPE_G,
            REG_EN_G      => REG_EN_G,
            DOA_REG_G     => REG_EN_G,
            DOB_REG_G     => REG_EN_G,
            BYTE_WR_EN_G  => false,
            DATA_WIDTH_G  => RAM_DATA_WIDTH_C,
            ADDR_WIDTH_G  => ADDR_WIDTH_C)
         port map (
            clka  => axisClk,
            rsta  => axisRst,
            wea   => rin.ramWe,
            addra => ramAddrr,
            dina  => ramDin,
            douta => ramDout);
   end generate GEN_SEQ;

   NO_SEQ : if (SEQ_CNT_SIZE_G = 0) generate
      process (axisClk, axisRst) is
      begin
         if (RST_ASYNC_G and axisRst = '1') then
            ramDout <= (others => '0') after TPD_G;
         elsif (rising_edge(axisClk)) then
            if (RST_ASYNC_G = false and axisRst = '1') then
               ramDout <= (others => '0') after TPD_G;
            else
               ramDout <= ramDin after TPD_G;
            end if;
         end if;
      end process;
   end generate NO_SEQ;

   ramAddrr <= rin.activeTDest when (TDEST_BITS_G > 0) else (others => '0');
   crcIn    <= endianSwap(inputAxisMaster.tData(63 downto 0));

   GEN_CRC : if (CRC_EN_C) generate

      ETH_CRC : if (CRC_POLY_G = x"04C11DB7") generate
         U_Crc32 : entity surf.Crc32Parallel
            generic map (
               TPD_G            => TPD_G,
               RST_ASYNC_G      => RST_ASYNC_G,
               INPUT_REGISTER_G => false,
               BYTE_WIDTH_G     => 8,
               CRC_INIT_G       => X"FFFFFFFF")
            port map (
               crcPwrOnRst  => axisRst,
               crcOut       => crcOut,
               crcRem       => crcRem,
               crcClk       => axisClk,
               crcDataValid => rin.crcDataValid,
               crcDataWidth => rin.crcDataWidth,
               crcIn        => crcIn,
               crcInit      => rin.crcInit,
               crcReset     => rin.crcReset);
      end generate;

      GENERNAL_CRC : if (CRC_POLY_G /= x"04C11DB7") generate
         U_Crc32 : entity surf.Crc32
            generic map (
               TPD_G            => TPD_G,
               RST_ASYNC_G      => RST_ASYNC_G,
               INPUT_REGISTER_G => false,
               BYTE_WIDTH_G     => 8,
               CRC_INIT_G       => X"FFFFFFFF",
               CRC_POLY_G       => CRC_POLY_G)
            port map (
               crcPwrOnRst  => axisRst,
               crcOut       => crcOut,
               crcRem       => crcRem,
               crcClk       => axisClk,
               crcDataValid => rin.crcDataValid,
               crcDataWidth => rin.crcDataWidth,
               crcIn        => crcIn,
               crcInit      => rin.crcInit,
               crcReset     => rin.crcReset);
      end generate;

   end generate;

   comb : process (inputAxisMaster, linkGood, outputAxisSlave, r, ramCrcRem, crcOut,
                   ramPacketActiveOut, ramPacketSeqOut, ramSentEofeOut) is
      variable v         : RegType;
      variable sof       : sl;
      variable lastBytes : integer;

      procedure doTail is
      begin
         -- Check for packetError or CRC error
         if ((r.state = MOVE_S) and (v.debug.packetError = '1')) or
            ((r.state = MOVE_S) and ((CRC_EN_C = true) and (v.outputAxisMaster(1).tData(PACKETIZER2_TAIL_CRC_FIELD_C) /= crcOut))) or
            ((r.state = MOVE_S) and ((CRC_EN_C = false) and (v.outputAxisMaster(1).tData(PACKETIZER2_TAIL_CRC_FIELD_C) /= x"00000000"))) or
            ((r.state = CRC_S) and (r.debug.packetError = '1')) or
            ((r.state = CRC_S) and ((CRC_EN_C = true) and (r.outputAxisMaster(1).tData(PACKETIZER2_TAIL_CRC_FIELD_C) /= crcOut))) or
            ((r.state = CRC_S) and ((CRC_EN_C = false) and (r.outputAxisMaster(1).tData(PACKETIZER2_TAIL_CRC_FIELD_C) /= x"00000000"))) then
            -- EOP with error, do EOFE
            ssiSetUserEofe(AXIS_CONFIG_C, v.outputAxisMaster(0), '1');
            v.outputAxisMaster(0).tLast := '1';
            v.packetActive              := '0';
            v.packetSeq                 := (others => '0');
            v.sentEofe                  := '1';
            v.crcInit                   := (others => '1');
            v.crcReset                  := '1';  -- Reset CRC in ram to 0xFFFFFFFF
            v.ramWe                     := '1';
            v.debug.eof                 := '1';
            v.debug.eofe                := '1';
            v.debug.eop                 := '1';

            if CRC_EN_C then
               if (r.outputAxisMaster(1).tData(PACKETIZER2_TAIL_CRC_FIELD_C) /= crcOut) then
                  v.debug.crcError := '1';
               end if;
            else
               if (r.outputAxisMaster(1).tData(PACKETIZER2_TAIL_CRC_FIELD_C) /= x"00000000") then
                  v.debug.crcError := '1';
               end if;
            end if;

         elsif ((r.state = MOVE_S) and (v.outputAxisMaster(1).tData(PACKETIZER2_TAIL_EOF_BIT_C) = '1')) or
            ((r.state = CRC_S) and (r.outputAxisMaster(1).tData(PACKETIZER2_TAIL_EOF_BIT_C) = '1')) then
            -- If EOF, reset packetActive and packetSeq
            v.packetActive := '0';
            v.packetSeq    := (others => '0');
            v.sentEofe     := '0';
            v.crcInit      := (others => '1');
            v.crcReset     := '1';      -- Reset CRC in ram to 0xFFFFFFFF
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
      end procedure doTail;
   begin
      -- Latch the current value
      v := r;

      -- Reset debug strobes flag
      v.debug          := PACKETIZER2_DEBUG_INIT_C;
      v.debug.initDone := r.debug.initDone;  --- Don't touch initDone

      -- Don't write new packet number by default
      v.ramWe := '0';

      -- Default CRC variable values
      v.crcDataValid := '0';
      v.crcReset     := '0';
      v.crcDataWidth := "111";          -- 64-bit transfer

      -- Reset tready by default
      v.inputAxisSlave.tready := '0';

      -- Check if data accepted
      if (outputAxisSlave.tReady = '1') then
         v.outputAxisMaster(1).tValid := '0';
         v.outputAxisMaster(0).tValid := '0';
      end if;

      case r.state is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Update the RAM address
            if (TDEST_BITS_G > 0) then
               v.activeTDest := inputAxisMaster.tData((ADDR_WIDTH_C-1)+PACKETIZER2_HDR_TDEST_BIT_C downto PACKETIZER2_HDR_TDEST_BIT_C);
            else
               v.activeTDest := (others => '0');
            end if;

            -- Advance the output pipeline
            if (r.outputAxisMaster(1).tValid = '1' and v.outputAxisMaster(0).tValid = '0') then
               v.outputAxisMaster(0) := r.outputAxisMaster(1);
            end if;

            -- Check for data
            if (inputAxisMaster.tValid = '1') then
               -- Check for 2 read cycle latency
               if (MEMORY_TYPE_G /= "distributed") and (REG_EN_G) then
                  v.state := WAIT_S;
               -- Else 1 read cycle latency
               else
                  v.state := HEADER_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when WAIT_S =>
            v.state := HEADER_S;
         ----------------------------------------------------------------------
         when HEADER_S =>
            -- The header data won't be pushed to the output this cycle, so accept by default
            v.inputAxisSlave.tready := '1';
            v.outputAxisMaster(1)   := axiStreamMasterInit(AXIS_CONFIG_C);

            -- Reset the CRC for the next packet
            v.crcReset := '1';
            v.crcInit  := ramCrcRem;

            -- Update the RAM address
            if (TDEST_BITS_G > 0) then
               v.activeTDest := inputAxisMaster.tData((ADDR_WIDTH_C-1)+PACKETIZER2_HDR_TDEST_BIT_C downto PACKETIZER2_HDR_TDEST_BIT_C);
            else
               v.activeTDest := (others => '0');
            end if;

            -- Assign sideband fields
            v.outputAxisMaster(1).tDest(7 downto 0)              := x"00";  -- Initialize
            v.outputAxisMaster(1).tDest(ADDR_WIDTH_C-1 downto 0) := v.activeTDest;
            v.outputAxisMaster(1).tId(7 downto 0)                := inputAxisMaster.tData(PACKETIZER2_HDR_TID_FIELD_C);
            v.outputAxisMaster(1).tUser(7 downto 0)              := inputAxisMaster.tData(PACKETIZER2_HDR_TUSER_FIELD_C);
            sof                                                  := inputAxisMaster.tData(PACKETIZER2_HDR_SOF_BIT_C);
            v.packetSeq                                          := inputAxisMaster.tData(PACKETIZER2_HDR_SEQ_FIELD_C'low+SEQ_CNT_SIZE_C-1 downto PACKETIZER2_HDR_SEQ_FIELD_C'low);

            -- Advance the output pipeline
            if (r.outputAxisMaster(1).tValid = '1' and v.outputAxisMaster(0).tValid = '0') then
               v.outputAxisMaster(0) := r.outputAxisMaster(1);
            end if;

            -- Process an incoming transaction
            if (inputAxisMaster.tValid = '1' and v.outputAxisMaster(1).tValid = '0') then
               -- Calculate CRC on head of enabled to do so
               v.crcDataValid := toSl(CRC_HEAD_TAIL_C);

               -- Check for BRAM or REG_EN_G used
               if (MEMORY_TYPE_G /= "distributed") or (REG_EN_G) then
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
                     (inputAxisMaster.tData(PACKETIZER2_HDR_CRC_TYPE_FIELD_C) = crcStrToSlv(CRC_MODE_G)) then
                     -- Header metadata as expected
                     v.state    := MOVE_S;
                     v.sideband := '1';

                     -- Set packetActive in ram for this tdest
                     -- v.packetSeq is already correct
                     v.packetActive := '1';
                     v.sentEofe     := '0';  -- Clear any frame error
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

                     if (sof /= not ramPacketActiveOut) then
                        v.debug.sofError := '1';
                     end if;
                     if (v.packetSeq /= ramPacketSeqOut) then
                        v.debug.seqError := '1';
                     end if;
                     if (inputAxisMaster.tData(PACKETIZER2_HDR_VERSION_FIELD_C) /= PACKETIZER2_VERSION_C) then
                        v.debug.versionError := '1';
                     end if;
                     if (inputAxisMaster.tData(PACKETIZER2_HDR_CRC_TYPE_FIELD_C) /= crcStrToSlv(CRC_MODE_G)) then
                        v.debug.crcModeError := '1';
                     end if;
                  end if;

               end if;
            end if;
         ----------------------------------------------------------------------
         when MOVE_S =>
            -- Keep the caches copy
            v.outputAxisMaster(1).tvalid := r.outputAxisMaster(1).tvalid;
            -- Check if we can move data
            if (inputAxisMaster.tValid = '1' and v.outputAxisMaster(0).tValid = '0') then
               -- Accept the data
               v.inputAxisSlave.tready     := '1';
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
                  v.sideband                  := '0';
               end if;
               -- Updated the CRC
               v.crcDataValid := toSl(CRC_EN_C);
               -- End of packet
               if (inputAxisMaster.tLast = '1') then
                  v.outputAxisMaster(1).tValid := '0';
                  v.crcDataWidth               := ite(CRC_HEAD_TAIL_C, "011", "111");  -- 32-bit transfer
                  v.crcDataValid               := toSl(CRC_HEAD_TAIL_C);
                  -- Append EOF metadata to previous txn which has been held
                  lastBytes                    := conv_integer(inputAxisMaster.tData(PACKETIZER2_TAIL_BYTES_FIELD_C));
                  v.outputAxisMaster(0).tLast  := inputAxisMaster.tData(PACKETIZER2_TAIL_EOF_BIT_C);
                  v.outputAxisMaster(0).tKeep  := genTkeep(conv_integer(inputAxisMaster.tData(PACKETIZER2_TAIL_BYTES_FIELD_C)));
                  axiStreamSetUserField(AXIS_CONFIG_C, v.outputAxisMaster(0), inputAxisMaster.tData(PACKETIZER2_TAIL_TUSER_FIELD_C), -1);  -- -1 = last
                  -- Update flag
                  v.debug.packetError          := ssiGetUserEofe(AXIS_CONFIG_C, inputAxisMaster);
                  v.debug.eofeError            := ssiGetUserEofe(AXIS_CONFIG_C, inputAxisMaster);

                  if (CRC_HEAD_TAIL_C) then
                     -- Need to calculate CRC on tail data
                     -- Hold everything
                     v.outputAxisMaster(0).tValid := '0';
                     v.state                      := CRC_S;
                  else
                     -- Can sent tail right now
                     doTail;
                     -- Check for BRAM used
                     if (MEMORY_TYPE_G /= "distributed") or (REG_EN_G) then
                        -- Next state (1 or 2 cycle read latency)
                        v.state := IDLE_S;
                     else
                        -- Next state (0 cycle read latency)
                        v.state := HEADER_S;
                     end if;
                  end if;
               end if;
            end if;
         ----------------------------------------------------------------------
         when CRC_S =>
            -- Move the data (Note: v.outputAxisMaster(0).tValid = '0' in previous state)
            v.outputAxisMaster(0).tValid := '1';
            -- Can sent tail right now
            doTail;
            -- Check for BRAM used
            if (MEMORY_TYPE_G /= "distributed") or (REG_EN_G) then
               -- Next state (1 or 2 cycle read latency)
               v.state := IDLE_S;
            else
               -- Next state (0 cycle read latency)
               v.state := HEADER_S;
            end if;
         ----------------------------------------------------------------------
         when TERMINATE_S =>

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
            if (r.debug.initDone = '1') then
               -- Wait for link to come back up
               if (linkGood = '1') then
                  -- Check for BRAM or REG_EN_G used
                  if (MEMORY_TYPE_G /= "distributed") or (REG_EN_G) then
                     -- Next state (1 or 2 cycle read latency)
                     v.state := IDLE_S;
                  else
                     -- Next state (0 cycle read latency)
                     v.state := HEADER_S;
                  end if;
               end if;
            else
               -- Check if ready to move data and RAM output ready
               if (v.outputAxisMaster(1).tValid = '0') and (r.rdLat = 0) then
                  -- Write to the RAM
                  v.activeTDest                                        := r.activeTDest - 1;
                  -- Increment the index
                  v.ramWe                                              := '1';
                  -- Terminate any open frames with EOFE
                  ssiSetUserEofe(AXIS_CONFIG_C, v.outputAxisMaster(1), '1');
                  v.outputAxisMaster(1).tLast                          := '1';
                  v.outputAxisMaster(1).tValid                         := ramPacketActiveOut;
                  v.outputAxisMaster(1).tDest(7 downto 0)              := x"00";  -- Initialize
                  v.outputAxisMaster(1).tDest(ADDR_WIDTH_C-1 downto 0) := r.activeTDest;
                  v.debug.eof                                          := ramPacketActiveOut;
                  v.debug.eofe                                         := ramPacketActiveOut;
                  -- Check if initializing the RAM is done
                  if (r.activeTDest = 0) then
                     v.debug.initDone := '1';
                  end if;
               end if;
            end if;
      ----------------------------------------------------------------------
      end case;

      -- Check for read transaction
      if (r.activeTDest /= v.activeTDest) then
         -- zero latency
         if (MEMORY_TYPE_G = "distributed") and (REG_EN_G = false) then
            v.rdLat := 0;
         -- 1 cycle latency
         elsif (MEMORY_TYPE_G = "distributed") and (REG_EN_G = true) then
            v.rdLat := 1;
         -- 1 cycle latency
         elsif (MEMORY_TYPE_G /= "distributed") and (REG_EN_G = false) then
            v.rdLat := 1;
         -- 2 cycle latency
         else
            v.rdLat := 2;
         end if;
      elsif (r.rdLat /= 0) then
         v.rdLat := r.rdLat - 1;
      end if;

      -- Keep a delayed copy
      v.linkGoodDly := linkGood;

      -- Check for link drop event
      if (r.linkGoodDly = '1') and (linkGood = '0') then
         -- Reset CRC now because crcRem has 1 cycle latency
         v.crcReset       := '1';
         v.crcInit        := (others => '1');
         -- Reset the index
         v.activeTDest    := (others => '1');
         v.debug.initDone := '0';
         -- Next state
         v.state          := TERMINATE_S;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs
      inputAxisSlave   <= v.inputAxisSlave;
      outputAxisMaster <= r.outputAxisMaster(0);
      debug            <= r.debug;

   end process comb;

   seq : process (axisClk, axisRst) is
   begin
      if (RST_ASYNC_G and axisRst = '1') then
         r <= REG_INIT_C after TPD_G;
      elsif (rising_edge(axisClk)) then
         if (RST_ASYNC_G = false and axisRst = '1') then
            r <= REG_INIT_C after TPD_G;
         else
            r <= rin after TPD_G;
         end if;
      end if;
   end process seq;

   ------------------
   -- Output pipeline
   ------------------
   U_Output : entity surf.AxiStreamPipeline
      generic map (
         TPD_G         => TPD_G,
         RST_ASYNC_G   => RST_ASYNC_G,
         PIPE_STAGES_G => OUTPUT_PIPE_STAGES_G)
      port map (
         axisClk     => axisClk,
         axisRst     => axisRst,
         sAxisMaster => outputAxisMaster,
         sAxisSlave  => outputAxisSlave,
         mAxisMaster => mAxisMaster,
         mAxisSlave  => mAxisSlave);

end architecture rtl;
