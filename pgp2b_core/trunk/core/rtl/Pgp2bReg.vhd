-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : Pgp2bReg.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-05-09
-- Last update: 2014-05-09
-- Platform   : Vivado 2014.1
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2014 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.Pgp2bPkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;

entity Pgp2bReg is
   generic (
      TPD_G              : time                  := 1 ns;
      LANE_CNT_G         : natural range 1 to 2  := 1;      -- Number of lanes, 1-2
      TX_ENABLE_G        : boolean               := true;   -- Enable TX direction
      RX_ENABLE_G        : boolean               := true;   -- Enable RX direction
      COMMON_TX_CLK_G    : boolean               := false;  -- Set to true if axiClk and pgpTxClk are the same clock
      COMMON_RX_CLK_G    : boolean               := false;  -- Set to true if axiClk and pgpRxClk are the same clock
      STATUS_CNT_WIDTH_G : natural range 1 to 32 := 4;
      AXI_ERROR_RESP_G   : slv(1 downto 0)       := AXI_RESP_SLVERR_C);
   port (
      -- PgpTx Interface (pgpTxClk domain)
      pgpTxClk         : in  sl;
      pgpTxRst         : in  sl;
      pgpTxIn          : in  Pgp2bTxInType;
      pgpTxOut         : in  Pgp2bTxOutType;
      pgpTxMasters     : in  AxiStreamMasterArray(3 downto 0);
      pgpTxSlaves      : in  AxiStreamSlaveArray(3 downto 0);
      phyTxReady       : in  sl;
      -- PgpRx Interface (pgpRxClk domain)
      pgpRxClk         : in  sl;
      pgpRxRst         : in  sl;
      pgpRxIn          : in  Pgp2bRxInType;
      pgpRxOut         : in  Pgp2bRxOutType;
      pgpRxMasters     : in  AxiStreamMasterArray(3 downto 0);
      pgpRxMasterMuxed : in  AxiStreamMasterType;
      pgpRxCtrl        : in  AxiStreamCtrlArray(3 downto 0);
      phyRxLanesOut    : in  Pgp2bRxPhyLaneOutArray(0 to LANE_CNT_G-1);
      phyRxLanesIn     : in  Pgp2bRxPhyLaneInArray(0 to LANE_CNT_G-1);
      phyRxReady       : in  sl;
      phyRxInit        : in  sl;
      -- Status Bus (axiClk domain)
      statusWords      : out Slv64Array(0 to 0);
      statusSend       : out sl;
      -- AXI-Lite Register Interface (axiClk domain)
      axiClk           : in  sl;
      axiRst           : in  sl;
      axiReadMaster    : in  AxiLiteReadMasterType;
      axiReadSlave     : out AxiLiteReadSlaveType;
      axiWriteMaster   : in  AxiLiteWriteMasterType;
      axiWriteSlave    : out AxiLiteWriteSlaveType);      
end Pgp2bReg;

architecture rtl of Pgp2bReg is

   constant STATUS_TX_SIZE_C : positive := 17;
   constant STATUS_RX_SIZE_C : positive := 42;

   type RegType is record
      cntRstTx      : sl;
      rollOverEnTx  : slv(STATUS_TX_SIZE_C-1 downto 0);
      irqEnTx       : slv(STATUS_TX_SIZE_C-1 downto 0);
      cntRstRx      : sl;
      rollOverEnRx  : slv(STATUS_RX_SIZE_C-1 downto 0);
      irqEnRx       : slv(STATUS_RX_SIZE_C-1 downto 0);
      axiReadSlave  : AxiLiteReadSlaveType;
      axiWriteSlave : AxiLiteWriteSlaveType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      '1',
      (others => '0'),
      (others => '0'),
      '1',
      (others => '0'),
      (others => '0'),
      AXI_LITE_READ_SLAVE_INIT_C,
      AXI_LITE_WRITE_SLAVE_INIT_C);   

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal statusTx : slv(STATUS_TX_SIZE_C-1 downto 0);
   signal statusRx : slv(STATUS_RX_SIZE_C-1 downto 0);

   signal cntOutTx : SlVectorArray(STATUS_TX_SIZE_C-1 downto 0, STATUS_CNT_WIDTH_G-1 downto 0);
   signal cntOutRx : SlVectorArray(STATUS_RX_SIZE_C-1 downto 0, STATUS_CNT_WIDTH_G-1 downto 0);

   signal statusSendTx,
      statusSendRx : sl;
   
   signal rxLanesOut : Pgp2bRxPhyLaneOutArray(0 to 1);
   signal rxLanesIn  : Pgp2bRxPhyLaneInArray(0 to 1);
   
begin

   -------------------------------
   -- Configuration Register
   -------------------------------  
   comb : process (axiReadMaster, axiRst, axiWriteMaster, cntOutRx, cntOutTx, r, statusRx, statusTx) is
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
      v.cntRstTx := '0';
      v.cntRstRx := '0';

      if (axiStatus.writeEnable = '1') then
         -- Check for an out of 32 bit aligned address
         axiWriteResp := ite(axiWriteMaster.awaddr(1 downto 0) = "00", AXI_RESP_OK_C, AXI_ERROR_RESP_G);
         -- Decode address and perform write
         case (axiWriteMaster.awaddr(9 downto 2)) is
            when x"F0" =>
               v.rollOverEnTx := axiWriteMaster.wdata(STATUS_TX_SIZE_C-1 downto 0);
            when x"F1" =>
               v.irqEnTx := axiWriteMaster.wdata(STATUS_TX_SIZE_C-1 downto 0);
            when x"F2" =>
               v.rollOverEnRx(31 downto 0) := axiWriteMaster.wdata(31 downto 0);
            when x"F3" =>
               v.rollOverEnRx(STATUS_RX_SIZE_C-1 downto 32) := axiWriteMaster.wdata(STATUS_RX_SIZE_C-33 downto 0);
            when x"F4" =>
               v.irqEnRx(31 downto 0) := axiWriteMaster.wdata(31 downto 0);
            when x"F5" =>
               v.irqEnRx(STATUS_RX_SIZE_C-1 downto 32) := axiWriteMaster.wdata(STATUS_RX_SIZE_C-33 downto 0);
            when x"FE" =>
               v.cntRstTx := '1';
            when x"FF" =>
               v.cntRstRx := '1';
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
            when x"70" =>
               v.axiReadSlave.rdata(STATUS_TX_SIZE_C-1 downto 0) := statusTx;
            when x"71" =>
               v.axiReadSlave.rdata(31 downto 0) := statusRx(31 downto 0);
            when x"72" =>
               v.axiReadSlave.rdata(STATUS_RX_SIZE_C-33 downto 0) := statusRx(STATUS_RX_SIZE_C-1 downto 32);
            when x"73" =>
               v.axiReadSlave.rdata := toSlv(LANE_CNT_G, 32);
            when x"74" =>
               v.axiReadSlave.rdata(0) := ite(TX_ENABLE_G, '1', '0');
            when x"75" =>
               v.axiReadSlave.rdata(0) := ite(RX_ENABLE_G, '1', '0');
            when x"76" =>
               v.axiReadSlave.rdata(0) := ite(COMMON_TX_CLK_G, '1', '0');
            when x"77" =>
               v.axiReadSlave.rdata(0) := ite(COMMON_RX_CLK_G, '1', '0');
            when x"78" =>
               v.axiReadSlave.rdata := toSlv(STATUS_CNT_WIDTH_G, 32);
            when x"F0" =>
               v.axiReadSlave.rdata(STATUS_TX_SIZE_C-1 downto 0) := r.rollOverEnTx;
            when x"F1" =>
               v.axiReadSlave.rdata(STATUS_TX_SIZE_C-1 downto 0) := r.irqEnTx;
            when x"F2" =>
               v.axiReadSlave.rdata(31 downto 0) := r.rollOverEnRx(31 downto 0);
            when x"F3" =>
               v.axiReadSlave.rdata(STATUS_RX_SIZE_C-33 downto 0) := r.irqEnRx(STATUS_RX_SIZE_C-1 downto 32);
            when x"F4" =>
               v.axiReadSlave.rdata(31 downto 0) := r.rollOverEnRx(31 downto 0);
            when x"F5" =>
               v.axiReadSlave.rdata(STATUS_RX_SIZE_C-33 downto 0) := r.irqEnRx(STATUS_RX_SIZE_C-1 downto 32);
            when others =>
               -- Check for a TX counter read
               if axiReadMaster.araddr(9 downto 2) < STATUS_TX_SIZE_C then
                  v.axiReadSlave.rdata(STATUS_CNT_WIDTH_G-1 downto 0) := muxSlVectorArray(cntOutTx, conv_integer(axiReadMaster.araddr(9 downto 2)));
               -- Check for a RX counter read
               elsif axiReadMaster.araddr(9 downto 2) < (STATUS_TX_SIZE_C+STATUS_RX_SIZE_C) then
                  v.axiReadSlave.rdata(STATUS_CNT_WIDTH_G-1 downto 0) := muxSlVectorArray(cntOutRx, conv_integer(axiReadMaster.araddr(9 downto 2))-STATUS_TX_SIZE_C);
               -- Invalid address read detected
               else
                  axiReadResp := AXI_ERROR_RESP_G;
               end if;
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

   SyncStatusVec_Tx : entity work.SyncStatusVector
      generic map (
         TPD_G          => TPD_G,
         COMMON_CLK_G   => COMMON_TX_CLK_G,
         CNT_RST_EDGE_G => false,
         CNT_WIDTH_G    => STATUS_CNT_WIDTH_G,
         WIDTH_G        => STATUS_TX_SIZE_C)     
      port map (
         -- Input Status bit Signals (wrClk domain)         
         statusIn(16) => pgpTxIn.flush,
         statusIn(15) => pgpTxIn.opCodeEn,
         statusIn(14) => pgpTxIn.locLinkReady,
         statusIn(13) => pgpTxOut.linkReady,
         statusIn(12) => phyTxReady,
         statusIn(11) => pgpTxMasters(3).tLast,
         statusIn(10) => pgpTxMasters(2).tLast,
         statusIn(9)  => pgpTxMasters(1).tLast,
         statusIn(8)  => pgpTxMasters(0).tLast,
         statusIn(7)  => pgpTxMasters(3).tValid,
         statusIn(6)  => pgpTxMasters(2).tValid,
         statusIn(5)  => pgpTxMasters(1).tValid,
         statusIn(4)  => pgpTxMasters(0).tValid,
         statusIn(3)  => pgpTxSlaves(3).tReady,
         statusIn(2)  => pgpTxSlaves(2).tReady,
         statusIn(1)  => pgpTxSlaves(1).tReady,
         statusIn(0)  => pgpTxSlaves(0).tReady,
         -- Output Status bit Signals (rdClk domain)  
         statusOut    => statusTx,
         -- Status Bit Counters Signals (rdClk domain) 
         cntRstIn     => r.cntRstTx,
         rollOverEnIn => r.rollOverEnTx,
         cntOut       => cntOutTx,
         -- Interrupt Signals (rdClk domain) 
         irqEnIn      => r.irqEnTx,
         irqOut       => statusSendTx,
         -- Clocks and Reset Ports
         wrClk        => pgpTxClk,
         rdClk        => axiClk); 

   SyncStatusVec_Rx : entity work.SyncStatusVector
      generic map (
         TPD_G          => TPD_G,
         COMMON_CLK_G   => COMMON_RX_CLK_G,
         CNT_RST_EDGE_G => false,
         CNT_WIDTH_G    => STATUS_CNT_WIDTH_G,
         WIDTH_G        => STATUS_RX_SIZE_C)     
      port map (
         -- Input Status bit Signals (wrClk domain)         
         statusIn(41) => rxLanesIn(1).decErr(1),
         statusIn(40) => rxLanesIn(0).decErr(1),
         statusIn(39) => rxLanesIn(1).decErr(0),
         statusIn(38) => rxLanesIn(0).decErr(0),
         statusIn(37) => rxLanesIn(1).dispErr(1),
         statusIn(36) => rxLanesIn(0).dispErr(1),
         statusIn(35) => rxLanesIn(1).dispErr(0),
         statusIn(34) => rxLanesIn(0).dispErr(0),
         statusIn(33) => rxLanesOut(1).polarity,
         statusIn(32) => rxLanesOut(0).polarity,
         statusIn(31) => phyRxReady,
         statusIn(30) => phyRxInit,
         statusIn(29) => pgpRxOut.linkReady,
         statusIn(28) => pgpRxOut.cellError,
         statusIn(27) => pgpRxOut.linkDown,
         statusIn(26) => pgpRxOut.linkError,
         statusIn(25) => pgpRxOut.opCodeEn,
         statusIn(24) => pgpRxOut.remLinkReady,
         statusIn(23) => pgpRxOut.remOverFlow(3),
         statusIn(22) => pgpRxOut.remOverFlow(2),
         statusIn(21) => pgpRxOut.remOverFlow(1),
         statusIn(20) => pgpRxOut.remOverFlow(0),
         statusIn(19) => pgpRxIn.flush,
         statusIn(18) => pgpRxIn.resetRx,
         statusIn(17) => pgpRxMasterMuxed.tLast,
         statusIn(16) => pgpRxMasterMuxed.tValid,
         statusIn(15) => pgpRxCtrl(3).pause,
         statusIn(14) => pgpRxCtrl(2).pause,
         statusIn(13) => pgpRxCtrl(1).pause,
         statusIn(12) => pgpRxCtrl(0).pause,
         statusIn(11) => pgpRxCtrl(3).overflow,
         statusIn(10) => pgpRxCtrl(2).overflow,
         statusIn(9)  => pgpRxCtrl(1).overflow,
         statusIn(8)  => pgpRxCtrl(0).overflow,
         statusIn(7)  => pgpRxMasters(3).tLast,
         statusIn(6)  => pgpRxMasters(2).tLast,
         statusIn(5)  => pgpRxMasters(1).tLast,
         statusIn(4)  => pgpRxMasters(0).tLast,
         statusIn(3)  => pgpRxMasters(3).tValid,
         statusIn(2)  => pgpRxMasters(2).tValid,
         statusIn(1)  => pgpRxMasters(1).tValid,
         statusIn(0)  => pgpRxMasters(0).tValid,
         -- Output Status bit Signals (rdClk domain)  
         statusOut    => statusRx,
         -- Status Bit Counters Signals (rdClk domain) 
         cntRstIn     => r.cntRstRx,
         rollOverEnIn => r.rollOverEnRx,
         cntOut       => cntOutRx,
         -- Interrupt Signals (rdClk domain) 
         irqEnIn      => r.irqEnRx,
         irqOut       => statusSendRx,
         -- Clocks and Reset Ports
         wrClk        => pgpRxClk,
         rdClk        => axiClk);          

   rxLanesIn(1).decErr(1) <= phyRxLanesIn(1).decErr(1) when(LANE_CNT_G = 2) else '0';
   rxLanesIn(0).decErr(1) <= phyRxLanesIn(0).decErr(1);

   rxLanesIn(1).decErr(0) <= phyRxLanesIn(1).decErr(0) when(LANE_CNT_G = 2) else '0';
   rxLanesIn(0).decErr(0) <= phyRxLanesIn(0).decErr(0);

   rxLanesIn(1).dispErr(1) <= phyRxLanesIn(1).dispErr(1) when(LANE_CNT_G = 2) else '0';
   rxLanesIn(0).dispErr(1) <= phyRxLanesIn(0).dispErr(1);

   rxLanesIn(1).dispErr(0) <= phyRxLanesIn(1).dispErr(0) when(LANE_CNT_G = 2) else '0';
   rxLanesIn(0).dispErr(0) <= phyRxLanesIn(0).dispErr(0);

   rxLanesOut(1).polarity <= phyRxLanesOut(1).polarity when(LANE_CNT_G = 2) else '0';
   rxLanesOut(0).polarity <= phyRxLanesOut(0).polarity;

   statusSend <= statusSendTx or statusSendRx;

   statusWords(0)((STATUS_TX_SIZE_C-1) downto 0)                                 <= statusTx;
   statusWords(0)((STATUS_TX_SIZE_C+STATUS_RX_SIZE_C-1) downto STATUS_TX_SIZE_C) <= statusRx;
   statusWords(0)(63 downto (STATUS_TX_SIZE_C+STATUS_RX_SIZE_C))                 <= (others => '0');

end rtl;
