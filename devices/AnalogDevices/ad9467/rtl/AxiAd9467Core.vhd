-------------------------------------------------------------------------------
-- File       : AxiAd9467Core.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-09-23
-- Last update: 2014-09-24
-------------------------------------------------------------------------------
-- Description: AXI-Lite interface to AD9467 ADC IC
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

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.AxiAd9467Pkg.all;

entity AxiAd9467Core is
   generic (
      TPD_G              : time                  := 1 ns;
      STATUS_CNT_WIDTH_G : natural range 1 to 32 := 32;
      AXI_CLK_FREQ_G     : real                  := 125.0E+6;  -- units of Hz
      ADC_CLK_FREQ_G     : real                  := 250.0E+6;  -- units of Hz
      AXI_ERROR_RESP_G   : slv(1 downto 0)       := AXI_RESP_SLVERR_C;
      DEMUX_INIT_G       : sl                    := '0';
      DELAY_INIT_G       : Slv5Array(0 to 7)     := (others => "00000");
      IODELAY_GROUP_G    : string                := "AXI_AD9467_IODELAY_GRP");
   port (
      -- ADC Ports
      adcIn          : in    AxiAd9467InType;
      adcInOut       : inout AxiAd9467InOutType;
      adcOut         : out   AxiAd9467OutType;
      -- ADC Data Interface (adcClk domain)
      adcClk         : in    sl;
      adcRst         : in    sl;
      adcData        : out   slv(15 downto 0);
      -- IDELAY Reference clock
      refClk200Mhz   : in    sl;
      -- AXI-Lite Register Interface (axiClk domain)      
      axiClk         : in    sl;
      axiRst         : in    sl;
      axiReadMaster  : in    AxiLiteReadMasterType;
      axiReadSlave   : out   AxiLiteReadSlaveType;
      axiWriteMaster : in    AxiLiteWriteMasterType;
      axiWriteSlave  : out   AxiLiteWriteSlaveType);
end AxiAd9467Core;

architecture mapping of AxiAd9467Core is
   
   signal status : AxiAd9467StatusType;
   signal config : AxiAd9467ConfigType;
   
begin

   adcData <= status.adcData;

   AxiAd9467Reg_Inst : entity work.AxiAd9467Reg
      generic map(
         TPD_G              => TPD_G,
         DEMUX_INIT_G       => DEMUX_INIT_G,
         DELAY_INIT_G       => DELAY_INIT_G,
         STATUS_CNT_WIDTH_G => STATUS_CNT_WIDTH_G,
         AXI_ERROR_RESP_G   => AXI_ERROR_RESP_G)
      port map(
         -- AXI-Lite Register Interface    
         axiClk         => axiClk,
         axiRst         => axiRst,
         axiReadMaster  => axiReadMaster,
         axiReadSlave   => axiReadSlave,
         axiWriteMaster => axiWriteMaster,
         axiWriteSlave  => axiWriteSlave,
         -- Register Inputs/Outputs
         status         => status,
         config         => config,
         -- Clock and reset
         adcClk         => adcClk,
         adcRst         => adcRst,
         refClk200Mhz   => refClk200Mhz);

   AxiAd9467Spi_Inst : entity work.AxiAd9467Spi
      generic map(
         TPD_G          => TPD_G,
         AXI_CLK_FREQ_G => AXI_CLK_FREQ_G)
      port map (
         --ADC SPI I/O ports
         adcCs     => adcOut.cs,
         adcSck    => adcOut.sck,
         adcSdio   => adcInOut.sdio,
         -- AXI-Lite Interface
         axiClk    => axiClk,
         axiRst    => axiRst,
         adcSpiIn  => config.spi,
         adcSpiOut => status.spi);

   AxiAd9467Pll_Inst : entity work.AxiAd9467Pll
      generic map(
         TPD_G          => TPD_G,
         ADC_CLK_FREQ_G => ADC_CLK_FREQ_G)
      port map (
         -- ADC Clocking ports
         adcClkOutP => adcOut.clkP,
         adcClkOutN => adcOut.clkN,
         adcClkInP  => adcIn.clkP,
         adcClkInN  => adcIn.clkN,
         -- PLL Status
         pllLocked  => status.pllLocked,
         -- ADC Reference Signals
         adcClk     => adcClk,
         adcRst     => adcRst);  

   AxiAd9467Deser_Inst : entity work.AxiAd9467Deser
      generic map(
         TPD_G           => TPD_G,
         DELAY_INIT_G    => DELAY_INIT_G,
         IODELAY_GROUP_G => IODELAY_GROUP_G)
      port map (
         --ADC I/O ports
         adcDataOrP   => adcIn.orP,
         adcDataOrN   => adcIn.orN,
         adcDataInP   => adcIn.dataP,
         adcDataInN   => adcIn.dataN,
         -- ADC Interface
         adcClk       => adcClk,
         adcRst       => adcRst,
         adcData      => status.adcData,
         -- IDELAY Interface
         refClk200Mhz => refClk200Mhz,
         delayin      => config.delay,
         delayOut     => status.delay); 

   AxiAd9467Mon_Inst : entity work.AxiAd9467Mon
      generic map (
         TPD_G          => TPD_G,
         ADC_CLK_FREQ_G => ADC_CLK_FREQ_G)
      port map (
         adcClk     => adcClk,
         adcRst     => adcRst,
         adcData    => status.adcData,
         adcDataMon => status.adcDataMon);       

end mapping;
