-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Readout for one eight-channel AD9249 output bank
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
use surf.AdcDdrPkg.all;

entity Ad9249ReadoutBank is
   generic (
      TPD_G             : time                                      := 1 ns;
      AXIL_BASE_ADDR_G  : slv(31 downto 0)                          := (others => '0');
      NUM_CHANNELS_G    : natural range 1 to 8                      := 8;
      DEVICE_FAMILY_G   : string                                    := "ULTRASCALE";
      IODELAY_GROUP_G   : string                                    := "DEFAULT_GROUP";
      IDELAYCTRL_FREQ_G : real                                      := 200.0;
      DATA_DELAY_INIT_G : NaturalArray(NUM_CHANNELS_G-1 downto 0)   := (others => 0);
      FCO_DELAY_INIT_G  : NaturalArray(0 downto 0)                  := (others => 0);
      ADC_INVERT_CH_G   : slv(7 downto 0)                           := (others => '0');
      PATTERN_CHECK_G   : boolean                                   := true;
      OFFSET_BINARY_G   : boolean                                   := false;
      NEGATE_G          : boolean                                   := false);
   port (
      axilClk         : in  sl;
      axilRst         : in  sl;
      axilWriteMaster : in  AxiLiteWriteMasterType;
      axilWriteSlave  : out AxiLiteWriteSlaveType;
      axilReadMaster  : in  AxiLiteReadMasterType;
      axilReadSlave   : out AxiLiteReadSlaveType;

      adcClkRst     : in sl;
      idelayCtrlRdy : in sl := '0';
      adcSerial     : in Ad9249SerialGroupType;

      adcStreamClk : in  sl;
      adcStreamRst : in  sl;
      adcStreams   : out AxiStreamMasterArray(NUM_CHANNELS_G-1 downto 0));
end entity Ad9249ReadoutBank;

architecture rtl of Ad9249ReadoutBank is

   constant FRAME_PATTERN_C : slv(13 downto 0) := "11111110000000";
   constant DELAY_BITS_C     : positive         := adcDdrDelayBits(DEVICE_FAMILY_G);

   signal adcWordClk : sl;
   signal adcWordRst : sl;
   signal phyReset   : sl;
   signal delayReady : sl;

   signal dataWord : Slv16Array(NUM_CHANNELS_G-1 downto 0);
   signal dataValid : slv(NUM_CHANNELS_G-1 downto 0);
   signal sampleIn : Slv16Array(NUM_CHANNELS_G-1 downto 0);
   signal fcoWord  : Slv16Array(0 downto 0);
   signal fcoValid : slv(0 downto 0);

   signal bitSlip       : slv(0 downto 0);
   signal dataDelay     : AdcDdrDelayArray(NUM_CHANNELS_G-1 downto 0);
   signal frameDelay    : AdcDdrDelayArray(0 downto 0);

begin

   U_Phy : entity surf.AdcDdrPhy
      generic map (
         TPD_G                  => TPD_G,
         DEVICE_FAMILY_G        => DEVICE_FAMILY_G,
         DATA_LANES_G           => NUM_CHANNELS_G,
         FCO_LANES_G            => 1,
         SERIALIZATION_FACTOR_G => 14,
         IODELAY_GROUP_G        => IODELAY_GROUP_G,
         IDELAYCTRL_FREQ_G      => IDELAYCTRL_FREQ_G,
         -- Ranged-choice (not "others =>") avoids a VCS elaborator segfault when
         -- driving a generic-sized NaturalArray generic (DATA_LANES_G-1 downto 0).
         DATA_FCO_MAP_G         => (NUM_CHANNELS_G-1 downto 0 => 0))
      port map (
         adcClkRst     => adcClkRst, -- [in]
         idelayCtrlRdy => idelayCtrlRdy, -- [in]
         phyReset      => phyReset, -- [in]
         dClkP         => adcSerial.dClkP, -- [in]
         dClkN         => adcSerial.dClkN, -- [in]
         fcoP           => (0 => adcSerial.fClkP), -- [in]
         fcoN           => (0 => adcSerial.fClkN), -- [in]
         dataP          => adcSerial.chP(NUM_CHANNELS_G-1 downto 0), -- [in]
         dataN          => adcSerial.chN(NUM_CHANNELS_G-1 downto 0), -- [in]
         bitSlip        => bitSlip, -- [in]
         dataDelayWrite => dataDelay, -- [in]
         fcoDelayWrite  => frameDelay, -- [in]
         captureClk     => adcWordClk, -- [out]
         captureRst     => adcWordRst, -- [out]
         delayReady     => delayReady, -- [out]
         dataWord       => dataWord, -- [out]
         dataValid      => dataValid, -- [out]
         fcoWord        => fcoWord, -- [out]
         fcoValid       => fcoValid); -- [out]

   GEN_CHANNEL : for i in NUM_CHANNELS_G-1 downto 0 generate
      sampleIn(i) <= "00" & ite(ADC_INVERT_CH_G(i) = '1',
                                 not dataWord(i)(13 downto 0), dataWord(i)(13 downto 0));
   end generate GEN_CHANNEL;

   U_Core : entity surf.AdcDdrCore
      generic map (
         TPD_G                  => TPD_G,
         AXIL_BASE_ADDR_G       => AXIL_BASE_ADDR_G,
         DATA_LANES_G           => NUM_CHANNELS_G,
         FCO_LANES_G            => 1,
         CHANNELS_G             => NUM_CHANNELS_G,
         SAMPLE_WIDTH_G         => 14,
         SERIALIZATION_FACTOR_G => 14,
         DELAY_BITS_G           => DELAY_BITS_C,
         DATA_DELAY_INIT_G      => DATA_DELAY_INIT_G,
         FCO_DELAY_INIT_G       => FCO_DELAY_INIT_G,
         FRAME_PATTERN_G        => FRAME_PATTERN_C,
         PATTERN_CHECK_G        => PATTERN_CHECK_G,
         OFFSET_BINARY_G        => OFFSET_BINARY_G,
         NEGATE_G               => NEGATE_G)
      port map (
         axilClk         => axilClk, -- [in]
         axilRst         => axilRst, -- [in]
         axilReadMaster  => axilReadMaster, -- [in]
         axilReadSlave   => axilReadSlave, -- [out]
         axilWriteMaster => axilWriteMaster, -- [in]
         axilWriteSlave  => axilWriteSlave, -- [out]
         captureClk      => adcWordClk, -- [in]
         captureRst      => adcWordRst, -- [in]
         delayReady      => delayReady, -- [in]
         fcoWord         => fcoWord, -- [in]
         fcoValid        => fcoValid, -- [in]
         sampleValid     => uAnd(dataValid), -- [in]
         sampleIn        => sampleIn, -- [in]
         phyReset        => phyReset, -- [out]
         bitSlip         => bitSlip, -- [out]
         dataDelayWrite  => dataDelay, -- [out]
         fcoDelayWrite   => frameDelay, -- [out]
         streamClk       => adcStreamClk, -- [in]
         streamRst       => adcStreamRst, -- [in]
         streams         => adcStreams); -- [out]

end architecture rtl;
