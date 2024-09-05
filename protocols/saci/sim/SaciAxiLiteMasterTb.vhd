-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: surf.AxiLiteCrossbar cocoTB testbed
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

entity SaciAxiLiteMasterTb is
   port (
      -- AXI-Lite Interface
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
end SaciAxiLiteMasterTb;

architecture mapping of SaciAxiLiteMasterTb is

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

   signal rstL : sl;

   signal saciClk    : sl;
   signal saciCmd    : sl;
   signal saciSelL   : slv(0 downto 0);
   signal saciRsp    : slv(0 downto 0);
   signal saciBusReq : sl;
   signal saciBusGr  : sl := '1';

begin

   U_ShimLayer : entity surf.SlaveAxiLiteIpIntegrator
      generic map (
         EN_ERROR_RESP => true,
         FREQ_HZ       => 125000000,
         ADDR_WIDTH    => 32)
      port map (
         -- IP Integrator AXI-Lite Interface
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
         -- SURF AXI-Lite Interface
         axilClk         => fpgaAxilClk,
         axilRst         => fpgaAxilRst,
         axilReadMaster  => fpgaAxilReadMaster,
         axilReadSlave   => fpgaAxilReadSlave,
         axilWriteMaster => fpgaAxilWriteMaster,
         axilWriteSlave  => fpgaAxilWriteSlave);

   -------------------------------------------------------------------------------------------------
   -- FPGA Side
   -------------------------------------------------------------------------------------------------
   U_AxiLiteSaciMaster_1 : entity surf.AxiLiteSaciMaster
      generic map (
         TPD_G              => 1 ns,
         AXIL_CLK_PERIOD_G  => 125.0e6,
         AXIL_TIMEOUT_G     => AXIL_TIMEOUT_G,
         AXIL_TIMEOUT_G     => 1.0e-3,
         SACI_CLK_PERIOD_G  => 1.0e-6,
         SACI_CLK_FREERUN_G => false,
         SACI_NUM_CHIPS_G   => 1,
         SACI_RSP_BUSSED_G  => false)
      port map (
         saciClk         => saciClk,              -- [out]
         saciCmd         => saciCmd,              -- [out]
         saciSelL        => saciSelL,             -- [out]
         saciRsp         => saciRsp,              -- [in]
         saciBusReq      => saciBusReq,           -- [out]
         saciBusGr       => saciBusGr,            -- [in]
         axilClk         => fpgaAxilClk,          -- [in]
         axilRst         => fpgaAxilRst,          -- [in]
         axilReadMaster  => fpgaAxilReadMaster,   -- [in]
         axilReadSlave   => fpgaAxilReadSlave,    -- [out]
         axilWriteMaster => fpgaAxilWriteMaster,  -- [in]
         axilWriteSlave  => fpgaAxilWriteSlave);  -- [out]

   -------------------------------------------------------------------------------------------------
   -- ASIC side
   -------------------------------------------------------------------------------------------------
   U_ClkRst_1 : entity surf.ClkRst
      generic map (
         CLK_PERIOD_G => 8.0 ns)
      port map (
         clkP => asicAxilClk,           -- [out]
         rst  => asicAxilRst,           -- [out]
         rstL => rstL);                 -- [out]

   U_SaciAxiLiteMaster_1 : entity surf.SaciAxiLiteMaster
      generic map (
         TPD_G => 1 ns)
      port map (
         rstL            => rstL,                 -- [in]
         saciClk         => saciClk,              -- [in]
         saciCmd         => saciCmd,              -- [in]
         saciSelL        => saciSelL(0),          -- [in]
         saciRsp         => saciRsp(0),           -- [out]
         axilClk         => asicAxilClk,          -- [in]
         axilRst         => asicAxilRst,          -- [in]
         axilReadMaster  => asicAxilReadMaster,   -- [in]
         axilReadSlave   => asicAxilReadSlave,    -- [out]
         axilWriteMaster => asicAxilWriteMaster,  -- [in]
         axilWriteSlave  => asicAxilWriteSlave);  -- [out]


   U_MEM : entity surf.AxiDualPortRam
      generic map (
         ADDR_WIDTH_G => 22,
         DATA_WIDTH_G => 32)
      port map (
         -- Axi Port
         axiClk         => asicAxilClk,
         axiRst         => asicAxilRst,
         axiReadMaster  => asicAxilReadMaster,
         axiReadSlave   => asicAxilReadSlave,
         axiWriteMaster => asicAxilWriteMaster,
         axiWriteSlave  => asicAxilWriteSlave);


end mapping;
