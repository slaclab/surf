-------------------------------------------------------------------------------
-- File       : Pgp3GthUsIpWrapper.vhd
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: 
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
use work.StdRtlPkg.all;
use work.AxiLitePkg.all;

entity Pgp3GthUsIpWrapper is
   generic (
      TPD_G         : time    := 1 ns;
      EN_DRP_G      : boolean := true;
      RATE_G        : string  := "10.3125Gbps";  -- or "6.25Gbps"
      TX_POLARITY_G : sl      := '0';
      RX_POLARITY_G : sl      := '0');
   port (
      stableClk      : in  sl;
      stableRst      : in  sl;
      -- QPLL Interface
      qpllLock       : in  slv(1 downto 0);
      qpllclk        : in  slv(1 downto 0);
      qpllrefclk     : in  slv(1 downto 0);
      qpllRst        : out slv(1 downto 0);
      gtRefclk       : in sl;
      -- GTH FPGA IO
      gtRxP          : in  sl;
      gtRxN          : in  sl;
      gtTxP          : out sl;
      gtTxN          : out sl;
      -- Rx ports
      rxReset        : in  sl;
      rxUsrClkActive : out sl;
      rxResetDone    : out sl;
      rxUsrClk       : out sl;
      rxUsrClk2      : out sl;
      rxUsrClkRst    : out sl;
      rxData         : out slv(63 downto 0);
      rxDataValid    : out sl;
      rxHeader       : out slv(1 downto 0);
      rxHeaderValid  : out sl;
      rxStartOfSeq   : out sl;
      rxGearboxSlip  : in  sl;
      rxOutClk       : out sl;
      -- Tx Ports
      txReset        : in  sl;
      txUsrClkActive : out sl;
      txResetDone    : out sl;
      txUsrClk       : out sl;
      txUsrClk2      : out sl;
      txUsrClkRst    : out sl;
      txData         : in  slv(63 downto 0);
      txHeader       : in  slv(1 downto 0);
      txOutClk       : out sl;
      loopback       : in  slv(2 downto 0);

      -- AXI-Lite DRP Interface
      axilClk         : in  sl                     := '0';
      axilRst         : in  sl                     := '0';
      axilReadMaster  : in  AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
      axilReadSlave   : out AxiLiteReadSlaveType   := AXI_LITE_READ_SLAVE_EMPTY_DECERR_C;
      axilWriteMaster : in  AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
      axilWriteSlave  : out AxiLiteWriteSlaveType  := AXI_LITE_WRITE_SLAVE_EMPTY_DECERR_C);
end entity Pgp3GthUsIpWrapper;

architecture mapping of Pgp3GthUsIpWrapper is

   component Pgp3GthUsIp10G
      port (
    gtwiz_userclk_tx_reset_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_userclk_tx_srcclk_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_userclk_tx_usrclk_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_userclk_tx_usrclk2_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_userclk_tx_active_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_userclk_rx_reset_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_userclk_rx_srcclk_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_userclk_rx_usrclk_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_userclk_rx_usrclk2_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_userclk_rx_active_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_reset_clk_freerun_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_reset_all_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_reset_tx_pll_and_datapath_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_reset_tx_datapath_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_reset_rx_pll_and_datapath_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_reset_rx_datapath_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_reset_qpll0lock_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_reset_rx_cdr_stable_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_reset_tx_done_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_reset_rx_done_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_reset_qpll0reset_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_userdata_tx_in : IN STD_LOGIC_VECTOR(63 DOWNTO 0);
    gtwiz_userdata_rx_out : OUT STD_LOGIC_VECTOR(63 DOWNTO 0);
    drpaddr_in : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
    drpclk_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    drpdi_in : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    drpen_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    drpwe_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    gthrxn_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    gthrxp_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    loopback_in : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
    qpll0clk_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    qpll0refclk_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    qpll1clk_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    qpll1refclk_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    rxgearboxslip_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    rxpolarity_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    txdiffctrl_in : IN STD_LOGIC_VECTOR(4 DOWNTO 0);
    txheader_in : IN STD_LOGIC_VECTOR(5 DOWNTO 0);
    txpolarity_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    txpostcursor_in : IN STD_LOGIC_VECTOR(4 DOWNTO 0);
    txprecursor_in : IN STD_LOGIC_VECTOR(4 DOWNTO 0);
    txsequence_in : IN STD_LOGIC_VECTOR(6 DOWNTO 0);
    drpdo_out : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
    drprdy_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    gthtxn_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    gthtxp_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtpowergood_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    rxdatavalid_out : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    rxheader_out : OUT STD_LOGIC_VECTOR(5 DOWNTO 0);
    rxheadervalid_out : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    rxpmaresetdone_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    rxprgdivresetdone_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    rxstartofseq_out : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    txpmaresetdone_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    txprgdivresetdone_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0)
  );
END COMPONENT;

   component Pgp3GthUsIp6G
      port (
    gtwiz_userclk_tx_reset_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_userclk_tx_srcclk_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_userclk_tx_usrclk_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_userclk_tx_usrclk2_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_userclk_tx_active_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_userclk_rx_reset_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_userclk_rx_srcclk_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_userclk_rx_usrclk_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_userclk_rx_usrclk2_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_userclk_rx_active_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_reset_clk_freerun_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_reset_all_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_reset_tx_pll_and_datapath_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_reset_tx_datapath_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_reset_rx_pll_and_datapath_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_reset_rx_datapath_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_reset_rx_cdr_stable_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_reset_tx_done_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_reset_rx_done_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_userdata_tx_in : IN STD_LOGIC_VECTOR(63 DOWNTO 0);
    gtwiz_userdata_rx_out : OUT STD_LOGIC_VECTOR(63 DOWNTO 0);
    gtrefclk00_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    qpll0outclk_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    qpll0outrefclk_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    drpaddr_in : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
    drpclk_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    drpdi_in : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    drpen_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    drpwe_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    gthrxn_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    gthrxp_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    loopback_in : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
    rxgearboxslip_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    rxpolarity_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    txdiffctrl_in : IN STD_LOGIC_VECTOR(4 DOWNTO 0);
    txheader_in : IN STD_LOGIC_VECTOR(5 DOWNTO 0);
    txpolarity_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    txpostcursor_in : IN STD_LOGIC_VECTOR(4 DOWNTO 0);
    txprecursor_in : IN STD_LOGIC_VECTOR(4 DOWNTO 0);
    txsequence_in : IN STD_LOGIC_VECTOR(6 DOWNTO 0);
    drpdo_out : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
    drprdy_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    gthtxn_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    gthtxp_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtpowergood_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    rxdatavalid_out : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    rxheader_out : OUT STD_LOGIC_VECTOR(5 DOWNTO 0);
    rxheadervalid_out : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    rxpmaresetdone_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    rxprgdivresetdone_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    rxstartofseq_out : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    txpmaresetdone_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    txprgdivresetdone_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0)
  );
END COMPONENT;

   component Pgp3GthUsIp3G
  PORT (
    gtwiz_userclk_tx_reset_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_userclk_tx_srcclk_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_userclk_tx_usrclk_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_userclk_tx_usrclk2_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_userclk_tx_active_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_userclk_rx_reset_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_userclk_rx_srcclk_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_userclk_rx_usrclk_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_userclk_rx_usrclk2_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_userclk_rx_active_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_reset_clk_freerun_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_reset_all_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_reset_tx_pll_and_datapath_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_reset_tx_datapath_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_reset_rx_pll_and_datapath_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_reset_rx_datapath_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_reset_rx_cdr_stable_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_reset_tx_done_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_reset_rx_done_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_userdata_tx_in : IN STD_LOGIC_VECTOR(63 DOWNTO 0);
    gtwiz_userdata_rx_out : OUT STD_LOGIC_VECTOR(63 DOWNTO 0);
    gtrefclk00_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    qpll0outclk_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    qpll0outrefclk_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    drpaddr_in : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
    drpclk_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    drpdi_in : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    drpen_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    drpwe_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    gthrxn_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    gthrxp_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    loopback_in : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
    rxgearboxslip_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    rxpolarity_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    txdiffctrl_in : IN STD_LOGIC_VECTOR(4 DOWNTO 0);
    txheader_in : IN STD_LOGIC_VECTOR(5 DOWNTO 0);
    txpolarity_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    txpostcursor_in : IN STD_LOGIC_VECTOR(4 DOWNTO 0);
    txprecursor_in : IN STD_LOGIC_VECTOR(4 DOWNTO 0);
    txsequence_in : IN STD_LOGIC_VECTOR(6 DOWNTO 0);
    drpdo_out : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
    drprdy_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    gthtxn_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    gthtxp_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtpowergood_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    rxdatavalid_out : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    rxheader_out : OUT STD_LOGIC_VECTOR(5 DOWNTO 0);
    rxheadervalid_out : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    rxpmaresetdone_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    rxprgdivresetdone_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    rxstartofseq_out : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    txpmaresetdone_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    txprgdivresetdone_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0)
  );
END COMPONENT;
   signal dummy1  : sl;
   signal dummy2  : sl;
   signal dummy3  : slv(3 downto 0);
   signal dummy4  : sl;
   signal dummy5  : sl;
   signal dummy6  : sl;
   signal dummy7  : sl;
   signal dummy8  : sl;
   signal dummy9  : sl;
   signal dummy10 : sl;
   signal dummy11 : sl;
   signal zeroBit : sl;

   signal txsequence_in : slv(6 downto 0);
   signal txheader_in   : slv(5 downto 0);

   signal rxUsrClk2Int      : sl;
   signal rxUsrClkActiveInt : sl;
   signal txUsrClk2Int      : sl;
   signal txUsrClkActiveInt : sl;

   signal drpAddr : slv(9 downto 0)  := (others => '0');
   signal drpDi   : slv(15 downto 0) := (others => '0');
   signal drpDo   : slv(15 downto 0) := (others => '0');
   signal drpEn   : sl               := '0';
   signal drpWe   : sl               := '0';
   signal drpRdy  : sl               := '0';

begin

   rxUsrClk2      <= rxUsrClk2Int;
   rxUsrClkActive <= rxUsrClkActiveInt;
   txUsrClk2      <= txUsrClk2Int;
   txUsrClkActive <= txUsrClkActiveInt;

   U_RstSync_TX : entity work.RstSync
      generic map (
         TPD_G          => TPD_G,
         IN_POLARITY_G  => '0',
         OUT_POLARITY_G => '1',
         OUT_REG_RST_G  => true)
      port map (
         clk      => txUsrClk2Int,       -- [in]
         asyncRst => txUsrClkActiveInt,  -- [in]
         syncRst  => txUsrClkRst);       -- [out]

   U_RstSync_RX : entity work.RstSync
      generic map (
         TPD_G          => TPD_G,
         IN_POLARITY_G  => '0',
         OUT_POLARITY_G => '1',
         OUT_REG_RST_G  => true)
      port map (
         clk      => rxUsrClk2Int,       -- [in]
         asyncRst => rxUsrClkActiveInt,  -- [in]
         syncRst  => rxUsrClkRst);       -- [out]

   GEN_10G : if (RATE_G = "10.3125Gbps") generate
      U_Pgp3GthUsIp : Pgp3GthUsIp10G
         port map (
            gtwiz_userclk_tx_reset_in(0)          => txReset,
            gtwiz_userclk_tx_srcclk_out(0)        => txOutClk,
            gtwiz_userclk_tx_usrclk_out(0)        => txUsrClk,
            gtwiz_userclk_tx_usrclk2_out(0)       => txUsrClk2Int,
            gtwiz_userclk_tx_active_out(0)        => txUsrClkActiveInt,
            gtwiz_userclk_rx_reset_in(0)          => rxReset,
            gtwiz_userclk_rx_srcclk_out(0)        => rxOutClk,
            gtwiz_userclk_rx_usrclk_out(0)        => rxUsrClk,
            gtwiz_userclk_rx_usrclk2_out(0)       => rxUsrClk2Int,
            gtwiz_userclk_rx_active_out(0)        => rxUsrClkActiveInt,
            gtwiz_reset_clk_freerun_in(0)         => stableClk,
            gtwiz_reset_all_in(0)                 => stableRst,
            gtwiz_reset_tx_pll_and_datapath_in(0) => zeroBit,
            gtwiz_reset_tx_datapath_in(0)         => zeroBit,
            gtwiz_reset_rx_pll_and_datapath_in(0) => zeroBit,
            gtwiz_reset_rx_datapath_in(0)         => rxReset,
            gtwiz_reset_qpll0lock_in(0)           => qpllLock(0),
            gtwiz_reset_rx_cdr_stable_out(0)      => dummy5,
            gtwiz_reset_tx_done_out(0)            => txResetDone,
            gtwiz_reset_rx_done_out(0)            => rxResetDone,
            gtwiz_reset_qpll0reset_out(0)         => qpllRst(0),
            gtwiz_userdata_tx_in                  => txData,
            gtwiz_userdata_rx_out                 => rxData,
            drpclk_in(0)                          => stableClk,
            drpaddr_in                            => drpAddr,
            drpdi_in                              => drpDi,
            drpen_in(0)                           => drpEn,
            drpwe_in(0)                           => drpWe,
            drpdo_out                             => drpDo,
            drprdy_out(0)                         => drpRdy,
            gthrxn_in(0)                          => gtRxN,
            gthrxp_in(0)                          => gtRxP,
            loopback_in                           => loopback,
            qpll0clk_in(0)                        => qpllclk(0),
            qpll0refclk_in(0)                     => qpllrefclk(0),
            qpll1clk_in(0)                        => qpllclk(1),
            qpll1refclk_in(0)                     => qpllrefclk(1),
            rxgearboxslip_in(0)                   => rxGearboxSlip,
            rxpolarity_in(0)                      => RX_POLARITY_G,
            txdiffctrl_in                         => "11111",
            txheader_in                           => txheader_in,
            txpolarity_in(0)                      => TX_POLARITY_G,
            txpostcursor_in                       => "00111",
            txprecursor_in                        => "00111",
            txsequence_in                         => txsequence_in,
            gthtxn_out(0)                         => gtTxN,
            gthtxp_out(0)                         => gtTxP,
            rxdatavalid_out(0)                    => rxDataValid,
            rxdatavalid_out(1)                    => dummy1,
            rxheader_out(1 downto 0)              => rxHeader,
            rxheader_out(5 downto 2)              => dummy3,
            rxheadervalid_out(0)                  => rxHeaderValid,
            rxheadervalid_out(1)                  => dummy4,
            rxpmaresetdone_out(0)                 => dummy8,
            rxprgdivresetdone_out(0)              => dummy9,
            rxstartofseq_out(1)                   => dummy2,
            rxstartofseq_out(0)                   => rxStartOfSeq,
            txpmaresetdone_out(0)                 => dummy10,
            txprgdivresetdone_out(0)              => dummy11);
   end generate GEN_10G;

   GEN_6G : if (RATE_G = "6.25Gbps") generate
      U_Pgp3GthUsIp : Pgp3GthUsIp6G
         port map (
            gtwiz_userclk_tx_reset_in(0)          => txReset,
            gtwiz_userclk_tx_srcclk_out(0)        => txOutClk,
            gtwiz_userclk_tx_usrclk_out(0)        => txUsrClk,
            gtwiz_userclk_tx_usrclk2_out(0)       => txUsrClk2Int,
            gtwiz_userclk_tx_active_out(0)        => txUsrClkActiveInt,
            gtwiz_userclk_rx_reset_in(0)          => rxReset,
            gtwiz_userclk_rx_srcclk_out(0)        => rxOutClk,
            gtwiz_userclk_rx_usrclk_out(0)        => rxUsrClk,
            gtwiz_userclk_rx_usrclk2_out(0)       => rxUsrClk2Int,
            gtwiz_userclk_rx_active_out(0)        => rxUsrClkActiveInt,
            gtwiz_reset_clk_freerun_in(0)         => stableClk,
            gtwiz_reset_all_in(0)                 => stableRst,
            gtwiz_reset_tx_pll_and_datapath_in(0) => zeroBit,
            gtwiz_reset_tx_datapath_in(0)         => zeroBit,
            gtwiz_reset_rx_pll_and_datapath_in(0) => zeroBit,
            gtwiz_reset_rx_datapath_in(0)         => rxReset,
            --gtwiz_reset_qpll0lock_in(0)           => qpllLock(0),
            gtwiz_reset_rx_cdr_stable_out(0)      => dummy5,
            gtwiz_reset_tx_done_out(0)            => txResetDone,
            gtwiz_reset_rx_done_out(0)            => rxResetDone,
            --gtwiz_reset_qpll0reset_out(0)         => qpllRst(0),
            gtwiz_userdata_tx_in                  => txData,
            gtwiz_userdata_rx_out                 => rxData,
            gtrefclk00_in(0)                      => gtRefclk,
            drpclk_in(0)                          => stableClk,
            drpaddr_in                            => drpAddr,
            drpdi_in                              => drpDi,
            drpen_in(0)                           => drpEn,
            drpwe_in(0)                           => drpWe,
            drpdo_out                             => drpDo,
            drprdy_out(0)                         => drpRdy,
            gthrxn_in(0)                          => gtRxN,
            gthrxp_in(0)                          => gtRxP,
            loopback_in                           => loopback,
            --qpll0clk_in(0)                        => qpllclk(0),
            --qpll0refclk_in(0)                     => qpllrefclk(0),
            --qpll1clk_in(0)                        => qpllclk(1),
            --qpll1refclk_in(0)                     => qpllrefclk(1),
            rxgearboxslip_in(0)                   => rxGearboxSlip,
            rxpolarity_in(0)                      => RX_POLARITY_G,
            txdiffctrl_in                         => "11111",
            txheader_in                           => txheader_in,
            txpolarity_in(0)                      => TX_POLARITY_G,
            txpostcursor_in                       => "00111",
            txprecursor_in                        => "00111",
            txsequence_in                         => txsequence_in,
            gthtxn_out(0)                         => gtTxN,
            gthtxp_out(0)                         => gtTxP,
            rxdatavalid_out(0)                    => rxDataValid,
            rxdatavalid_out(1)                    => dummy1,
            rxheader_out(1 downto 0)              => rxHeader,
            rxheader_out(5 downto 2)              => dummy3,
            rxheadervalid_out(0)                  => rxHeaderValid,
            rxheadervalid_out(1)                  => dummy4,
            rxpmaresetdone_out(0)                 => dummy8,
            rxprgdivresetdone_out(0)              => dummy9,
            rxstartofseq_out(1)                   => dummy2,
            rxstartofseq_out(0)                   => rxStartOfSeq,
            txpmaresetdone_out(0)                 => dummy10,
            txprgdivresetdone_out(0)              => dummy11);
   end generate GEN_6G;

   GEN_3G : if (RATE_G = "3.125Gbps") generate
      U_Pgp3GthUsIp : Pgp3GthUsIp3G
         port map (
            gtwiz_userclk_tx_reset_in(0)          => txReset,
            gtwiz_userclk_tx_srcclk_out(0)        => txOutClk,
            gtwiz_userclk_tx_usrclk_out(0)        => txUsrClk,
            gtwiz_userclk_tx_usrclk2_out(0)       => txUsrClk2Int,
            gtwiz_userclk_tx_active_out(0)        => txUsrClkActiveInt,
            gtwiz_userclk_rx_reset_in(0)          => rxReset,
            gtwiz_userclk_rx_srcclk_out(0)        => rxOutClk,
            gtwiz_userclk_rx_usrclk_out(0)        => rxUsrClk,
            gtwiz_userclk_rx_usrclk2_out(0)       => rxUsrClk2Int,
            gtwiz_userclk_rx_active_out(0)        => rxUsrClkActiveInt,
            gtwiz_reset_clk_freerun_in(0)         => stableClk,
            gtwiz_reset_all_in(0)                 => stableRst,
            gtwiz_reset_tx_pll_and_datapath_in(0) => zeroBit,
            gtwiz_reset_tx_datapath_in(0)         => zeroBit,
            gtwiz_reset_rx_pll_and_datapath_in(0) => zeroBit,
            gtwiz_reset_rx_datapath_in(0)         => rxReset,
            --gtwiz_reset_qpll0lock_in(0)           => qpllLock(0),
            gtwiz_reset_rx_cdr_stable_out(0)      => dummy5,
            gtwiz_reset_tx_done_out(0)            => txResetDone,
            gtwiz_reset_rx_done_out(0)            => rxResetDone,
           -- gtwiz_reset_qpll0reset_out(0)         => qpllRst(0),
            gtwiz_userdata_tx_in                  => txData,
            gtwiz_userdata_rx_out                 => rxData,
            gtrefclk00_in(0)                      => gtRefclk,
            drpclk_in(0)                          => stableClk,
            drpaddr_in                            => drpAddr,
            drpdi_in                              => drpDi,
            drpen_in(0)                           => drpEn,
            drpwe_in(0)                           => drpWe,
            drpdo_out                             => drpDo,
            drprdy_out(0)                         => drpRdy,
            gthrxn_in(0)                          => gtRxN,
            gthrxp_in(0)                          => gtRxP,
            loopback_in                           => loopback,
            --qpll0clk_in(0)                        => qpllclk(0),
            --qpll0refclk_in(0)                     => qpllrefclk(0),
            --qpll1clk_in(0)                        => qpllclk(1),
            --qpll1refclk_in(0)                     => qpllrefclk(1),
            rxgearboxslip_in(0)                   => rxGearboxSlip,
            rxpolarity_in(0)                      => RX_POLARITY_G,
            txdiffctrl_in                         => "11111",
            txheader_in                           => txheader_in,
            txpolarity_in(0)                      => TX_POLARITY_G,
            txpostcursor_in                       => "00111",
            txprecursor_in                        => "00111",
            txsequence_in                         => txsequence_in,
            gthtxn_out(0)                         => gtTxN,
            gthtxp_out(0)                         => gtTxP,
            rxdatavalid_out(0)                    => rxDataValid,
            rxdatavalid_out(1)                    => dummy1,
            rxheader_out(1 downto 0)              => rxHeader,
            rxheader_out(5 downto 2)              => dummy3,
            rxheadervalid_out(0)                  => rxHeaderValid,
            rxheadervalid_out(1)                  => dummy4,
            rxpmaresetdone_out(0)                 => dummy8,
            rxprgdivresetdone_out(0)              => dummy9,
            rxstartofseq_out(1)                   => dummy2,
            rxstartofseq_out(0)                   => rxStartOfSeq,
            txpmaresetdone_out(0)                 => dummy10,
            txprgdivresetdone_out(0)              => dummy11);
   end generate GEN_3G;

   qpllRst(1)                <= '0';
   zeroBit                   <= '0';
   txsequence_in(6)          <= '0';
   txsequence_in(5 downto 0) <= (others => '0');
   txheader_in(5 downto 2)   <= (others => '0');
   txheader_in(1 downto 0)   <= txHeader;

   GEN_DRP : if (EN_DRP_G) generate
      U_AxiLiteToDrp_1 : entity work.AxiLiteToDrp
         generic map (
            TPD_G            => TPD_G,
            COMMON_CLK_G     => false,
            EN_ARBITRATION_G => false,
            ADDR_WIDTH_G     => 10,
            DATA_WIDTH_G     => 16)
         port map (
            axilClk         => axilClk,          -- [in]
            axilRst         => axilRst,          -- [in]
            axilReadMaster  => axilReadMaster,   -- [in]
            axilReadSlave   => axilReadSlave,    -- [out]
            axilWriteMaster => axilWriteMaster,  -- [in]
            axilWriteSlave  => axilWriteSlave,   -- [out]
            drpClk          => stableClk,        -- [in]
            drpRst          => stableRst,        -- [in]
            drpReq          => open,             -- [out]
            drpRdy          => drpRdy,           -- [in]
            drpEn           => drpEn,            -- [out]
            drpWe           => drpWe,            -- [out]
            drpUsrRst       => open,             -- [out]
            drpAddr         => drpAddr,          -- [out]
            drpDi           => drpDi,            -- [out]
            drpDo           => drpDo);           -- [in]
   end generate GEN_DRP;

end architecture mapping;
