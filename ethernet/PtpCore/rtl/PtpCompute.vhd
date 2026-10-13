-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Prototype shared word-addressed PTP measurement arithmetic.
--
-- Four independently owned contexts share one 128 x 32 RAM, one 32-bit
-- carry/borrow ALU and one 32 x 32 partial-product multiplier. No full-width
-- operand/result registers or buses are retained. This is not yet instantiated
-- by PtpEndpoint; the production clients remain the behavioral reference.
--
-- Each context owns 16 little-endian words: A[0:3], B[4:7], result[8:11],
-- remainder[12:15]. Write all eight operand words before submitting a job.
-- Operations 0/1/2/3 are signed 128-bit add/subtract/multiply/divide. Overflow
-- sets resultError and retains the wrapped low 128 bits. Division can round
-- nearest, ties away; remainder always describes truncation toward zero.
-- Divide by zero returns zero result/remainder with error.
--
-- One queued or completed job per context. Completed words remain immutable
-- until resultReady releases that context. Tags accompany registered result
-- valid. Word reads are permitted only for completed results and have one held
-- response slot. Result acknowledgement releases unread words; an already
-- accepted read still completes and prevents context reuse until acknowledged.
-- A held response/result for one context does not block other contexts.
--
-- Memory transfers and nonpreemptive jobs alternate when both are waiting;
-- queued jobs use round-robin selection. Client adapters must preserve original
-- capture time, generation and cancellation ownership. Cancel/reset win over
-- all transfers on that edge. RAM is not cleared; ownership is invalidated.
-- RAM controls are registered, with an explicit wait before read consumption.
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

entity PtpCompute is
   generic (
      TPD_G         : time   := 1 ns;
      MEMORY_TYPE_G : string := "block");
   port (
      clk           : in  sl;
      rst           : in  sl;
      cancel        : in  slv(3 downto 0);
      memValid      : in  sl;
      memReady      : out sl;
      memWrite      : in  sl;
      memClient     : in  slv(1 downto 0);
      memWord       : in  slv(3 downto 0);
      memData       : in  slv(31 downto 0);
      readValid     : out sl;
      readReady     : in  sl;
      readData      : out slv(31 downto 0);
      readClient    : out slv(1 downto 0);
      readWord      : out slv(3 downto 0);
      jobValid      : in  sl;
      jobReady      : out sl;
      jobClient     : in  slv(1 downto 0);
      jobOperation  : in  slv(1 downto 0);
      jobRound      : in  sl;
      jobTag        : in  slv(31 downto 0);
      resultValid   : out slv(3 downto 0);
      resultReady   : in  slv(3 downto 0);
      resultError   : out slv(3 downto 0);
      resultTag     : out slv(127 downto 0));
end entity PtpCompute;

architecture rtl of PtpCompute is

   constant ADD_C : slv(1 downto 0) := "00";
   constant SUB_C : slv(1 downto 0) := "01";
   constant MUL_C : slv(1 downto 0) := "10";
   constant DIV_C : slv(1 downto 0) := "11";

   -- Shared scratch is inaccessible through the context word interface.
   constant MAG_A_C   : natural := 64;
   constant MAG_B_C   : natural := 68;
   constant PRODUCT_C : natural := 72;  -- Eight words; quotient uses low four.
   constant REM_C     : natural := 80;  -- Five words retain the 129th trial bit.
   constant TRIAL_C   : natural := 85;

   type StateType is (
      IDLE_S, READ_WAIT_S, HOST_READ_S,
      ADD_A_S, ADD_B_S, ADD_STORE_S,
      SIGN_A_S, SIGN_B_S, NORMAL_A_S, NORMAL_WRITE_A_S,
      NORMAL_B_S, NORMAL_WRITE_B_S, CLEAR_S, ZERO_RESULT_S,
      MUL_A_S, MUL_B_S, MUL_ACC_S, MUL_CARRY_S, MUL_LOW_S, MUL_HIGH_S,
      MUL_CHECK_S,
      DIV_LOAD_A_S, DIV_REM_S, DIV_B_S, DIV_SUB_S, DIV_COPY_S,
      DIV_BIT_DONE_S, ROUND_READ_S, ROUND_WRITE_S,
      RESTORE_START_S, RESTORE_READ_S, RESTORE_WRITE_S, FINISH_S);

   type OperationArray is array (0 to 3) of slv(1 downto 0);

   type RegType is record
      -- Reverse ready controls are combinational: admission must honor the
      -- current cancel/reset and cannot reserve an extra delayed-ready slot.
      memReady     : sl;
      jobReady     : sl;
      state        : StateType;
      returnState  : StateType;
      pending      : slv(3 downto 0);
      completed    : slv(3 downto 0);
      errors       : slv(3 downto 0);
      loaded       : slv(31 downto 0);
      operations   : OperationArray;
      rounding     : slv(3 downto 0);
      tags         : slv(127 downto 0);
      cursor       : natural range 0 to 3;
      client       : natural range 0 to 3;
      active       : sl;
      memTurn      : sl;
      readValid    : sl;
      readData     : slv(31 downto 0);
      readClient   : slv(1 downto 0);
      readWord     : slv(3 downto 0);
      readPending  : sl;
      ramRead      : sl;
      ramReadAddr  : slv(6 downto 0);
      ramWrite     : sl;
      ramWriteAddr : slv(6 downto 0);
      ramWriteData : slv(31 downto 0);
      operation    : slv(1 downto 0);
      roundNearest : sl;
      negativeA    : sl;
      negativeB    : sl;
      negative     : sl;
      error        : sl;
      nonzeroB     : sl;
      nonzeroLow   : sl;
      wordIndex    : natural range 0 to 7;
      clearIndex   : natural range 0 to 12;
      rowIndex     : natural range 0 to 3;
      columnIndex  : natural range 0 to 3;
      bitWord      : natural range 0 to 3;
      bitIndex     : natural range 0 to 31;
      dividendWord : slv(31 downto 0);
      quotientWord : slv(31 downto 0);
      shiftCarry   : sl;
      roundTest    : sl;
      remainderOut : sl;
      wordA        : unsigned(31 downto 0);
      product      : unsigned(63 downto 0);
      carryWord    : unsigned(31 downto 0);
      productCarry : sl;
      aluA         : unsigned(31 downto 0);
      aluB         : unsigned(31 downto 0);
      carry        : sl;
   end record;

   constant REG_INIT_C : RegType := (
      memReady     => '0',
      jobReady     => '0',
      state        => IDLE_S,
      returnState  => IDLE_S,
      pending      => (others => '0'),
      completed    => (others => '0'),
      errors       => (others => '0'),
      loaded       => (others => '0'),
      operations   => (others => ADD_C),
      rounding     => (others => '0'),
      tags         => (others => '0'),
      cursor       => 0,
      client       => 0,
      active       => '0',
      memTurn      => '1',
      readValid    => '0',
      readData     => (others => '0'),
      readClient   => (others => '0'),
      readWord     => (others => '0'),
      readPending  => '0',
      ramRead      => '0',
      ramReadAddr  => (others => '0'),
      ramWrite     => '0',
      ramWriteAddr => (others => '0'),
      ramWriteData => (others => '0'),
      operation    => ADD_C,
      roundNearest => '0',
      negativeA    => '0',
      negativeB    => '0',
      negative     => '0',
      error        => '0',
      nonzeroB     => '0',
      nonzeroLow   => '0',
      wordIndex    => 0,
      clearIndex   => 0,
      rowIndex     => 0,
      columnIndex  => 0,
      bitWord      => 3,
      bitIndex     => 31,
      dividendWord => (others => '0'),
      quotientWord => (others => '0'),
      shiftCarry   => '0',
      roundTest    => '0',
      remainderOut => '0',
      wordA        => (others => '0'),
      product      => (others => '0'),
      carryWord    => (others => '0'),
      productCarry => '0',
      aluA         => (others => '0'),
      aluB         => (others => '0'),
      carry        => '0');

   signal r        : RegType := REG_INIT_C;
   signal rin      : RegType;
   signal ramData  : slv(31 downto 0);
   signal ramWrite : sl;
   signal ramRead  : sl;

   procedure readRam (
      variable v       : inout RegType;
      constant address : in    natural;
      constant target  : in    StateType) is
   begin
      v.ramRead     := '1';
      v.ramReadAddr := std_logic_vector(to_unsigned(address, 7));
      v.returnState := target;
      v.state       := READ_WAIT_S;
   end procedure readRam;

   procedure writeRam (
      variable v       : inout RegType;
      constant address : in    natural;
      constant data    : in    unsigned(31 downto 0)) is
   begin
      v.ramWrite     := '1';
      v.ramWriteAddr := std_logic_vector(to_unsigned(address, 7));
      v.ramWriteData := std_logic_vector(data);
   end procedure writeRam;

begin

   -- Reset suppresses registered port strobes. Cancellation invalidates the
   -- owning context; any already-issued write finishes before slot reuse.
   ramWrite <= r.ramWrite and not rst;
   ramRead  <= r.ramRead and not rst;

   U_WorkRam : entity surf.SimpleDualPortRam
      generic map (
         TPD_G          => TPD_G,
         MEMORY_TYPE_G  => MEMORY_TYPE_G,
         COMMON_CLK_G   => true,
         DATA_WIDTH_G   => 32,
         BYTE_WR_EN_G   => false,
         BYTE_WIDTH_G   => 32,
         ADDR_WIDTH_G   => 7,
         DOB_REG_G      => false,
         READ_LATENCY_G => 1)
      port map (
         clka  => clk,
         ena   => ramWrite,
         wea   => ramWrite,
         addra => r.ramWriteAddr,
         dina  => r.ramWriteData,
         clkb  => clk,
         enb   => ramRead,
         rstb  => rst,
         addrb => r.ramReadAddr,
         doutb => ramData);

   comb : process (r, rst, cancel, memValid, memWrite, memClient, memWord, memData,
                   readReady, jobValid, jobClient, jobOperation, jobRound, jobTag,
                   resultReady, ramData) is
      variable v           : RegType;
      variable alu         : unsigned(32 downto 0);
      variable carryIn     : unsigned(32 downto 0);
      variable memorySlot  : natural range 0 to 3;
      variable commandSlot : natural range 0 to 3;
      variable address     : natural range 0 to 15;
      variable selected    : integer range -1 to 3;
      variable candidate   : natural range 0 to 3;
      variable memoryOk    : boolean;
      variable data        : unsigned(31 downto 0);
   begin
      v := r;
      v.memReady := '0';
      v.jobReady := '0';
      v.ramRead  := '0';
      v.ramWrite := '0';
      memorySlot := to_integer(unsigned(memClient));
      commandSlot := to_integer(unsigned(jobClient));
      address := to_integer(unsigned(memWord));
      data := unsigned(ramData);

      -- The only data add/subtract site. Subtraction supplies complemented B
      -- and carry=1; carry out is the inverse borrow for the next word.
      carryIn := (others => '0');
      carryIn(0) := r.carry;
      alu := ('0' & r.aluA) + ('0' & r.aluB) + carryIn;

      if r.readValid = '1' and readReady = '1' then
         v.readValid := '0';
      end if;

      for i in 0 to 3 loop
         if r.completed(i) = '1' and resultReady(i) = '1' then
            v.completed(i) := '0';
            v.loaded(8*i+7 downto 8*i) := (others => '0');
         end if;
      end loop;

      -- Metadata can queue while another context computes. Operand memory is
      -- immutable from admission until explicit release/cancellation.
      if r.pending(commandSlot) = '0' and r.completed(commandSlot) = '0' and
         not (r.active = '1' and r.client = commandSlot) and
         r.loaded(8*commandSlot+7 downto 8*commandSlot) = x"FF" and
         not (memValid = '1' and memorySlot = commandSlot) and
         cancel(commandSlot) = '0' then
         v.jobReady := '1';
      end if;

      if jobValid = '1' and v.jobReady = '1' then
         v.pending(commandSlot) := '1';
         v.operations(commandSlot) := jobOperation;
         v.rounding(commandSlot) := jobRound;
         v.tags(32*commandSlot+31 downto 32*commandSlot) := jobTag;
      end if;

      case r.state is
         when IDLE_S =>
            selected := -1;

            for i in 0 to 3 loop
               candidate := (r.cursor+i) mod 4;

               if selected = -1 and r.pending(candidate) = '1' and cancel(candidate) = '0' then
                  selected := candidate;
               end if;
            end loop;

            memoryOk := false;

            if memWrite = '1' then
               memoryOk := address < 8 and r.pending(memorySlot) = '0' and
                           r.completed(memorySlot) = '0' and
                           not ((r.readPending = '1' or r.readValid = '1') and
                                to_integer(unsigned(r.readClient)) = memorySlot);
            else
               memoryOk := address >= 8 and r.completed(memorySlot) = '1' and
                           resultReady(memorySlot) = '0' and r.readValid = '0';
            end if;

            if memoryOk and cancel(memorySlot) = '0' and
               (selected = -1 or r.memTurn = '1') then
               v.memReady := '1';
            end if;

            if memValid = '1' and v.memReady = '1' then
               v.memTurn := '0';

               if memWrite = '1' then
                  writeRam(v, 16*memorySlot+address, unsigned(memData));
                  v.loaded(8*memorySlot+address) := '1';
               else
                  v.readClient := memClient;
                  v.readWord := memWord;
                  v.readPending := '1';
                  readRam(v, 16*memorySlot+address, HOST_READ_S);
               end if;
            elsif selected /= -1 then
               v.client := selected;
               v.cursor := (selected+1) mod 4;
               v.active := '1';
               v.pending(selected) := '0';
               v.operation := r.operations(selected);
               v.roundNearest := r.rounding(selected);
               v.error := '0';
               v.nonzeroB := '0';
               v.wordIndex := 0;
               v.carry := '0';
               v.memTurn := '1';

               if r.operations(selected) = ADD_C or r.operations(selected) = SUB_C then
                  if r.operations(selected) = SUB_C then
                     v.carry := '1';
                  end if;

                  readRam(v, 16*selected, ADD_A_S);
               else
                  readRam(v, 16*selected+3, SIGN_A_S);
               end if;
            end if;

         when READ_WAIT_S =>
            -- Registered read enable is sampled now. ramData settles before
            -- the return state consumes it at the following edge.
            v.state := r.returnState;

         when HOST_READ_S =>
            v.readData := ramData;
            v.readValid := '1';
            v.readPending := '0';
            v.state := IDLE_S;

         when ADD_A_S =>
            v.aluA := data;
            v.negativeA := data(31);
            readRam(v, 16*r.client+4+r.wordIndex, ADD_B_S);

         when ADD_B_S =>
            v.aluB := data;

            if r.operation = SUB_C then
               v.aluB := not data;
            end if;

            v.negativeB := data(31);
            v.state := ADD_STORE_S;

         when ADD_STORE_S =>
            writeRam(v, 16*r.client+8+r.wordIndex, alu(31 downto 0));
            v.carry := alu(32);

            if r.wordIndex = 3 then
               if ((r.operation = ADD_C and r.negativeA = r.negativeB) or
                   (r.operation = SUB_C and r.negativeA /= r.negativeB)) and
                  alu(31) /= r.negativeA then
                  v.error := '1';
               end if;

               v.clearIndex := 4;
               v.state := ZERO_RESULT_S;
            else
               v.wordIndex := r.wordIndex+1;
               readRam(v, 16*r.client+r.wordIndex+1, ADD_A_S);
            end if;

         when SIGN_A_S =>
            v.negativeA := data(31);
            readRam(v, 16*r.client+7, SIGN_B_S);

         when SIGN_B_S =>
            v.negativeB := data(31);
            v.negative := r.negativeA xor data(31);
            v.carry := r.negativeA;
            readRam(v, 16*r.client, NORMAL_A_S);

         when NORMAL_A_S =>
            v.aluA := data;

            if r.negativeA = '1' then
               v.aluA := not data;
            end if;

            v.aluB := (others => '0');
            v.state := NORMAL_WRITE_A_S;

         when NORMAL_WRITE_A_S =>
            writeRam(v, MAG_A_C+r.wordIndex, alu(31 downto 0));
            v.carry := alu(32);

            if r.wordIndex = 3 then
               v.wordIndex := 0;
               v.carry := r.negativeB;
               readRam(v, 16*r.client+4, NORMAL_B_S);
            else
               v.wordIndex := r.wordIndex+1;
               readRam(v, 16*r.client+r.wordIndex+1, NORMAL_A_S);
            end if;

         when NORMAL_B_S =>
            v.aluA := data;

            if r.negativeB = '1' then
               v.aluA := not data;
            end if;

            v.aluB := (others => '0');
            v.state := NORMAL_WRITE_B_S;

         when NORMAL_WRITE_B_S =>
            writeRam(v, MAG_B_C+r.wordIndex, alu(31 downto 0));
            v.carry := alu(32);

            if alu(31 downto 0) /= 0 then
               v.nonzeroB := '1';
            end if;

            if r.wordIndex = 3 then
               v.clearIndex := 0;
               v.state := CLEAR_S;

               if r.operation = DIV_C and v.nonzeroB = '0' then
                  v.error := '1';
                  v.state := ZERO_RESULT_S;
               end if;
            else
               v.wordIndex := r.wordIndex+1;
               readRam(v, 16*r.client+5+r.wordIndex, NORMAL_B_S);
            end if;

         when ZERO_RESULT_S =>
            writeRam(v, 16*r.client+8+r.clearIndex, to_unsigned(0, 32));

            if r.clearIndex = 7 then
               v.state := FINISH_S;
            else
               v.clearIndex := r.clearIndex+1;
            end if;

         when CLEAR_S =>
            -- Scratch product and remainder; no RAM-wide reset/mux tree.
            writeRam(v, PRODUCT_C+r.clearIndex, to_unsigned(0, 32));

            if r.clearIndex = 12 then
               v.rowIndex := 0;
               v.columnIndex := 0;
               v.carryWord := (others => '0');
               v.bitWord := 3;
               v.bitIndex := 31;
               v.roundTest := '0';
               v.quotientWord := (others => '0');

               if r.operation = MUL_C then
                  readRam(v, MAG_A_C, MUL_A_S);
               else
                  readRam(v, MAG_A_C+3, DIV_LOAD_A_S);
               end if;
            else
               v.clearIndex := r.clearIndex+1;
            end if;

         when MUL_A_S =>
            v.wordA := data;
            readRam(v, MAG_B_C, MUL_B_S);

         when MUL_B_S =>
            -- One selected partial product, rather than a 128-bit multiplier.
            v.product := r.wordA*data;
            readRam(v, PRODUCT_C+r.rowIndex+r.columnIndex, MUL_ACC_S);

         when MUL_ACC_S =>
            v.aluA := r.product(31 downto 0);
            v.aluB := data;
            v.carry := '0';
            v.state := MUL_CARRY_S;

         when MUL_CARRY_S =>
            v.productCarry := alu(32);
            v.aluA := alu(31 downto 0);
            v.aluB := r.carryWord;
            v.state := MUL_LOW_S;

         when MUL_LOW_S =>
            writeRam(v, PRODUCT_C+r.rowIndex+r.columnIndex, alu(31 downto 0));
            v.aluA := r.product(63 downto 32);
            v.aluB := (others => '0');
            v.aluB(1) := r.productCarry and alu(32);
            v.aluB(0) := r.productCarry xor alu(32);
            v.state := MUL_HIGH_S;

         when MUL_HIGH_S =>
            v.carryWord := alu(31 downto 0);

            if r.columnIndex /= 3 then
               v.columnIndex := r.columnIndex+1;
               readRam(v, MAG_B_C+r.columnIndex+1, MUL_B_S);
            else
               writeRam(v, PRODUCT_C+r.rowIndex+4, alu(31 downto 0));

               if r.rowIndex /= 3 then
                  v.rowIndex := r.rowIndex+1;
                  v.columnIndex := 0;
                  v.carryWord := (others => '0');
                  readRam(v, MAG_A_C+r.rowIndex+1, MUL_A_S);
               else
                  v.wordIndex := 4;
                  readRam(v, PRODUCT_C+4, MUL_CHECK_S);
               end if;
            end if;

         when MUL_CHECK_S =>
            if data /= 0 then
               v.error := '1';
            end if;

            if r.wordIndex = 7 then
               v.state := RESTORE_START_S;
            else
               v.wordIndex := r.wordIndex+1;
               readRam(v, PRODUCT_C+r.wordIndex+1, MUL_CHECK_S);
            end if;

         when DIV_LOAD_A_S =>
            v.dividendWord := ramData;
            v.shiftCarry := data(31);
            v.bitIndex := 31;
            v.wordIndex := 0;
            v.carry := '1';
            readRam(v, REM_C, DIV_REM_S);

         when DIV_REM_S =>
            v.wordA := data(30 downto 0) & r.shiftCarry;
            v.shiftCarry := data(31);

            if r.wordIndex < 4 then
               readRam(v, MAG_B_C+r.wordIndex, DIV_B_S);
            else
               v.aluA := v.wordA;
               v.aluB := (others => '1');
               v.state := DIV_SUB_S;
            end if;

            -- Retain the shifted remainder even when trial subtraction fails.
            -- The final rounding comparison must leave the original remainder.
            if r.roundTest = '0' then
               writeRam(v, REM_C+r.wordIndex, v.wordA);
            end if;

         when DIV_B_S =>
            v.aluA := r.wordA;
            v.aluB := not data;
            v.state := DIV_SUB_S;

         when DIV_SUB_S =>
            writeRam(v, TRIAL_C+r.wordIndex, alu(31 downto 0));
            v.carry := alu(32);

            if r.wordIndex < 4 then
               v.wordIndex := r.wordIndex+1;
               readRam(v, REM_C+r.wordIndex+1, DIV_REM_S);
            elsif r.roundTest = '1' then
               if alu(32) = '1' then
                  v.wordIndex := 0;
                  v.carry := '1';
                  readRam(v, PRODUCT_C, ROUND_READ_S);
               else
                  v.state := RESTORE_START_S;
               end if;
            else
               v.quotientWord := r.quotientWord(30 downto 0) & alu(32);

               if alu(32) = '1' then
                  v.wordIndex := 0;
                  readRam(v, TRIAL_C, DIV_COPY_S);
               else
                  v.state := DIV_BIT_DONE_S;
               end if;
            end if;

         when DIV_COPY_S =>
            writeRam(v, REM_C+r.wordIndex, data);

            if r.wordIndex = 4 then
               v.state := DIV_BIT_DONE_S;
            else
               v.wordIndex := r.wordIndex+1;
               readRam(v, TRIAL_C+r.wordIndex+1, DIV_COPY_S);
            end if;

         when DIV_BIT_DONE_S =>
            v.wordIndex := 0;
            v.carry := '1';

            if r.bitIndex /= 0 then
               v.bitIndex := r.bitIndex-1;
               v.shiftCarry := r.dividendWord(r.bitIndex-1);
               readRam(v, REM_C, DIV_REM_S);
            else
               writeRam(v, PRODUCT_C+r.bitWord, unsigned(r.quotientWord));
               v.quotientWord := (others => '0');

               if r.bitWord /= 0 then
                  v.bitWord := r.bitWord-1;
                  readRam(v, MAG_A_C+r.bitWord-1, DIV_LOAD_A_S);
               elsif r.roundNearest = '1' then
                  v.roundTest := '1';
                  v.shiftCarry := '0';
                  readRam(v, REM_C, DIV_REM_S);
               else
                  v.state := RESTORE_START_S;
               end if;
            end if;

         when ROUND_READ_S =>
            v.aluA := data;
            v.aluB := (others => '0');
            v.state := ROUND_WRITE_S;

         when ROUND_WRITE_S =>
            writeRam(v, PRODUCT_C+r.wordIndex, alu(31 downto 0));
            v.carry := alu(32);

            if r.wordIndex = 3 then
               v.state := RESTORE_START_S;
            else
               v.wordIndex := r.wordIndex+1;
               readRam(v, PRODUCT_C+r.wordIndex+1, ROUND_READ_S);
            end if;

         when RESTORE_START_S =>
            v.wordIndex := 0;
            v.nonzeroLow := '0';
            v.remainderOut := '0';
            v.carry := r.negative;
            readRam(v, PRODUCT_C, RESTORE_READ_S);

         when RESTORE_READ_S =>
            v.aluA := data;
            v.aluB := (others => '0');

            if (r.remainderOut = '0' and r.negative = '1') or
               (r.remainderOut = '1' and r.negativeA = '1') then
               v.aluA := not data;
            end if;

            if r.remainderOut = '0' then
               if r.wordIndex = 3 then
                  if data(31) = '1' and
                     (r.negative = '0' or data(30 downto 0) /= 0 or r.nonzeroLow = '1') then
                     v.error := '1';
                  end if;
               elsif data /= 0 then
                  v.nonzeroLow := '1';
               end if;
            end if;

            v.state := RESTORE_WRITE_S;

         when RESTORE_WRITE_S =>
            if r.remainderOut = '0' then
               writeRam(v, 16*r.client+8+r.wordIndex, alu(31 downto 0));
            else
               writeRam(v, 16*r.client+12+r.wordIndex, alu(31 downto 0));
            end if;

            v.carry := alu(32);

            if r.wordIndex = 3 then
               if r.remainderOut = '0' then
                  v.remainderOut := '1';
                  v.wordIndex := 0;
                  v.carry := r.negativeA;
                  readRam(v, REM_C, RESTORE_READ_S);
               else
                  v.state := FINISH_S;
               end if;
            else
               v.wordIndex := r.wordIndex+1;

               if r.remainderOut = '0' then
                  readRam(v, PRODUCT_C+r.wordIndex+1, RESTORE_READ_S);
               else
                  readRam(v, REM_C+r.wordIndex+1, RESTORE_READ_S);
               end if;
            end if;

         when FINISH_S =>
            -- The final registered write commits on the same edge as valid.
            v.completed(r.client) := '1';
            v.errors(r.client) := r.error;
            v.active := '0';
            v.state := IDLE_S;
      end case;

      for i in 0 to 3 loop
         if cancel(i) = '1' then
            v.pending(i) := '0';
            v.completed(i) := '0';
            v.errors(i) := '0';
            v.loaded(8*i+7 downto 8*i) := (others => '0');

            if r.active = '1' and r.client = i then
               v.active := '0';
               v.state := IDLE_S;
               v.ramRead := '0';
               v.ramWrite := '0';
            end if;

            if to_integer(unsigned(r.readClient)) = i then
               v.readValid := '0';

               if r.readPending = '1' then
                  v.readPending := '0';
                  v.ramRead := '0';
                  v.state := IDLE_S;
               end if;
            end if;
         end if;
      end loop;

      if rst = '1' then
         v := REG_INIT_C;
      end if;

      rin <= v;
      memReady <= v.memReady;
      jobReady <= v.jobReady;
      readValid <= r.readValid;
      readData <= r.readData;
      readClient <= r.readClient;
      readWord <= r.readWord;
      resultValid <= r.completed;
      resultError <= r.errors;
      resultTag <= r.tags;
   end process comb;

   seq : process (clk) is
   begin
      if rising_edge(clk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end architecture rtl;
