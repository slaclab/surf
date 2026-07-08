-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Generic cocotb-facing wrapper for single-channel FIR
--              configurations that use external AXI-Lite coefficient access.
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

entity FirFilterSingleChannelWrapper is
   generic (
      NUM_TAPS_G       : positive               := 3;
      SIDEBAND_WIDTH_G : positive               := 1;
      DATA_WIDTH_G     : positive               := 8;
      COEFF_WIDTH_G    : positive range 1 to 32 := 4);
   port (
      clk           : in  sl;
      rst           : in  sl;
      ibValid       : in  sl;
      ibReady       : out sl;
      din           : in  slv(DATA_WIDTH_G-1 downto 0);
      sbIn          : in  slv(SIDEBAND_WIDTH_G-1 downto 0);
      obValid       : out sl;
      obReady       : in  sl;
      dout          : out slv(DATA_WIDTH_G-1 downto 0);
      sbOut         : out slv(SIDEBAND_WIDTH_G-1 downto 0);
      S_AXI_ACLK    : in  std_logic;
      S_AXI_ARESETN : in  std_logic;
      S_AXI_AWADDR  : in  std_logic_vector(8 downto 0);
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
      S_AXI_ARADDR  : in  std_logic_vector(8 downto 0);
      S_AXI_ARPROT  : in  std_logic_vector(2 downto 0);
      S_AXI_ARVALID : in  std_logic;
      S_AXI_ARREADY : out std_logic;
      S_AXI_RDATA   : out std_logic_vector(31 downto 0);
      S_AXI_RRESP   : out std_logic_vector(1 downto 0);
      S_AXI_RVALID  : out std_logic;
      S_AXI_RREADY  : in  std_logic);
end entity FirFilterSingleChannelWrapper;

architecture rtl of FirFilterSingleChannelWrapper is

   constant ZERO_COEFFICIENTS_C : IntegerArray(0 to NUM_TAPS_G-1) := (others => 0);

   signal axilClkSig      : sl;
   signal axilRstSig      : sl;
   signal axilReadMaster  : AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
   signal axilReadSlave   : AxiLiteReadSlaveType   := AXI_LITE_READ_SLAVE_INIT_C;
   signal axilWriteMaster : AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
   signal axilWriteSlave  : AxiLiteWriteSlaveType  := AXI_LITE_WRITE_SLAVE_INIT_C;

begin

   U_AXIL : entity surf.SlaveAxiLiteIpIntegrator
      generic map (
         ADDR_WIDTH => 9,
         HAS_PROT   => 1,
         HAS_WSTRB  => 1)
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
         axilClk         => axilClkSig,
         axilRst         => axilRstSig,
         axilReadMaster  => axilReadMaster,
         axilReadSlave   => axilReadSlave,
         axilWriteMaster => axilWriteMaster,
         axilWriteSlave  => axilWriteSlave);

   U_DUT : entity surf.FirFilterSingleChannel
      generic map (
         COMMON_CLK_G      => true,
         NUM_TAPS_G        => NUM_TAPS_G,
         SIDEBAND_WIDTH_G  => SIDEBAND_WIDTH_G,
         IBREADY_DEFAULT_G => '1',
         DATA_WIDTH_G      => DATA_WIDTH_G,
         COEFF_WIDTH_G     => COEFF_WIDTH_G,
         COEFFICIENTS_G    => ZERO_COEFFICIENTS_C)
      port map (
         clk             => clk,
         rst             => rst,
         ibValid         => ibValid,
         ibReady         => ibReady,
         din             => din,
         sbIn            => sbIn,
         obValid         => obValid,
         obReady         => obReady,
         dout            => dout,
         sbOut           => sbOut,
         axilClk         => axilClkSig,
         axilRst         => axilRstSig,
         axilReadMaster  => axilReadMaster,
         axilReadSlave   => axilReadSlave,
         axilWriteMaster => axilWriteMaster,
         axilWriteSlave  => axilWriteSlave);

end architecture rtl;
