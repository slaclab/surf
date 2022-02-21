-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: SSP Decoder Wrapper
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
use surf.AxiLitePkg.all;

entity SspLowSpeedDecoder10b12bWrapper is
   generic (
      TPD_G           : time                    := 1 ns;
      SIMULATION_G    : boolean                 := false;
      DLY_STEP_SIZE_G : positive range 1 to 255 := 1;
      NUM_LANE_G      : positive                := 1);
   port (
      -- Deserialization Interface (deserClk domain)
      deserClk        : in  sl;
      deserRst        : in  sl;
      deserData       : in  Slv8Array(NUM_LANE_G-1 downto 0);
      dlyLoad         : out slv(NUM_LANE_G-1 downto 0);
      dlyCfg          : out Slv9Array(NUM_LANE_G-1 downto 0);
      -- SSP Frame Output
      rxLinkUp        : out slv(NUM_LANE_G-1 downto 0);
      rxValid         : out slv(NUM_LANE_G-1 downto 0);
      rxData          : out Slv10Array(NUM_LANE_G-1 downto 0);
      rxSof           : out slv(NUM_LANE_G-1 downto 0);
      rxEof           : out slv(NUM_LANE_G-1 downto 0);
      rxEofe          : out slv(NUM_LANE_G-1 downto 0);
      -- AXI-Lite Interface (axilClk domain)
      axilClk         : in  sl;
      axilRst         : in  sl;
      axilReadMaster  : in  AxiLiteReadMasterType;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType;
      axilWriteSlave  : out AxiLiteWriteSlaveType);
end SspLowSpeedDecoder10b12bWrapper;

architecture mapping of SspLowSpeedDecoder10b12bWrapper is

   constant DATA_WIDTH_C : positive := 10;

   signal dlyConfig : Slv9Array(NUM_LANE_G-1 downto 0);

   signal enUsrDlyCfg    : sl;
   signal usrDlyCfg      : Slv9Array(NUM_LANE_G-1 downto 0);
   signal minEyeWidth    : slv(7 downto 0);
   signal lockingCntCfg  : slv(23 downto 0);
   signal bypFirstBerDet : sl;
   signal lockOnIdle     : sl;
   signal bitOrder       : slv(1 downto 0);
   signal errorMask      : slv(2 downto 0);
   signal polarity       : slv(NUM_LANE_G-1 downto 0);
   signal errorDet       : slv(NUM_LANE_G-1 downto 0);
   signal bitSlip        : slv(NUM_LANE_G-1 downto 0);
   signal eyeWidth       : Slv9Array(NUM_LANE_G-1 downto 0);
   signal locked         : slv(NUM_LANE_G-1 downto 0);
   signal idleCode       : slv(NUM_LANE_G-1 downto 0);

begin

   dlyCfg <= dlyConfig;

   GEN_VEC :
   for i in NUM_LANE_G-1 downto 0 generate

      U_Lane : entity surf.SspLowSpeedDecoderLane
         generic map (
            TPD_G           => TPD_G,
            SIMULATION_G    => SIMULATION_G,
            DATA_WIDTH_G    => DATA_WIDTH_C,
            DLY_STEP_SIZE_G => DLY_STEP_SIZE_G)
         port map (
            -- Clock and Reset Interface
            clk            => deserClk,
            rst            => deserRst,
            -- Deserialization Interface
            deserData      => deserData(i),
            dlyLoad        => dlyLoad(i),
            dlyCfg         => dlyConfig(i),
            -- Config/Status Interface
            enUsrDlyCfg    => enUsrDlyCfg,
            usrDlyCfg      => usrDlyCfg(i),
            minEyeWidth    => minEyeWidth,
            lockingCntCfg  => lockingCntCfg,
            bypFirstBerDet => bypFirstBerDet,
            polarity       => polarity(i),
            bitOrder       => bitOrder,
            errorMask      => errorMask,
            lockOnIdle     => lockOnIdle,
            errorDet       => errorDet(i),
            bitSlip        => bitSlip(i),
            eyeWidth       => eyeWidth(i),
            locked         => locked(i),
            idleCode       => idleCode(i),
            -- SSP Frame Output
            rxLinkUp       => rxLinkUp(i),
            rxValid        => rxValid(i),
            rxData         => rxData(i),
            rxSof          => rxSof(i),
            rxEof          => rxEof(i),
            rxEofe         => rxEofe(i));

   end generate GEN_VEC;

   U_Reg : entity surf.SspLowSpeedDecoderReg
      generic map (
         TPD_G        => TPD_G,
         SIMULATION_G => SIMULATION_G,
         DATA_WIDTH_G => DATA_WIDTH_C,
         NUM_LANE_G   => NUM_LANE_G)
      port map (
         -- Deserialization Interface (deserClk domain)
         deserClk        => deserClk,
         deserRst        => deserRst,
         dlyConfig       => dlyConfig,
         errorDet        => errorDet,
         bitSlip         => bitSlip,
         eyeWidth        => eyeWidth,
         locked          => locked,
         idleCode        => idleCode,
         enUsrDlyCfg     => enUsrDlyCfg,
         usrDlyCfg       => usrDlyCfg,
         minEyeWidth     => minEyeWidth,
         lockingCntCfg   => lockingCntCfg,
         bypFirstBerDet  => bypFirstBerDet,
         polarity        => polarity,
         bitOrder        => bitOrder,
         errorMask       => errorMask,
         lockOnIdle      => lockOnIdle,
         -- AXI-Lite Interface (axilClk domain)
         axilClk         => axilClk,
         axilRst         => axilRst,
         axilReadMaster  => axilReadMaster,
         axilReadSlave   => axilReadSlave,
         axilWriteMaster => axilWriteMaster,
         axilWriteSlave  => axilWriteSlave);

end mapping;
