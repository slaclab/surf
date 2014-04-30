-------------------------------------------------------------------------------
-- Title      : SsiCmdMasterPkg
-------------------------------------------------------------------------------
-- File       : SsiCmdMasterPkg.vhd
-- Author     : Benjamin Reese  <bareese@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-04-25
-- Last update: 2014-04-30
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Support package for SsiCmdMaster module. Defines IO records.
-------------------------------------------------------------------------------
-- Copyright (c) 2014 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------



library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;

package SsiCmdMasterPkg is

   type SsiCmdMasterType is record
      valid   : sl;                     -- Command Opcode is valid (formerly cmdEn)
      opCode  : slv(7 downto 0);        -- Command OpCode
      context : slv(23 downto 0);       -- Command Context
   end record;

   type SsiCmdMasterArray is array (natural range <>) of SsiCmdMasterType;

   constant SSI_CMD_MASTER_INIT_C : SsiCmdMasterType := (
      valid   => '0',
      opCode  => (others => '0'),
      context => (others => '0'));

end SsiCmdMasterPkg;
