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
use ieee.numeric_std.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;
use surf.SsiPkg.all;

entity AxiStreamPacketizer is
   generic (
      TPD_G                : time            := 1 ns;
      RST_ASYNC_G          : boolean         := false;
      MAX_PACKET_BYTES_G   : integer         := 1440;  -- Must be a multiple of 8
      MIN_TKEEP_G          : slv(7 downto 0) := x"01";
      OUTPUT_SSI_G         : boolean         := true;  -- SSI compliant output (SOF on tuser)
      INPUT_PIPE_STAGES_G  : integer         := 0;
      OUTPUT_PIPE_STAGES_G : integer         := 0);
   port (
      -- AXI-Lite Interface for local registers
      axisClk : in sl;
      axisRst : in sl;

      -- Actual byte count; will be truncated to multiple of word-size
      maxPktBytes : in slv(bitSize(MAX_PACKET_BYTES_G) - 1 downto 0) := toSlv(MAX_PACKET_BYTES_G, bitSize(MAX_PACKET_BYTES_G));

      sAxisMaster : in  AxiStreamMasterType;
      sAxisSlave  : out AxiStreamSlaveType;

      mAxisMaster : out AxiStreamMasterType;
      mAxisSlave  : in  AxiStreamSlaveType);
end entity AxiStreamPacketizer;

architecture rtl of AxiStreamPacketizer is

   constant LD_WORD_SIZE_C : positive := 3;
   constant WORD_SIZE_C    : positive := 2**LD_WORD_SIZE_C;

   subtype WordCounterType is unsigned(maxPktBytes'left - LD_WORD_SIZE_C downto 0);

   constant PROTO_WORDS_C    : positive        := 3;
   constant MAX_WORD_COUNT_C : WordCounterType := to_unsigned(MAX_PACKET_BYTES_G / WORD_SIZE_C, WordCounterType'length);

   constant AXIS_CONFIG_C : AxiStreamConfigType := (
      TSTRB_EN_C    => false,
      TDATA_BYTES_C => 8,
      TDEST_BITS_C  => 0,
      TID_BITS_C    => 0,
      TKEEP_MODE_C  => TKEEP_NORMAL_C,
      TUSER_BITS_C  => ite(OUTPUT_SSI_G, 2, 0),
      TUSER_MODE_C  => TUSER_FIRST_LAST_C);

   constant VERSION_C : slv(3 downto 0) := "0000";

   type StateType is (
      IDLE_S,
      MOVE_S,
      TAIL_S);

   type RegType is record
      state            : StateType;
      frameNumber      : unsigned(11 downto 0);
      packetNumber     : unsigned(23 downto 0);
      wordCount        : WordCounterType;
      maxWords         : WordCounterType;
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
      maxWords         => to_unsigned(1, WordCounterType'length),
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

   signal maxWords : WordCounterType;

   -- attribute dont_touch                     : string;
   -- attribute dont_touch of r                : signal is "TRUE";
   -- attribute dont_touch of inputAxisMaster  : signal is "TRUE";
   -- attribute dont_touch of inputAxisSlave   : signal is "TRUE";
   -- attribute dont_touch of outputAxisMaster : signal is "TRUE";
   -- attribute dont_touch of outputAxisSlave  : signal is "TRUE";

begin

   assert ((MAX_PACKET_BYTES_G rem 8) = 0)
      report "MAX_PACKET_BYTES_G must be a multiple of 8" severity error;

   maxWords <= WordCounterType(maxPktBytes(maxPktBytes'left downto LD_WORD_SIZE_C));

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

   comb : process (axisRst, inputAxisMaster, outputAxisSlave, r, maxWords) is
      variable v    : RegType;
      variable fits : boolean;

   begin
      -- Latch the current value
      v := r;

      -- Reset tready by default
      v.inputAxisSlave.tready := '0';

      -- Check if data accepted
      if (outputAxisSlave.tReady = '1') then
         v.outputAxisMaster.tValid := '0';
      end if;

      case r.state is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Reset the counter
            v.wordCount := (others => '0');

            -- Check and register the max. word count
            -- NOTE: wordCount is compared only after incrementing
            --       (and doing some work in MOVE_S), thus at least
            --       one non-protocol word  must fit.
            if (maxWords <= to_unsigned(PROTO_WORDS_C, maxWords'length)) then
               fits := false;
            else
               fits := true;
               if (maxWords >= MAX_WORD_COUNT_C) then
                  v.maxWords := MAX_WORD_COUNT_C - PROTO_WORDS_C;
               else
                  v.maxWords := maxWords - PROTO_WORDS_C;
               end if;
            end if;

            -- Check if ready to move data
            if (fits and inputAxisMaster.tValid = '1' and v.outputAxisMaster.tValid = '0') then
               -- Initialize the AXIS buffer
               v.outputAxisMaster                     := axiStreamMasterInit(AXIS_CONFIG_C);
               -- Generate the 64-bit header
               v.outputAxisMaster.tValid              := '1';
               v.outputAxisMaster.tData(3 downto 0)   := VERSION_C;
               v.outputAxisMaster.tData(15 downto 4)  := slv(r.frameNumber);
               v.outputAxisMaster.tData(39 downto 16) := slv(r.packetNumber);
               v.outputAxisMaster.tData(47 downto 40) := inputAxisMaster.tDest(7 downto 0);
               v.outputAxisMaster.tData(55 downto 48) := inputAxisMaster.tId(7 downto 0);
               v.outputAxisMaster.tData(63 downto 56) := inputAxisMaster.tUser(7 downto 0);
               -- Check if SSI output
               if (OUTPUT_SSI_G) then
                  -- Set the SOF bit
                  axiStreamSetUserBit(AXIS_CONFIG_C, v.outputAxisMaster, SSI_SOF_C, '1', 0);  -- SOF
               end if;
               -- Increment the counter
               v.packetNumber := r.packetNumber + 1;
               -- Next state
               v.state        := MOVE_S;
            end if;
         ----------------------------------------------------------------------
         when MOVE_S =>
            -- Check if ready to move data
            if (inputAxisMaster.tValid = '1' and v.outputAxisMaster.tValid = '0') then

               -- Accept the data
               v.inputAxisSlave.tReady := '1';

               -- Send data through
               v.outputAxisMaster       := inputAxisMaster;
               v.outputAxisMaster.tUser := (others => '0');
               v.outputAxisMaster.tDest := (others => '0');
               v.outputAxisMaster.tId   := (others => '0');
               v.outputAxisMaster.tKeep := resize(x"00FF", AXI_STREAM_MAX_TKEEP_WIDTH_C);

               -- Increment word count with each txn
               v.wordCount := r.wordCount + 1;

               -- Reach max packet size. Append tail.
               if (r.wordCount = r.maxWords) then
                  -- Next state
                  v.state := TAIL_S;
               end if;

               -- Check for the end of the frame
               if (inputAxisMaster.tLast = '1') then

                  -- Increment the counter
                  v.frameNumber  := r.frameNumber + 1;
                  -- Reset the counter
                  v.packetNumber := (others => '0');
                  -- Next state
                  v.state        := IDLE_S;

                  ----------------------------------------------------------------------
                  -- Generate the TAIL with respect to the TKEEP
                  ----------------------------------------------------------------------
                  case (inputAxisMaster.tKeep(7 downto 0)) is
                     when x"00" =>
                        v.outputAxisMaster.tKeep(7 downto 0) := (x"01" or MIN_TKEEP_G);
                        v.outputAxisMaster.tData(7 downto 0) := '1' & inputAxisMaster.tUser(6 downto 0);
                     when x"01" =>
                        v.outputAxisMaster.tKeep(7 downto 0)  := (x"03" or MIN_TKEEP_G);
                        v.outputAxisMaster.tData(15 downto 8) := '1' & inputAxisMaster.tUser(14 downto 8);
                     when x"03" =>
                        v.outputAxisMaster.tKeep(7 downto 0)   := (x"07" or MIN_TKEEP_G);
                        v.outputAxisMaster.tData(23 downto 16) := '1' & inputAxisMaster.tUser(22 downto 16);
                     when x"07" =>
                        v.outputAxisMaster.tKeep(7 downto 0)   := (x"0F" or MIN_TKEEP_G);
                        v.outputAxisMaster.tData(31 downto 24) := '1' & inputAxisMaster.tUser(30 downto 24);
                     when x"0F" =>
                        v.outputAxisMaster.tKeep(7 downto 0)   := (x"1F" or MIN_TKEEP_G);
                        v.outputAxisMaster.tData(39 downto 32) := '1' & inputAxisMaster.tUser(38 downto 32);
                     when x"1F" =>
                        v.outputAxisMaster.tKeep(7 downto 0)   := (x"3F" or MIN_TKEEP_G);
                        v.outputAxisMaster.tData(47 downto 40) := '1' & inputAxisMaster.tUser(46 downto 40);
                     when x"3F" =>
                        v.outputAxisMaster.tKeep(7 downto 0)   := (x"7F" or MIN_TKEEP_G);
                        v.outputAxisMaster.tData(55 downto 48) := '1' & inputAxisMaster.tUser(54 downto 48);
                     when x"7F" =>
                        v.outputAxisMaster.tKeep(7 downto 0)   := (x"FF" or MIN_TKEEP_G);
                        v.outputAxisMaster.tData(63 downto 56) := '1' & inputAxisMaster.tUser(62 downto 56);
                     when others =>
                        -- No room for TAIL this cycle and will add it in the next state
                        v.outputAxisMaster.tKeep(7 downto 0) := (x"FF" or MIN_TKEEP_G);
                        -- Save the tUser at tLast
                        v.tUserLast                          := inputAxisMaster.tUser(7 downto 0);
                        -- Set the flag
                        v.eof                                := '1';
                        -- Reset the flag
                        v.outputAxisMaster.tLast             := '0';
                        -- Next state
                        v.state                              := TAIL_S;
                  end case;
                  ----------------------------------------------------------------------

               end if;
            end if;
         ----------------------------------------------------------------------
         when TAIL_S =>
            -- Check if ready to move data
            if (v.outputAxisMaster.tValid = '0') then
               -- Generate the footer
               v.outputAxisMaster.tValid            := '1';
               v.outputAxisMaster.tKeep(7 downto 0) := MIN_TKEEP_G;  --x"01";
               v.outputAxisMaster.tData             := (others => '0');
               v.outputAxisMaster.tData(7)          := r.eof;
               v.outputAxisMaster.tData(6 downto 0) := r.tUserLast(6 downto 0);
               v.outputAxisMaster.tUser             := (others => '0');
               v.outputAxisMaster.tLast             := '1';
               -- Set the flag
               v.eof                                := '0';
               -- Next state
               v.state                              := IDLE_S;
            end if;
      ----------------------------------------------------------------------
      end case;

      -- Match the tStrobe to tKeep
      v.outputAxisMaster.tStrb := v.outputAxisMaster.tKeep;

      -- Combinatorial outputs before the reset
      inputAxisSlave <= v.inputAxisSlave;

      -- Reset
      if (RST_ASYNC_G = false and axisRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Registered Outputs
      outputAxisMaster <= r.outputAxisMaster;

   end process comb;

   seq : process (axisClk, axisRst) is
   begin
      if (RST_ASYNC_G and axisRst = '1') then
         r <= REG_INIT_C after TPD_G;
      elsif rising_edge(axisClk) then
         r <= rin after TPD_G;
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
