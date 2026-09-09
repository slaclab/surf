-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Flattened simulation wrapper for surf.AdcDdrPatternTester
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

entity AdcDdrPatternTesterWrapper is
   generic (
      TPD_G : time := 1 ns);
   port (
      clk           : in  sl;
      rst           : in  sl;
      S_AXI_AWADDR  : in  slv(11 downto 0);
      S_AXI_AWPROT  : in  slv(2 downto 0);
      S_AXI_AWVALID : in  sl;
      S_AXI_AWREADY : out sl;
      S_AXI_WDATA   : in  slv(31 downto 0);
      S_AXI_WSTRB   : in  slv(3 downto 0);
      S_AXI_WVALID  : in  sl;
      S_AXI_WREADY  : out sl;
      S_AXI_BRESP   : out slv(1 downto 0);
      S_AXI_BVALID  : out sl;
      S_AXI_BREADY  : in  sl;
      S_AXI_ARADDR  : in  slv(11 downto 0);
      S_AXI_ARPROT  : in  slv(2 downto 0);
      S_AXI_ARVALID : in  sl;
      S_AXI_ARREADY : out sl;
      S_AXI_RDATA   : out slv(31 downto 0);
      S_AXI_RRESP   : out slv(1 downto 0);
      S_AXI_RVALID  : out sl;
      S_AXI_RREADY  : in  sl;
      sampleValid   : in  sl;
      sampleIn      : in  slv(31 downto 0);
      fcoValid      : in  sl;
      fcoWord       : in  slv(13 downto 0));
end entity AdcDdrPatternTesterWrapper;

architecture rtl of AdcDdrPatternTesterWrapper is

   signal axilReadMaster  : AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
   signal axilReadSlave   : AxiLiteReadSlaveType   := AXI_LITE_READ_SLAVE_INIT_C;
   signal axilWriteMaster : AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
   signal axilWriteSlave  : AxiLiteWriteSlaveType  := AXI_LITE_WRITE_SLAVE_INIT_C;
   signal axiAResetN      : sl                     := '1';
   signal sampleArray     : Slv16Array(1 downto 0);
   signal fcoArray        : Slv16Array(0 downto 0);

begin

   axiAResetN <= not rst;

   U_ShimLayer : entity surf.SlaveAxiLiteIpIntegrator
      generic map (
         EN_ERROR_RESP => true,
         HAS_PROT      => 1,
         HAS_WSTRB     => 1,
         ADDR_WIDTH    => 12)
      port map (
         S_AXI_ACLK      => clk,             -- [in]
         S_AXI_ARESETN   => axiAResetN,      -- [in]
         S_AXI_AWADDR    => S_AXI_AWADDR,    -- [in]
         S_AXI_AWPROT    => S_AXI_AWPROT,    -- [in]
         S_AXI_AWVALID   => S_AXI_AWVALID,   -- [in]
         S_AXI_AWREADY   => S_AXI_AWREADY,   -- [out]
         S_AXI_WDATA     => S_AXI_WDATA,     -- [in]
         S_AXI_WSTRB     => S_AXI_WSTRB,     -- [in]
         S_AXI_WVALID    => S_AXI_WVALID,    -- [in]
         S_AXI_WREADY    => S_AXI_WREADY,    -- [out]
         S_AXI_BRESP     => S_AXI_BRESP,     -- [out]
         S_AXI_BVALID    => S_AXI_BVALID,    -- [out]
         S_AXI_BREADY    => S_AXI_BREADY,    -- [in]
         S_AXI_ARADDR    => S_AXI_ARADDR,    -- [in]
         S_AXI_ARPROT    => S_AXI_ARPROT,    -- [in]
         S_AXI_ARVALID   => S_AXI_ARVALID,   -- [in]
         S_AXI_ARREADY   => S_AXI_ARREADY,   -- [out]
         S_AXI_RDATA     => S_AXI_RDATA,     -- [out]
         S_AXI_RRESP     => S_AXI_RRESP,     -- [out]
         S_AXI_RVALID    => S_AXI_RVALID,    -- [out]
         S_AXI_RREADY    => S_AXI_RREADY,    -- [in]
         axilClk         => open,            -- [out]
         axilRst         => open,            -- [out]
         axilReadMaster  => axilReadMaster,  -- [out]
         axilReadSlave   => axilReadSlave,   -- [in]
         axilWriteMaster => axilWriteMaster, -- [out]
         axilWriteSlave  => axilWriteSlave); -- [in]

   sampleArray(0) <= sampleIn(15 downto 0);
   sampleArray(1) <= sampleIn(31 downto 16);
   fcoArray(0)    <= "00" & fcoWord;

   U_DUT : entity surf.AdcDdrPatternTester
      generic map (
         TPD_G                  => TPD_G,
         CHANNELS_G             => 2,
         FCO_LANES_G            => 1,
         SAMPLE_WIDTH_G         => 14,
         SERIALIZATION_FACTOR_G => 14,
         FRAME_PATTERN_G        => "11111110000000")
      port map (
         clk             => clk,             -- [in]
         rst             => rst,             -- [in]
         axilReadMaster  => axilReadMaster,  -- [in]
         axilReadSlave   => axilReadSlave,   -- [out]
         axilWriteMaster => axilWriteMaster, -- [in]
         axilWriteSlave  => axilWriteSlave,  -- [out]
         sampleValid     => sampleValid,     -- [in]
         sampleIn        => sampleArray,     -- [in]
         fcoValid        => (0 => fcoValid), -- [in]
         fcoWord         => fcoArray);       -- [in]

end architecture rtl;
