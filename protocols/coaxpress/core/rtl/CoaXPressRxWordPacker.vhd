-------------------------------------------------------------------------------
-- Title      : CoaXPress Protocol: http://jiia.org/wp-content/themes/jiia/pdf/standard_dl/coaxpress/CXP-001-2021.pdf
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: CoaXPress RX Word packer
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
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;

entity CoaXPressRxWordPacker is
   generic (
      TPD_G       : time     := 1 ns;
      NUM_LANES_G : positive := 1);
   port (
      -- System clock and reset
      rxClk       : in  sl;
      rxRst       : in  sl;
      -- Inbound frame
      sAxisMaster : in  AxiStreamMasterType;
      -- Outbound frame
      mAxisMaster : out AxiStreamMasterType);
end CoaXPressRxWordPacker;

architecture rtl of CoaXPressRxWordPacker is

   type RegType is record
      wordCount : natural range 0 to NUM_LANES_G-1;
      firstWord : natural range 0 to NUM_LANES_G-1;
      lastWord  : natural range 0 to NUM_LANES_G-1;
      inMaster  : AxiStreamMasterType;
      curMaster : AxiStreamMasterType;
      nxtMaster : AxiStreamMasterType;
      outMaster : AxiStreamMasterType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      wordCount => 0,
      firstWord => 0,
      lastWord  => 0,
      inMaster  => AXI_STREAM_MASTER_INIT_C,
      curMaster => AXI_STREAM_MASTER_INIT_C,
      nxtMaster => AXI_STREAM_MASTER_INIT_C,
      outMaster => AXI_STREAM_MASTER_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   comb : process (r, rxRst, sAxisMaster) is
      variable v     : RegType;
      variable valid : sl;
      variable last  : sl;
      variable data  : slv(31 downto 0);
   begin
      v := r;

      -- Register input
      v.inMaster := sAxisMaster;

      -- Find location of last word
      for i in 0 to NUM_LANES_G-1 loop
         if (sAxisMaster.tKeep(4*i) = '1') then
            v.lastWord := i;
         end if;
      end loop;

      -- Find location of first word
      for i in NUM_LANES_G-1 downto 0 loop
         if (sAxisMaster.tKeep(4*i) = '1') then
            v.firstWord := i;
         end if;
      end loop;

      -- Pending output from current
      if r.curMaster.tValid = '1' then
         v.outMaster       := r.curMaster;
         v.curMaster       := r.nxtMaster;
         v.nxtMaster       := AXI_STREAM_MASTER_INIT_C;
         v.nxtMaster.tKeep := (others => '0');
      else
         v.outMaster := AXI_STREAM_MASTER_INIT_C;
      end if;

      -- Data is valid
      if r.inMaster.tValid = '1' then

         -- Process each input word
         for i in 0 to NUM_LANES_G-1 loop
            if (i >= r.firstWord) and (i <= r.lastWord) then

               -- Extract values for each iteration
               last  := r.inMaster.tLast and toSl(i = r.lastWord);
               valid := toSl(v.wordCount = NUM_LANES_G-1) or last;
               data  := r.inMaster.tData(i*32+31 downto i*32);

               -- Still filling current data
               if v.curMaster.tValid = '0' then

                  v.curMaster.tData(v.wordCount*32+31 downto v.wordCount*32) := data;
                  v.curMaster.tKeep(v.wordCount*4+3 downto v.wordCount*4)    := x"F";

                  v.curMaster.tValid := valid;
                  v.curMaster.tLast  := last;

               -- Filling next data
               elsif v.nxtMaster.tValid = '0' then

                  v.nxtMaster.tData(v.wordCount*32+31 downto v.wordCount*32) := data;
                  v.nxtMaster.tKeep(v.wordCount*4+3 downto v.wordCount*4)    := x"F";

                  v.nxtMaster.tValid := valid;
                  v.nxtMaster.tLast  := last;

               end if;

               if v.wordCount = NUM_LANES_G-1 or last = '1' then
                  v.wordCount := 0;
               else
                  v.wordCount := v.wordCount + 1;
               end if;
            end if;
         end loop;
      end if;

      -- Reset
      if (rxRst = '1') then
         v                 := REG_INIT_C;
         v.curMaster.tKeep := (others => '0');
         v.nxtMaster.tKeep := (others => '0');
      end if;

      rin <= v;

      mAxisMaster <= r.outMaster;

   end process;

   seq : process (rxClk) is
   begin
      if (rising_edge(rxClk)) then
         r <= rin;
      end if;
   end process;

end rtl;

