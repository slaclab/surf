-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
-------------------------------------------------------------------------------
-- This file is part of 'SLAC MGT Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the
-- top-level directory of this distribution and at:
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
-- No part of 'SLAC MGT Library', including this file,
-- may be copied, modified, propagated, or distributed except according to
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library surf;
use surf.StdRtlPkg.all;

library unisim;
use unisim.vcomponents.all;

entity Gtpe2ChannelDummy is
   generic (
      TPD_G        : time                  := 1 ns;
      SIMULATION_G : boolean               := false;
      EXT_QPLL_G   : boolean               := false;
      WIDTH_G      : positive range 1 to 4 := 1);
   port (
      refClk           : in  sl;        -- Required by DRC REQP #48
      qPllOutClkExt    : in  slv(1 downto 0) := "00";
      qPllOutRefClkExt : in  slv(1 downto 0) := "00";
      gtRxP            : in  slv(WIDTH_G-1 downto 0);
      gtRxN            : in  slv(WIDTH_G-1 downto 0);
      gtTxP            : out slv(WIDTH_G-1 downto 0);
      gtTxN            : out slv(WIDTH_G-1 downto 0));
end entity Gtpe2ChannelDummy;

architecture mapping of Gtpe2ChannelDummy is

   signal qPllOutClk    : slv(1 downto 0);
   signal qPllOutRefClk : slv(1 downto 0);

begin

   ----------------------------------------------------
   -- https://www.xilinx.com/support/answers/70060.html
   ----------------------------------------------------
   NOT_SIM : if (SIMULATION_G = false) generate

      INT_QPLL : if (EXT_QPLL_G = false) generate
         U_Gtp7QuadPll : entity surf.Gtp7QuadPll
            generic map (
               TPD_G             => TPD_G,
               PLL0_REFCLK_SEL_G => "111",
               PLL1_REFCLK_SEL_G => "111")
            port map (
               qPllRefClk     => (others => refClk),
               qplllockdetclk => (others => refClk),
               qPllOutClk     => qPllOutClk,
               qPllOutRefClk  => qPllOutRefClk,
               qPllPowerDown  => (others => '1'),
               qPllReset      => (others => '1'));
      end generate;

      EXT_QPLL : if (EXT_QPLL_G = true) generate
         qPllOutClk    <= qPllOutClkExt;
         qPllOutRefClk <= qPllOutRefClkExt;
      end generate;

      GEN_VEC :
      for i in WIDTH_G-1 downto 0 generate
         U_GTP : GTPE2_CHANNEL
            port map (
               DMONITOROUT          => open,
               DRPDO                => open,
               DRPRDY               => open,
               EYESCANDATAERROR     => open,
               GTPTXN               => gtTxN(i),
               GTPTXP               => gtTxP(i),
               PCSRSVDOUT           => open,
               PHYSTATUS            => open,
               PMARSVDOUT0          => open,
               PMARSVDOUT1          => open,
               RXBUFSTATUS          => open,
               RXBYTEISALIGNED      => open,
               RXBYTEREALIGN        => open,
               RXCDRLOCK            => open,
               RXCHANBONDSEQ        => open,
               RXCHANISALIGNED      => open,
               RXCHANREALIGN        => open,
               RXCHARISCOMMA        => open,
               RXCHARISK            => open,
               RXCHBONDO            => open,
               RXCLKCORCNT          => open,
               RXCOMINITDET         => open,
               RXCOMMADET           => open,
               RXCOMSASDET          => open,
               RXCOMWAKEDET         => open,
               RXDATA               => open,
               RXDATAVALID          => open,
               RXDISPERR            => open,
               RXDLYSRESETDONE      => open,
               RXELECIDLE           => open,
               RXHEADER             => open,
               RXHEADERVALID        => open,
               RXNOTINTABLE         => open,
               RXOSINTDONE          => open,
               RXOSINTSTARTED       => open,
               RXOSINTSTROBEDONE    => open,
               RXOSINTSTROBESTARTED => open,
               RXOUTCLK             => open,
               RXOUTCLKFABRIC       => open,
               RXOUTCLKPCS          => open,
               RXPHALIGNDONE        => open,
               RXPHMONITOR          => open,
               RXPHSLIPMONITOR      => open,
               RXPMARESETDONE       => open,
               RXPRBSERR            => open,
               RXRATEDONE           => open,
               RXRESETDONE          => open,
               RXSTARTOFSEQ         => open,
               RXSTATUS             => open,
               RXSYNCDONE           => open,
               RXSYNCOUT            => open,
               RXVALID              => open,
               TXBUFSTATUS          => open,
               TXCOMFINISH          => open,
               TXDLYSRESETDONE      => open,
               TXGEARBOXREADY       => open,
               TXOUTCLK             => open,
               TXOUTCLKFABRIC       => open,
               TXOUTCLKPCS          => open,
               TXPHALIGNDONE        => open,
               TXPHINITDONE         => open,
               TXPMARESETDONE       => open,
               TXRATEDONE           => open,
               TXRESETDONE          => open,
               TXSYNCDONE           => open,
               TXSYNCOUT            => open,
               CFGRESET             => '0',
               CLKRSVD0             => '0',
               CLKRSVD1             => '0',
               DMONFIFORESET        => '0',
               DMONITORCLK          => '0',
               DRPADDR              => (others => '0'),
               DRPCLK               => '0',
               DRPDI                => (others => '0'),
               DRPEN                => '0',
               DRPWE                => '0',
               EYESCANMODE          => '0',
               EYESCANRESET         => '0',
               EYESCANTRIGGER       => '0',
               GTPRXN               => gtRxN(i),
               GTPRXP               => gtRxP(i),
               GTRESETSEL           => '0',
               GTRSVD               => (others => '0'),
               GTRXRESET            => '0',
               GTTXRESET            => '0',
               LOOPBACK             => (others => '0'),
               PCSRSVDIN            => (others => '0'),
               PLL0CLK              => qPllOutClk(0),
               PLL0REFCLK           => qPllOutRefClk(0),
               PLL1CLK              => qPllOutClk(1),
               PLL1REFCLK           => qPllOutRefClk(1),
               PMARSVDIN0           => '0',
               PMARSVDIN1           => '0',
               PMARSVDIN2           => '0',
               PMARSVDIN3           => '0',
               PMARSVDIN4           => '0',
               RESETOVRD            => '0',
               RX8B10BEN            => '0',
               RXADAPTSELTEST       => (others => '0'),
               RXBUFRESET           => '0',
               RXCDRFREQRESET       => '0',
               RXCDRHOLD            => '0',
               RXCDROVRDEN          => '0',
               RXCDRRESET           => '0',
               RXCDRRESETRSV        => '0',
               RXCHBONDEN           => '0',
               RXCHBONDI            => (others => '0'),
               RXCHBONDLEVEL        => (others => '0'),
               RXCHBONDMASTER       => '0',
               RXCHBONDSLAVE        => '0',
               RXCOMMADETEN         => '0',
               RXDDIEN              => '0',
               RXDFEXYDEN           => '0',
               RXDLYBYPASS          => '0',
               RXDLYEN              => '0',
               RXDLYOVRDEN          => '0',
               RXDLYSRESET          => '0',
               RXELECIDLEMODE       => (others => '0'),
               RXGEARBOXSLIP        => '0',
               RXLPMHFHOLD          => '0',
               RXLPMHFOVRDEN        => '0',
               RXLPMLFHOLD          => '0',
               RXLPMLFOVRDEN        => '0',
               RXLPMOSINTNTRLEN     => '0',
               RXLPMRESET           => '0',
               RXMCOMMAALIGNEN      => '0',
               RXOOBRESET           => '0',
               RXOSCALRESET         => '0',
               RXOSHOLD             => '0',
               RXOSINTCFG           => (others => '0'),
               RXOSINTEN            => '0',
               RXOSINTHOLD          => '0',
               RXOSINTID0           => (others => '0'),
               RXOSINTNTRLEN        => '0',
               RXOSINTOVRDEN        => '0',
               RXOSINTPD            => '0',
               RXOSINTSTROBE        => '0',
               RXOSINTTESTOVRDEN    => '0',
               RXOSOVRDEN           => '0',
               RXOUTCLKSEL          => (others => '0'),
               RXPCOMMAALIGNEN      => '0',
               RXPCSRESET           => '0',
               RXPD                 => (others => '1'),  -- power down GTH
               RXPHALIGN            => '0',
               RXPHALIGNEN          => '0',
               RXPHDLYPD            => '0',
               RXPHDLYRESET         => '0',
               RXPHOVRDEN           => '0',
               RXPMARESET           => '0',
               RXPOLARITY           => '0',
               RXPRBSCNTRESET       => '0',
               RXPRBSSEL            => (others => '0'),
               RXRATE               => (others => '0'),
               RXRATEMODE           => '0',
               RXSLIDE              => '0',
               RXSYNCALLIN          => '0',
               RXSYNCIN             => '0',
               RXSYNCMODE           => '0',
               RXSYSCLKSEL          => (others => '0'),
               RXUSERRDY            => '0',
               RXUSRCLK             => '0',
               RXUSRCLK2            => '0',
               SETERRSTATUS         => '0',
               SIGVALIDCLK          => '0',
               TSTIN                => (others => '0'),
               TX8B10BBYPASS        => (others => '0'),
               TX8B10BEN            => '0',
               TXBUFDIFFCTRL        => (others => '0'),
               TXCHARDISPMODE       => (others => '0'),
               TXCHARDISPVAL        => (others => '0'),
               TXCHARISK            => (others => '0'),
               TXCOMINIT            => '0',
               TXCOMSAS             => '0',
               TXCOMWAKE            => '0',
               TXDATA               => (others => '0'),
               TXDEEMPH             => '0',
               TXDETECTRX           => '0',
               TXDIFFCTRL           => (others => '0'),
               TXDIFFPD             => '0',
               TXDLYBYPASS          => '0',
               TXDLYEN              => '0',
               TXDLYHOLD            => '0',
               TXDLYOVRDEN          => '0',
               TXDLYSRESET          => '0',
               TXDLYUPDOWN          => '0',
               TXELECIDLE           => '0',
               TXHEADER             => (others => '0'),
               TXINHIBIT            => '0',
               TXMAINCURSOR         => (others => '0'),
               TXMARGIN             => (others => '0'),
               TXOUTCLKSEL          => (others => '0'),
               TXPCSRESET           => '0',
               TXPD                 => (others => '1'),  -- power down GTH
               TXPDELECIDLEMODE     => '0',
               TXPHALIGN            => '0',
               TXPHALIGNEN          => '0',
               TXPHDLYPD            => '0',
               TXPHDLYRESET         => '0',
               TXPHDLYTSTCLK        => '0',
               TXPHINIT             => '0',
               TXPHOVRDEN           => '0',
               TXPIPPMEN            => '0',
               TXPIPPMOVRDEN        => '0',
               TXPIPPMPD            => '0',
               TXPIPPMSEL           => '0',
               TXPIPPMSTEPSIZE      => (others => '0'),
               TXPISOPD             => '0',
               TXPMARESET           => '0',
               TXPOLARITY           => '0',
               TXPOSTCURSOR         => (others => '0'),
               TXPOSTCURSORINV      => '0',
               TXPRBSFORCEERR       => '0',
               TXPRBSSEL            => (others => '0'),
               TXPRECURSOR          => (others => '0'),
               TXPRECURSORINV       => '0',
               TXRATE               => (others => '0'),
               TXRATEMODE           => '0',
               TXSEQUENCE           => (others => '0'),
               TXSTARTSEQ           => '0',
               TXSWING              => '0',
               TXSYNCALLIN          => '0',
               TXSYNCIN             => '0',
               TXSYNCMODE           => '0',
               TXSYSCLKSEL          => (others => '0'),
               TXUSERRDY            => '0',
               TXUSRCLK             => '0',
               TXUSRCLK2            => '0');
      end generate GEN_VEC;

   end generate;

end architecture mapping;
