-------------------------------------------------------------------------------
-- File       : AxiLtc2270Core.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-04-21
-- Last update: 2014-04-21
-------------------------------------------------------------------------------
-- Description: AXI-Lite interface to LTC2270 ADC IC
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
use ieee.numeric_std.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.AxiLtc2270Pkg.all;

entity AxiLtc2270Core is
   generic (
      TPD_G              : time                            := 1 ns;
      DMODE_INIT_G       : slv(1 downto 0)                 := "00";
      DELAY_INIT_G       : Slv5VectorArray(0 to 1, 0 to 7) := (others => (others => (others => '0')));
      IODELAY_GROUP_G    : string                          := "AXI_LTC2270_IODELAY_GRP";
      STATUS_CNT_WIDTH_G : natural range 1 to 32           := 32;
      AXI_CLK_FREQ_G     : real                            := 200.0E+6;  -- units of Hz
      AXI_ERROR_RESP_G   : slv(1 downto 0)                 := AXI_RESP_SLVERR_C);      
   port (
      -- ADC Ports
      adcIn          : in    AxiLtc2270InType;
      adcOut         : out   AxiLtc2270OutType;
      adcInOut       : inout AxiLtc2270InOutType;
      -- ADC signals (axiClk domain)
      adcValid       : out   slv(0 to 1);
      adcData        : out   Slv16Array(0 to 1);                         --2's complement      
      -- AXI-Lite Register Interface (axiClk domain)
      axiReadMaster  : in    AxiLiteReadMasterType;
      axiReadSlave   : out   AxiLiteReadSlaveType;
      axiWriteMaster : in    AxiLiteWriteMasterType;
      axiWriteSlave  : out   AxiLiteWriteSlaveType;
      -- Clocks and Resets
      axiClk         : in    sl;
      axiRst         : in    sl;
      adcClk         : in    sl;                                         -- up to 20 MHz
      refclk200MHz   : in    sl);
end AxiLtc2270Core;

architecture mapping of AxiLtc2270Core is
   
   signal status : AxiLtc2270StatusType;
   signal config : AxiLtc2270ConfigType;
   
begin

   adcValid <= status.adcValid;
   adcData  <= status.adcData;

   AxiLtc2270Reg_Inst : entity work.AxiLtc2270Reg
      generic map(
         TPD_G              => TPD_G,
         DMODE_INIT_G       => DMODE_INIT_G,
         DELAY_INIT_G       => DELAY_INIT_G,
         STATUS_CNT_WIDTH_G => STATUS_CNT_WIDTH_G,
         AXI_CLK_FREQ_G     => AXI_CLK_FREQ_G,
         AXI_ERROR_RESP_G   => AXI_ERROR_RESP_G)
      port map(
         -- ADC Ports
         adcCs          => adcOut.cs,
         adcSck         => adcOut.sck,
         adcSdi         => adcOut.sdi,
         adcSdo         => adcInOut.sdo,
         adcPar         => adcOut.par,
         -- AXI-Lite Register Interface    
         axiReadMaster  => axiReadMaster,
         axiReadSlave   => axiReadSlave,
         axiWriteMaster => axiWriteMaster,
         axiWriteSlave  => axiWriteSlave,
         -- Register Inputs/Outputs (Mixed Domain)
         status         => status,
         config         => config,
         -- Clocks and Resets
         axiClk         => axiClk,
         axiRst         => axiRst,
         refclk200MHz   => refclk200MHz);   

   AxiLtc2270Deser_Inst : entity work.AxiLtc2270Deser
      generic map(
         TPD_G           => TPD_G,
         DELAY_INIT_G    => DELAY_INIT_G,
         IODELAY_GROUP_G => IODELAY_GROUP_G)
      port map (
         -- ADC Ports  
         clkInP       => adcIn.clkP,
         clkInN       => adcIn.clkN,
         clkOutP      => adcOut.clkP,
         clkOutN      => adcOut.clkN,
         dataP        => adcIn.dataP,
         dataN        => adcIn.dataN,
         orP          => adcIn.orP,
         orN          => adcIn.orN,
         -- ADC Data Interface (axiClk domain)
         adcValid     => status.adcValid,
         adcData      => status.adcData,
         -- Register Interface (axiClk domain)
         dmode        => config.dmode,
         -- Register Interface (refclk200MHz domain)
         delayin      => config.delayin,
         delayOut     => status.delayOut,
         -- Clocks and Resets
         axiClk       => axiClk,
         axiRst       => axiRst,
         adcClk       => adcClk,
         refclk200MHz => refclk200MHz);  

end mapping;
