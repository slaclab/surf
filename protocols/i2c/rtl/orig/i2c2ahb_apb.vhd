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
-- Entity:      i2c2ahb_apb
-- File:        i2c2ahb_apb.vhd
-- Author:      Jan Andersson - Aeroflex Gaisler AB
-- Contact:     support@gaisler.com
-- Description: Simple I2C-slave providing a bridge to AMBA AHB
--              This entity provides an APB interface for setting defining the
--              AHB address window that can be accessed from I2C.
--              See i2c2ahbx.vhd and GRIP for documentation
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library gaisler;
use gaisler.i2c.all;

library grlib;
use grlib.amba.all;
use grlib.devices.all;
use grlib.stdlib.conv_std_logic;
use grlib.stdlib.conv_std_logic_vector;

entity i2c2ahb_apb is
 generic (
   -- AHB Configuration
   hindex     : integer := 0;
   --
   ahbaddrh   : integer := 0;
   ahbaddrl   : integer := 0;
   ahbmaskh   : integer := 0;
   ahbmaskl   : integer := 0;
   resen      : integer := 0;
   -- APB configuration
   pindex     : integer := 0;         -- slave bus index
   paddr      : integer := 0;
   pmask      : integer := 16#fff#;
   pirq       : integer := 0;
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
   --
   apbi   : in  apb_slv_in_type;
   apbo   : out apb_slv_out_type;
   -- I2C signals
   i2ci   : in  i2c_in_type;
   i2co   : out i2c_out_type
   );
end entity i2c2ahb_apb;

architecture rtl of i2c2ahb_apb is

  -- Register offsets
  constant CTRL_OFF : std_logic_vector(4 downto 2) := "000";
  constant STS_OFF  : std_logic_vector(4 downto 2) := "001";
  constant ADDR_OFF : std_logic_vector(4 downto 2) := "010";
  constant MASK_OFF : std_logic_vector(4 downto 2) := "011";
  constant SLVA_OFF : std_logic_vector(4 downto 2) := "100";
  constant SLVC_OFF : std_logic_vector(4 downto 2) := "101";
  
  -- AMBA PnP
  constant PCONFIG : apb_config_type := (
    0 => ahb_device_reg(VENDOR_GAISLER, GAISLER_I2C2AHB, 0, 0, 0),
    1 => apb_iobar(paddr, pmask));


  type apb_reg_type is record
    i2c2ahbi : i2c2ahb_in_type;
    irq      : std_ulogic;
    irqen    : std_ulogic;
    prot     : std_ulogic;
    protx    : std_ulogic;
    wr       : std_ulogic;
    dma      : std_ulogic;
    dmax     : std_ulogic;
  end record;
  
  signal r, rin   : apb_reg_type;
  signal i2c2ahbo : i2c2ahb_out_type;
  
begin

  bridge : i2c2ahbx
    generic map (hindex => hindex, oepol => oepol, filter => filter)
    port map (rstn => rstn, clk => clk, ahbi => ahbi, ahbo => ahbo,
              i2ci => i2ci, i2co => i2co, i2c2ahbi => r.i2c2ahbi,
              i2c2ahbo => i2c2ahbo);
    
  comb: process (r, rstn, apbi, i2c2ahbo)
    variable v         : apb_reg_type;
    variable apbaddr   : std_logic_vector(4 downto 2);
    variable apbout    : std_logic_vector(31 downto 0);
    variable irqout    : std_logic_vector(NAHBIRQ-1 downto 0);
  begin
    v := r; apbaddr := apbi.paddr(apbaddr'range); apbout := (others => '0');
    v.irq := '0'; irqout := (others => '0'); irqout(pirq) := r.irq;
    v.protx := i2c2ahbo.prot; v.dmax := i2c2ahbo.dma;
    
    ---------------------------------------------------------------------------
    -- APB register interface
    ---------------------------------------------------------------------------
    -- read registers
    if (apbi.psel(pindex) and apbi.penable and (not apbi.pwrite)) = '1' then
      case apbaddr is
        when CTRL_OFF => apbout(1 downto 0) := r.irqen & r.i2c2ahbi.en;
        when STS_OFF  => apbout(2 downto 0) := r.prot & r.wr & r.dma;
        when ADDR_OFF => apbout := r.i2c2ahbi.haddr;
        when MASK_OFF => apbout := r.i2c2ahbi.hmask;
        when SLVA_OFF => apbout(6 downto 0) := r.i2c2ahbi.slvaddr;
        when SLVC_OFF => apbout(6 downto 0) := r.i2c2ahbi.cfgaddr;
        when others => null;
      end case;
    end if;
   
    -- write registers
    if (apbi.psel(pindex) and apbi.penable and apbi.pwrite) = '1' then
      case apbaddr is
        when CTRL_OFF => v.irqen := apbi.pwdata(1); v.i2c2ahbi.en := apbi.pwdata(0);
        when STS_OFF  => v.dma := r.dma and not apbi.pwdata(0);
                         v.prot := r.prot and not apbi.pwdata(2);
        when ADDR_OFF => v.i2c2ahbi.haddr := apbi.pwdata;
        when MASK_OFF => v.i2c2ahbi.hmask := apbi.pwdata;
        when SLVA_OFF => v.i2c2ahbi.slvaddr := apbi.pwdata(6 downto 0);
        when SLVC_OFF => v.i2c2ahbi.cfgaddr := apbi.pwdata(6 downto 0);
        when others => null;
      end case;
    end if;

    -- interrupt and status register handling
    if ((i2c2ahbo.dma and not r.dmax) or
        (i2c2ahbo.prot and not r.protx)) = '1' then
      v.dma := '1'; v.prot := r.prot or i2c2ahbo.prot; v.wr := i2c2ahbo.wr;
      if (r.irqen and not r.dma) = '1' then v.irq := '1'; end if;
    end if;
    
    ---------------------------------------------------------------------------
    -- reset
    ---------------------------------------------------------------------------
    if rstn = '0' then
      v.i2c2ahbi.en := conv_std_logic(resen = 1);
      v.i2c2ahbi.haddr := conv_std_logic_vector(ahbaddrh, 16) &
                          conv_std_logic_vector(ahbaddrl, 16);
      v.i2c2ahbi.hmask := conv_std_logic_vector(ahbmaskh, 16) &
                          conv_std_logic_vector(ahbmaskl, 16);
      v.i2c2ahbi.slvaddr := conv_std_logic_vector(i2cslvaddr, 7);
      v.i2c2ahbi.cfgaddr := conv_std_logic_vector(i2ccfgaddr, 7);
      v.irqen := '0'; v.prot := '0'; v.wr := '0'; v.dma := '0';
    end if;

    ---------------------------------------------------------------------------
    -- signal assignments
    ---------------------------------------------------------------------------
    -- update registers
    rin <= v;

    -- update outputs
    apbo.prdata  <= apbout;
    apbo.pirq    <= irqout;
    apbo.pconfig <= PCONFIG;
    apbo.pindex  <= pindex;

  end process comb;

  reg: process(clk)
  begin
    if rising_edge(clk) then r <= rin; end if;
  end process reg;

  -- Boot message provided in i2c2ahbx...
  
end architecture rtl;
