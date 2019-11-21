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
-------------------------------------------------------------------------------
-- Entity:      i2cmst_gen
-- File:        i2cmst_gen.vhd
-- Author:      Jan Andersson - Aeroflex Gaisler
-- Contact:     support@gaisler.com
-- Description: Generic I2CMST, see i2cmst.vhd
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library grlib;
use grlib.amba.all;
use grlib.devices.all;
use grlib.stdlib.all;

library gaisler;
use gaisler.i2c.all;

entity i2cmst_gen is
  generic (
    oepol  : integer range 0 to 1 := 0;    -- output enable polarity
    filter  : integer range 2 to 512 := 2; -- filter bit size
    dynfilt : integer range 0 to 1 := 0);
  port (
    rstn        : in  std_ulogic;
    clk         : in  std_ulogic;
    -- APB signals
    psel        : in  std_ulogic;
    penable     : in  std_ulogic;
    paddr       : in  std_logic_vector(31 downto 0);
    pwrite      : in  std_ulogic;
    pwdata      : in  std_logic_vector(31 downto 0);
    prdata      : out std_logic_vector(31 downto 0);
    irq         : out std_logic;
    -- I2C signals
    --i2ci    : in  i2c_in_type;
    i2ci_scl    : in  std_ulogic;
    i2ci_sda    : in  std_ulogic;
    --i2co    : out i2c_out_type
    i2co_scl    : out std_ulogic;
    i2co_scloen : out std_ulogic;
    i2co_sda    : out std_ulogic;
    i2co_sdaoen : out std_ulogic;
    i2co_enable : out std_ulogic
    );
end entity i2cmst_gen;

architecture rtl of i2cmst_gen is

  -- APB signals
  signal apbi  : apb_slv_in_type;
  signal apbo  : apb_slv_out_type;

  -- I2C signals
  signal i2ci  : i2c_in_type;
  signal i2co  : i2c_out_type;
  
begin

  apbi.psel(0) <= psel;
  apbi.psel(1 to NAPBSLV-1) <= (others => '0');
  apbi.penable <= penable;
  apbi.paddr   <= paddr;
  apbi.pwrite  <= pwrite;
  apbi.pwdata  <= pwdata;
  apbi.pirq    <= (others => '0');
  apbi.testen  <= '0';
  apbi.testrst <= '0';
  apbi.scanen  <= '0';
  apbi.testoen <= '0';

  prdata       <= apbo.prdata;
  irq          <= apbo.pirq(0);

  i2ci.scl     <= i2ci_scl;
  i2ci.sda     <= i2ci_sda;

  i2co_scl     <= i2co.scl;
  i2co_scloen  <= i2co.scloen;
  i2co_sda     <= i2co.sda;
  i2co_sdaoen  <= i2co.sdaoen;
  i2co_enable  <= i2co.enable;
  
  i2c0 : i2cmst
    generic map (pindex => 0, paddr => 0, pmask => 0, pirq => 0,
                 oepol  => oepol, filter => filter, dynfilt => dynfilt)
    port map (rstn, clk, apbi, apbo, i2ci, i2co);
  
end architecture rtl;
