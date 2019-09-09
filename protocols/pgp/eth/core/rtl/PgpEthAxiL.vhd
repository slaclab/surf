-------------------------------------------------------------------------------
-- File       : Pgp2bAxi.vhd
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
-- AXI-Lite block to manage the PGP_ETH interface.
--
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
use IEEE.STD_LOGIC_ARITH.all;
use IEEE.STD_LOGIC_UNSIGNED.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.PgpEthPkg.all;

entity PgpEthAxiL is
   generic (
      TPD_G            : time                  := 1 ns;
      WRITE_EN_G       : boolean               := false;  -- Set to false when on remote end of a link
      AXIL_CLK_FREQ_G  : real                  := 156.25E+6;
      RX_POLARITY_G    : slv(9 downto 0)       := (others => '0');
      TX_POLARITY_G    : slv(9 downto 0)       := (others => '0');
      TX_DIFF_CTRL_G   : Slv5Array(9 downto 0) := (others => "11000");
      TX_PRE_CURSOR_G  : Slv5Array(9 downto 0) := (others => "00000");
      TX_POST_CURSOR_G : Slv5Array(9 downto 0) := (others => "00000"));
   port (
      -- Clock and Reset
      pgpClk          : in  sl;
      pgpRst          : in  sl;
      -- Tx User interface (pgpClk domain)
      pgpTxIn         : out PgpEthTxInType;
      pgpTxOut        : in  PgpEthTxOutType;
      locTxIn         : in  PgpEthTxInType := PGP_ETH_TX_IN_INIT_C;
      -- RX PGP Interface (pgpClk domain)
      pgpRxIn         : out PgpEthRxInType;
      pgpRxOut        : in  PgpEthRxOutType;
      locRxIn         : in  PgpEthRxInType := PGP_ETH_RX_IN_INIT_C;
      -- Ethernet Configuration
      remoteMac       : in  slv(47 downto 0);
      localMac        : in  slv(47 downto 0);
      broadcastMac    : out slv(47 downto 0);
      etherType       : out slv(15 downto 0);
      -- Misc Debug Interfaces
      loopback        : out slv(2 downto 0);
      rxPolarity      : out slv(9 downto 0);
      txPolarity      : out slv(9 downto 0);
      txDiffCtrl      : out Slv5Array(9 downto 0);
      txPreCursor     : out Slv5Array(9 downto 0);
      txPostCursor    : out Slv5Array(9 downto 0);
      -- AXI-Lite Register Interface (axilClk domain)
      axilClk         : in  sl;
      axilRst         : in  sl;
      axilReadMaster  : in  AxiLiteReadMasterType;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType;
      axilWriteSlave  : out AxiLiteWriteSlaveType);
end PgpEthAxiL;

architecture rtl of PgpEthAxiL is

   constant STATUS_SIZE_C      : positive := 60;
   constant STATUS_CNT_WIDTH_C : positive := 12;

   type RegType is record
      cntRst         : sl;
      rollOverEn     : slv(STATUS_SIZE_C-1 downto 0);
      broadcastMac   : slv(47 downto 0);
      etherType      : slv(15 downto 0);
      loopback       : slv(2 downto 0);
      rxPolarity     : slv(9 downto 0);
      txPolarity     : slv(9 downto 0);
      txDiffCtrl     : Slv5Array(9 downto 0);
      txPreCursor    : Slv5Array(9 downto 0);
      txPostCursor   : Slv5Array(9 downto 0);
      pgpTxIn        : PgpEthTxInType;
      pgpRxIn        : PgpEthRxInType;
      axilWriteSlave : AxiLiteWriteSlaveType;
      axilReadSlave  : AxiLiteReadSlaveType;
   end record RegType;
   constant REG_INIT_C : RegType := (
      cntRst         => '0',
      rollOverEn     => x"3FA_FFFF_0000_0000",
      broadcastMac   => x"FF_FF_FF_FF_FF_FF",
      etherType      => x"11_01",       -- EtherType = 0x0111 ("Experimental")
      loopBack       => (others => '0'),
      rxPolarity     => RX_POLARITY_G,
      txPolarity     => TX_POLARITY_G,
      txDiffCtrl     => TX_DIFF_CTRL_G,
      txPreCursor    => TX_PRE_CURSOR_G,
      txPostCursor   => TX_POST_CURSOR_G,
      pgpTxIn        => PGP_ETH_TX_IN_INIT_C,
      pgpRxIn        => PGP_ETH_RX_IN_INIT_C,
      axilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C,
      axilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal freqMeasured : slv(31 downto 0);

   signal statusOut : slv(STATUS_SIZE_C-1 downto 0);
   signal statusCnt : SlVectorArray(STATUS_SIZE_C-1 downto 0, STATUS_CNT_WIDTH_C-1 downto 0);

   signal syncTxIn : PgpEthTxInType;

begin

   U_ClockFreq : entity work.SyncClockFreq
      generic map (
         TPD_G          => TPD_G,
         REF_CLK_FREQ_G => AXIL_CLK_FREQ_G,
         CNT_WIDTH_G    => 32)
      port map (
         freqOut => freqMeasured,
         -- Clocks
         clkIn   => pgpClk,
         locClk  => axilClk,
         refClk  => axilClk);

   U_SyncStatusVector : entity work.SyncStatusVector
      generic map (
         TPD_G          => TPD_G,
         OUT_POLARITY_G => '1',
         CNT_RST_EDGE_G => true,
         CNT_WIDTH_G    => STATUS_CNT_WIDTH_C,
         WIDTH_G        => STATUS_SIZE_C)
      port map (
         -- Input Status bit Signals (wrClk domain)
         statusIn(59)           => pgpRxOut.opCodeEn,
         statusIn(58)           => pgpTxOut.opCodeReady,
         statusIn(57)           => pgpRxOut.remRxLinkReady,
         statusIn(56)           => pgpRxOut.linkDown,
         statusIn(55)           => pgpRxOut.linkReady,
         statusIn(54)           => pgpTxOut.linkReady,
         statusIn(53)           => pgpRxOut.phyRxActive,
         statusIn(52)           => pgpTxOut.phyTxActive,
         statusIn(51)           => pgpRxOut.frameRxErr,
         statusIn(50)           => pgpRxOut.frameRx,
         statusIn(49)           => pgpTxOut.frameTxErr,
         statusIn(48)           => pgpTxOut.frameTx,
         statusIn(47 downto 32) => pgpTxOut.locOverflow,
         statusIn(31 downto 16) => pgpTxOut.locPause,
         statusIn(15 downto 0)  => pgpRxOut.remRxPause,
         -- Output Status bit Signals (rdClk domain)  
         statusOut              => statusOut,
         -- Status Bit Counters Signals (rdClk domain) 
         cntRstIn               => r.cntRst,
         rollOverEnIn           => r.rollOverEn,
         cntOut                 => statusCnt,
         -- Clocks and Reset Ports
         wrClk                  => pgpClk,
         rdClk                  => axilClk);

   process (axilReadMaster, axilRst, axilWriteMaster, freqMeasured, localMac,
            r, remoteMac, statusCnt, statusOut) is
      variable v      : RegType;
      variable axilEp : AxiLiteEndpointType;
   begin
      -- Latch the current value
      v := r;

      -- Reset strobes
      v.cntRst := '0';

      -- Determine the transaction type
      axiSlaveWaitTxn(axilEp, axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave);

      -- Map the read registers
      for i in STATUS_SIZE_C-1 downto 0 loop
         axiSlaveRegisterR(axilEp, toSlv((4*i), 8), 0, muxSlVectorArray(statusCnt, i));
      end loop;
      axiSlaveRegisterR(axilEp, x"100", 0, statusOut);
      axiSlaveRegisterR(axilEp, x"180", 0, freqMeasured);

      if (WRITE_EN_G) then

         axiSlaveRegister(axilEp, x"200", 0, v.etherType);

         axiSlaveRegister(axilEp, x"300", 0, v.loopback);
         axiSlaveRegister(axilEp, x"304", 0, v.rxPolarity);
         axiSlaveRegister(axilEp, x"308", 0, v.txPolarity);

         for i in 9 downto 0 loop
            axiSlaveRegister(axilEp, toSlv(1024+(4*i), 8), 0, v.txDiffCtrl(i));
            axiSlaveRegister(axilEp, toSlv(1024+(4*i), 8), 8, v.txPreCursor(i));
            axiSlaveRegister(axilEp, toSlv(1024+(4*i), 8), 16, v.txPostCursor(i));
         end loop;

      else

         axiSlaveRegisterR(axilEp, x"200", 0, r.etherType);

         axiSlaveRegisterR(axilEp, x"300", 0, r.loopback);
         axiSlaveRegisterR(axilEp, x"304", 0, r.rxPolarity);
         axiSlaveRegisterR(axilEp, x"308", 0, r.txPolarity);

         for i in 9 downto 0 loop
            axiSlaveRegisterR(axilEp, toSlv(1024+(4*i), 8), 0, r.txDiffCtrl(i));
            axiSlaveRegisterR(axilEp, toSlv(1024+(4*i), 8), 8, r.txPreCursor(i));
            axiSlaveRegisterR(axilEp, toSlv(1024+(4*i), 8), 16, r.txPostCursor(i));
         end loop;

      end if;

      axiSlaveRegisterR(axilEp, x"204", 0, localMac);
      axiSlaveRegisterR(axilEp, x"208", 0, remoteMac);
      axiSlaveRegister(axilEp, x"20C", 0, v.broadcastMac);

      axiSlaveRegister(axilEp, x"FF0", 0, v.rollOverEn);
      axiSlaveRegister(axilEp, x"FFC", 0, v.cntRst);

      -- Close out the AXI-Lite transaction
      axiSlaveDefault(axilEp, v.axilWriteSlave, v.axilReadSlave, AXI_RESP_DECERR_C);

      -- Reset
      if (axilRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Next register assignment
      rin <= v;

      -- Outputs
      axilReadSlave  <= r.axilReadSlave;
      axilWriteSlave <= r.axilWriteSlave;
      loopback       <= r.loopback;
      rxPolarity     <= r.rxPolarity;
      txPolarity     <= r.txPolarity;
      txDiffCtrl     <= r.txDiffCtrl;
      txPreCursor    <= r.txPreCursor;
      txPostCursor   <= r.txPostCursor;

   end process;

   process (axilClk) is
   begin
      if (rising_edge(axilClk)) then
         r <= rin after TPD_G;
      end if;
   end process;

   U_etherType : entity work.SynchronizerVector
      generic map(
         TPD_G   => TPD_G,
         WIDTH_G => 16)
      port map (
         clk     => pgpClk,
         dataIn  => r.etherType,
         dataOut => etherType);

   U_broadcastMac : entity work.SynchronizerVector
      generic map(
         TPD_G   => TPD_G,
         WIDTH_G => 48)
      port map (
         clk     => pgpClk,
         dataIn  => r.broadcastMac,
         dataOut => broadcastMac);

   U_nullInterval : entity work.SynchronizerVector
      generic map(
         TPD_G   => TPD_G,
         WIDTH_G => 32)
      port map (
         clk     => pgpClk,
         dataIn  => r.pgpTxIn.nullInterval,
         dataOut => syncTxIn.nullInterval);

   U_SyncBits : entity work.SynchronizerVector
      generic map(
         TPD_G   => TPD_G,
         WIDTH_G => 2)
      port map (
         clk        => pgpClk,
         -- Inputs
         dataIn(0)  => r.pgpTxIn.disable,
         dataIn(1)  => r.pgpTxIn.flowCntlDis,
         -- Outputs
         dataOut(0) => syncTxIn.disable,
         dataOut(1) => syncTxIn.flowCntlDis);

   pgpTxIn.disable      <= locTxIn.disable or syncTxIn.disable;
   pgpTxIn.flowCntlDis  <= locTxIn.flowCntlDis or syncTxIn.flowCntlDis;
   pgpTxIn.nullInterval <= syncTxIn.nullInterval;
   pgpTxIn.opCodeEn     <= locTxIn.opCodeEn;
   pgpTxIn.opCode       <= locTxIn.opCode;
   pgpTxIn.locData      <= locTxIn.locData;
   pgpRxIn.resetRx      <= locRxIn.resetRx;

end rtl;
