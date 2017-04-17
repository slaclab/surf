-------------------------------------------------------------------------------
-- File       : GtpPgpWordAligner.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2012-11-06
-- Last update: 2013-07-15
-------------------------------------------------------------------------------
-- Description: Pgp2 Gtp Word aligner
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

entity GtpRxCommaAligner is
  
  generic (
    TPD_G : time := 1 ns);

  port (
    gtpRxUsrClk2     : in  std_logic;
    gtpRxUsrClk2Rst : in  std_logic;
    gtpRxData        : in  std_logic_vector(19 downto 0);
    codeErr          : in  std_logic_vector(1 downto 0);
    dispErr          : in  std_logic_vector(1 downto 0);
    gtpRxUsrClk2Sel  : out std_logic;   -- Select phase of usrclk2
    gtpRxSlide       : out std_logic;
    gtpRxCdrReset    : out std_logic;
    aligned          : out std_logic);

end entity GtpRxCommaAligner;

architecture rtl of GtpRxCommaAligner is

  constant RAW_COMMA_C : std_logic_vector(9 downto 0) := "0101111100";

  type StateType is (SEARCH_S, RESET_S, SLIDE_S, SLIDE_WAIT_0_S, SLIDE_WAIT_1_S, WAIT_SETTLE_S, ALIGNED_S);

  type RegType is record
    state       : StateType;
    last        : std_logic_vector(9 downto 0);
    slideCount  : unsigned(2 downto 0);
    waitCounter : unsigned(4 downto 0);

    -- Outputs
    gtpRxUsrClk2Sel : std_logic;        -- Select phase of usrclk2
    gtpRxSlide      : std_logic;
    gtpRxCdrReset   : std_logic;
    aligned         : std_logic;
  end record RegType;

  signal r, rin : RegType;

begin

  seq : process (gtpRxUsrClk2, gtpRxUsrClk2Rst) is
  begin
    if (gtpRxUsrClk2Rst = '1') then
      r.state       <= SEARCH_S        after TPD_G;
      r.last        <= (others => '0') after TPD_G;
      r.slideCount  <= (others => '0') after TPD_G;
      r.waitCounter <= (others => '0') after TPD_G;

      r.gtpRxUsrClk2Sel <= '0' after TPD_G;
      r.gtpRxSlide      <= '0' after TPD_G;
      r.gtpRxCdrReset   <= '0' after TPD_G;
      r.aligned         <= '0' after TPD_G;
    elsif (rising_edge(gtpRxUsrClk2)) then
      r <= rin after TPD_G;
    end if;
  end process;

  comb : process (r, gtpRxData, codeErr, dispErr) is
    variable v         : RegType;
    variable searchVar : std_logic_vector(29 downto 0);
  begin
    v := r;

    v.gtpRxCdrReset := '0';
    v.gtpRxSlide    := '0';
    v.aligned       := '0';

    v.last    := gtpRxData(19 downto 10);  -- Save high byte
    searchVar := gtpRxData & r.last;

    case r.state is
      when SEARCH_S =>
        for i in 0 to 20 loop
          -- Look for pos or neg comma
          if (searchVar((i+9) downto i) = RAW_COMMA_C or searchVar(i+9 downto i) = not RAW_COMMA_C) then
            if (i = 2 or i = 4 or i = 6 or i = 8 or i = 0) then
--              v.slideCount := to_unsigned(9-i, 3);
--              v.state      := SLIDE_S;
              v.gtpRxUsrClk2Sel := not r.gtpRxUsrClk2Sel;  -- Invert clock
            elsif (i = 12 or i = 14 or i = 16 or i = 18) then
              v.slideCount := to_unsigned(i-11, 3);
              v.state      := SLIDE_S;
              -- Not sure if this can be done here.
              -- Might want some wait time before starting slides
              
            elsif (i = 10) then
              v.state := ALIGNED_S;
            else
              -- else reset the rx and hope for a new lock requiring an even number of slides
              v.gtpRxCdrReset := '1';
              v.state         := RESET_S;
            end if;
          end if;
        end loop;

      when RESET_S =>
        v.gtpRxCdrReset := '1';
        -- Async reset will eventually get everything back to SEARCH_S state

      when SLIDE_S =>
        v.gtpRxSlide := '1';
        v.state      := SLIDE_WAIT_0_S;

      when SLIDE_WAIT_0_S =>
        v.slideCount := r.slideCount - 1;
        if (r.slideCount = 0) then
          v.slideCount := (others => '0');
          v.state      := WAIT_SETTLE_S;
        else
          v.state := SLIDE_WAIT_1_S;
        end if;

      when SLIDE_WAIT_1_S =>
        v.state := SLIDE_S;

      when WAIT_SETTLE_S =>
        -- All the rxslide assertions take some time
        v.waitCounter := r.waitCounter + 1;
        if (r.waitCounter = "11111") then
          v.state := SEARCH_S;          -- Double check that the slides worked
        end if;

      when ALIGNED_S =>
        v.aligned := '1';
        -- Reuse wait counter to count 8b10b errors
        -- After several errors, reset
        if (codeErr /= "00" or dispErr /= "00") then
          v.waitCounter := r.waitCounter + 1;
        end if;
        if (r.waitCounter = "11111") then
           v.state := RESET_S;
        end if;
        
    end case;

    rin <= v;

    gtpRxUsrClk2Sel <= r.gtpRxUsrClk2Sel;
    gtpRxSlide      <= r.gtpRxSlide;
    gtpRxCdrReset   <= r.gtpRxCdrReset;
    aligned         <= r.aligned;

  end process comb;

end architecture rtl;
