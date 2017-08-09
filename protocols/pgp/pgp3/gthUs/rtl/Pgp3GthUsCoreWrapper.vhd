-------------------------------------------------------------------------------
-- File       : Pgp3GthCoreWrapper.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-06-29
-- Last update: 2017-08-08
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- This file is part of 'Example Project Firmware'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'Example Project Firmware', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use work.StdRtlPkg.all;

entity Pgp3GthCoreWrapper is

   generic (
      TPD_G : time := 1 ns);

   port (
      stableClk : in  sl;
      stableRst : in  sl;
      -- GTH FPGA IO
      gtRefClk  : in  sl;
      gtRxP     : in  sl;
      gtRxN     : in  sl;
      gtTxP     : out sl;
      gtTxN     : out sl;

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
      loopback       : in  slv(2 downto 0));
end entity Pgp3GthCoreWrapper;

architecture mapping of Pgp3GthCoreWrapper is


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
         gtwiz_reset_rx_cdr_stable_out      : out slv(0 downto 0);
         gtwiz_reset_tx_done_out            : out slv(0 downto 0);
         gtwiz_reset_rx_done_out            : out slv(0 downto 0);
         gtwiz_userdata_tx_in               : in  slv(63 downto 0);
         gtwiz_userdata_rx_out              : out slv(63 downto 0);
         gtrefclk00_in                      : in  slv(0 downto 0);
         qpll0outclk_out                    : out slv(0 downto 0);
         qpll0outrefclk_out                 : out slv(0 downto 0);
         gthrxn_in                          : in  slv(0 downto 0);
         gthrxp_in                          : in  slv(0 downto 0);
--         loopback_in                        : in  slv(2 downto 0);
         rxgearboxslip_in                   : in  slv(0 downto 0);
         txheader_in                        : in  slv(5 downto 0);
         txsequence_in                      : in  slv(6 downto 0);
         gthtxn_out                         : out slv(0 downto 0);
         gthtxp_out                         : out slv(0 downto 0);
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

   signal dummy1            : sl;
   signal dummy2            : sl;
   signal dummy3            : slv(3 downto 0);
   signal dummy4            : sl;
   signal dummy5            : sl;
   signal dummy6            : sl;
   signal dummy7            : sl;
   signal dummy8            : sl;
   signal dummy9            : sl;
   signal dummy10           : sl;
   signal dummy11           : sl;
   
   signal rxUsrClk2Int      : sl;
   signal rxUsrClkActiveInt : sl;
   signal txUsrClk2Int      : sl;
   signal txUsrClkActiveInt : sl;

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

   U_Pgp3GthUsIp_1 : entity work.Pgp3GthUsIp
      port map (
         gtwiz_userclk_tx_reset_in(0)          => txReset,            -- [in]
         gtwiz_userclk_tx_srcclk_out(0)        => txOutClk,           -- [out]
         gtwiz_userclk_tx_usrclk_out(0)        => txUsrClk,           -- [out]
         gtwiz_userclk_tx_usrclk2_out(0)       => txUsrClk2Int,       -- [out]
         gtwiz_userclk_tx_active_out(0)        => txUsrClkActiveInt,  -- [out]
         gtwiz_userclk_rx_reset_in(0)          => rxReset,            -- [in]
         gtwiz_userclk_rx_srcclk_out(0)        => rxOutClk,           -- [out]
         gtwiz_userclk_rx_usrclk_out(0)        => rxUsrClk,           -- [out]
         gtwiz_userclk_rx_usrclk2_out(0)       => rxUsrClk2Int,       -- [out]
         gtwiz_userclk_rx_active_out(0)        => rxUsrClkActiveInt,  -- [out]
         gtwiz_reset_clk_freerun_in(0)         => stableClk,          -- [in]
         gtwiz_reset_all_in(0)                 => stableRst,          -- [in]
         gtwiz_reset_tx_pll_and_datapath_in(0) => '0',                -- [in]
         gtwiz_reset_tx_datapath_in(0)         => '0',                -- [in] --txReset?
         gtwiz_reset_rx_pll_and_datapath_in(0) => '0',                -- [in]
         gtwiz_reset_rx_datapath_in(0)         => rxReset,            -- [in]
         gtwiz_reset_rx_cdr_stable_out(0)      => dummy5,             -- [out]
         gtwiz_reset_tx_done_out(0)            => txResetDone,        -- [out]
         gtwiz_reset_rx_done_out(0)            => rxResetDone,        -- [out]
         gtwiz_userdata_tx_in                  => txData,             -- [in]
         gtwiz_userdata_rx_out                 => rxData,             -- [out]
         gtrefclk00_in(0)                      => gtRefClk,           -- [in]
         qpll0outclk_out(0)                    => dummy6,             -- [out]
         qpll0outrefclk_out(0)                 => dummy7,             -- [out]
         gthrxn_in(0)                          => gtRxN,              -- [in]
         gthrxp_in(0)                          => gtRxP,              -- [in]
--         loopback_in(0)                        => loopback,           -- [in]
         rxgearboxslip_in(0)                   => rxGearboxSlip,      -- [in]
         txheader_in(5 downto 2)               => (others => '0'),    -- [in]
         txheader_in(1 downto 0)               => txHeader,           -- [in]
         txsequence_in(6)                      => '0',                -- [in],
         txsequence_in(5 downto 0)             => txSequence,         -- [in]
         gthtxn_out(0)                         => gtTxN,              -- [out]
         gthtxp_out(0)                         => gtTxP,              -- [out]
         rxdatavalid_out(0)                    => rxDataValid,        -- [out]
         rxdatavalid_out(1)                    => dummy1,             -- [out]
         rxheader_out(1 downto 0)              => rxHeader,           -- [out]
         rxheader_out(5 downto 2)              => dummy3,
         rxheadervalid_out(0)                  => rxHeaderValid,      -- [out]
         rxheadervalid_out(1)                  => dummy4,             -- [out]
         rxpmaresetdone_out(0)                 => dummy8,             -- [out]
         rxprgdivresetdone_out(0)              => dummy9,             -- [out]
         rxstartofseq_out(1)                   => dummy2,             -- [out]
         rxstartofseq_out(0)                   => rxStartOfSeq,       -- [out]
         txpmaresetdone_out(0)                 => dummy10,            -- [out]
         txprgdivresetdone_out(0)              => dummy11);           -- [out]




end architecture mapping;
