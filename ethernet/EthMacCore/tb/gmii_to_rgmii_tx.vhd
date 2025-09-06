library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

library UNISIM;
use UNISIM.vcomponents.all;

entity gmii_to_rgmii_tx is
  port (
    clk125 : in std_logic; --! 125 MHz system clock
    clk125s : in std_logic; --! 125 MHz system clock

    gmii_txd   : in std_logic_vector(7 downto 0); --! GMII input interface
    gmii_tx_en : in std_logic; --! GMII input interface
    gmii_tx_er : in std_logic; --! GMII input interface

    rgmii_txd    : out std_logic_vector(3 downto 0); --! rgmii output interface
    rgmii_tx_ctl : out std_logic; --! rgmii output interface
    rgmii_tx_clk : out std_logic --! rgmii output interface
  );
end gmii_to_rgmii_tx;

architecture Behavioral of gmii_to_rgmii_tx is
  signal txd_r : std_logic_vector(3 downto 0); --! tx data for rising edge
  signal txd_f : std_logic_vector(3 downto 0); --! tx data for falling edge
  signal ctl_r : std_logic; --! ctrl rising data
  signal ctl_f : std_logic; --! ctrl falling data

  attribute IODELAY_GROUP              : string;
  --attribute IODELAY_GROUP of datadelay_f_inst : label is "eth_delay";
  --attribute IODELAY_GROUP of datadelay_r_inst : label is "eth_delay";
  --attribute IODELAY_GROUP of datactrl_f_inst : label is "eth_delay";
  --attribute IODELAY_GROUP of datactrl_r_inst : label is "eth_delay";
  --attribute IODELAY_GROUP of IDELAYE3_inst : label is "eth_delay";
  --attribute IODELAY_GROUP of ctl_delay : label is "rgmmi_delay_group";

  signal delayed_txd_r : std_logic_vector(3 downto 0); --! tx data for rising edge
  signal delayed_txd_f : std_logic_vector(3 downto 0); --! tx data for falling edge
  signal delayed_ctl_r : std_logic; --! ctrl rising data
  signal delayed_ctl_f : std_logic; --! ctrl falling data
  signal delay_tx_clk :  std_logic; --! rgmii output interface
  signal delay_tx0_clk :  std_logic; --! rgmii output interface
begin
  --! rearrange data to be clocked out
  rearranhe_data : process (clk125)
  begin
    if rising_edge(clk125) then
      txd_r <= gmii_txd(3 downto 0);
      txd_f <= gmii_txd(7 downto 4);

      ctl_r <= gmii_tx_en;
      ctl_f <= gmii_tx_en xor gmii_tx_er;
    end if;
  end process;
  gen_oddr_txd : for i in 0 to 3 generate
    --! Clock out data
    ODDR_inst : ODDR
    generic map(
      DDR_CLK_EDGE => "SAME_EDGE", INIT => '0', SRTYPE => "SYNC"
    )
    port map
    (
      Q  => rgmii_txd(i),
      C  => clk125, --delay_tx0_clk,
      CE => '1',
      D1 => txd_r(i), --delayed_txd_r(i),
      D2 => txd_f(i), --delayed_txd_f(i),
      R  => '0',
      S  => '0'
    );
  --datadelay_f_inst : IDELAYE2
  --generic map(
  --  CINVCTRL_SEL          => "FALSE", -- Enable dynamic clock inversion (FALSE, TRUE)
  --  DELAY_SRC             => "DATAIN", -- Delay input (IDATAIN, DATAIN)
  --  HIGH_PERFORMANCE_MODE => "FALSE", -- Reduced jitter ("TRUE"), Reduced power ("FALSE")
  --  IDELAY_TYPE           => "FIXED", -- FIXED, VARIABLE, VAR_LOAD, VAR_LOAD_PIPE
  --  IDELAY_VALUE          => 0, -- Input delay tap setting (0-31)
  --  PIPE_SEL              => "FALSE", -- Select pipelined mode, FALSE, TRUE
  --  REFCLK_FREQUENCY      => 200.0, -- IDELAYCTRL clock input frequency in MHz (190.0-210.0, 290.0-310.0).
  --  SIGNAL_PATTERN        => "DATA" -- DATA, CLOCK input signal
  --)
  --port map
  --(
  --  CNTVALUEOUT => open, -- 5-bit output: Counter value output
  --  DATAOUT     => delayed_txd_f(i), -- 1-bit output: Delayed data output
  --  C           => '0', -- 1-bit input: Clock input
  --  CE          => '0', -- 1-bit input: Active high enable increment/decrement input
  --  CINVCTRL    => '0', -- 1-bit input: Dynamic clock inversion input
  --  CNTVALUEIN  => "00000", -- 5-bit input: Counter value input
  --  DATAIN      => txd_f(i), -- 1-bit input: Internal delay data input
  --  IDATAIN     => '0', -- 1-bit input: Data input from the I/O
  --  INC         => '0', -- 1-bit input: Increment / Decrement tap delay input
  --  LD          => '0', -- 1-bit input: Load IDELAY_VALUE input
  --  LDPIPEEN    => '0', -- 1-bit input: Enable PIPELINE register to load data input
  --  REGRST      => '0' -- 1-bit input: Active-high reset tap-delay input
  --);
  --datadelay_r_inst : IDELAYE2
  --generic map(
  --  CINVCTRL_SEL          => "FALSE", -- Enable dynamic clock inversion (FALSE, TRUE)
  --  DELAY_SRC             => "DATAIN", -- Delay input (IDATAIN, DATAIN)
  --  HIGH_PERFORMANCE_MODE => "FALSE", -- Reduced jitter ("TRUE"), Reduced power ("FALSE")
  --  IDELAY_TYPE           => "FIXED", -- FIXED, VARIABLE, VAR_LOAD, VAR_LOAD_PIPE
  --  IDELAY_VALUE          => 0, -- Input delay tap setting (0-31)
  --  PIPE_SEL              => "FALSE", -- Select pipelined mode, FALSE, TRUE
  --  REFCLK_FREQUENCY      => 200.0, -- IDELAYCTRL clock input frequency in MHz (190.0-210.0, 290.0-310.0).
  --  SIGNAL_PATTERN        => "DATA" -- DATA, CLOCK input signal
  --)
  --port map
  --(
  --  CNTVALUEOUT => open, -- 5-bit output: Counter value output
  --  DATAOUT     => delayed_txd_r(i), -- 1-bit output: Delayed data output
  --  C           => '0', -- 1-bit input: Clock input
  --  CE          => '0', -- 1-bit input: Active high enable increment/decrement input
  --  CINVCTRL    => '0', -- 1-bit input: Dynamic clock inversion input
  --  CNTVALUEIN  => "00000", -- 5-bit input: Counter value input
  --  DATAIN      => txd_r(i), -- 1-bit input: Internal delay data input
  --  IDATAIN     => '0', -- 1-bit input: Data input from the I/O
  --  INC         => '0', -- 1-bit input: Increment / Decrement tap delay input
  --  LD          => '0', -- 1-bit input: Load IDELAY_VALUE input
  --  LDPIPEEN    => '0', -- 1-bit input: Enable PIPELINE register to load data input
  --  REGRST      => '0' -- 1-bit input: Active-high reset tap-delay input
  --);
  end generate;

  --! Output ctrl as DDR: TX_CTL => D1 = TX_EN, D2 = TX_EN XOR TX_ER
  ODDR_ctl : ODDR
  generic map(
    DDR_CLK_EDGE => "SAME_EDGE", INIT => '0', SRTYPE => "SYNC"
  )
  port map
  (
    Q  => rgmii_tx_ctl,
    C  => clk125, --delay_tx0_clk,
    CE => '1',
    D1 => ctl_r, --delayed_ctl_r,
    D2 => ctl_f, --delayed_ctl_f,
    R  => '0',
    S  => '0'
  );
  --datactrl_r_inst : IDELAYE2
  --generic map(
  --  CINVCTRL_SEL          => "FALSE", -- Enable dynamic clock inversion (FALSE, TRUE)
  --  DELAY_SRC             => "DATAIN", -- Delay input (IDATAIN, DATAIN)
  --  HIGH_PERFORMANCE_MODE => "FALSE", -- Reduced jitter ("TRUE"), Reduced power ("FALSE")
  --  IDELAY_TYPE           => "FIXED", -- FIXED, VARIABLE, VAR_LOAD, VAR_LOAD_PIPE
  --  IDELAY_VALUE          => 0, -- Input delay tap setting (0-31)
  --  PIPE_SEL              => "FALSE", -- Select pipelined mode, FALSE, TRUE
  --  REFCLK_FREQUENCY      => 200.0, -- IDELAYCTRL clock input frequency in MHz (190.0-210.0, 290.0-310.0).
  --  SIGNAL_PATTERN        => "DATA" -- DATA, CLOCK input signal
  --)
  --port map
  --(
  --  CNTVALUEOUT => open, -- 5-bit output: Counter value output
  --  DATAOUT     => delayed_ctl_r, -- 1-bit output: Delayed data output
  --  C           => '0', -- 1-bit input: Clock input
  --  CE          => '0', -- 1-bit input: Active high enable increment/decrement input
  --  CINVCTRL    => '0', -- 1-bit input: Dynamic clock inversion input
  --  CNTVALUEIN  => "00000", -- 5-bit input: Counter value input
  --  DATAIN      => ctl_r, -- 1-bit input: Internal delay data input
  --  IDATAIN     => '0', -- 1-bit input: Data input from the I/O
  --  INC         => '0', -- 1-bit input: Increment / Decrement tap delay input
  --  LD          => '0', -- 1-bit input: Load IDELAY_VALUE input
  --  LDPIPEEN    => '0', -- 1-bit input: Enable PIPELINE register to load data input
  --  REGRST      => '0' -- 1-bit input: Active-high reset tap-delay input
  --);
  --datactrl_f_inst : IDELAYE2
  --generic map(
  --  CINVCTRL_SEL          => "FALSE", -- Enable dynamic clock inversion (FALSE, TRUE)
  --  DELAY_SRC             => "DATAIN", -- Delay input (IDATAIN, DATAIN)
  --  HIGH_PERFORMANCE_MODE => "FALSE", -- Reduced jitter ("TRUE"), Reduced power ("FALSE")
  --  IDELAY_TYPE           => "FIXED", -- FIXED, VARIABLE, VAR_LOAD, VAR_LOAD_PIPE
  --  IDELAY_VALUE          => 0, -- Input delay tap setting (0-31)
  --  PIPE_SEL              => "FALSE", -- Select pipelined mode, FALSE, TRUE
  --  REFCLK_FREQUENCY      => 200.0, -- IDELAYCTRL clock input frequency in MHz (190.0-210.0, 290.0-310.0).
  --  SIGNAL_PATTERN        => "DATA" -- DATA, CLOCK input signal
  --)
  --port map
  --(
  --  CNTVALUEOUT => open, -- 5-bit output: Counter value output
  --  DATAOUT     => delayed_ctl_f, -- 1-bit output: Delayed data output
  --  C           => '0', -- 1-bit input: Clock input
  --  CE          => '0', -- 1-bit input: Active high enable increment/decrement input
  --  CINVCTRL    => '0', -- 1-bit input: Dynamic clock inversion input
  --  CNTVALUEIN  => "00000", -- 5-bit input: Counter value input
  --  DATAIN      => ctl_f, -- 1-bit input: Internal delay data input
  --  IDATAIN     => '0', -- 1-bit input: Data input from the I/O
  --  INC         => '0', -- 1-bit input: Increment / Decrement tap delay input
  --  LD          => '0', -- 1-bit input: Load IDELAY_VALUE input
  --  LDPIPEEN    => '0', -- 1-bit input: Enable PIPELINE register to load data input
  --  REGRST      => '0' -- 1-bit input: Active-high reset tap-delay input
  --);
  --! Generate RGMII TX clock (DDR 125 MHz clock)
  ODDR_clk : ODDR
  generic map(
    DDR_CLK_EDGE => "SAME_EDGE", INIT => '0', SRTYPE => "SYNC"
  )
  port map
  (
    Q  => rgmii_tx_clk,
    C  => clk125s, --delay_tx_clk,
    CE => '1',
    D1 => '1',
    D2 => '0',
    R  => '0',
    S  => '0'
  );
  --IDELAYE3_inst : IDELAYE2
  --generic map(
  --  CINVCTRL_SEL          => "FALSE", -- Enable dynamic clock inversion (FALSE, TRUE)
  --  DELAY_SRC             => "DATAIN", -- Delay input (IDATAIN, DATAIN)
  --  HIGH_PERFORMANCE_MODE => "FALSE", -- Reduced jitter ("TRUE"), Reduced power ("FALSE")
  --  IDELAY_TYPE           => "FIXED", -- FIXED, VARIABLE, VAR_LOAD, VAR_LOAD_PIPE
  --  IDELAY_VALUE          => 0, -- Input delay tap setting (0-31)
  --  PIPE_SEL              => "FALSE", -- Select pipelined mode, FALSE, TRUE
  --  REFCLK_FREQUENCY      => 200.0, -- IDELAYCTRL clock input frequency in MHz (190.0-210.0, 290.0-310.0).
  --  SIGNAL_PATTERN        => "CLOCK" -- DATA, CLOCK input signal
  --)
  --port map
  --(
  --  CNTVALUEOUT => open, -- 5-bit output: Counter value output
  --  DATAOUT     => delay_tx_clk, -- 1-bit output: Delayed data output
  --  C           => '0', -- 1-bit input: Clock input
  --  CE          => '0', -- 1-bit input: Active high enable increment/decrement input
  --  CINVCTRL    => '0', -- 1-bit input: Dynamic clock inversion input
  --  CNTVALUEIN  => "00000", -- 5-bit input: Counter value input
  --  DATAIN      => clk125, -- 1-bit input: Internal delay data input
  --  IDATAIN     => '0', -- 1-bit input: Data input from the I/O
  --  INC         => '0', -- 1-bit input: Increment / Decrement tap delay input
  --  LD          => '0', -- 1-bit input: Load IDELAY_VALUE input
  --  LDPIPEEN    => '0', -- 1-bit input: Enable PIPELINE register to load data input
  --  REGRST      => '0' -- 1-bit input: Active-high reset tap-delay input
  --);



end Behavioral;