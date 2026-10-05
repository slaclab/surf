-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Native VHDL RoCEv2 iCRC engine. Replaces the Bluespec-
--              generated Send/Recv CRC Verilog with an eight-stage
--              pipeline mirroring CrcAxiStream.bsv's own eight
--              rules exactly, built on surf.RoCEv2ICrcPkg's elaboration-time
--              lookup tables. SEND_MODE_G selects Send or Recv behaviour at
--              the three points the two directions differ (all three are
--              table-base offsets); no other part of the datapath changes
--              between the two modes.
--
--              The port list is name-identical and width-identical to the
--              component declaration the Send and Recv wrappers carried
--              before this engine existed, so each wrapper's existing
--              eleven-line named port map needs no edit, only a mode
--              generic added to the entity instantiation.
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
use surf.RoCEv2ICrcPkg.all;

entity RoCEv2ICrc is
   generic (
      TPD_G       : time    := 1 ns;   -- simulation propagation delay
      SEND_MODE_G : boolean := true);  -- true = Send direction, false = Recv direction
   port (
      CLK                : in  std_logic;
      RST_N              : in  std_logic;
      s_axis_tvalid      : in  std_logic;
      s_axis_tdata       : in  std_logic_vector(255 downto 0);
      s_axis_tkeep       : in  std_logic_vector(31 downto 0);
      s_axis_tlast       : in  std_logic;
      -- Declared and intentionally unused: the original design's own
      -- preProcess rule reads only tData, tKeep, and tLast, never tUser.
      -- Keeping this port makes the entity's port list name-identical to
      -- the component the wrappers previously declared.
      s_axis_tuser       : in  std_logic;
      s_axis_tready      : out std_logic;
      m_crc_stream_data  : out std_logic_vector(31 downto 0);
      m_crc_stream_valid : out std_logic;
      m_crc_stream_ready : in  std_logic);
end entity RoCEv2ICrc;

architecture rtl of RoCEv2ICrc is

   -- Mirrors CrcAxiStream.bsv's CrcCtrlSig struct: the per-beat control
   -- fields carried alongside the data through stages 1 through 5.
   type CtrlType is record
      isFirst  : sl;
      isLast   : sl;
      shiftAmt : natural range 0 to AXIS_KEEP_WIDTH_C;
   end record CtrlType;

   constant CTRL_INIT_C : CtrlType := (
      isFirst  => '0',
      isLast   => '0',
      shiftAmt => 0);

   type RegType is record
      -- Stage 1, preProcess (CrcAxiStream.bsv:82).
      preValid    : sl;
      preData     : slv(AXIS_DATA_WIDTH_C - 1 downto 0);
      preCtrl     : CtrlType;
      isFirstFlag : sl;
      -- Stage 2, shiftInput (CrcAxiStream.bsv:112).
      shiftValid  : sl;
      shiftData   : slv(AXIS_DATA_WIDTH_C - 1 downto 0);
      shiftCtrl   : CtrlType;
      -- Stage 3, readCrcTab plus the lower fold levels (CrcAxiStream.bsv:122).
      tabValid    : sl;
      tabFoldLo   : slv(31 downto 0);
      tabFoldHi   : slv(31 downto 0);
      tabCtrl     : CtrlType;
      -- Stage 4, reduceCrc (CrcAxiStream.bsv:140).
      redValid    : sl;
      curCrc      : slv(31 downto 0);
      redCtrl     : CtrlType;
      -- Stage 5, accuCrc (CrcAxiStream.bsv:153).
      running      : slv(31 downto 0);
      accuValid    : sl;
      accuCurCrc   : slv(31 downto 0);
      accuSnapshot : slv(31 downto 0);
      accuCtrl     : CtrlType;
      -- Stage 6, shiftInterCrc (CrcAxiStream.bsv:196).
      interValid  : sl;
      interData   : slv(INTER_WIDTH_C - 1 downto 0);
      interCurCrc : slv(31 downto 0);
      -- Stage 7, readInterCrcTab plus the lower fold levels (CrcAxiStream.bsv:216).
      finValid    : sl;
      finFoldLo   : slv(31 downto 0);
      finFoldHi   : slv(31 downto 0);
      finCurCrc   : slv(31 downto 0);
      -- Stage 8, reduceFinalCrc (CrcAxiStream.bsv:232): the output holding
      -- register.
      outValid    : sl;
      outData     : slv(31 downto 0);
   end record RegType;

   constant REG_INIT_C : RegType := (
      preValid     => '0',
      preData      => (others => '0'),
      preCtrl      => CTRL_INIT_C,
      -- Reg#(Bool) isFirstFlag <- mkReg(True): the first beat after reset
      -- is always treated as the first beat of a packet.
      isFirstFlag  => '1',
      shiftValid   => '0',
      shiftData    => (others => '0'),
      shiftCtrl    => CTRL_INIT_C,
      tabValid     => '0',
      tabFoldLo    => (others => '0'),
      tabFoldHi    => (others => '0'),
      tabCtrl      => CTRL_INIT_C,
      redValid     => '0',
      curCrc       => (others => '0'),
      redCtrl      => CTRL_INIT_C,
      running      => CRC32_INIT_C,
      accuValid    => '0',
      accuCurCrc   => (others => '0'),
      accuSnapshot => (others => '0'),
      accuCtrl     => CTRL_INIT_C,
      interValid   => '0',
      interData    => (others => '0'),
      interCurCrc  => (others => '0'),
      finValid     => '0',
      finFoldLo    => (others => '0'),
      finFoldHi    => (others => '0'),
      finCurCrc    => (others => '0'),
      outValid     => '0',
      outData      => (others => '0'));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   comb : process (r, s_axis_tvalid, s_axis_tdata, s_axis_tkeep, s_axis_tlast, m_crc_stream_ready, RST_N) is
      variable v             : RegType;
      variable stall         : boolean;
      variable accuBase      : natural;
      variable interShiftAmt : natural;
      variable interWide     : slv(INTER_WIDTH_C - 1 downto 0);
   begin
      -- Latch the current value
      v := r;

      -- The whole pipeline stalls as a unit: the output holding register
      -- is the only buffering this engine has, so when it is occupied and
      -- the downstream consumer is not ready, every stage holds and no new
      -- beat is accepted. This is the simplest scheme that cannot drop or
      -- duplicate a word; exact ready timing is deliberately not compared
      -- elsewhere in this phase.
      stall := (r.outValid = '1') and (m_crc_stream_ready = '0');

      if not stall then

         -- Stage 1, preProcess (CrcAxiStream.bsv:82). isFirstFlag advances
         -- on every accepted beat; a beat is only captured into the
         -- pipeline when s_axis_tvalid is asserted this cycle.
         v.preValid := s_axis_tvalid;
         if s_axis_tvalid = '1' then
            v.preData := icrcReverseEachByte(icrcSwapEndian(s_axis_tdata and icrcExpandKeep(s_axis_tkeep)));
            v.preCtrl := (
               isFirst  => r.isFirstFlag,
               isLast   => s_axis_tlast,
               shiftAmt => icrcTrailingInvalidBytes(s_axis_tkeep));
            v.isFirstFlag := s_axis_tlast;
         end if;

         -- Stage 2, shiftInput (CrcAxiStream.bsv:112).
         v.shiftValid := r.preValid;
         v.shiftData  := icrcByteRightShift(r.preData, r.preCtrl.shiftAmt);
         v.shiftCtrl  := r.preCtrl;

         -- Stage 3, readCrcTab plus the lower fold levels
         -- (CrcAxiStream.bsv:122). SEND_MODE_G selects the data-byte table
         -- base, the first of the three Send-versus-Recv offset
         -- differences (CrcAxiStream.bsv:128).
         v.tabValid := r.shiftValid;
         if SEND_MODE_G then
            v.tabFoldLo := icrcTableFold(r.shiftData, SEND_TAB_OFFSET_C, 0, 15);
            v.tabFoldHi := icrcTableFold(r.shiftData, SEND_TAB_OFFSET_C, 16, 31);
         else
            v.tabFoldLo := icrcTableFold(r.shiftData, RECV_TAB_OFFSET_C, 0, 15);
            v.tabFoldHi := icrcTableFold(r.shiftData, RECV_TAB_OFFSET_C, 16, 31);
         end if;
         v.tabCtrl := r.shiftCtrl;

         -- Stage 4, reduceCrc (CrcAxiStream.bsv:140).
         v.redValid := r.tabValid;
         v.curCrc   := r.tabFoldLo xor r.tabFoldHi;
         v.redCtrl  := r.tabCtrl;

         -- Stage 5, accuCrc (CrcAxiStream.bsv:153). The value forwarded to
         -- stage 6 on the last beat is the running register's pre-update
         -- value (interCrcRes in the BSV), not the post-update next value:
         -- forwarding the post-update value instead is a silent error that
         -- passes elaboration and produces a wrong word for every packet.
         -- The running-value table base is the second offset difference
         -- (CrcAxiStream.bsv:160-175).
         v.accuValid := '0';
         if r.redValid = '1' then
            if (not SEND_MODE_G) and (r.redCtrl.isFirst = '1') then
               accuBase := RECV_INIT_TAB_OFFSET_C;
            else
               accuBase := ACCU_TAB_OFFSET_C;
            end if;
            if r.redCtrl.isLast = '1' then
               v.accuValid    := '1';
               v.accuCurCrc   := r.curCrc;
               v.accuSnapshot := r.running;
               v.accuCtrl     := r.redCtrl;
               v.running      := CRC32_INIT_C;
            else
               v.running := icrcTableFold(r.running, accuBase, 0, CRC_BYTE_NUM_C - 1) xor r.curCrc;
            end if;
         end if;

         -- Stage 6, shiftInterCrc (CrcAxiStream.bsv:196). Fires only on a
         -- beat stage 5 forwarded. The Recv-only single-beat +crcByteNum
         -- addition is the third and last offset difference
         -- (CrcAxiStream.bsv:202-206), and it fires only when a packet is
         -- exactly one beat long.
         v.interValid := r.accuValid;
         if r.accuValid = '1' then
            interWide                                              := (others => '0');
            interWide(INTER_WIDTH_C - 1 downto INTER_WIDTH_C - 32) := r.accuSnapshot;
            interShiftAmt := r.accuCtrl.shiftAmt;
            if (not SEND_MODE_G) and (r.accuCtrl.isFirst = '1') and (r.accuCtrl.isLast = '1') then
               interShiftAmt := interShiftAmt + CRC_BYTE_NUM_C;
            end if;
            v.interData   := icrcByteRightShift(interWide, interShiftAmt);
            v.interCurCrc := r.accuCurCrc;
         end if;

         -- Stage 7, readInterCrcTab plus the lower fold levels
         -- (CrcAxiStream.bsv:216). No offset in either mode.
         v.finValid := r.interValid;
         if r.interValid = '1' then
            v.finFoldLo := icrcTableFold(r.interData, 0, 0, 17);
            v.finFoldHi := icrcTableFold(r.interData, 0, 18, 35);
            v.finCurCrc := r.interCurCrc;
         end if;

         -- Stage 8, reduceFinalCrc (CrcAxiStream.bsv:232): the output
         -- holding register.
         v.outValid := r.finValid;
         if r.finValid = '1' then
            v.outData := icrcFinalize(r.finFoldLo xor r.finFoldHi xor r.finCurCrc);
         end if;

      end if;

      -- Outputs
      if stall then
         s_axis_tready <= '0';
      else
         s_axis_tready <= '1';
      end if;
      m_crc_stream_data  <= r.outData;
      m_crc_stream_valid <= r.outValid;

      -- Reset (synchronous, active low)
      if RST_N = '0' then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

   end process comb;

   seq : process (CLK) is
   begin
      if rising_edge(CLK) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end architecture rtl;
