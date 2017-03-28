-------------------------------------------------------------------------------
-- File       : Gtx7TxManualPhaseAligner.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-05-23
-- Last update: 2013-06-13
-------------------------------------------------------------------------------
-- Description: GTX7 TX manual phase aligner
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Firmware Standard Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'SLAC Firmware Standard Library', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.all;
use work.StdRtlPkg.all;

entity Gtx7TxManualPhaseAligner is
   generic (
      TPD_G : time := 1 ns);
   port (
      stableClk : in sl;

      -- TX RST IO
      resetPhAlignment   : in  sl;
      runPhAlignment     : in  sl;
      phaseAlignmentDone : out sl;

      -- GT IO - Inputs are asynchronous
      gtTxDlySReset     : out sl;
      gtTxDlySResetDone : in  sl;
      gtTxPhInit        : out sl;
      gtTxPhInitDone    : in  sl;
      gtTxPhAlign       : out sl;
      gtTxPhAlignDone   : in  sl;
      gtTxDlyEn         : out sl);
end Gtx7TxManualPhaseAligner;

architecture rtl of Gtx7TxManualPhaseAligner is

   type StateType is (
      INIT_S,
      WAIT_DLY_SRESET_DONE_S,
      WAIT_PH_INIT_DONE_S,
      WAIT_PH_ALIGN_DONE_S,
      WAIT_PH_ALIGN_DONE_2_S,
      DONE_S);

   type RegType is record
      state              : StateType;
      -- Outputs
      phaseAlignmentDone : sl;
      gtTxDlySReset      : sl;
      gtTxPhInit         : sl;
      gtTxPhAlign        : sl;
      gtTxDlyEn          : sl;
   end record RegType;

   constant REG_RESET_C : RegType := (
      state              => INIT_S,
      phaseAlignmentDone => '0',
      gtTxDlySReset      => '0',
      gtTxPhInit         => '0',
      gtTxPhAlign        => '0',
      gtTxDlyEn          => '0');

   signal r, rin : RegType := REG_RESET_C;

   signal gtTxDlySResetDoneSync : sl;
   signal gtTxPhInitDoneSync    : sl;
   signal gtTxPhAlignDoneSync   : sl;
   signal gtTxPhAlignDoneEdge   : sl;

   attribute KEEP_HIERARCHY : string;
   attribute KEEP_HIERARCHY of 
      TX_DLY_S_RESET_DONE_SYNC,
      TX_PH_INIT_DONE_SYNC,
      TX_PH_ALIGN_DONE_SYNC : label is "TRUE";
   
begin

   TX_DLY_S_RESET_DONE_SYNC : entity work.Synchronizer
      generic map (
         TPD_G => TPD_G)
      port map (
         clk     => stableClk,
         dataIn  => gtTxDlySResetDone,
         dataOut => gtTxDlySResetDoneSync);

   TX_PH_INIT_DONE_SYNC : entity work.Synchronizer
      generic map (
         TPD_G => TPD_G)
      port map (
         clk     => stableClk,
         dataIn  => gtTxPhInitDone,
         dataOut => gtTxPhInitDoneSync);

   TX_PH_ALIGN_DONE_SYNC : entity work.SynchronizerEdge
      generic map (
         TPD_G => TPD_G)
      port map (
         clk         => stableClk,
         dataIn      => gtTxPhAlignDone,
         dataOut     => gtTxPhAlignDoneSync,
         risingEdge  => gtTxPhAlignDoneEdge,
         fallingEdge => open);

   comb : process (r, gtTxDlySResetDoneSync, gtTxPhInitDoneSync, gtTxPhAlignDoneSync, gtTxPhAlignDoneEdge,
                   resetPhAlignment, runPhAlignment) is
      variable v : RegType;
   begin
      v := r;

      case (r.state) is
         when INIT_S =>
            if (runPhAlignment = '1') then
               v.gtTxDlySReset := '1';
               v.state         := WAIT_DLY_SRESET_DONE_S;
            end if;

         when WAIT_DLY_SRESET_DONE_S =>
            -- When resetDone arrives, lower reset and raise phInit
            if (gtTxDlySResetDoneSync = '1') then
               v.gtTxDlySReset := '0';
               v.gtTxPhInit    := '1';
               v.state         := WAIT_PH_INIT_DONE_S;
            end if;

         when WAIT_PH_INIT_DONE_S =>
            if (gtTxPhInitDoneSync = '1') then
               v.gtTxPhInit  := '0';
               v.gtTxPhAlign := '1';
               v.state       := WAIT_PH_ALIGN_DONE_S;
            end if;

         when WAIT_PH_ALIGN_DONE_S =>
            if (gtTxPhAlignDoneEdge = '1') then
               v.gtTxPhAlign := '0';
               v.gtTxDlyEn   := '1';
--               v.state       := WAIT_PH_ALIGN_DONE_2_S;
               v.state := DONE_S;
            end if;

         when WAIT_PH_ALIGN_DONE_2_S =>
            if (gtTxPhAlignDoneEdge = '1') then
               v.gtTxDlyEn := '0';
               v.state     := DONE_S;
            end if;

         when DONE_S =>
            v.phaseAlignmentDone := '1';
            
         when others => null;
      end case;

      if (resetPhAlignment = '1') then
         v := REG_RESET_C;
      end if;

      rin <= v;

      phaseAlignmentDone <= r.phaseAlignmentDone;
      gtTxDlySReset      <= r.gtTxDlySReset;
      gtTxPhInit         <= r.gtTxPhInit;
      gtTxPhAlign        <= r.gtTxPhAlign;
      gtTxDlyEn          <= r.gtTxDlyEn;
      
   end process comb;

   seq : process (stableClk) is
   begin
      if rising_edge(stableClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;
end architecture rtl;
