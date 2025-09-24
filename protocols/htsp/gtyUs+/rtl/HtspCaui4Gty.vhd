-------------------------------------------------------------------------------
-- Title      : HTSP: https://confluence.slac.stanford.edu/x/pQmODw
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Wrapper for HTSP Ethernet with GTY-based CAUI4 PHY
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

library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;
use surf.AxiLitePkg.all;
use surf.HtspPkg.all;

library unisim;
use unisim.vcomponents.all;

entity HtspCaui4Gty is
   generic (
      TPD_G                 : time                        := 1 ns;
      SIM_SPEEDUP_G         : boolean                     := false;
      ROGUE_SIM_EN_G        : boolean                     := false;
      ROGUE_SIM_PORT_NUM_G  : natural range 1024 to 49151 := 9000;
      REFCLK_TYPE_G         : string                      := "161MHz";  -- or "156.25MHz"
      -- HTSP Settings
      NUM_VC_G              : integer range 1 to 16       := 4;
      TX_MAX_PAYLOAD_SIZE_G : positive                    := 8192;  -- Must be a multiple of 64B (in units of bytes)
      -- Misc Debug Settings
      LOOPBACK_G            : slv(2 downto 0)             := (others => '0');
      RX_POLARITY_G         : slv(3 downto 0)             := (others => '0');
      TX_POLARITY_G         : slv(3 downto 0)             := (others => '0');
      TX_DIFF_CTRL_G        : Slv5Array(3 downto 0)       := (others => "11000");
      TX_PRE_CURSOR_G       : Slv5Array(3 downto 0)       := (others => "00011");
      TX_POST_CURSOR_G      : Slv5Array(3 downto 0)       := (others => "00011");
      -- AXI-Lite Settings
      AXIL_WRITE_EN_G       : boolean                     := false;  -- Set to false when on remote end of a link
      AXIL_CLK_FREQ_G       : real                        := 156.25E+6);
   port (
      -- Stable Clock and Reset
      stableClk       : in  sl;         -- GT needs a stable clock to "boot up"
      stableRst       : in  sl;
      -- HTSP Clock and Reset
      htspClk         : out sl;
      htspRst         : out sl;
      -- Non VC Rx Signals
      htspRxIn        : in  HtspRxInType                             := HTSP_RX_IN_INIT_C;
      htspRxOut       : out HtspRxOutType;
      -- Non VC Tx Signals
      htspTxIn        : in  HtspTxInType                             := HTSP_TX_IN_INIT_C;
      htspTxOut       : out HtspTxOutType;
      -- Frame Transmit Interface
      htspTxMasters   : in  AxiStreamMasterArray(NUM_VC_G-1 downto 0);
      htspTxSlaves    : out AxiStreamSlaveArray(NUM_VC_G-1 downto 0);
      -- Frame Receive Interface
      htspRxMasters   : out AxiStreamMasterArray(NUM_VC_G-1 downto 0);
      htspRxCtrl      : in  AxiStreamCtrlArray(NUM_VC_G-1 downto 0);
      htspRxSlaves    : in  AxiStreamSlaveArray(NUM_VC_G-1 downto 0) := (others => AXI_STREAM_SLAVE_INIT_C);  -- Simulation Only
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
      gtRefClkOut     : out sl;
      gtRxP           : in  slv(3 downto 0);
      gtRxN           : in  slv(3 downto 0);
      gtTxP           : out slv(3 downto 0);
      gtTxN           : out slv(3 downto 0));

end HtspCaui4Gty;

architecture mapping of HtspCaui4Gty is

   signal phyClk     : sl;
   signal phyRst     : sl;
   signal phyUsrRst  : sl;
   signal htspRefClk : sl;

   signal phyRxMaster     : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal phyRxMasterReg0 : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal phyRxMasterReg1 : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;

   signal phyTxMaster : AxiStreamMasterType;
   signal phyTxSlave  : AxiStreamSlaveType;

   signal loopback     : slv(2 downto 0);
   signal rxPolarity   : slv(3 downto 0);
   signal txPolarity   : slv(3 downto 0);
   signal txDiffCtrl   : Slv5Array(3 downto 0);
   signal txPreCursor  : Slv5Array(3 downto 0);
   signal txPostCursor : Slv5Array(3 downto 0);

   signal stableReset : sl;
   signal phyReady    : sl;

   signal rxFecCorInc   : sl;
   signal rxFecUnCorInc : sl;

begin

   assert (isPowerOf2(TX_MAX_PAYLOAD_SIZE_G) = true)
      report "MAX_PAYLOAD_SIZE_G must be power of 2" severity failure;

   REAL_HTSP : if (not ROGUE_SIM_EN_G) generate

      htspClk <= phyClk;

      U_htspRst : entity surf.RstPipeline
         generic map (
            TPD_G => TPD_G)
         port map (
            clk    => phyClk,
            rstIn  => phyRst,
            rstOut => htspRst);

      stableReset <= stableRst or phyUsrRst;

      U_Core : entity surf.HtspCore
         generic map (
            TPD_G                 => TPD_G,
            -- HTSP Settings
            NUM_VC_G              => NUM_VC_G,
            TX_MAX_PAYLOAD_SIZE_G => TX_MAX_PAYLOAD_SIZE_G,
            -- Misc Debug Settings
            LOOPBACK_G            => LOOPBACK_G,
            RX_POLARITY_G         => RX_POLARITY_G,
            TX_POLARITY_G         => TX_POLARITY_G,
            TX_DIFF_CTRL_G        => TX_DIFF_CTRL_G,
            TX_PRE_CURSOR_G       => TX_PRE_CURSOR_G,
            TX_POST_CURSOR_G      => TX_POST_CURSOR_G,
            -- HTSP Settings
            AXIL_WRITE_EN_G       => AXIL_WRITE_EN_G,
            AXIL_CLK_FREQ_G       => AXIL_CLK_FREQ_G)
         port map (
            -- Clock and Reset
            htspClk         => phyClk,
            htspRst         => phyRst,
            -- Tx User interface
            htspTxIn        => htspTxIn,
            htspTxOut       => htspTxOut,
            htspTxMasters   => htspTxMasters,
            htspTxSlaves    => htspTxSlaves,
            -- Rx User interface
            htspRxIn        => htspRxIn,
            htspRxOut       => htspRxOut,
            htspRxMasters   => htspRxMasters,
            htspRxCtrl      => htspRxCtrl,
            -- Tx PHY Interface
            phyTxRdy        => phyReady,
            phyTxMaster     => phyTxMaster,
            phyTxSlave      => phyTxSlave,
            -- Rx PHY Interface
            phyRxRdy        => phyReady,
            phyRxMaster     => phyRxMasterReg1,
            -- Debug Interface
            localMacIn      => localMac,
            rxFecCorInc     => rxFecCorInc,
            rxFecUnCorInc   => rxFecUnCorInc,
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
      -- Help with making timing
      --------------------------
      process(phyClk)
      begin
         if rising_edge(phyClk) then
            phyRxMasterReg1 <= phyRxMasterReg0 after TPD_G;
            phyRxMasterReg0 <= phyRxMaster     after TPD_G;
         end if;
      end process;

      --------------------------
      -- Wrapper for GT IP core
      --------------------------
      U_IP : entity surf.Caui4GtyIpWrapper
         generic map (
            TPD_G              => TPD_G,
            REFCLK_TYPE_G      => REFCLK_TYPE_G,
            MAX_PAYLOAD_SIZE_G => TX_MAX_PAYLOAD_SIZE_G,
            SIM_SPEEDUP_G      => SIM_SPEEDUP_G)
         port map (
            -- Stable Clock and Reset Reference
            stableClk     => stableClk,
            stableRst     => stableReset,
            -- PHY Clock and Reset
            phyClk        => phyClk,
            phyRst        => phyRst,
            -- Rx PHY Interface
            phyRxMaster   => phyRxMaster,
            -- Tx PHY Interface
            phyTxMaster   => phyTxMaster,
            phyTxSlave    => phyTxSlave,
            -- Misc Debug Interfaces
            phyReady      => phyReady,
            rxFecCorInc   => rxFecCorInc,
            rxFecUnCorInc => rxFecUnCorInc,
            loopback      => loopback,
            rxPolarity    => rxPolarity,
            txPolarity    => txPolarity,
            txDiffCtrl    => txDiffCtrl,
            txPreCursor   => txPreCursor,
            txPostCursor  => txPostCursor,
            -- GT Ports
            gtRefClkP     => gtRefClkP,
            gtRefClkN     => gtRefClkN,
            gtRefClkOut   => gtRefClkOut,
            gtRxP         => gtRxP,
            gtRxN         => gtRxN,
            gtTxP         => gtTxP,
            gtTxN         => gtTxN);

   end generate REAL_HTSP;

   SIM_HTSP : if (ROGUE_SIM_EN_G) generate

      U_Rogue : entity surf.RogueHtspSim
         generic map(
            TPD_G      => TPD_G,
            PORT_NUM_G => ROGUE_SIM_PORT_NUM_G,
            NUM_VC_G   => NUM_VC_G)
         port map(
            -- GT Ports
            htspRefClk      => htspRefClk,
            -- HTSP Clock and Reset
            htspClk         => htspClk,
            htspRst         => htspRst,
            -- Non VC Rx Signals
            htspRxIn        => htspRxIn,
            htspRxOut       => htspRxOut,
            -- Non VC Tx Signals
            htspTxIn        => htspTxIn,
            htspTxOut       => htspTxOut,
            -- Frame Transmit Interface
            htspTxMasters   => htspTxMasters,
            htspTxSlaves    => htspTxSlaves,
            -- Frame Receive Interface
            htspRxMasters   => htspRxMasters,
            htspRxSlaves    => htspRxSlaves,
            -- AXI-Lite Register Interface (axilClk domain)
            axilClk         => axilClk,
            axilRst         => axilRst,
            axilReadMaster  => axilReadMaster,
            axilReadSlave   => axilReadSlave,
            axilWriteMaster => axilWriteMaster,
            axilWriteSlave  => axilWriteSlave);

      U_htspRefClk : IBUFDS_GTE4
         generic map (
            REFCLK_EN_TX_PATH  => '0',
            REFCLK_HROW_CK_SEL => "00",  -- 2'b00: ODIV2 = O
            REFCLK_ICNTL_RX    => "00")
         port map (
            I     => gtRefClkP,
            IB    => gtRefClkN,
            CEB   => '0',
            ODIV2 => htspRefClk,
            O     => open);

      gtTxP <= x"0";
      gtTxN <= x"F";

   end generate SIM_HTSP;

end mapping;
