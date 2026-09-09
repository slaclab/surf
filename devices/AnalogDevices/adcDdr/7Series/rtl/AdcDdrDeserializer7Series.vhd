-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: One delayed DDR input lane for AMD 7 Series FPGAs
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

library surf;
use surf.StdRtlPkg.all;

library unisim;
use unisim.vcomponents.all;

entity AdcDdrDeserializer7Series is
   generic (
      IODELAY_GROUP_G         : string   := "DEFAULT_GROUP";
      IDELAYCTRL_FREQ_G       : real     := 200.0;
      SERIALIZATION_FACTOR_G  : positive := 14);
   port (
      bitClk    : in sl;
      bitClkInv : in sl;
      wordClk   : in sl;
      rst       : in sl;
      bitSlip   : in sl;

      delayClk   : in  sl;
      delayValue : in  slv(4 downto 0);
      delayLoad  : in  sl;

      serialData : in  sl;
      dataWord   : out slv(SERIALIZATION_FACTOR_G-1 downto 0));
end entity AdcDdrDeserializer7Series;

architecture rtl of AdcDdrDeserializer7Series is

   signal delayedData  : sl;
   signal rawWord      : slv(13 downto 0);
   signal shift1        : sl;
   signal shift2        : sl;

   attribute IODELAY_GROUP            : string;
   attribute IODELAY_GROUP of U_Delay : label is IODELAY_GROUP_G;

begin

   assert SERIALIZATION_FACTOR_G = 4 or SERIALIZATION_FACTOR_G = 6 or
          SERIALIZATION_FACTOR_G = 8 or SERIALIZATION_FACTOR_G = 10 or
          SERIALIZATION_FACTOR_G = 14
      report "AdcDdrDeserializer7Series supports only native DDR widths 4, 6, 8, 10, and 14"
      severity failure;

   U_Delay : IDELAYE2
      generic map (
         DELAY_SRC             => "IDATAIN",
         HIGH_PERFORMANCE_MODE => "TRUE",
         IDELAY_TYPE           => "VAR_LOAD",
         IDELAY_VALUE          => 0,
         REFCLK_FREQUENCY      => IDELAYCTRL_FREQ_G,
         SIGNAL_PATTERN        => "DATA")
      port map (
         C           => delayClk, -- [in]
         REGRST      => '0', -- [in]
         LD          => delayLoad, -- [in]
         CE          => '0', -- [in]
         INC         => '1', -- [in]
         CINVCTRL    => '0', -- [in]
         CNTVALUEIN  => delayValue, -- [in]
         IDATAIN     => serialData, -- [in]
         DATAIN      => '0', -- [in]
         LDPIPEEN    => '0', -- [in]
         DATAOUT     => delayedData, -- [out]
         CNTVALUEOUT => open); -- [out]

   ------------------------------------------------------------------------------------------------
   -- Every supported width uses the same master. Q outputs above the selected
   -- width and width-expansion shift outputs are ignored when no slave exists.
   ------------------------------------------------------------------------------------------------
   U_Master : ISERDESE2
      generic map (
         DATA_RATE         => "DDR",
         DATA_WIDTH        => SERIALIZATION_FACTOR_G,
         INTERFACE_TYPE    => "NETWORKING",
         DYN_CLKDIV_INV_EN => "FALSE",
         DYN_CLK_INV_EN    => "FALSE",
         NUM_CE            => 1,
         OFB_USED          => "FALSE",
         IOBDELAY          => "IFD",
         SERDES_MODE       => "MASTER")
      port map (
         Q1           => rawWord(0), -- [out]
         Q2           => rawWord(1), -- [out]
         Q3           => rawWord(2), -- [out]
         Q4           => rawWord(3), -- [out]
         Q5           => rawWord(4), -- [out]
         Q6           => rawWord(5), -- [out]
         Q7           => rawWord(6), -- [out]
         Q8           => rawWord(7), -- [out]
         SHIFTOUT1    => shift1, -- [out]
         SHIFTOUT2    => shift2, -- [out]
         BITSLIP      => bitSlip, -- [in]
         CE1          => '1', -- [in]
         CE2          => '1', -- [in]
         CLK          => bitClk, -- [in]
         CLKB         => bitClkInv, -- [in]
         CLKDIV       => wordClk, -- [in]
         CLKDIVP      => '0', -- [in]
         D            => '0', -- [in]
         DDLY         => delayedData, -- [in]
         RST          => rst, -- [in]
         SHIFTIN1     => '0', -- [in]
         SHIFTIN2     => '0', -- [in]
         DYNCLKDIVSEL => '0', -- [in]
         DYNCLKSEL    => '0', -- [in]
         OFB          => '0', -- [in]
         OCLK         => '0', -- [in]
         OCLKB        => '0', -- [in]
         O            => open); -- [out]

   ------------------------------------------------------------------------------------------------
   -- The native 10- and 14-bit DDR modes use the dedicated master/slave width
   -- expansion path. For width 10 only slave Q3/Q4 are meaningful; width 14
   -- additionally uses Q5 through Q8.
   ------------------------------------------------------------------------------------------------
   GEN_WIDTH_WIDE : if SERIALIZATION_FACTOR_G = 10 or SERIALIZATION_FACTOR_G = 14 generate
   begin
      U_Slave : ISERDESE2
         generic map (
            DATA_RATE         => "DDR",
            DATA_WIDTH        => SERIALIZATION_FACTOR_G,
            INTERFACE_TYPE    => "NETWORKING",
            DYN_CLKDIV_INV_EN => "FALSE",
            DYN_CLK_INV_EN    => "FALSE",
            NUM_CE            => 1,
            OFB_USED          => "FALSE",
            IOBDELAY          => "IFD",
            SERDES_MODE       => "SLAVE")
         port map (
            Q1           => open, -- [out]
            Q2           => open, -- [out]
            Q3           => rawWord(8), -- [out]
            Q4           => rawWord(9), -- [out]
            Q5           => rawWord(10), -- [out]
            Q6           => rawWord(11), -- [out]
            Q7           => rawWord(12), -- [out]
            Q8           => rawWord(13), -- [out]
            SHIFTOUT1    => open, -- [out]
            SHIFTOUT2    => open, -- [out]
            BITSLIP      => bitSlip, -- [in]
            CE1          => '1', -- [in]
            CE2          => '1', -- [in]
            CLK          => bitClk, -- [in]
            CLKB         => bitClkInv, -- [in]
            CLKDIV       => wordClk, -- [in]
            CLKDIVP      => '0', -- [in]
            D            => '0', -- [in]
            DDLY         => '0', -- [in]
            RST          => rst, -- [in]
            SHIFTIN1     => shift1, -- [in]
            SHIFTIN2     => shift2, -- [in]
            DYNCLKDIVSEL => '0', -- [in]
            DYNCLKSEL    => '0', -- [in]
            OFB          => '0', -- [in]
            OCLK         => '0', -- [in]
            OCLKB        => '0', -- [in]
            O            => open); -- [out]
   end generate GEN_WIDTH_WIDE;

   dataWord <= rawWord(SERIALIZATION_FACTOR_G-1 downto 0);

end architecture rtl;
