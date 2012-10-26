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
--library grlib;
--use grlib.amba.all;

package i2cPkg is

  type i2c_in_type is record
    scl : std_ulogic;
    sda : std_ulogic;
  end record;

  type i2c_out_type is record
    scl    : std_ulogic;
    scloen : std_ulogic;
    sda    : std_ulogic;
    sdaoen : std_ulogic;
    enable : std_ulogic;
  end record;

  type i2cMasterInType is record
    enable   : sl;                      -- Enable the master
    prescale : slv(15 downto 0);        -- Determines i2c clock speed
    filter   : slv(15 downto 0);        -- Dynamic filter value
    txnReq   : sl;                      -- Execute a transaction
    stop     : sl;                      -- Set STOP when done
    op       : sl;                      -- 1 for write, 0 for read
    addr     : slv(9 downto 0);         -- i2c device address
    tenbit   : sl;                      -- use 10 bit addressing
    txnSize  : slv(1 downto 0);         -- Support up to 4 bytes / txn
    wrData   : slv(31 downto 0);        -- Data sent during write txn
  end record i2cMasterInType;

  type i2cMasterOutType is record
    txnDone  : sl;                      -- Asserted when tranaction is complete or errors out
    txnError : sl;                      -- An error occured during the txn
    rdData   : slv(31 downto 0);        -- Data received during read txn
  end record i2cMasterOutType;

  -- Opencores i2c
  component i2c_master_byte_ctrl is
    generic (filter : integer; dynfilt : integer);
    port (
      clk    : in std_logic;
      rst    : in std_logic;            -- active high reset
      nReset : in std_logic;            -- asynchornous active low reset
      -- (not used in GRLIB)
      ena    : in std_logic;            -- core enable signal

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
      scl_i   : in  std_logic;          -- i2c clock line input
      scl_o   : out std_logic;          -- i2c clock line output
      scl_oen : out std_logic;          -- i2c clock line output enable, active low
      sda_i   : in  std_logic;          -- i2c data line input
      sda_o   : out std_logic;          -- i2c data line output
      sda_oen : out std_logic           -- i2c data line output enable, active low
      );
  end component i2c_master_byte_ctrl;



end;
