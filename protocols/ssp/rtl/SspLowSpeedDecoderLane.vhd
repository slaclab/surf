-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: PLL and Deserialization
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

library surf;
use surf.StdRtlPkg.all;

entity SspLowSpeedDecoderLane is
   generic (
      TPD_G        : time     := 1 ns;
      DATA_WIDTH_G : positive := 10;
      SIMULATION_G : boolean  := false);
   port (
      -- Clock and Reset Interface
      clk            : in  sl;
      rst            : in  sl;
      -- Deserialization Interface
      deserData      : in  slv(7 downto 0);
      dlyLoad        : out sl;
      dlyCfg         : out slv(8 downto 0);
      -- Config/Status Interface
      enUsrDlyCfg    : in  sl;
      usrDlyCfg      : in  slv(8 downto 0);
      minEyeWidth    : in  slv(7 downto 0);
      lockingCntCfg  : in  slv(23 downto 0);
      bypFirstBerDet : in  sl;
      polarity       : in  sl;
      bitOrder       : in  slv(1 downto 0);
      errorDet       : out sl;
      bitSlip        : out sl;
      locked         : out sl;
      -- SSP Frame Output
      rxLinkUp       : out sl;
      rxValid        : out sl;
      rxData         : out slv(DATA_WIDTH_G-1 downto 0);
      rxSof          : out sl;
      rxEof          : out sl;
      rxEofe         : out sl);
end SspLowSpeedDecoderLane;

architecture mapping of SspLowSpeedDecoderLane is

   constant ENCODE_WIDTH_C : positive := ite(DATA_WIDTH_G = 16, 20, DATA_WIDTH_G+2);

   signal deserDataMask : slv(7 downto 0);

   signal reset          : sl;
   signal gearboxAligned : sl;
   signal slip           : sl;
   signal validOut       : sl;

   signal encodeValid : sl;
   signal encodeData  : slv(ENCODE_WIDTH_C-1 downto 0);

   signal decodeValid     : sl;
   signal decodeOutOfSync : sl;
   signal decodeCodeErr   : sl;
   signal decodeDispErr   : sl;

begin

   assert ((DATA_WIDTH_G = 10) or (DATA_WIDTH_G = 12) or (DATA_WIDTH_G = 16))
      report "DATA_WIDTH_C must be either [10,12,16]"
      severity failure;

   process(clk)
   begin
      if rising_edge(clk) then
         bitSlip  <= slip;
         rxLinkUp <= gearboxAligned after TPD_G;
         locked   <= gearboxAligned after TPD_G;
      end if;
   end process;

   U_reset : entity surf.RstPipeline
      generic map (
         TPD_G => TPD_G)
      port map (
         clk    => clk,
         rstIn  => rst,
         rstOut => reset);

   deserDataMask <= deserData when(polarity = '0') else not(deserData);

   U_Gearbox : entity surf.Gearbox
      generic map (
         TPD_G          => TPD_G,
         SLAVE_WIDTH_G  => 8,
         MASTER_WIDTH_G => ENCODE_WIDTH_C)
      port map (
         clk            => clk,
         rst            => reset,
         slip           => slip,
         -- Slave Interface
         slaveValid     => '1',
         slaveData      => deserDataMask,
         slaveBitOrder  => bitOrder(0),
         -- Master Interface
         masterValid    => encodeValid,
         masterData     => encodeData,
         masterReady    => '1',
         masterBitOrder => bitOrder(1));

   U_GearboxAligner : entity surf.SelectIoRxGearboxAligner
      generic map (
         TPD_G        => TPD_G,
         CODE_TYPE_G  => "LINE_CODE",
         SIMULATION_G => SIMULATION_G)
      port map (
         -- Clock and Reset
         clk             => clk,
         rst             => reset,
         -- Line-Code Interface (CODE_TYPE_G = "LINE_CODE")
         lineCodeValid   => decodeValid,
         lineCodeErr     => decodeCodeErr,
         lineCodeDispErr => decodeDispErr,
         linkOutOfSync   => decodeOutOfSync,
         -- 64b/66b Interface (CODE_TYPE_G = "SCRAMBLER")
         rxHeaderValid   => '0',
         rxHeader        => (others => '0'),
         -- Link Status and Gearbox Slip
         bitSlip         => slip,
         -- IDELAY (DELAY_TYPE="VAR_LOAD") Interface
         dlyLoad         => dlyLoad,
         dlyCfg          => dlyCfg,
         -- Configuration Interface
         enUsrDlyCfg     => enUsrDlyCfg,
         usrDlyCfg       => usrDlyCfg,
         bypFirstBerDet  => bypFirstBerDet,
         minEyeWidth     => minEyeWidth,
         lockingCntCfg   => lockingCntCfg,
         -- Status Interface
         errorDet        => errorDet,
         locked          => gearboxAligned);

   GEN_10B12B : if (DATA_WIDTH_G = 10) generate
      U_Decoder : entity surf.SspDecoder10b12b
         generic map (
            TPD_G          => TPD_G,
            RST_POLARITY_G => '1',
            RST_ASYNC_G    => false)
         port map (
            -- Clock and Reset
            clk       => clk,
            rst       => reset,
            -- Encoded Input
            validIn   => encodeValid,
            dataIn    => encodeData,
            -- Framing Output
            validOut  => validOut,
            dataOut   => rxData,
            errorOut  => decodeOutOfSync,
            sof       => rxSof,
            eof       => rxEof,
            eofe      => rxEofe,
            -- Decoder Monitoring
            validDec  => decodeValid,
            codeError => decodeCodeErr,
            dispError => decodeDispErr);
   end generate;

   GEN_12B14B : if (DATA_WIDTH_G = 12) generate
      U_Decoder : entity surf.SspDecoder12b14b
         generic map (
            TPD_G          => TPD_G,
            RST_POLARITY_G => '1',
            RST_ASYNC_G    => false)
         port map (
            -- Clock and Reset
            clk       => clk,
            rst       => reset,
            -- Encoded Input
            validIn   => encodeValid,
            dataIn    => encodeData,
            -- Framing Output
            validOut  => validOut,
            dataOut   => rxData,
            errorOut  => decodeOutOfSync,
            sof       => rxSof,
            eof       => rxEof,
            eofe      => rxEofe,
            -- Decoder Monitoring
            validDec  => decodeValid,
            codeError => decodeCodeErr,
            dispError => decodeDispErr);
   end generate;

   GEN_16B20B : if (DATA_WIDTH_G = 16) generate
      U_Decoder : entity surf.SspDecoder8b10b
         generic map (
            TPD_G          => TPD_G,
            RST_POLARITY_G => '1',
            RST_ASYNC_G    => false)
         port map (
            -- Clock and Reset
            clk       => clk,
            rst       => reset,
            -- Encoded Input
            validIn   => encodeValid,
            dataIn    => encodeData,
            -- Framing Output
            validOut  => validOut,
            dataOut   => rxData,
            errorOut  => decodeOutOfSync,
            sof       => rxSof,
            eof       => rxEof,
            eofe      => rxEofe,
            -- Decoder Monitoring
            validDec  => decodeValid,
            codeError => decodeCodeErr,
            dispError => decodeDispErr);
   end generate;

   rxValid <= validOut and gearboxAligned;

end mapping;
