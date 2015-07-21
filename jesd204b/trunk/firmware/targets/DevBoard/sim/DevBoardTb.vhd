-------------------------------------------------------------------------------
-- Title      : Testbench for design "DevBoard"
-------------------------------------------------------------------------------
-- File       : DevBoardTb.vhd
-- Author     : Benjamin Reese  <bareese@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-04-29
-- Last update: 2015-04-29
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


----------------------------------------------------------------------------------------------------

entity DevBoardTb is

end entity DevBoardTb;

----------------------------------------------------------------------------------------------------

architecture sim of DevBoardTb is

   -- component generics
   constant TPD_G                  : time    := 1 ns;
   constant SIMULATION_G           : boolean := false;
   constant PGP_REFCLK_FREQ_G      : real    := 125.0E6;
   constant PGP_LINE_RATE_G        : real    := 3.125E9;
   constant AXIL_CLK_FREQ_G        : real    := 125.0E6;
   constant AXIS_CLK_FREQ_G        : real    := 185.0E6;
   constant AXIS_FIFO_ADDR_WIDTH_G : integer := 9;

   -- component ports
   signal pgpRefClkP   : sl;
   signal pgpRefClkN   : sl;
   signal sysClk125P   : sl;
   signal sysClk125N   : sl;
   signal pgpGtRxN     : sl              := '0';
   signal pgpGtRxP     : sl              := '0';
   signal pgpGtTxN     : sl;
   signal pgpGtTxP     : sl;
   signal fpgaDevClkaP : sl              := '0';
   signal fpgaDevClkaN : sl              := '1';
   signal fpgaSysRefP  : sl              := '0';
   signal fpgaSysRefN  : sl              := '1';
   signal adcGtTxP     : slv(3 downto 0);
   signal adcGtTxN     : slv(3 downto 0);
   signal adcGtRxP     : slv(3 downto 0) := (others => '0');
   signal adcGtRxN     : slv(3 downto 0) := (others => '1');
   signal syncbP       : sl;
   signal syncbN       : sl;
   signal leds         : slv(4 downto 0);

   signal   spiSclk_o              : sl:= '1';
   signal   spiSdi_o               : sl:= '1';
   signal   spiSdo_i               : sl := '1';
   signal   spiSdio_io             : sl:= '1';
   signal   spiCsL_o               : slv(3 downto 0):= "0000";
   signal   spiSclkDac_o           : sl := '1';
   signal   spiSdioDac_io          : sl:= '1';
   signal   spiCsLDac_o            : sl:= '1';

begin

   ClkRst_1 : entity work.ClkRst
   generic map (
      CLK_PERIOD_G => 8 ns)
   port map (
      clkP => pgpRefClkP,
      clkN => pgpRefClkN);
         
   ClkRst_2 : entity work.ClkRst
   generic map (
      CLK_PERIOD_G => 8 ns)
   port map (
      clkP => sysClk125P,
      clkN => sysClk125N);

   -- component instantiation
   DUT : entity work.DevBoard
      generic map (
         TPD_G                  => TPD_G,
         SIMULATION_G           => true,
         PGP_REFCLK_FREQ_G      => 125.0E6,
         PGP_LINE_RATE_G        => 3.125E9,
         AXIL_CLK_FREQ_G        => 125.0E6,
         AXIS_CLK_FREQ_G        => 156.25E6,
         AXIS_FIFO_ADDR_WIDTH_G => 10)
      port map (
         sysClk125P   => sysClk125P,
         sysClk125N   => sysClk125N,
         pgpRefClkSel  => open,
         pgpRefClkP   => pgpRefClkP,
         pgpRefClkN   => pgpRefClkN,
         pgpGtRxN     => pgpGtRxN,
         pgpGtRxP     => pgpGtRxP,
         pgpGtTxN     => pgpGtTxN,
         pgpGtTxP     => pgpGtTxP,
 --        fpgaDevClkaP => fpgaDevClkaP,
 --        fpgaDevClkaN => fpgaDevClkaN,
         fpgaSysRefP  => fpgaSysRefP,
         fpgaSysRefN  => fpgaSysRefN,
         -- adcGtTxP     => adcGtTxP,
         -- adcGtTxN     => adcGtTxN,
         -- adcGtRxP     => adcGtRxP,
         -- adcGtRxN     => adcGtRxN,
         syncbP       => syncbP,
         syncbN       => syncbN,
         spiSclk_o     => spiSclk_o,
         spiSdi_o      => spiSdi_o,
         spiSdo_i      => spiSdo_i,
         spiSdio_io    => spiSdio_io,
         spiCsL_o      => spiCsL_o,
         spiSclkDac_o  => spiSclkDac_o,
         spiSdioDac_io => spiSdioDac_io,
         spiCsLDac_o   => spiCsLDac_o,
         leds         => leds);





end architecture sim;

----------------------------------------------------------------------------------------------------


