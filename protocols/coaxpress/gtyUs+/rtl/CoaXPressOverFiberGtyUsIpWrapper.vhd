-------------------------------------------------------------------------------
-- Title      : CXP Over Fiber Protocol: http://jiia.org/wp-content/themes/jiia/pdf/standard_dl/coaxpress/CXPR-008-2021.pdf
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: CoaXPress Gty Ultrascale IP core Wrapper
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

entity CoaXPressOverFiberGtyUsIpWrapper is
   generic (
      TPD_G   : time    := 1 ns;
      LANE0_G : boolean := true);
   port (
      -- QPLL Interface
      qpllLock        : in  slv(1 downto 0);
      qpllclk         : in  slv(1 downto 0);
      qpllrefclk      : in  slv(1 downto 0);
      qpllRst         : out slv(1 downto 0);
      -- GT Ports
      gtRxP           : in  sl;
      gtRxN           : in  sl;
      gtTxP           : out sl;
      gtTxN           : out sl;
      -- Tx Interface (txClk domain)
      txClk           : out sl;
      txRst           : out sl;
      txLsValid       : in  sl;
      txLsData        : in  slv(7 downto 0);
      txLsDataK       : in  sl;
      txLsRate        : in  sl;
      txLsLaneEn      : in  slv(3 downto 0);
      txHsEnable      : in  sl;
      txHsData        : in  slv(31 downto 0);
      txHsDataK       : in  slv(3 downto 0);
      txLinkUp        : out sl;
      -- Rx Interface (rxClk domain)
      rxClk           : out sl;
      rxRst           : out sl;
      rxData          : out slv(31 downto 0);
      rxDataK         : out slv(3 downto 0);
      rxDispErr       : out sl := '0';
      rxDecErr        : out sl := '0';
      rxLinkUp        : out sl;
      -- AXI-Lite DRP Interface
      axilClk         : in  sl;
      axilRst         : in  sl;
      axilReadMaster  : in  AxiLiteReadMasterType;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType;
      axilWriteSlave  : out AxiLiteWriteSlaveType);
end entity CoaXPressOverFiberGtyUsIpWrapper;

architecture mapping of CoaXPressOverFiberGtyUsIpWrapper is

   component CoaXPressOverFiberGtyUsIp
      port (
         gt_txp_out                        : out std_logic_vector(0 downto 0);
         gt_txn_out                        : out std_logic_vector(0 downto 0);
         gt_rxp_in                         : in  std_logic_vector(0 downto 0);
         gt_rxn_in                         : in  std_logic_vector(0 downto 0);
         rx_core_clk_0                     : in  std_logic;
         rx_serdes_reset_0                 : in  std_logic;
         txoutclksel_in_0                  : in  std_logic_vector(2 downto 0);
         rxoutclksel_in_0                  : in  std_logic_vector(2 downto 0);
         rxrecclkout_0                     : out std_logic;
         sys_reset                         : in  std_logic;
         dclk                              : in  std_logic;
         tx_mii_clk_0                      : out std_logic;
         rx_clk_out_0                      : out std_logic;
         gtpowergood_out_0                 : out std_logic;
         qpll0clk_in                       : in  std_logic_vector(0 downto 0);
         qpll0refclk_in                    : in  std_logic_vector(0 downto 0);
         qpll1clk_in                       : in  std_logic_vector(0 downto 0);
         qpll1refclk_in                    : in  std_logic_vector(0 downto 0);
         gtwiz_reset_qpll0lock_in          : in  std_logic;
         gtwiz_reset_qpll0reset_out        : out std_logic;
         gtwiz_reset_qpll1lock_in          : in  std_logic;
         gtwiz_reset_qpll1reset_out        : out std_logic;
         ctl_gt_reset_all_0                : out std_logic;
         ctl_gt_tx_reset_0                 : out std_logic;
         ctl_gt_rx_reset_0                 : out std_logic;
         gt_reset_tx_done_out_0            : out std_logic;
         gt_reset_rx_done_out_0            : out std_logic;
         gt_reset_all_in_0                 : in  std_logic;
         gt_tx_reset_in_0                  : in  std_logic;
         gt_rx_reset_in_0                  : in  std_logic;
         s_axi_aclk_0                      : in  std_logic;
         s_axi_aresetn_0                   : in  std_logic;
         pm_tick_0                         : in  std_logic;
         s_axi_awaddr_0                    : in  std_logic_vector(31 downto 0);
         s_axi_awvalid_0                   : in  std_logic;
         s_axi_awready_0                   : out std_logic;
         s_axi_wdata_0                     : in  std_logic_vector(31 downto 0);
         s_axi_wstrb_0                     : in  std_logic_vector(3 downto 0);
         s_axi_wvalid_0                    : in  std_logic;
         s_axi_wready_0                    : out std_logic;
         s_axi_bresp_0                     : out std_logic_vector(1 downto 0);
         s_axi_bvalid_0                    : out std_logic;
         s_axi_bready_0                    : in  std_logic;
         s_axi_araddr_0                    : in  std_logic_vector(31 downto 0);
         s_axi_arvalid_0                   : in  std_logic;
         s_axi_arready_0                   : out std_logic;
         s_axi_rdata_0                     : out std_logic_vector(31 downto 0);
         s_axi_rresp_0                     : out std_logic_vector(1 downto 0);
         s_axi_rvalid_0                    : out std_logic;
         s_axi_rready_0                    : in  std_logic;
         rx_reset_0                        : in  std_logic;
         rx_mii_d_0                        : out std_logic_vector(63 downto 0);
         rx_mii_c_0                        : out std_logic_vector(7 downto 0);
         stat_rx_framing_err_0             : out std_logic;
         stat_rx_framing_err_valid_0       : out std_logic;
         stat_rx_local_fault_0             : out std_logic;
         stat_rx_block_lock_0              : out std_logic;
         stat_rx_valid_ctrl_code_0         : out std_logic;
         stat_rx_status_0                  : out std_logic;
         stat_rx_hi_ber_0                  : out std_logic;
         stat_rx_bad_code_0                : out std_logic;
         stat_rx_bad_code_valid_0          : out std_logic;
         stat_rx_error_0                   : out std_logic_vector(7 downto 0);
         stat_rx_error_valid_0             : out std_logic;
         stat_rx_fifo_error_0              : out std_logic;
         stat_tx_fifo_error_0              : out std_logic;
         tx_reset_0                        : in  std_logic;
         tx_mii_d_0                        : in  std_logic_vector(63 downto 0);
         tx_mii_c_0                        : in  std_logic_vector(7 downto 0);
         stat_tx_local_fault_0             : out std_logic;
         stat_fec_inc_correct_count_0      : out std_logic;
         stat_fec_inc_cant_correct_count_0 : out std_logic;
         stat_fec_lock_error_0             : out std_logic;
         stat_fec_rx_lock_0                : out std_logic;
         user_reg0_0                       : out std_logic_vector(31 downto 0)
         );
   end component;

   signal phyClk156 : sl;
   signal phyClk312 : sl;
   signal phyRst312 : sl;

   signal axilRstL : sl;

   signal txReset   : sl;
   signal txRstDone : sl;

   signal rxReset   : sl;
   signal rxRstDone : sl;

   signal xgmiiTxd : slv(63 downto 0) := CXPOF_IDLE_WORD_C & CXPOF_IDLE_WORD_C;
   signal xgmiiTxc : slv(7 downto 0)  := x"FF";

   signal xgmiiRxd : slv(63 downto 0);
   signal xgmiiRxc : slv(7 downto 0);

begin

   txClk   <= phyClk312;
   txReset <= phyRst312 or not(txRstDone);

   U_txRst : entity surf.RstSync
      generic map (
         TPD_G          => TPD_G,
         IN_POLARITY_G  => '1',
         OUT_POLARITY_G => '1',
         OUT_REG_RST_G  => true)
      port map (
         clk      => phyClk312,
         asyncRst => txReset,
         syncRst  => txRst);

   U_txLinkUp : entity surf.RstSync
      generic map (
         TPD_G          => TPD_G,
         IN_POLARITY_G  => '1',
         OUT_POLARITY_G => '0',
         OUT_REG_RST_G  => true)
      port map (
         clk      => phyClk312,
         asyncRst => txReset,
         syncRst  => txLinkUp);

   rxClk   <= phyClk312;
   rxReset <= phyRst312 or not(rxRstDone);

   U_rxRst : entity surf.RstSync
      generic map (
         TPD_G          => TPD_G,
         IN_POLARITY_G  => '1',
         OUT_POLARITY_G => '1',
         OUT_REG_RST_G  => true)
      port map (
         clk      => phyClk312,
         asyncRst => rxReset,
         syncRst  => rxRst);

   U_rxLinkUp : entity surf.RstSync
      generic map (
         TPD_G          => TPD_G,
         IN_POLARITY_G  => '1',
         OUT_POLARITY_G => '0',
         OUT_REG_RST_G  => true)
      port map (
         clk      => phyClk312,
         asyncRst => rxReset,
         syncRst  => rxLinkUp);

   axilRstL <= not(axilRst);

   U_GT : CoaXPressOverFiberGtyUsIp
      port map (
         gt_txp_out(0)                     => gtTxP,
         gt_txn_out(0)                     => gtTxN,
         gt_rxp_in(0)                      => gtRxP,
         gt_rxn_in(0)                      => gtRxN,
         rx_core_clk_0                     => phyClk156,
         rx_serdes_reset_0                 => axilRst,
         txoutclksel_in_0                  => "101",
         rxoutclksel_in_0                  => "101",
         rxrecclkout_0                     => open,
         sys_reset                         => axilRst,
         dclk                              => axilClk,
         tx_mii_clk_0                      => phyClk156,
         rx_clk_out_0                      => open,
         gtpowergood_out_0                 => open,
         qpll0clk_in(0)                    => qpllclk(0),
         qpll0refclk_in(0)                 => qpllrefclk(0),
         qpll1clk_in(0)                    => qpllclk(1),
         qpll1refclk_in(0)                 => qpllrefclk(1),
         gtwiz_reset_qpll0lock_in          => qplllock(0),
         gtwiz_reset_qpll0reset_out        => qpllRst(0),
         gtwiz_reset_qpll1lock_in          => qplllock(1),
         gtwiz_reset_qpll1reset_out        => qpllRst(1),
         ctl_gt_reset_all_0                => open,
         ctl_gt_tx_reset_0                 => open,
         ctl_gt_rx_reset_0                 => open,
         gt_reset_tx_done_out_0            => txRstDone,
         gt_reset_rx_done_out_0            => rxRstDone,
         gt_reset_all_in_0                 => axilRst,
         gt_tx_reset_in_0                  => axilRst,
         gt_rx_reset_in_0                  => axilRst,
         pm_tick_0                         => '0',
         s_axi_aclk_0                      => axilClk,
         s_axi_aresetn_0                   => axilRstL,
         s_axi_awaddr_0                    => axilWriteMaster.awaddr,
         s_axi_awvalid_0                   => axilWriteMaster.awvalid,
         s_axi_awready_0                   => axilWriteSlave.awready,
         s_axi_wdata_0                     => axilWriteMaster.wdata,
         s_axi_wstrb_0                     => axilWriteMaster.wstrb,
         s_axi_wvalid_0                    => axilWriteMaster.wvalid,
         s_axi_wready_0                    => axilWriteSlave.wready,
         s_axi_bresp_0                     => axilWriteSlave.bresp,
         s_axi_bvalid_0                    => axilWriteSlave.bvalid,
         s_axi_bready_0                    => axilWriteMaster.bready,
         s_axi_araddr_0                    => axilReadMaster.araddr,
         s_axi_arvalid_0                   => axilReadMaster.arvalid,
         s_axi_arready_0                   => axilReadSlave.arready,
         s_axi_rdata_0                     => axilReadSlave.rdata,
         s_axi_rresp_0                     => axilReadSlave.rresp,
         s_axi_rvalid_0                    => axilReadSlave.rvalid,
         s_axi_rready_0                    => axilReadMaster.rready,
         rx_reset_0                        => axilRst,
         rx_mii_d_0                        => xgmiiRxd,
         rx_mii_c_0                        => xgmiiRxc,
         stat_rx_framing_err_0             => open,
         stat_rx_framing_err_valid_0       => open,
         stat_rx_local_fault_0             => open,
         stat_rx_block_lock_0              => open,
         stat_rx_valid_ctrl_code_0         => open,
         stat_rx_status_0                  => open,
         stat_rx_hi_ber_0                  => open,
         stat_rx_bad_code_0                => open,
         stat_rx_bad_code_valid_0          => open,
         stat_rx_error_0                   => open,
         stat_rx_error_valid_0             => open,
         stat_rx_fifo_error_0              => open,
         stat_tx_fifo_error_0              => open,
         tx_reset_0                        => axilRst,
         tx_mii_d_0                        => xgmiiTxd,
         tx_mii_c_0                        => xgmiiTxc,
         stat_tx_local_fault_0             => open,
         stat_fec_inc_correct_count_0      => open,
         stat_fec_inc_cant_correct_count_0 => open,
         stat_fec_lock_error_0             => open,
         stat_fec_rx_lock_0                => open,
         user_reg0_0                       => open);

   U_phyClk312 : entity surf.ClockManagerUltraScale
      generic map(
         TPD_G             => TPD_G,
         TYPE_G            => "PLL",
         INPUT_BUFG_G      => false,
         FB_BUFG_G         => true,
         RST_IN_POLARITY_G => '1',
         NUM_CLOCKS_G      => 1,
         -- PLL attributes
         CLKIN_PERIOD_G    => 6.4,      -- 156.25 MHz
         CLKFBOUT_MULT_G   => 8,        -- 1.25GHz = 8 x 156.25 MHz
         CLKOUT0_DIVIDE_G  => 4)        -- 312.5MHz = 1.25GHz/4
      port map(
         -- Clock Input
         clkIn     => phyClk156,
         rstIn     => axilRst,
         -- Clock Outputs
         clkOut(0) => phyClk312,
         -- Reset Outputs
         rstOut(0) => phyRst312);

   U_Bridge : entity surf.CoaXPressOverFiberBridge
      generic map (
         TPD_G   => TPD_G,
         LANE0_G => LANE0_G)
      port map (
         -- XGMII TX interface (txClk156 domain)
         txClk156   => phyClk156,
         xgmiiTxd   => xgmiiTxd,
         xgmiiTxc   => xgmiiTxc,
         -- XGMII RX interface (rxClk156 domain)
         rxClk156   => phyClk156,
         xgmiiRxd   => xgmiiRxd,
         xgmiiRxc   => xgmiiRxc,
         -- CXP TX interface (txClk312 domain)
         txClk312   => phyClk312,
         txRst312   => phyRst312,
         txLsValid  => txLsValid,
         txLsData   => txLsData,
         txLsDataK  => txLsDataK,
         txLsRate   => txLsRate,
         txLsLaneEn => txLsLaneEn,
         txHsEnable => txHsEnable,
         txHsData   => txHsData,
         txHsDataK  => txHsDataK,
         -- CXP RX interface (rxClk312 domain)
         rxClk312   => phyClk312,
         rxRst312   => phyRst312,
         rxData     => rxData,
         rxDataK    => rxDataK);

end mapping;
