-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: AXI-Lite interface to ADS42LB69 ADC IC
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
use surf.AxiLitePkg.all;
use surf.AxiAds42lb69Pkg.all;

entity AxiAds42lb69Core is
   generic (
      TPD_G           : time                                    := 1 ns;
      SIM_SPEEDUP_G   : boolean                                 := false;
      USE_PLL_G       : boolean                                 := false;  -- true = phase compensate the ADC data bus
      USE_FBCLK_G     : boolean                                 := true;
      ADC_CLK_FREQ_G  : real                                    := 250.00E+6;  -- units of Hz
      DMODE_INIT_G    : slv(1 downto 0)                         := "00";
      DELAY_INIT_G    : Slv9VectorArray(1 downto 0, 7 downto 0) := (others => (others => (others => '0')));
      IODELAY_GROUP_G : string                                  := "AXI_ADS42LB69_IODELAY_GRP";
      XIL_DEVICE_G    : string                                  := "7SERIES"
      );
   port (
      -- ADC Ports
      adcIn          : in  AxiAds42lb69InType;
      adcOut         : out AxiAds42lb69OutType;
      -- ADC signals (adcClk domain)
      adcSync        : in  sl;
      adcData        : out Slv16Array(1 downto 0);
      -- AXI-Lite Register Interface (axiClk domain)
      axiReadMaster  : in  AxiLiteReadMasterType;
      axiReadSlave   : out AxiLiteReadSlaveType;
      axiWriteMaster : in  AxiLiteWriteMasterType;
      axiWriteSlave  : out AxiLiteWriteSlaveType;
      -- Clocks and Resets
      axiClk         : in  sl;
      axiRst         : in  sl;
      adcClk         : in  sl;
      adcRst         : in  sl;
      refClk200MHz   : in  sl;
      refRst200MHz   : in  sl := '0');
end AxiAds42lb69Core;

architecture mapping of AxiAds42lb69Core is

   signal status     : AxiAds42lb69StatusType;
   signal config     : AxiAds42lb69ConfigType;
   signal adcDataCnv : Slv16Array(1 downto 0);
   signal convert    : slv(1 downto 0);
   signal invert     : slv(1 downto 0);

begin

   SynchVector0_Inst : entity surf.SynchronizerVector
      generic map(
         TPD_G   => TPD_G,
         WIDTH_G => 2)
      port map(
         clk     => adcClk,
         dataIn  => config.convert,
         dataOut => convert);

   SynchVector1_Inst : entity surf.SynchronizerVector
      generic map(
         TPD_G   => TPD_G,
         WIDTH_G => 2)
      port map(
         clk     => adcClk,
         dataIn  => config.invert,
         dataOut => invert);

   GEN_INVERT : for i in 1 downto 0 generate
      process (adcClk) is
      begin
         if (rising_edge(adcClk)) then
            -- option to convert 2s complement data to binary
            if convert(i) = '1' then
               adcDataCnv(i) <= status.adcData(i) - x"8000" after TPD_G;
            else
               adcDataCnv(i) <= status.adcData(i) after TPD_G;
            end if;
            -- option to invert data
            -- useful when the PCB polarity is swapped
            if invert(i) = '1' then
               adcData(i) <= x"FFFF" - adcDataCnv(i) after TPD_G;
            else
               adcData(i) <= adcDataCnv(i) after TPD_G;
            end if;
         end if;
      end process;
   end generate;

   AxiAds42lb69Reg_Inst : entity surf.AxiAds42lb69Reg
      generic map(
         TPD_G          => TPD_G,
         SIM_SPEEDUP_G  => SIM_SPEEDUP_G,
         ADC_CLK_FREQ_G => ADC_CLK_FREQ_G,
         DMODE_INIT_G   => DMODE_INIT_G)
      port map(
         -- AXI-Lite Register Interface (axiClk domain)
         axiReadMaster  => axiReadMaster,
         axiReadSlave   => axiReadSlave,
         axiWriteMaster => axiWriteMaster,
         axiWriteSlave  => axiWriteSlave,
         -- Register Inputs/Outputs (Mixed Domain)
         status         => status,
         config         => config,
         -- Clocks and Resets
         adcClk         => adcClk,
         adcRst         => adcRst,
         axiClk         => axiClk,
         axiRst         => axiRst);

   AxiAds42lb69Deser_Inst : entity surf.AxiAds42lb69Deser
      generic map(
         TPD_G           => TPD_G,
         USE_PLL_G       => USE_PLL_G,
         USE_FBCLK_G     => USE_FBCLK_G,
         ADC_CLK_FREQ_G  => ADC_CLK_FREQ_G,
         DELAY_INIT_G    => DELAY_INIT_G,
         IODELAY_GROUP_G => IODELAY_GROUP_G,
         XIL_DEVICE_G    => XIL_DEVICE_G)
      port map (
         -- ADC Ports
         clkP         => adcOut.clkP,
         clkN         => adcOut.clkN,
         syncP        => adcOut.syncP,
         syncN        => adcOut.syncN,
         clkFbP       => adcIn.clkFbP,
         clkFbN       => adcIn.clkFbN,
         dataP        => adcIn.dataP,
         dataN        => adcIn.dataN,
         -- ADC Data Interface (adcClk domain)
         adcData      => status.adcData,
         -- Register Interface (axiClk domain)
         dmode        => config.dmode,
         -- Register Interface (axiClk domain)
         delayIn      => config.delayIn,
         delayOut     => status.delayOut,
         -- Clocks and Resets
         axiClk       => axiClk,
         axiRst       => axiRst,
         adcClk       => adcClk,
         adcRst       => adcRst,
         adcSync      => adcSync,
         refClk200MHz => refClk200MHz,
         refRst200MHz => refRst200MHz);

end mapping;
