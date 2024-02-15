-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
-- ADC Readout Controller
-- Receives ADC Data from an AD9592 chip.
-- Designed specifically for Xilinx 7 series FPGAs
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

entity Ad9249ReadoutGroup2 is
   generic (
      TPD_G           : time            := 1 ns;
      SIM_DEVICE_G    : string          := "ULTRASCALE";
      NUM_CHANNELS_G  : natural         := 8;
      SIMULATION_G    : boolean         := false;
      DEFAULT_DELAY_G : slv(8 downto 0) := "000000000";
      ADC_INVERT_CH_G : slv(7 downto 0) := "00000000");
   port (
      -- AXI-Lite clock
      axilClk : in sl;
      axilRst : in sl;

      -- Axi Interface
      axilWriteMaster : in  AxiLiteWriteMasterType;
      axilWriteSlave  : out AxiLiteWriteSlaveType := AXI_LITE_WRITE_SLAVE_EMPTY_DECERR_C;
      axilReadMaster  : in  AxiLiteReadMasterType;
      axilReadSlave   : out AxiLiteReadSlaveType  := AXI_LITE_READ_SLAVE_EMPTY_DECERR_C;

      -- Asynchronous reset for adc deserializer
      adcClkRst : in sl;

      -- DDR Serial Data from ADC
      adcSerial : in Ad9249SerialGroupType;

      -- Deserialized ADC Data
      adcStreamClk : in  sl;
      adcStreams   : out AxiStreamMasterArray(NUM_CHANNELS_G-1 downto 0) := (others => axiStreamMasterInit(AD9249_AXIS_CFG_G)));

end Ad9249ReadoutGroup2;

-- Define architecture
architecture rtl of Ad9249ReadoutGroup2 is


   -------------------------------------------------------------------------------------------------
   -- AXIL Registers
   -------------------------------------------------------------------------------------------------
   type AxilRegType is record
      axilWriteSlave : AxiLiteWriteSlaveType;
      axilReadSlave  : AxiLiteReadSlaveType;
      delay          : slv(8 downto 0);
      delaySet       : sl;
      freezeDebug    : sl;
      readoutDebug0  : slv16Array(7 downto 0);
      readoutDebug1  : slv16Array(7 downto 0);
      lockedCountRst : sl;
      invert         : sl;
      realign        : sl;
      minEyeWidth    : slv(7 downto 0);
   end record;

   constant AXIL_REG_INIT_C : AxilRegType := (
      axilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C,
      axilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
      delay          => DEFAULT_DELAY_G,
      delaySet       => '0',
      freezeDebug    => '0',
      readoutDebug0  => (others => (others => '0')),
      readoutDebug1  => (others => (others => '0')),
      lockedCountRst => '0',
      invert         => '0',
      realign        => '1',
      minEyeWidth    => X"50");

   signal lockedSync      : sl;
   signal lockedFallCount : slv(15 downto 0);

   signal axilR   : AxilRegType := AXIL_REG_INIT_C;
   signal axilRin : AxilRegType;

   -------------------------------------------------------------------------------------------------
   -- ADC Readout Clocked Registers
   -------------------------------------------------------------------------------------------------
   type AdcRegType is record
      errorDet : sl;
   end record;

   constant ADC_REG_INIT_C : AdcRegType := (
      errorDet => '1');


   signal adcR   : AdcRegType := ADC_REG_INIT_C;
   signal adcRin : AdcRegType;


   -- Local Signals
   signal adcBitClk     : sl;
   signal adcBitRst     : sl;
   signal adcBitClkDiv4 : sl;
   signal adcBitRstDiv4 : sl;

   signal adcFrame          : slv(13 downto 0);
   signal adcFrameValid     : sl;
   signal adcFrameSync      : slv(13 downto 0);
   signal adcFrameSyncValid : sl;
   signal adcData           : slv14Array(NUM_CHANNELS_G-1 downto 0);
   signal adcDataValid      : slv(NUM_CHANNELS_G-1 downto 0);

   signal fifoWrData    : slv16Array(NUM_CHANNELS_G-1 downto 0);
   signal fifoDataValid : sl;
   signal fifoDataOut   : slv(NUM_CHANNELS_G*16-1 downto 0);
   signal fifoDataIn    : slv(NUM_CHANNELS_G*16-1 downto 0);
   signal fifoDataTmp   : slv16Array(NUM_CHANNELS_G-1 downto 0);

   signal debugDataValid : sl;
   signal debugDataOut   : slv(NUM_CHANNELS_G*16-1 downto 0);
   signal debugDataTmp   : slv16Array(7 downto 0);

   signal invertSync      : sl;
   signal bitSlip         : sl;
   signal dlyLoad         : sl;
   signal dlyCfg          : slv(8 downto 0);
   signal enUsrDlyCfg     : sl;
   signal usrDlyCfg       : slv(8 downto 0)  := (others => '0');
   signal minEyeWidthSync : slv(7 downto 0);
   signal lockingCntCfg   : slv(23 downto 0) := ite(SIMULATION_G, X"000008", X"00FFFF");
   signal locked          : sl;
   signal realignSync     : sl;
   signal curDelay        : slv(8 downto 0);
   signal errorDetCount   : slv(15 downto 0);
   signal errorDet        : sl;


begin
   -------------------------------------------------------------------------------------------------
   -- Synchronize adcR.locked across to axil clock domain and count falling edges on it
   -------------------------------------------------------------------------------------------------
   Synchronizer_locked : entity surf.Synchronizer
      generic map (
         TPD_G    => TPD_G,
         STAGES_G => 2)
      port map (
         clk     => axilClk,
         rst     => axilRst,
         dataIn  => locked,
         dataOut => lockedSync);

   SynchronizerOneShotCnt_locked_fall : entity surf.SynchronizerOneShotCnt
      generic map (
         TPD_G          => TPD_G,
         IN_POLARITY_G  => '0',
         OUT_POLARITY_G => '0',
         CNT_RST_EDGE_G => true,
         CNT_WIDTH_G    => 16)
      port map (
         dataIn     => locked,
         rollOverEn => '0',
         cntRst     => axilR.lockedCountRst,
         dataOut    => open,
         cntOut     => lockedFallCount,
         wrClk      => adcBitClkDiv4,
         wrRst      => '0',
         rdClk      => axilClk,
         rdRst      => axilRst);

   SynchronizerOneShotCnt_2 : entity surf.SynchronizerOneShotCnt
      generic map (
         TPD_G          => TPD_G,
         IN_POLARITY_G  => '1',
         OUT_POLARITY_G => '1',
         CNT_RST_EDGE_G => false,
         CNT_WIDTH_G    => 16)
      port map (
         dataIn     => errorDet,
         rollOverEn => '0',
         cntRst     => axilR.lockedCountRst,
         dataOut    => open,
         cntOut     => errorDetCount,
         wrClk      => adcBitClkDiv4,
         wrRst      => '0',
         rdClk      => axilClk,
         rdRst      => axilRst);


   SynchronizerVector_FRAME : entity surf.SynchronizerFifo
      generic map (
         TPD_G         => TPD_G,
         MEMORY_TYPE_G => "distributed",
         DATA_WIDTH_G  => 14,
         ADDR_WIDTH_G  => 4)
      port map (
         rst    => axilRst,
         wr_clk => adcBitClkDiv4,
         wr_en  => adcFrameValid,
         din    => adcFrame,
         rd_clk => axilClk,
         rd_en  => adcFrameSyncValid,
         valid  => adcFrameSyncValid,
         dout   => adcFrameSync);

   U_SynchronizerVector_CUR_DELAY : entity surf.SynchronizerVector
      generic map (
         TPD_G    => TPD_G,
         STAGES_G => 2,
         WIDTH_G  => 9)
      port map (
         clk     => axilClk,            -- [in]
         rst     => axilRst,            -- [in]
         dataIn  => dlyCfg,             -- [in]
         dataOut => curDelay);          -- [out]


   -- AXIL to ADC clock
   Synchronizer_INVERT : entity surf.Synchronizer
      generic map (
         TPD_G    => TPD_G,
         STAGES_G => 2)
      port map (
         clk     => adcBitClkDiv4,
         dataIn  => axilR.invert,
         dataOut => invertSync);

   Synchronizer_REALIGN : entity surf.RstSync
      generic map (
         TPD_G           => TPD_G,
         RELEASE_DELAY_G => 3)
      port map (
         clk      => adcBitClkDiv4,
         asyncRst => axilR.realign,
         syncRst  => realignSync);

   Synchronizer_USR_DELAY_SET : entity surf.Synchronizer
      generic map (
         TPD_G    => TPD_G,
         STAGES_G => 3)
      port map (
         clk     => adcBitClkDiv4,
         rst     => adcBitRstDiv4,
         dataIn  => axilR.delaySet,
         dataOut => enUsrDlyCfg);

   U_SynchronizerVector_USR_DELAY : entity surf.SynchronizerVector
      generic map (
         TPD_G    => TPD_G,
         STAGES_G => 2,
         WIDTH_G  => 9)
      port map (
         clk     => adcBitClkDiv4,      -- [in]
         rst     => adcBitRstDiv4,      -- [in]
         dataIn  => axilR.delay,        -- [in]
         dataOut => usrDlyCfg);         -- [out]

   U_SynchronizerVector_EYE_WIDTH : entity surf.SynchronizerVector
      generic map (
         TPD_G    => TPD_G,
         STAGES_G => 2,
         WIDTH_G  => 8)
      port map (
         clk     => adcBitClkDiv4,      -- [in]
         rst     => adcBitRstDiv4,      -- [in]
         dataIn  => axilR.minEyeWidth,  -- [in]
         dataOut => minEyeWidthSync);   -- [out]



-------------------------------------------------------------------------------------------------
-- AXIL Interface
-------------------------------------------------------------------------------------------------
   axilComb : process (adcFrameSync, axilR, axilReadMaster, axilRst, axilWriteMaster, curDelay,
                       debugDataTmp, debugDataValid, errorDetCount, lockedFallCount, lockedSync) is
      variable v      : AxilRegType;
      variable axilEp : AxiLiteEndpointType;
   begin
      v := axilR;

      v.delaySet := '0';

      -- Store last two samples read from ADC
      if (debugDataValid = '1' and axilR.freezeDebug = '0') then
         v.readoutDebug0 := debugDataTmp;
         v.readoutDebug1 := axilR.readoutDebug0;
      end if;

      axiSlaveWaitTxn(axilEp, axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave);

      -- Write delay values to IDELAY primatives
      -- Overriding gearbox aligner
      -- All writes go to same r.delay register,
      axiSlaveRegister(axilEp, X"00", 0, v.delay);
      axiWrDetect(axilEp, X"00", v.delaySet);
      axiSlaveRegisterR(axilEp, X"00", 0, curDelay);

      v.realign := '0';
      axiSlaveRegister(axilEp, X"20", 0, v.realign);
      axiSlaveRegisterR(axilEp, X"30", 0, errorDetCount);

      -- Debug output to see how many times the shift has needed a relock
      axiSlaveRegisterR(axilEp, X"50", 0, lockedFallCount);
      axiSlaveRegisterR(axilEp, X"50", 16, lockedSync);

      axiSlaveRegisterR(axilEp, X"58", 0, adcFrameSync);

      axiSlaveRegister(axilEp, X"5C", 0, v.lockedCountRst);

      axiSlaveRegister(axilEp, X"60", 0, v.invert);

      -- Debug registers. Output the last 2 words received
      for ch in 0 to 7 loop
         axiSlaveRegisterR(axilEp, X"80"+toSlv((ch*4), 8), 0, axilR.readoutDebug0(ch));
         axiSlaveRegisterR(axilEp, X"80"+toSlv((ch*4), 8), 16, axilR.readoutDebug1(ch));
      end loop;

      axiSlaveRegister(axilEp, X"A0", 0, v.freezeDebug);

      axiSlaveDefault(axilEp, v.axilWriteSlave, v.axilReadSlave, AXI_RESP_DECERR_C);

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


-------------------------------------------------------------------------------------------------
-- Create Clocks
-------------------------------------------------------------------------------------------------

   AdcClk_I_Ibufds : IBUFGDS
      port map (
         I  => adcSerial.dClkP,
         IB => adcSerial.dClkN,
         O  => adcBitClk);


   ADC_BITCLK_RST_SYNC : entity surf.RstSync
      generic map (
         TPD_G           => TPD_G,
         RELEASE_DELAY_G => 5)
      port map (
         clk      => adcBitClk,
         asyncRst => adcClkRst,
         syncRst  => adcBitRst);


   U_AdcBitClkRD4 : BUFGCE_DIV
      generic map (
         BUFGCE_DIVIDE   => 4,          -- 1-8
         -- Programmable Inversion Attributes: Specifies built-in programmable inversion on specific pins
         IS_CE_INVERTED  => '0',        -- Optional inversion for CE
         IS_CLR_INVERTED => '0',        -- Optional inversion for CLR
         IS_I_INVERTED   => '0')        -- Optional inversion for I
      port map (
         I   => adcBitClk,
         O   => adcBitClkDiv4,
         CE  => '1',
         CLR => '0');


   ADC_BITCLK_DIV4_RST_SYNC : entity surf.RstSync
      generic map (
         TPD_G           => TPD_G,
         RELEASE_DELAY_G => 5)
      port map (
         clk      => adcBitClkDiv4,
         asyncRst => adcClkRst,
         syncRst  => adcBitRstDiv4);


-------------------------------------------------------------------------------------------------
-- Deserializers
-------------------------------------------------------------------------------------------------

   U_FRAME_DESERIALIZER : entity surf.Ad9249Deserializer
      generic map (
         TPD_G             => TPD_G,
         SIM_DEVICE_G      => SIM_DEVICE_G,
         DEFAULT_DELAY_G   => DEFAULT_DELAY_G,
         IDELAYCTRL_FREQ_G => 350.0,    -- Check this
         ADC_INVERT_CH_G   => '0',
         BIT_REV_G         => '1')
      port map (
         dClk          => adcBitClk,
         dRst          => adcBitRst,
         dClkDiv4      => adcBitClkDiv4,
         dRstDiv4      => realignSync,
         sDataP        => adcSerial.fClkP,
         sDataN        => adcSerial.fClkN,
         loadDelay     => dlyLoad,
         delay         => dlyCfg,
         bitSlip       => bitSlip,
         delayValueOut => open,
         adcData       => adcFrame,
         adcValid      => adcFrameValid);


--------------------------------
-- Data Input, 8 channels
--------------------------------
   GenData : for ch in NUM_CHANNELS_G-1 downto 0 generate
      U_DATA_DESERIALIZER : entity surf.Ad9249Deserializer
         generic map (
            TPD_G             => TPD_G,
            SIM_DEVICE_G      => SIM_DEVICE_G,
            DEFAULT_DELAY_G   => DEFAULT_DELAY_G,
            IDELAYCTRL_FREQ_G => 350.0,  -- Check this
            ADC_INVERT_CH_G   => ADC_INVERT_CH_G(ch),
            BIT_REV_G         => '1')    -- Should maybe be '1'
         port map (
            dClk          => adcBitClk,
            dRst          => adcBitRst,
            dClkDiv4      => adcBitClkDiv4,
            dRstDiv4      => realignSync,
            sDataP        => adcSerial.chP(ch),
            sDataN        => adcSerial.chN(ch),
            loadDelay     => dlyLoad,
            delay         => dlyCfg,
            bitSlip       => bitSlip,
            delayValueOut => open,
            adcData       => adcData(ch),
            adcValid      => adcDataValid(ch));
   end generate;


   ----------------------------------------------------------------------------------------------
   -- Aligner
   ----------------------------------------------------------------------------------------------
   U_SelectIoRxGearboxAligner_1 : entity surf.SelectIoRxGearboxAligner
      generic map (
         TPD_G           => TPD_G,
         SIMULATION_G    => SIMULATION_G,
         CODE_TYPE_G     => "LINE_CODE",
         DLY_STEP_SIZE_G => ite(SIMULATION_G, 16, 1))
      port map (
         clk             => adcBitClkDiv4,    -- [in]
         rst             => adcBitRstDiv4,    -- [in]
         lineCodeValid   => '1',              -- [in]
         lineCodeErr     => adcR.errorDet,    -- [in]
         lineCodeDispErr => realignSync,      -- [in]
         linkOutOfSync   => '0',              -- [in]
         rxHeaderValid   => '0',              -- [in]
         rxHeader        => (others => '0'),  -- [in]
         bitSlip         => bitSlip,          -- [out]
         dlyLoad         => dlyLoad,          -- [out]
         dlyCfg          => dlyCfg,           -- [out]
         enUsrDlyCfg     => enUsrDlyCfg,      -- [in]
         usrDlyCfg       => usrDlyCfg,        -- [in]
         bypFirstBerDet  => '1',              -- [in]
         minEyeWidth     => minEyeWidthSync,  -- [in]
         lockingCntCfg   => lockingCntCfg,    -- [in]
         errorDet        => errorDet,         -- [out]
         locked          => locked);          -- [out]


   -------------------------------------------------------------------------------------------------
   -- ADC Bit Clocked Logic
   -------------------------------------------------------------------------------------------------
   adcComb : process (adcFrame, adcFrameValid, adcR) is
      variable v : AdcRegType;
   begin
      v := adcR;

      if (adcFrameValid = '1') then
         v.errorDet := toSl(adcFrame /= "11111110000000");
      end if;

      adcRin <= v;

   end process adcComb;

   adcSeq : process (adcBitClkDiv4, adcBitRstDiv4) is
   begin
      if (adcBitRstDiv4 = '1') then
         adcR <= ADC_REG_INIT_C after TPD_G;
      elsif (rising_edge(adcBitClkDiv4)) then
         adcR <= adcRin after TPD_G;
      end if;
   end process adcSeq;


   GLUE_COMB : process (adcData, invertSync, locked) is
   begin
      for ch in NUM_CHANNELS_G-1 downto 0 loop
         if (locked = '1') then
            -- Locked, output adc data
            if invertSync = '1' then
               -- Invert all bits but keep 2 LSBs clear
               fifoWrData(ch) <= "00" & ("11111111111111" - adcData(ch));
            else
               fifoWrData(ch) <= "00" & adcData(ch);
            end if;
         else
            -- Not locked
            fifoWrData(ch) <= (others => '1');  --"10" & "00000000000000";
         end if;
      end loop;
   end process GLUE_COMB;


-- Flatten fifoWrData onto fifoDataIn for FIFO
-- Regroup fifoDataOut by channel into fifoDataTmp
-- Format fifoDataTmp into AxiStream channels
   glue : for i in NUM_CHANNELS_G-1 downto 0 generate
      fifoDataIn(i*16+15 downto i*16)  <= fifoWrData(i);
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
         rst    => adcBitRstDiv4,
         wr_clk => adcBitClkDiv4,
         wr_en  => adcFrameValid,       --Always write data
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
         rst    => adcBitRstDiv4,
         wr_clk => adcBitClkDiv4,
         wr_en  => adcFrameValid,       --Always write data
         din    => fifoDataIn,
         rd_clk => axilClk,
         rd_en  => debugDataValid,
         valid  => debugDataValid,
         dout   => debugDataOut);


end rtl;

