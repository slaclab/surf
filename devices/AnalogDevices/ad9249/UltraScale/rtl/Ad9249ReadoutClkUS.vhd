-------------------------------------------------------------------------------
-- File       : Ad9249ReadoutClkUS.vhd
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
-- ADC Readout Controller
-- Receives ADC Data from an AD9592 chip.
-- Designed specifically for Xilinx 7 series FPGAs
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

use ieee.std_logic_arith.all;
use ieee.numeric_std.all;

library UNISIM;
use UNISIM.vcomponents.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;
use work.Ad9249Pkg.all;

entity Ad9249ReadoutClkUS is
   generic (
      TPD_G             : time                 := 1 ns;
      NUM_CHANNELS_G    : natural range 1 to 8 := 8;
      IODELAY_GROUP_G   : string               := "DEFAULT_GROUP";
      IDELAYCTRL_FREQ_G : real                 := 350.0;
      DELAY_VALUE_G     : natural              := 1250;
      DEFAULT_DELAY_G   : slv(4 downto 0)      := (others => '0');
      ADC_INVERT_CH_G   : slv(7 downto 0)      := "00000000");
   port (
      -- Master system clock, 125Mhz
      axilClk             : in  sl;
      axilRst             : in  sl;
      -- Reset for adc deserializer
      adcClkRst           : in  sl;
      -- Signals to/from idelayCtrl
      idelayCtrlRdy       : in  sl;
      cmt_locked          : out sl;     -- MMCM/PLL locked if used  
      -- Serial Data from ADC
      dClkP               : in  sl;     -- Data clock
      dClkN               : in  sl;
      dClkPOut            : out sl;
      dClkNOut            : out sl;
      dClkDiv4Out         : out sl;
      dClkDiv7Out         : out sl;
      fClkP               : in  sl;     -- Frame clock
      fClkN               : in  sl;
      -- Signal to control data gearboxes
      loadDelay           : in  sl;
      delay               : in  slv(8 downto 0) := "000000000";
      masterDelayValueOut : out slv(8 downto 0);
      slaveDelayValueOut  : out slv(8 downto 0);
      bitSlip             : in  slv(3 downto 0) := "0000";
      gearboxOffset       : in  slv(2 downto 0) := "000";
      pixData             : out slv(13 downto 0)
      );
end Ad9249ReadoutClkUS;

-- Define architecture
architecture rtl of Ad9249ReadoutClkUS is
   -------------------------------------------------------------------------------------------------
   -- ADC Readout Clocked Registers
   -------------------------------------------------------------------------------------------------

   type StateType is (IDLE_S, WAIT_IDELAY_CTRL_RDY_S, LOAD_VALUE_S, WAIT_LOAD_S, LOAD_PULSE_S, WAIT_READ_S, READ_VALUE_S);

   type AdcClkRegType is record
      state            : StateType;
      waitStateCnt     : slv(3 downto 0);
      -- idelay signals 
      masterCntValueIn : slv(8 downto 0);
      slaveCntValueIn  : slv(8 downto 0);
      masterCntValue   : slv(8 downto 0);
      slaveCntValue    : slv(8 downto 0);
      masterCE         : sl;
      slaveCE          : sl;
      masterEn_Vtc     : sl;
      slaveEn_Vtc      : sl;
      masterLoad       : sl;
      slaveLoad        : sl;
   end record;

   constant ADC_CLK_REG_INIT_C : AdcClkRegType := (
      state            => IDLE_S,
      waitStateCnt     => (others => '0'),
      masterCntValueIn => (others => '0'),
      slaveCntValueIn  => (others => '0'),
      masterCntValue   => (others => '0'),
      slaveCntValue    => (others => '0'),
      masterCE         => '1',
      slaveCE          => '1',
      masterEn_Vtc     => '0',
      slaveEn_Vtc      => '0',
      masterLoad       => '0',
      slaveLoad        => '0'
      );

   type AdcClkDiv4RegType is record
      masterData      : slv(7 downto 0);
      masterData_1    : slv(7 downto 0);
      slaveData       : slv(7 downto 0);
      slaveData_1     : slv(7 downto 0);
      longDataCounter : slv(2 downto 0);
      longData        : slv(55 downto 0);
      longData_1      : slv(55 downto 0);
      longDataD       : slv(55 downto 0);
      DWByte          : sl;
      masterDataDW    : slv(15 downto 0);
      masterDataDW_1  : slv(15 downto 0);
      bitSlip         : slv(3 downto 0);
      masterDataDWBS  : slv(15 downto 0);
      longDataStable  : sl;
   end record;

   constant ADC_CLK_DV4_REG_INIT_C : AdcClkDiv4RegType := (
      masterData      => (others => '0'),
      masterData_1    => (others => '0'),
      slaveData       => (others => '0'),
      slaveData_1     => (others => '0'),
      longDataCounter => (others => '0'),
      longData        => (others => '0'),
      longData_1      => (others => '0'),
      longDataD       => (others => '0'),
      DWByte          => '0',
      masterDataDW    => (others => '0'),
      masterDataDW_1  => (others => '0'),
      bitSlip         => (others => '0'),
      masterDataDWBS  => (others => '0'),
      longDataStable  => '0'
      );

   type AdcClkDiv7RegType is record
      gearboxCounter     : slv(2 downto 0);
      gearboxSeq         : slv(2 downto 0);
      masterPixData      : slv(13 downto 0);
      slavePixData       : slv(13 downto 0);
      dataAligned        : sl;
      pixDataGearboxIn   : slv(15 downto 0);
      pixDataGearboxIn_1 : slv(15 downto 0);
   end record;

   constant ADC_CLK_DV7_REG_INIT_C : AdcClkDiv7RegType := (
      gearboxCounter     => (others => '0'),
      gearboxSeq         => (others => '0'),
      masterPixData      => (others => '0'),
      slavePixData       => (others => '0'),
      dataAligned        => '0',
      pixDataGearboxIn   => (others => '0'),
      pixDataGearboxIn_1 => (others => '0')
      );



   signal adcR   : AdcClkRegType := ADC_CLK_REG_INIT_C;
   signal adcRin : AdcClkRegType;

   signal adcDV4R   : AdcClkDiv4RegType := ADC_CLK_DV4_REG_INIT_C;
   signal adcDv4Rin : AdcClkDiv4RegType;

   signal adcDV7R   : AdcClkDiv7RegType := ADC_CLK_DV7_REG_INIT_C;
   signal adcDv7Rin : AdcClkDiv7RegType;


   -- Local signals
   signal fClkP_i        : sl;
   signal fClkN_i        : sl;
   signal fClkP_d        : sl;
   signal fClkN_d        : sl;
   signal dClk           : sl;
   signal dClkP_i        : sl;
   signal dClkN_i        : sl;
   signal dClkDiv7       : sl;
   signal dClkDiv4       : sl;
   -- idelay signals
   signal idelayRdy_n    : sl;
   signal masterCntValue : slv(8 downto 0);
   signal slaveCntValue  : slv(8 downto 0);
   -- iserdes signal
   signal masterData     : slv(7 downto 0);
   signal slaveData      : slv(7 downto 0);

begin

   cmt_locked  <= '1';
   idelayRdy_n <= not idelayCtrlRdy;
   dClkPOut    <= dClkP_i;
   dClkNOut    <= dClkN_i;
   dClk        <= dClkP_i;
   dClkDiv4Out <= dClkDiv4;
   dClkDiv7Out <= dClkDiv7;

   -------------------------------------------------------------------------------------------------
   -- Create Clocks
   -------------------------------------------------------------------------------------------------

   -- input fclk buffer
   -- the fclock in this module has the function of a reference data
   --
   U_IBUFDS_DIFF_OUT_fclk : IBUFDS_DIFF_OUT
      generic map (
         DQS_BIAS => "FALSE"            -- (FALSE, TRUE)
         )
      port map (
         O  => fClkP_i,                 -- 1-bit output: Buffer diff_p output
         OB => fClkN_i,                 -- 1-bit output: Buffer diff_n output
         I  => fClkP,  -- 1-bit input: Diff_p buffer input (connect directly to top-level port)
         IB => fClkN   -- 1-bit input: Diff_n buffer input (connect directly to top-level port)
         );

   U_IBUFDS_dclk : IBUFDS_DIFF_OUT
      generic map (
         DQS_BIAS => "FALSE"            -- (FALSE, TRUE)
         )
      port map (
         O  => dclkP_i,                 -- 1-bit output: Buffer output
         OB => dClkN_i,                 -- 1-bit output: Buffer diff_n output
         I  => dclkP,  -- 1-bit input: Diff_p buffer input (connect directly to top-level port)
         IB => dclkN   -- 1-bit input: Diff_n buffer input (connect directly to top-level port)
         );

   U_BUFGCE_DIV_dclk2 : BUFGCE_DIV
      generic map (
         BUFGCE_DIVIDE   => 7,          -- 1-8
         -- Programmable Inversion Attributes: Specifies built-in programmable inversion on specific pins
         IS_CE_INVERTED  => '0',        -- Optional inversadion for CE
         IS_CLR_INVERTED => '0',        -- Optional inversion for CLR
         IS_I_INVERTED   => '0'         -- Optional inversion for I
         )
      port map (
         O   => dClkDiv7,               -- 1-bit output: Buffer
         CE  => '1',                    -- 1-bit input: Buffer enable
         CLR => '0',                    -- 1-bit input: Asynchronous clear
         I   => dClk                    -- 1-bit input: Buffer
         );

   U_BUFGCE_DIV_dclk8 : BUFGCE_DIV
      generic map (
         BUFGCE_DIVIDE   => 4,          -- 1-8
         -- Programmable Inversion Attributes: Specifies built-in programmable inversion on specific pins
         IS_CE_INVERTED  => '0',        -- Optional inversion for CE
         IS_CLR_INVERTED => '0',        -- Optional inversion for CLR
         IS_I_INVERTED   => '0'         -- Optional inversion for I
         )
      port map (
         O   => dClkDiv4,               -- 1-bit output: Buffer
         CE  => '1',                    -- 1-bit input: Buffer enable
         CLR => '0',                    -- 1-bit input: Asynchronous clear
         I   => dClk                    -- 1-bit input: Buffer
         );

   ----------------------------------------------------------------------------
   -- idelay3 
   ----------------------------------------------------------------------------
   U_IDELAYE3_0 : IDELAYE3
      generic map (
         CASCADE          => "NONE",    -- Cascade setting (MASTER, NONE, SLAVE_END, SLAVE_MIDDLE)
         DELAY_FORMAT     => "TIME",    -- Units of the DELAY_VALUE (COUNT, TIME)
         DELAY_SRC        => "IDATAIN",   -- Delay input (DATAIN, IDATAIN)
         DELAY_TYPE       => "VAR_LOAD",  -- Set the type of tap delay line (FIXED, VARIABLE, VAR_LOAD)
         DELAY_VALUE      => DELAY_VALUE_G,      -- Input delay value setting
         IS_CLK_INVERTED  => '0',       -- Optional inversion for CLK
         IS_RST_INVERTED  => '0',       -- Optional inversion for RST
         REFCLK_FREQUENCY => IDELAYCTRL_FREQ_G,  -- IDELAYCTRL clock input frequency in MHz (200.0-2667.0)
         SIM_DEVICE       => "ULTRASCALE",  -- Set the device version (ULTRASCALE, ULTRASCALE_PLUS, ULTRASCALE_PLUS_ES1,
         -- ULTRASCALE_PLUS_ES2)
         UPDATE_MODE      => "ASYNC"  -- Determines when updates to the delay will take effect (ASYNC, MANUAL,
       -- SYNC)
         )
      port map (
         CASC_OUT    => open,         -- 1-bit output: Cascade delay output to ODELAY input cascade
         CNTVALUEOUT => masterCntValue,   -- 9-bit output: Counter value output
         DATAOUT     => fClkP_d,        -- 1-bit output: Delayed data output
         CASC_IN     => '1',  -- 1-bit input: Cascade delay input from slave ODELAY CASCADE_OUT
         CASC_RETURN => '1',  -- 1-bit input: Cascade delay returning from slave ODELAY DATAOUT
         CE          => adcR.masterCE,  -- 1-bit input: Active high enable increment/decrement input
         CLK         => dClk,           -- 1-bit input: Clock input
         CNTVALUEIN  => adcR.masterCntValueIn,   -- 9-bit input: Counter value input
         DATAIN      => '1',            -- 1-bit input: Data input from the logic
         EN_VTC      => adcR.masterEn_Vtc,  -- 1-bit input: Keep delay constant over VT
         IDATAIN     => fclkP_i,        -- 1-bit input: Data input from the IOBUF
         INC         => '0',            -- 1-bit input: Increment / Decrement tap delay input
         LOAD        => adcR.masterLoad,  -- 1-bit input: Load DELAY_VALUE input
         RST         => axilRst         -- 1-bit input: Asynchronous Reset to the DELAY_VALUE
         );

   U_IDELAYE3_1 : IDELAYE3
      generic map (
         CASCADE          => "NONE",
         DELAY_FORMAT     => "TIME",
         DELAY_SRC        => "IDATAIN",
         DELAY_TYPE       => "VAR_LOAD",
         DELAY_VALUE      => DELAY_VALUE_G,
         IS_CLK_INVERTED  => '0',
         IS_RST_INVERTED  => '0',
         REFCLK_FREQUENCY => IDELAYCTRL_FREQ_G,
         SIM_DEVICE       => "ULTRASCALE",
         UPDATE_MODE      => "ASYNC"
         )
      port map (
         CASC_OUT    => open,
         CNTVALUEOUT => slaveCntValue,
         DATAOUT     => fClkN_d,
         CASC_IN     => '1',
         CASC_RETURN => '1',
         CE          => adcR.slaveCE,
         CLK         => dClk,
         CNTVALUEIN  => adcR.slaveCntValueIn,
         DATAIN      => '1',
         EN_VTC      => adcR.slaveEn_Vtc,
         IDATAIN     => fclkN_i,
         INC         => '0',
         LOAD        => adcR.slaveLoad,
         RST         => axilRst
         );

   ----------------------------------------------------------------------------
   -- iserdes3
   ----------------------------------------------------------------------------
   U_ISERDESE3_master : ISERDESE3
      generic map (
         DATA_WIDTH        => 8,        -- Parallel data width (4,8)
         FIFO_ENABLE       => "FALSE",  -- Enables the use of the FIFO
         FIFO_SYNC_MODE    => "FALSE",  -- Enables the use of internal 2-stage synchronizers on the FIFO
         IS_CLK_B_INVERTED => '0',      -- Optional inversion for CLK_B
         IS_CLK_INVERTED   => '0',      -- Optional inversion for CLK
         IS_RST_INVERTED   => '0',      -- Optional inversion for RST
         SIM_DEVICE        => "ULTRASCALE"  -- Set the device version (ULTRASCALE, ULTRASCALE_PLUS, ULTRASCALE_PLUS_ES1,
       -- ULTRASCALE_PLUS_ES2)
         )
      port map (
         FIFO_EMPTY      => open,       -- 1-bit output: FIFO empty flag
         INTERNAL_DIVCLK => open,  -- 1-bit output: Internally divided down clock used when FIFO is
         -- disabled (do not connect)

         Q           => masterData,     -- bit registered output
         CLK         => dClkP_i,        -- 1-bit input: High-speed clock
         CLKDIV      => dClkDiv4,       -- 1-bit input: Divided Clock
         CLK_B       => dClkN_i,        -- 1-bit input: Inversion of High-speed clock CLK
         D           => fclkP_d,        -- 1-bit input: Serial Data Input
         FIFO_RD_CLK => '1',            -- 1-bit input: FIFO read clock
         FIFO_RD_EN  => '1',            -- 1-bit input: Enables reading the FIFO when asserted
         RST         => axilRst         -- 1-bit input: Asynchronous Reset
         );

   U_ISERDESE3_slave : ISERDESE3
      generic map (
         DATA_WIDTH        => 8,
         FIFO_ENABLE       => "FALSE",
         FIFO_SYNC_MODE    => "FALSE",
         IS_CLK_B_INVERTED => '0',
         IS_CLK_INVERTED   => '0',
         IS_RST_INVERTED   => '0',
         SIM_DEVICE        => "ULTRASCALE"
         )
      port map (
         FIFO_EMPTY      => open,
         INTERNAL_DIVCLK => open,
         Q               => slaveData,
         CLK             => dClkP_i,
         CLKDIV          => dClkDiv4,
         CLK_B           => dClkN_i,
         D               => fclkN_d,
         FIFO_RD_CLK     => '1',
         FIFO_RD_EN      => '1',
         RST             => axilRst
         );

   -----------------------------------------------------------------------------
   -- custom logic 
   -----------------------------------------------------------------------------
   adcComb : process (adcR, loadDelay, masterCntValue, slaveCntValue) is
      variable v : AdcClkRegType;
   begin
      v := adcR;

      case (adcR.state) is
         when WAIT_IDELAY_CTRL_RDY_S =>
            if idelayCtrlRdy = '1' then
               v.state := LOAD_VALUE_S;
            else
               v.state := IDLE_S;                  -- can't program the delay if control is
                                                   -- not ready yet.
            end if;
         when LOAD_VALUE_S =>
            v.slaveEn_Vtc  := '0';
            v.masterEn_Vtc := '0';                 -- needed to readback the tapdelay value
            v.slaveLoad    := '0';
            v.masterLoad   := '0';
            v.waitStateCnt := (others => '0');
            v.state        := WAIT_LOAD_S;
         when WAIT_LOAD_S =>
            v.waitStateCnt := adcR.waitStateCnt + '1';
            if adcR.waitStateCnt = X"1" then
               v.state := LOAD_PULSE_S;
            end if;
         when LOAD_PULSE_S =>
            v.slaveLoad    := '1';
            v.masterLoad   := '1';
            v.waitStateCnt := (others => '0');
            v.state        := WAIT_READ_S;
         when WAIT_READ_S =>
            v.slaveLoad    := '0';
            v.masterLoad   := '0';
            v.waitStateCnt := adcR.waitStateCnt + '1';
            if adcR.waitStateCnt = X"9" then
               v.state := READ_VALUE_S;
            end if;
         when READ_VALUE_S =>
            v.slaveCntValue  := slaveCntValue;
            v.masterCntValue := masterCntValue;
            v.state          := IDLE_S;
         when IDLE_S =>
            v.slaveLoad        := '0';
            v.masterLoad       := '0';
            v.slaveCE          := '0';
            v.masterCE         := '0';
            v.slaveEn_Vtc      := idelayRdy_n;     -- check if the value should be '1'
                                                   -- or idelayRdy_n
            v.masterEn_Vtc     := idelayRdy_n;
            v.slaveCntValueIn  := delay;           -- save new delay value
            v.masterCntValueIn := delay;           -- save new delay value
            if loadDelay = '1' then
               v.state := WAIT_IDELAY_CTRL_RDY_S;  --loopthrough load delay routine
            end if;
         when others =>
            v.state := IDLE_S;
      end case;

      adcRin <= v;

      --outputs
      masterDelayValueOut <= adcR.masterCntValue;
      slaveDelayValueOut  <= adcR.slaveCntValue;

   end process adcComb;


   adcSeq : process (dClkDiv4, axilRst) is
   begin
      if (axilRst = '1') then
         adcR <= ADC_CLK_REG_INIT_C after TPD_G;
      elsif (rising_edge(dClkDiv4)) then
         adcR <= adcRin after TPD_G;
      end if;
   end process adcSeq;


   -----------------------------------------------------------------------------
   -- 8 to 16, 56 gearbox and bitSlip control logic
   -- Part or all 56 bits can be used for idelay3 adjustment
   -----------------------------------------------------------------------------
   adc8to56GearboxComb : process (adcDv4R, masterData, slaveData, bitSlip) is
      variable v : AdcClkDiv4RegType;
   begin

      v := adcDv4R;

      -- update register with signal values
      v.masterData := masterData;
      v.slaveData  := slaveData;
      v.bitSlip    := bitSlip;

      -- creates pipeline
      v.masterData_1 := adcDv4R.masterData;
      v.slaveData_1  := adcDv4R.slaveData;
      v.longData_1   := adcDv4R.longData;

      -- data checks on this logic.
      -- 56 bit assembly logic
      case (adcDv4R.longDataCounter) is
         when "000" =>
            v.longData(7 downto 0) := adcDv4R.masterData_1;
            v.longDataCounter      := adcDv4R.longDataCounter + 1;
         when "001" =>
            v.longData(15 downto 8) := adcDv4R.masterData_1;
            v.longDataCounter       := adcDv4R.longDataCounter + 1;
         when "010" =>
            v.longData(23 downto 16) := adcDv4R.masterData_1;
            v.longDataCounter        := adcDv4R.longDataCounter + 1;
         when "011" =>
            v.longData(31 downto 24) := adcDv4R.masterData_1;
            v.longDataCounter        := adcDv4R.longDataCounter + 1;
         when "100" =>
            v.longData(39 downto 32) := adcDv4R.masterData_1;
            v.longDataCounter        := adcDv4R.longDataCounter + 1;
         when "101" =>
            v.longData(47 downto 40) := adcDv4R.masterData_1;
            v.longDataCounter        := adcDv4R.longDataCounter + 1;
         when "110" =>
            v.longData(55 downto 48) := adcDv4R.masterData_1;
            v.longDataCounter        := (others => '0');
         when others =>
            v.longData        := (others => '0');
            v.longDataCounter := (others => '0');
      end case;

      if adcDv4R.longDataCounter = "000" then
         if adcDv4r.longData = adcDv4r.longData_1 then
            v.longDataStable := '1';
         else
            v.longDataStable := '0';
         end if;
      end if;

      --16 bit data assembly logic
      if adcDv4R.DWByte = '1' then
         v.masterDataDW(7 downto 0)  := adcDv4R.masterData_1;
         v.masterDataDW(15 downto 8) := adcDv4R.masterData;
         v.masterDataDW_1            := adcDv4R.masterDataDW;
      end if;

      v.DWByte := not adcDv4R.DWByte;

      --bit slip logic
      case (adcDv4R.bitSlip) is
         when "0000" =>
            v.masterDataDWBS := adcDv4R.masterDataDW(15 downto 0);
         when "0001" =>
            v.masterDataDWBS := adcDv4R.masterDataDW(14 downto 0) & adcDv4R.masterDataDW_1(15);
         when "0010" =>
            v.masterDataDWBS := adcDv4R.masterDataDW(13 downto 0) & adcDv4R.masterDataDW_1(15 downto 14);
         when "0011" =>
            v.masterDataDWBS := adcDv4R.masterDataDW(12 downto 0) & adcDv4R.masterDataDW_1(15 downto 13);
         when "0100" =>
            v.masterDataDWBS := adcDv4R.masterDataDW(11 downto 0) & adcDv4R.masterDataDW_1(15 downto 12);
         when "0101" =>
            v.masterDataDWBS := adcDv4R.masterDataDW(10 downto 0) & adcDv4R.masterDataDW_1(15 downto 11);
         when "0110" =>
            v.masterDataDWBS := adcDv4R.masterDataDW(9 downto 0) & adcDv4R.masterDataDW_1(15 downto 10);
         when "0111" =>
            v.masterDataDWBS := adcDv4R.masterDataDW(8 downto 0) & adcDv4R.masterDataDW_1(15 downto 9);
         when "1000" =>
            v.masterDataDWBS := adcDv4R.masterDataDW(7 downto 0) & adcDv4R.masterDataDW_1(15 downto 8);
         when "1001" =>
            v.masterDataDWBS := adcDv4R.masterDataDW(6 downto 0) & adcDv4R.masterDataDW_1(15 downto 7);
         when "1010" =>
            v.masterDataDWBS := adcDv4R.masterDataDW(5 downto 0) & adcDv4R.masterDataDW_1(15 downto 6);
         when "1011" =>
            v.masterDataDWBS := adcDv4R.masterDataDW(4 downto 0) & adcDv4R.masterDataDW_1(15 downto 5);
         when "1100" =>
            v.masterDataDWBS := adcDv4R.masterDataDW(3 downto 0) & adcDv4R.masterDataDW_1(15 downto 4);
         when "1101" =>
            v.masterDataDWBS := adcDv4R.masterDataDW(2 downto 0) & adcDv4R.masterDataDW_1(15 downto 3);
         when "1110" =>
            v.masterDataDWBS := adcDv4R.masterDataDW(1 downto 0) & adcDv4R.masterDataDW_1(15 downto 2);
         when "1111" =>
            v.masterDataDWBS := adcDv4R.masterDataDW(0) & adcDv4R.masterDataDW_1(15 downto 1);
         when others =>
            v.masterDataDWBS := (others => '0');
      end case;

      adcDv4Rin <= v;

      --outputs

   end process;

   adclongSeq : process (axilRst, dClkDiv4, adcDv4Rin) is
   begin
      if (axilRst = '1') then
         adcDv4R <= ADC_CLK_DV4_REG_INIT_C;
      elsif (rising_edge(dClkDiv4)) then
         -- latch deserializer data
         adcDv4R <= adcDv4Rin after TPD_G;
      end if;
   end process;


   adc8To7GearboxComb : process (adcDv4R, adcDv7R, gearboxOffset) is
      variable v : AdcClkDiv7RegType;
   begin

      v := adcDv7R;

      v.gearboxSeq       := adcDv7R.gearboxCounter + gearboxOffset;
      v.pixDataGearboxIn := adcDv4R.masterDataDWBS;

      -- creates pipeline
      v.pixDataGearboxIn_1 := adcDv7R.pixDataGearboxIn;

      -- flag that indicates data, or frame signal matches the expected pattern
      if adcDv7R.masterPixData = "11111110000000" then
         v.dataAligned := '1';
      else
         v.dataAligned := '0';
      end if;

      case (adcDv7R.gearboxSeq) is
         when "000" =>
            v.masterPixData  := adcDv7R.pixDataGearboxIn(15 downto 2);
            v.gearboxCounter := adcDv7R.gearboxCounter + 1;
         when "001" =>
            v.masterPixData  := adcDv7R.pixDataGearboxIn(13 downto 0);
            v.gearboxCounter := adcDv7R.gearboxCounter + 1;
         when "010" =>
            v.masterPixData  := adcDv7R.pixDataGearboxIn(11 downto 0) & adcDv7R.pixDataGearboxIn_1(15 downto 14);
            v.gearboxCounter := adcDv7R.gearboxCounter + 1;
         when "011" =>
            v.masterPixData  := adcDv7R.pixDataGearboxIn(9 downto 0) & adcDv7R.pixDataGearboxIn_1(15 downto 12);
            v.gearboxCounter := adcDv7R.gearboxCounter + 1;
         when "100" =>
            v.masterPixData  := adcDv7R.pixDataGearboxIn(7 downto 0) & adcDv7R.pixDataGearboxIn_1(15 downto 10);
            v.gearboxCounter := adcDv7R.gearboxCounter + 1;
         when "101" =>
            v.masterPixData  := adcDv7R.pixDataGearboxIn(5 downto 0) & adcDv7R.pixDataGearboxIn_1(15 downto 8);
            v.gearboxCounter := adcDv7R.gearboxCounter + 1;
         when "110" =>
            v.masterPixData  := adcDv7R.pixDataGearboxIn(3 downto 0) & adcDv7R.pixDataGearboxIn_1(15 downto 6);
            v.gearboxCounter := adcDv7R.gearboxCounter + 1;
         when "111" =>
            v.masterPixData  := adcDv7R.pixDataGearboxIn(1 downto 0) & adcDv7R.pixDataGearboxIn_1(15 downto 4);
            v.gearboxCounter := adcDv7R.gearboxCounter + 1;
         when others =>
            v.masterPixData  := (others => '0');
            v.gearboxCounter := (others => '0');
      end case;

      adcDv7Rin <= v;

      --outputs
      PixData <= adcDv7R.masterPixData;

   end process;


   adc8To7GearboxSeq : process (axilRst, dClkDiv7, adcDv7Rin) is
   begin
      if (axilRst = '1') then
         adcDv7R <= ADC_CLK_DV7_REG_INIT_C;
      elsif (rising_edge(dClkDiv7)) then
         -- latch deserializer data
         adcDv7R <= adcDv7Rin after TPD_G;
      end if;
   end process;


end rtl;

