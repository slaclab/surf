-------------------------------------------------------------------------------
-- File       : GtpTxPhaseAligner.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2012-11-12
-- Last update: 2012-12-06
-------------------------------------------------------------------------------
-- Description: GTH7 TX phase aligner
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

entity GtpTxPhaseAligner is
  
  generic (
    TPD_G : time := 1 ns);

  port (
    gtpTxUsrClk2         : in  std_logic;
    gtpReset             : in  std_logic;
    gtpPllLockDetect     : in  std_logic;
    gtpTxEnPmaPhaseAlign : out std_logic;
    gtpTxPmaSetPhase     : out std_logic;
    gtpTxAligned         : out std_logic);

end entity GtpTxPhaseAligner;

architecture rtl of GtpTxPhaseAligner is

  type StateType is (PHASE_ALIGN_S, SET_PHASE_S, ALIGNED_S);

  type RegType is record
    state                : StateType;
    counter              : unsigned(13 downto 0);
    gtpTxEnPmaPhaseAlign : std_logic;
    gtpTxPmaSetPhase     : std_logic;
  end record RegType;

  signal r, rin : RegType;

begin

  seq : process (gtpTxUsrClk2, gtpReset, gtpPllLockDetect) is
  begin
    if (gtpReset = '1' or gtpPllLockDetect = '0') then
      r.state                <= PHASE_ALIGN_S   after TPD_G;
      r.counter              <= (others => '0') after TPD_G;
      r.gtpTxEnPmaPhaseAlign <= '0'             after TPD_G;
      r.gtpTxPmaSetPhase     <= '0'             after TPD_G;
    elsif (rising_edge(gtpTxUsrClk2)) then
      r <= rin after TPD_G;
    end if;
  end process seq;

  comb : process (r) is
    variable v : RegType;
  begin
    v := r;

    v.gtpTxPmaSetPhase     := '0';
    v.gtpTxEnPmaPhaseAlign := '0';
    gtpTxAligned           <= '0';

    case r.state is
      when PHASE_ALIGN_S =>
        v.gtpTxPmaSetPhase     := '0';
        v.gtpTxEnPmaPhaseAlign := '1';
        v.counter              := r.counter + 1;
        if (r.counter(9) = '1') then    -- Count reached 512
          v.counter := (others => '0');
          v.state   := SET_PHASE_S;
        end if;

      when SET_PHASE_S =>
        v.gtpTxEnPmaPhaseAlign := '1';
        v.gtpTxPmaSetPhase     := '1';
        v.counter              := r.counter + 1;
        if (r.counter(13) = '1') then   -- Count reached 16384
          v.state := ALIGNED_S;
        end if;

      when ALIGNED_S =>
        v.gtpTxEnPmaPhaseAlign := '1';
        v.gtpTxPmaSetPhase     := '0';
        gtpTxAligned           <= '1';
    end case;

    rin <= v;

    gtpTxPmaSetPhase     <= r.gtpTxPmaSetPhase;
    gtpTxEnPmaPhaseAlign <= r.gtpTxEnPmaPhaseAlign;

    
  end process comb;

end architecture rtl;
