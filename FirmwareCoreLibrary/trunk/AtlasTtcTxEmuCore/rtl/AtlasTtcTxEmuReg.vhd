-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : AtlasTtcTxEmuReg.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-06-06
-- Last update: 2014-08-07
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
use work.AtlasTtcTxEmuPkg.all;

entity AtlasTtcTxEmuReg is
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
      status          : in  AtlasTtcTxEmuStatusType;
      config          : out AtlasTtcTxEmuConfigType);   
end AtlasTtcTxEmuReg;

architecture rtl of AtlasTtcTxEmuReg is

   constant STATUS_SIZE_C : positive := 1;

   type RegType is record
      cntRst        : sl;
      rollOverEn    : slv(STATUS_SIZE_C-1 downto 0);
      irqEn         : slv(STATUS_SIZE_C-1 downto 0);
      config        : AtlasTtcTxEmuConfigType;
      axiReadSlave  : AxiLiteReadSlaveType;
      axiWriteSlave : AxiLiteWriteSlaveType;
   end record RegType;
   
   constant REG_INIT_C : RegType := (
      '1',
      (others => '0'),
      (others => '0'),
      ATLAS_TTC_TX_EMU_CONFIG_INIT_C,
      AXI_LITE_READ_SLAVE_INIT_C,
      AXI_LITE_WRITE_SLAVE_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal cntOut  : SlVectorArray(STATUS_SIZE_C-1 downto 0, STATUS_CNT_WIDTH_G-1 downto 0);
   signal busyCnt : slv(STATUS_CNT_WIDTH_G-1 downto 0);

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
   comb : process (axiReadMaster, axiWriteMaster, busyCnt, r, rst, status) is
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
      v.config.rstCnt   := "000";
      v.cntRst          := '0';
      v.config.iacValid := '0';
      v.config.burstRst := '0';

      if (axiStatus.writeEnable = '1') then
         -- Check for an out of 32 bit aligned address
         axiWriteResp := ite(axiWriteMaster.awaddr(1 downto 0) = "00", AXI_RESP_OK_C, AXI_ERROR_RESP_G);
         -- Decode address and perform write
         case (axiWriteMaster.awaddr(9 downto 2)) is
            when x"80" =>
               v.config.rstCnt(0)  := '1';
               v.config.trigPeriod := axiWriteMaster.wdata;
            when x"81" =>
               v.config.rstCnt(1) := '1';
               v.config.ecrPeriod := axiWriteMaster.wdata;
            when x"82" =>
               v.config.rstCnt(2) := '1';
               v.config.bcrPeriod := axiWriteMaster.wdata;
            when x"83" =>
               v.config.enbleContinousMode := axiWriteMaster.wdata(0);
            when x"84" =>
               v.config.enbleBurstMode := axiWriteMaster.wdata(0);
               v.config.burstRst       := axiWriteMaster.wdata(0);
            when x"90" =>
               if (axiWriteMaster.wdata /= r.config.trigBurstCnt) then
                  v.config.trigBurstCnt   := axiWriteMaster.wdata;
                  v.config.burstRst       := '1';
                  v.config.enbleBurstMode := '0';
               end if;
            when x"91" =>
               if (axiWriteMaster.wdata /= r.config.ecrBurstCnt) then
                  v.config.ecrBurstCnt    := axiWriteMaster.wdata;
                  v.config.burstRst       := '1';
                  v.config.enbleBurstMode := '0';
               end if;
            when x"92" =>
               if (axiWriteMaster.wdata /= r.config.bcrBurstCnt) then
                  v.config.bcrBurstCnt    := axiWriteMaster.wdata;
                  v.config.burstRst       := '1';
                  v.config.enbleBurstMode := '0';
               end if;
            when x"F0" =>
               v.rollOverEn := axiWriteMaster.wdata(STATUS_SIZE_C-1 downto 0);
            when x"F1" =>
               v.irqEn := axiWriteMaster.wdata(STATUS_SIZE_C-1 downto 0);
            when x"F2" =>
               v.config.iacValid := '1';
               v.config.iacData  := axiWriteMaster.wdata;
            when x"FD" =>
               v := REG_INIT_C;
            when x"FE" =>
               v.config.rstCnt := "111";
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
               v.axiReadSlave.rdata(STATUS_CNT_WIDTH_G-1 downto 0) := busyCnt;
            when x"40" =>
               v.axiReadSlave.rdata(0) := status.busy;
            when x"70" =>
               v.axiReadSlave.rdata := status.trigBurstCnt;
            when x"71" =>
               v.axiReadSlave.rdata := status.ecrBurstCnt;
            when x"72" =>
               v.axiReadSlave.rdata := status.bcrBurstCnt;
            when x"80" =>
               v.axiReadSlave.rdata := r.config.trigPeriod;
            when x"81" =>
               v.axiReadSlave.rdata := r.config.ecrPeriod;
            when x"82" =>
               v.axiReadSlave.rdata := r.config.bcrPeriod;
            when x"83" =>
               v.axiReadSlave.rdata(0) := r.config.enbleContinousMode;
            when x"84" =>
               v.axiReadSlave.rdata(0) := r.config.enbleBurstMode;
            when x"90" =>
               v.axiReadSlave.rdata := r.config.trigBurstCnt;
            when x"91" =>
               v.axiReadSlave.rdata := r.config.ecrBurstCnt;
            when x"92" =>
               v.axiReadSlave.rdata := r.config.bcrBurstCnt;
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
         statusIn(0)  => status.busy,
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

   busyCnt <= muxSlVectorArray(cntOut, 0);

   -- Spare
   locStatusWords(0)(63 downto STATUS_SIZE_C) <= (others => '0');

   locStatusWords(0)(0) <= status.busy;
   
end rtl;
