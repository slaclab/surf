-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : AtlasTtcRx.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-03-14
-- Last update: 2015-02-20
-- Platform   : Vivado 2014.3
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Top-Level ATLAS TTC-RX Deserializer 
--          
-- Note: This module assumes that an ADN2816 IC 
--       is used for the Clock Data Recovery (CDR).
-------------------------------------------------------------------------------
-- Copyright (c) 2014 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.AtlasTtcRxPkg.all;

entity AtlasTtcRx is
   generic (
      TPD_G              : time                  := 1 ns;
      AXI_ERROR_RESP_G   : slv(1 downto 0)       := AXI_RESP_SLVERR_C;
      IDELAY_VALUE_G     : slv(4 downto 0)       := toSlv(0, 5);
      STATUS_CNT_WIDTH_G : natural range 1 to 32 := 32;
      IODELAY_GROUP_G    : string                := "atlas_ttc_rx_delay_group";
      CASCADE_SIZE_G     : positive              := 1);  -- number of FIFOs to cascade (if set to 1, then no FIFO cascading)    
   port (
      -- External CDR Ports
      clkP              : in  sl;       -- From ADN2816 IC
      clkN              : in  sl;       -- From ADN2816 IC
      dataP             : in  sl;       -- From ADN2816 IC
      dataN             : in  sl;       -- From ADN2816 IC
      -- RMB Status Signals
      busyIn            : in  sl;       -- FPGA fabric input busy signal
      busyP             : out sl;       -- RMB's busy LEMO interface
      busyN             : out sl;       -- RMB's busy LEMO interface 
      -- Emulation Trigger Signals
      emuSel            : in  sl := '0';
      emuClk            : in  sl := '0';
      emuData           : in  sl := '0';
      -- AXI-Lite Register and Status Bus Interface (axiClk domain)
      axiClk            : in  sl;
      axiRst            : in  sl;
      axiReadMaster     : in  AxiLiteReadMasterType;
      axiReadSlave      : out AxiLiteReadSlaveType;
      axiWriteMaster    : in  AxiLiteWriteMasterType;
      axiWriteSlave     : out AxiLiteWriteSlaveType;
      statusWords       : out Slv64Array(0 to 0);
      statusSend        : out sl;
      -- Reference 200 MHz clock
      refClk200MHz      : in  sl;
      refClkLocked      : in  sl;
      -- Atlas Clocks and trigger interface  (atlasClk160MHz domain)
      atlasTtcRxOut     : out AtlasTTCRxOutType;
      atlasClk40MHz     : out sl;
      atlasClk80MHz     : out sl;
      atlasClk160MHz    : out sl;
      atlasClk160MHzEn  : out sl;       -- phased up with time mux'd CHA
      atlasClk160MHzRst : out sl);
end AtlasTtcRx;

architecture mapping of AtlasTtcRx is
   
   signal locClk,
      locClkEn,
      locRst,
      clkSync,
      bcValid,
      iacValid,
      fifoWr,
      fifoAFull,
      trigL1,
      serDataRising,
      serDataFalling : sl;
   signal bcCheck  : slv(4 downto 0);
   signal iacCheck : slv(6 downto 0);
   signal bcData   : slv(7 downto 0);
   signal iacData  : slv(31 downto 0);
   signal fifoData : slv(30 downto 0);
   signal config   : AtlasTTCRxConfigType := ATLAS_TTC_RX_CONFIG_INIT_C;
   signal status   : AtlasTTCRxStatusType := ATLAS_TTC_RX_STATUS_INIT_C;

   -- attribute KEEP_HIERARCHY : string;
   -- attribute KEEP_HIERARCHY of
   -- AtlasTtcRxReg_Inst,
   -- AtlasTtcRxCdrInputs_Inst,
   -- AtlasTtcRxClkMon_Inst,
   -- AtlasTtcRxDeSer_Inst,
   -- AtlasTtcRxDecodeBc_Inst,
   -- AtlasTtcRxDecodeIac_Inst,
   -- AtlasTtcRxCnt_Inst : label is "TRUE";
   
begin

   ----------
   -- Outputs 
   ----------
   atlasTtcRxOut     <= status.ttcRx;
   atlasClk160MHz    <= locClk;
   atlasClk160MHzEn  <= locClkEn;
   atlasClk160MHzRst <= locRst;

   ---------
   -- Sync 
   ---------
   SyncIn_Busy : entity work.Synchronizer
      generic map (
         TPD_G => TPD_G)
      port map (
         clk     => locClk,
         dataIn  => busyIn,
         dataOut => status.busyIn);  

   -- Sync refClkLocked in the AtlasTtcRxReg's SyncStatusVector module
   status.refClkLocked <= refClkLocked;

   ------------------------------------------------------------
   -- Configuration/Status Register and FIFO for Trigger Events
   ------------------------------------------------------------
   AtlasTtcRxReg_Inst : entity work.AtlasTtcRxReg
      generic map (
         TPD_G              => TPD_G,
         STATUS_CNT_WIDTH_G => STATUS_CNT_WIDTH_G,
         AXI_ERROR_RESP_G   => AXI_ERROR_RESP_G,
         IDELAY_VALUE_G     => IDELAY_VALUE_G,
         CASCADE_SIZE_G     => CASCADE_SIZE_G,
         XIL_DEVICE_G       => "7SERIES",
         USE_BUILT_IN_G     => false,
         FIFO_ADDR_WIDTH_G  => 9,
         FIFO_FIXED_THES_G  => false)      
      port map (
         -- Status Bus (axiClk domain)
         statusWords    => statusWords,
         statusSend     => statusSend,
         -- AXI-Lite Register Interface (axiClk domain)
         axiReadMaster  => axiReadMaster,
         axiReadSlave   => axiReadSlave,
         axiWriteMaster => axiWriteMaster,
         axiWriteSlave  => axiWriteSlave,
         -- Configuration and Status Interface (Mixed domains - refer to AtlasTtcRxPkg)
         config         => config,
         status         => status,
         -- FIFO Interface (locClk domain)
         fifoAFull      => fifoAFull,
         fifoWr         => fifoWr,
         fifoData       => fifoData,
         -- Global Signals
         refClk200MHz   => refClk200MHz,
         axiClk         => axiClk,
         axiRst         => axiRst,
         locClk         => locClk,
         locRst         => locRst);   

   ----------------------------------
   -- Clock/Data Recovery (CDR)Inputs 
   ---------------------------------- 
   AtlasTtcRxCdrInputs_Inst : entity work.AtlasTtcRxCdrInputs
      generic map (
         TPD_G           => TPD_G,
         IODELAY_GROUP_G => IODELAY_GROUP_G,
         XIL_DEVICE_G    => "7SERIES")   
      port map (
         -- CDR Signals
         clkP           => clkP,
         clkN           => clkN,
         clk            => open,
         dataP          => dataP,
         dataN          => dataN,
         data           => open,
         -- Emulation Trigger Signals
         emuSel         => emuSel,
         emuClk         => emuClk,
         emuData        => emuData,
         -- Serial Data Signals
         serDataRising  => serDataRising,
         serDataFalling => serDataFalling,
         -- Delay CTRL (refClk200MHz domain)
         delayIn        => config.delayIn,
         delayOut       => status.delayOut,
         -- Clock Signals
         refClk200MHz   => refClk200MHz,
         clkSync        => clkSync,
         locClk40MHz    => atlasClk40MHz,
         locClk80MHz    => atlasClk80MHz,
         locClk160MHz   => locClk);   

   -------------------
   -- Clock Monitoring
   -------------------
   AtlasTtcRxClkMon_Inst : entity work.AtlasTtcRxClkMon
      generic map (
         TPD_G             => TPD_G,
         EN_LOL_PORT_G     => false,
         EN_SIG_DET_PORT_G => false)    
      port map (
         -- Status Monitoring
         clkLocked       => status.clkLocked,
         freqLocked      => status.freqLocked,
         cdrLocked       => open,
         sigLocked       => open,
         freqMeasured    => status.freqMeasured,
         ignoreSigLocked => '1',
         ignoreCdrLocked => '1',
         lockedP         => open,
         lockedN         => open,
         -- Global Signals
         refClk200MHz    => refClk200MHz,
         locClk          => locClk,
         locRst          => locRst);   

   ------------------------------------------------
   -- Time Demultiplexer and Deserialization Module
   ------------------------------------------------
   AtlasTtcRxDeSer_Inst : entity work.AtlasTtcRxDeSer
      generic map (
         TPD_G => TPD_G)    
      port map (
         -- Serial Data Signals
         serDataEdgeSel => config.serDataEdgeSel,
         serDataRising  => serDataRising,
         serDataFalling => serDataFalling,
         -- Level-1 Trigger
         trigL1         => trigL1,
         -- BC Encoded Message
         bcValid        => bcValid,
         bcData         => bcData,
         bcCheck        => bcCheck,
         -- IAC Encoded Message
         iacValid       => iacValid,
         iacData        => iacData,
         iacCheck       => iacCheck,
         -- Status Monitoring
         clkLocked      => status.clkLocked,
         bpmLocked      => status.bpmLocked,
         bpmErr         => status.bpmErr,
         deSerErr       => status.deSerErr,
         -- Clock Signals
         clkSync        => clkSync,
         locClkEn       => locClkEn,
         locClk         => locClk,
         locRst         => locRst);       

   -----------------------     
   -- BC's Hamming Decoder
   -----------------------     
   AtlasTtcRxDecodeBc_Inst : entity work.AtlasTtcRxDecodeBc
      generic map (
         TPD_G                => TPD_G,
         BYPASS_ERROR_CHECK_G => false)   
      port map (
         -- Encoded Message Input      
         validIn   => bcValid,
         dataIn    => bcData,
         checkIn   => bcCheck,
         -- Decoded Message Output
         bc        => status.ttcRx.bc,
         sBitErrBc => status.sBitErrBc,
         dBitErrBc => status.dBitErrBc,
         -- Global Signals
         locClk    => locClk,
         locRst    => locRst); 

   ------------------------    
   -- IAC's Hamming Decoder
   ------------------------
   AtlasTtcRxDecodeIac_Inst : entity work.AtlasTtcRxDecodeIac
      generic map (
         TPD_G                => TPD_G,
         BYPASS_ERROR_CHECK_G => false)   
      port map (
         -- Encoded Message Input
         validIn    => iacValid,
         dataIn     => iacData,
         checkIn    => iacCheck,
         -- Decoded Message Output
         iac        => status.ttcRx.iac,
         sBitErrIac => status.sBitErrIac,
         dBitErrIac => status.dBitErrIac,
         -- Global Signals
         locClk     => locClk,
         locRst     => locRst);           

   ---------------------------------------------------
   -- Bunch/Event Counters and Trigger Event Generator
   ---------------------------------------------------         
   AtlasTtcRxCnt_Inst : entity work.AtlasTtcRxCnt
      generic map (
         TPD_G => TPD_G)   
      port map (
         -- Trigger Signals
         trigL1In        => trigL1,
         trigL1Out       => status.ttcRx.trigL1,
         bc              => status.ttcRx.bc,
         forceBusy       => config.forceBusy,
         presetECR       => config.presetECR,
         pauseECR        => config.pauseECR,
         ignoreExtBusyIn => config.ignoreExtBusyIn,
         ignoreFifoFull  => config.ignoreFifoFull,
         busyIn          => status.busyIn,
         busyP           => busyP,
         busyN           => busyN,
         bunchCnt        => status.ttcRx.bunchCnt,
         bunchRstCnt     => status.ttcRx.bunchRstCnt,
         eventCnt        => status.ttcRx.eventCnt,
         eventRstCnt     => status.ttcRx.eventRstCnt,
         busyRateRst     => config.busyRateRst,
         busyRateCnt     => status.busyRateCnt,
         busyRate        => status.busyRate,
         -- FIFO Interface
         fifoAFull       => fifoAFull,
         fifoWr          => fifoWr,
         fifoData        => fifoData,
         -- Global Signals
         refClk200MHz    => refClk200MHz,
         locClk          => locClk,
         locClkEn        => locClkEn,
         locRst          => config.rstL1Id);         

   ---------------------------------------------------
   -- ECR and EC debugging (no resets applied)
   ---------------------------------------------------         
   AtlasTtcRxDebugCnt_Inst : entity work.AtlasTtcRxDebugCnt
      generic map (
         TPD_G => TPD_G)   
      port map (
         -- Trigger Signals
         trigL1In    => trigL1,
         bc          => status.ttcRx.bc,
         eventCnt    => status.debugEC,
         eventRstCnt => status.debugECR,
         ecrDet      => status.ttcRx.ecrDet,
         -- Global Signals
         locClk      => locClk,
         locClkEn    => locClkEn,
         locRst      => config.rstL1Id);         

end mapping;
