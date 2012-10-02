-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : SaciMasterPkg.vhd
-- Author     : Benjamin Reese  <bareese@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2012-08-14
-- Last update: 2012-09-27
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:
-------------------------------------------------------------------------------
-- Copyright (c) 2012 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------


library IEEE;
use IEEE.std_logic_1164.all;
use ieee.numeric_std.all;
use work.StdRtlPkg.all;

package SaciMasterPkg is

  constant SACI_WRITE_C      : sl       := '1';
  constant SACI_READ_C       : sl       := '0';
  constant SACI_NUM_SLAVES_C : positive := 2;
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

end package SaciMasterPkg;
