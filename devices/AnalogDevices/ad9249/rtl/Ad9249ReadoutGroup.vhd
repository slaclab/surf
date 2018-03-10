-------------------------------------------------------------------------------
-- File       : Ad9249ReadoutGroup.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-05-26
-- Last update: 2018-03-08
-------------------------------------------------------------------------------
-- Description:
-- ADC Readout Controller
-- Receives ADC Data from an AD9592 chip.
-- Designed specifically for Xilinx 7 series FPGAs
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
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

library UNISIM;
use UNISIM.vcomponents.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;
use work.Ad9249Pkg.all;

entity Ad9249ReadoutGroup is
   generic (
      TPD_G             : time                 := 1 ns;
      NUM_CHANNELS_G    : natural range 1 to 8 := 8;
      IODELAY_GROUP_G   : string               := "DEFAULT_GROUP";
      XIL_DEVICE_G      : string               := "7SERIES";  -- option is "ULTRASCALE"
      IDELAYCTRL_FREQ_G : real                 := 200.0;
      DEFAULT_DELAY_G   : slv(4 downto 0)      := (others => '0');
      ADC_INVERT_CH_G   : slv(7 downto 0)      := "00000000");
   port (
      -- Master system clock, 125Mhz
      axilClk : in sl;
      axilRst : in sl;

      -- Axi Interface
      axilWriteMaster : in  AxiLiteWriteMasterType;
      axilWriteSlave  : out AxiLiteWriteSlaveType;
      axilReadMaster  : in  AxiLiteReadMasterType;
      axilReadSlave   : out AxiLiteReadSlaveType;

      -- Reset for adc deserializer
      adcClkRst : in sl;

      -- Serial Data from ADC
      adcSerial : in Ad9249SerialGroupType;

      -- Deserialized ADC Data
      adcStreamClk : in  sl;
      adcStreams   : out AxiStreamMasterArray(NUM_CHANNELS_G-1 downto 0) :=
      (others => axiStreamMasterInit((false, 2, 8, 0, TKEEP_NORMAL_C, 0, TUSER_NORMAL_C))));
end Ad9249ReadoutGroup;

-- Define architecture
architecture rtl of Ad9249ReadoutGroup is

   signal idelayCtrlRdy : sl;
   signal cmt_locked    : sl;

begin

  GEN_7SERIES_AD9249 : if (XIL_DEVICE_G = "7SERIES") generate
    U_AD9249_0 : entity work.Ad9249ReadoutGroup7S
      generic map (
        TPD_G             => TPD_G,
        NUM_CHANNELS_G    => NUM_CHANNELS_G,
        IODELAY_GROUP_G   => IODELAY_GROUP_G,
        IDELAYCTRL_FREQ_G => IDELAYCTRL_FREQ_G
        )
      port map (
        axilClk           => axilClk,
        axilRst           => axilRst,
        axilReadMaster    => axilReadMaster,
        axilReadSlave     => axilReadSlave,
        axilWriteMaster   => axilWriteMaster,
        axilWriteSlave    => axilWriteSlave,
        adcClkRst         => adcClkRst,
        adcSerial         => adcSerial,
        adcStreamClk      => adcStreamClk,
        adcStreams        => adcStreams
        );      
  end generate GEN_7SERIES_AD9249;

  GEN_ULTRASCALE_AD9249 : if (XIL_DEVICE_G = "ULTRASCALE") generate
    U_AD9249_0 : entity work.Ad9249ReadoutGroupUS
      generic map (
        TPD_G             => TPD_G,
        NUM_CHANNELS_G    => NUM_CHANNELS_G,
        IODELAY_GROUP_G   => IODELAY_GROUP_G,
        IDELAYCTRL_FREQ_G => IDELAYCTRL_FREQ_G
        )
      port map (
        axilClk           => axilClk,
        axilRst           => axilRst,
        axilReadMaster    => axilReadMaster,
        axilReadSlave     => axilReadSlave,
        axilWriteMaster   => axilWriteMaster,
        axilWriteSlave    => axilWriteSlave,
        adcClkRst         => adcClkRst,
        adcSerial         => adcSerial,
        adcStreamClk      => adcStreamClk,
        adcStreams        => adcStreams
        );
  end generate GEN_ULTRASCALE_AD9249;
end rtl;

