-------------------------------------------------------------------------------
-- File       : Pgp3GthUsIpWrapper.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-06-29
-- Last update: 2017-11-01
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
      TPD_G             : time            := 1 ns;
      EN_DRP_G          : boolean         := true;
      AXIL_ERROR_RESP_G : slv(1 downto 0) := AXI_RESP_DECERR_C);
   port (
      stableClk      : in  sl;
      stableRst      : in  sl;
      -- QPLL Interface
      qpllLock       : in  slv(1 downto 0);
      qpllclk        : in  slv(1 downto 0);
      qpllrefclk     : in  slv(1 downto 0);
      qpllRst        : out slv(1 downto 0);
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
      txSequence     : in  slv(5 downto 0);
      txOutClk       : out sl;
      loopback       : in  slv(2 downto 0);

      -- AXI-Lite DRP Interface
      axilClk         : in  sl                     := '0';
      axilRst         : in  sl                     := '0';
      axilReadMaster  : in  AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
      axilWriteSlave  : out AxiLiteWriteSlaveType);

end entity Pgp3GthUsIpWrapper;

architecture mapping of Pgp3GthUsIpWrapper is

   component Pgp3GthUsIp
      port (
         gtwiz_userclk_tx_reset_in          : in  slv(0 downto 0);
         gtwiz_userclk_tx_srcclk_out        : out slv(0 downto 0);
         gtwiz_userclk_tx_usrclk_out        : out slv(0 downto 0);
         gtwiz_userclk_tx_usrclk2_out       : out slv(0 downto 0);
         gtwiz_userclk_tx_active_out        : out slv(0 downto 0);
         gtwiz_userclk_rx_reset_in          : in  slv(0 downto 0);
         gtwiz_userclk_rx_srcclk_out        : out slv(0 downto 0);
         gtwiz_userclk_rx_usrclk_out        : out slv(0 downto 0);
         gtwiz_userclk_rx_usrclk2_out       : out slv(0 downto 0);
         gtwiz_userclk_rx_active_out        : out slv(0 downto 0);
         gtwiz_reset_clk_freerun_in         : in  slv(0 downto 0);
         gtwiz_reset_all_in                 : in  slv(0 downto 0);
         gtwiz_reset_tx_pll_and_datapath_in : in  slv(0 downto 0);
         gtwiz_reset_tx_datapath_in         : in  slv(0 downto 0);
         gtwiz_reset_rx_pll_and_datapath_in : in  slv(0 downto 0);
         gtwiz_reset_rx_datapath_in         : in  slv(0 downto 0);
         gtwiz_reset_qpll0lock_in           : in  slv(0 downto 0);
         gtwiz_reset_rx_cdr_stable_out      : out slv(0 downto 0);
         gtwiz_reset_tx_done_out            : out slv(0 downto 0);
         gtwiz_reset_rx_done_out            : out slv(0 downto 0);
         gtwiz_reset_qpll0reset_out         : out slv(0 downto 0);
         gtwiz_userdata_tx_in               : in  slv(63 downto 0);
         gtwiz_userdata_rx_out              : out slv(63 downto 0);
         drpaddr_in                         : in  slv(8 downto 0);
         drpclk_in                          : in  slv(0 downto 0);
         drpdi_in                           : in  slv(15 downto 0);
         drpen_in                           : in  slv(0 downto 0);
         drpwe_in                           : in  slv(0 downto 0);
         drpdo_out                          : out slv(15 downto 0);
         drprdy_out                         : out slv(0 downto 0);
         gthrxn_in                          : in  slv(0 downto 0);
         gthrxp_in                          : in  slv(0 downto 0);
         loopback_in                        : in  slv(2 downto 0);
         qpll0clk_in                        : in  slv(0 downto 0);
         qpll0refclk_in                     : in  slv(0 downto 0);
         qpll1clk_in                        : in  slv(0 downto 0);
         qpll1refclk_in                     : in  slv(0 downto 0);
         rxgearboxslip_in                   : in  slv(0 downto 0);
         txheader_in                        : in  slv(5 downto 0);
         txsequence_in                      : in  slv(6 downto 0);
         gthtxn_out                         : out slv(0 downto 0);
         gthtxp_out                         : out slv(0 downto 0);
         gtpowergood_out                    : out slv(0 downto 0);
         rxdatavalid_out                    : out slv(1 downto 0);
         rxheader_out                       : out slv(5 downto 0);
         rxheadervalid_out                  : out slv(1 downto 0);
         rxpmaresetdone_out                 : out slv(0 downto 0);
         rxprgdivresetdone_out              : out slv(0 downto 0);
         rxstartofseq_out                   : out slv(1 downto 0);
         txpmaresetdone_out                 : out slv(0 downto 0);
         txprgdivresetdone_out              : out slv(0 downto 0)
         );
   end component;

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

   signal drpAddr : slv(8 downto 0)  := (others => '0');
   signal drpDi   : slv(15 downto 0) := (others => '0');
   signal drpDo   : slv(15 downto 0) := (others => '0');
   signal drpEn   : sl               := '0';
   signal drpWe   : sl               := '0';
   signal drpRdy  : sl               := '0'
                                        ;
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
   --
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

   U_Pgp3GthUsIp_1 : Pgp3GthUsIp
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
         txheader_in                           => txheader_in,
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
            AXI_ERROR_RESP_G => AXIL_ERROR_RESP_G,
            COMMON_CLK_G     => false,
            EN_ARBITRATION_G => false,
            ADDR_WIDTH_G     => 9,
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
