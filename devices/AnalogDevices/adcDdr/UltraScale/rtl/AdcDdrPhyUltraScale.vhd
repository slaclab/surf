-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Serialized DDR ADC physical input for AMD UltraScale FPGAs
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

library unisim;
use unisim.vcomponents.all;

entity AdcDdrPhyUltraScale is
   generic (
      TPD_G                  : time                                    := 1 ns;
      DEVICE_FAMILY_G        : string                                  := "ULTRASCALE";
      DATA_LANES_G           : positive                                := 8;
      FCO_LANES_G            : positive                                := 1;
      SERIALIZATION_FACTOR_G : positive                                := 14;
      IODELAY_GROUP_G        : string                                  := "DEFAULT_GROUP";
      DATA_FCO_MAP_G         : NaturalArray(DATA_LANES_G-1 downto 0)   := (others => 0));
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

      captureClk : out sl;
      captureRst : out sl;
      delayReady : out sl;
      dataWord   : out Slv16Array(DATA_LANES_G-1 downto 0);
      dataValid  : out slv(DATA_LANES_G-1 downto 0);
      fcoWord    : out Slv16Array(FCO_LANES_G-1 downto 0);
      fcoValid   : out slv(FCO_LANES_G-1 downto 0));
end entity AdcDdrPhyUltraScale;

architecture rtl of AdcDdrPhyUltraScale is

   constant ISERDES_WIDTH_C : positive := ite(SERIALIZATION_FACTOR_G <= 6, 4, 8);

   signal bitClk     : sl;
   signal bitClkInv  : sl;
   signal wordClk    : sl;
   signal wordRst    : sl;
   signal deserReset : sl;
   signal fcoPad     : slv(FCO_LANES_G-1 downto 0);
   signal dataPad    : slv(DATA_LANES_G-1 downto 0);

begin

   assert DEVICE_FAMILY_G = "ULTRASCALE" or DEVICE_FAMILY_G = "ULTRASCALE_PLUS"
      report "AdcDdrPhyUltraScale DEVICE_FAMILY_G must be ULTRASCALE or ULTRASCALE_PLUS"
      severity failure;

   assert SERIALIZATION_FACTOR_G = 4 or SERIALIZATION_FACTOR_G = 6 or
          SERIALIZATION_FACTOR_G = 8 or SERIALIZATION_FACTOR_G = 10 or
          SERIALIZATION_FACTOR_G = 12 or SERIALIZATION_FACTOR_G = 14
      report "AdcDdrPhyUltraScale supports only DDR widths 4, 6, 8, 10, 12, and 14"
      severity failure;

   GEN_MAP_CHECK : for i in DATA_LANES_G-1 downto 0 generate
      assert DATA_FCO_MAP_G(i) < FCO_LANES_G
         report "AdcDdrPhyUltraScale data-to-FCO mapping index is out of range"
         severity failure;
   end generate GEN_MAP_CHECK;

   U_DcoInput : IBUFGDS
      port map (
         I  => dClkP, -- [in]
         IB => dClkN, -- [in]
         O  => bitClk); -- [out]

   bitClkInv <= not bitClk;

   U_WordClock : BUFGCE_DIV
      generic map (
         BUFGCE_DIVIDE   => ISERDES_WIDTH_C/2,
         IS_CE_INVERTED  => '0',
         IS_CLR_INVERTED => '0',
         IS_I_INVERTED   => '0')
      port map (
         I   => bitClk, -- [in]
         O   => wordClk, -- [out]
         CE  => '1', -- [in]
         CLR => '0'); -- [in]

   U_WordReset : entity surf.RstSync
      generic map (
         TPD_G           => TPD_G,
         RELEASE_DELAY_G => 5)
      port map (
         clk      => wordClk, -- [in]
         asyncRst => adcClkRst, -- [in]
         syncRst  => wordRst); -- [out]

   deserReset <= wordRst or phyReset;

   GEN_FCO : for i in FCO_LANES_G-1 downto 0 generate
   begin
      U_Input : IBUFDS
         port map (
            I  => fcoP(i), -- [in]
            IB => fcoN(i), -- [in]
            O  => fcoPad(i)); -- [out]

      U_Deserializer : entity surf.AdcDdrDeserializerUltraScale
         generic map (
            TPD_G                  => TPD_G,
            DEVICE_FAMILY_G        => DEVICE_FAMILY_G,
            IODELAY_GROUP_G        => IODELAY_GROUP_G,
            SERIALIZATION_FACTOR_G => SERIALIZATION_FACTOR_G)
         port map (
            bitClk     => bitClk, -- [in]
            bitClkInv  => bitClkInv, -- [in]
            wordClk    => wordClk, -- [in]
            rst        => deserReset, -- [in]
            bitSlip    => bitSlip(i), -- [in]
            delayClk   => wordClk, -- [in]
            delayValue => fcoDelayWrite(i).value, -- [in]
            delayLoad  => fcoDelayWrite(i).load, -- [in]
            serialData => fcoPad(i), -- [in]
            dataWord   => fcoWord(i)(SERIALIZATION_FACTOR_G-1 downto 0), -- [out]
            dataValid  => fcoValid(i)); -- [out]

      fcoWord(i)(15 downto SERIALIZATION_FACTOR_G) <= (others => '0');
   end generate GEN_FCO;

   GEN_DATA : for i in DATA_LANES_G-1 downto 0 generate
   begin
      U_Input : IBUFDS
         port map (
            I  => dataP(i), -- [in]
            IB => dataN(i), -- [in]
            O  => dataPad(i)); -- [out]

      U_Deserializer : entity surf.AdcDdrDeserializerUltraScale
         generic map (
            TPD_G                  => TPD_G,
            DEVICE_FAMILY_G        => DEVICE_FAMILY_G,
            IODELAY_GROUP_G        => IODELAY_GROUP_G,
            SERIALIZATION_FACTOR_G => SERIALIZATION_FACTOR_G)
         port map (
            bitClk     => bitClk, -- [in]
            bitClkInv  => bitClkInv, -- [in]
            wordClk    => wordClk, -- [in]
            rst        => deserReset, -- [in]
            bitSlip    => bitSlip(DATA_FCO_MAP_G(i)), -- [in]
            delayClk   => wordClk, -- [in]
            delayValue => dataDelayWrite(i).value, -- [in]
            delayLoad  => dataDelayWrite(i).load, -- [in]
            serialData => dataPad(i), -- [in]
            dataWord   => dataWord(i)(SERIALIZATION_FACTOR_G-1 downto 0), -- [out]
            dataValid  => dataValid(i)); -- [out]

      dataWord(i)(15 downto SERIALIZATION_FACTOR_G) <= (others => '0');
   end generate GEN_DATA;

   captureClk <= wordClk;
   captureRst <= wordRst;
   delayReady <= not wordRst;

end architecture rtl;
