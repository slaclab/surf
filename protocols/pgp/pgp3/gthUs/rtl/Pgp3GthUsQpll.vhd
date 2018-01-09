-------------------------------------------------------------------------------
-- File       : Pgp3GthUsQpll.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2017-10-26
-- Last update: 2017-11-01
-------------------------------------------------------------------------------
-- Description: 
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

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;

library unisim;
use unisim.vcomponents.all;

entity Pgp3GthUsQpll is
   generic (
      TPD_G             : time            := 1 ns;
      EN_DRP_G          : boolean         := true;
      AXIL_ERROR_RESP_G : slv(1 downto 0) := AXI_RESP_DECERR_C);
   port (
      -- Stable Clock and Reset
      stableClk       : in  sl;         -- GT needs a stable clock to "boot up"
      stableRst       : in  sl;
      -- QPLL Clocking
      pgpRefClk       : in  sl;
      qpllLock        : out Slv2Array(3 downto 0);
      qpllClk         : out Slv2Array(3 downto 0);
      qpllRefclk      : out Slv2Array(3 downto 0);
      qpllRst         : in  Slv2Array(3 downto 0);
      -- AXI-Lite Interface
      axilClk         : in  sl                     := '0';
      axilRst         : in  sl                     := '0';
      axilReadMaster  : in  AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
      axilWriteSlave  : out AxiLiteWriteSlaveType);
end Pgp3GthUsQpll;

architecture mapping of Pgp3GthUsQpll is

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
         U_PwrUpRst : entity work.PwrUpRst
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

   pllRefClk     <= pgpRefClk & pgpRefClk;
   pllLockDetClk <= stableClk & stableClk;

   U_QPLL : entity work.GthUltraScaleQuadPll
      generic map (
         -- Simulation Parameters
         TPD_G              => TPD_G,
         -- AXI-Lite Parameters
         EN_DRP_G           => EN_DRP_G,
         AXIL_ERROR_RESP_G  => AXIL_ERROR_RESP_G,
         -- QPLL Configuration Parameters
         QPLL_CFG0_G        => (others => x"321C"),
         QPLL_CFG1_G        => (others => x"1018"),
         QPLL_CFG1_G3_G     => (others => x"1018"),
         QPLL_CFG2_G        => (others => x"0048"),
         QPLL_CFG2_G3_G     => (others => x"0048"),
         QPLL_CFG3_G        => (others => x"0120"),
         QPLL_CFG4_G        => (others => x"0009"),
         QPLL_CP_G          => (others => "0000011111"),
         QPLL_CP_G3_G       => (others => "1111111111"),
         QPLL_FBDIV_G       => (others => 66),
         QPLL_FBDIV_G3_G    => (others => 80),
         QPLL_INIT_CFG0_G   => (others => x"02B2"),
         QPLL_INIT_CFG1_G   => (others => x"00"),
         QPLL_LOCK_CFG_G    => (others => x"21E8"),
         QPLL_LOCK_CFG_G3_G => (others => x"21E8"),
         QPLL_LPF_G         => (others => "1111111100"),
         QPLL_LPF_G3_G      => (others => "0000010101"),
         QPLL_REFCLK_DIV_G  => (others => 1),
         -- Clock Selects
         QPLL_REFCLK_SEL_G  => (others => "001"))
      port map (
         qPllRefClk       => pllRefClk,
         qPllOutClk       => pllOutClk,
         qPllOutRefClk    => pllOutRefClk,
         qPllFbClkLost    => pllFbClkLost,
         qPllLock         => pllLock,
         qPllLockDetClk   => pllLockDetClk,
         qPllRefClkLost   => pllRefClkLost,
         qPllPowerDown(0) => '0',       -- Never power down QPLL[0]
         qPllPowerDown(1) => '1',       -- Power down QPLL[1]
         qPllReset        => pllReset,
         -- AXI Lite interface
         axilClk          => axilClk,
         axilRst          => axilRst,
         axilReadMaster   => axilReadMaster,
         axilReadSlave    => axilReadSlave,
         axilWriteMaster  => axilWriteMaster,
         axilWriteSlave   => axilWriteSlave);

end mapping;
