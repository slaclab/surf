-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
-- This modules is for interfacing with the slow ADS1217 ADC. This is an eight
-- channel ADC, with option for external multiplexers (e.g. MAX4781) that are
-- controlled from eight digital outputs of the ADC. This results in a maximum
-- 8*256 = 2048 number of ADC channels. This is assuming there are eight
-- multiplexers, each with 256 inputs that are switched from the eight digital
-- outputs from the ADC. The MAX4781 is an eight channel multiplexer with three
-- control bits. Multiple of these could be combined to reach the total 256
-- input channels.
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
use ieee.math_real.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;
use surf.AxiStreamPkg.all;
use surf.SsiPkg.all;
use surf.AxiAds1217Pkg.all;

entity AxiAds1217Core is
  generic (
    TPD_G             : time := 1 ns;
    SYS_CLK_PERIOD_G  : real := 1.0/(156.25E6); -- 156.25 MHz
    ADC_CLK_PERIOD_G  : real := 1.0/(5.0E6);    -- 5 MHz
    SPI_SCLK_PERIOD_G : real := 1.0/(1.0E6);    -- 1 MHz
    AXIL_ERR_RESP_G   : slv(1 downto 0) := AXI_RESP_DECERR_C;
    NUM_CHANNELS_G    : natural := 8            -- Default using eight channels (same as the number of AIN pins)
  );
  port (
    -- System Clock
    sysClk            : in  sl;
    sysRst            : in  sl;

    -- Trigger Control
    adcStart          : in  sl;

    -- AXI lite slave port for register access
    axilClk           : in  sl;
    axilRst           : in  sl;
    sAxilReadMaster   : in  AxiLiteReadMasterType;
    sAxilReadSlave    : out AxiLiteReadSlaveType;
    sAxilWriteMaster  : in  AxiLiteWriteMasterType;
    sAxilWriteSlave   : out AxiLiteWriteSlaveType;

    -- ADC initialization
    adcAinValues      : in  Slv4Array(NUM_CHANNELS_G-1 downto 0)  := AXI_ADS1217_AIN_PINS_DEFAULT_C;  -- Default using only the AIN pins
    adcDirValues      : in  slv(7 downto 0)                       := (others => '1');                 -- Default all DIO as inputs
    adcDioValues      : in  Slv8Array(NUM_CHANNELS_G-1 downto 0)  := (others => (others => '0'));     -- Default all DIO pins to 0
    pgaValuesInit     : in  Slv3Array(NUM_CHANNELS_G-1 downto 0)  := (others => AXI_ADS1217_PGA_1_C); -- Default all to PGA=1

    -- ADC Interface
    adcRefClk         : out sl;
    adcDrdy           : in  sl;
    adcSclk           : out sl;
    adcDout           : in  sl;
    adcCsL            : out sl;
    adcDin            : out sl
  );
end AxiAds1217Core;


-- Define architecture
architecture rtl of AxiAds1217Core is
  -- TODO: make these accesible from outside as generics
  constant R0_SPEED_C   : slv(0 downto 0)   := "0";             -- "0" - fosc/128, "1" - fosc/256
  constant R0_REFHI_C   : slv(0 downto 0)   := "0";             -- "0" - Vref 1.25, "1" - Vref 2.5
  constant R0_BUFEN_C   : slv(0 downto 0)   := "0";             -- "0" - buffer disabled, "1" - buffer enabled
  constant R2_IDAC1R_C  : slv(1 downto 0)   := "01";            -- "00" - off, "01" - range 1 (0.25mA@1.25Vref) ... "11" - range 3 (1mA@1.25Vref)
  constant R2_IDAC2R_C  : slv(1 downto 0)   := "01";            -- "00" - off, "01" - range 1 (0.25mA@1.25Vref) ... "11" - range 3 (1mA@1.25Vref)
  constant R2_PGA_C     : slv(2 downto 0)   := "000";           -- PGA 1 to 128
  constant R3_IDAC1_C   : slv(7 downto 0)   := toSlv(26, 8);    -- I DAC1 0 to max range
  constant R4_IDAC2_C   : slv(7 downto 0)   := toSlv(26, 8);    -- I DAC2 0 to max range
  constant R5_R6_DEC0_C : slv(10 downto 0)  := toSlv(195, 11);  -- Decimation value
  constant R6_UB_C      : slv(0 downto 0)   := "1";             -- "0" - bipolar, "1" - unipolar
  constant R6_MODE_C    : slv(1 downto 0)   := "00";            -- "00" - auto, "01" - fast ...

  constant ADC_SETUP_REGS_C : Slv8Array(9 downto 0) := (
    0 => "000" & R0_SPEED_C & "1" & R0_REFHI_C & R0_BUFEN_C & "0",    -- SETUP: See above
    1 => AXI_ADS1217_AIN0_C & AXI_ADS1217_AINCOM_C,                   -- MUX: start with MUX set to PSEL=AIN0 and NSEL=AINCOM
    2 => "0" & R2_IDAC1R_C & R2_IDAC2R_C & R2_PGA_C,                  -- ACR: See above
    3 => R3_IDAC1_C,                                                  -- IDAC1: See above
    4 => R4_IDAC2_C,                                                  -- IDAC2: See above
    5 => "00000000",                                                  -- ODAC: offset DAC leave default
    6 => "00000000",                                                  -- DIO: all as LOW
    7 => "11111111",                                                  -- DIR: all as inputs ('1')
    8 => R5_R6_DEC0_C(7 downto 0),                                    -- DEC0: See above
    9 => "0" & R6_UB_C & R6_MODE_C & "0" & R5_R6_DEC0_C(10 downto 8)  -- M/DEC1: See above
  );

  constant CMD_WR_REG_C : slv(3 downto 0) := "0101";
  constant CMD_RESET_C  : slv(7 downto 0) := "11111110";
  constant CMD_DSYNC_C  : slv(7 downto 0) := "11111100";
  constant CMD_RDATA_C  : slv(7 downto 0) := "00000001";

  constant ADC_REFCLK_C : integer := integer(ceil((ADC_CLK_PERIOD_G / SYS_CLK_PERIOD_G) / 2.0)) - 1;
  constant DOUT_WAIT_C  : integer := 60;
  constant WREG_WAIT_C  : integer := 6;
  constant RESET_WAIT_C : integer := 20;

  -- Offsets for the registers based on the number of channels
  constant FIRST_ADC_DATA_RAW_OFFSET_C  : natural := 16#20#;
  constant FIRST_ADC_PGA_VALUE_OFFSET_C : natural := FIRST_ADC_DATA_RAW_OFFSET_C + 4 * (NUM_CHANNELS_G + 1);


  type StateType is (RESET_S, IDLE_S, CMD_SEND_S, CMD_WAIT_S, CMD_DLY_S, WAIT_DRDY_S, READ_DATA_S, STORE_DATA_S);
  signal state, nextState : StateType;

  signal adcDrdyEn    : sl;
  signal adcDrdyD1    : sl;
  signal adcDrdyD2    : sl;
  signal adcStartEn   : sl;
  signal adcStartD1   : sl;
  signal adcStartD2   : sl;
  signal spiWrEn      : sl;
  signal spiWrData    : slv(7 downto 0);
  signal spiRdEn      : sl;
  signal spiRdEnD1    : sl;
  signal spiRdData    : slv(7 downto 0);
  signal cmdCounter   : integer range 0 to 22;
  signal cmdData      : integer range 0 to 22;
  signal cmdLoad      : sl;
  signal cmdEn        : sl;
  signal chSel        : slv(3 downto 0);
  signal byteCounter  : integer range 0 to 3;
  signal byteRst      : sl;
  signal byteEn       : sl;
  signal chCounter    : integer range 0 to NUM_CHANNELS_G;
  signal channelEn    : sl;

  signal waitCounter  : integer range 0 to DOUT_WAIT_C;
  signal waitData     : integer range 0 to DOUT_WAIT_C;
  signal waitLoad     : sl;
  signal waitDone     : sl;

  signal data_23_16   : slv(7 downto 0);
  signal data_15_08   : slv(7 downto 0);

  signal refCounter   : integer range 0 to ADC_REFCLK_C;
  signal refClk       : sl;
  signal refClkEn     : sl;

  signal cslMaster    : sl;
  signal cslCmd       : sl;

  signal adcData      : Slv24Array(NUM_CHANNELS_G-1 downto 0);
  signal adcDataSync  : Slv24Array(NUM_CHANNELS_G-1 downto 0);

  type RegType is record
    streamEn          : sl;
    streamPeriod      : slv(31 downto 0);
    adcStartEnManual  : sl;
    adcPgaValues      : Slv3Array(NUM_CHANNELS_G-1 downto 0);
    sAxilWriteSlave   : AxiLiteWriteSlaveType;
    sAxilReadSlave    : AxiLiteReadSlaveType;
  end record RegType;

  constant REG_INIT_C : RegType := (
    streamEn          => '0',
    streamPeriod      => (others => '0'),
    adcStartEnManual  => '0',
    adcPgaValues      => pgaValuesInit,
    sAxilWriteSlave   => AXI_LITE_WRITE_SLAVE_INIT_C,
    sAxilReadSlave    => AXI_LITE_READ_SLAVE_INIT_C
  );

  signal r   : RegType := REG_INIT_C;
  signal rin : RegType;

begin
  ----------------------------------------------------------------------
  --                AXI-Lite Register Logic
  ----------------------------------------------------------------------
  G_adcDataSync : for i in 0 to NUM_CHANNELS_G-1 generate
    U_SynchronizerVector: entity surf.SynchronizerVector
      generic map (
        WIDTH_G  => 24
      )
      port map (
        clk     => axilClk,
        rst     => axilRst,
        dataIn  => adcData(i),
        dataOut => adcDataSync(i)
      );
  end generate;

  -- Combinatorial process for AXI-lite registers
  comb : process (axilRst, sAxilReadMaster, sAxilWriteMaster, r, adcDataSync) is
      variable v        : RegType;
      variable regCon   : AxiLiteEndPointType;
  begin
    -- Latch the current value
    v := r;

    ----------------------------------------------------------------------
    --                AXI-Lite Register Logic
    ----------------------------------------------------------------------
    -- Determine the transaction type
    axiSlaveWaitTxn(regCon, sAxilWriteMaster, sAxilReadMaster, v.sAxilWriteSlave, v.sAxilReadSlave);

    -- Manual control of start
    axiSlaveRegister(regCon, x"010", 0, v.adcStartEnManual);

    -- Raw ADC data registers
    for i in 0 to NUM_CHANNELS_G-1 loop
      axiSlaveRegisterR(regCon, toSlv(FIRST_ADC_DATA_RAW_OFFSET_C+4*i, 12), 0, adcDataSync(i));
    end loop;

    -- ADC PGA value registers
    for i in 0 to NUM_CHANNELS_G-1 loop
      axiSlaveRegister(regCon, toSlv(FIRST_ADC_PGA_VALUE_OFFSET_C+4*i, 12), 0, v.adcPgaValues(i));
    end loop;

    -- Closeout the transaction
    axiSlaveDefault(regCon, v.sAxilWriteSlave, v.sAxilReadSlave, AXIL_ERR_RESP_G);
    ----------------------------------------------------------------------
    -- Outputs
    sAxilWriteSlave <= r.sAxilWriteSlave;
    sAxilReadSlave  <= r.sAxilReadSlave;

    ----------------------------------------------------------------------
    -- Reset
    if (axilRst = '1') then
      v := REG_INIT_C;
    end if;

    -- Register the variable for next clock cycle
    rin <= v;
  end process comb;

  -- Sequential process for update of register values
  seq : process (axilClk) is
  begin
    if (rising_edge(axilClk)) then
      r <= rin after TPD_G;
    end if;
  end process seq;


  ----------------------------------------------------------------------
  --   ADC data readout logic
  ----------------------------------------------------------------------
  -- ADC reference clock counter
  ref_cnt_p: process (sysClk)
  begin
    if rising_edge(sysClk) then
      if sysRst = '1' then
        refCounter <= 0 after TPD_G;
        refClk <= '0' after TPD_G;
      elsif refCounter >= ADC_REFCLK_C then
        refCounter <= 0 after TPD_G;
        refClk <= not refClk after TPD_G;
      else
        refCounter <= refCounter + 1 after TPD_G;
      end if;
    end if;
  end process;
  adcRefClk <= refClk;
  refClkEn <= '1' when refClk = '1' and refCounter >= ADC_REFCLK_C else '0';

  -- Drdy sync and falling edge detector
  process (sysClk)
  begin
    if rising_edge(sysClk) then
      if sysRst = '1' then
        adcDrdyD1   <= '0' after TPD_G;
        adcDrdyD2   <= '0' after TPD_G;
        adcStartD1  <= '0' after TPD_G;
        adcStartD2  <= '0' after TPD_G;
        spiRdEnD1   <= '0' after TPD_G;
      else
        adcDrdyD1   <= adcDrdy after TPD_G;
        adcDrdyD2   <= adcDrdyD1 after TPD_G;
        adcStartD1  <= adcStart after TPD_G;
        adcStartD2  <= adcStartD1 after TPD_G;
        spiRdEnD1   <= spiRdEn after TPD_G;
      end if;
    end if;
  end process;
  -- Falling edge for Drdy
  adcDrdyEn <= adcDrdyD2 and (not adcDrdyD1);
  -- Rising edge for adcStart, or the internal value for manual control
  adcStartEn <= ((not adcStartD2) and adcStartD1) or r.adcStartEnManual;

  -- Instance of the SPI Master controller
  U_spiMaster : entity surf.SpiMaster
    generic map (
      TPD_G             => TPD_G,
      NUM_CHIPS_G       => 1,
      DATA_SIZE_G       => 8,
      CPHA_G            => '1',
      CPOL_G            => '1',
      CLK_PERIOD_G      => SYS_CLK_PERIOD_G,
      SPI_SCLK_PERIOD_G => SPI_SCLK_PERIOD_G
    )
    port map (
      -- Global Signals
      clk       => sysClk,
      sRst      => sysRst,
      -- Parallel interface
      chipSel   => "0",
      wrEn      => spiWrEn,
      wrData    => spiWrData,
      rdEn      => spiRdEn,
      rdData    => spiRdData,
      -- SPI interface
      spiCsL(0) => cslMaster,
      spiSclk   => adcSclk,
      spiSdi    => adcDin,
      spiSdo    => adcDout
    );

  adcCsL <= cslMaster and cslCmd;

  -- keep CS low when within one command
  cslCmd <=
    '1'   when cmdCounter = 0 else    -- write reset command
    '1'   when cmdCounter = 1 else    -- write register command starting from reg 0
    '0'   when cmdCounter = 2 else    -- write register command write 10 registers
    '0'   when cmdCounter = 3 else    -- write registers 0 to 9
    '0'   when cmdCounter = 4 else
    '0'   when cmdCounter = 5 else
    '0'   when cmdCounter = 6 else
    '0'   when cmdCounter = 7 else
    '0'   when cmdCounter = 8 else
    '0'   when cmdCounter = 9 else
    '0'   when cmdCounter = 10 else
    '0'   when cmdCounter = 11 else
    '0'   when cmdCounter = 12 else
    '1'   when cmdCounter = 13 else
    '1'   when cmdCounter = 14 else
    '1'   when cmdCounter = 15 else
    '0';

  -- Select the command to be transmitted to the ADC
  spiWrData <=
    CMD_RESET_C               when cmdCounter = 0 else  -- write reset command
    CMD_WR_REG_C & "0000"     when cmdCounter = 1 else  -- write register command starting from reg 0
    "00001001"                when cmdCounter = 2 else  -- write register command write 10 registers
    ADC_SETUP_REGS_C(0)       when cmdCounter = 3 else  -- write SETUP register
    adcAinValues(chCounter) & AXI_ADS1217_AINCOM_C when cmdCounter = 4 else -- write MUX register with the active positive channel and the negative channel set to AINCOM
    ADC_SETUP_REGS_C(2)(7 downto 3) & r.adcPgaValues(chCounter) when cmdCounter = 5 else -- write ACR register with specific PGA value for each channel
    ADC_SETUP_REGS_C(3)       when cmdCounter = 6 else  -- write IDAC1 register
    ADC_SETUP_REGS_C(4)       when cmdCounter = 7 else  -- write IDAC2 register
    ADC_SETUP_REGS_C(5)       when cmdCounter = 8 else  -- write ODAC register
    adcDioValues(chCounter)   when cmdCounter = 9 else  -- write DIO register with the value for the active channel
    adcDirValues              when cmdCounter = 10 else -- write DIR register
    ADC_SETUP_REGS_C(8)       when cmdCounter = 11 else -- write DEC0 register
    ADC_SETUP_REGS_C(9)       when cmdCounter = 12 else -- write M/DEC1 register
    CMD_DSYNC_C               when cmdCounter = 13 else -- write dsync command
    "00000000"                when cmdCounter = 14 else -- write zeros to release reset (see ADC doc.)
    CMD_RDATA_C               when cmdCounter = 15 else -- write RDATA command
    "00000000";


  -- comand select counter
  cmd_cnt_p : process (sysClk)
  begin
    if rising_edge(sysClk) then
      if sysRst = '1' then
        cmdCounter <= 0 after TPD_G;
      elsif cmdLoad = '1'  then
        cmdCounter <= cmdData after TPD_G;
      elsif cmdEn = '1' then
        cmdCounter <= cmdCounter + 1 after TPD_G;
      end if;
    end if;
  end process;


  -- after command delay counter
  wait_cnt_p : process (sysClk)
  begin
    if rising_edge(sysClk) then
      if sysRst = '1' then
        waitCounter <= 0 after TPD_G;
      elsif waitLoad = '1' then
        waitCounter <= waitData after TPD_G;
      elsif waitDone = '0' and refClkEn = '1' then
        waitCounter <= waitCounter - 1 after TPD_G;
      end if;
    end if;
  end process;
  waitDone <= '1' when waitCounter = 0 else '0';
  waitData <=
    RESET_WAIT_C  when cmdCounter = 1 else     -- tosc delay after reset cmd
    WREG_WAIT_C   when cmdCounter = 13 else    -- tosc delay after wreg cmd
    WREG_WAIT_C   when cmdCounter = 14 else    -- tosc delay after dsync
    DOUT_WAIT_C   when cmdCounter = 16 else    -- tosc delay after rdata cmd
    0;

  -- read byte counter
  byte_cnt_p : process (sysClk)
  begin
    if rising_edge(sysClk) then
      if sysRst = '1' or byteRst = '1' then
        byteCounter <= 0 after TPD_G;
      elsif byteEn = '1' then
        byteCounter <= byteCounter + 1 after TPD_G;
      end if;
    end if;
  end process;

  -- acquisition channel counter
  ch_cnt_p : process (sysClk)
  begin
    if rising_edge(sysClk) then
      if sysRst = '1' then
        chCounter <= 0 after TPD_G;
      elsif channelEn = '1' then
        if chCounter < NUM_CHANNELS_G-1 then
          chCounter <= chCounter + 1 after TPD_G;
        else
          chCounter <= 0 after TPD_G;
        end if;
      end if;
    end if;
  end process;
  chSel <= toSlv(chCounter, 4);

  -- acquisition data storage
  data_reg_p : process (sysClk)
  begin
    if rising_edge(sysClk) then
      if sysRst = '1' then
        data_23_16 <= (others => '0') after TPD_G;
        data_15_08 <= (others => '0') after TPD_G;
      elsif byteCounter = 0 and spiRdEn = '1' and spiRdEnD1 = '0' then
        data_23_16 <= spiRdData after TPD_G;
      elsif byteCounter = 1 and spiRdEn = '1' and spiRdEnD1 = '0' then
        data_15_08 <= spiRdData after TPD_G;
      elsif byteCounter = 2 and spiRdEn = '1' and spiRdEnD1 = '0' then
        adcData(chCounter) <= data_23_16 & data_15_08 & spiRdData after TPD_G;
      end if;
    end if;
  end process;

  -- Readout loop FSM
  fsm_cnt_p : process (sysClk)
  begin
    if rising_edge(sysClk) then
      if sysRst = '1' then
        state <= RESET_S after TPD_G;
      else
        state <= nextState after TPD_G;
      end if;
    end if;
  end process;

  fsm_cmb_p : process (state, adcDrdyEn, spiRdEn, cmdCounter, byteCounter, adcStartEn, waitDone)
  begin
    nextState <= state;
    cmdEn <= '0';
    cmdLoad <= '0';
    cmdData <= 0;
    byteEn <= '0';
    byteRst <= '0';
    spiWrEn <= '0';
    channelEn <= '0';
    waitLoad <= '0';

    case state is
      -- command 0 (reset) only after power up
      when RESET_S =>
        cmdLoad <= '1';
        if adcStartEn = '1' then
          nextState <= CMD_SEND_S;
        end if;

      -- start from command 1
      when IDLE_S =>
        cmdData <= 1;
        cmdLoad <= '1';
        if adcStartEn = '1' then
          nextState <= CMD_SEND_S;
        end if;

      -- trigger the SPI master
      when CMD_SEND_S =>
        spiWrEn <= '1';
        cmdEn <= '1';
        nextState <= CMD_WAIT_S;

      -- wait for the SPI master to finish
      when CMD_WAIT_S =>
        waitLoad <= '1';
        if spiRdEn = '1' then
          nextState <= CMD_DLY_S;
        end if;

      -- wait required Tosc periods (see ADC doc.)
      when CMD_DLY_S =>
        if waitDone = '1' then
          if cmdCounter < 15 then      -- repeat send command up to DSYNC
            nextState <= CMD_SEND_S;
          elsif cmdCounter = 15 then   -- after DSYNC must wait for DRDY
            nextState <= WAIT_DRDY_S;
          else                          -- after RDATA go to data readout
            byteRst <= '1';
            nextState <= READ_DATA_S;
          end if;
        end if;

      -- wait for DRDY and go to send RDATA command
      when WAIT_DRDY_S =>
        if adcDrdyEn = '1' then
          nextState <= CMD_SEND_S;
        end if;

      -- trigger the SPI master for readout
      when READ_DATA_S =>
        spiWrEn <= '1';
        nextState <= STORE_DATA_S;

      -- wait for the readout to complete and repeat 3 times
      when STORE_DATA_S =>
        if spiRdEn = '1' then
          if byteCounter < 2 then
            nextState <= READ_DATA_S;
            byteEn <= '1';
          else
            nextState <= IDLE_S;
            channelEn <= '1';
            byteEn <= '1';
          end if;
        end if;

      when others =>
        nextState <= RESET_S;
    end case;
  end process;

end rtl;
