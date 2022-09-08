-------------------------------------------------------------------------------
-- Title      : CoaXPress Protocol: http://jiia.org/wp-content/themes/jiia/pdf/standard_dl/coaxpress/CXP-001-2021.pdf
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: AXI-Lite block to manage the CoaXPress interface
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
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;
use surf.CoaXPressPkg.all;

entity CoaXPressAxiL is
   generic (
      TPD_G              : time                  := 1 ns;
      NUM_LANES_G        : positive              := 1;
      STATUS_CNT_WIDTH_G : natural range 1 to 32 := 12;
      AXIL_CLK_FREQ_G    : real                  := 156.25E+6);
   port (
      -- Tx Interface (txClk domain)
      txClk           : in  sl;
      txRst           : in  sl;
      txTrig          : in  sl;
      swTrig          : out sl;
      txRate          : out sl;
      txTrigDrop      : in  sl;
      txLinkUp        : in  sl;
      -- Rx Interface (rxClk domain)
      rxClk           : in  slv(NUM_LANES_G-1 downto 0);
      rxRst           : in  slv(NUM_LANES_G-1 downto 0);
      rxDispErr       : in  slv(NUM_LANES_G-1 downto 0);
      rxDecErr        : in  slv(NUM_LANES_G-1 downto 0);
      rxFifoOverflow  : in  slv(NUM_LANES_G-1 downto 0);
      rxLinkUp        : in  slv(NUM_LANES_G-1 downto 0);
      rxCfgDrop       : in  sl;
      rxDataDrop      : in  sl;
      rxFifoRst       : out sl;
      -- Config Interface (cfgClk domain)
      cfgClk          : in  sl;
      cfgRst          : in  sl;
      configTimerSize : out slv(23 downto 0);
      configErrResp   : out slv(1 downto 0);
      -- AXI-Lite Register Interface (axilClk domain)
      axilClk         : in  sl;
      axilRst         : in  sl;
      axilReadMaster  : in  AxiLiteReadMasterType;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType;
      axilWriteSlave  : out AxiLiteWriteSlaveType);
end CoaXPressAxiL;

architecture rtl of CoaXPressAxiL is

   type RegType is record
      configTimerSize : slv(23 downto 0);
      configErrResp   : slv(1 downto 0);
      txRate          : sl;
      swTrig          : sl;
      rxFifoRst       : sl;
      cntRst          : sl;
      axilWriteSlave  : AxiLiteWriteSlaveType;
      axilReadSlave   : AxiLiteReadSlaveType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      configTimerSize => (others => '1'),
      configErrResp   => (others => '1'),
      txRate          => '0',
      swTrig          => '0',
      rxFifoRst       => '0',
      cntRst          => '0',
      axilWriteSlave  => AXI_LITE_WRITE_SLAVE_INIT_C,
      axilReadSlave   => AXI_LITE_READ_SLAVE_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal rxLinkUpCnt       : SlVectorArray(NUM_LANES_G-1 downto 0, STATUS_CNT_WIDTH_G-1 downto 0);
   signal rxFifoOverflowCnt : SlVectorArray(NUM_LANES_G-1 downto 0, STATUS_CNT_WIDTH_G-1 downto 0);
   signal rxDecErrCnt       : SlVectorArray(NUM_LANES_G-1 downto 0, STATUS_CNT_WIDTH_G-1 downto 0);
   signal rxDispErrCnt      : SlVectorArray(NUM_LANES_G-1 downto 0, STATUS_CNT_WIDTH_G-1 downto 0);

   signal rxCntOut : SlVectorArray(1 downto 0, STATUS_CNT_WIDTH_G-1 downto 0);
   signal txCntOut : SlVectorArray(2 downto 0, STATUS_CNT_WIDTH_G-1 downto 0);

   signal rxDispErrSync      : slv(NUM_LANES_G-1 downto 0);
   signal rxDecErrSync       : slv(NUM_LANES_G-1 downto 0);
   signal rxFifoOverflowSync : slv(NUM_LANES_G-1 downto 0);
   signal rxLinkUpSync       : slv(NUM_LANES_G-1 downto 0);
   signal rxLinkUpStatus     : slv(NUM_LANES_G-1 downto 0);

   signal txStatusOut : slv(2 downto 0);
   signal trigFreq    : slv(31 downto 0);
   signal txClkFreq   : slv(31 downto 0);
   signal rxClkFreq   : Slv32Array(NUM_LANES_G-1 downto 0);

begin

   process (axilReadMaster, axilRst, axilWriteMaster, r, rxClkFreq, rxCntOut,
            rxDecErrCnt, rxDispErrCnt, rxFifoOverflowCnt, rxLinkUpCnt,
            rxLinkUpStatus, trigFreq, txClkFreq, txCntOut, txStatusOut) is
      variable v      : RegType;
      variable axilEp : AxiLiteEndpointType;
   begin
      -- Latch the current value
      v := r;

      -- Reset strobes
      v.swTrig    := '0';
      v.rxFifoRst := '0';
      v.cntRst    := '0';

      ------------------------
      -- AXI-Lite Transactions
      ------------------------

      -- Determine the transaction type
      axiSlaveWaitTxn(axilEp, axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave);

      for i in 0 to NUM_LANES_G-1 loop
         axiSlaveRegisterR(axilEp, x"000"+toSlv(i*4+0*64, 12), 0, muxSlVectorArray(rxLinkUpCnt, i));  -- 0x000:0x03F
         axiSlaveRegisterR(axilEp, x"040"+toSlv(i*4+1*64, 12), 0, muxSlVectorArray(rxFifoOverflowCnt, i));  -- 0x040:0x07F
         axiSlaveRegisterR(axilEp, x"080"+toSlv(i*4+2*64, 12), 0, muxSlVectorArray(rxDecErrCnt, i));  -- 0x080:0x0BF
         axiSlaveRegisterR(axilEp, x"0C0"+toSlv(i*4+3*64, 12), 0, muxSlVectorArray(rxDispErrCnt, i));  -- 0x0C0:0x0FF
         axiSlaveRegisterR(axilEp, x"100"+toSlv(i*4+4*64, 12), 0, rxClkFreq(i));  -- 0x100:0x13F
      end loop;

      axiSlaveRegisterR(axilEp, x"700", 0, rxLinkUpStatus);
      axiSlaveRegisterR(axilEp, x"704", 0, txStatusOut);
      axiSlaveRegisterR(axilEp, x"708", 0, trigFreq);
      axiSlaveRegisterR(axilEp, x"70C", 0, txClkFreq);

      axiSlaveRegisterR(axilEp, x"710", 0, muxSlVectorArray(rxCntOut, 0));
      axiSlaveRegisterR(axilEp, x"714", 0, muxSlVectorArray(rxCntOut, 1));

      axiSlaveRegisterR(axilEp, x"720", 0, muxSlVectorArray(txCntOut, 0));
      axiSlaveRegisterR(axilEp, x"724", 0, muxSlVectorArray(txCntOut, 1));
      axiSlaveRegisterR(axilEp, x"728", 0, muxSlVectorArray(txCntOut, 2));

      axiSlaveRegister (axilEp, x"FEC", 0, v.configTimerSize);
      axiSlaveRegister (axilEp, x"FEC", 24, v.configErrResp);
      axiSlaveRegister (axilEp, x"FEC", 26, v.txRate);

      axiSlaveRegisterR(axilEp, x"FF0", 0, toSlv(NUM_LANES_G, 8));
      axiSlaveRegisterR(axilEp, x"FF0", 8, toSlv(STATUS_CNT_WIDTH_G, 8));
      axiSlaveRegister (axilEp, X"FF4", 0, v.swTrig);
      axiSlaveRegister (axilEp, X"FF8", 0, v.rxFifoRst);
      axiSlaveRegister (axilEp, X"FFC", 0, v.cntRst);

      -- Close the transaction
      axiSlaveDefault(axilEp, v.axilWriteSlave, v.axilReadSlave, AXI_RESP_DECERR_C);

      -- Outputs
      axilReadSlave  <= r.axilReadSlave;
      axilWriteSlave <= r.axilWriteSlave;

      -- Reset
      if (axilRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Next register assignment
      rin <= v;

   end process;

   process (axilClk) is
   begin
      if (rising_edge(axilClk)) then
         r <= rin after TPD_G;
      end if;
   end process;

   ------------------------------
   -- Transmitter Synchronization
   ------------------------------

   U_swTrig : entity surf.SynchronizerOneShot
      generic map (
         TPD_G => TPD_G)
      port map (
         clk     => txClk,
         rst     => txRst,
         dataIn  => r.swTrig,
         dataOut => swTrig);

   U_txRate : entity surf.Synchronizer
      generic map (
         TPD_G   => TPD_G)
      port map (
         clk     => txClk,
         dataIn  => r.txRate,
         dataOut => txRate);

   U_txCntOut : entity surf.SyncStatusVector
      generic map (
         TPD_G       => TPD_G,
         CNT_WIDTH_G => STATUS_CNT_WIDTH_G,
         WIDTH_G     => 3)
      port map (
         statusIn(0)  => txLinkUp,
         statusIn(1)  => txTrig,
         statusIn(2)  => txTrigDrop,
         statusOut    => txStatusOut,
         cntRstIn     => r.cntRst,
         rollOverEnIn => "010",
         cntOut       => txCntOut,
         wrClk        => txClk,
         wrRst        => txRst,
         rdClk        => axilClk,
         rdRst        => axilRst);

   U_trigFreq : entity surf.SyncTrigRate
      generic map (
         TPD_G          => TPD_G,
         ONE_SHOT_G     => true,        -- true=SynchronizerOneShot
         REF_CLK_FREQ_G => AXIL_CLK_FREQ_G)
      port map (
         -- Trigger Input (locClk domain)
         trigIn      => txTrig,
         -- Trigger Rate Output (locClk domain)
         trigRateOut => trigFreq,
         -- Clocks
         locClk      => axilClk,
         refClk      => axilClk);

   U_txClkFreq : entity surf.SyncClockFreq
      generic map (
         TPD_G          => TPD_G,
         REF_CLK_FREQ_G => AXIL_CLK_FREQ_G,
         COMMON_CLK_G   => true,        -- locClk = refClk
         CNT_WIDTH_G    => 32)
      port map (
         freqOut => txClkFreq,
         clkIn   => txClk,
         locClk  => axilClk,
         refClk  => axilClk);

   ---------------------------
   -- Receiver Synchronization
   ---------------------------

   U_rxFifoRst : entity surf.SynchronizerOneShot
      generic map (
         TPD_G => TPD_G)
      port map (
         clk     => rxClk(0),
         rst     => rxRst(0),
         dataIn  => r.rxFifoRst,
         dataOut => rxFifoRst);

   U_rxDispErrSync : entity surf.SynchronizerOneShotVector
      generic map (
         TPD_G   => TPD_G,
         WIDTH_G => NUM_LANES_G)
      port map (
         clk     => rxClk(0),
         rst     => rxRst(0),
         dataIn  => rxDispErr,
         dataOut => rxDispErrSync);

   U_rxDispErr : entity surf.SyncStatusVector
      generic map (
         TPD_G       => TPD_G,
         CNT_WIDTH_G => STATUS_CNT_WIDTH_G,
         WIDTH_G     => NUM_LANES_G)
      port map (
         statusIn => rxDispErrSync,
         cntRstIn => r.cntRst,
         cntOut   => rxDispErrCnt,
         wrClk    => rxClk(0),
         wrRst    => rxRst(0),
         rdClk    => axilClk,
         rdRst    => axilRst);

   U_rxDecErrSync : entity surf.SynchronizerOneShotVector
      generic map (
         TPD_G   => TPD_G,
         WIDTH_G => NUM_LANES_G)
      port map (
         clk     => rxClk(0),
         rst     => rxRst(0),
         dataIn  => rxDecErr,
         dataOut => rxDecErrSync);

   U_rxDecErr : entity surf.SyncStatusVector
      generic map (
         TPD_G       => TPD_G,
         CNT_WIDTH_G => STATUS_CNT_WIDTH_G,
         WIDTH_G     => NUM_LANES_G)
      port map (
         statusIn => rxDecErrSync,
         cntRstIn => r.cntRst,
         cntOut   => rxDecErrCnt,
         wrClk    => rxClk(0),
         wrRst    => rxRst(0),
         rdClk    => axilClk,
         rdRst    => axilRst);

   U_rxFifoOverflowSync : entity surf.SynchronizerOneShotVector
      generic map (
         TPD_G   => TPD_G,
         WIDTH_G => NUM_LANES_G)
      port map (
         clk     => rxClk(0),
         rst     => rxRst(0),
         dataIn  => rxFifoOverflow,
         dataOut => rxFifoOverflowSync);

   U_rxFifoOverflow : entity surf.SyncStatusVector
      generic map (
         TPD_G       => TPD_G,
         CNT_WIDTH_G => STATUS_CNT_WIDTH_G,
         WIDTH_G     => NUM_LANES_G)
      port map (
         statusIn => rxFifoOverflowSync,
         cntRstIn => r.cntRst,
         cntOut   => rxFifoOverflowCnt,
         wrClk    => rxClk(0),
         wrRst    => rxRst(0),
         rdClk    => axilClk,
         rdRst    => axilRst);

   U_rxLinkUpSync : entity surf.SynchronizerVector
      generic map (
         TPD_G   => TPD_G,
         WIDTH_G => NUM_LANES_G)
      port map (
         clk     => rxClk(0),
         rst     => rxRst(0),
         dataIn  => rxLinkUp,
         dataOut => rxLinkUpSync);

   U_rxLinkUp : entity surf.SyncStatusVector
      generic map (
         TPD_G       => TPD_G,
         CNT_WIDTH_G => STATUS_CNT_WIDTH_G,
         WIDTH_G     => NUM_LANES_G)
      port map (
         statusIn  => rxLinkUpSync,
         statusOut => rxLinkUpStatus,
         cntRstIn  => r.cntRst,
         cntOut    => rxLinkUpCnt,
         wrClk     => rxClk(0),
         wrRst     => rxRst(0),
         rdClk     => axilClk,
         rdRst     => axilRst);

   U_rxCntOut : entity surf.SyncStatusVector
      generic map (
         TPD_G       => TPD_G,
         CNT_WIDTH_G => STATUS_CNT_WIDTH_G,
         WIDTH_G     => 2)
      port map (
         statusIn(0) => rxCfgDrop,
         statusIn(1) => rxDataDrop,
         cntRstIn    => r.cntRst,
         cntOut      => rxCntOut,
         wrClk       => rxClk(0),
         wrRst       => rxRst(0),
         rdClk       => axilClk,
         rdRst       => axilRst);

   GEN_VEC :
   for i in (NUM_LANES_G-1) downto 0 generate

      U_rxClkFreq : entity surf.SyncClockFreq
         generic map (
            TPD_G          => TPD_G,
            REF_CLK_FREQ_G => AXIL_CLK_FREQ_G,
            COMMON_CLK_G   => true,     -- locClk = refClk
            CNT_WIDTH_G    => 32)
         port map (
            freqOut => rxClkFreq(i),
            clkIn   => rxClk(i),
            locClk  => axilClk,
            refClk  => axilClk);

   end generate GEN_VEC;

   --------------------------------
   -- Configuration Synchronization
   --------------------------------

   U_configTimerSize : entity surf.SynchronizerVector
      generic map (
         TPD_G   => TPD_G,
         WIDTH_G => 24)
      port map (
         clk     => cfgClk,
         dataIn  => r.configTimerSize,
         dataOut => configTimerSize);

   U_configErrResp : entity surf.SynchronizerVector
      generic map (
         TPD_G   => TPD_G,
         WIDTH_G => 2)
      port map (
         clk     => cfgClk,
         dataIn  => r.configErrResp,
         dataOut => configErrResp);

end rtl;

