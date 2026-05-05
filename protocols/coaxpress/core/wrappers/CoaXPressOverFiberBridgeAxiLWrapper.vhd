-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing wrapper for CoaXPressOverFiberBridgeAxiL
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
use surf.CoaXPressPkg.all;

entity CoaXPressOverFiberBridgeAxiLWrapper is
   port (
      -- Bridge RX status clock domain
      rxClk               : in  sl;
      rxRst               : in  sl;
      rxError             : in  sl;
      rxAbort             : in  sl;
      rxErrorCode         : in  slv(3 downto 0);
      seqValid            : in  sl;
      seqData             : in  slv(23 downto 0);
      seqError            : in  sl;
      seqExpected         : in  slv(23 downto 0);
      seqErrorExpected    : in  slv(23 downto 0);
      hkpValid            : in  sl;
      hkpData             : in  slv(31 downto 0);
      hkpEop              : in  sl;
      hkpSof              : in  sl;
      hkpError            : in  sl;
      hkpWordCount        : in  slv(7 downto 0);
      hkpKCodeMask        : in  slv(3 downto 0);
      hkpKCodeValid       : in  sl;
      hkpType             : in  slv(3 downto 0);
      -- AXI-Lite Register Interface
      S_AXI_ACLK          : in  std_logic;
      S_AXI_ARESETN       : in  std_logic;
      S_AXI_AWADDR        : in  std_logic_vector(11 downto 0);
      S_AXI_AWPROT        : in  std_logic_vector(2 downto 0);
      S_AXI_AWVALID       : in  std_logic;
      S_AXI_AWREADY       : out std_logic;
      S_AXI_WDATA         : in  std_logic_vector(31 downto 0);
      S_AXI_WSTRB         : in  std_logic_vector(3 downto 0);
      S_AXI_WVALID        : in  std_logic;
      S_AXI_WREADY        : out std_logic;
      S_AXI_BRESP         : out std_logic_vector(1 downto 0);
      S_AXI_BVALID        : out std_logic;
      S_AXI_BREADY        : in  std_logic;
      S_AXI_ARADDR        : in  std_logic_vector(11 downto 0);
      S_AXI_ARPROT        : in  std_logic_vector(2 downto 0);
      S_AXI_ARVALID       : in  std_logic;
      S_AXI_ARREADY       : out std_logic;
      S_AXI_RDATA         : out std_logic_vector(31 downto 0);
      S_AXI_RRESP         : out std_logic_vector(1 downto 0);
      S_AXI_RVALID        : out std_logic;
      S_AXI_RREADY        : in  std_logic);
end entity CoaXPressOverFiberBridgeAxiLWrapper;

architecture mapping of CoaXPressOverFiberBridgeAxiLWrapper is

   signal axilClk         : sl;
   signal axilRst         : sl;
   signal axilReadMaster  : AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
   signal axilReadSlave   : AxiLiteReadSlaveType   := AXI_LITE_READ_SLAVE_INIT_C;
   signal axilWriteMaster : AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
   signal axilWriteSlave  : AxiLiteWriteSlaveType  := AXI_LITE_WRITE_SLAVE_INIT_C;

   signal rxStatus : CxpofRxStatusType := CXPOF_RX_STATUS_INIT_C;

begin

   rxStatus.rxError          <= rxError;
   rxStatus.rxAbort          <= rxAbort;
   rxStatus.rxErrorCode      <= rxErrorCode;
   rxStatus.seqValid         <= seqValid;
   rxStatus.seqData          <= seqData;
   rxStatus.seqError         <= seqError;
   rxStatus.seqExpected      <= seqExpected;
   rxStatus.seqErrorExpected <= seqErrorExpected;
   rxStatus.hkpValid         <= hkpValid;
   rxStatus.hkpData          <= hkpData;
   rxStatus.hkpEop           <= hkpEop;
   rxStatus.hkpSof           <= hkpSof;
   rxStatus.hkpError         <= hkpError;
   rxStatus.hkpWordCount     <= hkpWordCount;
   rxStatus.hkpKCodeMask     <= hkpKCodeMask;
   rxStatus.hkpKCodeValid    <= hkpKCodeValid;
   rxStatus.hkpType          <= hkpType;

   U_ShimLayer : entity surf.SlaveAxiLiteIpIntegrator
      generic map (
         INTERFACENAME => "S_AXI",
         HAS_PROT      => 1,
         HAS_WSTRB     => 1,
         ADDR_WIDTH    => 12)
      port map (
         S_AXI_ACLK      => S_AXI_ACLK,
         S_AXI_ARESETN   => S_AXI_ARESETN,
         S_AXI_AWADDR    => S_AXI_AWADDR,
         S_AXI_AWPROT    => S_AXI_AWPROT,
         S_AXI_AWVALID   => S_AXI_AWVALID,
         S_AXI_AWREADY   => S_AXI_AWREADY,
         S_AXI_WDATA     => S_AXI_WDATA,
         S_AXI_WSTRB     => S_AXI_WSTRB,
         S_AXI_WVALID    => S_AXI_WVALID,
         S_AXI_WREADY    => S_AXI_WREADY,
         S_AXI_BRESP     => S_AXI_BRESP,
         S_AXI_BVALID    => S_AXI_BVALID,
         S_AXI_BREADY    => S_AXI_BREADY,
         S_AXI_ARADDR    => S_AXI_ARADDR,
         S_AXI_ARPROT    => S_AXI_ARPROT,
         S_AXI_ARVALID   => S_AXI_ARVALID,
         S_AXI_ARREADY   => S_AXI_ARREADY,
         S_AXI_RDATA     => S_AXI_RDATA,
         S_AXI_RRESP     => S_AXI_RRESP,
         S_AXI_RVALID    => S_AXI_RVALID,
         S_AXI_RREADY    => S_AXI_RREADY,
         axilClk         => axilClk,
         axilRst         => axilRst,
         axilReadMaster  => axilReadMaster,
         axilReadSlave   => axilReadSlave,
         axilWriteMaster => axilWriteMaster,
         axilWriteSlave  => axilWriteSlave);

   U_DUT : entity surf.CoaXPressOverFiberBridgeAxiL
      generic map (
         TPD_G       => 1 ns,
         CNT_WIDTH_G => 16)
      port map (
         rxClk           => rxClk,
         rxRst           => rxRst,
         rxStatus        => rxStatus,
         axilClk         => axilClk,
         axilRst         => axilRst,
         axilReadMaster  => axilReadMaster,
         axilReadSlave   => axilReadSlave,
         axilWriteMaster => axilWriteMaster,
         axilWriteSlave  => axilWriteSlave);

end architecture mapping;
