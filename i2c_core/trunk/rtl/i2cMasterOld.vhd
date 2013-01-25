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
-- Entity:      i2cMaster
-- File:        i2cMaster.vhd
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
use work.i2cPkg.all;

entity i2cMaster is
  generic (
    TPD_G                : time                   := 1 ns;  -- Simulated propagation delay
    OUTPUT_EN_POLARITY_G : integer range 0 to 1   := 0;     -- output enable polarity
    FILTER_G             : integer range 2 to 512 := 126;     -- filter bit size
    DYNAMIC_FILTER_G     : integer range 0 to 1   := 0);
  port (
    clk : in sl;
    rst : in sl;

    -- Front End
    i2cMasterIn  : in  i2cMasterInType;
    i2cMasterOut : out i2cMasterOutType;

    -- I2C signals
    i2ci : in  i2c_in_type;
    i2co : out i2c_out_type
    );
end entity i2cMaster;

architecture rtl of i2cMaster is
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
                     WAIT_WRITE_ACK_S,
                     WAIT_REQ_FALL_S);

  -- Module Registers
  type RegType is record
    byteCtrlIn   : ByteCtrlInType;
    state        : StateType;
    byteCount    : unsigned(1 downto 0);
    tenbit       : sl;
    i2cMasterOut : i2cMasterOutType;
  end record RegType;


  --------------------------------------------------------------------------------------------------
  -- Signals
  --------------------------------------------------------------------------------------------------
  -- Register interface
  signal r, rin : RegType;

  -- Outputs from byte_ctrl block
  signal byteCtrlOut : ByteCtrlOutType;
  signal iSclOEn     : sl;                                           -- Internal SCL output enable
  signal iSdaOEn     : sl;                                           -- Internal SDA output enablee
  signal filter      : slv((FILTER_G-1)*DYNAMIC_FILTER_G downto 0);  -- filt input to byte_ctrl

begin

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
      rst      => rst,
      nReset   => '1',
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


  reg : process (clk, rst)
  begin
    if (rst = '1') then
      r.byteCtrlIn.start      <= '0'             after TPD_G;
      r.byteCtrlIn.stop       <= '0'             after TPD_G;
      r.byteCtrlIn.read       <= '0'             after TPD_G;
      r.byteCtrlIn.write      <= '0'             after TPD_G;
      r.byteCtrlIn.ackIn      <= '0'             after TPD_G;
      r.byteCtrlIn.din        <= (others => '0') after TPD_G;
      r.state                 <= WAIT_TXN_REQ_S  after TPD_G;
      r.byteCount             <= (others => '0') after TPD_G;
      r.tenbit                <= '0'             after TPD_G;
      r.i2cMasterOut.txnDone  <= '0'             after TPD_G;
      r.i2cMasterOut.txnError <= '0'             after TPD_G;
      r.i2cMasterOut.rdData   <= (others => '0') after TPD_G;
    elsif rising_edge(clk) then
      r <= rin after TPD_G;
    end if;
  end process reg;

  comb : process (r, byteCtrlOut, i2cMasterIn)
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

    case (r.state) is
      when WAIT_TXN_REQ_S =>
        -- Reset front end outputs
        v.i2cMasterOut.txnDone  := '0';
        v.i2cMasterOut.txnError := '0';
        v.i2cMasterOut.rdData   := (others => '0');

        if (i2cMasterIn.txnReq = '1') then
          v.byteCount := unsigned(i2cMasterIn.txnSize);
          v.state     := ADDR_S;
          v.tenbit    := i2cMasterIn.tenbit;
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
        -- Clear command bits
        v.byteCtrlIn.start := '0';
        v.byteCtrlIn.write := '0';

        if (byteCtrlOut.cmdAck = '1') then
          -- Master sent the command
          if (byteCtrlOut.ackOut = '0') then
            -- Slave ack'd the transfer
            if (r.tenbit = '1') then
              -- Must send second half of addr if tenbit set
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
            v.i2cMasterOut.txnDone  := '1';
            v.state                 := WAIT_REQ_FALL_S;
          end if;
        end if;

        
      when READ_S =>
        v.byteCtrlIn.read  := '1';
        -- If last byte of txn send ack (will nack). Send stop if enabled
        v.byteCtrlIn.ackIn := toSl(r.byteCount = 0);
        v.byteCtrlIn.stop  := toSl(r.byteCount = 0) and i2cMasterIn.stop;
        v.state            := WAIT_READ_DATA_S;


      when WAIT_READ_DATA_S =>
        if (byteCtrlOut.cmdAck = '1') then
          -- Master sent the command
          indexVar := (3-to_integer(r.byteCount))*8;

          v.i2cMasterOut.rdData(indexVar+7 downto indexVar) := byteCtrlOut.dout;
          if (r.byteCount = 0) then
            -- If last byte then done
            v.i2cMasterOut.txnError := '0';
            v.i2cMasterOut.txnDone  := '1';
            v.state                 := WAIT_REQ_FALL_S;
          else
            -- If not last byte decrement byteCount and start another read
            v.byteCount := r.byteCount - 1;
            v.state     := READ_S;
          end if;
        end if;

      when WRITE_S =>
        -- Write the next byte
        v.byteCtrlIn.write := '1';
        v.byteCtrlIn.stop  := toSl(r.byteCount = 0) and i2cMasterIn.stop;
        indexVar           := (3-to_integer(r.byteCount))*8;
        v.byteCtrlIn.din   := i2cMasterIn.wrData(indexVar+7 downto indexVar);
        v.state            := WAIT_WRITE_ACK_S;

      when WAIT_WRITE_ACK_S =>
        v.byteCtrlIn.write := '0';
        if (byteCtrlOut.cmdAck = '1') then
          -- Master sent the command
          if (byteCtrlOut.ackOut = '0') then
            -- Slave ack'd the transfer
            if (r.byteCount = 0) then
              -- If last byte then done
              v.i2cMasterOut.txnError := '0';
              v.i2cMasterOut.txnDone  := '1';
              v.state                 := WAIT_REQ_FALL_S;
            else
              -- If not last byte decrement byteCount and start another write
              v.byteCount := r.byteCount - 1;
              v.state     := WRITE_S;
            end if;
          else
            -- Slave did not ack the transfer, fail the txn
            v.i2cMasterOut.txnError := '1';
            v.i2cMasterOut.txnDone  := '1';
            v.state                 := WAIT_REQ_FALL_S;
          end if;
        end if;

      when WAIT_REQ_FALL_S =>
        if (i2cMasterIn.txnReq = '0') then
          v.state := WAIT_TXN_REQ_S;
        end if;
        
      when others => null;
    end case;

    -- Must always monitor for arbitration loss
    if (byteCtrlOut.al = '1') then
      -- Retry the entire TXN. Nothing done has been valid if arbitration is lost.
      -- Should probably have a retry limit.
      v.state := WAIT_TXN_REQ_S;
    end if;

    -- Update registers
    rin <= v;

    -- Assign outputs
    i2cMasterOut <= r.i2cMasterOut;

  end process comb;
  filter <= i2cMasterIn.filter when DYNAMIC_FILTER_G = 1 else (others => '0');
  
end architecture rtl;
