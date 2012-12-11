-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : GtxPgpWordAligner.vhd
-- Author     : Benjamin Reese  <bareese@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2012-11-06
-- Last update: 2012-12-10
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2012 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.Pgp2CoreTypesPkg.all;


entity GtxRxCommaAligner is
  
  generic (
    TPD_G : time := 1 ns);

  port (
    gtxRxUsrClk    : in  std_logic;
    gtxRxUsrClkRst : in  std_logic;
    gtxRxData      : in  std_logic_vector(19 downto 0);
    codeErr        : in  std_logic_vector(1 downto 0);
    dispErr        : in  std_logic_vector(1 downto 0);
    gtxRxSlide     : out std_logic;
    gtxRxCdrReset  : out std_logic;
    aligned        : out std_logic);

end entity GtxRxCommaAligner;

architecture rtl of GtxRxCommaAligner is

  constant RAW_COMMA_C : std_logic_vector(9 downto 0) := "0101111100";

  type StateType is (SEARCH_S, RESET_S, SLIDE_S, SLIDE_WAIT_0_S, SLIDE_WAIT_1_S, WAIT_SETTLE_S, ALIGNED_S);

  type RegType is record
    state       : StateType;
    last        : std_logic_vector(9 downto 0);
    slideCount  : unsigned(4 downto 0);
    waitCounter : unsigned(4 downto 0);

    -- Outputs
    gtxRxSlide    : std_logic;
    gtxRxCdrReset : std_logic;
    aligned       : std_logic;
  end record RegType;

  signal r, rin : RegType;

begin

  seq : process (gtxRxUsrClk, gtxRxUsrClkRst) is
  begin
    if (gtxRxUsrClkRst = '1') then
      r.state       <= SEARCH_S        after TPD_G;
      r.last        <= (others => '0') after TPD_G;
      r.slideCount  <= (others => '0') after TPD_G;
      r.waitCounter <= (others => '0') after TPD_G;

      r.gtxRxSlide    <= '0' after TPD_G;
      r.gtxRxCdrReset <= '0' after TPD_G;
      r.aligned       <= '0' after TPD_G;
    elsif (rising_edge(gtxRxUsrClk)) then
      r <= rin after TPD_G;
    end if;
  end process;

  comb : process (r, gtxRxData, codeErr, dispErr) is
    variable v         : RegType;
    variable searchVar : std_logic_vector(29 downto 0);
  begin
    v := r;

    v.gtxRxCdrReset := '0';
    v.gtxRxSlide    := '0';
    v.aligned       := '0';

    v.last    := gtxRxData(19 downto 10);  -- Save high byte
    searchVar := gtxRxData & r.last;

    case r.state is
      when SEARCH_S =>
        for i in 1 to 20 loop
          -- Look for pos or neg comma
          if (searchVar((i+9) downto i) = RAW_COMMA_C or searchVar(i+9 downto i) = not RAW_COMMA_C) then
            if (i = 10) then
              v.state := ALIGNED_S;
            elsif (i mod 2 = 0) then
              -- Even number of slides needed
              v.slideCount := to_unsigned(((i+10) mod 20)-1, 5);
              v.state      := SLIDE_S;
            else
              -- else reset the rx and hope for a new lock requiring an even number of slides
              v.gtxRxCdrReset := '1';
              v.state         := RESET_S;
            end if;
          end if;
        end loop;

      when RESET_S =>
        v.gtxRxCdrReset := '1';
--        v.slideCount := r.slideCount + 1;
--        if (r.slideCount = 3) then
--          v.state := SEARCH_S;
--        end if;
        -- Async reset will eventually get everything back to SEARCH_S state

      when SLIDE_S =>
        v.gtxRxSlide := '1';
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

    gtxRxSlide    <= r.gtxRxSlide;
    gtxRxCdrReset <= r.gtxRxCdrReset;
    aligned       <= r.aligned;

  end process comb;

end architecture rtl;
