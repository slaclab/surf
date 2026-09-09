-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Full-device AD9249 serialized readout
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
use surf.AxiLitePkg.all;
use surf.AxiStreamPkg.all;
use surf.Ad9249Pkg.all;

entity Ad9249Readout is
   generic (
      TPD_G               : time                       := 1 ns;
      AXIL_BASE_ADDR_G    : slv(31 downto 0)           := (others => '0');
      IODELAY_GROUP_0_G   : string                     := "DEFAULT_GROUP_0";
      IODELAY_GROUP_1_G   : string                     := "DEFAULT_GROUP_1";
      IDELAYCTRL_FREQ_G   : real                       := 200.0;
      DEVICE_FAMILY_G     : string                     := "ULTRASCALE";
      DATA_DELAY_INIT_G   : NaturalArray(15 downto 0)  := (others => 0);
      FCO_DELAY_INIT_G    : NaturalArray(1 downto 0)   := (others => 0);
      ADC_INVERT_CH_G     : slv(15 downto 0)           := (others => '0');
      PATTERN_CHECK_G     : boolean                    := true;
      OFFSET_BINARY_G     : boolean                    := false;
      NEGATE_G            : boolean                    := false);
   port (
      axilClk         : in  sl;
      axilRst         : in  sl;
      axilWriteMaster : in  AxiLiteWriteMasterType;
      axilWriteSlave  : out AxiLiteWriteSlaveType;
      axilReadMaster  : in  AxiLiteReadMasterType;
      axilReadSlave   : out AxiLiteReadSlaveType;

      adcClkRst     : in sl;
      idelayCtrlRdy : in slv(1 downto 0) := (others => '0');
      adcSerial     : in Ad9249SerialGroupArray(1 downto 0);

      adcStreamClk : in  sl;
      adcStreamRst : in  sl;
      adcStreams   : out AxiStreamMasterArray(15 downto 0));
end entity Ad9249Readout;

architecture rtl of Ad9249Readout is

   constant AXIL_CONFIG_C : AxiLiteCrossbarMasterConfigArray(1 downto 0) :=
      genAxiLiteConfig(2, AXIL_BASE_ADDR_G, 13, 12);

   function bankDataDelay (
      values : NaturalArray;
      bank   : natural)
      return NaturalArray is
      variable result : NaturalArray(7 downto 0);
   begin
      for ch in 7 downto 0 loop
         result(ch) := values((8*bank)+ch);
      end loop;
      return result;
   end function bankDataDelay;

   function bankFcoDelay (
      values : NaturalArray;
      bank   : natural)
      return NaturalArray is
      variable result : NaturalArray(0 downto 0);
   begin
      result(0) := values(bank);
      return result;
   end function bankFcoDelay;

   function bankInvert (values : slv; bank : natural) return slv is
      variable result : slv(7 downto 0);
   begin
      for ch in 7 downto 0 loop
         result(ch) := values((8*bank)+ch);
      end loop;
      return result;
   end function bankInvert;

   signal bankWriteMasters : AxiLiteWriteMasterArray(1 downto 0);
   signal bankWriteSlaves  : AxiLiteWriteSlaveArray(1 downto 0);
   signal bankReadMasters  : AxiLiteReadMasterArray(1 downto 0);
   signal bankReadSlaves   : AxiLiteReadSlaveArray(1 downto 0);
   signal bank0Streams     : AxiStreamMasterArray(7 downto 0);
   signal bank1Streams     : AxiStreamMasterArray(7 downto 0);

begin

   -------------------------------------------------------------------------------------------------
   -- Decode one 8-KiB device window into independent 4-KiB bank register
   -- regions. Each bank keeps its own DCO/FCO capture domain and AdcDdrCore.
   -------------------------------------------------------------------------------------------------
   U_AxiLiteCrossbar : entity surf.AxiLiteCrossbar
      generic map (
         TPD_G              => TPD_G,
         NUM_SLAVE_SLOTS_G  => 1,
         NUM_MASTER_SLOTS_G => 2,
         MASTERS_CONFIG_G   => AXIL_CONFIG_C)
      port map (
         axiClk              => axilClk, -- [in]
         axiClkRst           => axilRst, -- [in]
         sAxiWriteMasters(0) => axilWriteMaster, -- [in]
         sAxiWriteSlaves(0)  => axilWriteSlave, -- [out]
         sAxiReadMasters(0)  => axilReadMaster, -- [in]
         sAxiReadSlaves(0)   => axilReadSlave, -- [out]
         mAxiWriteMasters    => bankWriteMasters, -- [out]
         mAxiWriteSlaves     => bankWriteSlaves, -- [in]
         mAxiReadMasters     => bankReadMasters, -- [out]
         mAxiReadSlaves      => bankReadSlaves); -- [in]

   U_Bank0 : entity surf.Ad9249ReadoutBank
      generic map (
         TPD_G             => TPD_G,
         AXIL_BASE_ADDR_G  => AXIL_CONFIG_C(0).baseAddr,
         NUM_CHANNELS_G    => 8,
         DEVICE_FAMILY_G   => DEVICE_FAMILY_G,
         IODELAY_GROUP_G   => IODELAY_GROUP_0_G,
         IDELAYCTRL_FREQ_G => IDELAYCTRL_FREQ_G,
         DATA_DELAY_INIT_G => bankDataDelay(DATA_DELAY_INIT_G, 0),
         FCO_DELAY_INIT_G  => bankFcoDelay(FCO_DELAY_INIT_G, 0),
         ADC_INVERT_CH_G   => bankInvert(ADC_INVERT_CH_G, 0),
         PATTERN_CHECK_G   => PATTERN_CHECK_G,
         OFFSET_BINARY_G   => OFFSET_BINARY_G,
         NEGATE_G          => NEGATE_G)
      port map (
         axilClk         => axilClk, -- [in]
         axilRst         => axilRst, -- [in]
         axilWriteMaster => bankWriteMasters(0), -- [in]
         axilWriteSlave  => bankWriteSlaves(0), -- [out]
         axilReadMaster  => bankReadMasters(0), -- [in]
         axilReadSlave   => bankReadSlaves(0), -- [out]
         adcClkRst       => adcClkRst, -- [in]
         idelayCtrlRdy   => idelayCtrlRdy(0), -- [in]
         adcSerial       => adcSerial(0), -- [in]
         adcStreamClk    => adcStreamClk, -- [in]
         adcStreamRst    => adcStreamRst, -- [in]
         adcStreams      => bank0Streams); -- [out]

   U_Bank1 : entity surf.Ad9249ReadoutBank
      generic map (
         TPD_G             => TPD_G,
         AXIL_BASE_ADDR_G  => AXIL_CONFIG_C(1).baseAddr,
         NUM_CHANNELS_G    => 8,
         DEVICE_FAMILY_G   => DEVICE_FAMILY_G,
         IODELAY_GROUP_G   => IODELAY_GROUP_1_G,
         IDELAYCTRL_FREQ_G => IDELAYCTRL_FREQ_G,
         DATA_DELAY_INIT_G => bankDataDelay(DATA_DELAY_INIT_G, 1),
         FCO_DELAY_INIT_G  => bankFcoDelay(FCO_DELAY_INIT_G, 1),
         ADC_INVERT_CH_G   => bankInvert(ADC_INVERT_CH_G, 1),
         PATTERN_CHECK_G   => PATTERN_CHECK_G,
         OFFSET_BINARY_G   => OFFSET_BINARY_G,
         NEGATE_G          => NEGATE_G)
      port map (
         axilClk         => axilClk, -- [in]
         axilRst         => axilRst, -- [in]
         axilWriteMaster => bankWriteMasters(1), -- [in]
         axilWriteSlave  => bankWriteSlaves(1), -- [out]
         axilReadMaster  => bankReadMasters(1), -- [in]
         axilReadSlave   => bankReadSlaves(1), -- [out]
         adcClkRst       => adcClkRst, -- [in]
         idelayCtrlRdy   => idelayCtrlRdy(1), -- [in]
         adcSerial       => adcSerial(1), -- [in]
         adcStreamClk    => adcStreamClk, -- [in]
         adcStreamRst    => adcStreamRst, -- [in]
         adcStreams      => bank1Streams); -- [out]

   mapStreams : process (bank0Streams, bank1Streams) is
      variable v : AxiStreamMasterArray(15 downto 0);
   begin
      for ch in 7 downto 0 loop
         v(ch)         := bank0Streams(ch);
         v(ch).tDest   := toSlv(ch, 8);
         v(8+ch)       := bank1Streams(ch);
         v(8+ch).tDest := toSlv(8+ch, 8);
      end loop;
      adcStreams <= v;
   end process mapStreams;

end architecture rtl;
