-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Thin PTP register/PHC adapter with controllable command backpressure
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

entity PtpRegWrapper is
   port (
      clk                  : in  sl;
      rst                  : in  sl;
      regRst               : in  sl;
      commandBlock         : in  sl;
      localMac             : in  slv(47 downto 0);
      axil_awaddr          : in  slv(11 downto 0);
      axil_awvalid         : in  sl;
      axil_awready         : out sl;
      axil_wdata           : in  slv(31 downto 0);
      axil_wstrb           : in  slv(3 downto 0);
      axil_wvalid          : in  sl;
      axil_wready          : out sl;
      axil_bresp           : out slv(1 downto 0);
      axil_bvalid          : out sl;
      axil_bready          : in  sl;
      axil_araddr          : in  slv(11 downto 0);
      axil_arvalid         : in  sl;
      axil_arready         : out sl;
      axil_rdata           : out slv(31 downto 0);
      axil_rresp           : out slv(1 downto 0);
      axil_rvalid          : out sl;
      axil_rready          : in  sl;
      activeLocal          : out slv(79 downto 0);
      activeSource         : out slv(79 downto 0);
      activeEnable         : out sl;
      activeServo          : out sl;
      configRestart        : out sl;
      timeSeconds          : out slv(47 downto 0);
      timeNanoseconds      : out slv(31 downto 0);
      timeFraction         : out slv(31 downto 0);
      timeTicks            : out slv(63 downto 0);
      timeGeneration       : out slv(31 downto 0);
      timeValid            : out sl;
      commandValid         : out sl;
      commandPhaseSeconds  : out slv(63 downto 0);
      commandPhaseFraction : out slv(63 downto 0);
      irq                  : out sl);
end entity PtpRegWrapper;

architecture rtl of PtpRegWrapper is

   signal resetN        : sl;
   signal readMaster    : AxiLiteReadMasterType;
   signal readSlave     : AxiLiteReadSlaveType;
   signal writeMaster   : AxiLiteWriteMasterType;
   signal writeSlave    : AxiLiteWriteSlaveType;
   signal config        : PtpConfigType;
   signal timeValue     : PtpTimeType;
   signal status        : PtpPhcStatusType;
   signal command       : PtpPhcCommandType;
   signal valid         : sl;
   signal ready         : sl;
   signal acceptedValid : sl;
   signal acceptedReady : sl;
   signal captureAbort  : sl;

begin

   resetN <= not rst;

   U_Axi : entity surf.SlaveAxiLiteIpIntegrator
      generic map (
         ADDR_WIDTH    => 12,
         EN_ERROR_RESP => true,
         HAS_WSTRB     => 1,
         FREQ_HZ       => 125000000)
      port map (
         S_AXI_ACLK      => clk,           -- [in]
         S_AXI_ARESETN   => resetN,        -- [in]
         S_AXI_AWADDR    => axil_awaddr,   -- [in]
         S_AXI_AWPROT    => "000",         -- [in]
         S_AXI_AWVALID   => axil_awvalid,  -- [in]
         S_AXI_AWREADY   => axil_awready,  -- [out]
         S_AXI_WDATA     => axil_wdata,    -- [in]
         S_AXI_WSTRB     => axil_wstrb,    -- [in]
         S_AXI_WVALID    => axil_wvalid,   -- [in]
         S_AXI_WREADY    => axil_wready,   -- [out]
         S_AXI_BRESP     => axil_bresp,    -- [out]
         S_AXI_BVALID    => axil_bvalid,   -- [out]
         S_AXI_BREADY    => axil_bready,   -- [in]
         S_AXI_ARADDR    => axil_araddr,   -- [in]
         S_AXI_ARPROT    => "000",         -- [in]
         S_AXI_ARVALID   => axil_arvalid,  -- [in]
         S_AXI_ARREADY   => axil_arready,  -- [out]
         S_AXI_RDATA     => axil_rdata,    -- [out]
         S_AXI_RRESP     => axil_rresp,    -- [out]
         S_AXI_RVALID    => axil_rvalid,   -- [out]
         S_AXI_RREADY    => axil_rready,   -- [in]
         axilClk         => open,          -- [out]
         axilRst         => open,          -- [out]
         axilReadMaster  => readMaster,    -- [out]
         axilReadSlave   => readSlave,     -- [in]
         axilWriteMaster => writeMaster,   -- [out]
         axilWriteSlave  => writeSlave);   -- [in]

   acceptedValid <= valid and not commandBlock;
   acceptedReady <= ready and not commandBlock;

   U_DUT : entity surf.PtpReg
      generic map (
         CLK_FREQ_G        => 125000000,
         PACKET_LIFETIME_G => 5000,
         INGRESS_LATENCY_G => x"FFFFFFFFFFFF0000",
         EGRESS_LATENCY_G  => x"0000000000020000")
      port map (
         clk                 => clk,                          -- [in]
         rst                 => rst,                          -- [in]
         regRst              => regRst,                       -- [in]
         axiReadMaster       => readMaster,                   -- [in]
         axiReadSlave        => readSlave,                    -- [out]
         axiWriteMaster      => writeMaster,                  -- [in]
         axiWriteSlave       => writeSlave,                   -- [out]
         localMac            => localMac,                     -- [in]
         config              => config,                       -- [out]
         configRestart       => configRestart,                -- [out]
         phcTime             => timeValue,                    -- [in]
         phcStatus           => status,                       -- [in]
         captureAbort        => captureAbort,                 -- [in]
         command             => command,                      -- [out]
         commandValid        => valid,                        -- [out]
         commandReady        => acceptedReady,                -- [in]
         commandAck          => status.ack,                   -- [in]
         commandError        => status.error,                 -- [in]
         portActive          => '0',                          -- [in]
         servoState          => "000",                        -- [in]
         filteredDelay       => (others => '0'),              -- [in]
         offsetValue         => (others => '0'),              -- [in]
         ratePpb             => (others => '0'),              -- [in]
         filterCount         => "000",                        -- [in]
         exchange            => PTP_EXCHANGE_INIT_C,          -- [in]
         announceBody        => (others => '0'),              -- [in]
         ledgerStatus        => (others => '0'),              -- [in]
         announceValid       => '0',                          -- [in]
         grandmasterIdentity => (others => '0'),              -- [in]
         announceFlags       => (others => '0'),              -- [in]
         utcOffset           => (others => '0'),              -- [in]
         counters            => (others => (others => '0')),  -- [in]
         irq                 => irq);                         -- [out]

   U_Phc : entity surf.PtpPhc
      generic map (
         CLK_FREQ_G => 125000000)
      port map (
         clk          => clk,               -- [in]
         rst          => rst,               -- [in]
         monotonic    => config.monotonic,  -- [in]
         command      => command,           -- [in]
         commandValid => acceptedValid,     -- [in]
         commandReady => ready,             -- [out]
         phcTime      => timeValue,         -- [out]
         status       => status,            -- [out]
         captureAbort => captureAbort,      -- [out]
         pps          => open);             -- [out]

   activeLocal          <= config.localIdentity;
   activeSource         <= config.sourceIdentity;
   activeEnable         <= config.enable;
   activeServo          <= config.servoEnable;
   timeSeconds          <= timeValue.seconds;
   timeNanoseconds      <= timeValue.nanoseconds;
   timeFraction         <= timeValue.fraction;
   timeTicks            <= status.ticks;
   timeGeneration       <= status.generation;
   timeValid            <= status.timeValid;
   commandValid         <= valid;
   commandPhaseSeconds  <= command.phaseSeconds;
   commandPhaseFraction <= command.phaseFraction;

end architecture rtl;
