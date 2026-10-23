-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing wrapper -- instantiates Jesd204bTx and flattens
--              the jesdGtTxLaneTypeArray record output and AXI-Lite record
--              ports for cocotb observation.
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

entity Jesd204bTxWrapper is
   generic (
      TPD_G      : time                   := 1 ns;
      F_G        : positive               := 2;
      K_G        : positive               := 32;
      L_G        : positive range 1 to 16 := 2;  -- capped at 16
      -- ILAS generics (forwarded; all defaulted, same pattern as JesdTxLaneWrapper):
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
      -- AXI-Lite flat ports (from FirFilterSingleChannelWrapper.vhd:40-60 pattern)
      S_AXI_ACLK     : in  std_logic;
      S_AXI_ARESETN  : in  std_logic;   -- active-low
      S_AXI_AWADDR   : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
      S_AXI_AWPROT   : in  std_logic_vector(2 downto 0);
      S_AXI_AWVALID  : in  std_logic;
      S_AXI_AWREADY  : out std_logic;
      S_AXI_WDATA    : in  std_logic_vector(31 downto 0);
      S_AXI_WSTRB    : in  std_logic_vector(3 downto 0);
      S_AXI_WVALID   : in  std_logic;
      S_AXI_WREADY   : out std_logic;
      S_AXI_BRESP    : out std_logic_vector(1 downto 0);
      S_AXI_BVALID   : out std_logic;
      S_AXI_BREADY   : in  std_logic;
      S_AXI_ARADDR   : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
      S_AXI_ARPROT   : in  std_logic_vector(2 downto 0);
      S_AXI_ARVALID  : in  std_logic;
      S_AXI_ARREADY  : out std_logic;
      S_AXI_RDATA    : out std_logic_vector(31 downto 0);
      S_AXI_RRESP    : out std_logic_vector(1 downto 0);
      S_AXI_RVALID   : out std_logic;
      S_AXI_RREADY   : in  std_logic;
      -- JESD devClk domain
      devClk_i       : in  sl;
      devRst_i       : in  sl;
      sysRef_i       : in  sl;
      -- Per-lane nSync input (index-named for cocotb; L_G<=16):
      nSync_0_i      : in  sl;
      nSync_1_i      : in  sl;
      -- Per-lane extSampleData input (GT_WORD_SIZE_C*8 = 32 bits):
      extData_0_i    : in  slv(GT_WORD_SIZE_C*8-1 downto 0);
      extData_1_i    : in  slv(GT_WORD_SIZE_C*8-1 downto 0);
      -- Per-lane GT ready input:
      gtTxReady_0_i  : in  sl;
      gtTxReady_1_i  : in  sl;
      -- Per-lane GT TX output (flattened jesdGtTxLaneTypeArray):
      gtTxData_0_o   : out slv(GT_WORD_SIZE_C*8-1 downto 0);
      gtTxDataK_0_o  : out slv(GT_WORD_SIZE_C-1 downto 0);
      gtTxData_1_o   : out slv(GT_WORD_SIZE_C*8-1 downto 0);
      gtTxDataK_1_o  : out slv(GT_WORD_SIZE_C-1 downto 0);
      -- Control port spot-check outputs (verifiable in bench):
      txDiffCtrl_0_o : out slv(7 downto 0);
      txPolarity_0_o : out slv(0 downto 0);
      loopback_0_o   : out slv(0 downto 0);
      -- Status ports:
      dacReady_0_o   : out sl;
      dacReady_1_o   : out sl);
end entity Jesd204bTxWrapper;

architecture rtl of Jesd204bTxWrapper is

   signal s_axilReadMaster  : AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
   signal s_axilReadSlave   : AxiLiteReadSlaveType   := AXI_LITE_READ_SLAVE_INIT_C;
   signal s_axilWriteMaster : AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
   signal s_axilWriteSlave  : AxiLiteWriteSlaveType  := AXI_LITE_WRITE_SLAVE_INIT_C;

   -- Lane array records (assembled before U_DUT)
   signal s_nSyncArr   : slv(L_G-1 downto 0);
   signal s_extData    : sampleDataArray(L_G-1 downto 0);
   signal s_gtTxReady  : slv(L_G-1 downto 0);
   signal s_gtTxArr    : jesdGtTxLaneTypeArray(L_G-1 downto 0);
   signal s_txDiffCtrl : Slv8Array(L_G-1 downto 0);
   signal s_txPolarity : slv(L_G-1 downto 0);
   signal s_loopback   : slv(L_G-1 downto 0);
   signal s_dacReady   : slv(L_G-1 downto 0);

begin

   ---------------------------------------------------------------------------
   -- SlaveAxiLiteIpIntegrator: converts flat S_AXI_* to SURF record types
   -- Source: FirFilterSingleChannelWrapper.vhd:76-108 (exact port-map pattern)
   ---------------------------------------------------------------------------
   U_AXIL : entity surf.SlaveAxiLiteIpIntegrator
      generic map (
         EN_ERROR_RESP => true,
         ADDR_WIDTH    => ADDR_WIDTH,
         HAS_PROT      => 1,
         HAS_WSTRB     => 1)
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
         axilReadMaster  => s_axilReadMaster,
         axilReadSlave   => s_axilReadSlave,
         axilWriteMaster => s_axilWriteMaster,
         axilWriteSlave  => s_axilWriteSlave);
   -- NOTE: SlaveAxiLiteIpIntegrator drives axilClk/axilRst as outputs; do NOT
   -- use them -- wire axiClk/axiRst of U_DUT directly from S_AXI_ACLK/ARESETN.

   ---------------------------------------------------------------------------
   -- Assemble flat ports into arrays (source: JesdRxLaneWrapper.vhd:65-71 pattern)
   -- Indices 0 and 1 cover L_G={1,2} bench sweep (capped at 16).
   -- When L_G=1: only s_nSyncArr(0)/s_extData(0)/s_gtTxReady(0) are used by DUT.
   ---------------------------------------------------------------------------
   s_nSyncArr(0)  <= nSync_0_i;
   s_extData(0)   <= extData_0_i;
   s_gtTxReady(0) <= gtTxReady_0_i;

   GEN_LANE1 : if L_G >= 2 generate
      s_nSyncArr(1)  <= nSync_1_i;
      s_extData(1)   <= extData_1_i;
      s_gtTxReady(1) <= gtTxReady_1_i;
   end generate GEN_LANE1;

   ---------------------------------------------------------------------------
   -- DUT instance (entity label U_DUT per all prior wrappers)
   ---------------------------------------------------------------------------
   U_DUT : entity surf.Jesd204bTx
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
         axiClk               => S_AXI_ACLK,
         axiRst               => not S_AXI_ARESETN,  -- CRITICAL: invert active-low to active-high
         axilReadMaster       => s_axilReadMaster,
         axilReadSlave        => s_axilReadSlave,
         axilWriteMaster      => s_axilWriteMaster,
         axilWriteSlave       => s_axilWriteSlave,
         devClk_i             => devClk_i,
         devRst_i             => devRst_i,
         sysRef_i             => sysRef_i,
         nSync_i              => s_nSyncArr,
         extSampleDataArray_i => s_extData,
         gtTxReady_i          => s_gtTxReady,
         r_jesdGtTxArr        => s_gtTxArr,
         txDiffCtrl           => s_txDiffCtrl,
         txPolarity           => s_txPolarity,
         loopback             => s_loopback,
         dacReady_o           => s_dacReady,
         gtTxReset_o          => open,
         txPostCursor         => open,
         txPowerDown          => open,
         txEnable             => open,
         txEnableL            => open,
         pulse_o              => open,
         leds_o               => open);

   ---------------------------------------------------------------------------
   -- Unpack GT TX record array (source: JesdTxLaneWrapper.vhd:101-102 pattern)
   ---------------------------------------------------------------------------
   gtTxData_0_o  <= s_gtTxArr(0).data;
   gtTxDataK_0_o <= s_gtTxArr(0).dataK;

   GEN_LANE1_OUT : if L_G >= 2 generate
      gtTxData_1_o  <= s_gtTxArr(1).data;
      gtTxDataK_1_o <= s_gtTxArr(1).dataK;
      dacReady_1_o  <= s_dacReady(1);
   end generate GEN_LANE1_OUT;

   GEN_LANE1_ZERO : if L_G < 2 generate
      gtTxData_1_o  <= (others => '0');
      gtTxDataK_1_o <= (others => '0');
      dacReady_1_o  <= '0';
   end generate GEN_LANE1_ZERO;

   ---------------------------------------------------------------------------
   -- Control port spot-check outputs
   ---------------------------------------------------------------------------
   txDiffCtrl_0_o <= s_txDiffCtrl(0);
   txPolarity_0_o <= s_txPolarity(0 downto 0);
   loopback_0_o   <= s_loopback(0 downto 0);
   dacReady_0_o   <= s_dacReady(0);

end architecture rtl;
