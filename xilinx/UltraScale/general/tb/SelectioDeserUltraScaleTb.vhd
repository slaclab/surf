-------------------------------------------------------------------------------
-- Title      : SSI Protocol: https://confluence.slac.stanford.edu/x/0oyfD
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Simulation Testbed for testing SelectioDeserUltraScale
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

library unisim;
use unisim.vcomponents.all;

entity SelectioDeserUltraScaleTb is end SelectioDeserUltraScaleTb;

architecture testbed of SelectioDeserUltraScaleTb is

   constant CLK_PERIOD_C : time := 7.812 ns;
   constant TPD_C        : time := 100 ps;

   constant AXI_STREAM_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(2);
   constant TX_PACKET_LENGTH_C  : slv(31 downto 0)    := toSlv(256, 32);
   constant NUMBER_PACKET_C     : slv(31 downto 0)    := x"000000FF";

   signal refClk128 : sl := '0';
   signal refRst128 : sl := '1';

   signal clk512 : sl := '0';
   signal clk128 : sl := '0';
   signal rst128 : sl := '1';

   signal txMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal txSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;

   signal txGbValid : sl := '0';
   signal txGbReady : sl := '0';
   signal txGbData  : slv(19 downto 0);
   signal txVec     : slv(1 downto 0);
   signal tx        : sl := '0';
   signal txDly     : sl := '0';
   signal txP       : sl := '0';
   signal txN       : sl := '1';

   signal deserData : Slv8Array(0 downto 0);
   signal dlyLoad   : slv(0 downto 0);
   signal dlyCfg    : Slv9Array(0 downto 0);

   signal sspLinkUp : slv(0 downto 0);
   signal sspValid  : slv(0 downto 0);
   signal sspData   : Slv16Array(0 downto 0);
   signal sspSof    : slv(0 downto 0);
   signal sspEof    : slv(0 downto 0);
   signal sspEofe   : slv(0 downto 0);

   signal rxMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;

   signal passed   : sl := '0';
   signal failed   : sl := '0';
   signal updated  : sl := '0';
   signal errorDet : sl := '0';
   signal cnt      : slv(31 downto 0);

begin

   U_ClkRst : entity surf.ClkRst
      generic map (
         CLK_PERIOD_G      => CLK_PERIOD_C,
         RST_START_DELAY_G => 0 ns,  -- Wait this long into simulation before asserting reset
         RST_HOLD_TIME_G   => 1 us)   -- Hold reset for this long)
      port map (
         clkP => refClk128,
         rst  => refRst128);

   U_SsiPrbsTx : entity surf.SsiPrbsTx
      generic map (
         TPD_G                      => TPD_C,
         AXI_EN_G                   => '0',
         MASTER_AXI_STREAM_CONFIG_G => AXI_STREAM_CONFIG_C)
      port map (
         -- Master Port (mAxisClk)
         mAxisClk     => clk128,
         mAxisRst     => rst128,
         mAxisMaster  => txMaster,
         mAxisSlave   => txSlave,
         -- Trigger Signal (locClk domain)
         locClk       => clk128,
         locRst       => rst128,
         trig         => sspLinkUp(0),
         packetLength => TX_PACKET_LENGTH_C);

   U_Encode : entity surf.SspEncoder8b10b
      generic map (
         TPD_G          => TPD_C,
         RST_POLARITY_G => '1',
         RST_ASYNC_G    => false,
         AUTO_FRAME_G   => true,
         FLOW_CTRL_EN_G => true)
      port map (
         clk      => clk128,
         rst      => rst128,
         validIn  => txMaster.tValid,
         readyIn  => txSlave.tReady,
         sof      => txMaster.tUser(SSI_SOF_C),
         eof      => txMaster.tLast,
         dataIn   => txMaster.tData(15 downto 0),
         validOut => txGbValid,
         readyOut => txGbReady,
         dataOut  => txGbData);

   U_Gearbox : entity surf.AsyncGearbox
      generic map (
         TPD_G             => TPD_C,
         SLAVE_WIDTH_G     => 20,
         MASTER_WIDTH_G    => 2,
         FIFO_ADDR_WIDTH_G => 5)
      port map (
         -- Slave Interface
         slaveClk       => clk128,
         slaveRst       => rst128,
         slaveValid     => txGbValid,
         slaveData      => txGbData,
         slaveReady     => txGbReady,
         slaveBitOrder  => '0',
         -- Master Interface
         masterClk      => clk512,
         masterRst      => '0',
         masterData     => txVec,
         masterReady    => '1',
         masterBitOrder => '0');

   U_ODDR : ODDRE1
      port map (
         Q  => tx,
         C  => clk512,
         D1 => txVec(0),
         D2 => txVec(1),
         SR => '0');

   process(tx)
   begin
      txDly <= tx after TPD_C;
   end process;

   U_OBUFDS : OBUFDS
      port map (
         I  => txDly,
         O  => txP,
         OB => txN);

   -------------------------
   -- SELECTIO Deserializers
   -------------------------
   U_Deser : entity surf.SelectioDeserUltraScale
      generic map(
         TPD_G            => TPD_C,
         SIMULATION_G     => true,
         NUM_LANE_G       => 1,
         CLKIN_PERIOD_G   => 7.812,     -- 128 MHz
         CLKFBOUT_MULT_G  => 8,         -- 1.024 GHz = 128 MHz x 8
         CLKOUT0_DIVIDE_G => 2)
      port map (
         -- SELECTIO Ports
         rxP(0)          => txP,
         rxN(0)          => txN,
         pllClk          => clk512,
         -- Reference Clock and Reset
         refClk          => refClk128,
         refRst          => refRst128,
         -- Deserialization Interface (deserClk domain)
         deserClk        => clk128,
         deserRst        => rst128,
         deserData       => deserData,
         dlyLoad         => dlyLoad,
         dlyCfg          => dlyCfg,
         -- AXI-Lite Interface (axilClk domain)
         axilClk         => refClk128,
         axilRst         => refRst128,
         axilReadMaster  => AXI_LITE_READ_MASTER_INIT_C,
         axilReadSlave   => open,
         axilWriteMaster => AXI_LITE_WRITE_MASTER_INIT_C,
         axilWriteSlave  => open);

   ----------------------------------
   -- SELECTIO Gearbox and SSP framer
   ----------------------------------
   U_SspDecoder : entity surf.SspLowSpeedDecoder8b10bWrapper
      generic map(
         TPD_G        => TPD_C,
         SIMULATION_G => true,
         NUM_LANE_G   => 1)
      port map (
         -- Deserialization Interface (deserClk domain)
         deserClk        => clk128,
         deserRst        => rst128,
         deserData       => deserData,
         dlyLoad         => dlyLoad,
         dlyCfg          => dlyCfg,
         -- SSP Frame Output (deserClk domain)
         rxLinkUp        => sspLinkUp,
         rxValid         => sspValid,
         rxData          => sspData,
         rxSof           => sspSof,
         rxEof           => sspEof,
         rxEofe          => sspEofe,
         -- AXI-Lite Interface (axilClk domain)
         axilClk         => refClk128,
         axilRst         => refRst128,
         axilReadMaster  => AXI_LITE_READ_MASTER_INIT_C,
         axilReadSlave   => open,
         axilWriteMaster => AXI_LITE_WRITE_MASTER_INIT_C,
         axilWriteSlave  => open);

   rxMaster.tValid              <= sspValid(0);
   rxMaster.tData(15 downto 0)  <= sspData(0);
   rxMaster.tUser(SSI_SOF_C)    <= sspSof(0);
   rxMaster.tLast               <= sspEof(0);

   U_SsiPrbsRx : entity surf.SsiPrbsRx
      generic map (
         TPD_G                     => TPD_C,
         SLAVE_READY_EN_G          => false,
         SLAVE_AXI_STREAM_CONFIG_G => AXI_STREAM_CONFIG_C)
      port map (
         -- Streaming RX Data Interface (sAxisClk domain)
         sAxisClk       => clk128,
         sAxisRst       => rst128,
         sAxisMaster    => rxMaster,
         -- Error Detection Signals (sAxisClk domain)
         updatedResults => updated,
         errorDet       => errorDet);

   process(clk128)
   begin
      if rising_edge(clk128) then
         if rst128 = '1' then
            cnt    <= (others => '0') after TPD_C;
            passed <= '0'             after TPD_C;
            failed <= '0'             after TPD_C;
         elsif updated = '1' then
            -- Check for packet error
            if errorDet = '1' then
               failed <= '1' after TPD_C;
            end if;
            -- Check the counter
            if cnt = NUMBER_PACKET_C then
               passed <= '1' after TPD_C;
            else
               -- Increment the counter
               cnt <= cnt + 1 after TPD_C;
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
