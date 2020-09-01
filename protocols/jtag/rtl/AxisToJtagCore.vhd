-------------------------------------------------------------------------------
-- Title      : JTAG Support
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Axi Stream to JTAG Interface/Adapter
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
use surf.AxiStreamPkg.all;


-- Convert an AXI Stream into JTAG and return the TDO reply as an AXI Stream.
--
-- The input stream must be formatted as follows:
--
--   A stream of words of (AXIS_WIDTH_G * 8) bits each.
--   1. The first word specifies the *total* number of bits to shift minus one
--      (e.g., a value of indicates 1 bit to shift).
--   2. This first word is followed by a sequence of words that provide
--      TMS and TDI bits:
--
--      total_number_bits_minus_one
--      first_8AXIS_WIDTH_G_TMS_bits
--      first_8AXIS_WIDTH_G_TDI_bits
--      2nd___8AXIS_WIDTH_G_TMS_bits
--      2nd___8AXIS_WIDTH_G_TDI_bits
--      3rd___8AXIS_WIDTH_G_TMS_bits
--      3rd___8AXIS_WIDTH_G_TDI_bits
--      Nth___8AXIS_WIDTH_G_TMS_bits
--      Nth___8AXIS_WIDTH_G_TDI_bits
--
-- If the total number of bits is not word aligned then only the remaining
-- bits are shifted.
--
-- Bits are shifted in little-endian format (LSB shifted out first)
--
-- The returned Stream ships the (same number) of TDO bits
--
--      first_8AXIS_WIDTH_G_TDO_bits
--      2nd___8AXIS_WIDTH_G_TDO_bits
--      3rd___8AXIS_WIDTH_G_TDO_bits
--      Nth___8AXIS_WIDTH_G_TDO_bits
--
-- TDO bits are shifted in little-endian format (LSB is the 'oldest' bit).
-- In the last word, the 'remaining' bits are right-adjusted.
--
-- E.g., AXIS_WIDTH_G is 32 and the total number of bits is 33 then:
--
-- Output:
--         0x00000020       -- length: 33 - 1 = 32
--         0x76543210       -- first TMS word; bit sequence is 0,0,0,0,1,0,0,0,0,1,0,0,... (lsb first)
--         0xfedcba98       -- first TDI word; bit sequence is 0,0,0,1,1,0,0,1,0,1,0,1,... (lsb first)
--         0xfffffffe       -- last TMS bit;   bit sequence is 0
--         0x00000001       -- last TDI bit;   bit sequence is 1
--
-- Input:
--         0x33221100       -- first TDO word (first 32 bits; first 8 bits are 0; first bits in lsB)
--         0x00000001       -- last TDO bit   (right-aligned); last bit is '1'
--
-- TLAST Handling:
--   - Input Stream:  TLAST must be asserted when the last TDI word is transmitted.
--                    If it is detected earlier then processing will be aborted (and
--                    the return stream truncated as well). If TLAST is asserted
--                    after the announced number of bits then the excess words are
--                    discarded.
--                    If the TLAST_IGNORE_G generic is true the the behavior is
--                    changed and no data are discarded if TLAST is missing (an early
--                    TLAST still leads to truncated data).
--                    This TLAST_IGNORE_G allows the core to be used with implicit
--                    framing by the 'nbits' word.
--   - Output Stream: TLAST is asserted during transmission of the last TDO word.
--
-- TKEEP/TSTROBE/TUSR/TDEST/TID: unused; not generated or inspected.
--

entity AxisToJtagCore is
   generic (
      TPD_G            : time                  := 1 ns;
      AXIS_WIDTH_G     : positive              := 4;     -- bytes
      LEN_POS0_G       : natural               := 0;
      LEN_POSN_G       : natural               := 17;
      CLK_DIV2_G       : positive              := 8;     -- half-period of TCK in axisClk cycles
      TLAST_IGNORE_G   : boolean               := false  -- don't wait for TLAST on input
   );
   port (
      axisClk          : in sl;
      axisRst          : in sl;

      mAxisTmsTdi      : in  AxiStreamMasterType;
      sAxisTmsTdi      : out AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;

      mAxisTdo         : out AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
      sAxisTdo         : in  AxiStreamSlaveType;

      running          : out sl;

      tck              : out sl;
      tdi              : out sl;
      tms              : out sl;
      tdo              : in  sl
   );
end entity AxisToJtagCore;

architecture AxisToJtagCoreImpl of AxisToJtagCore is


   type StateType is (IDLE_S, GET_TMS_S, GET_TDI_S, SHIFT_S, ALIGN_S, DISCARD_S);

   constant AXIS_BW_C       : positive  := 8*AXIS_WIDTH_G;

   type RegType is record
      state      : StateType;
      tdi        : slv(AXIS_BW_C - 1 downto 0);
      tms        : slv(AXIS_BW_C - 1 downto 0);
      tdo        : slv(AXIS_BW_C - 1 downto 0);
      nBits      : natural range 0 to AXIS_BW_C - 1;
      nBitsTot   : slv(LEN_POSN_G - LEN_POS0_G downto 0);
      tdiValid   : sl;
      sReady     : sl;
      tdoValid   : sl;
      tdoPass    : sl;
      last       : boolean;
      tLastSeen  : boolean;
      iCnt       : slv(1 downto 0);
      oCnt       : slv(1 downto 0);
      tLast      : sl;
      running    : sl;
   end record RegType;

   constant REG_INIT_C : RegType := (
      state      => IDLE_S,
      tdi        => (others => '0'),
      tms        => (others => '0'),
      tdo        => (others => '0'),
      nBits      => 0,
      nBitsTot   => (others => '0'),
      tdiValid   => '0',
      sReady     => '1',
      tdoValid   => '0',
      tdoPass    => '1',
      last       => false,
      tLastSeen  => false,
      iCnt       => (others => '0'),
      oCnt       => (others => '0'),
      tLast      => '0',
      running    => '0'
   );

   signal tdoData     : slv(AXIS_BW_C - 1 downto 0);

   signal r           : RegType := REG_INIT_C;

   signal rin         : RegType;

   signal tdiReady    : sl;
   signal tdoValidLoc : sl;
   signal tdoValid    : sl;

   signal tdoReady    : sl;

begin
   running                                   <= r.running;

   sAxisTmsTdi.tReady                        <= r.sReady;

   tdoValid                                  <= r.tdoValid and r.tdoPass;

   GEN_PAD_TKEEP : if (mAxisTdo.tKeep'left > AXIS_WIDTH_G) generate -- silence critical warning
      mAxisTdo.tKeep(mAxisTdo.tKeep'left - 1 downto AXIS_WIDTH_G) <= ( others => '0' );
   end generate;
   mAxisTdo.tKeep(AXIS_WIDTH_G - 1 downto 0) <= ( others => '1' );
   mAxisTdo.tValid                           <= tdoValid;
   mAxisTdo.tLast                            <= r.tLast;
   mAxisTdo.tData(AXIS_BW_C    - 1 downto 0) <= r.tdo;

   tdoReady <= not r.tdoValid or ( sAxisTdo.tReady and r.tdoPass );

   U_Jtag : entity surf.JtagSerDesCore
      generic map (
         TPD_G         => TPD_G,
         WIDTH_G       => AXIS_BW_C,
         CLK_DIV2_G    => CLK_DIV2_G
      )
      port map (
         clk           => axisClk,
         rst           => axisRst,

         numBits       => r.nBits,

         dataInTms     => r.tms,
         dataInTdi     => r.tdi,
         dataInValid   => r.tdiValid,
         dataInReady   => tdiReady,

         dataOutReady  => tdoReady,
         dataOutValid  => tdoValidLoc,
         dataOut       => tdoData,

         tck           => tck,
         tms           => tms,
         tdi           => tdi,
         tdo           => tdo
      );

   P_COMB : process( r, tdiReady, tdoValid, tdoData, tdoValidLoc, tdoReady, mAxisTmsTdi, sAxisTdo )
      variable v : RegType;
   begin

      v := r;

      case ( r.state ) is
         when IDLE_S =>
            v.last      := false;
            v.tLastSeen := false;
            v.iCnt      := ( others => '0' );
            v.oCnt      := ( others => '0' );
            v.tLast     := '0';
            v.tdoPass   := '1';
            v.sReady    := '1';
            if ( (r.sReady and mAxisTmsTdi.tValid) = '1' ) then
               -- first word is bit count (minus one)
               if ( mAxisTmsTdi.tLast /= '1' ) then
                  v.nBitsTot := mAxisTmsTdi.tData(LEN_POSN_G downto LEN_POS0_G);
                  v.state    := GET_TMS_S;
               end if;
            end if;

         when GET_TMS_S =>
            if ( (r.sReady and mAxisTmsTdi.tValid) = '1' ) then
               if ( mAxisTmsTdi.tLast = '1' ) then
                  -- not enough data for this beat; abort
                  if ( v.iCnt /= v.oCnt ) then
                     -- wait for outstanding transaction
                     v.last      := true;
                     v.tLastSeen := true;
                     v.nBits     := AXIS_BW_C - 1;
                     v.state     := ALIGN_S;
                  else
                     -- nothing outstanding -- go back to idle state
                     v.state    := IDLE_S;
                  end if;
               else
                  v.tms      := mAxisTmsTdi.tData(AXIS_BW_C - 1 downto 0);
                  v.state    := GET_TDI_S;
                  v.iCnt     := slv(unsigned(r.iCnt) + 1);
                  v.running  := '1';
                  if ( unsigned(r.nBitsTot) >= AXIS_BW_C ) then
                     v.nBits    := AXIS_BW_C - 1;
                     v.nBitsTot := slv(unsigned(r.nBitsTot) - unsigned(toSlv(AXIS_BW_C, v.nBitsTot'length)));
                  else
                     v.last     := true;
                     v.nBits    := to_integer(unsigned(r.nBitsTot));
                  end if;
               end if;
            end if;

         when GET_TDI_S =>
            if ( (r.sReady and mAxisTmsTdi.tValid) = '1' ) then
               if ( mAxisTmsTdi.tLast = '1' ) then
                  v.tLastSeen := true;
                  if ( not r.last ) then
                     -- premature end; still do this word...
                     v.nBitsTot  := toSlv( r.nBits, v.nBitsTot'length );
                     v.last      := true;
                  end if;
               end if;
               v.tdi      := mAxisTmsTdi.tData(AXIS_BW_C - 1 downto 0);
               v.tdiValid := '1';
               v.sReady   := '0';
               v.state    := SHIFT_S;
            end if;

         when SHIFT_S   =>
            if ( (tdiReady and r.tdiValid) = '1' ) then
               v.tdiValid := '0';
               if ( not r.last ) then
                  v.state   := GET_TMS_S;
                  v.sReady  := '1';
               end if;
            end if;

         when ALIGN_S =>
            if ( r.nBits = AXIS_BW_C - 1 ) then
               v.tLast   := '1';
               if ( ( r.tdoValid and sAxisTdo.tReady ) = '1' ) then
                  v.state := DISCARD_S;
               end if;
            else
               v.tdo   := ( '0' & r.tdo( r.tdo'left downto 1 ) );
               v.nBits := r.nBits + 1;
            end if;

         -- discard stuff after requested number of bits
         when DISCARD_S =>
            if ( r.tLastSeen or TLAST_IGNORE_G ) then
               v.tdoPass := '1';
            else
               v.sReady  := '1';
               if ( (r.sReady and mAxisTmsTdi.tValid) = '1' ) then
                  if ( mAxisTmsTdi.tLast = '1' ) then
                     v.tLastSeen := true;
                     v.tdoPass   := '1';
                     v.sReady    := '0';
                  end if;
               end if;
			end if;
      end case;

      if ( (tdoValid and sAxisTdo.tReady) = '1' ) then
         if ( r.tLast = '1' ) then
            v.running := '0';
            v.state   := IDLE_S;
         end if;
         v.tdoValid := '0';
      end if;
      if ( ( tdoValidLoc and tdoReady ) = '1' ) then
         v.tdo      := tdoData;
         v.tdoValid := '1';
         v.oCnt     := slv(unsigned(r.oCnt) + 1);
         if ( r.last and v.oCnt = r.iCnt ) then
            v.tdoPass  := '0';
            v.state    := ALIGN_S;
         end if;
      end if;

      rin   <= v;

   end process P_COMB;

   P_SEQ : process( axisClk )
   begin
      if ( rising_edge( axisClk ) ) then
         if ( axisRst /= '0' ) then
            r <= REG_INIT_C after TPD_G;
         else
            r <= rin after TPD_G;
         end if;
      end if;
   end process P_SEQ;

end architecture AxisToJtagCoreImpl;
