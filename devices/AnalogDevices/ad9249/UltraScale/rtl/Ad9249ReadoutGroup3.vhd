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

library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;
use surf.AxiStreamPkg.all;
use surf.Ad9249Pkg.all;

library unisim;
use unisim.vcomponents.all;

entity Ad9249ReadoutGroup3 is
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
end Ad9249ReadoutGroup3;

architecture rtl of Ad9249ReadoutGroup3 is

   constant FRAME_PATTERN_C : slv(13 downto 0) := "11111110000000";


   -------------------------------------------------------------------------------------------------
   -- Registers
   -------------------------------------------------------------------------------------------------
   type RegType is record
      slip             : sl;
      count            : slv(5 downto 0);
      locked           : sl;
      lostLockCount    : slv(15 downto 0);
      lostLockCountRst : sl;
      relock          : sl;
      axilWriteSlave   : AxiLiteWriteSlaveType;
      axilReadSlave    : AxiLiteReadSlaveType;
      frameDelay       : slv(8 downto 0);
      frameDelaySet    : sl;
      dataDelay        : slv9Array(7 downto 0);
      dataDelaySet     : slv(7 downto 0);
      freezeDebug      : sl;
      readoutDebug0    : slv14Array(7 downto 0);
      readoutDebug1    : slv14Array(7 downto 0);
      invert           : sl;
   end record;

   constant REG_INIT_C : RegType := (
      slip             => '0',
      count            => (others => '0'),
      locked           => '0',
      lostLockCount    => (others => '0'),
      lostLockCountRst => '0',
      relock          => '0',
      axilWriteSlave   => AXI_LITE_WRITE_SLAVE_INIT_C,
      axilReadSlave    => AXI_LITE_READ_SLAVE_INIT_C,
      frameDelay       => (others => '0'),
      frameDelaySet    => '0',
      dataDelay        => (others => (others => '0')),
      dataDelaySet     => (others => '0'),
      freezeDebug      => '0',
      readoutDebug0    => (others => (others => '0')),
      readoutDebug1    => (others => (others => '0')),
      invert           => '0');

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   -- Local Signals
   signal adcBitClk     : sl;
   signal adcBitRst     : sl;
   signal adcBitClkDiv4 : sl;
   signal adcBitRstDiv4 : sl;

   signal adcFrame      : slv(13 downto 0);
   signal adcFrameValid : sl;
   signal adcData       : slv14Array(NUM_CHANNELS_G-1 downto 0);
   signal adcDataValid  : slv(NUM_CHANNELS_G-1 downto 0);

   signal syncAxilReadMaster  : AxiLiteReadMasterType;
   signal syncAxilReadSlave   : AxiLiteReadSlaveType;
   signal syncAxilWriteMaster : AxiLiteWriteMasterType;
   signal syncAxilWriteSlave  : AxiLiteWriteSlaveType;

   signal fifoWrData    : slv16Array(NUM_CHANNELS_G-1 downto 0);
   signal fifoDataValid : sl;
   signal fifoDataOut   : slv(NUM_CHANNELS_G*16-1 downto 0);
   signal fifoDataIn    : slv(NUM_CHANNELS_G*16-1 downto 0);
   signal fifoDataTmp   : slv16Array(NUM_CHANNELS_G-1 downto 0);


begin


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
         IDELAYCTRL_FREQ_G => 350.0,
         ADC_INVERT_CH_G   => '0',
         BIT_REV_G         => '1')
      port map (
         dClk          => adcBitClk,
         dRst          => adcBitRst,
         dClkDiv4      => adcBitClkDiv4,
         dRstDiv4      => r.relock,
         sDataP        => adcSerial.fClkP,
         sDataN        => adcSerial.fClkN,
         loadDelay     => r.frameDelaySet,
         delay         => r.frameDelay,
         bitSlip       => r.slip,
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
            IDELAYCTRL_FREQ_G => 350.0,
            ADC_INVERT_CH_G   => ADC_INVERT_CH_G(ch),
            BIT_REV_G         => '1')
         port map (
            dClk          => adcBitClk,
            dRst          => adcBitRst,
            dClkDiv4      => adcBitClkDiv4,
            dRstDiv4      => r.relock,
            sDataP        => adcSerial.chP(ch),
            sDataN        => adcSerial.chN(ch),
            loadDelay     => r.dataDelaySet(ch),
            delay         => r.dataDelay(ch),
            bitSlip       => r.slip,
            delayValueOut => open,
            adcData       => adcData(ch),
            adcValid      => adcDataValid(ch));
   end generate;


   -------------------------------------------------------------------------------------------------
   -- Synchronize AXI Lite bus to ADC deserializer word clock
   -------------------------------------------------------------------------------------------------
   U_AxiLiteAsync_1 : entity surf.AxiLiteAsync
      generic map (
         TPD_G => TPD_G)
      port map (
         sAxiClk         => axilClk,              -- [in]
         sAxiClkRst      => axilRst,              -- [in]
         sAxiReadMaster  => axilReadMaster,       -- [in]
         sAxiReadSlave   => axilReadSlave,        -- [out]
         sAxiWriteMaster => axilWriteMaster,      -- [in]
         sAxiWriteSlave  => axilWriteSlave,       -- [out]
         mAxiClk         => adcBitClkDiv4,        -- [in]
         mAxiClkRst      => adcBitRstDiv4,        -- [in]
         mAxiReadMaster  => syncAxilReadMaster,   -- [out]
         mAxiReadSlave   => syncAxilReadSlave,    -- [in]
         mAxiWriteMaster => syncAxilWriteMaster,  -- [out]
         mAxiWriteSlave  => syncAxilWriteSlave);  -- [in]   

-------------------------------------------------------------------------------------------------
-- AXIL Interface
-------------------------------------------------------------------------------------------------
   comb : process (adcBitRstDiv4, adcData, adcFrame, adcFrameValid, r, syncAxilReadMaster,
                   syncAxilWriteMaster) is
      variable v      : RegType;
      variable axilEp : AxiLiteEndpointType;
   begin
      v := r;

      ----------------------------------------------------------------------------------------------
      -- Slip all deserailizers until correct frame pattern seen
      ----------------------------------------------------------------------------------------------
      v.slip := '0';
      if (r.count = 0) then
         if adcFrameValid = '1' then
            if (adcFrame = FRAME_PATTERN_C) then
               v.locked := '1';
            else
               v.locked := '0';
               v.slip   := '1';
               v.count  := r.count + 1;
            end if;
         end if;
      end if;

      if (r.count /= 0) then
         v.count := r.count + 1;
      end if;

      if (r.locked = '1' and adcFrameValid = '1' and adcFrame /= FRAME_PATTERN_C) then
         v.locked        := '0';
         v.lostLockCount := r.lostLockCount + 1;
      end if;

      if (r.relock = '1') then
         v.locked        := '0';
         v.lostLockCount := r.lostLockCount + 1;
      end if;


      -- Store last two samples read from ADC
      if (r.locked = '1' and adcFrameValid = '1' and r.freezeDebug = '0') then
         for ch in NUM_CHANNELS_G-1 downto 0 loop
            v.readoutDebug0(ch) := adcData(ch);
            v.readoutDebug1(ch) := r.readoutDebug0(ch);
         end loop;
      end if;

      v.frameDelaySet    := '0';
      v.dataDelaySet     := (others => '0');
      v.lostLockCountRst := '0';
      v.relock           := '0';

      axiSlaveWaitTxn(axilEp, syncAxilWriteMaster, syncAxilReadMaster, v.axilWriteSlave, v.axilReadSlave);

      -- Write delay values to IDELAY primatives
      -- Overriding gearbox aligner
      -- All writes go to same r.delay register,
      for i in 0 to NUM_CHANNELS_G-1 loop
         axiSlaveRegister(axilEp, X"00"+toSlv(i*4, 8), 0, v.dataDelay(i));
         axiSlaveRegister(axilEp, X"00"+toSlv(i*4, 8), 9, v.dataDelaySet(i), '1');
      end loop;
      axiSlaveRegister(axilEp, X"20", 0, v.frameDelay);
      axiSlaveRegisterR(axilEp, X"20", 9, v.frameDelaySet);

      -- Debug output to see how many times the shift has needed a relock
      axiSlaveRegisterR(axilEp, X"30", 0, r.lostLockCount);
      axiSlaveRegisterR(axilEp, X"30", 16, r.locked);

      axiSlaveRegisterR(axilEp, X"34", 0, adcFrame);

      axiSlaveRegister(axilEp, X"38", 0, v.lostLockCountRst);

      axiSlaveRegister(axilEp, X"40", 0, v.invert);

      axiSlaveRegister(axilEp, X"44", 0, v.relock);

      -- Debug registers. Output the last 2 words received
      for ch in 0 to 7 loop
         axiSlaveRegisterR(axilEp, X"80"+toSlv((ch*4), 8), 0, r.readoutDebug0(ch));
         axiSlaveRegisterR(axilEp, X"80"+toSlv((ch*4), 8), 16, r.readoutDebug1(ch));
      end loop;

      axiSlaveRegister(axilEp, X"A0", 0, v.freezeDebug);

      axiSlaveDefault(axilEp, v.axilWriteSlave, v.axilReadSlave, AXI_RESP_DECERR_C);

      if (adcBitRstDiv4 = '1') then
         v               := REG_INIT_C;
         v.lostLockCount := r.lostLockCount;
      end if;

      if (r.lostLockCountRst = '1') then
         v.lostLockCount := (others => '0');
      end if;

      rin <= v;

      syncAxilWriteSlave <= r.axilWriteSlave;
      syncAxilReadSlave  <= r.axilReadSlave;

   end process;

   seq : process (adcBitClkDiv4) is
   begin
      if (rising_edge(adcBitClkDiv4)) then
         r <= rin after TPD_G;
      end if;
   end process seq;



   GLUE_COMB : process (adcData, r) is
   begin
      for ch in NUM_CHANNELS_G-1 downto 0 loop
         if (r.locked = '1') then
            -- Locked, output adc data
            if r.invert = '1' then
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



end rtl;

