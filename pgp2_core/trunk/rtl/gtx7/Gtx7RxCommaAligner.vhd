-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : Gtx7PgpWordAligner.vhd
-- Author     : Benjamin Reese  <bareese@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2012-11-06
-- Last update: 2012-12-14
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


entity Gtx7RxCommaAligner is
  
  generic (
    TPD_G : time := 1 ns;
    COMMA_G : std_logic_vector(9 downto 0) := "0101111100";
    SLIDE_WAIT_G : integer := 32);

  port (
    gtRxUsrClk    : in  std_logic;
    gtRxUsrClkRst : in  std_logic;
    gtRxData      : in  std_logic_vector(19 downto 0);
    codeErr        : in  std_logic_vector(1 downto 0);
    dispErr        : in  std_logic_vector(1 downto 0);
    gtRxSlide     : out std_logic;
    gtRxReset  : out std_logic;
    aligned        : out std_logic);

end entity Gtx7RxCommaAligner;

architecture rtl of Gtx7RxCommaAligner is

  type StateType is (SEARCH_S, RESET_S, SLIDE_S, SLIDE_WAIT_0_S, SLIDE_WAIT_1_S, WAIT_SETTLE_S, ALIGNED_S);

  type RegType is record
    state       : StateType;
    last        : std_logic_vector(9 downto 0);
    slideCount  : unsigned(4 downto 0);
    waitCounter : unsigned(4 downto 0);

    -- Outputs
    gtRxSlide    : std_logic;
    gtRxCdrReset : std_logic;
    aligned       : std_logic;
  end record RegType;

  signal r, rin : RegType;

begin

  seq : process (gtRxUsrClk, gtRxUsrClkRstN) is
  begin
    if (gtRxUsrClkRstN = '0') then
      r.state       <= SEARCH_S        after TPD_G;
      r.last        <= (others => '0') after TPD_G;
      r.slideCount  <= (others => '0') after TPD_G;
      r.waitCounter <= (others => '0') after TPD_G;

      r.gtRxSlide    <= '0' after TPD_G;
      r.gtRxCdrReset <= '0' after TPD_G;
      r.aligned       <= '0' after TPD_G;
    elsif (rising_edge(gtRxUsrClk)) then
      r <= rin after TPD_G;
    end if;
  end process;

  comb : process (r, gtRxData, codeErr, dispErr) is
    variable v         : RegType;
    variable searchVar : std_logic_vector(29 downto 0);
  begin
    v := r;

    v.gtRxCdrReset := '0';
    v.gtRxSlide    := '0';
    v.aligned       := '0';

    v.last    := gtRxData(19 downto 10);  -- Save high byte
    searchVar := gtRxData & r.last;

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
              v.state         := RESET_S;
            end if;
          end if;
        end loop;

      when RESET_S =>
        -- Async reset will eventually get everything back to SEARCH_S state
        v.gtRxCdrReset := '1';


      when SLIDE_S =>
        v.gtRxSlide := '1';
        v.state      := SLIDE_WAIT_S;

      when SLIDE_WAIT_S =>
        -- Wait SLIDE_WAIT_G clocks between each slide
        v.waitCounter := r.waitCounter + 1;
        if (r.waitCounter = "11111") then
          if (r.slideCount = 0) then
            v.state := SEARCH_S;          -- Double check that the slides worked
          else
            v.slideCount := r.slideCount - 1;
            v.state := SLIDE_S;
          end if;
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

    gtRxSlide    <= r.gtRxSlide;
    gtRxCdrReset <= r.gtRxCdrReset;
    aligned       <= r.aligned;

  end process comb;

end architecture rtl;
