-------------------------------------------------------------------------------
-- Title      : PGPv3: https://confluence.slac.stanford.edu/x/OndODQ
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: PGP3 GTH Ultrascale QPLL Wrapper
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

library unisim;
use unisim.vcomponents.all;

entity Pgp3GthUsQpll is
   generic (
      TPD_G    : time    := 1 ns;
      RATE_G   : string  := "10.3125Gbps";  -- or "6.25Gbps" or "3.125Gbps"
      EN_DRP_G : boolean := true);
   port (
      -- Stable Clock and Reset
      stableClk       : in  sl;         -- GT needs a stable clock to "boot up"
      stableRst       : in  sl;
      -- QPLL Clocking
      pgpRefClk       : in  sl;         -- 156.25 MHz
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
end Pgp3GthUsQpll;

architecture mapping of Pgp3GthUsQpll is

   constant PPF_CFG_C : slv(15 downto 0) :=
      ite((RATE_G = "10.3125Gbps"), b"0000011000000000",
          ite((RATE_G = "15.46875Gbps"), b"0000111100000000",
              b"0000100000000000"));

   constant QPLL_CFG2_C : slv(15 downto 0) :=
      ite((RATE_G = "10.3125Gbps"), b"0000111111000000",
          ite((RATE_G = "15.46875Gbps"), b"0000111111000001",
              b"0000111111000011"));

   constant QPLL_CFG4_C : slv(15 downto 0) :=
      ite((RATE_G = "10.3125Gbps"), b"0000000000000011",
          ite((RATE_G = "15.46875Gbps"), b"0000000001000101",
              b"0000000000000100"));

   constant QPLL_FBDIV_C : positive :=
      ite((RATE_G = "10.3125Gbps"), 66,
          ite((RATE_G = "15.46875Gbps"), 99,
              80));

   constant QPLL_LPF_C : slv(9 downto 0) :=
      ite((RATE_G = "10.3125Gbps"), b"1000111111",
          ite((RATE_G = "15.46875Gbps"), b"1101111111",
              b"1000011111"));

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

   assert ((RATE_G = "3.125Gbps") or (RATE_G = "6.25Gbps") or (RATE_G = "10.3125Gbps") or (RATE_G = "12.5Gbps") or (RATE_G = "15.46875Gbps"))
      report "RATE_G: Must be either 3.125Gbps or 6.25Gbps or 10.3125Gbps or 12.5Gbps or 15.46875Gbps"
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

   pllRefClk     <= pgpRefClk & pgpRefClk;
   pllLockDetClk <= stableClk & stableClk;

   U_QPLL : entity surf.GthUltraScaleQuadPll
      generic map (
         -- Simulation Parameters
         TPD_G              => TPD_G,
         -- AXI-Lite Parameters
         EN_DRP_G           => EN_DRP_G,
         -- QPLL Configuration Parameters
         PPF_CFG_G          => (others => PPF_CFG_C),
         QPLL_CFG0_G        => (others => b"0011001100011100"),
         QPLL_CFG1_G        => (others => b"1101000000111000"),
         QPLL_CFG1_G3_G     => (others => b"1101000000111000"),
         QPLL_CFG2_G        => (others => QPLL_CFG2_C),
         QPLL_CFG2_G3_G     => (others => QPLL_CFG2_C),
         QPLL_CFG3_G        => (others => b"0000000100100000"),
         QPLL_CFG4_G        => (others => QPLL_CFG4_C),
         QPLL_CP_G          => (others => b"0011111111"),
         QPLL_CP_G3_G       => (others => b"0000001111"),
         QPLL_FBDIV_G       => (others => QPLL_FBDIV_C),
         QPLL_FBDIV_G3_G    => (others => 160),
         QPLL_INIT_CFG0_G   => (others => b"0000001010110010"),
         QPLL_INIT_CFG1_G   => (others => b"00000000"),
         QPLL_LOCK_CFG_G    => (others => b"0010010111101000"),
         QPLL_LOCK_CFG_G3_G => (others => b"0010010111101000"),
         QPLL_LPF_G         => (others => QPLL_LPF_C),
         QPLL_LPF_G3_G      => (others => b"0111010101"),
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
