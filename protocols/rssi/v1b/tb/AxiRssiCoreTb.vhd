-------------------------------------------------------------------------------
-- Title      : RSSI Protocol: https://confluence.slac.stanford.edu/x/1IyfD
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Simulation Testbed for testing the AxiRssiCore
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
use surf.AxiPkg.all;
use surf.AxiStreamPkg.all;
use surf.AxiLitePkg.all;
use surf.SsiPkg.all;
use surf.AxiRssiPkg.all;
use surf.RssiPkg.all;

entity AxiRssiCoreTb is
end AxiRssiCoreTb;

architecture testbed of AxiRssiCoreTb is

   constant CLK_PERIOD_C : time := 10 ns;  -- 1 us makes it easy to count clock cycles in sim GUI
   constant TPD_G        : time := CLK_PERIOD_C/4;

   -- RSSI Timeouts
   constant CLK_FREQUENCY_C   : real     := 100.0E+6;  -- In units of Hz
   constant TIMEOUT_UNIT_C    : real     := 1.0E-6;    -- In units of seconds
   constant ACK_TOUT_C        : positive := 25;  -- unit depends on TIMEOUT_UNIT_G
   constant RETRANS_TOUT_C    : positive := 50;  -- unit depends on TIMEOUT_UNIT_G  (Recommended >= MAX_NUM_OUTS_SEG_G*Data segment transmission time)
   constant NULL_TOUT_C       : positive := 200;  -- unit depends on TIMEOUT_UNIT_G  (Recommended >= 4*RETRANS_TOUT_G)
   -- Counters
   constant MAX_RETRANS_CNT_C : positive := 3;
   constant MAX_CUM_ACK_CNT_C : positive := 2;

   constant JUMBO_C : boolean := true;
   constant AXI_CONFIG_C : AxiConfigType := (
      ADDR_WIDTH_C => ite(JUMBO_C, 16, 13),  -- (true=64kB buffer),(false=8kB buffer)
      DATA_BYTES_C => 8,                -- 8 bytes = 64-bits
      ID_BITS_C    => 2,
      LEN_BITS_C   => ite(JUMBO_C, 8, 7));  -- (true=2kB bursting),(false=1kB bursting)

   type RegType is record
      packetLength : slv(31 downto 0);
      trig         : sl;
      txBusy       : sl;
      errorDet     : sl;
   end record RegType;

   constant REG_INIT_C : RegType := (
      packetLength => toSlv(0, 32),
      trig         => '0',
      txBusy       => '0',
      errorDet     => '0');

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal clk : sl := '0';
   signal rst : sl := '0';

   signal txMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal txSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;

   signal ibSrvMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal ibSrvSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;
   signal obSrvMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal obSrvSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;

   signal ibCltMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal ibCltSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;
   signal obCltMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal obCltSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;

   signal axiWriteMasters : AxiWriteMasterArray(3 downto 0);
   signal axiWriteSlaves  : AxiWriteSlaveArray(3 downto 0);
   signal axiReadMasters  : AxiReadMasterArray(3 downto 0);
   signal axiReadSlaves   : AxiReadSlaveArray(3 downto 0);

   signal rxMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal rxSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;

   signal linkUp         : sl;
   signal updatedResults : sl;
   signal errorDet       : sl;
   signal rxBusy         : sl;
   signal txBusy         : sl;

begin

   ---------------------------
   -- Generate clock and reset
   ---------------------------
   U_ClkRst : entity surf.ClkRst
      generic map (
         CLK_PERIOD_G      => CLK_PERIOD_C,
         RST_START_DELAY_G => 0 ns,
         RST_HOLD_TIME_G   => 1 us)
      port map (
         clkP => clk,
         rst  => rst);

   ----------
   -- PRBS TX
   ----------
   U_SsiPrbsTx : entity surf.SsiPrbsTx
      generic map (
         TPD_G                      => TPD_G,
         AXI_EN_G                   => '0',
         MASTER_AXI_STREAM_CONFIG_G => RSSI_AXIS_CONFIG_C)
      port map (
         -- Master Port (mAxisClk)
         mAxisClk     => clk,
         mAxisRst     => rst,
         mAxisMaster  => txMaster,
         mAxisSlave   => txSlave,
         -- Trigger Signal (locClk domain)
         locClk       => clk,
         locRst       => rst,
         packetLength => r.packetLength,
         -- packetLength => toSlv(800,32),
         trig         => r.trig,
         busy         => txBusy);

   --------------
   -- RSSI Server
   --------------
   U_RssiServer : entity surf.AxiRssiCoreWrapper
      generic map (
         TPD_G             => TPD_G,
         JUMBO_G           => JUMBO_C,
         SERVER_G          => true,     -- Server
         AXI_CONFIG_G      => AXI_CONFIG_C,
         -- AXIS Configurations
         APP_AXIS_CONFIG_G => (0 => RSSI_AXIS_CONFIG_C),
         TSP_AXIS_CONFIG_G => RSSI_AXIS_CONFIG_C,
         -- RSSI Timeouts
         CLK_FREQUENCY_G   => CLK_FREQUENCY_C,
         TIMEOUT_UNIT_G    => TIMEOUT_UNIT_C,
         ACK_TOUT_G        => ACK_TOUT_C,
         RETRANS_TOUT_G    => RETRANS_TOUT_C,
         NULL_TOUT_G       => NULL_TOUT_C,
         -- Counters
         MAX_RETRANS_CNT_G => MAX_RETRANS_CNT_C,
         MAX_CUM_ACK_CNT_G => MAX_CUM_ACK_CNT_C)
      port map (
         clk                => clk,
         rst                => rst,
         openRq             => '1',
         -- AXI TX Segment Buffer Interface
         txAxiOffset        => (others => '0'),
         txAxiWriteMaster   => axiWriteMasters(0),
         txAxiWriteSlave    => axiWriteSlaves(0),
         txAxiReadMaster    => axiReadMasters(0),
         txAxiReadSlave     => axiReadSlaves(0),
         -- AXI RX Segment Buffer Interface
         rxAxiOffset        => (others => '0'),
         rxAxiWriteMaster   => axiWriteMasters(1),
         rxAxiWriteSlave    => axiWriteSlaves(1),
         rxAxiReadMaster    => axiReadMasters(1),
         rxAxiReadSlave     => axiReadSlaves(1),
         -- Application Layer Interface
         sAppAxisMasters(0) => txMaster,
         sAppAxisSlaves(0)  => txSlave,
         mAppAxisSlaves(0)  => AXI_STREAM_SLAVE_FORCE_C,
         -- Transport Layer Interface
         sTspAxisMaster     => ibSrvMaster,
         sTspAxisSlave      => ibSrvSlave,
         mTspAxisMaster     => obSrvMaster,
         mTspAxisSlave      => obSrvSlave);

   --------------
   -- RSSI Client
   --------------
   U_RssiClient : entity surf.AxiRssiCoreWrapper
      generic map (
         TPD_G             => TPD_G,
         JUMBO_G           => JUMBO_C,
         SERVER_G          => false,    -- Client
         AXI_CONFIG_G      => AXI_CONFIG_C,
         -- AXIS Configurations
         APP_AXIS_CONFIG_G => (0 => RSSI_AXIS_CONFIG_C),
         TSP_AXIS_CONFIG_G => RSSI_AXIS_CONFIG_C,
         -- RSSI Timeouts
         CLK_FREQUENCY_G   => CLK_FREQUENCY_C,
         TIMEOUT_UNIT_G    => TIMEOUT_UNIT_C,
         ACK_TOUT_G        => ACK_TOUT_C,
         RETRANS_TOUT_G    => RETRANS_TOUT_C,
         NULL_TOUT_G       => NULL_TOUT_C,
         -- Counters
         MAX_RETRANS_CNT_G => MAX_RETRANS_CNT_C,
         MAX_CUM_ACK_CNT_G => MAX_CUM_ACK_CNT_C)
      port map (
         clk                => clk,
         rst                => rst,
         openRq             => '1',
         linkUp             => linkUp,
         -- AXI TX Segment Buffer Interface
         txAxiOffset        => (others => '0'),
         txAxiWriteMaster   => axiWriteMasters(2),
         txAxiWriteSlave    => axiWriteSlaves(2),
         txAxiReadMaster    => axiReadMasters(2),
         txAxiReadSlave     => axiReadSlaves(2),
         -- AXI RX Segment Buffer Interface
         rxAxiOffset        => (others => '0'),
         rxAxiWriteMaster   => axiWriteMasters(3),
         rxAxiWriteSlave    => axiWriteSlaves(3),
         rxAxiReadMaster    => axiReadMasters(3),
         rxAxiReadSlave     => axiReadSlaves(3),
         -- Application Layer Interface
         sAppAxisMasters(0) => AXI_STREAM_MASTER_INIT_C,
         mAppAxisMasters(0) => rxMaster,
         mAppAxisSlaves(0)  => rxSlave,
         -- Transport Layer Interface
         sTspAxisMaster     => ibCltMaster,
         sTspAxisSlave      => ibCltSlave,
         mTspAxisMaster     => obCltMaster,
         mTspAxisSlave      => obCltSlave);

   -------------
   -- AXI Memory
   -------------
   GEN_VEC : for i in 3 downto 0 generate
      U_MEM : entity surf.AxiRam
         generic map (
            TPD_G        => TPD_G,
            SYNTH_MODE_G => "xpm",
            AXI_CONFIG_G => AXI_CONFIG_C)
         port map (
            -- Clock and Reset
            axiClk          => clk,
            axiRst          => rst,
            -- Slave Write Interface
            sAxiWriteMaster => axiWriteMasters(i),
            sAxiWriteSlave  => axiWriteSlaves(i),
            -- Slave Read Interface
            sAxiReadMaster  => axiReadMasters(i),
            sAxiReadSlave   => axiReadSlaves(i));
   end generate GEN_VEC;

   ----------
   -- PRBS RX
   ----------
   U_SsiPrbsRx : entity surf.SsiPrbsRx
      generic map (
         TPD_G                     => TPD_G,
         SLAVE_AXI_STREAM_CONFIG_G => RSSI_AXIS_CONFIG_C)
      port map (
         -- Slave Port (sAxisClk)
         sAxisClk       => clk,
         sAxisRst       => rst,
         sAxisMaster    => rxMaster,
         sAxisSlave     => rxSlave,
         -- Error Detection Signals (sAxisClk domain)
         updatedResults => updatedResults,
         errorDet       => errorDet,
         busy           => rxBusy);

   comb : process (errorDet, ibCltSlave, ibSrvSlave, linkUp, obCltMaster,
                   obSrvMaster, r, rst, txBusy) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Keep delay copies
      v.errorDet := errorDet;
      v.txBusy   := txBusy;
      v.trig     := not(r.txBusy) and linkUp;

      -- Check for the packet completion
      if (txBusy = '1') and (r.txBusy = '0') then
         -- Sweeping the packet size size
         v.packetLength := r.packetLength + 1;
      end if;

      -- Reset
      if (rst = '1') then
         v := REG_INIT_C;
      end if;

      ---------------------------------
      -- Simulation Error Self-checking
      ---------------------------------
      if r.errorDet = '1' then
         assert false
            report "Simulation Failed!" severity failure;
      end if;

      if (r.packetLength < 8192) then
         -- if (r.packetLength < 128) then
         ibSrvMaster <= obCltMaster;
         obCltSlave  <= ibSrvSlave;
         ibCltMaster <= obSrvMaster;
         obSrvSlave  <= ibCltSlave;
      else                              -- Emulation a cable being disconnected
         ibSrvMaster <= AXI_STREAM_MASTER_INIT_C;
         obCltSlave  <= AXI_STREAM_SLAVE_FORCE_C;
         ibCltMaster <= AXI_STREAM_MASTER_INIT_C;
         obSrvSlave  <= AXI_STREAM_SLAVE_FORCE_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

   end process comb;

   seq : process (clk) is
   begin
      if (rising_edge(clk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end testbed;
