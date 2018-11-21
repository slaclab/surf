-------------------------------------------------------------------------------
-- File       : AxiRssiCoreTb.vhd
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

use work.StdRtlPkg.all;
use work.AxiPkg.all;
use work.AxiStreamPkg.all;
use work.AxiLitePkg.all;
use work.SsiPkg.all;
use work.AxiRssiPkg.all;
use work.RssiPkg.all;

entity AxiRssiCoreTb is
end AxiRssiCoreTb;

architecture testbed of AxiRssiCoreTb is

   constant CLK_PERIOD_C : time := 10 ns;  -- 1 us makes it easy to count clock cycles in sim GUI
   constant TPD_G        : time := CLK_PERIOD_C/4;

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

   signal tspMasters : AxiStreamMasterArray(1 downto 0);
   signal tspSlaves  : AxiStreamSlaveArray(1 downto 0);

   signal axiWriteMasters : AxiWriteMasterArray(1 downto 0);
   signal axiWriteSlaves  : AxiWriteSlaveArray(1 downto 0);
   signal axiReadMasters  : AxiReadMasterArray(1 downto 0);
   signal axiReadSlaves   : AxiReadSlaveArray(1 downto 0);

   signal rxMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal rxSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;

   signal statusReg : slv(6 downto 0);

   signal updatedResults : sl;
   signal errorDet       : sl;
   signal rxBusy         : sl;
   signal txBusy         : sl;

begin

   ---------------------------
   -- Generate clock and reset
   ---------------------------
   U_ClkRst : entity work.ClkRst
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
   U_SsiPrbsTx : entity work.SsiPrbsTx
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
   U_RssiServer : entity work.AxiRssiCoreWrapper
      generic map (
         TPD_G             => TPD_G,
         SERVER_G          => true,     -- Server
         AXI_CONFIG_G      => RSSI_AXI_CONFIG_C,
         APP_AXIS_CONFIG_G => (0 => RSSI_AXIS_CONFIG_C),
         TSP_AXIS_CONFIG_G => RSSI_AXIS_CONFIG_C)
      port map (
         clk                => clk,
         rst                => rst,
         openRq             => '1',
         -- AXI Segment Buffer Interface
         mAxiWriteMaster    => axiWriteMasters(0),
         mAxiWriteSlave     => axiWriteSlaves(0),
         mAxiReadMaster     => axiReadMasters(0),
         mAxiReadSlave      => axiReadSlaves(0),
         -- Application Layer Interface
         sAppAxisMasters(0) => txMaster,
         sAppAxisSlaves(0)  => txSlave,
         mAppAxisSlaves(0)  => AXI_STREAM_SLAVE_FORCE_C,
         -- Transport Layer Interface
         sTspAxisMaster     => tspMasters(0),
         sTspAxisSlave      => tspSlaves(0),
         mTspAxisMaster     => tspMasters(1),
         mTspAxisSlave      => tspSlaves(1));

   --------------
   -- RSSI Client
   --------------         
   U_RssiClient : entity work.AxiRssiCoreWrapper
      generic map (
         TPD_G             => TPD_G,
         SERVER_G          => false,    -- Client
         AXI_CONFIG_G      => RSSI_AXI_CONFIG_C,
         APP_AXIS_CONFIG_G => (0 => RSSI_AXIS_CONFIG_C),
         TSP_AXIS_CONFIG_G => RSSI_AXIS_CONFIG_C)
      port map (
         clk                => clk,
         rst                => rst,
         openRq             => '1',
         statusReg          => statusReg,
         -- AXI Segment Buffer Interface
         mAxiWriteMaster    => axiWriteMasters(1),
         mAxiWriteSlave     => axiWriteSlaves(1),
         mAxiReadMaster     => axiReadMasters(1),
         mAxiReadSlave      => axiReadSlaves(1),
         -- Application Layer Interface
         sAppAxisMasters(0) => AXI_STREAM_MASTER_INIT_C,
         mAppAxisMasters(0) => rxMaster,
         mAppAxisSlaves(0)  => rxSlave,
         -- Transport Layer Interface
         sTspAxisMaster     => tspMasters(1),
         sTspAxisSlave      => tspSlaves(1),
         mTspAxisMaster     => tspMasters(0),
         mTspAxisSlave      => tspSlaves(0));

   -------------
   -- AXI Memory
   -------------
   GEN_VEC : for i in 1 downto 0 generate
      U_MEM : entity work.AxiRam
         generic map (
            TPD_G        => TPD_G,
            SYNTH_MODE_G => "xpm",
            AXI_CONFIG_G => RSSI_AXI_CONFIG_C)
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
   U_SsiPrbsRx : entity work.SsiPrbsRx
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

   comb : process (errorDet, r, rst, txBusy) is
      variable v : RegType;
   begin
      -- Latch the current value   
      v := r;

      -- Keep delay copies
      v.errorDet := errorDet;
      v.txBusy   := txBusy;
      v.trig     := not(r.txBusy);

      -- Check for rising edge
      if (txBusy = '1') and (r.txBusy = '0') then
         v.packetLength := r.packetLength + 1;
      end if;

      -- Reset      
      if (rst = '1') then
         v := REG_INIT_C;
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

   process(r)
   begin
      if r.errorDet = '1' then
         assert false
            report "Simulation Failed!" severity failure;
      end if;
   end process;

end testbed;
