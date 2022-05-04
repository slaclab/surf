-------------------------------------------------------------------------------
-- Title      : CoaXPress Protocol: http://jiia.org/wp-content/themes/jiia/pdf/standard_dl/coaxpress/CXP-001-2021.pdf
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: CoaXPress GTH Ultrascale IP core Wrapper
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

entity CoaXPressGthUsIpWrapper is
   generic (
      TPD_G      : time         := 1 ns;
      CXP_RATE_G : CxpSpeedType := CXP_12_C);
   port (
      -- Stable Clock and Reset
      stableClk25     : in  sl;
      stableRst25     : in  sl;
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
      txData          : in  slv(31 downto 0);
      txLinkUp        : out sl;
      -- Rx Interface (rxClk domain)
      rxClk           : out sl;
      rxRst           : out sl;
      rxData          : out slv(31 downto 0);
      rxDataK         : out slv(3 downto 0);
      rxDispErr       : out sl;
      rxDecErr        : out sl;
      rxLinkUp        : out sl;
      -- AXI-Lite DRP Interface
      axilClk         : in  sl;
      axilRst         : in  sl;
      axilReadMaster  : in  AxiLiteReadMasterType;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType;
      axilWriteSlave  : out AxiLiteWriteSlaveType);
end entity CoaXPressGthUsIpWrapper;

architecture mapping of CoaXPressGthUsIpWrapper is

   component CoaXPressGthUsIp12G
      port (
         gtwiz_userclk_tx_reset_in          : in  std_logic_vector(0 downto 0);
         gtwiz_userclk_tx_srcclk_out        : out std_logic_vector(0 downto 0);
         gtwiz_userclk_tx_usrclk_out        : out std_logic_vector(0 downto 0);
         gtwiz_userclk_tx_usrclk2_out       : out std_logic_vector(0 downto 0);
         gtwiz_userclk_tx_active_out        : out std_logic_vector(0 downto 0);
         gtwiz_userclk_rx_reset_in          : in  std_logic_vector(0 downto 0);
         gtwiz_userclk_rx_srcclk_out        : out std_logic_vector(0 downto 0);
         gtwiz_userclk_rx_usrclk_out        : out std_logic_vector(0 downto 0);
         gtwiz_userclk_rx_usrclk2_out       : out std_logic_vector(0 downto 0);
         gtwiz_userclk_rx_active_out        : out std_logic_vector(0 downto 0);
         gtwiz_buffbypass_tx_reset_in       : in  std_logic_vector(0 downto 0);
         gtwiz_buffbypass_tx_start_user_in  : in  std_logic_vector(0 downto 0);
         gtwiz_buffbypass_tx_done_out       : out std_logic_vector(0 downto 0);
         gtwiz_buffbypass_tx_error_out      : out std_logic_vector(0 downto 0);
         gtwiz_buffbypass_rx_reset_in       : in  std_logic_vector(0 downto 0);
         gtwiz_buffbypass_rx_start_user_in  : in  std_logic_vector(0 downto 0);
         gtwiz_buffbypass_rx_done_out       : out std_logic_vector(0 downto 0);
         gtwiz_buffbypass_rx_error_out      : out std_logic_vector(0 downto 0);
         gtwiz_reset_clk_freerun_in         : in  std_logic_vector(0 downto 0);
         gtwiz_reset_all_in                 : in  std_logic_vector(0 downto 0);
         gtwiz_reset_tx_pll_and_datapath_in : in  std_logic_vector(0 downto 0);
         gtwiz_reset_tx_datapath_in         : in  std_logic_vector(0 downto 0);
         gtwiz_reset_rx_pll_and_datapath_in : in  std_logic_vector(0 downto 0);
         gtwiz_reset_rx_datapath_in         : in  std_logic_vector(0 downto 0);
         gtwiz_reset_qpll0lock_in           : in  std_logic_vector(0 downto 0);
         gtwiz_reset_qpll1lock_in           : in  std_logic_vector(0 downto 0);
         gtwiz_reset_rx_cdr_stable_out      : out std_logic_vector(0 downto 0);
         gtwiz_reset_tx_done_out            : out std_logic_vector(0 downto 0);
         gtwiz_reset_rx_done_out            : out std_logic_vector(0 downto 0);
         gtwiz_reset_qpll0reset_out         : out std_logic_vector(0 downto 0);
         gtwiz_reset_qpll1reset_out         : out std_logic_vector(0 downto 0);
         gtwiz_userdata_tx_in               : in  std_logic_vector(31 downto 0);
         gtwiz_userdata_rx_out              : out std_logic_vector(31 downto 0);
         drpaddr_in                         : in  std_logic_vector(8 downto 0);
         drpclk_in                          : in  std_logic_vector(0 downto 0);
         drpdi_in                           : in  std_logic_vector(15 downto 0);
         drpen_in                           : in  std_logic_vector(0 downto 0);
         drpwe_in                           : in  std_logic_vector(0 downto 0);
         gthrxn_in                          : in  std_logic_vector(0 downto 0);
         gthrxp_in                          : in  std_logic_vector(0 downto 0);
         qpll0clk_in                        : in  std_logic_vector(0 downto 0);
         qpll0refclk_in                     : in  std_logic_vector(0 downto 0);
         qpll1clk_in                        : in  std_logic_vector(0 downto 0);
         qpll1refclk_in                     : in  std_logic_vector(0 downto 0);
         rx8b10ben_in                       : in  std_logic_vector(0 downto 0);
         rxcommadeten_in                    : in  std_logic_vector(0 downto 0);
         rxmcommaalignen_in                 : in  std_logic_vector(0 downto 0);
         rxpcommaalignen_in                 : in  std_logic_vector(0 downto 0);
         drpdo_out                          : out std_logic_vector(15 downto 0);
         drprdy_out                         : out std_logic_vector(0 downto 0);
         gthtxn_out                         : out std_logic_vector(0 downto 0);
         gthtxp_out                         : out std_logic_vector(0 downto 0);
         gtpowergood_out                    : out std_logic_vector(0 downto 0);
         rxbyteisaligned_out                : out std_logic_vector(0 downto 0);
         rxbyterealign_out                  : out std_logic_vector(0 downto 0);
         rxcommadet_out                     : out std_logic_vector(0 downto 0);
         rxctrl0_out                        : out std_logic_vector(15 downto 0);
         rxctrl1_out                        : out std_logic_vector(15 downto 0);
         rxctrl2_out                        : out std_logic_vector(7 downto 0);
         rxctrl3_out                        : out std_logic_vector(7 downto 0);
         rxpmaresetdone_out                 : out std_logic_vector(0 downto 0);
         txpmaresetdone_out                 : out std_logic_vector(0 downto 0);
         txprgdivresetdone_out              : out std_logic_vector(0 downto 0)
         );
   end component;

   signal txClock     : sl;
   signal txReset     : sl;
   signal txDone      : sl;
   signal txBypDone   : sl;
   signal txActive    : sl;
   signal txUsrClkRst : sl;

   signal rxClock     : sl;
   signal rxReset     : sl;
   signal rxDone      : sl;
   signal rxBypDone   : sl;
   signal rxActive    : sl;
   signal rxUsrReset  : sl;
   signal rxUsrClkRst : sl;

   signal rxDataInt : slv(31 downto 0) := (others => '0');
   signal rxctrl0   : slv(15 downto 0) := (others => '0');
   signal rxctrl1   : slv(15 downto 0) := (others => '0');
   signal rxctrl2   : slv(7 downto 0)  := (others => '0');
   signal rxctrl3   : slv(7 downto 0)  := (others => '0');

   signal drpAddr : slv(8 downto 0)  := (others => '0');
   signal drpDi   : slv(15 downto 0) := (others => '0');
   signal drpDo   : slv(15 downto 0) := (others => '0');
   signal drpEn   : sl               := '0';
   signal drpWe   : sl               := '0';
   signal drpRdy  : sl               := '0';

begin

   assert (CXP_RATE_G = CXP_12_C)
      report "CXP_RATE_G: Only CXP_12_C is supported at this time"
      severity error;

   ----------------------
   -- TX Clock and Resets
   ----------------------
   txClk   <= txClock;
   txReset <= stableRst25 or not(txDone) or not(txBypDone);

   U_txRst : entity surf.RstSync
      generic map (
         TPD_G          => TPD_G,
         IN_POLARITY_G  => '1',
         OUT_POLARITY_G => '1',
         OUT_REG_RST_G  => true)
      port map (
         clk      => txClock,
         asyncRst => txReset,
         syncRst  => txRst);

   U_txLinkUp : entity surf.RstSync
      generic map (
         TPD_G          => TPD_G,
         IN_POLARITY_G  => '1',
         OUT_POLARITY_G => '0',
         OUT_REG_RST_G  => true)
      port map (
         clk      => txClock,
         asyncRst => txReset,
         syncRst  => txLinkUp);

   U_txUsrClkRst : entity surf.RstSync
      generic map (
         TPD_G          => TPD_G,
         IN_POLARITY_G  => '0',
         OUT_POLARITY_G => '1',
         OUT_REG_RST_G  => true)
      port map (
         clk      => txClock,
         asyncRst => txActive,
         syncRst  => txUsrClkRst);

   ----------------------
   -- RX Clock and Resets
   ----------------------
   rxClk   <= rxClock;
   rxReset <= stableRst25 or not(rxDone) or not(rxBypDone);
   U_rxRst : entity surf.RstSync
      generic map (
         TPD_G          => TPD_G,
         IN_POLARITY_G  => '1',
         OUT_POLARITY_G => '1',
         OUT_REG_RST_G  => true)
      port map (
         clk      => rxClock,
         asyncRst => rxReset,
         syncRst  => rxRst);

   U_rxUsrClkRst : entity surf.RstSync
      generic map (
         TPD_G          => TPD_G,
         IN_POLARITY_G  => '1',
         OUT_POLARITY_G => '1',
         OUT_REG_RST_G  => true)
      port map (
         clk      => rxClock,
         asyncRst => rxUsrReset,
         syncRst  => rxUsrClkRst);

   rxUsrReset <= not(rxActive) or not(txBypDone);

   -------------------------------
   -- Register to help with timing
   -------------------------------
   process(rxClock)
   begin
      if rising_edge(rxClock) then
         rxData    <= rxDataInt                after TPD_G;
         rxDataK   <= rxctrl0(3 downto 0)      after TPD_G;
         rxDispErr <= uOr(rxctrl1(3 downto 0)) after TPD_G;
         rxDecErr  <= uOr(rxctrl3(3 downto 0)) after TPD_G;
         rxLinkUp  <= rxBypDone and rxDone     after TPD_G;
      end if;
   end process;

   GEN_12G : if (CXP_RATE_G = CXP_12_C) generate
      U_GT : CoaXPressGthUsIp12G
         port map (
            gtwiz_userclk_tx_reset_in          => (others => '0'),
            gtwiz_userclk_tx_srcclk_out        => open,
            gtwiz_userclk_tx_usrclk_out        => open,
            gtwiz_userclk_tx_usrclk2_out(0)    => txClock,
            gtwiz_userclk_tx_active_out(0)     => txActive,
            gtwiz_userclk_rx_reset_in          => (others => '0'),
            gtwiz_userclk_rx_srcclk_out        => open,
            gtwiz_userclk_rx_usrclk_out        => open,
            gtwiz_userclk_rx_usrclk2_out(0)    => rxClock,
            gtwiz_userclk_rx_active_out(0)     => rxActive,
            gtwiz_buffbypass_tx_reset_in(0)    => txUsrClkRst,
            gtwiz_buffbypass_tx_start_user_in  => (others => '0'),
            gtwiz_buffbypass_tx_done_out(0)    => txBypDone,
            gtwiz_buffbypass_tx_error_out      => open,
            gtwiz_buffbypass_rx_reset_in(0)    => rxUsrClkRst,
            gtwiz_buffbypass_rx_start_user_in  => (others => '0'),
            gtwiz_buffbypass_rx_done_out(0)    => rxBypDone,
            gtwiz_buffbypass_rx_error_out      => open,
            gtwiz_reset_clk_freerun_in(0)      => stableClk25,
            gtwiz_reset_all_in(0)              => stableRst25,
            gtwiz_reset_tx_pll_and_datapath_in => (others => '0'),
            gtwiz_reset_tx_datapath_in         => (others => '0'),
            gtwiz_reset_rx_pll_and_datapath_in => (others => '0'),
            gtwiz_reset_rx_datapath_in         => (others => '0'),
            gtwiz_reset_qpll0lock_in(0)        => qpllLock(0),
            gtwiz_reset_qpll1lock_in(0)        => qpllLock(1),
            gtwiz_reset_rx_cdr_stable_out      => open,
            gtwiz_reset_tx_done_out(0)         => txDone,
            gtwiz_reset_rx_done_out(0)         => rxDone,
            gtwiz_reset_qpll0reset_out(0)      => qpllRst(0),
            gtwiz_reset_qpll1reset_out(0)      => qpllRst(1),
            gtwiz_userdata_tx_in               => txData,
            gtwiz_userdata_rx_out              => rxDataInt,
            drpaddr_in                         => drpAddr,
            drpclk_in(0)                       => stableClk25,
            drpdi_in                           => drpDi,
            drpen_in(0)                        => drpEn,
            drpwe_in(0)                        => drpWe,
            gthrxn_in(0)                       => gtRxN,
            gthrxp_in(0)                       => gtRxP,
            qpll0clk_in(0)                     => qpllclk(0),
            qpll0refclk_in(0)                  => qpllrefclk(0),
            qpll1clk_in(0)                     => qpllclk(1),
            qpll1refclk_in(0)                  => qpllrefclk(1),
            rx8b10ben_in                       => (others => '1'),
            rxcommadeten_in                    => (others => '1'),
            rxmcommaalignen_in                 => (others => '1'),
            rxpcommaalignen_in                 => (others => '1'),
            drpdo_out                          => drpDo,
            drprdy_out(0)                      => drpRdy,
            gthtxn_out(0)                      => gtTxN,
            gthtxp_out(0)                      => gtTxP,
            gtpowergood_out                    => open,
            rxbyteisaligned_out                => open,
            rxbyterealign_out                  => open,
            rxcommadet_out                     => open,
            rxctrl0_out                        => rxctrl0,
            rxctrl1_out                        => rxctrl1,
            rxctrl2_out                        => rxctrl2,
            rxctrl3_out                        => rxctrl3,
            rxpmaresetdone_out                 => open,
            txpmaresetdone_out                 => open,
            txprgdivresetdone_out              => open);
   end generate GEN_12G;

   U_Drp : entity surf.AxiLiteToDrp
      generic map (
         TPD_G            => TPD_G,
         COMMON_CLK_G     => false,
         EN_ARBITRATION_G => false,
         ADDR_WIDTH_G     => 9,
         DATA_WIDTH_G     => 16)
      port map (
         axilClk         => axilClk,
         axilRst         => axilRst,
         axilReadMaster  => axilReadMaster,
         axilReadSlave   => axilReadSlave,
         axilWriteMaster => axilWriteMaster,
         axilWriteSlave  => axilWriteSlave,
         drpClk          => stableClk25,
         drpRst          => stableRst25,
         drpReq          => open,
         drpRdy          => drpRdy,
         drpEn           => drpEn,
         drpWe           => drpWe,
         drpUsrRst       => open,
         drpAddr         => drpAddr,
         drpDi           => drpDi,
         drpDo           => drpDo);

end mapping;
