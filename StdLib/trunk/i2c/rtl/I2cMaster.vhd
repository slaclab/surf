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
-- Entity:      I2cMaster
-- File:        I2cMaster.vhd
-- Author:      Jan Andersson - Gaisler Research
-- Contact:     support@gaisler.com
-- Description:
--
--         Generic interface to OpenCores I2C-master. This is a wrapper
--         that instantiates the byte- and bit-controller of the OpenCores I2C
--         master (OC core developed by Richard Herveille, richard@asics.ws). 
--
-- Modifications:
--   10/2012 - Ben Reese <bareese@slac.stanford.edu>
--     Removed AMBA bus register based interfaced and replaced with generic
--     IO interface for use anywhere within a firmware design.
--     Interface based on transactions consisting of a i2c device address
--     followed by up to 4 byte-reads or 4 byte-writes.
--
--     Dynamic filter and bus speed adjustment have been left in as features,
--     though they will probably be rarely used.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.StdRtlPkg.all;
use work.I2cPkg.all;

entity I2cMaster is
   generic (
      TPD_G                : time                   := 1 ns;  -- Simulated propagation delay
      OUTPUT_EN_POLARITY_G : integer range 0 to 1   := 0;     -- output enable polarity
      FILTER_G             : integer range 2 to 512 := 126;   -- filter bit size
      DYNAMIC_FILTER_G     : integer range 0 to 1   := 0);
   port (
      clk          : in  sl;
      srst         : in  sl := '0';
      arst         : in  sl := '0';
      -- Front End
      i2cMasterIn  : in  I2cMasterInType;
      i2cMasterOut : out I2cMasterOutType;

      -- I2C signals
      i2ci : in  i2c_in_type;
      i2co : out i2c_out_type
      );
end entity I2cMaster;

architecture rtl of I2cMaster is
   -----------------------------------------------------------------------------
   -- Constants
   -----------------------------------------------------------------------------

   -----------------------------------------------------------------------------
   -- Types 
   -----------------------------------------------------------------------------
   -- i2c_master_byte_ctrl IO
   type ByteCtrlInType is record
      start : sl;
      stop  : sl;
      read  : sl;
      write : sl;
      ackIn : sl;
      din   : slv(7 downto 0);
   end record;

   type ByteCtrlOutType is record
      cmdAck : sl;
      ackOut : sl;
      al     : sl;
      busy   : sl;
      dout   : slv(7 downto 0);
   end record;

   type StateType is (WAIT_TXN_REQ_S,
                      ADDR_S,
                      WAIT_ADDR_ACK_S,
                      READ_S,
                      WAIT_READ_DATA_S,
                      WRITE_S,
                      WAIT_WRITE_ACK_S);

   -- Module Registers
   type RegType is record
      byteCtrlIn   : ByteCtrlInType;
      state        : StateType;
      tenbit       : sl;
      i2cMasterOut : I2cMasterOutType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      byteCtrlIn   => (
         start     => '0',
         stop      => '0',
         read      => '0',
         write     => '0',
         ackIn     => '0',
         din       => (others => '0')),
      state        => WAIT_TXN_REQ_S,
      tenbit       => '0',
      i2cMasterOut => (
         busAck    => '0',
         txnError  => '0',
         wrAck     => '0',
         rdValid   => '0',
         rdData    => (others => '0')));


   --------------------------------------------------------------------------------------------------
   -- Signals
   --------------------------------------------------------------------------------------------------
   -- Register interface
   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   -- Outputs from byte_ctrl block
   signal byteCtrlOut : ByteCtrlOutType;
   signal iSclOEn     : sl;                                           -- Internal SCL output enable
   signal iSdaOEn     : sl;                                           -- Internal SDA output enablee
   signal filter      : slv((FILTER_G-1)*DYNAMIC_FILTER_G downto 0);  -- filt input to byte_ctrl
   signal arstL       : sl;

begin

   arstL <= not arst;

   -- Byte Controller from OpenCores I2C master,
   -- by Richard Herveille (richard@asics.ws). The asynchronous
   -- reset is tied to '1'. Only the synchronous reset is used.
   -- OC I2C logic has active high reset.
   byte_ctrl : i2c_master_byte_ctrl
      generic map (
         filter  => FILTER_G,
         dynfilt => DYNAMIC_FILTER_G)
      port map (
         clk      => clk,
         rst      => srst,
         nReset   => arstL,
         ena      => i2cMasterIn.enable,
         clk_cnt  => i2cMasterIn.prescale,
         start    => r.byteCtrlIn.start,
         stop     => r.byteCtrlIn.stop,
         read     => r.byteCtrlIn.read,
         write    => r.byteCtrlIn.write,
         ack_in   => r.byteCtrlIn.ackIn,
         din      => r.byteCtrlIn.din,
         filt     => filter,
         cmd_ack  => byteCtrlOut.cmdAck,
         ack_out  => byteCtrlOut.ackOut,
         i2c_busy => byteCtrlOut.busy,
         i2c_al   => byteCtrlOut.al,
         dout     => byteCtrlOut.dout,
         scl_i    => i2ci.scl,
         scl_o    => i2co.scl,
         scl_oen  => iscloen,
         sda_i    => i2ci.sda,
         sda_o    => i2co.sda,
         sda_oen  => isdaoen);

   i2co.enable <= i2cMasterIn.enable;

   -- Fix output enable polarity
   soepol0 : if OUTPUT_EN_POLARITY_G = 0 generate
      i2co.scloen <= iscloen;
      i2co.sdaoen <= isdaoen;
   end generate soepol0;
   soepol1 : if OUTPUT_EN_POLARITY_G /= 0 generate
      i2co.scloen <= not iscloen;
      i2co.sdaoen <= not isdaoen;
   end generate soepol1;




   comb : process (r, byteCtrlOut, i2cMasterIn, srst)
      variable v        : RegType;
      variable indexVar : integer;
   begin  -- process comb
      v := r;

      -- byteCtrl commands default to zero
      -- unless overridden in a state below
      v.byteCtrlIn.start := '0';
      v.byteCtrlIn.stop  := '0';
      v.byteCtrlIn.read  := '0';
      v.byteCtrlIn.write := '0';
      v.byteCtrlIn.ackIn := '0';

      v.i2cMasterOut.wrAck  := '0';      -- pulsed
      v.i2cMasterOut.busAck := '0';      -- pulsed

      if (i2cMasterIn.rdAck = '1') then
         v.i2cMasterOut.rdValid  := '0';
         v.i2cMasterOut.txnError := '0';
      end if;

      case (r.state) is
         when WAIT_TXN_REQ_S =>
            -- Reset front end outputs
            v.i2cMasterOut.rdData := (others => '0');  -- Necessary?
            -- If new request and any previous rdData has been acked.
            if (i2cMasterIn.txnReq = '1') and (r.i2cMasterOut.rdValid = '0') and (r.i2cMasterOut.busAck = '0') then
               v.state  := ADDR_S;
               v.tenbit := i2cMasterIn.tenbit;
            end if;

         when ADDR_S =>
            v.byteCtrlIn.start := '1';
            v.byteCtrlIn.write := '1';
            if (r.tenbit = '0') then
               if (i2cMasterIn.tenbit = '0') then
                  -- Send normal 7 bit address
                  v.byteCtrlIn.din(7 downto 1) := i2cMasterIn.addr(6 downto 0);
                  v.byteCtrlIn.din(0)          := not i2cMasterIn.op;
               else
                  -- Send second half of 10 bit address
                  v.byteCtrlIn.din := i2cMasterIn.addr(7 downto 0);
               end if;
            else
               -- Send first half of 10 bit address
               v.byteCtrlIn.din(7 downto 3) := "00000";
               v.byteCtrlIn.din(2 downto 1) := i2cMasterIn.addr(9 downto 8);
               v.byteCtrlIn.din(0)          := not i2cMasterIn.op;
            end if;
            v.state := WAIT_ADDR_ACK_S;

            
         when WAIT_ADDR_ACK_S =>
            if (byteCtrlOut.cmdAck = '1') then     -- Master sent the command
               if (byteCtrlOut.ackOut = '0') then  -- Slave ack'd the transfer
                  if (r.tenbit = '1') then         -- Must send second half of addr if tenbit set
                     v.tenbit := '0';
                     v.state  := ADDR_S;
                  else
                     -- Do read or write depending on op
                     if (i2cMasterIn.op = '0') then
                        v.state := READ_S;
                     else
                        v.state := WRITE_S;
                     end if;
                  end if;
               else
                  -- Slave did not ack the transfer, fail the txn
                  v.i2cMasterOut.txnError := '1';
                  v.i2cMasterOut.rdValid  := '1';
                  v.i2cMasterOut.rdData   := I2C_INVALID_ADDR_ERROR_C;
                  v.state                 := WAIT_TXN_REQ_S;
               end if;
               if (r.tenbit = '0') and (i2cMasterIn.busReq = '1') then
                  v.i2cMasterOut.busAck := '1';
                  v.state               := WAIT_TXN_REQ_S;
               end if;
            end if;

            
         when READ_S =>
            if (r.i2cMasterOut.rdValid = '0') then  -- Previous byte has been ack'd
               v.byteCtrlIn.read  := '1';
               -- If last byte of txn send nack.
               -- Send stop on last byte if enabled (else repeated start will occur on next txn).
               v.byteCtrlIn.ackIn := not i2cMasterIn.txnReq;
               v.byteCtrlIn.stop  := not i2cMasterIn.txnReq and i2cMasterIn.stop;
               v.state            := WAIT_READ_DATA_S;
            end if;


         when WAIT_READ_DATA_S =>
            v.byteCtrlIn.stop  := r.byteCtrlIn.stop;   -- Hold stop or it wont get seen
            v.byteCtrlIn.ackIn := r.byteCtrlIn.ackIn;  -- This too
            if (byteCtrlOut.cmdAck = '1') then         -- Master sent the command
               v.byteCtrlIn.stop      := '0';          -- Drop stop asap or it will be repeated
               v.byteCtrlIn.ackIn     := '0';
               v.i2cMasterOut.rdData  := byteCtrlOut.dout;
               v.i2cMasterOut.rdValid := '1';
               if (i2cMasterIn.txnReq = '0') then      -- Last byte of txn
                  v.i2cMasterOut.txnError := '0';      -- Necessary? Should already be 0
                  v.state                 := WAIT_TXN_REQ_S;
               else
                  -- If not last byte, read another.
                  v.state := READ_S;
               end if;
            end if;

         when WRITE_S =>
            -- Write the next byte
            if (i2cMasterIn.wrValid = '1' and r.i2cMasterOut.wrAck = '0') then
               v.byteCtrlIn.write := '1';
               -- Send stop on last byte if enabled (else repeated start will occur on next txn).
               v.byteCtrlIn.stop  := not i2cMasterIn.txnReq and i2cMasterIn.stop;
               v.byteCtrlIn.din   := i2cMasterIn.wrData;
               v.state            := WAIT_WRITE_ACK_S;
            end if;

         when WAIT_WRITE_ACK_S =>
            v.byteCtrlIn.stop := r.byteCtrlIn.stop;
            if (byteCtrlOut.cmdAck = '1') then        -- Master sent the command
               if (byteCtrlOut.ackOut = '0') then     -- Slave ack'd the transfer
                  v.byteCtrlIn.stop    := '0';
                  v.i2cMasterOut.wrAck := '1';        -- Pass wr ack to front end
                  if (i2cMasterIn.txnReq = '0') then  -- Last byte of txn
                     v.i2cMasterOut.txnError := '0';  -- Necessary, should already be 0?
                     v.state                 := WAIT_TXN_REQ_S;
                  else
                     -- If not last byte, write nother
                     v.state := WRITE_S;
                  end if;
               else
                  -- Slave did not ack the transfer, fail the txn
                  v.i2cMasterOut.txnError := '1';
                  v.i2cMasterOut.rdValid  := '1';
                  v.i2cMasterOut.rdData   := I2C_WRITE_ACK_ERROR_C;
                  v.state                 := WAIT_TXN_REQ_S;
               end if;
            end if;
            
         when others => v.state := WAIT_TXN_REQ_S;
      end case;

      -- Must always monitor for arbitration loss
      if (byteCtrlOut.al = '1') then
         -- Retry the entire TXN. Nothing done has been valid if arbitration is lost.
         -- Should probably have a retry limit.
         v.state                 := WAIT_TXN_REQ_S;
         v.i2cMasterOut.txnError := '1';
         v.i2cMasterOut.rdValid  := '1';
         v.i2cMasterOut.rdData   := I2C_ARBITRATION_LOST_ERROR_C;
      end if;

      ------------------------------------------------------------------------------------------------
      -- Synchronous Reset
      ------------------------------------------------------------------------------------------------
      if (srst = '1') then
         v := REG_INIT_C;
      end if;

      ------------------------------------------------------------------------------------------------
      -- Signal Assignments
      ------------------------------------------------------------------------------------------------
      -- Update registers
      rin <= v;

      -- Assign outputs
      i2cMasterOut <= r.i2cMasterOut;

   end process comb;
   filter <= i2cMasterIn.filter when DYNAMIC_FILTER_G = 1 else (others => '0');

   reg : process (clk, arst)
   begin
      if (arst = '1') then
         r <= REG_INIT_C after TPD_G;
      elsif rising_edge(clk) then
         r <= rin after TPD_G;
      end if;
   end process reg;


end architecture rtl;
