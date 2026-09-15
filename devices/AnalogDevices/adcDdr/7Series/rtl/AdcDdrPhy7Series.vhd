-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Serialized DDR ADC physical input for AMD 7 Series FPGAs
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

entity AdcDdrPhy7Series is
   generic (
      TPD_G                  : time                                    := 1 ns;
      DATA_LANES_G           : positive                                := 8;
      FCO_LANES_G            : positive                                := 1;
      SERIALIZATION_FACTOR_G : positive                                := 14;
      IODELAY_GROUP_G        : string                                  := "DEFAULT_GROUP";
      IDELAYCTRL_FREQ_G      : real                                    := 200.0;
      DATA_FCO_MAP_G         : NaturalArray(DATA_LANES_G-1 downto 0)   := (others => 0));
   port (
      adcClkRst     : in sl;
      idelayCtrlRdy : in sl := '0';
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
end entity AdcDdrPhy7Series;

architecture rtl of AdcDdrPhy7Series is

   function bufrDivide (value : positive) return string is
   begin
      case value is
         when 1      => return "1";
         when 2      => return "2";
         when 3      => return "3";
         when 4      => return "4";
         when 5      => return "5";
         when 6      => return "6";
         when 7      => return "7";
         when others => return "8";
      end case;
   end function bufrDivide;

   signal dClkPad    : sl;
   signal bitClk     : sl;
   signal bitClkInv  : sl;
   signal wordClk    : sl;
   signal wordRst    : sl;
   signal deserReset : sl;
   signal fcoPad     : slv(FCO_LANES_G-1 downto 0);
   signal dataPad    : slv(DATA_LANES_G-1 downto 0);

begin

   assert SERIALIZATION_FACTOR_G = 4 or SERIALIZATION_FACTOR_G = 6 or
          SERIALIZATION_FACTOR_G = 8 or SERIALIZATION_FACTOR_G = 10 or
          SERIALIZATION_FACTOR_G = 14
      report "AdcDdrPhy7Series supports only native DDR widths 4, 6, 8, 10, and 14"
      severity failure;

   GEN_MAP_CHECK : for i in DATA_LANES_G-1 downto 0 generate
      assert DATA_FCO_MAP_G(i) < FCO_LANES_G
         report "AdcDdrPhy7Series data-to-FCO mapping index is out of range"
         severity failure;
   end generate GEN_MAP_CHECK;

   U_DelayReadySync : entity surf.Synchronizer
      generic map (
         TPD_G => TPD_G)
      port map (
         clk     => wordClk, -- [in]
         rst     => wordRst, -- [in]
         dataIn  => idelayCtrlRdy, -- [in]
         dataOut => delayReady); -- [out]

   U_DcoInput : IBUFDS
      generic map (
         DIFF_TERM  => true,
         IOSTANDARD => "LVDS_25")
      port map (
         I  => dClkP, -- [in]
         IB => dClkN, -- [in]
         O  => dClkPad); -- [out]

   U_BitClock : BUFIO
      port map (
         I => dClkPad, -- [in]
         O => bitClk); -- [out]

   bitClkInv <= not bitClk;

   U_WordClock : BUFR
      generic map (
         SIM_DEVICE  => "7SERIES",
         BUFR_DIVIDE => bufrDivide(SERIALIZATION_FACTOR_G/2))
      port map (
         I   => dClkPad, -- [in]
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

   -- The common PHY command carries the widest supported nine-bit value. Fail
   -- on an invalid 7-Series load instead of silently discarding its upper bits.
   GEN_FCO : for i in FCO_LANES_G-1 downto 0 generate
   begin
      assert fcoDelayWrite(i).load /= '1' or fcoDelayWrite(i).value(8 downto 5) = X"0"
         report "AdcDdrPhy7Series FCO delay value exceeds the native five-bit range; " &
                "the value will be truncated"
         severity warning;

      U_Input : IBUFDS
         generic map (
            DIFF_TERM => true)
         port map (
            I  => fcoP(i), -- [in]
            IB => fcoN(i), -- [in]
            O  => fcoPad(i)); -- [out]

      U_Deserializer : entity surf.AdcDdrDeserializer7Series
         generic map (
            IODELAY_GROUP_G        => IODELAY_GROUP_G,
            IDELAYCTRL_FREQ_G      => IDELAYCTRL_FREQ_G,
            SERIALIZATION_FACTOR_G => SERIALIZATION_FACTOR_G)
         port map (
            bitClk    => bitClk, -- [in]
            bitClkInv => bitClkInv, -- [in]
            wordClk   => wordClk, -- [in]
            rst       => deserReset, -- [in]
            bitSlip   => bitSlip(i), -- [in]
            delayClk  => wordClk, -- [in]
            delayValue => fcoDelayWrite(i).value(4 downto 0), -- [in]
            delayLoad => fcoDelayWrite(i).load, -- [in]
            serialData => fcoPad(i), -- [in]
            dataWord   => fcoWord(i)(SERIALIZATION_FACTOR_G-1 downto 0)); -- [out]

      fcoWord(i)(15 downto SERIALIZATION_FACTOR_G) <= (others => '0');
   end generate GEN_FCO;

   GEN_DATA : for i in DATA_LANES_G-1 downto 0 generate
   begin
      assert dataDelayWrite(i).load /= '1' or dataDelayWrite(i).value(8 downto 5) = X"0"
         report "AdcDdrPhy7Series data delay value exceeds the native five-bit range; " &
                "the value will be truncated"
         severity warning;

      U_Input : IBUFDS
         generic map (
            DIFF_TERM => true)
         port map (
            I  => dataP(i), -- [in]
            IB => dataN(i), -- [in]
            O  => dataPad(i)); -- [out]

      U_Deserializer : entity surf.AdcDdrDeserializer7Series
         generic map (
            IODELAY_GROUP_G        => IODELAY_GROUP_G,
            IDELAYCTRL_FREQ_G      => IDELAYCTRL_FREQ_G,
            SERIALIZATION_FACTOR_G => SERIALIZATION_FACTOR_G)
         port map (
            bitClk     => bitClk, -- [in]
            bitClkInv  => bitClkInv, -- [in]
            wordClk    => wordClk, -- [in]
            rst        => deserReset, -- [in]
            bitSlip    => bitSlip(DATA_FCO_MAP_G(i)), -- [in]
            delayClk   => wordClk, -- [in]
            delayValue => dataDelayWrite(i).value(4 downto 0), -- [in]
            delayLoad  => dataDelayWrite(i).load, -- [in]
            serialData => dataPad(i), -- [in]
            dataWord   => dataWord(i)(SERIALIZATION_FACTOR_G-1 downto 0)); -- [out]

      dataWord(i)(15 downto SERIALIZATION_FACTOR_G) <= (others => '0');
   end generate GEN_DATA;

   captureClk <= wordClk;
   captureRst <= wordRst;
   dataValid  <= (others => not deserReset);
   fcoValid   <= (others => not deserReset);

end architecture rtl;
