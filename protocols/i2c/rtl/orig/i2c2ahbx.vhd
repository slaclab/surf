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
-- Entity:      i2c2ahbx
-- File:        i2c2ahbx.vhd
-- Author:      Jan Andersson - Aeroflex Gaisler AB
-- Contact:     support@gaisler.com
-- Description: Simple I2C-slave providing a bridge to AMBA AHB
--              This entity is typically wrapped with i2c2ahb or i2c2ahb_apb
--              before use.
-------------------------------------------------------------------------------
--
-- Short core documentation, for additional information see the GRLIB IP
-- Library User's Manual (GRIP):
--
-- The core functions as a I2C memory device. To write to the core, issue the
-- following I2C bus sequence:
--
-- 0. START condition
-- 1. Send core's I2C address with direction = write 
-- 2. Send 32-bit address to be used for AMBA bus
-- 3. Send data to be written
--
-- The core will expect 32-bits of data and write these as a word. This can be
-- changed by writing to the core's control register. See documentation further
-- down. When the core's internal FIFO is full, the core will use clock
-- stretching to stall the transfer.
--
-- To write to the core, issue the following I2C bus sequence:
--
-- 0. START condition
-- 1. Send core's I2C address with direction = write 
-- 2. Send 32-bit address to be used for AMBA bus
-- 3. Send repeated start condition
-- 4. Send core's I2C address with direction = read
-- 5. Read bytes
--
-- The core will perform 32-bit data accesses to fill its internal buffer. This
-- can be changed by writing to the core's control register (see documentation
-- further down). When the buffer is empty the core will use clock stretching
-- to stall the transfer.
--
-- The cores control/status register is accessed via address i2caddr + 1. The
-- register has the following layout:
--
-- +--------+-----------------------------------------------------------------+
-- | Bit(s) | Description                                                     |
-- +--------+-----------------------------------------------------------------+
-- |  7:6   | Reserved, always zero (RO)                                      |
-- |   5    | PROT: Memory protection triggered. Last access was outside      |
-- |        | range. Updated after each AMBA access (RO)                      |
-- |   4    | MEXC: Memory exception. Gets set if core receives AMBA ERROR    |
-- |        | response. Updated after each AMBA access. (RO)                  |
-- |   3    | DMAACT: Core is currently performing DMA (RO)                   |
-- |   2    | NACK: NACK instead of using clock stretching (RW)               |
-- |  1:0   | HSIZE: Controls the access size core will use for AMBA accesses |
-- |        | Default is HSIZE = WORD. HSIZE 11 is illegal (RW)               |
-- +--------+-----------------------------------------------------------------+
--
-- Documentation of generics:
--
-- [hindex]  AHB master index
--
-- [oepol]   Output enable polarity
--
-- [filter]  Length of filters used on SCL and SDA
--


library ieee;
use ieee.std_logic_1164.all;

library gaisler;
use gaisler.i2c.all;

library grlib;
use grlib.amba.all;
use grlib.devices.all;
use grlib.stdlib.all;

entity i2c2ahbx is
 generic (
   -- AHB configuration
   hindex   : integer := 0;
   oepol    : integer range 0 to 1 := 0;
   filter   : integer range 2 to 512 := 2
   );
 port (
   rstn     : in  std_ulogic;
   clk      : in  std_ulogic;
   -- AHB master interface
   ahbi     : in  ahb_mst_in_type;
   ahbo     : out ahb_mst_out_type;
   -- I2C signals
   i2ci     : in  i2c_in_type;
   i2co     : out i2c_out_type;
   --
   i2c2ahbi : in  i2c2ahb_in_type;
   i2c2ahbo : out i2c2ahb_out_type
   );
end entity i2c2ahbx;

architecture rtl of i2c2ahbx is
  -----------------------------------------------------------------------------
  -- Constants
  -----------------------------------------------------------------------------
  
  constant OEPOL_LEVEL : std_ulogic := conv_std_logic(oepol = 1);
 
  constant I2C_LOW   : std_ulogic := OEPOL_LEVEL;  -- OE
  constant I2C_HIZ   : std_ulogic := not OEPOL_LEVEL;

  constant I2C_ACK   : std_ulogic := '0';
  
  -----------------------------------------------------------------------------
  -- Types
  -----------------------------------------------------------------------------

  type i2c_in_array is array (filter downto 0) of i2c_in_type;

  type state_type is (idle, checkaddr, sclhold, movebyte, handshake);
  
  type i2c2ahb_reg_type is record
    state    : state_type;
    --
    haddr    : std_logic_vector(31 downto 0);
    hdata    : std_logic_vector(31 downto 0);
    hsize    : std_logic_vector(1 downto 0);
    hwrite   : std_ulogic;
    mexc     : std_ulogic;
    dodma    : std_ulogic;
    nack     : std_ulogic;
    prot     : std_ulogic;
    -- Transfer phase
    i2caddr  : std_ulogic;
    ahbacc   : std_ulogic;
    ahbadd   : std_ulogic;
    rec      : std_ulogic;
    bcnt     : std_logic_vector(1 downto 0);
    -- Shift register
    sreg     : std_logic_vector(7 downto 0);
    cnt      : std_logic_vector(2 downto 0);
    -- Synchronizers for inputs SCL and SDA
    scl      : std_ulogic;
    sda      : std_ulogic;
    i2ci     : i2c_in_array;
    -- Output enables
    scloen   : std_ulogic;
    sdaoen   : std_ulogic;
  end record;  
  
  -----------------------------------------------------------------------------
  -- Signals
  -----------------------------------------------------------------------------

  signal ami : ahb_dma_in_type;
  signal amo : ahb_dma_out_type;
  
  signal r, rin : i2c2ahb_reg_type;

begin

  -- Generic AHB master interface
  ahbmst0 : ahbmst
    generic map (hindex => hindex, hirq => 0, venid => VENDOR_GAISLER,
                 devid => GAISLER_I2C2AHB, version => 0,
                 chprot => 3, incaddr => 0)
    port map (rstn, clk, ami, amo, ahbi, ahbo);
  
  comb: process (r, rstn, i2ci, amo, i2c2ahbi)
    variable v         : i2c2ahb_reg_type;
    variable sclfilt   : std_logic_vector(filter-1 downto 0);
    variable sdafilt   : std_logic_vector(filter-1 downto 0);
    variable hrdata    : std_logic_vector(31 downto 0);
    variable ahbreq    : std_ulogic;
    variable slv       : std_ulogic;
    variable cfg       : std_ulogic;
    variable lb        : std_ulogic;
  begin
    v := r; ahbreq := '0'; slv := '0'; cfg := '0'; lb := '0';
    hrdata := (others => '0');
    v.i2ci(0) := i2ci; v.i2ci(filter downto 1) := r.i2ci(filter-1 downto 0);      

    ----------------------------------------------------------------------------
    -- Bus filtering
    ----------------------------------------------------------------------------
    for i in 0 to filter-1 loop 
      sclfilt(i) := r.i2ci(i+1).scl; sdafilt(i) := r.i2ci(i+1).sda;
    end loop;  -- i
    if andv(sclfilt) = '1' then v.scl := '1'; end if;
    if orv(sclfilt) = '0' then v.scl := '0'; end if;
    if andv(sdafilt) = '1' then v.sda := '1'; end if;
    if orv(sdafilt) = '0' then v.sda := '0'; end if;

    ---------------------------------------------------------------------------
    -- DMA control
    ---------------------------------------------------------------------------
    if r.dodma = '1' then
      if amo.active = '1' then
        if amo.ready = '1' then
          hrdata := ahbreadword(amo.rdata);
          case r.hsize is
            when "00" =>
              v.haddr := r.haddr + 1;
              for i in 1 to 3 loop
                if i = conv_integer(r.haddr(1 downto 0)) then
                  hrdata(31 downto 24) := hrdata(31-8*i downto 24-8*i);
                end if;
              end loop;
            when "01" =>
              v.haddr := r.haddr + 2;
              if r.haddr(1) = '1' then
                hrdata(31 downto 16) := hrdata(15 downto 0);
              end if;
            when others =>
              v.haddr := r.haddr + 4;
          end case;
          v.sreg := hrdata(31 downto 24);
          v.hdata(31 downto 8) := hrdata(23 downto 0);
          v.mexc := '0';
          v.dodma := '0';
        end if;
        if amo.mexc = '1' then
          v.mexc := '1';
          v.dodma := '0';
        end if;
      else
        ahbreq := '1';
      end if;
    end if;
    
    ---------------------------------------------------------------------------
    -- I2C slave control FSM
    ---------------------------------------------------------------------------
    case r.state is
      when idle =>
        -- Release bus
        if (r.scl and not v.scl) = '1' then
          v.sdaoen := I2C_HIZ;
        end if;
     
      when checkaddr =>
        if r.sreg(7 downto 1) = i2c2ahbi.slvaddr then slv := '1'; end if;
        if r.sreg(7 downto 1) = i2c2ahbi.cfgaddr then cfg := '1'; end if;
        v.rec := not r.sreg(0);
        
        if (slv or cfg) = '1' then 
          if (slv and r.dodma) = '1' then
            -- Core is busy performing DMA
            if r.nack = '1' then v.state := idle;
            else v.state := sclhold; end if;
          else
            v.state := handshake;
          end if;
        else
          -- Slave address did not match
          v.state := idle;
        end if;
        v.hwrite := v.rec;
        if (slv and not r.dodma) = '1' then v.dodma := not v.rec; end if;
        v.ahbacc := slv; v.bcnt := "00"; v.ahbadd := '0';
        
      when sclhold =>
        -- This state is used when the device has been addressed to see if SCL
        -- should be kept low until the core is ready to process another
        -- transfer. It is also used when a data byte has been transmitted or
        -- received to keep SCL low until a DMA operation has completed.
        -- In the transmit case we keep SCL low before the rising edge of the
        -- first byte, so we go directly to move byte. In the receive case we
        -- stretch the ACK cycle so we jump to handshake next.
        if (r.scl and not v.scl) = '1' then
          v.scloen := I2C_LOW;
          v.sdaoen := I2C_HIZ;
        end if;
        if r.dodma = '0' then
          if (not r.rec and not r.i2caddr) = '1' then
            v.state := movebyte;
          else
            v.state := handshake;
          end if;
          v.scloen := I2C_HIZ;
          -- Falling edge that should be detected in movebyte may have passed
          if (r.i2caddr or r.rec or v.scl) = '0' then
            v.sdaoen := r.sreg(7) xor OEPOL_LEVEL;
          end if;
        end if;

      when movebyte =>
        if (r.scl and not v.scl) = '1' then
          if (r.i2caddr or r.rec) = '0' then
            v.sdaoen := r.sreg(7) xor OEPOL_LEVEL;
          else
            v.sdaoen := I2C_HIZ;
          end if;
        end if;
        if (not r.scl and v.scl) = '1' then
          v.sreg := r.sreg(6 downto 0) & r.sda;
          if r.cnt = "111" then
            if r.i2caddr = '1' then
              v.state := checkaddr;
            else
              v.state := handshake;
            end if;
            v.cnt := (others => '0');
          else
            v.cnt := r.cnt + 1;
          end if;
        end if;
      
      when handshake =>
        if ((r.hsize = "00") or ((r.hsize(0) and r.bcnt(0)) = '1') or
            (r.bcnt = "11")) then
          lb := '1';
        end if;
        -- Falling edge
        if (r.scl and not v.scl) = '1' then
          if (r.i2caddr or not r.ahbacc) = '1' then
            -- Also handles first byte on AHB read access
            if (r.rec or r.i2caddr) = '1' then
              v.sdaoen := I2C_LOW;
            else
              v.sdaoen := I2C_HIZ;
            end if;
            if (not r.i2caddr and r.rec) = '1' then
              -- Control register access
              v.nack := r.sreg(2);
              v.hsize := r.sreg(1 downto 0);
            end if;
          else
            -- AHB access
            if r.rec = '1' then  
              -- First we need a 4 byte address, then we handle data.
              v.bcnt := r.bcnt + 1;
              if r.ahbadd = '0' then
                -- We could check if the address is within the allowed memory
                -- area here, and nack otherwise, but we do it when the access
                -- is performed instead, to have one check for all cases.
                v.haddr := r.haddr(23 downto 0) & r.sreg;
                if r.bcnt = "11" then v.ahbadd := '1'; end if;
                v.sdaoen := I2C_LOW;
              elsif r.dodma = '0'  then
                if r.bcnt = "00" then v.hdata(31 downto 24) := r.sreg; end if;
                if r.bcnt(1) = '0' then v.hdata(23 downto 16) := r.sreg; end if;
                if r.bcnt(0) = '0' then v.hdata(15 downto 8) := r.sreg; end if;
                v.hdata(7 downto 0) := r.sreg;
                if lb = '1' then v.dodma := '1'; v.bcnt := "00"; end if;
                v.sdaoen := I2C_LOW;
              end if;
            else
              -- Transmit, release bus
              v.sdaoen := I2C_HIZ;
            end if;
          end if;
          -- Previous DMA is not finished yet
          if (r.dodma and r.ahbacc) = '1' then
            if r.nack = '0' then
              -- Hold clock low and handle data when DMA is finished
              v.state := sclhold;
              v.scloen := I2C_LOW;
            else
              -- NAK byte
              v.sdaoen := I2C_HIZ;
              v.state := idle;
            end if;
          end if;
        end if;
        -- Risinge edge
        if (not r.scl and v.scl) = '1' then
          if (r.i2caddr or not r.ahbacc) = '1' then
            if r.sda = I2C_ACK then
              v.state := movebyte;
            else
              v.state := idle;
            end if;
          else
            if r.rec = '1' then
              v.state := movebyte;
            else
              -- Transmit, check ACK/NAK from master
              -- If the master NAKs the transmitted byte the transfer has ended
              -- and we should wait for the master's next action. If the master
              -- ACKs the byte the core we will continue to transmit data until
              -- we reach the last available byte. When the last byte has been
              -- transmitted we will act depending on if we are allowed to enter
              -- sclhold. If we can, we enter sclhold and start a new DMA
              -- operation, otherwise we stop communicating until the next start
              -- condition.
              v.bcnt := r.bcnt + 1;
              if r.sda = I2C_ACK then
                if lb = '1' then
                  if r.nack = '1' then
                    v.state := idle;
                  else
                    v.dodma := '1'; v.bcnt := "00";
                    v.state := sclhold;
                   end if;
                else
                  v.state := movebyte;
                end if;
              else
                v.state := idle;
              end if;
              v.hdata(31 downto 8) := r.hdata(23 downto 0);
              v.sreg := r.hdata(31 downto 24);
            end if;
          end if;
          v.i2caddr := '0';
          if r.ahbacc = '0' then
            -- Control register access
            v.sreg := zero32(7 downto 6) & r.prot & r.mexc &
                      r.dodma & r.nack & r.hsize;
          end if;
        end if;
    end case;

    if i2c2ahbi.hmask /= zero32 then
      if v.dodma = '1' then
        if ((i2c2ahbi.haddr xor r.haddr) and i2c2ahbi.hmask) /= zero32 then
          v.dodma := '0';
          v.prot := '1';
          v.state := idle;
        else
          v.prot := '0';
        end if;
      end if;
    else
      v.prot := '0';
    end if;
    
    if i2c2ahbi.en = '1' then
      -- STOP condition
      if (r.scl and v.scl and not r.sda and v.sda) = '1' then
        v.state := idle;
      end if;

      -- START or repeated START condition
      if (r.scl and v.scl and r.sda and not v.sda) = '1' then
        v.state := movebyte;
        v.cnt := (others => '0');
        v.i2caddr := '1';
      end if;
    end if;
   
   ----------------------------------------------------------------------------
   -- Reset
   ----------------------------------------------------------------------------

    if rstn = '0' then
      v.state  := idle;
      v.hsize  := HSIZE_WORD(1 downto 0);
      v.mexc   := '0';
      v.dodma  := '0';
      v.nack   := '0';
      v.prot   := '0';
      v.scl    := '0';
      v.scloen := I2C_HIZ; v.sdaoen := I2C_HIZ;
    end if;

    if i2c2ahbi.hmask = zero32 then v.prot := '0'; end if;
    
    ----------------------------------------------------------------------------
    -- Signal assignments
    ----------------------------------------------------------------------------
   
    -- Core registers
    rin <= v;
    
    -- AHB master control
    ami.address   <= r.haddr;
    ami.wdata     <= ahbdrivedata(r.hdata);
    ami.start     <= ahbreq;
    ami.burst     <= '0';
    ami.write     <= r.hwrite;
    ami.busy      <= '0';
    ami.irq       <= '0';
    ami.size      <= '0' & r.hsize;
    
    -- Update outputs
    i2c2ahbo.dma  <= r.dodma;
    i2c2ahbo.wr   <= r.hwrite;
    i2c2ahbo.prot <= r.prot;
    
    i2co.scl      <= '0';
    i2co.scloen   <= r.scloen;
    i2co.sda      <= '0';
    i2co.sdaoen   <= r.sdaoen;
    i2co.enable   <= i2c2ahbi.en;
  end process comb;

  reg: process (clk)
  begin
    if rising_edge(clk) then r <= rin; end if;
  end process reg;

 -- Boot message
 -- pragma translate_off
 bootmsg : report_version
   generic map ("i2c2ahb" & tost(hindex) & ": I2C to AHB bridge");
 -- pragma translate_on

end architecture rtl;

