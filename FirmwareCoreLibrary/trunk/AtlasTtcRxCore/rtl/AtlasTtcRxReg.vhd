-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : AtlasTtcRxReg.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-03-20
-- Last update: 2015-01-20
-- Platform   : Vivado 2014.3
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2014 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.AtlasTtcRxPkg.all;
use work.Version.all;

entity AtlasTtcRxReg is
   generic (
      TPD_G              : time                  := 1 ns;
      STATUS_CNT_WIDTH_G : natural range 1 to 32 := 32;
      AXI_ERROR_RESP_G   : slv(1 downto 0)       := AXI_RESP_SLVERR_C;
      IDELAY_VALUE_G     : slv(4 downto 0)       := toSlv(0, 5);
      CASCADE_SIZE_G     : positive              := 1;  -- number of FIFOs to cascade (if set to 1, then no FIFO cascading)
      XIL_DEVICE_G       : string                := "7SERIES";
      USE_BUILT_IN_G     : boolean               := true;
      FIFO_ADDR_WIDTH_G  : integer range 4 to 48 := 9;
      FIFO_FIXED_THES_G  : boolean               := false;
      FIFO_AFULL_THRES_G : positive              := 256);
   -- Note: If FIFO_FIXED_THES_G = true, then the fixed FIFO_AFULL_THRES_G is used.
   --       If FIFO_FIXED_THES_G = false, then the programmable threshold (vcRxThreshold) is used.        
   port (
      -- Status Bus (axiClk domain)
      statusWords    : out Slv64Array(0 to 0);
      statusSend     : out sl;
      -- AXI-Lite Register Interface (axiClk domain)
      axiReadMaster  : in  AxiLiteReadMasterType;
      axiReadSlave   : out AxiLiteReadSlaveType;
      axiWriteMaster : in  AxiLiteWriteMasterType;
      axiWriteSlave  : out AxiLiteWriteSlaveType;
      -- Register Inputs/Outputs (Mixed domains - refer to AtlasTtcRxPkg)
      config         : out AtlasTTCRxConfigType;
      status         : in  AtlasTTCRxStatusType;
      -- FIFO Interface (locClk domain)
      fifoAFull      : out sl;
      fifoWr         : in  sl;
      fifoData       : in  slv(30 downto 0);
      -- Global Signals
      refClk200MHz   : in  sl;
      axiClk         : in  sl;
      axiRst         : in  sl;
      locClk         : in  sl;
      locRst         : out sl);   
end AtlasTtcRxReg;

architecture rtl of AtlasTtcRxReg is

   constant STATUS_SIZE_C : positive := 15;

   constant MAX_FIFO_CNT_C : slv(FIFO_ADDR_WIDTH_G-1 downto 0) := (others => '1');

   type RegType is record
      locReset      : sl;
      cntRst        : sl;
      rollOverEn    : slv(STATUS_SIZE_C-1 downto 0);
      irqEn         : slv(STATUS_SIZE_C-1 downto 0);
      fifoThreshold : slv(FIFO_ADDR_WIDTH_G-1 downto 0);
      fifoRd        : sl;
      fifoReq       : sl;
      regOut        : AtlasTTCRxConfigType;
      axiReadSlave  : AxiLiteReadSlaveType;
      axiWriteSlave : AxiLiteWriteSlaveType;
   end record RegType;
   
   constant REG_INIT_C : RegType := (
      '1',
      '1',
      (others => '0'),
      (others => '0'),
      (others => '1'),
      '0',
      '0',
      ATLAS_TTC_RX_CONFIG_INIT_C,
      AXI_LITE_READ_SLAVE_INIT_C,
      AXI_LITE_WRITE_SLAVE_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal regIn  : AtlasTTCRxStatusType := ATLAS_TTC_RX_STATUS_INIT_C;
   signal regOut : AtlasTTCRxConfigType := ATLAS_TTC_RX_CONFIG_INIT_C;

   signal locReset,
      fifoRd,
      fifoValid,
      fifoEmpty,
      fifoAlmostFull,
      fifoProgFull,
      fifoOverFlow,
      overflow,
      cntRst : sl;
   signal rollOverEn,
      irqEn : slv(STATUS_SIZE_C-1 downto 0);
   signal cntOut : SlVectorArray(STATUS_SIZE_C-1 downto 0, STATUS_CNT_WIDTH_G-1 downto 0);
   signal fifoThreshold,
      fifoCntSync,
      fifoCnt : slv(FIFO_ADDR_WIDTH_G-1 downto 0);
   signal busyInCnt,
      fifoAlmostFullCnt,
      fifoOverFlowCnt,
      busyOutCnt,
      trigL1Cnt,
      dBitErrIacCnt,
      sBitErrIacCnt,
      dBitErrBcCnt,
      sBitErrBcCnt,
      deSerErrCnt,
      bpmErrCnt,
      bpmLockedCnt,
      freqLockedCnt,
      clkLockedCnt,
      refClkLockedCnt : slv(STATUS_CNT_WIDTH_G-1 downto 0);
   signal timingData : slv(30 downto 0);
   signal fifoReqRate,
      fifoReadRate : slv(31 downto 0);
   
begin

   fifoAFull <= fifoAlmostFull;

   process(locClk)
   begin
      if rising_edge(locClk) then
         -- Check for a reset
         if locReset = '1' then
            fifoAlmostFull <= '1' after TPD_G;
         else
            if FIFO_FIXED_THES_G then
               fifoAlmostFull <= fifoProgFull after TPD_G;
            else
               -- Else using programmable threshold
               if fifoCnt = MAX_FIFO_CNT_C then
                  fifoAlmostFull <= '1' after TPD_G;
               elsif fifoCnt > fifoThreshold then
                  fifoAlmostFull <= '1' after TPD_G;
               else
                  fifoAlmostFull <= '0' after TPD_G;
               end if;
            end if;
         end if;
      end if;
   end process;

   Fifo_Inst : entity work.FifoCascade
      generic map (
         TPD_G              => TPD_G,
         CASCADE_SIZE_G     => CASCADE_SIZE_G,
         LAST_STAGE_ASYNC_G => true,
         RST_POLARITY_G     => '1',
         RST_ASYNC_G        => false,
         GEN_SYNC_FIFO_G    => false,
         BRAM_EN_G          => true,
         FWFT_EN_G          => true,
         USE_DSP48_G        => "no",
         ALTERA_SYN_G       => false,
         ALTERA_RAM_G       => "M9K",
         USE_BUILT_IN_G     => USE_BUILT_IN_G,
         XIL_DEVICE_G       => XIL_DEVICE_G,
         SYNC_STAGES_G      => 3,
         PIPE_STAGES_G      => 0,
         DATA_WIDTH_G       => 31,
         ADDR_WIDTH_G       => FIFO_ADDR_WIDTH_G,
         INIT_G             => "0",
         FULL_THRES_G       => FIFO_AFULL_THRES_G,
         EMPTY_THRES_G      => 1)         
      port map (
         -- Resets
         rst           => locReset,
         --Write Ports (wr_clk domain)
         wr_clk        => locClk,
         wr_en         => fifoWr,
         din           => fifoData,
         wr_data_count => fifoCnt,
         overflow      => fifoOverFlow,
         prog_full     => fifoProgFull,
         --Read Ports (rd_clk domain)
         rd_clk        => axiClk,
         rd_en         => fifoRd,
         dout          => timingData,
         valid         => fifoValid,
         empty         => fifoEmpty);

   Sync_fifoThreshold : entity work.SynchronizerFifo
      generic map (
         TPD_G        => TPD_G,
         DATA_WIDTH_G => FIFO_ADDR_WIDTH_G)
      port map (
         wr_clk => axiClk,
         din    => r.fifoThreshold,
         rd_clk => locClk,
         dout   => fifoThreshold);  

   Sync_fifoCnt : entity work.SynchronizerFifo
      generic map (
         TPD_G        => TPD_G,
         DATA_WIDTH_G => FIFO_ADDR_WIDTH_G)
      port map (
         wr_clk => locClk,
         din    => fifoCnt,
         rd_clk => axiClk,
         dout   => fifoCntSync); 

   Sync_fifoReqRate : entity work.SyncTrigRate
      generic map (
         TPD_G          => TPD_G,
         COMMON_CLK_G   => false,
         IN_POLARITY_G  => '1',
         REF_CLK_FREQ_G => 200.0E+6,    -- units of Hz
         REFRESH_RATE_G => 1.0E+0,      -- units of Hz
         USE_DSP48_G    => "no",
         CNT_WIDTH_G    => 32)
      port map (
         -- Trigger Input (locClk domain)
         trigIn          => r.fifoReq,
         -- Trigger Rate Output (locClk domain)
         trigRateUpdated => open,
         trigRateOut     => fifoReqRate,
         -- Clocks
         locClkEn        => '1',
         locClk          => axiClk,
         refClk          => refClk200MHz);  

   Sync_fifoReadRate : entity work.SyncTrigRate
      generic map (
         TPD_G          => TPD_G,
         COMMON_CLK_G   => false,
         IN_POLARITY_G  => '1',
         REF_CLK_FREQ_G => 200.0E+6,    -- units of Hz
         REFRESH_RATE_G => 1.0E+0,      -- units of Hz
         USE_DSP48_G    => "no",
         CNT_WIDTH_G    => 32)
      port map (
         -- Trigger Input (locClk domain)
         trigIn          => fifoRd,
         -- Trigger Rate Output (locClk domain)
         trigRateUpdated => open,
         trigRateOut     => fifoReadRate,
         -- Clocks
         locClkEn        => '1',
         locClk          => axiClk,
         refClk          => refClk200MHz);           

   -------------------------------
   -- Configuration Register
   -------------------------------  
   comb : process (axiReadMaster, axiRst, axiWriteMaster, bpmErrCnt, bpmLockedCnt, busyInCnt,
                   busyOutCnt, clkLockedCnt, dBitErrBcCnt, dBitErrIacCnt, deSerErrCnt,
                   fifoAlmostFullCnt, fifoEmpty, fifoOverFlowCnt, fifoValid, freqLockedCnt, r,
                   refClkLockedCnt, regIn, sBitErrBcCnt, sBitErrIacCnt, timingData, trigL1Cnt) is
      variable v            : RegType;
      variable axiStatus    : AxiLiteStatusType;
      variable axiWriteResp : slv(1 downto 0);
      variable axiReadResp  : slv(1 downto 0);
   begin
      -- Latch the current value
      v := r;

      -- Determine the transaction type
      axiSlaveWaitTxn(axiWriteMaster, axiReadMaster, v.axiWriteSlave, v.axiReadSlave, axiStatus);

      -- Reset strobe signals
      v.regOut.delayIn.load := '0';
      v.regOut.delayIn.rst  := '0';
      v.locReset            := '0';
      v.cntRst              := '0';
      v.fifoRd              := '0';
      v.fifoReq             := '0';
      v.regOut.rstL1Id      := '0';

      if (axiStatus.writeEnable = '1') then
         -- Check for an out of 32 bit aligned address
         axiWriteResp := ite(axiWriteMaster.awaddr(1 downto 0) = "00", AXI_RESP_OK_C, AXI_ERROR_RESP_G);
         -- Decode address and perform write
         case (axiWriteMaster.awaddr(9 downto 2)) is
            when x"80" =>
               v.regOut.forceBusy := axiWriteMaster.wdata(0);
            when x"81" =>
               v.regOut.ignoreExtBusyIn := axiWriteMaster.wdata(0);
            when x"82" =>
               v.regOut.ignoreFifoFull := axiWriteMaster.wdata(0);
            when x"83" =>
               v.regOut.presetECR := axiWriteMaster.wdata(7 downto 0);
            when x"84" =>
               v.regOut.pauseECR := axiWriteMaster.wdata(0);
            when x"A0" =>
               v.fifoThreshold := axiWriteMaster.wdata(FIFO_ADDR_WIDTH_G-1 downto 0);
            when x"F0" =>
               v.rollOverEn := axiWriteMaster.wdata(STATUS_SIZE_C-1 downto 0);
            when x"F1" =>
               v.irqEn := axiWriteMaster.wdata(STATUS_SIZE_C-1 downto 0);
            when x"FC" =>
               v.regOut.rstL1Id := '1';
            when x"FD" =>
               v                     := REG_INIT_C;
               v.locReset            := '1';
               v.cntRst              := '1';
               v.regOut.delayIn.load := '1';
               v.regOut.delayIn.rst  := '1';
               v.regOut.delayIn.data := IDELAY_VALUE_G;
            when x"FE" =>
               v.locReset       := '1';
               v.regOut.rstL1Id := '1';
            when x"FF" =>
               v.cntRst := '1';
            when others =>
               axiWriteResp := AXI_ERROR_RESP_G;
         end case;
         -- Send AXI response
         axiSlaveWriteResponse(v.axiWriteSlave, axiWriteResp);
      end if;

      if (axiStatus.readEnable = '1') then
         -- Check for an out of 32 bit aligned address
         axiReadResp          := ite(axiReadMaster.araddr(1 downto 0) = "00", AXI_RESP_OK_C, AXI_ERROR_RESP_G);
         -- Decode address and assign read data 
         v.axiReadSlave.rdata := (others => '0');
         case (axiReadMaster.araddr(9 downto 2)) is
            when x"00" =>
               v.axiReadSlave.rdata(STATUS_CNT_WIDTH_G-1 downto 0) := refClkLockedCnt;
            when x"01" =>
               v.axiReadSlave.rdata(STATUS_CNT_WIDTH_G-1 downto 0) := clkLockedCnt;
            when x"02" =>
               v.axiReadSlave.rdata(STATUS_CNT_WIDTH_G-1 downto 0) := freqLockedCnt;
            when x"03" =>
               v.axiReadSlave.rdata(STATUS_CNT_WIDTH_G-1 downto 0) := bpmLockedCnt;
            when x"04" =>
               v.axiReadSlave.rdata(STATUS_CNT_WIDTH_G-1 downto 0) := bpmErrCnt;
            when x"05" =>
               v.axiReadSlave.rdata(STATUS_CNT_WIDTH_G-1 downto 0) := deSerErrCnt;
            when x"06" =>
               v.axiReadSlave.rdata(STATUS_CNT_WIDTH_G-1 downto 0) := sBitErrBcCnt;
            when x"07" =>
               v.axiReadSlave.rdata(STATUS_CNT_WIDTH_G-1 downto 0) := dBitErrBcCnt;
            when x"08" =>
               v.axiReadSlave.rdata(STATUS_CNT_WIDTH_G-1 downto 0) := sBitErrIacCnt;
            when x"09" =>
               v.axiReadSlave.rdata(STATUS_CNT_WIDTH_G-1 downto 0) := dBitErrIacCnt;
            when x"0A" =>
               v.axiReadSlave.rdata(STATUS_CNT_WIDTH_G-1 downto 0) := trigL1Cnt;
            when x"0B" =>
               v.axiReadSlave.rdata(STATUS_CNT_WIDTH_G-1 downto 0) := busyOutCnt;
            when x"0C" =>
               v.axiReadSlave.rdata(STATUS_CNT_WIDTH_G-1 downto 0) := fifoOverFlowCnt;
            when x"0D" =>
               v.axiReadSlave.rdata(STATUS_CNT_WIDTH_G-1 downto 0) := fifoAlmostFullCnt;
            when x"0E" =>
               v.axiReadSlave.rdata(STATUS_CNT_WIDTH_G-1 downto 0) := busyInCnt;
            when x"40" =>
               v.axiReadSlave.rdata(14) := regIn.busyIn;
               v.axiReadSlave.rdata(13) := regIn.fifoAlmostFull;
               v.axiReadSlave.rdata(12) := regIn.fifoOverFlow;
               v.axiReadSlave.rdata(11) := regIn.ttcRx.ecrDet;
               v.axiReadSlave.rdata(10) := regIn.ttcRx.trigL1;
               v.axiReadSlave.rdata(9)  := regIn.dBitErrIac;
               v.axiReadSlave.rdata(8)  := regIn.sBitErrIac;
               v.axiReadSlave.rdata(7)  := regIn.dBitErrBc;
               v.axiReadSlave.rdata(6)  := regIn.sBitErrBc;
               v.axiReadSlave.rdata(5)  := regIn.deSerErr;
               v.axiReadSlave.rdata(4)  := regIn.bpmErr;
               v.axiReadSlave.rdata(3)  := regIn.bpmLocked;
               v.axiReadSlave.rdata(2)  := regIn.freqLocked;
               v.axiReadSlave.rdata(1)  := regIn.clkLocked;
               v.axiReadSlave.rdata(0)  := regIn.refClkLocked;
            when x"50" =>
               v.axiReadSlave.rdata(11 downto 0) := regIn.ttcRx.bunchCnt;
            when x"51" =>
               v.axiReadSlave.rdata(7 downto 0) := regIn.ttcRx.bunchRstCnt;
            when x"52" =>
               v.axiReadSlave.rdata(23 downto 0) := regIn.ttcRx.eventCnt;
            when x"53" =>
               v.axiReadSlave.rdata(7 downto 0) := regIn.ttcRx.eventRstCnt;
            when x"54" =>
               v.axiReadSlave.rdata(23 downto 0) := regIn.debugEC;
            when x"55" =>
               v.axiReadSlave.rdata(7 downto 0) := regIn.debugECR;
            when x"70" =>
               v.axiReadSlave.rdata(31)          := fifoEmpty;
               v.axiReadSlave.rdata(30 downto 0) := timingData;
               v.fifoRd                          := fifoValid;
               v.fifoReq                         := '1';
            when X"7D" =>
               v.axiReadSlave.rdata := regIn.freqMeasured;               
            when X"7E" =>
               v.axiReadSlave.rdata := regIn.busyRateCnt;
            when X"7F" =>
               v.axiReadSlave.rdata := regIn.busyRate;
            when x"80" =>
               v.axiReadSlave.rdata(0) := r.regOut.forceBusy;
            when x"81" =>
               v.axiReadSlave.rdata(0) := r.regOut.ignoreExtBusyIn;
            when x"82" =>
               v.axiReadSlave.rdata(0) := r.regOut.ignoreFifoFull;
            when x"83" =>
               v.axiReadSlave.rdata(7 downto 0) := r.regOut.presetECR;
            when x"84" =>
               v.axiReadSlave.rdata(0) := r.regOut.pauseECR;
            when x"A0" =>
               if FIFO_FIXED_THES_G = true then
                  v.axiReadSlave.rdata(FIFO_ADDR_WIDTH_G-1 downto 0) := toSlv(FIFO_AFULL_THRES_G, FIFO_ADDR_WIDTH_G);
               else
                  v.axiReadSlave.rdata(FIFO_ADDR_WIDTH_G-1 downto 0) := r.fifoThreshold;
               end if;
            when x"F0" =>
               v.axiReadSlave.rdata(STATUS_SIZE_C-1 downto 0) := r.rollOverEn;
            when x"F1" =>
               v.axiReadSlave.rdata(STATUS_SIZE_C-1 downto 0) := r.irqEn;
            when others =>
               axiReadResp := AXI_ERROR_RESP_G;
         end case;
         -- Send AXI Response
         axiSlaveReadResponse(v.axiReadSlave, axiReadResp);
      end if;

      -- Synchronous Reset
      if axiRst = '1' then
         v                     := REG_INIT_C;
         v.regOut.delayIn.load := '1';
         v.regOut.delayIn.rst  := '1';
         v.regOut.delayIn.data := IDELAY_VALUE_G;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs
      axiReadSlave  <= r.axiReadSlave;
      axiWriteSlave <= r.axiWriteSlave;
      regOut        <= r.regOut;
      cntRst        <= r.cntRst;
      rollOverEn    <= r.rollOverEn;
      irqEn         <= r.irqEn;
      fifoRd        <= r.fifoRd;

   end process comb;

   seq : process (axiClk) is
   begin
      if rising_edge(axiClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   -------------------------------            
   -- Synchronization: Outputs
   -------------------------------     
   SyncOut_locRst : entity work.RstSync
      generic map (
         TPD_G => TPD_G)   
      port map (
         clk      => locClk,
         asyncRst => r.locReset,
         syncRst  => locReset);

   locRst <= locReset;

   SyncOut_rstL1Id : entity work.RstSync
      generic map (
         TPD_G => TPD_G)   
      port map (
         clk      => locClk,
         asyncRst => regOut.rstL1Id,
         syncRst  => config.rstL1Id);         

   SyncOut_configBits : entity work.SynchronizerVector
      generic map (
         TPD_G   => TPD_G,
         WIDTH_G => 4)    
      port map (
         clk        => locClk,
         dataIn(0)  => regOut.forceBusy,
         dataIn(1)  => regOut.serDataEdgeSel,
         dataIn(2)  => regOut.ignoreExtBusyIn,
         dataIn(3)  => regOut.ignoreFifoFull,
         dataOut(0) => config.forceBusy,
         dataOut(1) => config.serDataEdgeSel,
         dataOut(2) => config.ignoreExtBusyIn,
         dataOut(3) => config.ignoreFifoFull);  

   SyncOut_delayIn_data : entity work.SynchronizerFifo
      generic map (
         TPD_G        => TPD_G,
         DATA_WIDTH_G => 5)
      port map (
         wr_clk => axiClk,
         din    => regOut.delayIn.data,
         rd_clk => refClk200MHz,
         dout   => config.delayIn.data);    

   SyncOut_delayIn_load : entity work.RstSync
      generic map (
         TPD_G           => TPD_G,
         RELEASE_DELAY_G => 32)   
      port map (
         clk      => refClk200MHz,
         asyncRst => regOut.delayIn.load,
         syncRst  => config.delayIn.load); 

   SyncOut_delayIn_rst : entity work.RstSync
      generic map (
         TPD_G           => TPD_G,
         RELEASE_DELAY_G => 16)   
      port map (
         clk      => refClk200MHz,
         asyncRst => regOut.delayIn.rst,
         syncRst  => config.delayIn.rst);  

   SyncOut_busyRateRst : entity work.RstSync
      generic map (
         TPD_G => TPD_G)   
      port map (
         clk      => locClk,
         asyncRst => cntRst,
         syncRst  => config.busyRateRst);

   SyncOut_presentECR : entity work.SynchronizerFifo
      generic map (
         TPD_G        => TPD_G,
         DATA_WIDTH_G => 8)
      port map (
         wr_clk => axiClk,
         din    => regOut.presetECR,
         rd_clk => locClk,
         dout   => config.presetECR);

   SyncOut_pauseECR : entity work.Synchronizer
      generic map (
         TPD_G => TPD_G)    
      port map (
         clk     => locClk,
         dataIn  => regOut.pauseECR,
         dataOut => config.pauseECR);          

   -------------------------------
   -- Synchronization: Inputs
   -------------------------------                
   SyncIn_freqMeasured : entity work.SynchronizerFifo
      generic map (
         TPD_G        => TPD_G,
         DATA_WIDTH_G => 32)
      port map (
         wr_clk => locClk,
         din    => status.freqMeasured,
         rd_clk => axiClk,
         dout   => regIn.freqMeasured);  

   SyncIn_busyRate : entity work.SynchronizerFifo
      generic map (
         TPD_G        => TPD_G,
         DATA_WIDTH_G => 32)
      port map (
         wr_clk => locClk,
         din    => status.busyRate,
         rd_clk => axiClk,
         dout   => regIn.busyRate);      

   SyncIn_busyRateCnt : entity work.SynchronizerFifo
      generic map (
         TPD_G        => TPD_G,
         DATA_WIDTH_G => 32)
      port map (
         wr_clk => locClk,
         din    => status.busyRateCnt,
         rd_clk => axiClk,
         dout   => regIn.busyRateCnt);      

   SyncIn_bunchCnt : entity work.SynchronizerFifo
      generic map (
         TPD_G        => TPD_G,
         DATA_WIDTH_G => 12)
      port map (
         wr_clk => locClk,
         din    => status.ttcRx.bunchCnt,
         rd_clk => axiClk,
         dout   => regIn.ttcRx.bunchCnt);

   SyncIn_bunchRstCnt : entity work.SynchronizerFifo
      generic map (
         TPD_G        => TPD_G,
         DATA_WIDTH_G => 8)
      port map (
         wr_clk => locClk,
         din    => status.ttcRx.bunchRstCnt,
         rd_clk => axiClk,
         dout   => regIn.ttcRx.bunchRstCnt);  

   SyncIn_eventCnt : entity work.SynchronizerFifo
      generic map (
         TPD_G        => TPD_G,
         DATA_WIDTH_G => 24)
      port map (
         wr_clk => locClk,
         din    => status.ttcRx.eventCnt,
         rd_clk => axiClk,
         dout   => regIn.ttcRx.eventCnt);

   SyncIn_eventRstCnt : entity work.SynchronizerFifo
      generic map (
         TPD_G        => TPD_G,
         DATA_WIDTH_G => 8)
      port map (
         wr_clk => locClk,
         din    => status.ttcRx.eventRstCnt,
         rd_clk => axiClk,
         dout   => regIn.ttcRx.eventRstCnt);  

   SyncIn_bc : entity work.SynchronizerFifo
      generic map (
         TPD_G        => TPD_G,
         DATA_WIDTH_G => 8)
      port map (
         wr_clk => locClk,
         din    => status.ttcRx.bc.cmdData,
         rd_clk => axiClk,
         dout   => regIn.ttcRx.bc.cmdData);

   SyncIn_debugEC : entity work.SynchronizerFifo
      generic map (
         TPD_G        => TPD_G,
         DATA_WIDTH_G => 24)
      port map (
         wr_clk => locClk,
         din    => status.debugEC,
         rd_clk => axiClk,
         dout   => regIn.debugEC);

   SyncIn_debugECR : entity work.SynchronizerFifo
      generic map (
         TPD_G        => TPD_G,
         DATA_WIDTH_G => 8)
      port map (
         wr_clk => locClk,
         din    => status.debugECR,
         rd_clk => axiClk,
         dout   => regIn.debugECR);          

   SyncIn_iac : entity work.SynchronizerFifo
      generic map (
         TPD_G        => TPD_G,
         DATA_WIDTH_G => 32)
      port map (
         wr_clk             => locClk,
         din(31 downto 18)  => status.ttcRx.iac.addr,
         din(17)            => status.ttcRx.iac.bitE,
         din(16)            => status.ttcRx.iac.reserved,
         din(15 downto 8)   => status.ttcRx.iac.subAddr,
         din(7 downto 0)    => status.ttcRx.iac.data,
         rd_clk             => axiClk,
         dout(31 downto 18) => regIn.ttcRx.iac.addr,
         dout(17)           => regIn.ttcRx.iac.bitE,
         dout(16)           => regIn.ttcRx.iac.reserved,
         dout(15 downto 8)  => regIn.ttcRx.iac.subAddr,
         dout(7 downto 0)   => regIn.ttcRx.iac.data);            

   SyncIn_delayOut_data : entity work.SynchronizerFifo
      generic map (
         TPD_G        => TPD_G,
         DATA_WIDTH_G => 5)
      port map (
         wr_clk => refClk200MHz,
         din    => status.delayOut.data,
         rd_clk => axiClk,
         dout   => regIn.delayOut.data);  

   SyncIn_delayOut_rdy : entity work.Synchronizer
      generic map (
         TPD_G => TPD_G)
      port map (
         clk     => axiClk,
         dataIn  => status.delayOut.rdy,
         dataOut => regIn.delayOut.rdy);

   SyncStatusVec_Inst : entity work.SyncStatusVector
      generic map (
         TPD_G          => TPD_G,
         OUT_POLARITY_G => '1',
         CNT_RST_EDGE_G => true,
         CNT_WIDTH_G    => STATUS_CNT_WIDTH_G,
         WIDTH_G        => STATUS_SIZE_C)     
      port map (
         -- Input Status bit Signals (wrClk domain)
         statusIn(14)  => status.busyIn,
         statusIn(13)  => fifoAlmostFull,
         statusIn(12)  => fifoOverFlow,
         statusIn(11)  => status.ttcRx.ecrDet,
         statusIn(10)  => status.ttcRx.trigL1,
         statusIn(9)   => status.dBitErrIac,
         statusIn(8)   => status.sBitErrIac,
         statusIn(7)   => status.dBitErrBc,
         statusIn(6)   => status.sBitErrBc,
         statusIn(5)   => status.deSerErr,
         statusIn(4)   => status.bpmErr,
         statusIn(3)   => status.bpmLocked,
         statusIn(2)   => status.freqLocked,
         statusIn(1)   => status.clkLocked,
         statusIn(0)   => status.refClkLocked,
         -- Output Status bit Signals (rdClk domain)  
         statusOut(14) => regIn.busyIn,
         statusOut(13) => regIn.fifoAlmostFull,
         statusOut(12) => regIn.fifoOverFlow,
         statusOut(11) => regIn.ttcRx.ecrDet,
         statusOut(10) => regIn.ttcRx.trigL1,
         statusOut(9)  => regIn.dBitErrIac,
         statusOut(8)  => regIn.sBitErrIac,
         statusOut(7)  => regIn.dBitErrBc,
         statusOut(6)  => regIn.sBitErrBc,
         statusOut(5)  => regIn.deSerErr,
         statusOut(4)  => regIn.bpmErr,
         statusOut(3)  => regIn.bpmLocked,
         statusOut(2)  => regIn.freqLocked,
         statusOut(1)  => regIn.clkLocked,
         statusOut(0)  => regIn.refClkLocked,
         -- Status Bit Counters Signals (rdClk domain) 
         cntRstIn      => cntRst,
         rollOverEnIn  => rollOverEn,
         cntOut        => cntOut,
         -- Interrupt Signals (rdClk domain) 
         irqEnIn       => irqEn,
         irqOut        => statusSend,
         -- Clocks and Reset Ports
         wrClk         => locClk,
         rdClk         => axiClk);

   busyInCnt         <= muxSlVectorArray(cntOut, 14);
   fifoAlmostFullCnt <= muxSlVectorArray(cntOut, 13);
   fifoOverFlowCnt   <= muxSlVectorArray(cntOut, 12);
   busyOutCnt        <= muxSlVectorArray(cntOut, 11);
   trigL1Cnt         <= muxSlVectorArray(cntOut, 10);
   dBitErrIacCnt     <= muxSlVectorArray(cntOut, 9);
   sBitErrIacCnt     <= muxSlVectorArray(cntOut, 8);
   dBitErrBcCnt      <= muxSlVectorArray(cntOut, 7);
   sBitErrBcCnt      <= muxSlVectorArray(cntOut, 6);
   deSerErrCnt       <= muxSlVectorArray(cntOut, 5);
   bpmErrCnt         <= muxSlVectorArray(cntOut, 4);
   bpmLockedCnt      <= muxSlVectorArray(cntOut, 3);
   freqLockedCnt     <= muxSlVectorArray(cntOut, 2);
   clkLockedCnt      <= muxSlVectorArray(cntOut, 1);
   refClkLockedCnt   <= muxSlVectorArray(cntOut, 0);

   statusWords(0)(31 downto STATUS_SIZE_C) <= (others => '0');  -- Spare

   statusWords(0)(14) <= regIn.busyIn;
   statusWords(0)(13) <= regIn.fifoAlmostFull;
   statusWords(0)(12) <= regIn.fifoOverFlow;
   statusWords(0)(11) <= regIn.ttcRx.ecrDet;
   statusWords(0)(10) <= regIn.ttcRx.trigL1;
   statusWords(0)(9)  <= regIn.dBitErrIac;
   statusWords(0)(8)  <= regIn.sBitErrIac;
   statusWords(0)(7)  <= regIn.dBitErrBc;
   statusWords(0)(6)  <= regIn.sBitErrBc;
   statusWords(0)(5)  <= regIn.deSerErr;
   statusWords(0)(4)  <= regIn.bpmErr;
   statusWords(0)(3)  <= regIn.bpmLocked;
   statusWords(0)(2)  <= regIn.freqLocked;
   statusWords(0)(1)  <= regIn.clkLocked;
   statusWords(0)(0)  <= regIn.refClkLocked;
   
end rtl;
