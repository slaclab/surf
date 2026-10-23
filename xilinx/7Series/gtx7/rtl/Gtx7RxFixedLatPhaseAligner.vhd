-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
-- Used in conjunction for a Xilinx 7 Series GTX.
-- Given raw 8b10b encoded data presented 2 bytes at a time (20 bits),
-- attempts to align any observed comma to the lower byte.
-- Assumes GTX comma align is enabled and in PMA mode.
-- Comma is configurable through the COMMA_G generic.
-- If an odd number of rxSlides is required for alignment, resets the GTX RX
-- so that a new CDR lock can be obtained. The GTX in PMA Slide Mode shifts
-- the phase of the output clock only every other slide. This module's
-- purpose is to obtain an output clock that exactly matches the phase of the
-- commas.
--
-- That reset-and-retry is RX_ODD_ALIGN_MODE_G = "RESET", the default, and it
-- can loop without bound on a link whose CDR keeps landing odd. "BITSLIP"
-- resolves an odd landing in fabric instead and never resets; see the generic
-- below for what it costs.
--
-- Because "BITSLIP" never asserts rxReset, returning to SEARCH_S after an
-- alignment is LOST depends entirely on the enclosing Gtx7RxRst deasserting
-- rxRunPhAlignment, which it only does when its own DATA_VALID supervision
-- fails. A caller selecting "BITSLIP" must therefore drive Gtx7Core's
-- rxDataValidIn from a decoder rather than leave it at its default of '1'.
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

entity Gtx7RxFixedLatPhaseAligner is
   generic (
      TPD_G               : time            := 1 ns;
      WORD_SIZE_G         : integer         := 20;
      COMMA_EN_G          : slv(3 downto 0) := "0011";
      COMMA_0_G           : slv             := "----------0101111100";
      COMMA_1_G           : slv             := "----------1010000011";
      COMMA_2_G           : slv             := "XXXXXXXXXXXXXXXXXXXX";
      COMMA_3_G           : slv             := "XXXXXXXXXXXXXXXXXXXX";
      RX_ODD_ALIGN_MODE_G : string          := "RESET");  -- "RESET": legacy behavior, resets the GTX RX on
                                                          -- an odd comma landing and hopes for an even
                                                          -- relock; "BITSLIP": resolves an odd landing in
                                                          -- fabric using only even rxSlide counts, then a
                                                          -- constant 1-bit fabric slice. Both terminal
                                                          -- states present the aligned word one rxUsrClk
                                                          -- after the GT, so the latency is the same for
                                                          -- every landing.
   port (
      rxUsrClk             : in  sl;
      rxRunPhAlignment     : in  sl;  -- From RxRst, active low reset, not clocked by rxUsrClk
      rxData               : in  slv(WORD_SIZE_G-1 downto 0);  -- Encoded raw rx data
      rxReset              : out sl;
      rxSlide              : out sl;    -- RXSLIDE input to GTX
      rxPhaseAlignmentDone : out sl;   -- Alignment has been achieved.
      rxDataAligned        : out slv(WORD_SIZE_G-1 downto 0);  -- Valid only when rxDataAlignedSel='1'
      rxDataAlignedSel     : out sl);  -- '1': downstream must select rxDataAligned over rxData
end entity Gtx7RxFixedLatPhaseAligner;

architecture rtl of Gtx7RxFixedLatPhaseAligner is

   constant SLIDE_WAIT_C : integer := 32;  -- Dictated by UG476 GTX Transceiver Guide

   constant BITSLIP_MODE_C : boolean := (RX_ODD_ALIGN_MODE_G = "BITSLIP");

   constant ODD_OBS_WIDTH_C : positive := bitSize(WORD_SIZE_G);
   constant ODD_CNT_WIDTH_C : positive := 8;

   type StateType is (SEARCH_S, RESET_S, SLIDE_S, SLIDE_WAIT_S, ALIGNED_S, ALIGNED_SLIP_S);

   type RegType is record
      state                : StateType;
      alignmentValue       : integer;
      last                 : slv(WORD_SIZE_G*2-1 downto 0);
      slideCount           : unsigned(bitSize(WORD_SIZE_G)-1 downto 0);
      slideWaitCounter     : unsigned(bitSize(SLIDE_WAIT_C)-1 downto 0);
      rxReset              : sl;
      rxSlide              : sl;        -- Output
      rxPhaseAlignmentDone : sl;        --Output
   end record RegType;

   constant REG_RESET_C : RegType := (
      state                => SEARCH_S,
      alignmentValue       => 0,
      last                 => (others => '0'),
      slideCount           => (others => '0'),
      slideWaitCounter     => (others => '0'),
      rxReset              => '0',
      rxSlide              => '0',
      rxPhaseAlignmentDone => '0');

   subtype OddOffsetType is natural range 0 to WORD_SIZE_G-1;

   type OddObsType is record
      landedOffset    : slv(ODD_OBS_WIDTH_C-1 downto 0);
      landedValid     : sl;
      oddLandingCount : slv(ODD_CNT_WIDTH_C-1 downto 0);
   end record OddObsType;

   constant ODD_OBS_INIT_C : OddObsType := (
      landedOffset    => (others => '0'),
      landedValid     => '0',
      oddLandingCount => (others => '0'));

   signal r   : RegType := REG_RESET_C;
   signal rin : RegType;

   signal rxRunPhAlignmentSync : sl;

   -- Combinational, not part of r/rin: gated by the elaboration-time BITSLIP_MODE_C constant, so
   -- under "RESET" this elaborates to a constant '0' drive with no added mux, and dont_touch on r
   -- does not preserve any register for it.
   signal rxDataAlignedInt    : slv(WORD_SIZE_G-1 downto 0);
   signal rxDataAlignedSelInt : sl;

   attribute dont_touch      : string;
   attribute dont_touch of r : signal is "TRUE";

   attribute KEEP_HIERARCHY              : string;
   attribute KEEP_HIERARCHY of RstSync_1 : label is "TRUE";

begin

   -- RX_ODD_ALIGN_MODE_G is a string generic so it cannot carry a constrained range; this assert
   -- enforces the two-member enumeration explicitly instead.
   assert (RX_ODD_ALIGN_MODE_G = "RESET") or (RX_ODD_ALIGN_MODE_G = "BITSLIP")
      report "Gtx7RxFixedLatPhaseAligner: RX_ODD_ALIGN_MODE_G must be RESET or BITSLIP"
      severity failure;

   -- Must use async resets since rxUsrClk can drop out
   RstSync_1 : entity surf.RstSync
      generic map (
         TPD_G          => TPD_G,
         IN_POLARITY_G  => '0',
         OUT_POLARITY_G => '0')
      port map (
         clk      => rxUsrClk,
         asyncRst => rxRunPhAlignment,
         syncRst  => rxRunPhAlignmentSync);


   comb : process (r, rxData) is
      variable v : RegType;
   begin
      v := r;

      v.rxSlide              := '0';
      v.rxPhaseAlignmentDone := '0';

      v.last := rxData & r.last(WORD_SIZE_G*2-1 downto WORD_SIZE_G);  -- Save last word

      case r.state is
         when SEARCH_S =>
            for i in 0 to WORD_SIZE_G - 1 loop
               -- Look for pos or neg comma
               if (std_match(r.last((i+WORD_SIZE_G-1) downto i), COMMA_0_G) and (COMMA_EN_G(0) = '1')) or
                  (std_match(r.last((i+WORD_SIZE_G-1) downto i), COMMA_1_G) and (COMMA_EN_G(1) = '1')) or
                  (std_match(r.last((i+WORD_SIZE_G-1) downto i), COMMA_2_G) and (COMMA_EN_G(2) = '1')) or
                  (std_match(r.last((i+WORD_SIZE_G-1) downto i), COMMA_3_G) and (COMMA_EN_G(3) = '1')) then
                  if (i = 0) then
                     -- Latch the Alignment Value
                     v.alignmentValue := i;
                     -- Data is Aligned
                     v.state          := ALIGNED_S;
                  elsif (i mod 2 = 0) then
                     -- Latch the Alignment Value
                     v.alignmentValue := i;
                     -- Even number of slides needed
                     -- slideCount set to number of slides needed - 1
                     v.slideCount     := to_unsigned(i-1, bitSize(WORD_SIZE_G));
                     v.state          := SLIDE_S;
                  else
                     -- Latch the Alignment Value
                     v.alignmentValue := i;
                     if BITSLIP_MODE_C then
                        if (i = 1) then
                           -- Zero slides needed: the residue resolves through the fabric slice
                           -- alone
                           v.state      := ALIGNED_SLIP_S;
                        else
                           -- Reduce the residue to 1 using the i mod 2 = 0 branch's own slide
                           -- sequencer (SLIDE_S/SLIDE_WAIT_S, unmodified). That sequencer issues
                           -- slideCount+1 pulses, as the even branch above notes, so slideCount
                           -- must be i-2 to issue i-1 pulses, which is even for odd i. Setting it
                           -- to i-1 would issue i pulses, an odd count landing on offset 0, which
                           -- is exactly what this mode exists to avoid. SLIDE_WAIT_S returns to
                           -- SEARCH_S, which re-scans and re-enters this branch at i = 1,
                           -- resolving with no further slides.
                           v.slideCount := to_unsigned(i-2, bitSize(WORD_SIZE_G));
                           v.state      := SLIDE_S;
                        end if;
                     else
                        -- Reset the rx and hope for a new lock requiring an even number of slides
                        v.state := RESET_S;
                     end if;
                  end if;
               end if;
            end loop;

         when RESET_S =>
            -- Async reset will eventually get everything back to SEARCH_S state
            v.rxReset := '1';

         when SLIDE_S =>
            v.rxSlide := '1';
            v.state   := SLIDE_WAIT_S;

         when SLIDE_WAIT_S =>
            -- Wait SLIDE_WAIT_C clocks between each slide
            v.slideWaitCounter := r.slideWaitCounter + 1;
            if (uAnd(slv(r.slideWaitCounter)) = '1') then
               if (r.slideCount = 0) then
                  v.state := SEARCH_S;  -- Double check that the slides worked
               else
                  v.slideCount := r.slideCount - 1;
                  v.state      := SLIDE_S;
               end if;
            end if;

         when ALIGNED_S =>
            v.rxPhaseAlignmentDone := '1';
            -- Gtx7RxRst module will reset this module back to SEARCH_S if alignment is lost

         when ALIGNED_SLIP_S =>
            v.rxPhaseAlignmentDone := '1';
            -- Gtx7RxRst module will reset this module back to SEARCH_S if alignment is lost.
            -- rxDataAlignedSelInt (driven below, combinationally, from r.state) tells Gtx7Core to
            -- select the fabric-sliced word instead of rxData while this state holds.

      end case;

      rin <= v;

      -- Outputs
      rxReset              <= r.rxReset;
      rxSlide              <= r.rxSlide;
      rxPhaseAlignmentDone <= r.rxPhaseAlignmentDone;
   end process comb;

   -- Aligned-word output, valid only when BITSLIP_MODE_C. Every odd landing resolves to a fixed
   -- residue of 1 before the slice is taken, so the slice is a constant bit range of the history,
   -- not an offset-dependent one.
   --
   -- Both terminal states source the word one rxUsrClk after the GT presented it, so the latency
   -- from fiber to rxDataOut does not depend on where the comma landed:
   --
   --   ALIGNED_S      (offset 0) -> the previous GT word, unshifted
   --   ALIGNED_SLIP_S (offset 1) -> the previous GT word shifted up one bit, its missing MSB taken
   --                                from the live word
   --
   -- One stage is the floor here, not a convenience: at offset 1 the aligned word's last bit only
   -- arrives with the next GT word, so it cannot be presented combinationally. Sourcing ALIGNED_S
   -- from rxData instead would make the two states differ by a full parallel-clock period, which
   -- is the determinism this mode is supposed to provide.
   --
   -- Under "RESET" both drives elaborate to constants with no mux, since BITSLIP_MODE_C is an
   -- elaboration-time constant.
   rxDataAlignedInt <=
      (rxData(0) & r.last(WORD_SIZE_G*2-1 downto WORD_SIZE_G+1)) when (BITSLIP_MODE_C and (r.state = ALIGNED_SLIP_S)) else
      r.last(WORD_SIZE_G*2-1 downto WORD_SIZE_G)                 when (BITSLIP_MODE_C and (r.state = ALIGNED_S))      else
      (others => '0');

   rxDataAlignedSelInt <= '1' when (BITSLIP_MODE_C and ((r.state = ALIGNED_S) or (r.state = ALIGNED_SLIP_S))) else '0';

   rxDataAligned    <= rxDataAlignedInt;
   rxDataAlignedSel <= rxDataAlignedSelInt;

   ODD_OBS_GEN : if BITSLIP_MODE_C generate

      signal obs : OddObsType := ODD_OBS_INIT_C;

      attribute dont_touch of obs : signal is "TRUE";

   begin

      obsSeq : process (rxRunPhAlignmentSync, rxUsrClk) is
      begin
         if (rising_edge(rxUsrClk)) then
            -- Latch only the FIRST odd offset seen since reset. Every odd landing above 1 slides
            -- down to a residue of 1 and re-scans, so without this guard the offset the CDR
            -- actually landed on would always be overwritten by that terminal 1.
            if (r.state = SEARCH_S) and ((rin.alignmentValue mod 2) = 1) and (obs.landedValid = '0') then
               obs.landedOffset <= std_logic_vector(
                  to_unsigned(OddOffsetType'(rin.alignmentValue), ODD_OBS_WIDTH_C)) after TPD_G;
               obs.landedValid  <= '1' after TPD_G;
            end if;
            if (rin.state = ALIGNED_SLIP_S) and (r.state /= ALIGNED_SLIP_S) then
               obs.oddLandingCount <= std_logic_vector(
                  unsigned(obs.oddLandingCount) + 1) after TPD_G;
            end if;
         end if;
         if (rxRunPhAlignmentSync = '0') then
            obs <= ODD_OBS_INIT_C after TPD_G;
         end if;
      end process obsSeq;

   end generate ODD_OBS_GEN;

   seq : process (rxRunPhAlignmentSync, rxUsrClk) is
   begin
      if (rising_edge(rxUsrClk)) then
         r <= rin after TPD_G;
      end if;
      if (rxRunPhAlignmentSync = '0') then
         r <= REG_RESET_C after TPD_G;
      end if;
   end process;

end architecture rtl;
