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
-- Entity:      i2cmst
-- File:        i2cmst.vhd
-- Author:      Jan Andersson - Gaisler Research
-- Contact:     support@gaisler.com
-- Description:
--
--         APB interface to OpenCores I2C-master. This is an GRLIB AMBA wrapper
--         that instantiates the byte- and bit-controller of the OpenCores I2C
--         master (OC core developed by Richard Herveille, richard@asics.ws). 
--         The OC byte- and bit-controller are located under lib/opencores/i2c
--
--         The original master had a WISHBONE interface with registers
--         aligned at byte boundaries. This wrapper has a slighly different
--         alignment of the registers, and also (optionally) adds a filter
--         filter register (FR):
--
--         +------------+--------------------------------------+
--         |  Offset    |            Bits in word              |
--         |            |---------+---------+---------+--------+
--         |            | 31 - 24 | 23 - 16 | 15 - 8  | 7 - 0  |
--         +------------+---------+---------+---------+--------+
--         |   0x00     |  0x00   |   0x00  | PRERhi  | PRERlo |
--         |   0x04     |  0x00   |   0x00  |  0x00   |  CTR   |
--         |   0x08     |  0x00   |   0x00  |  0x00   |  TXR   |
--         |   0x08     |  0x00   |   0x00  |  0x00   |  RXR   |
--         |   0x0C     |  0x00   |   0x00  |  0x00   |  CR    |
--         |   0x0C     |  0x00   |   0x00  |  0x00   |  SR    |
--         |   0x10     |                   FR                 |
--         +------------+---------+---------+---------+--------+
--
-- Revision 1 of this core also sets the TIP bit when STO is set.
--
-- Revision 2 of this core adds a filter generic to adjust the low pass filter
--
-- Revision 3 of this core adds yet another filter generic that can be set to
--            make the filter soft configurable.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library grlib;
use grlib.amba.all;
use grlib.devices.all;
use grlib.stdlib.all;

library gaisler;
use gaisler.i2c.all;

library opencores;
use opencores.i2coc.all;

entity i2cmst is
  generic (
    -- APB generics
    pindex  : integer := 0;                -- slave bus index
    paddr   : integer := 0;
    pmask   : integer := 16#fff#;
    pirq    : integer := 0;                -- interrupt index
    oepol   : integer range 0 to 1 := 0;   -- output enable polarity
    filter  : integer range 2 to 512 := 2; -- filter bit size
    dynfilt : integer range 0 to 1 := 0);
  port (
    rstn  : in std_ulogic;
    clk   : in std_ulogic;
    
    -- APB signals
    apbi  : in  apb_slv_in_type;
    apbo  : out apb_slv_out_type;

    -- I2C signals
    i2ci  : in  i2c_in_type;
    i2co  : out i2c_out_type
    );
end entity i2cmst;

architecture rtl of i2cmst is
  -----------------------------------------------------------------------------
  -- Constants
  -----------------------------------------------------------------------------

  constant I2CMST_REV : integer := 3;
  
  constant PCONFIG : apb_config_type := (
  0 => ahb_device_reg(VENDOR_GAISLER, GAISLER_I2CMST, 0, I2CMST_REV, pirq),
  1 => apb_iobar(paddr, pmask));

  constant PRER_addr : std_logic_vector(7 downto 2) := "000000";
  constant CTR_addr  : std_logic_vector(7 downto 2) := "000001";
  constant TXR_addr  : std_logic_vector(7 downto 2) := "000010";
  constant RXR_addr  : std_logic_vector(7 downto 2) := "000010";
  constant CR_addr   : std_logic_vector(7 downto 2) := "000011";
  constant SR_addr   : std_logic_vector(7 downto 2) := "000011";
  constant FR_addr   : std_logic_vector(7 downto 2) := "000100";

  -----------------------------------------------------------------------------
  -- 
  -----------------------------------------------------------------------------
  
  -----------------------------------------------------------------------------
  -- Types 
  -----------------------------------------------------------------------------
  -- Register interface
  type ctrl_reg_type is record          -- Control register
      en  : std_ulogic;
      ien : std_ulogic;
  end record;

  type cmd_reg_type is record           -- Command register
      sta : std_ulogic;
      sto : std_ulogic;
      rd  : std_ulogic;
      wr  : std_ulogic;
      ack : std_ulogic;
  end record;

  type sts_reg_type is record           -- Status register
      rxack : std_ulogic;
      busy  : std_ulogic;
      al    : std_ulogic;
      tip   : std_ulogic;
      ifl   : std_ulogic;     
  end record;
  
  -- Core registers
  type i2c_reg_type is record
       -- i2c registers
       prer : std_logic_vector(15 downto 0);     -- clock prescale register
       ctrl : ctrl_reg_type;                     -- control register
       txr  : std_logic_vector(7 downto 0);      -- transmit register
       cmd  : cmd_reg_type;                      -- command register
       sts  : sts_reg_type;                      -- status register
       filt : std_logic_vector((filter-1)*dynfilt downto 0); -- filter register
       --
       irq  : std_ulogic;
 end record;

  -- Signals to and from byte controller block
  signal rxr       : std_logic_vector(7 downto 0); -- Receive register
  signal done      : std_logic;         -- Signals completion of command
  signal rxack     : std_logic;         -- Received acknowledge
  signal busy      : std_logic;         -- I2C core busy
  signal al        : std_logic;         -- Aribitration lost
  signal irst      : std_ulogic;        -- Internal, negated reset signal
  signal iscloen   : std_ulogic;        -- Internal SCL output enable
  signal isdaoen   : std_ulogic;        -- Internal SDA output enable
  
  -- Register interface
  signal r, rin : i2c_reg_type;
  signal vcc : std_logic;
begin
  -- Byte Controller from OpenCores I2C master,
  -- by Richard Herveille (richard@asics.ws). The asynchronous
  -- reset is tied to '1'. Only the synchronous reset is used.
  vcc <= '1';
  byte_ctrl: i2c_master_byte_ctrl
    generic map (
      filter   => filter,
      dynfilt  => dynfilt)
    port map (
      clk      => clk,
      rst      => irst,
      nReset   => vcc,
      ena      => r.ctrl.en,
      clk_cnt  => r.prer,
      start    => r.cmd.sta,
      stop     => r.cmd.sto,
      read     => r.cmd.rd,
      write    => r.cmd.wr,
      ack_in   => r.cmd.ack,
      din      => r.txr,
      filt     => r.filt,
      cmd_ack  => done,
      ack_out  => rxack,
      i2c_busy => busy,
      i2c_al   => al,
      dout     => rxr,
      scl_i    => i2ci.scl,
      scl_o    => i2co.scl,
      scl_oen  => iscloen,
      sda_i    => i2ci.sda,
      sda_o    => i2co.sda,
      sda_oen  => isdaoen);

  -- OC I2C logic has active high reset.
  irst <= not rstn;

  i2co.enable <= r.ctrl.en;
  
  -- Fix output enable polarity
  soepol0: if oepol = 0 generate
    i2co.scloen <= iscloen; 
    i2co.sdaoen <= isdaoen;
  end generate soepol0;
  soepol1: if oepol /= 0 generate
    i2co.scloen <= not iscloen;
    i2co.sdaoen <= not isdaoen;
  end generate soepol1;
  
  comb: process (r, rstn, rxr, rxack, busy, al, done, apbi)
    variable v : i2c_reg_type;
    variable irq : std_logic_vector((NAHBIRQ-1) downto 0);
    variable apbaddr : std_logic_vector(7 downto 2);
    variable apbout : std_logic_vector(31 downto 0);
  begin  -- process comb
    v := r;  v.irq := '0'; irq := (others=>'0'); irq(pirq) := r.irq;
    apbaddr := apbi.paddr(7 downto 2); apbout := (others => '0');
    
    -- Command done or arbitration lost, clear command register
    if (done or al) = '1' then
      v.cmd := ('0', '0', '0', '0', '0');
    end if;

    -- Update status register
    v.sts := (rxack => rxack,
              busy  => busy,
              al    => al or (r.sts.al and not r.cmd.sta),
              tip   => r.cmd.rd or r.cmd.wr or r.cmd.sto,
              ifl   => done or al or r.sts.ifl);
    v.irq := (done or al) and r.ctrl.ien;
   
    -- read registers
    if (apbi.psel(pindex) and apbi.penable and (not apbi.pwrite)) = '1' then
      case apbaddr is
        when PRER_addr =>
          apbout(15 downto 0) := r.prer;
        when CTR_addr  =>
          apbout(7 downto 6) := r.ctrl.en & r.ctrl.ien;
        when RXR_addr  =>
          apbout(7 downto 0) := rxr;
        when SR_addr   =>
          apbout(7 downto 5) := r.sts.rxack & r.sts.busy & r.sts.al;
          apbout(1 downto 0) := r.sts.tip & r.sts.ifl;
        when FR_addr =>
          if dynfilt /= 0 then apbout(r.filt'range) := r.filt; end if;
        when others => null;
      end case;
    end if;

    -- write registers
    if (apbi.psel(pindex) and apbi.penable and apbi.pwrite) = '1' then
      case apbaddr is
        when PRER_addr => v.prer := apbi.pwdata(15 downto 0);
        when CTR_addr  => v.ctrl.en := apbi.pwdata(7);
                          v.ctrl.ien := apbi.pwdata(6);
        when TXR_addr  => v.txr  := apbi.pwdata(7 downto 0);
        when CR_addr   =>
          -- Check that core is enabled and that WR and RD has been cleared
          -- before accepting new command.
          if (r.ctrl.en and not (r.cmd.wr or r.cmd.rd)) = '1' then
            v.cmd.sta := apbi.pwdata(7);
            v.cmd.sto := apbi.pwdata(6);
            v.cmd.rd  := apbi.pwdata(5);
            v.cmd.wr  := apbi.pwdata(4);
            v.cmd.ack := apbi.pwdata(3);
          end if;
          -- Bit 0 of CR is interrupt acknowledge. The core will only pulse one
          -- interrupt per irq event. Software does not have to clear the
          -- interrupt flag... 
          if apbi.pwdata(0) = '1' then
            v.sts.ifl := '0';
          end if;
        when FR_addr =>
          if dynfilt /= 0 then v.filt := apbi.pwdata(r.filt'range); end if;
        when others => null;
      end case;
    end if;
    
    if rstn = '0' then
      v.prer := (others => '1');
      v.ctrl := ('0', '0');
      v.txr  := (others => '0');
      v.cmd  := ('0','0','0','0', '0');
      v.sts   := ('0','0','0','0', '0');
      if dynfilt /= 0 then v.filt := (others => '1'); end if;
    end if;

    if dynfilt = 0 then v.filt := (others => '0'); end if;
    
    -- Update registers
    rin <= v;

    -- Update outputs
    apbo.prdata <= apbout;
    apbo.pirq <= irq;
    apbo.pconfig <= PCONFIG;
    apbo.pindex <= pindex;
    
  end process comb;

  reg: process (clk)
  begin  -- process reg
    if rising_edge(clk) then
      r <= rin;
    end if;
  end process reg;

  -- Boot message
  -- pragma translate_off
  bootmsg : report_version 
    generic map (
      "i2cmst" & tost(pindex) & ": AMBA Wrapper for OC I2C-master rev " &
      tost(I2CMST_REV) & ", irq " & tost(pirq));
  -- pragma translate_on
  
end architecture rtl;
