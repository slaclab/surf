-------------------------------------------------------------------------------
-- Title      : CoaXPress Protocol: http://jiia.org/wp-content/themes/jiia/pdf/standard_dl/coaxpress/CXP-001-2021.pdf
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: CoaXPress GTH Ultrascale QPLL Wrapper
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
use surf.CoaXPressPkg.all;

library unisim;
use unisim.vcomponents.all;

entity CoaXPressGthUsQpll is
   generic (
      TPD_G             : time                  := 1 ns;
      CXP_RATE_G        : CxpSpeedType          := CXP_12_C;
      QPLL_REFCLK_SEL_G : Slv3Array(1 downto 0) := (0 => "001", 1 => "111");  -- Default: 156.25MHz=gtRefClk, 250MHz=fabric
      EN_DRP_G          : boolean               := true);
   port (
      -- Stable Clock and Reset
      stableClk       : in  sl;         -- GT needs a stable clock to "boot up"
      stableRst       : in  sl;
      -- QPLL Clocking
      refClk156       : in  sl;         -- 156.25 MHz
      refClk250       : in  sl;         -- 250 MHz
      qpllLock        : out Slv2Array(3 downto 0);
      qpllClk         : out Slv2Array(3 downto 0);
      qpllRefclk      : out Slv2Array(3 downto 0);
      qpllRst         : in  Slv2Array(3 downto 0);
      -- AXI-Lite Interface
      axilClk         : in  sl                     := '0';
      axilRst         : in  sl                     := '0';
      axilReadMaster  : in  AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
      axilReadSlave   : out AxiLiteReadSlaveType   := AXI_LITE_READ_SLAVE_EMPTY_DECERR_C;
      axilWriteMaster : in  AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
      axilWriteSlave  : out AxiLiteWriteSlaveType  := AXI_LITE_WRITE_SLAVE_EMPTY_DECERR_C);
end CoaXPressGthUsQpll;

architecture mapping of CoaXPressGthUsQpll is

   type QpllConfig is record
      QPLL_CFG0        : slv(15 downto 0);
      QPLL_CFG1        : slv(15 downto 0);
      QPLL_CFG1_G3     : slv(15 downto 0);
      QPLL_CFG2        : slv(15 downto 0);
      QPLL_CFG2_G3     : slv(15 downto 0);
      QPLL_CFG3        : slv(15 downto 0);
      QPLL_CFG4        : slv(15 downto 0);
      QPLL_CP          : slv(9 downto 0);
      QPLL_CP_G3       : slv(9 downto 0);
      QPLL_FBDIV       : natural;
      QPLL_FBDIV_G3    : natural;
      QPLL_INIT_CFG0   : slv(15 downto 0);
      QPLL_INIT_CFG1   : slv(7 downto 0);
      QPLL_LOCK_CFG    : slv(15 downto 0);
      QPLL_LOCK_CFG_G3 : slv(15 downto 0);
      QPLL_LPF         : slv(9 downto 0);
      QPLL_LPF_G3      : slv(9 downto 0);
      QPLL_REFCLK_DIV  : natural;
   end record QpllConfig;
   constant QPLL0_C : QpllConfig := (
      QPLL_CFG0        => b"0011001000011100",
      QPLL_CFG1        => b"0001000000011000",
      QPLL_CFG1_G3     => b"0001000000011000",
      QPLL_CFG2        => b"0000000001001000",
      QPLL_CFG2_G3     => b"0000000001001000",
      QPLL_CFG3        => b"0000000100100000",
      QPLL_CFG4        => b"0000000000000000",
      QPLL_CP          => b"0111111111",
      QPLL_CP_G3       => b"1111111111",
      QPLL_FBDIV       => 80,
      QPLL_FBDIV_G3    => 80,
      QPLL_INIT_CFG0   => b"0000001010110010",
      QPLL_INIT_CFG1   => b"00000000",
      QPLL_LOCK_CFG    => b"0010000111101000",
      QPLL_LOCK_CFG_G3 => b"0010000111101000",
      QPLL_LPF         => b"1111111100",
      QPLL_LPF_G3      => b"0000010101",
      QPLL_REFCLK_DIV  => 1);
   constant QPLL1_C : QpllConfig := (
      QPLL_CFG0        => b"0011001000011100",
      QPLL_CFG1        => b"0001000000011000",
      QPLL_CFG1_G3     => b"0001000000011000",
      QPLL_CFG2        => b"0000000001000000",
      QPLL_CFG2_G3     => b"0000000001000000",
      QPLL_CFG3        => b"0000000100100000",
      QPLL_CFG4        => b"0000000000000000",
      QPLL_CP          => b"0111111111",
      QPLL_CP_G3       => b"1111111111",
      QPLL_FBDIV       => 128,
      QPLL_FBDIV_G3    => 80,
      QPLL_INIT_CFG0   => b"0000001010110010",
      QPLL_INIT_CFG1   => b"00000000",
      QPLL_LOCK_CFG    => b"0010000111101000",
      QPLL_LOCK_CFG_G3 => b"0010000111101000",
      QPLL_LPF         => b"1111111100",
      QPLL_LPF_G3      => b"0000010101",
      QPLL_REFCLK_DIV  => 3);

   signal pllRefClk     : slv(1 downto 0);
   signal pllOutClk     : slv(1 downto 0);
   signal pllOutRefClk  : slv(1 downto 0);
   signal pllFbClkLost  : slv(1 downto 0);  -- unused
   signal pllLock       : slv(1 downto 0);
   signal pllLockDetClk : slv(1 downto 0);
   signal pllRefClkLost : slv(1 downto 0);
   signal pllPowerDown  : slv(1 downto 0);
   signal pllReset      : slv(1 downto 0);
   signal lockedStrobe  : Slv2Array(3 downto 0);
   signal gtQPllReset   : Slv2Array(3 downto 0);

begin

   assert (CXP_RATE_G = CXP_12_C)
      report "CXP_RATE_G: Only CXP_12_C is supported at this time"
      severity error;

   GEN_VEC :
   for i in 3 downto 0 generate
      GEN_CH :
      for j in 1 downto 0 generate

         qpllClk(i)(j)    <= pllOutClk(j);
         qpllRefclk(i)(j) <= pllOutRefClk(j);
         qpllLock(i)(j)   <= pllLock(j) and not(lockedStrobe(i)(j));  -- trick the GTH state machine of lock transition

         ----------------------------------------------------------------------------
         -- Prevent the gtQPllRst of this lane disrupting the other lanes in the QUAD
         ----------------------------------------------------------------------------
         U_PwrUpRst : entity surf.PwrUpRst
            generic map (
               TPD_G      => TPD_G,
               DURATION_G => 12500)
            port map (
               arst   => qpllRst(i)(j),
               clk    => stableClk,
               rstOut => lockedStrobe(i)(j));

         gtQPllReset(i)(j) <= qpllRst(i)(j) and not (pllLock(j));

      end generate GEN_CH;
   end generate GEN_VEC;

   pllReset(0) <= gtQPllReset(0)(0) or gtQPllReset(1)(0) or gtQPllReset(2)(0) or gtQPllReset(3)(0) or stableRst;
   pllReset(1) <= gtQPllReset(0)(1) or gtQPllReset(1)(1) or gtQPllReset(2)(1) or gtQPllReset(3)(1) or stableRst;

   pllRefClk(0)  <= refClk156;
   pllRefClk(1)  <= refClk250;
   pllLockDetClk <= stableClk & stableClk;

   U_QPLL : entity surf.GthUltraScaleQuadPll
      generic map (
         -- Simulation Parameters
         TPD_G              => TPD_G,
         -- AXI-Lite Parameters
         EN_DRP_G           => EN_DRP_G,
         -- QPLL Configuration Parameters
         QPLL_CFG0_G        => (0 => QPLL0_C.QPLL_CFG0, 1 => QPLL1_C.QPLL_CFG0),
         QPLL_CFG1_G        => (0 => QPLL0_C.QPLL_CFG1, 1 => QPLL1_C.QPLL_CFG1),
         QPLL_CFG1_G3_G     => (0 => QPLL0_C.QPLL_CFG1_G3, 1 => QPLL1_C.QPLL_CFG1_G3),
         QPLL_CFG2_G        => (0 => QPLL0_C.QPLL_CFG2, 1 => QPLL1_C.QPLL_CFG2),
         QPLL_CFG2_G3_G     => (0 => QPLL0_C.QPLL_CFG2_G3, 1 => QPLL1_C.QPLL_CFG2_G3),
         QPLL_CFG3_G        => (0 => QPLL0_C.QPLL_CFG3, 1 => QPLL1_C.QPLL_CFG3),
         QPLL_CFG4_G        => (0 => QPLL0_C.QPLL_CFG4, 1 => QPLL1_C.QPLL_CFG4),
         QPLL_CP_G          => (0 => QPLL0_C.QPLL_CP, 1 => QPLL1_C.QPLL_CP),
         QPLL_CP_G3_G       => (0 => QPLL0_C.QPLL_CP_G3, 1 => QPLL1_C.QPLL_CP_G3),
         QPLL_FBDIV_G       => (0 => QPLL0_C.QPLL_FBDIV, 1 => QPLL1_C.QPLL_FBDIV),
         QPLL_FBDIV_G3_G    => (0 => QPLL0_C.QPLL_FBDIV_G3, 1 => QPLL1_C.QPLL_FBDIV_G3),
         QPLL_INIT_CFG0_G   => (0 => QPLL0_C.QPLL_INIT_CFG0, 1 => QPLL1_C.QPLL_INIT_CFG0),
         QPLL_INIT_CFG1_G   => (0 => QPLL0_C.QPLL_INIT_CFG1, 1 => QPLL1_C.QPLL_INIT_CFG1),
         QPLL_LOCK_CFG_G    => (0 => QPLL0_C.QPLL_LOCK_CFG, 1 => QPLL1_C.QPLL_LOCK_CFG),
         QPLL_LOCK_CFG_G3_G => (0 => QPLL0_C.QPLL_LOCK_CFG_G3, 1 => QPLL1_C.QPLL_LOCK_CFG_G3),
         QPLL_LPF_G         => (0 => QPLL0_C.QPLL_LPF, 1 => QPLL1_C.QPLL_LPF),
         QPLL_LPF_G3_G      => (0 => QPLL0_C.QPLL_LPF_G3, 1 => QPLL1_C.QPLL_LPF_G3),
         QPLL_REFCLK_DIV_G  => (0 => QPLL0_C.QPLL_REFCLK_DIV, 1 => QPLL1_C.QPLL_REFCLK_DIV),
         -- Clock Selects
         QPLL_REFCLK_SEL_G  => QPLL_REFCLK_SEL_G)
      port map (
         qPllRefClk      => pllRefClk,
         qPllOutClk      => pllOutClk,
         qPllOutRefClk   => pllOutRefClk,
         qPllFbClkLost   => pllFbClkLost,
         qPllLock        => pllLock,
         qPllLockDetClk  => pllLockDetClk,
         qPllRefClkLost  => pllRefClkLost,
         qPllPowerDown   => "00",       -- Never power down QPLL
         qPllReset       => pllReset,
         -- AXI Lite interface
         axilClk         => axilClk,
         axilRst         => axilRst,
         axilReadMaster  => axilReadMaster,
         axilReadSlave   => axilReadSlave,
         axilWriteMaster => axilWriteMaster,
         axilWriteSlave  => axilWriteSlave);

end mapping;
