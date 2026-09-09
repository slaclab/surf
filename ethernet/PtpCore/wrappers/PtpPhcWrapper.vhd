-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Flattened PHC and asynchronous snapshot verification interface.
--
-- Instantiates PtpPhc with configurable clock frequency and reset semantics,
-- packs the exposed command fields into PtpPhcCommandType, and unpacks time,
-- rate, raw ticks, validity, acknowledgement and fault status. PPS,
-- discontinuity and capture-abort outputs allow tests to check edge-specific
-- clock behavior against an independent numerical model. The standard AXI
-- adapter exposes the PHC register bank; Python programs monotonic policy and
-- drives prepare/apply strobes. Hardware commands use the servo arbitration
-- path, with automatic control enabled and ownership held through completion.
--
-- Also instantiates PtpPhcRead with a separately driven reader clock/reset and
-- exposes its request, completion, snapshot and sequence fields. Reset
-- polarity is adapted for the mailbox. Cocotb controls both clocks and command
-- timing to exercise coherent snapshots, reset cancellation and stopped-peer
-- recovery; the wrapper adds no clock model or stimulus state machine.
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

library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;
use surf.PtpPkg.all;

entity PtpPhcWrapper is
   generic (
      TPD_G          : time     := 1 ns;
      RST_POLARITY_G : sl       := '1';
      RST_ASYNC_G    : boolean  := false;
      CLK_FREQ_G     : positive := 156250000);
   port (
      clk                  : in  sl;
      rst                  : in  sl;
      axil_awaddr          : in  slv(31 downto 0);
      axil_awvalid         : in  sl;
      axil_awready         : out sl;
      axil_wdata           : in  slv(31 downto 0);
      axil_wstrb           : in  slv(3 downto 0);
      axil_wvalid          : in  sl;
      axil_wready          : out sl;
      axil_bresp           : out slv(1 downto 0);
      axil_bvalid          : out sl;
      axil_bready          : in  sl;
      axil_araddr          : in  slv(31 downto 0);
      axil_arvalid         : in  sl;
      axil_arready         : out sl;
      axil_rdata           : out slv(31 downto 0);
      axil_rresp           : out slv(1 downto 0);
      axil_rvalid          : out sl;
      axil_rready          : in  sl;
      prepareConfig        : in  sl;
      applyConfig          : in  sl;
      configValid          : out sl;
      commandValid         : in  sl;
      commandReady         : out sl;
      commandKind          : in  slv(2 downto 0);
      commandGeneration    : in  slv(31 downto 0);
      commandSeconds       : in  slv(47 downto 0);
      commandNanoseconds   : in  slv(31 downto 0);
      commandFraction      : in  slv(31 downto 0);
      phaseSeconds         : in  slv(63 downto 0);
      phaseFraction        : in  slv(63 downto 0);
      commandRate          : in  slv(63 downto 0);
      commandValue         : in  sl;
      timeSeconds          : out slv(47 downto 0);
      timeNanoseconds      : out slv(31 downto 0);
      timeFraction         : out slv(31 downto 0);
      timeGeneration       : out slv(31 downto 0);
      timeTicks            : out slv(63 downto 0);
      timeIncrement        : out slv(63 downto 0);
      timeRate             : out slv(63 downto 0);
      timeValid            : out sl;
      commandAck           : out sl;
      commandError         : out sl;
      discontinuity        : out sl;
      fault                : out sl;
      pps                  : out sl;
      captureAbort         : out sl;
      readClk              : in  sl;
      readRst              : in  sl;
      readRequest          : in  sl;
      readReady            : out sl;
      readValid            : out sl;
      readSeconds          : out slv(47 downto 0);
      readNanoseconds      : out slv(31 downto 0);
      readFraction         : out slv(31 downto 0);
      readGeneration       : out slv(31 downto 0);
      readTicks            : out slv(63 downto 0);
      readTimeValid        : out sl;
      readSequence         : out slv(31 downto 0));
end entity PtpPhcWrapper;

architecture rtl of PtpPhcWrapper is

   signal resetN         : sl;
   signal axiReadMaster  : AxiLiteReadMasterType;
   signal axiReadSlave   : AxiLiteReadSlaveType;
   signal axiWriteMaster : AxiLiteWriteMasterType;
   signal axiWriteSlave  : AxiLiteWriteSlaveType;

   signal command      : PtpPhcCommandType;
   signal status       : PtpPhcStatusType;
   signal timeValue    : PtpTimeType;
   signal snapshot     : PtpTimeType;
   signal abortCapture : sl;
   signal resetHigh    : sl;

begin

   command         <=
   (
      kind          => commandKind,
      generation    => commandGeneration,
      setTime       => (seconds => commandSeconds, nanoseconds => commandNanoseconds, fraction => commandFraction),
      phaseSeconds  => phaseSeconds,
      phaseFraction => phaseFraction,
      rate          => commandRate,
      value         => commandValue
   );
   resetHigh       <= '1' when rst = RST_POLARITY_G else '0';
   resetN          <= not resetHigh;
   timeSeconds     <= timeValue.seconds;
   timeNanoseconds <= timeValue.nanoseconds;
   timeFraction    <= timeValue.fraction;
   timeGeneration  <= status.generation;
   timeTicks       <= status.ticks;
   timeIncrement   <= status.increment;
   timeRate        <= status.rate;
   timeValid       <= status.timeValid;
   discontinuity   <= status.discontinuity;
   fault           <= status.fault;
   captureAbort    <= abortCapture;
   readSeconds     <= snapshot.seconds;
   readNanoseconds <= snapshot.nanoseconds;
   readFraction    <= snapshot.fraction;

   U_Axi : entity surf.SlaveAxiLiteIpIntegrator
      generic map (
         ADDR_WIDTH    => 32,
         EN_ERROR_RESP => true,
         HAS_WSTRB     => 1,
         FREQ_HZ       => CLK_FREQ_G)
      port map (
         S_AXI_ACLK      => clk,             -- [in]
         S_AXI_ARESETN   => resetN,          -- [in]
         S_AXI_AWADDR    => axil_awaddr,     -- [in]
         S_AXI_AWPROT    => "000",           -- [in]
         S_AXI_AWVALID   => axil_awvalid,    -- [in]
         S_AXI_AWREADY   => axil_awready,    -- [out]
         S_AXI_WDATA     => axil_wdata,      -- [in]
         S_AXI_WSTRB     => axil_wstrb,      -- [in]
         S_AXI_WVALID    => axil_wvalid,     -- [in]
         S_AXI_WREADY    => axil_wready,     -- [out]
         S_AXI_BRESP     => axil_bresp,      -- [out]
         S_AXI_BVALID    => axil_bvalid,     -- [out]
         S_AXI_BREADY    => axil_bready,     -- [in]
         S_AXI_ARADDR    => axil_araddr,     -- [in]
         S_AXI_ARPROT    => "000",           -- [in]
         S_AXI_ARVALID   => axil_arvalid,    -- [in]
         S_AXI_ARREADY   => axil_arready,    -- [out]
         S_AXI_RDATA     => axil_rdata,      -- [out]
         S_AXI_RRESP     => axil_rresp,      -- [out]
         S_AXI_RVALID    => axil_rvalid,     -- [out]
         S_AXI_RREADY    => axil_rready,     -- [in]
         axilClk         => open,            -- [out]
         axilRst         => open,            -- [out]
         axilReadMaster  => axiReadMaster,   -- [out]
         axilReadSlave   => axiReadSlave,    -- [in]
         axilWriteMaster => axiWriteMaster,  -- [out]
         axilWriteSlave  => axiWriteSlave);  -- [in]

   U_DUT : entity surf.PtpPhc
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G,
         CLK_FREQ_G     => CLK_FREQ_G)
      port map (
         clk                   => clk,             -- [in]
         rst                   => rst,             -- [in]
         axiReadMaster         => axiReadMaster,   -- [in]
         axiReadSlave          => axiReadSlave,    -- [out]
         axiWriteMaster        => axiWriteMaster,  -- [in]
         axiWriteSlave         => axiWriteSlave,   -- [out]
         configControl.prepare => prepareConfig,   -- [in]
         configControl.apply   => applyConfig,     -- [in]
         configControl.busy    => '0',             -- [in]
         configValid           => configValid,     -- [out]
         servoEnable           => '1',             -- [in]
         commandMaster.data    => command,         -- [in]
         commandMaster.valid   => commandValid,    -- [in]
         commandMaster.cancel  => '0',             -- [in]
         commandMaster.stale   => '0',             -- [in]
         commandSlave.ready    => commandReady,    -- [out]
         commandSlave.ack      => commandAck,      -- [out]
         commandSlave.error    => commandError,    -- [out]
         phcTime               => timeValue,       -- [out]
         status                => status,          -- [out]
         pps                   => pps,             -- [out]
         captureAbort          => abortCapture);   -- [out]

   U_Read : entity surf.PtpPhcRead
      generic map (
         TPD_G => TPD_G)
      port map (
         phcClk         => clk,             -- [in]
         phcRst         => resetHigh,       -- [in]
         phcTime        => timeValue,       -- [in]
         phcStatus      => status,          -- [in]
         captureAbort   => abortCapture,    -- [in]
         readClk        => readClk,         -- [in]
         readRst        => readRst,         -- [in]
         readRequest    => readRequest,     -- [in]
         readReady      => readReady,       -- [out]
         readValid      => readValid,       -- [out]
         readTime       => snapshot,        -- [out]
         readGeneration => readGeneration,  -- [out]
         readTicks      => readTicks,       -- [out]
         readTimeValid  => readTimeValid,   -- [out]
         readSequence   => readSequence);   -- [out]

end architecture rtl;
