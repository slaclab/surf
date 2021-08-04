-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Simulation Testbed for testing the SaltCoreTb module
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
use surf.SaltPkg.all;

entity SaltCoreTb is end SaltCoreTb;

architecture testbed of SaltCoreTb is

   constant TPD_G : time := 0.6 ns;

   constant TX_PACKET_LENGTH_C : slv(31 downto 0) := toSlv(256, 32);
   constant NUMBER_PACKET_C    : slv(31 downto 0) := x"000000FF";

   constant PRBS_SEED_SIZE_C : positive := 8*SSI_SALT_CONFIG_C.TDATA_BYTES_C;

   signal txMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal txSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;

   signal rxMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal rxSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;

   signal linkUp   : sl := '0';
   signal passed   : sl := '0';
   signal failed   : sl := '0';
   signal updated  : sl := '0';
   signal errorDet : sl := '0';
   signal cnt      : slv(31 downto 0);

   signal mps125MHzClk : sl := '0';
   signal mps125MHzRst : sl := '1';

   signal mps156MHzClk : sl := '0';
   signal mps156MHzRst : sl := '1';

   signal mps625MHzClkP : sl := '0';
   signal mps625MHzClkN : sl := '1';
   signal mps625MHzRst  : sl := '1';

   signal loopbackP : sl := '0';
   signal loopbackN : sl := '1';

begin

   U_125MHz : entity surf.ClkRst
      generic map (
         CLK_PERIOD_G      => 8.0 ns,
         RST_START_DELAY_G => 0 ns,
         RST_HOLD_TIME_G   => 1000 ns)
      port map (
         clkP => mps125MHzClk,
         rst  => mps125MHzRst);

   U_156MHz : entity surf.ClkRst
      generic map (
         CLK_PERIOD_G      => 6.4 ns,
         RST_START_DELAY_G => 0 ns,
         RST_HOLD_TIME_G   => 1000 ns)
      port map (
         clkP => mps156MHzClk,
         rst  => mps156MHzRst);

   U_625MHz : entity surf.ClkRst
      generic map (
         CLK_PERIOD_G      => 1.6 ns,
         RST_START_DELAY_G => 0 ns,
         RST_HOLD_TIME_G   => 1000 ns)
      port map (
         clkP => mps625MHzClkP,
         clkN => mps625MHzClkN,
         rst  => mps625MHzRst);

   U_SsiPrbsTx : entity surf.SsiPrbsTx
      generic map (
         TPD_G                      => TPD_G,
         PRBS_SEED_SIZE_G           => PRBS_SEED_SIZE_C,
         AXI_EN_G                   => '0',
         MASTER_AXI_STREAM_CONFIG_G => SSI_SALT_CONFIG_C)
      port map (
         -- Master Port (mAxisClk)
         mAxisClk     => mps125MHzClk,
         mAxisRst     => mps125MHzRst,
         mAxisMaster  => txMaster,
         mAxisSlave   => txSlave,
         -- Trigger Signal (locClk domain)
         locClk       => mps125MHzClk,
         locRst       => mps125MHzRst,
         trig         => linkUp,
         packetLength => TX_PACKET_LENGTH_C);

   U_DUT : entity surf.SaltCore
      generic map (
         TPD_G               => TPD_G,
         SIMULATION_G        => true,
         SLAVE_AXI_CONFIG_G  => SSI_SALT_CONFIG_C,
         MASTER_AXI_CONFIG_G => SSI_SALT_CONFIG_C)
      port map (
         -- TX Serial Stream
         txP         => loopbackP,
         txN         => loopbackN,
         -- RX Serial Stream
         rxP         => loopbackP,
         rxN         => loopbackN,
         -- Reference Signals
         clk125MHz   => mps125MHzClk,
         rst125MHz   => mps125MHzRst,
         clk156MHz   => mps156MHzClk,
         rst156MHz   => mps156MHzRst,
         clk625MHz   => mps625MHzClkP,
         -- Status Interface
         linkUp      => linkUp,
         -- Slave Port
         sAxisClk    => mps125MHzClk,
         sAxisRst    => mps125MHzRst,
         sAxisMaster => txMaster,
         sAxisSlave  => txSlave,
         -- Master Port
         mAxisClk    => mps125MHzClk,
         mAxisRst    => mps125MHzRst,
         mAxisMaster => rxMaster,
         mAxisSlave  => rxSlave);

   U_SsiPrbsRx : entity surf.SsiPrbsRx
      generic map (
         TPD_G                     => TPD_G,
         PRBS_SEED_SIZE_G          => PRBS_SEED_SIZE_C,
         SLAVE_READY_EN_G          => true,
         SLAVE_AXI_STREAM_CONFIG_G => SSI_SALT_CONFIG_C)
      port map (
         -- Streaming RX Data Interface (sAxisClk domain)
         sAxisClk       => mps125MHzClk,
         sAxisRst       => mps125MHzRst,
         sAxisMaster    => rxMaster,
         sAxisSlave     => rxSlave,
         -- Error Detection Signals (sAxisClk domain)
         updatedResults => updated,
         errorDet       => errorDet);

   process(mps125MHzClk)
   begin
      if rising_edge(mps125MHzClk) then
         if mps125MHzRst = '1' then
            cnt    <= (others => '0') after TPD_G;
            passed <= '0'             after TPD_G;
            failed <= '0'             after TPD_G;
         elsif updated = '1' then
            -- Check for packet error
            if errorDet = '1' then
               failed <= '1' after TPD_G;
            end if;
            -- Check the counter
            if cnt = NUMBER_PACKET_C then
               passed <= '1' after TPD_G;
            else
               -- Increment the counter
               cnt <= cnt + 1 after TPD_G;
            end if;
         end if;
      end if;
   end process;

   process(failed, passed)
   begin
      if failed = '1' then
         assert false
            report "Simulation Failed!" severity failure;
      end if;
      if passed = '1' then
         assert false
            report "Simulation Passed!" severity failure;
      end if;
   end process;

end testbed;
