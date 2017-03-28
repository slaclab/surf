-------------------------------------------------------------------------------
-- File       : SaciMasterPkg.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2012-08-14
-- Last update: 2012-09-27
-------------------------------------------------------------------------------
-- Description: Saci Master Package File
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Firmware Standard Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'SLAC Firmware Standard Library', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use ieee.numeric_std.all;
use work.StdRtlPkg.all;

package SaciMasterPkg is

  constant SACI_WRITE_C      : sl       := '1';
  constant SACI_READ_C       : sl       := '0';
  constant SACI_NUM_SLAVES_C : positive := 4;
  constant SACI_CHIP_WIDTH_C : natural  := log2(SACI_NUM_SLAVES_C);

  type SaciMasterInType is record
    req    : sl;
    reset  : sl;
    chip   : slv(SACI_CHIP_WIDTH_C-1 downto 0);
    op     : sl;
    cmd    : slv(6 downto 0);
    addr   : slv(11 downto 0);
    wrData : slv(31 downto 0);
  end record SaciMasterInType;

  type SaciMasterOutType is record
    ack    : sl;
    fail   : sl;
    rdData : slv(31 downto 0);
  end record SaciMasterOutType;

   constant SACI_MASTER_IN_INIT_C : SaciMasterInType := (
      req    => '0',
      reset  => '0',
      chip   => (others => '0'),
      op     => '0',
      cmd    => (others => '0'),
      addr   => (others => '0'),
      wrData => (others => '0'));

   constant SACI_MASTER_OUT_INIT_C : SaciMasterOutType := (
      ack    => '0',
      fail   => '0',
      rdData => (others => '0'));

end package SaciMasterPkg;
