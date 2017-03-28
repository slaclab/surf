-------------------------------------------------------------------------------
-- File       : FrontEndSaciAnalogTb.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2012-10-02
-- Last update: 2013-03-01
-------------------------------------------------------------------------------
-- Description: Simple Saci testbench with Saci Master connected to the
-- standard Front End Register interface.
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
use work.StdRtlPkg.all;
use work.FrontEndPkg.all;
use work.SaciMasterPkg.all;

entity FrontEndSaciAnalogTb is

end entity FrontEndSaciAnalogTb;

architecture testbench of FrontEndSaciAnalogTb is

  constant TPD_C : time := 1 ns;

  -- Clocks and resets
  signal gtpClk    : sl;
  signal fpgaRst   : sl;
  signal pgpClk    : sl;
  signal pgpRst    : sl;
  signal saciClkIn : sl;
  signal saciRst   : sl;

  -- Front End Register Interface
  signal frontEndRegCntlIn  : FrontEndRegCntlInType;
  signal frontEndRegCntlOut : FrontEndRegCntlOutType;

  -- SACI Master Parallel Interface
  signal saciMasterIn  : SaciMasterInType;
  signal saciMasterOut : SaciMasterOutType;

  -- SACI serial interface
  signal saciClk  : sl;
  signal saciSelL : slv(SACI_NUM_SLAVES_C-1 downto 0);
  signal saciCmd  : sl;
  signal saciRsp  : sl;

  -- SACI Slave Parallel Interface
  signal asicRstL : sl;
--  signal saciSlaveRstL : sl;
--  signal exec          : sl;
--  signal ack           : sl;
--  signal readL         : sl;
--  signal cmd           : slv(6 downto 0);
--  signal addr          : slv(11 downto 0);
--  signal wrData        : slv(31 downto 0);
--  signal rdData        : slv(31 downto 0);

  
begin

  -- Create 156.25 MHz system clock and main reset
  ClkRst_1 : entity work.ClkRst
    generic map (
      CLK_PERIOD_G      => 6.4 ns,
      RST_START_DELAY_G => 1 ns,
      RST_HOLD_TIME_G   => 6 us)
    port map (
      clkP => gtpClk,
      clkN => open,
      rst  => fpgaRst,
      rstL => open);

  -- Create 1 MHz SACI Serial Clock
  ClkRst_2 : entity work.ClkRst
    generic map (
      CLK_PERIOD_G => 1 us)
    port map (
      clkP => saciClkIn,
      clkN => open,
      rst  => open,
      rstL => open);

  -- Synchronize main reset to sysClk125
  RstSync_1 : entity work.RstSync
    generic map (
      DELAY_G => TPD_C)
    port map (
      clk      => pgpClk,
      asyncRst => saciRst,              -- Wait until slower SACI rst is done to release pgp rst
      syncRst  => pgpRst);

  -- Synchronize main reset to SACI serial clock
  RstSync_2 : entity work.RstSync
    generic map (
      DELAY_G => TPD_C)
    port map (
      clk      => saciClkIn,
      asyncRst => fpgaRst,
      syncRst  => saciRst);

  --------------------------------------------------------------------------------------------------

  -- Front End register interface
  Pgp2FrontEnd_1 : entity work.Pgp2FrontEnd
    port map (
      pgpRefClk    => gtpClk,
      pgpRefClkOut => pgpClk,
      pgpClk       => pgpClk,
      pgpClk2x     => '0',              -- Not used in sim variant
      pgpReset     => pgpRst,
      locClk       => pgpClk,
      locReset     => pgpRst,
      regReq       => frontEndRegCntlOut.regReq,
      regOp        => frontEndRegCntlOut.regOp,
      regInp       => frontEndRegCntlOut.regInp,
      regAck       => frontEndRegCntlIn.regAck,
      regFail      => frontEndRegCntlIn.regFail,
      regAddr      => frontEndRegCntlOut.regAddr,
      regDataOut   => frontEndRegCntlOut.regDataOut,
      regDataIn    => frontEndRegCntlIn.regDataIn,
      pgpRxN       => '0',
      pgpRxP       => '0',
      pgpTxN       => open,
      pgpTxP       => open);

  -- Register Decoder
  FrontEndRegDecoder_1 : entity work.FrontEndRegDecoder
    generic map (
      DELAY_G => TPD_C)
    port map (
      sysClk             => pgpClk,
      sysRst             => pgpRst,
      frontEndRegCntlOut => frontEndRegCntlOut,
      frontEndRegCntlIn  => frontEndRegCntlIn,
      saciMasterIn       => saciMasterIn,
      saciMasterOut      => saciMasterOut);

  SaciMaster_1 : entity work.SaciMaster
    generic map (
      TPD_G                 => TPD_C,
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

  -- End of FPGA Side
  --------------------------------------------------------------------------------------------------

  -- ASIC Side
  -- Create Asic Reset
  ClkRst_3 : entity work.ClkRst
    generic map (
      RST_START_DELAY_G => 1 ns,
      RST_HOLD_TIME_G   => 6 us)
    port map (
      clkP => open,
      clkN => open,
      rst  => open,
      rstL => asicRstL);


  SaciSlaveWrapper_0 : entity work.SaciSlaveWrapper
    port map (
      asicRstL => asicRstL,
      saciClk  => saciClk,
      saciSelL => saciSelL(0),
      saciCmd  => saciCmd,
      saciRsp  => saciRsp);

  SaciSlaveWrapper_1 : entity work.SaciSlaveWrapper
    port map (
      asicRstL => asicRstL,
      saciClk  => saciClk,
      saciSelL => saciSelL(1),
      saciCmd  => saciCmd,
      saciRsp  => saciRsp);




end architecture testbench;
