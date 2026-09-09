-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Initial lane alignment sequence Generator
--              Adds A and R characters at the LMFC borders.
--              Second ILAS multiframe (mfCnt=1) carries /Q/ (0x9C) at octet 1
--              followed by 14 link-configuration octets (incl. FCHK).
--
-- Spec: JESD204B 8.2 Figure 50 rules 3/4; 8.3 Table 20/21
-- Observed: JesdIlasGen previously emitted only /R/ and /A/; second multiframe
--           lacked /Q/ and link-config octets entirely.
-- Root cause: No mfCnt tracking; config-octet emission logic absent.
-- Fix: Added mfCnt/wordCnt counters; MF2 (mfCnt=1) now emits /Q/ + 14 config
--      octets in GT byte order data[7:0]=first-transmitted. Config generics
--      (DID_G..CF_G) and runtime ports (lid_i, scrEnable_i, subClass_i) are
--      all defaulted so existing instantiations compile unchanged.
-- JESDV=001 (JESD204B, Table 20). ADJCNT/ADJDIR/PHADJ left 0 (Subclass-2 only).
-- RES1/RES2 set to 0x00 (Table 21 "set to all X" - transmit as 0).
-- FCHK = Sigma(config[0..12]) mod 256 per 8.3 Table 20 CHKSUM.
-- Interop: SURF RX ILA state counts multiframes, does not parse config octets
--          (JesdSyncFsmRx ILA_S state); config-octet content cannot break
--          SURF<->SURF loopback.
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
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

library surf;
use surf.StdRtlPkg.all;
use surf.Jesd204bpkg.all;

entity JesdIlasGen is
   generic (
      TPD_G    : time            := 1 ns;
      F_G      : positive        := 2;
      K_G      : positive        := 32;
      L_G      : positive        := 1;         -- Lanes in link (Table 21 octet 3, encoded L-1)
      -- ILAS config generics (all default 0 -- existing instances unaffected)
      DID_G    : slv(7 downto 0) := x"00";     -- Device ID
      BID_G    : slv(3 downto 0) := x"0";      -- Bank ID
      M_G      : slv(7 downto 0) := x"00";     -- Converters per device - 1
      N_G      : slv(4 downto 0) := "00000";   -- Converter resolution - 1
      NPRIME_G : slv(4 downto 0) := "00000";   -- Total bits/sample - 1
      CS_G     : slv(1 downto 0) := "00";      -- Control bits/sample
      S_G      : slv(4 downto 0) := "00000";   -- Samples/converter/frame - 1
      HD_G     : sl              := '0';       -- High-density format
      CF_G     : slv(4 downto 0) := "00000");  -- Control words/frame/lane
   port (
      clk : in sl;
      rst : in sl;

      -- Enable counter
      enable_i : in sl;

      -- Increase counter
      ilas_i : in sl;

      -- Increase counter
      lmfc_i : in sl;

      -- Runtime fields sourced from JesdTxLane
      lid_i       : in slv(4 downto 0);  -- Lane ID (Table 21 octet 2)
      scrEnable_i : in sl;               -- SCR field (octet 3 bit 7)
      subClass_i  : in sl;               -- SUBCLASSV (octet 8 bits [7:5])

      -- Outs
      ilasData_o : out slv(GT_WORD_SIZE_C*8-1 downto 0);
      ilasK_o    : out slv(GT_WORD_SIZE_C-1 downto 0));
end entity JesdIlasGen;

architecture rtl of JesdIlasGen is

   type RegType is record
      lmfcD1  : sl;
      lmfcD2  : sl;
      -- multiframe counter and word counter for config-octet placement
      mfCnt   : slv(7 downto 0);  -- counts lmfc_i pulses while ilas_i='1' (0-indexed)
      wordCnt : slv(7 downto 0);  -- GT-word counter within current multiframe
   end record RegType;

   constant REG_INIT_C : RegType := (
      lmfcD1  => '0',
      lmfcD2  => '0',
      mfCnt   => (others => '0'),
      wordCnt => (others => '0'));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   comb : process (enable_i, ilas_i, lid_i, lmfc_i, r, rst, scrEnable_i,
                   subClass_i) is
      variable v         : RegType;
      variable vIlasData : slv(ilasData_o'range);
      variable vIlasK    : slv(ilasK_o'range);
      -- Config octets [0..13] for MF2 (JESD204B Table 21)
      variable cfg     : Slv8Array(0 to 13);
      variable fchkSum : slv(9 downto 0);
   begin
      v := r;

      -- Delay LMFC for 2 c-c
      v.lmfcD1 := lmfc_i;
      v.lmfcD2 := r.lmfcD1;

      -- Combinatorial logic
      vIlasData := (others => '0');
      vIlasK    := (others => '0');

      -- Count LMFC pulses while in ILAS (mfCnt) and GT words within multiframe (wordCnt)
      if enable_i = '1' and ilas_i = '1' then
         if lmfc_i = '1' then
            v.mfCnt   := r.mfCnt + 1;
            v.wordCnt := (others => '0');
         else
            v.wordCnt := r.wordCnt + 1;
         end if;
      else
         v.mfCnt   := (others => '0');
         v.wordCnt := (others => '0');
      end if;

      -- Build 14 config octets per JESD204B 8.3 Table 21
      -- octet 0: DID[7:0]
      cfg(0)  := DID_G;
      -- octet 1: ADJCNT[7:4]=0 (Subclass-2 only), BID[3:0]
      cfg(1)  := "0000" & BID_G;
      -- octet 2: X=0, ADJDIR=0, PHADJ=0, LID[4:0]
      cfg(2)  := "000" & lid_i;
      -- octet 3: SCR[7], X=0, X=0, L-1[4:0] (Table 21 lane count, L encoded as L-1)
      cfg(3)  := scrEnable_i & "00" & conv_std_logic_vector(L_G - 1, 5);
      -- octet 4: F-1 [7:0]
      cfg(4)  := conv_std_logic_vector(F_G - 1, 8);
      -- octet 5: X=0, X=0, X=0, K-1 [4:0]
      cfg(5)  := "000" & conv_std_logic_vector(K_G - 1, 5);
      -- octet 6: M[7:0]
      cfg(6)  := M_G;
      -- octet 7: CS[7:6], X=0, N[4:0]
      cfg(7)  := CS_G & '0' & N_G;
      -- octet 8: SUBCLASSV[7:5], N'[4:0]  (Table 21: SUBCLASSV<2:0> | N'<4:0>)
      -- SUBCLASSV: 000=Subclass0, 001=Subclass1 -- 3-bit field at [7:5]
      cfg(8)  := "00" & subClass_i & NPRIME_G;
      -- octet 9: JESDV[7:5]=001 (JESD204B), S[4:0]  (Table 21: JESDV<2:0> | S<4:0>)
      -- JESDV=001 per Table 20 "001 - JESD204B"
      cfg(9)  := "001" & S_G;
      -- octet 10: HD[7], X=0, X=0, CF[4:0]
      cfg(10) := HD_G & "00" & CF_G;
      -- octet 11: RES1 = 0x00 (Table 21 "set to all X" -- transmit 0)
      cfg(11) := x"00";
      -- octet 12: RES2 = 0x00
      cfg(12) := x"00";
      -- octet 13: FCHK = Sigma(cfg[0..12]) mod 256  (Table 20 CHKSUM)
      fchkSum := (others => '0');
      for i in 0 to 12 loop
         fchkSum := fchkSum + ("00" & cfg(i));
      end loop;
      cfg(13) := fchkSum(7 downto 0);

      if enable_i = '1' and ilas_i = '1' then
         -- Send A character (end of previous multiframe)
         if r.lmfcD1 = '1' then
            vIlasData(vIlasData'high downto vIlasData'high-7) := A_CHAR_C;
            vIlasK(vIlasK'high)                               := '1';
         end if;
         -- Send R character (start of new multiframe)
         if r.lmfcD2 = '1' then
            vIlasData(7 downto 0) := R_CHAR_C;
            vIlasK(0)             := '1';
            -- MF2 (mfCnt=1): place /Q/ + config[0..1] in the same GT word as /R/
            -- GT byte order: data[7:0]=first tx, so /R/=octet0, /Q/=octet1,
            -- config[0]=octet2, config[1]=octet3 of the lmfcD2 GT word
            if r.mfCnt = x"01" then
               vIlasData(15 downto 8)  := Q_CHAR_C;
               vIlasK(1)               := '1';
               vIlasData(23 downto 16) := cfg(0);  -- DID
               vIlasData(31 downto 24) := cfg(1);  -- ADJCNT/BID
            end if;
         end if;
         -- MF2 follow-on words carrying config[2..13]
         -- wordCnt=1: lmfcD2 clock (r.wordCnt=1 when r.lmfcD2=1); /R/+/Q/+cfg0+cfg1
         --            placed above by the r.lmfcD2='1' block -- no follow-on here.
         -- wordCnt=2: cfg[2..5] (LID, SCR/L, F-1, K-1)
         -- wordCnt=3: cfg[6..9] (M, CS/N, SUBCLASSV/N', JESDV/S)
         -- wordCnt=4: cfg[10..13] (HD/CF, RES1, RES2, FCHK)
         -- Note: wordCnt resets to 0 on lmfc_i='1'; increments to 1 at lmfcD1,
         --       to 2 at lmfcD2+1, etc.  The lmfcD2='1' word corresponds to
         --       wordCnt=1, so follow-on starts at wordCnt=2.
         if r.mfCnt = x"01" then
            if r.wordCnt = x"02" then
               vIlasData(7 downto 0)   := cfg(2);
               vIlasData(15 downto 8)  := cfg(3);
               vIlasData(23 downto 16) := cfg(4);
               vIlasData(31 downto 24) := cfg(5);
            end if;
            if r.wordCnt = x"03" then
               vIlasData(7 downto 0)   := cfg(6);
               vIlasData(15 downto 8)  := cfg(7);
               vIlasData(23 downto 16) := cfg(8);
               vIlasData(31 downto 24) := cfg(9);
            end if;
            if r.wordCnt = x"04" then
               vIlasData(7 downto 0)   := cfg(10);
               vIlasData(15 downto 8)  := cfg(11);
               vIlasData(23 downto 16) := cfg(12);
               vIlasData(31 downto 24) := cfg(13);
            end if;
         end if;
      end if;

      if (rst = '1') then
         v := REG_INIT_C;
      end if;

      rin <= v;

      -- Output assignment
      ilasData_o <= vIlasData;
      ilasK_o    <= vIlasK;
   end process comb;

   seq : process (clk) is
   begin
      if (rising_edge(clk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end architecture rtl;
