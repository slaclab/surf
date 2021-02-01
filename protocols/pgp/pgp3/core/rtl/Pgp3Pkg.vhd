-------------------------------------------------------------------------------
-- Title      : PGPv3: https://confluence.slac.stanford.edu/x/OndODQ
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: PGPv3 Support Package
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

package Pgp3Pkg is

   constant PGP3_VERSION_C : slv(2 downto 0) := "011";

   constant PGP3_DEFAULT_TX_CELL_WORDS_MAX_C : positive := 128;  -- Number of 64-bit words per cell

   constant PGP3_AXIS_CONFIG_C : AxiStreamConfigType :=
      ssiAxiStreamConfig(
         dataBytes => 8,
         tKeepMode => TKEEP_COMP_C,
         tUserMode => TUSER_FIRST_LAST_C,
         tDestBits => 4,
         tUserBits => 2);

   -- Define K code BTFs
   constant PGP3_IDLE_C : slv(7 downto 0)   := X"99";
   constant PGP3_SOF_C  : slv(7 downto 0)   := X"AA";
   constant PGP3_EOF_C  : slv(7 downto 0)   := X"55";
   constant PGP3_SOC_C  : slv(7 downto 0)   := X"CC";
   constant PGP3_EOC_C  : slv(7 downto 0)   := X"33";
   constant PGP3_SKP_C  : slv(7 downto 0)   := X"66";
   constant PGP3_USER_C : Slv8Array(0 to 7) := (X"78", X"87", X"2D", X"D2", X"1E", X"E1", X"B4", X"4B");

   constant PGP3_VALID_BTF_ARRAY_C : Slv8Array := (
      0  => PGP3_IDLE_C,
      1  => PGP3_SOF_C,
      2  => PGP3_EOF_C,
      3  => PGP3_SOC_C,
      4  => PGP3_EOC_C,
      5  => PGP3_SKP_C,
      6  => PGP3_USER_C(0),
      7  => PGP3_USER_C(1),
      8  => PGP3_USER_C(2),
      9  => PGP3_USER_C(3),
      10 => PGP3_USER_C(4),
      11 => PGP3_USER_C(5),
      12 => PGP3_USER_C(6),
      13 => PGP3_USER_C(7));

   constant PGP3_D_HEADER_C : slv(1 downto 0) := "01";
   constant PGP3_K_HEADER_C : slv(1 downto 0) := "10";

   constant PGP3_SCRAMBLER_TAPS_C : IntegerArray(0 to 1) := (0 => 39, 1 => 58);

   subtype PGP3_BTF_FIELD_C is natural range 63 downto 56;
   subtype PGP3_LINKINFO_FIELD_C is natural range 39 downto 0;
   subtype PGP3_SOFC_VC_FIELD_C is natural range 43 downto 40;
   subtype PGP3_SOFC_SEQ_FIELD_C is natural range 55 downto 44;
   subtype PGP3_EOFC_TUSER_FIELD_C is natural range 7 downto 0;
   subtype PGP3_EOFC_BYTES_LAST_FIELD_C is natural range 19 downto 16;
   subtype PGP3_EOFC_CRC_FIELD_C is natural range 55 downto 24;
   subtype PGP3_USER_CHECKSUM_FIELD_C is natural range 55 downto 48;
   subtype PGP3_USER_OPCODE_FIELD_C is natural range 47 downto 0;
   subtype PGP3_SKIP_DATA_FIELD_C is natural range 55 downto 0;

   constant PGP3_CRC_POLY_C : slv(31 downto 0) := X"04C11DB7";

   function pgp3MakeLinkInfo (
      locRxFifoCtrl  : AxiStreamCtrlArray;
      locRxLinkReady : sl)
      return slv;

   procedure pgp3ExtractLinkInfo (
      linkInfo       : in    slv(39 downto 0);
      remRxFifoCtrl  : inout AxiStreamCtrlArray;
      remRxLinkReady : inout sl;
      version        : inout slv(2 downto 0));

   function pgp3OpCodeChecksum (
      opCodeData : slv(47 downto 0))
      return slv;


   type Pgp3TxInType is record
      disable      : sl;
      flowCntlDis  : sl;
      resetTx      : sl;
      skpInterval  : slv(31 downto 0);
      opCodeEn     : sl;
      opCodeNumber : slv(2 downto 0);
      opCodeData   : slv(47 downto 0);
      locData      : slv(55 downto 0);
   end record Pgp3TxInType;

   type Pgp3TxInArray is array (natural range<>) of Pgp3TxInType;

   constant PGP3_TX_IN_INIT_C : Pgp3TxInType := (
      disable      => '0',
      flowCntlDis  => '0',
      resetTx      => '0',
      skpInterval  => toSlv(5000, 32),
      opCodeEn     => '0',
      opCodeNumber => (others => '0'),
      opCodeData   => (others => '0'),
      locData      => (others => '0'));


   type Pgp3TxOutType is record
      locOverflow : slv(15 downto 0);
      locPause    : slv(15 downto 0);
      phyTxActive : sl;
      linkReady   : sl;
      opCodeReady : sl;
      frameTx     : sl;                 -- A good frame was transmitted
      frameTxErr  : sl;                 -- An errored frame was transmitted
   end record;

   type Pgp3TxOutArray is array (natural range<>) of Pgp3TxOutType;

   constant PGP3_TX_OUT_INIT_C : Pgp3TxOutType := (
      locOverflow => (others => '0'),
      locPause    => (others => '0'),
      phyTxActive => '0',
      linkReady   => '0',
      opCodeReady => '0',
      frameTx     => '0',
      frameTxErr  => '0');

   type Pgp3RxInType is record
      loopback : slv(2 downto 0);
      resetRx  : sl;
   end record Pgp3RxInType;

   type Pgp3RxInArray is array (natural range<>) of Pgp3RxInType;

   constant PGP3_RX_IN_INIT_C : Pgp3RxInType := (
      loopback => (others => '0'),
      resetRx  => '0');


   type Pgp3RxOutType is record
      phyRxActive    : sl;
      linkReady      : sl;                -- locRxLinkReady
      frameRx        : sl;                -- A good frame was received
      frameRxErr     : sl;                -- An errored frame was received
      cellError      : sl;                -- A cell error has occured
      linkDown       : sl;                -- A link down event has occured
      linkError      : sl;                -- A link error has occured
      opCodeEn       : sl;                -- Opcode valid
      opCodeNumber   : slv(2 downto 0);   -- Opcode number
      opCodeData     : slv(47 downto 0);  -- Opcode data
      remLinkData    : slv(55 downto 0);  -- Far end side User Data
      remRxLinkReady : sl;                -- Far end RX has link
      remRxOverflow  : slv(15 downto 0);  -- Far end RX overflow status
      remRxPause     : slv(15 downto 0);  -- Far end pause status

      phyRxData   : slv(63 downto 0);
      phyRxHeader : slv(1 downto 0);
      phyRxValid  : sl;
      phyRxInit   : sl;

      gearboxAligned : sl;

      ebData     : slv(63 downto 0);
      ebHeader   : slv(1 downto 0);
      ebValid    : sl;
      ebOverflow : sl;
      ebStatus   : slv(8 downto 0);
   end record Pgp3RxOutType;

   type Pgp3RxOutArray is array (natural range<>) of Pgp3RxOutType;

   constant PGP3_RX_OUT_INIT_C : Pgp3RxOutType := (
      phyRxActive    => '0',
      linkReady      => '0',
      frameRx        => '0',
      frameRxErr     => '0',
      cellError      => '0',
      linkDown       => '0',
      linkError      => '0',
      opCodeEn       => '0',
      opCodeNumber   => (others => '0'),
      opCodeData     => (others => '0'),
      remLinkData    => (others => '0'),
      remRxLinkReady => '0',
      remRxOverflow  => (others => '0'),
      remRxPause     => (others => '0'),
      phyRxData      => (others => '0'),
      phyRxHeader    => (others => '0'),
      phyRxValid     => '0',
      phyRxInit      => '0',
      gearboxAligned => '0',
      ebData         => (others => '0'),
      ebHeader       => (others => '0'),
      ebValid        => '0',
      ebOverflow     => '0',
      ebStatus       => (others => '0'));

end package Pgp3Pkg;

package body Pgp3Pkg is

   function pgp3MakeLinkInfo (
      locRxFifoCtrl  : AxiStreamCtrlArray;
      locRxLinkReady : sl)
      return slv
   is
      variable ret : slv(39 downto 0) := (others => '0');
   begin
      for i in locRxFifoCtrl'range loop
         ret(i)    := locRxFifoCtrl(i).pause;
         ret(i+16) := locRxFifoCtrl(i).overflow;
      end loop;
      ret(32)           := locRxLinkReady;
      ret(35 downto 33) := PGP3_VERSION_C;
      return ret;
   end function;

   procedure pgp3ExtractLinkInfo (
      linkInfo       : in    slv(39 downto 0);
      remRxFifoCtrl  : inout AxiStreamCtrlArray;
      remRxLinkReady : inout sl;
      version        : inout slv(2 downto 0)) is
   begin
      for i in remRxFifoCtrl'range loop
         remRxFifoCtrl(i).pause    := linkInfo(i);
         remRxFifoCtrl(i).overflow := linkInfo(i+16);
      end loop;
      remRxLinkReady := linkInfo(32);
      version        := linkInfo(35 downto 33);
   end procedure;

   function pgp3OpCodeChecksum (
      opCodeData : slv(47 downto 0))
      return slv
   is
      variable ret : slv(7 downto 0);
   begin
      ret := not (opCodeData(7 downto 0) +
                  opCodeData(15 downto 8) +
                  opCodeData(23 downto 16) +
                  opCodeData(31 downto 24) +
                  opCodeData(39 downto 32) +
                  opCodeData(47 downto 40));
      return ret;
   end function;

end package body Pgp3Pkg;
