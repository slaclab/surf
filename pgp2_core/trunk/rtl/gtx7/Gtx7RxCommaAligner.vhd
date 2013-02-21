-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : Gtx7RxCommaAligner.vhd
-- Author     : Benjamin Reese  <bareese@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2012-11-06
-- Last update: 2012-12-19
-- Platform   : Xilinx 7 Series
-- Standard   : VHDL'93/02
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
-------------------------------------------------------------------------------
-- Copyright (c) 2012 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.Pgp2CoreTypesPkg.all;
use work.StdRtlPkg.all;


entity Gtx7RxCommaAligner is
  
  generic (
    TPD_G        : time            := 1 ns;
    COMMA_G      : slv(9 downto 0) := "0101111100";
    SLIDE_WAIT_G : integer         := 32);

  port (
    rxUsrClk    : in  sl;
    rxUserRdy   : in  sl;               -- Used as active low reset
    rxData      : in  slv(19 downto 0);  -- Encoded raw rx data
    decodeErr   : in  sl;               -- From decoder. Used to determine when lock is lost
    rxSlide     : out sl;               -- RXSLIDE input to GTX
    rxUserReset : out sl;               -- Input to Rx reset state machine, resets the entire GTX Rx
    aligned     : out sl);              -- Alignment has been achieved.

end entity Gtx7RxCommaAligner;

architecture rtl of Gtx7RxCommaAligner is

  type StateType is (SEARCH_S, RESET_S, SLIDE_S, SLIDE_WAIT_0_S, SLIDE_WAIT_1_S, WAIT_SETTLE_S, ALIGNED_S);

  type RegType is record
    state       : StateType;
    last        : slv(9 downto 0);
    slideCount  : unsigned(4 downto 0);
    waitCounter : unsigned(4 downto 0);

    -- Outputs
    rxSlide     : sl;
    rxUserReset : sl;
    aligned     : sl;
  end record RegType;

  signal r, rin : RegType;

begin

  seq : process (rxUsrClk, rxUserRdy) is
  begin
    if (rxUserRdy = '0') then
      r.state       <= SEARCH_S        after TPD_G;
      r.last        <= (others => '0') after TPD_G;
      r.slideCount  <= (others => '0') after TPD_G;
      r.waitCounter <= (others => '0') after TPD_G;

      r.rxSlide     <= '0' after TPD_G;
      r.rxUserReset <= '0' after TPD_G;
      r.aligned     <= '0' after TPD_G;
    elsif (rising_edge(rxUsrClk)) then
      r <= rin after TPD_G;
    end if;
  end process;

  comb : process (r, rxData, decodeErr) is
    variable v         : RegType;
    variable searchVar : slv(29 downto 0);
  begin
    v := r;

    v.rxUserReset := '0';
    v.rxSlide     := '0';
    v.aligned     := '0';

    v.last    := rxData(19 downto 10);  -- Save high byte
    searchVar := rxData & r.last;

    case r.state is
      when SEARCH_S =>
        for i in 1 to 20 loop
          -- Look for pos or neg comma
          if (searchVar((i+9) downto i) = COMMA_G or searchVar(i+9 downto i) = not COMMA_G) then
            if (i = 10) then
              v.state := ALIGNED_S;
            elsif (i mod 2 = 0) then
              -- Even number of slides needed
              -- slideCount set to number of slides needed - 1
              v.slideCount := to_unsigned(((i+10) mod 20)-1, 5);
              v.state      := SLIDE_S;
            else
              -- Reset the rx and hope for a new lock requiring an even number of slides
              v.state := RESET_S;
            end if;
          end if;
        end loop;

      when RESET_S =>
        -- Async reset will eventually get everything back to SEARCH_S state
        v.rxUserReset := '1';


      when SLIDE_S =>
        v.rxSlide := '1';
        v.state   := SLIDE_WAIT_S;

      when SLIDE_WAIT_S =>
        -- Wait SLIDE_WAIT_G clocks between each slide
        v.waitCounter := r.waitCounter + 1;
        if (r.waitCounter = "11111") then
          if (r.slideCount = 0) then
            v.state := SEARCH_S;        -- Double check that the slides worked
          else
            v.slideCount := r.slideCount - 1;
            v.state      := SLIDE_S;
          end if;
        end if;

      when ALIGNED_S =>
        v.aligned := '1';
        -- Reuse wait counter to count 8b10b errors
        -- After several errors, reset
        if (decodeErr = '1') then
          v.waitCounter := r.waitCounter + 1;
        end if;
        if (r.waitCounter = "11111") then
          v.state := RESET_S;
        end if;
        
    end case;

    rin <= v;

    rxSlide     <= r.rxSlide;
    rxUserReset <= r.rxUserReset;
    aligned     <= r.aligned;

  end process comb;

end architecture rtl;
