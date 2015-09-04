-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : AtlasSLinkLscGtx7.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-04-14
-- Last update: 2014-09-18
-- Platform   : Vivado 2014.1
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2014 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;
use work.GlinkPkg.all;

entity AtlasSLinkLscGtx7 is
   generic (
      TPD_G : time := 1 ns);
   port (
      sysClk    : in  sl;
      sysRst    : in  sl;
      gtRstDone : out sl;
      -- G-Link's MGT Serial IO
      gtTxP     : out sl;
      gtTxN     : out sl;
      gtRxP     : in  sl;
      gtRxN     : in  sl;
      -- TLK2501 transmit ports
      TLK_TXD   : in  std_logic_vector(15 downto 0);
      TLK_TXEN  : in  std_logic;
      TLK_TXER  : in  std_logic;
      -- TLK2501 transmit ports
      TLK_RXD   : out std_logic_vector(15 downto 0);
      TLK_RXDV  : out std_logic;
      TLK_RXER  : out std_logic);       
end AtlasSLinkLscGtx7;

architecture mapping of AtlasSLinkLscGtx7 is
   
   signal rxCharIsKByteDly,
      gtTxResetDone,
      gtRxResetDone : sl;
   signal txCharIsK,
      rxCharIsK : slv(1 downto 0);
   signal rxDataByteDly : slv(7 downto 0);
   signal txData,
      GTX_RXDATA,
      rxData : slv(15 downto 0);
   
   attribute dont_touch : string;
   attribute dont_touch of
      rxCharIsKByteDly,
      rxDataByteDly,
      gtTxResetDone,
      gtRxResetDone,
      txCharIsK,
      rxCharIsK,
      txData,
      rxData : signal is "true";

   -- attribute KEEP_HIERARCHY : string;
   -- attribute KEEP_HIERARCHY of
   -- tlk_gtx_interface_1 : label is "TRUE";
   
begin

   gtRstDone <= gtTxResetDone and gtRxResetDone;

   -- The GTX7 automatically aligns the commas on the even 
   -- byte (byte[0]). But the tlk_gtx_interface firmware 
   -- module expects the alignment to be on the odd byte 
   -- (byte[1]). We correct for this by swapping the 
   -- byte mapping and delaying the odd byte by 1 clock cycle.
   process(sysClk)
   begin
      if rising_edge(sysClk) then
         rxCharIsKByteDly <= rxCharIsK(1);
         rxDataByteDly    <= rxData(15 downto 8);
      end if;
   end process;

   tlk_gtx_interface_1 : entity work.tlk_gtx_interface
      port map (
         SYS_RST                 => sysRst,
         -- GTX receive ports
         GTX_RXUSRCLK2           => sysClk,
         GTX_RXCHARISK(1)        => rxCharIsK(0),
         GTX_RXCHARISK(0)        => rxCharIsKByteDly,
         GTX_RXDATA(15 downto 8) => rxData(7 downto 0),
         GTX_RXDATA(7 downto 0)  => rxDataByteDly,
         -- GTX transmit ports
         GTX_TXUSRCLK2           => sysClk,
         GTX_TXDATA              => txData,
         GTX_TXCHARISK           => txCharIsK,
         -- TLK2501 ports
         TLK_TXD                 => TLK_TXD,
         TLK_TXEN                => TLK_TXEN,
         TLK_TXER                => TLK_TXER,
         TLK_RXD                 => TLK_RXD,
         TLK_RXDV                => TLK_RXDV,
         TLK_RXER                => TLK_RXER);

   Gtx7Core_Inst : entity work.Gtx7Core
      generic map (
         TPD_G                  => TPD_G,
         CPLL_REFCLK_SEL_G      => "111",
         CPLL_FBDIV_G           => 4,
         CPLL_FBDIV_45_G        => 5,
         CPLL_REFCLK_DIV_G      => 1,
         RXOUT_DIV_G            => 2,
         TXOUT_DIV_G            => 2,
         RX_CLK25_DIV_G         => 5,
         TX_CLK25_DIV_G         => 5,
         TX_PLL_G               => "CPLL",
         RX_PLL_G               => "CPLL",
         TX_EXT_DATA_WIDTH_G    => 16,
         TX_INT_DATA_WIDTH_G    => 20,
         TX_8B10B_EN_G          => true,
         RX_EXT_DATA_WIDTH_G    => 16,
         RX_INT_DATA_WIDTH_G    => 20,
         RX_8B10B_EN_G          => true,
         TX_BUF_EN_G            => true,
         TX_OUTCLK_SRC_G        => "OUTCLKPMA",
         TX_DLY_BYPASS_G        => '1',
         TX_PHASE_ALIGN_G       => "NONE",
         TX_BUF_ADDR_MODE_G     => "FULL",
         RX_BUF_EN_G            => true,
         RX_OUTCLK_SRC_G        => "OUTCLKPMA",
         RX_USRCLK_SRC_G        => "RXOUTCLK",
         RX_DLY_BYPASS_G        => '0',
         RX_DDIEN_G             => '0',
         RX_BUF_ADDR_MODE_G     => "FULL",
         RX_ALIGN_MODE_G        => "GT",
         ALIGN_COMMA_DOUBLE_G   => "FALSE",
         ALIGN_COMMA_ENABLE_G   => "1111111111",
         ALIGN_COMMA_WORD_G     => 2,
         ALIGN_MCOMMA_DET_G     => "TRUE",
         ALIGN_MCOMMA_VALUE_G   => "1010000011",
         ALIGN_MCOMMA_EN_G      => '1',
         ALIGN_PCOMMA_DET_G     => "TRUE",
         ALIGN_PCOMMA_VALUE_G   => "0101111100",
         ALIGN_PCOMMA_EN_G      => '1',
         SHOW_REALIGN_COMMA_G   => "FALSE",
         RXSLIDE_MODE_G         => "AUTO",
         RX_DISPERR_SEQ_MATCH_G => "TRUE",
         DEC_MCOMMA_DETECT_G    => "TRUE",
         DEC_PCOMMA_DETECT_G    => "TRUE",
         DEC_VALID_COMMA_ONLY_G => "FALSE",
         CBCC_DATA_SOURCE_SEL_G => "DECODED",
         RX_OS_CFG_G            => "0000010000000",
         RXCDR_CFG_G            => x"03000023ff40200020",
         RXDFEXYDEN_G           => '0',
         RX_DFE_KL_CFG2_G       => x"3008E56A")
      port map (
         stableClkIn      => sysClk,
         cPllRefClkIn     => sysClk,
         cPllLockOut      => open,
         qPllRefClkIn     => '0',
         qPllClkIn        => '0',
         qPllLockIn       => '1',
         qPllRefClkLostIn => '0',
         qPllResetOut     => open,
         gtTxP            => gtTxP,
         gtTxN            => gtTxN,
         gtRxP            => gtRxP,
         gtRxN            => gtRxN,
         rxUsrClkIn       => sysClk,
         rxUsrClk2In      => sysClk,
         rxUserResetIn    => sysRst,
         rxResetDoneOut   => gtRxResetDone,
         rxDataOut        => rxData,
         rxCharIsKOut     => rxCharIsK,
         txUsrClkIn       => sysClk,
         txUsrClk2In      => sysClk,
         txUserResetIn    => sysRst,
         txResetDoneOut   => gtTxResetDone,
         txDataIn         => txData,
         txCharIsKIn      => txCharIsK);

end mapping;
