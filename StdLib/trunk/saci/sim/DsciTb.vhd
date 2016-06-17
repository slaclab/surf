-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : DsciTb.vhd
-- Author     : Benjamin Reese  <bareese@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2012-09-19
-- Last update: 2012-09-20
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2012 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use ieee.numeric_std.all;
use work.StdRtlPkg.all;
use work.std_sim_p.all;
use work.txt_util_p.all;
use work.DsciMasterPkg.all;
use work.DsciMasterTbPkg.all;

entity DsciTb is

end entity DsciTb;

architecture behavioral of DsciTb is

  constant TPD_G : time := 1 ns;

  signal clk : sl;
  signal rst : sl;

  signal dsciClk  : sl;
  signal dsciSelN : slv(DSCI_NUM_SLAVES_C-1 downto 0);
  signal dsciCmd  : sl;
  signal dsciRsp  : sl;

  signal dsciMasterIn  : DsciMasterInType;
  signal dsciMasterOut : DsciMasterOutType;

  signal dsciClkOut : sl;
  signal exec       : sl;
  signal ack        : sl;
  signal readN      : sl;
  signal cmd        : slv(6 downto 0);
  signal addr       : slv(11 downto 0);
  signal data       : slv(31 downto 0);

begin

  clk_rst_bfm_1 : entity work.clk_rst_bfm
    generic map (
      CLK_FREQUENCY_G   => 1 Mhz,
      RST_START_DELAY_G => 1 ns,
      RST_HOLD_TIME_G   => 6 us)
    port map (
      clk_p => clk,
      clk_n => open,
      rst   => rst,
      rst_l => open);

  DsciMaster_1 : entity work.DsciMaster
    generic map (
      TPD_G => TPD_G)
    port map (
      clk           => clk,
      rst           => rst,
      dsciClk       => dsciClk,
      dsciSelN      => dsciSelN,
      dsciCmd       => dsciCmd,
      dsciRsp       => dsciRsp,
      dsciMasterIn  => dsciMasterIn,
      dsciMasterOut => dsciMasterOut);

  DsciSlave_1 : entity work.DsciSlave
    generic map (
      TPD_G => TPD_G)
    port map (
      rst        => rst,
      dsciClk    => dsciClk,
      dsciSelN   => dsciSelN(0),
      dsciCmd    => dsciCmd,
      dsciRsp    => dsciRsp,
      dsciClkOut => dsciClkOut,
      exec       => exec,
      ack        => ack,
      readN      => readN,
      cmd        => cmd,
      addr       => addr,
      data       => data);

  DsciSlaveRam_1 : entity work.DsciSlaveRam
    port map (
      dsciClkOut => dsciClkOut,
      exec       => exec,
      ack        => ack,
      readN      => readN,
      cmd        => cmd,
      addr       => addr,
      data       => data);

  process is
    variable chipV   : slv(DSCI_CHIP_WIDTH_C-1 downto 0) := (others => '0');
    variable cmdV    : slv(6 downto 0);
    variable addrV   : slv(11 downto 0);
    variable wrDataV : slv(31 downto 0);
    variable rdDataV : slv(31 downto 0);
  begin
    dsciMasterIn <= DSCI_MASTER_ZERO_C;
    wait until rst = '1';
    wait until rst = '0';
    wait for 10 us;

    dsciReset(dsciMasterIn, dsciMasterOut);

    addrV   := X"123";
    cmdV    := "0101010";
    wrDataV := X"AAAAAAAA";
               

    wait for 100 us;
    dsciWrite(dsciMasterIn, dsciMasterOut, chipV, cmdV, addrV, wrDataV);
    wait for 5 us;
    dsciRead(dsciMasterIn, dsciMasterOut, chipV, cmdV, addrV, rdDataV);
    assert (wrDataV = rdDataV) report "Mismatch! " & hstr(wrDataV) & " " & hstr(rdDatav) severity warning;
    wait for 5 us;
    
    for i in 0 to 31 loop
      addrV   := slv(to_unsigned(i, addrV'length));
      cmdV    := slv(to_unsigned(i, cmdV'length));
      wrDataV := slv(to_unsigned(i, wrDataV'length));
      dsciWrite(dsciMasterIn, dsciMasterOut, chipV, cmdV, addrV, wrDataV);
      wait for 5 us;
      dsciRead(dsciMasterIn, dsciMasterOut, chipV, cmdV, addrV, rdDataV);
      assert (wrDataV = rdDataV) report "Mismatch! " & hstr(wrDataV) & " " & hstr(rdDatav) severity warning;
      wait for 5 us;
    end loop;

  end process;

end architecture behavioral;
