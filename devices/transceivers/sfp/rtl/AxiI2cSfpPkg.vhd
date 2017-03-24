-------------------------------------------------------------------------------
-- File       : AxiI2cSfpPkg.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-04-18
-- Last update: 2016-09-20
-------------------------------------------------------------------------------
-- Description: AxiI2cSfp Package File
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

package AxiI2cSfpPkg is
   
   type AxiI2cSfpInType is record
      rxLoss     : sl;  -- Loss of Signal – High indicates loss of received optical signal 
      moduleDetL : sl;  -- Module Definition 0 (MOD-DEF0) – Grounded in module (module present indicator) 
      txFault    : sl;  -- Transmitter Fault Indication – High indicates a fault condition 
   end record;
   type AxiI2cSfpInArray is array (natural range <>) of AxiI2cSfpInType;
   type AxiI2cSfpInVectorArray is array (integer range<>, integer range<>)of AxiI2cSfpInType;
   constant AXI_SFP_IN_INIT_C : AxiI2cSfpInType := (
      '0',
      '0',
      '0');   

   type AxiI2cSfpInOutType is record
      rateSel : slv(1 downto 0);        -- Bit Rate Parametric Optimization 
      scl     : sl;  -- Module Definition 1 (MOD-DEF1) – Two wire serial ID interface clock line (SCL) 
      sda     : sl;  -- Module Definition 2 (MOD-DEF2) – Two wire serial ID interface data line (SDA) 
   end record;
   type AxiI2cSfpInOutArray is array (natural range <>) of AxiI2cSfpInOutType;
   type AxiI2cSfpInOutVectorArray is array (integer range<>, integer range<>)of AxiI2cSfpInOutType;
   constant AXI_SFP_IN_OUT_INIT_C : AxiI2cSfpInOutType := (
      (others => 'Z'),
      'Z',
      'Z');       

   type AxiI2cSfpOutType is record
      txDisable : sl;  -- Transmitter Disable – Module electrical input disables on high or open 
   end record;
   type AxiI2cSfpOutArray is array (natural range <>) of AxiI2cSfpOutType;
   type AxiI2cSfpOutVectorArray is array (integer range<>, integer range<>)of AxiI2cSfpOutType;
   constant AXI_SFP_OUT_INIT_C : AxiI2cSfpOutType := (
      (others => '0'));  

   type AxiI2cSfpStatusType is record
      rxLoss     : sl;
      moduleDetL : sl;
      txFault    : sl;
   end record;
   constant AXI_SFP_STATUS_INIT_C : AxiI2cSfpStatusType := (
      '0',
      '0',
      '0');

   type AxiI2cSfpConfigType is record
      rateSel   : slv(1 downto 0);
      txDisable : sl;
   end record;
   constant AXI_SFP_CONFIG_INIT_C : AxiI2cSfpConfigType := (
      (others => '1'),
      '0');  

end package;
