-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Pgp4RxLite Low Speed Wrapper
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
use surf.AxiStreamPkg.all;
use surf.AxiLitePkg.all;
use surf.Pgp4Pkg.all;

entity Pgp4LiteRxLowSpeed is
   generic (
      TPD_G              : time                    := 1 ns;
      SIMULATION_G       : boolean                 := false;
      DLY_STEP_SIZE_G    : positive range 1 to 255 := 1;
      NUM_LANE_G         : positive                := 1;
      STATUS_CNT_WIDTH_G : natural range 1 to 32   := 16;
      ERROR_CNT_WIDTH_G  : natural range 1 to 32   := 8;
      AXIL_CLK_FREQ_G    : real; -- In units of HZ
      AXIL_BASE_ADDR_G   : slv(31 downto 0));
   port (
      -- Deserialization Interface (deserClk domain)
      deserClk        : in  sl;
      deserRst        : in  sl;
      deserData       : in  Slv8Array(NUM_LANE_G-1 downto 0);
      dlyLoad         : out slv(NUM_LANE_G-1 downto 0);
      dlyCfg          : out Slv9Array(NUM_LANE_G-1 downto 0);
      -- PGP Streaming Outputs (deserClk domain)
      pgpRxMasters    : out AxiStreamMasterArray(NUM_LANE_G-1 downto 0);
      -- AXI-Lite Interface (axilClk domain)
      axilClk         : in  sl;
      axilRst         : in  sl;
      axilReadMaster  : in  AxiLiteReadMasterType;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType;
      axilWriteSlave  : out AxiLiteWriteSlaveType);
end Pgp4LiteRxLowSpeed;

architecture mapping of Pgp4LiteRxLowSpeed is

   constant NUM_AXIL_MASTERS_C : positive := NUM_LANE_G+1;

   constant XBAR_CONFIG_C : AxiLiteCrossbarMasterConfigArray(NUM_AXIL_MASTERS_C-1 downto 0) := genAxiLiteConfig(NUM_AXIL_MASTERS_C, AXIL_BASE_ADDR_G, 20, 12);

   signal axilWriteMasters : AxiLiteWriteMasterArray(NUM_AXIL_MASTERS_C-1 downto 0);
   signal axilWriteSlaves  : AxiLiteWriteSlaveArray(NUM_AXIL_MASTERS_C-1 downto 0) := (others => AXI_LITE_WRITE_SLAVE_EMPTY_SLVERR_C);
   signal axilReadMasters  : AxiLiteReadMasterArray(NUM_AXIL_MASTERS_C-1 downto 0);
   signal axilReadSlaves   : AxiLiteReadSlaveArray(NUM_AXIL_MASTERS_C-1 downto 0)  := (others => AXI_LITE_READ_SLAVE_EMPTY_SLVERR_C);

   signal deserReset : sl;
   signal dlyConfig  : Slv9Array(NUM_LANE_G-1 downto 0);

   signal enUsrDlyCfg    : sl;
   signal usrDlyCfg      : Slv9Array(NUM_LANE_G-1 downto 0);
   signal minEyeWidth    : slv(7 downto 0);
   signal lockingCntCfg  : slv(23 downto 0);
   signal bypFirstBerDet : sl;
   signal polarity       : slv(NUM_LANE_G-1 downto 0);
   signal bitOrder       : slv(1 downto 0);
   signal errorDet       : slv(NUM_LANE_G-1 downto 0);
   signal bitSlip        : slv(NUM_LANE_G-1 downto 0);
   signal eyeWidth       : Slv9Array(NUM_LANE_G-1 downto 0);
   signal locked         : slv(NUM_LANE_G-1 downto 0);

begin

   dlyCfg <= dlyConfig;

   U_deserReset : entity surf.RstPipeline
      generic map (
         TPD_G => TPD_G)
      port map (
         clk    => deserClk,
         rstIn  => deserRst,
         rstOut => deserReset);

   U_XBAR : entity surf.AxiLiteCrossbar
      generic map (
         TPD_G              => TPD_G,
         NUM_SLAVE_SLOTS_G  => 1,
         NUM_MASTER_SLOTS_G => NUM_AXIL_MASTERS_C,
         MASTERS_CONFIG_G   => XBAR_CONFIG_C)
      port map (
         axiClk              => axilClk,
         axiClkRst           => axilRst,
         sAxiWriteMasters(0) => axilWriteMaster,
         sAxiWriteSlaves(0)  => axilWriteSlave,
         sAxiReadMasters(0)  => axilReadMaster,
         sAxiReadSlaves(0)   => axilReadSlave,
         mAxiWriteMasters    => axilWriteMasters,
         mAxiWriteSlaves     => axilWriteSlaves,
         mAxiReadMasters     => axilReadMasters,
         mAxiReadSlaves      => axilReadSlaves);

   U_Reg : entity surf.Pgp4RxLiteLowSpeedReg
      generic map (
         TPD_G              => TPD_G,
         SIMULATION_G       => SIMULATION_G,
         STATUS_CNT_WIDTH_G => STATUS_CNT_WIDTH_G,
         NUM_LANE_G         => NUM_LANE_G)
      port map (
         -- Deserialization Interface (deserClk domain)
         deserClk        => deserClk,
         deserRst        => deserRst,
         dlyConfig       => dlyConfig,
         errorDet        => errorDet,
         bitSlip         => bitSlip,
         eyeWidth        => eyeWidth,
         locked          => locked,
         enUsrDlyCfg     => enUsrDlyCfg,
         usrDlyCfg       => usrDlyCfg,
         minEyeWidth     => minEyeWidth,
         lockingCntCfg   => lockingCntCfg,
         bypFirstBerDet  => bypFirstBerDet,
         polarity        => polarity,
         bitOrder        => bitOrder,
         -- AXI-Lite Interface (axilClk domain)
         axilClk         => axilClk,
         axilRst         => axilRst,
         axilReadMaster  => axilReadMasters(0),
         axilReadSlave   => axilReadSlaves(0),
         axilWriteMaster => axilWriteMasters(0),
         axilWriteSlave  => axilWriteSlaves(0));

   GEN_LANE :
   for i in NUM_LANE_G-1 downto 0 generate

      U_PgpLane : entity surf.Pgp4RxLiteLowSpeedLane
         generic map (
            TPD_G              => TPD_G,
            SIMULATION_G       => SIMULATION_G,
            DLY_STEP_SIZE_G    => DLY_STEP_SIZE_G,
            STATUS_CNT_WIDTH_G => STATUS_CNT_WIDTH_G,
            ERROR_CNT_WIDTH_G  => ERROR_CNT_WIDTH_G,
            AXIL_CLK_FREQ_G    => AXIL_CLK_FREQ_G)
         port map (
            -- Deserialization Interface (deserClk domain)
            deserClk        => deserClk,
            deserRst        => deserReset,
            deserData       => deserData(i),
            dlyLoad         => dlyLoad(i),
            dlyCfg          => dlyConfig(i),
            -- Config/Status Interface (deserClk domain)
            enUsrDlyCfg     => enUsrDlyCfg,
            usrDlyCfg       => usrDlyCfg(i),
            minEyeWidth     => minEyeWidth,
            lockingCntCfg   => lockingCntCfg,
            bypFirstBerDet  => bypFirstBerDet,
            polarity        => polarity(i),
            bitOrder        => bitOrder,
            errorDet        => errorDet(i),
            bitSlip         => bitSlip(i),
            eyeWidth        => eyeWidth(i),
            locked          => locked(i),
            -- PGP Streaming Outputs (deserClk domain)
            pgpRxMaster     => pgpRxMasters(i),
            -- AXI-Lite Register Interface (axilClk domain)
            axilClk         => axilClk,
            axilRst         => axilRst,
            axilReadMaster  => axilReadMasters(i+1),
            axilReadSlave   => axilReadSlaves(i+1),
            axilWriteMaster => axilWriteMasters(i+1),
            axilWriteSlave  => axilWriteSlaves(i+1));

   end generate GEN_LANE;

end mapping;
