-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: IP integrator wrapper for surf.AxiLiteCrossbar with two slave
--              ports and master ports left undriven at their EMPTY_* defaults
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

entity AxiLiteCrossbarTerminationIpIntegrator is
   port (
      -- Clock and reset shared by both slave ports
      S_AXI_ACLK     : in  std_logic;
      S_AXI_ARESETN  : in  std_logic;
      -- Slave port 0
      S0_AXI_AWADDR  : in  std_logic_vector(31 downto 0);
      S0_AXI_AWPROT  : in  std_logic_vector(2 downto 0);
      S0_AXI_AWVALID : in  std_logic;
      S0_AXI_AWREADY : out std_logic;
      S0_AXI_WDATA   : in  std_logic_vector(31 downto 0);
      S0_AXI_WSTRB   : in  std_logic_vector(3 downto 0);
      S0_AXI_WVALID  : in  std_logic;
      S0_AXI_WREADY  : out std_logic;
      S0_AXI_BRESP   : out std_logic_vector(1 downto 0);
      S0_AXI_BVALID  : out std_logic;
      S0_AXI_BREADY  : in  std_logic;
      S0_AXI_ARADDR  : in  std_logic_vector(31 downto 0);
      S0_AXI_ARPROT  : in  std_logic_vector(2 downto 0);
      S0_AXI_ARVALID : in  std_logic;
      S0_AXI_ARREADY : out std_logic;
      S0_AXI_RDATA   : out std_logic_vector(31 downto 0);
      S0_AXI_RRESP   : out std_logic_vector(1 downto 0);
      S0_AXI_RVALID  : out std_logic;
      S0_AXI_RREADY  : in  std_logic;
      -- Slave port 1
      S1_AXI_AWADDR  : in  std_logic_vector(31 downto 0);
      S1_AXI_AWPROT  : in  std_logic_vector(2 downto 0);
      S1_AXI_AWVALID : in  std_logic;
      S1_AXI_AWREADY : out std_logic;
      S1_AXI_WDATA   : in  std_logic_vector(31 downto 0);
      S1_AXI_WSTRB   : in  std_logic_vector(3 downto 0);
      S1_AXI_WVALID  : in  std_logic;
      S1_AXI_WREADY  : out std_logic;
      S1_AXI_BRESP   : out std_logic_vector(1 downto 0);
      S1_AXI_BVALID  : out std_logic;
      S1_AXI_BREADY  : in  std_logic;
      S1_AXI_ARADDR  : in  std_logic_vector(31 downto 0);
      S1_AXI_ARPROT  : in  std_logic_vector(2 downto 0);
      S1_AXI_ARVALID : in  std_logic;
      S1_AXI_ARREADY : out std_logic;
      S1_AXI_RDATA   : out std_logic_vector(31 downto 0);
      S1_AXI_RRESP   : out std_logic_vector(1 downto 0);
      S1_AXI_RVALID  : out std_logic;
      S1_AXI_RREADY  : in  std_logic);
end entity AxiLiteCrossbarTerminationIpIntegrator;

architecture mapping of AxiLiteCrossbarTerminationIpIntegrator is

   -- 0x0000: RAM, 0x1000: EMPTY_OK, 0x2000: EMPTY_SLVERR, 0x3000: EMPTY_DECERR, 0x4000: cascade
   constant NUM_AXIL_MASTERS_C : positive                                                        := 5;
   constant AXIL_XBAR_CONFIG_C : AxiLiteCrossbarMasterConfigArray(NUM_AXIL_MASTERS_C-1 downto 0) := genAxiLiteConfig(NUM_AXIL_MASTERS_C, x"0000_0000", 16, 12);

   -- 0x4000: RAM, 0x4800: EMPTY_SLVERR
   constant NUM_CASCADE_MASTERS_C : positive                                                           := 2;
   constant CASCADE_XBAR_CONFIG_C : AxiLiteCrossbarMasterConfigArray(NUM_CASCADE_MASTERS_C-1 downto 0) := genAxiLiteConfig(NUM_CASCADE_MASTERS_C, x"0000_4000", 12, 11);

   signal axilClk          : sl;
   signal axilRst          : sl;
   signal axilReadMasters  : AxiLiteReadMasterArray(1 downto 0);
   signal axilReadSlaves   : AxiLiteReadSlaveArray(1 downto 0);
   signal axilWriteMasters : AxiLiteWriteMasterArray(1 downto 0);
   signal axilWriteSlaves  : AxiLiteWriteSlaveArray(1 downto 0);

   -- Master ports 1 to 3 are never driven, so they keep these EMPTY_* defaults
   signal xbarReadMasters  : AxiLiteReadMasterArray(NUM_AXIL_MASTERS_C-1 downto 0);
   signal xbarReadSlaves   : AxiLiteReadSlaveArray(NUM_AXIL_MASTERS_C-1 downto 0) := (
      1      => AXI_LITE_READ_SLAVE_EMPTY_OK_C,
      2      => AXI_LITE_READ_SLAVE_EMPTY_SLVERR_C,
      3      => AXI_LITE_READ_SLAVE_EMPTY_DECERR_C,
      others => AXI_LITE_READ_SLAVE_EMPTY_SLVERR_C);
   signal xbarWriteMasters : AxiLiteWriteMasterArray(NUM_AXIL_MASTERS_C-1 downto 0);
   signal xbarWriteSlaves  : AxiLiteWriteSlaveArray(NUM_AXIL_MASTERS_C-1 downto 0) := (
      1      => AXI_LITE_WRITE_SLAVE_EMPTY_OK_C,
      2      => AXI_LITE_WRITE_SLAVE_EMPTY_SLVERR_C,
      3      => AXI_LITE_WRITE_SLAVE_EMPTY_DECERR_C,
      others => AXI_LITE_WRITE_SLAVE_EMPTY_SLVERR_C);

   -- Cascade master port 1 is never driven, so it keeps the EMPTY_SLVERR default
   signal cascadeReadMasters  : AxiLiteReadMasterArray(NUM_CASCADE_MASTERS_C-1 downto 0);
   signal cascadeReadSlaves   : AxiLiteReadSlaveArray(NUM_CASCADE_MASTERS_C-1 downto 0)  := (others => AXI_LITE_READ_SLAVE_EMPTY_SLVERR_C);
   signal cascadeWriteMasters : AxiLiteWriteMasterArray(NUM_CASCADE_MASTERS_C-1 downto 0);
   signal cascadeWriteSlaves  : AxiLiteWriteSlaveArray(NUM_CASCADE_MASTERS_C-1 downto 0) := (others => AXI_LITE_WRITE_SLAVE_EMPTY_SLVERR_C);

begin

   ----------------
   -- Shim layers
   ----------------
   U_ShimLayer0 : entity surf.SlaveAxiLiteIpIntegrator
      generic map (
         INTERFACENAME => "S0_AXI",
         EN_ERROR_RESP => true,
         FREQ_HZ       => 125000000,
         ADDR_WIDTH    => 32)
      port map (
         S_AXI_ACLK      => S_AXI_ACLK,
         S_AXI_ARESETN   => S_AXI_ARESETN,
         S_AXI_AWADDR    => S0_AXI_AWADDR,
         S_AXI_AWPROT    => S0_AXI_AWPROT,
         S_AXI_AWVALID   => S0_AXI_AWVALID,
         S_AXI_AWREADY   => S0_AXI_AWREADY,
         S_AXI_WDATA     => S0_AXI_WDATA,
         S_AXI_WSTRB     => S0_AXI_WSTRB,
         S_AXI_WVALID    => S0_AXI_WVALID,
         S_AXI_WREADY    => S0_AXI_WREADY,
         S_AXI_BRESP     => S0_AXI_BRESP,
         S_AXI_BVALID    => S0_AXI_BVALID,
         S_AXI_BREADY    => S0_AXI_BREADY,
         S_AXI_ARADDR    => S0_AXI_ARADDR,
         S_AXI_ARPROT    => S0_AXI_ARPROT,
         S_AXI_ARVALID   => S0_AXI_ARVALID,
         S_AXI_ARREADY   => S0_AXI_ARREADY,
         S_AXI_RDATA     => S0_AXI_RDATA,
         S_AXI_RRESP     => S0_AXI_RRESP,
         S_AXI_RVALID    => S0_AXI_RVALID,
         S_AXI_RREADY    => S0_AXI_RREADY,
         axilClk         => axilClk,
         axilRst         => axilRst,
         axilReadMaster  => axilReadMasters(0),
         axilReadSlave   => axilReadSlaves(0),
         axilWriteMaster => axilWriteMasters(0),
         axilWriteSlave  => axilWriteSlaves(0));

   U_ShimLayer1 : entity surf.SlaveAxiLiteIpIntegrator
      generic map (
         INTERFACENAME => "S1_AXI",
         EN_ERROR_RESP => true,
         FREQ_HZ       => 125000000,
         ADDR_WIDTH    => 32)
      port map (
         S_AXI_ACLK      => S_AXI_ACLK,
         S_AXI_ARESETN   => S_AXI_ARESETN,
         S_AXI_AWADDR    => S1_AXI_AWADDR,
         S_AXI_AWPROT    => S1_AXI_AWPROT,
         S_AXI_AWVALID   => S1_AXI_AWVALID,
         S_AXI_AWREADY   => S1_AXI_AWREADY,
         S_AXI_WDATA     => S1_AXI_WDATA,
         S_AXI_WSTRB     => S1_AXI_WSTRB,
         S_AXI_WVALID    => S1_AXI_WVALID,
         S_AXI_WREADY    => S1_AXI_WREADY,
         S_AXI_BRESP     => S1_AXI_BRESP,
         S_AXI_BVALID    => S1_AXI_BVALID,
         S_AXI_BREADY    => S1_AXI_BREADY,
         S_AXI_ARADDR    => S1_AXI_ARADDR,
         S_AXI_ARPROT    => S1_AXI_ARPROT,
         S_AXI_ARVALID   => S1_AXI_ARVALID,
         S_AXI_ARREADY   => S1_AXI_ARREADY,
         S_AXI_RDATA     => S1_AXI_RDATA,
         S_AXI_RRESP     => S1_AXI_RRESP,
         S_AXI_RVALID    => S1_AXI_RVALID,
         S_AXI_RREADY    => S1_AXI_RREADY,
         axilClk         => open,
         axilRst         => open,
         axilReadMaster  => axilReadMasters(1),
         axilReadSlave   => axilReadSlaves(1),
         axilWriteMaster => axilWriteMasters(1),
         axilWriteSlave  => axilWriteSlaves(1));

   ---------------------
   -- Primary crossbar
   ---------------------
   U_AXIL_XBAR : entity surf.AxiLiteCrossbar
      generic map (
         NUM_SLAVE_SLOTS_G  => 2,
         NUM_MASTER_SLOTS_G => NUM_AXIL_MASTERS_C,
         MASTERS_CONFIG_G   => AXIL_XBAR_CONFIG_C)
      port map (
         axiClk           => axilClk,
         axiClkRst        => axilRst,
         sAxiWriteMasters => axilWriteMasters,
         sAxiWriteSlaves  => axilWriteSlaves,
         sAxiReadMasters  => axilReadMasters,
         sAxiReadSlaves   => axilReadSlaves,
         mAxiWriteMasters => xbarWriteMasters,
         mAxiWriteSlaves  => xbarWriteSlaves,
         mAxiReadMasters  => xbarReadMasters,
         mAxiReadSlaves   => xbarReadSlaves);

   U_MEM : entity surf.AxiDualPortRam
      generic map (
         ADDR_WIDTH_G => 10,
         DATA_WIDTH_G => 32)
      port map (
         axiClk         => axilClk,
         axiRst         => axilRst,
         axiReadMaster  => xbarReadMasters(0),
         axiReadSlave   => xbarReadSlaves(0),
         axiWriteMaster => xbarWriteMasters(0),
         axiWriteSlave  => xbarWriteSlaves(0));

   ---------------------
   -- Cascade crossbar
   ---------------------
   U_CASCADE_XBAR : entity surf.AxiLiteCrossbar
      generic map (
         NUM_SLAVE_SLOTS_G  => 1,
         NUM_MASTER_SLOTS_G => NUM_CASCADE_MASTERS_C,
         MASTERS_CONFIG_G   => CASCADE_XBAR_CONFIG_C)
      port map (
         axiClk              => axilClk,
         axiClkRst           => axilRst,
         sAxiWriteMasters(0) => xbarWriteMasters(4),
         sAxiWriteSlaves(0)  => xbarWriteSlaves(4),
         sAxiReadMasters(0)  => xbarReadMasters(4),
         sAxiReadSlaves(0)   => xbarReadSlaves(4),
         mAxiWriteMasters    => cascadeWriteMasters,
         mAxiWriteSlaves     => cascadeWriteSlaves,
         mAxiReadMasters     => cascadeReadMasters,
         mAxiReadSlaves      => cascadeReadSlaves);

   U_CASCADE_MEM : entity surf.AxiDualPortRam
      generic map (
         ADDR_WIDTH_G => 9,
         DATA_WIDTH_G => 32)
      port map (
         axiClk         => axilClk,
         axiRst         => axilRst,
         axiReadMaster  => cascadeReadMasters(0),
         axiReadSlave   => cascadeReadSlaves(0),
         axiWriteMaster => cascadeWriteMasters(0),
         axiWriteSlave  => cascadeWriteSlaves(0));

end architecture mapping;
