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
-- Entity:      i2c2ahb
-- File:        i2c2ahb.vhd
-- Author:      Jan Andersson - Aeroflex Gaisler AB
-- Contact:     support@gaisler.com
-- Description: Simple I2C-slave providing a bridge to AMBA AHB
--              See i2c2ahbx.vhd and GRIP for documentation
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library grlib;
use grlib.amba.all;
use grlib.stdlib.conv_std_logic_vector;

library gaisler;
use gaisler.i2c.all;



entity i2c2ahb is
 generic (
   -- AHB Configuration
   hindex     : integer := 0;
   --
   ahbaddrh   : integer := 0;
   ahbaddrl   : integer := 0;
   ahbmaskh   : integer := 0;
   ahbmaskl   : integer := 0;
   -- I2C configuration
   i2cslvaddr : integer range 0 to 127 := 0;
   i2ccfgaddr : integer range 0 to 127 := 0;
   oepol      : integer range 0 to 1 := 0;
   --
   filter     : integer range 2 to 512 := 2
   );
 port (
   rstn   : in  std_ulogic;
   clk    : in  std_ulogic;
   -- AHB master interface
   ahbi   : in  ahb_mst_in_type;
   ahbo   : out ahb_mst_out_type;
   -- I2C signals
   i2ci   : in  i2c_in_type;
   i2co   : out i2c_out_type
   );
end entity i2c2ahb;

architecture rtl of i2c2ahb is

  signal i2c2ahbi : i2c2ahb_in_type;

begin
  
  bridge : i2c2ahbx
    generic map (
      hindex   => hindex,
      oepol    => oepol,
      filter   => filter)
    port map (
      rstn     => rstn,
      clk      => clk,
      ahbi     => ahbi,
      ahbo     => ahbo,
      i2ci     => i2ci,
      i2co     => i2co,
      i2c2ahbi => i2c2ahbi,
      i2c2ahbo => open);
  
  i2c2ahbi.en <= '1';
  i2c2ahbi.haddr <= conv_std_logic_vector(ahbaddrh, 16) &
                    conv_std_logic_vector(ahbaddrl, 16);
  i2c2ahbi.hmask <= conv_std_logic_vector(ahbmaskh, 16) &
                    conv_std_logic_vector(ahbmaskl, 16);
  i2c2ahbi.slvaddr <= conv_std_logic_vector(i2cslvaddr, 7);
  i2c2ahbi.cfgaddr <= conv_std_logic_vector(i2ccfgaddr, 7);

  
end architecture rtl;
