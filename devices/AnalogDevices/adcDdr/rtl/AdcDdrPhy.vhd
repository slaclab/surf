-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Device-family selector for the serialized DDR ADC PHY
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
use surf.AdcDdrPkg.all;

entity AdcDdrPhy is
   generic (
      TPD_G                  : time                                    := 1 ns;
      DEVICE_FAMILY_G        : string                                  := "ULTRASCALE";
      DATA_LANES_G           : positive                                := 8;
      FCO_LANES_G            : positive                                := 1;
      SERIALIZATION_FACTOR_G : positive                                := 14;
      IODELAY_GROUP_G        : string                                  := "DEFAULT_GROUP";
      IDELAYCTRL_FREQ_G      : real                                    := 200.0;
      DATA_FCO_MAP_G         : NaturalArray(DATA_LANES_G-1 downto 0)   := (others => 0));
   port (
      adcClkRst     : in sl;
      idelayCtrlRdy : in sl := '1';
      phyReset      : in sl;
      dClkP         : in sl;
      dClkN         : in sl;
      fcoP          : in slv(FCO_LANES_G-1 downto 0);
      fcoN          : in slv(FCO_LANES_G-1 downto 0);
      dataP         : in slv(DATA_LANES_G-1 downto 0);
      dataN         : in slv(DATA_LANES_G-1 downto 0);

      bitSlip        : in slv(FCO_LANES_G-1 downto 0);
      dataDelayWrite : in AdcDdrDelayArray(DATA_LANES_G-1 downto 0);
      fcoDelayWrite  : in AdcDdrDelayArray(FCO_LANES_G-1 downto 0);

      captureClk : out sl;
      captureRst : out sl;
      delayReady : out sl;
      dataWord   : out Slv16Array(DATA_LANES_G-1 downto 0);
      dataValid  : out slv(DATA_LANES_G-1 downto 0);
      fcoWord    : out Slv16Array(FCO_LANES_G-1 downto 0);
      fcoValid   : out slv(FCO_LANES_G-1 downto 0));
end entity AdcDdrPhy;

architecture rtl of AdcDdrPhy is

   component AdcDdrPhy7Series is
      generic (
         TPD_G                  : time;
         DATA_LANES_G           : positive;
         FCO_LANES_G            : positive;
         SERIALIZATION_FACTOR_G : positive;
         IODELAY_GROUP_G        : string;
         IDELAYCTRL_FREQ_G      : real;
         DATA_FCO_MAP_G         : NaturalArray(DATA_LANES_G-1 downto 0));
      port (
         adcClkRst     : in sl;
         idelayCtrlRdy : in sl;
         phyReset      : in sl;
         dClkP         : in sl;
         dClkN         : in sl;
         fcoP          : in slv(FCO_LANES_G-1 downto 0);
         fcoN          : in slv(FCO_LANES_G-1 downto 0);
         dataP         : in slv(DATA_LANES_G-1 downto 0);
         dataN         : in slv(DATA_LANES_G-1 downto 0);
         bitSlip        : in slv(FCO_LANES_G-1 downto 0);
         dataDelayWrite : in AdcDdrDelayArray(DATA_LANES_G-1 downto 0);
         fcoDelayWrite  : in AdcDdrDelayArray(FCO_LANES_G-1 downto 0);
         captureClk     : out sl;
         captureRst     : out sl;
         delayReady     : out sl;
         dataWord       : out Slv16Array(DATA_LANES_G-1 downto 0);
         dataValid      : out slv(DATA_LANES_G-1 downto 0);
         fcoWord        : out Slv16Array(FCO_LANES_G-1 downto 0);
         fcoValid       : out slv(FCO_LANES_G-1 downto 0));
   end component AdcDdrPhy7Series;

   component AdcDdrPhyUltraScale is
      generic (
         TPD_G                  : time;
         DEVICE_FAMILY_G        : string;
         DATA_LANES_G           : positive;
         FCO_LANES_G            : positive;
         SERIALIZATION_FACTOR_G : positive;
         IODELAY_GROUP_G        : string;
         DATA_FCO_MAP_G         : NaturalArray(DATA_LANES_G-1 downto 0));
      port (
         adcClkRst : in sl;
         phyReset  : in sl;
         dClkP     : in sl;
         dClkN     : in sl;
         fcoP      : in slv(FCO_LANES_G-1 downto 0);
         fcoN      : in slv(FCO_LANES_G-1 downto 0);
         dataP     : in slv(DATA_LANES_G-1 downto 0);
         dataN     : in slv(DATA_LANES_G-1 downto 0);
         bitSlip        : in slv(FCO_LANES_G-1 downto 0);
         dataDelayWrite : in AdcDdrDelayArray(DATA_LANES_G-1 downto 0);
         fcoDelayWrite  : in AdcDdrDelayArray(FCO_LANES_G-1 downto 0);
         captureClk     : out sl;
         captureRst     : out sl;
         delayReady     : out sl;
         dataWord       : out Slv16Array(DATA_LANES_G-1 downto 0);
         dataValid      : out slv(DATA_LANES_G-1 downto 0);
         fcoWord        : out Slv16Array(FCO_LANES_G-1 downto 0);
         fcoValid       : out slv(FCO_LANES_G-1 downto 0));
   end component AdcDdrPhyUltraScale;

   constant ULTRASCALE_C : boolean :=
      DEVICE_FAMILY_G = "ULTRASCALE" or DEVICE_FAMILY_G = "ULTRASCALE_PLUS";

begin

   assert DEVICE_FAMILY_G = "7SERIES" or ULTRASCALE_C
      report "AdcDdrPhy DEVICE_FAMILY_G must be 7SERIES, ULTRASCALE, or ULTRASCALE_PLUS"
      severity failure;

   GEN_7SERIES : if DEVICE_FAMILY_G = "7SERIES" generate
      U_Phy : AdcDdrPhy7Series
         generic map (
            TPD_G                  => TPD_G,
            DATA_LANES_G           => DATA_LANES_G,
            FCO_LANES_G            => FCO_LANES_G,
            SERIALIZATION_FACTOR_G => SERIALIZATION_FACTOR_G,
            IODELAY_GROUP_G        => IODELAY_GROUP_G,
            IDELAYCTRL_FREQ_G      => IDELAYCTRL_FREQ_G,
            DATA_FCO_MAP_G         => DATA_FCO_MAP_G)
         port map (
            adcClkRst     => adcClkRst, -- [in]
            idelayCtrlRdy => idelayCtrlRdy, -- [in]
            phyReset      => phyReset, -- [in]
            dClkP         => dClkP, -- [in]
            dClkN         => dClkN, -- [in]
            fcoP          => fcoP, -- [in]
            fcoN          => fcoN, -- [in]
            dataP         => dataP, -- [in]
            dataN         => dataN, -- [in]
            bitSlip        => bitSlip, -- [in]
            dataDelayWrite => dataDelayWrite, -- [in]
            fcoDelayWrite  => fcoDelayWrite, -- [in]
            captureClk     => captureClk, -- [out]
            captureRst     => captureRst, -- [out]
            delayReady     => delayReady, -- [out]
            dataWord       => dataWord, -- [out]
            dataValid      => dataValid, -- [out]
            fcoWord        => fcoWord, -- [out]
            fcoValid       => fcoValid); -- [out]
   end generate GEN_7SERIES;

   GEN_ULTRASCALE : if ULTRASCALE_C generate
      U_Phy : AdcDdrPhyUltraScale
         generic map (
            TPD_G                  => TPD_G,
            DEVICE_FAMILY_G        => DEVICE_FAMILY_G,
            DATA_LANES_G           => DATA_LANES_G,
            FCO_LANES_G            => FCO_LANES_G,
            SERIALIZATION_FACTOR_G => SERIALIZATION_FACTOR_G,
            IODELAY_GROUP_G        => IODELAY_GROUP_G,
            DATA_FCO_MAP_G         => DATA_FCO_MAP_G)
         port map (
            adcClkRst     => adcClkRst, -- [in]
            phyReset      => phyReset, -- [in]
            dClkP         => dClkP, -- [in]
            dClkN         => dClkN, -- [in]
            fcoP          => fcoP, -- [in]
            fcoN          => fcoN, -- [in]
            dataP         => dataP, -- [in]
            dataN         => dataN, -- [in]
            bitSlip        => bitSlip, -- [in]
            dataDelayWrite => dataDelayWrite, -- [in]
            fcoDelayWrite  => fcoDelayWrite, -- [in]
            captureClk     => captureClk, -- [out]
            captureRst     => captureRst, -- [out]
            delayReady     => delayReady, -- [out]
            dataWord       => dataWord, -- [out]
            dataValid      => dataValid, -- [out]
            fcoWord        => fcoWord, -- [out]
            fcoValid       => fcoValid); -- [out]
   end generate GEN_ULTRASCALE;

end architecture rtl;
