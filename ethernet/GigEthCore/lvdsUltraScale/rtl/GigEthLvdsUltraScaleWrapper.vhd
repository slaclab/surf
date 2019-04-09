-------------------------------------------------------------------------------
-- File       : GigEthLvdsUltraScaleWrapper.vhd
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Wrapper for SGMII/LVDS Ethernet
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
use work.EthMacPkg.all;
use work.GigEthPkg.all;

library unisim;
use unisim.vcomponents.all;

entity GigEthLvdsUltraScaleWrapper is
   generic (
      TPD_G           : time                             := 1 ns;
      NUM_LANE_G      : positive                         := 1;
      PAUSE_EN_G      : boolean                          := true;
      PAUSE_512BITS_G : positive                         := 8;
      -- Clocking Configurations
      USE_REFCLK_G    : boolean                          := false;  --  FALSE: sgmiiClkP/N,  TRUE: sgmiiRefClk
      CLKFBOUT_MULT_G : positive                         := 10;
      CLKOUT1_PHASE_G : real                             := 90.0;
      -- AXI-Lite Configurations
      EN_AXI_REG_G    : boolean                          := false;
      -- AXI Streaming Configurations
      AXIS_CONFIG_G   : AxiStreamConfigArray(3 downto 0) := (others => EMAC_AXIS_CONFIG_C));
   port (
      -- Local Configurations
      localMac            : in  Slv48Array(NUM_LANE_G-1 downto 0)              := (others => MAC_ADDR_INIT_C);
      -- Streaming DMA Interface
      dmaClk              : in  slv(NUM_LANE_G-1 downto 0);
      dmaRst              : in  slv(NUM_LANE_G-1 downto 0);
      dmaIbMasters        : out AxiStreamMasterArray(NUM_LANE_G-1 downto 0);
      dmaIbSlaves         : in  AxiStreamSlaveArray(NUM_LANE_G-1 downto 0);
      dmaObMasters        : in  AxiStreamMasterArray(NUM_LANE_G-1 downto 0);
      dmaObSlaves         : out AxiStreamSlaveArray(NUM_LANE_G-1 downto 0);
      -- Slave AXI-Lite Interface
      axiLiteClk          : in  slv(NUM_LANE_G-1 downto 0)                     := (others => '0');
      axiLiteRst          : in  slv(NUM_LANE_G-1 downto 0)                     := (others => '0');
      axiLiteReadMasters  : in  AxiLiteReadMasterArray(NUM_LANE_G-1 downto 0)  := (others => AXI_LITE_READ_MASTER_INIT_C);
      axiLiteReadSlaves   : out AxiLiteReadSlaveArray(NUM_LANE_G-1 downto 0);
      axiLiteWriteMasters : in  AxiLiteWriteMasterArray(NUM_LANE_G-1 downto 0) := (others => AXI_LITE_WRITE_MASTER_INIT_C);
      axiLiteWriteSlaves  : out AxiLiteWriteSlaveArray(NUM_LANE_G-1 downto 0);
      -- Misc. Signals
      extRst              : in  sl                                             := '0';
      phyClk              : out sl;
      phyRst              : out sl;
      phyReady            : out slv(NUM_LANE_G-1 downto 0);
      sigDet              : in  slv(NUM_LANE_G-1 downto 0)                     := (others => '1');
      mmcmLocked          : out sl;
      speed_is_10_100     : in  slv(NUM_LANE_G-1 downto 0)                     := (others => '0');
      speed_is_100        : in  slv(NUM_LANE_G-1 downto 0)                     := (others => '1');
      -- MGT Clock Port
      sgmiiRefClk         : in  sl                                             := '0';  -- 125 MHz
      sgmiiClkP           : in  sl                                             := '1';  -- 625 MHz
      sgmiiClkN           : in  sl                                             := '0';  -- 625 MHz
      -- MGT Ports
      sgmiiTxP            : out slv(NUM_LANE_G-1 downto 0);
      sgmiiTxN            : out slv(NUM_LANE_G-1 downto 0);
      sgmiiRxP            : in  slv(NUM_LANE_G-1 downto 0);
      sgmiiRxN            : in  slv(NUM_LANE_G-1 downto 0));
end GigEthLvdsUltraScaleWrapper;

architecture mapping of GigEthLvdsUltraScaleWrapper is

   signal sgmiiClk     : sl;
   signal sgmiiClkBufg : sl;
   signal refClk       : sl;
   signal refRst       : sl;
   signal locked       : sl;
   signal clkFb        : sl;

   signal CLKOUT0 : sl;
   signal CLKOUT1 : sl;

   signal sysClk625 : sl;
   signal sysClk312 : sl;
   signal sysClk125 : sl;
   signal sysRst125 : sl;

begin

   phyClk <= sysClk125;
   phyRst <= sysRst125;

   mmcmLocked <= locked;

   -----------------------------
   -- Select the Reference Clock
   -----------------------------
   IBUFGDS_SGMII : IBUFGDS
      port map (
         I  => sgmiiClkP,
         IB => sgmiiClkN,
         O  => sgmiiClk);

   U_Bufg_sgmiiClk : BUFGCE_DIV
      generic map (
         BUFGCE_DIVIDE => 5)
      port map (
         I   => sgmiiClk,               -- 625 MHz (CLKIN_PERIOD_G)
         CE  => '1',
         CLR => '0',
         O   => sgmiiClkBufg);          -- 125 MHz (CLKIN_PERIOD_G*5)

   refClk <= sgmiiClkBufg when(USE_REFCLK_G = false) else sgmiiRefClk;  -- 125 MHz

   U_PwrUpRst : entity work.PwrUpRst
      generic map(
         TPD_G => TPD_G)
      port map (
         arst   => extRst,
         clk    => refClk,
         rstOut => refRst);

   ----------------
   -- Clock Manager
   ----------------
   U_PLL : PLLE3_ADV
      generic map(
         CLKOUTPHY_MODE => "VCO",
         COMPENSATION   => "INTERNAL",
         STARTUP_WAIT   => "FALSE",
         CLKIN_PERIOD   => 8.0,
         DIVCLK_DIVIDE  => 1,
         CLKFBOUT_MULT  => CLKFBOUT_MULT_G,  -- 1.25GHz
         CLKOUT0_DIVIDE => 2,                -- 625 MHz
         CLKOUT1_DIVIDE => 4,                -- 312.5 MHz
         CLKOUT0_PHASE  => 0.0,
         CLKOUT1_PHASE  => CLKOUT1_PHASE_G)  -- Deskew the clk0/clk1
      port map (
         DCLK        => '0',
         DRDY        => open,
         DEN         => '0',
         DWE         => '0',
         DADDR       => (others => '0'),
         DI          => (others => '0'),
         DO          => open,
         PWRDWN      => '0',
         CLKOUTPHYEN => '0',
         CLKIN       => refClk,              -- 125 MHz
         RST         => refRst,
         CLKFBIN     => clkFb,
         CLKFBOUT    => clkFb,
         CLKOUT0     => CLKOUT0,
         CLKOUT1     => CLKOUT1,
         LOCKED      => locked);

   U_sysClk125 : BUFGCE_DIV
      generic map (
         BUFGCE_DIVIDE => 5)
      port map (
         I   => CLKOUT0,
         CE  => '1',
         CLR => '0',
         O   => sysClk125);

   U_sysRst125 : entity work.RstSync
      generic map (
         TPD_G         => TPD_G,
         IN_POLARITY_G => '0')
      port map (
         clk      => sysClk125,
         asyncRst => locked,
         syncRst  => sysRst125);

   ----------------------------------------------------------
   -- Refer to "Fig: Fabric Clocking With MMCM clock outputs"
   -- https://www.xilinx.com/support/answers/67885.html
   ----------------------------------------------------------
   U_sysClk625 : BUFG
      port map (
         I => CLKOUT0,
         O => sysClk625);

   U_sysClk312 : BUFG
      port map (
         I => CLKOUT1,
         O => sysClk312);

   --------------------------------------------------------------------------------------------------------
   -- Ethernet 'lanes' (in case multiple Ethernets can share a common clock -- however, due to tight timing
   --                   they should probably all fit into the same clock region)
   --------------------------------------------------------------------------------------------------------
   GEN_LANE : for i in 0 to NUM_LANE_G-1 generate
      signal ethClkEn : sl;
   begin

      U_ethClkEn : entity work.GigEthLvdsClockEnable
         port map (
            sysClk125       => sysClk125,
            sysRst125       => sysRst125,
            speed_is_10_100 => speed_is_10_100(i),
            speed_is_100    => speed_is_100(i),
            ethClkEn        => ethClkEn);

      U_GigEthLvdsUltraScale : entity work.GigEthLvdsUltraScale
         generic map (
            TPD_G           => TPD_G,
            PAUSE_EN_G      => PAUSE_EN_G,
            PAUSE_512BITS_G => PAUSE_512BITS_G,
            -- AXI-Lite Configurations
            EN_AXI_REG_G    => EN_AXI_REG_G,
            -- AXI Streaming Configurations
            AXIS_CONFIG_G   => AXIS_CONFIG_G(i))
         port map (
            -- Local Configurations
            localMac           => localMac(i),
            -- Streaming DMA Interface
            dmaClk             => dmaClk(i),
            dmaRst             => dmaRst(i),
            dmaIbMaster        => dmaIbMasters(i),
            dmaIbSlave         => dmaIbSlaves(i),
            dmaObMaster        => dmaObMasters(i),
            dmaObSlave         => dmaObSlaves(i),
            -- Slave AXI-Lite Interface
            axiLiteClk         => axiLiteClk(i),
            axiLiteRst         => axiLiteRst(i),
            axiLiteReadMaster  => axiLiteReadMasters(i),
            axiLiteReadSlave   => axiLiteReadSlaves(i),
            axiLiteWriteMaster => axiLiteWriteMasters(i),
            axiLiteWriteSlave  => axiLiteWriteSlaves(i),
            -- PHY + MAC signals
            ethClkEn           => ethClkEn,
            sysClk625          => sysClk625,
            sysClk312          => sysClk312,
            sysClk125          => sysClk125,
            sysRst125          => sysRst125,
            extRst             => refRst,
            phyReady           => phyReady(i),
            sigDet             => sigDet(i),
            mmcmLocked         => locked,
            speed_is_10_100    => speed_is_10_100(i),
            speed_is_100       => speed_is_100(i),
            -- MGT Ports
            sgmiiTxP           => sgmiiTxP(i),
            sgmiiTxN           => sgmiiTxN(i),
            sgmiiRxP           => sgmiiRxP(i),
            sgmiiRxN           => sgmiiRxN(i));

   end generate GEN_LANE;

end mapping;
