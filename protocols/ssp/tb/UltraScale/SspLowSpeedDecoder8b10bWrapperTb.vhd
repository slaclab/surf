-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Simulation Testbed for testing the SspLowSpeedDecoder8b10bWrapperTb module
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

entity SspLowSpeedDecoder8b10bWrapperTb is end SspLowSpeedDecoder8b10bWrapperTb;

architecture testbed of SspLowSpeedDecoder8b10bWrapperTb is

   constant TPD_C             : time := 0.25 ns;
   constant RST_START_DELAY_C : time := 0 ns;
   constant RST_HOLD_TIME_C   : time := 1000 ns;

   constant NUM_LANE_C : positive := 1;

   signal axilClk         : sl                     := '0';
   signal axilRst         : sl                     := '1';
   signal axilWriteMaster : AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
   signal axilWriteSlave  : AxiLiteWriteSlaveType  := AXI_LITE_WRITE_SLAVE_INIT_C;
   signal axilReadMaster  : AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
   signal axilReadSlave   : AxiLiteReadSlaveType   := AXI_LITE_READ_SLAVE_INIT_C;

   signal clk1000 : sl := '0';
   signal rst1000 : sl := '1';

   signal clk500 : sl := '0';
   signal rst500 : sl := '1';

   signal txEncodeValid : sl := '0';
   signal txEncodeReady : sl := '0';
   signal txEncodeData  : slv(19 downto 0);

   signal asicDataP : sl := '0';
   signal asicDataN : sl := '1';

   signal deserClk  : sl := '0';
   signal deserRst  : sl := '1';
   signal deserData : Slv8Array(NUM_LANE_C-1 downto 0);
   signal dlyLoad   : slv(NUM_LANE_C-1 downto 0);
   signal dlyCfg    : Slv9Array(NUM_LANE_C-1 downto 0);

   signal sspRxLinkUp : slv(NUM_LANE_C-1 downto 0);
   signal sspRxValid  : slv(NUM_LANE_C-1 downto 0);
   signal sspRxData   : Slv16Array(NUM_LANE_C-1 downto 0);
   signal sspRxSof    : slv(NUM_LANE_C-1 downto 0);
   signal sspRxEof    : slv(NUM_LANE_C-1 downto 0);
   signal sspRxEofe   : slv(NUM_LANE_C-1 downto 0);

begin

   --------------------
   -- Clocks and Resets
   --------------------
   U_axilClk : entity surf.ClkRst
      generic map (
         CLK_PERIOD_G      => 6.4 ns,
         RST_START_DELAY_G => RST_START_DELAY_C,
         RST_HOLD_TIME_G   => RST_HOLD_TIME_C)
      port map (
         clkP => axilClk,
         rst  => axilRst);

   U_clk1000 : entity surf.ClkRst
      generic map (
         CLK_PERIOD_G      => 1.0 ns,
         RST_START_DELAY_G => RST_START_DELAY_C,
         RST_HOLD_TIME_G   => RST_HOLD_TIME_C)
      port map (
         clkP => clk1000,
         rst  => rst1000);

   U_clk500 : entity surf.ClkRst
      generic map (
         CLK_PERIOD_G      => 2.0 ns,
         RST_START_DELAY_G => RST_START_DELAY_C,
         RST_HOLD_TIME_G   => RST_HOLD_TIME_C)
      port map (
         clkP => clk500,
         rst  => rst500);

   ----------
   -- Encoder
   ----------
   U_Encoder : entity surf.SspEncoder8b10b
      generic map (
         TPD_G          => TPD_C,
         RST_POLARITY_G => '1',
         RST_ASYNC_G    => false,
         AUTO_FRAME_G   => true,
         FLOW_CTRL_EN_G => true)
      port map (
         -- Clock and REset
         clk      => clk1000,
         rst      => rst1000,
         -- Inbound Interface
         validIn  => '0',
         dataIn   => x"00_00",
         -- Outbound Interface
         validOut => txEncodeValid,
         readyOut => txEncodeReady,
         dataOut  => txEncodeData);

   ---------------
   -- 20:1 Gearbox
   ---------------
   U_Serializer : entity surf.Gearbox
      generic map (
         TPD_G          => TPD_C,
         SLAVE_WIDTH_G  => 20,
         MASTER_WIDTH_G => 1)
      port map (
         -- Clock and Reset
         clk           => clk1000,
         rst           => rst1000,
         -- Slave Interface
         slaveValid    => txEncodeValid,
         slaveReady    => txEncodeReady,
         slaveData     => txEncodeData,
         -- Master Interface
         masterData(0) => asicDataP);

   asicDataN <= not(asicDataP);

   -------------------------
   -- SELECTIO Deserializers
   -------------------------
   U_Deser : entity surf.SelectioDeserUltraScale
      generic map(
         TPD_G        => TPD_C,
         EXT_PLL_G    => true,
         SIMULATION_G => true,
         NUM_LANE_G   => NUM_LANE_C)
      port map (
         -- SELECTIO Ports
         rxP(0)      => asicDataP,
         rxN(0)      => asicDataN,
         -- External PLL Interface
         extPllClkIn => clk500,
         extPllRstIn => rst500,
         -- Reference Clock and Reset
         refClk      => '0',
         refRst      => '1',
         -- Deserialization Interface (deserClk domain)
         deserClk    => deserClk,
         deserRst    => deserRst,
         deserData   => deserData,
         dlyLoad     => dlyLoad,
         dlyCfg      => dlyCfg);

   ----------------------------------
   -- SELECTIO Gearbox and SSP framer
   ----------------------------------
   U_SspDecoder : entity surf.SspLowSpeedDecoder8b10bWrapper
      generic map(
         TPD_G        => TPD_C,
         SIMULATION_G => true,
         NUM_LANE_G   => NUM_LANE_C)
      port map (
         -- Deserialization Interface (deserClk domain)
         deserClk        => deserClk,
         deserRst        => deserRst,
         deserData       => deserData,
         dlyLoad         => dlyLoad,
         dlyCfg          => dlyCfg,
         -- SSP Frame Output (deserClk domain)
         rxLinkUp        => sspRxLinkUp,
         rxValid         => sspRxValid,
         rxData          => sspRxData,
         rxSof           => sspRxSof,
         rxEof           => sspRxEof,
         rxEofe          => sspRxEofe,
         -- AXI-Lite Interface (axilClk domain)
         axilClk         => axilClk,
         axilRst         => axilRst,
         axilReadMaster  => axilReadMaster,
         axilReadSlave   => axilReadSlave,
         axilWriteMaster => axilWriteMaster,
         axilWriteSlave  => axilWriteSlave);

   ---------------------------------
   -- AXI-Lite Register Transactions
   ---------------------------------
   test : process is
      variable debugData : slv(31 downto 0) := (others => '0');
   begin
      ------------------------------------------
      -- Wait for the AXI-Lite reset to complete
      ------------------------------------------
      wait until axilRst = '1';
      wait until axilRst = '0';

      axiLiteBusSimWrite (axilClk, axilWriteMaster, axilWriteSlave, x"0000_0904", x"0000_0001", true);  -- lockOnIdle=0x1
      axiLiteBusSimWrite (axilClk, axilWriteMaster, axilWriteSlave, x"0000_0808", x"0000_0050", true);  -- minEyeWidth=80 (0x50)
      axiLiteBusSimWrite (axilClk, axilWriteMaster, axilWriteSlave, x"0000_080C", x"0000_0004", true);  -- lockingCntCfg=0x4
      axiLiteBusSimWrite (axilClk, axilWriteMaster, axilWriteSlave, x"0000_0810", x"0000_0001", true);  -- bypFirstBerDet=0x1
      axiLiteBusSimWrite (axilClk, axilWriteMaster, axilWriteSlave, x"0000_0800", x"0000_0000", true);  -- enUsrDlyCfg=0x0
      axiLiteBusSimWrite (axilClk, axilWriteMaster, axilWriteSlave, x"0000_0500", x"0000_0010", true);  -- usrDlyCfg[0]=0x10

   end process test;

end testbed;
