-------------------------------------------------------------------------------
-- File       : AxiAds42lb69Deser.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-03-20
-- Last update: 2015-05-19
-------------------------------------------------------------------------------
-- Description: ADC DDR Deserializer
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
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.AxiAds42lb69Pkg.all;

library unisim;
use unisim.vcomponents.all;

entity AxiAds42lb69Deser is
   generic (
      TPD_G           : time                                    := 1 ns;
      USE_PLL_G       : boolean                                 := false;
      ADC_CLK_FREQ_G  : real                                    := 250.0E+6;
      DELAY_INIT_G    : Slv5VectorArray(1 downto 0, 7 downto 0) := (others => (others => (others => '0')));
      IODELAY_GROUP_G : string                                  := "AXI_ADS42LB69_IODELAY_GRP");
   port (
      -- ADC Ports  
      clkP         : out sl;
      clkN         : out sl;
      syncP        : out sl;
      syncN        : out sl;
      clkFbP       : in  sl;
      clkFbN       : in  sl;
      dataP        : in  Slv8Array(1 downto 0);
      dataN        : in  Slv8Array(1 downto 0);
      -- ADC Data Interface (adcClk domain)
      adcData      : out Slv16Array(1 downto 0);
      -- Register Interface (adcClk domain)
      dmode        : in  slv(1 downto 0);
      -- Register Interface (refclk200MHz domain)
      delayin      : in  AxiAds42lb69DelayInType;
      delayOut     : out AxiAds42lb69DelayOutType;
      -- Clocks and Resets
      adcClk       : in  sl;
      adcRst       : in  sl;
      adcSync      : in  sl;
      refclk200MHz : in  sl);
end AxiAds42lb69Deser;

architecture rtl of AxiAds42lb69Deser is

   signal adcClock  : sl;
   signal dmux      : slv(1 downto 0);
   signal adcDataPs : Slv8Array(1 downto 0);
   signal adcDataNs : Slv8Array(1 downto 0);
   signal adcDataP  : Slv8Array(1 downto 0);
   signal adcDataN  : Slv8Array(1 downto 0);
   signal adcDataNd : Slv8Array(1 downto 0);
   signal adcDmuxA  : Slv8Array(1 downto 0);
   signal adcDmuxB  : Slv8Array(1 downto 0);
   signal data      : Slv16Array(1 downto 0);

   attribute IODELAY_GROUP                    : string;
   attribute IODELAY_GROUP of IDELAYCTRL_Inst : label is IODELAY_GROUP_G;
   
begin

   AxiAds42lb69Pll_Inst : entity work.AxiAds42lb69Pll
      generic map(
         TPD_G          => TPD_G,
         USE_PLL_G      => USE_PLL_G,
         ADC_CLK_FREQ_G => ADC_CLK_FREQ_G)
      port map (
         -- ADC Clocking ports
         adcClkP   => clkP,
         adcClkN   => clkN,
         adcSyncP  => syncP,
         adcSyncN  => syncN,
         adcClkFbP => clkFbP,
         adcClkFbN => clkFbN,
         -- ADC Reference Signals
         adcSync   => adcSync,
         adcClk    => adcClk,
         adcRst    => adcRst,
         adcClock  => adcClock);         

   SynchVector_Inst : entity work.SynchronizerVector
      generic map(
         TPD_G   => TPD_G,
         WIDTH_G => 2)
      port map(
         clk     => adcClock,
         dataIn  => dmode,
         dataOut => dmux);

   IDELAYCTRL_Inst : IDELAYCTRL
      port map (
         RDY    => delayOut.rdy,        -- 1-bit output: Ready output
         REFCLK => refClk200MHz,        -- 1-bit input: Reference clock input
         RST    => delayIn.rst);        -- 1-bit input: Active high reset input                   

   GEN_CH :
   for ch in 1 downto 0 generate
      GEN_DAT :
      for i in 7 downto 0 generate
         
         AxiAds42lb69DeserBit_Inst : entity work.AxiAds42lb69DeserBit
            generic map(
               TPD_G           => TPD_G,
               DELAY_INIT_G    => DELAY_INIT_G(ch, i),
               IODELAY_GROUP_G => IODELAY_GROUP_G)
            port map (
               -- ADC Data (clk domain)
               dataP        => dataP(ch)(i),
               dataN        => dataN(ch)(i),
               Q1           => adcDataPs(ch)(i),
               Q2           => adcDataNs(ch)(i),
               -- IO_Delay (refClk200MHz domain)
               delayInLoad  => delayIn.load,
               delayInData  => delayIn.data(ch, i),
               delayOutData => delayOut.data(ch, i),
               -- Clocks
               clk          => adcClock,
               refClk200MHz => refClk200MHz);

      end generate GEN_DAT;

      process(adcClock)
         variable i : integer;
      begin
         if rising_edge(adcClock) then
            adcDataP(ch)  <= adcDataPs(ch) after TPD_G;
            adcDataN(ch)  <= adcDataNs(ch) after TPD_G;
            adcDataNd(ch) <= adcDataN(ch)  after TPD_G;
            if dmux(ch) = '0' then
               adcDmuxA(ch) <= adcDataNd(ch) after TPD_G;
               adcDmuxB(ch) <= adcDataP(ch)  after TPD_G;
            else
               adcDmuxA(ch) <= adcDataP(ch) after TPD_G;
               adcDmuxB(ch) <= adcDataN(ch) after TPD_G;
            end if;
            for i in 7 downto 0 loop
               data(ch)(2*i+1) <= adcDmuxB(ch)(i) after TPD_G;
               data(ch)(2*i)   <= adcDmuxA(ch)(i) after TPD_G;
            end loop;
         end if;
      end process;

      SyncFifo_Inst : entity work.SynchronizerFifo
         generic map(
            TPD_G        => TPD_G,
            COMMON_CLK_G => USE_PLL_G,
            DATA_WIDTH_G => 16)
         port map(
            -- Asynchronous Reset
            rst    => adcRst,
            --Write Ports (wr_clk domain)
            wr_clk => adcClock,
            din    => data(ch),
            --Read Ports (rd_clk domain)
            rd_clk => adcClk,
            dout   => adcData(ch));

   end generate GEN_CH;
   
end rtl;
