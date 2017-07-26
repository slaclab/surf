-------------------------------------------------------------------------------
-- File       : Pgp3GthCoreWrapper.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-06-29
-- Last update: 2017-06-29
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
      rxUsrClkActive : in  sl;
      rxResetDone    : out sl;
      rxUsrClk       : in  sl;
      rxUsrClk2      : in  sl;
      rxData         : out slv(63 downto 0);
      rxDataValid    : out sl;
      rxHeader       : out slv(1 downto 0);
      rxHeaderValid  : out sl;
      rxStartOfSeq   : out sl;
      rxGearboxSlip  : in  sl;
      rxOutClk       : out sl;

      -- Tx Ports
      txReset        : in  sl;
      txUsrClkActive : in  sl;
      txResetDone    : out sl;
      txUsrClk       : in  sl;
      txUsrClk2      : in  sl;
      txData         : in  slv(63 downto 0);
      txHeader       : in  slv(1 downto 0);
      txSequence     : in  slv(6 downto 0);
      txOutClk       : out sl;
      loopback       : in  slv(2 downto 0));
end entity Pgp3GthCoreWrapper;

architecture mapping of Pgp3GthCoreWrapper is

   component Pgp3GthUs
      port (
         gtwiz_userclk_tx_active_in         : in  slv(0 downto 0);
         gtwiz_userclk_rx_active_in         : in  slv(0 downto 0);
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
         loopback_in                        : in  slv(2 downto 0);
         rxgearboxslip_in                   : in  slv(0 downto 0);
         rxusrclk_in                        : in  slv(0 downto 0);
         rxusrclk2_in                       : in  slv(0 downto 0);
         txheader_in                        : in  slv(5 downto 0);
         txsequence_in                      : in  slv(6 downto 0);
         txusrclk_in                        : in  slv(0 downto 0);
         txusrclk2_in                       : in  slv(0 downto 0);
         gthtxn_out                         : out slv(0 downto 0);
         gthtxp_out                         : out slv(0 downto 0);
         rxdatavalid_out                    : out slv(1 downto 0);
         rxheader_out                       : out slv(5 downto 0);
         rxheadervalid_out                  : out slv(1 downto 0);
         rxoutclk_out                       : out slv(0 downto 0);
         rxpmaresetdone_out                 : out slv(0 downto 0);
         rxstartofseq_out                   : out slv(1 downto 0);
         txoutclk_out                       : out slv(0 downto 0);
         txpmaresetdone_out                 : out slv(0 downto 0)
         );
   end component;

   signal dummy : sl;

begin

   -- Note: Has to be generated from aurora core in order to work properly
   U_PgpGthCore : PgpGthUs
      port map (
         gtwiz_userclk_tx_active_in(0)         => txUsrClkActive,
         gtwiz_userclk_rx_active_in(0)         => rxUsrClkActive,
         gtwiz_reset_clk_freerun_in (0)        => stableClk,
         gtwiz_reset_all_in(0)                 => stableRst,
         gtwiz_reset_tx_pll_and_datapath_in(0) => '0',
         gtwiz_reset_tx_datapath_in(0)         => txReset,
         gtwiz_reset_rx_pll_and_datapath_in(0) => '0',
         gtwiz_reset_rx_datapath_in(0)         => rxReset,
         gtwiz_reset_rx_cdr_stable_out(0)      => open,
         gtwiz_reset_tx_done_out(0)            => txResetDone,
         gtwiz_reset_rx_done_out(0)            => rxResetDone,
         gtwiz_userdata_tx_in                  => txData,
         gtwiz_userdata_rx_out                 => rxData,
         gthrxn_in(0)                          => gtRxN,
         gthrxp_in(0)                          => gtRxP,
         gtrefclk00_in(0)                      => gtRefClk,
         loopback_in                           => loopback,
         rxgearboxslip_in                      => rxGearboxSlip,
         rxusrclk_in(0)                        => rxUsrClk,
         rxusrclk2_in(0)                       => rxUsrClk2,
         txheader_in(5 downto 2)               => (others => '0'),
         txheader_in(1 downto 0)               => txHeader,
         txsequence_in(6)                      => '0',
         txsequence_in(5 downto 0)             => txSequence,
         txusrclk_in(0)                        => txUsrClk,
         txusrclk2_in(0)                       => txUsrClk2,
         gthtxn_out(0)                         => gtTxN,
         gthtxp_out(0)                         => gtTxP,
         rxdatavalid_out(0)                    => rxDataValid,
         rxheader_out(0)                       => rxHeader,
         rxheadervalid_out(0)                  => rxHeaderValid,
         rxoutclk_out(0)                       => rxOutClk,
         rxpmaresetdone_out(0)                 => open,
         rxstartofseq_out(1)                   => dummy,
         rxstartofseq_out(0)                   => rxStartOfSeq,
         txoutclk_out(0)                       => txOutClk,
         txpmaresetdone_out(0)                 => open);

end architecture mapping;
