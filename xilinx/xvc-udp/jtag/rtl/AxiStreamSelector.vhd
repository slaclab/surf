-------------------------------------------------------------------------------
-- Title      : JTAG Support
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Select between two input streams under control of a binary signal
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


library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;

entity AxiStreamSelector is
   generic (
      TPD_G : time := 1 ns
   );
   port (
      clk : in  sl;
      rst : in  sl;
      sel : in  sl;
      mIb : in  AxiStreamMasterArray(1 downto 0);
      sIb : out AxiStreamSlaveArray (1 downto 0);

      mOb : out AxiStreamMasterType;
      sOb : in  AxiStreamSlaveType
   );
end entity AxiStreamSelector;

architecture AxiStreamSelectorImpl of AxiStreamSelector is

   type RegType is record
      streamBuf : AxiStreamMasterType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      streamBuf => AXI_STREAM_MASTER_INIT_C
   );

   signal r      : RegType := REG_INIT_C;
   signal rin    : RegType;
   signal rdyLoc : sl;

begin

   rdyLoc          <= not r.streamBuf.tValid or sOb.tReady;

   sIb(1).tReady   <= rdyLoc when sel = '1' else '0';
   sIb(0).tReady   <= rdyLoc when sel = '0' else '0';

   mOb             <= r.streamBuf;

   P_COMB : process(r, rdyLoc, sel, mIb, sOb)
      variable v : RegType;
   begin
      v   := r;

      if ( rdyLoc = '1' ) then
         if ( sel = '1' ) then
            v.streamBuf := mIb(1);
         else
            v.streamBuf := mIb(0);
         end if;
      end if;

      rin <= v;
   end process P_COMB;

   P_SEQ : process( clk )
   begin
      if ( rising_edge( clk ) ) then
         if ( rst = '1' ) then
            r <= REG_INIT_C after TPD_G;
         else
            r <= rin after TPD_G;
         end if;
      end if;
   end process P_SEQ;

end architecture AxiStreamSelectorImpl;
