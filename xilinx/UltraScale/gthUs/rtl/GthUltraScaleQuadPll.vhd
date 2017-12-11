-------------------------------------------------------------------------------
-- File       : GthUltraScaleQuadPll.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-04-08
-- Last update: 2017-11-01
-------------------------------------------------------------------------------
-- Description: Wrapper for Ultrascale GTH QPLL primitive
-------------------------------------------------------------------------------
-- This file is part of 'SLAC MGT Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'SLAC MGT Library', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;

library unisim;
use unisim.vcomponents.all;

entity GthUltraScaleQuadPll is
   generic (
      -- Simulation Parameters
      TPD_G               : time                     := 1 ns;
      SIM_RESET_SPEEDUP_G : string                   := "FALSE";
      SIM_VERSION_G       : natural                  := 2;
      -- AXI-Lite Parameters
      EN_DRP_G            : boolean                  := true;
      AXIL_ERROR_RESP_G   : slv(1 downto 0)          := AXI_RESP_DECERR_C;
      -- QPLL Configuration Parameters
      BIAS_CFG0_G         : slv(15 downto 0)         := x"0000";
      BIAS_CFG1_G         : slv(15 downto 0)         := x"0000";
      BIAS_CFG2_G         : slv(15 downto 0)         := x"0000";
      BIAS_CFG3_G         : slv(15 downto 0)         := x"0040";
      BIAS_CFG4_G         : slv(15 downto 0)         := x"0000";
      BIAS_CFG_RSVD_G     : slv(9 downto 0)          := "0000000000";
      COMMON_CFG0_G       : slv(15 downto 0)         := x"0000";
      COMMON_CFG1_G       : slv(15 downto 0)         := x"0000";
      POR_CFG_G           : slv(15 downto 0)         := x"0004";
      QPLL_CFG0_G         : Slv16Array(1 downto 0)   := (others => x"3018");
      QPLL_CFG1_G         : Slv16Array(1 downto 0)   := (others => x"0000");
      QPLL_CFG1_G3_G      : Slv16Array(1 downto 0)   := (others => x"0020");
      QPLL_CFG2_G         : Slv16Array(1 downto 0)   := (others => x"0000");
      QPLL_CFG2_G3_G      : Slv16Array(1 downto 0)   := (others => x"0000");
      QPLL_CFG3_G         : Slv16Array(1 downto 0)   := (others => x"0120");
      QPLL_CFG4_G         : Slv16Array(1 downto 0)   := (others => x"0009");
      QPLL_CP_G           : Slv10Array(1 downto 0)   := (others => "0000011111");
      QPLL_CP_G3_G        : Slv10Array(1 downto 0)   := (others => "0000011111");
      QPLL_FBDIV_G        : NaturalArray(1 downto 0) := (others => 66);
      QPLL_FBDIV_G3_G     : NaturalArray(1 downto 0) := (others => 80);
      QPLL_INIT_CFG0_G    : Slv16Array(1 downto 0)   := (others => x"0000");
      QPLL_INIT_CFG1_G    : Slv8Array(1 downto 0)    := (others => x"00");
      QPLL_LOCK_CFG_G     : Slv16Array(1 downto 0)   := (others => x"01E8");
      QPLL_LOCK_CFG_G3_G  : Slv16Array(1 downto 0)   := (others => x"01E8");
      QPLL_LPF_G          : Slv10Array(1 downto 0)   := (others => "1111111111");
      QPLL_LPF_G3_G       : Slv10Array(1 downto 0)   := (others => "1111111111");
      QPLL_REFCLK_DIV_G   : NaturalArray(1 downto 0) := (others => 2);
      QPLL_SDM_CFG0_G     : Slv16Array(1 downto 0)   := (others => x"0000");
      QPLL_SDM_CFG1_G     : Slv16Array(1 downto 0)   := (others => x"0000");
      QPLL_SDM_CFG2_G     : Slv16Array(1 downto 0)   := (others => x"0000");
      -- Clock Selects
      QPLL_REFCLK_SEL_G   : Slv3Array(1 downto 0)    := (others => "001"));
   port (
      qPllRefClk      : in  slv(1 downto 0);
      qPllOutClk      : out slv(1 downto 0);
      qPllOutRefClk   : out slv(1 downto 0);
      qPllFbClkLost   : out slv(1 downto 0);
      qPllLock        : out slv(1 downto 0);
      qPllLockDetClk  : in  slv(1 downto 0);
      qPllRefClkLost  : out slv(1 downto 0);
      qPllPowerDown   : in  slv(1 downto 0)        := "00";
      qPllReset       : in  slv(1 downto 0);
      -- AXI-Lite Interface
      axilClk         : in  sl                     := '0';
      axilRst         : in  sl                     := '0';
      axilReadMaster  : in  AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
      axilWriteSlave  : out AxiLiteWriteSlaveType);
end entity GthUltraScaleQuadPll;

architecture mapping of GthUltraScaleQuadPll is

   signal gtRefClk0      : slv(1 downto 0);
   signal gtRefClk1      : slv(1 downto 0);
   signal gtNorthRefClk0 : slv(1 downto 0);
   signal gtNorthRefClk1 : slv(1 downto 0);
   signal gtSouthRefClk0 : slv(1 downto 0);
   signal gtSouthRefClk1 : slv(1 downto 0);
   signal gtGRefClk      : slv(1 downto 0);

   signal drpEn   : sl               := '0';
   signal drpWe   : sl               := '0';
   signal drpRdy  : sl               := '0';
   signal drpAddr : slv(8 downto 0)  := (others => '0');
   signal drpDi   : slv(15 downto 0) := (others => '0');
   signal drpDo   : slv(15 downto 0) := (others => '0');

begin

   ---------------------------------------------------------------------------------------
   -- QPLL clock select. Only ever use 1 clock to drive QPLL Channel. Never switch clocks.
   ---------------------------------------------------------------------------------------
   GEN_CLK_SELECT :
   for i in 1 downto 0 generate
      gtRefClk0(i)      <= qpllRefClk(i) when QPLL_REFCLK_SEL_G(i) = "001" else '0';
      gtRefClk1(i)      <= qpllRefClk(i) when QPLL_REFCLK_SEL_G(i) = "010" else '0';
      gtNorthRefClk0(i) <= qpllRefClk(i) when QPLL_REFCLK_SEL_G(i) = "011" else '0';
      gtNorthRefClk1(i) <= qpllRefClk(i) when QPLL_REFCLK_SEL_G(i) = "100" else '0';
      gtSouthRefClk0(i) <= qpllRefClk(i) when QPLL_REFCLK_SEL_G(i) = "101" else '0';
      gtSouthRefClk1(i) <= qpllRefClk(i) when QPLL_REFCLK_SEL_G(i) = "110" else '0';
      gtGRefClk(i)      <= qpllRefClk(i) when QPLL_REFCLK_SEL_G(i) = "111" else '0';
   end generate GEN_CLK_SELECT;

   GTHE3_COMMON_Inst : GTHE3_COMMON
      generic map (
         BIAS_CFG0          => BIAS_CFG0_G,
         BIAS_CFG1          => BIAS_CFG1_G,
         BIAS_CFG2          => BIAS_CFG2_G,
         BIAS_CFG3          => BIAS_CFG3_G,
         BIAS_CFG4          => BIAS_CFG4_G,
         BIAS_CFG_RSVD      => BIAS_CFG_RSVD_G,
         COMMON_CFG0        => COMMON_CFG0_G,
         COMMON_CFG1        => COMMON_CFG1_G,
         POR_CFG            => POR_CFG_G,
         QPLL0_CFG0         => QPLL_CFG0_G(0),
         QPLL0_CFG1         => QPLL_CFG1_G(0),
         QPLL0_CFG1_G3      => QPLL_CFG1_G3_G(0),
         QPLL0_CFG2         => QPLL_CFG2_G(0),
         QPLL0_CFG2_G3      => QPLL_CFG2_G3_G(0),
         QPLL0_CFG3         => QPLL_CFG3_G(0),
         QPLL0_CFG4         => QPLL_CFG4_G(0),
         QPLL0_CP           => QPLL_CP_G(0),
         QPLL0_CP_G3        => QPLL_CP_G3_G(0),
         QPLL0_FBDIV        => QPLL_FBDIV_G(0),
         QPLL0_FBDIV_G3     => QPLL_FBDIV_G3_G(0),
         QPLL0_INIT_CFG0    => QPLL_INIT_CFG0_G(0),
         QPLL0_INIT_CFG1    => QPLL_INIT_CFG1_G(0),
         QPLL0_LOCK_CFG     => QPLL_LOCK_CFG_G(0),
         QPLL0_LOCK_CFG_G3  => QPLL_LOCK_CFG_G3_G(0),
         QPLL0_LPF          => QPLL_LPF_G(0),
         QPLL0_LPF_G3       => QPLL_LPF_G3_G(0),
         QPLL0_REFCLK_DIV   => QPLL_REFCLK_DIV_G(0),
         QPLL0_SDM_CFG0     => QPLL_SDM_CFG0_G(0),
         QPLL0_SDM_CFG1     => QPLL_SDM_CFG1_G(0),
         QPLL0_SDM_CFG2     => QPLL_SDM_CFG2_G(0),
         QPLL1_CFG0         => QPLL_CFG0_G(1),
         QPLL1_CFG1         => QPLL_CFG1_G(1),
         QPLL1_CFG1_G3      => QPLL_CFG1_G3_G(1),
         QPLL1_CFG2         => QPLL_CFG2_G(1),
         QPLL1_CFG2_G3      => QPLL_CFG2_G3_G(1),
         QPLL1_CFG3         => QPLL_CFG3_G(1),
         QPLL1_CFG4         => QPLL_CFG4_G(1),
         QPLL1_CP           => QPLL_CP_G(1),
         QPLL1_CP_G3        => QPLL_CP_G3_G(1),
         QPLL1_FBDIV        => QPLL_FBDIV_G(1),
         QPLL1_FBDIV_G3     => QPLL_FBDIV_G3_G(1),
         QPLL1_INIT_CFG0    => QPLL_INIT_CFG0_G(1),
         QPLL1_INIT_CFG1    => QPLL_INIT_CFG1_G(1),
         QPLL1_LOCK_CFG     => QPLL_LOCK_CFG_G(1),
         QPLL1_LOCK_CFG_G3  => QPLL_LOCK_CFG_G3_G(1),
         QPLL1_LPF          => QPLL_LPF_G(1),
         QPLL1_LPF_G3       => QPLL_LPF_G3_G(1),
         QPLL1_REFCLK_DIV   => QPLL_REFCLK_DIV_G(1),
         QPLL1_SDM_CFG0     => QPLL_SDM_CFG0_G(1),
         QPLL1_SDM_CFG1     => QPLL_SDM_CFG1_G(1),
         QPLL1_SDM_CFG2     => QPLL_SDM_CFG2_G(1),
         RSVD_ATTR0         => x"0000",
         RSVD_ATTR1         => x"0000",
         RSVD_ATTR2         => x"0000",
         RSVD_ATTR3         => x"0000",
         RXRECCLKOUT0_SEL   => "00",
         RXRECCLKOUT1_SEL   => "00",
         SARC_EN            => '1',
         SARC_SEL           => '0',
         SDM0DATA1_0        => "0000000000000000",
         SDM0DATA1_1        => "000000000",
         SDM0INITSEED0_0    => "0000000000000000",
         SDM0INITSEED0_1    => "000000000",
         SDM0_DATA_PIN_SEL  => '0',
         SDM0_WIDTH_PIN_SEL => '0',
         SDM1DATA1_0        => "0000000000000000",
         SDM1DATA1_1        => "000000000",
         SDM1INITSEED0_0    => "0000000000000000",
         SDM1INITSEED0_1    => "000000000",
         SDM1_DATA_PIN_SEL  => '0',
         SDM1_WIDTH_PIN_SEL => '0',
         SIM_RESET_SPEEDUP  => SIM_RESET_SPEEDUP_G,
         SIM_VERSION        => SIM_VERSION_G)
      port map (
         -- DRP Ports
         DRPADDR           => drpAddr,
         DRPCLK            => axilClk,
         DRPDI             => drpDi,
         DRPDO             => drpDo,
         DRPEN             => drpEn,
         DRPRDY            => drpRdy,
         DRPWE             => drpWe,
         -- QPLL Outputs
         PMARSVDOUT0       => open,
         PMARSVDOUT1       => open,
         QPLLDMONITOR0     => open,
         QPLLDMONITOR1     => open,
         REFCLKOUTMONITOR0 => open,
         REFCLKOUTMONITOR1 => open,
         RXRECCLK0_SEL     => open,
         RXRECCLK1_SEL     => open,
         QPLL0FBCLKLOST    => qPllFbClkLost(0),
         QPLL0LOCK         => qPllLock(0),
         QPLL0OUTCLK       => qPllOutClk(0),
         QPLL0OUTREFCLK    => qPllOutRefClk(0),
         QPLL0REFCLKLOST   => qPllRefClkLost(0),
         QPLL1FBCLKLOST    => qPllFbClkLost(1),
         QPLL1LOCK         => qPllLock(1),
         QPLL1OUTCLK       => qPllOutClk(1),
         QPLL1OUTREFCLK    => qPllOutRefClk(1),
         QPLL1REFCLKLOST   => qPllRefClkLost(1),
         -- QPLL Inputs
         QPLL0CLKRSVD0     => '0',
         QPLL0CLKRSVD1     => '0',
         QPLL0LOCKDETCLK   => qPllLockDetClk(0),
         QPLL0LOCKEN       => '1',
         QPLL0PD           => qPllPowerDown(0),
         QPLL0REFCLKSEL    => QPLL_REFCLK_SEL_G(0),
         QPLL0RESET        => qPllReset(0),
         QPLL1CLKRSVD0     => '0',
         QPLL1CLKRSVD1     => '0',
         QPLL1LOCKDETCLK   => qPllLockDetClk(1),
         QPLL1LOCKEN       => '1',
         QPLL1PD           => qPllPowerDown(1),
         QPLL1REFCLKSEL    => QPLL_REFCLK_SEL_G(1),
         QPLL1RESET        => qPllReset(1),
         BGBYPASSB         => '1',
         BGMONITORENB      => '1',
         BGPDB             => '1',
         BGRCALOVRD        => (others => '1'),
         BGRCALOVRDENB     => '1',
         GTREFCLK00        => gtRefClk0(0),
         GTREFCLK10        => gtRefClk1(0),
         GTNORTHREFCLK00   => gtNorthRefClk0(0),
         GTNORTHREFCLK10   => gtNorthRefClk1(0),
         GTSOUTHREFCLK00   => gtSouthRefClk0(0),
         GTSOUTHREFCLK10   => gtSouthRefClk1(0),
         GTGREFCLK0        => gtGRefClk(0),
         GTREFCLK01        => gtRefClk0(1),
         GTREFCLK11        => gtRefClk1(1),
         GTNORTHREFCLK01   => gtNorthRefClk0(1),
         GTNORTHREFCLK11   => gtNorthRefClk1(1),
         GTSOUTHREFCLK01   => gtSouthRefClk0(1),
         GTSOUTHREFCLK11   => gtSouthRefClk1(1),
         GTGREFCLK1        => gtGRefClk(1),
         PMARSVD0          => (others => '0'),
         PMARSVD1          => (others => '0'),
         QPLLRSVD1         => (others => '0'),
         QPLLRSVD2         => (others => '0'),
         QPLLRSVD3         => (others => '0'),
         QPLLRSVD4         => (others => '0'),
         RCALENB           => '1');

   GEN_DRP : if (EN_DRP_G) generate
      U_AxiLiteToDrp : entity work.AxiLiteToDrp
         generic map (
            TPD_G            => TPD_G,
            AXI_ERROR_RESP_G => AXIL_ERROR_RESP_G,
            COMMON_CLK_G     => true,
            EN_ARBITRATION_G => false,
            TIMEOUT_G        => 4096,
            ADDR_WIDTH_G     => 9,
            DATA_WIDTH_G     => 16)
         port map (
            -- AXI-Lite Port
            axilClk         => axilClk,
            axilRst         => axilRst,
            axilReadMaster  => axilReadMaster,
            axilReadSlave   => axilReadSlave,
            axilWriteMaster => axilWriteMaster,
            axilWriteSlave  => axilWriteSlave,
            -- DRP Interface
            drpClk          => axilClk,
            drpRst          => axilRst,
            drpRdy          => drpRdy,
            drpEn           => drpEn,
            drpWe           => drpWe,
            drpAddr         => drpAddr,
            drpDi           => drpDi,
            drpDo           => drpDo);
   end generate GEN_DRP;

   NO_DRP : if (not EN_DRP_G) generate
      U_AxiLiteEmpty_1 : entity work.AxiLiteEmpty
         generic map (
            TPD_G            => TPD_G,
            AXI_ERROR_RESP_G => AXIL_ERROR_RESP_G)
         port map (
            axiClk         => axilClk,          -- [in]
            axiClkRst      => axilRst,          -- [in]
            axiReadMaster  => axilReadMaster,   -- [in]
            axiReadSlave   => axilReadSlave,    -- [out]
            axiWriteMaster => axilWriteMaster,  -- [in]
            axiWriteSlave  => axilWriteSlave);  -- [out]
   end generate NO_DRP;

end architecture mapping;
