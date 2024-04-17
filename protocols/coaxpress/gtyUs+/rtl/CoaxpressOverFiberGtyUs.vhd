-------------------------------------------------------------------------------
-- Title      : CoaXPress Protocol: http://jiia.org/wp-content/themes/jiia/pdf/standard_dl/coaxpress/CXP-001-2021.pdf
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: CoaXPress Gty Ultrascale Core Module
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
use surf.CoaXPressPkg.all;

entity CoaxpressOverFiberGtyUs is
   generic (
      TPD_G              : time                   := 1 ns;
      NUM_LANES_G        : positive               := 1;
      STATUS_CNT_WIDTH_G : positive range 1 to 32 := 12;
      RX_FSM_CNT_WIDTH_C : positive range 1 to 24 := 16;  -- Optimize this down w.r.t camera to help make timing in CoaXPressRxHsFsm.vhd
      AXIL_BASE_ADDR_G   : slv(31 downto 0);
      AXIL_CLK_FREQ_G    : real;        -- axilClk frequency (units of Hz)
      AXIS_CLK_FREQ_G    : real;        -- dataClk frequency (units of Hz)
      DATA_AXIS_CONFIG_G : AxiStreamConfigType;
      CFG_AXIS_CONFIG_G  : AxiStreamConfigType);
   port (
      -- QPLL Interface
      qpllLock        : in  Slv2Array(NUM_LANES_G-1 downto 0);
      qpllClk         : in  Slv2Array(NUM_LANES_G-1 downto 0);
      qpllRefclk      : in  Slv2Array(NUM_LANES_G-1 downto 0);
      qpllRst         : out Slv2Array(NUM_LANES_G-1 downto 0);
      -- GT Ports
      gtTxP           : out slv(NUM_LANES_G-1 downto 0);
      gtTxN           : out slv(NUM_LANES_G-1 downto 0);
      gtRxP           : in  slv(NUM_LANES_G-1 downto 0);
      gtRxN           : in  slv(NUM_LANES_G-1 downto 0);
      -- Trigger Interface (trigClk domain)
      trigClk         : out sl;
      trigRst         : out sl;
      trigger         : in  sl;
      -- Data Interface (dataClk domain)
      dataClk         : in  sl;
      dataRst         : in  sl;
      dataMaster      : out AxiStreamMasterType;
      dataSlave       : in  AxiStreamSlaveType;
      imageHdrMaster  : out AxiStreamMasterType;
      imageHdrSlave   : in  AxiStreamSlaveType;
      -- Config Interface (cfgClk domain)
      cfgClk          : in  sl;
      cfgRst          : in  sl;
      cfgIbMaster     : in  AxiStreamMasterType;
      cfgIbSlave      : out AxiStreamSlaveType;
      cfgObMaster     : out AxiStreamMasterType;
      cfgObSlave      : in  AxiStreamSlaveType;
      -- AXI-Lite Register Interface (axilClk domain)
      axilClk         : in  sl;
      axilRst         : in  sl;
      axilReadMaster  : in  AxiLiteReadMasterType;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType;
      axilWriteSlave  : out AxiLiteWriteSlaveType);
end CoaxpressOverFiberGtyUs;

architecture mapping of CoaxpressOverFiberGtyUs is

   constant MON_AXIL_INDEX_C   : integer := 0;
   constant DRP_AXIL_INDEX_C   : integer := 1;
   constant NUM_AXIL_MASTERS_C : integer := (1+NUM_LANES_G);

   constant XBAR_CONFIG_C : AxiLiteCrossbarMasterConfigArray(NUM_AXIL_MASTERS_C-1 downto 0) := genAxiLiteConfig(NUM_AXIL_MASTERS_C, AXIL_BASE_ADDR_G, 16, 12);

   signal axilReadMasters  : AxiLiteReadMasterArray(NUM_AXIL_MASTERS_C-1 downto 0);
   signal axilReadSlaves   : AxiLiteReadSlaveArray(NUM_AXIL_MASTERS_C-1 downto 0)  := (others => AXI_LITE_READ_SLAVE_EMPTY_DECERR_C);
   signal axilWriteMasters : AxiLiteWriteMasterArray(NUM_AXIL_MASTERS_C-1 downto 0);
   signal axilWriteSlaves  : AxiLiteWriteSlaveArray(NUM_AXIL_MASTERS_C-1 downto 0) := (others => AXI_LITE_WRITE_SLAVE_EMPTY_DECERR_C);

   signal txClk      : slv(NUM_LANES_G-1 downto 0)       := (others => '0');
   signal txRst      : slv(NUM_LANES_G-1 downto 0)       := (others => '0');
   signal txLsValid  : slv(NUM_LANES_G-1 downto 0)       := (others => '0');
   signal txLsData   : slv8Array(NUM_LANES_G-1 downto 0) := (others => CXP_IDLE_C(7 downto 0));
   signal txLsDataK  : slv(NUM_LANES_G-1 downto 0)       := (others => '1');
   signal txLsLaneEn : Slv4Array(NUM_LANES_G-1 downto 0) := (others => x"0");
   signal txLsRate   : slv(NUM_LANES_G-1 downto 0)       := (others => '0');
   signal txLinkUp   : slv(NUM_LANES_G-1 downto 0);

   signal rxClk     : slv(NUM_LANES_G-1 downto 0)        := (others => '0');
   signal rxRst     : slv(NUM_LANES_G-1 downto 0)        := (others => '0');
   signal rxData    : slv32Array(NUM_LANES_G-1 downto 0) := (others => CXP_IDLE_C);
   signal rxDataK   : Slv4Array(NUM_LANES_G-1 downto 0)  := (others => CXP_IDLE_K_C);
   signal rxDispErr : slv(NUM_LANES_G-1 downto 0)        := (others => '0');
   signal rxDecErr  : slv(NUM_LANES_G-1 downto 0)        := (others => '0');
   signal rxLinkUp  : slv(NUM_LANES_G-1 downto 0)        := (others => '0');

begin

   trigClk <= txClk(0);
   trigRst <= txRst(0);

   U_XBAR : entity surf.AxiLiteCrossbar
      generic map (
         TPD_G              => TPD_G,
         NUM_SLAVE_SLOTS_G  => 1,
         NUM_MASTER_SLOTS_G => NUM_AXIL_MASTERS_C,
         MASTERS_CONFIG_G   => XBAR_CONFIG_C)
      port map (
         axiClk              => axilClk,
         axiClkRst           => axilRst,
         sAxiWriteMasters(0) => axilWriteMaster,
         sAxiWriteSlaves(0)  => axilWriteSlave,
         sAxiReadMasters(0)  => axilReadMaster,
         sAxiReadSlaves(0)   => axilReadSlave,
         mAxiWriteMasters    => axilWriteMasters,
         mAxiWriteSlaves     => axilWriteSlaves,
         mAxiReadMasters     => axilReadMasters,
         mAxiReadSlaves      => axilReadSlaves);

   U_Core : entity surf.CoaXPressCore
      generic map (
         TPD_G              => TPD_G,
         NUM_LANES_G        => NUM_LANES_G,
         STATUS_CNT_WIDTH_G => STATUS_CNT_WIDTH_G,
         RX_FSM_CNT_WIDTH_C => RX_FSM_CNT_WIDTH_C,
         DATA_AXIS_CONFIG_G => DATA_AXIS_CONFIG_G,
         CFG_AXIS_CONFIG_G  => CFG_AXIS_CONFIG_G,
         AXIS_CLK_FREQ_G    => AXIS_CLK_FREQ_G,
         AXIL_CLK_FREQ_G    => AXIL_CLK_FREQ_G)
      port map (
         -- Data Interface (dataClk domain)
         dataClk         => dataClk,
         dataRst         => dataRst,
         dataMaster      => dataMaster,
         dataSlave       => dataSlave,
         imageHdrMaster  => imageHdrMaster,
         imageHdrSlave   => imageHdrSlave,
         -- Config Interface (cfgClk domain)
         cfgClk          => cfgClk,
         cfgRst          => cfgRst,
         cfgIbMaster     => cfgIbMaster,
         cfgIbSlave      => cfgIbSlave,
         cfgObMaster     => cfgObMaster,
         cfgObSlave      => cfgObSlave,
         -- Tx Interface (txClk domain)
         txClk           => txClk(0),
         txRst           => txRst(0),
         txLsValid       => txLsValid(0),
         txLsData        => txLsData(0),
         txLsDataK       => txLsDataK(0),
         txLsLaneEn      => txLsLaneEn(0),
         txLsRate        => txLsRate(0),
         txTrig          => trigger,
         txLinkUp        => txLinkUp(0),
         -- Rx Interface (rxClk domain)
         rxClk           => rxClk,
         rxRst           => rxRst,
         rxData          => rxData,
         rxDataK         => rxDataK,
         rxDispErr       => rxDispErr,
         rxDecErr        => rxDecErr,
         rxLinkUp        => rxLinkUp,
         -- AXI-Lite Register Interface (axilClk domain)
         axilClk         => axilClk,
         axilRst         => axilRst,
         axilReadMaster  => axilReadMasters(MON_AXIL_INDEX_C),
         axilReadSlave   => axilReadSlaves(MON_AXIL_INDEX_C),
         axilWriteMaster => axilWriteMasters(MON_AXIL_INDEX_C),
         axilWriteSlave  => axilWriteSlaves(MON_AXIL_INDEX_C));

   --------------------------
   -- Wrapper for Gty IP core
   --------------------------
   GEN_LANE : for i in NUM_LANES_G-1 downto 0 generate

      U_CXPoF : entity surf.CoaXPressOverFiberGtyUsIpWrapper
         generic map (
            TPD_G   => TPD_G,
            LANE0_G => (i = 0))
         port map (
            -- QPLL Interface
            qpllLock        => qpllLock(i),
            qpllclk         => qpllclk(i),
            qpllrefclk      => qpllrefclk(i),
            qpllRst         => qpllRst(i),
            -- GT Ports
            gtRxP           => gtRxP(i),
            gtRxN           => gtRxN(i),
            gtTxP           => gtTxP(i),
            gtTxN           => gtTxN(i),
            -- Tx Interface (txClk domain)
            txClk           => txClk(i),
            txRst           => txRst(i),
            txLsValid       => txLsValid(i),
            txLsData        => txLsData(i),
            txLsDataK       => txLsDataK(i),
            txLsRate        => txLsRate(i),
            txLsLaneEn      => txLsLaneEn(i),
            txLinkUp        => txLinkUp(i),
            -- Rx Interface (rxClk domain)
            rxClk           => rxClk(i),
            rxRst           => rxRst(i),
            rxData          => rxData(i),
            rxDataK         => rxDataK(i),
            rxDispErr       => rxDispErr(i),
            rxDecErr        => rxDecErr(i),
            rxLinkUp        => rxLinkUp(i),
            -- AXI-Lite Register Interface (axilClk domain)
            axilClk         => axilClk,
            axilRst         => axilRst,
            axilReadMaster  => axilReadMasters(DRP_AXIL_INDEX_C+i),
            axilReadSlave   => axilReadSlaves(DRP_AXIL_INDEX_C+i),
            axilWriteMaster => axilWriteMasters(DRP_AXIL_INDEX_C+i),
            axilWriteSlave  => axilWriteSlaves(DRP_AXIL_INDEX_C+i));

   end generate GEN_LANE;

end mapping;
