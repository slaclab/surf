-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Elaboration-time CRC32 lookup tables and byte-lane datapath
--              helpers for the native VHDL RoCEv2 iCRC engine, RoCEv2ICrc.
--
--              Every one of the 36 lookup tables this package builds is the
--              same recurrence, called with a different iteration count:
--              value(k, b) starts from the raw byte value b and applies the
--              step v := (v(23 downto 0) & x"00") xor
--              crcByteLookup(v(31 downto 24), CRC32_POLY_C) exactly k times.
--              Equivalently, value(k, b) equals b multiplied by x to the
--              power 8*k, reduced modulo the CRC-32 generator polynomial
--              over GF(2). No .mem file is read at simulation time; every
--              table value is an elaboration-time constant generated from
--              surf.CrcPkg.crcByteLookup rather than read from a file.
--
--              A Bluespec Vector's element 0 packs into the least
--              significant bits, which is why lane i of a byte-shifted word
--              is looked up in table (base + i) rather than table
--              (base + byteNum - 1 - i): the datapath's own byte-lane
--              numbering already matches that convention.
--
--              A hole in the middle of s_axis_tkeep is silently treated as
--              a zero data byte, matching the original design exactly: the
--              shift amount this package computes depends only on the run
--              of zero bits counting down from tkeep's own most significant
--              bit, so a zero bit anywhere below the first one does not
--              change it.
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

library surf;
use surf.StdRtlPkg.all;
use surf.CrcPkg.all;

package RoCEv2ICrcPkg is

   constant CRC32_POLY_C      : slv(31 downto 0) := x"04C11DB7";
   constant CRC32_INIT_C      : slv(31 downto 0) := x"FFFFFFFF";
   constant CRC32_FINAL_XOR_C : slv(31 downto 0) := x"FFFFFFFF";

   constant CRC_WIDTH_C       : positive := 32;
   constant CRC_BYTE_NUM_C    : positive := 4;
   constant AXIS_KEEP_WIDTH_C : positive := 32;
   constant AXIS_DATA_WIDTH_C : positive := 256;
   constant INTER_BYTE_NUM_C  : positive := 36;
   constant INTER_WIDTH_C     : positive := INTER_BYTE_NUM_C * 8;

   -- Data-byte table base (readCrcTab, CrcAxiStream.bsv:127-129): Send reads
   -- tables SEND_TAB_OFFSET_C..SEND_TAB_OFFSET_C+31, Recv reads tables
   -- RECV_TAB_OFFSET_C..RECV_TAB_OFFSET_C+31.
   constant SEND_TAB_OFFSET_C : natural := CRC_BYTE_NUM_C;
   constant RECV_TAB_OFFSET_C : natural := 0;

   -- Running-CRC table base (accuCrc, CrcAxiStream.bsv:159-175): both modes
   -- read ACCU_TAB_OFFSET_C..ACCU_TAB_OFFSET_C+3 except Recv on a beat whose
   -- isFirst is set, which reads RECV_INIT_TAB_OFFSET_C.._RECV_INIT_TAB_OFFSET_C+3.
   constant ACCU_TAB_OFFSET_C      : natural := AXIS_KEEP_WIDTH_C;
   constant RECV_INIT_TAB_OFFSET_C : natural := ACCU_TAB_OFFSET_C - CRC_BYTE_NUM_C;

   type CrcByteTableType is array (0 to 255) of slv(31 downto 0);
   type CrcTableSetType is array (0 to INTER_BYTE_NUM_C - 1) of CrcByteTableType;

   -- genCrcByteTable/genCrcTableSet build every table value at elaboration
   -- time from surf.CrcPkg.crcByteLookup; CRC_TABLES_C is a deferred
   -- constant (declared here, given its value in the package body) because
   -- its initializer calls genCrcTableSet, whose implementation lives in
   -- the package body.
   function genCrcByteTable (tabIndex : natural) return CrcByteTableType;
   function genCrcTableSet return CrcTableSetType;

   constant CRC_TABLES_C : CrcTableSetType;

   function icrcExpandKeep (keep : slv(31 downto 0)) return slv;
   function icrcSwapEndian (data : slv) return slv;
   function icrcReverseEachByte (data : slv) return slv;
   function icrcTrailingInvalidBytes (keep : slv(31 downto 0)) return natural;
   function icrcByteRightShift (data : slv; shiftBytes : natural) return slv;
   function icrcTableFold (data : slv; tabOffset : natural; loLane : natural; hiLane : natural) return slv;
   function icrcFinalize (crc : slv(31 downto 0)) return slv;

end package RoCEv2ICrcPkg;

package body RoCEv2ICrcPkg is

   function genCrcByteTable (tabIndex : natural) return CrcByteTableType is
      variable retVar : CrcByteTableType;
      variable v      : slv(31 downto 0);
   begin
      -- Table 0 must come out as the identity map, value(0, b) = b: the
      -- loop range below is 1 to tabIndex, a null range (zero iterations)
      -- exactly when tabIndex = 0. Iterating once too many (a loop range of
      -- 0 to tabIndex instead) computes table tabIndex + 1 and produces a
      -- wrong CRC for every packet: it elaborates cleanly and gives no
      -- runtime symptom other than the wrong answer.
      for b in 0 to 255 loop
         v := x"000000" & toSlv(b, 8);
         for k in 1 to tabIndex loop
            v := (v(23 downto 0) & x"00") xor crcByteLookup(v(31 downto 24), CRC32_POLY_C);
         end loop;
         retVar(b) := v;
      end loop;
      return retVar;
   end function genCrcByteTable;

   function genCrcTableSet return CrcTableSetType is
      variable retVar : CrcTableSetType;
   begin
      for k in 0 to INTER_BYTE_NUM_C - 1 loop
         retVar(k) := genCrcByteTable(k);
      end loop;
      return retVar;
   end function genCrcTableSet;

   constant CRC_TABLES_C : CrcTableSetType := genCrcTableSet;

   function icrcExpandKeep (keep : slv(31 downto 0)) return slv is
      variable retVar : slv(AXIS_DATA_WIDTH_C - 1 downto 0);
   begin
      -- bitMask(): keep(j) replicates across bits 8j+7 downto 8j of the
      -- returned lane mask.
      for j in 0 to AXIS_KEEP_WIDTH_C - 1 loop
         retVar(8 * j + 7 downto 8 * j) := (others => keep(j));
      end loop;
      return retVar;
   end function icrcExpandKeep;

   function icrcSwapEndian (data : slv) return slv is
      -- An unconstrained slv formal's actual may arrive with an ascending,
      -- non-zero-based index range when the actual is itself an anonymous
      -- expression (for example the result of an "and" of two signals)
      -- rather than a named signal or variable: GHDL then has no target
      -- subtype to inherit a descending range from. normData is a
      -- positional copy (leftmost bit to leftmost bit, regardless of
      -- either side's own index direction) into a locally declared,
      -- guaranteed descending, zero-based object, so every absolute-index
      -- slice below is always safe regardless of what bounds the actual
      -- argument happened to carry.
      constant WIDTH_C    : natural := data'length;
      constant BYTE_NUM_C : natural := WIDTH_C / 8;
      variable normData   : slv(WIDTH_C - 1 downto 0) := data;
      variable retVar     : slv(WIDTH_C - 1 downto 0);
   begin
      -- swapEndian(): lane i of the result holds the byte that was at lane
      -- (byteNum - 1 - i) of the input.
      for i in 0 to BYTE_NUM_C - 1 loop
         retVar(8 * i + 7 downto 8 * i) := normData(8 * (BYTE_NUM_C - 1 - i) + 7 downto 8 * (BYTE_NUM_C - 1 - i));
      end loop;
      return retVar;
   end function icrcSwapEndian;

   function icrcReverseEachByte (data : slv) return slv is
      -- See icrcSwapEndian's comment: normData is the same safe positional
      -- copy into a guaranteed descending, zero-based local object.
      constant WIDTH_C    : natural := data'length;
      constant BYTE_NUM_C : natural := WIDTH_C / 8;
      variable normData   : slv(WIDTH_C - 1 downto 0) := data;
      variable retVar     : slv(WIDTH_C - 1 downto 0);
   begin
      -- reverseBitsOfEachByte(): bitReverse() applied independently to
      -- each 8-bit slice; byte order (lane index) is untouched.
      for i in 0 to BYTE_NUM_C - 1 loop
         retVar(8 * i + 7 downto 8 * i) := bitReverse(normData(8 * i + 7 downto 8 * i));
      end loop;
      return retVar;
   end function icrcReverseEachByte;

   function icrcTrailingInvalidBytes (keep : slv(31 downto 0)) return natural is
      variable count : natural := 0;
   begin
      -- countZerosLSB(reverseBits(tKeep)): the count of consecutive '0'
      -- bits starting from keep's own most significant bit downward,
      -- stopping at the first '1'. A hole below the first '1' bit does not
      -- change this count, which is why a non-contiguous tkeep is silently
      -- treated as a zero data byte rather than raising any error.
      for i in 31 downto 0 loop
         if keep(i) = '0' then
            count := count + 1;
         else
            exit;
         end if;
      end loop;
      return count;
   end function icrcTrailingInvalidBytes;

   function icrcByteRightShift (data : slv; shiftBytes : natural) return slv is
      -- See icrcSwapEndian's comment: normData is the same safe positional
      -- copy into a guaranteed descending, zero-based local object.
      constant WIDTH_C  : natural := data'length;
      variable normData : slv(WIDTH_C - 1 downto 0) := data;
      variable retVar   : slv(WIDTH_C - 1 downto 0) := (others => '0');
   begin
      -- byteRightShift()/shiftOutFrom0(): a right shift in the bit domain,
      -- because a Bluespec Vector's element 0 packs into the least
      -- significant bits (see the package header comment). Zero-filled at
      -- the most significant end.
      if shiftBytes * 8 < WIDTH_C then
         retVar(WIDTH_C - 1 - 8 * shiftBytes downto 0) := normData(WIDTH_C - 1 downto 8 * shiftBytes);
      end if;
      return retVar;
   end function icrcByteRightShift;

   function icrcTableFold (data : slv; tabOffset : natural; loLane : natural; hiLane : natural) return slv is
      -- See icrcSwapEndian's comment: normData is the same safe positional
      -- copy into a guaranteed descending, zero-based local object.
      constant WIDTH_C  : natural := data'length;
      variable normData : slv(WIDTH_C - 1 downto 0) := data;
      variable retVar   : slv(31 downto 0) := (others => '0');
   begin
      -- XOR-reduces the byte-table lookups for lanes loLane through
      -- hiLane, table index (tabOffset + i) for lane i, mirroring
      -- CrcAxiStream.bsv's readCrcTab/accuCrc/readInterCrcTab rules and
      -- their reduceBalancedTree XOR reduction.
      for i in loLane to hiLane loop
         retVar := retVar xor CRC_TABLES_C(tabOffset + i)(to_integer(unsigned(normData(8 * i + 7 downto 8 * i))));
      end loop;
      return retVar;
   end function icrcTableFold;

   function icrcFinalize (crc : slv(31 downto 0)) return slv is
   begin
      -- Whole-32-bit-word reflection, then XOR with the final-XOR
      -- constant. Not a per-byte reflection: crc_out_from_remainder() in
      -- tests/base/crc/crc_test_utils.py reflects within each byte and is
      -- a byte swap away from correct. Measured pair: remainder
      -- 0xbc78e776 must produce 0x9118e1c2, never the per-byte-reflected
      -- 0xc2e11891.
      return bitReverse(crc) xor CRC32_FINAL_XOR_C;
   end function icrcFinalize;

end package body RoCEv2ICrcPkg;
