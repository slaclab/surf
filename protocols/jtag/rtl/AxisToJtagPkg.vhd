-------------------------------------------------------------------------------
-- Title      : JTAG Support
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Axi Stream to JTAG Package
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Firmware Standard Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the
-- top-level directory of this distribution and at:
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
-- No part of 'SLAC Firmware Standard Library', including this file,
-- may be copied, modified, propagated, or distributed except according to
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

-- Axi Stream to JTAG Protocol

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;

--
-- This module implements a simple protocol for encoding XVC transactions over
-- an AXI stream. Part of this is support for unreliable transport protocols
-- (by means of a memory buffer and transaction IDs).
-- Once the protocol header is processed the stream is delegated to the
-- AxisToJtagCore module.
--
-- INCOMING STREAM
--
-- The incoming Stream consists of consecutive words of AXIS_WIDTH_G bytes,
-- must be framed with 'TLAST' and is expected to have the following format :
--
--    Header Word [, Payload ]
--
-- The header word is defined as
--
--   [31:30]  Protocol Version -- currently "00"
--   [29:28]  Command
--   [27:00]  Command-specific parameter(s)
--
-- Note that if the core is configured for a stream width (AXIS_WIDTH_G) > 4
-- then the header is padded up to the desired width, i.e., the paylod must
-- be word-aligned.
--
-- Each command word is answered with a reply word on the outgoing stream
-- (see below).
--
-- The following commands are currently defined:
--
--      "00"  QUERY: request basic features such as word length, memory depth.
--
--            Payload: NONE, i.e., TLAST should be asserted with this command.
--
--      "01"  JTAG: shift jtag vectors. The vectors are shipped in the payload.
--            The parameter bits for this command are defined as follows:
--
--            [27:20] Transaction ID; this is used when the core is configured
--                    with MEM_DEPTH_G > 0 in order to support a non-reliable
--                    transport.
--            [19:00] JTAG vector length (in bits). The payload must provide
--                    2*ceil( length / AXIS_WIDTH_G ) words of TMS/TDI vector
--                    data. I.e., the length refers to the length of a single
--                    TMS or TDI vector.
--                    !!!!!!!
--                     NOTE: the number in [19:00] encodes the actual number
--                           minus 1. E.g., a value of 0 transmits one TMS
--                           and one TDI bit. Two payload words are expected
--                           in this example.
--                    !!!!!!!
--
--            Payload: sequence of words from the TMS and TDI bit-vectors:
--
--                    TMS_WORD, TDI_WORD, TMS_WORD, TDI_WORD, ...
--
--                    Note that the user must format the stream accordingly
--                    and therefore must be aware of the stream width. This
--                    parameter is returned by the QUERY command.
--
--                    If the number of bits supplied does not fill the last
--                    word then the relevant bits must be lsb/right-aligned
--                    in the last word.
--
--                    TLAST must be asserted during the transmission of the
--                    last TDI/payload word.
--
-- OUTGOING STREAM
--
-- The outgoing stream consists of consecutive words of AXIS_WIDTH_G bytes
-- and is framed with 'TLAST'. Each reply has the following format:
--
--    Header Word [, Payload ]
--
-- The header word is defined as
--
--   [31:30]  Protocol Version; if the user supplies an unsupported protocol
--            version in the request header then the reply contains an error
--            code (see below) and the protocol version in the reply is set
--            to the supported version.
--
--   [29:28]  Command -- the request command is returned unless an error occurred;
--            in case of an error the command bits in the reply are:
--
--            "10"  ERROR: An error was detected. The 8 least-significant bits
--                  [7:0] contain an error code:
--                  1: bad protocol version; the protocol version in the reply
--                     is set to the supported version.
--                  2: bad/unsupported command code
--                  3: truncated input stream (TLAST detected before the
--                     first TDI word was received). Note that a premature
--                     TLAST which is detected after the first TDI word
--                     does NOT flag an error but yields a truncated reply
--                     (less TDO words than requested by the number of bits).
--                  4: 'debug bridge not present' error. I.e., the FW only
--                     implements a stub and no true debug bridge.
--
--            "00"  QUERY: the response to a QUERY command encodes information
--                  in the command-specific bits:
--
--                 [ 3: 0] AXIS_WIDTH_G - 1. I.e., this field encodes the
--                         word size (minus one) used by the core. This information
--                         is important for formatting the stream.
--                 [19: 4] MEM_DEPTH_G. Indicates how much memory (if any) was
--                         configured in words.
--                 [27:20] TCK period. Encoded as
--
--                                          200Mhz     1
--                            round{ log10( ------- ) --- 256 }
--                                           Ttck      4
--
--                        With the special value 0 representing 'unknown'.
--
--
--            "01"  JTAG: the response to a JTAG command is a sequence of
--                  TDO words which form the TDO bit vector. The vector
--                  stored in little-endian format (first bit of the vector
--                  is the LSB of the first TDO word).
--                  If the number of JTAG bits does not fill the last TDO
--                  word completely then the relevant bits are right-
--                  aligned.
--
-- RELIABILITY SUPPORT
--
-- If the transport mechanism contains unreliable segments with a potential for
-- data loss then a simple retry mechanism is not suitable because JTAG operations
-- are not necessarily idempotent.
-- The core can be configured to use internal memory (MEM_DEPTH_C > 0) in which
-- case it stores the last JTAG TDO response in memory.
-- When the next JTAG command arrives the core inspects the 'transaction ID' field
-- of the command and if it is identical with the ID submitted along with the previous
-- transaction then the core detects a retried operation and does not actually execute
-- it again on JTAG but plays back the stored TDO response to the requestor.

package AxisToJtagPkg is

   -- bit indices in the header word

   -- REQUEST
   constant LEN_SHIFT_C : natural  :=  0;
   constant LEN_WIDTH_C : positive := 20;
   constant XID_SHIFT_C : natural  := LEN_SHIFT_C + LEN_WIDTH_C;
   constant XID_WIDTH_C : positive :=  8;
   constant CMD_SHIFT_C : natural  := XID_SHIFT_C + XID_WIDTH_C;
   constant CMD_WIDTH_C : positive :=  2;
   constant VER_SHIFT_C : natural  := CMD_SHIFT_C + CMD_WIDTH_C;
   constant VER_WIDTH_C : positive :=  2;

   -- REPLY (query)
   constant QWL_SHIFT_C : natural  := LEN_SHIFT_C;
   constant QWL_WIDTH_C : natural  :=  4;
   constant QMS_SHIFT_C : natural  := QWL_SHIFT_C + QWL_WIDTH_C;
   constant QMS_WIDTH_C : natural  := 16;
   constant QPD_SHIFT_C : natural  := QMS_SHIFT_C + QMS_WIDTH_C;
   constant QPD_WIDTH_C : natural  :=  8;

   subtype LenType  is slv(LEN_WIDTH_C - 1 downto 0);
   subtype XidType  is slv(XID_WIDTH_C - 1 downto 0);
   subtype ProType  is slv(VER_WIDTH_C - 1 downto 0);
   subtype CmdType  is slv(CMD_WIDTH_C - 1 downto 0);

   -- Protocol Version
   constant PRO_VERSN_C : ProType := "00";

   -- Commands
   constant CMD_QUERY_C : CmdType := "00";
   constant CMD_TRANS_C : CmdType := "01";
   constant CMD_ERROR_C : CmdType := "10";

   -- Error codes (CMD_ERROR_C)
   constant ERR_BAD_VERSION_C : LenType := toSlv( 1, LenType'length );
   constant ERR_BAD_COMMAND_C : LenType := toSlv( 2, LenType'length );
   constant ERR_TRUNCATED_C   : LenType := toSlv( 3, LenType'length );
   constant ERR_NOT_PRESENT_C : LenType := toSlv( 4, LenType'length );

   function getVersion(
      data       : in slv
   ) return ProType;

   procedure setVersion(
      version    : in    ProType;
      data       : inout slv
   );

   function getCommand(
      data       : in slv
   ) return CmdType;

   function getXid(
      data       : in slv
   ) return XidType;

   function getLen(
      data       : in slv
   ) return LenType;

   procedure setErr(
      err        : in    LenType;
      data       : inout slv
   );

end package AxisToJtagPkg;

package body AxisToJtagPkg is

   function getVersion(
      data       : in slv
   ) return ProType is
   begin
      return data(VER_SHIFT_C + VER_WIDTH_C - 1 downto VER_SHIFT_C);
   end function getVersion;

   procedure setVersion(
      version    : in    ProType;
      data       : inout slv
   ) is
   begin
      data(VER_SHIFT_C + VER_WIDTH_C - 1 downto VER_SHIFT_C) := version;
   end procedure setVersion;

   function getCommand(
      data       : in slv
   ) return CmdType is
   begin
      return data(CMD_SHIFT_C + CMD_WIDTH_C - 1 downto CMD_SHIFT_C);
   end function getCommand;

   function getXid(
      data       : in slv
   ) return XidType is
   begin
      return data(XID_SHIFT_C + XID_WIDTH_C - 1 downto XID_SHIFT_C);
   end function getXid;

   function getLen(
      data       : in slv
   ) return LenType is
   begin
      return data(LEN_SHIFT_C + LEN_WIDTH_C - 1 downto LEN_SHIFT_C);
   end function getLen;

   procedure setErr(
      err        : in    LenType;
      data       : inout slv
   ) is
   begin
      data(CMD_SHIFT_C + CMD_WIDTH_C - 1 downto CMD_SHIFT_C) := CMD_ERROR_C;
      data(LEN_SHIFT_C + LEN_WIDTH_C - 1 downto LEN_SHIFT_C) := err;
   end procedure setErr;

end package body AxisToJtagPkg;
