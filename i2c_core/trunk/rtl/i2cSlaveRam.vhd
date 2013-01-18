-------------------------------------------------------------------------------
-- Title      : I2C Slave RAM Interface
-------------------------------------------------------------------------------
-- File       : i2cSlaveRam.vhd
-- Author     : Benjamin Reese  <bareese@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-01-16
-- Last update: 2013-01-17
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Implements an I2C slave attached to a generic RAM interface.
-- Protocol is simple: Address of configurable size, followed by data of
-- configurable size.
-------------------------------------------------------------------------------
-- Copyright (c) 2013 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.StdRtlPkg.all;
use work.i2cPkg.all;


entity i2cSlaveRam is
  generic (
    -- Generics passed down to i2cSlave
    TENBIT_G             : integer range 0 to 1    := 0;
    I2C_ADDR_G           : integer range 0 to 1023 := 0;
    OUTPUT_EN_POLARITY_G : integer range 0 to 1    := 0;
    FILTER_G             : integer range 2 to 512  := 4;
    -- RAM generics
    ADDR_SIZE_G          : positive                := 2;   -- in bytes
    DATA_SIZE_G          : positive                := 1);  -- in bytes
  port (
    rstn   : in  sl;
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
end entity i2cSlaveRam;

architecture rtl of i2cSlaveRam is

  type StateType is (IDLE_S, ADDR_S, WRITE_DATA_S, READ_DATA_S);

  type RegType is record
    state   : StateType;
    byteCnt : unsigned(bitSize(ADDR_SIZE_G)-1 downto 0);

    addr       : unsigned((8*ADDR_SIZE_G)-1 downto 0);
    wrEn       : sl;
    wrData     : slv((8*DATA_SIZE_G)-1 downto 0);
    rdEn       : sl;
    i2cSlaveIn : i2cSlaveInType;        -- Signals to i2cSlave
  end record RegType;

  signal r, rin      : RegType;
  signal i2cSlaveOut : i2cSlaveOutType;  -- From i2cSlave
  signal i2cSlaveIn  : i2cSlaveInType;   -- To i2cSlave
  
begin

  i2cSlave_1 : entity work.i2cSlave
    generic map (
      TENBIT_G             => TENBIT_G,
      I2C_ADDR_G           => I2C_ADDR_G,
      OUTPUT_EN_POLARITY_G => OUTPUT_EN_POLARITY_G,
      FILTER_G             => FILTER_G,
      RMODE_G              => 0,
      TMODE_G              => 0)
    port map (
      rstn        => rstn,
      clk         => clk,
      i2cSlaveIn  => i2cSlaveIn,
      i2cSlaveOut => i2cSlaveOut,
      i2ci        => i2ci,
      i2co        => i2co);

  comb : process (rdData, r, i2cSlaveOut) is
    variable v          : RegType;
    variable byteCntVar : integer;
  begin
    v := r;
    byteCntVar := to_integer(r.byteCnt);

    -- Enable the i2cSlave after reset
    v.i2cSlaveIn.enable := '1';

    -- Read and Write enables are pulsed, defualt to 0
    v.wrEn := '0';
    v.rdEn := '0';

    -- Pulse rxAck or wait until rxValid drops?
    -- Can get away with pulsing.
    v.i2cSlaveIn.rxAck := '0';

    case (r.state) is
      when IDLE_S =>
        v.byteCnt := (others => '0');

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
          v.addr((8*byteCntVar)+7 downto 8*byteCntVar) := unsigned(i2cSlaveOut.rxData);
          v.byteCnt                                    := r.byteCnt + 1;
          if (r.byteCnt = ADDR_SIZE_G-1) then
            v.byteCnt := (others => '0');
            v.state   := WRITE_DATA_S;
          end if;
        end if;

        if (i2cSlaveOut.rxActive = '0') then
          -- Didn't get enough bytes, go back to idle
          v.state := IDLE_S;
        end if;

      when WRITE_DATA_S =>
        if (i2cSlaveOut.rxValid = '1') then
          -- Received another byte
          v.wrData((8*byteCntVar)+7 downto 8*byteCntVar) := i2cSlaveOut.rxData;
          v.byteCnt                                      := r.byteCnt + 1;
--          v.i2cSlaveIn.rxAck := '1';
          if (byteCntVar = DATA_SIZE_G -1) then
            -- Received a whole word. Increment addr, reset byteCnt
            v.wrEn    := '1';
            v.byteCnt := (others => '0');
            v.addr    := r.addr + 1;
          end if;
        end if;

        if (i2cSlaveOut.rxActive = '0') then
          v.state := IDLE_S;
        end if;

      when READ_DATA_S =>
        -- Could maybe move txData and txValid assignments up a level
        v.i2cSlaveIn.txData  := rdData((8*byteCntVar)+7 downto 8*byteCntVar);
        v.i2cSlaveIn.txValid := '1';
        if (i2cSlaveOut.txAck = '1') then
          -- Byte was sent
          v.byteCnt := r.byteCnt + 1;
          if (byteCntVar = DATA_SIZE_G - 1) then
            -- Word was sent. Increment addr to get next word, reset byteCnt
            v.rdEn    := '1';
            v.byteCnt := (others => '0');
            v.addr    := r.addr + 1;
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
    if (rstn = '0') then
      v.state := IDLE_S;
    v.byteCnt := (others => '0');
      v.addr := (others => '0');
      v.wrEn := '0';
      v.wrData := (others => '0');
      v.rdEn := '0';
      v.i2cSlaveIn.enable := '0';
      v.i2cSlaveIn.txValid := '0';
      v.i2cSlaveIn.txData := (others => '0');
      v.i2cSlaveIn.rxAck := '0';
    end if;

    ------------------------------------------------------------------------------------------------
    -- Signal Assignments
    ------------------------------------------------------------------------------------------------
    -- Update registers
    rin <= v;

    -- Internal signals
    i2cSlaveIn <= r.i2cSlaveIn;
    i2cSlaveIn.rxAck <= i2cSlaveOut.rxValid;  -- Always ack

    -- Update Outputs
    addr       <= slv(r.addr);
    wrData     <= r.wrData;
    wrEn       <= r.wrEn;
    rdEn       <= r.rdEn;
    
  end process comb;

  seq: process (clk) is
  begin
    if (rising_edge(clk)) then
      r <= rin;
    end if;
  end process seq;

end architecture rtl;
