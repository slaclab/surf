-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Simulation Testbed for testing the AxiStreamResize module
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

entity AxiStreamResizeTb is end AxiStreamResizeTb;

architecture testbed of AxiStreamResizeTb is

   constant CLK_PERIOD_C    : time             := 10 ns;
   constant TPD_C           : time             := CLK_PERIOD_C/4;
   constant PACKET_LENGTH_C : slv(31 downto 0) := toSlv(32, 32);
   constant NUMBER_PACKET_C : slv(31 downto 0) := toSlv(4096, 32);

   constant PRBS_SSI_CONFIG_C : AxiStreamConfigType := (
      TSTRB_EN_C    => false,
      TDATA_BYTES_C => 8,
      TDEST_BITS_C  => 8,
      TID_BITS_C    => 8,
      TKEEP_MODE_C  => TKEEP_COMP_C,
      TUSER_BITS_C  => 2,
      TUSER_MODE_C  => TUSER_FIRST_LAST_C);

   constant CONFIG_SIZE_C : natural := 8;
   constant AXI_STREAM_CONFIG_C : AxiStreamConfigArray(CONFIG_SIZE_C-1 downto 0) := (
      0                => (
         TSTRB_EN_C    => PRBS_SSI_CONFIG_C.TSTRB_EN_C,
         TKEEP_MODE_C  => PRBS_SSI_CONFIG_C.TKEEP_MODE_C,
         TUSER_MODE_C  => PRBS_SSI_CONFIG_C.TUSER_MODE_C,
         TDATA_BYTES_C => 1,
         TDEST_BITS_C  => PRBS_SSI_CONFIG_C.TDEST_BITS_C,
         TID_BITS_C    => PRBS_SSI_CONFIG_C.TID_BITS_C,
         TUSER_BITS_C  => PRBS_SSI_CONFIG_C.TUSER_BITS_C),
      1                => (
         TSTRB_EN_C    => PRBS_SSI_CONFIG_C.TSTRB_EN_C,
         TKEEP_MODE_C  => PRBS_SSI_CONFIG_C.TKEEP_MODE_C,
         TUSER_MODE_C  => PRBS_SSI_CONFIG_C.TUSER_MODE_C,
         TDATA_BYTES_C => 1,
         TDEST_BITS_C  => 0,
         TID_BITS_C    => PRBS_SSI_CONFIG_C.TID_BITS_C,
         TUSER_BITS_C  => PRBS_SSI_CONFIG_C.TUSER_BITS_C),
      2                => (
         TSTRB_EN_C    => PRBS_SSI_CONFIG_C.TSTRB_EN_C,
         TKEEP_MODE_C  => PRBS_SSI_CONFIG_C.TKEEP_MODE_C,
         TUSER_MODE_C  => PRBS_SSI_CONFIG_C.TUSER_MODE_C,
         TDATA_BYTES_C => 1,
         TDEST_BITS_C  => PRBS_SSI_CONFIG_C.TDEST_BITS_C,
         TID_BITS_C    => 0,
         TUSER_BITS_C  => PRBS_SSI_CONFIG_C.TUSER_BITS_C),
      3                => (
         TSTRB_EN_C    => PRBS_SSI_CONFIG_C.TSTRB_EN_C,
         TKEEP_MODE_C  => PRBS_SSI_CONFIG_C.TKEEP_MODE_C,
         TUSER_MODE_C  => PRBS_SSI_CONFIG_C.TUSER_MODE_C,
         TDATA_BYTES_C => 1,
         TDEST_BITS_C  => 0,
         TID_BITS_C    => 0,
         TUSER_BITS_C  => PRBS_SSI_CONFIG_C.TUSER_BITS_C),
      4                => (
         TSTRB_EN_C    => PRBS_SSI_CONFIG_C.TSTRB_EN_C,
         TKEEP_MODE_C  => PRBS_SSI_CONFIG_C.TKEEP_MODE_C,
         TUSER_MODE_C  => PRBS_SSI_CONFIG_C.TUSER_MODE_C,
         TDATA_BYTES_C => 1,
         TDEST_BITS_C  => PRBS_SSI_CONFIG_C.TDEST_BITS_C,
         TID_BITS_C    => PRBS_SSI_CONFIG_C.TID_BITS_C,
         TUSER_BITS_C  => 0),
      5                => (
         TSTRB_EN_C    => PRBS_SSI_CONFIG_C.TSTRB_EN_C,
         TKEEP_MODE_C  => PRBS_SSI_CONFIG_C.TKEEP_MODE_C,
         TUSER_MODE_C  => PRBS_SSI_CONFIG_C.TUSER_MODE_C,
         TDATA_BYTES_C => 1,
         TDEST_BITS_C  => 0,
         TID_BITS_C    => PRBS_SSI_CONFIG_C.TID_BITS_C,
         TUSER_BITS_C  => 0),
      6                => (
         TSTRB_EN_C    => PRBS_SSI_CONFIG_C.TSTRB_EN_C,
         TKEEP_MODE_C  => PRBS_SSI_CONFIG_C.TKEEP_MODE_C,
         TUSER_MODE_C  => PRBS_SSI_CONFIG_C.TUSER_MODE_C,
         TDATA_BYTES_C => 1,
         TDEST_BITS_C  => PRBS_SSI_CONFIG_C.TDEST_BITS_C,
         TID_BITS_C    => 0,
         TUSER_BITS_C  => 0),
      7                => (
         TSTRB_EN_C    => PRBS_SSI_CONFIG_C.TSTRB_EN_C,
         TKEEP_MODE_C  => PRBS_SSI_CONFIG_C.TKEEP_MODE_C,
         TUSER_MODE_C  => PRBS_SSI_CONFIG_C.TUSER_MODE_C,
         TDATA_BYTES_C => 1,
         TDEST_BITS_C  => 0,
         TID_BITS_C    => 0,
         TUSER_BITS_C  => 0));

   signal clk : sl := '0';
   signal rst : sl := '1';

   signal dropWrite : sl                            := '0';
   signal dropFrame : sl                            := '0';
   signal passed    : slv(CONFIG_SIZE_C-1 downto 0) := (others => '0');
   signal failed    : sl                            := '0';

   signal updated  : slv(CONFIG_SIZE_C-1 downto 0) := (others => '0');
   signal errorDet : slv(CONFIG_SIZE_C-1 downto 0) := (others => '0');

   signal errLength  : sl := '0';
   signal errDataBus : sl := '0';
   signal errEofe    : sl := '0';

   signal errWordCnt    : slv(31 downto 0)                     := (others => '0');
   signal errbitCnt     : slv(31 downto 0)                     := (others => '0');
   signal cnt           : Slv32Array(CONFIG_SIZE_C-1 downto 0) := (others => (others => '0'));
   signal packetLengths : Slv32Array(CONFIG_SIZE_C-1 downto 0) := (others => (others => '0'));

   signal txMasters : AxiStreamMasterArray(CONFIG_SIZE_C-1 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
   signal txSlaves  : AxiStreamSlaveArray(CONFIG_SIZE_C-1 downto 0);

   signal resizeMasters : AxiStreamMasterArray(CONFIG_SIZE_C-1 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
   signal resizeSlaves  : AxiStreamSlaveArray(CONFIG_SIZE_C-1 downto 0);

   signal sofMasters : AxiStreamMasterArray(CONFIG_SIZE_C-1 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
   signal sofSlaves  : AxiStreamSlaveArray(CONFIG_SIZE_C-1 downto 0);

   signal rxMasters : AxiStreamMasterArray(CONFIG_SIZE_C-1 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
   signal rxSlaves  : AxiStreamSlaveArray(CONFIG_SIZE_C-1 downto 0);

begin

   ---------------------------
   -- Generate clock and reset
   ---------------------------
   U_ClkRst : entity surf.ClkRst
      generic map (
         CLK_PERIOD_G      => CLK_PERIOD_C,
         RST_START_DELAY_G => 0 ns,  -- Wait this long into simulation before asserting reset
         RST_HOLD_TIME_G   => 1000 ns)  -- Hold reset for this long)
      port map (
         clkP => clk,
         clkN => open,
         rst  => rst,
         rstL => open);

   --------------
   -- Data Source
   --------------
   GEN_VEC :
   for i in (CONFIG_SIZE_C-1) downto 0 generate

      U_SsiPrbsTx : entity surf.SsiPrbsTx
         generic map (
            -- General Configurations
            TPD_G                      => TPD_C,
            AXI_EN_G                   => '0',
            -- AXI Stream Configurations
            MASTER_AXI_STREAM_CONFIG_G => AXI_STREAM_CONFIG_C(i))
         port map (
            -- Master Port (mAxisClk)
            mAxisClk     => clk,
            mAxisRst     => rst,
            mAxisMaster  => txMasters(i),
            mAxisSlave   => txSlaves(i),
            -- Trigger Signal (locClk domain)
            locClk       => clk,
            locRst       => rst,
            trig         => '1',
            packetLength => PACKET_LENGTH_C,
            forceEofe    => '0',
            busy         => open,
            tDest        => (others => '0'),
            tId          => (others => '0'));

      U_ResizeUp : entity surf.AxiStreamFifoV2
         generic map(
            -- General Configurations
            TPD_G               => TPD_C,
            -- AXI Stream Port Configurations
            SLAVE_AXI_CONFIG_G  => AXI_STREAM_CONFIG_C(i),
            MASTER_AXI_CONFIG_G => PRBS_SSI_CONFIG_C)
         port map (
            -- Slave Port
            sAxisClk    => clk,
            sAxisRst    => rst,
            sAxisMaster => txMasters(i),
            sAxisSlave  => txSlaves(i),
            -- Master Port
            mAxisClk    => clk,
            mAxisRst    => rst,
            mAxisMaster => sofMasters(i),
            mAxisSlave  => sofSlaves(i));

      BYPASS_SOF_INSERT : if (AXI_STREAM_CONFIG_C(i).TUSER_BITS_C >= 2) generate
         rxMasters(i) <= sofMasters(i);
         sofSlaves(i) <= rxSlaves(i);
      end generate;

      SOF_INSERT : if (AXI_STREAM_CONFIG_C(i).TUSER_BITS_C < 2) generate
         U_Sof : entity surf.SsiInsertSof
            generic map (
               TPD_G               => TPD_C,
               COMMON_CLK_G        => true,
               SLAVE_FIFO_G        => false,
               MASTER_FIFO_G       => false,
               SLAVE_AXI_CONFIG_G  => PRBS_SSI_CONFIG_C,
               MASTER_AXI_CONFIG_G => PRBS_SSI_CONFIG_C)
            port map (
               -- Slave Port
               sAxisClk    => clk,
               sAxisRst    => rst,
               sAxisMaster => sofMasters(i),
               sAxisSlave  => sofSlaves(i),
               -- Master Port
               mAxisClk    => clk,
               mAxisRst    => rst,
               mAxisMaster => rxMasters(i),
               mAxisSlave  => rxSlaves(i));
      end generate;

      U_SsiPrbsRx : entity surf.SsiPrbsRx
         generic map (
            -- General Configurations
            TPD_G                     => TPD_C,
            -- FIFO Configurations
            GEN_SYNC_FIFO_G           => true,
            -- AXI Stream Configurations
            SLAVE_AXI_STREAM_CONFIG_G => PRBS_SSI_CONFIG_C)
         port map (
            -- Streaming RX Data Interface (sAxisClk domain)
            sAxisClk       => clk,
            sAxisRst       => rst,
            sAxisMaster    => rxMasters(i),
            sAxisSlave     => rxSlaves(i),
            -- Optional: AXI-Lite Register Interface (axiClk domain)
            axiClk         => clk,
            axiRst         => rst,
            axiReadMaster  => AXI_LITE_READ_MASTER_INIT_C,
            axiWriteMaster => AXI_LITE_WRITE_MASTER_INIT_C,
            -- Error Detection Signals (sAxisClk domain)
            updatedResults => updated(i),
            errorDet       => errorDet(i),
            packetLength   => packetLengths(i));

   end generate GEN_VEC;

   process(clk)
      variable i : natural;
   begin
      if rising_edge(clk) then
         if rst = '1' then
            failed <= '0'             after TPD_C;
            passed <= (others => '0') after TPD_C;
         else
            for i in CONFIG_SIZE_C-1 downto 0 loop
               if updated(i) = '1' then
                  -- Check for missed packet error
                  if errorDet(i) = '1' then
                     failed <= '1' after TPD_C;
                  end if;
                  -- Check for packet size mismatch
                  if packetLengths(i) /= PACKET_LENGTH_C then
                     failed <= '1' after TPD_C;
                  end if;
                  -- Check the counter
                  if cnt(i) = NUMBER_PACKET_C then
                     passed(i) <= '1' after TPD_C;
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
