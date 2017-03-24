-------------------------------------------------------------------------------
-- File       : AxiAds42lb69Core.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-03-20
-- Last update: 2015-05-19
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

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.AxiAds42lb69Pkg.all;

entity AxiAds42lb69Core is
   generic (
      TPD_G              : time                                    := 1 ns;
      COMMON_CLK_G       : boolean                                 := false;  -- true if axiClk = adcClk
      USE_PLL_G          : boolean                                 := false;  -- true = phase compensate the ADC data bus
      ADC_CLK_FREQ_G     : real                                    := 250.0E+6;  -- units of Hz
      DMODE_INIT_G       : slv(1 downto 0)                         := "00";
      DELAY_INIT_G       : Slv5VectorArray(1 downto 0, 7 downto 0) := (others => (others => (others => '0')));
      IODELAY_GROUP_G    : string                                  := "AXI_ADS42LB69_IODELAY_GRP";
      STATUS_CNT_WIDTH_G : natural range 1 to 32                   := 32;
      AXI_ERROR_RESP_G   : slv(1 downto 0)                         := AXI_RESP_SLVERR_C);      
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
      refclk200MHz   : in  sl);
end AxiAds42lb69Core;

architecture mapping of AxiAds42lb69Core is
   
   signal status : AxiAds42lb69StatusType;
   signal config : AxiAds42lb69ConfigType;

   signal mAxiReadMaster  : AxiLiteReadMasterType;
   signal mAxiReadSlave   : AxiLiteReadSlaveType;
   signal mAxiWriteMaster : AxiLiteWriteMasterType;
   signal mAxiWriteSlave  : AxiLiteWriteSlaveType;
   
begin

   adcData <= status.adcData;

   GEN_ASYNC_AXI_LITE : if (COMMON_CLK_G = false) generate
      
      AxiLiteAsync_Inst : entity work.AxiLiteAsync
         generic map (
            TPD_G => TPD_G)
         port map (
            -- Slave Port
            sAxiClk         => axiClk,
            sAxiClkRst      => axiRst,
            sAxiReadMaster  => axiReadMaster,
            sAxiReadSlave   => axiReadSlave,
            sAxiWriteMaster => axiWriteMaster,
            sAxiWriteSlave  => axiWriteSlave,
            -- Master Port
            mAxiClk         => adcClk,
            mAxiClkRst      => adcRst,
            mAxiReadMaster  => mAxiReadMaster,
            mAxiReadSlave   => mAxiReadSlave,
            mAxiWriteMaster => mAxiWriteMaster,
            mAxiWriteSlave  => mAxiWriteSlave);    

   end generate;

   GEN_SYNC_AXI_LITE : if (COMMON_CLK_G = true) generate

      mAxiReadMaster  <= axiReadMaster;
      axiReadSlave    <= mAxiReadSlave;
      mAxiWriteMaster <= axiWriteMaster;
      axiWriteSlave   <= mAxiWriteSlave;
      
   end generate;

   AxiAds42lb69Reg_Inst : entity work.AxiAds42lb69Reg
      generic map(
         TPD_G              => TPD_G,
         DMODE_INIT_G       => DMODE_INIT_G,
         DELAY_INIT_G       => DELAY_INIT_G,
         STATUS_CNT_WIDTH_G => STATUS_CNT_WIDTH_G,
         ADC_CLK_FREQ_G     => ADC_CLK_FREQ_G,
         AXI_ERROR_RESP_G   => AXI_ERROR_RESP_G)
      port map(
         -- ADC Ports
         csL            => adcOut.csL,
         sck            => adcOut.sck,
         sdi            => adcOut.sdi,
         rst            => adcOut.rst,
         sdo            => adcIn.sdo,
         -- AXI-Lite Register Interface (adcClk domain)
         axiReadMaster  => mAxiReadMaster,
         axiReadSlave   => mAxiReadSlave,
         axiWriteMaster => mAxiWriteMaster,
         axiWriteSlave  => mAxiWriteSlave,
         -- Register Inputs/Outputs (Mixed Domain)
         status         => status,
         config         => config,
         -- Clocks and Resets
         adcClk         => adcClk,
         adcRst         => adcRst,
         refclk200MHz   => refclk200MHz);   

   AxiAds42lb69Deser_Inst : entity work.AxiAds42lb69Deser
      generic map(
         TPD_G           => TPD_G,
         USE_PLL_G       => USE_PLL_G,
         ADC_CLK_FREQ_G  => ADC_CLK_FREQ_G,
         DELAY_INIT_G    => DELAY_INIT_G,
         IODELAY_GROUP_G => IODELAY_GROUP_G)
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
         -- Register Interface (adcClk domain)
         dmode        => config.dmode,
         -- Register Interface (refclk200MHz domain)
         delayin      => config.delayin,
         delayOut     => status.delayOut,
         -- Clocks and Resets
         adcClk       => adcClk,
         adcRst       => adcRst,
         adcSync      => adcSync,
         refclk200MHz => refclk200MHz);      

end mapping;
