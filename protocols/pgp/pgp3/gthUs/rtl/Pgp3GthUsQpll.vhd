-------------------------------------------------------------------------------
-- Title      : PGPv3: https://confluence.slac.stanford.edu/x/OndODQ
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: PGPv3 GTH Ultrascale QPLL Wrapper
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
use surf.Pgp3Pkg.all;

library unisim;
use unisim.vcomponents.all;

entity Pgp3GthUsQpll is
   generic (
      TPD_G             : time            := 1 ns;
      REFCLK_FREQ_G     : real            := 156.25E+6;
      RATE_G            : string          := "10.3125Gbps";  -- or "6.25Gbps" or "3.125Gbps"
      QPLL_REFCLK_SEL_G : slv(2 downto 0) := "001";
      EN_DRP_G          : boolean         := true);
   port (
      -- Stable Clock and Reset
      stableClk       : in  sl;         -- GT needs a stable clock to "boot up"
      stableRst       : in  sl;
      -- QPLL Clocking
      pgpRefClk       : in  sl;         -- REFCLK_FREQ_G
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
   constant QPLL_CONFIG_INIT_C : QpllConfig := (
      QPLL_CFG0        => "0011001000011100",
      QPLL_CFG1        => "0001000000011000",
      QPLL_CFG1_G3     => "0001000000011000",
      QPLL_CFG2        => "0000000001001000",
      QPLL_CFG2_G3     => "0000000001001000",
      QPLL_CFG3        => "0000000100100000",
      QPLL_CFG4        => "0000000000001001",
      QPLL_CP          => "0000011111",
      QPLL_CP_G3       => "1111111111",
      QPLL_FBDIV       => 66,
      QPLL_FBDIV_G3    => 80,
      QPLL_INIT_CFG0   => "0000001010110010",
      QPLL_INIT_CFG1   => "00000000",
      QPLL_LOCK_CFG    => "0010000111101000",
      QPLL_LOCK_CFG_G3 => "0010000111101000",
      QPLL_LPF         => "1111111100",
      QPLL_LPF_G3      => "0000010101",
      QPLL_REFCLK_DIV  => 1);
   function getQpllConfig (refClkFreq : real; rate : string) return QpllConfig is
      variable retVar : QpllConfig;
   begin
      -- Init
      retVar := QPLL_CONFIG_INIT_C;

      ----------------------------------------
      -- Check for 156.25 MHz or 312.5 MHz OSC
      ----------------------------------------
      if (refClkFreq = 156.25E+6) or (refClkFreq = 312.5E+6) then

         -- Check for 15 Gb/s rate
         if (RATE_G = "15.46875Gbps") then
            retVar.QPLL_CFG4        := "0000000000011011";
            retVar.QPLL_CP          := "0111111111";
            retVar.QPLL_FBDIV       := 99;
            retVar.QPLL_LOCK_CFG    := "0010010111101000";
            retVar.QPLL_LOCK_CFG_G3 := "0010010111101000";

         -- Check for non-10Gb/s rate
         elsif (rate /= "10.3125Gbps") then
            retVar.QPLL_CP    := "0111111111";
            retVar.QPLL_FBDIV := 80;
         end if;

         -- Check for double rate OSC
         if (refClkFreq = 312.5E+6) then
            retVar.QPLL_REFCLK_DIV := 2;
         end if;

      ------------------------------------
      -- Else 185.71 MHz or 371.42 MHz OSC
      ------------------------------------
      else

         -- Only support 10.3125 Gb/s
         assert (rate = "10.3125Gbps")
            report "Pgp3GthUsQpll.getQpllConfig(): (RATE_G = 10.3125Gbps) condition not meet"
            severity error;

         -- Init
         retVar.QPLL_CP    := "0111111111";
         retVar.QPLL_FBDIV := 111;

         -- Check for OSC Frequency
         if (refClkFreq = 185.7142855E+6) then
            retVar.QPLL_REFCLK_DIV := 2;
         else
            retVar.QPLL_REFCLK_DIV := 4;
         end if;

      end if;

      -- Return the configuration
      return(retVar);
   end function;

   constant QPLL_CONFIG_C : QpllConfig := getQpllConfig(REFCLK_FREQ_G, RATE_G);

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

   assert ((REFCLK_FREQ_G = 156.25E+6) or (REFCLK_FREQ_G = 185.7142855E+6) or (REFCLK_FREQ_G = 312.5E+6) or (REFCLK_FREQ_G = 371.428571E+6))
      report "REFCLK_FREQ_G: Must be either 156.25E+6, 185.7142855E+6, 312.5E+6 or 371.428571E+6"
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
         QPLL_CFG0_G        => (others => QPLL_CONFIG_C.QPLL_CFG0),
         QPLL_CFG1_G        => (others => QPLL_CONFIG_C.QPLL_CFG1),
         QPLL_CFG1_G3_G     => (others => QPLL_CONFIG_C.QPLL_CFG1_G3),
         QPLL_CFG2_G        => (others => QPLL_CONFIG_C.QPLL_CFG2),
         QPLL_CFG2_G3_G     => (others => QPLL_CONFIG_C.QPLL_CFG2_G3),
         QPLL_CFG3_G        => (others => QPLL_CONFIG_C.QPLL_CFG3),
         QPLL_CFG4_G        => (others => QPLL_CONFIG_C.QPLL_CFG4),
         QPLL_CP_G          => (others => QPLL_CONFIG_C.QPLL_CP),
         QPLL_CP_G3_G       => (others => QPLL_CONFIG_C.QPLL_CP_G3),
         QPLL_FBDIV_G       => (others => QPLL_CONFIG_C.QPLL_FBDIV),
         QPLL_FBDIV_G3_G    => (others => QPLL_CONFIG_C.QPLL_FBDIV_G3),
         QPLL_INIT_CFG0_G   => (others => QPLL_CONFIG_C.QPLL_INIT_CFG0),
         QPLL_INIT_CFG1_G   => (others => QPLL_CONFIG_C.QPLL_INIT_CFG1),
         QPLL_LOCK_CFG_G    => (others => QPLL_CONFIG_C.QPLL_LOCK_CFG),
         QPLL_LOCK_CFG_G3_G => (others => QPLL_CONFIG_C.QPLL_LOCK_CFG_G3),
         QPLL_LPF_G         => (others => QPLL_CONFIG_C.QPLL_LPF),
         QPLL_LPF_G3_G      => (others => QPLL_CONFIG_C.QPLL_LPF_G3),
         QPLL_REFCLK_DIV_G  => (others => QPLL_CONFIG_C.QPLL_REFCLK_DIV),
         -- Clock Selects
         QPLL_REFCLK_SEL_G  => (others => QPLL_REFCLK_SEL_G))
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
