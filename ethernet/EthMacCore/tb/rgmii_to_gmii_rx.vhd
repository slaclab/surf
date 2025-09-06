----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 06/12/2025 04:15:49 PM
-- Design Name: 
-- Module Name: rgmii_to_gmii_rx - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

library UNISIM;
use UNISIM.vcomponents.all;
entity rgmii_to_gmii_rx is
  port (
    -- The following signals are in the RGMII in-band status signals
    link_status   : out std_logic;
    clock_speed   : out std_logic_vector(1 downto 0);
    duplex_status : out std_logic;
    update        : out std_logic;

    locked        : out std_logic;
    clk_rx        : out std_logic;
    clk_tx        : out std_logic;
    rst           : in std_logic;

    rgmii_rx_clk : in std_logic;
    rgmii_rxd    : in std_logic_vector(3 downto 0);
    rgmii_rx_ctl : in std_logic;

    gmii_rxd   : out std_logic_vector(7 downto 0);
    gmii_rx_dv : out std_logic;
    gmii_rx_er : out std_logic
  );
end rgmii_to_gmii_rx;

architecture Behavioral of rgmii_to_gmii_rx is
  signal rxd_r, rxd_f      : std_logic_vector(3 downto 0);
  signal ctl_r, ctl_f, clk : std_logic;
  signal inband_ce         : std_logic;
  signal delay_rx_clk      : std_logic;
  signal delay_rxd         : std_logic_vector(3 downto 0);
  signal delay_rx_ctl      : std_logic;
  attribute IODELAY_GROUP              : string;
  --attribute IODELAY_GROUP of IDELAYE2_data_inst : label is "eth_delay";
  ----attribute IODELAY_GROUP of IDELAYE2_data_inst : label is "eth_delay";
  attribute IODELAY_GROUP of IDELAYE2_inst : label is "eth_delay";
--  attribute IODELAY_GROUP of gen_iddr_rxd(0).IDELAYE2_data_inst : label is "eth_delay";
--  attribute IODELAY_GROUP of gen_iddr_rxd(1).IDELAYE2_data_inst : label is "eth_delay";
--  attribute IODELAY_GROUP of gen_iddr_rxd(2).IDELAYE2_data_inst : label is "eth_delay";
--  attribute IODELAY_GROUP of gen_iddr_rxd(3).IDELAYE2_data_inst : label is "eth_delay";
  
  signal clkfb, clkfd_buf : std_logic;
  signal clktx_buf : std_logic;
  signal clkrx, clkrx_buf : std_logic;
begin
  -----------------------------------------------------------------------------------------------
  -- clock buffers
  -----------------------------------------------------------------------------------------------
  clk_rx <= clk;
  clk_tx_inst : BUFG
  port map
  (
    O => clk_tx, -- 1-bit output: Clock output
    I => clktx_buf --delay_rx_clk -- 1-bit input: Clock input
  );
  clkrx_inst : BUFG
  port map
  (
    O => clkrx, -- 1-bit output: Clock output
    I => clkrx_buf --delay_rx_clk -- 1-bit input: Clock input
  );
  clk_fd_inst : BUFG
  port map
  (
    O => clkfb, -- 1-bit output: Clock output
    I => clkfd_buf --delay_rx_clk -- 1-bit input: Clock input
  );
  BUFG_inst : BUFG
  port map
  (
    O => clk, -- 1-bit output: Clock output
    I => rgmii_rx_clk --delay_rx_clk -- 1-bit input: Clock input
  );
  MMCME2_BASE_inst : MMCME2_BASE
  generic map(
    BANDWIDTH       => "OPTIMIZED", -- Jitter programming (OPTIMIZED, HIGH, LOW)
    CLKFBOUT_MULT_F => 8.0, -- Multiply value for all CLKOUT (2.000-64.000).
    CLKFBOUT_PHASE  => 0.0, -- Phase offset in degrees of CLKFB (-360.000-360.000).
    CLKIN1_PERIOD   => 8.0, -- Input clock period in ns to ps resolution (i.e. 33.333 is 30 MHz).
    -- CLKOUT0_DIVIDE - CLKOUT6_DIVIDE: Divide amount for each CLKOUT (1-128)
    CLKOUT1_DIVIDE   => 8,
    CLKOUT2_DIVIDE   => 1,
    CLKOUT3_DIVIDE   => 1,
    CLKOUT4_DIVIDE   => 1,
    CLKOUT5_DIVIDE   => 1,
    CLKOUT6_DIVIDE   => 1,
    CLKOUT0_DIVIDE_F => 8.0, -- Divide amount for CLKOUT0 (1.000-128.000).
    -- CLKOUT0_DUTY_CYCLE - CLKOUT6_DUTY_CYCLE: Duty cycle for each CLKOUT (0.01-0.99).
    CLKOUT0_DUTY_CYCLE => 0.5,
    CLKOUT1_DUTY_CYCLE => 0.5,
    CLKOUT2_DUTY_CYCLE => 0.5,
    CLKOUT3_DUTY_CYCLE => 0.5,
    CLKOUT4_DUTY_CYCLE => 0.5,
    CLKOUT5_DUTY_CYCLE => 0.5,
    CLKOUT6_DUTY_CYCLE => 0.5,
    -- CLKOUT0_PHASE - CLKOUT6_PHASE: Phase offset for each CLKOUT (-360.000-360.000).
    CLKOUT0_PHASE   => 0.0,
    CLKOUT1_PHASE   => 90.0,
    CLKOUT2_PHASE   => 0.0,
    CLKOUT3_PHASE   => 0.0,
    CLKOUT4_PHASE   => 0.0,
    CLKOUT5_PHASE   => 0.0,
    CLKOUT6_PHASE   => 0.0,
    CLKOUT4_CASCADE => FALSE, -- Cascade CLKOUT4 counter with CLKOUT6 (FALSE, TRUE)
    DIVCLK_DIVIDE   => 1, -- Master division value (1-106)
    REF_JITTER1     => 0.0, -- Reference input jitter in UI (0.000-0.999).
    STARTUP_WAIT    => FALSE -- Delays DONE until MMCM is locked (FALSE, TRUE)
  )
  port map
  (
    -- Clock Outputs: 1-bit (each) output: User configurable clock outputs
    CLKOUT0  => clkrx_buf, -- 1-bit output: CLKOUT0
    CLKOUT0B => open, -- 1-bit output: Inverted CLKOUT0
    CLKOUT1  => clktx_buf, -- 1-bit output: CLKOUT1
    CLKOUT1B => open, -- 1-bit output: Inverted CLKOUT1
    CLKOUT2  => open, -- 1-bit output: CLKOUT2
    CLKOUT2B => open, -- 1-bit output: Inverted CLKOUT2
    CLKOUT3  => open, -- 1-bit output: CLKOUT3
    CLKOUT3B => open, -- 1-bit output: Inverted CLKOUT3
    CLKOUT4  => open, -- 1-bit output: CLKOUT4
    CLKOUT5  => open, -- 1-bit output: CLKOUT5
    CLKOUT6  => open, -- 1-bit output: CLKOUT6
    -- Feedback Clocks: 1-bit (each) output: Clock feedback ports
    CLKFBOUT  => clkfd_buf, -- 1-bit output: Feedback clock
    CLKFBOUTB => open, -- 1-bit output: Inverted CLKFBOUT
    -- Status Ports: 1-bit (each) output: MMCM status ports
    LOCKED => locked, -- 1-bit output: LOCK
    -- Clock Inputs: 1-bit (each) input: Clock input
    CLKIN1 => clk, -- 1-bit input: Clock
    -- Control Ports: 1-bit (each) input: MMCM control ports
    PWRDWN => '0', -- 1-bit input: Power-down
    RST    => rst, -- 1-bit input: Reset
    -- Feedback Clocks: 1-bit (each) input: Clock feedback ports
    CLKFBIN => clkfb -- 1-bit input: Feedback clock
  );
  --IDELAYE2_data_inst : IDELAYE2
  --generic map(
  --  CINVCTRL_SEL          => "FALSE", -- Enable dynamic clock inversion (FALSE, TRUE)
  --  DELAY_SRC             => "IDATAIN", -- Delay input (IDATAIN, DATAIN)
  --  HIGH_PERFORMANCE_MODE => "FALSE", -- Reduced jitter ("TRUE"), Reduced power ("FALSE")
  --  IDELAY_TYPE           => "FIXED", -- FIXED, VARIABLE, VAR_LOAD, VAR_LOAD_PIPE
  --  IDELAY_VALUE          => 20, -- Input delay tap setting (0-31)
  --  PIPE_SEL              => "FALSE", -- Select pipelined mode, FALSE, TRUE
  --  REFCLK_FREQUENCY      => 200.0, -- IDELAYCTRL clock input frequency in MHz (190.0-210.0, 290.0-310.0).
  --  SIGNAL_PATTERN        => "CLOCK" -- DATA, CLOCK input signal
  --)
  --port map
  --(
  --  CNTVALUEOUT => open, -- 5-bit output: Counter value output
  --  DATAOUT     => delay_rx_clk, -- 1-bit output: Delayed data output
  --  C           => '0', -- 1-bit input: Clock input
  --  CE          => '0', -- 1-bit input: Active high enable increment/decrement input
  --  CINVCTRL    => '0', -- 1-bit input: Dynamic clock inversion input
  --  CNTVALUEIN  => "00000", -- 5-bit input: Counter value input
  --  DATAIN      => '0', -- 1-bit input: Internal delay data input
  --  IDATAIN     => rgmii_rx_clk, -- 1-bit input: Data input from the I/O
  --  INC         => '0', -- 1-bit input: Increment / Decrement tap delay input
  --  LD          => '0', -- 1-bit input: Load IDELAY_VALUE input
  --  LDPIPEEN    => '0', -- 1-bit input: Enable PIPELINE register to load data input
  --  REGRST      => '0' -- 1-bit input: Active-high reset tap-delay input
  --);
  --clk <= rgmii_rx_clk;
  gen_iddr_rxd : for i in 0 to 3 generate
    IDDR_inst : IDDR
    generic map(
      DDR_CLK_EDGE => "SAME_EDGE_PIPELINED", INIT_Q1 => '0', INIT_Q2 => '0', SRTYPE => "SYNC"
    )
    port map
    (
      Q1 => rxd_r(i),
      Q2 => rxd_f(i),
      C  => clk,
      CE => '1',
      D  => delay_rxd(i), --rgmii_rxd(i), --delay_rxd(i),
      R  => '0',
      S  => '0'
    );
    IDELAYE2_data_inst : IDELAYE2
    generic map(
      CINVCTRL_SEL          => "FALSE", -- Enable dynamic clock inversion (FALSE, TRUE)
      DELAY_SRC             => "IDATAIN", -- Delay input (IDATAIN, DATAIN)
      HIGH_PERFORMANCE_MODE => "TRUE", -- Reduced jitter ("TRUE"), Reduced power ("FALSE")
      IDELAY_TYPE           => "FIXED", -- FIXED, VARIABLE, VAR_LOAD, VAR_LOAD_PIPE
      IDELAY_VALUE          => 12, -- Input delay tap setting (0-31)
      PIPE_SEL              => "FALSE", -- Select pipelined mode, FALSE, TRUE
      REFCLK_FREQUENCY      => 200.0, -- IDELAYCTRL clock input frequency in MHz (190.0-210.0, 290.0-310.0).
      SIGNAL_PATTERN        => "DATA" -- DATA, CLOCK input signal
    )
    port map
    (
      CNTVALUEOUT => open, -- 5-bit output: Counter value output
      DATAOUT     => delay_rxd(i), -- 1-bit output: Delayed data output
      C           => clk, -- 1-bit input: Clock input
      CE          => '0', -- 1-bit input: Active high enable increment/decrement input
      CINVCTRL    => '0', -- 1-bit input: Dynamic clock inversion input
      CNTVALUEIN  => "00000", -- 5-bit input: Counter value input
      DATAIN      => '0', -- 1-bit input: Internal delay data input
      IDATAIN     => rgmii_rxd(i), -- 1-bit input: Data input from the I/O
      INC         => '0', -- 1-bit input: Increment / Decrement tap delay input
      LD          => '0', -- 1-bit input: Load IDELAY_VALUE input
      LDPIPEEN    => '0', -- 1-bit input: Enable PIPELINE register to load data input
      REGRST      => '0' -- 1-bit input: Active-high reset tap-delay input
    );
  end generate;

  IDDR_ctl : IDDR
  generic map(
    DDR_CLK_EDGE => "SAME_EDGE_PIPELINED", INIT_Q1 => '0', INIT_Q2 => '0', SRTYPE => "SYNC"
  )
  port map
  (
    Q1 => ctl_r,
    Q2 => ctl_f,
    C  => clk,
    CE => '1',
    D  => delay_rx_ctl, --,rgmii_rx_ctl
    R  => '0',
    S  => '0'
  );
  IDELAYE2_inst : IDELAYE2
  generic map(
    CINVCTRL_SEL          => "FALSE", -- Enable dynamic clock inversion (FALSE, TRUE)
    DELAY_SRC             => "IDATAIN", -- Delay input (IDATAIN, DATAIN)
    HIGH_PERFORMANCE_MODE => "TRUE", -- Reduced jitter ("TRUE"), Reduced power ("FALSE")
    IDELAY_TYPE           => "FIXED", -- FIXED, VARIABLE, VAR_LOAD, VAR_LOAD_PIPE
    IDELAY_VALUE          => 12, -- Input delay tap setting (0-31)
    PIPE_SEL              => "FALSE", -- Select pipelined mode, FALSE, TRUE
    REFCLK_FREQUENCY      => 200.0, -- IDELAYCTRL clock input frequency in MHz (190.0-210.0, 290.0-310.0).
    SIGNAL_PATTERN        => "DATA" -- DATA, CLOCK input signal
  )
  port map
  (
    CNTVALUEOUT => open, -- 5-bit output: Counter value output
    DATAOUT     => delay_rx_ctl, -- 1-bit output: Delayed data output
    C           => clk, -- 1-bit input: Clock input
    CE          => '0', -- 1-bit input: Active high enable increment/decrement input
    CINVCTRL    => '0', -- 1-bit input: Dynamic clock inversion input
    CNTVALUEIN  => "00000", -- 5-bit input: Counter value input
    DATAIN      => '0', -- 1-bit input: Internal delay data input
    IDATAIN     => rgmii_rx_ctl, -- 1-bit input: Data input from the I/O
    INC         => '0', -- 1-bit input: Increment / Decrement tap delay input
    LD          => '0', -- 1-bit input: Load IDELAY_VALUE input
    LDPIPEEN    => '0', -- 1-bit input: Enable PIPELINE register to load data input
    REGRST      => '0' -- 1-bit input: Active-high reset tap-delay input
  );

  -----------------------------------------------------------------------------
  -- RGMII Inband Status Registers :
  -- extract the inband status from received rgmii data
  -----------------------------------------------------------------------------

  -- Enable inband status registers during Interframe Gap
  inband_ce <= ctl_r nor (ctl_r xor ctl_f);
  reg_inband_status : process (clk)
  begin
    if clk'event and clk = '1' then
      if inband_ce = '1' then
        link_status             <= rxd_r(0);
        clock_speed(1 downto 0) <= rxd_r(2 downto 1);
        duplex_status           <= rxd_r(3);
        update                  <= '1';
      else
        update <= '0';
      end if;
    end if;
  end process reg_inband_status;
  -- Combine captured data
  gmii_rxd   <= rxd_f & rxd_r;
  gmii_rx_dv <= ctl_r;
  gmii_rx_er <= ctl_r xor ctl_f;

end Behavioral;