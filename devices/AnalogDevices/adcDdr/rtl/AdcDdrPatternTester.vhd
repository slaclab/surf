-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Parallel finite-window pattern checker for serialized ADC data
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
use surf.AxiLitePkg.all;
use surf.AdcDdrPkg.all;

entity AdcDdrPatternTester is
   generic (
      TPD_G                  : time                   := 1 ns;
      CHANNELS_G             : positive               := 8;
      FCO_LANES_G            : positive               := 1;
      SAMPLE_WIDTH_G         : positive range 2 to 16 := 14;
      SERIALIZATION_FACTOR_G : positive               := 14;
      FRAME_PATTERN_G        : slv                    := "11111110000000");
   port (
      clk             : in  sl;
      rst             : in  sl;
      axilReadMaster  : in  AxiLiteReadMasterType;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType;
      axilWriteSlave  : out AxiLiteWriteSlaveType;
      sampleValid     : in  sl;
      sampleIn        : in  Slv16Array(CHANNELS_G-1 downto 0);
      fcoValid        : in  slv(FCO_LANES_G-1 downto 0);
      fcoWord         : in  Slv16Array(FCO_LANES_G-1 downto 0));
end entity AdcDdrPatternTester;

architecture rtl of AdcDdrPatternTester is

   constant PN23_MIN_SAMPLES_C : positive := (23/SAMPLE_WIDTH_G)+1;

   type RegType is record
      start            : sl;
      abort            : sl;
      cfgAlternating   : sl;
      cfgPn23          : sl;
      cfgReference     : slv(7 downto 0);
      cfgChannelMask   : slv(CHANNELS_G-1 downto 0);
      cfgFcoMask       : slv(FCO_LANES_G-1 downto 0);
      cfgDataMask      : slv(SAMPLE_WIDTH_G-1 downto 0);
      cfgPatternA      : slv(SAMPLE_WIDTH_G-1 downto 0);
      cfgPatternB      : slv(SAMPLE_WIDTH_G-1 downto 0);
      cfgSamples       : slv(31 downto 0);
      cfgTimeout       : slv(31 downto 0);
      busy             : sl;
      done             : sl;
      timedOut         : sl;
      configError      : sl;
      aborted          : sl;
      phaseAcquired    : sl;
      expectedPhase    : sl;
      allChannelsPass  : sl;
      allFcoPass       : sl;
      alternating      : sl;
      pn23             : sl;
      referenceChannel : slv(7 downto 0);
      channelMask      : slv(CHANNELS_G-1 downto 0);
      fcoMask          : slv(FCO_LANES_G-1 downto 0);
      dataMask         : slv(SAMPLE_WIDTH_G-1 downto 0);
      patternA         : slv(SAMPLE_WIDTH_G-1 downto 0);
      patternB         : slv(SAMPLE_WIDTH_G-1 downto 0);
      requestedSamples : slv(31 downto 0);
      noValidTimeout   : slv(31 downto 0);
      noValidCount     : slv(31 downto 0);
      pnReferenceWord  : slv(SAMPLE_WIDTH_G-1 downto 0);
      pnErrorBits      : slv(SAMPLE_WIDTH_G-1 downto 0);
      pnHistory        : slv(22 downto 0);
      pnHistoryCount   : natural range 0 to 23;
      completionSeq    : slv(31 downto 0);
      checkedSamples   : slv(31 downto 0);
      channelPassed    : slv(CHANNELS_G-1 downto 0);
      fcoPassed        : slv(FCO_LANES_G-1 downto 0);
      fcoSeen          : slv(FCO_LANES_G-1 downto 0);
      wordErrorCount   : Slv32Array(CHANNELS_G-1 downto 0);
      bitErrorMask     : Slv16Array(CHANNELS_G-1 downto 0);
      fcoErrorCount    : Slv32Array(FCO_LANES_G-1 downto 0);
      axilReadSlave    : AxiLiteReadSlaveType;
      axilWriteSlave   : AxiLiteWriteSlaveType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      start            => '0',
      abort            => '0',
      cfgAlternating   => '0',
      cfgPn23          => '0',
      cfgReference     => (others => '0'),
      cfgChannelMask   => (others => '1'),
      cfgFcoMask       => (others => '1'),
      cfgDataMask      => (others => '1'),
      cfgPatternA      => (others => '0'),
      cfgPatternB      => (others => '1'),
      cfgSamples       => x"00000100",
      cfgTimeout       => x"00000100",
      busy             => '0',
      done             => '0',
      timedOut         => '0',
      configError      => '0',
      aborted          => '0',
      phaseAcquired    => '0',
      expectedPhase    => '0',
      allChannelsPass  => '0',
      allFcoPass       => '0',
      alternating      => '0',
      pn23             => '0',
      referenceChannel => (others => '0'),
      channelMask      => (others => '0'),
      fcoMask          => (others => '0'),
      dataMask         => (others => '0'),
      patternA         => (others => '0'),
      patternB         => (others => '0'),
      requestedSamples => (others => '0'),
      noValidTimeout   => (others => '0'),
      noValidCount     => (others => '0'),
      pnReferenceWord  => (others => '0'),
      pnErrorBits      => (others => '0'),
      pnHistory        => (others => '0'),
      pnHistoryCount   => 0,
      completionSeq    => (others => '0'),
      checkedSamples   => (others => '0'),
      channelPassed    => (others => '0'),
      fcoPassed        => (others => '0'),
      fcoSeen          => (others => '0'),
      wordErrorCount   => (others => (others => '0')),
      bitErrorMask     => (others => (others => '0')),
      fcoErrorCount    => (others => (others => '0')),
      axilReadSlave    => AXI_LITE_READ_SLAVE_INIT_C,
      axilWriteSlave   => AXI_LITE_WRITE_SLAVE_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   assert FRAME_PATTERN_G'length = SERIALIZATION_FACTOR_G
      report "FRAME_PATTERN_G length must equal SERIALIZATION_FACTOR_G"
      severity failure;

   comb : process (axilReadMaster, axilWriteMaster, fcoValid, fcoWord, r, rst,
                   sampleIn, sampleValid) is
      variable v               : RegType;
      variable ep              : AxiLiteEndpointType;
      variable actual          : slv(SAMPLE_WIDTH_G-1 downto 0);
      variable expected        : slv(SAMPLE_WIDTH_G-1 downto 0);
      variable errorBits       : slv(SAMPLE_WIDTH_G-1 downto 0);
      variable selectedPhase   : sl;
      variable phaseValid      : sl;
      variable terminal        : sl;
      variable invalidConfig   : sl;
      variable channelsPassing : sl;
      variable fcoPassing      : sl;
   begin
      v := r;

      -- Default all combinational scratch variables before conditional logic.
      actual          := (others => '0');
      expected        := (others => '0');
      errorBits       := (others => '0');
      selectedPhase   := '0';
      phaseValid      := '0';
      terminal        := '0';
      invalidConfig   := '0';
      channelsPassing := '0';
      fcoPassing      := '0';

      v.start := '0';
      v.abort := '0';
      v.done  := '0';

      if (r.busy = '1') then
         for i in FCO_LANES_G-1 downto 0 loop
            if (r.fcoMask(i) = '1' and fcoValid(i) = '1') then
               v.fcoSeen(i) := '1';
               if (fcoWord(i)(SERIALIZATION_FACTOR_G-1 downto 0) /= FRAME_PATTERN_G) then
                  if (r.fcoErrorCount(i) /= x"FFFFFFFF") then
                     v.fcoErrorCount(i) := std_logic_vector(unsigned(r.fcoErrorCount(i)) + 1);
                  end if;
               end if;
            end if;
         end loop;

         if (r.abort = '1') then
            v.busy    := '0';
            v.done    := '1';
            v.aborted := '1';
         elsif (sampleValid = '1') then
            v.noValidCount := (others => '0');
            phaseValid := '1';
            selectedPhase := '0';

            if (r.pn23 = '1') then
               v.pnReferenceWord :=
                  (sampleIn(to_integer(unsigned(r.referenceChannel)))(SAMPLE_WIDTH_G-1 downto 0) xor
                   r.patternA) and r.dataMask;
               v.pnErrorBits := (others => '0');
               for bitindex in SAMPLE_WIDTH_G-1 downto 0 loop
                  if (v.pnHistoryCount < 23) then
                     v.pnHistory := v.pnHistory(21 downto 0) & v.pnReferenceWord(bitindex);
                     v.pnHistoryCount := v.pnHistoryCount + 1;
                     if (v.pnHistoryCount = 23) then
                        if uOr(v.pnHistory) = '1' then
                           v.phaseAcquired := '1';
                        else
                           -- The all-zero state satisfies the recurrence but is
                           -- not part of the maximal-length PN23 sequence.
                           v.pnErrorBits := (others => '1');
                        end if;
                     end if;
                  else
                     if (v.pnReferenceWord(bitindex) /=
                         (v.pnHistory(22) xor v.pnHistory(17))) then
                        v.pnErrorBits(bitindex) := '1';
                     end if;
                     v.pnHistory := v.pnHistory(21 downto 0) & v.pnReferenceWord(bitindex);
                  end if;
               end loop;

            elsif (r.alternating = '1') then
               if (r.phaseAcquired = '1') then
                  selectedPhase := r.expectedPhase;
               else
                  actual := sampleIn(to_integer(unsigned(r.referenceChannel)))
                            (SAMPLE_WIDTH_G-1 downto 0) and r.dataMask;
                  if (actual = (r.patternA and r.dataMask)) then
                     selectedPhase := '0';
                     v.phaseAcquired := '1';
                     v.expectedPhase := '1';
                  elsif (actual = (r.patternB and r.dataMask)) then
                     selectedPhase := '1';
                     v.phaseAcquired := '1';
                     v.expectedPhase := '0';
                  else
                     phaseValid := '0';
                  end if;
               end if;
            end if;

            for i in CHANNELS_G-1 downto 0 loop
               if (r.channelMask(i) = '1') then
                  if (r.pn23 = '1') then
                     if (i = to_integer(unsigned(r.referenceChannel))) then
                        errorBits := v.pnErrorBits;
                     else
                        actual := (sampleIn(i)(SAMPLE_WIDTH_G-1 downto 0) xor
                                  r.patternA) and r.dataMask;
                        errorBits := actual xor v.pnReferenceWord;
                     end if;
                  elsif (phaseValid = '0') then
                     errorBits := r.dataMask;
                  else
                     if (selectedPhase = '0') then
                        expected := r.patternA and r.dataMask;
                     else
                        expected := r.patternB and r.dataMask;
                     end if;
                     actual := sampleIn(i)(SAMPLE_WIDTH_G-1 downto 0) and r.dataMask;
                     errorBits := actual xor expected;
                  end if;
                  if (uOr(errorBits) = '1') then
                     if (r.wordErrorCount(i) /= x"FFFFFFFF") then
                        v.wordErrorCount(i) := std_logic_vector(unsigned(r.wordErrorCount(i)) + 1);
                     end if;
                     v.bitErrorMask(i)(SAMPLE_WIDTH_G-1 downto 0) :=
                        r.bitErrorMask(i)(SAMPLE_WIDTH_G-1 downto 0) or errorBits;
                  end if;
               end if;
            end loop;

            if (r.alternating = '1' and r.phaseAcquired = '1') then
               v.expectedPhase := not r.expectedPhase;
            end if;
            v.checkedSamples := std_logic_vector(unsigned(r.checkedSamples) + 1);
            if (unsigned(r.checkedSamples) + 1 >= unsigned(r.requestedSamples)) then
               terminal := '1';
            end if;
         elsif (r.noValidTimeout /= x"00000000") then
            if (unsigned(r.noValidCount) + 1 >= unsigned(r.noValidTimeout)) then
               v.busy     := '0';
               v.done     := '1';
               v.timedOut := '1';
            else
               v.noValidCount := std_logic_vector(unsigned(r.noValidCount) + 1);
            end if;
         end if;

         if (terminal = '1') then
            v.busy := '0';
            v.done := '1';
            channelsPassing := '1';
            for i in CHANNELS_G-1 downto 0 loop
               if (r.channelMask(i) = '1') then
                  if (v.wordErrorCount(i) = x"00000000") then
                     v.channelPassed(i) := '1';
                  else
                     v.channelPassed(i) := '0';
                     channelsPassing := '0';
                  end if;
               end if;
            end loop;
            fcoPassing := '1';
            for i in FCO_LANES_G-1 downto 0 loop
               if (r.fcoMask(i) = '1') then
                  if (v.fcoSeen(i) = '1' and v.fcoErrorCount(i) = x"00000000") then
                     v.fcoPassed(i) := '1';
                  else
                     v.fcoPassed(i) := '0';
                     fcoPassing := '0';
                  end if;
               end if;
            end loop;
            v.allChannelsPass := channelsPassing;
            v.allFcoPass      := fcoPassing;
            if (r.pn23 = '1' and v.phaseAcquired = '0') then
               v.allChannelsPass := '0';
            end if;
         end if;

      elsif (r.start = '1') then
         v.busy             := '0';
         v.timedOut         := '0';
         v.configError      := '0';
         v.aborted          := '0';
         v.phaseAcquired    := '0';
         v.expectedPhase    := '0';
         v.allChannelsPass  := '0';
         v.allFcoPass       := '0';
         v.alternating      := r.cfgAlternating;
         v.pn23             := r.cfgPn23;
         v.referenceChannel := r.cfgReference;
         v.channelMask      := r.cfgChannelMask;
         v.fcoMask          := r.cfgFcoMask;
         v.dataMask         := r.cfgDataMask;
         v.patternA         := r.cfgPatternA;
         v.patternB         := r.cfgPatternB;
         v.requestedSamples := r.cfgSamples;
         v.noValidTimeout   := r.cfgTimeout;
         v.noValidCount     := (others => '0');
         v.pnReferenceWord  := (others => '0');
         v.pnErrorBits      := (others => '0');
         v.pnHistory        := (others => '0');
         v.pnHistoryCount   := 0;
         v.checkedSamples   := (others => '0');
         v.channelPassed    := (others => '0');
         v.fcoPassed        := (others => '0');
         v.fcoSeen          := (others => '0');
         v.wordErrorCount   := (others => (others => '0'));
         v.bitErrorMask     := (others => (others => '0'));
         v.fcoErrorCount    := (others => (others => '0'));
         invalidConfig := '0';
         if (r.cfgSamples = x"00000000" or uOr(r.cfgChannelMask) = '0' or
             uOr(r.cfgDataMask) = '0') then
            invalidConfig := '1';
         end if;
         if (r.cfgAlternating = '1' and r.cfgPn23 = '1') then
            invalidConfig := '1';
         end if;
         if (r.cfgAlternating = '1' or r.cfgPn23 = '1') then
            if (to_integer(unsigned(r.cfgReference)) >= CHANNELS_G) then
               invalidConfig := '1';
            elsif (r.cfgChannelMask(to_integer(unsigned(r.cfgReference))) = '0') then
               invalidConfig := '1';
            end if;
            if (r.cfgAlternating = '1' and
                (r.cfgPatternA and r.cfgDataMask) = (r.cfgPatternB and r.cfgDataMask)) then
               invalidConfig := '1';
            end if;
         end if;
         if (r.cfgPn23 = '1') then
            if uAnd(r.cfgDataMask) = '0' or
               unsigned(r.cfgSamples) < to_unsigned(PN23_MIN_SAMPLES_C, 32) then
               invalidConfig := '1';
            end if;
         end if;
         if (invalidConfig = '1') then
            v.done        := '1';
            v.configError := '1';
         else
            v.busy          := '1';
            v.phaseAcquired := not r.cfgAlternating and not r.cfgPn23;
         end if;
      end if;

      if (v.done = '1') then
         v.completionSeq := std_logic_vector(unsigned(r.completionSeq) + 1);
      end if;

      axiSlaveWaitTxn(ep, axilWriteMaster, axilReadMaster,
                      v.axilWriteSlave, v.axilReadSlave);
      axiSlaveRegister(ep, ADC_DDR_PATTERN_START_ADDR_C, 0, v.start);
      axiSlaveRegister(ep, ADC_DDR_PATTERN_ABORT_ADDR_C, 0, v.abort);
      axiSlaveRegister(ep, ADC_DDR_PATTERN_CONFIG_ADDR_C,
                       ADC_DDR_PATTERN_ALTERNATING_BIT_C, v.cfgAlternating);
      axiSlaveRegister(ep, ADC_DDR_PATTERN_CONFIG_ADDR_C,
                       ADC_DDR_PATTERN_PN23_BIT_C, v.cfgPn23);
      axiSlaveRegister(ep, ADC_DDR_PATTERN_CONFIG_ADDR_C,
                       ADC_DDR_PATTERN_REFERENCE_OFFSET_C, v.cfgReference);
      axiSlaveRegister(ep, ADC_DDR_PATTERN_CHANNEL_MASK_ADDR_C, 0, v.cfgChannelMask);
      axiSlaveRegister(ep, ADC_DDR_PATTERN_FCO_MASK_ADDR_C, 0, v.cfgFcoMask);
      axiSlaveRegister(ep, ADC_DDR_PATTERN_DATA_MASK_ADDR_C, 0, v.cfgDataMask);
      axiSlaveRegister(ep, ADC_DDR_PATTERN_A_ADDR_C, 0, v.cfgPatternA);
      axiSlaveRegister(ep, ADC_DDR_PATTERN_B_ADDR_C, 0, v.cfgPatternB);
      axiSlaveRegister(ep, ADC_DDR_PATTERN_SAMPLES_ADDR_C, 0, v.cfgSamples);
      axiSlaveRegister(ep, ADC_DDR_PATTERN_TIMEOUT_ADDR_C, 0, v.cfgTimeout);
      axiSlaveRegisterR(ep, ADC_DDR_PATTERN_STATUS_ADDR_C,
                        ADC_DDR_PATTERN_BUSY_BIT_C, r.busy);
      axiSlaveRegisterR(ep, ADC_DDR_PATTERN_STATUS_ADDR_C,
                        ADC_DDR_PATTERN_TIMEOUT_BIT_C, r.timedOut);
      axiSlaveRegisterR(ep, ADC_DDR_PATTERN_STATUS_ADDR_C,
                        ADC_DDR_PATTERN_CONFIG_ERROR_BIT_C, r.configError);
      axiSlaveRegisterR(ep, ADC_DDR_PATTERN_STATUS_ADDR_C,
                        ADC_DDR_PATTERN_ABORTED_BIT_C, r.aborted);
      axiSlaveRegisterR(ep, ADC_DDR_PATTERN_STATUS_ADDR_C,
                        ADC_DDR_PATTERN_PHASE_ACQUIRED_BIT_C, r.phaseAcquired);
      axiSlaveRegisterR(ep, ADC_DDR_PATTERN_STATUS_ADDR_C,
                        ADC_DDR_PATTERN_CHANNEL_PASS_BIT_C, r.allChannelsPass);
      axiSlaveRegisterR(ep, ADC_DDR_PATTERN_STATUS_ADDR_C,
                        ADC_DDR_PATTERN_FCO_PASS_BIT_C, r.allFcoPass);
      axiSlaveRegisterR(ep, ADC_DDR_PATTERN_SEQUENCE_ADDR_C, 0, r.completionSeq);
      axiSlaveRegisterR(ep, ADC_DDR_PATTERN_CHECKED_ADDR_C, 0, r.checkedSamples);
      axiSlaveRegisterR(ep, ADC_DDR_PATTERN_CHANNEL_PASS_ADDR_C, 0, r.channelPassed);
      axiSlaveRegisterR(ep, ADC_DDR_PATTERN_FCO_PASS_ADDR_C, 0, r.fcoPassed);
      for i in CHANNELS_G-1 downto 0 loop
         axiSlaveRegisterR(ep, std_logic_vector(unsigned(ADC_DDR_PATTERN_WORD_ERROR_ADDR_C)+(4*i)),
                           0, r.wordErrorCount(i));
         axiSlaveRegisterR(ep, std_logic_vector(unsigned(ADC_DDR_PATTERN_BIT_ERROR_ADDR_C)+(4*i)),
                           0, r.bitErrorMask(i));
      end loop;
      for i in FCO_LANES_G-1 downto 0 loop
         axiSlaveRegisterR(ep, std_logic_vector(unsigned(ADC_DDR_PATTERN_FCO_ERROR_ADDR_C)+(4*i)),
                           0, r.fcoErrorCount(i));
      end loop;
      axiSlaveDefault(ep, v.axilWriteSlave, v.axilReadSlave, AXI_RESP_DECERR_C);

      if (rst = '1') then
         v := REG_INIT_C;
      end if;

      rin <= v;

      axilReadSlave  <= r.axilReadSlave;
      axilWriteSlave <= r.axilWriteSlave;
   end process comb;

   seq : process (clk) is
   begin
      if rising_edge(clk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end architecture rtl;
