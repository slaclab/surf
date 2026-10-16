-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Protocol configuration, AXI-Lite and coherent diagnostic banks.
-- Active configuration and MAC identity changes are published without another
-- pipeline stage. The protocol producer supplies registered word writes and
-- commits; snapshot capture retains the original pre-edge semantics.
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
use surf.PtpPkg.all;
use surf.PtpRegisterPkg.all;

entity PtpProtocolReg is
   generic (
      TPD_G             : time             := 1 ns;
      RST_POLARITY_G    : sl               := '1';
      RST_ASYNC_G       : boolean          := false;
      CLK_FREQ_G        : positive         := 156250000;
      PACKET_LIFETIME_G : positive         := 156250000;
      INGRESS_LATENCY_G : slv(63 downto 0) := (others => '0');
      EGRESS_LATENCY_G  : slv(63 downto 0) := (others => '0'));
   port (
      clk              : in  sl;
      rst              : in  sl;
      regRst           : in  sl;
      axiReadMaster    : in  AxiLiteReadMasterType;
      axiReadSlave     : out AxiLiteReadSlaveType;
      axiWriteMaster   : in  AxiLiteWriteMasterType;
      axiWriteSlave    : out AxiLiteWriteSlaveType;
      configControl    : in  PtpConfigControlType;
      snapshotControl  : in  PtpSnapshotControlType;
      snapshotPrepared : out sl;
      configValid      : out sl;
      configPrepared   : out sl;
      localMac         : in  slv(47 downto 0);
      identityChanged  : out sl;
      activeConfig     : out PtpPortConfigType;
      sharedConfig     : out PtpSharedConfigType;
      rxCounters       : in  PtpRxCountersType;
      status           : in  PtpPortStatusType;
      timeoutCount     : in  slv(31 downto 0);
      publication      : in  PtpPublicationType);
end entity PtpProtocolReg;

architecture rtl of PtpProtocolReg is

   function initialConfig return PtpPortConfigType is
      variable v      : PtpPortConfigType     := PTP_PORT_CONFIG_INIT_C;
      constant TICK_C : unsigned(63 downto 0) := to_unsigned(CLK_FREQ_G, 64);
   begin
      v.delayInterval      := slv(TICK_C);               -- 1 s before jitter.
      v.syncTimeout        := slv(resize(TICK_C*3, 64));  -- 3 s.
      v.associationTimeout := slv(resize(TICK_C*2, 64));  -- 2 s at supported PHY clocks.

      if unsigned(v.associationTimeout) < PTP_MIN_ASSOCIATION_TICKS_C then
         v.associationTimeout := toSlv(PTP_MIN_ASSOCIATION_TICKS_C,64);
      end if;

      v.maxExchange := slv(resize(TICK_C*2, 64));  -- 2 s.
      v.minRateSpan := slv(TICK_C/2);             -- 0.5 s, rounded down to ticks.
      v.maxRateAge  := slv(resize(TICK_C*4, 64));  -- 4 s.
      return v;
   end function;

   function initialWords return Slv32Array is
      constant CFG_C : PtpPortConfigType := initialConfig;
      variable words : Slv32Array(0 to 47) := (others => (others => '0'));
      procedure put(constant index : natural;
      constant value : slv) is
      begin
         for i in 0 to (value'length+31)/32-1 loop
            words(index+i) := slv(resize(shift_right(unsigned(value),32*i),32));
         end loop;
      end procedure;

   begin
      words(1)(4) := CFG_C.identityOverride;
      words(2)(7 downto 0) := CFG_C.domainNumber;
      words(2)(11 downto 8) := CFG_C.minorVersion;
      put(4,CFG_C.localIdentity);
      put(8,CFG_C.sourceIdentity);
      put(32,CFG_C.delayInterval);
      put(34,CFG_C.syncTimeout);
      put(36,CFG_C.associationTimeout);
      put(38,CFG_C.maxExchange);
      put(40,CFG_C.minRateSpan);
      put(42,CFG_C.maxRateAge);
      put(44,CFG_C.lfsrSeed);
      put(46,CFG_C.maxPathDelay);
      return words;
   end function;

   function configIndex(address : slv(11 downto 0)) return integer is
      variable index : natural := to_integer(unsigned(address(11 downto 2)));
   begin

      case index is
         when 1 | 2 | 4 to 6 | 8 to 10 | 32 to 44 | 46 to 47 =>
            return index;
         when others =>
            return -1;
      end case;

   end function;

   function configMask(index : integer;
   strobe : slv(3 downto 0)) return slv is
      variable mask : slv(31 downto 0) := (others => '0');
   begin

      case index is
         when 1 =>

            if strobe(0) = '1' then
               mask(4) := '1';
            end if;

         when 2 =>

            if strobe(0) = '1' then
               mask(7 downto 0) := (others => '1');
            end if;

            if strobe(1) = '1' then
               mask(11 downto 8) := (others => '1');
            end if;

         when 6 | 10 | 44 =>

            if strobe(1 downto 0) = "11" then
               mask(15 downto 0) := (others => '1');
            end if;

         when others =>

            if strobe = x"F" then
               mask := (others => '1');
            end if;

      end case;

      return mask;
   end function;

   type RegType is record
      readSlave        : AxiLiteReadSlaveType;
      writeSlave       : AxiLiteWriteSlaveType;
      candidate        : PtpPortConfigType;
      configBus        : PtpRegisterBusType;
      validateValue    : slv(63 downto 0);
      validatePrevious : slv(63 downto 0);
      configValid      : sl;
      activeConfig     : PtpPortConfigType;
      lastMac          : slv(47 downto 0);
      sequenceId       : slv(31 downto 0);
      snapshotBus      : PtpRegisterBusType;
      counterBus       : PtpRegisterBusType;
   end record;

   constant REG_INIT_C : RegType := (
      readSlave        => AXI_LITE_READ_SLAVE_INIT_C,
      writeSlave       => AXI_LITE_WRITE_SLAVE_INIT_C,
      candidate        => initialConfig,
      configBus        => PTP_REGISTER_BUS_INIT_C,
      validateValue    => (others => '0'),
      validatePrevious => (others => '0'),
      configValid      => '1',
      activeConfig     => initialConfig,
      lastMac          => (others => '0'),
      sequenceId       => (others => '0'),
      snapshotBus      => PTP_REGISTER_BUS_INIT_C,
      counterBus       => PTP_REGISTER_BUS_INIT_C);

   signal r               : RegType := REG_INIT_C;
   signal rin             : RegType;
   signal snapshotSlave : PtpRegisterSlaveType;
   signal counterSlave  : PtpRegisterSlaveType;
   signal snapshotScalars : Slv32Array(0 to 6);
   signal configMasters : PtpRegisterMasterArray(0 to 1);
   signal configSlaves  : PtpRegisterSlaveArray(0 to 1);

   signal configScan : PtpConfigScanType;

begin

   snapshotScalars <=
   (
      rxCounters.accepted,
      rxCounters.dropped,
      rxCounters.overflow,
      status.rejectedCount,
      status.syncCount,
      status.delayCount,
      timeoutCount
   );

   U_Publication : entity surf.PtpPublicationBank
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G,
         RECORD_WORDS_G => IntegerArray'(12,20),
         MEMORY_TYPE_G  => "block")
      port map (
         clk         => clk,                   -- [in]
         rst         => rst,                   -- [in]
         publication => publication,           -- [in]
         snapshot    => snapshotControl,       -- [in]
         master      => r.snapshotBus.master,  -- [in]
         slave       => snapshotSlave);        -- [out]

   U_Snapshot : entity surf.PtpSnapshotBank
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G,
         WORDS_G        => 7)
      port map (
         clk      => clk,                  -- [in]
         rst      => rst,                  -- [in]
         scalars  => snapshotScalars,      -- [in]
         snapshot => snapshotControl,      -- [in]
         prepared => snapshotPrepared,     -- [out]
         master   => r.counterBus.master,  -- [in]
         slave    => counterSlave);        -- [out]

   configMasters(0) <= r.configBus.master;
   configMasters(1) <= PTP_REGISTER_MASTER_INIT_C;

   U_Config : entity surf.PtpConfigBank
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G,
         DEFAULTS_G     => initialWords,
         MEMORY_TYPE_G  => "block")
      port map (
         clk      => clk,                    -- [in]
         rst      => rst,                    -- [in]
         prepare  => configControl.prepare,  -- [in]
         apply    => configControl.apply,    -- [in]
         prepared => configPrepared,         -- [out]
         scan     => configScan,             -- [out]
         masters  => configMasters,          -- [in]
         slaves   => configSlaves);          -- [out]

   comb : process (all) is
      variable readAddress      : slv(11 downto 0);
      variable writeAddress     : slv(11 downto 0);
      variable v                : RegType;
      variable ep               : AxiLiteEndpointType;
      variable configReadIndex  : integer range -1 to 47;
      variable configWriteIndex : integer range -1 to 47;
      variable configIndexValue : natural range 0 to 255;
      variable snapshotIndex    : integer range -1 to 31;
      variable snapshotAddress  : natural range 0 to 1023;
   begin
      v := r;
      axiSlaveWaitTxn(ep, axiWriteMaster, axiReadMaster, v.writeSlave, v.readSlave);
      -- An inactive AXI address is unspecified. Decode only admitted requests;
      -- RAM responses retain their address/ownership inside ptpRegisterBus.
      readAddress  := (others => '0');
      writeAddress := (others => '0');
      if ep.axiStatus.readEnable = '1' then
         readAddress := ep.axiReadMaster.araddr(11 downto 0);
      end if;
      if ep.axiStatus.writeEnable = '1' then
         writeAddress := ep.axiWriteMaster.awaddr(11 downto 0);
      end if;

      -- Suppress register accesses during AXI-only reset.
      if regRst = '1' then
         ep.axiStatus := AXI_LITE_STATUS_INIT_C;
      end if;

      -- Configuration shadows and live identity/status.
      axiSlaveRegisterR(ep, x"030", 0, localMac);
      axiSlaveRegisterR(ep, x"044", 0, status.active);
      axiSlaveRegisterR(ep, x"044", 1, status.announceValid);
      axiSlaveRegisterR(ep, x"044", 2, status.ratioValid);
      axiSlaveRegisterR(ep, x"048", 0, status.ledgerStatus);
      axiSlaveRegisterR(ep, x"060", 0, r.activeConfig.localIdentity);
      axiSlaveRegisterR(ep, x"070", 0, r.activeConfig.sourceIdentity);
      -- Protocol timer and acceptance-limit shadows.
      -- Implementation constants and active shared limits.
      axiSlaveRegisterR(ep, x"0C0", 0, slv(to_unsigned(PACKET_LIFETIME_G, 64)));
      axiSlaveRegisterR(ep, x"0D0", 0, INGRESS_LATENCY_G);
      axiSlaveRegisterR(ep, x"0D8", 0, EGRESS_LATENCY_G);
      axiSlaveRegisterR(ep, x"0E0", 0, r.activeConfig.associationTimeout);
      axiSlaveRegisterR(ep, x"0E8", 0, r.activeConfig.syncTimeout);
      axiSlaveRegisterR(ep, x"0F0", 0, r.activeConfig.maxPathDelay);
      axiSlaveRegisterR(ep, x"0F8", 0, toSlv(PTP_MIN_ASSOCIATION_TICKS_C, 32));
      -- Coherent Announce and exchange snapshots.
      -- Coherent RX/protocol counters and snapshot sequence.
      axiSlaveRegisterR(ep, x"3FC", 0, r.sequenceId);
      configReadIndex  := configIndex(readAddress);
      configWriteIndex := configIndex(writeAddress);
      ptpRegisterBus(v.configBus, r.configBus, configSlaves(0), ep, configReadIndex, configWriteIndex,
         configMask(configWriteIndex,ep.axiWriteMaster.wstrb), "00", regRst);
      snapshotIndex   := -1;
      snapshotAddress := to_integer(unsigned(readAddress(11 downto 2)));

      case snapshotAddress is
         when 76 to 79 =>
            snapshotIndex := snapshotAddress-68;
         when 80 to 87 =>
            snapshotIndex := snapshotAddress-80;
         when 88 to 90 =>
            snapshotIndex := snapshotAddress-76;
         when 92 to 94 =>
            snapshotIndex := snapshotAddress-77;
         when 96 to 98 =>
            snapshotIndex := snapshotAddress-78;
         when 100 to 102 =>
            snapshotIndex := snapshotAddress-79;
         when 104 to 111 =>
            snapshotIndex := snapshotAddress-80;
         when others =>
            null;
      end case;

      ptpRegisterBus(v.snapshotBus, r.snapshotBus, snapshotSlave, ep, snapshotIndex, -1, x"00000000", "00", regRst);
      snapshotIndex := -1;

      if snapshotAddress >= 128 and snapshotAddress <= 134 then
         snapshotIndex := snapshotAddress-128;
      end if;

      ptpRegisterBus(v.counterBus, r.counterBus, counterSlave, ep, snapshotIndex, -1, x"00000000", "00", regRst);
      axiSlaveDefault(ep, v.writeSlave, v.readSlave, AXI_RESP_DECERR_C);
      -- The bus reset cancels responses only. Accepted operations and active
      -- settings belong to the system-reset lifetime, not the AXI transaction.
      if regRst = '1' then
         v.readSlave  := AXI_LITE_READ_SLAVE_INIT_C;
         v.writeSlave := AXI_LITE_WRITE_SLAVE_INIT_C;
      end if;

      -------------------------------------------------------------------------
      -- Coordinated configuration and snapshots survive AXI-only reset.
      -------------------------------------------------------------------------
      -- Validate only the frozen candidate streamed by the word bank. Its
      -- preparation handshake keeps the coordinator from sampling a partial vote.
      if configControl.prepare = '1' then
         v.configValid := '1';
      end if;

      if configScan.valid = '1' then
         configIndexValue := to_integer(unsigned(configScan.index));
         if configIndexValue mod 2 = 0 then
            v.validateValue(31 downto 0) := configScan.data;
         else
            v.validateValue(63 downto 32) := configScan.data;
         end if;

         case configIndexValue is
            when 1 =>
               v.candidate.identityOverride := configScan.data(4);
            when 2 =>
               v.candidate.domainNumber := configScan.data(7 downto 0);
               v.candidate.minorVersion := configScan.data(11 downto 8);
               if unsigned(configScan.data(11 downto 8)) > unsigned(PTP_MINOR_VERSION_MAX_C) then
                  v.configValid := '0';
               end if;
            when 4 to 5 =>
               v.candidate.localIdentity(32*(configIndexValue-4)+31 downto 32*(configIndexValue-4)) := configScan.data;
               if configIndexValue = 4 and unsigned(configScan.data(15 downto 0)) = 0 then
                  v.configValid := '0';
               end if;
            when 6 =>
               v.candidate.localIdentity(79 downto 64) := configScan.data(15 downto 0);
            when 8 to 9 =>
               v.candidate.sourceIdentity(32*(configIndexValue-8)+31 downto 32*(configIndexValue-8)) := configScan.data;
               if configIndexValue = 8 and unsigned(configScan.data(15 downto 0)) = 0 then
                  v.configValid := '0';
               end if;
            when 10 =>
               v.candidate.sourceIdentity(79 downto 64) := configScan.data(15 downto 0);
            when 33 =>
               v.candidate.delayInterval := v.validateValue;
            when 35 =>
               v.candidate.syncTimeout := v.validateValue;
            when 37 =>
               v.candidate.associationTimeout := v.validateValue;
               if unsigned(v.validateValue) < PTP_MIN_ASSOCIATION_TICKS_C then
                  v.configValid := '0';
               end if;
            when 39 =>
               v.candidate.maxExchange := v.validateValue;
            when 41 =>
               v.candidate.minRateSpan := v.validateValue;
               v.validatePrevious      := v.validateValue;
            when 43 =>
               v.candidate.maxRateAge := v.validateValue;
               if unsigned(v.validateValue) < unsigned(r.validatePrevious) then
                  v.configValid := '0';
               end if;
            when 44 =>
               v.candidate.lfsrSeed := configScan.data(15 downto 0);
            when 47 =>
               v.candidate.maxPathDelay := v.validateValue;
               if signed(v.validateValue) <= 0 then
                  v.configValid := '0';
               end if;
            when others =>
               null;
         end case;

         if configIndexValue >= 33 and configIndexValue <= 43 and configIndexValue mod 2 = 1 then
            if not ptpValidTimeout(v.validateValue) then
               v.configValid := '0';
            end if;
         end if;
      end if;

      if configControl.apply = '1' then
         v.activeConfig := r.candidate;
      end if;

      -- Derive the active identity at apply and whenever the shared MAC
      -- changes. A frozen override candidate remains independent of MAC edits.
      if configControl.apply = '1' or localMac /= r.lastMac then
         if v.activeConfig.identityOverride = '0' then
            v.activeConfig.localIdentity := ptpPortIdentity(
               localMac, v.activeConfig.localIdentity(15 downto 0));
         end if;
      end if;

      v.lastMac := localMac;

      if snapshotControl.publish = '1' then
         v.sequenceId := snapshotControl.sequenceId;
      end if;

      if not RST_ASYNC_G and rst = RST_POLARITY_G then
         v := REG_INIT_C;
      end if;
      rin           <= v;
      configValid   <= r.configValid;
      axiReadSlave  <= r.readSlave;
      axiWriteSlave <= r.writeSlave;
      activeConfig  <= r.activeConfig;
      -- Same-edge detection is required to cancel the old source session.
      identityChanged                 <= toSl(localMac /= r.lastMac);
      sharedConfig.associationTimeout <= r.activeConfig.associationTimeout;
      sharedConfig.syncTimeout        <= r.activeConfig.syncTimeout;
      sharedConfig.maxPathDelay       <= r.activeConfig.maxPathDelay;
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
