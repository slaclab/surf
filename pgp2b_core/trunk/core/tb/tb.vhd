LIBRARY ieee;
USE work.ALL;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
Library unisim;
use unisim.vcomponents.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.Pgp2bPkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;

entity tb is end tb;

-- Define architecture
architecture tb of tb is

   signal gtClkP           : sl;
   signal gtClkN           : sl;
   signal gtTxP            : sl;
   signal gtTxN            : sl;
   signal gtRxP            : sl;
   signal gtRxN            : sl;
   signal extRst           : sl;
   signal txPllLock        : sl;
   signal rxPllLock        : sl;
   signal txClk            : sl;
   signal rxClk            : sl;
   signal stableClk        : sl;
   signal testCnt          : slv(11 downto 0);
   signal testEn           : sl;
   signal pgpRxIn          : Pgp2bRxInType;
   signal pgpRxOut         : Pgp2bRxOutType;
   signal pgpTxIn          : Pgp2bTxInType;
   signal pgpTxOut         : Pgp2bTxOutType;

begin

   process begin
      gtClkP <= '1';
      gtClkN <= '0';
      wait for 2 ns;
      gtClkP <= '0';
      gtClkN <= '1';
      wait for 2 ns;
   end process;

   process begin
      extRst <= '1';
      wait for (50 ns);
      extRst <= '0';
      wait;
   end process;

   process ( txClk, extRst, txPllLock ) begin
      if extRst = '1' or pgpRxOut.linkReady = '0' then
         testCnt <= (others=>'0');
         testEn  <= '0';
      elsif rising_edge(txClk) then
         testCnt <= testCnt + 1;

         if testCnt = x"fff" then
            testEn <= '1';
         else
            testEn <= '0';
         end if;
      end if;
   end process;

   pgpTxIn.flush           <= '0';
   pgpTxIn.opCodeEn        <= testEn;
   pgpTxIn.opCode          <= x"5a";
   pgpTxIn.locData         <= (others=>'0');
   pgpTxIn.flowCntlDis     <= '0';
   pgpRxIn.flush           <= '0';
   pgpRxIn.resetRx         <= '0';
   pgpRxIn.loopback        <= (others=>'0');

   U_PgpSim : entity work.Pgp2bGtp7FixedLatWrapper
      generic map (
         MASTER_SEL_G         => true,
         RX_CLK_SEL_G         => true,
         NUM_VC_EN_G          => 4,
         QPLL_FBDIV_IN_G      => 4,
         QPLL_FBDIV_45_IN_G   => 5,
         QPLL_REFCLK_DIV_IN_G => 1,
         MMCM_CLKIN_PERIOD_G  => 8.000,
         MMCM_CLKFBOUT_MULT_G => 8.000,
         MMCM_GTCLK_DIVIDE_G  => 8.000,
         MMCM_TXCLK_DIVIDE_G  => 8,
         RXOUT_DIV_G          => 2,
         TXOUT_DIV_G          => 2,
         RX_CLK25_DIV_G       => 5,                         -- Set by wizard
         TX_CLK25_DIV_G       => 5,                         -- Set by wizard
         PMA_RSV_G            => x"00000333",               -- Set by wizard
         RX_OS_CFG_G          => "0001111110000",           -- Set by wizard
         RXCDR_CFG_G          => x"0000107FE206001041010",  -- Set by wizard
         RXLPM_INCM_CFG_G     => '1',                       -- Set by wizard
         RXLPM_IPCM_CFG_G     => '0',                       -- Set by wizard
         TX_PLL_G             => "PLL0",
         RX_PLL_G             => "PLL1"
      ) port map (
         extRst            => extRst,
         txPllLock         => txPllLock,
         rxPllLock         => rxPllLock,
         txClk             => txClk,
         rxClk             => rxClk,
         stableClk         => stableClk,
         pgpRxIn           => pgpRxIn,
         pgpRxOut          => pgpRxOut,
         pgpTxIn           => pgpTxIn,
         pgpTxOut          => pgpTxOut,
         pgpTxMasters      => (others=>AXI_STREAM_MASTER_INIT_C),
         pgpTxSlaves       => open,
         pgpRxMasters      => open,
         pgpRxMasterMuxed  => open,
         pgpRxCtrl         => (others=>AXI_STREAM_CTRL_INIT_C),
         gtClkP            => gtClkP,
         gtClkN            => gtClkN,
         gtTxP             => gtTxP,
         gtTxN             => gtTxN,
         gtRxP             => gtRxP,
         gtRxN             => gtRxN
      );

   gtRxP <= gtTxP;
   gtRxN <= gtTxN;

end tb;

