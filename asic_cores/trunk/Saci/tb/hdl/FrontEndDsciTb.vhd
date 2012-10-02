-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : FrontEndDsciTb.vhd
-- Author     : Benjamin Reese  <bareese@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2012-10-02
-- Last update: 2012-10-02
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Simple Dsci testbench with Dsci Master connected to the
-- standard Front End Register interface.
-------------------------------------------------------------------------------
-- Copyright (c) 2012 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use work.StdRtlPkg.all;

entity FrontEndDsciTb is

end entity FrontEndDsciTb;

architecture testbench of FrontEndDsciTb is

  -- Clocks and resets
  signal gtpClk    : sl;
  signal fpgaRst   : sl;
  signal sysClk125 : sl;
  signal sysRst125 : sl;
  signal saciClkIn : sl;
  signal saciRst   : sl;

  -- Front End Register Interface
  signal regReq     : sl;
  signal regOp      : sl;
  signal regInp     : sl;
  signal regAck     : sl;
  signal regFail    : sl;
  signal regAddr    : sl;
  signal regDataOut : slv(31 downto 0);
  signal regDataIn  : sl(31 downto 0);

  -- SACI Master Parallel Interface
  signal saciMasterIn  : SaciMasterInType;
  signal saciMasterOut : SaciMasterOutType;

  -- SACI serial interface
  signal saciClk  : sl;
  signal saciSelL : sl;
  signal saciCmd  : sl;
  signal saciRsp  : sl;

  -- SACI Slave Parallel Interface
  signal asicRstL      : sl;
  signal saciSlaveRstL : sl;
  signal exec          : sl;
  signal ack           : sl;
  signal readL         : sl;
  signal cmd           : sl;
  signal addr          : sl;
  signal wrData        : sl;
  signal rdData        : sl;

  
begin

  -- Create 125 MHz system clock and main reset
  ClkRstBfm_1 : entity work.ClkRstBfm
    generic map (
      CLK_FREQUENCY_G   => 125 Mhz,
      RST_START_DELAY_G => 1 ns,
      RST_HOLD_TIME_G   => 6 us)
    port map (
      clkP => gtpClk,
      clkN => open,
      rst  => fpgaRst,
      rstL => open);

  -- Create 1 MHz SACI Serial Clock
  ClkRstBfm_1 : entity work.ClkRstBfm
    generic map (
      CLK_FREQUENCY_G => 1 Mhz)
    port map (
      clkP => saciClkIn,
      clkN => open,
      rst  => open,
      rstL => open);

  -- Synchronize main reset to sysClk125
  RstSync_1 : entity work.RstSync
    generic map (
      DELAY_G => 1 ns)
    port map (
      clk      => sysClk125,
      asyncRst => fpgaRst,
      syncRst  => sysRst125);

  -- Synchronize main reset to SACI serial clock
  RstSync_1 : entity work.RstSync
    generic map (
      DELAY_G => 1 ns)
    port map (
      clk      => saciClkIn,
      asyncRst => fpgaRst,
      syncRst  => saciRst);

  -- Front End register interface
  EthFrontEnd_1 : entity work.EthFrontEnd
    port map (
      gtpClk        => gtpClk,
      gtpClkRst     => sysRst125,
      gtpRefClk     => sysClk125,
      gtpRefClkOut  => sysClk125,
      cmdEn         => open,
      cmdOpCode     => open,
      cmdCtxOut     => open,
      regReq        => regReq,
      regOp         => regOp,
      regInp        => regInp,
      regAck        => regAck,
      regFail       => regFail,
      regAddr       => regAddr,
      regDataOut    => regDataOut,
      regDataIn     => regDataIn,
      frameTxEnable => '0',
      frameTxSOF    => '0',
      frameTxEOF    => '0',
      frameTxAfull  => open,
      frameTxData   => (others => '0'),
      gtpRxN        => '0',
      gtpRxP        => '0',
      gtpTxN        => open,
      gtpTxP        => open);

  -- Tie Front End Registers to SaciMaster interface
  saciMasterIn.req <= regReq;
  saciMasterIn.reset <= regReq and regAddr(23) and regOp;
  saciMasterIn.cmd <= regAddr(6 downto 0);
  saciMasterIn.addr <= regAddr(18 downto 7);
  saciMasterIn.chip <= regAddr(SACI_CHIP_WIDTH_C+19 downto 19);
  saciMasterIn.wrData <= regDataOut;
  regAck <= saciMasterOut.ack;
  regFail <= saciMasterOut.fail;
  regDataIn <= saciMasterOut.rdData;

  
  SaciMaster_1 : entity work.SaciMaster
    generic map (
      TPD_G                 => 1 ns,
      SYNCHRONIZE_CONTROL_G => true)
    port map (
      clk           => saciClkIn,
      rst           => saciRst,
      saciClk       => saciClk,
      saciSelL      => saciSelL,
      saciCmd       => saciCmd,
      saciRsp       => saciRsp,
      saciMasterIn  => saciMasterIn,
      saciMasterOut => saciMasterOut);

  SaciSlave_1 : entity work.SaciSlave
    generic map (
      TPD_G => TPD_G)
    port map (
      rstL     => asicRstL,
      saciClk  => saciClk,
      saciSelL => saciSelL,
      saciCmd  => saciCmd,
      saciRsp  => saciRsp,
      rstOutL  => saciSlaveRstL,
      rstInL   => saciSlaveRstL,
      exec     => exec,
      ack      => ack,
      readL    => readL,
      cmd      => cmd,
      addr     => addr,
      wrData   => wrData,
      rdData   => rdData);

  DsciSlaveRam_1 : entity work.DsciSlaveRam
    port map (
      dsciClkOut => saciClk,
      exec       => exec,
      ack        => ack,
      readN      => readN,
      cmd        => cmd,
      addr       => addr,
      wrData     => wrData,
      rdData     => rdData);

end architecture testbench;
