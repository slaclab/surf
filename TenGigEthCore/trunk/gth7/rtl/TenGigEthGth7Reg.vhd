-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : TenGigEthGth7Reg.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-02-20
-- Last update: 2015-03-27
-- Platform   : Vivado 2014.3
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
use work.TenGigEthPkg.all;
use work.TenGigEthGth7Pkg.all;

entity TenGigEthGth7Reg is
   generic (
      TPD_G              : time                  := 1 ns;
      MAC_ADDR_G         : slv(47 downto 0)      := TEN_GIG_ETH_MAC_ADDR_INIT_C;
      STATUS_CNT_WIDTH_G : natural range 1 to 32 := 32;
      AXI_ERROR_RESP_G   : slv(1 downto 0)       := AXI_RESP_SLVERR_C);
   port (
      -- Clocks and resets
      clk            : in  sl;
      rst            : in  sl;
      -- AXI-Lite Register Interface
      axiReadMaster  : in  AxiLiteReadMasterType;
      axiReadSlave   : out AxiLiteReadSlaveType;
      axiWriteMaster : in  AxiLiteWriteMasterType;
      axiWriteSlave  : out AxiLiteWriteSlaveType;
      -- Configuration and Status Interface
      config         : out TenGigEthGth7Config;
      status         : in  TenGigEthGth7Status);   
end TenGigEthGth7Reg;

architecture rtl of TenGigEthGth7Reg is

   constant STATUS_SIZE_C : positive := 29;

   type RegType is record
      cntRst        : sl;
      rollOverEn    : slv(STATUS_SIZE_C-1 downto 0);
      config        : TenGigEthGth7Config;
      axiReadSlave  : AxiLiteReadSlaveType;
      axiWriteSlave : AxiLiteWriteSlaveType;
   end record RegType;
   
   constant REG_INIT_C : RegType := (
      cntRst        => '1',
      rollOverEn    => (others => '0'),
      config        => TEN_GIG_ETH_GTH7_CONFIG_INIT_C,
      axiReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
      axiWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal statusOut : slv(STATUS_SIZE_C-1 downto 0);
   signal cntOut    : SlVectorArray(STATUS_SIZE_C-1 downto 0, STATUS_CNT_WIDTH_G-1 downto 0);
   
begin

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
         statusIn(0)  => status.phyReady,
         statusIn(1)  => status.phyStatus.rxPauseReq,
         statusIn(2)  => status.phyStatus.rxPauseSet,
         statusIn(3)  => status.phyStatus.rxCountEn,
         statusIn(4)  => status.phyStatus.rxOverFlow,
         statusIn(5)  => status.phyStatus.rxCrcError,
         statusIn(6)  => status.phyStatus.txCountEn,
         statusIn(7)  => status.phyStatus.txUnderRun,
         statusIn(8)  => status.phyStatus.txLinkNotReady,
         statusIn(9)  => status.txDisable,
         statusIn(10) => status.sigDet,
         statusIn(11) => status.txFault,
         statusIn(12) => status.gtTxRst,
         statusIn(13) => status.gtRxRst,
         statusIn(14) => status.rstCntDone,
         statusIn(15) => status.qplllock,
         statusIn(16) => status.txRstdone,
         statusIn(17) => status.rxRstdone,
         statusIn(18) => status.pma_link_status,
         statusIn(19) => status.rx_sig_det,
         statusIn(20) => status.pcs_rx_link_status,
         statusIn(21) => status.pcs_rx_locked,
         statusIn(22) => status.pcs_hiber,
         statusIn(23) => status.pcs_rx_hiber_lh,
         statusIn(24) => status.pcs_rx_locked_ll,
         statusIn(25) => status.gtEyeScanDataError,
         statusIn(26) => status.gtRxPrbsErr,
         statusIn(27) => status.gtTxResetDone,
         statusIn(28) => status.gtRxResetDone,
         -- Output Status bit Signals (rdClk domain)           
         statusOut    => statusOut,
         -- Status Bit Counters Signals (rdClk domain) 
         cntRstIn     => r.cntRst,
         rollOverEnIn => r.rollOverEn,
         cntOut       => cntOut,
         -- Clocks and Reset Ports
         wrClk        => clk,
         rdClk        => clk);

   -------------------------------
   -- Configuration Register
   -------------------------------  
   comb : process (axiReadMaster, axiWriteMaster, cntOut, r, rst, status, statusOut) is
      variable v            : RegType;
      variable axiStatus    : AxiLiteStatusType;
      variable axiWriteResp : slv(1 downto 0);
      variable axiReadResp  : slv(1 downto 0);
      variable rdPntr       : natural;
   begin
      -- Latch the current value
      v := r;

      -- Determine the transaction type
      axiSlaveWaitTxn(axiWriteMaster, axiReadMaster, v.axiWriteSlave, v.axiReadSlave, axiStatus);

      -- Reset strobe signals
      v.cntRst         := '0';
      v.config.softRst := '0';

      -- Calculate the read pointer
      rdPntr := conv_integer(axiReadMaster.araddr(9 downto 2));

      if (axiStatus.writeEnable = '1') then
         -- Check for an out of 32 bit aligned address
         if axiWriteMaster.awaddr(1 downto 0) /= "00" then
            axiWriteResp := AXI_ERROR_RESP_G;
         else
            axiWriteResp := AXI_RESP_OK_C;
            -- Decode address and perform write
            case (axiWriteMaster.awaddr(9 downto 2)) is
               when x"80" =>
                  v.config.phyConfig.macAddress(31 downto 0) := axiWriteMaster.wdata;
               when x"81" =>
                  v.config.phyConfig.macAddress(47 downto 32) := axiWriteMaster.wdata(15 downto 0);
               when x"82" =>
                  v.config.phyConfig.txPauseTime     := axiWriteMaster.wdata(15 downto 0);
                  v.config.phyConfig.txInterFrameGap := axiWriteMaster.wdata(19 downto 16);
                  v.config.phyConfig.txShift         := axiWriteMaster.wdata(23 downto 20);
                  v.config.phyConfig.rxShift         := axiWriteMaster.wdata(27 downto 24);
                  v.config.phyConfig.txShiftEn       := axiWriteMaster.wdata(29);
                  v.config.phyConfig.rxShiftEn       := axiWriteMaster.wdata(30);
                  v.config.phyConfig.byteSwap        := axiWriteMaster.wdata(31);
               when x"90" =>
                  v.config.timer_ctrl        := axiWriteMaster.wdata(15 downto 0);
                  v.config.pma_pmd_type      := axiWriteMaster.wdata(18 downto 16);
                  v.config.pma_loopback      := axiWriteMaster.wdata(19);
                  v.config.pma_reset         := axiWriteMaster.wdata(20);
                  v.config.global_tx_disable := axiWriteMaster.wdata(21);
                  v.config.pcs_loopback      := axiWriteMaster.wdata(22);
                  v.config.pcs_reset         := axiWriteMaster.wdata(23);
                  v.config.data_patt_sel     := axiWriteMaster.wdata(24);
                  v.config.test_patt_sel     := axiWriteMaster.wdata(25);
                  v.config.tx_test_patt_en   := axiWriteMaster.wdata(26);
                  v.config.rx_test_patt_en   := axiWriteMaster.wdata(27);
                  v.config.prbs31_tx_en      := axiWriteMaster.wdata(28);
                  v.config.prbs31_rx_en      := axiWriteMaster.wdata(29);
               when x"91" =>
                  v.config.set_pma_link_status       := axiWriteMaster.wdata(0);
                  v.config.set_pcs_link_status       := axiWriteMaster.wdata(1);
                  v.config.clear_pcs_status2         := axiWriteMaster.wdata(2);
                  v.config.clear_test_patt_err_count := axiWriteMaster.wdata(3);
               when x"92" =>
                  v.config.test_patt_a_b(31 downto 0) := axiWriteMaster.wdata;
               when x"93" =>
                  v.config.test_patt_a_b(57 downto 32) := axiWriteMaster.wdata(25 downto 0);
               when x"A0" =>
                  v.config.gtTxDiffCtrl     := axiWriteMaster.wdata(3 downto 0);
                  v.config.gtTxPostCursor   := axiWriteMaster.wdata(8 downto 4);
                  v.config.gtTxPreCursor    := axiWriteMaster.wdata(13 downto 9);
                  v.config.gtRxRate         := axiWriteMaster.wdata(16 downto 14);
                  v.config.gtRxlpmen        := axiWriteMaster.wdata(17);
                  v.config.gtRxDfelpmReset  := axiWriteMaster.wdata(18);
                  v.config.gtRxPmaReset     := axiWriteMaster.wdata(19);
                  v.config.gtTxPmaReset     := axiWriteMaster.wdata(20);
                  v.config.gtRxPolarity     := axiWriteMaster.wdata(21);
                  v.config.gtTxPolarity     := axiWriteMaster.wdata(22);
                  v.config.gtTxPrbsForceErr := axiWriteMaster.wdata(23);
                  v.config.gtRxCdrHold      := axiWriteMaster.wdata(24);
                  v.config.gtEyeScanTrigger := axiWriteMaster.wdata(25);
                  v.config.gtEyeScanReset   := axiWriteMaster.wdata(26);
               when x"F0" =>
                  v.rollOverEn := axiWriteMaster.wdata(STATUS_SIZE_C-1 downto 0);
               when x"FD" =>
                  v.cntRst := '1';
               when x"FE" =>
                  v.config.softRst := '1';
               when x"FF" =>
                  v                             := REG_INIT_C;
                  v.config.phyConfig.macAddress := MAC_ADDR_G;
               when others =>
                  axiWriteResp := AXI_ERROR_RESP_G;
            end case;
         end if;
         -- Send AXI response
         axiSlaveWriteResponse(v.axiWriteSlave, axiWriteResp);
      end if;

      if (axiStatus.readEnable = '1') then
         -- Check for an out of 32 bit aligned address
         if axiReadMaster.araddr(1 downto 0) /= "00" then
            axiReadResp := AXI_ERROR_RESP_G;
         else
            axiReadResp          := AXI_RESP_OK_C;
            -- Decode address and assign read data 
            v.axiReadSlave.rdata := (others => '0');
            case (axiReadMaster.araddr(9 downto 2)) is
               when x"40" =>
                  v.axiReadSlave.rdata(STATUS_SIZE_C-1 downto 0) := statusOut;
               when x"7D" =>
                  v.axiReadSlave.rdata(15 downto 0) := status.phyStatus.rxPauseValue;
               when x"7E" =>
                  v.axiReadSlave.rdata(15 downto 0)  := status.pcs_test_patt_err_count;
                  v.axiReadSlave.rdata(23 downto 16) := status.pcs_err_block_count;
                  v.axiReadSlave.rdata(29 downto 24) := status.pcs_ber_count;
               when x"7F" =>
                  v.axiReadSlave.rdata(7 downto 0)   := status.core_status;
                  v.axiReadSlave.rdata(15 downto 8)  := status.gtDmonitorOut;
                  v.axiReadSlave.rdata(17 downto 16) := status.gtTxBufStatus;
                  v.axiReadSlave.rdata(20 downto 18) := status.gtRxBufStatus;
               when X"80" =>
                  v.axiReadSlave.rdata := r.config.phyConfig.macAddress(31 downto 0);
               when X"81" =>
                  v.axiReadSlave.rdata(15 downto 0) := r.config.phyConfig.macAddress(47 downto 32);
               when x"82" =>
                  v.axiReadSlave.rdata(15 downto 0)  := r.config.phyConfig.txPauseTime;
                  v.axiReadSlave.rdata(19 downto 16) := r.config.phyConfig.txInterFrameGap;
                  v.axiReadSlave.rdata(23 downto 20) := r.config.phyConfig.txShift;
                  v.axiReadSlave.rdata(27 downto 24) := r.config.phyConfig.rxShift;
                  v.axiReadSlave.rdata(29)           := r.config.phyConfig.txShiftEn;
                  v.axiReadSlave.rdata(30)           := r.config.phyConfig.rxShiftEn;
                  v.axiReadSlave.rdata(31)           := r.config.phyConfig.byteSwap;
               when x"90" =>
                  v.axiReadSlave.rdata(15 downto 0)  := r.config.timer_ctrl;
                  v.axiReadSlave.rdata(18 downto 16) := r.config.pma_pmd_type;
                  v.axiReadSlave.rdata(19)           := r.config.pma_loopback;
                  v.axiReadSlave.rdata(20)           := r.config.pma_reset;
                  v.axiReadSlave.rdata(21)           := r.config.global_tx_disable;
                  v.axiReadSlave.rdata(22)           := r.config.pcs_loopback;
                  v.axiReadSlave.rdata(23)           := r.config.pcs_reset;
                  v.axiReadSlave.rdata(24)           := r.config.data_patt_sel;
                  v.axiReadSlave.rdata(25)           := r.config.test_patt_sel;
                  v.axiReadSlave.rdata(26)           := r.config.tx_test_patt_en;
                  v.axiReadSlave.rdata(27)           := r.config.rx_test_patt_en;
                  v.axiReadSlave.rdata(28)           := r.config.prbs31_tx_en;
                  v.axiReadSlave.rdata(29)           := r.config.prbs31_rx_en;
               when x"91" =>
                  v.axiReadSlave.rdata(0) := r.config.set_pma_link_status;
                  v.axiReadSlave.rdata(1) := r.config.set_pcs_link_status;
                  v.axiReadSlave.rdata(2) := r.config.clear_pcs_status2;
                  v.axiReadSlave.rdata(3) := r.config.clear_test_patt_err_count;
               when x"92" =>
                  v.axiReadSlave.rdata(31 downto 0) := r.config.test_patt_a_b(31 downto 0);
               when x"93" =>
                  v.axiReadSlave.rdata(25 downto 0) := r.config.test_patt_a_b(57 downto 32);
               when x"A0" =>
                  v.axiReadSlave.rdata(3 downto 0)   := r.config.gtTxDiffCtrl;
                  v.axiReadSlave.rdata(8 downto 4)   := r.config.gtTxPostCursor;
                  v.axiReadSlave.rdata(13 downto 9)  := r.config.gtTxPreCursor;
                  v.axiReadSlave.rdata(16 downto 14) := r.config.gtRxRate;
                  v.axiReadSlave.rdata(17)           := r.config.gtRxlpmen;
                  v.axiReadSlave.rdata(18)           := r.config.gtRxDfelpmReset;
                  v.axiReadSlave.rdata(19)           := r.config.gtRxPmaReset;
                  v.axiReadSlave.rdata(20)           := r.config.gtTxPmaReset;
                  v.axiReadSlave.rdata(21)           := r.config.gtRxPolarity;
                  v.axiReadSlave.rdata(22)           := r.config.gtTxPolarity;
                  v.axiReadSlave.rdata(23)           := r.config.gtTxPrbsForceErr;
                  v.axiReadSlave.rdata(24)           := r.config.gtRxCdrHold;
                  v.axiReadSlave.rdata(25)           := r.config.gtEyeScanTrigger;
                  v.axiReadSlave.rdata(26)           := r.config.gtEyeScanReset;
               when x"F0" =>
                  v.axiReadSlave.rdata(STATUS_SIZE_C-1 downto 0) := r.rollOverEn;
               when others =>
                  if rdPntr < STATUS_SIZE_C then
                     v.axiReadSlave.rdata(STATUS_CNT_WIDTH_G-1 downto 0) := muxSlVectorArray(cntOut, rdPntr);
                  else
                     axiReadResp := AXI_ERROR_RESP_G;
                  end if;
            end case;
         end if;
         -- Send AXI Response
         axiSlaveReadResponse(v.axiReadSlave, axiReadResp);
      end if;

      -- Synchronous Reset
      if rst = '1' then
         v                             := REG_INIT_C;
         v.config.phyConfig.macAddress := MAC_ADDR_G;
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

end rtl;
