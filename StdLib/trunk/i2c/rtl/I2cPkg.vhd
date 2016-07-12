------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2012, Aeroflex Gaisler
--
--  This program is free software; you can redistribute it and/or modify
--  it under the terms of the GNU General Public License as published by
--  the Free Software Foundation; either version 2 of the License, or
--  (at your option) any later version.
--
--  This program is distributed in the hope that it will be useful,
--  but WITHOUT ANY WARRANTY; without even the implied warranty of
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--  GNU General Public License for more details.
--
--  You should have received a copy of the GNU General Public License
--  along with this program; if not, write to the Free Software
--  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA 
-----------------------------------------------------------------------------
-- Package:     i2c
-- File:        i2c.vhd
-- Author:      Jiri Gaisler - Gaisler Research
-- Description: I2C interface package
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use work.StdRtlPkg.all;

package I2cPkg is

   type i2c_in_type is record
      scl : std_ulogic;
      sda : std_ulogic;
   end record;

   type i2c_in_array is array (natural range <>) of i2c_in_type;

   type i2c_out_type is record
      scl    : std_ulogic;
      scloen : std_ulogic;
      sda    : std_ulogic;
      sdaoen : std_ulogic;
      enable : std_ulogic;
   end record;

   type i2c_out_array is array (natural range <>) of i2c_out_type;

   --------------------------------------------------------------------------------------------------
   constant I2C_INVALID_ADDR_ERROR_C     : slv(7 downto 0) := X"01";
   constant I2C_WRITE_ACK_ERROR_C        : slv(7 downto 0) := X"02";
   constant I2C_ARBITRATION_LOST_ERROR_C : slv(7 downto 0) := X"03";

   type I2cMasterInType is record
      enable   : sl;                    -- Enable the master
      prescale : slv(15 downto 0);      -- Determines i2c clock speed
      filter   : slv(15 downto 0);      -- Dynamic filter value
      txnReq   : sl;                    -- Execute a transaction
      stop     : sl;                    -- Set STOP when done
      op       : sl;                    -- 1 for write, 0 for read
      busReq   : sl;                    -- 1 for bus request, 0 for read/write
      addr     : slv(9 downto 0);       -- i2c device address
      tenbit   : sl;                    -- use 10 bit addressing
      wrValid  : sl;
      wrData   : slv(7 downto 0);       -- Data sent during write txn
      rdAck    : sl;
   end record;

   type I2cMasterOutType is record
      busAck   : sl;
      txnError : sl;                    -- An error occured during the txn
      wrAck    : sl;
      rdValid  : sl;
      rdData   : slv(7 downto 0);       -- Data received during read txn
   end record;
   --------------------------------------------------------------------------------------------------
   type I2cRegMasterInType is record
      i2cAddr     : slv(9 downto 0);
      tenbit      : sl;
      regAddr     : slv(31 downto 0);
      regWrData   : slv(31 downto 0);
      regOp       : sl;
      regAddrSkip : sl;
      regAddrSize : slv(1 downto 0);
      regDataSize : slv(1 downto 0);
      regReq      : sl;
      busReq      : sl;
      endianness  : sl;
      repeatStart : sl;
   end record;

   constant I2C_REG_MASTER_IN_INIT_C : I2cRegMasterInType := (
      i2cAddr     => (others => '0'),
      tenbit      => '0',
      regAddr     => (others => '0'),
      regWrData   => (others => '0'),
      regOp       => '0',               -- 1 for write, 0 for read
      regAddrSkip => '0',
      regAddrSize => (others => '0'),
      regDataSize => (others => '0'),
      regReq      => '0',
      busReq      => '0',
      endianness  => '0',
      repeatStart => '0');

   type I2cRegMasterInArray is array (natural range <>) of I2cRegMasterInType;

   type I2cRegMasterOutType is record
      regAck      : sl;
      regFail     : sl;
      regFailCode : slv(7 downto 0);
      regRdData   : slv(31 downto 0);
   end record;

   constant I2C_REG_MASTER_OUT_INIT_C : I2cRegMasterOutType := (
      regAck      => '0',
      regFail     => '0',
      regFailCode => (others => '0'),
      regRdData   => (others => '0'));

   type I2cRegMasterOutArray is array (natural range <>) of I2cRegMasterOutType;

   --------------------------------------------------------------------------------------------------
   type I2cSlaveInType is record
      enable  : sl;
      txValid : sl;
      txData  : slv(7 downto 0);
      rxAck   : sl;
   end record I2cSlaveInType;

   constant I2C_SLAVE_IN_INIT_C : I2cSlaveInType := (
      enable  => '0',
      txValid => '0',
      txData  => (others => '0'),
      rxAck   => '0');

   type I2cSlaveOutType is record
      rxActive : sl;
      rxValid  : sl;
      rxData   : slv(7 downto 0);
      txActive : sl;
      txAck    : sl;
      nack     : sl;
   end record I2cSlaveOutType;

   constant I2C_SLAVE_OUT_INIT_C : I2cSlaveOutType := (
      rxActive => '0',
      rxValid  => '0',
      rxData   => (others => '0'),
      txActive => '0',
      txAck    => '0',
      nack     => '0');

   -------------------------------------------------------------------------------------------------
   -- AXI Bridge Generic Type, stick here for now
   -------------------------------------------------------------------------------------------------
   type I2cAxiLiteDevType is record
      i2cAddress  : slv(9 downto 0);
      i2cTenbit   : sl;
      dataSize    : integer;
      addrSize    : integer;
      endianness  : sl;
      repeatStart : sl;
   end record I2cAxiLiteDevType;

   function MakeI2cAxiLiteDevType (
      i2cAddress  : slv;
      dataSize    : integer;
      addrSize    : integer;
      endianness  : sl;
      repeatStart : sl := '0')
      return I2cAxiLiteDevType;

   type I2cAxiLiteDevArray is array (natural range <>) of I2cAxiLiteDevType;

   function maxAddrSize (constant devMap : I2cAxiLiteDevArray) return natural;

   --------------------------------------------------------------------------------------------------
   -- Opencores i2c
   component i2c_master_byte_ctrl is
      generic (filter : integer; dynfilt : integer);
      port (
         clk    : in std_logic;
         rst    : in std_logic;         -- active high reset
         nReset : in std_logic;         -- asynchornous active low reset
         -- (not used in GRLIB)
         ena    : in std_logic;         -- core enable signal

         clk_cnt : in std_logic_vector(15 downto 0);  -- 4x SCL

         -- input signals
         start,
         stop,
         read,
         write,
         ack_in :    std_logic;
         din    : in std_logic_vector(7 downto 0);
         filt   : in std_logic_vector((filter-1)*dynfilt downto 0);

         -- output signals
         cmd_ack  : out std_logic;
         ack_out  : out std_logic;
         i2c_busy : out std_logic;
         i2c_al   : out std_logic;
         dout     : out std_logic_vector(7 downto 0);

         -- i2c lines
         scl_i   : in  std_logic;       -- i2c clock line input
         scl_o   : out std_logic;       -- i2c clock line output
         scl_oen : out std_logic;       -- i2c clock line output enable, active low
         sda_i   : in  std_logic;       -- i2c data line input
         sda_o   : out std_logic;       -- i2c data line output
         sda_oen : out std_logic        -- i2c data line output enable, active low
         );
   end component i2c_master_byte_ctrl;



end;

package body I2cPkg is

   function MakeI2cAxiLiteDevType (
      i2cAddress  : slv;
      dataSize    : integer;
      addrSize    : integer;
      endianness  : sl;
      repeatStart : sl := '0')
      return I2cAxiLiteDevType
   is
      variable ret : I2cAxiLiteDevType;
   begin
      if (i2cAddress'length = 7) then
         ret.i2cAddress := "000" & i2cAddress;
         ret.i2cTenbit  := '0';
      elsif (i2cAddress'length = 10) then
         ret.i2cAddress := i2cAddress;
         ret.i2cTenbit  := '1';
      else
         report "i2cAddress param must have length of 7 or 10" severity error;
      end if;

      ret.dataSize    := dataSize;
      ret.addrSize    := addrSize;
      ret.endianness  := endianness;
      ret.repeatStart := repeatStart;
      return ret;
   end function MakeI2cAxiLiteDevType;

   function maxAddrSize (constant devMap : I2cAxiLiteDevArray) return natural is
      variable ret : natural := 0;
   begin
      for i in devMap'range loop
         if (devMap(i).addrSize > ret) then
            ret := devMap(i).addrSize;
         end if;
      end loop;
      return ret;
   end function maxAddrSize;

end package body I2cPkg;
