-------------------------------------------------------------------------------
-- File       : AxiLtc2270Deser.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-04-21
-- Last update: 2015-01-20
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
use work.AxiLtc2270Pkg.all;

library unisim;
use unisim.vcomponents.all;

entity AxiLtc2270Deser is
   generic (
      TPD_G           : time                            := 1 ns;
      DELAY_INIT_G    : Slv5VectorArray(0 to 1, 0 to 7) := (others => (others => (others => '0')));
      IODELAY_GROUP_G : string                          := "AXI_LTC2270_IODELAY_GRP");
   port (
      -- ADC Ports  
      clkInP       : in  sl;
      clkInN       : in  sl;
      clkOutP      : out sl;
      clkOutN      : out sl;
      dataP        : in  Slv8Array(0 to 1);
      dataN        : in  Slv8Array(0 to 1);
      orP          : in  sl;
      orN          : in  sl;
      -- ADC Data Interface (axiClk domain)
      adcValid     : out slv(0 to 1);
      adcData      : out Slv16Array(0 to 1);  -- 2's complement  
      -- Register Interface (axiClk domain)
      dmode        : in  slv(1 downto 0);
      -- Register Interface (refclk200MHz domain)
      delayin      : in  AxiLtc2270DelayInType;
      delayOut     : out AxiLtc2270DelayOutType;
      -- Clocks and Resets
      axiClk       : in  sl;
      axiRst       : in  sl;
      adcClk       : in  sl;                  -- Up to 20 MHz
      refclk200MHz : in  sl);
end AxiLtc2270Deser;

architecture rtl of AxiLtc2270Deser is

   signal adcInClk,
      adcClock : sl;
   signal dmux : slv(1 downto 0);
   signal adcDataPs,
      adcDataNs,
      adcDataP,
      adcDataN,
      adcDataNd,
      adcDmuxA,
      adcDmuxB : Slv8Array(0 to 1);
   signal data : Slv16Array(0 to 1);

   attribute IODELAY_GROUP                    : string;
   attribute IODELAY_GROUP of IDELAYCTRL_Inst : label is IODELAY_GROUP_G;
   
begin

   ClkOutBufDiff_0 : entity work.ClkOutBufDiff
      port map (
         clkIn   => adcClk,
         clkOutP => clkOutP,
         clkOutN => clkOutN);

   IBUFDS_OR : IBUFDS
      generic map (
         DIFF_TERM => true)
      port map (
         I  => orP,
         IB => orN,
         O  => open);

   IBUFGDS_0 : IBUFGDS
      port map (
         I  => clkInP,
         IB => clkInN,
         O  => adcInClk);

   BUFG_0 : BUFG
      port map (
         I => adcInClk,
         O => adcClock);         

   SynchVector_Inst : entity work.SynchronizerVector
      generic map(
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
   for ch in 0 to 1 generate
      GEN_DAT :
      for i in 0 to 7 generate
         
         AxiLtc2270DeserBit_Inst : entity work.AxiLtc2270DeserBit
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
            DATA_WIDTH_G => 16)
         port map(
            -- Asynchronous Reset
            rst    => axiRst,
            --Write Ports (wr_clk domain)
            wr_clk => adcClock,
            din    => data(ch),
            --Read Ports (rd_clk domain)
            rd_clk => axiClk,
            valid  => adcValid(ch),
            dout   => adcData(ch));

   end generate GEN_CH;
   
end rtl;
