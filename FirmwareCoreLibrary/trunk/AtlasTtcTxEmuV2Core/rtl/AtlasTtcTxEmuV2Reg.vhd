-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : AtlasTtcTxEmuV2Reg.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-06-06
-- Last update: 2014-12-12
-- Platform   : Vivado 2014.1
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2014 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.AtlasTtcTxEmuV2Pkg.all;

entity AtlasTtcTxEmuV2Reg is
   generic (
      TPD_G              : time                  := 1 ns;
      STATUS_CNT_WIDTH_G : natural range 1 to 32 := 32;
      AXI_ERROR_RESP_G   : slv(1 downto 0)       := AXI_RESP_SLVERR_C);  
   port (
      -- AXI-Lite Register and Status Bus Interface (sAxiClk domain)
      sAxiClk         : in  sl;
      sAxiRst         : in  sl;
      sAxiReadMaster  : in  AxiLiteReadMasterType;
      sAxiReadSlave   : out AxiLiteReadSlaveType;
      sAxiWriteMaster : in  AxiLiteWriteMasterType;
      sAxiWriteSlave  : out AxiLiteWriteSlaveType;
      statusWords     : out Slv64Array(0 to 0);
      statusSend      : out sl;
      -- Local Interface (clk domain)
      clk             : in  sl;
      rst             : in  sl;
      status          : in  AtlasTtcTxEmuV2StatusType;
      config          : out AtlasTtcTxEmuV2ConfigType);   
end AtlasTtcTxEmuV2Reg;

architecture rtl of AtlasTtcTxEmuV2Reg is

   constant STATUS_SIZE_C : positive := 9;

   type RegType is record
      cntRst        : sl;
      rollOverEn    : slv(STATUS_SIZE_C-1 downto 0);
      irqEn         : slv(STATUS_SIZE_C-1 downto 0);
      config        : AtlasTtcTxEmuV2ConfigType;
      axiReadSlave  : AxiLiteReadSlaveType;
      axiWriteSlave : AxiLiteWriteSlaveType;
   end record RegType;
   
   constant REG_INIT_C : RegType := (
      '1',
      (others => '0'),
      (others => '0'),
      ATLAS_TTC_TX_EMU_V2_CONFIG_INIT_C,
      AXI_LITE_READ_SLAVE_INIT_C,
      AXI_LITE_WRITE_SLAVE_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal cntOut : SlVectorArray(STATUS_SIZE_C-1 downto 0, STATUS_CNT_WIDTH_G-1 downto 0);
   signal busyCnt,
      overflowCntB,
      fullCntB,
      emptyCntB,
      runningCntB,
      overflowCntA,
      fullCntA,
      emptyCntA,
      runningCntA : slv(STATUS_CNT_WIDTH_G-1 downto 0);
   
   signal locStatusWords : Slv64Array(0 to 0) := (others => (others => '0'));
   signal locStatusSend  : sl                 := '0';

   signal axiReadMaster  : AxiLiteReadMasterType;
   signal axiReadSlave   : AxiLiteReadSlaveType;
   signal axiWriteMaster : AxiLiteWriteMasterType;
   signal axiWriteSlave  : AxiLiteWriteSlaveType;
   
begin

   AxiLiteAsync_Inst : entity work.AxiLiteAsync
      generic map (
         TPD_G => TPD_G)
      port map (
         -- Slave Port
         sAxiClk         => sAxiClk,
         sAxiClkRst      => sAxiRst,
         sAxiReadMaster  => sAxiReadMaster,
         sAxiReadSlave   => sAxiReadSlave,
         sAxiWriteMaster => sAxiWriteMaster,
         sAxiWriteSlave  => sAxiWriteSlave,
         -- Master Port
         mAxiClk         => clk,
         mAxiClkRst      => rst,
         mAxiReadMaster  => axiReadMaster,
         mAxiReadSlave   => axiReadSlave,
         mAxiWriteMaster => axiWriteMaster,
         mAxiWriteSlave  => axiWriteSlave);

   SyncFifo_Inst : entity work.SynchronizerFifo
      generic map (
         TPD_G        => TPD_G,
         DATA_WIDTH_G => 64)
      port map (
         -- Write Ports (wr_clk domain)
         wr_clk => clk,
         wr_en  => locStatusSend,
         din    => locStatusWords(0),
         -- Read Ports (rd_clk domain)
         rd_clk => sAxiClk,
         valid  => statusSend,
         dout   => statusWords(0));         

   -------------------------------
   -- Configuration Register
   -------------------------------  
   comb : process (axiReadMaster, axiWriteMaster, busyCnt, emptyCntA, emptyCntB, fullCntA, fullCntB,
                   overflowCntA, overflowCntB, r, rst, runningCntA, runningCntB, status) is
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
      v.cntRst                  := '0';
      v.config.reset            := '0';
      v.config.engineA.wrEn     := '0';
      v.config.engineA.startCmd := '0';
      v.config.engineA.stopCmd  := '0';
      v.config.engineB.wrEn     := '0';
      v.config.engineB.startCmd := '0';
      v.config.engineB.stopCmd  := '0';

      if (axiStatus.writeEnable = '1') then
         -- Check for an out of 32 bit aligned address  
         axiWriteResp := ite(axiWriteMaster.awaddr(1 downto 0) = "00", AXI_RESP_OK_C, AXI_ERROR_RESP_G);
         -- Decode address and perform write
         case (axiWriteMaster.awaddr(9 downto 2)) is
            when x"80" =>
               v.config.engineA.preset := axiWriteMaster.wdata;
            when x"81" =>
               v.config.engineB.preset := axiWriteMaster.wdata;
            when x"82" =>
               v.config.engineA.wrEn := '1';
               v.config.engineA.data := axiWriteMaster.wdata;
            when x"83" =>
               v.config.engineB.wrEn := '1';
               v.config.engineB.data := axiWriteMaster.wdata;
            when x"84" =>
               v.config.engineA.startCmd := axiWriteMaster.wdata(0);
               v.config.engineA.stopCmd  := axiWriteMaster.wdata(1);
               v.config.engineB.startCmd := axiWriteMaster.wdata(2);
               v.config.engineB.stopCmd  := axiWriteMaster.wdata(3);
            when x"F0" =>
               v.rollOverEn := axiWriteMaster.wdata(STATUS_SIZE_C-1 downto 0);
            when x"F1" =>
               v.irqEn := axiWriteMaster.wdata(STATUS_SIZE_C-1 downto 0);
            when x"FD" =>
               v := REG_INIT_C;
            when x"FE" =>
               v.config.reset := '1';
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
               v.axiReadSlave.rdata(STATUS_CNT_WIDTH_G-1 downto 0) := runningCntA;
            when x"01" =>
               v.axiReadSlave.rdata(STATUS_CNT_WIDTH_G-1 downto 0) := emptyCntA;
            when x"02" =>
               v.axiReadSlave.rdata(STATUS_CNT_WIDTH_G-1 downto 0) := fullCntA;
            when x"03" =>
               v.axiReadSlave.rdata(STATUS_CNT_WIDTH_G-1 downto 0) := overflowCntA;
            when x"04" =>
               v.axiReadSlave.rdata(STATUS_CNT_WIDTH_G-1 downto 0) := runningCntB;
            when x"05" =>
               v.axiReadSlave.rdata(STATUS_CNT_WIDTH_G-1 downto 0) := emptyCntB;
            when x"06" =>
               v.axiReadSlave.rdata(STATUS_CNT_WIDTH_G-1 downto 0) := fullCntB;
            when x"07" =>
               v.axiReadSlave.rdata(STATUS_CNT_WIDTH_G-1 downto 0) := overflowCntB;
            when x"08" =>
               v.axiReadSlave.rdata(STATUS_CNT_WIDTH_G-1 downto 0) := busyCnt;
            when x"40" =>
               v.axiReadSlave.rdata(8) := status.busy;
               v.axiReadSlave.rdata(7) := status.engineB.overflow;
               v.axiReadSlave.rdata(6) := status.engineB.full;
               v.axiReadSlave.rdata(5) := status.engineB.empty;
               v.axiReadSlave.rdata(4) := status.engineB.running;
               v.axiReadSlave.rdata(3) := status.engineA.overflow;
               v.axiReadSlave.rdata(2) := status.engineA.full;
               v.axiReadSlave.rdata(1) := status.engineA.empty;
               v.axiReadSlave.rdata(0) := status.engineA.running;
            when x"80" =>
               v.axiReadSlave.rdata := r.config.engineA.preset;
            when x"81" =>
               v.axiReadSlave.rdata := r.config.engineB.preset;
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
      if rst = '1' then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs
      axiReadSlave  <= r.axiReadSlave;
      axiWriteSlave <= r.axiWriteSlave;
      config        <= r.config;

   end process comb;

   seq : process (clk) is
   begin
      if rising_edge(clk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   SyncStatusVec_Inst : entity work.SyncStatusVector
      generic map (
         TPD_G          => TPD_G,
         OUT_POLARITY_G => '1',
         CNT_RST_EDGE_G => false,
         COMMON_CLK_G   => true,
         CNT_WIDTH_G    => STATUS_CNT_WIDTH_G,
         WIDTH_G        => STATUS_SIZE_C)     
      port map (
         -- Input Status bit Signals (wrClk domain)
         statusIn(0)  => status.engineA.running,
         statusIn(1)  => status.engineA.empty,
         statusIn(2)  => status.engineA.full,
         statusIn(3)  => status.engineA.overflow,
         statusIn(4)  => status.engineB.running,
         statusIn(5)  => status.engineB.empty,
         statusIn(6)  => status.engineB.full,
         statusIn(7)  => status.engineB.overflow,
         statusIn(8)  => status.busy,
         -- Status Bit Counters Signals (rdClk domain) 
         cntRstIn     => r.cntRst,
         rollOverEnIn => r.rollOverEn,
         cntOut       => cntOut,
         -- Interrupt Signals (rdClk domain) 
         irqEnIn      => r.irqEn,
         irqOut       => locStatusSend,
         -- Clocks and Reset Ports
         wrClk        => clk,
         rdClk        => clk); 

   busyCnt      <= muxSlVectorArray(cntOut, 8);
   overflowCntB <= muxSlVectorArray(cntOut, 7);
   fullCntB     <= muxSlVectorArray(cntOut, 6);
   emptyCntB    <= muxSlVectorArray(cntOut, 5);
   runningCntB  <= muxSlVectorArray(cntOut, 4);
   overflowCntA <= muxSlVectorArray(cntOut, 3);
   fullCntA     <= muxSlVectorArray(cntOut, 2);
   emptyCntA    <= muxSlVectorArray(cntOut, 1);
   runningCntA  <= muxSlVectorArray(cntOut, 0);

   -- Spare
   locStatusWords(0)(63 downto STATUS_SIZE_C) <= (others => '0');

   locStatusWords(0)(8) <= status.busy;
   locStatusWords(0)(7) <= status.engineB.overflow;
   locStatusWords(0)(6) <= status.engineB.full;
   locStatusWords(0)(5) <= status.engineB.empty;
   locStatusWords(0)(4) <= status.engineB.running;
   locStatusWords(0)(3) <= status.engineA.overflow;
   locStatusWords(0)(2) <= status.engineA.full;
   locStatusWords(0)(1) <= status.engineA.empty;
   locStatusWords(0)(0) <= status.engineA.running;

end rtl;
