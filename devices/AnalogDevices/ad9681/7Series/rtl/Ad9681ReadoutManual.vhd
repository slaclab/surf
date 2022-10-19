-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
-- ADC ReadoutManual Controller
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
use surf.Ad9681Pkg.all;

entity Ad9681ReadoutManual is
   generic (
      TPD_G : time := 1 ns;

      IODELAY_GROUP_G   : string                    := "DEFAULT_GROUP";
      IDELAYCTRL_FREQ_G : real                      := 200.0;
      DEFAULT_DELAY_G   : integer range 0 to 2**5-1 := 0;
      INVERT_G          : boolean                   := false;
      NEGATE_G          : boolean                   := false);
   port (
      -- Master system clock, 125Mhz
      axilClk : in sl;
      axilRst : in sl;

      -- Axi Interface
      axilWriteMaster : in  AxiLiteWriteMasterType;
      axilWriteSlave  : out AxiLiteWriteSlaveType := AXI_LITE_WRITE_SLAVE_EMPTY_DECERR_C;
      axilReadMaster  : in  AxiLiteReadMasterType;
      axilReadSlave   : out AxiLiteReadSlaveType  := AXI_LITE_READ_SLAVE_EMPTY_DECERR_C;

      -- Reset for adc deserializer
      adcClkRst : in sl;

      -- Serial Data from ADC
      adcSerial : in Ad9681SerialType;

      -- Deserialized ADC Data
      adcStreamClk : in  sl;
      adcStreams   : out AxiStreamMasterArray(7 downto 0) := (others => axiStreamMasterInit(AD9681_AXIS_CFG_G)));

end Ad9681ReadoutManual;

-- Define architecture
architecture rtl of Ad9681ReadoutManual is

   constant NUM_CHANNELS_C : natural := 8;


   type AdcDataArray is array (natural range <>) of slv8Array(7 downto 0);
   type DelayDataArray is array (natural range <>) of slv5Array(7 downto 0);

   -------------------------------------------------------------------------------------------------
   -- AXIL Registers
   -------------------------------------------------------------------------------------------------
   type AxilRegType is record
      axilWriteSlave : AxiLiteWriteSlaveType;
      axilReadSlave  : AxiLiteReadSlaveType;
      delay          : slv(4 downto 0);
      dataDelaySet   : slv8Array(1 downto 0);
      frameDelaySet  : slv(1 downto 0);
      freezeDebug    : sl;
      readoutDebug0  : slv16Array(NUM_CHANNELS_C-1 downto 0);
      readoutDebug1  : slv16Array(NUM_CHANNELS_C-1 downto 0);
      lockedCountRst : sl;
      invert         : sl;
      negate         : sl;
      relock         : slv(1 downto 0);
      curDelayFrame  : slv5Array(1 downto 0);
      curDelayData   : DelayDataArray(1 downto 0);
   end record;

   constant AXIL_REG_INIT_C : AxilRegType := (
      axilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C,
      axilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
      delay          => toSlv(DEFAULT_DELAY_G, 5),
      dataDelaySet   => (others => (others => '1')),
      frameDelaySet  => "11",
      freezeDebug    => '0',
      readoutDebug0  => (others => (others => '0')),
      readoutDebug1  => (others => (others => '0')),
      lockedCountRst => '0',
      invert         => toSl(INVERT_G),
      negate         => toSl(NEGATE_G),
      relock         => "00",
      curDelayFrame  => (others => (others => '0')),
      curDelayData   => (others => (others => (others => '0'))));

   signal lockedSync      : slv(1 downto 0);
   signal lockedFallCount : slv16Array(1 downto 0);

   signal axilR   : AxilRegType := AXIL_REG_INIT_C;
   signal axilRin : AxilRegType;

   -------------------------------------------------------------------------------------------------
   -- ADC Readout Clocked Registers
   -------------------------------------------------------------------------------------------------
   type SyncStateType is (RESET_S, SYNCING_S, SYNCED_S);

   type AdcRegType is record
      state  : SyncStateType;
      slip   : sl;
      count  : slv(5 downto 0);
      locked : sl;
      reset  : sl;
   end record;

   type AdcRegArray is array (natural range <>) of AdcRegType;

   constant ADC_REG_INIT_C : AdcRegType := (
      state  => RESET_S,
      slip   => '0',
      count  => (others => '0'),
      locked => '0',
      reset  => '1');

   signal adcR     : AdcRegArray(1 downto 0) := (others => ADC_REG_INIT_C);
   signal adcRin   : AdcRegArray(1 downto 0);
   signal adcValid : slv(1 downto 0);


   -- Local Signals
   signal tmpAdcClk      : slv(1 downto 0);
   signal adcBitClkIo    : slv(1 downto 0);
   signal adcBitClkIoInv : slv(1 downto 0);
   signal adcBitClkR     : slv(1 downto 0);
   signal adcBitRst      : slv(1 downto 0);

   signal adcFramePad  : slv(1 downto 0);
   signal adcFrame     : slv8Array(1 downto 0);
   signal adcFrameSync : slv8Array(1 downto 0);
   signal adcDataPad   : slv8Array(1 downto 0);
   signal adcData      : AdcDataArray(1 downto 0);

   signal curDelayFrame : slv5Array(1 downto 0);
   signal curDelayData  : DelayDataArray(1 downto 0);

   signal fifoWrData    : slv16Array(NUM_CHANNELS_C-1 downto 0);
   signal fifoDataValid : sl;
   signal fifoDataOut   : slv(NUM_CHANNELS_C*16-1 downto 0);
   signal fifoDataIn    : slv(NUM_CHANNELS_C*16-1 downto 0);
   signal fifoDataTmp   : slv16Array(NUM_CHANNELS_C-1 downto 0);

   signal debugDataValid : sl;
   signal debugDataOut   : slv(NUM_CHANNELS_C*16-1 downto 0);
   signal debugDataTmp   : slv16Array(NUM_CHANNELS_C-1 downto 0);

   signal invertSync : slv(1 downto 0);
   signal negateSync : slv(1 downto 0);
   signal relockSync : slv(1 downto 0);

begin
   -------------------------------------------------------------------------------------------------
   -- Synchronize adcR.locked across to axil clock domain and count falling edges on it
   -------------------------------------------------------------------------------------------------
   SYNC_GEN : for i in 1 downto 0 generate

      SynchronizerOneShotCnt_1 : entity surf.SynchronizerOneShotCnt
         generic map (
            TPD_G          => TPD_G,
            IN_POLARITY_G  => '0',
            OUT_POLARITY_G => '0',
            CNT_RST_EDGE_G => true,
            CNT_WIDTH_G    => 16)
         port map (
            dataIn     => adcR(i).locked,
            rollOverEn => '0',
            cntRst     => axilR.lockedCountRst,
            dataOut    => open,
            cntOut     => lockedFallCount(i),
            wrClk      => adcBitClkR(i),
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
            dataIn  => adcR(i).locked,
            dataOut => lockedSync(i));

      SynchronizerVec_1 : entity surf.SynchronizerVector
         generic map (
            TPD_G    => TPD_G,
            STAGES_G => 2,
            WIDTH_G  => 8)
         port map (
            clk     => axilClk,
            rst     => axilRst,
            dataIn  => adcFrame(i),
            dataOut => adcFrameSync(i));

      Synchronizer_2 : entity surf.Synchronizer
         generic map (
            TPD_G    => TPD_G,
            STAGES_G => 2)
         port map (
            clk     => adcBitClkR(i),
            dataIn  => axilR.invert,
            dataOut => invertSync(i));

      Synchronizer_4 : entity surf.Synchronizer
         generic map (
            TPD_G    => TPD_G,
            STAGES_G => 2)
         port map (
            clk     => adcBitClkR(i),
            dataIn  => axilR.negate,
            dataOut => negateSync(i));


      Synchronizer_3 : entity surf.Synchronizer
         generic map (
            TPD_G    => TPD_G,
            STAGES_G => 2)
         port map (
            clk     => adcBitClkR(i),
--            rst     => axilRst,
            dataIn  => axilR.relock(i),
            dataOut => relockSync(i));


   end generate SYNC_GEN;



   -------------------------------------------------------------------------------------------------
   -- AXIL Interface
   -------------------------------------------------------------------------------------------------
   axilComb : process (adcFrameSync, axilR, axilReadMaster, axilRst, axilWriteMaster, curDelayData,
                       curDelayFrame, debugDataTmp, debugDataValid, lockedFallCount, lockedSync) is
      variable v      : AxilRegType;
      variable axilEp : AxiLiteEndpointType;
   begin
      v := axilR;

      v.dataDelaySet  := (others => (others => '0'));
      v.frameDelaySet := "00";

      v.curDelayFrame := curDelayFrame;
      v.curDelayData  := curDelayData;

      -- Store last two samples read from ADC
      if (debugDataValid = '1' and axilR.freezeDebug = '0') then
         v.readoutDebug0 := debugDataTmp;
         v.readoutDebug1 := axilR.readoutDebug0;
      end if;

      axiSlaveWaitTxn(axilEp, axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave);

      -- Up to 8 delay registers
      -- Write delay values to IDELAY primatives
      -- All writes go to same r.delay register,
      -- dataDelaySet(ch) or frameDelaySet enables the primative write
      for i in 1 downto 0 loop
         for ch in 0 to NUM_CHANNELS_C-1 loop
            axiSlaveRegister(axilEp, X"00"+toSlv((ch*8+i*4), 8), 0, v.delay);
            axiWrDetect(axilEp, X"00"+toSlv((ch*8+i*4), 8), v.dataDelaySet(i)(ch));

            axiSlaveRegisterR(axilEp, X"00"+toSlv((ch*8+i*4), 8), 0, axilR.curDelayData(i)(ch));
         end loop;

         axiSlaveRegister(axilEp, X"40"+toSlv(i*4, 8), 0, v.delay);
         axiWrDetect(axilEp, X"40"+toSlv(i*4, 8), v.frameDelaySet(i));

         axiSlaveRegisterR(axilEp, X"40"+toSlv(i*4, 8), 0, axilR.curDelayFrame(i));
      end loop;




      -- Debug output to see how many times the shift has needed a relock
      axiSlaveRegisterR(axilEp, X"50", 0, lockedFallCount(0));
      axiSlaveRegisterR(axilEp, X"50", 16, lockedSync(0));
      axiSlaveRegisterR(axilEp, X"54", 0, lockedFallCount(1));
      axiSlaveRegisterR(axilEp, X"54", 16, lockedSync(1));

      axiSlaveRegisterR(axilEp, X"58", 0, adcFrameSync(0));
      axiSlaveRegisterR(axilEp, X"58", 8, adcFrameSync(1));

      axiSlaveRegister(axilEp, X"5C", 0, v.lockedCountRst);

      axiSlaveRegister(axilEp, X"60", 0, v.invert);
      axiSlaveRegister(axilEp, X"60", 1, v.negate);

      axiSlaveRegister(axilEp, X"70", 0, v.relock);

      -- Debug registers. Output the last 2 words received
      for ch in 0 to NUM_CHANNELS_C-1 loop
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




   GEN_PARTS : for i in 1 downto 0 generate

      -------------------------------------------------------------------------------------------------
      -- Create Clocks
      -------------------------------------------------------------------------------------------------

      AdcClk_I_Ibufds : IBUFDS
         generic map (
            DIFF_TERM  => true,
            IOSTANDARD => "LVDS_25")
         port map (
            I  => adcSerial.dClkP(i),
            IB => adcSerial.dClkN(i),
            O  => tmpAdcClk(i));

      -- IO Clock
      U_BUFIO : BUFIO
         port map (
            I => tmpAdcClk(i),
            O => adcBitClkIo(i));

      adcBitClkIoInv(i) <= not adcBitClkIo(i);

      -- Regional clock
      U_AdcBitClkR : BUFR
         generic map (
            SIM_DEVICE  => "7SERIES",
            BUFR_DIVIDE => "4")
         port map (
            I   => tmpAdcClk(i),
            O   => adcBitClkR(i),
            CE  => '1',
            CLR => '0');

      -- Regional clock reset
      ADC_BITCLK_RST_SYNC : entity surf.RstSync
         generic map (
            TPD_G           => TPD_G,
            RELEASE_DELAY_G => 5)
         port map (
            clk      => adcBitClkR(i),
            asyncRst => adcClkRst,
            syncRst  => adcBitRst(i));


      -------------------------------------------------------------------------------------------------
      -- Deserializers
      -------------------------------------------------------------------------------------------------

      -- Frame signal input
      U_FrameIn : IBUFDS
         generic map (
            DIFF_TERM => true)
         port map (
            I  => adcSerial.fClkP(i),
            IB => adcSerial.fClkN(i),
            O  => adcFramePad(i));

      U_FRAME_DESERIALIZER : entity surf.Ad9681Deserializer
         generic map (
            TPD_G             => TPD_G,
            DEFAULT_DELAY_G   => DEFAULT_DELAY_G,
            IODELAY_GROUP_G   => IODELAY_GROUP_G,
            IDELAYCTRL_FREQ_G => IDELAYCTRL_FREQ_G)
         port map (
            clkIo    => adcBitClkIo(0),
            clkIoInv => adcBitClkIoInv(0),
            clkR     => adcBitClkR(0),
            rst      => adcR(i).reset,  --adcBitRst(i),
            slip     => adcR(i).slip,
            sysClk   => axilClk,
            curDelay => curDelayFrame(i),
            setDelay => axilR.delay,
            setValid => axilR.frameDelaySet(i),
            iData    => adcFramePad(i),
            oData    => adcFrame(i));

      --------------------------------
      -- Data Input, 8 channels
      --------------------------------
      GenData : for ch in NUM_CHANNELS_C-1 downto 0 generate

         -- Frame signal input
         U_DataIn : IBUFDS
            generic map (
               DIFF_TERM => true)
            port map (
               I  => adcSerial.chP(i)(ch),
               IB => adcSerial.chN(i)(ch),
               O  => adcDataPad(i)(ch));

         -- Optionally invert the pad input
--         adcDataPad(i)(ch) <= adcDataPadOut(i)(ch) when ADC_INVERT_CH_G(i)(ch) = '0' else (not adcDataPadOut(i)(ch));

         U_DATA_DESERIALIZER : entity surf.Ad9681Deserializer
            generic map (
               TPD_G             => TPD_G,
               DEFAULT_DELAY_G   => DEFAULT_DELAY_G,
               IODELAY_GROUP_G   => IODELAY_GROUP_G,
               IDELAYCTRL_FREQ_G => IDELAYCTRL_FREQ_G)
            port map (
               clkIo    => adcBitClkIo(0),
               clkIoInv => adcBitClkIoInv(0),
               clkR     => adcBitClkR(0),
               rst      => adcR(i).reset,  --adcBitRst(i),
               slip     => adcR(i).slip,
               sysClk   => axilClk,
               curDelay => curDelayData(i)(ch),
               setDelay => axilR.delay,
               setValid => axilR.dataDelaySet(i)(ch),
               iData    => adcDataPad(i)(ch),
               oData    => adcData(i)(ch));
      end generate;



      -------------------------------------------------------------------------------------------------
      -- ADC Bit Clocked Logic
      -------------------------------------------------------------------------------------------------
      adcComb : process (adcFrame, adcR, relockSync) is
         variable v : AdcRegType;
      begin
         v := adcR(i);

         ----------------------------------------------------------------------------------------------
         -- Slip bits until correct alignment seen
         ----------------------------------------------------------------------------------------------
         v.slip   := '0';
         v.reset  := '0';
         v.locked := '0';

         v.count := adcR(i).count + 1;

         case adcR(i).state is
            when RESET_S =>
               v.reset := '1';
               if (adcR(i).count = "111111") then
                  v.state := SYNCING_S;
               end if;

            when SYNCING_S =>
               if (adcR(i).count = "111111") then
                  if (adcFrame(i) = "11110000") then
                     v.state := SYNCED_S;
                  else
                     v.slip := '1';
                  end if;
               end if;

            when SYNCED_S =>
               v.locked := '1';
               v.count  := (others => '0');
               if (adcFrame(i) /= "11110000") then
                  v.state := RESET_S;
               end if;

            when others => null;
         end case;

         if (relockSync(i) = '1') then
            v.state := RESET_S;
         end if;

         ----------------------------------------------------------------------------------------------
         -- Look for Frame rising edges and write data to fifos
         ----------------------------------------------------------------------------------------------
         adcRin(i)   <= v;
         adcValid(i) <= adcR(i).locked;

      end process adcComb;

      adcSeq : process (adcBitClkR, adcBitRst) is
      begin
         if (adcBitRst(0) = '1') then
            adcR(i) <= ADC_REG_INIT_C after TPD_G;
         elsif (rising_edge(adcBitClkR(0))) then
            adcR(i) <= adcRin(i) after TPD_G;
         end if;
      end process adcSeq;

   end generate;

   GLUE_COMB : process (adcData, adcValid, invertSync, negateSync) is
      variable tmp : slv16Array(7 downto 0);
   begin
      for ch in NUM_CHANNELS_C-1 downto 0 loop
         if (adcValid = "11") then
            tmp(ch) := adcData(1)(ch) & adcData(0)(ch);
            -- Locked, output adc data
            if invertSync(0) = '1' then
               -- Invert all bits but keep 2 LSBs clear
               tmp(ch) := (X"FFFF" - tmp(ch)) and X"FFFC";
            elsif (negateSync(0) = '1') then
               if (tmp(ch) = X"8000") then
                  -- Negative 1 case
                  tmp(Ch) := X"7FFC";
               else
                  tmp(ch) := (not(tmp(ch)(15 downto 2)) + 1) & "00";
               end if;
            end if;
         else
            -- Not locked
            tmp(ch) := (others => '1');  --"10" & "00000000000000";
         end if;
      end loop;
      fifoWrData <= tmp;
   end process GLUE_COMB;


-- Flatten fifoWrData onto fifoDataIn for FIFO
-- Regroup fifoDataOut by channel into fifoDataTmp
-- Format fifoDataTmp into AxiStream channels
   glue : for i in NUM_CHANNELS_C-1 downto 0 generate
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
         DATA_WIDTH_G  => NUM_CHANNELS_C*16,
         ADDR_WIDTH_G  => 4,
         INIT_G        => "0")
      port map (
         rst    => adcBitRst(0),
         wr_clk => adcBitClkR(0),
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
         DATA_WIDTH_G  => NUM_CHANNELS_C*16,
         ADDR_WIDTH_G  => 4,
         INIT_G        => "0")
      port map (
         rst    => adcBitRst(0),
         wr_clk => adcBitClkR(0),
         wr_en  => '1',                 --Always write data
         din    => fifoDataIn,
         rd_clk => axilClk,
         rd_en  => debugDataValid,
         valid  => debugDataValid,
         dout   => debugDataOut);


end rtl;

