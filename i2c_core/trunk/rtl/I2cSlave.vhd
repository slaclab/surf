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
-- Entity: i2cslv
-- File:   i2cslv.vhd
-- Author: Jan Andersson - Gaisler Research
--         jan@gaisler.com
--
-- Documentation of generics:
--
-- [TENBIT_G]
-- Support for ten bit addresses.
--
-- [I2C_ADDR_G]
-- The slave's i2c address.
--
-- [OUTPUT_EN_POLARITY_G]
-- Output enable polarity
--
-- [FILTER_G]
-- Length of filters used on SCL and SDA.
-- This generic should specify, in number of system clock cycles plus one,
-- the time of the shortest pulse on the I2C bus to be registered as a valid
-- value. For instance, to disregard any pulse that is 50 ns or shorter in
-- a system with a system frequency of 54 MHz this generic should be set to:
-- ((pulse time) / (clock period)) + 1 =  (50 ns) / ((1/(54 MHz)) + 1 = 3.7
-- The value from this calculation should always be rounded up.
-- In other words an appropriate filter length for a 54 MHz system is 4.
--
-- The slave has four different modes operation. The mode is defined by the
-- value of the bits RMODE and TMODE.
-- RMODE TMODE   I2CSLAVE Mode
--   0     0          0
--   0     1          1
--   1     0          2
--   1     1          3
--
-- RMODE_G 0:
-- The slave accepts one byte and NAKs all other transfers until software has
-- acknowledged the received byte.
-- RMODE_G 1:
-- The slave accepts one byte and keeps SCL low until software has acknowledged
-- the received byte
-- TMODE_G 0:
-- The slave transmits the same byte to all if the master requests more than
-- one byte in the transfer. The slave then NAKs all read requests unless the
-- Transmit Always Valid (TAV) bit in the control register is set.
-- TMODE_G 1:
-- The slave transmits one byte and then keeps SCL low until software has
-- acknowledged that the byte has been transmitted.
----------------------------------------------------------------------------------------------------
-- Modified by Benjamin Reese <bareese@slac.stanford.edu>
-- Removed APB interface and replaced with generic IO.


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.StdRtlPkg.all;
use work.I2cPkg.all;
use work.stdlib.all;


entity I2cSlave is
   generic (
      TPD_G                : time                    := 1 ns;
      -- I2C configuration
      TENBIT_G             : integer range 0 to 1    := 0;
      I2C_ADDR_G           : integer range 0 to 1023 := 0;
      OUTPUT_EN_POLARITY_G : integer range 0 to 1    := 0;
      FILTER_G             : integer range 2 to 512  := 4;
      RMODE_G              : integer range 0 to 1    := 0;
      TMODE_G              : integer range 0 to 1    := 0
      );
   port (
      sRst        : in  std_ulogic := '0';  -- Synchronous Reset - active high
      aRst        : in  std_ulogic := '0';  -- Asynchronous Reset - active high
      clk         : in  std_ulogic;
      -- Front End
      i2cSlaveIn  : in  I2cSlaveInType;
      i2cSlaveOut : out I2cSlaveOutType;
      -- I2C signals
      i2ci        : in  i2c_in_type;
      i2co        : out i2c_out_type
      );
end entity I2cSlave;

architecture rtl of I2cSlave is
   -----------------------------------------------------------------------------
   -- Constants
   -----------------------------------------------------------------------------
   -- Core configuration
   constant I2C_ADDR_LEN_C   : integer := 7 + TENBIT_G*3;
   constant I2C_SLAVE_ADDR_C : std_logic_vector((I2C_ADDR_LEN_C-1) downto 0) :=
      conv_std_logic_vector(I2C_ADDR_G, I2C_ADDR_LEN_C);

   -- Misc constants
   constant I2C_READ_C  : std_ulogic := '1';  -- R/Wn bit
   constant I2C_WRITE_C : std_ulogic := '0';

   constant OEPOL_LEVEL_C : std_ulogic := conv_std_logic(OUTPUT_EN_POLARITY_G = 1);

   constant I2C_LOW_C : std_ulogic := OEPOL_LEVEL_C;  -- OE
   constant I2C_HIZ_C : std_ulogic := not OEPOL_LEVEL_C;

   constant I2C_ACK_C : std_ulogic := '0';

   constant TENBIT_ADDR_START_C : std_logic_vector(4 downto 0) := "11110";

   -----------------------------------------------------------------------------
   -- Types
   -----------------------------------------------------------------------------
   type i2c_in_array is array (FILTER_G downto 0) of i2c_in_type;

   type slv_state_type is (idle, checkaddr, check10bitaddr, sclhold,
                           movebyte, handshake);

   type i2cslv_reg_type is record
      slvstate : slv_state_type;
      -- Transfer phase
      active   : boolean;
      addr     : boolean;
--    transmit : boolean;
--    receive  : boolean;
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
      -- Registered Outputs
      o        : I2cSlaveOutType;
   end record;

   constant REG_INIT_C : i2cslv_reg_type := (
      slvstate => idle,
      active => false,
      addr => false,
      sreg => (others => '0'),
      cnt => (others => '0'),
      scl => '0',
      sda => '0',
      i2ci => (others => (scl => '0', sda => '0')),
      scloen => I2C_HIZ_C,
      sdaoen => I2C_HIZ_C,
      o => I2C_SLAVE_OUT_INIT_C);
   
   -----------------------------------------------------------------------------
   -- Subprograms
   -----------------------------------------------------------------------------
   -- purpose: Compares the first byte of a received address with the slave's
   -- address. The tba input determines if the slave is using a ten bit address.
   function compaddr1stb (
      ibyte : std_logic_vector(7 downto 0))  -- I2C byte
      return boolean
   is
      variable correct : std_logic_vector(7 downto 1);
   begin  -- compaddr1stb
      if TENBIT_G = 1 then
         correct(7 downto 3) := TENBIT_ADDR_START_C;
         correct(2 downto 1) := I2C_SLAVE_ADDR_C((I2C_ADDR_LEN_C-1) downto (I2C_ADDR_LEN_C-2));
      else
         correct(7 downto 1) := I2C_SLAVE_ADDR_C(6 downto 0);
      end if;
      return ibyte(7 downto 1) = correct(7 downto 1);
   end compaddr1stb;

   -- purpose: Compares the 2nd byte of a ten bit address with the slave address
   function compaddr2ndb (
      ibyte : std_logic_vector(7 downto 0))  -- I2C byte
      return boolean is
   begin  -- compaddr2ndb
      return ibyte((I2C_ADDR_LEN_C-3) downto 0) = I2C_SLAVE_ADDR_C((I2C_ADDR_LEN_C-3) downto 0);
   end compaddr2ndb;

   -----------------------------------------------------------------------------
   -- Signals
   -----------------------------------------------------------------------------

   -- Register interface
   signal r : i2cslv_reg_type := REG_INIT_C;
   signal rin : i2cslv_reg_type;

begin

   comb : process (r, sRst, i2ci, i2cSlaveIn)
      variable v       : i2cslv_reg_type;
      variable sclfilt : std_logic_vector(FILTER_G-1 downto 0);
      variable sdafilt : std_logic_vector(FILTER_G-1 downto 0);
   begin  -- process comb
      v := r;

      v.i2ci(0) := i2ci; v.i2ci(FILTER_G downto 1) := r.i2ci(FILTER_G-1 downto 0);

      ----------------------------------------------------------------------------
      -- Bus filtering
      ----------------------------------------------------------------------------
      for i in 0 to FILTER_G-1 loop
         sclfilt(i) := r.i2ci(i+1).scl; sdafilt(i) := r.i2ci(i+1).sda;
      end loop;  -- i
      if andv(sclfilt) = '1' then v.scl := '1'; end if;
      if orv(sclfilt) = '0' then v.scl  := '0'; end if;
      if andv(sdafilt) = '1' then v.sda := '1'; end if;
      if orv(sdafilt) = '0' then v.sda  := '0'; end if;

      -- txAck pulsed for 1 clock only when set by state machine below.
      v.o.txAck := '0';

      -- Reset rxValid when ack'd from IO
      if (r.o.rxValid = '1' and i2cSlaveIn.rxAck = '1') then
         v.o.rxValid := '0';
      end if;

      ---------------------------------------------------------------------------
      -- I2C slave control FSM
      ---------------------------------------------------------------------------
      case r.slvstate is
         when idle =>
            -- Release bus
            if (r.scl and not v.scl) = '1' then
               v.sdaoen := I2C_HIZ_C;
            end if;
            
         when checkaddr =>
            if compaddr1stb(r.sreg) then
               if r.sreg(0) = I2C_READ_C then
                  if (TENBIT_G = 0 or (TENBIT_G = 1 and r.active)) then
                     if i2cSlaveIn.txValid = '1' then
                        -- Transmit data
                        v.o.txActive := '1';
                        v.slvstate   := handshake;
                     else
                        -- No data to transmit, NAK
                        v.o.nack   := '1';
                        v.slvstate := idle;
                     end if;
                  else
                     -- Ten bit address with R/Wn = 1 and slave not previously
                     -- addressed.
                     v.slvstate := idle;
                  end if;
               else
                  v.o.rxActive := toSl(TENBIT_G = 0);
                  v.slvstate   := handshake;
               end if;
            else
               -- Slave address did not match
               v.active   := false;
               v.slvstate := idle;
            end if;
            v.sreg := i2cSlaveIn.txData;
            
         when check10bitaddr =>
            if compaddr2ndb(r.sreg) then
               -- Slave has been addressed with a matching 10 bit address
               -- If we receive a repeated start condition, matching address
               -- and R/Wn = 1 we will transmit data. Without start condition we
               -- will receive data.
               v.addr       := true;
               v.active     := true;
               v.o.rxActive := '1';
               v.slvstate   := handshake;
            else
               v.slvstate := idle;
            end if;
            
         when sclhold =>
            -- This state is used when the device has been addressed to see if SCL
            -- should be kept low until the receive register is free or the
            -- transmit register is filled. It is also used when a data byte has
            -- been transmitted or received to SCL low until software acknowledges
            -- the transfer.
            if (r.scl and not v.scl) = '1' then
               v.scloen := I2C_LOW_C;
               v.sdaoen := I2C_HIZ_C;
            end if;
            -- Ack has happened and rxValid set back to '0'
            if ((r.o.rxActive = '1' and (r.o.rxValid = '0' or RMODE_G = 0)) or
                (r.o.txActive = '1' and (i2cSlaveIn.txValid = '1' or TMODE_G = 0))) then
               v.slvstate := movebyte;
               v.scloen   := I2C_HIZ_C;
               -- Falling edge that should be detected in movebyte may have passed
               if r.o.txActive = '1' and v.scl = '0' then
                  v.sdaoen := r.sreg(7) xor OEPOL_LEVEL_C;
               end if;
            end if;
            v.sreg := i2cSlaveIn.txData;

         when movebyte =>
            if (r.scl and not v.scl) = '1' then
               if r.o.txActive = '1' then
                  v.sdaoen := r.sreg(7) xor OEPOL_LEVEL_C;
               else
                  v.sdaoen := I2C_HIZ_C;
               end if;
            end if;
            if (not r.scl and v.scl) = '1' then
               v.sreg := r.sreg(6 downto 0) & r.sda;
               if r.cnt = "111" then
                  if r.addr then
                     v.slvstate := checkaddr;
                  elsif r.o.rxActive = '1' nor r.o.txActive = '1' then
                     v.slvstate := check10bitaddr;
                  else
                     v.slvstate := handshake;
                  end if;
                  v.cnt := (others => '0');
               else
                  v.cnt := r.cnt + 1;
               end if;
            end if;
            
         when handshake =>
            -- Falling edge
            if (r.scl and not v.scl) = '1' then
               if r.addr then
                  v.sdaoen := I2C_LOW_C;
               elsif r.o.rxActive = '1' then
                  -- Receive, send ACK/NAK
                  -- Acknowledge byte if core has room in receive register
                  -- This code assumes that the core's receive register is free if we are
                  -- in RMODE 1. This should always be the case unless software has
                  -- reconfigured the core during operation.
                  if r.o.rxValid = '0' then
                     v.sdaoen    := I2C_LOW_C;
                     v.o.rxData  := r.sreg;
                     v.o.rxValid := '1';
                  else
                     -- NAK the byte, the master must abort the transfer
                     v.sdaoen   := I2C_HIZ_C;
                     v.slvstate := idle;
                  end if;
               else
                  -- Transmit, release bus
                  v.sdaoen  := I2C_HIZ_C;
                  -- Byte transmitted, ack it.
                  v.o.txAck := '1';
               end if;
               if not r.addr and r.o.rxActive = '1' and v.sdaoen = I2C_HIZ_C then
                  v.o.nack := '1';
               end if;
            end if;
            -- Risinge edge
            if (not r.scl and v.scl) = '1' then
               if r.addr then
                  v.slvstate := movebyte;
               else
                  if r.o.rxActive = '1' then
                     -- RMODE 0: Be ready to accept one more byte which will be NAK'd if
                     -- software has not read the receive register
                     -- RMODE 1: Keep SCL low until software has acknowledged received byte
                     if RMODE_G = 0 then
                        v.slvstate := movebyte;
                     else
                        v.slvstate := sclhold;
                     end if;
                  else
                     -- Transmit, check ACK/NAK from master
                     -- If the master NAKs the transmitted byte the transfer has ended and
                     -- we should wait for the master's next action. If the master ACKs the
                     -- byte the core will act depending on tmode:
                     -- TMODE 0:
                     -- If the master ACKs the byte we must continue to transmit and will
                     -- transmit the same byte on all requests.
                     -- TMODE 1:
                     -- IF the master ACKs the byte we will keep SCL low until software has
                     -- put new transmit data into the transmit register.
                     if r.sda = I2C_ACK_C then
                        if TMODE_G = 0 then
                           v.slvstate := movebyte;
                        else
                           v.slvstate := sclhold;
                        end if;
                     else
                        v.slvstate := idle;
                     end if;
                  end if;
               end if;
               v.addr := false;
               v.sreg := i2cSlaveIn.txData;
            end if;
      end case;

      if i2cSlaveIn.enable = '1' then
         -- STOP condition
         if (r.scl and v.scl and not r.sda and v.sda) = '1' then
            v.active     := false;
            v.slvstate   := idle;
            v.o.txActive := '0';
            v.o.rxActive := '0';
         end if;

         -- START or repeated START condition
         if (r.scl and v.scl and r.sda and not v.sda) = '1' then
            v.slvstate   := movebyte;
            v.cnt        := (others => '0');
            v.addr       := true;
            v.o.txActive := '0';
            v.o.rxActive := '0';
         end if;
      end if;

      ----------------------------------------------------------------------------
      -- Reset and idle operation
      ----------------------------------------------------------------------------

      if (sRst = '1') then
         v.slvstate   := idle;
         v.scl        := '0';
         v.active     := false;
         v.scloen     := I2C_HIZ_C;
         v.sdaoen     := I2C_HIZ_C;
         v.sreg       := (others => '0');
         v.cnt        := (others => '0');
         v.o.rxActive := '0';
         v.o.rxValid  := '0';
         v.o.rxData   := (others => '0');
         v.o.txActive := '0';
         v.o.txAck    := '0';
         v.o.nack     := '0';
         
      end if;

      ----------------------------------------------------------------------------
      -- Signal assignments
      ----------------------------------------------------------------------------

      -- Update registers
      rin <= v;

      -- Update outputs
      i2cSlaveOut <= r.o;
      i2co.scl    <= '0';
      i2co.scloen <= r.scloen;
      i2co.sda    <= '0';
      i2co.sdaoen <= r.sdaoen;
      i2co.enable <= i2cSlaveIn.enable;
   end process comb;

   reg : process (clk, aRst)
   begin  -- process reg
      if (aRst = '1') then
         r.slvstate   <= idle            after TPD_G;
         r.scl        <= '0'             after TPD_G;
         r.active     <= false           after TPD_G;
         r.scloen     <= I2C_HIZ_C       after TPD_G;
         r.sdaoen     <= I2C_HIZ_C       after TPD_G;
         r.sreg       <= (others => '0') after TPD_G;
         r.cnt        <= (others => '0') after TPD_G;
         r.o.rxActive <= '0'             after TPD_G;
         r.o.rxValid  <= '0'             after TPD_G;
         r.o.rxData   <= (others => '0') after TPD_G;
         r.o.txActive <= '0'             after TPD_G;
         r.o.txAck    <= '0'             after TPD_G;
         r.o.nack     <= '0'             after TPD_G;
      elsif rising_edge(clk) then
         r <= rin after TPD_G;
      end if;
   end process reg;


end architecture rtl;
