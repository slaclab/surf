-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing wrapper for surf.GtRxAlignCheck that flattens the
--              slave register-map and master DRP AXI-Lite records, and exposes
--              the DRP base address as an integer generic for stable test
--              parameterization under GHDL.
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

entity GtRxAlignCheckWrapper is
   generic (
      TPD_G          : time    := 1 ns;
      SIMULATION_G   : boolean := false;
      LOCK_VALUE_G   : integer := 16;
      MASK_VALUE_G   : integer := 126;
      GT_TYPE_G      : string  := "GTHE3";  -- or GTYE3, GTHE4, GTYE4
      DRP_ADDR_INT_G : natural := 0);
   port (
      -- Clock and Reset
      axilClk       : in  sl;
      axilRst       : in  sl;
      -- Clock Monitoring
      txClk         : in  sl;
      rxClk         : in  sl;
      refClk        : in  sl;
      -- GTH Status/Control Interface
      resetIn       : in  sl;
      resetOut      : out sl;
      resetDone     : in  sl;
      resetErr      : in  sl;
      locked        : out sl;
      -- Slave AXI-Lite Interface (register map)
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
      -- Master AXI-Lite Interface (DRP read path)
      M_AXI_AWADDR  : out slv(31 downto 0);
      M_AXI_AWPROT  : out slv(2 downto 0);
      M_AXI_AWVALID : out sl;
      M_AXI_AWREADY : in  sl;
      M_AXI_WDATA   : out slv(31 downto 0);
      M_AXI_WSTRB   : out slv(3 downto 0);
      M_AXI_WVALID  : out sl;
      M_AXI_WREADY  : in  sl;
      M_AXI_BRESP   : in  slv(1 downto 0);
      M_AXI_BVALID  : in  sl;
      M_AXI_BREADY  : out sl;
      M_AXI_ARADDR  : out slv(31 downto 0);
      M_AXI_ARPROT  : out slv(2 downto 0);
      M_AXI_ARVALID : out sl;
      M_AXI_ARREADY : in  sl;
      M_AXI_RDATA   : in  slv(31 downto 0);
      M_AXI_RRESP   : in  slv(1 downto 0);
      M_AXI_RVALID  : in  sl;
      M_AXI_RREADY  : out sl);
end entity GtRxAlignCheckWrapper;

architecture rtl of GtRxAlignCheckWrapper is

   -- Translate the cocotb-friendly integer generic into the DRP base address
   -- slv used by the underlying checker.
   constant DRP_ADDR_C : slv(31 downto 0) := toSlv(DRP_ADDR_INT_G, 32);

   signal axilAResetN : sl := '1';

   signal sAxilReadMaster  : AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
   signal sAxilReadSlave   : AxiLiteReadSlaveType   := AXI_LITE_READ_SLAVE_INIT_C;
   signal sAxilWriteMaster : AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
   signal sAxilWriteSlave  : AxiLiteWriteSlaveType  := AXI_LITE_WRITE_SLAVE_INIT_C;

   signal mAxilReadMaster  : AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
   signal mAxilReadSlave   : AxiLiteReadSlaveType   := AXI_LITE_READ_SLAVE_INIT_C;
   signal mAxilWriteMaster : AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
   signal mAxilWriteSlave  : AxiLiteWriteSlaveType  := AXI_LITE_WRITE_SLAVE_INIT_C;

begin

   ---------------------
   -- Input flattening
   ---------------------
   axilAResetN <= not axilRst;

   -----------------------------------------------------
   -- Shim layer: register map slave and DRP read master
   -----------------------------------------------------
   U_SlaveShim : entity surf.SlaveAxiLiteIpIntegrator
      generic map (
         INTERFACENAME => "S_AXI",
         EN_ERROR_RESP => true,
         HAS_PROT      => 1,
         HAS_WSTRB     => 1,
         ADDR_WIDTH    => 12)
      port map (
         S_AXI_ACLK      => axilClk,
         S_AXI_ARESETN   => axilAResetN,
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
         axilClk         => open,
         axilRst         => open,
         axilReadMaster  => sAxilReadMaster,
         axilReadSlave   => sAxilReadSlave,
         axilWriteMaster => sAxilWriteMaster,
         axilWriteSlave  => sAxilWriteSlave);

   U_MasterShim : entity surf.MasterAxiLiteIpIntegrator
      generic map (
         INTERFACENAME => "M_AXI",
         EN_ERROR_RESP => true,
         HAS_PROT      => 1,
         HAS_WSTRB     => 1,
         ADDR_WIDTH    => 32)
      port map (
         M_AXI_ACLK      => axilClk,
         M_AXI_ARESETN   => axilAResetN,
         M_AXI_AWADDR    => M_AXI_AWADDR,
         M_AXI_AWPROT    => M_AXI_AWPROT,
         M_AXI_AWVALID   => M_AXI_AWVALID,
         M_AXI_AWREADY   => M_AXI_AWREADY,
         M_AXI_WDATA     => M_AXI_WDATA,
         M_AXI_WSTRB     => M_AXI_WSTRB,
         M_AXI_WVALID    => M_AXI_WVALID,
         M_AXI_WREADY    => M_AXI_WREADY,
         M_AXI_BRESP     => M_AXI_BRESP,
         M_AXI_BVALID    => M_AXI_BVALID,
         M_AXI_BREADY    => M_AXI_BREADY,
         M_AXI_ARADDR    => M_AXI_ARADDR,
         M_AXI_ARPROT    => M_AXI_ARPROT,
         M_AXI_ARVALID   => M_AXI_ARVALID,
         M_AXI_ARREADY   => M_AXI_ARREADY,
         M_AXI_RDATA     => M_AXI_RDATA,
         M_AXI_RRESP     => M_AXI_RRESP,
         M_AXI_RVALID    => M_AXI_RVALID,
         M_AXI_RREADY    => M_AXI_RREADY,
         axilClk         => open,
         axilRst         => open,
         axilReadMaster  => mAxilReadMaster,
         axilReadSlave   => mAxilReadSlave,
         axilWriteMaster => mAxilWriteMaster,
         axilWriteSlave  => mAxilWriteSlave);

   ------------------------
   -- DUT instantiation
   ------------------------
   U_DUT : entity surf.GtRxAlignCheck
      generic map (
         TPD_G          => TPD_G,
         SIMULATION_G   => SIMULATION_G,
         LOCK_VALUE_G   => LOCK_VALUE_G,
         MASK_VALUE_G   => MASK_VALUE_G,
         GT_TYPE_G      => GT_TYPE_G,
         AXI_CLK_FREQ_G => 156.25E+6,
         DRP_ADDR_G     => DRP_ADDR_C)
      port map (
         -- Clock Monitoring
         txClk            => txClk,
         rxClk            => rxClk,
         refClk           => refClk,
         -- GTH Status/Control Interface
         resetIn          => resetIn,
         resetOut         => resetOut,
         resetDone        => resetDone,
         resetErr         => resetErr,
         locked           => locked,
         -- Clock and Reset
         axilClk          => axilClk,
         axilRst          => axilRst,
         -- Master AXI-Lite Interface
         mAxilReadMaster  => mAxilReadMaster,
         mAxilReadSlave   => mAxilReadSlave,
         mAxilWriteMaster => mAxilWriteMaster,
         mAxilWriteSlave  => mAxilWriteSlave,
         -- Slave AXI-Lite Interface
         sAxilReadMaster  => sAxilReadMaster,
         sAxilReadSlave   => sAxilReadSlave,
         sAxilWriteMaster => sAxilWriteMaster,
         sAxilWriteSlave  => sAxilWriteSlave);

end architecture rtl;
