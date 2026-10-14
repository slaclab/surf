-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Shared word-addressed PTP measurement arithmetic and workspaces.
--
-- Rate/E2E/servo retain 64 words each, PHC 16, across descriptor acknowledgement.
-- Addressed operations chain results without host copies. Full cancellation/reset
-- invalidate stored words. One queued/completed descriptor belongs to each owner;
-- a completed job releases the engine independently of consumer acknowledgement.
-- Four held read-response slots prevent a stalled reader blocking another owner.
--
-- The datapath uses a 32-bit carry/borrow ALU, one 32 x 32 partial product and
-- synchronous RAM scratch. Signed128 operations retain wrapped results and flag
-- overflow. Division and right shifts optionally round nearest, ties away;
-- division remainder describes truncation. Comparison reports signed less/equal
-- without depending on the sign of a potentially overflowing subtraction.
--
-- Descriptors queue independently. Round-robin jobs alternate with round-robin
-- word transfers at idle boundaries. Memory requests wait during nonpreemptive
-- arithmetic. Cancellation excludes transfers for its owner and drains any
-- already-issued write before reuse. RAM payload is never reset.
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
use surf.PtpComputePkg.all;

entity PtpCompute is
   generic (
      TPD_G          : time    := 1 ns;
      MEMORY_TYPE_G  : string  := "block";
      RST_POLARITY_G : sl      := '1';
      RST_ASYNC_G    : boolean := false);
   port (
      clk     : in  sl;
      rst     : in  sl;
      masters : in  PtpComputeMasterArray(0 to PTP_COMPUTE_OWNERS_C-1);
      slaves  : out PtpComputeSlaveArray(0 to PTP_COMPUTE_OWNERS_C-1));
end entity PtpCompute;

architecture rtl of PtpCompute is

   constant ADD_C : slv(2 downto 0) := PTP_COMPUTE_ADD_C;
   constant SUB_C : slv(2 downto 0) := PTP_COMPUTE_SUB_C;
   constant MUL_C : slv(2 downto 0) := PTP_COMPUTE_MUL_C;
   constant DIV_C : slv(2 downto 0) := PTP_COMPUTE_DIV_C;
   -- 208 persistent words followed by 26 inaccessible arithmetic scratch words.
   constant MAG_A_C   : natural := PTP_COMPUTE_PERSISTENT_WORDS_C;
   constant MAG_B_C   : natural := MAG_A_C+4;
   constant PRODUCT_C : natural := MAG_B_C+4;
   constant REM_C     : natural := PRODUCT_C+8;
   constant TRIAL_C   : natural := REM_C+5;
   constant ADDR_BITS_C : positive := bitSize(TRIAL_C+4);
   type StateType is (
      IDLE_S, READ_WAIT_S, HOST_READ_S, COPY_S, SHIFT_LOAD_S, SHIFT_START_S, SHIFT_WORD_S, ROUND_START_S,
      ADD_A_S, ADD_B_S, ADD_STORE_S,
      SIGN_A_S, SIGN_B_S, NORMAL_A_S, NORMAL_WRITE_A_S,
      NORMAL_B_S, NORMAL_WRITE_B_S, CLEAR_S, ZERO_RESULT_S,
      MUL_A_S, MUL_B_S, MUL_ACC_S, MUL_CARRY_S, MUL_LOW_S, MUL_HIGH_S,
      MUL_CHECK_S,
      DIV_LOAD_A_S, DIV_REM_S, DIV_B_S, DIV_SUB_S, DIV_COPY_S,
      DIV_BIT_DONE_S, ROUND_READ_S, ROUND_WRITE_S,
      RESTORE_START_S, RESTORE_READ_S, RESTORE_WRITE_S, FINISH_S);

   type LoadedArray is array (0 to 3) of slv(PTP_COMPUTE_WORDS_C-1 downto 0);
   type RegType is record
      -- Reverse ready controls are combinational: admission must honor the
      -- current cancel/reset and cannot reserve an extra delayed-ready slot.
      responses    : PtpComputeSlaveArray(0 to 3);
      state        : StateType;
      returnState  : StateType;
      pending      : slv(3 downto 0);
      loaded       : LoadedArray;
      jobs         : PtpComputeJobArray(0 to 3);
      cursor       : natural range 0 to 3;
      memoryCursor : natural range 0 to 3;
      client       : natural range 0 to 3;
      active       : sl;
      memTurn      : sl;
      readClient   : natural range 0 to 3;
      readPending  : sl;
      sourceA      : natural range 0 to MAG_A_C-4;
      sourceB      : natural range 0 to MAG_A_C-4;
      target       : natural range 0 to MAG_A_C-4;
      remainder    : natural range 0 to MAG_A_C-4;
      shifts       : natural range 0 to 127;
      less         : sl;
      equal        : sl;
      ramRead      : sl;
      ramReadAddr  : slv(ADDR_BITS_C-1 downto 0);
      ramWrite     : sl;
      ramWriteAddr : slv(ADDR_BITS_C-1 downto 0);
      ramWriteData : slv(31 downto 0);
      operation    : slv(2 downto 0);
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
      responses    => (others => PTP_COMPUTE_SLAVE_INIT_C),
      state        => IDLE_S,
      returnState  => IDLE_S,
      pending      => (others => '0'),
      loaded       => (others => (others => '0')),
      jobs         => (others => PTP_COMPUTE_JOB_INIT_C),
      cursor       => 0,
      memoryCursor => 0,
      client       => 0,
      active       => '0',
      memTurn      => '1',
      readClient   => 0,
      readPending  => '0',
      sourceA      => 0,
      sourceB      => 4,
      target       => 8,
      remainder    => 12,
      shifts       => 0,
      less         => '0',
      equal        => '1',
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
      v.ramReadAddr := std_logic_vector(to_unsigned(address, ADDR_BITS_C));
      v.returnState := target;
      v.state       := READ_WAIT_S;
   end procedure readRam;

   procedure writeRam (
      variable v       : inout RegType;
      constant address : in    natural;
      constant data    : in    unsigned(31 downto 0)) is
   begin
      v.ramWrite     := '1';
      v.ramWriteAddr := std_logic_vector(to_unsigned(address, ADDR_BITS_C));
      v.ramWriteData := std_logic_vector(data);
   end procedure writeRam;

begin

   -- Reset suppresses registered port strobes. Cancellation invalidates the
   -- owning context; any already-issued write finishes before slot reuse.
   ramWrite <= r.ramWrite;
   ramRead  <= r.ramRead;

   U_WorkRam : entity surf.SimpleDualPortRam
      generic map (
         TPD_G          => TPD_G,
         MEMORY_TYPE_G  => MEMORY_TYPE_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G,
         COMMON_CLK_G   => true,
         DATA_WIDTH_G   => 32,
         BYTE_WR_EN_G   => false,
         BYTE_WIDTH_G   => 32,
         ADDR_WIDTH_G   => ADDR_BITS_C,
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

   comb : process (r, rst, masters, ramData) is
      variable v              : RegType;
      variable alu            : unsigned(32 downto 0);
      variable carryIn        : unsigned(32 downto 0);
      variable address        : natural range 0 to PTP_COMPUTE_WORDS_C-1;
      variable selected       : integer range -1 to 3;
      variable memorySlot     : integer range -1 to 3;
      variable candidate      : natural range 0 to 3;
      variable aSlot          : natural range 0 to 15;
      variable bSlot          : natural range 0 to 15;
      variable memoryOk       : boolean;
      variable memoryEligible : BooleanArray(0 to 3);
      variable unary          : boolean;
      variable data           : unsigned(31 downto 0);
   begin
      v := r;
      v.ramRead  := '0';
      v.ramWrite := '0';
      data := unsigned(ramData);
      -- The only data add/subtract site. Subtraction supplies complemented B
      -- and carry=1; carry out is the inverse borrow for the next word.
      carryIn := (others => '0');
      carryIn(0) := r.carry;
      alu := ('0' & r.aluA) + ('0' & r.aluB) + carryIn;
      for i in 0 to 3 loop
         v.responses(i).memReady := '0';
         v.responses(i).jobReady := '0';

         if masters(i).readReady = '1' then
            v.responses(i).readValid := '0';
         end if;

         if masters(i).resultReady = '1' then
            v.responses(i).resultValid := '0';
         end if;

         aSlot := to_integer(unsigned(masters(i).job.sourceA));
         bSlot := to_integer(unsigned(masters(i).job.sourceB));
         unary := masters(i).job.operation = PTP_COMPUTE_COPY_C or
                  masters(i).job.operation = PTP_COMPUTE_SHL_C or
                  masters(i).job.operation = PTP_COMPUTE_SHR_C;
         -- Pending/active ownership freezes the whole local workspace. A held
         -- read prevents reuse even after its descriptor has been acknowledged.
         if r.pending(i) = '0' and r.responses(i).resultValid = '0' and
            not (r.active = '1' and r.client = i) and
            not (r.readPending = '1' and r.readClient = i) and
            r.responses(i).readValid = '0' and
            r.loaded(i)(4*aSlot+3 downto 4*aSlot) = x"F" and
            (unary or r.loaded(i)(4*bSlot+3 downto 4*bSlot) = x"F") and
            to_integer(unsigned(masters(i).job.target)) < PTP_COMPUTE_OWNER_WORDS_C(i)/4 and
            to_integer(unsigned(masters(i).job.remainder)) < PTP_COMPUTE_OWNER_WORDS_C(i)/4 and
            masters(i).job.target /= masters(i).job.remainder and
            masters(i).memValid = '0' and masters(i).cancel = '0' then
            v.responses(i).jobReady := '1';
         end if;

         if masters(i).jobValid = '1' and v.responses(i).jobReady = '1' then
            v.pending(i) := '1';
            v.jobs(i) := masters(i).job;
            v.responses(i).resultTag := masters(i).job.tag;
            -- In-place operands remain readable by the engine, but a canceled
            -- partial destination must never regain public validity. Loaded
            -- validity is not consulted during an admitted operation.
            aSlot := to_integer(unsigned(masters(i).job.target));
            bSlot := to_integer(unsigned(masters(i).job.remainder));
            v.loaded(i)(4*aSlot+3 downto 4*aSlot) := x"0";
            v.loaded(i)(4*bSlot+3 downto 4*bSlot) := x"0";
         end if;

      end loop;

      case r.state is
         when IDLE_S =>
            selected := -1;
            for i in 0 to 3 loop
               candidate := (r.cursor+i) mod 4;

               if selected = -1 and r.pending(candidate) = '1' and masters(candidate).cancel = '0' then
                  selected := candidate;
               end if;

            end loop;
            -- Qualify every owner at its own constant index, then choose among
            -- the four results by rotation. Reading r.loaded(i)(address) with a
            -- rotated candidate index would build a 64:1 select per owner over
            -- a dynamically chosen bank; a constant i leaves one select per
            -- owner against its own bank and lets unused words fold away.
            -- Round-robin order, single grant and cancel/reset priority are
            -- unchanged: only where the rotation is applied moves.
            for i in 0 to 3 loop
               address  := to_integer(unsigned(masters(i).memWord));
               memoryOk := address < PTP_COMPUTE_OWNER_WORDS_C(i) and r.pending(i) = '0' and
                           r.responses(i).readValid = '0';

               if masters(i).memWrite = '1' then
                  memoryOk := memoryOk and r.responses(i).resultValid = '0';
               else
                  memoryOk := memoryOk and r.loaded(i)(address) = '1';
               end if;

               memoryEligible(i) := memoryOk and masters(i).memValid = '1' and
                                    masters(i).cancel = '0';
            end loop;

            memorySlot := -1;
            for i in 0 to 3 loop
               candidate := (r.memoryCursor+i) mod 4;

               if memorySlot = -1 and memoryEligible(candidate) then
                  memorySlot := candidate;
               end if;

            end loop;

            if memorySlot /= -1 and (selected = -1 or r.memTurn = '1') then
               v.responses(memorySlot).memReady := '1';
               v.memoryCursor := (memorySlot+1) mod 4;
               v.memTurn := '0';
               address := to_integer(unsigned(masters(memorySlot).memWord));
               if masters(memorySlot).memWrite = '1' then
                  writeRam(v, PTP_COMPUTE_WORDS_C*memorySlot+address, unsigned(masters(memorySlot).memData));
                  v.loaded(memorySlot)(address) := '1';
               else
                  v.readClient := memorySlot;
                  v.responses(memorySlot).readWord := masters(memorySlot).memWord;
                  v.readPending := '1';
                  readRam(v, PTP_COMPUTE_WORDS_C*memorySlot+address, HOST_READ_S);
               end if;
            elsif selected /= -1 then
               v.client := selected;
               v.cursor := (selected+1) mod 4;
               v.active := '1';
               v.pending(selected) := '0';
               v.operation := r.jobs(selected).operation;
               v.roundNearest := r.jobs(selected).rounding;
               v.sourceA := PTP_COMPUTE_WORDS_C*selected+4*to_integer(unsigned(r.jobs(selected).sourceA));
               v.sourceB := PTP_COMPUTE_WORDS_C*selected+4*to_integer(unsigned(r.jobs(selected).sourceB));
               v.target := PTP_COMPUTE_WORDS_C*selected+4*to_integer(unsigned(r.jobs(selected).target));
               v.remainder := PTP_COMPUTE_WORDS_C*selected+4*to_integer(unsigned(r.jobs(selected).remainder));
               v.shifts := to_integer(unsigned(r.jobs(selected).shift));
               v.error := '0';
               v.equal := '1';
               v.less := '0';
               v.nonzeroB := '0';
               v.wordIndex := 0;
               v.carry := '0';
               v.memTurn := '1';
               if v.operation = ADD_C or v.operation = SUB_C or v.operation = PTP_COMPUTE_CMP_C then
                  if v.operation /= ADD_C then
                     v.carry := '1';
                  end if;
                  readRam(v, v.sourceA, ADD_A_S);
               elsif v.operation = PTP_COMPUTE_COPY_C then
                  readRam(v, v.sourceA, COPY_S);
               else
                  readRam(v, v.sourceA+3, SIGN_A_S);
               end if;
            end if;

         when READ_WAIT_S =>
            -- Registered read enable is sampled now. ramData settles before
            -- the return state consumes it at the following edge.
            v.state := r.returnState;
         when HOST_READ_S =>
            v.responses(r.readClient).readData := ramData;
            v.responses(r.readClient).readValid := '1';
            v.readPending := '0';
            v.state := IDLE_S;
         when COPY_S =>
            writeRam(v, r.target+r.wordIndex, data);

            if r.wordIndex = 3 then
               v.clearIndex := 4;
               v.state := ZERO_RESULT_S;
            else
               v.wordIndex := r.wordIndex+1;
               readRam(v, r.sourceA+r.wordIndex+1, COPY_S);
            end if;

         when SHIFT_LOAD_S =>
            writeRam(v, PRODUCT_C+r.wordIndex, data);

            if r.wordIndex /= 3 then
               v.wordIndex := r.wordIndex+1;
               readRam(v, MAG_A_C+r.wordIndex+1, SHIFT_LOAD_S);
            elsif r.shifts = 0 then
               v.state := RESTORE_START_S;
            else
               v.shiftCarry := '0';
               v.wordIndex := 0;
               if r.operation = PTP_COMPUTE_SHR_C then
                  v.wordIndex := 3;
               end if;
               v.state := SHIFT_START_S;
            end if;

         when SHIFT_START_S =>
            -- Drain the final copy write before reading the same address.
            readRam(v, PRODUCT_C+r.wordIndex, SHIFT_WORD_S);
         when ROUND_START_S =>
            -- Right shift finishes by writing word zero; avoid a collision.
            readRam(v, PRODUCT_C, ROUND_READ_S);
         when SHIFT_WORD_S =>

            if r.operation = PTP_COMPUTE_SHL_C then
               writeRam(v, PRODUCT_C+r.wordIndex, data(30 downto 0) & r.shiftCarry);
               v.shiftCarry := data(31);
               v.wordIndex := (r.wordIndex+1) mod 4;
            else
               writeRam(v, PRODUCT_C+r.wordIndex, r.shiftCarry & data(31 downto 1));
               v.shiftCarry := data(0);
               v.wordIndex := (r.wordIndex+3) mod 4;
            end if;

            if (r.operation = PTP_COMPUTE_SHL_C and r.wordIndex = 3) or
               (r.operation = PTP_COMPUTE_SHR_C and r.wordIndex = 0) then
               if r.operation = PTP_COMPUTE_SHL_C and v.shiftCarry = '1' then
                  v.error := '1';
               end if;
               if r.shifts = 1 then
                  v.state := RESTORE_START_S;
                  if r.operation = PTP_COMPUTE_SHR_C and r.roundNearest = '1' and v.shiftCarry = '1' then
                     v.wordIndex := 0;
                     v.carry := '1';
                     v.state := ROUND_START_S;
                  end if;
               else
                  v.shifts := r.shifts-1;
                  v.shiftCarry := '0';
                  readRam(v, PRODUCT_C+v.wordIndex, SHIFT_WORD_S);
               end if;
            else
               readRam(v, PRODUCT_C+v.wordIndex, SHIFT_WORD_S);
            end if;

         when ADD_A_S =>
            v.aluA := data;
            v.negativeA := data(31);
            readRam(v, r.sourceB+r.wordIndex, ADD_B_S);
         when ADD_B_S =>
            v.aluB := data;

            if r.operation = SUB_C or r.operation = PTP_COMPUTE_CMP_C then
               v.aluB := not data;
            end if;

            v.negativeB := data(31);
            v.state := ADD_STORE_S;
         when ADD_STORE_S =>
            writeRam(v, r.target+r.wordIndex, alu(31 downto 0));
            v.carry := alu(32);

            if alu(31 downto 0) /= 0 then
               v.equal := '0';
            end if;

            if r.wordIndex = 3 then
               v.less := not alu(32);
               if r.negativeA /= r.negativeB then
                  v.less := r.negativeA;
               end if;
               if ((r.operation = ADD_C and r.negativeA = r.negativeB) or
                   (r.operation /= ADD_C and r.negativeA /= r.negativeB)) and
                  alu(31) /= r.negativeA then
                  v.error := '1';
               end if;
               v.clearIndex := 4;
               v.state := ZERO_RESULT_S;
            else
               v.wordIndex := r.wordIndex+1;
               readRam(v, r.sourceA+r.wordIndex+1, ADD_A_S);
            end if;

         when SIGN_A_S =>
            v.negativeA := data(31);

            if r.operation = PTP_COMPUTE_SHL_C or r.operation = PTP_COMPUTE_SHR_C then
               v.negative := data(31);
               v.carry := data(31);
               readRam(v, r.sourceA, NORMAL_A_S);
            else
               readRam(v, r.sourceB+3, SIGN_B_S);
            end if;

         when SIGN_B_S =>
            v.negativeB := data(31);
            v.negative := r.negativeA xor data(31);
            v.carry := r.negativeA;
            readRam(v, r.sourceA, NORMAL_A_S);
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
               if r.operation = PTP_COMPUTE_SHL_C or r.operation = PTP_COMPUTE_SHR_C then
                  v.clearIndex := 0;
                  v.state := CLEAR_S;
               else
                  readRam(v, r.sourceB, NORMAL_B_S);
               end if;
            else
               v.wordIndex := r.wordIndex+1;
               readRam(v, r.sourceA+r.wordIndex+1, NORMAL_A_S);
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
               readRam(v, r.sourceB+1+r.wordIndex, NORMAL_B_S);
            end if;

         when ZERO_RESULT_S =>

            if r.clearIndex < 4 then
               writeRam(v, r.target+r.clearIndex, to_unsigned(0, 32));
            else
               writeRam(v, r.remainder+r.clearIndex-4, to_unsigned(0, 32));
            end if;

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
               elsif r.operation = DIV_C then
                  readRam(v, MAG_A_C+3, DIV_LOAD_A_S);
               else
                  v.wordIndex := 0;
                  readRam(v, MAG_A_C, SHIFT_LOAD_S);
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
               writeRam(v, r.target+r.wordIndex, alu(31 downto 0));
            else
               writeRam(v, r.remainder+r.wordIndex, alu(31 downto 0));
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
            v.responses(r.client).resultValid := '1';
            v.responses(r.client).resultError := r.error;
            v.responses(r.client).resultLess := r.less;
            v.responses(r.client).resultEqual := r.equal;
            v.loaded(r.client)(r.target mod PTP_COMPUTE_WORDS_C+3 downto r.target mod PTP_COMPUTE_WORDS_C) := x"F";
            v.loaded(r.client)(r.remainder mod PTP_COMPUTE_WORDS_C+3 downto r.remainder mod PTP_COMPUTE_WORDS_C) := x"F";
            v.active := '0';
            v.state := IDLE_S;
      end case;

      for i in 0 to 3 loop

         if masters(i).cancel = '1' then
            v.pending(i) := '0';
            v.responses(i) := PTP_COMPUTE_SLAVE_INIT_C;
            if masters(i).retain = '0' then
               v.loaded(i) := (others => '0');
            elsif r.active = '1' and r.client = i then
               -- Cancellation wins even on FINISH. The destination may contain
               -- a partial write; committed values occupy different slots.
               v.loaded(i)(r.target mod PTP_COMPUTE_WORDS_C+3 downto r.target mod PTP_COMPUTE_WORDS_C) := x"0";
               v.loaded(i)(r.remainder mod PTP_COMPUTE_WORDS_C+3 downto r.remainder mod PTP_COMPUTE_WORDS_C) := x"0";
            end if;
            if r.active = '1' and r.client = i then
               v.active := '0';
               v.state := IDLE_S;
               v.ramRead := '0';
               v.ramWrite := '0';
            end if;
            if r.readClient = i and r.readPending = '1' then
               v.readPending := '0';
               v.ramRead := '0';
               v.state := IDLE_S;
            end if;
         end if;

      end loop;

      if not RST_ASYNC_G and rst = RST_POLARITY_G then
         v := REG_INIT_C;
      end if;

      rin <= v;
      -- Capacity-ready is the sole combinational exception; payload, result
      -- and read validity remain registered and stable through stalls.
      for i in 0 to 3 loop
         slaves(i).memReady <= v.responses(i).memReady;
         slaves(i).jobReady <= v.responses(i).jobReady;
         slaves(i).readValid <= r.responses(i).readValid;
         slaves(i).readData <= r.responses(i).readData;
         slaves(i).readWord <= r.responses(i).readWord;
         slaves(i).resultValid <= r.responses(i).resultValid;
         slaves(i).resultError <= r.responses(i).resultError;
         slaves(i).resultLess <= r.responses(i).resultLess;
         slaves(i).resultEqual <= r.responses(i).resultEqual;
         slaves(i).resultTag <= r.responses(i).resultTag;
      end loop;
   end process comb;
   seq : process (clk, rst) is
   begin

      if RST_ASYNC_G and rst = RST_POLARITY_G then
         r <= REG_INIT_C after TPD_G;
      elsif rising_edge(clk) then
         r <= rin after TPD_G;
      end if;

   end process seq;

end architecture rtl;
