-- Title      : JTAG Support
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: JTAG serializer/deserializer with parallel word interface
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

-- Serialize a TMS/TDI word pair into JTAG signals and deserialize
-- TDO into a paralle output word.

entity JtagSerDesCore is
   generic (
      TPD_G        : time     := 1 ns;
      WIDTH_G      : positive := 32;
      CLK_DIV2_G   : positive := 8
   );
   port (
      clk          : in sl;
      rst          : in sl;

      numBits      : in natural range 0 to WIDTH_G - 1;

      dataInTms    : in  slv(WIDTH_G - 1 downto 0);
      dataInTdi    : in  slv(WIDTH_G - 1 downto 0);
      dataInValid  : in  sl;
      dataInReady  : out sl;

      dataOut      : out slv(WIDTH_G - 1 downto 0);
      dataOutValid : out sl;
      dataOutReady : in  sl;

      tck          : out sl;
      tdi          : out sl;
      tms          : out sl;
      tdo          : in  sl
   );
end entity JtagSerDesCore;

architecture JtagSerDesCoreImpl of JtagSerDesCore is

   type StateType is (IDLE_S, SHIFT_S, WAI_S);

   type RegType is record
      cnt     : integer range -1 to WIDTH_G - 1;
      div     : natural;
      tms     : slv(WIDTH_G - 1 downto 0 );
      tdi     : slv(WIDTH_G - 1 downto 0 );
      tdo     : slv(WIDTH_G     downto 0 );
      tck     : sl;
      lastBit : boolean;
      oValid  : sl;
      iReady  : sl;
      state   : StateType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      cnt     => -1,
      div     => 0,
      tms     => (others => '0'),
      tdi     => (others => '0'),
      tdo     => (others => '0'),
      tck     => '0',
      lastBit => false,
      oValid  => '0',
      iReady  => '1',
      state   => IDLE_S
   );

   signal r       : RegType := REG_INIT_C;
   signal rin     : RegType;

begin

   tck          <= r.tck;
   tdi          <= r.tdi(0);
   tms          <= r.tms(0);

   dataOutValid <= r.oValid;
   dataInReady  <= r.iReady;
   dataOut      <= r.tdo(WIDTH_G - 1 downto 0);

   P_COMB : process(r, numBits,  dataInTms, dataInTdi, dataInValid, dataOutReady, tdo)
      variable v : RegType;
   begin
      v := r;

      case (r.state) is
         when IDLE_S =>
            v.oValid := '0';
            if ( dataInValid /= '0' and r.iReady /= '0' ) then
               v.tms    := dataInTms;
               v.tdi    := dataInTdi;
               v.iReady := '0';
               v.cnt    := numBits;
               v.div    := CLK_DIV2_G - 1;
               v.state  := SHIFT_S;
            end if;

         when SHIFT_S =>
            v.iReady := '0';
            v.oValid := '0';
            if ( r.div = 0 ) then
               if ( r.tck = '0' ) then
                  -- about to raise TCK
                  v.tdo := ( tdo & r.tdo( r.tdo'left downto 1 ) );
                  if ( r.lastBit ) then
                     -- latch last TDO bit
                     v.lastBit := false;
                     v.oValid  := '1';
                     if ( r.cnt >= 0 ) then
                        -- more words in the pipeline; if receiver is ready
                        -- then we continue shifting - otherwise we must wait
                        if ( dataOutReady /= '0' ) then
                           -- next clock; continue shifting
                           v.tck   := '1';
                           v.div   := CLK_DIV2_G - 1;
                        else
                           v.state := WAI_S;
                        end if;
                     else
                        -- we are done
                        if ( dataOutReady /= '0' ) then
                           v.iReady := '1';
                           v.state  := IDLE_S;
                        else
                           v.state  := WAI_S;
                        end if;
                     end if;
                  else
                     v.tck := '1';
                     v.div := CLK_DIV2_G - 1;
                  end if;
               else
                  -- falling edge of TCK
                  v.tms := ( '0' & r.tms(r.tms'left downto 1 ) );
                  v.tdi := ( '0' & r.tdi(r.tdi'left downto 1 ) );
                  v.cnt := r.cnt - 1;
                  if ( r.cnt = 0 ) then
                     if ( dataInValid /= '0' ) then
                        v.tms    := dataInTms;
                        v.tdi    := dataInTdi;
                        v.cnt    := numBits;
                        v.iReady := '1';
                     end if;
                     v.lastBit := true;
                  end if;
                  v.tck := '0';
                  v.div := CLK_DIV2_G - 1;
               end if;
            else
               v.div := r.div - 1;
            end if;

         when WAI_S =>
            if ( dataOutReady /= '0' ) then
               v.oValid := '0';
               if ( r.cnt >= 0 ) then
                  v.tck    := '1';
                  v.div    := CLK_DIV2_G - 1;
                  v.state  := SHIFT_S;
               else
                  v.iReady := '1';
                  v.state  := IDLE_S;
               end if;
            end if;

      end case;

      rin <= v;

   end process P_COMB;

   P_SEQ : process(clk )
   begin
      if ( rising_edge( clk ) ) then
         if ( rst /= '0' ) then
            r <= REG_INIT_C after TPD_G;
         else
            r <= rin after TPD_G;
         end if;
      end if;
   end process P_SEQ;

end architecture JtagSerDesCoreImpl;
