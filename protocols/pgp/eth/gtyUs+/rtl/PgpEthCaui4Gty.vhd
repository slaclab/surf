-------------------------------------------------------------------------------
-- File       : PgpEthCaui4Gty.vhd
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: 
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
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.AxiLitePkg.all;
use work.PgpEthPkg.all;

library unisim;
use unisim.vcomponents.all;

entity PgpEthCaui4Gty is
   generic (
      TPD_G                 : time                        := 1 ns;
      SIM_SPEEDUP_G         : boolean                     := false;
      ROGUE_SIM_EN_G        : boolean                     := false;
      ROGUE_SIM_PORT_NUM_G  : natural range 1024 to 49151 := 9000;
      REFCLK_TYPE_G         : boolean                     := true;  -- false = 156.25 MHz, true = 161.1328125 MHz
      -- PGP Settings
      NUM_VC_G              : integer range 1 to 16       := 4;
      TX_MAX_PAYLOAD_SIZE_G : positive                    := 1024;  -- Must be a multiple of 64B (in units of bytes)
      -- Misc Debug Settings
      LOOPBACK_G            : slv(2 downto 0)             := (others => '0');
      RX_POLARITY_G         : slv(3 downto 0)             := (others => '0');
      TX_POLARITY_G         : slv(3 downto 0)             := (others => '0');
      TX_DIFF_CTRL_G        : Slv5Array(3 downto 0)       := (others => "11000");
      TX_PRE_CURSOR_G       : Slv5Array(3 downto 0)       := (others => "00000");
      TX_POST_CURSOR_G      : Slv5Array(3 downto 0)       := (others => "00000");
      -- AXI-Lite Settings
      AXIL_WRITE_EN_G       : boolean                     := false;  -- Set to false when on remote end of a link
      AXIL_BASE_ADDR_G      : slv(31 downto 0)            := (others => '0');
      AXIL_CLK_FREQ_G       : real                        := 156.25E+6);
   port (
      -- Stable Clock and Reset
      stableClk       : in  sl;         -- GT needs a stable clock to "boot up"
      stableRst       : in  sl;
      -- PGP Clock and Reset
      pgpClk          : out sl;
      pgpRst          : out sl;
      -- Non VC Rx Signals
      pgpRxIn         : in  PgpEthRxInType                           := PGP_ETH_RX_IN_INIT_C;
      pgpRxOut        : out PgpEthRxOutType;
      -- Non VC Tx Signals
      pgpTxIn         : in  PgpEthTxInType                           := PGP_ETH_TX_IN_INIT_C;
      pgpTxOut        : out PgpEthTxOutType;
      -- Frame Transmit Interface
      pgpTxMasters    : in  AxiStreamMasterArray(NUM_VC_G-1 downto 0);
      pgpTxSlaves     : out AxiStreamSlaveArray(NUM_VC_G-1 downto 0);
      -- Frame Receive Interface
      pgpRxMasters    : out AxiStreamMasterArray(NUM_VC_G-1 downto 0);
      pgpRxCtrl       : in  AxiStreamCtrlArray(NUM_VC_G-1 downto 0);
      pgpRxSlaves     : in  AxiStreamSlaveArray(NUM_VC_G-1 downto 0) := (others => AXI_STREAM_SLAVE_INIT_C);  -- Simulation Only
      -- AXI-Lite Register Interface (axilClk domain)
      axilClk         : in  sl                                       := '0';
      axilRst         : in  sl                                       := '0';
      axilReadMaster  : in  AxiLiteReadMasterType                    := AXI_LITE_READ_MASTER_INIT_C;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType                   := AXI_LITE_WRITE_MASTER_INIT_C;
      axilWriteSlave  : out AxiLiteWriteSlaveType;
      -- Ethernet MAC 
      localMac        : in  slv(47 downto 0)                         := x"01_02_03_56_44_00";  -- 00:44:56:03:02:01
      -- GT Ports
      gtRefClkP       : in  sl;
      gtRefClkN       : in  sl;
      gtRxP           : in  slv(3 downto 0);
      gtRxN           : in  slv(3 downto 0);
      gtTxP           : out slv(3 downto 0);
      gtTxN           : out slv(3 downto 0));

end PgpEthCaui4Gty;

architecture mapping of PgpEthCaui4Gty is

   constant RX_POLARITY_C : slv(9 downto 0) := ("000000" & RX_POLARITY_G);
   constant TX_POLARITY_C : slv(9 downto 0) := ("000000" & TX_POLARITY_G);
   constant TX_DIFF_CTRL_C : Slv5Array(9 downto 0) := (
      0 => TX_DIFF_CTRL_G(0),
      1 => TX_DIFF_CTRL_G(1),
      2 => TX_DIFF_CTRL_G(2),
      3 => TX_DIFF_CTRL_G(3),
      4 => "11111",
      5 => "11111",
      6 => "11111",
      7 => "11111",
      8 => "11111",
      9 => "11111");
   constant TX_PRE_CURSOR_C : Slv5Array(9 downto 0) := (
      0 => TX_PRE_CURSOR_G(0),
      1 => TX_PRE_CURSOR_G(1),
      2 => TX_PRE_CURSOR_G(2),
      3 => TX_PRE_CURSOR_G(3),
      4 => "11111",
      5 => "11111",
      6 => "11111",
      7 => "11111",
      8 => "11111",
      9 => "11111");
   constant TX_POST_CURSOR_C : Slv5Array(9 downto 0) := (
      0 => TX_POST_CURSOR_G(0),
      1 => TX_POST_CURSOR_G(1),
      2 => TX_POST_CURSOR_G(2),
      3 => TX_POST_CURSOR_G(3),
      4 => "11111",
      5 => "11111",
      6 => "11111",
      7 => "11111",
      8 => "11111",
      9 => "11111");

   signal phyClk    : sl;
   signal phyRst    : sl;
   signal phyUsrRst : sl;
   signal pgpRefClk : sl;

   signal phyRxMaster : AxiStreamMasterType;

   signal phyTxMaster : AxiStreamMasterType;
   signal phyTxSlave  : AxiStreamSlaveType;

   signal loopback     : slv(2 downto 0);
   signal rxPolarity   : slv(9 downto 0);
   signal txPolarity   : slv(9 downto 0);
   signal txDiffCtrl   : Slv5Array(9 downto 0);
   signal txPreCursor  : Slv5Array(9 downto 0);
   signal txPostCursor : Slv5Array(9 downto 0);
   signal stableReset  : sl;
   signal phyReady     : sl;

begin

   REAL_PGP : if (not ROGUE_SIM_EN_G) generate

      pgpClk <= phyClk;
      pgpRst <= phyRst;

      stableReset <= stableRst or phyUsrRst;

      U_Core : entity work.PgpEthCore
         generic map (
            TPD_G                 => TPD_G,
            -- PGP Settings
            NUM_VC_G              => NUM_VC_G,
            TX_MAX_PAYLOAD_SIZE_G => TX_MAX_PAYLOAD_SIZE_G,
            -- Misc Debug Settings
            LOOPBACK_G            => LOOPBACK_G,
            RX_POLARITY_G         => RX_POLARITY_C,
            TX_POLARITY_G         => TX_POLARITY_C,
            TX_DIFF_CTRL_G        => TX_DIFF_CTRL_C,
            TX_PRE_CURSOR_G       => TX_PRE_CURSOR_C,
            TX_POST_CURSOR_G      => TX_POST_CURSOR_C,
            -- PGP Settings         
            AXIL_WRITE_EN_G       => AXIL_WRITE_EN_G,
            AXIL_BASE_ADDR_G      => AXIL_BASE_ADDR_G,
            AXIL_CLK_FREQ_G       => AXIL_CLK_FREQ_G)
         port map (
            -- Clock and Reset
            pgpClk          => phyClk,
            pgpRst          => phyRst,
            -- Tx User interface
            pgpTxIn         => pgpTxIn,
            pgpTxOut        => pgpTxOut,
            pgpTxMasters    => pgpTxMasters,
            pgpTxSlaves     => pgpTxSlaves,
            -- Rx User interface
            pgpRxIn         => pgpRxIn,
            pgpRxOut        => pgpRxOut,
            pgpRxMasters    => pgpRxMasters,
            pgpRxCtrl       => pgpRxCtrl,
            -- Tx PHY Interface
            phyTxRdy        => phyReady,
            phyTxMaster     => phyTxMaster,
            phyTxSlave      => phyTxSlave,
            -- Rx PHY Interface
            phyRxRdy        => phyReady,
            phyRxMaster     => phyRxMaster,
            -- Debug Interface
            localMac        => localMac,
            loopback        => loopback,
            rxPolarity      => rxPolarity,
            txPolarity      => txPolarity,
            txDiffCtrl      => txDiffCtrl,
            txPreCursor     => txPreCursor,
            txPostCursor    => txPostCursor,
            phyUsrRst       => phyUsrRst,
            -- AXI-Lite Register Interface (axilClk domain)
            axilClk         => axilClk,
            axilRst         => axilRst,
            axilReadMaster  => axilReadMaster,
            axilReadSlave   => axilReadSlave,
            axilWriteMaster => axilWriteMaster,
            axilWriteSlave  => axilWriteSlave);

      --------------------------
      -- Wrapper for GT IP core
      --------------------------
      U_IP : entity work.Caui4GtyIpWrapper
         generic map (
            TPD_G              => TPD_G,
            REFCLK_TYPE_G      => REFCLK_TYPE_G,
            MAX_PAYLOAD_SIZE_G => TX_MAX_PAYLOAD_SIZE_G,
            SIM_SPEEDUP_G      => SIM_SPEEDUP_G)
         port map (
            -- Stable Clock and Reset Reference
            stableClk    => stableClk,
            stableRst    => stableReset,
            -- PHY Clock and Reset
            phyClk       => phyClk,
            phyRst       => phyRst,
            -- Rx PHY Interface
            phyRxMaster  => phyRxMaster,
            -- Tx PHY Interface
            phyTxMaster  => phyTxMaster,
            phyTxSlave   => phyTxSlave,
            -- Misc Debug Interfaces
            phyReady     => phyReady,
            loopback     => loopback,
            rxPolarity   => rxPolarity(3 downto 0),
            txPolarity   => txPolarity(3 downto 0),
            txDiffCtrl   => txDiffCtrl(3 downto 0),
            txPreCursor  => txPreCursor(3 downto 0),
            txPostCursor => txPostCursor(3 downto 0),
            -- GT Ports
            gtRefClkP    => gtRefClkP,
            gtRefClkN    => gtRefClkN,
            gtRxP        => gtRxP,
            gtRxN        => gtRxN,
            gtTxP        => gtTxP,
            gtTxN        => gtTxN);

   end generate REAL_PGP;

   SIM_PGP : if (ROGUE_SIM_EN_G) generate

      U_Rogue : entity work.RoguePgpEthSim
         generic map(
            TPD_G      => TPD_G,
            PORT_NUM_G => ROGUE_SIM_PORT_NUM_G,
            NUM_VC_G   => NUM_VC_G)
         port map(
            -- GT Ports
            pgpRefClk       => pgpRefClk,
            -- PGP Clock and Reset
            pgpClk          => pgpClk,
            pgpRst          => pgpRst,
            -- Non VC Rx Signals
            pgpRxIn         => pgpRxIn,
            pgpRxOut        => pgpRxOut,
            -- Non VC Tx Signals
            pgpTxIn         => pgpTxIn,
            pgpTxOut        => pgpTxOut,
            -- Frame Transmit Interface
            pgpTxMasters    => pgpTxMasters,
            pgpTxSlaves     => pgpTxSlaves,
            -- Frame Receive Interface
            pgpRxMasters    => pgpRxMasters,
            pgpRxSlaves     => pgpRxSlaves,
            -- AXI-Lite Register Interface (axilClk domain)
            axilClk         => axilClk,
            axilRst         => axilRst,
            axilReadMaster  => axilReadMaster,
            axilReadSlave   => axilReadSlave,
            axilWriteMaster => axilWriteMaster,
            axilWriteSlave  => axilWriteSlave);

      U_pgpRefClk : IBUFDS_GTE4
         generic map (
            REFCLK_EN_TX_PATH  => '0',
            REFCLK_HROW_CK_SEL => "00",  -- 2'b00: ODIV2 = O
            REFCLK_ICNTL_RX    => "00")
         port map (
            I     => gtRefClkP,
            IB    => gtRefClkN,
            CEB   => '0',
            ODIV2 => pgpRefClk,
            O     => open);

      gtTxP <= x"0";
      gtTxN <= x"F";

   end generate SIM_PGP;

end mapping;
