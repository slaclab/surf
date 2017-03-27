-------------------------------------------------------------------------------
-- File       : XadcSimpleCore.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-01-10
-- Last update: 2016-12-08
-------------------------------------------------------------------------------
-- Description: This core only measures internal voltages and temperature
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
use ieee.numeric_std.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;

library unisim;
use unisim.vcomponents.all;

entity XadcSimpleCore is
   generic (
      TPD_G              : time   := 1 ns;
      SIM_DEVICE_G       : string := "7SERIES";
      SIM_MONITOR_FILE_G : string := "design.txt";

      AXIL_ERROR_RESP_G : slv(1 downto 0) := AXI_RESP_DECERR_C;

      -- Global XADC configurations
      SEQUENCER_MODE_G : string                 := "DEFAULT";  -- SINGLE_PASS, CONTINUOUS, SINGLE_CHANNEL,
                                                               -- SIMULTANEOUS, INDEPENDENT
      SAMPLING_MODE_G  : string                 := "CONTINUOUS";  -- or "EVENT-DRIVEN"      
      MUX_EN_G         : boolean                := false;      -- Enable external multiplexer
      ADCCLK_RATIO_G   : integer range 2 to 255 := 7;
      SAMPLE_AVG_G     : slv(1 downto 0)        := "11";  -- No averaging, 16  64 or 256 samples
      COEF_AVG_EN_G    : boolean                := true;  -- Enable averaging for calibration coefficients

      -- Configurations for single channel operation
      SING_ADC_CH_SEL_G : slv(4 downto 0) := "00000";  -- Only valid for single channel or ext
      SING_ACQ_EN_G     : boolean         := false;    -- Extra settling time in single channel mode
      SING_BIPOLAR_G    : boolean         := false;    -- false: unipolar, true: bipolar

      -- Alarm configuration
      OVERTEMP_AUTO_SHDN_G : boolean := true;
      OVERTEMP_ALM_EN_G    : boolean := false;
      OVERTEMP_LIMIT_G     : real    := 125.0;
      OVERTEMP_RESET_G     : real    := 50.0;
      TEMP_ALM_EN_G        : boolean := false;
      TEMP_UPPER_G         : real    := 80.0;
      TEMP_LOWER_G         : real    := 70.0;
      VCCINT_ALM_EN_G      : boolean := false;
      VCCINT_UPPER_G       : real    := 1.1;
      VCCINT_LOWER_G       : real    := 0.9;
      VCCAUX_ALM_EN_G      : boolean := false;
      VCCAUX_UPPER_G       : real    := 1.9;
      VCCAUX_LOWER_G       : real    := 1.7;
      VCCBRAM_ALM_EN_G     : boolean := false;
      VCCBRAM_UPPER_G      : real    := 1.1;
      VCCBRAM_LOWER_G      : real    := 0.9;
      VCCPINT_ALM_EN_G     : boolean := false;
      VCCPINT_UPPER_G      : real    := 1.1;
      VCCPINT_LOWER_G      : real    := 0.9;
      VCCPAUX_ALM_EN_G     : boolean := false;
      VCCPAUX_UPPER_G      : real    := 1.9;
      VCCPAUX_LOWER_G      : real    := 1.7;
      VCCODDR_ALM_EN_G     : boolean := false;
      VCCODDR_UPPER_G      : real    := 1.9;
      VCCODDR_LOWER_G      : real    := 1.7;

      -- Calibration coefficient configuration
      ADC_OFFSET_CORR_EN_G    : boolean := true;  -- CAL0
      ADC_GAIN_CORR_EN_G      : boolean := true;  -- CAL1
      SUPPLY_OFFSET_CORR_EN_G : boolean := true;  -- CAL2
      SUPPLY_GAIN_CORR_EN_G   : boolean := true;  -- CAL3

      -- Sequencer configurations
      SEQ_XADC_CAL_SEL_EN_G    : boolean                   := true;
      SEQ_VCCPINT_SEL_EN_G     : boolean                   := false;
      SEQ_VCCPAUX_SEL_EN_G     : boolean                   := false;
      SEQ_VCCODDR_SEL_EN_G     : boolean                   := false;
      SEQ_TEMPERATURE_SEL_EN_G : boolean                   := false;
      SEQ_VCCINT_SEL_EN_G      : boolean                   := false;
      SEQ_VCCAUX_SEL_EN_G      : boolean                   := false;
      SEQ_VPVN_SEL_EN_G        : boolean                   := false;
      SEQ_VREFP_SEL_EN_G       : boolean                   := false;
      SEQ_VREFN_SEL_EN_G       : boolean                   := false;
      SEQ_VCCBRAM_SEL_EN_G     : boolean                   := false;
      SEQ_VAUX_SEL_EN_G        : booleanArray(15 downto 0) := (others => false);

      SEQ_XADC_CAL_AVG_EN_G    : boolean                   := true;
      SEQ_VCCPINT_AVG_EN_G     : boolean                   := true;
      SEQ_VCCPAUX_AVG_EN_G     : boolean                   := true;
      SEQ_VCCODDR_AVG_EN_G     : boolean                   := true;
      SEQ_TEMPERATURE_AVG_EN_G : boolean                   := true;
      SEQ_VCCINT_AVG_EN_G      : boolean                   := true;
      SEQ_VCCAUX_AVG_EN_G      : boolean                   := true;
      SEQ_VPVN_AVG_EN_G        : boolean                   := true;
      SEQ_VREFP_AVG_EN_G       : boolean                   := true;
      SEQ_VREFN_AVG_EN_G       : boolean                   := true;
      SEQ_VCCBRAM_AVG_EN_G     : boolean                   := true;
      SEQ_VAUX_AVG_EN_G        : booleanArray(15 downto 0) := (others => true);

      SEQ_VPVN_BIPOLAR_G : boolean                   := false;
      SEQ_VAUX_BIPOLAR_G : BooleanArray(15 downto 0) := (others => false);

      SEQ_XADC_CAL_ACQ_EN_G    : boolean                   := false;
      SEQ_VCCPINT_ACQ_EN_G     : boolean                   := false;
      SEQ_VCCPAUX_ACQ_EN_G     : boolean                   := false;
      SEQ_VCCODDR_ACQ_EN_G     : boolean                   := false;
      SEQ_TEMPERATURE_ACQ_EN_G : boolean                   := false;
      SEQ_VCCINT_ACQ_EN_G      : boolean                   := false;
      SEQ_VCCAUX_ACQ_EN_G      : boolean                   := false;
      SEQ_VPVN_ACQ_EN_G        : boolean                   := false;
      SEQ_VREFP_ACQ_EN_G       : boolean                   := false;
      SEQ_VREFN_ACQ_EN_G       : boolean                   := false;
      SEQ_VCCBRAM_ACQ_EN_G     : boolean                   := false;
      SEQ_VAUX_ACQ_EN_G        : BooleanArray(15 downto 0) := (others => false));

   port (
      -- AxiLite Interface
      axilClk         : in  sl;
      axilRst         : in  sl;
      axilReadMaster  : in  AxiLiteReadMasterType;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType;
      axilWriteSlave  : out AxiLiteWriteSlaveType;
      --XADC I/O ports
      vpIn            : in  sl               := '0';
      vnIn            : in  sl               := '0';
      vAuxP           : in  slv(15 downto 0) := (others => '0');
      vAuxN           : in  slv(15 downto 0) := (others => '0');
      convSt          : in  sl               := '0';
      convStClk       : in  sl               := '0';
      alm             : out slv(7 downto 0);
      ot              : out sl;
      busy            : out sl;
      channel         : out slv(4 downto 0);
      eoc             : out sl;
      eos             : out sl;
      muxAddr         : out slv(4 downto 0));
end XadcSimpleCore;

architecture rtl of XadcSimpleCore is

   function convTemp (temp : real) return slv is
      variable ret : slv(11 downto 0);
   begin
      return slv(to_unsigned(integer((temp + 273.15) * (4096.0 / 503.975)), 12));
   end function convTemp;

   function convPwr (pwr : real) return slv is
      variable ret : slv(11 downto 0);
   begin
      return slv(to_unsigned(integer((pwr / 3.0) * 4096.0), 12));
   end function convPwr;

   -------------------------------------------------------------------------------------------------
   -- Global config registers
   -------------------------------------------------------------------------------------------------
   function INIT_40_C return bit_vector is
      variable ret : slv(15 downto 0);
   begin
      ret(4 downto 0) := SING_ADC_CH_SEL_G;
      ret(7 downto 5) := (others => '0');
      ret(8)          := toSl(SING_ACQ_EN_G);
      if (SAMPLING_MODE_G = "CONTINUOUS") then
         ret(9) := '0';
      elsif (SAMPLING_MODE_G = "EVENT-DRIVEN") then
         ret(9) := '1';
      else
         ret(9) := '0';
      end if;
      ret(10)           := toSl(SING_BIPOLAR_G);
      ret(11)           := toSl(MUX_EN_G);
      ret(13 downto 12) := SAMPLE_AVG_G;
      ret(14)           := '0';
      ret(15)           := toSl(not COEF_AVG_EN_G);
      return to_bitvector(ret);
   end function INIT_40_C;

   function INIT_41_C return bit_vector is
      variable ret : slv(15 downto 0) := (others => '0');
   begin
      ret(0)  := toSl(not OVERTEMP_ALM_EN_G);
      ret(1)  := toSl(not TEMP_ALM_EN_G);
      ret(2)  := toSl(not VCCINT_ALM_EN_G);
      ret(3)  := toSl(not VCCAUX_ALM_EN_G);
      ret(4)  := toSl(ADC_OFFSET_CORR_EN_G);
      ret(5)  := toSl(ADC_GAIN_CORR_EN_G);
      ret(6)  := toSl(SUPPLY_OFFSET_CORR_EN_G);
      ret(7)  := toSl(SUPPLY_GAIN_CORR_EN_G);
      ret(8)  := toSl(not VCCBRAM_ALM_EN_G);
      ret(9)  := toSl(not VCCPINT_ALM_EN_G);
      ret(10) := toSl(not VCCPAUX_ALM_EN_G);
      ret(11) := toSl(not VCCODDR_ALM_EN_G);
      if (SEQUENCER_MODE_G = "DEFAULT") then
         ret(15 downto 12) := "0000";
      elsif (SEQUENCER_MODE_G = "SINGLE_PASS") then
         ret(15 downto 12) := "0001";
      elsif (SEQUENCER_MODE_G = "CONTINUOUS") then
         ret(15 downto 12) := "0010";
      elsif(SEQUENCER_MODE_G = "SINGLE_CHANNEL") then
         ret(15 downto 12) := "0011";
      elsif(SEQUENCER_MODE_G = "SIMULTANEOUS") then
         ret(15 downto 12) := "0100";
      elsif(SEQUENCER_MODE_G = "INDEPENDENT") then
         ret(15 downto 12) := "1000";
      else
         ret(15 downto 12) := "0000";
      end if;
      return to_bitvector(ret);
   end function INIT_41_C;

   function INIT_42_C return bit_vector is
      variable ret : slv(15 downto 0) := (others => '0');
   begin
      ret(5 downto 4)  := (others => '0');  -- Powerdown
      ret(15 downto 8) := slv(to_unsigned(ADCCLK_RATIO_G, 8));
      return to_bitvector(ret);
   end function INIT_42_C;

   -------------------------------------------------------------------------------------------------
   -- Sequencer registers
   -------------------------------------------------------------------------------------------------
   function INIT_48_C return bit_vector is
      variable ret : slv(15 downto 0) := (others => '0');
   begin
      ret(0)  := toSl(SEQ_XADC_CAL_SEL_EN_G);
      ret(5)  := toSl(SEQ_VCCPINT_SEL_EN_G);
      ret(6)  := toSl(SEQ_VCCPAUX_SEL_EN_G);
      ret(7)  := toSl(SEQ_VCCODDR_SEL_EN_G);
      ret(8)  := toSl(SEQ_TEMPERATURE_SEL_EN_G);
      ret(9)  := toSl(SEQ_VCCINT_SEL_EN_G);
      ret(10) := toSl(SEQ_VCCAUX_SEL_EN_G);
      ret(11) := toSl(SEQ_VPVN_SEL_EN_G);
      ret(12) := toSl(SEQ_VREFP_SEL_EN_G);
      ret(13) := toSl(SEQ_VREFN_SEL_EN_G);
      ret(14) := toSl(SEQ_VCCBRAM_SEL_EN_G);
      return to_bitvector(ret);
   end function INIT_48_C;

   constant INIT_49_C : bit_vector(15 downto 0) := to_bitvector(toSlv(SEQ_VAUX_SEL_EN_G));

   function INIT_4A_C return bit_vector is
      variable ret : slv(15 downto 0) := (others => '0');
   begin
      ret(0)  := toSl(SEQ_XADC_CAL_AVG_EN_G);
      ret(5)  := toSl(SEQ_VCCPINT_AVG_EN_G);
      ret(6)  := toSl(SEQ_VCCPAUX_AVG_EN_G);
      ret(7)  := toSl(SEQ_VCCODDR_AVG_EN_G);
      ret(8)  := toSl(SEQ_TEMPERATURE_AVG_EN_G);
      ret(9)  := toSl(SEQ_VCCINT_AVG_EN_G);
      ret(10) := toSl(SEQ_VCCAUX_AVG_EN_G);
      ret(11) := toSl(SEQ_VPVN_AVG_EN_G);
      ret(12) := toSl(SEQ_VREFP_AVG_EN_G);
      ret(13) := toSl(SEQ_VREFN_AVG_EN_G);
      ret(14) := toSl(SEQ_VCCBRAM_AVG_EN_G);
      return to_bitvector(ret);
   end function INIT_4A_C;

   constant INIT_4B_C : bit_vector(15 downto 0) := to_bitvector(toSlv(SEQ_VAUX_AVG_EN_G));

   function INIT_4C_C return bit_vector is
      variable ret : slv(15 downto 0) := (others => '0');
   begin
      ret(11) := toSl(SEQ_VPVN_BIPOLAR_G);
      return to_bitvector(ret);
   end function INIT_4C_C;

   constant INIT_4D_C : bit_vector(15 downto 0) := to_bitvector(toSlv(SEQ_VAUX_BIPOLAR_G));

   function INIT_4E_C return bit_vector is
      variable ret : slv(15 downto 0) := (others => '0');
   begin
      ret(0)  := toSl(SEQ_XADC_CAL_ACQ_EN_G);
      ret(5)  := toSl(SEQ_VCCPINT_ACQ_EN_G);
      ret(6)  := toSl(SEQ_VCCPAUX_ACQ_EN_G);
      ret(7)  := toSl(SEQ_VCCODDR_ACQ_EN_G);
      ret(8)  := toSl(SEQ_TEMPERATURE_ACQ_EN_G);
      ret(9)  := toSl(SEQ_VCCINT_ACQ_EN_G);
      ret(10) := toSl(SEQ_VCCAUX_ACQ_EN_G);
      ret(11) := toSl(SEQ_VPVN_ACQ_EN_G);
      ret(12) := toSl(SEQ_VREFP_ACQ_EN_G);
      ret(13) := toSl(SEQ_VREFN_ACQ_EN_G);
      ret(14) := toSl(SEQ_VCCBRAM_ACQ_EN_G);
      return to_bitvector(ret);
   end function INIT_4E_C;

   constant INIT_4F_C : bit_vector(15 downto 0) := to_bitvector(toSlv(SEQ_VAUX_ACQ_EN_G));
   -------------------------------------------------------------------------------------------------
   -- ALARM registers
   -------------------------------------------------------------------------------------------------
   constant INIT_50_C : bit_vector(15 downto 0) := to_bitvector(convTemp(TEMP_UPPER_G) & "0000");
   constant INIT_51_C : bit_vector(15 downto 0) := to_bitvector(convPwr(VCCINT_UPPER_G) & "0000");
   constant INIT_52_C : bit_vector(15 downto 0) := to_bitvector(convPwr(VCCAUX_UPPER_G) & "0000");
   constant INIT_53_C : bit_vector(15 downto 0) := to_bitvector(convTemp(OVERTEMP_LIMIT_G) &
                                                                ite(OVERTEMP_AUTO_SHDN_G, "0011", "0000"));
   constant INIT_54_C : bit_vector(15 downto 0) := to_bitvector(convTemp(TEMP_LOWER_G) & "0000");
   constant INIT_55_C : bit_vector(15 downto 0) := to_bitvector(convPwr(VCCINT_LOWER_G) & "0000");
   constant INIT_56_C : bit_vector(15 downto 0) := to_bitvector(convPwr(VCCAUX_LOWER_G) & "0000");
   constant INIT_57_C : bit_vector(15 downto 0) := to_bitvector(convTemp(OVERTEMP_RESET_G) & "0000");
   constant INIT_58_C : bit_vector(15 downto 0) := to_bitvector(convPwr(VCCBRAM_UPPER_G) & "0000");
   constant INIT_59_C : bit_vector(15 downto 0) := to_bitvector(convPwr(VCCPINT_UPPER_G) & "0000");
   constant INIT_5A_C : bit_vector(15 downto 0) := to_bitvector(convPwr(VCCPAUX_UPPER_G) & "0000");
   constant INIT_5B_C : bit_vector(15 downto 0) := to_bitvector(convPwr(VCCODDR_UPPER_G) & "0000");
   constant INIT_5C_C : bit_vector(15 downto 0) := to_bitvector(convPwr(VCCBRAM_LOWER_G) & "0000");
   constant INIT_5D_C : bit_vector(15 downto 0) := to_bitvector(convPwr(VCCPINT_LOWER_G) & "0000");
   constant INIT_5E_C : bit_vector(15 downto 0) := to_bitvector(convPwr(VCCPAUX_LOWER_G) & "0000");
   constant INIT_5F_C : bit_vector(15 downto 0) := to_bitvector(convPwr(VCCODDR_LOWER_G) & "0000");

   -------------------------------------------------------------------------------------------------
   -- Signals
   -------------------------------------------------------------------------------------------------
   signal drpAddr   : slv(6 downto 0);
   signal drpEn     : sl;
   signal drpDi     : slv(15 downto 0);
   signal drpDo     : slv(15 downto 0);
   signal drpWe     : sl;
   signal drpRdy    : sl;
   signal drpUsrRst : sl;

begin

   U_AxiLiteToDrp_1 : entity work.AxiLiteToDrp
      generic map (
         TPD_G            => TPD_G,
         AXI_ERROR_RESP_G => AXIL_ERROR_RESP_G,
         COMMON_CLK_G     => true,
         EN_ARBITRATION_G => false,
         TIMEOUT_G        => 4096,
         ADDR_WIDTH_G     => 7,
         DATA_WIDTH_G     => 16)
      port map (
         axilClk         => axilClk,          -- [in]
         axilRst         => axilRst,          -- [in]
         axilReadMaster  => axilReadMaster,   -- [in]
         axilReadSlave   => axilReadSlave,    -- [out]
         axilWriteMaster => axilWriteMaster,  -- [in]
         axilWriteSlave  => axilWriteSlave,   -- [out]
         drpClk          => axilClk,          -- [in]
         drpRst          => axilRst,          -- [in]
         drpRdy          => drpRdy,           -- [in]
         drpEn           => drpEn,            -- [out]
         drpWe           => drpWe,            -- [out]
         drpUsrRst       => drpUsrRst,        -- [out]
         drpAddr         => drpAddr,          -- [out]
         drpDi           => drpDi,            -- [out]
         drpDo           => drpDo);           -- [in]

   XADC_Inst : XADC
      generic map(
         INIT_40          => INIT_40_C,
         INIT_41          => INIT_41_C,
         INIT_42          => INIT_42_C,
         INIT_43          => X"0000",
         INIT_44          => X"0000",
         INIT_45          => X"0000",
         INIT_46          => X"0000",
         INIT_47          => X"0000",
         INIT_48          => INIT_48_C,
         INIT_49          => INIT_49_C,
         INIT_4A          => INIT_4A_C,
         INIT_4B          => INIT_4B_C,
         INIT_4C          => INIT_4C_C,
         INIT_4D          => INIT_4D_C,
         INIT_4E          => INIT_4E_C,
         INIT_4F          => INIT_4F_C,
         INIT_50          => INIT_50_C,
         INIT_51          => INIT_51_C,
         INIT_52          => INIT_52_C,
         INIT_53          => INIT_53_C,
         INIT_54          => INIT_54_C,
         INIT_55          => INIT_55_C,
         INIT_56          => INIT_56_C,
         INIT_57          => INIT_57_C,
         INIT_58          => INIT_58_C,
         INIT_59          => INIT_59_C,
         INIT_5A          => INIT_5A_C,
         INIT_5B          => INIT_5B_C,
         INIT_5C          => INIT_5C_C,
         INIT_5D          => INIT_5D_C,
         INIT_5E          => INIT_5E_C,
         INIT_5F          => INIT_5F_C,
         SIM_DEVICE       => SIM_DEVICE_G,
         SIM_MONITOR_FILE => SIM_MONITOR_FILE_G)
      port map (
         CONVST       => convSt,
         CONVSTCLK    => convStClk,
         DADDR        => drpAddr,
         DCLK         => axilClk,
         DEN          => drpEn,
         DI           => drpDi,
         DWE          => drpWe,
         RESET        => drpUsrRst,
         VAUXN        => vAuxN,
         VAUXP        => vAuxP,
         ALM          => alm,
         BUSY         => busy,
         CHANNEL      => channel,
         DO           => drpDo,
         DRDY         => drpRdy,
         EOC          => eoc,
         EOS          => eos,
         JTAGBUSY     => open,
         JTAGLOCKED   => open,
         JTAGMODIFIED => open,
         OT           => ot,
         MUXADDR      => muxaddr,
         VN           => vnIn,
         VP           => vpIn);

end rtl;
