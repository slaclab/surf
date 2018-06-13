-------------------------------------------------------------------------------
-- File       : AxiStreamPacketizer2.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2017-05-02
-- Last update: 2018-06-13
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

entity AxiStreamPacketizer2 is
   generic (
      TPD_G                : time             := 1 ns;
      BRAM_EN_G            : boolean          := false;
      CRC_MODE_G           : string           := "DATA";  -- or "NONE" or "FULL"
      CRC_POLY_G           : slv(31 downto 0) := x"04C11DB7";
      MAX_PACKET_BYTES_G   : positive         := 256*8;  -- Must be a multiple of 8
      TDEST_BITS_G         : natural          := 8;
      INPUT_PIPE_STAGES_G  : natural          := 0;
      OUTPUT_PIPE_STAGES_G : natural          := 0);
   port (
      -- Clock and Reset
      axisClk     : in  sl;
      axisRst     : in  sl;
      -- Status for phase locking externally
      rearbitrate : out sl;
      -- AXIS Interfaces
      sAxisMaster : in  AxiStreamMasterType;
      sAxisSlave  : out AxiStreamSlaveType;
      mAxisMaster : out AxiStreamMasterType;
      mAxisSlave  : in  AxiStreamSlaveType);
end entity AxiStreamPacketizer2;

architecture rtl of AxiStreamPacketizer2 is

   constant MAX_WORD_COUNT_C : positive := (MAX_PACKET_BYTES_G / 8) - 3;
   constant CRC_EN_C         : boolean  := (CRC_MODE_G /= "NONE");
   constant CRC_HEAD_TAIL_C  : boolean  := (CRC_MODE_G = "FULL");
   constant ADDR_WIDTH_C     : positive := ite((TDEST_BITS_G = 0), 1, TDEST_BITS_G);

   type StateType is (
      IDLE_S,
      HEADER_S,
      MOVE_S,
      TAIL_S);

   type RegType is record
      state            : StateType;
      packetSeq        : slv(15 downto 0);
      packetActive     : sl;
      activeTDest      : slv(ADDR_WIDTH_C-1 downto 0);
      ramWe            : sl;
      wordCount        : slv(bitSize(MAX_WORD_COUNT_C)-1 downto 0);
      eof              : sl;
      lastByteCount    : slv(3 downto 0);
      tUserLast        : slv(7 downto 0);
      rearbitrate      : sl;
      crcDataValid     : sl;
      crcDataWidth     : slv(2 downto 0);
      crcInit          : slv(31 downto 0);
      crcRem           : slv(31 downto 0);
      crcReset         : sl;
      tailCrcReady     : sl;
      inputAxisSlave   : AxiStreamSlaveType;
      outputAxisMaster : AxiStreamMasterType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      state            => HEADER_S,
      packetSeq        => (others => '0'),
      packetActive     => '0',
      activeTDest      => (others => '0'),
      ramWe            => '0',
      wordCount        => (others => '0'),
      eof              => '0',
      lastByteCount    => "1000",
      tUserLast        => (others => '0'),
      rearbitrate      => '0',
      crcDataValid     => '0',
      crcDataWidth     => (others => '1'),
      crcInit          => (others => '1'),
      crcRem           => (others => '1'),
      crcReset         => '0',
      tailCrcReady     => toSl(not CRC_HEAD_TAIL_C),
      inputAxisSlave   => AXI_STREAM_SLAVE_INIT_C,
      outputAxisMaster => axiStreamMasterInit(PACKETIZER2_AXIS_CFG_C));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal inputAxisMaster  : AxiStreamMasterType;
   signal inputAxisSlave   : AxiStreamSlaveType;
   signal outputAxisMaster : AxiStreamMasterType;
   signal outputAxisSlave  : AxiStreamSlaveType;

   signal ramPacketSeqOut    : slv(15 downto 0);
   signal ramPacketActiveOut : sl;
   signal ramCrcRem          : slv(31 downto 0) := (others => '1');
   signal ramAddrr           : slv(ADDR_WIDTH_C-1 downto 0);

   signal crcIn  : slv(63 downto 0) := (others => '1');
   signal crcOut : slv(31 downto 0) := (others => '0');
   signal crcRem : slv(31 downto 0) := (others => '1');

   -- attribute dont_touch                     : string;
   -- attribute dont_touch of r                : signal is "TRUE";
   -- attribute dont_touch of crcOut           : signal is "TRUE";
   -- attribute dont_touch of ramPacketSeqOut  : signal is "TRUE";
   -- attribute dont_touch of ramPacketActiveOut  : signal is "TRUE";
   -- attribute dont_touch of inputAxisMaster  : signal is "TRUE";
   -- attribute dont_touch of inputAxisSlave   : signal is "TRUE";
   -- attribute dont_touch of outputAxisMaster : signal is "TRUE";
   -- attribute dont_touch of outputAxisSlave  : signal is "TRUE";

begin

   assert ((MAX_PACKET_BYTES_G rem 8) = 0)
      report "MAX_PACKET_BYTES_G must be a multiple of 8" severity error;

   assert ((CRC_MODE_G = "NONE") or (CRC_MODE_G = "DATA") or (CRC_MODE_G = "FULL"))
      report "CRC_MODE_G must be NONE or DATA or FULL" severity error;

   assert (TDEST_BITS_G <= 8)
      report "TDEST_BITS_G must be less than or equal to 8" severity error;

   -----------------
   -- Input pipeline
   -----------------
   U_Input : entity work.AxiStreamPipeline
      generic map (
         TPD_G         => TPD_G,
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
   U_DualPortRam_1 : entity work.DualPortRam
      generic map (
         TPD_G        => TPD_G,
         BRAM_EN_G    => BRAM_EN_G,
         REG_EN_G     => false,
         DOA_REG_G    => false,
         DOB_REG_G    => false,
         BYTE_WR_EN_G => false,
         DATA_WIDTH_G => 17+32,
         ADDR_WIDTH_G => ADDR_WIDTH_C)
      port map (
         clka                => axisClk,
         rsta                => axisRst,
         wea                 => rin.ramWe,
         addra               => rin.activeTDest,
         dina(15 downto 0)   => rin.packetSeq,
         dina(16)            => rin.packetActive,
         dina(48 downto 17)  => rin.crcRem,
         clkb                => axisClk,
         rstb                => axisRst,
         addrb               => ramAddrr,
         doutb(15 downto 0)  => ramPacketSeqOut,
         doutb(16)           => ramPacketActiveOut,
         doutb(48 downto 17) => ramCrcRem);

   ramAddrr <= inputAxisMaster.tDest(ADDR_WIDTH_C-1 downto 0) when (TDEST_BITS_G > 0) else (others => '0');
   crcIn    <= endianSwap(rin.outputAxisMaster.tData(63 downto 0));

   GEN_CRC : if (CRC_EN_C) generate

      ETH_CRC : if (CRC_POLY_G = x"04C11DB7") generate
         U_Crc32 : entity work.Crc32Parallel
            generic map (
               TPD_G            => TPD_G,
               INPUT_REGISTER_G => false,
               BYTE_WIDTH_G     => 8,
               CRC_INIT_G       => X"FFFFFFFF")
            port map (
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
         U_Crc32 : entity work.Crc32
            generic map (
               TPD_G            => TPD_G,
               INPUT_REGISTER_G => false,
               BYTE_WIDTH_G     => 8,
               CRC_INIT_G       => X"FFFFFFFF",
               CRC_POLY_G       => CRC_POLY_G)
            port map (
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

   comb : process (axisRst, crcOut, crcRem, inputAxisMaster, outputAxisSlave,
                   r, ramCrcRem, ramPacketActiveOut, ramPacketSeqOut) is
      variable v     : RegType;
      variable tdest : slv(7 downto 0);
   begin
      -- Latch the current value
      v := r;

      if (outputAxisSlave.tReady = '1') then
         v.outputAxisMaster.tValid := '0';
      end if;

      -- Don't accept new data by default
      v.inputAxisSlave.tReady := '0';

      -- Don't write new packet number by default
      v.ramWe := '0';

      -- keep a copy of the CRC interim remainder (phased aligned with v.ramWe)
      v.crcRem := crcRem;

      -- Default CRC variable values
      v.crcDataValid := '0';
      v.crcReset     := '0';
      v.crcDataWidth := "111";          -- 64-bit transfer
      -- Stay at '1' and optimize away if CRC_HEAD_TAIL_G is false
      v.tailCrcReady := toSl(not CRC_HEAD_TAIL_C);

      -- Main state machine
      case r.state is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Check for data
            if (inputAxisMaster.tValid = '1') then
               v.state := HEADER_S;
            end if;
         ----------------------------------------------------------------------
         when HEADER_S =>
            -- Reset the word counter
            v.wordCount     := (others => '0');
            -- Set default tlast.tkeep (8 Bytes)
            v.lastByteCount := "1000";
            -- Pre-load the CRC with the interim remainder 
            v.crcInit       := ramCrcRem;
            -- Reset the CRC (which pre-loads it with crcInit)
            v.crcReset      := '1';
            -- Use header in CRC if enabled
            v.crcDataValid  := toSl(CRC_HEAD_TAIL_C);

            -- Check if ready to move data
            if (inputAxisMaster.tValid = '1' and v.outputAxisMaster.tValid = '0') then
               tdest                          := x"00";
               tdest(ADDR_WIDTH_C-1 downto 0) := inputAxisMaster.tDest(ADDR_WIDTH_C-1 downto 0);
               v.outputAxisMaster :=
                  makePacketizer2Header(
                     CRC_MODE_C => CRC_MODE_G,
                     valid      => inputAxisMaster.tValid,
                     sof        => not ramPacketActiveOut,
                     tdest      => tDest,
                     tuser      => inputAxisMaster.tUser(7 downto 0),
                     tid        => inputAxisMaster.tId,
                     seq        => ramPacketSeqOut);

               -- Check for active header
               if (ramPacketActiveOut = '0') then
                  -- Reset crc at start of new frame
                  v.crcInit := (others => '1');
               end if;

               -- Increment the sequence counter
               v.packetSeq    := ramPacketSeqOut + 1;
               -- Set the flag
               v.packetActive := '1';
               -- Latch the current TDEST for TDEST change detection in next state
               v.activeTDest  := inputAxisMaster.tDest(ADDR_WIDTH_C-1 downto 0);
               -- Next state
               v.state        := MOVE_S;

            end if;
         ----------------------------------------------------------------------
         when MOVE_S =>
            -- Check if ready to move data
            if (inputAxisMaster.tvalid = '1' and v.outputAxisMaster.tValid = '0') then

               -- Accept the data
               v.inputAxisSlave.tReady := '1';

               -- Send data through
               v.outputAxisMaster       := inputAxisMaster;
               v.outputAxisMaster.tUser := (others => '0');
               v.outputAxisMaster.tDest := (others => '0');
               v.outputAxisMaster.tId   := (others => '0');

               -- Increment word count with each txn
               v.wordCount := r.wordCount + 1;

               -- Reach max packet size. Append tail.
               if (r.wordCount = MAX_WORD_COUNT_C) then
                  -- Next state
                  v.state := TAIL_S;
               end if;

               -- Upstream interleave detected, append tail
               if (inputAxisMaster.tDest(ADDR_WIDTH_C-1 downto 0) /= r.activeTDest) then

                  -- Hold acceptance of new data
                  -- and transmission of output data
                  v.inputAxisSlave.tReady   := '0';
                  v.outputAxisMaster        := r.outputAxisMaster;
                  v.outputAxisMaster.tValid := '0';
                  -- Next state
                  v.state                   := TAIL_S;
                  -- Write metadata to RAM
                  v.ramWe                   := '1';

               -- End of frame, append tail
               elsif (inputAxisMaster.tLast = '1') then

                  -- Reset frame state in ram
                  v.packetSeq              := (others => '0');
                  v.packetActive           := '0';
                  v.tUserLast              := inputAxisMaster.tUser(7 downto 0);
                  v.eof                    := '1';
                  v.lastByteCount          := toSlv(getTKeep(inputAxisMaster.tKeep), 4);
                  v.outputAxisMaster.tLast := '0';
                  -- Next state
                  v.state                  := TAIL_S;
                  -- Write metadata to RAM
                  v.ramWe                  := '1';

               end if;

               -- Update the CRC based on the next outputAxisMaster.tValid
               v.crcDataValid := v.outputAxisMaster.tValid;

            end if;
         ----------------------------------------------------------------------
         when TAIL_S =>
            -- Assign the crc block inputs
            -- Don't do CRC if CRC_HEAD_TAIL_G is false
            v.crcDataValid := not(r.tailCrcReady);
            v.crcDataWidth := "011";    -- 32-bit transfer

            -- It CRC_HEAD_TAIL_G = true, tailCrcReady will be '0' coming in to this state
            -- This delays the output txn by 1 cycle to allow the CRC to be
            -- calculated on the tail data
            -- If CRC_HEAD_TAIL_G = false, tailCrcReady will be '1' coming in to this state
            -- Can send the tail txn right away as we have the CRC,
            v.tailCrcReady := '1';
            if (r.tailCrcReady = '1') then
               if (v.outputAxisMaster.tValid = '0') then
                  -- Send the tail
                  v.outputAxisMaster.tValid := '1';
                  -- Assign the tail txn
                  v.outputAxisMaster :=
                     makePacketizer2Tail(
                        CRC_MODE_C => CRC_MODE_G,
                        valid      => '0',  -- Override below
                        eof        => r.eof,
                        tuser      => r.tUserLast,
                        bytes      => r.lastByteCount,
                        crc        => crcOut);
                  -- Save current CRC and packet state in ram
                  -- and clear registers for next frame
                  v.ramWe     := '1';
                  v.eof       := '0';
                  v.tUserLast := (others => '0');
                  -- Check for BRAM used
                  if (BRAM_EN_G) then
                     -- Next state (1 cycle read latency)
                     v.state := IDLE_S;
                  else
                     -- Next state (0 cycle read latency)
                     v.state := HEADER_S;
                  end if;
               end if;
            end if;
      ----------------------------------------------------------------------
      end case;

      -- Always a 64-bit transfer
      v.outputAxisMaster.tKeep := x"00FF";
      v.outputAxisMaster.tStrb := v.outputAxisMaster.tKeep;

      -- Combinatorial outputs before the reset
      inputAxisSlave <= v.inputAxisSlave;

      -- Reset
      if (axisRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Registered Outputs
      outputAxisMaster <= r.outputAxisMaster;
      rearbitrate      <= r.rearbitrate;

   end process comb;

   seq : process (axisClk) is
   begin
      if (rising_edge(axisClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   ------------------
   -- Output pipeline
   ------------------
   U_Output : entity work.AxiStreamPipeline
      generic map (
         TPD_G         => TPD_G,
         PIPE_STAGES_G => OUTPUT_PIPE_STAGES_G)
      port map (
         axisClk     => axisClk,
         axisRst     => axisRst,
         sAxisMaster => outputAxisMaster,
         sAxisSlave  => outputAxisSlave,
         mAxisMaster => mAxisMaster,
         mAxisSlave  => mAxisSlave);

end architecture rtl;
