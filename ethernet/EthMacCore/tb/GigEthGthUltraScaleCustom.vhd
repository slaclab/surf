-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: 1000BASE-X Ethernet for Gth7
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

library xpm;
use xpm.vcomponents.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;
use surf.AxiLitePkg.all;
use surf.EthMacPkg.all;
use surf.GigEthPkg.all;

entity GigEthGthUltraScaleCustom is
   generic (
      TPD_G                : time                          := 1 ns;
      RST_POLARITY_G       : sl                            := '1';
      DEBUG_G              : string                        := "false";
      -- MAC Configurations
      INT_PIPE_STAGES_G    : natural                       := 1;
      PIPE_STAGES_G        : natural                       := 1;
      FIFO_ADDR_WIDTH_G    : positive                      := 12;       -- single 4K UltraRAM
      SYNTH_MODE_G         : string                        := "xpm";
      MEMORY_TYPE_G        : string                        := "ultra";
      PHY_TYPE_G           : string                        := "GMII";   -- "GMII", "XGMII", or "XLGMII"
      JUMBO_G              : boolean                       := true;
      PAUSE_EN_G           : boolean                       := true;
      ROCEV2_EN_G          : boolean                       := false;
      --
      AN_ADV_CONFIG_INIT_G : std_logic_vector(15 downto 0) := x"0020";  -- 1000BASE-X Full duplex
      -- AXI Streaming Configurations
      AXIS_CONFIG_G        : AxiStreamConfigType           := EMAC_AXIS_CONFIG_C);
   port (
      --
      -- Streaming DMA Interface at core_clk
      core_clk    : in  std_logic;
      core_rst    : in  std_logic;
      dmaIbMaster : out AxiStreamMasterType;
      dmaIbSlave  : in  AxiStreamSlaveType;
      dmaObMaster : in  AxiStreamMasterType;
      dmaObSlave  : out AxiStreamSlaveType;

      phyReady      : in  std_logic;
      gth_resetdone : in  std_logic;
      ethConfig     : in  EthMacConfigType;
      ethStatus     : out EthMacStatusType;
      --

      -- GMII PHY Interface
      gmiiRxDv : in  sl               := '0';
      gmiiRxEr : in  sl               := '0';
      gmiiRxd  : in  slv(7 downto 0)  := (others => '0');
      gmiiTxEn : out sl;
      gmiiTxEr : out sl;
      gmiiTxd  : out slv(7 downto 0);
      -- XGMII PHY Interface
      xgmiiRxd : in  slv(63 downto 0) := (others => '0');
      xgmiiRxc : in  slv(7 downto 0)  := (others => '0');
      xgmiiTxd : out slv(63 downto 0);
      xgmiiTxc : out slv(7 downto 0);

      -- GT Reference clock
      ethClk : in std_logic;
      ethRst : in std_logic

      );
end GigEthGthUltraScaleCustom;

architecture mapping of GigEthGthUltraScaleCustom is

   --------------------------------------------------------------------------------
   -- Interconnect signals
   --------------------------------------------------------------------------------
   --------------------------------------------------------------------------------
   -- Debug probes
   --------------------------------------------------------------------------------
   attribute mark_debug                  : string;
   attribute mark_debug of gth_resetdone : signal is DEBUG_G;
   attribute mark_debug of gmiiTxd       : signal is DEBUG_G;
   attribute mark_debug of gmiiTxEn      : signal is DEBUG_G;
   attribute mark_debug of gmiiTxEr      : signal is DEBUG_G;
   attribute mark_debug of gmiiRxd       : signal is DEBUG_G;
   attribute mark_debug of gmiiRxDv      : signal is DEBUG_G;
   attribute mark_debug of gmiiRxEr      : signal is DEBUG_G;
   attribute mark_debug of ethStatus     : signal is DEBUG_G;
   attribute mark_debug of phyReady      : signal is DEBUG_G;
   attribute mark_debug of xgmiiRxd      : signal is DEBUG_G;
   attribute mark_debug of xgmiiRxc      : signal is DEBUG_G;
   attribute mark_debug of xgmiiTxd      : signal is DEBUG_G;
   attribute mark_debug of xgmiiTxc      : signal is DEBUG_G;

begin
   ------------------------------------------------------------------------------------------------
   -- Ethernet MAC core
   U_MAC : entity surf.EthMacTop
      generic map(
         TPD_G             => TPD_G,
         RST_POLARITY_G    => RST_POLARITY_G,
         INT_PIPE_STAGES_G => INT_PIPE_STAGES_G,
         PIPE_STAGES_G     => PIPE_STAGES_G,
         FIFO_ADDR_WIDTH_G => FIFO_ADDR_WIDTH_G,
         SYNTH_MODE_G      => SYNTH_MODE_G,
         MEMORY_TYPE_G     => MEMORY_TYPE_G,
         JUMBO_G           => JUMBO_G,
         PAUSE_EN_G        => PAUSE_EN_G,
         PAUSE_512BITS_G   => PAUSE_512BITS_C,
         ROCEV2_EN_G       => ROCEV2_EN_G,
         PHY_TYPE_G        => PHY_TYPE_G,
         PRIM_CONFIG_G     => AXIS_CONFIG_G)
      port map
      (
         -- Primary Interface
         primClk         => core_clk,
         primRst         => core_rst,
         ibMacPrimMaster => dmaObMaster,
         ibMacPrimSlave  => dmaObSlave,
         obMacPrimMaster => dmaIbMaster,
         obMacPrimSlave  => dmaIbSlave,
         --
         -- Ethernet Interface
         ethClk          => ethClk,
         ethRst          => ethRst,
         ethConfig       => ethConfig,
         ethStatus       => ethStatus,
         phyReady        => phyReady,
         --
         -- XGMII PHY Interface
         xgmiiRxd        => xgmiiRxd,
         xgmiiRxc        => xgmiiRxc,
         xgmiiTxd        => xgmiiTxd,
         xgmiiTxc        => xgmiiTxc,
         -- GMII PHY Interface
         gmiiRxDv        => gmiiRxDv,
         gmiiRxEr        => gmiiRxEr,
         gmiiRxd         => gmiiRxd,
         gmiiTxEn        => gmiiTxEn,
         gmiiTxEr        => gmiiTxEr,
         gmiiTxd         => gmiiTxd
         );
end mapping;
