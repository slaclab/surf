-------------------------------------------------------------------------------
-- File       : AxiI2cQsfpPkg.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-10-21
-- Last update: 2016-09-20
-------------------------------------------------------------------------------
-- Description: AxiI2cQsfp Package File
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

package AxiI2cQsfpPkg is

   type AxiI2cQsfpInType is record
      modPrstL : sl;                    -- Module Present
      -- ModPrsL is pulled up to Vcc_Host on the host board and 
      -- grounded in the module. The ModPrsL is asserted “Low” 
      -- when module is inserted into the host connector, and 
      -- deasserted “High” when the module is physically absent 
      -- from the host connector.      
      intL     : sl;                    -- Interrupt
      -- IntL is an output signal. When “Low”, it indicates a possible module operational fault or a status critical to the 
      -- host system. The host identifies the source of the interrupt using the 2-wire serial interface. The IntL signal is an 
      -- open collector output and must be pulled to host supply 
      -- voltage on the host board. A corresponding soft status 
      -- IntL signal is also available in the transceiver memory 
      -- page 0 address 2 bit 1.      
   end record;
   type AxiI2cQsfpInArray is array (natural range <>) of AxiI2cQsfpInType;
   type AxiI2cQsfpInVectorArray is array (integer range<>, integer range<>)of AxiI2cQsfpInType;
   constant AXI_QSFP_IN_INIT_C : AxiI2cQsfpInType := (
      '1',
      '1');   

   type AxiI2cQsfpInOutType is record
      scl : sl;                         -- 2-wire serial interface clock (SCL) 
      sda : sl;                         -- 2-wire serial interface data (SDA) 
   end record;
   type AxiI2cQsfpInOutArray is array (natural range <>) of AxiI2cQsfpInOutType;
   type AxiI2cQsfpInOutVectorArray is array (integer range<>, integer range<>)of AxiI2cQsfpInOutType;
   constant AXI_QSFP_IN_OUT_INIT_C : AxiI2cQsfpInOutType := (
      'Z',
      'Z');       

   type AxiI2cQsfpOutType is record
      modSelL : sl;                     -- Module Select
      -- The ModSelL is an input signal. When held low by the 
      -- host, the module responds to 2-wire serial communication commands. The ModSelL allows the use of multiple 
      -- QSFP+ modules on a single 2-wire interface bus. When 
      -- the ModSelL is “High”, the module will not respond to or 
      -- acknowledge any 2-wire interface communication from 
      -- the host. ModSelL signal input node is biased to the “High” 
      -- state in the module. In order to avoid conflicts, the host 
      -- system shall not attempt 2-wire interface communications within the ModSelL de-assert time after any QSFP+ 
      -- module is deselected. Similarly, the host must wait at least 
      -- for the period of the ModSelL assert time before communicating with the newly selected module. The assertion and 
      -- de-assertion periods of different modules may overlap as 
      -- long as the above timing requirements are met.      
      rstL    : sl;                     -- Module Reset
      -- The ResetL signal is pulled to Vcc in the QSFP+ module. 
      -- A low level on the ResetL signal for longer than the 
      -- minimum pulse length (t_Reset_init) initiates a complete 
      -- module reset, returning all user module settings to their 
      -- default state. Module Reset Assert Time (t_init) starts on 
      -- the rising edge after the low level on the ResetL pin is 
      -- released. During the execution of a reset (t_init) the host 
      -- shall disregard all status bits until the module indicates a 
      -- completion of the reset interrupt. The module indicates 
      -- this by posting an IntL signal with the Data_Not_Ready bit 
      -- negated. Note that on power up (including hot insertion) 
      -- the module will post this completion of reset interrupt 
      -- without requiring a reset.      
      lpMode  : sl;                     -- Low Power Mode
      -- Low power mode. When held high by host, the module 
      -- is held at low power mode. When held low by host, the 
      -- module operates in the normal mode. For class 1 power 
      -- level modules (1.5W), low power mode has no effect.      
   end record;
   type AxiI2cQsfpOutArray is array (natural range <>) of AxiI2cQsfpOutType;
   type AxiI2cQsfpOutVectorArray is array (integer range<>, integer range<>)of AxiI2cQsfpOutType;
   constant AXI_QSFP_OUT_INIT_C : AxiI2cQsfpOutType := (
      '1',
      '1',
      '0');

   type AxiI2cQsfpStatusType is record
      modPrst   : sl;
      interrupt : sl;
   end record;
   constant AXI_QSFP_STATUS_INIT_C : AxiI2cQsfpStatusType := (
      '1',
      '1'); 

   type AxiI2cQsfpConfigType is record
      modSel  : sl;
      rst     : sl;
      lpMode  : sl;
   end record;
   constant AXI_QSFP_CONFIG_INIT_C : AxiI2cQsfpConfigType := (
      '1',
      '1',
      '0'); 

end package;
