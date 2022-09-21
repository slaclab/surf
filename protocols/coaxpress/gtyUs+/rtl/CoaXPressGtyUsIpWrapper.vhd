-------------------------------------------------------------------------------
-- Title      : CoaXPress Protocol: http://jiia.org/wp-content/themes/jiia/pdf/standard_dl/coaxpress/CXP-001-2021.pdf
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

entity CoaXPressGtyUsIpWrapper is
   generic (
      TPD_G      : time         := 1 ns;
      CXP_RATE_G : CxpSpeedType := CXP_12_C);
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
end entity CoaXPressGtyUsIpWrapper;

architecture mapping of CoaXPressGtyUsIpWrapper is

   component CoaXPressGtyUsIp12G
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
         gtwiz_reset_clk_freerun_in         : in  std_logic_vector(0 downto 0);
         gtwiz_reset_all_in                 : in  std_logic_vector(0 downto 0);
         gtwiz_reset_tx_pll_and_datapath_in : in  std_logic_vector(0 downto 0);
         gtwiz_reset_tx_datapath_in         : in  std_logic_vector(0 downto 0);
         gtwiz_reset_rx_pll_and_datapath_in : in  std_logic_vector(0 downto 0);
         gtwiz_reset_rx_datapath_in         : in  std_logic_vector(0 downto 0);
         gtwiz_reset_qpll0lock_in           : in  std_logic_vector(0 downto 0);
         gtwiz_reset_rx_cdr_stable_out      : out std_logic_vector(0 downto 0);
         gtwiz_reset_tx_done_out            : out std_logic_vector(0 downto 0);
         gtwiz_reset_rx_done_out            : out std_logic_vector(0 downto 0);
         gtwiz_reset_qpll0reset_out         : out std_logic_vector(0 downto 0);
         gtwiz_userdata_tx_in               : in  std_logic_vector(31 downto 0);
         gtwiz_userdata_rx_out              : out std_logic_vector(31 downto 0);
         drpaddr_in                         : in  std_logic_vector(9 downto 0);
         drpclk_in                          : in  std_logic_vector(0 downto 0);
         drpdi_in                           : in  std_logic_vector(15 downto 0);
         drpen_in                           : in  std_logic_vector(0 downto 0);
         drpwe_in                           : in  std_logic_vector(0 downto 0);
         gtyrxn_in                          : in  std_logic_vector(0 downto 0);
         gtyrxp_in                          : in  std_logic_vector(0 downto 0);
         qpll0clk_in                        : in  std_logic_vector(0 downto 0);
         qpll0refclk_in                     : in  std_logic_vector(0 downto 0);
         qpll1clk_in                        : in  std_logic_vector(0 downto 0);
         qpll1refclk_in                     : in  std_logic_vector(0 downto 0);
         rx8b10ben_in                       : in  std_logic_vector(0 downto 0);
         rxcommadeten_in                    : in  std_logic_vector(0 downto 0);
         rxmcommaalignen_in                 : in  std_logic_vector(0 downto 0);
         rxpcommaalignen_in                 : in  std_logic_vector(0 downto 0);
         tx8b10ben_in                       : in  std_logic_vector(0 downto 0);
         txctrl0_in                         : in  std_logic_vector(15 downto 0);
         txctrl1_in                         : in  std_logic_vector(15 downto 0);
         txctrl2_in                         : in  std_logic_vector(7 downto 0);
         drpdo_out                          : out std_logic_vector(15 downto 0);
         drprdy_out                         : out std_logic_vector(0 downto 0);
         gtpowergood_out                    : out std_logic_vector(0 downto 0);
         gtytxn_out                         : out std_logic_vector(0 downto 0);
         gtytxp_out                         : out std_logic_vector(0 downto 0);
         rxbyteisaligned_out                : out std_logic_vector(0 downto 0);
         rxbyterealign_out                  : out std_logic_vector(0 downto 0);
         rxcommadet_out                     : out std_logic_vector(0 downto 0);
         rxctrl0_out                        : out std_logic_vector(15 downto 0);
         rxctrl1_out                        : out std_logic_vector(15 downto 0);
         rxctrl2_out                        : out std_logic_vector(7 downto 0);
         rxctrl3_out                        : out std_logic_vector(7 downto 0);
         rxpmaresetdone_out                 : out std_logic_vector(0 downto 0);
         txpmaresetdone_out                 : out std_logic_vector(0 downto 0)
         );
   end component;

   signal txClock   : sl;
   signal txReset   : sl;
   signal txDone    : sl;
   signal txPmaDone : sl;
   signal txResetIn : sl;
   signal txActive  : sl;
   signal txctrl2   : slv(7 downto 0)  := x"0" & CXP_IDLE_K_C;
   signal txDataInt : slv(31 downto 0) := CXP_IDLE_C;

   signal rxClock   : sl;
   signal rxReset   : sl;
   signal rxDone    : sl;
   signal rxPmaDone : sl;
   signal rxResetIn : sl;
   signal rxActive  : sl;

   signal rxDataInt : slv(31 downto 0) := (others => '0');
   signal rxctrl0   : slv(15 downto 0) := (others => '0');
   signal rxctrl1   : slv(15 downto 0) := (others => '0');
   signal rxctrl2   : slv(7 downto 0)  := (others => '0');
   signal rxctrl3   : slv(7 downto 0)  := (others => '0');

   signal drpAddr : slv(9 downto 0)  := (others => '0');
   signal drpDi   : slv(15 downto 0) := (others => '0');
   signal drpDo   : slv(15 downto 0) := (others => '0');
   signal drpEn   : sl               := '0';
   signal drpWe   : sl               := '0';
   signal drpRdy  : sl               := '0';

begin

   assert (false)
      report "None CXP over fiber configuration not ready for production yet"
      severity error;

   assert (CXP_RATE_G = CXP_12_C)
      report "CXP_RATE_G: Only CXP_12_C is supported at this time"
      severity error;

   ----------------------
   -- TX Clock and Resets
   ----------------------
   txClk   <= txClock;
   txReset <= axilRst or not(txDone);

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

   -- -- Register to help with timing
   -- process(txClock)
   -- begin
      -- if rising_edge(txClock) then
         -- txDataInt <= txHsData         after TPD_G;
         -- txctrl2   <= x"0" & txHsDataK after TPD_G;
      -- end if;
   -- end process;

   -- The TX user clocking helper block should be held in reset until the clock source of that block is known to be
   -- stable. The following assignment is an example of how that stability can be determined, based on the selected TX
   -- user clock source. Replace the assignment with the appropriate signal or logic to achieve that behavior as needed.
   txResetIn <= not(txPmaDone);

   ----------------------
   -- RX Clock and Resets
   ----------------------
   rxClk   <= rxClock;
   rxReset <= axilRst or not(rxDone);

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

   U_rxLinkUp : entity surf.RstSync
      generic map (
         TPD_G          => TPD_G,
         IN_POLARITY_G  => '1',
         OUT_POLARITY_G => '0',
         OUT_REG_RST_G  => true)
      port map (
         clk      => rxClock,
         asyncRst => rxReset,
         syncRst  => rxLinkUp);

   -- Register to help with timing
   process(rxClock)
   begin
      if rising_edge(rxClock) then
         rxData    <= rxDataInt                after TPD_G;
         rxDataK   <= rxctrl0(3 downto 0)      after TPD_G;
         rxDispErr <= uOr(rxctrl1(3 downto 0)) after TPD_G;
         rxDecErr  <= uOr(rxctrl3(3 downto 0)) after TPD_G;
      end if;
   end process;

   -- The RX user clocking helper block should be held in reset until the clock source of that block is known to be
   -- stable. The following assignment is an example of how that stability can be determined, based on the selected RX
   -- user clock source. Replace the assignment with the appropriate signal or logic to achieve that behavior as needed.
   rxResetIn <= not(rxPmaDone);

   GEN_12G : if (CXP_RATE_G = CXP_12_C) generate
      U_GT : CoaXPressGtyUsIp12G
         port map (
            gtwiz_userclk_tx_reset_in(0)       => txResetIn,
            gtwiz_userclk_tx_srcclk_out        => open,
            gtwiz_userclk_tx_usrclk_out        => open,
            gtwiz_userclk_tx_usrclk2_out(0)    => txClock,
            gtwiz_userclk_tx_active_out(0)     => txActive,
            gtwiz_userclk_rx_reset_in(0)       => rxResetIn,
            gtwiz_userclk_rx_srcclk_out        => open,
            gtwiz_userclk_rx_usrclk_out        => open,
            gtwiz_userclk_rx_usrclk2_out(0)    => rxClock,
            gtwiz_userclk_rx_active_out(0)     => rxActive,
            gtwiz_reset_clk_freerun_in(0)      => axilClk,
            gtwiz_reset_all_in(0)              => axilRst,
            gtwiz_reset_tx_pll_and_datapath_in => (others => '0'),
            gtwiz_reset_tx_datapath_in         => (others => '0'),
            gtwiz_reset_rx_pll_and_datapath_in => (others => '0'),
            gtwiz_reset_rx_datapath_in         => (others => '0'),
            gtwiz_reset_qpll0lock_in(0)        => qpllLock(0),
            gtwiz_reset_rx_cdr_stable_out      => open,
            gtwiz_reset_tx_done_out(0)         => txDone,
            gtwiz_reset_rx_done_out(0)         => rxDone,
            gtwiz_reset_qpll0reset_out(0)      => qpllRst(0),
            gtwiz_userdata_tx_in               => txDataInt,
            gtwiz_userdata_rx_out              => rxDataInt,
            drpaddr_in                         => drpAddr,
            drpclk_in(0)                       => axilClk,
            drpdi_in                           => drpDi,
            drpen_in(0)                        => drpEn,
            drpwe_in(0)                        => drpWe,
            Gtyrxn_in(0)                       => gtRxN,
            Gtyrxp_in(0)                       => gtRxP,
            qpll0clk_in(0)                     => qpllclk(0),
            qpll0refclk_in(0)                  => qpllrefclk(0),
            qpll1clk_in(0)                     => qpllclk(1),
            qpll1refclk_in(0)                  => qpllrefclk(1),
            rx8b10ben_in                       => (others => '1'),
            rxcommadeten_in                    => (others => '1'),
            rxmcommaalignen_in                 => (others => '1'),
            rxpcommaalignen_in                 => (others => '1'),
            tx8b10ben_in                       => (others => '1'),
            txctrl0_in                         => (others => '0'),
            txctrl1_in                         => (others => '0'),
            txctrl2_in                         => txctrl2,
            drpdo_out                          => drpDo,
            drprdy_out(0)                      => drpRdy,
            gtpowergood_out                    => open,
            Gtytxn_out(0)                      => gtTxN,
            Gtytxp_out(0)                      => gtTxP,
            rxbyteisaligned_out                => open,
            rxbyterealign_out                  => open,
            rxcommadet_out                     => open,
            rxctrl0_out                        => rxctrl0,
            rxctrl1_out                        => rxctrl1,
            rxctrl2_out                        => rxctrl2,
            rxctrl3_out                        => rxctrl3,
            rxpmaresetdone_out(0)              => rxPmaDone,
            txpmaresetdone_out(0)              => txPmaDone);
   end generate GEN_12G;

   U_Drp : entity surf.AxiLiteToDrp
      generic map (
         TPD_G            => TPD_G,
         COMMON_CLK_G     => true,
         EN_ARBITRATION_G => false,
         ADDR_WIDTH_G     => 10,
         DATA_WIDTH_G     => 16)
      port map (
         axilClk         => axilClk,
         axilRst         => axilRst,
         axilReadMaster  => axilReadMaster,
         axilReadSlave   => axilReadSlave,
         axilWriteMaster => axilWriteMaster,
         axilWriteSlave  => axilWriteSlave,
         drpClk          => axilClk,
         drpRst          => axilRst,
         drpReq          => open,
         drpRdy          => drpRdy,
         drpEn           => drpEn,
         drpWe           => drpWe,
         drpUsrRst       => open,
         drpAddr         => drpAddr,
         drpDi           => drpDi,
         drpDo           => drpDo);

end mapping;
