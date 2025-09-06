library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;
use surf.AxiLitePkg.all;
use surf.SsiPkg.all;
use surf.EthMacPkg.all;
use surf.GigEthPkg.all;

entity tb_gmii_arp_receiver is
end entity;

architecture sim of tb_gmii_arp_receiver is

    signal clk         : std_logic := '0';
    signal rst         : std_logic := '1';
    signal gmii_rx_dv  : std_logic := '0';
    signal gmii_rxd    : std_logic_vector(7 downto 0) := (others => '0');

    constant CLK_PERIOD : time := 8 ns; -- 125 MHz
    signal gmii_rx_er : std_logic := '0';

    -- Packet Data
    type pkt_array is array (0 to 53) of std_logic_vector(7 downto 0);
    constant arp_packet : pkt_array := (
        x"55", x"55", x"55", x"55", x"55", x"55", x"55", x"d5",
        x"cc", x"fe", x"a9", x"c5", x"c0", x"01",
        x"b4", x"2e", x"99", x"32", x"96", x"f3",
        x"08", x"06",
        x"00", x"01",
        x"08", x"00",
        x"06", x"04",
        x"00", x"02",
        x"b4", x"2e", x"99", x"32", x"96", x"f3",
        x"0a", x"f0", x"e5", x"fa",
        x"cc", x"fe", x"a9", x"c5", x"c0", x"01",
        x"0a", x"f0", x"e5", x"16",
        x"a5", x"8a", x"47", x"ec" -- FCS ("CRC")
    );
  signal m_core_rx_tdata  : std_logic_vector(127 downto 0);
  signal m_core_rx_tuser  : std_logic_vector(1 downto 0);
  signal m_core_rx_tkeep  : std_logic_vector(15 downto 0);
  signal m_core_rx_tlast  : std_logic;
  signal m_core_rx_tvalid : std_logic;
  signal m_core_rx_tready : std_logic := '1';

  signal s_core_tx_tdata  : std_logic_vector(127 downto 0);
  signal s_core_tx_tuser  : std_logic_vector(1 downto 0);
  signal s_core_tx_tkeep  : std_logic_vector(15 downto 0);
  signal s_core_tx_tlast  : std_logic;
  signal s_core_tx_tvalid : std_logic;
  signal s_core_tx_tready : std_logic := '1';

  signal gmii_txd   : std_logic_vector(7 downto 0);
  signal gmii_tx_en : std_logic;
  signal gmii_tx_er : std_logic;
  signal xgmiiRxd : std_logic_vector(63 downto 0) := (others => '0');
  signal xgmiiRxc : std_logic_vector(7 downto 0)  := (others => '0');
  signal xgmiiTxd : std_logic_vector(63 downto 0);
  signal xgmiiTxc : std_logic_vector(7 downto 0);
  signal gth_status_vector : std_logic_vector(15 downto 0) := (others => '1');
  signal gth_reset_tx_user : std_logic                     := '0';
  signal gth_reset_rx_user : std_logic                     := '1';
  signal gth_resetdone     : std_logic;

  signal an_configuration_vector : std_logic_vector(15 downto 0) := x"0000";
  signal an_adv_config_vector    : std_logic_vector(15 downto 0) := x"0020";
  signal an_restart_config       : std_logic                     := '0';
  signal an_interrupt            : std_logic                     := '0';
  signal local_mac     : std_logic_vector(47 downto 0) := x"01c0c5a9fecc";

  signal update, eth_reset_n, eth_reset_sn : std_logic := '0';
begin

    ethernet_mac_inst: entity surf.ethernet_mac
     generic map(
        RST_POLARITY_G => '0',
        IS_10G         => false,
        SIMULATION_G   => false,
        DEBUG_G        => "false",
        SYNTH_MODE_G   => "xpm",
        PHY_TYPE_G     => "GMII", -- "GMII", "XGMII", or "XLGMII"
        MEMORY_TYPE_G  => "block"
    )
     port map(
        userClk  => clk,
        core_clk => clk,
        core_rst => eth_reset_sn,

        -- Static configuration
        local_mac => local_mac,
        --
        -- GT reference clock

        gth_status_vector => gth_status_vector,
        gth_reset_tx_user => gth_reset_tx_user,
        gth_reset_rx_user => gth_reset_rx_user,
        gth_resetdone     => gth_resetdone,

        an_configuration_vector => an_configuration_vector,
        an_adv_config_vector    => an_adv_config_vector,
        an_restart_config       => an_restart_config,
        an_interrupt            => an_interrupt,
        gmiiRxDv => gmii_rx_dv,
        gmiiRxEr => gmii_rx_er,
        gmiiRxd => gmii_rxd,
        gmiiTxEn => gmii_tx_en,
        gmiiTxEr => gmii_tx_er,
        gmiiTxd => gmii_txd,
        xgmiiRxd => xgmiiRxd,
        xgmiiRxc => xgmiiRxc,
        xgmiiTxd => xgmiiTxd,
        xgmiiTxc => xgmiiTxc,
        s_core_tx_tdata => s_core_tx_tdata,
        s_core_tx_tuser => s_core_tx_tuser,
        s_core_tx_tkeep => s_core_tx_tkeep,
        s_core_tx_tlast => s_core_tx_tlast,
        s_core_tx_tvalid => s_core_tx_tvalid,
        s_core_tx_tready => s_core_tx_tready,
        m_core_rx_tdata => m_core_rx_tdata,
        m_core_rx_tuser => m_core_rx_tuser,
        m_core_rx_tkeep => m_core_rx_tkeep,
        m_core_rx_tlast => m_core_rx_tlast,
        m_core_rx_tvalid => m_core_rx_tvalid,
        m_core_rx_tready => m_core_rx_tready
    );
    -- Clock generation
    clk_proc: process
    begin
        clk <= '0';
        wait for CLK_PERIOD / 2;
        clk <= '1';
        wait for CLK_PERIOD / 2;
    end process;

    -- Reset release
    process
    begin
        wait for 1000 ns;
        eth_reset_sn <= '1';--1000 ns
        wait for 1000 ns;
        gth_resetdone <= '1';--1000 ns
        wait for 1000 ns;
        rst <= '0';
        wait;
    end process;

    -- ARP Packet GMII RX Simulation
    receiver_proc: process(clk)
        variable byte_counter : integer := 0;
        variable wait_counter : integer := 0;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                gmii_rx_dv <= '0';
                gmii_rxd <= (others => '0');
                byte_counter := 0;
                wait_counter := 0;
            else
                if wait_counter = 12500 then -- 1 ms at 125 MHz
                    if byte_counter <= 53 then
                        gmii_rx_dv <= '1';
                        gmii_rxd <= arp_packet(byte_counter);
                        byte_counter := byte_counter + 1;
                    else
                        gmii_rx_dv <= '0';
                        gmii_rxd <= (others => '0');
                        byte_counter := 0;
                        wait_counter := 0; -- reset timer for next 1 ms interval
                    end if;
                else
                    if gmii_rx_dv = '0' then
                        wait_counter := wait_counter + 1;
                    end if;
                end if;
            end if;
        end if;
    end process;

end architecture;
