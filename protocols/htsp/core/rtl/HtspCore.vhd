-------------------------------------------------------------------------------
-- Title      : HTSP: https://confluence.slac.stanford.edu/x/pQmODw
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: HTSP Ethernet Core
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

library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;
use surf.AxiLitePkg.all;
use surf.HtspPkg.all;

entity HtspCore is
   generic (
      TPD_G                 : time                   := 1 ns;
      -- HTSP Settings
      NUM_VC_G              : positive range 1 to 16 := 4;
      TX_MAX_PAYLOAD_SIZE_G : positive               := 8192;  -- Must be a multiple of 64B (in units of bytes)
      -- Misc Debug Settings
      LOOPBACK_G            : slv(2 downto 0)        := (others => '0');
      RX_POLARITY_G         : slv(9 downto 0)        := (others => '0');
      TX_POLARITY_G         : slv(9 downto 0)        := (others => '0');
      TX_DIFF_CTRL_G        : Slv5Array(9 downto 0)  := (others => "11000");
      TX_PRE_CURSOR_G       : Slv5Array(9 downto 0)  := (others => "00000");
      TX_POST_CURSOR_G      : Slv5Array(9 downto 0)  := (others => "00000");
      -- AXI-Lite Settings
      AXIL_WRITE_EN_G       : boolean                := false;  -- Set to false when on remote end of a link
      AXIL_BASE_ADDR_G      : slv(31 downto 0)       := (others => '0');
      AXIL_CLK_FREQ_G       : real                   := 156.25E+6);
   port (
      -- Clock and Reset
      htspClk         : in  sl;
      htspRst         : in  sl;
      -- Tx User interface
      htspTxIn        : in  HtspTxInType           := HTSP_TX_IN_INIT_C;
      htspTxOut       : out HtspTxOutType;
      htspTxMasters   : in  AxiStreamMasterArray(NUM_VC_G-1 downto 0);
      htspTxSlaves    : out AxiStreamSlaveArray(NUM_VC_G-1 downto 0);
      -- Rx User interface
      htspRxIn        : in  HtspRxInType           := HTSP_RX_IN_INIT_C;
      htspRxOut       : out HtspRxOutType;
      htspRxMasters   : out AxiStreamMasterArray(NUM_VC_G-1 downto 0);
      htspRxCtrl      : in  AxiStreamCtrlArray(NUM_VC_G-1 downto 0);
      -- Tx PHY interface
      phyTxRdy        : in  sl;
      phyTxMaster     : out AxiStreamMasterType;
      phyTxSlave      : in  AxiStreamSlaveType;
      -- Rx PHY interface
      phyRxRdy        : in  sl;
      phyRxMaster     : in  AxiStreamMasterType;
      -- Misc Debug Interfaces
      localMac        : in  slv(47 downto 0)       := x"01_02_03_56_44_00";  -- 00:44:56:03:02:01
      loopback        : out slv(2 downto 0);
      rxPolarity      : out slv(9 downto 0);
      txPolarity      : out slv(9 downto 0);
      txDiffCtrl      : out Slv5Array(9 downto 0);
      txPreCursor     : out Slv5Array(9 downto 0);
      txPostCursor    : out Slv5Array(9 downto 0);
      phyUsrRst       : out sl;
      -- AXI-Lite Register Interface (axilClk domain)
      axilClk         : in  sl                     := '0';
      axilRst         : in  sl                     := '0';
      axilReadMaster  : in  AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
      axilReadSlave   : out AxiLiteReadSlaveType   := AXI_LITE_READ_SLAVE_EMPTY_DECERR_C;
      axilWriteMaster : in  AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
      axilWriteSlave  : out AxiLiteWriteSlaveType  := AXI_LITE_WRITE_SLAVE_EMPTY_DECERR_C);
end entity HtspCore;

architecture mapping of HtspCore is

   signal locRxLinkReady : sl;
   signal remRxFifoCtrl  : AxiStreamCtrlArray(NUM_VC_G-1 downto 0);
   signal remRxLinkReady : sl;

   signal htspTxInInt  : HtspTxInType;
   signal htspTxOutInt : HtspTxOutType;
   signal htspRxInInt  : HtspRxInType;
   signal htspRxOutInt : HtspRxOutType;

   signal broadcastMac : slv(47 downto 0);
   signal remoteMac    : slv(47 downto 0);
   signal etherType    : slv(15 downto 0);

   signal remRxFifoCtrlReg  : AxiStreamCtrlArray(NUM_VC_G-1 downto 0) := (others => AXI_STREAM_CTRL_INIT_C);
   signal remRxLinkReadyReg : sl                                      := '0';
   signal locRxLinkReadyReg : sl                                      := '0';

   attribute dont_touch                   : string;
   attribute dont_touch of locRxLinkReady : signal is "TRUE";
   attribute dont_touch of remRxLinkReady : signal is "TRUE";
   attribute dont_touch of htspTxInInt    : signal is "TRUE";
   attribute dont_touch of htspTxOutInt   : signal is "TRUE";
   attribute dont_touch of htspRxInInt    : signal is "TRUE";
   attribute dont_touch of htspRxOutInt   : signal is "TRUE";

begin

   assert (isPowerOf2(TX_MAX_PAYLOAD_SIZE_G) = true)
      report "TX_MAX_PAYLOAD_SIZE_G must be power of 2" severity failure;

   phyUsrRst <= htspRxInInt.resetRx;
   htspRxOut <= htspRxOutInt;
   htspTxOut <= htspTxOutInt;

   U_Tx : entity surf.HtspTx
      generic map (
         TPD_G              => TPD_G,
         NUM_VC_G           => NUM_VC_G,
         MAX_PAYLOAD_SIZE_G => TX_MAX_PAYLOAD_SIZE_G)
      port map (
         -- Ethernet Configuration
         remoteMac      => remoteMac,
         localMac       => localMac,
         broadcastMac   => broadcastMac,
         etherType      => etherType,
         -- Tx User interface
         htspClk        => htspClk,
         htspRst        => htspRst,
         htspTxIn       => htspTxInInt,
         htspTxOut      => htspTxOutInt,
         htspTxMasters  => htspTxMasters,
         htspTxSlaves   => htspTxSlaves,
         -- Status of receive and remote FIFOs
         locRxFifoCtrl  => htspRxCtrl,
         locRxLinkReady => locRxLinkReadyReg,
         remRxFifoCtrl  => remRxFifoCtrlReg,
         remRxLinkReady => remRxLinkReadyReg,
         -- Tx PHY interface
         phyTxRdy       => phyTxRdy,
         phyTxMaster    => phyTxMaster,
         phyTxSlave     => phyTxSlave);

   -- Help with making timing
   process (htspClk) is
   begin
      if rising_edge(htspClk) then
         locRxLinkReadyReg <= locRxLinkReady after TPD_G;
         remRxFifoCtrlReg  <= remRxFifoCtrl  after TPD_G;
         remRxLinkReadyReg <= remRxLinkReady after TPD_G;
      end if;
   end process;

   U_Rx : entity surf.HtspRx
      generic map (
         TPD_G    => TPD_G,
         NUM_VC_G => NUM_VC_G)
      port map (
         -- Ethernet Configuration
         remoteMac      => remoteMac,
         localMac       => localMac,
         broadcastMac   => broadcastMac,
         etherType      => etherType,
         -- Rx User interface
         htspClk        => htspClk,
         htspRst        => htspRst,
         htspRxIn       => htspRxInInt,
         htspRxOut      => htspRxOutInt,
         htspRxMasters  => htspRxMasters,
         -- Status of local receive FIFOs
         remRxFifoCtrl  => remRxFifoCtrl,
         remRxLinkReady => remRxLinkReady,
         locRxLinkReady => locRxLinkReady,
         -- Rx PHY interface
         phyRxRdy       => phyRxRdy,
         phyRxMaster    => phyRxMaster);

   U_AxiLite : entity surf.HtspAxiL
      generic map (
         TPD_G            => TPD_G,
         WRITE_EN_G       => AXIL_WRITE_EN_G,
         AXIL_BASE_ADDR_G => AXIL_BASE_ADDR_G,
         AXIL_CLK_FREQ_G  => AXIL_CLK_FREQ_G,
         LOOPBACK_G       => LOOPBACK_G,
         RX_POLARITY_G    => RX_POLARITY_G,
         TX_POLARITY_G    => TX_POLARITY_G,
         TX_DIFF_CTRL_G   => TX_DIFF_CTRL_G,
         TX_PRE_CURSOR_G  => TX_PRE_CURSOR_G,
         TX_POST_CURSOR_G => TX_POST_CURSOR_G)
      port map (
         -- Clock and Reset
         htspClk         => htspClk,
         htspRst         => htspRst,
         -- Tx User interface
         htspTxIn        => htspTxInInt,
         htspTxOut       => htspTxOutInt,
         locTxIn         => htspTxIn,
         -- Rx User interface
         htspRxIn        => htspRxInInt,
         htspRxOut       => htspRxOutInt,
         locRxIn         => htspRxIn,
         -- Ethernet Configuration
         remoteMac       => remoteMac,
         localMac        => localMac,
         broadcastMac    => broadcastMac,
         etherType       => etherType,
         -- Misc Debug Interfaces
         loopback        => loopback,
         rxPolarity      => rxPolarity,
         txPolarity      => txPolarity,
         txDiffCtrl      => txDiffCtrl,
         txPreCursor     => txPreCursor,
         txPostCursor    => txPostCursor,
         -- AXI-Lite Interface
         axilClk         => axilClk,
         axilRst         => axilRst,
         axilReadMaster  => axilReadMaster,
         axilReadSlave   => axilReadSlave,
         axilWriteMaster => axilWriteMaster,
         axilWriteSlave  => axilWriteSlave);

end mapping;
