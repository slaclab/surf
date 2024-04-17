-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Simulation Testbed for testing the AxiStreamMux module
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

entity AxiStreamMuxTb is end AxiStreamMuxTb;

architecture testbed of AxiStreamMuxTb is

   -- Constants
   constant SLOW_CLK_PERIOD_C  : time             := 10 ns;
   constant FAST_CLK_PERIOD_C  : time             := SLOW_CLK_PERIOD_C/3.14159;
   constant TPD_C              : time             := FAST_CLK_PERIOD_C/4;
   constant STATUS_CNT_WIDTH_C : natural          := 32;
   constant TX_PACKET_LENGTH_C : slv(31 downto 0) := toSlv(32, 32);
   constant NUMBER_PACKET_C    : slv(31 downto 0) := toSlv(4096, 32);
   constant MUX_SIZE_C         : natural          := 4;

   -- FIFO configurations
   constant MEMORY_TYPE_G       : string  := "block";
   constant CASCADE_SIZE_C      : natural := 1;
   constant FIFO_ADDR_WIDTH_C   : natural := 9;
   constant FIFO_PAUSE_THRESH_C : natural := 2**8;

   -- PRBS Configuration
   constant PRBS_SEED_SIZE_C : natural      := 32;
   constant PRBS_TAPS_C      : NaturalArray := (0 => 31, 1 => 6, 2 => 2, 3 => 1);

   -- AXI Stream Configurations
   constant AXI_STREAM_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(4);
   constant AXI_PIPE_STAGES_C   : natural             := 1;

   -- Signals
   signal fastClk : sl := '0';
   signal fastRst : sl := '1';

   signal slowClk : sl := '0';
   signal slowRst : sl := '1';

   signal dropWrite  : sl                         := '0';
   signal dropFrame  : sl                         := '0';
   signal passedSlow : slv(MUX_SIZE_C-1 downto 0) := (others => '0');
   signal failedSlow : sl                         := '0';
   signal failedFast : sl                         := '0';

   signal updated  : slv(MUX_SIZE_C-1 downto 0) := (others => '0');
   signal errorDet : slv(MUX_SIZE_C-1 downto 0) := (others => '0');

   signal errLength  : sl := '0';
   signal errDataBus : sl := '0';
   signal errEofe    : sl := '0';

   signal errWordCnt    : slv(31 downto 0)                  := (others => '0');
   signal errbitCnt     : slv(31 downto 0)                  := (others => '0');
   signal cnt           : Slv32Array(MUX_SIZE_C-1 downto 0) := (others => (others => '0'));
   signal packetLengths : Slv32Array(MUX_SIZE_C-1 downto 0) := (others => (others => '0'));

   signal ibMaster  : AxiStreamMasterType;
   signal ibSlave   : AxiStreamSlaveType;
   signal ibMasters : AxiStreamMasterArray(MUX_SIZE_C-1 downto 0);
   signal ibSlaves  : AxiStreamSlaveArray(MUX_SIZE_C-1 downto 0);

   signal obMaster  : AxiStreamMasterType;
   signal obSlave   : AxiStreamSlaveType;
   signal obMasters : AxiStreamMasterArray(MUX_SIZE_C-1 downto 0);
   signal obSlaves  : AxiStreamSlaveArray(MUX_SIZE_C-1 downto 0);

   signal rearbitrate : sl      := '0';
   signal rearbCount  : integer := 0;

begin

   ---------------------------------------
   -- Generate fast clocks and fast resets
   ---------------------------------------
   ClkRst_Fast : entity surf.ClkRst
      generic map (
         CLK_PERIOD_G      => FAST_CLK_PERIOD_C,
         RST_START_DELAY_G => 0 ns,     -- Wait this long into simulation before asserting reset
         RST_HOLD_TIME_G   => 200 ns)   -- Hold reset for this long)
      port map (
         clkP => fastClk,
         clkN => open,
         rst  => fastRst,
         rstL => open);

   ClkRst_Slow : entity surf.ClkRst
      generic map (
         CLK_PERIOD_G      => SLOW_CLK_PERIOD_C,
         RST_START_DELAY_G => 0 ns,     -- Wait this long into simulation before asserting reset
         RST_HOLD_TIME_G   => 200 ns)   -- Hold reset for this long)
      port map (
         clkP => slowClk,
         clkN => open,
         rst  => slowRst,
         rstL => open);

   --------------
   -- Data Source
   --------------
   GEN_SRC :
   for i in (MUX_SIZE_C-1) downto 0 generate
      SsiPrbsTx_Inst : entity surf.SsiPrbsTx
         generic map (
            -- General Configurations
            TPD_G                      => TPD_C,
            -- FIFO configurations
            MEMORY_TYPE_G              => MEMORY_TYPE_C,
            GEN_SYNC_FIFO_G            => true,
            CASCADE_SIZE_G             => CASCADE_SIZE_C,
            FIFO_ADDR_WIDTH_G          => FIFO_ADDR_WIDTH_C,
            FIFO_PAUSE_THRESH_G        => FIFO_PAUSE_THRESH_C,
            -- PRBS Configurations
            PRBS_SEED_SIZE_G           => PRBS_SEED_SIZE_C,
            PRBS_TAPS_G                => PRBS_TAPS_C,
--            PRBS_INCREMENT_G => true,
            -- AXI Stream Configurations
            MASTER_AXI_STREAM_CONFIG_G => AXI_STREAM_CONFIG_C,
            MASTER_AXI_PIPE_STAGES_G   => AXI_PIPE_STAGES_C)
         port map (
            -- Master Port (mAxisClk)
            mAxisClk     => fastClk,
            mAxisRst     => fastRst,
            mAxisMaster  => obMasters(i),
            mAxisSlave   => obSlaves(i),
            -- Trigger Signal (locClk domain)
            locClk       => fastClk,
            locRst       => fastRst,
            trig         => '1',
            packetLength => (TX_PACKET_LENGTH_C+(i*10)),
            forceEofe    => '0',
            busy         => open,
            tDest        => (others => '0'),
            tId          => (others => '0'));
   end generate GEN_SRC;


   rearb_proc : process (fastClk) is
   begin
      if (rising_edge(fastClk)) then
         if (rearbCount = 80) then
            rearbCount  <= 0   after TPD_C;
            rearbitrate <= '1' after TPD_C;
         else
            rearbCount  <= rearbCount + 1 after TPD_C;
            rearbitrate <= '0'            after TPD_C;
         end if;
      end if;
   end process rearb_proc;

   -- Module to be tested
   U_AxiStreamMux : entity surf.AxiStreamMux
      generic map (
         TPD_G                => TPD_C,
         NUM_SLAVES_G         => MUX_SIZE_C,
         ILEAVE_EN_G          => true,
         ILEAVE_ON_NOTVALID_G => true,
         ILEAVE_REARB_G       => 16)
      port map (
         -- Clock and reset
         axisClk      => fastClk,
         axisRst      => fastRst,
         -- Slaves
         rearbitrate  => rearbitrate,
         sAxisMasters => obMasters,
         sAxisSlaves  => obSlaves,
         -- Master
         mAxisMaster  => obMaster,
         mAxisSlave   => obSlave);

   process(fastClk)
   begin
      if rising_edge(fastClk) then
         if fastRst = '1' then
            failedFast <= '0' after TPD_C;
         else
            -- Check for dropped word error
            if dropWrite = '1' then
               failedFast <= '1' after TPD_C;
            end if;
            -- Check for dropped frame error
            if dropFrame = '1' then
               failedFast <= '1' after TPD_C;
            end if;
         end if;
      end if;
   end process;

   process(failedFast, failedSlow, passedSlow)
   begin
      if (failedFast = '1') or (failedSlow = '1') then
         assert false
            report "Simulation Failed!" severity failure;
      end if;
      if uAnd(passedSlow) = '1' then
         assert false
            report "Simulation Passed!" severity failure;
      end if;
   end process;

   U_AxiStreamDeMux : entity surf.AxiStreamDeMux
      generic map (
         TPD_G         => TPD_C,
         NUM_MASTERS_G => MUX_SIZE_C)
      port map (
         -- Clock and reset
         axisClk      => slowClk,
         axisRst      => slowRst,
         -- Slaves
         sAxisMaster  => obMaster,
         sAxisSlave   => obSlave,
         -- Master
         mAxisMasters => ibMasters,
         mAxisSlaves  => ibSlaves);

   ------------
   -- Data Sink
   ------------
   GEN_SINK :
   for i in (MUX_SIZE_C-1) downto 0 generate
      SsiPrbsRx_Inst : entity surf.SsiPrbsRx
         generic map (
            -- General Configurations
            TPD_G                      => TPD_C,
            STATUS_CNT_WIDTH_G         => STATUS_CNT_WIDTH_C,
            -- FIFO Configurations
            MEMORY_TYPE_G              => MEMORY_TYPE_C,
            GEN_SYNC_FIFO_G            => true,
            CASCADE_SIZE_G             => CASCADE_SIZE_C,
            FIFO_ADDR_WIDTH_G          => FIFO_ADDR_WIDTH_C,
            FIFO_PAUSE_THRESH_G        => FIFO_PAUSE_THRESH_C,
            -- PRBS Configurations
            PRBS_SEED_SIZE_G           => PRBS_SEED_SIZE_C,
            PRBS_TAPS_G                => PRBS_TAPS_C,
            -- AXI Stream Configurations
            SLAVE_AXI_STREAM_CONFIG_G  => AXI_STREAM_CONFIG_C,
            SLAVE_AXI_PIPE_STAGES_G    => AXI_PIPE_STAGES_C)
         port map (
            -- Streaming RX Data Interface (sAxisClk domain)
            sAxisClk       => slowClk,
            sAxisRst       => slowRst,
            sAxisMaster    => ibMasters(i),
            sAxisSlave     => ibSlaves(i),
            sAxisCtrl      => open,
            -- Optional: AXI-Lite Register Interface (axiClk domain)
            axiClk         => slowClk,
            axiRst         => slowRst,
            axiReadMaster  => AXI_LITE_READ_MASTER_INIT_C,
            axiReadSlave   => open,
            axiWriteMaster => AXI_LITE_WRITE_MASTER_INIT_C,
            -- Error Detection Signals (sAxisClk domain)
            updatedResults => updated(i),
            errorDet       => errorDet(i),
            packetLength   => packetLengths(i));
   end generate GEN_SINK;

   process(slowClk)
      variable i : natural;
   begin
      if rising_edge(slowClk) then
         if slowRst = '1' then
            failedSlow <= '0'             after TPD_C;
            passedSlow <= (others => '0') after TPD_C;
         else
            for i in MUX_SIZE_C-1 downto 0 loop
               if updated(i) = '1' then
                  -- Check for missed packet error
                  if errorDet(i) = '1' then
                     failedSlow <= '1' after TPD_C;
                  end if;
                  -- Check for packet size mismatch
                  if packetLengths(i) /= (TX_PACKET_LENGTH_C+i) then
                     failedSlow <= '1' after TPD_C;
                  end if;
                  -- Check the counter
                  if cnt(i) = NUMBER_PACKET_C then
                     passedSlow(i) <= '1' after TPD_C;
                  else
                     -- Increment the counter
                     cnt(i) <= cnt(i) + 1 after TPD_C;
                  end if;
               end if;
            end loop;
         end if;
      end if;
   end process;

end testbed;
