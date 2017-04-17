-------------------------------------------------------------------------------
-- File       : I2cRegMaster.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-01-22
-- Last update: 2016-07-11
-------------------------------------------------------------------------------
-- Description:
--   PRESCALE_G = (clk_freq / (5 * i2c_freq)) - 1
--   FILTER_G = (min_pulse_time / clk_period) + 1
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Firmware Standard Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'SLAC Firmware Standard Library', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.StdRtlPkg.all;
use work.I2cPkg.all;

entity I2cRegMaster is
   
   generic (
      TPD_G                : time                      := 1 ns;
      OUTPUT_EN_POLARITY_G : integer range 0 to 1      := 0;
      FILTER_G             : integer range 2 to 512    := 8;
      PRESCALE_G           : integer range 0 to 655535 := 62);
   port (
      clk    : in  sl;
      srst   : in  sl := '0';
      arst   : in  sl := '0';
      regIn  : in  I2cRegMasterInType;
      regOut : out I2cRegMasterOutType;
      i2ci   : in  i2c_in_type;
      i2co   : out i2c_out_type);

end entity I2cRegMaster;

architecture rtl of I2cRegMaster is

   type StateType is (
      WAIT_REQ_S, 
      ADDR_S, 
      WRITE_S, 
      READ_TXN_S, 
      READ_S, 
      BUS_ACK_S, 
      REG_ACK_S);

   type RegType is record
      state       : StateType;
      byteCount   : unsigned(1 downto 0);
      regOut      : I2cRegMasterOutType;
      i2cMasterIn : I2cMasterInType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      state          => WAIT_REQ_S,
      byteCount      => (others => '0'),
      regOut         => (
         regAck      => '0',
         regFail     => '0',
         regFailCode => (others => '0'),
         regRdData   => (others => '0')),
      i2cMasterIn    => (
         enable      => '0',
         prescale    => (others => '0'),
         filter      => (others => '0'),
         txnReq      => '0',
         stop        => '0',
         op          => '0',
         busReq      => '0',
         addr        => (others => '0'),
         tenbit      => '0',
         wrValid     => '0',
         wrData      => (others => '0'),
         rdAck       => '0'));

   signal r            : RegType := REG_INIT_C;
   signal rin          : RegType;
   signal i2cMasterIn  : I2cMasterInType;
   signal i2cMasterOut : I2cMasterOutType;

   function getIndex (
      endianness : sl;
      byteCount  : unsigned;
      totalBytes : unsigned)
      return integer is
   begin
      if (endianness = '0') then
         -- little endian
         return to_integer(byteCount)*8;
      else
         -- big endian
         return (to_integer(totalBytes)-to_integer(byteCount))*8;
      end if;
   end function getIndex;

begin

   i2cMaster_1 : entity work.I2cMaster
      generic map (
         TPD_G                => TPD_G,
         OUTPUT_EN_POLARITY_G => OUTPUT_EN_POLARITY_G,
         FILTER_G             => FILTER_G,
         DYNAMIC_FILTER_G     => 0)
      port map (
         clk          => clk,
         srst         => srst,
         arst         => arst,
         i2cMasterIn  => i2cMasterIn,
         i2cMasterOut => i2cMasterOut,
         i2ci         => i2ci,
         i2co         => i2co);

   comb : process (regIn, i2cMasterOut, r, srst) is
      variable v            : RegType;
      variable addrIndexVar : integer;
      variable dataIndexVar : integer;
   begin
      v := r;

      addrIndexVar := getIndex(regIn.endianness, r.byteCount, unsigned(regIn.regAddrSize));
      dataIndexVar := getIndex(regIn.endianness, r.byteCount, unsigned(regIn.regDataSize));

      v.regOut.regAck  := '0';
      v.regOut.regFail := '0';

      v.i2cMasterIn.rdAck := '0';

      case r.state is
         when WAIT_REQ_S =>
            v.byteCount := (others => '0');
            if (regIn.regReq = '1') then
               v.i2cMasterIn.txnReq := '1';
               v.i2cMasterIn.op     := '1';
               -- Use a repeated start for reads when directed to do so
               -- This is done by setting stop to 0 for the regAddr write txn
               -- Then the following read txn will be issued with repeated start
               v.i2cMasterIn.stop   := ite(regIn.regOp = '0' and regIn.repeatStart = '1', '0', '1');
               v.i2cMasterIn.busReq := regIn.busReq;
               v.state              := ADDR_S;
               if regIn.busReq = '1' then
                  v.state := BUS_ACK_S;
               elsif (regIn.regAddrSkip = '1') then
                  if (regIn.regOp = '1') then
                     v.state := WRITE_S;
                  else
                     v.i2cMasterIn.op := '0';
                     v.state := READ_S;
                  end if;                  
               end if;
            end if;
            
         when ADDR_S =>
            -- When a new register access request is seen,
            -- Write the register address out on the bus first
            -- One byte at a time, order determined by endianness input
            v.i2cMasterIn.wrData  := regIn.regAddr(addrIndexVar+7 downto addrIndexVar);
            v.i2cMasterIn.wrValid := '1';
            -- Must drop txnReq as last byte is sent if reading
            v.i2cMasterIn.txnReq  := not toSl(slv(r.byteCount) = regIn.regAddrSize and regIn.regOp = '0');

            if (i2cMasterOut.wrAck = '1') then
               v.byteCount           := r.byteCount + 1;
               v.i2cMasterIn.wrValid := '0';
               if (slv(r.byteCount) = regIn.regAddrSize) then
                  -- Done sending addr
                  v.byteCount := (others => '0');
                  if (regIn.regOp = '1') then
                     v.state := WRITE_S;
                  else
                     v.state := READ_TXN_S;
                  end if;
               end if;
            end if;

         when WRITE_S =>
            -- Txn started in WAIT_REQ_S still active
            -- Put wrData on the bus one byte at a time
            v.i2cMasterIn.wrData  := regIn.regWrData(dataIndexVar+7 downto dataIndexVar);
            v.i2cMasterIn.wrValid := '1';
            v.i2cMasterIn.txnReq  := not toSl(slv(r.byteCount) = regIn.regDataSize);
            v.i2cMasterIn.stop    := '1';  -- Send stop when done writing all bytes
            if (i2cMasterOut.wrAck = '1') then
               v.byteCount           := r.byteCount + 1;
               v.i2cMasterIn.wrValid := '0';
               if (slv(r.byteCount) = regIn.regDataSize) then  -- could use rxnReq = 0
                  v.state := REG_ACK_S;
               end if;
            end if;
            

         when READ_TXN_S =>
            -- Start new txn to read data bytes
            v.i2cMasterIn.txnReq := '1';
            v.i2cMasterIn.op     := '0';
            v.i2cMasterIn.stop   := '1';  -- i2c stop after all bytes are read
            v.state              := READ_S;

         when READ_S =>
            -- Drop txnReq on last byte
            v.i2cMasterIn.txnReq := not toSl(slv(r.byteCount) = regIn.regDataSize);
            -- Read data bytes as they arrive
            if (i2cMasterOut.rdValid = '1' and r.i2cMasterIn.rdAck = '0') then
               v.byteCount                                            := r.byteCount + 1;
               v.regOut.regRdData(dataIndexVar+7 downto dataIndexVar) := i2cMasterOut.rdData;
               v.i2cMasterIn.rdAck                                    := '1';
               if (slv(r.byteCount) = regIn.regDataSize) then
                  -- Done
                  v.state := REG_ACK_S;
               end if;
            end if;

         when BUS_ACK_S => 
            if i2cMasterOut.busAck = '1' then
               v.i2cMasterIn.txnReq := '0';
               v.state              := REG_ACK_S;
            end if;
            
         when REG_ACK_S =>
            -- Req done. Ack the req.
            -- Might have failed so hold regFail (would be set to 0 otherwise).
            v.regOut.regAck  := '1';
            v.regOut.regFail := r.regOut.regFail;
            if (regIn.regReq = '0') then
--          v.regOut.regAck := '0'; Might want this back. 
               v.state := WAIT_REQ_S;
            end if;

      end case;

      -- Always check for errors an cancel the txn if they happen
      if (i2cMasterOut.txnError = '1' and i2cMasterOut.rdValid = '1') then
         v.regOut.regFail     := '1';
         v.regOut.regFailCode := i2cMasterOut.rdData;
         v.i2cMasterIn.txnReq := '0';
         v.i2cMasterIn.rdAck  := '1';
         v.state              := REG_ACK_S;
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

      -- Internal signals
      i2cMasterIn.enable   <= '1';
      i2cMasterIn.prescale <= slv(to_unsigned(PRESCALE_G, 16));
      i2cMasterIn.filter   <= (others => '0');  -- Not using dynamic filtering
      i2cMasterIn.addr     <= regIn.i2cAddr;
      i2cMasterIn.tenbit   <= regIn.tenbit;
      i2cMasterIn.txnReq   <= r.i2cMasterIn.txnReq;
      i2cMasterIn.stop     <= r.i2cMasterIn.stop;
      i2cMasterIn.op       <= r.i2cMasterIn.op;
      i2cMasterIn.wrValid  <= r.i2cMasterIn.wrValid;
      i2cMasterIn.wrData   <= r.i2cMasterIn.wrData;
      i2cMasterIn.rdAck    <= r.i2cMasterIn.rdAck;
      i2cMasterIn.busReq   <= r.i2cMasterIn.busReq;

      -- Outputs
      regOut <= r.regOut;
      
   end process comb;

   seq : process (clk, arst) is
   begin
      if (arst = '1') then
         r <= REG_INIT_C after TPD_G;
      elsif (rising_edge(clk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;



end architecture rtl;
