-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
-- ADC Readout Controller
-- Receives ADC Data from an AD9592 chip.
-- Designed specifically for Xilinx Ultrascale series FPGAs
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

library UNISIM;
use UNISIM.vcomponents.all;


library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;
use surf.AxiStreamPkg.all;
use surf.Ad9249Pkg.all;

entity Ad9249ReadoutGroup is
   generic (
      TPD_G             : time                 := 1 ns;
      NUM_CHANNELS_G    : natural range 1 to 8 := 8;
      IODELAY_GROUP_G   : string               := "DEFAULT_GROUP";
      D_DELAY_CASCADE_G : boolean              := false;
      F_DELAY_CASCADE_G : boolean              := false;
      IDELAYCTRL_FREQ_G : real                 := 200.0;
      DEFAULT_DELAY_G   : slv(8 downto 0)      := (others => '0');
      ADC_INVERT_CH_G   : slv(7 downto 0)      := "00000000";
      USE_MMCME_G       : boolean              := false;
      SIM_SPEEDUP_G     : boolean              := false);
   port (
      -- Master system clock, 125Mhz
      axilClk           : in sl;
      axilRst           : in sl;

      -- Axi Interface
      axilWriteMaster   : in  AxiLiteWriteMasterType;
      axilWriteSlave    : out AxiLiteWriteSlaveType;
      axilReadMaster    : in  AxiLiteReadMasterType;
      axilReadSlave     : out AxiLiteReadSlaveType;

      -- Reset for adc deserializer (axilClk domain)
      adcClkRst         : in sl;
      
      -- clocks must be provided with USE_MMCME_G = false
      -- this option is necessary if there is many ADCs
      -- one external MMCM should be instantiated to be used with all Ad9249ReadoutGroups
      adcBitClkIn       : in sl;    -- 350.0 MHz
      adcBitClkDiv4In   : in sl;    --  87.5 MHz
      adcBitClkDiv7In   : in sl;    --  50.0 MHz
      adcBitRstIn       : in sl;
      adcBitRstDiv4In   : in sl;
      adcBitRstDiv7In   : in sl;

      -- Serial Data from ADC
      adcSerial         : in Ad9249SerialGroupType;

      -- Deserialized ADC Data
      adcStreamClk      : in  sl;
      adcStreams        : out AxiStreamMasterArray(NUM_CHANNELS_G-1 downto 0) :=
      (others => axiStreamMasterInit((false, 2, 8, 0, TKEEP_NORMAL_C, 0, TUSER_NORMAL_C))));
end Ad9249ReadoutGroup;

-- Define architecture
architecture rtl of Ad9249ReadoutGroup is

   attribute keep : string;

   constant FRAME_PATTERN_C : slv(13 downto 0) := "11111110000000";

   -------------------------------------------------------------------------------------------------
   -- AXIL Registers
   -------------------------------------------------------------------------------------------------
   type AxilRegType is record
      axilWriteSlave : AxiLiteWriteSlaveType;
      axilReadSlave  : AxiLiteReadSlaveType;
      delay          : slv(8 downto 0);
      dataDelaySet   : slv(NUM_CHANNELS_G-1 downto 0);
      frameDelaySet  : sl;
      freezeDebug    : sl;
      readoutDebug0  : slv16Array(NUM_CHANNELS_G-1 downto 0);
      readoutDebug1  : slv16Array(NUM_CHANNELS_G-1 downto 0);
      lockedCountRst : sl;
      invert         : sl;
   end record;

   constant AXIL_REG_INIT_C : AxilRegType := (
      axilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C,
      axilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
      delay          => DEFAULT_DELAY_G,
      dataDelaySet   => (others => '1'),
      frameDelaySet  => '1',
      freezeDebug    => '0',
      readoutDebug0  => (others => (others => '0')),
      readoutDebug1  => (others => (others => '0')),
      lockedCountRst => '0',
      invert         => '0'
   );

   signal lockedSync      : sl;
   signal lockedFallCount : slv(15 downto 0);

   signal axilR   : AxilRegType := AXIL_REG_INIT_C;
   signal axilRin : AxilRegType;

   -------------------------------------------------------------------------------------------------
   -- ADC Readout Clocked Registers
   -------------------------------------------------------------------------------------------------
   type AdcRegType is record
      slip          : slv(3 downto 0);
      count         : slv(5 downto 0);
      gearBoxOffset : slv(2 downto 0);
      --loadDelay      : sl;
      --delayValue     : slv(8 downto 0);
      locked        : sl;
      fifoWrData    : Slv16Array(NUM_CHANNELS_G-1 downto 0);
   end record;

   constant ADC_REG_INIT_C : AdcRegType := (
      slip          => (others => '0'),
      count         => (others => '0'),
      gearBoxOffset => (others => '0'),
      --loadDelay      => '0',
      --delayValue     => (others => '0'),
      locked        => '0',
      fifoWrData    => (others => (others => '0')));

   signal adcR   : AdcRegType := ADC_REG_INIT_C;
   signal adcRin : AdcRegType;


   -- Local Signals
   signal adcDclk       : sl;
   signal adcBitClk     : sl;
   signal adcBitClkDiv7 : sl;
   signal adcBitClkDiv4 : sl;
   signal adcBitRstDiv7 : sl;
   signal adcBitRstDiv4 : sl;
   signal adcBitRst     : sl;
   signal adcClkRstSync : sl;

   signal adcFramePad   : sl;
   signal adcFrame      : slv(13 downto 0);
   signal adcFrameSync  : slv(13 downto 0);
   signal adcDataPadOut : slv(NUM_CHANNELS_G-1 downto 0);
   signal adcDataPad    : slv(NUM_CHANNELS_G-1 downto 0);
   signal adcData       : Slv14Array(NUM_CHANNELS_G-1 downto 0);

   signal curDelayFrame : slv(8 downto 0);
   signal curDelayData  : slv9Array(NUM_CHANNELS_G-1 downto 0);

   signal fifoDataValid : sl;
   signal fifoDataOut   : slv(NUM_CHANNELS_G*16-1 downto 0);
   signal fifoDataIn    : slv(NUM_CHANNELS_G*16-1 downto 0);
   signal fifoDataTmp   : slv16Array(NUM_CHANNELS_G-1 downto 0);

   signal debugDataValid : sl;
   signal debugDataOut   : slv(NUM_CHANNELS_G*16-1 downto 0);
   signal debugDataTmp   : slv16Array(NUM_CHANNELS_G-1 downto 0);
   
   signal frameDelay    : slv(8 downto 0);
   signal frameDelaySet : sl;
   
   signal invertSync    : sl;
   
   signal slipSync      : slv(3 downto 0);
   
   attribute KEEP_HIERARCHY                     : string;
   attribute KEEP_HIERARCHY of AdcClk_I_Ibufds  : label is "TRUE";
   attribute dont_touch                         : string;
   attribute dont_touch of adcDclk              : signal is "TRUE";

begin
   -------------------------------------------------------------------------------------------------
   -- Synchronize adcR.locked across to axil clock domain and count falling edges on it
   -------------------------------------------------------------------------------------------------

   SynchronizerOneShotCnt_1 : entity surf.SynchronizerOneShotCnt
      generic map (
         TPD_G          => TPD_G,
         IN_POLARITY_G  => '0',
         OUT_POLARITY_G => '0',
         CNT_RST_EDGE_G => true,
         CNT_WIDTH_G    => 16)
      port map (
         dataIn     => adcR.locked,
         rollOverEn => '0',
         cntRst     => axilR.lockedCountRst,
         dataOut    => open,
         cntOut     => lockedFallCount,
         wrClk      => adcBitClkDiv7,
         wrRst      => '0',
         rdClk      => axilClk,
         rdRst      => axilRst);

   Synchronizer_1 : entity surf.Synchronizer
      generic map (
         TPD_G    => TPD_G,
         STAGES_G => 2)
      port map (
         clk     => axilClk,
         rst     => axilRst,
         dataIn  => adcR.locked,
         dataOut => lockedSync);

   SynchronizerVec_1 : entity surf.SynchronizerVector
      generic map (
         TPD_G    => TPD_G,
         STAGES_G => 2,
         WIDTH_G  => 14)
      port map (
         clk     => axilClk,
         rst     => axilRst,
         dataIn  => adcFrame,
         dataOut => adcFrameSync);
   
   Synchronizer_2 : entity surf.Synchronizer
      generic map (
         TPD_G    => TPD_G,
         STAGES_G => 2)
      port map (
         clk     => adcBitClkDiv7,
         dataIn  => axilR.invert,
         dataOut => invertSync);

   -------------------------------------------------------------------------------------------------
   -- AXIL Interface
   -------------------------------------------------------------------------------------------------
   axilComb : process (adcFrameSync, axilR, axilReadMaster, axilRst, axilWriteMaster, curDelayData,
                       curDelayFrame, debugDataTmp, debugDataValid, lockedFallCount, lockedSync, adcClkRst) is
      variable v      : AxilRegType;
      variable axilEp : AxiLiteEndpointType;
   begin
      v := axilR;

      v.dataDelaySet        := (others => '0');
      v.frameDelaySet       := '0';
      v.axilReadSlave.rdata := (others => '0');
      v.lockedCountRst      := '0';

      -- Store last two samples read from ADC
      if (debugDataValid = '1' and axilR.freezeDebug = '0') then
         v.readoutDebug0 := debugDataTmp;
         v.readoutDebug1 := axilR.readoutDebug0;
      end if;

      axiSlaveWaitTxn(axilEp, axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave);

      -- Up to 8 delay registers
      -- Write delay values to IDELAY primatives
      -- All writes go to same r.delay register,
      -- dataDelaySet(i) or frameDelaySet enables the primative write
      for i in 0 to NUM_CHANNELS_G-1 loop
         axiSlaveRegister(axilEp, X"00"+toSlv((i*4), 8), 0, v.delay);
         axiSlaveRegister(axilEp, X"00"+toSlv((i*4), 8), 9, v.dataDelaySet(i), '1');
      end loop;
      axiSlaveRegister(axilEp, X"20", 0, v.delay);
      axiSlaveRegister(axilEp, X"20", 9, v.frameDelaySet, '1');

      -- Override read from r.delay and use curDealy output from delay primative instead
      for i in 0 to NUM_CHANNELS_G-1 loop
         axiSlaveRegisterR(axilEp, X"00"+toSlv((i*4), 8), 0, curDelayData(i));
      end loop;
      axiSlaveRegisterR(axilEp, X"20", 0, curDelayFrame);


      -- Debug output to see how many times the shift has needed a relock
      axiSlaveRegisterR(axilEp, X"30", 0, lockedFallCount);
      axiSlaveRegisterR(axilEp, X"30", 16, lockedSync);
      axiSlaveRegisterR(axilEp, X"34", 0, adcFrameSync);
      axiSlaveRegister(axilEp, X"38", 0, v.lockedCountRst);
      
      axiSlaveRegister(axilEp, X"40", 0, v.invert);

      -- Debug registers. Output the last 2 words received
      for i in 0 to NUM_CHANNELS_G-1 loop
         axiSlaveRegisterR(axilEp, X"80"+toSlv((i*4), 8), 0, axilR.readoutDebug0(i));
         axiSlaveRegisterR(axilEp, X"80"+toSlv((i*4), 8), 16, axilR.readoutDebug1(i));
      end loop;

      axiSlaveRegister(axilEp, X"A0", 0, v.freezeDebug);

      axiSlaveDefault(axilEp, v.axilWriteSlave, v.axilReadSlave, AXI_RESP_DECERR_C);
      
      if adcClkRst = '1' then
         v.lockedCountRst := '1';
      end if;

      if (axilRst = '1') then
         v := AXIL_REG_INIT_C;
      end if;

      axilRin        <= v;
      axilWriteSlave <= axilR.axilWriteSlave;
      axilReadSlave  <= axilR.axilReadSlave;

   end process;

   axilSeq : process (axilClk) is
   begin
      if (rising_edge(axilClk)) then
         axilR <= axilRin after TPD_G;
      end if;
   end process axilSeq;


   AdcClk_I_Ibufds : IBUFDS
   generic map (
      DQS_BIAS => "FALSE"
   )
   port map (
      I  => adcSerial.dClkP,
      IB => adcSerial.dClkN,
      O  => adcDclk
   );

   -------------------------------------------------------------------------------------------------
   -- Create Clocks
   -------------------------------------------------------------------------------------------------

   G_MMCM : if USE_MMCME_G = true generate
      
      
      ------------------------------------------
      -- Generate clocks from ADC incoming clock
      ------------------------------------------
      -- clkIn     : 350.00 MHz ADC clock
      -- clkOut(0) : 350.00 MHz adcBitClk clock
      -- clkOut(1) :  87.50 MHz adcBitClkDiv4 clock
      -- clkOut(2) :  50.00 MHz adcBitClkDiv7 clock
      U_iserdesClockGen : entity surf.ClockManagerUltraScale
         generic map(
            TPD_G                  => 1 ns,
            TYPE_G                 => "MMCM",  -- or "PLL"
            INPUT_BUFG_G           => true,
            FB_BUFG_G              => true,
            RST_IN_POLARITY_G      => '1',     -- '0' for active low
            NUM_CLOCKS_G           => 3,
            -- MMCM attributes
            BANDWIDTH_G            => "OPTIMIZED",
            CLKIN_PERIOD_G         => 2.85,    -- Input period in ns );
            DIVCLK_DIVIDE_G        => 10,
            CLKFBOUT_MULT_F_G      => 20.0,
            CLKFBOUT_MULT_G        => 5,
            CLKOUT0_DIVIDE_F_G     => 1.0,
            CLKOUT0_DIVIDE_G       => 2,
            CLKOUT1_DIVIDE_G       => 8,
            CLKOUT2_DIVIDE_G       => 14
        )
         port map(
            clkIn     => adcDclk,
            rstIn     => '0',
            clkOut(0) => adcBitClk,
            clkOut(1) => adcBitClkDiv4,
            clkOut(2) => adcBitClkDiv7,
            rstOut(0) => adcBitRst,
            rstOut(1) => adcBitRstDiv4,
            rstOut(2) => adcBitRstDiv7,
            locked    => open
         );
      
   end generate G_MMCM;
   
   G_NO_MMCM : if USE_MMCME_G = false generate
      
      adcBitClk      <= adcBitClkIn;
      adcBitClkDiv4  <= adcBitClkDiv4In;
      adcBitClkDiv7  <= adcBitClkDiv7In;
      adcBitRst      <= adcBitRstIn;
      adcBitRstDiv4  <= adcBitRstDiv4In;
      adcBitRstDiv7  <= adcBitRstDiv7In;
      
   end generate G_NO_MMCM;

   -------------------------------------------------------------------------------------------------
   -- Deserializers
   -------------------------------------------------------------------------------------------------
   U_FRAME_DESERIALIZER : entity surf.Ad9249Deserializer
      generic map (
         TPD_G             => TPD_G,
         IODELAY_GROUP_G   => "DEFAULT_GROUP",
         IDELAY_CASCADE_G  => F_DELAY_CASCADE_G,
         IDELAYCTRL_FREQ_G => 350.0,
         DEFAULT_DELAY_G   => (others => '0'),
         ADC_INVERT_CH_G   => '1',
         BIT_REV_G         => '0')
      port map (
         dClk          => adcBitClk,      -- Data clock
         dRst          => adcBitRst,
         dClkDiv4      => adcBitClkDiv4,
         dRstDiv4      => adcBitRstDiv4,
         dClkDiv7      => adcBitClkDiv7,
         dRstDiv7      => adcBitRstDiv7,
         sDataP        => adcSerial.fClkP,  -- Frame clock
         sDataN        => adcSerial.fClkN,
         loadDelay     => frameDelaySet,
         delay         => frameDelay,
         delayValueOut => curDelayFrame,
         bitSlip       => slipSync,
         gearboxOffset => adcR.gearboxOffset,
         adcData       => adcFrame
         );
   
   U_FrmDlyFifo : entity surf.SynchronizerFifo
      generic map (
         TPD_G         => TPD_G,
         MEMORY_TYPE_G => "distributed",
         DATA_WIDTH_G  => 9,
         ADDR_WIDTH_G  => 4,
         INIT_G        => "0")
      port map (
         rst    => axilRst,
         wr_clk => axilClk,
         wr_en  => axilR.frameDelaySet,
         din    => axilR.delay,
         rd_clk => adcBitClkDiv4,
         rd_en  => '1',
         valid  => frameDelaySet,
         dout   => frameDelay);
   
   --------------------------------
   -- Data Input, 8 channels
   --------------------------------
   GenData : for i in NUM_CHANNELS_G-1 downto 0 generate
      signal dataDelaySet : slv(NUM_CHANNELS_G-1 downto 0);
      signal dataDelay    : slv9Array(NUM_CHANNELS_G-1 downto 0);
   begin

      U_DATA_DESERIALIZER : entity surf.Ad9249Deserializer
         generic map (
            TPD_G             => TPD_G,
            IODELAY_GROUP_G   => "DEFAULT_GROUP",
            IDELAY_CASCADE_G  => D_DELAY_CASCADE_G,
            IDELAYCTRL_FREQ_G => 350.0,
            DEFAULT_DELAY_G   => (others => '0'),
            ADC_INVERT_CH_G   => ADC_INVERT_CH_G(i),
            BIT_REV_G         => '1')
         port map (
            dClk          => adcBitClk,      -- Data clock
            dRst          => adcBitRst,
            dClkDiv4      => adcBitClkDiv4,
            dRstDiv4      => adcBitRstDiv4,
            dClkDiv7      => adcBitClkDiv7,
            dRstDiv7      => adcBitRstDiv7,
            sDataP        => adcSerial.chP(i),  -- Frame clock
            sDataN        => adcSerial.chN(i),
            loadDelay     => dataDelaySet(i),
            delay         => dataDelay(i),
            delayValueOut => curDelayData(i),
            bitSlip       => slipSync,
            gearboxOffset => adcR.gearboxOffset,
            adcData       => adcData(i)
            );
      
      
      U_DataDlyFifo : entity surf.SynchronizerFifo
         generic map (
            TPD_G         => TPD_G,
            MEMORY_TYPE_G => "distributed",
            DATA_WIDTH_G  => 9,
            ADDR_WIDTH_G  => 4,
            INIT_G        => "0")
         port map (
            rst    => axilRst,
            wr_clk => axilClk,
            wr_en  => axilR.dataDelaySet(i),
            din    => axilR.delay,
            rd_clk => adcBitClkDiv4,
            rd_en  => '1',
            valid  => dataDelaySet(i),
            dout   => dataDelay(i));
      
   end generate;

   -------------------------------------------------------------------------------------------------
   -- ADC Bit Clocked Logic
   -------------------------------------------------------------------------------------------------
   adcComb : process (adcData, adcFrame, adcR, invertSync) is
      variable v : AdcRegType;
   begin
      v := adcR;

      ----------------------------------------------------------------------------------------------
      -- Slip bits until correct alignment seen
      ----------------------------------------------------------------------------------------------
      if (adcR.count = 0) then
         if (adcFrame = FRAME_PATTERN_C) then
            v.locked := '1';
         else
            v.locked := '0';
            v.slip   := adcR.slip + 1;
            v.count  := adcR.count + 1;
            -- increments the gearbox
            if adcR.slip = 0 then
               v.gearBoxOffset := adcR.gearBoxOffset + 1;
            end if;
         end if;
      end if;

      if (adcR.count /= 0) then
         v.count := adcR.count + 1;
      end if;



      ----------------------------------------------------------------------------------------------
      -- Look for Frame rising edges and write data to fifos
      ----------------------------------------------------------------------------------------------
      for i in NUM_CHANNELS_G-1 downto 0 loop
         if (adcR.locked = '1' and adcFrame = FRAME_PATTERN_C) then
            -- Locked, output adc data
            if invertSync = '1' then
               v.fifoWrData(i) := "00" & (x"3FFF" - adcData(i));
            else
               v.fifoWrData(i) := "00" & adcData(i);
            end if;
         else
            -- Not locked
            v.fifoWrData(i) := (others => '1');  --"10" & "00000000000000";
         end if;
      end loop;

      adcRin <= v;

   end process adcComb;

   adcSeq : process (adcBitClkDiv7) is
   begin
      if (rising_edge(adcBitClkDiv7)) then
         if (adcBitRstDiv7 = '1' or adcClkRstSync = '1') then
            adcR <= ADC_REG_INIT_C after TPD_G;
         else
            adcR <= adcRin after TPD_G;
         end if;
      end if;
   end process adcSeq;
   
   
   SynchronizerVec_2 : entity surf.SynchronizerVector
   generic map (
      TPD_G    => TPD_G,
      WIDTH_G  => 4
   )
   port map (
      clk      => adcBitClkDiv4,
      rst      => adcBitRstDiv4,
      dataIn   => adcR.slip,
      dataOut  => slipSync
   ); 
   
   RstSync_1 : entity surf.RstSync
   generic map (
      TPD_G    => TPD_G
   )
   port map (
      clk      => adcBitClkDiv7,
      asyncRst => adcClkRst,
      syncRst  => adcClkRstSync
   );

   -- Flatten fifoWrData onto fifoDataIn for FIFO
   -- Regroup fifoDataOut by channel into fifoDataTmp
   -- Format fifoDataTmp into AxiStream channels
   glue : for i in NUM_CHANNELS_G-1 downto 0 generate
      fifoDataIn(i*16+15 downto i*16)  <= adcR.fifoWrData(i);
      fifoDataTmp(i)                   <= fifoDataOut(i*16+15 downto i*16);
      debugDataTmp(i)                  <= debugDataOut(i*16+15 downto i*16);
      adcStreams(i).tdata(15 downto 0) <= fifoDataTmp(i);
      adcStreams(i).tDest              <= toSlv(i, 8);
      adcStreams(i).tValid             <= fifoDataValid;
   end generate;

   -- Single fifo to synchronize adc data to the Stream clock
   U_DataFifo : entity surf.SynchronizerFifo
      generic map (
         TPD_G         => TPD_G,
         MEMORY_TYPE_G => "distributed",
         DATA_WIDTH_G  => NUM_CHANNELS_G*16,
         ADDR_WIDTH_G  => 4,
         INIT_G        => "0")
      port map (
         rst    => adcBitRstDiv7,
         wr_clk => adcBitClkDiv7,
         wr_en  => '1',                 --Always write data
         din    => fifoDataIn,
         rd_clk => adcStreamClk,
         rd_en  => fifoDataValid,
         valid  => fifoDataValid,
         dout   => fifoDataOut);

   U_DataFifoDebug : entity surf.SynchronizerFifo
      generic map (
         TPD_G         => TPD_G,
         MEMORY_TYPE_G => "distributed",
         DATA_WIDTH_G  => NUM_CHANNELS_G*16,
         ADDR_WIDTH_G  => 4,
         INIT_G        => "0")
      port map (
         rst    => adcBitRstDiv7,
         wr_clk => adcBitClkDiv7,
         wr_en  => '1',                 --Always write data
         din    => fifoDataIn,
         rd_clk => axilClk,
         rd_en  => debugDataValid,
         valid  => debugDataValid,
         dout   => debugDataOut);


end rtl;

