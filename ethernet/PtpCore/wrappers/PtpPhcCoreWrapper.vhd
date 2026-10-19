-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Flattened PtpPhcCore verification interface.
--
-- Exposes the standalone PHC subsystem: one AXI-Lite slave through the
-- standard IP-integrator adapter (on axilClk when COMMON_CLK_G = false,
-- otherwise on clk), the external command client fields packed into
-- PtpPhcCommandMasterType, lifecycle inputs and the unpacked live clock tuple,
-- status pulses, owner, PPS and IRQ. Local coordination is selected; the
-- enclosing-coordinator path is exercised through the endpoint fixtures. The
-- wrapper adds no stimulus or clock model.
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

entity PtpPhcCoreWrapper is
   generic (
      TPD_G            : time             := 1 ns;
      AXIL_BASE_ADDR_G : slv(31 downto 0) := (others => '0');
      CLK_FREQ_G       : positive         := 125000000;
      COMMON_CLK_G     : boolean          := true;
      EXT_COMMAND_EN_G : boolean          := true);
   port (
      -- Management clock domain (unused when COMMON_CLK_G = true)
      axilClk      : in  sl;
      axilRst      : in  sl;
      axil_awaddr  : in  slv(31 downto 0);
      axil_awvalid : in  sl;
      axil_awready : out sl;
      axil_wdata   : in  slv(31 downto 0);
      axil_wstrb   : in  slv(3 downto 0);
      axil_wvalid  : in  sl;
      axil_wready  : out sl;
      axil_bresp   : out slv(1 downto 0);
      axil_bvalid  : out sl;
      axil_bready  : in  sl;
      axil_araddr  : in  slv(31 downto 0);
      axil_arvalid : in  sl;
      axil_arready : out sl;
      axil_rdata   : out slv(31 downto 0);
      axil_rresp   : out slv(1 downto 0);
      axil_rvalid  : out sl;
      axil_rready  : in  sl;

      -- PHC clock domain and lifecycle (active-high resets)
      clk          : in  sl;
      rst          : in  sl;
      regRst       : in  sl;
      restart      : in  sl;
      commandAbort : in  sl;

      -- External command client
      commandValid       : in  sl;
      commandCancel      : in  sl;
      commandStale       : in  sl;
      commandKind        : in  slv(2 downto 0);
      commandGeneration  : in  slv(31 downto 0);
      commandSeconds     : in  slv(47 downto 0);
      commandNanoseconds : in  slv(31 downto 0);
      commandFraction    : in  slv(31 downto 0);
      phaseSeconds       : in  slv(63 downto 0);
      phaseFraction      : in  slv(63 downto 0);
      commandRate        : in  slv(63 downto 0);
      commandValue       : in  sl;
      commandReady       : out sl;
      commandAck         : out sl;
      commandError       : out sl;
      clearValid         : in  sl;
      externalOwner      : out sl;

      -- Participant handshakes (local coordination)
      configPrepared : out sl;
      configValid    : out sl;
      manualBusy     : out sl;

      -- Live clock tuple, status pulses, PPS and IRQ
      timeSeconds     : out slv(47 downto 0);
      timeNanoseconds : out slv(31 downto 0);
      timeFraction    : out slv(31 downto 0);
      timeGeneration  : out slv(31 downto 0);
      timeTicks       : out slv(63 downto 0);
      timeIncrement   : out slv(63 downto 0);
      timeRate        : out slv(63 downto 0);
      timeValid       : out sl;
      statusAck       : out sl;
      statusError     : out sl;
      discontinuity   : out sl;
      fault           : out sl;
      captureAbort    : out sl;
      pps             : out sl;
      irq             : out sl);
end entity PtpPhcCoreWrapper;

architecture mapping of PtpPhcCoreWrapper is

   signal busClk         : sl;
   signal busRst         : sl;
   signal busRstN        : sl;
   signal axiReadMaster  : AxiLiteReadMasterType;
   signal axiReadSlave   : AxiLiteReadSlaveType;
   signal axiWriteMaster : AxiLiteWriteMasterType;
   signal axiWriteSlave  : AxiLiteWriteSlaveType;
   signal commandMaster  : PtpPhcCommandMasterType;
   signal commandSlave   : PtpPhcCommandSlaveType;
   signal timeValue      : PtpTimeType;
   signal status         : PtpPhcStatusType;

begin

   GEN_COMMON : if COMMON_CLK_G generate
      busClk <= clk;
      busRst <= rst;
   end generate GEN_COMMON;

   GEN_ASYNC : if not COMMON_CLK_G generate
      busClk <= axilClk;
      busRst <= axilRst;
   end generate GEN_ASYNC;

   busRstN <= not busRst;

   commandMaster.data.kind                <= commandKind;
   commandMaster.data.generation          <= commandGeneration;
   commandMaster.data.setTime.seconds     <= commandSeconds;
   commandMaster.data.setTime.nanoseconds <= commandNanoseconds;
   commandMaster.data.setTime.fraction    <= commandFraction;
   commandMaster.data.phaseSeconds        <= phaseSeconds;
   commandMaster.data.phaseFraction       <= phaseFraction;
   commandMaster.data.rate                <= commandRate;
   commandMaster.data.value               <= commandValue;
   commandMaster.valid                    <= commandValid;
   commandMaster.cancel                   <= commandCancel;
   commandMaster.stale                    <= commandStale;

   commandReady    <= commandSlave.ready;
   commandAck      <= commandSlave.ack;
   commandError    <= commandSlave.error;
   timeSeconds     <= timeValue.seconds;
   timeNanoseconds <= timeValue.nanoseconds;
   timeFraction    <= timeValue.fraction;
   timeGeneration  <= status.generation;
   timeTicks       <= status.ticks;
   timeIncrement   <= status.increment;
   timeRate        <= status.rate;
   timeValid       <= status.timeValid;
   statusAck       <= status.ack;
   statusError     <= status.error;
   discontinuity   <= status.discontinuity;
   fault           <= status.fault;

   U_Axi : entity surf.SlaveAxiLiteIpIntegrator
      generic map (
         ADDR_WIDTH    => 32,
         EN_ERROR_RESP => true,
         HAS_WSTRB     => 1,
         FREQ_HZ       => CLK_FREQ_G)
      port map (
         S_AXI_ACLK      => busClk,          -- [in]
         S_AXI_ARESETN   => busRstN,         -- [in]
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

   U_DUT : entity surf.PtpPhcCore
      generic map (
         TPD_G            => TPD_G,
         AXIL_BASE_ADDR_G => AXIL_BASE_ADDR_G,
         CLK_FREQ_G       => CLK_FREQ_G,
         COMMON_CLK_G     => COMMON_CLK_G,
         EXT_COMMAND_EN_G => EXT_COMMAND_EN_G)
      port map (
         axilClk          => axilClk,         -- [in]
         axilRst          => axilRst,         -- [in]
         axiReadMaster    => axiReadMaster,   -- [in]
         axiReadSlave     => axiReadSlave,    -- [out]
         axiWriteMaster   => axiWriteMaster,  -- [in]
         axiWriteSlave    => axiWriteSlave,   -- [out]
         clk              => clk,             -- [in]
         rst              => rst,             -- [in]
         regRst           => regRst,          -- [in]
         restart          => restart,         -- [in]
         commandAbort     => commandAbort,    -- [in]
         commandMaster    => commandMaster,   -- [in]
         commandSlave     => commandSlave,    -- [out]
         clearValid       => clearValid,      -- [in]
         externalOwner    => externalOwner,   -- [out]
         configPrepared   => configPrepared,  -- [out]
         configValid      => configValid,     -- [out]
         snapshotPrepared => open,            -- [out]
         manualBusy       => manualBusy,      -- [out]
         phcTime          => timeValue,       -- [out]
         phcStatus        => status,          -- [out]
         captureAbort     => captureAbort,    -- [out]
         pps              => pps,             -- [out]
         irq              => irq);            -- [out]

end architecture mapping;
