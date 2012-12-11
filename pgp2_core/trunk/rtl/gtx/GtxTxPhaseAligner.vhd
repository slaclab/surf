-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : GtxTxPhaseAligner.vhd
-- Author     : Benjamin Reese  <bareese@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2012-11-12
-- Last update: 2012-12-07
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

entity GtxTxPhaseAligner is
  
  generic (
    TPD_G : time := 1 ns);

  port (
    gtxTxUsrClk         : in  std_logic;
    gtxReset             : in  std_logic;
    gtxPllLockDetect     : in  std_logic;
    gtxTxEnPmaPhaseAlign : out std_logic;
    gtxTxPmaSetPhase     : out std_logic;
    gtxTxAligned         : out std_logic);

end entity GtxTxPhaseAligner;

architecture rtl of GtxTxPhaseAligner is

  type StateType is (PHASE_ALIGN_S, SET_PHASE_S, ALIGNED_S);

  type RegType is record
    state                : StateType;
    counter              : unsigned(12 downto 0);
    gtxTxEnPmaPhaseAlign : std_logic;
    gtxTxPmaSetPhase     : std_logic;
  end record RegType;

  signal r, rin : RegType;

begin

  seq : process (gtxTxUsrClk, gtxReset, gtxPllLockDetect) is
  begin
    if (gtxReset = '1' or gtxPllLockDetect = '0') then
      r.state                <= PHASE_ALIGN_S   after TPD_G;
      r.counter              <= (others => '0') after TPD_G;
      r.gtxTxEnPmaPhaseAlign <= '0'             after TPD_G;
      r.gtxTxPmaSetPhase     <= '0'             after TPD_G;
    elsif (rising_edge(gtxTxUsrClk)) then
      r <= rin after TPD_G;
    end if;
  end process seq;

  comb : process (r) is
    variable v : RegType;
  begin
    v := r;

    v.gtxTxPmaSetPhase     := '0';
    v.gtxTxEnPmaPhaseAlign := '0';
    gtxTxAligned           <= '0';

    case r.state is
      when PHASE_ALIGN_S =>
        v.gtxTxPmaSetPhase     := '0';
        v.gtxTxEnPmaPhaseAlign := '1';
        v.counter              := r.counter + 1;
        if (r.counter(5) = '1') then    -- Count reached 32
          v.counter := (others => '0');
          v.state   := SET_PHASE_S;
        end if;

      when SET_PHASE_S =>
        v.gtxTxEnPmaPhaseAlign := '1';
        v.gtxTxPmaSetPhase     := '1';
        v.counter              := r.counter + 1;
        if (r.counter(12) = '1') then   -- Count reached 8192
          v.state := ALIGNED_S;
        end if;

      when ALIGNED_S =>
        v.gtxTxEnPmaPhaseAlign := '1';
        v.gtxTxPmaSetPhase     := '0';
        gtxTxAligned           <= '1';
    end case;

    rin <= v;

    gtxTxPmaSetPhase     <= r.gtxTxPmaSetPhase;
    gtxTxEnPmaPhaseAlign <= r.gtxTxEnPmaPhaseAlign;

    
  end process comb;

end architecture rtl;
