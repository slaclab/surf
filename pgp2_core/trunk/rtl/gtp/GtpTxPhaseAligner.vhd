-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : GtpTxPhaseAligner.vhd
-- Author     : Benjamin Reese  <bareese@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2012-11-12
-- Last update: 2012-11-26
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

entity GtpTxPhaseAligner is
  
  generic (
    TPD_G : time := 1 ns);

  port (
    pgpTxClk             : in  std_logic;
    gtpReset             : in  std_logic;
    gtpPllLockDetect     : in  std_logic;
    gtpTxClkLocked       : in  std_logic;
    gtpTxEnPmaPhaseAlign : out std_logic;
    gtpTxPmaSetPhase     : out std_logic);

end entity GtpTxPhaseAligner;

architecture rtl of GtpTxPhaseAligner is

  type StateType is (PHASE_ALIGN_S, SET_PHASE_S, ALIGNED_S);

  type RegType is record
    state                : StateType;
    counter              : unsigned(11 downto 0);
    gtpTxEnPmaPhaseAlign : std_logic;
    gtpTxPmaSetPhase     : std_logic;
  end record RegType;

  signal r, rin : RegType;

begin

  seq : process (pgpTxClk, gtpReset, gtpPllLockDetect, gtpTxClkLocked) is
  begin
    if (gtpReset = '1' or gtpPllLockDetect = '0' or gtpTxClkLocked = '0') then
      r.state                <= PHASE_ALIGN_S   after TPD_G;
      r.counter              <= (others => '0') after TPD_G;
      r.gtpTxEnPmaPhaseAlign <= '0'             after TPD_G;
      r.gtpTxPmaSetPhase     <= '0'             after TPD_G;
    elsif (rising_edge(pgpTxClk)) then
      r <= rin after TPD_G;
    end if;
  end process seq;

  comb : process (r) is
    variable v : RegType;
  begin
    v := r;

    v.gtpTxPmaSetPhase     := '0';
    v.gtpTxEnPmaPhaseAlign := '0';

    case r.state is
      when PHASE_ALIGN_S =>
        v.gtpTxPmaSetPhase     := '0';
        v.gtpTxEnPmaPhaseAlign := '1';
        v.counter              := r.counter + 1;
        if (r.counter = 512) then
          v.counter := (others => '0');
          v.state   := SET_PHASE_S;
        end if;

      when SET_PHASE_S =>
        v.gtpTxEnPmaPhaseAlign := '1';
        v.gtpTxPmaSetPhase     := '1';
        v.counter              := r.counter + 1;
        if (r.counter = 4095) then
          v.state := ALIGNED_S;
        end if;

      when ALIGNED_S =>
        v.gtpTxEnPmaPhaseAlign := '1';
        v.gtpTxPmaSetPhase     := '0';
        
    end case;

    rin <= v;

    gtpTxPmaSetPhase     <= r.gtpTxPmaSetPhase;
    gtpTxEnPmaPhaseAlign <= r.gtpTxEnPmaPhaseAlign;

  end process comb;

end architecture rtl;
