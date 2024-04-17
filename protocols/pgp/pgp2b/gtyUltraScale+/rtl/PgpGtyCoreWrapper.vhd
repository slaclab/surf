-------------------------------------------------------------------------------
-- Title      : PGPv2b: https://confluence.slac.stanford.edu/x/q86fD
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: PGPv2b GTY Ultrascale IP Core Wrapper
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

library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;

entity PgpGtyCoreWrapper is

   generic (
      TPD_G : time := 1 ns);
   port (
      stableClk : in  sl;
      stableRst : in  sl;
      -- GTY FPGA IO
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
      txPolarity     : in  sl;
      txOutClk       : out sl;
      loopback       : in  slv(2 downto 0);

      -- AXI-Lite DRP interface
      axilClk         : in  sl                     := '0';
      axilRst         : in  sl                     := '0';
      axilReadMaster  : in  AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
      axilWriteSlave  : out AxiLiteWriteSlaveType);

end entity PgpGtyCoreWrapper;

architecture mapping of PgpGtyCoreWrapper is

   component PgpGtyCore
      port (
         gtwiz_userclk_tx_reset_in          : in  std_logic_vector(0 downto 0);
         gtwiz_userclk_tx_active_in         : in  std_logic_vector(0 downto 0);
         gtwiz_userclk_rx_active_in         : in  std_logic_vector(0 downto 0);
         gtwiz_reset_clk_freerun_in         : in  std_logic_vector(0 downto 0);
         gtwiz_reset_all_in                 : in  std_logic_vector(0 downto 0);
         gtwiz_reset_tx_pll_and_datapath_in : in  std_logic_vector(0 downto 0);
         gtwiz_reset_tx_datapath_in         : in  std_logic_vector(0 downto 0);
         gtwiz_reset_rx_pll_and_datapath_in : in  std_logic_vector(0 downto 0);
         gtwiz_reset_rx_datapath_in         : in  std_logic_vector(0 downto 0);
         gtwiz_reset_rx_cdr_stable_out      : out std_logic_vector(0 downto 0);
         gtwiz_reset_tx_done_out            : out std_logic_vector(0 downto 0);
         gtwiz_reset_rx_done_out            : out std_logic_vector(0 downto 0);
         gtwiz_userdata_tx_in               : in  std_logic_vector(15 downto 0);
         gtwiz_userdata_rx_out              : out std_logic_vector(15 downto 0);
         drpaddr_in                         : in  std_logic_vector(9 downto 0);
         drpclk_in                          : in  std_logic_vector(0 downto 0);
         drpdi_in                           : in  std_logic_vector(15 downto 0);
         drpen_in                           : in  std_logic_vector(0 downto 0);
         drpwe_in                           : in  std_logic_vector(0 downto 0);
         gtrefclk0_in                       : in  std_logic_vector(0 downto 0);
         gtyrxn_in                          : in  std_logic_vector(0 downto 0);
         gtyrxp_in                          : in  std_logic_vector(0 downto 0);
         loopback_in                        : in  std_logic_vector(2 downto 0);
         rx8b10ben_in                       : in  std_logic_vector(0 downto 0);
         rxbufreset_in                      : in  std_logic_vector(0 downto 0);
         rxcommadeten_in                    : in  std_logic_vector(0 downto 0);
         rxmcommaalignen_in                 : in  std_logic_vector(0 downto 0);
         rxpcommaalignen_in                 : in  std_logic_vector(0 downto 0);
         rxpolarity_in                      : in  std_logic_vector(0 downto 0);
         rxusrclk_in                        : in  std_logic_vector(0 downto 0);
         rxusrclk2_in                       : in  std_logic_vector(0 downto 0);
         tx8b10ben_in                       : in  std_logic_vector(0 downto 0);
         txctrl0_in                         : in  std_logic_vector(15 downto 0);
         txctrl1_in                         : in  std_logic_vector(15 downto 0);
         txctrl2_in                         : in  std_logic_vector(7 downto 0);
         txpolarity_in                      : in  std_logic_vector(0 downto 0);
         txusrclk_in                        : in  std_logic_vector(0 downto 0);
         txusrclk2_in                       : in  std_logic_vector(0 downto 0);
         drpdo_out                          : out std_logic_vector(15 downto 0);
         drprdy_out                         : out std_logic_vector(0 downto 0);
         gtpowergood_out                    : out std_logic_vector(0 downto 0);
         gtytxn_out                         : out std_logic_vector(0 downto 0);
         gtytxp_out                         : out std_logic_vector(0 downto 0);
         rxbufstatus_out                    : out std_logic_vector(2 downto 0);
         rxbyteisaligned_out                : out std_logic_vector(0 downto 0);
         rxbyterealign_out                  : out std_logic_vector(0 downto 0);
         rxclkcorcnt_out                    : out std_logic_vector(1 downto 0);
         rxcommadet_out                     : out std_logic_vector(0 downto 0);
         rxctrl0_out                        : out std_logic_vector(15 downto 0);
         rxctrl1_out                        : out std_logic_vector(15 downto 0);
         rxctrl2_out                        : out std_logic_vector(7 downto 0);
         rxctrl3_out                        : out std_logic_vector(7 downto 0);
         rxoutclk_out                       : out std_logic_vector(0 downto 0);
         rxpmaresetdone_out                 : out std_logic_vector(0 downto 0);
         txoutclk_out                       : out std_logic_vector(0 downto 0);
         txpmaresetdone_out                 : out std_logic_vector(0 downto 0)
         );
   end component;

   signal drpAddr : slv(9 downto 0);
   signal drpDi   : slv(15 downto 0);
   signal drpDo   : slv(15 downto 0);
   signal drpEn   : sl;
   signal drpWe   : sl;
   signal drpRdy  : sl;

   signal dummy0_6  : slv(5 downto 0);
   signal dummy1_14 : slv(13 downto 0);
   signal dummy2_14 : slv(13 downto 0);
   signal dummy3_6  : slv(5 downto 0);
   signal dummy4_1  : sl;
   signal dummy5_1  : sl;

   signal txctrl2 : slv(7 downto 0);

begin

   -- Note: Has to be generated from aurora core in order to work properly
   U_PgpGtyCore : PgpGtyCore
      port map (
         gtwiz_userclk_tx_active_in(0)         => txUsrClkActive,
         gtwiz_userclk_rx_active_in(0)         => rxUsrClkActive,
         gtwiz_reset_clk_freerun_in(0)         => stableClk,
         gtwiz_reset_all_in(0)                 => stableRst,
         gtwiz_userclk_tx_reset_in(0)          => '0',
         gtwiz_reset_tx_pll_and_datapath_in(0) => '0',
         gtwiz_reset_tx_datapath_in(0)         => txReset,
         gtwiz_reset_rx_pll_and_datapath_in(0) => '0',
         gtwiz_reset_rx_datapath_in(0)         => rxReset,
         gtwiz_reset_rx_cdr_stable_out         => open,
         gtwiz_reset_tx_done_out(0)            => txResetDone,
         gtwiz_reset_rx_done_out(0)            => rxResetDone,
         gtwiz_userdata_tx_in                  => txData,
         gtwiz_userdata_rx_out                 => rxData,
         drpclk_in(0)                          => stableClk,
         drpaddr_in                            => drpAddr,
         drpdi_in                              => drpDi,
         drpen_in(0)                           => drpEn,
         drpwe_in(0)                           => drpWe,
         drpdo_out                             => drpDo,
         drprdy_out(0)                         => drpRdy,
         gtyrxn_in(0)                          => gtRxN,
         gtyrxp_in(0)                          => gtRxP,
         gtrefclk0_in(0)                       => gtRefClk,
         loopback_in                           => loopback,
         rxbufreset_in(0)                      => '0',
         rx8b10ben_in(0)                       => '1',
         rxcommadeten_in(0)                    => '1',
         rxmcommaalignen_in(0)                 => '1',
         rxpcommaalignen_in(0)                 => '1',
         rxpolarity_in(0)                      => rxPolarity,
         rxusrclk_in(0)                        => rxUsrClk,
         rxusrclk2_in(0)                       => rxUsrClk,
         tx8b10ben_in(0)                       => '1',
         txctrl0_in                            => X"0000",
         txctrl1_in                            => X"0000",
         txctrl2_in                            => txctrl2,
         txpolarity_in(0)                      => txPolarity,
         txusrclk_in(0)                        => txUsrClk,
         txusrclk2_in(0)                       => txUsrClk,
         gtytxn_out(0)                         => gtTxN,
         gtytxp_out(0)                         => gtTxP,
         rxbyteisaligned_out                   => open,
         rxbyterealign_out                     => open,
         rxcommadet_out                        => open,
         rxctrl0_out(1 downto 0)               => rxDataK,
         rxctrl0_out(15 downto 2)              => dummy1_14,
         rxctrl1_out(1 downto 0)               => rxDispErr,
         rxctrl1_out(15 downto 2)              => dummy2_14,
         rxctrl2_out                           => open,
         rxctrl3_out(1 downto 0)               => rxDecErr,
         rxctrl3_out(7 downto 2)               => dummy0_6,
         rxoutclk_out(0)                       => rxOutClk,
         rxpmaresetdone_out                    => open,
         txoutclk_out(0)                       => txOutClk,
         txpmaresetdone_out                    => open);

   txctrl2 <= "000000" & txDataK;

   U_AxiLiteToDrp_1 : entity surf.AxiLiteToDrp
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

end architecture mapping;
