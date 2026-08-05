-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: AD9681 serialized readout
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
use surf.Ad9681Pkg.all;
use surf.AdcDdrPkg.all;

entity Ad9681Readout is
   generic (
      TPD_G              : time                                  := 1 ns;
      AXIL_BASE_ADDR_G   : slv(31 downto 0)                      := (others => '0');
      IODELAY_GROUP_G    : string                                := "DEFAULT_GROUP";
      IDELAYCTRL_FREQ_G  : real                                  := 200.0;
      DEVICE_FAMILY_G    : string                                := "ULTRASCALE";
      CAPTURE_DCLK_IDX_G : natural range 0 to 1                  := 0;
      DATA_DELAY_INIT_G  : NaturalArray(15 downto 0)             := (others => 0);
      FCO_DELAY_INIT_G   : NaturalArray(1 downto 0)              := (others => 0);
      ADC_INVERT_CH_G    : Slv8Array(1 downto 0)                 := (others => (others => '0'));
      PATTERN_CHECK_G    : boolean                               := true;
      OFFSET_BINARY_G    : boolean                               := false;
      NEGATE_G           : boolean                               := false;
      LEFT_JUSTIFY_G     : boolean                               := true);
   port (
      axilClk         : in  sl;
      axilRst         : in  sl;
      axilWriteMaster : in  AxiLiteWriteMasterType;
      axilWriteSlave  : out AxiLiteWriteSlaveType;
      axilReadMaster  : in  AxiLiteReadMasterType;
      axilReadSlave   : out AxiLiteReadSlaveType;

      adcClkRst     : in sl;
      idelayCtrlRdy : in sl := '1';
      adcSerial     : in Ad9681SerialType;

      adcStreamClk : in  sl;
      adcStreamRst : in  sl;
      adcStreams   : out AxiStreamMasterArray(7 downto 0));
end entity Ad9681Readout;

architecture rtl of Ad9681Readout is

   constant FRAME_PATTERN_C : slv(7 downto 0) := "11110000";
   constant DELAY_BITS_C     : positive        := adcDdrDelayBits(DEVICE_FAMILY_G);
   constant DATA_FCO_MAP_C  : NaturalArray(15 downto 0) := (
      15 downto 8 => 1,
      7 downto 0  => 0);

   signal adcWordClk : sl;
   signal adcWordRst : sl;
   signal phyReset   : sl;
   signal delayReady : sl;

   signal dataP    : slv(15 downto 0);
   signal dataN    : slv(15 downto 0);
   signal dataWord : Slv16Array(15 downto 0);
   signal dataValid : slv(15 downto 0);
   signal sampleIn : Slv16Array(7 downto 0);
   signal fcoWord  : Slv16Array(1 downto 0);
   signal fcoValid : slv(1 downto 0);

   signal bitSlip      : slv(1 downto 0);
   signal dataDelay    : AdcDdrDelayArray(15 downto 0);
   signal frameDelay   : AdcDdrDelayArray(1 downto 0);

   -- Right-justified [13:0] streams as produced by AdcDdrCore.
   signal coreStreams  : AxiStreamMasterArray(7 downto 0);

begin

   -------------------------------------------------------------------------------------------------
   -- Capture both serialized halves with one selected DCLK. The two DCLKs are
   -- related ADC outputs, but combining their FPGA clock domains would make
   -- sample coherence depend on an implicit inter-clock relationship.
   -------------------------------------------------------------------------------------------------
   GEN_HALF : for i in 1 downto 0 generate
      GEN_CHANNEL : for ch in 7 downto 0 generate
         constant LANE_C : natural := (8*i)+ch;
      begin
         dataP(LANE_C) <= adcSerial.chP(i)(ch);
         dataN(LANE_C) <= adcSerial.chN(i)(ch);
      end generate GEN_CHANNEL;
   end generate GEN_HALF;

   U_Phy : entity surf.AdcDdrPhy
      generic map (
         TPD_G                  => TPD_G,
         DEVICE_FAMILY_G        => DEVICE_FAMILY_G,
         DATA_LANES_G           => 16,
         FCO_LANES_G            => 2,
         SERIALIZATION_FACTOR_G => 8,
         IODELAY_GROUP_G        => IODELAY_GROUP_G,
         IDELAYCTRL_FREQ_G      => IDELAYCTRL_FREQ_G,
         DATA_FCO_MAP_G         => DATA_FCO_MAP_C)
      port map (
         adcClkRst     => adcClkRst, -- [in]
         idelayCtrlRdy => idelayCtrlRdy, -- [in]
         phyReset      => phyReset, -- [in]
         dClkP         => adcSerial.dClkP(CAPTURE_DCLK_IDX_G), -- [in]
         dClkN         => adcSerial.dClkN(CAPTURE_DCLK_IDX_G), -- [in]
         fcoP           => adcSerial.fClkP, -- [in]
         fcoN           => adcSerial.fClkN, -- [in]
         dataP          => dataP, -- [in]
         dataN          => dataN, -- [in]
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

   -------------------------------------------------------------------------------------------------
   -- In default two-lane mode, half 1 contains the upper eight serialized bits
   -- and half 0 contains the lower six sample bits followed by two pad bits.
   -- Strip those pad bits so the core receives the 14-bit ADC code in bits 13:0.
   -------------------------------------------------------------------------------------------------
   GEN_ASSEMBLE : for ch in 7 downto 0 generate
      sampleIn(ch) <= "00" &
                      ite(ADC_INVERT_CH_G(1)(ch) = '1', not dataWord(8+ch)(7 downto 0),
                          dataWord(8+ch)(7 downto 0)) &
                      ite(ADC_INVERT_CH_G(0)(ch) = '1', not dataWord(ch)(7 downto 2),
                          dataWord(ch)(7 downto 2));
   end generate GEN_ASSEMBLE;

   U_Core : entity surf.AdcDdrCore
      generic map (
         TPD_G                  => TPD_G,
         AXIL_BASE_ADDR_G       => AXIL_BASE_ADDR_G,
         DATA_LANES_G           => 16,
         FCO_LANES_G            => 2,
         CHANNELS_G             => 8,
         SAMPLE_WIDTH_G         => 14,
         SERIALIZATION_FACTOR_G => 8,
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
         streams         => coreStreams); -- [out]

   -------------------------------------------------------------------------------------------------
   -- Sample justification
   --
   -- AdcDdrCore emits the 14-bit ADC code right-justified in bits 13:0. The
   -- previous Ad9681Readout and the warm-tdm DSP chain expect the sample
   -- left-justified into bits 15:2 with the two LSBs cleared. Reproduce that
   -- layout by default; keep the raw right-justified stream when disabled.
   -------------------------------------------------------------------------------------------------
   GEN_JUSTIFY : if LEFT_JUSTIFY_G generate
      GEN_CH : for ch in 7 downto 0 generate
         justify : process (coreStreams) is
            variable v : AxiStreamMasterType;
         begin
            v                    := coreStreams(ch);
            v.tData(15 downto 0) := coreStreams(ch).tData(13 downto 0) & "00";
            adcStreams(ch)       <= v;
         end process justify;
      end generate GEN_CH;
   end generate GEN_JUSTIFY;

   GEN_RAW : if not LEFT_JUSTIFY_G generate
      adcStreams <= coreStreams;
   end generate GEN_RAW;

end architecture rtl;
