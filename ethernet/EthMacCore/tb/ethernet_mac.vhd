---------------------------------------------------------------------------------------------------
-- Title       : Gigabit Ethernet SURF core wrapper
-- Project     : UKAEA
---------------------------------------------------------------------------------------------------
-- File        : gig_ethernet_gth_uplus.vhd
-- Company     : Cosylab
-- Platform    : Xilinx FPGAs
---------------------------------------------------------------------------------------------------
-- Description: Wraps the SURF gigabit ethernet core wrapper for koheron
--  the clock was updated to avoid constraining core_clk frequency.
--  The GT reference clock must be 156.25MHz and an mmcm is used to derived the clocks for the
--  Ethernet core.
---------------------------------------------------------------------------------------------------
-- Revisions:  Revisions and documentation are controlled by
-- the revision control system (RCS).
---------------------------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library UNISIM;
use UNISIM.vcomponents.all;
library xpm;
use xpm.vcomponents.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;
use surf.AxiLitePkg.all;
use surf.SsiPkg.all;
use surf.EthMacPkg.all;
use surf.GigEthPkg.all;
---------------------------------------------------------------------------------------------------
entity ethernet_mac is
  generic (


    RST_POLARITY_G       : std_logic                     := '1';
    IS_10G               : boolean                       := false;
    SIMULATION_G         : boolean                       := false;
    DEBUG_G              : string                        := "false";
    SYNTH_MODE_G         : string                        := "xpm";
    PHY_TYPE_G           : string                        := "GMII"; -- "GMII", "XGMII", or "XLGMII"
    MEMORY_TYPE_G        : string                        := "ultra";
    AN_ADV_CONFIG_INIT_G : std_logic_vector(15 downto 0) := x"0020" -- 1000BASE-X Full duplex
  );
  port (
    -- Core clock
    userClk   : in std_logic;
    core_clk  : in std_logic;
    core_rst  : in  std_logic;

    -- Static configuration
    local_mac : in std_logic_vector(47 downto 0);
    --
    -- GT reference clock

    gth_status_vector : in std_logic_vector(15 downto 0);
    gth_reset_tx_user : in std_logic := '0';
    gth_reset_rx_user : in std_logic := '0';
    gth_resetdone     : in std_logic;

    an_configuration_vector : out std_logic_vector(15 downto 0) := x"0000";
    an_adv_config_vector    : out std_logic_vector(15 downto 0) := x"0020";
    an_restart_config       : out std_logic                     := '0';
    an_interrupt            : in std_logic;

      -- 10G Ethernet Control/Status
      gtpowergood               : in std_logic                    := '0';
      stat_tx_local_fault       : in std_logic                    := '0';
      stat_rx_bad_code          : in std_logic                    := '0';
      stat_rx_bad_code_valid    : in std_logic                    := '0';
      stat_rx_block_lock        : in std_logic                    := '0';
      stat_rx_error_valid       : in std_logic                    := '0';
      stat_rx_fifo_error        : in std_logic                    := '0';
      stat_rx_framing_err       : in std_logic                    := '0';
      stat_rx_framing_err_valid : in std_logic                    := '0';
      stat_rx_local_fault       : in std_logic                    := '0';
      stat_rx_valid_ctrl_code   : in std_logic                    := '0';
      stat_rx_status            : in std_logic                    := '0';
      stat_rx_error             : in std_logic_vector(7 downto 0) := (others => '0');
    -- GMII PHY Interface
    gmiiRxDv : in std_logic                    := '0';
    gmiiRxEr : in std_logic                    := '0';
    gmiiRxd  : in std_logic_vector(7 downto 0) := (others => '0');
    gmiiTxEn : out std_logic;
    gmiiTxEr : out std_logic;
    gmiiTxd  : out std_logic_vector(7 downto 0);

    -- XGMII PHY Interface
    xgmiiRxd : in std_logic_vector(63 downto 0) := (others => '0');
    xgmiiRxc : in std_logic_vector(7 downto 0)  := (others => '0');
    xgmiiTxd : out std_logic_vector(63 downto 0);
    xgmiiTxc : out std_logic_vector(7 downto 0);
    --
    -- AXI-Stream TX Interface
    s_core_tx_tdata  : in std_logic_vector(127 downto 0);
    s_core_tx_tuser  : in std_logic_vector(1 downto 0);
    s_core_tx_tkeep  : in std_logic_vector(15 downto 0);
    s_core_tx_tlast  : in std_logic;
    s_core_tx_tvalid : in std_logic;
    s_core_tx_tready : out std_logic;
    --
    -- AXI-Stream RX Interface
    m_core_rx_tdata  : out std_logic_vector(127 downto 0);
    m_core_rx_tuser  : out std_logic_vector(1 downto 0);
    m_core_rx_tkeep  : out std_logic_vector(15 downto 0);
    m_core_rx_tlast  : out std_logic;
    m_core_rx_tvalid : out std_logic;
    m_core_rx_tready : in std_logic

  );
end ethernet_mac;
---------------------------------------------------------------------------------------------------
architecture rtl of ethernet_mac is

  constant TPD_G : time := 1 ns;
  constant PHY_TYPE_C : string := ite(IS_10G, "XGMII", "GMII");

  -- GT Clocking primitives interconnect
  signal localMacSync             : std_logic_vector(47 downto 0);
  signal clk_fb, clk_fb_g         : std_logic;
  signal gt_clk                   : std_logic;
  signal gt_clk_bufg              : std_logic;
  signal ethClk, ethRst, phyReady : std_logic;
  signal ethConfig                : EthMacConfigType;
  signal ethStatus                : EthMacStatusType;
  -- AXI-Stream Interface
  signal coreRxAxisMaster : AxiStreamMasterType; -- data to be transmitted
  signal coreRxAxisSlave  : AxiStreamSlaveType; -- AXI-Stream ready
  signal coreTxAxisMaster : AxiStreamMasterType; -- received data
  signal coreTxAxisSlave  : AxiStreamSlaveType; -- AXI-Stream ready
  attribute mark_debug                  : string;
  attribute MARK_DEBUG of coreRxAxisMaster, coreRxAxisSlave            : signal is "TRUE";
  attribute MARK_DEBUG of ethStatus, coreTxAxisMaster, coreTxAxisSlave : signal is "TRUE";

  signal gth_reset_tx_user_L : std_logic := '1';
  signal gth_reset_rx_user_L : std_logic := '1';

  ---------------------------------------------------------------------------------------------------
begin

   ethConfig.macAddress  <= local_mac;
   ethConfig.filtEnable  <= '1';
   ethConfig.pauseEnable <= '1';
   ethConfig.pauseTime   <= x"00FF";
   ethConfig.pauseThresh <= toSlv((9000/16), 16);  -- 9000B jumbo frame in cache
   ethConfig.ipCsumEn    <= '1';
   ethConfig.tcpCsumEn   <= '1';
   ethConfig.udpCsumEn   <= '1';
   ethConfig.dropOnPause <= '0';

  ------------------------------------------------------------------------------------------------
  -- Gigabit ethernet customized from surf library
  u_GigEthGthUltraScaleCustom : entity surf.GigEthGthUltraScaleCustom
    generic map(
      TPD_G                => 1 ns,
         RST_POLARITY_G       => RST_POLARITY_G,
      DEBUG_G              => DEBUG_G,
      INT_PIPE_STAGES_G    => 1, -- left as default
      PIPE_STAGES_G        => 1, -- left as default
      FIFO_ADDR_WIDTH_G    => 12, -- left as default
      SYNTH_MODE_G         => SYNTH_MODE_G,
      MEMORY_TYPE_G        => MEMORY_TYPE_G, -- left as default
      JUMBO_G              => false,
      PAUSE_EN_G           => true,
      ROCEV2_EN_G          => false, -- left as default
      PHY_TYPE_G           => PHY_TYPE_G,
      AN_ADV_CONFIG_INIT_G => AN_ADV_CONFIG_INIT_G)
    port map
    (
      --
      core_clk    => core_clk,
      core_rst    => core_rst,

      dmaIbMaster => coreRxAxisMaster,
      dmaIbSlave  => coreRxAxisSlave,
      dmaObMaster => coreTxAxisMaster,
      dmaObSlave  => coreTxAxisSlave,

      phyReady      => phyReady,
      gth_resetdone => gth_resetdone,

      ethConfig => ethConfig,
      ethStatus => ethStatus,

      -- GMII PHY Interface
      gmiiRxDv => gmiiRxDv,
      gmiiRxEr => gmiiRxEr,
      gmiiRxd  => gmiiRxd,
      gmiiTxEn => gmiiTxEn,
      gmiiTxEr => gmiiTxEr,
      gmiiTxd  => gmiiTxd,
      -- XGMII PHY Interface
      xgmiiRxd => xgmiiRxd,
      xgmiiRxc => xgmiiRxc,
      xgmiiTxd => xgmiiTxd,
      xgmiiTxc => xgmiiTxc,
      --
      ethClk => ethClk,
      ethRst => ethRst
    );

  ------------------------------------------------------------------------------------------------
  -- Wrap AXI-Stream DMA Interface
  coreTxAxisMaster.tdata(s_core_tx_tdata'range) <= s_core_tx_tdata;
  coreTxAxisMaster.tuser(s_core_tx_tuser'range) <= s_core_tx_tuser;
  coreTxAxisMaster.tkeep(s_core_tx_tkeep'range) <= s_core_tx_tkeep;
  coreTxAxisMaster.tlast                        <= s_core_tx_tlast;
  coreTxAxisMaster.tvalid                       <= s_core_tx_tvalid;
  s_core_tx_tready                              <= coreTxAxisSlave.tready;
  --
  m_core_rx_tdata        <= coreRxAxisMaster.tdata(m_core_rx_tdata'range);
  m_core_rx_tuser        <= coreRxAxisMaster.tuser(m_core_rx_tuser'range);
  m_core_rx_tkeep        <= coreRxAxisMaster.tkeep(m_core_rx_tkeep'range);
  m_core_rx_tlast        <= coreRxAxisMaster.tlast;
  m_core_rx_tvalid       <= coreRxAxisMaster.tvalid;
  coreRxAxisSlave.tready <= m_core_rx_tready;
  one_g_inst : if IS_10G = FALSE generate
    phyReady <= gth_status_vector(1);
    ethClk   <= userClk;
    u_eth_clk_125_rst_sync : xpm_cdc_sync_rst
    generic map(
      DEST_SYNC_FF => 3
    )
    port map
    (
      dest_rst => ethRst,
      dest_clk => userClk,
      src_rst  => core_rst);
  end generate;
  ------------------------------------------------------------------------------------------------
  -- 10GBASE-R's Reset Module
  ten_g_inst : if IS_10G = TRUE generate
    U_TenGigEthRst : entity surf.TenGigEthGthUltraScaleRstSim
      generic map(
        TPD_G => TPD_G)
      port map
      (
        coreClk   => core_clk,
        coreRst   => core_rst,
        txGtClk   => userClk,
        txRstdone => gth_reset_tx_user_L,
        rxRstdone => gth_reset_rx_user_L,
        phyClk    => ethClk,
        phyRst    => ethRst,
        phyReady  => phyReady
      );

  end generate;

   gth_reset_tx_user_L <= not gth_reset_tx_user;
   gth_reset_rx_user_L <= not gth_reset_rx_user;

end rtl;
