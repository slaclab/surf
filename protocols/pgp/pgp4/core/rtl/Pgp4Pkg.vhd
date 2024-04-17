-------------------------------------------------------------------------------
-- Title      : PGPv4: https://confluence.slac.stanford.edu/x/1dzgEQ
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: PGPv4 Support Package
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

package Pgp4Pkg is

   constant PGP4_VERSION_C : slv(7 downto 0) := toSlv(4, 8);  -- Version = 0x04

   constant PGP4_DEFAULT_TX_CELL_WORDS_MAX_C : positive := 128;  -- Number of 64-bit words per cell

   constant PGP4_AXIS_CONFIG_C : AxiStreamConfigType :=
      ssiAxiStreamConfig(
         dataBytes => 8,
         tKeepMode => TKEEP_COMP_C,
         tUserMode => TUSER_FIRST_LAST_C,
         tDestBits => 4,
         tUserBits => 2);

   -- Define K code BTFs
   constant PGP4_IDLE_C : slv(7 downto 0) := X"99";
   constant PGP4_SOF_C  : slv(7 downto 0) := X"AA";
   constant PGP4_EOF_C  : slv(7 downto 0) := X"55";
   constant PGP4_SOC_C  : slv(7 downto 0) := X"CC";
   constant PGP4_EOC_C  : slv(7 downto 0) := X"33";
   constant PGP4_SKP_C  : slv(7 downto 0) := X"66";
   constant PGP4_USER_C : slv(7 downto 0) := X"78";

   constant PGP4_VALID_BTF_ARRAY_C : Slv8Array := (
      0 => PGP4_IDLE_C,
      1 => PGP4_SOF_C,
      2 => PGP4_EOF_C,
      3 => PGP4_SOC_C,
      4 => PGP4_EOC_C,
      5 => PGP4_SKP_C,
      6 => PGP4_USER_C);

   constant PGP4_D_HEADER_C : slv(1 downto 0) := "01";
   constant PGP4_K_HEADER_C : slv(1 downto 0) := "10";

   constant PGP4_SCRAMBLER_TAPS_C : IntegerArray(0 to 1) := (0 => 39, 1 => 58);

   subtype PGP4_BTF_FIELD_C is natural range 63 downto 56;
   subtype PGP4_K_CODE_CRC_FIELD_C is natural range 55 downto 48;
   subtype PGP4_SKIP_DATA_FIELD_C is natural range 47 downto 0;
   subtype PGP4_USER_OPCODE_FIELD_C is natural range 47 downto 0;

   subtype PGP4_LINKINFO_FIELD_C is natural range 31 downto 0;
   subtype PGP4_SOFC_VC_FIELD_C is natural range 35 downto 32;
   subtype PGP4_SOFC_SEQ_FIELD_C is natural range 47 downto 36;

   subtype PGP4_EOFC_TUSER_FIELD_C is natural range 7 downto 0;
   subtype PGP4_EOFC_BYTES_LAST_FIELD_C is natural range 15 downto 12;
   subtype PGP4_EOFC_CRC_FIELD_C is natural range 47 downto 16;

   constant PGP4_CRC_POLY_C : slv(31 downto 0) := X"04C11DB7";

   function pgp4MakeLinkInfo (
      locRxFifoCtrl  : AxiStreamCtrlArray;
      locRxLinkReady : sl)
      return slv;

   procedure pgp4ExtractLinkInfo (
      linkInfo       : in    slv(PGP4_LINKINFO_FIELD_C);
      remRxFifoCtrl  : inout AxiStreamCtrlArray;
      remRxLinkReady : inout sl;
      version        : inout slv(7 downto 0));

   function pgp4KCodeCrc (
      kCodeWord : slv(63 downto 0))
      return slv;

   type Pgp4TxInType is record
      disable     : sl;
      flowCntlDis : sl;
      resetTx     : sl;
      skpInterval : slv(31 downto 0);
      opCodeEn    : sl;
      opCodeData  : slv(47 downto 0);
      locData     : slv(47 downto 0);
   end record Pgp4TxInType;
   type Pgp4TxInArray is array (natural range<>) of Pgp4TxInType;
   constant PGP4_TX_IN_INIT_C : Pgp4TxInType := (
      disable     => '0',
      flowCntlDis => '0',
      resetTx     => '0',
      skpInterval => toSlv(5000, 32),
      opCodeEn    => '0',
      opCodeData  => (others => '0'),
      locData     => (others => '0'));

   type Pgp4TxOutType is record
      locPause    : slv(15 downto 0);
      locOverflow : slv(15 downto 0);
      phyTxActive : sl;
      linkReady   : sl;
      opCodeReady : sl;
      frameTx     : sl;                 -- A good frame was transmitted
      frameTxErr  : sl;                 -- An errored frame was transmitted
   end record;
   type Pgp4TxOutArray is array (natural range<>) of Pgp4TxOutType;
   constant PGP4_TX_OUT_INIT_C : Pgp4TxOutType := (
      locPause    => (others => '0'),
      locOverflow => (others => '0'),
      phyTxActive => '0',
      linkReady   => '0',
      opCodeReady => '0',
      frameTx     => '0',
      frameTxErr  => '0');

   type Pgp4RxInType is record
      loopback : slv(2 downto 0);
      resetRx  : sl;
   end record Pgp4RxInType;
   type Pgp4RxInArray is array (natural range<>) of Pgp4RxInType;
   constant PGP4_RX_IN_INIT_C : Pgp4RxInType := (
      loopback => (others => '0'),
      resetRx  => '0');

   type Pgp4RxOutType is record
      phyRxActive      : sl;
      phyRxInit        : sl;
      gearboxAligned   : sl;
      linkReady        : sl;                -- locRxLinkReady
      remRxLinkReady   : sl;                -- Far end RX has link
      frameRx          : sl;                -- A good frame was received
      frameRxErr       : sl;                -- An errored frame was received
      linkDown         : sl;                -- A link down event has occurred
      linkError        : sl;                -- A link error has occurred
      ebOverflow       : sl;
      opCodeEn         : sl;                -- Opcode valid
      opCodeData       : slv(47 downto 0);  -- Opcode data
      remLinkData      : slv(47 downto 0);  -- Far end side User Data
      remRxOverflow    : slv(15 downto 0);  -- Far end RX overflow status
      remRxPause       : slv(15 downto 0);  -- Far end pause status
      cellError        : sl;                -- A cell error has occurred
      cellSofError     : sl;
      cellSeqError     : sl;
      cellVersionError : sl;
      cellCrcModeError : sl;
      cellCrcError     : sl;
      cellEofeError    : sl;
   end record Pgp4RxOutType;
   type Pgp4RxOutArray is array (natural range<>) of Pgp4RxOutType;
   constant PGP4_RX_OUT_INIT_C : Pgp4RxOutType := (
      phyRxActive      => '0',
      phyRxInit        => '0',
      gearboxAligned   => '0',
      linkReady        => '0',
      remRxLinkReady   => '0',
      frameRx          => '0',
      frameRxErr       => '0',
      linkDown         => '0',
      linkError        => '0',
      ebOverflow       => '0',
      opCodeEn         => '0',
      opCodeData       => (others => '0'),
      remLinkData      => (others => '0'),
      remRxOverflow    => (others => '0'),
      remRxPause       => (others => '0'),
      cellError        => '0',
      cellSofError     => '0',
      cellSeqError     => '0',
      cellVersionError => '0',
      cellCrcModeError => '0',
      cellCrcError     => '0',
      cellEofeError    => '0');

end package Pgp4Pkg;

package body Pgp4Pkg is

   function pgp4MakeLinkInfo (
      locRxFifoCtrl  : AxiStreamCtrlArray;
      locRxLinkReady : sl)
      return slv
   is
      variable ret : slv(PGP4_LINKINFO_FIELD_C) := (others => '0');
   begin
      ret(7 downto 0) := PGP4_VERSION_C;
      ret(8)          := locRxLinkReady;
      for i in locRxFifoCtrl'range loop
         ret(i+16) := locRxFifoCtrl(i).pause;
      end loop;
      return ret;
   end function;

   procedure pgp4ExtractLinkInfo (
      linkInfo       : in    slv(PGP4_LINKINFO_FIELD_C);
      remRxFifoCtrl  : inout AxiStreamCtrlArray;
      remRxLinkReady : inout sl;
      version        : inout slv(7 downto 0)) is
   begin
      version        := linkInfo(7 downto 0);
      remRxLinkReady := linkInfo(8);
      for i in remRxFifoCtrl'range loop
         remRxFifoCtrl(i).pause := linkInfo(i+16);
      end loop;
   end procedure;

   function pgp4KCodeCrc (
      kCodeWord : slv(63 downto 0))
      return slv
   is
      constant CRC_POLY_C : slv(7 downto 0) := X"07";

      variable data : slv(55 downto 0);
      variable fb   : slv(7 downto 0);
      variable ret  : slv(7 downto 0) := (others => '1');
   begin

      -- Gather the non-contiguous input bits
      data(47 downto 0)  := kCodeWord(47 downto 0);
      data(55 downto 48) := kCodeWord(63 downto 56);

      -- Reverse the input
      data := bitReverse(data);

      -- Apply the CRC algorithm
      for d in 0 to 55 loop
         fb  := (others => (ret(7) xor data(d)));
         ret := ret(6 downto 0) & fb(0);
         ret := (fb and CRC_POLY_C) xor ret;
      end loop;

      -- Transpose and invert the output
      ret := bitReverse(ret);
      ret := not ret;

      return ret;
   end function;

end package body Pgp4Pkg;
