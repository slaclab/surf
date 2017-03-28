-------------------------------------------------------------------------------
-- File       : i2cRegTb.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-01-24
-- Last update: 2013-01-28
-------------------------------------------------------------------------------
-- Description: Simulation testbed for i2cReg
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
use work.i2cPkg.all;
use work.i2cRegMasterPkg.all;

entity i2cRegTb is

end entity i2cRegTb;

architecture tb of i2cRegTb is

  constant TPD_C : time := 1 ns;

  signal masterClk : sl;
  signal masterRst : sl;

  signal slaveClk : slv(15 downto 0);
  signal slaveRst : slv(15 downto 0);

  signal regIn  : i2cRegMasterInType;
  signal regOut : i2cRegMasterOutType;
  signal i2ci   : i2c_in_type;
  signal i2co   : i2c_out_type;

  signal i2cSda : sl;
  signal i2cScl : sl;

begin

  --------------------------------------------------------------------------------------------------
  -- Master
  --------------------------------------------------------------------------------------------------
  -- Create Master clock and reset
  ClkRst_Master : entity work.ClkRst
    generic map (
      CLK_PERIOD_G      => 8 ns,
      RST_START_DELAY_G => 0 ns,
      RST_HOLD_TIME_G   => 5 us,
      SYNC_RESET_G      => true)
    port map (
      clkP => masterClk,
      clkN => open,
      rst  => masterRst,
      rstL => open);

  -- Instantiate Master
  i2cRegMaster_1 : entity work.i2cRegMaster
    generic map (
      TPD_G                => TPD_C,
      OUTPUT_EN_POLARITY_G => 0,
      FILTER_G             => 2,
      PRESCALE_G           => 62)       -- 400 kHz clk
    port map (
      clk    => masterClk,
      rst    => masterRst,
      regIn  => regIn,
      regOut => regOut,
      i2ci   => i2ci,
      i2co   => i2co);

  -- Tristate i2c io with pullups
  i2cSda   <= i2co.sda when i2co.sdaoen = '0' else 'H';
  i2ci.sda <= i2cSda;

  i2cScl   <= i2co.scl when i2co.scloen = '0' else 'H';
  i2ci.scl <= i2cScl;

  --------------------------------------------------------------------------------------------------
  -- Slaves
  -- Instantiate 16 Ram slaves on the bus with varying address and data sizes, and varying i2c
  -- addresses and clock speeds.
  --------------------------------------------------------------------------------------------------
--  gen_i : for i in 0 to 3 generate
--    gen_j : for j in 0 to 3 generate

--      ClkRst_Slave : entity work.ClkRst
--        generic map (
--          CLK_PERIOD_G      => (8+i)* 1 ns,
--          CLK_DELAY_G       => j * 1 ns,
--          RST_START_DELAY_G => 0 ns,
--          RST_HOLD_TIME_G   => 5 us,
--          SYNC_RESET_G      => true)
--        port map (
--          clkP => slaveClk(i*4+j),
--          clkN => open,
--          rst  => slaveRst(i*4+j),
--          rstL => open);

--      i2cRamSlave_1 : entity work.i2cRamSlave
--        generic map (
--          TPD_G        => TPD_C,
--          I2C_ADDR_G   => (i*4+j)*4+9,
--          TENBIT_G     => 0, --(j = 3),
--          FILTER_G     => 10, --integer((50.0 / (8.0+i)) + 2.0),
--          ADDR_SIZE_G  => i+1,
--          DATA_SIZE_G  => j+1,
--          ENDIANNESS_G => 0) --i = 2 or i = 3)
--        port map (
--          clk    => slaveClk(i*4+j),
--          rst    => slaveRst(i*4+j),
--          i2cSda => i2cSda,
--          i2cScl => i2cScl);

--    end generate gen_j;
--  end generate gen_i;

  ClkRst_Slave : entity work.ClkRst
    generic map (
      CLK_PERIOD_G      => 9 ns,
      CLK_DELAY_G       => 1 ns,
      RST_START_DELAY_G => 0 ns,
      RST_HOLD_TIME_G   => 5 us,
      SYNC_RESET_G      => true)
    port map (
      clkP => slaveClk(0),
      clkN => open,
      rst  => slaveRst(0),
      rstL => open);

  i2cRamSlave_1 : entity work.i2cRamSlave
    generic map (
      TPD_G        => TPD_C,
      I2C_ADDR_G   => 85,
      TENBIT_G     => 0,                --(j = 3),
      FILTER_G     => 2,                --integer((50.0 / (8.0+i)) + 2.0),
      ADDR_SIZE_G  => 2,
      DATA_SIZE_G  => 1,
      ENDIANNESS_G => 0)                --i = 2 or i = 3)
    port map (
      clk    => slaveClk(0),
      rst    => slaveRst(0),
      i2cSda => i2cSda,
      i2cScl => i2cScl);


  sim : process is
    variable i2cAddr   : slv(6 downto 0);
    variable tenbit    : boolean;
    variable regAddr   : slv(15 downto 0);
    variable regRdData : Slv8Array(0 to 3);
    variable regWrData : Slv8Array(0 to 3);
  begin
    wait until masterRst = '1';
    wait until masterRst = '0';

    i2cAddr := "1010101";               -- 25 = i=1, j=0
--    for i in 99 to 120 loop
--      regAddr   := slv(to_unsigned(i, regAddr'length));
--      regWrData := slv(to_unsigned(i, regWrData'length));
--      writeI2cReg(masterClk, regIn, regOut, i2cAddr, regAddr, regWrData, '1', true);
--    --wait for 10 us;
--    end loop;


--    wait for 100 us;


--    for i in 99 to 120 loop
--      regAddr := slv(to_unsigned(i, regAddr'length));
--      readI2cReg(masterClk, regIn, regOut, i2cAddr, regAddr, regRdData, '1', true);
--    end loop;

    regAddr := (others => '0');
    regWrData := (0 => X"11", 1 => X"22", 2 => X"33", 3 => X"44");
    writeI2cBurst8(masterClk, regIn, regOut, i2cAddr, regAddr, regWrData, '0', true);

    readI2cBurst8(masterClk, regIn, regOut, i2cAddr, regAddr, regRdData, '0', true);


  end process;

end architecture tb;
