-------------------------------------------------------------------------------
-- Title      : HTSP: https://confluence.slac.stanford.edu/x/pQmODw
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Package for HTSP Ethernet
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
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;
use surf.SsiPkg.all;

package HtspPkg is

   constant HTSP_VERSION_C : slv(7 downto 0) := x"01";

   constant HTSP_CLK_FREQ_C : real := 195.658E+6;  -- Units of Hz

   constant HTSP_AXIS_CONFIG_C : AxiStreamConfigType :=
      ssiAxiStreamConfig(
         dataBytes => (512/8),          -- 512-bit interface
         tKeepMode => TKEEP_COMP_C,
         tUserMode => TUSER_FIRST_LAST_C,
         tDestBits => 4,
         tUserBits => 2);

   type HtspTxInType is record
      disable      : sl;
      flowCntlDis  : sl;
      nullInterval : slv(31 downto 0);  -- Only used in network mode
      opCodeEn     : sl;
      opCode       : slv(127 downto 0);
      locData      : slv(127 downto 0);
   end record HtspTxInType;

   type HtspTxInArray is array (natural range<>) of HtspTxInType;

   constant HTSP_TX_IN_INIT_C : HtspTxInType := (
      disable      => '0',
      flowCntlDis  => '0',
      nullInterval => toSlv(127, 32),
      opCodeEn     => '0',
      opCode       => (others => '0'),
      locData      => (others => '0'));

   type HtspTxOutType is record
      locOverflow : slv(15 downto 0);
      locPause    : slv(15 downto 0);
      phyTxActive : sl;
      linkReady   : sl;
      opCodeReady : sl;
      frameTx     : sl;                 -- A good frame was transmitted
      frameTxErr  : sl;                 -- An error frame was transmitted
      frameTxSize : slv(15 downto 0);
   end record;

   type HtspTxOutArray is array (natural range<>) of HtspTxOutType;

   constant HTSP_TX_OUT_INIT_C : HtspTxOutType := (
      locOverflow => (others => '0'),
      locPause    => (others => '0'),
      phyTxActive => '0',
      linkReady   => '0',
      opCodeReady => '0',
      frameTx     => '0',
      frameTxErr  => '0',
      frameTxSize => (others => '0'));

   type HtspRxInType is record
      resetRx : sl;
   end record HtspRxInType;

   type HtspRxInArray is array (natural range<>) of HtspRxInType;

   constant HTSP_RX_IN_INIT_C : HtspRxInType := (
      resetRx => '0');

   type HtspRxOutType is record
      phyRxActive    : sl;
      linkReady      : sl;                 -- locRxLinkReady
      frameRx        : sl;                 -- A good frame was received
      frameRxErr     : sl;                 -- An error frame was received
      frameRxSize    : slv(15 downto 0);   -- RX frame size (units of bytes)
      linkDown       : sl;                 -- A link down event has occurred
      opCodeEn       : sl;                 -- Opcode valid
      opCode         : slv(127 downto 0);  -- Opcode data
      remLinkData    : slv(127 downto 0);  -- Far end data
      remRxLinkReady : sl;                 -- Far end RX has link
      remRxPause     : slv(15 downto 0);   -- Far end pause status
   end record HtspRxOutType;

   type HtspRxOutArray is array (natural range<>) of HtspRxOutType;

   constant HTSP_RX_OUT_INIT_C : HtspRxOutType := (
      phyRxActive    => '0',
      linkReady      => '0',
      frameRx        => '0',
      frameRxErr     => '0',
      frameRxSize    => (others => '0'),
      linkDown       => '0',
      opCodeEn       => '0',
      opCode         => (others => '0'),
      remLinkData    => (others => '0'),
      remRxLinkReady => '0',
      remRxPause     => (others => '0'));

end package HtspPkg;
