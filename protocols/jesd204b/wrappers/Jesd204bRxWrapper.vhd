-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing wrapper -- instantiates Jesd204bRx and flattens
--              the jesdGtRxLaneTypeArray record input and AXI-Lite record
--              ports for cocotb injection and observation.
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

entity Jesd204bRxWrapper is
   generic (
      TPD_G      : time                   := 1 ns;
      F_G        : positive               := 2;
      K_G        : positive               := 32;
      L_G        : positive range 1 to 16 := 2;
      ADDR_WIDTH : positive               := 12);
   port (
      -- AXI-Lite slave flat ports (cocotbext-axi S_AXI prefix)
      S_AXI_ACLK        : in  std_logic;
      S_AXI_ARESETN     : in  std_logic;
      S_AXI_AWADDR      : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
      S_AXI_AWPROT      : in  std_logic_vector(2 downto 0);
      S_AXI_AWVALID     : in  std_logic;
      S_AXI_AWREADY     : out std_logic;
      S_AXI_WDATA       : in  std_logic_vector(31 downto 0);
      S_AXI_WSTRB       : in  std_logic_vector(3 downto 0);
      S_AXI_WVALID      : in  std_logic;
      S_AXI_WREADY      : out std_logic;
      S_AXI_BRESP       : out std_logic_vector(1 downto 0);
      S_AXI_BVALID      : out std_logic;
      S_AXI_BREADY      : in  std_logic;
      S_AXI_ARADDR      : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
      S_AXI_ARPROT      : in  std_logic_vector(2 downto 0);
      S_AXI_ARVALID     : in  std_logic;
      S_AXI_ARREADY     : out std_logic;
      S_AXI_RDATA       : out std_logic_vector(31 downto 0);
      S_AXI_RRESP       : out std_logic_vector(1 downto 0);
      S_AXI_RVALID      : out std_logic;
      S_AXI_RREADY      : in  std_logic;
      -- JESD devClk domain
      devClk_i          : in  sl;
      devRst_i          : in  sl;
      sysRef_i          : in  sl;
      -- Per-lane GT RX inputs (assembled into jesdGtRxLaneTypeArray)
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
      -- Per-lane RX outputs (unpacked from DUT arrays)
      sampleData_0_o    : out slv(GT_WORD_SIZE_C*8-1 downto 0);
      sampleData_1_o    : out slv(GT_WORD_SIZE_C*8-1 downto 0);
      dataValid_0_o     : out sl;
      dataValid_1_o     : out sl;
      nSync_o           : out sl;
      sysRefDbg_o       : out sl;
      rxPolarity_0_o    : out sl);
end entity Jesd204bRxWrapper;

architecture rtl of Jesd204bRxWrapper is

   signal s_axilReadMaster  : AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
   signal s_axilReadSlave   : AxiLiteReadSlaveType   := AXI_LITE_READ_SLAVE_INIT_C;
   signal s_axilWriteMaster : AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
   signal s_axilWriteSlave  : AxiLiteWriteSlaveType  := AXI_LITE_WRITE_SLAVE_INIT_C;

   signal s_jesdGtRxArr   : jesdGtRxLaneTypeArray(L_G-1 downto 0);
   signal s_sampleDataArr : sampleDataArray(L_G-1 downto 0);
   signal s_dataValidVec  : slv(L_G-1 downto 0);
   signal s_rxPolarity    : slv(L_G-1 downto 0);

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

   ---------------------------------------------------------------------------
   -- Assemble jesdGtRxLaneTypeArray from flat per-lane ports
   -- Source: JesdRxLaneWrapper.vhd:66-71 record assembly pattern
   ---------------------------------------------------------------------------
   s_jesdGtRxArr(0).data      <= gtRxData_0_i;
   s_jesdGtRxArr(0).dataK     <= gtRxDataK_0_i;
   s_jesdGtRxArr(0).dispErr   <= gtRxDispErr_0_i;
   s_jesdGtRxArr(0).decErr    <= gtRxDecErr_0_i;
   s_jesdGtRxArr(0).rstDone   <= gtRxRstDone_0_i;
   s_jesdGtRxArr(0).cdrStable <= gtRxCdrStable_0_i;

   GEN_LANE1 : if L_G >= 2 generate
      s_jesdGtRxArr(1).data      <= gtRxData_1_i;
      s_jesdGtRxArr(1).dataK     <= gtRxDataK_1_i;
      s_jesdGtRxArr(1).dispErr   <= gtRxDispErr_1_i;
      s_jesdGtRxArr(1).decErr    <= gtRxDecErr_1_i;
      s_jesdGtRxArr(1).rstDone   <= gtRxRstDone_1_i;
      s_jesdGtRxArr(1).cdrStable <= gtRxCdrStable_1_i;
   end generate GEN_LANE1;

   ---------------------------------------------------------------------------
   -- DUT: Jesd204bRx
   -- axiRst is ACTIVE-HIGH; invert active-low S_AXI_ARESETN (CRITICAL)
   ---------------------------------------------------------------------------
   U_DUT : entity surf.Jesd204bRx
      generic map (
         TPD_G => TPD_G,
         F_G   => F_G,
         K_G   => K_G,
         L_G   => L_G)
      port map (
         axiClk          => S_AXI_ACLK,
         axiRst          => not S_AXI_ARESETN,
         axilReadMaster  => s_axilReadMaster,
         axilReadSlave   => s_axilReadSlave,
         axilWriteMaster => s_axilWriteMaster,
         axilWriteSlave  => s_axilWriteSlave,
         devClk_i        => devClk_i,
         devRst_i        => devRst_i,
         sysRef_i        => sysRef_i,
         sysRefDbg_o     => sysRefDbg_o,
         r_jesdGtRxArr   => s_jesdGtRxArr,
         gtRxReset_o     => open,
         rxPowerDown     => open,
         rxPolarity      => s_rxPolarity,
         nSync_o         => nSync_o,
         sampleDataArr_o => s_sampleDataArr,
         dataValidVec_o  => s_dataValidVec,
         pulse_o         => open,
         leds_o          => open);

   ---------------------------------------------------------------------------
   -- Unpack per-lane arrays to flat output ports
   ---------------------------------------------------------------------------
   sampleData_0_o <= s_sampleDataArr(0);
   dataValid_0_o  <= s_dataValidVec(0);
   rxPolarity_0_o <= s_rxPolarity(0);

   GEN_UNPACK1 : if L_G >= 2 generate
      sampleData_1_o <= s_sampleDataArr(1);
      dataValid_1_o  <= s_dataValidVec(1);
   end generate GEN_UNPACK1;

   GEN_UNPACK1_DEFAULT : if L_G < 2 generate
      sampleData_1_o <= (others => '0');
      dataValid_1_o  <= '0';
   end generate GEN_UNPACK1_DEFAULT;

end architecture rtl;
