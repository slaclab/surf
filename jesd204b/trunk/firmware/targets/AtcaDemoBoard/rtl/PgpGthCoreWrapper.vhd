-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : PgpGthCoreWrapper.vhd
-- Author     : Benjamin Reese  <bareese@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-06-09
-- Last update: 2015-06-10
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2015 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use work.StdRtlPkg.all;

entity PgpGthCoreWrapper is
   
   generic (
      TPD_G : time := 1 ns);

   port (
      stableClk : in  sl;
      -- GTH FPGA IO
      gtRefClk  : in  sl;
      gtRxP     : in  sl;
      gtRxN     : in  sl;
      gtTxP     : out sl;
      gtTxN     : out sl;

      -- Rx ports
      rxReset        : in  sl;
      rxUsrClkActive : in  sl;
      rxCdrStable    : out sl;
      rxResetDone    : out sl;
      rxUsrClk       : in  sl;
      rxData         : out slv(15 downto 0);
      rxDataK        : out slv(1 downto 0);
      rxDispErr      : out slv(1 downto 0);
      rxDecErr       : out slv(1 downto 0);
      rxPolarity     : in  sl;
      rxOutClk       : out sl;

      -- Tx Ports
      txReset        : in  sl;
      txUsrClk       : in  sl;
      txUsrClkActive : in  sl;
      txResetDone    : out sl;
      txData         : in  slv(15 downto 0);
      txDataK        : in  slv(1 downto 0);
      txOutClk       : out sl

      --loopback : in slv(2 downto 0)
      );
end entity PgpGthCoreWrapper;

architecture rtl of PgpGthCoreWrapper is

   component PgpGthCore
      port (
         gtwiz_userclk_tx_reset_in          : in  slv(0 downto 0);
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
         gtwiz_userdata_tx_in               : in  slv(15 downto 0);
         gtwiz_userdata_rx_out              : out slv(15 downto 0);
         drpclk_in                          : in  slv(0 downto 0);
         gthrxn_in                          : in  slv(0 downto 0);
         gthrxp_in                          : in  slv(0 downto 0);
         gtrefclk0_in                       : in  slv(0 downto 0);
        -- loopback_in                        : in  slv(2 downto 0);
         rx8b10ben_in                       : in  slv(0 downto 0);
         rxbufreset_in                      : in  slv(0 DOWNTO 0);
         rxcommadeten_in                    : in  slv(0 downto 0);
         rxmcommaalignen_in                 : in  slv(0 downto 0);
         rxpcommaalignen_in                 : in  slv(0 downto 0);
         rxpolarity_in                      : in  slv(0 downto 0);
         rxusrclk_in                        : in  slv(0 downto 0);
         rxusrclk2_in                       : in  slv(0 downto 0);
         tx8b10ben_in                       : in  slv(0 downto 0);
         txctrl0_in                         : in  slv(15 downto 0);
         txctrl1_in                         : in  slv(15 downto 0);
         txctrl2_in                         : in  slv(7 downto 0);
         txusrclk_in                        : in  slv(0 downto 0);
         txusrclk2_in                       : in  slv(0 downto 0);
         gthtxn_out                         : out slv(0 downto 0);
         gthtxp_out                         : out slv(0 downto 0);
         rxbyteisaligned_out                : out slv(0 downto 0);
         rxbyterealign_out                  : out slv(0 downto 0);
         rxcommadet_out                     : out slv(0 downto 0);
         rxctrl0_out                        : out slv(15 downto 0);
         rxctrl1_out                        : out slv(15 downto 0);
         rxctrl2_out                        : out slv(7 downto 0);
         rxctrl3_out                        : out slv(7 downto 0);
         rxoutclk_out                       : out slv(0 downto 0);
         rxpmaresetdone_out                 : out slv(0 downto 0);
         txoutclk_out                       : out slv(0 downto 0);
         txpmaresetdone_out                 : out slv(0 downto 0)
         );
   end component;

begin

   U_PgpGthCore : PgpGthCore
      port map (
         gtwiz_userclk_tx_reset_in(0)          => txReset,
         gtwiz_userclk_tx_active_in(0)         => txUsrClkActive,
         gtwiz_userclk_rx_active_in(0)         => rxUsrClkActive,
         gtwiz_reset_clk_freerun_in (0)        => stableClk,
         gtwiz_reset_all_in(0)                 => '0',
         gtwiz_reset_tx_pll_and_datapath_in(0) => '0',
         gtwiz_reset_tx_datapath_in(0)         => txReset,
         gtwiz_reset_rx_pll_and_datapath_in(0) => '0',
         gtwiz_reset_rx_datapath_in(0)         => rxReset,
         gtwiz_reset_rx_cdr_stable_out(0)      => open,
         gtwiz_reset_tx_done_out(0)            => txResetDone,
         gtwiz_reset_rx_done_out(0)            => rxResetDone,
         gtwiz_userdata_tx_in                  => txData,
         gtwiz_userdata_rx_out                 => rxData,
         drpclk_in(0)                          => stableClk,
         gthrxn_in(0)                          => gtRxN,
         gthrxp_in(0)                          => gtRxP,
         gtrefclk0_in(0)                       => gtRefClk,
        -- loopback_in                           => loopback,
         rx8b10ben_in(0)                       => '1',
         rxcommadeten_in(0)                    => '1',
         rxmcommaalignen_in(0)                 => '1',
         rxpcommaalignen_in(0)                 => '1',
         rxpolarity_in(0)                      => rxPolarity,
         rxusrclk_in(0)                        => rxUsrClk,
         rxusrclk2_in(0)                       => rxUsrClk,
         tx8b10ben_in(0)                       => '1',
         rxbufreset_in(0)                      => '0',
         txctrl0_in                            => X"0000",
         txctrl1_in                            => X"0000",
         txctrl2_in(1 downto 0)                => txDataK,
         txctrl2_in(7 downto 2)                => (others => '0'),
         txusrclk_in(0)                        => txUsrClk,
         txusrclk2_in(0)                       => txUsrClk,
         gthtxn_out(0)                         => gtTxN,
         gthtxp_out(0)                         => gtTxP,
         rxbyteisaligned_out(0)                => open,
         rxbyterealign_out(0)                  => open,
         rxcommadet_out(0)                     => open,
         rxctrl0_out(1 downto 0)               => rxDataK,
         rxctrl0_out(15 downto 2)              => open,
         rxctrl1_out(1 downto 0)               => rxDispErr,
         rxctrl1_out(15 downto 2)              => open,
         rxctrl2_out                           => open,
         rxctrl3_out(1 downto 0)               => rxDecErr,
         rxctrl3_out(7 downto 2)               => open,
         rxoutclk_out(0)                       => rxOutClk,
         rxpmaresetdone_out(0)                 => open,
         txoutclk_out(0)                       => txOutClk,
         txpmaresetdone_out(0)                 => open);
end architecture rtl;
