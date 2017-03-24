-------------------------------------------------------------------------------
-- File       : Code8b10bPkg.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-10-12
-- Last update: 2016-10-12
-------------------------------------------------------------------------------
-- Description: 8B10B Package File
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

package Code8b10bPkg is

   -------------------------------------------------------------------------------------------------
   -- Control Code Constants
   -------------------------------------------------------------------------------------------------
   constant K_28_0_C : slv(7 downto 0) := "00011100";  -- K28.0, 0x1C
   constant K_28_1_C : slv(7 downto 0) := "00111100";  -- K28.1, 0x3C (Comma)
   constant K_28_2_C : slv(7 downto 0) := "01011100";  -- K28.2, 0x5C
   constant K_28_3_C : slv(7 downto 0) := "01111100";  -- K28.3, 0x7C
   constant K_28_4_C : slv(7 downto 0) := "10011100";  -- K28.4, 0x9C
   constant K_28_5_C : slv(7 downto 0) := "10111100";  -- K28.5, 0xBC (Comma)
   constant K_28_6_C : slv(7 downto 0) := "11011100";  -- K28.6, 0xDC
   constant K_28_7_C : slv(7 downto 0) := "11111100";  -- K28.7, 0xFC (Comma)
   constant K_23_7_C : slv(7 downto 0) := "11110111";  -- K23.7, 0xF7
   constant K_27_7_C : slv(7 downto 0) := "11111011";  -- K27.7, 0xFB
   constant K_29_7_C : slv(7 downto 0) := "11111101";  -- K29.7, 0xFD
   constant K_30_7_C : slv(7 downto 0) := "11111110";  -- K30.7, 0xFE

   constant D_10_2_C : slv(7 downto 0) := "01001010";  -- D10.2, 0x4A
   constant D_21_5_C : slv(7 downto 0) := "10110101";  -- D21.5, 0xB5

   procedure encode8b10b (
      dataIn  : in  slv(7 downto 0);
      dataKIn : in  sl;
      dispIn  : in  sl;
      dataOut : out slv(9 downto 0);
      dispOut : out sl);

   procedure decode8b10b (
      dataIn   : in  slv(9 downto 0);
      dispIn   : in  sl;
      dataOut  : out slv(7 downto 0);
      dataKOut : out sl;
      dispOut  : out sl;
      codeErr  : out sl;
      dispErr  : out sl);

end package Code8b10bPkg;

package body Code8b10bPkg is

   procedure encode8b10b (
      dataIn  : in  slv(7 downto 0);
      dataKIn : in  sl;
      dispIn  : in  sl;
      dataOut : out slv(9 downto 0);
      dispOut : out sl)
   is
      variable ai, bi, ci, di, ei, fi, gi, hi, ki     : sl;
      variable aeqb, ceqd                             : sl;
      variable l22, l40, l04, l13, l31                : sl;
      variable ao, bo, co, do, eo, io, fo, go, ho, jo : sl;
      variable pd1s6, nd1s6, ndos6, pdos6             : sl;
      variable alt6, alt7                             : sl;
      variable nd1s4, pd1s4, ndos4, pdos4             : sl;
      variable illegalk                               : sl;
      variable compls6, disp6, compls4                : sl;
   begin
      
      ai := dataIn(0);
      bi := dataIn(1);
      ci := dataIn(2);
      di := dataIn(3);
      ei := dataIn(4);
      fi := dataIn(5);
      gi := dataIn(6);
      hi := dataIn(7);
      ki := dataKIn;

      aeqb := (ai and bi) or (not ai and not bi);
      ceqd := (ci and di) or (not ci and not di);
      l22  := (ai and bi and not ci and not di) or
              (ci and di and not ai and not bi) or
              (not aeqb and not ceqd);
      l40 := ai and bi and ci and di;
      l04 := not ai and not bi and not ci and not di;
      l13 := (not aeqb and not ci and not di) or
             (not ceqd and not ai and not bi);
      l31 := (not aeqb and ci and di) or
             (not ceqd and ai and bi);

      -- The 5B/6B encoding

      ao := ai;
      bo := (bi and not l40) or l04;
      co := l04 or ci or (ei and di and not ci and not bi and not ai);
      do := di and not (ai and bi and ci);
      eo := (ei or l13) and not (ei and di and not ci and not bi and not ai);
      io := (l22 and not ei) or
            (ei and not di and not ci and not (ai and bi)) or   -- D16, D17, D18
            (ei and l40) or
            (ki and ei and di and ci and not bi and not ai) or  -- K.28
            (ei and not di and ci and not bi and not ai);

      -- pds16 indicates cases where d-1 is assumed + to get our encoded value
      pd1s6 := (ei and di and not ci and not bi and not ai) or (not ei and not l22 and not l31);
      -- nds16 indicates cases where d-1 is assumed - to get our encoded value
      nd1s6 := ki or (ei and not l22 and not l13) or (not ei and not di and ci and bi and ai);

      -- ndos6 is pds16 cases where d-1 is + yields - disp out - all of them
      ndos6 := pd1s6;
      -- pdos6 is nds16 cases where d-1 is - yields + disp out - all but one
      pdos6 := ki or (ei and not l22 and not l13);


      -- some Dx.7 and all Kx.7 cases result in run length of 5 case unless
      -- an alternate coding is used (referred to as Dx.A7, normal is Dx.P7)
      -- specifically, D11, D13, D14, D17, D18, D19.
      if (dispIn = '1') then
         alt6 := (not ei and di and l31);
      else
         alt6 := (ei and not di and l13);
      end if;
      alt7 := fi and gi and hi and (ki or alt6);

      fo := fi and not alt7;
      go := gi or (not fi and not gi and not hi);
      ho := hi;
      jo := (not hi and (gi xor fi)) or alt7;

      -- nd1s4 is cases where d-1 is assumed - to get our encoded value
      nd1s4 := fi and gi;
      -- pd1s4 is cases where d-1 is assumed + to get our encoded value
      pd1s4 := (not fi and not gi) or (ki and ((fi and not gi) or (not fi and gi)));

      -- ndos4 is pd1s4 cases where d-1 is + yields - disp out - just some
      ndos4 := (not fi and not gi);
      -- pdos4 is nd1s4 cases where d-1 is - yields + disp out
      pdos4 := fi and gi and hi;

      -- only legal K codes are K28.0- > .7, K23/27/29/30.7
      -- K28.0- > 7 is ei = di = ci = 1, bi = ai = 0
      -- K23 is 10111
      -- K27 is 11011
      -- K29 is 11101
      -- K30 is 11110 - so K23/27/29/30 are ei and l31
      illegalk := ki and
                  (ai or bi or not ci or not di or not ei) and        -- not K28.0- > 7
                  (not fi or not gi or not hi or not ei or not l31);  -- not K23/27/29/30.7

      -- now determine whether to do the complementing
      -- complement if prev disp is - and pd1s6 is set, or + and nd1s6 is set
      compls6 := (pd1s6 and not dispin) or (nd1s6 and dispin);

      -- disparity out of 5b6b is disp in with pdso6 and ndso6
      -- pds16 indicates cases where d-1 is assumed + to get our encoded value
      -- ndos6 is cases where d-1 is + yields - disp out
      -- nds16 indicates cases where d-1 is assumed - to get our encoded value
      -- pdos6 is cases where d-1 is - yields + disp out
      -- disp toggles in all ndis16 cases, and all but that 1 nds16 case

      disp6 := dispin xor (ndos6 or pdos6);

      compls4 := (pd1s4 and not disp6) or (nd1s4 and disp6);
      dispOut := disp6 xor (ndos4 or pdos4);

      dataOut := (jo xor compls4) & (ho xor compls4) &
                 (go xor compls4) & (fo xor compls4) &
                 (io xor compls6) & (eo xor compls6) &
                 (do xor compls6) & (co xor compls6) &
                 (bo xor compls6) & (ao xor compls6);

   end procedure encode8b10b;

   procedure decode8b10b (
      dataIn   : in  slv(9 downto 0);
      dispIn   : in  sl;
      dataOut  : out slv(7 downto 0);
      dataKOut : out sl;
      dispOut  : out sl;
      codeErr  : out sl;
      dispErr  : out sl)
   is
      variable ai, bi, ci, di, ei, ii, fi, gi, hi, ji      : sl;
      variable aeqb, ceqd                                  : sl;
      variable p22, p13, p31, p40, p04                     : sl;
      variable disp6a, disp6a2, disp6a0, disp6b            : sl;
      variable p22bceeqi, p22bncneeqi, p13in, p31i, p13dei : sl;
      variable p22aceeqi, p22ancneeqi                      : sl;
      variable p13en, anbnenin, abei, cdei, cndnenin       : sl;
      variable p22enin, p22ei, p31dnenin, p31e             : sl;
      variable compa, compb, compc, compd, compe           : sl;
      variable ao, bo, co, do, eo, ko, fo, go, ho          : sl;
      variable feqg, heqj, fghj22, fghjp13, fghjp31        : sl;
      variable alt7, k28, k28p                             : sl;
      variable disp6p, disp6n, disp4p, disp4n              : sl;
   begin

      ai := dataIn(0);
      bi := dataIn(1);
      ci := dataIn(2);
      di := dataIn(3);
      ei := dataIn(4);
      ii := dataIn(5);
      fi := dataIn(6);
      gi := dataIn(7);
      hi := dataIn(8);
      ji := dataIn(9);

      aeqb := (ai and bi) or (not ai and not bi);
      ceqd := (ci and di) or (not ci and not di);
      p22  := (ai and bi and not ci and not di) or
              (ci and di and not ai and not bi) or
              (not aeqb and not ceqd);
      p13 := (not aeqb and not ci and not di) or
             (not ceqd and not ai and not bi);
      p31 := (not aeqb and ci and di) or
             (not ceqd and ai and bi);

      p40 := ai and bi and ci and di;
      p04 := not ai and not bi and not ci and not di;

      disp6a  := p31 or (p22 and dispin);  -- pos disp if p22 and was pos, or p31.
      disp6a2 := p31 and dispin;           -- disp is ++ after 4 bits
      disp6a0 := p13 and not dispin;       -- -- disp after 4 bits
      
      disp6b := (((ei and ii and not disp6a0) or (disp6a and (ei or ii)) or disp6a2 or
                  (ei and ii and di)) and (ei or ii or di)) ;

      -- The 5B/6B decoding special cases where ABCDE not = abcde

      p22bceeqi   := p22 and bi and ci and (ei xnor ii);
      p22bncneeqi := p22 and not bi and not ci and (ei xnor ii);
      p13in       := p13 and not ii;
      p31i        := p31 and ii;
      p13dei      := p13 and di and ei and ii;
      p22aceeqi   := p22 and ai and ci and (ei xnor ii);
      p22ancneeqi := p22 and not ai and not ci and (ei xnor ii);
      p13en       := p13 and not ei;
      anbnenin    := not ai and not bi and not ei and not ii;
      abei        := ai and bi and ei and ii;
      cdei        := ci and di and ei and ii;
      cndnenin    := not ci and not di and not ei and not ii;

      -- non-zero disparity cases:
      p22enin   := p22 and not ei and not ii;
      p22ei     := p22 and ei and ii;
      -- p13in := p12 and not ii ;
      -- p31i := p31 and ii ;
      p31dnenin := p31 and not di and not ei and not ii;
      -- p13dei := p13 and di and ei and ii ;
      p31e      := p31 and ei;

      compa := p22bncneeqi or p31i or p13dei or p22ancneeqi or
               p13en or abei or cndnenin;
      compb := p22bceeqi or p31i or p13dei or p22aceeqi or
               p13en or abei or cndnenin;
      compc := p22bceeqi or p31i or p13dei or p22ancneeqi or
               p13en or anbnenin or cndnenin;
      compd := p22bncneeqi or p31i or p13dei or p22aceeqi or
               p13en or abei or cndnenin;
      compe := p22bncneeqi or p13in or p13dei or p22ancneeqi or
               p13en or anbnenin or cndnenin;

      ao := ai xor compa;
      bo := bi xor compb;
      co := ci xor compc;
      do := di xor compd;
      eo := ei xor compe;

      feqg   := (fi and gi) or (not fi and not gi);
      heqj   := (hi and ji) or (not hi and not ji);
      fghj22 := (fi and gi and not hi and not ji) or
                (not fi and not gi and hi and ji) or
                (not feqg and not heqj);
      fghjp13 := (not feqg and not hi and not ji) or
                 (not heqj and not fi and not gi);
      fghjp31 := ((not feqg) and hi and ji) or
                 (not heqj and fi and gi);

      dispout := (fghjp31 or (disp6b and fghj22) or (hi and ji)) and (hi or ji);

      ko := ((ci and di and ei and ii) or (not ci and not di and not ei and not ii) or
             (p13 and not ei and ii and gi and hi and ji) or
             (p31 and ei and not ii and not gi and not hi and not ji)) ;

      alt7 := (fi and not gi and not hi and  -- 1000 cases, where disp6b is 1
               ((dispin and ci and di and not ei and not ii) or ko or
                (dispin and not ci and di and not ei and not ii))) or
              (not fi and gi and hi and      -- 0111 cases, where disp6b is 0
               ((not dispin and not ci and not di and ei and ii) or ko or
                (not dispin and ci and not di and ei and ii))) ;

      k28  := (ci and di and ei and ii) or not (ci or di or ei or ii);
      -- k28 with positive disp into fghi - .1, .2, .5, and .6 special cases
      k28p := not (ci or di or ei or ii);
      fo   := (ji and not fi and (hi or not gi or k28p)) or
              (fi and not ji and (not hi or gi or not k28p)) or
              (k28p and gi and hi) or
              (not k28p and not gi and not hi);
      go := (ji and not fi and (hi or not gi or not k28p)) or
            (fi and not ji and (not hi or gi or k28p)) or
            (not k28p and gi and hi) or
            (k28p and not gi and not hi);
      ho := ((ji xor hi) and not ((not fi and gi and not hi and ji and not k28p) or (not fi and gi and hi and not ji and k28p) or
                                  (fi and not gi and not hi and ji and not k28p) or (fi and not gi and hi and not ji and k28p))) or
            (not fi and gi and hi and ji) or (fi and not gi and not hi and not ji);

      disp6p := (p31 and (ei or ii)) or (p22 and ei and ii);
      disp6n := (p13 and not (ei and ii)) or (p22 and not ei and not ii);
      disp4p := fghjp31;
      disp4n := fghjp13;

      codeErr := p40 or p04 or (fi and gi and hi and ji) or (not fi and not gi and not hi and not ji) or
                 (p13 and not ei and not ii) or (p31 and ei and ii) or
                 (ei and ii and fi and gi and hi) or (not ei and not ii and not fi and not gi and not hi) or
                 (ei and not ii and gi and hi and ji) or (not ei and ii and not gi and not hi and not ji) or
                 (not p31 and ei and not ii and not gi and not hi and not ji) or
                 (not p13 and not ei and ii and gi and hi and ji) or
                 (((ei and ii and not gi and not hi and not ji) or
                   (not ei and not ii and gi and hi and ji)) and
                  not ((ci and di and ei) or (not ci and not di and not ei))) or
                 (disp6p and disp4p) or (disp6n and disp4n) or
                 (ai and bi and ci and not ei and not ii and ((not fi and not gi) or fghjp13)) or
                 (not ai and not bi and not ci and ei and ii and ((fi and gi) or fghjp31)) or
                 (fi and gi and not hi and not ji and disp6p) or
                 (not fi and not gi and hi and ji and disp6n) or
                 (ci and di and ei and ii and not fi and not gi and not hi) or
                 (not ci and not di and not ei and not ii and fi and gi and hi);

      dataOut  := ho & go & fo & eo & do & co & bo & ao;
      dataKOut := ko;

      --my disp err fires for any legal codes that violate disparity, may fire for illegal codes
      dispErr := ((dispin and disp6p) or (disp6n and not dispin) or
                  (dispin and not disp6n and fi and gi) or
                  (dispin and ai and bi and ci) or
                  (dispin and not disp6n and disp4p) or
                  (not dispin and not disp6p and not fi and not gi) or
                  (not dispin and not ai and not bi and not ci) or
                  (not dispin and not disp6p and disp4n) or
                  (disp6p and disp4p) or (disp6n and disp4n)) ;

   end procedure decode8b10b;

end package body Code8b10bPkg;
