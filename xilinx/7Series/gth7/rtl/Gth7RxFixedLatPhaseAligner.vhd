-------------------------------------------------------------------------------
-- File       : Gth7RxFixedLatPhaseAligner.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-04-01
-- Last update: 2015-04-01
-------------------------------------------------------------------------------
-- Description:
-- Used in conjunction for a Xilinx 7 Series GTH.
-- Given raw 8b10b encoded data presented 2 bytes at a time (20 bits),
-- attempts to align any observed comma to the lower byte.
-- Assumes GTX comma align is enabled and in PMA mode.
-- Comma is configurable through the COMMA_G generic.
-- If an odd number of rxSlides is required for alignment, resets the GTX RX
-- so that a new CDR lock can be obtained. The GTX in PMA Slide Mode shifts
-- the phase of the output clock only every other slide. This module's
-- purpose is to obtain an output clock that exactly matches the phase of the
-- commas. 
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

use work.StdRtlPkg.all;

entity Gth7RxFixedLatPhaseAligner is
   
   generic (
      TPD_G       : time            := 1 ns;
      WORD_SIZE_G : integer         := 20;
      COMMA_EN_G  : slv(3 downto 0) := "0011";
      COMMA_0_G   : slv             := "----------0101111100";
      COMMA_1_G   : slv             := "----------1010000011";
      COMMA_2_G   : slv             := "XXXXXXXXXXXXXXXXXXXX";
      COMMA_3_G   : slv             := "XXXXXXXXXXXXXXXXXXXX");
   port (
      rxUsrClk             : in  sl;
      rxRunPhAlignment     : in  sl;  -- From RxRst, active low reset, not clocked by rxUsrClk
      rxData               : in  slv(WORD_SIZE_G-1 downto 0);  -- Encoded raw rx data
      rxReset              : out sl;
      rxSlide              : out sl;    -- RXSLIDE input to GTX
      rxPhaseAlignmentDone : out sl);   -- Alignment has been achieved.

end entity Gth7RxFixedLatPhaseAligner;

architecture rtl of Gth7RxFixedLatPhaseAligner is

   constant SLIDE_WAIT_C : integer := 32;  -- Dictated by UG476 GTX Tranceiver Guide

   type StateType is (SEARCH_S, RESET_S, SLIDE_S, SLIDE_WAIT_S, ALIGNED_S);

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

   constant REG_RESET_C : RegType :=
      (state                => SEARCH_S,
       alignmentValue       => 0,
       last                 => (others => '0'),
       slideCount           => (others => '0'),
       slideWaitCounter     => (others => '0'),
       rxReset              => '0',
       rxSlide              => '0',
       rxPhaseAlignmentDone => '0');

   signal r, rin : RegType := REG_RESET_C;

   signal rxRunPhAlignmentSync : sl;

   attribute dont_touch      : string;
   attribute dont_touch of r : signal is "TRUE";
   
   attribute KEEP_HIERARCHY : string;
   attribute KEEP_HIERARCHY of 
      RstSync_1 : label is "TRUE";
   
begin

   -- Must use async resets since rxUsrClk can drop out
   RstSync_1 : entity work.RstSync
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
                     -- Reset the rx and hope for a new lock requiring an even number of slides
                     v.state          := RESET_S;
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
            -- Gth7RxRst module will reset this module back to SEARCH_S if alignment is lost
            
      end case;

      rin <= v;

      -- Outputs
      rxReset              <= r.rxReset;
      rxSlide              <= r.rxSlide;
      rxPhaseAlignmentDone <= r.rxPhaseAlignmentDone;
   end process comb;

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
