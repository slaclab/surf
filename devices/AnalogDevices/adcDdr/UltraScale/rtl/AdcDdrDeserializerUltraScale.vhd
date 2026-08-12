-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: One delayed DDR input lane for AMD UltraScale FPGAs
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

entity AdcDdrDeserializerUltraScale is
   generic (
      TPD_G                  : time     := 1 ns;
      DEVICE_FAMILY_G        : string   := "ULTRASCALE";
      IODELAY_GROUP_G        : string   := "DEFAULT_GROUP";
      SERIALIZATION_FACTOR_G : positive := 14);
   port (
      bitClk    : in sl;
      bitClkInv : in sl;
      wordClk   : in sl;
      rst       : in sl;
      bitSlip   : in sl;

      delayClk   : in  sl;
      delayValue : in  slv(8 downto 0);
      delayLoad  : in  sl;

      serialData : in  sl;
      dataWord   : out slv(SERIALIZATION_FACTOR_G-1 downto 0);
      dataValid  : out sl);
end entity AdcDdrDeserializerUltraScale;

architecture rtl of AdcDdrDeserializerUltraScale is

   constant ISERDES_WIDTH_C : positive := ite(SERIALIZATION_FACTOR_G <= 6, 4, 8);

   signal delayedData  : sl;
   signal rawData      : slv(7 downto 0);
   signal gearboxData  : slv(SERIALIZATION_FACTOR_G-1 downto 0);

begin

   assert SERIALIZATION_FACTOR_G = 4 or SERIALIZATION_FACTOR_G = 6 or
          SERIALIZATION_FACTOR_G = 8 or SERIALIZATION_FACTOR_G = 10 or
          SERIALIZATION_FACTOR_G = 12 or SERIALIZATION_FACTOR_G = 14
      report "AdcDdrDeserializerUltraScale supports only DDR widths 4, 6, 8, 10, 12, and 14"
      severity failure;

   U_Delay : entity surf.Idelaye3Wrapper
      generic map (
         CASCADE          => "NONE",
         DELAY_FORMAT     => "COUNT",
         DELAY_SRC        => "IDATAIN",
         DELAY_TYPE       => "VAR_LOAD",
         DELAY_VALUE      => 0,
         IS_CLK_INVERTED  => '0',
         IS_RST_INVERTED  => '0',
         SIM_DEVICE       => DEVICE_FAMILY_G,
         UPDATE_MODE      => "ASYNC")
      port map (
         BUSY        => open, -- [out]
         CASC_IN     => '0', -- [in]
         CASC_OUT    => open, -- [out]
         CASC_RETURN => '0', -- [in]
         CNTVALUEOUT => open, -- [out]
         DATAOUT     => delayedData, -- [out]
         CE          => '0', -- [in]
         CLK         => delayClk, -- [in]
         CNTVALUEIN  => delayValue, -- [in]
         DATAIN      => '0', -- [in]
         EN_VTC      => '0', -- [in]
         IDATAIN     => serialData, -- [in]
         INC         => '0', -- [in]
         LOAD        => delayLoad, -- [in]
         RST         => rst); -- [in]

   U_Deserializer : ISERDESE3
      generic map (
         DATA_WIDTH        => ISERDES_WIDTH_C,
         FIFO_ENABLE       => "FALSE",
         FIFO_SYNC_MODE    => "FALSE",
         IS_CLK_B_INVERTED => '0',
         IS_CLK_INVERTED   => '0',
         IS_RST_INVERTED   => '0',
         SIM_DEVICE        => DEVICE_FAMILY_G)
      port map (
         FIFO_EMPTY      => open, -- [out]
         INTERNAL_DIVCLK => open, -- [out]
         Q               => rawData, -- [out]
         CLK             => bitClk, -- [in]
         CLKDIV          => wordClk, -- [in]
         CLK_B           => bitClkInv, -- [in]
         D               => delayedData, -- [in]
         FIFO_RD_CLK     => '0', -- [in]
         FIFO_RD_EN      => '0', -- [in]
         RST             => rst); -- [in]

   U_Gearbox : entity surf.Gearbox
      generic map (
         TPD_G                => TPD_G,
         SLAVE_WIDTH_G        => ISERDES_WIDTH_C,
         MASTER_WIDTH_G       => SERIALIZATION_FACTOR_G,
         MASTER_BIT_REVERSE_G => true)
      port map (
         clk         => wordClk, -- [in]
         rst         => rst, -- [in]
         slaveData   => rawData(ISERDES_WIDTH_C-1 downto 0), -- [in]
         slaveValid  => '1', -- [in]
         slaveReady  => open, -- [out]
         startOfSeq  => '0', -- [in]
         slip        => bitSlip, -- [in]
         masterData  => gearboxData, -- [out]
         masterValid => dataValid, -- [out]
         masterReady => '1'); -- [in]

   dataWord <= gearboxData;

end architecture rtl;
