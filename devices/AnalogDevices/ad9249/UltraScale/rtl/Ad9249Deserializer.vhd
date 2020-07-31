-------------------------------------------------------------------------------
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

library UNISIM;
use UNISIM.vcomponents.all;


library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;
use surf.AxiStreamPkg.all;
use surf.Ad9249Pkg.all;

entity Ad9249Deserializer is
   generic (
      TPD_G             : time                 := 1 ns;
      IODELAY_GROUP_G   : string               := "DEFAULT_GROUP";
      IDELAY_CASCADE_G  : boolean              := false;
      IDELAYCTRL_FREQ_G : real                 := 300.0;
      DEFAULT_DELAY_G   : slv(8 downto 0)      := (others => '0');
      ADC_INVERT_CH_G   : sl                   := '0';
      BIT_REV_G         : sl                   := '0');
   port (
      -- Serial Data from ADC
      dClk          : in  sl;           -- Data clock
      dRst          : in  sl;           -- Data reset
      dClkDiv4      : in  sl;
      dRstDiv4      : in  sl;
      dClkDiv7      : in  sl;
      dRstDiv7      : in  sl;
      sDataP        : in  sl;           -- Frame clock
      sDataN        : in  sl;
      -- Signal to control data gearboxes
      loadDelay     : in  sl;
      delay         : in  slv(8 downto 0) := "000000000";
      delayValueOut : out slv(8 downto 0);
      bitSlip       : in  slv(3 downto 0) := "0000";        -- dClkDiv4 domain
      gearboxOffset : in  slv(2 downto 0) := "000";         -- dClkDiv7 domain
      adcData       : out slv(13 downto 0)                  -- dClkDiv7 domain
      );
end Ad9249Deserializer;

-- Define architecture
architecture rtl of Ad9249Deserializer is

   attribute keep : string;
   -------------------------------------------------------------------------------------------------
   -- ADC Readout Clocked Registers
   -------------------------------------------------------------------------------------------------
   
   constant CASCADE_C : string := ite(IDELAY_CASCADE_G, "MASTER", "NONE");

   type AdcClkDiv4RegType is record
      masterData      : slv(7 downto 0);
      masterData_1    : slv(7 downto 0);
      longDataCounter : slv(2 downto 0);
      longData        : slv(55 downto 0);
      longData_1      : slv(55 downto 0);
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
      longDataCounter => (others => '0'),
      longData        => (others => '0'),
      longData_1      => (others => '0'),
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
      masterAdcData      : slv(13 downto 0);
      adcDataGearboxIn   : slv(15 downto 0);
      adcDataGearboxIn_1 : slv(15 downto 0);
   end record;

   constant ADC_CLK_DV7_REG_INIT_C : AdcClkDiv7RegType := (
      gearboxCounter     => (others => '0'),
      gearboxSeq         => (others => '0'),
      masterAdcData      => (others => '0'),
      adcDataGearboxIn   => (others => '0'),
      adcDataGearboxIn_1 => (others => '0')
      );

   signal adcDV4R   : AdcClkDiv4RegType := ADC_CLK_DV4_REG_INIT_C;
   signal adcDv4Rin : AdcClkDiv4RegType;

   signal adcDV7R   : AdcClkDiv7RegType := ADC_CLK_DV7_REG_INIT_C;
   signal adcDv7Rin : AdcClkDiv7RegType;


   -- Local signals
   signal sDataPadP     : sl;
   signal sDataPadN     : sl;
   signal sData_i       : sl;
   signal sData_d       : sl;

   -- idelay signals
   signal masterCntValue1 : slv(8 downto 0);
   signal masterCntValue2 : slv(8 downto 0);
   signal cascOut    : sl;
   signal cascRet    : sl;
   -- iserdes signal
   signal masterData     : slv(7 downto 0);

   attribute keep of adcDV4R       : signal is "true";
   attribute keep of adcDV7R       : signal is "true";
   attribute keep of sData_i       : signal is "true";

begin
   
   adcData     <= bitReverse(adcDv7R.masterAdcData(6 downto 0)) & bitReverse(adcDv7R.masterAdcData(13 downto 7)) when BIT_REV_G = '1'
              else adcDv7R.masterAdcData;


   -------------------------------------------------------------------------------------------------
   -- Create Clocks
   -------------------------------------------------------------------------------------------------

   -- input sData buffer
   --
   U_IBUFDS_sData : IBUFDS_DIFF_OUT
      generic map (
         DQS_BIAS => "FALSE"            -- (FALSE, TRUE)
      )
      port map (
         O  => sDataPadP,               -- 1-bit output: Buffer output
         OB => sDataPadN,
         I  => sDataP,  -- 1-bit input: Diff_p buffer input (connect directly to top-level port)
         IB => sDataN   -- 1-bit input: Diff_n buffer input (connect directly to top-level port)
      );
   -- Optionally invert the pad input
   sData_i <= sDataPadP when ADC_INVERT_CH_G = '0' else sDataPadN;
   ----------------------------------------------------------------------------
   -- idelay3 
   ----------------------------------------------------------------------------
   U_IDELAYE3_0 : entity surf.Idelaye3Wrapper
      generic map (
         CASCADE          => CASCADE_C,    -- Cascade setting (MASTER, NONE, SLAVE_END, SLAVE_MIDDLE)
         DELAY_FORMAT     => "COUNT",   -- Units of the DELAY_VALUE (COUNT, TIME)
         DELAY_SRC        => "IDATAIN",   -- Delay input (DATAIN, IDATAIN)
         DELAY_TYPE       => "VAR_LOAD",  -- Set the type of tap delay line (FIXED, VARIABLE, VAR_LOAD)
         DELAY_VALUE      => conv_integer(DEFAULT_DELAY_G),  -- Input delay value setting
         IS_CLK_INVERTED  => '0',       -- Optional inversion for CLK
         IS_RST_INVERTED  => '0',       -- Optional inversion for RST
         REFCLK_FREQUENCY => IDELAYCTRL_FREQ_G,  -- IDELAYCTRL clock input frequency in MHz (200.0-2667.0)
         SIM_DEVICE       => "ULTRASCALE",  -- Set the device version (ULTRASCALE, ULTRASCALE_PLUS, ULTRASCALE_PLUS_ES1,
         -- ULTRASCALE_PLUS_ES2)
         UPDATE_MODE      => "ASYNC"  -- Determines when updates to the delay will take effect (ASYNC, MANUAL,
       -- SYNC)
         )
      port map (
         CASC_IN     => '0',  -- 1-bit input: Cascade delay input from slave ODELAY CASCADE_OUT
         CASC_OUT    => cascOut,         -- 1-bit output: Cascade delay output to ODELAY input cascade
         CASC_RETURN => cascRet,  -- 1-bit input: Cascade delay returning from slave ODELAY DATAOUT
         CNTVALUEOUT => masterCntValue1,   -- 9-bit output: Counter value output
         DATAOUT     => sData_d,        -- 1-bit output: Delayed data output
         CE          => '0',  -- 1-bit input: Active high enable increment/decrement input
         CLK         => dClkDiv4,       -- 1-bit input: Clock input
         CNTVALUEIN  => delay,   -- 9-bit input: Counter value input
         DATAIN      => '1',            -- 1-bit input: Data input from the logic
         EN_VTC      => '0',  -- 1-bit input: Keep delay constant over VT
         IDATAIN     => sData_i,        -- 1-bit input: Data input from the IOBUF
         INC         => '0',            -- 1-bit input: Increment / Decrement tap delay input
         LOAD        => loadDelay,  -- 1-bit input: Load DELAY_VALUE input
         RST         => dRstDiv4       -- 1-bit input: Asynchronous Reset to the DELAY_VALUE
         );
   
   G_IdelayCascade: if IDELAY_CASCADE_G = true generate
      signal masterCntValue   : slv(9 downto 0);
   begin
      
      U_ODELAYE3_0 : entity surf.Odelaye3Wrapper
         generic map (
            CASCADE => "SLAVE_END",    -- Cascade setting (MASTER, NONE, SLAVE_END, SLAVE_MIDDLE)
            DELAY_FORMAT => "COUNT",   -- Units of the DELAY_VALUE (COUNT, TIME)
            DELAY_TYPE => "VAR_LOAD",  -- Set the type of tap delay line (FIXED, VARIABLE, VAR_LOAD)
            DELAY_VALUE => conv_integer(DEFAULT_DELAY_G), -- Input delay value setting
            IS_CLK_INVERTED => '0',    -- Optional inversion for CLK
            IS_RST_INVERTED => '0',    -- Optional inversion for RST
            REFCLK_FREQUENCY => IDELAYCTRL_FREQ_G, -- IDELAYCTRL clock input frequency in MHz (200.0-2400.0)
            UPDATE_MODE => "ASYNC")    -- Determines when updates to the delay will take effect (ASYNC, MANUAL, SYNC)
         port map (
            CASC_IN     => cascOut,       -- 1-bit input: Cascade delay input from slave IDELAY CASCADE_OUT
            CASC_OUT    => open,          -- 1-bit output: Cascade delay output to IDELAY input cascade 
            CASC_RETURN => '0',           -- 1-bit input: Cascade delay returning from slave IDELAY DATAOUT 
            ODATAIN     => '0',           -- 1-bit input: Data input
            DATAOUT     => cascRet,       -- 1-bit output: Delayed data from ODATAIN input port 
            CLK         => dClkDiv4,           -- 1-bit input: Clock input 
            EN_VTC      => '0',           -- 1-bit input: Keep delay constant over VT 
            INC         => '0',           -- 1-bit input: Increment / Decrement tap delay input
            CE          => '0',           -- 1-bit input: Active high enable increment/decrement input 
            LOAD        => loadDelay,   -- 1-bit input: Load DELAY_VALUE input 
            RST         => dRstDiv4,      -- 1-bit input: Asynchronous Reset to the DELAY_VALUE 
            CNTVALUEIN  => delay,      -- 9-bit input: Counter value input
            CNTVALUEOUT => masterCntValue2);   -- 9-bit output: Counter value output 
      
      masterCntValue <= resize(masterCntValue1, 10, '0') + masterCntValue2;
      delayValueOut <= masterCntValue(9 downto 1);
         
   end generate;
   G_IdelayNoCascade: if IDELAY_CASCADE_G = false generate
      delayValueOut     <= masterCntValue1;
      masterCntValue2   <= (others=>'0');
      cascRet           <= '0';
   end generate;
   
   ----------------------------------------------------------------------------
   -- iserdes3
   ----------------------------------------------------------------------------
   U_ISERDESE3_master : ISERDESE3
      generic map (
         DATA_WIDTH        => 8,        -- Parallel data width (4,8)
         FIFO_ENABLE       => "FALSE",  -- Enables the use of the FIFO
         FIFO_SYNC_MODE    => "FALSE",  -- Enables the use of internal 2-stage synchronizers on the FIFO
         IS_CLK_B_INVERTED => '1',      -- Optional inversion for CLK_B
         IS_CLK_INVERTED   => '0',      -- Optional inversion for CLK
         IS_RST_INVERTED   => '0',      -- Optional inversion for RST
         SIM_DEVICE        => "ULTRASCALE"  -- Set the device version (ULTRASCALE, ULTRASCALE_PLUS, ULTRASCALE_PLUS_ES1,
      )
      port map (
         FIFO_EMPTY      => open,       -- 1-bit output: FIFO empty flag
         INTERNAL_DIVCLK => open,  -- 1-bit output: Internally divided down clock used when FIFO is
         Q           => masterData,     -- bit registered output
         CLK         => dClk,           -- 1-bit input: High-speed clock
         CLKDIV      => dClkDiv4,       -- 1-bit input: Divided Clock
         CLK_B       => dClk,           -- 1-bit input: Inversion of High-speed clock CLK
         D           => sData_d,        -- 1-bit input: Serial Data Input
         FIFO_RD_CLK => '1',            -- 1-bit input: FIFO read clock
         FIFO_RD_EN  => '1',            -- 1-bit input: Enables reading the FIFO when asserted
         RST         => dRstDiv4        -- 1-bit input: Asynchronous Reset
      );

   -----------------------------------------------------------------------------
   -- 8 to 16, 56 gearbox and bitSlip control logic
   -- Part or all 56 bits can be used for idelay3 adjustment
   -----------------------------------------------------------------------------
   adc8to56GearboxComb : process (adcDv4R, masterData, bitSlip) is
      variable v : AdcClkDiv4RegType;
   begin

      v := adcDv4R;

      -- update register with signal values
      v.masterData := masterData;
      v.bitSlip    := bitSlip;

      -- creates pipeline
      v.masterData_1 := adcDv4R.masterData;
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

   adclongSeq : process (dClkDiv4) is
   begin
      if (rising_edge(dClkDiv4)) then
         if (dRstDiv4 = '1') then
            adcDv4R <= ADC_CLK_DV4_REG_INIT_C;
         else
            adcDv4R <= adcDv4Rin after TPD_G;
         end if;
      end if;
   end process;


   adc8To7GearboxComb : process (adcDv4R, adcDv7R, gearboxOffset) is
      variable v : AdcClkDiv7RegType;
   begin

      v := adcDv7R;

      v.gearboxSeq       := adcDv7R.gearboxCounter + gearboxOffset;
      v.adcDataGearboxIn := adcDv4R.masterDataDWBS;

      -- creates pipeline
      v.adcDataGearboxIn_1 := adcDv7R.adcDataGearboxIn;

      case (adcDv7R.gearboxSeq) is
         when "000" =>
            v.masterAdcData  := adcDv7R.adcDataGearboxIn(13 downto 0);
            v.gearboxCounter := adcDv7R.gearboxCounter + 1;
         when "001" =>
            v.masterAdcData  := adcDv7R.adcDataGearboxIn(11 downto 0) & adcDv7R.adcDataGearboxIn_1(15 downto 14);
            v.gearboxCounter := adcDv7R.gearboxCounter + 1;
         when "010" =>
            v.masterAdcData  := adcDv7R.adcDataGearboxIn(9 downto 0) & adcDv7R.adcDataGearboxIn_1(15 downto 12);
            v.gearboxCounter := adcDv7R.gearboxCounter + 1;
         when "011" =>
            v.masterAdcData  := adcDv7R.adcDataGearboxIn(7 downto 0) & adcDv7R.adcDataGearboxIn_1(15 downto 10);
            v.gearboxCounter := adcDv7R.gearboxCounter + 1;
         when "100" =>
            v.masterAdcData  := adcDv7R.adcDataGearboxIn(5 downto 0) & adcDv7R.adcDataGearboxIn_1(15 downto 8);
            v.gearboxCounter := adcDv7R.gearboxCounter + 1;
         when "101" =>
            v.masterAdcData  := adcDv7R.adcDataGearboxIn(3 downto 0) & adcDv7R.adcDataGearboxIn_1(15 downto 6);
            v.gearboxCounter := adcDv7R.gearboxCounter + 1;
         when "110" =>
            v.masterAdcData  := adcDv7R.adcDataGearboxIn(1 downto 0) & adcDv7R.adcDataGearboxIn_1(15 downto 4);
            v.gearboxCounter := adcDv7R.gearboxCounter + 1;
         when "111" =>
            v.masterAdcData  := adcDv7R.adcDataGearboxIn_1(15 downto 2);
            v.gearboxCounter := adcDv7R.gearboxCounter + 1;
         when others =>
            v.masterAdcData  := (others => '0');
            v.gearboxCounter := (others => '0');
      end case;

      adcDv7Rin <= v;

      --outputs

   end process;


   adc8To7GearboxSeq : process (dClkDiv7) is
   begin
      if (rising_edge(dClkDiv7)) then
         if (dRstDiv7 = '1') then
            adcDv7R <= ADC_CLK_DV7_REG_INIT_C;
         else
            adcDv7R <= adcDv7Rin after TPD_G;
         end if;
      end if;
   end process;
end rtl;

