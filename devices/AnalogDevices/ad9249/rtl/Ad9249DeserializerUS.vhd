-------------------------------------------------------------------------------
-- File       : Ad9249ReadoutClkUS.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-05-26
-- Last update: 2018-03-20
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

entity Ad9249DeserializerUS is
   generic (
      TPD_G             : time                 := 1 ns;
      NUM_CHANNELS_G    : natural range 1 to 8 := 8;
      IODELAY_GROUP_G   : string               := "DEFAULT_GROUP";
      IDELAYCTRL_FREQ_G : real                 := 350.0;
      DEFAULT_DELAY_G   : slv(8 downto 0)      := (others => '0');
      FRAME_PATTERN_G   : slv(13 downto 0)     := "11111110000000";
      ADC_INVERT_CH_G   : sl                   := '0';
      BIT_REV_G         : sl                   := '0');
   port (
      -- Reset for adc deserializer
      adcClkRst : in sl;
      -- Signals to/from idelayCtrl
      idelayCtrlRdy : in  sl;
      -- Serial Data from ADC
      dClk     : in sl;                       -- Data clock
      dClkDiv4 : in sl;
      dClkDiv7 : in sl;
      sDataP   : in sl;                       -- Frame clock
      sDataN   : in sl;     
      -- Signal to control data gearboxes
      loadDelay       : in sl;
      delay           : in slv(8 downto 0) := "000000000";
      delayValueOut   : out slv(8 downto 0);
      bitSlip         : in slv(3 downto 0) := "0000";
      gearboxOffset   : in slv(2 downto 0) := "000";
      pixData         : out slv(13 downto 0)     
      );
end Ad9249DeserializerUS;

-- Define architecture
architecture rtl of Ad9249DeserializerUS is

  attribute keep : string;
  -------------------------------------------------------------------------------------------------
  -- ADC Readout Clocked Registers
  -------------------------------------------------------------------------------------------------

  type StateType is (IDLE_S, WAIT_IDELAY_CTRL_RDY_S, LOAD_VALUE_S, WAIT_LOAD_S, LOAD_PULSE_S ,WAIT_READ_S, READ_VALUE_S);
  
  type AdcClkRegType is record
    state             : StateType;
    waitStateCnt      : slv(3 downto 0);
    -- idelay signals 
    masterCntValueIn  : slv(8 downto 0);
    masterCntValue    : slv(8 downto 0);
    masterCE     : sl;
    masterEn_Vtc : sl;
    masterLoad   : sl;
  end record;

  constant ADC_CLK_REG_INIT_C : AdcClkRegType := (
    state            => IDLE_S,
    waitStateCnt     => (others => '0'),
    masterCntValueIn => (others => '0'),
    masterCntValue   => (others => '0'),
    masterCE     => '1',
    masterEn_Vtc => '0',
    masterLoad   => '0'
    );

  type AdcClkDiv4RegType is record
    masterData         : slv(7 downto 0);
    masterData_1       : slv(7 downto 0);
    longDataCounter    : slv(2 downto 0);
    longData           : slv(55 downto 0);
    longData_1         : slv(55 downto 0);
    DWByte             : sl;
    masterDataDW       : slv(15 downto 0);
    masterDataDW_1     : slv(15 downto 0);
    bitSlip            : slv(3 downto 0);
    masterDataDWBS     : slv(15 downto 0);
    longDataStable     : sl;
  end record;

  constant ADC_CLK_DV4_REG_INIT_C : AdcClkDiv4RegType := (
    masterData         => (others => '0'),
    masterData_1       => (others => '0'),
    longDataCounter    => (others => '0'),
    longData           => (others => '0'),
    longData_1         => (others => '0'),
    DWByte             => '0',
    masterDataDW       => (others => '0'),
    masterDataDW_1     => (others => '0'),
    bitSlip            => (others => '0'),
    masterDataDWBS     => (others => '0'),
    longDataStable     => '0'
    );

  type AdcClkDiv7RegType is record
    gearboxCounter      : slv(2 downto 0);
    gearboxSeq          : slv(2 downto 0);
    masterPixData       : slv(13 downto 0);
    dataAligned         : sl;
    pixDataGearboxIn    : slv(15 downto 0);
    pixDataGearboxIn_1  : slv(15 downto 0);
  end record;

  constant ADC_CLK_DV7_REG_INIT_C : AdcClkDiv7RegType := (
    gearboxCounter      => (others => '0'),
    gearboxSeq          => (others => '0'),
    masterPixData       => (others => '0'),
    dataAligned         => '0',
    pixDataGearboxIn    => (others => '0'),
    pixDataGearboxIn_1  => (others => '0')
    );

  
  
  signal adcR   : AdcClkRegType := ADC_CLK_REG_INIT_C;
  signal adcRin : AdcClkRegType;

  signal adcDV4R   : AdcClkDiv4RegType := ADC_CLK_DV4_REG_INIT_C;
  signal adcDv4Rin : AdcClkDiv4RegType;

  signal adcDV7R   : AdcClkDiv7RegType := ADC_CLK_DV7_REG_INIT_C;
  signal adcDv7Rin : AdcClkDiv7RegType;
  

   -- Local signals
  signal sDataPadP  : sl;
  signal sDataPadN  : sl;
  signal sData_i    : sl;
  signal sData_d    : sl;
  signal loadDelaySync : sl;

  -- idelay signals
  signal idelayRdy_n : sl;
  signal masterCntValue : slv(8 downto 0);
  -- iserdes signal
  signal masterData      : slv(7 downto 0);

  attribute keep of adcDV4R          : signal is "true";
  attribute keep of adcDV7R          : signal is "true";
  attribute keep of loadDelaySync    : signal is "true";
  attribute keep of sData_i          : signal is "true";

begin

  idelayRdy_n <= not idelayCtrlRdy;
  PixData <= adcDv7R.masterPixData(7)&adcDv7R.masterPixData(8)&adcDv7R.masterPixData(9)&adcDv7R.masterPixData(10)&adcDv7R.masterPixData(11)&adcDv7R.masterPixData(12)&adcDv7R.masterPixData(13)&adcDv7R.masterPixData(0)&adcDv7R.masterPixData(1)&adcDv7R.masterPixData(2)&adcDv7R.masterPixData(3)&adcDv7R.masterPixData(4)&adcDv7R.masterPixData(5)&adcDv7R.masterPixData(6)                       when BIT_REV_G = '1'
             else adcDv7R.masterPixData;

  -------------------------------------------------------------------------------------------------
  -- Create Clocks
  -------------------------------------------------------------------------------------------------
  
  -- input sData buffer
  --
  U_IBUFDS_sData : IBUFDS_DIFF_OUT
    generic map (
      DQS_BIAS => "FALSE"  -- (FALSE, TRUE)
      )
    port map (
      O  => sDataPadP,   -- 1-bit output: Buffer output
      OB => sDataPadN,
      I  => sDataP,   -- 1-bit input: Diff_p buffer input (connect directly to top-level port)
      IB => sDataN  -- 1-bit input: Diff_n buffer input (connect directly to top-level port)
      );
  -- Optionally invert the pad input
  sData_i <= sDataPadP when ADC_INVERT_CH_G = '0' else sDataPadN;
  ----------------------------------------------------------------------------
  -- idelay3 
  ----------------------------------------------------------------------------
  U_IDELAYE3_0 : IDELAYE3
    generic map (
      CASCADE => "NONE",          -- Cascade setting (MASTER, NONE, SLAVE_END, SLAVE_MIDDLE)
      DELAY_FORMAT => "COUNT",     -- Units of the DELAY_VALUE (COUNT, TIME)
      DELAY_SRC => "IDATAIN",     -- Delay input (DATAIN, IDATAIN)
      DELAY_TYPE => "VAR_LOAD",   -- Set the type of tap delay line (FIXED, VARIABLE, VAR_LOAD)
      DELAY_VALUE => conv_integer(DEFAULT_DELAY_G), -- Input delay value setting
      IS_CLK_INVERTED => '0',     -- Optional inversion for CLK
      IS_RST_INVERTED => '0',     -- Optional inversion for RST
      REFCLK_FREQUENCY => IDELAYCTRL_FREQ_G,  -- IDELAYCTRL clock input frequency in MHz (200.0-2667.0)
      SIM_DEVICE => "ULTRASCALE", -- Set the device version (ULTRASCALE, ULTRASCALE_PLUS, ULTRASCALE_PLUS_ES1,
                                  -- ULTRASCALE_PLUS_ES2)
      UPDATE_MODE => "ASYNC"      -- Determines when updates to the delay will take effect (ASYNC, MANUAL,
                                  -- SYNC)
      )
    port map (
      CASC_OUT => OPEN,       -- 1-bit output: Cascade delay output to ODELAY input cascade
      CNTVALUEOUT => masterCntValue, -- 9-bit output: Counter value output
      DATAOUT => sData_d,         -- 1-bit output: Delayed data output
      CASC_IN => '1',         -- 1-bit input: Cascade delay input from slave ODELAY CASCADE_OUT
      CASC_RETURN => '1', -- 1-bit input: Cascade delay returning from slave ODELAY DATAOUT
      CE => adcR.masterCE,                   -- 1-bit input: Active high enable increment/decrement input
      CLK => dClkDiv4,                 -- 1-bit input: Clock input
      CNTVALUEIN => adcR.masterCntValueIn,   -- 9-bit input: Counter value input
      DATAIN => '1',           -- 1-bit input: Data input from the logic
      EN_VTC => adcR.masterEn_Vtc,           -- 1-bit input: Keep delay constant over VT
      IDATAIN => sData_i,         -- 1-bit input: Data input from the IOBUF
      INC => '0',                 -- 1-bit input: Increment / Decrement tap delay input
      LOAD => adcR.masterLoad,               -- 1-bit input: Load DELAY_VALUE input
      RST => adcClkRst                  -- 1-bit input: Asynchronous Reset to the DELAY_VALUE
      );    
   
  ----------------------------------------------------------------------------
  -- iserdes3
  ----------------------------------------------------------------------------
  U_ISERDESE3_master : ISERDESE3
    generic map (
      DATA_WIDTH => 8,            -- Parallel data width (4,8)
      FIFO_ENABLE => "FALSE",     -- Enables the use of the FIFO
      FIFO_SYNC_MODE => "FALSE",  -- Enables the use of internal 2-stage synchronizers on the FIFO
      IS_CLK_B_INVERTED => '1',   -- Optional inversion for CLK_B
      IS_CLK_INVERTED => '0',     -- Optional inversion for CLK
      IS_RST_INVERTED => '0',     -- Optional inversion for RST
      SIM_DEVICE => "ULTRASCALE"  -- Set the device version (ULTRASCALE, ULTRASCALE_PLUS, ULTRASCALE_PLUS_ES1,
                                  -- ULTRASCALE_PLUS_ES2)
      )
    port map (
      FIFO_EMPTY => OPEN,         -- 1-bit output: FIFO empty flag
      INTERNAL_DIVCLK => open,    -- 1-bit output: Internally divided down clock used when FIFO is
                                  -- disabled (do not connect)

      Q => masterData,            -- bit registered output
      CLK => dClk,            -- 1-bit input: High-speed clock
      CLKDIV => dClkDiv4,         -- 1-bit input: Divided Clock
      CLK_B => dClk,        -- 1-bit input: Inversion of High-speed clock CLK
      D => sData_d,               -- 1-bit input: Serial Data Input
      FIFO_RD_CLK => '1',         -- 1-bit input: FIFO read clock
      FIFO_RD_EN => '1',          -- 1-bit input: Enables reading the FIFO when asserted
      RST => adcClkRst              -- 1-bit input: Asynchronous Reset
      );


  -----------------------------------------------------------------------------
  -- crossing clock domain
  -----------------------------------------------------------------------------
  U_sync_0: entity work.SynchronizerOneShot 
   generic map(
      TPD_G           => 1 ns,   -- Simulation FF output delay
      RST_POLARITY_G  => '1',    -- '1' for active HIGH reset, '0' for active LOW reset
      RST_ASYNC_G     => false,  -- Reset is asynchronous
      BYPASS_SYNC_G   => false,  -- Bypass RstSync module for synchronous data configuration
      RELEASE_DELAY_G => 3,      -- Delay between deassertion of async and sync resets
      IN_POLARITY_G   => '1',    -- 0 for active LOW, 1 for active HIGH
      OUT_POLARITY_G  => '1',    -- 0 for active LOW, 1 for active HIGH
      PULSE_WIDTH_G   => 1)      -- one-shot pulse width duration (units of clk cycles)
   port map(
      clk     => dClkDiv4,
      rst     => adcClkRst,
      dataIn  => loadDelay,
      dataOut => loadDelaySync); -- synced one-shot pulse
  
  -----------------------------------------------------------------------------
  -- custom logic 
  -----------------------------------------------------------------------------
  adcComb : process (adcR, loadDelaySync, masterCntValue, idelayCtrlRdy, idelayRdy_n, delay) is
    variable v : AdcClkRegType;
  begin
    v := adcR;

    case (adcR.state) is
      when WAIT_IDELAY_CTRL_RDY_S =>
        if idelayCtrlRdy = '1' then
          v.state := LOAD_VALUE_S;
        else
          v.state := IDLE_S;            -- can't program the delay if control is
                                        -- not ready yet.
        end if;
      when LOAD_VALUE_S =>
        v.masterEn_Vtc := '0'; -- needed to readback the tapdelay value
        v.masterLoad := '0';
        v.waitStateCnt := (others => '0');
        v.state := WAIT_LOAD_S;
      when WAIT_LOAD_S =>
        v.waitStateCnt := adcR.waitStateCnt + '1';
        if adcR.waitStateCnt = X"1" then
          v.state := LOAD_PULSE_S;
        end if;
      when LOAD_PULSE_S =>
        v.masterLoad := '1';
        v.waitStateCnt := (others => '0');
        v.state := WAIT_READ_S;
      when WAIT_READ_S =>
        v.masterLoad := '0';
        v.waitStateCnt := adcR.waitStateCnt + '1';
        if adcR.waitStateCnt = X"9" then
          v.state := READ_VALUE_S;
        end if;
      when READ_VALUE_S =>
        v.masterCntValue := masterCntValue;
        v.state          := IDLE_S;
      when IDLE_S =>
        v.masterLoad       := '0';
        v.masterCE         := '0';
        v.masterEn_Vtc     := idelayRdy_n; 
        v.masterCntValueIn := delay;  -- save new delay value
        if loadDelaySync = '1' then       
          v.state := WAIT_IDELAY_CTRL_RDY_S; --loopthrough load delay routine
        end if;
      when others =>
        v.state := IDLE_S;
    end case;
    
    adcRin <= v;
         
    --outputs
    delayValueOut <= adcR.masterCntValue;
   
  end process adcComb;


   adcSeq : process (dClkDiv4, adcClkRst) is
   begin
      if (adcClkRst = '1') then
         adcR <= ADC_CLK_REG_INIT_C after TPD_G;
      elsif (rising_edge(dClkDiv4)) then
         adcR <= adcRin after TPD_G;
      end if;
   end process adcSeq;
   

  -----------------------------------------------------------------------------
  -- 8 to 16, 56 gearbox and bitSlip control logic
  -- Part or all 56 bits can be used for idelay3 adjustment
  -----------------------------------------------------------------------------
  adc8to56GearboxComb : process (adcDv4R, masterData, bitSlip) is
    variable v : AdcClkDiv4RegType;
  begin

     v := adcDv4R;

     -- update register with signal values
     v.masterData   := masterData;
     v.bitSlip      := bitSlip;

     -- creates pipeline
     v.masterData_1 := adcDv4R.masterData;
     v.longData_1   := adcDv4R.longData;
     
     -- data checks on this logic.
     -- 56 bit assembly logic
     case (adcDv4R.longDataCounter) is
       when "000" =>
         v.longData(7 downto 0) := adcDv4R.masterData_1;
         v.longDataCounter := adcDv4R.longDataCounter + 1;
       when "001" =>
         v.longData(15 downto 8) := adcDv4R.masterData_1;
         v.longDataCounter := adcDv4R.longDataCounter + 1;
       when "010" =>
         v.longData(23 downto 16) := adcDv4R.masterData_1;
         v.longDataCounter := adcDv4R.longDataCounter + 1;
       when "011" =>
         v.longData(31 downto 24) := adcDv4R.masterData_1;
         v.longDataCounter := adcDv4R.longDataCounter + 1;            
       when "100" =>
         v.longData(39 downto 32) := adcDv4R.masterData_1;
         v.longDataCounter := adcDv4R.longDataCounter + 1;
       when "101" =>
         v.longData(47 downto 40) := adcDv4R.masterData_1;
         v.longDataCounter := adcDv4R.longDataCounter + 1;
       when "110" =>
         v.longData(55 downto 48) := adcDv4R.masterData_1;
         v.longDataCounter := (others => '0');
       when others =>
         v.longData  := (others => '0');
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
       v.masterDataDW_1 := adcDv4R.masterDataDW; 
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
         v.masterDataDWBS := adcDv4R.masterDataDW( 9 downto 0) & adcDv4R.masterDataDW_1(15 downto 10);
       when "0111" =>
         v.masterDataDWBS := adcDv4R.masterDataDW( 8 downto 0) & adcDv4R.masterDataDW_1(15 downto  9);
       when "1000" =>
         v.masterDataDWBS := adcDv4R.masterDataDW( 7 downto 0) & adcDv4R.masterDataDW_1(15 downto  8);
       when "1001" =>
         v.masterDataDWBS := adcDv4R.masterDataDW( 6 downto 0) & adcDv4R.masterDataDW_1(15 downto  7);
       when "1010" =>
         v.masterDataDWBS := adcDv4R.masterDataDW( 5 downto 0) & adcDv4R.masterDataDW_1(15 downto  6);
       when "1011" =>
         v.masterDataDWBS := adcDv4R.masterDataDW( 4 downto 0) & adcDv4R.masterDataDW_1(15 downto  5);
       when "1100" =>
         v.masterDataDWBS := adcDv4R.masterDataDW( 3 downto 0) & adcDv4R.masterDataDW_1(15 downto  4);
       when "1101" =>
         v.masterDataDWBS := adcDv4R.masterDataDW( 2 downto 0) & adcDv4R.masterDataDW_1(15 downto  3);
       when "1110" =>
         v.masterDataDWBS := adcDv4R.masterDataDW( 1 downto 0) & adcDv4R.masterDataDW_1(15 downto  2);
       when "1111" =>
         v.masterDataDWBS := adcDv4R.masterDataDW(          0) & adcDv4R.masterDataDW_1(15 downto  1);
       when others =>
         v.masterDataDWBS := (others => '0');
     end case;

     adcDv4Rin <= v;
         
     --outputs
     
   end process;

  adclongSeq : process (adcClkRst, dClkDiv4, adcDv4Rin) is 
  begin
    if (adcClkRst = '1') then           
      adcDv4R <= ADC_CLK_DV4_REG_INIT_C;
    elsif (rising_edge(dClkDiv4)) then
      -- latch deserializer data
      adcDv4R <= adcDv4Rin  after TPD_G;
    end if;      
  end process;
   
          
  adc8To7GearboxComb : process (adcDv4R, adcDv7R, gearboxOffset) is
    variable v : AdcClkDiv7RegType;
  begin

    v := adcDv7R;
      
    v.gearboxSeq        := adcDv7R.gearboxCounter + gearboxOffset;
    v.pixDataGearboxIn  := adcDv4R.masterDataDWBS;

    -- creates pipeline
    v.pixDataGearboxIn_1 := adcDv7R.pixDataGearboxIn;

    -- flag that indicates data, or frame signal matches the expected pattern
    if adcDv7R.masterPixData = FRAME_PATTERN_G then
      v.dataAligned := '1';
    else
      v.dataAligned := '0';
    end if;

    case (adcDv7R.gearboxSeq) is
      when "000" =>
        v.masterPixData   := adcDv7R.pixDataGearboxIn(15 downto 2);
        v.gearboxCounter  := adcDv7R.gearboxCounter + 1;
      when "001" =>
        v.masterPixData   := adcDv7R.pixDataGearboxIn(13 downto 0);
        v.gearboxCounter  := adcDv7R.gearboxCounter + 1;
      when "010" =>
        v.masterPixData   := adcDv7R.pixDataGearboxIn(11 downto 0) & adcDv7R.pixDataGearboxIn_1(15 downto 14);
        v.gearboxCounter  := adcDv7R.gearboxCounter + 1;
      when "011" =>
        v.masterPixData   := adcDv7R.pixDataGearboxIn( 9 downto 0) & adcDv7R.pixDataGearboxIn_1(15 downto 12);
        v.gearboxCounter  := adcDv7R.gearboxCounter + 1;
      when "100" =>
        v.masterPixData   := adcDv7R.pixDataGearboxIn( 7 downto 0) & adcDv7R.pixDataGearboxIn_1(15 downto  10);
        v.gearboxCounter  := adcDv7R.gearboxCounter + 1;
      when "101" =>
        v.masterPixData   := adcDv7R.pixDataGearboxIn( 5 downto 0) & adcDv7R.pixDataGearboxIn_1(15 downto  8);
        v.gearboxCounter  := adcDv7R.gearboxCounter + 1;
      when "110" =>
        v.masterPixData   := adcDv7R.pixDataGearboxIn( 3 downto 0) & adcDv7R.pixDataGearboxIn_1(15 downto  6);
        v.gearboxCounter  := adcDv7R.gearboxCounter + 1;
      when "111" =>
        v.masterPixData   := adcDv7R.pixDataGearboxIn( 1 downto 0) & adcDv7R.pixDataGearboxIn_1(15 downto  4);
        v.gearboxCounter  := adcDv7R.gearboxCounter + 1;
      when others =>
        v.masterPixData   := (others => '0');
        v.gearboxCounter  := (others => '0');
    end case;

    adcDv7Rin <= v;
         
     --outputs
    
  end process;
   
   
  adc8To7GearboxSeq : process (adcClkRst, dClkDiv7, adcDv7Rin) is 
  begin
    if (adcClkRst = '1') then
      adcDv7R <= ADC_CLK_DV7_REG_INIT_C;
    elsif (rising_edge(dClkDiv7)) then
      -- latch deserializer data
      adcDv7R <= adcDv7Rin after TPD_G;
    end if;  
  end process;
end rtl;

