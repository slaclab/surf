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

entity Gtxe2ChannelDummy is
   generic (
      TPD_G        : time     := 1 ns;
      SIMULATION_G : boolean  := false;
      WIDTH_G      : positive := 1);
   port (
      refClk : in  sl;                  -- Required by DRC REQP #48
      gtRxP  : in  slv(WIDTH_G-1 downto 0);
      gtRxN  : in  slv(WIDTH_G-1 downto 0);
      gtTxP  : out slv(WIDTH_G-1 downto 0);
      gtTxN  : out slv(WIDTH_G-1 downto 0));
end entity Gtxe2ChannelDummy;

architecture mapping of Gtxe2ChannelDummy is

begin

   ----------------------------------------------------
   -- https://www.xilinx.com/support/answers/70060.html
   ----------------------------------------------------
   NOT_SIM : if (SIMULATION_G = false) generate

      GEN_VEC :
      for i in WIDTH_G-1 downto 0 generate
         U_GTX : GTXE2_CHANNEL
            port map (
               CPLLFBCLKLOST    => open,
               CPLLLOCK         => open,
               CPLLREFCLKLOST   => open,
               DMONITOROUT      => open,
               DRPDO            => open,
               DRPRDY           => open,
               EYESCANDATAERROR => open,
               GTREFCLKMONITOR  => open,
               GTXTXN           => gtTxN(i),
               GTXTXP           => gtTxP(i),
               PCSRSVDOUT       => open,
               PHYSTATUS        => open,
               RXBUFSTATUS      => open,
               RXBYTEISALIGNED  => open,
               RXBYTEREALIGN    => open,
               RXCDRLOCK        => open,
               RXCHANBONDSEQ    => open,
               RXCHANISALIGNED  => open,
               RXCHANREALIGN    => open,
               RXCHARISCOMMA    => open,
               RXCHARISK        => open,
               RXCHBONDO        => open,
               RXCLKCORCNT      => open,
               RXCOMINITDET     => open,
               RXCOMMADET       => open,
               RXCOMSASDET      => open,
               RXCOMWAKEDET     => open,
               RXDATA           => open,
               RXDATAVALID      => open,
               RXDISPERR        => open,
               RXDLYSRESETDONE  => open,
               RXELECIDLE       => open,
               RXHEADER         => open,
               RXHEADERVALID    => open,
               RXMONITOROUT     => open,
               RXNOTINTABLE     => open,
               RXOUTCLK         => open,
               RXOUTCLKFABRIC   => open,
               RXOUTCLKPCS      => open,
               RXPHALIGNDONE    => open,
               RXPHMONITOR      => open,
               RXPHSLIPMONITOR  => open,
               RXPRBSERR        => open,
               RXQPISENN        => open,
               RXQPISENP        => open,
               RXRATEDONE       => open,
               RXRESETDONE      => open,
               RXSTARTOFSEQ     => open,
               RXSTATUS         => open,
               RXVALID          => open,
               TSTOUT           => open,
               TXBUFSTATUS      => open,
               TXCOMFINISH      => open,
               TXDLYSRESETDONE  => open,
               TXGEARBOXREADY   => open,
               TXOUTCLK         => open,
               TXOUTCLKFABRIC   => open,
               TXOUTCLKPCS      => open,
               TXPHALIGNDONE    => open,
               TXPHINITDONE     => open,
               TXQPISENN        => open,
               TXQPISENP        => open,
               TXRATEDONE       => open,
               TXRESETDONE      => open,
               CFGRESET         => '0',
               CLKRSVD          => (others => '0'),
               CPLLLOCKDETCLK   => '0',
               CPLLLOCKEN       => '0',
               CPLLPD           => '0',
               CPLLREFCLKSEL    => "111",            -- Using GTGREFCLK clock
               CPLLRESET        => '0',
               DRPADDR          => (others => '0'),
               DRPCLK           => '0',
               DRPDI            => (others => '0'),
               DRPEN            => '0',
               DRPWE            => '0',
               EYESCANMODE      => '0',
               EYESCANRESET     => '0',
               EYESCANTRIGGER   => '0',
               GTGREFCLK        => refClk,
               GTNORTHREFCLK0   => '0',
               GTNORTHREFCLK1   => '0',
               GTREFCLK0        => '0',
               GTREFCLK1        => '0',
               GTRESETSEL       => '0',
               GTRSVD           => (others => '0'),
               GTRXRESET        => '0',
               GTSOUTHREFCLK0   => '0',
               GTSOUTHREFCLK1   => '0',
               GTTXRESET        => '0',
               GTXRXN           => gtRxN(i),
               GTXRXP           => gtRxP(i),
               LOOPBACK         => (others => '0'),
               PCSRSVDIN        => (others => '0'),
               PCSRSVDIN2       => (others => '0'),
               PMARSVDIN        => (others => '0'),
               PMARSVDIN2       => (others => '0'),
               QPLLCLK          => '0',
               QPLLREFCLK       => '0',
               RESETOVRD        => '0',
               RX8B10BEN        => '0',
               RXBUFRESET       => '0',
               RXCDRFREQRESET   => '0',
               RXCDRHOLD        => '0',
               RXCDROVRDEN      => '0',
               RXCDRRESET       => '0',
               RXCDRRESETRSV    => '0',
               RXCHBONDEN       => '0',
               RXCHBONDI        => (others => '0'),
               RXCHBONDLEVEL    => (others => '0'),
               RXCHBONDMASTER   => '0',
               RXCHBONDSLAVE    => '0',
               RXCOMMADETEN     => '0',
               RXDDIEN          => '0',
               RXDFEAGCHOLD     => '0',
               RXDFEAGCOVRDEN   => '0',
               RXDFECM1EN       => '0',
               RXDFELFHOLD      => '0',
               RXDFELFOVRDEN    => '0',
               RXDFELPMRESET    => '0',
               RXDFETAP2HOLD    => '0',
               RXDFETAP2OVRDEN  => '0',
               RXDFETAP3HOLD    => '0',
               RXDFETAP3OVRDEN  => '0',
               RXDFETAP4HOLD    => '0',
               RXDFETAP4OVRDEN  => '0',
               RXDFETAP5HOLD    => '0',
               RXDFETAP5OVRDEN  => '0',
               RXDFEUTHOLD      => '0',
               RXDFEUTOVRDEN    => '0',
               RXDFEVPHOLD      => '0',
               RXDFEVPOVRDEN    => '0',
               RXDFEVSEN        => '0',
               RXDFEXYDEN       => '0',
               RXDFEXYDHOLD     => '0',
               RXDFEXYDOVRDEN   => '0',
               RXDLYBYPASS      => '0',
               RXDLYEN          => '0',
               RXDLYOVRDEN      => '0',
               RXDLYSRESET      => '0',
               RXELECIDLEMODE   => (others => '0'),
               RXGEARBOXSLIP    => '0',
               RXLPMEN          => '0',
               RXLPMHFHOLD      => '0',
               RXLPMHFOVRDEN    => '0',
               RXLPMLFHOLD      => '0',
               RXLPMLFKLOVRDEN  => '0',
               RXMCOMMAALIGNEN  => '0',
               RXMONITORSEL     => (others => '0'),
               RXOOBRESET       => '0',
               RXOSHOLD         => '0',
               RXOSOVRDEN       => '0',
               RXOUTCLKSEL      => (others => '0'),
               RXPCOMMAALIGNEN  => '0',
               RXPCSRESET       => '0',
               RXPD             => (others => '1'),  -- power down GTH
               RXPHALIGN        => '0',
               RXPHALIGNEN      => '0',
               RXPHDLYPD        => '0',
               RXPHDLYRESET     => '0',
               RXPHOVRDEN       => '0',
               RXPMARESET       => '0',
               RXPOLARITY       => '0',
               RXPRBSCNTRESET   => '0',
               RXPRBSSEL        => (others => '0'),
               RXQPIEN          => '0',
               RXRATE           => (others => '0'),
               RXSLIDE          => '0',
               RXSYSCLKSEL      => (others => '0'),
               RXUSERRDY        => '0',
               RXUSRCLK         => '0',
               RXUSRCLK2        => '0',
               SETERRSTATUS     => '0',
               TSTIN            => (others => '0'),
               TX8B10BBYPASS    => (others => '0'),
               TX8B10BEN        => '0',
               TXBUFDIFFCTRL    => (others => '0'),
               TXCHARDISPMODE   => (others => '0'),
               TXCHARDISPVAL    => (others => '0'),
               TXCHARISK        => (others => '0'),
               TXCOMINIT        => '0',
               TXCOMSAS         => '0',
               TXCOMWAKE        => '0',
               TXDATA           => (others => '0'),
               TXDEEMPH         => '0',
               TXDETECTRX       => '0',
               TXDIFFCTRL       => (others => '0'),
               TXDIFFPD         => '0',
               TXDLYBYPASS      => '0',
               TXDLYEN          => '0',
               TXDLYHOLD        => '0',
               TXDLYOVRDEN      => '0',
               TXDLYSRESET      => '0',
               TXDLYUPDOWN      => '0',
               TXELECIDLE       => '0',
               TXHEADER         => (others => '0'),
               TXINHIBIT        => '0',
               TXMAINCURSOR     => (others => '0'),
               TXMARGIN         => (others => '0'),
               TXOUTCLKSEL      => (others => '0'),
               TXPCSRESET       => '0',
               TXPD             => (others => '1'),  -- power down GTH
               TXPDELECIDLEMODE => '0',
               TXPHALIGN        => '0',
               TXPHALIGNEN      => '0',
               TXPHDLYPD        => '0',
               TXPHDLYRESET     => '0',
               TXPHDLYTSTCLK    => '0',
               TXPHINIT         => '0',
               TXPHOVRDEN       => '0',
               TXPISOPD         => '0',
               TXPMARESET       => '0',
               TXPOLARITY       => '0',
               TXPOSTCURSOR     => (others => '0'),
               TXPOSTCURSORINV  => '0',
               TXPRBSFORCEERR   => '0',
               TXPRBSSEL        => (others => '0'),
               TXPRECURSOR      => (others => '0'),
               TXPRECURSORINV   => '0',
               TXQPIBIASEN      => '0',
               TXQPISTRONGPDOWN => '0',
               TXQPIWEAKPUP     => '0',
               TXRATE           => (others => '0'),
               TXSEQUENCE       => (others => '0'),
               TXSTARTSEQ       => '0',
               TXSWING          => '0',
               TXSYSCLKSEL      => (others => '0'),
               TXUSERRDY        => '0',
               TXUSRCLK         => '0',
               TXUSRCLK2        => '0');
      end generate GEN_VEC;

   end generate;

end architecture mapping;
