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
use surf.SsiPkg.all;
use surf.CoaXPressPkg.all;

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
      sAxisSlave  : out AxiStreamSlaveType;
      -- Outbound frame
      mAxisMaster : out AxiStreamMasterType;
      mAxisSlave  : in  AxiStreamSlaveType);
end CoaXPressRxWordPacker;

architecture rtl of CoaXPressRxWordPacker is

   constant WIDE_AXIS_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(
      dataBytes => (4*NUM_LANES_G),
      tKeepMode => TKEEP_NORMAL_C,
      tUserMode => TUSER_NORMAL_C,
      tDestBits => 0,
      tUserBits => CXP_RX_STREAM_TUSER_BITS_C);

   type RegType is record
      wordCount : natural range 0 to NUM_LANES_G-1;
      firstWord : natural range 0 to NUM_LANES_G-1;
      lastWord  : natural range 0 to NUM_LANES_G-1;
      beatValid : sl;
      beatLast  : sl;
      beatData  : slv(31 downto 0);
      sAxisSlave : AxiStreamSlaveType;
      curMaster : AxiStreamMasterType;
      nxtMaster : AxiStreamMasterType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      wordCount => 0,
      firstWord => 0,
      lastWord  => 0,
      beatValid => '0',
      beatLast  => '0',
      beatData  => (others => '0'),
      sAxisSlave => AXI_STREAM_SLAVE_INIT_C,
      curMaster => AXI_STREAM_MASTER_INIT_C,
      nxtMaster => AXI_STREAM_MASTER_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   sAxisSlave <= rin.sAxisSlave;

   comb : process (mAxisSlave, r, rxRst, sAxisMaster) is
      variable v : RegType;
   begin
      v := r;

      v.beatValid := '0';
      v.beatLast  := '0';
      v.beatData  := (others => '0');

      -- Pop the completed output beat only when the downstream stage accepts it.
      if (mAxisSlave.tReady = '1') and (r.curMaster.tValid = '1') then
         v.curMaster       := r.nxtMaster;
         v.nxtMaster       := AXI_STREAM_MASTER_INIT_C;
         v.nxtMaster.tKeep := (others => '0');
      end if;

      -- The input beat can expand into at most the current partial word plus one
      -- next word, so the next slot being empty is sufficient capacity.
      v.sAxisSlave.tReady := not v.nxtMaster.tValid;

      -- Find location of last word
      v.lastWord := 0;
      for i in 0 to NUM_LANES_G-1 loop
         if (sAxisMaster.tKeep(4*i) = '1') then
            v.lastWord := i;
         end if;
      end loop;

      -- Find location of first word
      v.firstWord := 0;
      for i in NUM_LANES_G-1 downto 0 loop
         if (sAxisMaster.tKeep(4*i) = '1') then
            v.firstWord := i;
         end if;
      end loop;

      -- Data is valid and there is room to accept the whole input beat.
      if (sAxisMaster.tValid = '1') and (v.sAxisSlave.tReady = '1') then

         -- Process each input word
         for i in 0 to NUM_LANES_G-1 loop
            if (i >= v.firstWord) and (i <= v.lastWord) and (sAxisMaster.tKeep(4*i) = '1') then

               -- Extract values for each iteration
               v.beatLast  := sAxisMaster.tLast and toSl(i = v.lastWord);
               v.beatValid := toSl(v.wordCount = NUM_LANES_G-1) or v.beatLast;
               v.beatData  := sAxisMaster.tData(i*32+31 downto i*32);

               -- Still filling current data
               if v.curMaster.tValid = '0' then

                  v.curMaster.tData(v.wordCount*32+31 downto v.wordCount*32) := v.beatData;
                  v.curMaster.tKeep(v.wordCount*4+3 downto v.wordCount*4)    := x"F";

                  v.curMaster.tValid := v.beatValid;
                  v.curMaster.tLast  := v.beatLast;
                  if (v.beatLast = '1') then
                     ssiSetUserEofe(WIDE_AXIS_CONFIG_C, v.curMaster, ssiGetUserEofe(WIDE_AXIS_CONFIG_C, sAxisMaster));
                  end if;

               -- Filling next data
               elsif v.nxtMaster.tValid = '0' then

                  v.nxtMaster.tData(v.wordCount*32+31 downto v.wordCount*32) := v.beatData;
                  v.nxtMaster.tKeep(v.wordCount*4+3 downto v.wordCount*4)    := x"F";

                  v.nxtMaster.tValid := v.beatValid;
                  v.nxtMaster.tLast  := v.beatLast;
                  if (v.beatLast = '1') then
                     ssiSetUserEofe(WIDE_AXIS_CONFIG_C, v.nxtMaster, ssiGetUserEofe(WIDE_AXIS_CONFIG_C, sAxisMaster));
                  end if;

               end if;

               if v.wordCount = NUM_LANES_G-1 or v.beatLast = '1' then
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

      mAxisMaster <= r.curMaster;

   end process;

   seq : process (rxClk) is
   begin
      if (rising_edge(rxClk)) then
         r <= rin;
      end if;
   end process;

end rtl;
