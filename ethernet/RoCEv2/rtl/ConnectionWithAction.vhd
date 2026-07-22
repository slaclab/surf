-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Behaviour
-- ---------
-- A purely combinational hand-shaken wire-through. The BSV `connect` rule fires
-- whenever upstream has data (getIn.notEmpty) AND downstream can accept it
-- (putOut.notFull); on firing it forwards the datum and dequeues upstream. The
-- module has NO state register driving control flow, so this entity is emitted
-- as a combinational block (no two-process FSM, no clk/rst): there is genuinely
-- no hardware to clock.
--   * bthReg (BSV mkRegU, Reg#(BTH), 96 bits) is DEAD CODE — never read or
--     written in the module body. It is intentionally NOT emitted. See
--     OQ-FSM-15 (RESOLVED-DESIGN-NOTE).
--
-- connectAction (OQ-FSM-16, resolved: hardwire)
-- --------------------------------------------
-- The BSV `connectAction` is a function-valued elaboration parameter; VHDL has
-- no function-type ports. At the single instantiation site the action is:
--     function Action deqActionFunc(DataStream dataStream);
--         action if (dataStream.isLast) psnPipeIn.deq; endaction
--     endfunction
-- It is hardwired here as a 1-bit output strobe `psnDeqEn`, asserted when the
-- rule fires AND the forwarded datum's isLast bit is set. The parent
-- (CombineHeaderAndPayload) wires psnDeqEn to its PSN-queue dequeue/read enable.
--
-- Width / bit-layout trace (CLAUDE.md hard rule: trace widths, never invent)
-- --------------------------------------------------------------------------
-- DataStream (src-bsv/DataTypes.bsv:183-188) deriving(Bits) packs the first
-- field in the MSBs and the last field in the LSBs:
--     { DATA data; ByteEn byteEn; Bool isFirst; Bool isLast }
--   DATA    = Bit#(DATA_BUS_WIDTH)        = 256  (Settings.bsv:10)
--   ByteEn  = Bit#(DATA_BUS_BYTE_WIDTH)   =  32  (TDiv 256/8)
--   isFirst = 1, isLast = 1
--   => total = 290 bits ; isLast = bit 0 (LSB), isFirst = bit 1.
-- NOTE: the FSM spec stated 321 bits; that is incorrect — 290 is the traced
-- value. isLast at LSB is independent of DATA_W_G (always the last packed field).
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

entity ConnectionWithAction is
   generic (
      TPD_G       : time     := 1 ns;
      -- Width of the streamed datum (DataStream = 290 bits at the in-scope site).
      DATA_W_G    : positive := 290);
   port (
      -- Upstream source (BSV getIn : Get#(anytype))
      dataIn         : in  slv(DATA_W_G-1 downto 0);  -- getIn.first
      upstreamValid  : in  sl;                        -- getIn.notEmpty
      deqUpstream    : out sl;                         -- getIn.get (dequeue ack)
      -- Downstream sink (BSV putOut : Put#(anytype))
      dataOut        : out slv(DATA_W_G-1 downto 0);   -- putOut.put data
      dataOutValid   : out sl;                         -- putOut.put enable
      downstreamReady : in sl;                         -- putOut.notFull
      -- Hardwired connectAction strobe (OQ-FSM-16): psnPipeIn.deq when isLast
      psnDeqEn       : out sl);
end entity ConnectionWithAction;

architecture rtl of ConnectionWithAction is

   -- isLast occupies bit 0 of the packed DataStream (last struct field -> LSB).
   constant ISLAST_BIT_C : natural := 0;

   -- Rule `connect` fires iff upstream has data and downstream can accept it.
   signal fire : sl;

begin

   -- conflict_free single rule: fire = getIn.notEmpty AND putOut.notFull
   fire <= upstreamValid and downstreamReady;

   -- putOut.put(data): forward the datum; zeroed when idle (matches spec row 2).
   dataOut      <= dataIn after TPD_G when fire = '1' else
                   (others => '0') after TPD_G;
   dataOutValid <= fire after TPD_G;

   -- getIn.get: dequeue upstream on the same cycle the datum is forwarded.
   deqUpstream  <= fire after TPD_G;

   -- connectAction(data): psnPipeIn.deq when forwarded datum's isLast is set.
   psnDeqEn     <= (fire and dataIn(ISLAST_BIT_C)) after TPD_G;

end architecture rtl;
