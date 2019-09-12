-------------------------------------------------------------------------------
-- File       : PgpEthCore.vhd
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: PGPv3 Core
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

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.AxiLitePkg.all;
use work.PgpEthPkg.all;

entity PgpEthCore is
   generic (
      TPD_G                 : time                   := 1 ns;
      -- PGP Settings
      NUM_VC_G              : positive range 1 to 16 := 4;
      TX_MAX_PAYLOAD_SIZE_G : positive               := 1024;  -- Must be a multiple of 64B (in units of bytes)
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
      pgpClk          : in  sl;
      pgpRst          : in  sl;
      -- Tx User interface
      pgpTxIn         : in  PgpEthTxInType         := PGP_ETH_TX_IN_INIT_C;
      pgpTxOut        : out PgpEthTxOutType;
      pgpTxMasters    : in  AxiStreamMasterArray(NUM_VC_G-1 downto 0);
      pgpTxSlaves     : out AxiStreamSlaveArray(NUM_VC_G-1 downto 0);
      -- Rx User interface
      pgpRxIn         : in  PgpEthRxInType         := PGP_ETH_RX_IN_INIT_C;
      pgpRxOut        : out PgpEthRxOutType;
      pgpRxMasters    : out AxiStreamMasterArray(NUM_VC_G-1 downto 0);
      pgpRxCtrl       : in  AxiStreamCtrlArray(NUM_VC_G-1 downto 0);
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
end entity PgpEthCore;

architecture mapping of PgpEthCore is

   signal locRxLinkReady : sl;
   signal remRxFifoCtrl  : AxiStreamCtrlArray(NUM_VC_G-1 downto 0);
   signal remRxLinkReady : sl;

   signal pgpTxInInt  : PgpEthTxInType;
   signal pgpTxOutInt : PgpEthTxOutType;
   signal pgpRxInInt  : PgpEthRxInType;
   signal pgpRxOutInt : PgpEthRxOutType;

   signal broadcastMac : slv(47 downto 0);
   signal remoteMac    : slv(47 downto 0);
   signal etherType    : slv(15 downto 0);

   attribute dont_touch                   : string;
   attribute dont_touch of locRxLinkReady : signal is "TRUE";
   attribute dont_touch of remRxLinkReady : signal is "TRUE";
   attribute dont_touch of pgpTxInInt     : signal is "TRUE";
   attribute dont_touch of pgpTxOutInt    : signal is "TRUE";
   attribute dont_touch of pgpRxInInt     : signal is "TRUE";
   attribute dont_touch of pgpRxOutInt    : signal is "TRUE";

begin

   phyUsrRst <= pgpRxInInt.resetRx;
   pgpRxOut  <= pgpRxOutInt;
   pgpTxOut  <= pgpTxOutInt;

   U_Tx : entity work.PgpEthTx
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
         pgpClk         => pgpClk,
         pgpRst         => pgpRst,
         pgpTxIn        => pgpTxInInt,
         pgpTxOut       => pgpTxOutInt,
         pgpTxMasters   => pgpTxMasters,
         pgpTxSlaves    => pgpTxSlaves,
         -- Status of receive and remote FIFOs
         locRxFifoCtrl  => pgpRxCtrl,
         locRxLinkReady => locRxLinkReady,
         remRxFifoCtrl  => remRxFifoCtrl,
         remRxLinkReady => remRxLinkReady,
         -- Tx PHY interface
         phyTxRdy       => phyTxRdy,
         phyTxMaster    => phyTxMaster,
         phyTxSlave     => phyTxSlave);

   U_Rx : entity work.PgpEthRx
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
         pgpClk         => pgpClk,
         pgpRst         => pgpRst,
         pgpRxIn        => pgpRxInInt,
         pgpRxOut       => pgpRxOutInt,
         pgpRxMasters   => pgpRxMasters,
         -- Status of local receive FIFOs
         remRxFifoCtrl  => remRxFifoCtrl,
         remRxLinkReady => remRxLinkReady,
         locRxLinkReady => locRxLinkReady,
         -- Rx PHY interface
         phyRxRdy       => phyRxRdy,
         phyRxMaster    => phyRxMaster);

   U_AxiLite : entity work.PgpEthAxiL
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
         pgpClk          => pgpClk,
         pgpRst          => pgpRst,
         -- Tx User interface
         pgpTxIn         => pgpTxInInt,
         pgpTxOut        => pgpTxOutInt,
         locTxIn         => pgpTxIn,
         -- Rx User interface
         pgpRxIn         => pgpRxInInt,
         pgpRxOut        => pgpRxOutInt,
         locRxIn         => pgpRxIn,
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
