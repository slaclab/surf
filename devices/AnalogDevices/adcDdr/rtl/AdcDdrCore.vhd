-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Common control and readout core for serialized DDR ADCs
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

library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;
use surf.AxiStreamPkg.all;
use surf.AdcDdrPkg.all;

entity AdcDdrCore is
   generic (
      TPD_G                  : time                                      := 1 ns;
      AXIL_BASE_ADDR_G       : slv(31 downto 0)                          := (others => '0');
      DATA_LANES_G           : positive                                  := 8;
      FCO_LANES_G            : positive                                  := 1;
      CHANNELS_G             : positive                                  := 8;
      SAMPLE_WIDTH_G         : positive range 2 to 16                    := 14;
      SERIALIZATION_FACTOR_G : positive                                  := 14;
      DELAY_BITS_G           : positive range 1 to 9                     := 5;
      DATA_DELAY_INIT_G      : NaturalArray(DATA_LANES_G-1 downto 0)     := (others => 0);
      FCO_DELAY_INIT_G       : NaturalArray(FCO_LANES_G-1 downto 0)      := (others => 0);
      FIFO_ADDR_WIDTH_G      : positive                                  := 4;
      FRAME_PATTERN_G        : slv                                       := "11111110000000";
      PATTERN_CHECK_G        : boolean                                   := true;
      OFFSET_BINARY_G        : boolean                                   := false;
      NEGATE_G               : boolean                                   := false);
   port (
      axilClk          : in  sl;
      axilRst          : in  sl;
      axilReadMaster   : in  AxiLiteReadMasterType;
      axilReadSlave    : out AxiLiteReadSlaveType;
      axilWriteMaster  : in  AxiLiteWriteMasterType;
      axilWriteSlave   : out AxiLiteWriteSlaveType;

      captureClk       : in  sl;
      captureRst       : in  sl;
      delayReady       : in  sl;
      fcoWord          : in  Slv16Array(FCO_LANES_G-1 downto 0);
      fcoValid         : in  slv(FCO_LANES_G-1 downto 0)  := (others => '1');
      sampleValid      : in  sl;
      sampleIn         : in  Slv16Array(CHANNELS_G-1 downto 0);
      phyReset         : out sl;
      bitSlip          : out slv(FCO_LANES_G-1 downto 0);
      dataDelayWrite   : out AdcDdrDelayArray(DATA_LANES_G-1 downto 0);
      fcoDelayWrite    : out AdcDdrDelayArray(FCO_LANES_G-1 downto 0);

      streamClk        : in  sl;
      streamRst        : in  sl;
      streams          : out AxiStreamMasterArray(CHANNELS_G-1 downto 0));
end entity AdcDdrCore;

architecture rtl of AdcDdrCore is

   constant FIFO_WIDTH_C : positive := (16*CHANNELS_G)+1;
   constant AXIS_CONFIG_C : AxiStreamConfigType := (
      TSTRB_EN_C    => false,
      TDATA_BYTES_C => 2,
      TDEST_BITS_C  => 8,
      TID_BITS_C    => 0,
      TKEEP_MODE_C  => TKEEP_FIXED_C,
      TUSER_BITS_C  => 1,
      TUSER_MODE_C  => TUSER_NORMAL_C);
   constant AXIL_CONFIG_C : AxiLiteCrossbarMasterConfigArray(1 downto 0) := (
      0 => (
         baseAddr     => AXIL_BASE_ADDR_G,
         addrBits     => 11,
         connectivity => x"0001"),
      1 => (
         baseAddr     => AXIL_BASE_ADDR_G + resize(ADC_DDR_PATTERN_BASE_ADDR_C, 32),
         addrBits     => 8,
         connectivity => x"0001"));

   type FcoCountArray is array (natural range <>) of natural range 0 to ADC_DDR_LOCK_MATCHES_C;
   type FcoErrorArray is array (natural range <>) of natural range 0 to ADC_DDR_UNLOCK_ERRORS_C;
   type FcoWaitArray is array (natural range <>) of natural range 0 to ADC_DDR_BITSLIP_INTERVAL_C-1;

   function delayValuesToSlv (
      values     : NaturalArray;
      delayClass : string)
      return Slv9Array is
      variable result : Slv9Array(values'range);
   begin
      for i in values'range loop
         assert values(i) < 2**DELAY_BITS_G
            report "AdcDdrCore " & delayClass & " initial delay exceeds DELAY_BITS_G"
            severity failure;
         result(i) := toSlv(values(i), 9);
      end loop;
      return result;
   end function delayValuesToSlv;

   type RegType is record
      phyReset        : sl;
      startupPending  : sl;
      resetHold       : natural range 0 to ADC_DDR_RESET_HOLD_C;
      relock          : sl;
      clearCounters   : sl;
      bitSlip         : slv(FCO_LANES_G-1 downto 0);
      locked          : slv(FCO_LANES_G-1 downto 0);
      matchCount      : FcoCountArray(FCO_LANES_G-1 downto 0);
      errorCount      : FcoErrorArray(FCO_LANES_G-1 downto 0);
      slipWait        : FcoWaitArray(FCO_LANES_G-1 downto 0);
      lostLockCount   : Slv32Array(FCO_LANES_G-1 downto 0);
      overflowCount   : slv(31 downto 0);
      overflow        : sl;
      dataDelay       : Slv9Array(DATA_LANES_G-1 downto 0);
      fcoDelay        : Slv9Array(FCO_LANES_G-1 downto 0);
      dataDelayLoad   : slv(DATA_LANES_G-1 downto 0);
      fcoDelayLoad    : slv(FCO_LANES_G-1 downto 0);
      debugBusy       : sl;
      debugIndex      : natural range 0 to 3;
      snapshotSeq     : slv(31 downto 0);
      debugWorking    : Slv16Array((CHANNELS_G*4)-1 downto 0);
      debugSample     : Slv16Array((CHANNELS_G*4)-1 downto 0);
      formatted       : Slv16Array(CHANNELS_G-1 downto 0);
      sampleValid     : sl;
      axilReadSlave   : AxiLiteReadSlaveType;
      axilWriteSlave  : AxiLiteWriteSlaveType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      phyReset        => '0',
      startupPending  => '1',
      resetHold       => ADC_DDR_RESET_HOLD_C,
      relock          => '0',
      clearCounters   => '0',
      bitSlip         => (others => '0'),
      locked          => (others => '0'),
      matchCount      => (others => 0),
      errorCount      => (others => 0),
      slipWait        => (others => 0),
      lostLockCount   => (others => (others => '0')),
      overflowCount   => (others => '0'),
      overflow        => '0',
      dataDelay       => delayValuesToSlv(DATA_DELAY_INIT_G, "data"),
      fcoDelay        => delayValuesToSlv(FCO_DELAY_INIT_G, "FCO"),
      dataDelayLoad   => (others => '0'),
      fcoDelayLoad    => (others => '0'),
      debugBusy       => '0',
      debugIndex      => 0,
      snapshotSeq     => (others => '0'),
      debugWorking    => (others => (others => '0')),
      debugSample     => (others => (others => '0')),
      formatted       => (others => (others => '0')),
      sampleValid     => '0',
      axilReadSlave   => AXI_LITE_READ_SLAVE_INIT_C,
      axilWriteSlave  => AXI_LITE_WRITE_SLAVE_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal syncAxilReadMaster  : AxiLiteReadMasterType;
   signal syncAxilReadSlave   : AxiLiteReadSlaveType;
   signal syncAxilWriteMaster : AxiLiteWriteMasterType;
   signal syncAxilWriteSlave  : AxiLiteWriteSlaveType;

   signal xbarMasterReadMasters  : AxiLiteReadMasterArray(1 downto 0);
   signal xbarMasterReadSlaves   : AxiLiteReadSlaveArray(1 downto 0);
   signal xbarMasterWriteMasters : AxiLiteWriteMasterArray(1 downto 0);
   signal xbarMasterWriteSlaves  : AxiLiteWriteSlaveArray(1 downto 0);

   signal fifoIn       : slv(FIFO_WIDTH_C-1 downto 0);
   signal fifoOut      : slv(FIFO_WIDTH_C-1 downto 0);
   signal fifoValid    : sl;
   signal fifoOverflow : sl;

begin

   -- The frame-pattern width is part of the logical PHY contract. Catch a
   -- device-wrapper mismatch at elaboration instead of silently truncating it.
   assert FRAME_PATTERN_G'length = SERIALIZATION_FACTOR_G
      report "FRAME_PATTERN_G length must equal SERIALIZATION_FACTOR_G"
      severity failure;

   assert DATA_LANES_G <= 64
      report "Data-delay register window supports at most 64 lanes"
      severity failure;

   assert FCO_LANES_G <= 16
      report "FCO register windows support at most 16 lanes"
      severity failure;

   assert CHANNELS_G <= 32
      report "Debug register window supports at most 32 channels"
      severity failure;

   assert not PATTERN_CHECK_G or CHANNELS_G <= 16
      report "Pattern result windows support at most 16 channels"
      severity failure;

   assert not PATTERN_CHECK_G or FCO_LANES_G <= 16
      report "Pattern result windows support at most 16 FCO lanes"
      severity failure;

   -------------------------------------------------------------------------------------------------
   -- Cross the complete AXI-Lite bus into the ADC word-clock domain. Keeping
   -- the endpoint beside the capture state eliminates individual command and
   -- status CDC paths and makes multi-bit register reads inherently coherent.
   -------------------------------------------------------------------------------------------------
   U_AxiLiteAsync : entity surf.AxiLiteAsync
      generic map (
         TPD_G => TPD_G)
      port map (
         sAxiClk         => axilClk,              -- [in]
         sAxiClkRst      => axilRst,              -- [in]
         sAxiReadMaster  => axilReadMaster,       -- [in]
         sAxiReadSlave   => axilReadSlave,        -- [out]
         sAxiWriteMaster => axilWriteMaster,      -- [in]
         sAxiWriteSlave  => axilWriteSlave,       -- [out]
         mAxiClk         => captureClk,           -- [in]
         mAxiClkRst      => captureRst,           -- [in]
         mAxiReadMaster  => syncAxilReadMaster,   -- [out]
         mAxiReadSlave   => syncAxilReadSlave,    -- [in]
         mAxiWriteMaster => syncAxilWriteMaster,  -- [out]
         mAxiWriteSlave  => syncAxilWriteSlave);  -- [in]

   U_AxiLiteCrossbar : entity surf.AxiLiteCrossbar
      generic map (
         TPD_G              => TPD_G,
         NUM_SLAVE_SLOTS_G  => 1,
         NUM_MASTER_SLOTS_G => 2,
         MASTERS_CONFIG_G   => AXIL_CONFIG_C)
      port map (
         axiClk                => captureClk,                 -- [in]
         axiClkRst             => captureRst,                 -- [in]
         sAxiReadMasters(0)    => syncAxilReadMaster,         -- [in]
         sAxiReadSlaves(0)     => syncAxilReadSlave,          -- [out]
         sAxiWriteMasters(0)   => syncAxilWriteMaster,        -- [in]
         sAxiWriteSlaves(0)    => syncAxilWriteSlave,         -- [out]
         mAxiReadMasters       => xbarMasterReadMasters,      -- [out]
         mAxiReadSlaves        => xbarMasterReadSlaves,       -- [in]
         mAxiWriteMasters      => xbarMasterWriteMasters,     -- [out]
         mAxiWriteSlaves       => xbarMasterWriteSlaves);     -- [in]

   comb : process (captureRst, delayReady, fcoValid, fcoWord, fifoOverflow, r,
                   sampleIn, sampleValid, xbarMasterReadMasters,
                   xbarMasterWriteMasters) is
      variable v           : RegType;
      variable ep          : AxiLiteEndpointType;
      variable word        : slv(SAMPLE_WIDTH_G-1 downto 0);
      variable snapshotTxn : sl;
   begin
      v := r;

      ----------------------------------------------------------------------------------------------
      -- Default all command-like outputs low. AXI writes below assert these
      -- fields for exactly one captureClk cycle; sampleValid is pipelined with
      -- the formatted sample written into the output FIFO.
      ----------------------------------------------------------------------------------------------
      v.relock        := '0';
      v.clearCounters := '0';
      v.bitSlip       := (others => '0');
      v.dataDelayLoad := (others => '0');
      v.fcoDelayLoad  := (others => '0');
      v.sampleValid   := sampleValid;

      ----------------------------------------------------------------------------------------------
      -- FCO word alignment and continuous lock monitoring
      --
      -- While unlocked, require consecutive matching frame words before
      -- declaring lock. A mismatch requests bitslip only after the enforced
      -- quiet interval. Once locked, consecutive errors drop lock and increment
      -- the saturating lost-lock counter.
      ----------------------------------------------------------------------------------------------
      for i in FCO_LANES_G-1 downto 0 loop
         if (r.relock = '1' or r.phyReset = '1' or r.startupPending = '1' or
             delayReady = '0') then
            v.locked(i)     := '0';
            v.matchCount(i) := 0;
            v.errorCount(i) := 0;
            v.slipWait(i)   := 0;
         elsif (fcoValid(i) = '1') then
            if (r.locked(i) = '0') then
               v.errorCount(i) := 0;
               if (r.slipWait(i) /= 0) then
                  -- Do not evaluate the ISERDES output until the DDR BITSLIP
                  -- operation has propagated through its CLKDIV pipeline.
                  v.matchCount(i) := 0;
                  v.slipWait(i)   := r.slipWait(i) - 1;
               elsif (fcoWord(i)(SERIALIZATION_FACTOR_G-1 downto 0) = FRAME_PATTERN_G) then
                  if (r.matchCount(i) = ADC_DDR_LOCK_MATCHES_C-1) then
                     v.matchCount(i) := ADC_DDR_LOCK_MATCHES_C;
                     v.locked(i)     := '1';
                  else
                     v.matchCount(i) := r.matchCount(i) + 1;
                  end if;
               else
                  v.matchCount(i) := 0;
                  v.bitSlip(i)   := '1';
                  v.slipWait(i) := ADC_DDR_BITSLIP_INTERVAL_C-1;
               end if;
            else
               v.matchCount(i) := ADC_DDR_LOCK_MATCHES_C;
               v.slipWait(i)   := 0;
               if (fcoWord(i)(SERIALIZATION_FACTOR_G-1 downto 0) = FRAME_PATTERN_G) then
                  v.errorCount(i) := 0;
               elsif (r.errorCount(i) = ADC_DDR_UNLOCK_ERRORS_C-1) then
                  v.locked(i)     := '0';
                  v.matchCount(i) := 0;
                  v.errorCount(i) := 0;
                  if (r.lostLockCount(i) /= x"FFFFFFFF") then
                     v.lostLockCount(i) := r.lostLockCount(i) + 1;
                  end if;
               else
                  v.errorCount(i) := r.errorCount(i) + 1;
               end if;
            end if;
         end if;
      end loop;

      ----------------------------------------------------------------------------------------------
      -- Event accounting
      --
      -- The wide sample FIFO represents one coherent channel group, so one
      -- sticky flag and counter account for every dropped sample group.
      ----------------------------------------------------------------------------------------------
      if (fifoOverflow = '1') then
         v.overflow := '1';
         if (r.overflowCount /= x"FFFFFFFF") then
            v.overflowCount := r.overflowCount + 1;
         end if;
      end if;

      -- Clear is deliberately applied after event accumulation so software gets
      -- a deterministic all-zero result even when an event is present that cycle.
      if (r.clearCounters = '1') then
         v.lostLockCount   := (others => (others => '0'));
         v.overflowCount   := (others => '0');
         v.overflow        := '0';
      end if;

      ----------------------------------------------------------------------------------------------
      -- Numeric sample formatting
      --
      -- Physical lane polarity and word ordering are resolved by the device
      -- wrapper. Here offset-binary conversion and optional arithmetic negation
      -- operate only across the meaningful ADC width; upper transport bits stay zero.
      ----------------------------------------------------------------------------------------------
      if (sampleValid = '1') then
         for i in CHANNELS_G-1 downto 0 loop
            word := sampleIn(i)(SAMPLE_WIDTH_G-1 downto 0);
            if (OFFSET_BINARY_G) then
               word(SAMPLE_WIDTH_G-1) := not word(SAMPLE_WIDTH_G-1);
            end if;
            if (NEGATE_G) then
               word := (not word) + 1;
            end if;
            v.formatted(i) := (others => '0');
            v.formatted(i)(SAMPLE_WIDTH_G-1 downto 0) := word;
         end loop;
      end if;

      ----------------------------------------------------------------------------------------------
      -- Atomic debug snapshot
      --
      -- Four raw, assembled channel groups are collected before numeric format
      -- conversion so physical-lane calibration is independent of offset-binary
      -- conversion and arithmetic negation. Publishing the whole bank only
      -- after the fourth group prevents AXI software from observing a snapshot
      -- assembled from different requests.
      ----------------------------------------------------------------------------------------------
      if (r.debugBusy = '1' and sampleValid = '1' and delayReady = '1') then
         for i in CHANNELS_G-1 downto 0 loop
            v.debugWorking((r.debugIndex*CHANNELS_G)+i) :=
               resize(sampleIn(i)(SAMPLE_WIDTH_G-1 downto 0), 16);
         end loop;
         if (r.debugIndex = 3) then
            v.debugBusy   := '0';
            v.snapshotSeq := r.snapshotSeq + 1;
            v.debugSample := v.debugWorking;
         else
            v.debugIndex := r.debugIndex + 1;
         end if;
      end if;

      ----------------------------------------------------------------------------------------------
      -- Normalized AXI-Lite register map
      --
      -- Delay writes update the retained programmed value and create a one-cycle
      -- load strobe for the corresponding PHY lane. Status and debug windows are
      -- read directly in this clock domain, so no secondary status image exists.
      ----------------------------------------------------------------------------------------------
      axiSlaveWaitTxn(ep, xbarMasterWriteMasters(0), xbarMasterReadMasters(0),
                      v.axilWriteSlave, v.axilReadSlave);

      -- A snapshot write remains outstanding until the complete four-sample
      -- bank has been published. Holding both write-channel ready signals low
      -- keeps the request stable without adding a second command/status CDC.
      -- Reads remain available while the capture is active.
      snapshotTxn := r.debugBusy;
      if (r.debugBusy = '1') then
         ep.axiStatus.writeEnable := '0';
         if (delayReady = '0') then
            v.debugBusy  := '0';
            v.debugIndex := 0;
            axiSlaveWriteResponse(ep.axiWriteSlave, AXI_RESP_SLVERR_C);
         elsif (sampleValid = '1' and r.debugIndex = 3) then
            axiSlaveWriteResponse(ep.axiWriteSlave);
         end if;
      elsif (ep.axiStatus.writeEnable = '1' and
             ep.axiWriteMaster.awaddr(11 downto 0) = ADC_DDR_SNAPSHOT_ADDR_C and
             ep.axiWriteMaster.wstrb(0) = '1' and
             ep.axiWriteMaster.wdata(0) = '1') then
         snapshotTxn := '1';
         ep.axiStatus.writeEnable := '0';
         if (r.phyReset = '1' or r.startupPending = '1' or delayReady = '0') then
            axiSlaveWriteResponse(ep.axiWriteSlave, AXI_RESP_SLVERR_C);
         else
            v.debugBusy  := '1';
            v.debugIndex := 0;
         end if;
      end if;

      axiSlaveRegisterR(ep, ADC_DDR_VERSION_ADDR_C, 0, ADC_DDR_VERSION_C);
      axiSlaveRegisterR(ep, ADC_DDR_CAPABILITIES0_ADDR_C, 0, toSlv(DATA_LANES_G, 8));
      axiSlaveRegisterR(ep, ADC_DDR_CAPABILITIES0_ADDR_C, 8, toSlv(FCO_LANES_G, 8));
      axiSlaveRegisterR(ep, ADC_DDR_CAPABILITIES0_ADDR_C, 16, toSlv(CHANNELS_G, 8));
      axiSlaveRegisterR(ep, ADC_DDR_CAPABILITIES0_ADDR_C, 24, toSlv(SAMPLE_WIDTH_G, 8));
      axiSlaveRegisterR(ep, ADC_DDR_CAPABILITIES1_ADDR_C, 0, toSlv(DELAY_BITS_G, 8));
      axiSlaveRegisterR(ep, ADC_DDR_CAPABILITIES1_ADDR_C, 8, toSlv(SERIALIZATION_FACTOR_G, 8));
      axiSlaveRegisterR(ep, ADC_DDR_CAPABILITIES1_ADDR_C,
                        ADC_DDR_CAP_PATTERN_CHECK_BIT_C, toSl(PATTERN_CHECK_G));
      axiSlaveRegister(ep, ADC_DDR_CAPTURE_RESET_ADDR_C, 0, v.phyReset);
      axiSlaveRegister(ep, ADC_DDR_RELOCK_ADDR_C, 0, v.relock);
      axiSlaveRegister(ep, ADC_DDR_CLEAR_COUNTERS_ADDR_C, 0, v.clearCounters);
      axiSlaveRegisterR(ep, ADC_DDR_STATUS_ADDR_C,
                        ADC_DDR_STATUS_DELAY_READY_BIT_C, delayReady);
      axiSlaveRegisterR(ep, ADC_DDR_STATUS_ADDR_C,
                        ADC_DDR_STATUS_ALL_LOCKED_BIT_C, uAnd(r.locked));
      axiSlaveRegisterR(ep, ADC_DDR_STATUS_ADDR_C,
                        ADC_DDR_STATUS_ANY_OVERFLOW_BIT_C, r.overflow);
      axiSlaveRegisterR(ep, ADC_DDR_LOCKED_MASK_ADDR_C, 0, r.locked);
      axiSlaveRegisterR(ep, ADC_DDR_SNAPSHOT_SEQUENCE_ADDR_C, 0, r.snapshotSeq);

      for i in DATA_LANES_G-1 downto 0 loop
         axiSlaveRegister(ep, ADC_DDR_DATA_DELAY_ADDR_C+(4*i), 0,
                          v.dataDelay(i)(DELAY_BITS_G-1 downto 0));
         if (ep.axiStatus.writeEnable = '1' and
             xbarMasterWriteMasters(0).awaddr(11 downto 0) =
             ADC_DDR_DATA_DELAY_ADDR_C+(4*i)) then
            v.dataDelayLoad(i) := '1';
         end if;
      end loop;
      for i in FCO_LANES_G-1 downto 0 loop
         axiSlaveRegister(ep, ADC_DDR_FCO_DELAY_ADDR_C+(4*i), 0,
                          v.fcoDelay(i)(DELAY_BITS_G-1 downto 0));
         if (ep.axiStatus.writeEnable = '1' and
             xbarMasterWriteMasters(0).awaddr(11 downto 0) =
             ADC_DDR_FCO_DELAY_ADDR_C+(4*i)) then
            v.fcoDelayLoad(i) := '1';
         end if;
         axiSlaveRegisterR(ep, ADC_DDR_FCO_WORD_ADDR_C+(4*i), 0, fcoWord(i));
         axiSlaveRegisterR(ep, ADC_DDR_LOST_LOCK_COUNT_ADDR_C+(4*i), 0, r.lostLockCount(i));
      end loop;
      axiSlaveRegisterR(ep, ADC_DDR_OVERFLOW_COUNT_ADDR_C, 0, r.overflowCount);
      for i in CHANNELS_G-1 downto 0 loop
         for j in 3 downto 0 loop
            axiSlaveRegisterR(ep, ADC_DDR_DEBUG_ADDR_C+(16*i)+(4*j), 0,
                              r.debugSample((j*CHANNELS_G)+i));
         end loop;
      end loop;
      axiSlaveDefault(ep, v.axilWriteSlave, v.axilReadSlave,
                      AXI_RESP_DECERR_C, snapshotTxn);

      ----------------------------------------------------------------------------------------------
      -- Deserializer reset and alignment restart
      --
      -- Every alignment attempt -- power-up, a lost delay controller, a manual
      -- CaptureReset, or a Relock command -- runs the same sequence: hold the
      -- PHY (deserializer) reset for a fixed number of captureClk/CLKDIV cycles
      -- so a group's FCO and data deserializers all leave reset on the same
      -- edge, then reload every retained delay and let alignment restart. A bare
      -- Relock that only cleared the lock bits would re-run the bitslip search
      -- from whatever independent phase each deserializer happened to hold,
      -- aligning the FCO onto data lanes at an arbitrary relative offset.
      --
      -- The FCO FSM above already holds its counters cleared and issues no
      -- BITSLIP while startupPending is set, and delayReady/startupPending force
      -- sampleValid low, so FIFO writes and snapshots stay suppressed until the
      -- reset is released. Alignment therefore starts naturally on release from
      -- cleared counters; no separate relock strobe is asserted here (that would
      -- re-arm this sequence and loop).
      ----------------------------------------------------------------------------------------------
      if (delayReady = '0' or v.phyReset = '1' or r.relock = '1') then
         -- (Re)arm the sequence and keep the reset counter charged while any
         -- trigger persists.
         v.startupPending := '1';
         v.resetHold      := ADC_DDR_RESET_HOLD_C;
      elsif (r.startupPending = '1') then
         if (r.resetHold /= 0) then
            v.resetHold := r.resetHold - 1;
         else
            -- Reset held long enough with delays ready: release the PHY and
            -- reload every retained delay on the same edge.
            v.startupPending := '0';
            v.dataDelayLoad  := (others => '1');
            v.fcoDelayLoad   := (others => '1');
         end if;
      end if;

      ----------------------------------------------------------------------------------------------
      -- Capture-domain reset and registered outputs
      --
      -- phyReset is a software-controlled manual hold and must not reset this
      -- endpoint; captureRst is the only reset for the core state and AXI
      -- slave records. startupPending provides the hardware-owned startup hold.
      ----------------------------------------------------------------------------------------------
      if (captureRst = '1') then
         v := REG_INIT_C;
      end if;

      rin <= v;

      xbarMasterReadSlaves(0)  <= r.axilReadSlave;
      xbarMasterWriteSlaves(0) <= r.axilWriteSlave;
      phyReset           <= r.phyReset or r.startupPending;
      bitSlip            <= r.bitSlip;
      for i in DATA_LANES_G-1 downto 0 loop
         dataDelayWrite(i).value <= r.dataDelay(i);
         dataDelayWrite(i).load  <= r.dataDelayLoad(i);
      end loop;
      for i in FCO_LANES_G-1 downto 0 loop
         fcoDelayWrite(i).value <= r.fcoDelay(i);
         fcoDelayWrite(i).load  <= r.fcoDelayLoad(i);
      end loop;
   end process comb;

   seq : process (captureClk) is
   begin
      if rising_edge(captureClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   GEN_PATTERN_CHECK : if (PATTERN_CHECK_G) generate
      U_PatternTester : entity surf.AdcDdrPatternTester
         generic map (
            TPD_G                  => TPD_G,
            CHANNELS_G             => CHANNELS_G,
            FCO_LANES_G            => FCO_LANES_G,
            SAMPLE_WIDTH_G         => SAMPLE_WIDTH_G,
            SERIALIZATION_FACTOR_G => SERIALIZATION_FACTOR_G,
            FRAME_PATTERN_G        => FRAME_PATTERN_G)
         port map (
            clk             => captureClk,                   -- [in]
            rst             => captureRst,                   -- [in]
            axilReadMaster  => xbarMasterReadMasters(1),     -- [in]
            axilReadSlave   => xbarMasterReadSlaves(1),      -- [out]
            axilWriteMaster => xbarMasterWriteMasters(1),    -- [in]
            axilWriteSlave  => xbarMasterWriteSlaves(1),     -- [out]
            sampleValid     => sampleValid,                  -- [in]
            sampleIn        => sampleIn,                     -- [in]
            fcoValid        => fcoValid,                     -- [in]
            fcoWord         => fcoWord);                     -- [in]
   end generate GEN_PATTERN_CHECK;

   GEN_NO_PATTERN_CHECK : if (not PATTERN_CHECK_G) generate
      xbarMasterReadSlaves(1)  <= AXI_LITE_READ_SLAVE_EMPTY_DECERR_C;
      xbarMasterWriteSlaves(1) <= AXI_LITE_WRITE_SLAVE_EMPTY_DECERR_C;
   end generate GEN_NO_PATTERN_CHECK;

   -------------------------------------------------------------------------------------------------
   -- Coherent sample clock crossing
   --
   -- Pack all channels plus one common alignment-error bit into a single FIFO
   -- word. This preserves channel-to-channel sample association across unrelated
   -- capture and stream clocks.
   -------------------------------------------------------------------------------------------------
   -- Before frame lock the deserializer output (sampleIn -> r.formatted) is not
   -- yet valid and can be metavalue (X) in simulation. The stream is
   -- always-consumed and flags unaligned beats via tUser(0) below, but it must
   -- never drive X on tData with tValid asserted -- that poisons downstream
   -- feedback consumers (WaveformCapture pedestal, FIR, AdcDsp). Substitute a
   -- defined zero until all FCO lanes are locked; the tUser(0) flag still marks
   -- these beats as unaligned.
   fifoIn(FIFO_WIDTH_C-1) <= not uAnd(r.locked);
   GEN_FIFO_IN : for i in CHANNELS_G-1 downto 0 generate
      fifoIn((16*i)+15 downto 16*i) <=
         r.formatted(i) when uAnd(r.locked) = '1' else (others => '0');
   end generate GEN_FIFO_IN;

   U_DataFifo : entity surf.FifoAsync
      generic map (
         TPD_G         => TPD_G,
         MEMORY_TYPE_G => "distributed",
         FWFT_EN_G     => true,
         DATA_WIDTH_G  => FIFO_WIDTH_C,
         ADDR_WIDTH_G  => FIFO_ADDR_WIDTH_G)
      port map (
         rst           => captureRst or streamRst, -- [in]
         wr_clk        => captureClk,              -- [in]
         wr_en         => r.sampleValid and delayReady and not r.phyReset and not r.startupPending, -- [in]
         din           => fifoIn,                  -- [in]
         wr_data_count => open,                    -- [out]
         wr_ack        => open,                    -- [out]
         overflow      => fifoOverflow,            -- [out]
         prog_full     => open,                    -- [out]
         almost_full   => open,                    -- [out]
         full          => open,                    -- [out]
         not_full      => open,                    -- [out]
         rd_clk        => streamClk,               -- [in]
         rd_en         => fifoValid,               -- [in]
         dout          => fifoOut,                 -- [out]
         rd_data_count => open,                    -- [out]
         valid         => fifoValid,               -- [out]
         underflow     => open,                    -- [out]
         prog_empty    => open,                    -- [out]
         almost_empty  => open,                    -- [out]
         empty         => open);                   -- [out]

   -------------------------------------------------------------------------------------------------
   -- Reconstruct one always-consumed AXI Stream output per logical channel.
   -- tUser(0) reports that the capture group was not aligned without disturbing
   -- sample cadence or imposing SSI framing on the stream.
   -------------------------------------------------------------------------------------------------
   GEN_STREAM : for i in CHANNELS_G-1 downto 0 generate
      format : process (fifoOut, fifoValid) is
         variable v : AxiStreamMasterType;
      begin
         v := axiStreamMasterInit(AXIS_CONFIG_C);
         v.tValid := fifoValid;
         v.tData(15 downto 0) := fifoOut((16*i)+15 downto 16*i);
         v.tDest := toSlv(i, 8);
         v.tUser(0) := fifoOut(FIFO_WIDTH_C-1);
         streams(i) <= v;
      end process format;
   end generate GEN_STREAM;

end architecture rtl;
