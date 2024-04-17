-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Simulation Testbed for testing the AxiStreamFlush module
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
use surf.AxiLitePkg.all;
use surf.AxiStreamPkg.all;
use surf.SsiPkg.all;

entity AxiStreamFlushTb is end AxiStreamFlushTb;

architecture testbed of AxiStreamFlushTb is

   -- Constants
   constant FAST_CLK_PERIOD_C  : time             := 5 ns;
   constant TPD_C              : time             := FAST_CLK_PERIOD_C/4;

   -- PRBS Configuration
   constant PRBS_SEED_SIZE_C : natural      := 32;
   constant PRBS_TAPS_C      : NaturalArray := (0 => 31, 1 => 6, 2 => 2, 3 => 1);

   -- AXI Stream Configurations
   constant AXI_STREAM_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(4);

   -- Signals
   signal fastClk : sl := '0';
   signal fastRst : sl := '1';

   signal obMaster : AxiStreamMasterType;
   signal obSlave  : AxiStreamSlaveType;

   signal ibMaster : AxiStreamMasterType;
   signal ibCtrl   : AxiStreamCtrlType;

   signal flushEn  : sl;
   signal count    : integer range 0 to 254;

begin

   ---------------------------------------
   -- Generate fast clocks and fast resets
   ---------------------------------------
   ClkRst_Fast : entity surf.ClkRst
      generic map (
         CLK_PERIOD_G      => CLK_PERIOD_C,
         RST_START_DELAY_G => 0 ns,     -- Wait this long into simulation before asserting reset
         RST_HOLD_TIME_G   => 1000 ns)  -- Hold reset for this long)
      port map (
         clkP => fastClk,
         clkN => open,
         rst  => fastRst,
         rstL => open);

   --------------
   -- Data Source
   --------------
   SsiPrbsTx_Inst : entity surf.SsiPrbsTx
      generic map (
         -- General Configurations
         TPD_G                      => TPD_C,
         GEN_SYNC_FIFO_G            => true,
         PRBS_SEED_SIZE_G           => PRBS_SEED_SIZE_C,
         PRBS_TAPS_G                => PRBS_TAPS_C,
         MASTER_AXI_STREAM_CONFIG_G => AXI_STREAM_CONFIG_C)
      port map (
         mAxisClk     => fastClk,
         mAxisRst     => fastRst,
         mAxisMaster  => obMaster,
         mAxisSlave   => obSlave,
         locClk       => fastClk,
         locRst       => fastRst,
         trig         => '1',
         packetLength => toSlv(100,32),
         forceEofe    => '0',
         busy         => open,
         tDest        => (others => '0'),
         tId          => (others => '0'));

   U_Flush: entity surf.AxiStreamFlush
      generic map (
         TPD_G         => TPD_C,
         AXIS_CONFIG_G => AXI_STREAM_CONFIG_C,
         SSI_EN_G      => true)
      port map (
         axisClk     => fastClk,
         axisRst     => fastRst,
         flushEn     => flushEn,
         sAxisMaster => obMaster,
         sAxisSlave  => obSlave,
         mAxisMaster => ibMaster,
         mAxisCtrl   => ibCtrl);

   process(fastClk)
   begin
      if rising_edge(fastClk) then
         if fastRst = '1' then
            flushEn <= '0'                    after TPD_C;
            ibCtrl  <= AXI_STREAM_CTRL_INIT_C after TPD_C;
            count   <= 0                      after TPD_C;
         else

            if count = 254 then
               count <= 0 after TPD_C;
            else
               count <= count + 1 after TPD_C;
            end if;

            if count = 254 then
               flushEn <= '1' after TPD_C;
            else
               flushEn <= '0' after TPD_C;
            end if;

            if (count rem 10) = 0 then
               ibCtrl.pause <= '1' after TPD_C;
            else
               ibCtrl.pause <= '0' after TPD_C;
            end if;

         end if;
      end if;
   end process;

end testbed;
