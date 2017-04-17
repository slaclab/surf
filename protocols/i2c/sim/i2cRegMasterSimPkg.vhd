-------------------------------------------------------------------------------
-- File       : i2cRegMasterSimPkg.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-01-24
-- Last update: 2013-01-28
-------------------------------------------------------------------------------
-- Description: Simulation Package file for i2cRegMasterPkg
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
use work.i2cPkg.all;
use work.txt_util_p.all;

package i2cRegMasterPkg is

  procedure writeI2cReg (
    signal clk    : in  sl;
    signal regIn  : out i2cRegMasterInType;
    signal regOut : in  i2cRegMasterOutType;
    i2cAddr       : in  slv;
    regAddr       : in  slv;
    regData       : in  slv;
    endianness    : in  sl;
    debug         : in  boolean := false);

  procedure writeI2cBurst8 (
    signal clk    : in  sl;
    signal regIn  : out i2cRegMasterInType;
    signal regOut : in  i2cRegMasterOutType;
    i2cAddr       : in  slv;
    regAddr       : in  slv;
    regData        : in  Slv8Array(0 to 3);
    endianness    : in  sl;
    debug         : in  boolean := false);

  procedure readI2cReg (
    signal clk    : in  sl;
    signal regIn  : out i2cRegMasterInType;
    signal regOut : in  i2cRegMasterOutType;
    i2cAddr       : in  slv;
    regAddr       : in  slv;
    regData       : out slv;
    endianness    : in  sl;
    debug         : in  boolean := false);

  procedure readI2cBurst8 (
    signal clk    : in  sl;
    signal regIn  : out i2cRegMasterInType;
    signal regOut : in  i2cRegMasterOutType;
    i2cAddr       : in  slv;
    regAddr       : in  slv;
    regData       : out Slv8Array(0 to 3);
    endianness    : in  sl;
    debug         : in  boolean := false);

end package i2cRegMasterPkg;

package body i2cRegMasterPkg is

  procedure writeI2cReg (
    signal clk    : in  sl;
    signal regIn  : out i2cRegMasterInType;
    signal regOut : in  i2cRegMasterOutType;
    i2cAddr       : in  slv;
    regAddr       : in  slv;
    regData       : in  slv;
    endianness    : in  sl;
    debug         : in  boolean := false)
  is
    variable i2cAddrSizeVar : integer := i2cAddr'length;
    variable regAddrSizeVar : integer := regAddr'length/8;
    variable regDataSizeVar : integer := regData'length/8;
  begin
    wait until clk = '1';

    -- Put write on inputs
    if (i2cAddrSizeVar = 7) then
      regIn.i2cAddr <= "000" & i2cAddr;
      regIn.tenbit  <= '0';
    elsif (i2cAddrSizeVar = 10) then
      regIn.i2cAddr <= i2cAddr;
      regIn.tenbit  <= '1';
    end if;
    regIn.regAddr                <= (others => '0');
    regIn.regAddr(regAddr'range) <= regAddr;
    regIn.regAddrSize            <= slv(to_unsigned(regAddrSizeVar-1, 2));
    regIn.regDataSize            <= slv(to_unsigned(regDataSizeVar-1, 2));
    regIn.endianness             <= endianness;
    regIn.regOp                  <= '1';

    regIn.regWrData                <= (others => '0');
    regIn.regWrData(regData'range) <= regData;

    regIn.regReq <= '1';

    -- Wait for ack
    wait until regOut.regAck = '1';
    wait until clk = '1';
    regIn.regReq <= '0';
    wait until regOut.regAck = '0';
    wait until clk = '1';

    print(debug, "writeI2cReg: i2c: " & str(i2cAddr) & ", addr: " & hstr(regAddr) & ", data: " & hstr(regData));

  end procedure writeI2cReg;

  procedure writeI2cBurst8 (
    signal clk    : in  sl;
    signal regIn  : out i2cRegMasterInType;
    signal regOut : in  i2cRegMasterOutType;
    i2cAddr       : in  slv;
    regAddr       : in  slv;
    regData        : in  Slv8Array(0 to 3);
    endianness    : in  sl;
    debug         : in  boolean := false)
  is
    variable i2cAddrSizeVar : integer := i2cAddr'length;
    variable regAddrSizeVar : integer := regAddr'length/8;
    variable regDataSizeVar : integer := 4;
  begin
    wait until clk = '1';

    -- Put write on inputs
    if (i2cAddrSizeVar = 7) then
      regIn.i2cAddr <= "000" & i2cAddr;
      regIn.tenbit  <= '0';
    elsif (i2cAddrSizeVar = 10) then
      regIn.i2cAddr <= i2cAddr;
      regIn.tenbit  <= '1';
    end if;


    regIn.regAddr                <= (others => '0');
    regIn.regAddr(regAddr'range) <= regAddr;
    regIn.regAddrSize            <= slv(to_unsigned(regAddrSizeVar-1, 2));
    regIn.regDataSize            <= slv(to_unsigned(regDataSizeVar-1, 2));
    regIn.endianness             <= endianness;
    regIn.regOp                  <= '1';

    regIn.regWrData               <= (others => '0');
    regIn.regWrData(7 downto 0)   <= regData(0);
    regIn.regWrData(15 downto 8)  <= regData(1);
    regIn.regWrData(23 downto 16) <= regData(2);
    regIn.regWrData(31 downto 24) <= regData(3);

    regIn.regReq <= '1';

    -- Wait for ack
    wait until regOut.regAck = '1';
    wait until clk = '1';
    regIn.regReq <= '0';
    wait until regOut.regAck = '0';
    wait until clk = '1';

    print(debug, "writeI2cBurst: i2c: " & str(i2cAddr) & ", addr: " & hstr(regAddr) & ", data: " & hstr(regData(0)) & ", " & hstr(regData(1)) & ", " & hstr(regData(2)) & ", " & hstr(regData(3)));

  end procedure;

  procedure readI2cReg (
    signal clk    : in  sl;
    signal regIn  : out i2cRegMasterInType;
    signal regOut : in  i2cRegMasterOutType;
    i2cAddr       : in  slv;
    regAddr       : in  slv;
    regData       : out slv;
    endianness    : in  sl;
    debug         : in  boolean := false)
  is
    variable i2cAddrSizeVar : integer := i2cAddr'length;
    variable regAddrSizeVar : integer := regAddr'length/8;
    variable regDataSizeVar : integer := regData'length/8;
  begin
    wait until clk = '1';

    if (i2cAddrSizeVar = 7) then
      regIn.i2cAddr <= "000" & i2cAddr;
      regIn.tenbit  <= '0';
    elsif (i2cAddrSizeVar = 10) then
      regIn.i2cAddr <= i2cAddr;
      regIn.tenbit  <= '1';
    end if;
    regIn.regAddr                <= (others => '0');
    regIn.regAddr(regAddr'range) <= regAddr;
    regIn.regAddrSize            <= slv(to_unsigned(regAddrSizeVar-1, 2));
    regIn.regDataSize            <= slv(to_unsigned(regDataSizeVar-1, 2));
    regIn.endianness             <= endianness;
    regIn.regOp                  <= '0';

    regIn.regReq <= '1';

    wait until regOut.regAck = '1';
    wait until clk = '1';
    regIn.regReq <= '0';

    regData := regOut.regRdData(regData'range);
    wait until regOut.regAck = '0';
    wait until clk = '1';

    print(debug, "readI2cReg: i2c: " & str(i2cAddr) & ", addr: " & hstr(regAddr) & " Data: " & hstr(regOut.regRdData(regData'range)));
    
  end procedure readI2cReg;

  procedure readI2cBurst8 (
    signal clk    : in  sl;
    signal regIn  : out i2cRegMasterInType;
    signal regOut : in  i2cRegMasterOutType;
    i2cAddr       : in  slv;
    regAddr       : in  slv;
    regData       : out Slv8Array(0 to 3);
    endianness    : in  sl;
    debug         : in  boolean := false)
  is
    variable i2cAddrSizeVar : integer := i2cAddr'length;
    variable regAddrSizeVar : integer := regAddr'length/8;
    variable regDataSizeVar : integer := 4;
  begin
    wait until clk = '1';

    if (i2cAddrSizeVar = 7) then
      regIn.i2cAddr <= "000" & i2cAddr;
      regIn.tenbit  <= '0';
    elsif (i2cAddrSizeVar = 10) then
      regIn.i2cAddr <= i2cAddr;
      regIn.tenbit  <= '1';
    end if;
    regIn.regAddr                <= (others => '0');
    regIn.regAddr(regAddr'range) <= regAddr;
    regIn.regAddrSize            <= slv(to_unsigned(regAddrSizeVar-1, 2));
    regIn.regDataSize            <= slv(to_unsigned(regDataSizeVar-1, 2));
    regIn.endianness             <= endianness;
    regIn.regOp                  <= '0';

    regIn.regReq <= '1';

    wait until regOut.regAck = '1';
    wait until clk = '1';
    regIn.regReq <= '0';

    regData(0) := regOut.regRdData(7 downto 0);
    regData(1) := regOut.regRdData(15 downto 8);
    regData(2) := regOut.regRdData(23 downto 16);
    regData(3) := regOut.regRdData(31 downto 24);
    
    wait until regOut.regAck = '0';
    wait until clk = '1';

    print(debug, "readI2cBurst8: i2c: " & str(i2cAddr) & ", addr: " & hstr(regAddr) & " Data: " & hstr(regOut.regRdData));
    
  end procedure;

end package body i2cRegMasterPkg;
