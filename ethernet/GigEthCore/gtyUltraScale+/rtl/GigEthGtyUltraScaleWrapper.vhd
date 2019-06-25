-------------------------------------------------------------------------------
-- File       : GigEthGtyUltraScaleWrapper.vhd
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Gty Wrapper for 1000BASE-X Ethernet
-- Note: This module supports up to a MGT QUAD of 1GigE interfaces
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

entity GigEthGtyUltraScaleWrapper is
   generic (
      TPD_G              : time                             := 1 ns;
      NUM_LANE_G         : natural range 1 to 4             := 1;
      PAUSE_EN_G         : boolean                          := true;
      PAUSE_512BITS_G    : positive                         := 8;
      -- Clocking Configurations
      USE_GTREFCLK_G     : boolean                          := false;  --  FALSE: gtClkP/N,  TRUE: gtRefClk
      CLKIN_PERIOD_G     : real                             := 8.0;
      DIVCLK_DIVIDE_G    : positive                         := 1;
      CLKFBOUT_MULT_F_G  : real                             := 8.0;
      CLKOUT0_DIVIDE_F_G : real                             := 8.0;
      -- AXI-Lite Configurations
      EN_AXI_REG_G       : boolean                          := false;
      -- AXI Streaming Configurations
      AXIS_CONFIG_G      : AxiStreamConfigArray(3 downto 0) := (others => AXI_STREAM_CONFIG_INIT_C));
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
      -- Switch Polarity of TxN/TxP, RxN/RxP
      gtTxPolarity        : in  slv(NUM_LANE_G-1 downto 0)                     := (others => '0');
      gtRxPolarity        : in  slv(NUM_LANE_G-1 downto 0)                     := (others => '0');
      -- MGT Clock Port 
      gtRefClk            : in  sl                                             := '0';
      gtClkP              : in  sl                                             := '1';
      gtClkN              : in  sl                                             := '0';
      -- MGT Ports
      gtTxP               : out slv(NUM_LANE_G-1 downto 0);
      gtTxN               : out slv(NUM_LANE_G-1 downto 0);
      gtRxP               : in  slv(NUM_LANE_G-1 downto 0);
      gtRxN               : in  slv(NUM_LANE_G-1 downto 0));
end GigEthGtyUltraScaleWrapper;

architecture mapping of GigEthGtyUltraScaleWrapper is

   signal gtClk     : sl;
   signal gtClkBufg : sl;
   signal refClk    : sl;
   signal refRst    : sl;
   signal sysClk125 : sl;
   signal sysRst125 : sl;
   signal sysClk62  : sl;
   signal sysRst62  : sl;

begin

   phyClk <= sysClk125;
   phyRst <= sysRst125;

   -----------------------------
   -- Select the Reference Clock
   -----------------------------
   U_IBUFDS : IBUFDS_GTE4
      generic map (
         REFCLK_EN_TX_PATH  => '0',
         REFCLK_HROW_CK_SEL => "00",    -- 2'b00: ODIV2 = O
         REFCLK_ICNTL_RX    => "00")
      port map (
         I     => gtClkP,
         IB    => gtClkN,
         CEB   => '0',
         ODIV2 => gtClk,
         O     => open);

   BUFG_GT_Inst : BUFG_GT
      port map (
         I       => gtClk,
         CE      => '1',
         CEMASK  => '1',
         CLR     => '0',
         CLRMASK => '1',
         DIV     => "000",
         O       => gtClkBufg);

   refClk <= gtClkBufg when(USE_GTREFCLK_G = false) else gtRefClk;

   -----------------
   -- Power Up Reset
   -----------------
   PwrUpRst_Inst : entity work.PwrUpRst
      generic map (
         TPD_G => TPD_G)
      port map (
         arst   => extRst,
         clk    => refClk,
         rstOut => refRst);

   ----------------
   -- Clock Manager
   ----------------
   U_MMCM : entity work.ClockManagerUltraScale
      generic map(
         TPD_G              => TPD_G,
         TYPE_G             => "MMCM",
         INPUT_BUFG_G       => false,
         FB_BUFG_G          => true,
         RST_IN_POLARITY_G  => '1',
         NUM_CLOCKS_G       => 2,
         -- MMCM attributes
         BANDWIDTH_G        => "OPTIMIZED",
         CLKIN_PERIOD_G     => CLKIN_PERIOD_G,
         DIVCLK_DIVIDE_G    => DIVCLK_DIVIDE_G,
         CLKFBOUT_MULT_F_G  => CLKFBOUT_MULT_F_G,
         CLKOUT0_DIVIDE_F_G => CLKOUT0_DIVIDE_F_G,
         CLKOUT1_DIVIDE_G   => integer(2.0*CLKOUT0_DIVIDE_F_G))
      port map(
         clkIn     => refClk,
         rstIn     => refRst,
         clkOut(0) => sysClk125,
         clkOut(1) => sysClk62,
         rstOut(0) => sysRst125,
         rstOut(1) => sysRst62);

   --------------
   -- GigE Module 
   --------------
   GEN_LANE :
   for i in 0 to NUM_LANE_G-1 generate

      U_GigEthGtyUltraScale : entity work.GigEthGtyUltraScale
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
            sysClk62           => sysClk62,
            sysClk125          => sysClk125,
            sysRst125          => sysRst125,
            extRst             => refRst,
            phyReady           => phyReady(i),
            sigDet             => sigDet(i),
            -- Switch Polarity of TxN/TxP, RxN/RxP
            gtTxPolarity       => gtTxPolarity(i),
            gtRxPolarity       => gtRxPolarity(i),
            -- MGT Ports
            gtTxP              => gtTxP(i),
            gtTxN              => gtTxN(i),
            gtRxP              => gtRxP(i),
            gtRxN              => gtRxN(i));

   end generate GEN_LANE;

end mapping;
