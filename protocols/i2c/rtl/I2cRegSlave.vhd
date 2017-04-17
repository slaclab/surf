-------------------------------------------------------------------------------
-- File       : I2cRegSlave.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-01-16
-- Last update: 2014-03-13
-------------------------------------------------------------------------------
-- Description: Implements an I2C slave attached to a generic RAM interface.
-- Protocol is simple: Address of configurable size, followed by data of
-- configurable size.
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

entity I2cRegSlave is
   generic (
      TPD_G                : time                    := 1 ns;
      -- Generics passed down to I2cSlave
      TENBIT_G             : integer range 0 to 1    := 0;
      I2C_ADDR_G           : integer range 0 to 1023 := 0;
      OUTPUT_EN_POLARITY_G : integer range 0 to 1    := 0;
      FILTER_G             : integer range 2 to 512  := 4;
      -- RAM generics
      ADDR_SIZE_G          : positive                := 2;   -- in bytes
      DATA_SIZE_G          : positive                := 1;   -- in bytes
      ENDIANNESS_G         : integer range 0 to 1    := 0);  -- 0=LE, 1=BE
   port (
      sRst   : in  sl := '0';
      aRst   : in  sl := '0';
      clk    : in  sl;
      -- Front End Ram Interface
      addr   : out slv((8*ADDR_SIZE_G)-1 downto 0);
      wrEn   : out sl;
      wrData : out slv((8*DATA_SIZE_G)-1 downto 0);
      rdEn   : out sl;
      rdData : in  slv((8*DATA_SIZE_G)-1 downto 0);
      -- I2C Signals
      i2ci   : in  i2c_in_type;
      i2co   : out i2c_out_type);
end entity I2cRegSlave;

architecture rtl of I2cRegSlave is

   type StateType is (IDLE_S, ADDR_S, WRITE_DATA_S, READ_DATA_S);

   type RegType is record
      state   : StateType;
      byteCnt : unsigned(bitSize(maximum(ADDR_SIZE_G, DATA_SIZE_G))-1 downto 0);

      addr       : unsigned((8*ADDR_SIZE_G)-1 downto 0);
      wrEn       : sl;
      wrData     : slv((8*DATA_SIZE_G)-1 downto 0);
      rdEn       : sl;
      i2cSlaveIn : I2cSlaveInType;      -- Signals to i2cSlave
   end record RegType;

   constant REG_INIT_C : RegType := (
      state      => IDLE_S,
      byteCnt    => (others => '0'),
      addr       => (others => '0'),
      wrEn       => '0',
      wrData     => (others => '0'),
      rdEn       => '0',
      i2cSlaveIn => I2C_SLAVE_IN_INIT_C);

   signal r           : RegType := REG_INIT_C;
   signal rin         : RegType;
   signal i2cSlaveOut : I2cSlaveOutType;  -- From i2cSlave
   signal i2cSlaveIn  : I2cSlaveInType;   -- To I2cSlave

   function getIndex (
      byteCount  : unsigned;
      totalBytes : positive)
      return integer is
   begin
      if (ENDIANNESS_G = 0) then
         -- little endian
         return to_integer(byteCount)*8;
      else
         -- big endian
         return (totalBytes-1-to_integer(byteCount))*8;
      end if;
   end function getIndex;
   
begin

   I2cSlave_1 : entity work.I2cSlave
      generic map (
         TENBIT_G             => TENBIT_G,
         I2C_ADDR_G           => I2C_ADDR_G,
         OUTPUT_EN_POLARITY_G => OUTPUT_EN_POLARITY_G,
         FILTER_G             => FILTER_G,
         RMODE_G              => 0,
         TMODE_G              => 0)
      port map (
         sRst        => sRst,
         aRst        => aRst,
         clk         => clk,
         i2cSlaveIn  => i2cSlaveIn,
         i2cSlaveOut => i2cSlaveOut,
         i2ci        => i2ci,
         i2co        => i2co);

   comb : process (rdData, r, i2cSlaveOut, sRst) is
      variable v            : RegType;
      variable byteCntVar   : integer;
      variable addrIndexVar : integer;
      variable dataIndexVar : integer;
   begin
      v := r;

      byteCntVar   := to_integer(r.byteCnt);
      addrIndexVar := getIndex(r.byteCnt, ADDR_SIZE_G);
      dataIndexVar := getIndex(r.byteCnt, DATA_SIZE_G);

      -- Enable the i2cSlave after reset
      v.i2cSlaveIn.enable := '1';

      -- Read and Write enables are pulsed, defualt to 0
      v.wrEn := '0';
      v.rdEn := '0';

      -- Pulse rxAck or wait until rxValid drops?
      -- Can get away with pulsing.
      v.i2cSlaveIn.rxAck := '0';

      -- Auto increment the address after each read or write
      -- This enables bursts.
      if (r.wrEn = '1' or r.rdEn = '1') then
         v.addr := r.addr + 1;
      end if;

      -- Tx Data always valid, assigned based on byte cnt
      v.i2cSlaveIn.txValid := '1';

      case (r.state) is
         when IDLE_S =>
            v.byteCnt           := (others => '0');
            -- Get txData ready in case a read occurs.
            v.i2cSlaveIn.txData := rdData(dataIndexVar+7 downto dataIndexVar);

            -- Wait here for slave to be addressed
            if (i2cSlaveOut.rxActive = '1') then
               -- Slave has been addressed for a write on the i2c bus
               -- This write will consist of the ram address
               v.state := ADDR_S;
               v.addr  := (others => '0');

            elsif (i2cSlaveOut.txActive = '1') then
               v.state := READ_DATA_S;
            end if;

         when ADDR_S =>
            if (i2cSlaveOut.rxValid = '1') then
               -- Received a byte of the address
               v.addr(addrIndexVar+7 downto addrIndexVar) := unsigned(i2cSlaveOut.rxData);
               v.byteCnt                                  := r.byteCnt + 1;
               if (r.byteCnt = ADDR_SIZE_G-1) then
                  v.byteCnt := (others => '0');
                  v.state   := WRITE_DATA_S;
               end if;
            end if;

            if (i2cSlaveOut.rxActive = '0') then
               -- Didn't get enough bytes, go back to idle
               v.state   := IDLE_S;
               v.byteCnt := (others => '0');
            end if;

         when WRITE_DATA_S =>
            if (i2cSlaveOut.rxValid = '1') then
               -- Received another byte
               v.wrData(dataIndexVar+7 downto dataIndexVar) := i2cSlaveOut.rxData;
               v.byteCnt                                    := r.byteCnt + 1;
--          v.i2cSlaveIn.rxAck := '1';
               if (byteCntVar = DATA_SIZE_G -1) then
                  -- Received a whole word. Increment addr, reset byteCnt
                  v.wrEn    := '1';
                  v.byteCnt := (others => '0');
               end if;
            end if;

            if (i2cSlaveOut.rxActive = '0') then
               v.state := IDLE_S;
            end if;

         when READ_DATA_S =>
            v.i2cSlaveIn.txData := rdData(dataIndexVar+7 downto dataIndexVar);
            if (i2cSlaveOut.txAck = '1') then
               -- Byte was sent
               v.byteCnt := r.byteCnt + 1;
               if (byteCntVar = DATA_SIZE_G - 1) then
                  -- Word was sent. Increment addr to get next word, reset byteCnt
                  v.rdEn    := '1';
                  v.byteCnt := (others => '0');
               end if;
            end if;

            if (i2cSlaveOut.txActive = '0') then
               v.state := IDLE_S;
            end if;
            

         when others => null;
      end case;

      ------------------------------------------------------------------------------------------------
      -- Synchronous Reset
      ------------------------------------------------------------------------------------------------
      if (sRst = '1') then
         v := REG_INIT_C;
--      v.state              := IDLE_S;
--      v.byteCnt            := (others => '0');
--      v.addr               := (others => '0');
--      v.wrEn               := '0';
--      v.wrData             := (others => '0');
--      v.rdEn               := '0';
--      v.i2cSlaveIn.enable  := '0';
--      v.i2cSlaveIn.txValid := '0';
--      v.i2cSlaveIn.txData  := (others => '0');
--      v.i2cSlaveIn.rxAck   := '0';
      end if;

      ------------------------------------------------------------------------------------------------
      -- Signal Assignments
      ------------------------------------------------------------------------------------------------
      -- Update registers
      rin <= v;

      -- Internal signals
      i2cSlaveIn       <= r.i2cSlaveIn;
      i2cSlaveIn.rxAck <= i2cSlaveOut.rxValid;  -- Always ack

      -- Update Outputs
      addr   <= slv(r.addr);
      wrData <= r.wrData;
      wrEn   <= r.wrEn;
      rdEn   <= r.rdEn;
      
   end process comb;

   seq : process (clk, aRst) is
   begin
      if (aRst = '1') then
         r <= REG_INIT_C after TPD_G;
--      r.state              <= IDLE_S          after TPD_G;
--      r.byteCnt            <= (others => '0') after TPD_G;
--      r.addr               <= (others => '0') after TPD_G;
--      r.wrEn               <= '0'             after TPD_G;
--      r.wrData             <= (others => '0') after TPD_G;
--      r.rdEn               <= '0'             after TPD_G;
--      r.i2cSlaveIn.enable  <= '0'             after TPD_G;
--      r.i2cSlaveIn.txValid <= '0'             after TPD_G;
--      r.i2cSlaveIn.txData  <= (others => '0') after TPD_G;
--      r.i2cSlaveIn.rxAck   <= '0'             after TPD_G;
      elsif (rising_edge(clk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end architecture rtl;
