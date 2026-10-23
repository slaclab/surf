-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing loopback wrapper -- instantiates Jesd204bTx and
--              Jesd204bRx with GT and nSync paths EXPOSED as ports for bench
--              forwarding. Two independent AXI-Lite slave buses (TX prefix
--              S_AXI_TX_*, RX prefix S_AXI_RX_*). Python bench forwards
--              r_jesdGtTxArr -> r_jesdGtRxArr each devClk cycle.
--              Separate nSync ports: nSync_RX_o (from Jesd204bRx) and
--              nSync_TX_i (to Jesd204bTx) for Python-forwarded nSync path.
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
use ieee.numeric_std.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;
use surf.Jesd204bPkg.all;

entity Jesd204bLoopbackWrapper is
   generic (
      TPD_G      : time                   := 1 ns;
      F_G        : positive               := 2;
      K_G        : positive               := 32;
      L_G        : positive range 1 to 16 := 2;  -- capped at 16
      -- ILAS generics forwarded to U_Tx only (all defaulted):
      DID_G      : slv(7 downto 0)        := (others => '0');
      BID_G      : slv(3 downto 0)        := (others => '0');
      M_G        : slv(7 downto 0)        := (others => '0');
      N_G        : slv(4 downto 0)        := (others => '0');
      NPRIME_G   : slv(4 downto 0)        := (others => '0');
      CS_G       : slv(1 downto 0)        := (others => '0');
      S_G        : slv(4 downto 0)        := (others => '0');
      HD_G       : sl                     := '0';
      CF_G       : slv(4 downto 0)        := (others => '0');
      ADDR_WIDTH : positive               := 12);
   port (
      -- Shared device clock domain
      devClk_i          : in  sl;
      devRst_i          : in  sl;
      sysRef_i          : in  sl;
      -- TX AXI-Lite slave bus (S_AXI_TX_* prefix for cocotbext-axi auto-discovery)
      S_AXI_TX_ACLK     : in  std_logic;
      S_AXI_TX_ARESETN  : in  std_logic;
      S_AXI_TX_AWADDR   : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
      S_AXI_TX_AWPROT   : in  std_logic_vector(2 downto 0);
      S_AXI_TX_AWVALID  : in  std_logic;
      S_AXI_TX_AWREADY  : out std_logic;
      S_AXI_TX_WDATA    : in  std_logic_vector(31 downto 0);
      S_AXI_TX_WSTRB    : in  std_logic_vector(3 downto 0);
      S_AXI_TX_WVALID   : in  std_logic;
      S_AXI_TX_WREADY   : out std_logic;
      S_AXI_TX_BRESP    : out std_logic_vector(1 downto 0);
      S_AXI_TX_BVALID   : out std_logic;
      S_AXI_TX_BREADY   : in  std_logic;
      S_AXI_TX_ARADDR   : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
      S_AXI_TX_ARPROT   : in  std_logic_vector(2 downto 0);
      S_AXI_TX_ARVALID  : in  std_logic;
      S_AXI_TX_ARREADY  : out std_logic;
      S_AXI_TX_RDATA    : out std_logic_vector(31 downto 0);
      S_AXI_TX_RRESP    : out std_logic_vector(1 downto 0);
      S_AXI_TX_RVALID   : out std_logic;
      S_AXI_TX_RREADY   : in  std_logic;
      -- RX AXI-Lite slave bus (S_AXI_RX_* prefix for cocotbext-axi auto-discovery)
      S_AXI_RX_ACLK     : in  std_logic;
      S_AXI_RX_ARESETN  : in  std_logic;
      S_AXI_RX_AWADDR   : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
      S_AXI_RX_AWPROT   : in  std_logic_vector(2 downto 0);
      S_AXI_RX_AWVALID  : in  std_logic;
      S_AXI_RX_AWREADY  : out std_logic;
      S_AXI_RX_WDATA    : in  std_logic_vector(31 downto 0);
      S_AXI_RX_WSTRB    : in  std_logic_vector(3 downto 0);
      S_AXI_RX_WVALID   : in  std_logic;
      S_AXI_RX_WREADY   : out std_logic;
      S_AXI_RX_BRESP    : out std_logic_vector(1 downto 0);
      S_AXI_RX_BVALID   : out std_logic;
      S_AXI_RX_BREADY   : in  std_logic;
      S_AXI_RX_ARADDR   : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
      S_AXI_RX_ARPROT   : in  std_logic_vector(2 downto 0);
      S_AXI_RX_ARVALID  : in  std_logic;
      S_AXI_RX_ARREADY  : out std_logic;
      S_AXI_RX_RDATA    : out std_logic_vector(31 downto 0);
      S_AXI_RX_RRESP    : out std_logic_vector(1 downto 0);
      S_AXI_RX_RVALID   : out std_logic;
      S_AXI_RX_RREADY   : in  std_logic;
      -- TX extSampleData inputs (bench drives these)
      extData_0_i       : in  slv(GT_WORD_SIZE_C*8-1 downto 0);
      extData_1_i       : in  slv(GT_WORD_SIZE_C*8-1 downto 0);
      -- nSync forwarding ports (Python bench forwards nSync_RX_o -> nSync_TX_i)
      nSync_TX_i        : in  slv(L_G-1 downto 0);
      nSync_RX_o        : out sl;
      -- TX GT outputs (bench reads these and forwards to RX GT inputs each devClk cycle)
      gtTxData_0_o      : out slv(GT_WORD_SIZE_C*8-1 downto 0);
      gtTxDataK_0_o     : out slv(GT_WORD_SIZE_C-1 downto 0);
      gtTxData_1_o      : out slv(GT_WORD_SIZE_C*8-1 downto 0);
      gtTxDataK_1_o     : out slv(GT_WORD_SIZE_C-1 downto 0);
      -- RX GT inputs (bench drives from forwarded TX outputs)
      gtRxData_0_i      : in  slv(GT_WORD_SIZE_C*8-1 downto 0);
      gtRxDataK_0_i     : in  slv(GT_WORD_SIZE_C-1 downto 0);
      gtRxDispErr_0_i   : in  slv(GT_WORD_SIZE_C-1 downto 0);
      gtRxDecErr_0_i    : in  slv(GT_WORD_SIZE_C-1 downto 0);
      gtRxRstDone_0_i   : in  sl;
      gtRxCdrStable_0_i : in  sl;
      gtRxData_1_i      : in  slv(GT_WORD_SIZE_C*8-1 downto 0);
      gtRxDataK_1_i     : in  slv(GT_WORD_SIZE_C-1 downto 0);
      gtRxDispErr_1_i   : in  slv(GT_WORD_SIZE_C-1 downto 0);
      gtRxDecErr_1_i    : in  slv(GT_WORD_SIZE_C-1 downto 0);
      gtRxRstDone_1_i   : in  sl;
      gtRxCdrStable_1_i : in  sl;
      -- RX data outputs (bench compares against TX extData for scrambler integrity)
      sampleData_0_o    : out slv(GT_WORD_SIZE_C*8-1 downto 0);
      sampleData_1_o    : out slv(GT_WORD_SIZE_C*8-1 downto 0);
      dataValid_0_o     : out sl;
      dataValid_1_o     : out sl;
      sysRefDbg_o       : out sl);
end entity Jesd204bLoopbackWrapper;

architecture rtl of Jesd204bLoopbackWrapper is

   -- TX AXI-Lite record signals
   signal s_axilTxReadMaster  : AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
   signal s_axilTxReadSlave   : AxiLiteReadSlaveType   := AXI_LITE_READ_SLAVE_INIT_C;
   signal s_axilTxWriteMaster : AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
   signal s_axilTxWriteSlave  : AxiLiteWriteSlaveType  := AXI_LITE_WRITE_SLAVE_INIT_C;

   -- RX AXI-Lite record signals
   signal s_axilRxReadMaster  : AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
   signal s_axilRxReadSlave   : AxiLiteReadSlaveType   := AXI_LITE_READ_SLAVE_INIT_C;
   signal s_axilRxWriteMaster : AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
   signal s_axilRxWriteSlave  : AxiLiteWriteSlaveType  := AXI_LITE_WRITE_SLAVE_INIT_C;

   -- TX lane arrays
   signal s_nSyncArr  : slv(L_G-1 downto 0);
   signal s_extData   : sampleDataArray(L_G-1 downto 0);
   signal s_gtTxReady : slv(L_G-1 downto 0);
   signal s_gtTxArr   : jesdGtTxLaneTypeArray(L_G-1 downto 0);
   signal s_dacReady  : slv(L_G-1 downto 0);

   -- RX lane arrays
   signal s_jesdGtRxArr   : jesdGtRxLaneTypeArray(L_G-1 downto 0);
   signal s_sampleDataArr : sampleDataArray(L_G-1 downto 0);
   signal s_dataValidVec  : slv(L_G-1 downto 0);

begin

   ---------------------------------------------------------------------------
   -- TX SlaveAxiLiteIpIntegrator (two independent AXI-Lite buses)
   -- Source: Jesd204bTxWrapper.vhd:116-148 port-map pattern
   ---------------------------------------------------------------------------
   U_AXIL_TX : entity surf.SlaveAxiLiteIpIntegrator
      generic map (
         EN_ERROR_RESP => true,
         ADDR_WIDTH    => ADDR_WIDTH,
         HAS_PROT      => 1,
         HAS_WSTRB     => 1)
      port map (
         S_AXI_ACLK      => S_AXI_TX_ACLK,
         S_AXI_ARESETN   => S_AXI_TX_ARESETN,
         S_AXI_AWADDR    => S_AXI_TX_AWADDR,
         S_AXI_AWPROT    => S_AXI_TX_AWPROT,
         S_AXI_AWVALID   => S_AXI_TX_AWVALID,
         S_AXI_AWREADY   => S_AXI_TX_AWREADY,
         S_AXI_WDATA     => S_AXI_TX_WDATA,
         S_AXI_WSTRB     => S_AXI_TX_WSTRB,
         S_AXI_WVALID    => S_AXI_TX_WVALID,
         S_AXI_WREADY    => S_AXI_TX_WREADY,
         S_AXI_BRESP     => S_AXI_TX_BRESP,
         S_AXI_BVALID    => S_AXI_TX_BVALID,
         S_AXI_BREADY    => S_AXI_TX_BREADY,
         S_AXI_ARADDR    => S_AXI_TX_ARADDR,
         S_AXI_ARPROT    => S_AXI_TX_ARPROT,
         S_AXI_ARVALID   => S_AXI_TX_ARVALID,
         S_AXI_ARREADY   => S_AXI_TX_ARREADY,
         S_AXI_RDATA     => S_AXI_TX_RDATA,
         S_AXI_RRESP     => S_AXI_TX_RRESP,
         S_AXI_RVALID    => S_AXI_TX_RVALID,
         S_AXI_RREADY    => S_AXI_TX_RREADY,
         axilReadMaster  => s_axilTxReadMaster,
         axilReadSlave   => s_axilTxReadSlave,
         axilWriteMaster => s_axilTxWriteMaster,
         axilWriteSlave  => s_axilTxWriteSlave);
   -- NOTE: Do NOT use axilClk/axilRst outputs from SlaveAxiLiteIpIntegrator.
   -- Wire axiClk/axiRst of U_Tx directly from S_AXI_TX_ACLK/ARESETN.

   ---------------------------------------------------------------------------
   -- RX SlaveAxiLiteIpIntegrator (second independent AXI-Lite bus)
   ---------------------------------------------------------------------------
   U_AXIL_RX : entity surf.SlaveAxiLiteIpIntegrator
      generic map (
         EN_ERROR_RESP => true,
         ADDR_WIDTH    => ADDR_WIDTH,
         HAS_PROT      => 1,
         HAS_WSTRB     => 1)
      port map (
         S_AXI_ACLK      => S_AXI_RX_ACLK,
         S_AXI_ARESETN   => S_AXI_RX_ARESETN,
         S_AXI_AWADDR    => S_AXI_RX_AWADDR,
         S_AXI_AWPROT    => S_AXI_RX_AWPROT,
         S_AXI_AWVALID   => S_AXI_RX_AWVALID,
         S_AXI_AWREADY   => S_AXI_RX_AWREADY,
         S_AXI_WDATA     => S_AXI_RX_WDATA,
         S_AXI_WSTRB     => S_AXI_RX_WSTRB,
         S_AXI_WVALID    => S_AXI_RX_WVALID,
         S_AXI_WREADY    => S_AXI_RX_WREADY,
         S_AXI_BRESP     => S_AXI_RX_BRESP,
         S_AXI_BVALID    => S_AXI_RX_BVALID,
         S_AXI_BREADY    => S_AXI_RX_BREADY,
         S_AXI_ARADDR    => S_AXI_RX_ARADDR,
         S_AXI_ARPROT    => S_AXI_RX_ARPROT,
         S_AXI_ARVALID   => S_AXI_RX_ARVALID,
         S_AXI_ARREADY   => S_AXI_RX_ARREADY,
         S_AXI_RDATA     => S_AXI_RX_RDATA,
         S_AXI_RRESP     => S_AXI_RX_RRESP,
         S_AXI_RVALID    => S_AXI_RX_RVALID,
         S_AXI_RREADY    => S_AXI_RX_RREADY,
         axilReadMaster  => s_axilRxReadMaster,
         axilReadSlave   => s_axilRxReadSlave,
         axilWriteMaster => s_axilRxWriteMaster,
         axilWriteSlave  => s_axilRxWriteSlave);

   ---------------------------------------------------------------------------
   -- Assemble TX lane arrays from flat ports
   -- Source: Jesd204bTxWrapper.vhd:156-164 pattern
   ---------------------------------------------------------------------------
   s_nSyncArr(0)  <= nSync_TX_i(0);
   s_extData(0)   <= extData_0_i;
   s_gtTxReady(0) <= '1';  -- bench always drives gtTxReady high before enabling

   GEN_LANE1 : if L_G >= 2 generate
      s_nSyncArr(1)  <= nSync_TX_i(1);
      s_extData(1)   <= extData_1_i;
      s_gtTxReady(1) <= '1';
   end generate GEN_LANE1;

   ---------------------------------------------------------------------------
   -- Assemble RX GT lane array from flat ports
   -- Source: Jesd204bRxWrapper.vhd:138-152 record-assembly pattern
   ---------------------------------------------------------------------------
   s_jesdGtRxArr(0).data      <= gtRxData_0_i;
   s_jesdGtRxArr(0).dataK     <= gtRxDataK_0_i;
   s_jesdGtRxArr(0).dispErr   <= gtRxDispErr_0_i;
   s_jesdGtRxArr(0).decErr    <= gtRxDecErr_0_i;
   s_jesdGtRxArr(0).rstDone   <= gtRxRstDone_0_i;
   s_jesdGtRxArr(0).cdrStable <= gtRxCdrStable_0_i;

   GEN_RX_LANE1 : if L_G >= 2 generate
      s_jesdGtRxArr(1).data      <= gtRxData_1_i;
      s_jesdGtRxArr(1).dataK     <= gtRxDataK_1_i;
      s_jesdGtRxArr(1).dispErr   <= gtRxDispErr_1_i;
      s_jesdGtRxArr(1).decErr    <= gtRxDecErr_1_i;
      s_jesdGtRxArr(1).rstDone   <= gtRxRstDone_1_i;
      s_jesdGtRxArr(1).cdrStable <= gtRxCdrStable_1_i;
   end generate GEN_RX_LANE1;

   ---------------------------------------------------------------------------
   -- TX top instance
   ---------------------------------------------------------------------------
   U_Tx : entity surf.Jesd204bTx
      generic map (
         TPD_G    => TPD_G,
         F_G      => F_G,
         K_G      => K_G,
         L_G      => L_G,
         DID_G    => DID_G,
         BID_G    => BID_G,
         M_G      => M_G,
         N_G      => N_G,
         NPRIME_G => NPRIME_G,
         CS_G     => CS_G,
         S_G      => S_G,
         HD_G     => HD_G,
         CF_G     => CF_G)
      port map (
         axiClk               => S_AXI_TX_ACLK,
         axiRst               => not S_AXI_TX_ARESETN,  -- CRITICAL: invert active-low
         axilReadMaster       => s_axilTxReadMaster,
         axilReadSlave        => s_axilTxReadSlave,
         axilWriteMaster      => s_axilTxWriteMaster,
         axilWriteSlave       => s_axilTxWriteSlave,
         devClk_i             => devClk_i,
         devRst_i             => devRst_i,
         sysRef_i             => sysRef_i,
         nSync_i              => s_nSyncArr,
         extSampleDataArray_i => s_extData,
         gtTxReady_i          => s_gtTxReady,
         r_jesdGtTxArr        => s_gtTxArr,
         dacReady_o           => s_dacReady,
         gtTxReset_o          => open,
         txDiffCtrl           => open,
         txPolarity           => open,
         loopback             => open,
         txPostCursor         => open,
         txPowerDown          => open,
         txEnable             => open,
         txEnableL            => open,
         pulse_o              => open,
         leds_o               => open);

   ---------------------------------------------------------------------------
   -- RX top instance
   ---------------------------------------------------------------------------
   U_Rx : entity surf.Jesd204bRx
      generic map (
         TPD_G => TPD_G,
         F_G   => F_G,
         K_G   => K_G,
         L_G   => L_G)
      port map (
         axiClk          => S_AXI_RX_ACLK,
         axiRst          => not S_AXI_RX_ARESETN,  -- CRITICAL: invert active-low
         axilReadMaster  => s_axilRxReadMaster,
         axilReadSlave   => s_axilRxReadSlave,
         axilWriteMaster => s_axilRxWriteMaster,
         axilWriteSlave  => s_axilRxWriteSlave,
         devClk_i        => devClk_i,
         devRst_i        => devRst_i,
         sysRef_i        => sysRef_i,
         sysRefDbg_o     => sysRefDbg_o,
         r_jesdGtRxArr   => s_jesdGtRxArr,
         gtRxReset_o     => open,
         rxPowerDown     => open,
         rxPolarity      => open,
         nSync_o         => nSync_RX_o,
         sampleDataArr_o => s_sampleDataArr,
         dataValidVec_o  => s_dataValidVec,
         pulse_o         => open,
         leds_o          => open);

   ---------------------------------------------------------------------------
   -- TX GT output unpack (bench reads for forwarding to RX GT inputs)
   -- Source: Jesd204bTxWrapper.vhd:213-226 pattern
   ---------------------------------------------------------------------------
   gtTxData_0_o  <= s_gtTxArr(0).data;
   gtTxDataK_0_o <= s_gtTxArr(0).dataK;

   GEN_LANE1_OUT : if L_G >= 2 generate
      gtTxData_1_o  <= s_gtTxArr(1).data;
      gtTxDataK_1_o <= s_gtTxArr(1).dataK;
   end generate GEN_LANE1_OUT;

   GEN_LANE1_ZERO : if L_G < 2 generate
      gtTxData_1_o  <= (others => '0');
      gtTxDataK_1_o <= (others => '0');
   end generate GEN_LANE1_ZERO;

   ---------------------------------------------------------------------------
   -- RX sample data output unpack (bench compares against TX extData for scrambler integrity)
   -- Source: Jesd204bRxWrapper.vhd:188-200 pattern
   ---------------------------------------------------------------------------
   sampleData_0_o <= s_sampleDataArr(0);
   dataValid_0_o  <= s_dataValidVec(0);

   GEN_UNPACK1 : if L_G >= 2 generate
      sampleData_1_o <= s_sampleDataArr(1);
      dataValid_1_o  <= s_dataValidVec(1);
   end generate GEN_UNPACK1;

   GEN_UNPACK1_DEFAULT : if L_G < 2 generate
      sampleData_1_o <= (others => '0');
      dataValid_1_o  <= '0';
   end generate GEN_UNPACK1_DEFAULT;

end architecture rtl;
