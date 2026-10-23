-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing wrapper for surf.Saci2ToAxiLite integration
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
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;

entity Saci2ToAxiLiteWrapper is
   port (
      S_AXI_ACLK    : in  std_logic;
      S_AXI_ARESETN : in  std_logic;
      S_AXI_AWADDR  : in  std_logic_vector(31 downto 0);
      S_AXI_AWPROT  : in  std_logic_vector(2 downto 0);
      S_AXI_AWVALID : in  std_logic;
      S_AXI_AWREADY : out std_logic;
      S_AXI_WDATA   : in  std_logic_vector(31 downto 0);
      S_AXI_WSTRB   : in  std_logic_vector(3 downto 0);
      S_AXI_WVALID  : in  std_logic;
      S_AXI_WREADY  : out std_logic;
      S_AXI_BRESP   : out std_logic_vector(1 downto 0);
      S_AXI_BVALID  : out std_logic;
      S_AXI_BREADY  : in  std_logic;
      S_AXI_ARADDR  : in  std_logic_vector(31 downto 0);
      S_AXI_ARPROT  : in  std_logic_vector(2 downto 0);
      S_AXI_ARVALID : in  std_logic;
      S_AXI_ARREADY : out std_logic;
      S_AXI_RDATA   : out std_logic_vector(31 downto 0);
      S_AXI_RRESP   : out std_logic_vector(1 downto 0);
      S_AXI_RVALID  : out std_logic;
      S_AXI_RREADY  : in  std_logic);
end entity Saci2ToAxiLiteWrapper;

architecture rtl of Saci2ToAxiLiteWrapper is

   constant AXIL_CONFIG_C : AxiLiteCrossbarMasterConfigArray(0 downto 0) := (
      0               => (
         baseAddr     => x"0000_0000",
         addrBits     => 20,
         connectivity => x"FFFF"));

   signal fpgaAxilClk : sl;
   signal fpgaAxilRst : sl;

   signal fpgaAxilReadMaster  : AxiLiteReadMasterType;
   signal fpgaAxilReadSlave   : AxiLiteReadSlaveType;
   signal fpgaAxilWriteMaster : AxiLiteWriteMasterType;
   signal fpgaAxilWriteSlave  : AxiLiteWriteSlaveType;

   signal asicAxilClk : sl;
   signal asicAxilRst : sl;

   signal asicAxilReadMaster  : AxiLiteReadMasterType;
   signal asicAxilReadSlave   : AxiLiteReadSlaveType;
   signal asicAxilWriteMaster : AxiLiteWriteMasterType;
   signal asicAxilWriteSlave  : AxiLiteWriteSlaveType;

   signal memAxilReadMaster  : AxiLiteReadMasterType;
   signal memAxilReadSlave   : AxiLiteReadSlaveType;
   signal memAxilWriteMaster : AxiLiteWriteMasterType;
   signal memAxilWriteSlave  : AxiLiteWriteSlaveType;

   signal rstL : sl;

   signal saciClk    : sl;
   signal saciCmd    : sl;
   signal saciSelL   : slv(0 downto 0);
   signal saciRsp    : slv(0 downto 0);
   signal saciBusReq : sl;
   signal saciBusGr  : sl := '1';

begin

   ---------------------------------------------------------------------------
   -- AXI-Lite shim
   ---------------------------------------------------------------------------
   U_ShimLayer : entity surf.SlaveAxiLiteIpIntegrator
      generic map (
         EN_ERROR_RESP => true,
         FREQ_HZ       => 125000000,
         ADDR_WIDTH    => 32)
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
         axilClk         => fpgaAxilClk,
         axilRst         => fpgaAxilRst,
         axilReadMaster  => fpgaAxilReadMaster,
         axilReadSlave   => fpgaAxilReadSlave,
         axilWriteMaster => fpgaAxilWriteMaster,
         axilWriteSlave  => fpgaAxilWriteSlave);

   ---------------------------------------------------------------------------
   -- FPGA-side transport
   ---------------------------------------------------------------------------
   U_AxiLiteToSaci2 : entity surf.AxiLiteToSaci2
      generic map (
         TPD_G              => 1 ns,
         AXIL_CLK_PERIOD_G  => 8.0E-9,
         AXIL_TIMEOUT_G     => 1.0E-3,
         SACI_CLK_PERIOD_G  => 50.0E-9,
         SACI_CLK_FREERUN_G => false,
         SACI_NUM_CHIPS_G   => 1,
         SACI_RSP_BUSSED_G  => false)
      port map (
         saciClk         => saciClk,
         saciCmd         => saciCmd,
         saciSelL        => saciSelL,
         saciRsp         => saciRsp,
         saciBusReq      => saciBusReq,
         saciBusGr       => saciBusGr,
         axilClk         => fpgaAxilClk,
         axilRst         => fpgaAxilRst,
         axilReadMaster  => fpgaAxilReadMaster,
         axilReadSlave   => fpgaAxilReadSlave,
         axilWriteMaster => fpgaAxilWriteMaster,
         axilWriteSlave  => fpgaAxilWriteSlave);

   ---------------------------------------------------------------------------
   -- ASIC-side target and backing RAM
   ---------------------------------------------------------------------------
   U_ClkRst : entity surf.ClkRst
      generic map (
         CLK_PERIOD_G => 8.0 ns)
      port map (
         clkP => asicAxilClk,
         rst  => asicAxilRst,
         rstL => rstL);

   U_Saci2ToAxiLite : entity surf.Saci2ToAxiLite
      generic map (
         TPD_G => 1 ns)
      port map (
         rstL            => rstL,
         saciClk         => saciClk,
         saciCmd         => saciCmd,
         saciSelL        => saciSelL(0),
         saciRsp         => saciRsp(0),
         axilClk         => asicAxilClk,
         axilRst         => asicAxilRst,
         axilReadMaster  => asicAxilReadMaster,
         axilReadSlave   => asicAxilReadSlave,
         axilWriteMaster => asicAxilWriteMaster,
         axilWriteSlave  => asicAxilWriteSlave);

   U_Crossbar : entity surf.AxiLiteCrossbar
      generic map (
         NUM_SLAVE_SLOTS_G  => 1,
         NUM_MASTER_SLOTS_G => 1,
         MASTERS_CONFIG_G   => AXIL_CONFIG_C)
      port map (
         axiClk              => asicAxilClk,
         axiClkRst           => asicAxilRst,
         sAxiWriteMasters(0) => asicAxilWriteMaster,
         sAxiWriteSlaves(0)  => asicAxilWriteSlave,
         sAxiReadMasters(0)  => asicAxilReadMaster,
         sAxiReadSlaves(0)   => asicAxilReadSlave,
         mAxiWriteMasters(0) => memAxilWriteMaster,
         mAxiWriteSlaves(0)  => memAxilWriteSlave,
         mAxiReadMasters(0)  => memAxilReadMaster,
         mAxiReadSlaves(0)   => memAxilReadSlave);

   U_MEM : entity surf.AxiDualPortRam
      generic map (
         ADDR_WIDTH_G => 20,
         DATA_WIDTH_G => 32)
      port map (
         axiClk         => asicAxilClk,
         axiRst         => asicAxilRst,
         axiReadMaster  => memAxilReadMaster,
         axiReadSlave   => memAxilReadSlave,
         axiWriteMaster => memAxilWriteMaster,
         axiWriteSlave  => memAxilWriteSlave);

end architecture rtl;

