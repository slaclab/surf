-------------------------------------------------------------------------------
-- File       : Ad9249ReadoutGroup.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-05-26
-- Last update: 2017-03-07
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

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;
use work.Ad9249Pkg.all;

entity Ad9249ReadoutGroup is
   generic (
      TPD_G             : time                 := 1 ns;
      NUM_CHANNELS_G    : natural range 1 to 8 := 8;
      IODELAY_GROUP_G   : string               := "DEFAULT_GROUP";
      IDELAYCTRL_FREQ_G : real                 := 200.0;
      DEFAULT_DELAY_G   : slv(4 downto 0)      := (others => '0');
      ADC_INVERT_CH_G   : slv(7 downto 0)      := "00000000");
   port (
      -- Master system clock, 125Mhz
      axilClk : in sl;
      axilRst : in sl;

      -- Axi Interface
      axilWriteMaster : in  AxiLiteWriteMasterType;
      axilWriteSlave  : out AxiLiteWriteSlaveType;
      axilReadMaster  : in  AxiLiteReadMasterType;
      axilReadSlave   : out AxiLiteReadSlaveType;

      -- Reset for adc deserializer
      adcClkRst : in sl;

      -- Serial Data from ADC
      adcSerial : in Ad9249SerialGroupType;

      -- Deserialized ADC Data
      adcStreamClk : in  sl;
      adcStreams   : out AxiStreamMasterArray(NUM_CHANNELS_G-1 downto 0) :=
      (others => axiStreamMasterInit((false, 2, 8, 0, TKEEP_NORMAL_C, 0, TUSER_NORMAL_C))));
end Ad9249ReadoutGroup;

-- Define architecture
architecture rtl of Ad9249ReadoutGroup is

   -------------------------------------------------------------------------------------------------
   -- AXIL Registers
   -------------------------------------------------------------------------------------------------
   type AxilRegType is record
      axilWriteSlave : AxiLiteWriteSlaveType;
      axilReadSlave  : AxiLiteReadSlaveType;
      delay          : slv(4 downto 0);
      dataDelaySet   : slv(NUM_CHANNELS_G-1 downto 0);
      frameDelaySet  : sl;
      readoutDebug0  : slv16Array(NUM_CHANNELS_G-1 downto 0);
      readoutDebug1  : slv16Array(NUM_CHANNELS_G-1 downto 0);
      lockedCountRst : sl;
   end record;

   constant AXIL_REG_INIT_C : AxilRegType := (
      axilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C,
      axilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
      delay          => DEFAULT_DELAY_G,
      dataDelaySet   => (others => '1'),
      frameDelaySet  => '1',
      readoutDebug0  => (others => (others => '0')),
      readoutDebug1  => (others => (others => '0')),
      lockedCountRst => '0');

   signal lockedSync      : sl;
   signal lockedFallCount : slv(15 downto 0);

   signal axilR   : AxilRegType := AXIL_REG_INIT_C;
   signal axilRin : AxilRegType;

   -------------------------------------------------------------------------------------------------
   -- ADC Readout Clocked Registers
   -------------------------------------------------------------------------------------------------
   type AdcRegType is record
      slip       : sl;
      count      : slv(5 downto 0);
      locked     : sl;
      fifoWrData : Slv16Array(NUM_CHANNELS_G-1 downto 0);
   end record;

   constant ADC_REG_INIT_C : AdcRegType := (
      slip       => '0',
      count      => (others => '0'),
      locked     => '0',
      fifoWrData => (others => (others => '0')));

   signal adcR   : AdcRegType := ADC_REG_INIT_C;
   signal adcRin : AdcRegType;


   -- Local Signals
   signal tmpAdcClk      : sl;
   signal adcBitClkIo    : sl;
   signal adcBitClkIoInv : sl;
   signal adcBitClkR     : sl;
   signal adcBitRst      : sl;

   signal adcFramePad   : sl;
   signal adcFrame      : slv(13 downto 0);
   signal adcFrameSync  : slv(13 downto 0);
   signal adcDataPadOut : slv(NUM_CHANNELS_G-1 downto 0);
   signal adcDataPad    : slv(NUM_CHANNELS_G-1 downto 0);
   signal adcData       : Slv14Array(NUM_CHANNELS_G-1 downto 0);

   signal curDelayFrame : slv(4 downto 0);
   signal curDelayData  : slv5Array(NUM_CHANNELS_G-1 downto 0);

   signal fifoDataValid : sl;
   signal fifoDataOut   : slv(NUM_CHANNELS_G*16-1 downto 0);
   signal fifoDataIn    : slv(NUM_CHANNELS_G*16-1 downto 0);
   signal fifoDataTmp   : slv16Array(NUM_CHANNELS_G-1 downto 0);

   signal debugDataValid : sl;
   signal debugDataOut   : slv(NUM_CHANNELS_G*16-1 downto 0);
   signal debugDataTmp   : slv16Array(NUM_CHANNELS_G-1 downto 0);   

begin
   -------------------------------------------------------------------------------------------------
   -- Synchronize adcR.locked across to axil clock domain and count falling edges on it
   -------------------------------------------------------------------------------------------------

   SynchronizerOneShotCnt_1 : entity work.SynchronizerOneShotCnt
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
         wrClk      => adcBitClkR,
         wrRst      => '0',
         rdClk      => axilClk,
         rdRst      => axilRst);

   Synchronizer_1 : entity work.Synchronizer
      generic map (
         TPD_G    => TPD_G,
         STAGES_G => 2)
      port map (
         clk     => axilClk,
         rst     => axilRst,
         dataIn  => adcR.locked,
         dataOut => lockedSync);

   SynchronizerVec_1 : entity work.SynchronizerVector
      generic map (
         TPD_G    => TPD_G,
         STAGES_G => 2,
         WIDTH_G  => 14)
      port map (
         clk     => axilClk,
         rst     => axilRst,
         dataIn  => adcFrame,
         dataOut => adcFrameSync);

   -------------------------------------------------------------------------------------------------
   -- AXIL Interface
   -------------------------------------------------------------------------------------------------
   axilComb : process (adcFrameSync, axilR, axilReadMaster, axilRst, axilWriteMaster, curDelayData,
                       curDelayFrame, debugDataTmp, debugDataValid, lockedFallCount, lockedSync) is
      variable v      : AxilRegType;
      variable axilEp : AxiLiteEndpointType;
   begin
      v := axilR;

      v.dataDelaySet        := (others => '0');
      v.frameDelaySet       := '0';
      v.axilReadSlave.rdata := (others => '0');

      -- Store last two samples read from ADC
      if (debugDataValid = '1') then
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
         axiSlaveRegister(axilEp, X"00"+toSlv((i*4), 8), 5, v.dataDelaySet(i), '1');
      end loop;
      axiSlaveRegister(axilEp, X"20", 0, v.delay);
      axiSlaveRegister(axilEp, X"20", 5, v.frameDelaySet, '1');

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

      -- Debug registers. Output the last 2 words received
      for i in 0 to NUM_CHANNELS_G-1 loop
         axiSlaveRegisterR(axilEp, X"80"+toSlv((i*4), 8), 0, axilR.readoutDebug0(i));
         axiSlaveRegisterR(axilEp, X"80"+toSlv((i*4), 8), 16, axilR.readoutDebug1(i));
      end loop;

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

   AdcClk_I_Ibufds : IBUFDS
      generic map (
         DIFF_TERM  => true,
         IOSTANDARD => "LVDS_25")
      port map (
         I  => adcSerial.dClkP,
         IB => adcSerial.dClkN,
         O  => tmpAdcClk);

   -- IO Clock
   U_BUFIO : BUFIO
      port map (
         I => tmpAdcClk,
         O => adcBitClkIo);

   adcBitClkIoInv <= not adcBitClkIo;

   -- Regional clock
   U_AdcBitClkR : BUFR
      generic map (
         SIM_DEVICE  => "7SERIES",
         BUFR_DIVIDE => "7")
      port map (
         I   => tmpAdcClk,
         O   => adcBitClkR,
         CE  => '1',
         CLR => '0');

   -- Regional clock reset
   ADC_BITCLK_RST_SYNC : entity work.RstSync
      generic map (
         TPD_G           => TPD_G,
         RELEASE_DELAY_G => 5)
      port map (
         clk      => adcBitClkR,
         asyncRst => adcClkRst,
         syncRst  => adcBitRst);


   -------------------------------------------------------------------------------------------------
   -- Deserializers
   -------------------------------------------------------------------------------------------------

   -- Frame signal input
   U_FrameIn : IBUFDS
      generic map (
         DIFF_TERM => true)
      port map (
         I  => adcSerial.fClkP,
         IB => adcSerial.fClkN,
         O  => adcFramePad);

   U_FRAME_DESERIALIZER : entity work.Ad9249Deserializer
      generic map (
         TPD_G             => TPD_G,
         IODELAY_GROUP_G   => IODELAY_GROUP_G,
         IDELAYCTRL_FREQ_G => IDELAYCTRL_FREQ_G)
      port map (
         clkIo    => adcBitClkIo,
         clkIoInv => adcBitClkIoInv,
         clkR     => adcBitClkR,
         rst      => adcBitRst,
         slip     => adcR.slip,
         sysClk   => axilClk,
         curDelay => curDelayFrame,
         setDelay => axilR.delay,
         setValid => axilR.frameDelaySet,
         iData    => adcFramePad,
         oData    => adcFrame);

   --------------------------------
   -- Data Input, 8 channels
   --------------------------------
   GenData : for i in NUM_CHANNELS_G-1 downto 0 generate

      -- Frame signal input
      U_DataIn : IBUFDS
         generic map (
            DIFF_TERM => true)
         port map (
            I  => adcSerial.chP(i),
            IB => adcSerial.chN(i),
            O  => adcDataPadOut(i));

      -- Optionally invert the pad input
      adcDataPad(i) <= adcDataPadOut(i) when ADC_INVERT_CH_G(i) = '0' else not adcDataPadOut(i);

      U_DATA_DESERIALIZER : entity work.Ad9249Deserializer
         generic map (
            TPD_G             => TPD_G,
            IODELAY_GROUP_G   => IODELAY_GROUP_G,
            IDELAYCTRL_FREQ_G => IDELAYCTRL_FREQ_G)
         port map (
            clkIo    => adcBitClkIo,
            clkIoInv => adcBitClkIoInv,
            clkR     => adcBitClkR,
            rst      => adcBitRst,
            slip     => adcR.slip,
            sysClk   => axilClk,
            curDelay => curDelayData(i),
            setDelay => axilR.delay,
            setValid => axilR.dataDelaySet(i),
            iData    => adcDataPad(i),
            oData    => adcData(i));
   end generate;

   -------------------------------------------------------------------------------------------------
   -- ADC Bit Clocked Logic
   -------------------------------------------------------------------------------------------------
   adcComb : process (adcData, adcFrame, adcR) is
      variable v : AdcRegType;
   begin
      v := adcR;

      ----------------------------------------------------------------------------------------------
      -- Slip bits until correct alignment seen
      ----------------------------------------------------------------------------------------------
      v.slip := '0';

      if (adcR.count = 0) then
         if (adcFrame = "11111110000000") then
            v.locked := '1';
         else
            v.locked := '0';
            v.slip   := '1';
            v.count  := adcR.count + 1;
         end if;
      end if;

      if (adcR.count /= 0) then
         v.count := adcR.count + 1;
      end if;

      ----------------------------------------------------------------------------------------------
      -- Look for Frame rising edges and write data to fifos
      ----------------------------------------------------------------------------------------------
      for i in NUM_CHANNELS_G-1 downto 0 loop
         if (adcR.locked = '1' and adcFrame = "11111110000000") then
            -- Locked, output adc data
            v.fifoWrData(i) := "00" & adcData(i);
         else
            -- Not locked
            v.fifoWrData(i) := (others => '1'); --"10" & "00000000000000";
         end if;
      end loop;

      adcRin <= v;

   end process adcComb;

   adcSeq : process (adcBitClkR, adcBitRst) is
   begin
      if (adcBitRst = '1') then
         adcR <= ADC_REG_INIT_C after TPD_G;
      elsif (rising_edge(adcBitClkR)) then
         adcR <= adcRin after TPD_G;
      end if;
   end process adcSeq;

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
   U_DataFifo : entity work.SynchronizerFifo
      generic map (
         TPD_G        => TPD_G,
         BRAM_EN_G    => false,
         DATA_WIDTH_G => NUM_CHANNELS_G*16,
         ADDR_WIDTH_G => 4,
         INIT_G       => "0")
      port map (
         rst    => adcBitRst,
         wr_clk => adcBitClkR,
         wr_en  => '1',                 --Always write data
         din    => fifoDataIn,
         rd_clk => adcStreamClk,
         rd_en  => fifoDataValid,
         valid  => fifoDataValid,
         dout   => fifoDataOut);

   U_DataFifoDebug : entity work.SynchronizerFifo
      generic map (
         TPD_G        => TPD_G,
         BRAM_EN_G    => false,
         DATA_WIDTH_G => NUM_CHANNELS_G*16,
         ADDR_WIDTH_G => 4,
         INIT_G       => "0")
      port map (
         rst    => adcBitRst,
         wr_clk => adcBitClkR,
         wr_en  => '1',                 --Always write data
         din    => fifoDataIn,
         rd_clk => axilClk,
         rd_en  => debugDataValid,
         valid  => debugDataValid,
         dout   => debugDataOut);


end rtl;

