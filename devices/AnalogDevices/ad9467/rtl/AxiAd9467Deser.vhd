-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Wrapper for AxiAd9467DeserBit modules
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

library surf;
use surf.StdRtlPkg.all;
use surf.AxiAd9467Pkg.all;

library unisim;
use unisim.vcomponents.all;

entity AxiAd9467Deser is
   generic (
      TPD_G           : time              := 1 ns;
      DELAY_INIT_G    : Slv5Array(0 to 7) := (others => "00000");
      IODELAY_GROUP_G : string            := "AXI_AD9467_IODELAY_GRP");
   port (
      --ADC I/O ports
      adcDataOrP   : in  sl;
      adcDataOrN   : in  sl;
      adcDataInP   : in  slv(7 downto 0);
      adcDataInN   : in  slv(7 downto 0);
      -- ADC Interface
      adcClk       : in  sl;
      adcRst       : in  sl;
      adcData      : out slv(15 downto 0);
      -- IDELAY Interface
      refClk200Mhz : in  sl;
      delayin      : in  AxiAd9467DelayInType;
      delayOut     : out AxiAd9467DelayOutType);
end AxiAd9467Deser;

architecture rtl of AxiAd9467Deser is

   signal adcDataPs : slv(7 downto 0) := (others => '0');
   signal adcDataNs : slv(7 downto 0) := (others => '0');
   signal adcDataP  : slv(7 downto 0) := (others => '0');
   signal adcDataN  : slv(7 downto 0) := (others => '0');
   signal adcDataNd : slv(7 downto 0) := (others => '0');
   signal adcDmuxA  : slv(7 downto 0) := (others => '0');
   signal adcDmuxB  : slv(7 downto 0) := (others => '0');

   attribute IODELAY_GROUP                    : string;
   attribute IODELAY_GROUP of IDELAYCTRL_Inst : label is IODELAY_GROUP_G;

begin

   IBUFDS_OR : IBUFDS
      generic map (
         DIFF_TERM => true)
      port map(
         I  => adcDataOrP,
         IB => adcDataOrN,
         O  => open);

   IDELAYCTRL_Inst : IDELAYCTRL
      port map (
         RDY    => delayOut.rdy,        -- 1-bit output: Ready output
         REFCLK => refClk200Mhz,        -- 1-bit input: Reference clock input
         RST    => delayIn.rst);        -- 1-bit input: Active high reset input

   GEN_DAT :
   for i in 0 to 7 generate

      AxiAd9467DeserBit_Inst : entity surf.AxiAd9467DeserBit
         generic map(
            TPD_G           => TPD_G,
            DELAY_INIT_G    => DELAY_INIT_G(i),
            IODELAY_GROUP_G => IODELAY_GROUP_G)
         port map (
            -- ADC Data (clk domain)
            dataP        => adcDataInP(i),
            dataN        => adcDataInN(i),
            Q1           => adcDataPs(i),
            Q2           => adcDataNs(i),
            -- IO_Delay (refClk200Mhz domain)
            delayInLoad  => delayIn.load,
            delayInData  => delayIn.data(i),
            delayOutData => delayOut.data(i),
            -- Clocks
            clk          => adcClk,
            refClk200Mhz => refClk200Mhz);

   end generate GEN_DAT;

   process(adcClk)
      variable i : integer;
   begin
      if rising_edge(adcClk) then
         adcDataP  <= adcDataPs after TPD_G;
         adcDataN  <= adcDataNs after TPD_G;
         adcDataNd <= adcDataN  after TPD_G;
         if delayin.dmux = '0' then
            adcDmuxA <= adcDataN after TPD_G;
            adcDmuxB <= adcDataP after TPD_G;
         else
            adcDmuxA <= adcDataP  after TPD_G;
            adcDmuxB <= adcDataNd after TPD_G;
         end if;
         for i in 7 downto 0 loop
            adcData(2*i+1) <= adcDmuxB(i) after TPD_G;
            adcData(2*i)   <= adcDmuxA(i) after TPD_G;
         end loop;
      end if;
   end process;

end rtl;
