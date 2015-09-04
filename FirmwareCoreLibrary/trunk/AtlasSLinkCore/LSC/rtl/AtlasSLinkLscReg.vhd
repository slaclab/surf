-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : AtlasSLinkLscReg.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-04-10
-- Last update: 2015-04-24
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2015 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.AtlasSLinkLscPkg.all;

entity AtlasSLinkLscReg is
   generic (
      TPD_G              : time                  := 1 ns;
      STATUS_CNT_WIDTH_G : natural range 1 to 32 := 32;
      AXI_ERROR_RESP_G   : slv(1 downto 0)       := AXI_RESP_SLVERR_C);
   port (
      -- AXI-Lite Register Interface (axiClk domain)
      axiClk         : in  sl;
      axiRst         : in  sl;
      axiReadMaster  : in  AxiLiteReadMasterType;
      axiReadSlave   : out AxiLiteReadSlaveType;
      axiWriteMaster : in  AxiLiteWriteMasterType;
      axiWriteSlave  : out AxiLiteWriteSlaveType;
      statusWords    : out Slv64Array(0 to 0);
      statusSend     : out sl;
      -- Register Inputs/Outputs (gLinkTxClk/gLinkRxClk domain)
      sysClk         : in  sl;
      sysRst         : in  sl;
      config         : out AtlasSLinkLscConfigType;
      status         : in  AtlasSLinkLscStatusType);
end AtlasSLinkLscReg;

architecture rtl of AtlasSLinkLscReg is
   
   constant STATUS_SIZE_C : positive := 10;

   type RegType is record
      cntRst        : sl;
      rollOverEn    : slv(STATUS_SIZE_C-1 downto 0);
      irqEn         : slv(STATUS_SIZE_C-1 downto 0);
      regOut        : AtlasSLinkLscConfigType;
      axiReadSlave  : AxiLiteReadSlaveType;
      axiWriteSlave : AxiLiteWriteSlaveType;
   end record RegType;
   
   constant REG_INIT_C : RegType := (
      '1',
      (others => '0'),
      (others => '0'),
      ATLAS_SLINK_CONFIG_INIT_C,
      AXI_LITE_READ_SLAVE_INIT_C,
      AXI_LITE_WRITE_SLAVE_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal regIn : AtlasSLinkLscStatusType;

   signal cntOut : SlVectorArray(STATUS_SIZE_C-1 downto 0, STATUS_CNT_WIDTH_G-1 downto 0);
   signal xorCheckCnt,
      linkActiveCnt,
      flowCtrlCnt,
      overflowCnt,
      testModeCnt,
      linkFullCnt,
      packetSentCnt,
      linkUpCnt,
      linkDownCnt,
      gtxReadyCnt : slv(STATUS_CNT_WIDTH_G-1 downto 0);
   
begin

   -------------------------------
   -- Configuration Register
   -------------------------------  
   comb : process (axiReadMaster, axiRst, axiWriteMaster, flowCtrlCnt, gtxReadyCnt, linkActiveCnt,
                   linkDownCnt, linkFullCnt, linkUpCnt, overflowCnt, packetSentCnt, r, regIn,
                   testModeCnt, xorCheckCnt) is
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
      v.cntRst         := '0';
      v.regOut.userRst := '0';

      if (axiStatus.writeEnable = '1') then
         -- Check for an out of 32 bit aligned address
         axiWriteResp := ite(axiWriteMaster.awaddr(1 downto 0) = "00", AXI_RESP_OK_C, AXI_ERROR_RESP_G);
         -- Decode address and perform write
         case (axiWriteMaster.awaddr(9 downto 2)) is
            when x"82" =>
               v.regOut.blowOff := axiWriteMaster.wdata(0);
            when x"83" =>
               v.regOut.blowOffMask := axiWriteMaster.wdata;
            when x"F0" =>
               v.rollOverEn := axiWriteMaster.wdata(STATUS_SIZE_C-1 downto 0);
            when x"F1" =>
               v.irqEn := axiWriteMaster.wdata(STATUS_SIZE_C-1 downto 0);
            when x"FD" =>
               v := REG_INIT_C;
            when x"FE" =>
               v.regOut.userRst := '1';
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

         -- Decode address and perform read
         case (axiReadMaster.araddr(9 downto 2)) is
            when x"00" =>
               v.axiReadSlave.rdata(STATUS_CNT_WIDTH_G-1 downto 0) := gtxReadyCnt;
            when x"01" =>
               v.axiReadSlave.rdata(STATUS_CNT_WIDTH_G-1 downto 0) := linkDownCnt;
            when x"02" =>
               v.axiReadSlave.rdata(STATUS_CNT_WIDTH_G-1 downto 0) := linkUpCnt;
            when x"03" =>
               v.axiReadSlave.rdata(STATUS_CNT_WIDTH_G-1 downto 0) := linkFullCnt;
            when x"04" =>
               v.axiReadSlave.rdata(STATUS_CNT_WIDTH_G-1 downto 0) := packetSentCnt;
            when x"05" =>
               v.axiReadSlave.rdata(STATUS_CNT_WIDTH_G-1 downto 0) := testModeCnt;
            when x"06" =>
               v.axiReadSlave.rdata(STATUS_CNT_WIDTH_G-1 downto 0) := overflowCnt;
            when x"07" =>
               v.axiReadSlave.rdata(STATUS_CNT_WIDTH_G-1 downto 0) := flowCtrlCnt;
            when x"08" =>
               v.axiReadSlave.rdata(STATUS_CNT_WIDTH_G-1 downto 0) := linkActiveCnt;
            when x"09" =>
               v.axiReadSlave.rdata(STATUS_CNT_WIDTH_G-1 downto 0) := xorCheckCnt;
            when x"40" =>
               v.axiReadSlave.rdata(9) := regIn.xorCheck;
               v.axiReadSlave.rdata(8) := regIn.linkActive;
               v.axiReadSlave.rdata(7) := regIn.flowCtrl;
               v.axiReadSlave.rdata(6) := regIn.overflow;
               v.axiReadSlave.rdata(5) := regIn.testMode;
               v.axiReadSlave.rdata(4) := regIn.packetSent;
               v.axiReadSlave.rdata(3) := regIn.linkFull;
               v.axiReadSlave.rdata(2) := regIn.linkUp;
               v.axiReadSlave.rdata(1) := regIn.linkDown;
               v.axiReadSlave.rdata(0) := regIn.gtxReady;
            when x"79" =>
               v.axiReadSlave.rdata := regIn.dmaSize;
            when x"7A" =>
               v.axiReadSlave.rdata := regIn.dmaMaxSize;
            when x"7B" =>
               v.axiReadSlave.rdata := regIn.dmaMinSize;
            when x"7C" =>
               v.axiReadSlave.rdata := regIn.pktCnt;
            when x"7D" =>
               v.axiReadSlave.rdata := regIn.pktCntMax;
            when x"7E" =>
               v.axiReadSlave.rdata := regIn.pktCntMin;
            when x"7F" =>
               v.axiReadSlave.rdata := regIn.fullRate;
            when x"80" =>
               v.axiReadSlave.rdata := r.regOut.startCmd;
            when x"81" =>
               v.axiReadSlave.rdata := r.regOut.stopCmd;
            when x"82" =>
               v.axiReadSlave.rdata(0) := r.regOut.blowOff;
            when x"83" =>
               v.axiReadSlave.rdata := r.regOut.blowOffMask;
            -- when x"E0" =>
            -- v.axiReadSlave.rdata := regIn.debug(0);
            when x"F0" =>
               v.axiReadSlave.rdata(STATUS_SIZE_C-1 downto 0) := r.rollOverEn;
            when x"F1" =>
               v.axiReadSlave.rdata(STATUS_SIZE_C-1 downto 0) := r.irqEn;
            when others =>
               axiReadResp := AXI_ERROR_RESP_G;
         end case;
         -- Send Axi Response
         axiSlaveReadResponse(v.axiReadSlave, axiReadResp);
      end if;

      -- Synchronous Reset
      if axiRst = '1' then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs
      axiReadSlave  <= r.axiReadSlave;
      axiWriteSlave <= r.axiWriteSlave;
      
   end process comb;

   seq : process (axiClk) is
   begin
      if rising_edge(axiClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   GEN_QUEUE :
   for i in 0 to 0 generate
      
      SyncIn_debug : entity work.SynchronizerFifo
         generic map (
            TPD_G        => TPD_G,
            DATA_WIDTH_G => 32)
         port map (
            wr_clk => sysClk,
            din    => status.debug(i),
            rd_clk => axiClk,
            dout   => regIn.debug(i));     

   end generate GEN_QUEUE;

   SyncIn_blowOffMask : entity work.SynchronizerVector
      generic map (
         TPD_G   => TPD_G,
         WIDTH_G => 32)
      port map (
         clk     => sysClk,
         dataIn  => r.regOut.blowOffMask,
         dataOut => config.blowOffMask);     

   SyncIn_startCmd : entity work.SynchronizerVector
      generic map (
         TPD_G   => TPD_G,
         WIDTH_G => 32)
      port map (
         clk     => sysClk,
         dataIn  => r.regOut.startCmd,
         dataOut => config.startCmd);            

   SyncIn_stopCmd : entity work.SynchronizerVector
      generic map (
         TPD_G   => TPD_G,
         WIDTH_G => 32)
      port map (
         clk     => sysClk,
         dataIn  => r.regOut.stopCmd,
         dataOut => config.stopCmd);          

   SyncOut_usrRst : entity work.RstSync
      generic map (
         TPD_G => TPD_G)   
      port map (
         clk      => sysClk,
         asyncRst => r.regOut.userRst,
         syncRst  => config.userRst); 

   SyncOut_blowOff : entity work.Synchronizer
      generic map (
         TPD_G => TPD_G)   
      port map (
         clk     => sysClk,
         dataIn  => r.regOut.blowOff,
         dataOut => config.blowOff);             

   SyncIn_fullRate : entity work.SynchronizerFifo
      generic map (
         TPD_G        => TPD_G,
         DATA_WIDTH_G => 32)
      port map (
         wr_clk => sysClk,
         din    => status.fullRate,
         rd_clk => axiClk,
         dout   => regIn.fullRate); 

   SyncIn_pktCnt : entity work.SynchronizerFifo
      generic map (
         TPD_G        => TPD_G,
         DATA_WIDTH_G => 32)
      port map (
         wr_clk => sysClk,
         din    => status.pktCnt,
         rd_clk => axiClk,
         dout   => regIn.pktCnt); 

   SyncIn_pktCntMax : entity work.SynchronizerFifo
      generic map (
         TPD_G        => TPD_G,
         DATA_WIDTH_G => 32)
      port map (
         wr_clk => sysClk,
         din    => status.pktCntMax,
         rd_clk => axiClk,
         dout   => regIn.pktCntMax); 

   SyncIn_pktCntMin : entity work.SynchronizerFifo
      generic map (
         TPD_G        => TPD_G,
         DATA_WIDTH_G => 32)
      port map (
         wr_clk => sysClk,
         din    => status.pktCntMin,
         rd_clk => axiClk,
         dout   => regIn.pktCntMin);     

   SyncIn_dmaSize : entity work.SynchronizerFifo
      generic map (
         TPD_G        => TPD_G,
         DATA_WIDTH_G => 32)
      port map (
         wr_clk => sysClk,
         din    => status.dmaSize,
         rd_clk => axiClk,
         dout   => regIn.dmaSize); 

   SyncIn_dmaMaxSize : entity work.SynchronizerFifo
      generic map (
         TPD_G        => TPD_G,
         DATA_WIDTH_G => 32)
      port map (
         wr_clk => sysClk,
         din    => status.dmaMaxSize,
         rd_clk => axiClk,
         dout   => regIn.dmaMaxSize); 

   SyncIn_dmaMinSize : entity work.SynchronizerFifo
      generic map (
         TPD_G        => TPD_G,
         DATA_WIDTH_G => 32)
      port map (
         wr_clk => sysClk,
         din    => status.dmaMinSize,
         rd_clk => axiClk,
         dout   => regIn.dmaMinSize);              

   SyncStatusVec_Inst : entity work.SyncStatusVector
      generic map (
         TPD_G          => TPD_G,
         OUT_POLARITY_G => '1',
         CNT_RST_EDGE_G => true,
         CNT_WIDTH_G    => STATUS_CNT_WIDTH_G,
         WIDTH_G        => STATUS_SIZE_C)     
      port map (
         -- Input Status bit Signals (wrClk domain)
         statusIn(9)  => status.xorCheck,
         statusIn(8)  => status.linkActive,
         statusIn(7)  => status.flowCtrl,
         statusIn(6)  => status.overflow,
         statusIn(5)  => status.testMode,
         statusIn(4)  => status.packetSent,
         statusIn(3)  => status.linkFull,
         statusIn(2)  => status.linkUp,
         statusIn(1)  => status.linkDown,
         statusIn(0)  => status.gtxReady,
         -- Output Status bit Signals (rdClk domain)  
         statusOut(9) => regIn.xorCheck,
         statusOut(8) => regIn.linkActive,
         statusOut(7) => regIn.flowCtrl,
         statusOut(6) => regIn.overflow,
         statusOut(5) => regIn.testMode,
         statusOut(4) => regIn.packetSent,
         statusOut(3) => regIn.linkFull,
         statusOut(2) => regIn.linkUp,
         statusOut(1) => regIn.linkDown,
         statusOut(0) => regIn.gtxReady,
         -- Status Bit Counters Signals (rdClk domain) 
         cntRstIn     => r.cntRst,
         rollOverEnIn => r.rollOverEn,
         cntOut       => cntOut,
         -- Interrupt Signals (rdClk domain) 
         irqEnIn      => r.irqEn,
         irqOut       => statusSend,
         -- Clocks and Reset Ports
         wrClk        => sysClk,
         rdClk        => axiClk); 

   xorCheckCnt   <= muxSlVectorArray(cntOut, 9);
   linkActiveCnt <= muxSlVectorArray(cntOut, 8);
   flowCtrlCnt   <= muxSlVectorArray(cntOut, 7);
   overflowCnt   <= muxSlVectorArray(cntOut, 6);
   testModeCnt   <= muxSlVectorArray(cntOut, 5);
   packetSentCnt <= muxSlVectorArray(cntOut, 4);
   linkFullCnt   <= muxSlVectorArray(cntOut, 3);
   linkUpCnt     <= muxSlVectorArray(cntOut, 2);
   linkDownCnt   <= muxSlVectorArray(cntOut, 1);
   gtxReadyCnt   <= muxSlVectorArray(cntOut, 0);

   -- Spare
   statusWords(0)(63 downto STATUS_SIZE_C) <= (others => '0');

   statusWords(0)(9) <= regIn.xorCheck;
   statusWords(0)(8) <= regIn.linkActive;
   statusWords(0)(7) <= regIn.flowCtrl;
   statusWords(0)(6) <= regIn.overflow;
   statusWords(0)(5) <= regIn.testMode;
   statusWords(0)(4) <= regIn.packetSent;
   statusWords(0)(3) <= regIn.linkFull;
   statusWords(0)(2) <= regIn.linkUp;
   statusWords(0)(1) <= regIn.linkDown;
   statusWords(0)(0) <= regIn.gtxReady;
   
end rtl;
