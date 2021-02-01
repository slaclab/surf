-------------------------------------------------------------------------------
-- Title      : PGPv3: https://confluence.slac.stanford.edu/x/OndODQ
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: PGPv3 GTP7 QPLL Wrapper
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

entity Pgp3Gtp7Qpll is
   generic (
      TPD_G         : time           := 1 ns;
      EN_DRP_G      : boolean        := true;
      REFCLK_FREQ_G : real           := 250.0E+6;
      RATE_G        : string         := "6.25Gbps");  -- or "3.125Gbps"
   port (
      -- Stable Clock and Reset
      stableClk       : in  sl;         -- GT needs a stable clock to "boot up"
      stableRst       : in  sl;
      -- QPLL Clocking
      pgpRefClk       : in  sl;
      qPllOutClk      : out Slv2Array(3 downto 0);
      qPllOutRefClk   : out Slv2Array(3 downto 0);
      qPllLock        : out Slv2Array(3 downto 0);
      qPllRefClkLost  : out Slv2Array(3 downto 0);
      qpllRst         : in  Slv2Array(3 downto 0);
      -- AXI-Lite Interface
      axilClk         : in  sl                     := '0';
      axilRst         : in  sl                     := '0';
      axilReadMaster  : in  AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
      axilReadSlave   : out AxiLiteReadSlaveType   := AXI_LITE_READ_SLAVE_EMPTY_DECERR_C;
      axilWriteMaster : in  AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
      axilWriteSlave  : out AxiLiteWriteSlaveType  := AXI_LITE_WRITE_SLAVE_EMPTY_DECERR_C);
end Pgp3Gtp7Qpll;

architecture mapping of Pgp3Gtp7Qpll is

   ----------------------------------------------------------------
   -- | Ref Clk | FBDIV_IN_C | FBDIV_45_IN_C | REFCLK_DIV_IN_C | --
   ----------------------------------------------------------------
   -- |   312   |     4      |      5        |        2        | --
   -- |   156   |     4      |      5        |        1        | --
   -- |   250   |     5      |      5        |        2        | --
   -- |   125   |     5      |      5        |        1        | --
   ----------------------------------------------------------------

   impure function GenQpllFbDiv return integer is
   begin
      if (REFCLK_FREQ_G = 312.5E+6) or (REFCLK_FREQ_G = 156.25E+6) then
         return 4;
      elsif (REFCLK_FREQ_G = 250.0E+6) or (REFCLK_FREQ_G = 125.0E+6) then
         return 5;
      else
         return -1;
      end if;
   end function;
   constant FBDIV_IN_C : positive := GenQpllFbDiv;

   constant FBDIV_45_IN_C : positive := 5;

   impure function GenQpllRefDiv return integer is
   begin
      if (REFCLK_FREQ_G = 312.5E+6) or (REFCLK_FREQ_G = 250.0E+6) then
         return 2;
      elsif (REFCLK_FREQ_G = 156.25E+6) or (REFCLK_FREQ_G = 125.0E+6) then
         return 1;
      else
         return -1;
      end if;
   end function;
   constant REFCLK_DIV_IN_C : positive := GenQpllRefDiv;

   signal qPllRefClk     : slv(1 downto 0);
   signal qPllLockDetClk : slv(1 downto 0);
   signal pllOutClk      : slv(1 downto 0);
   signal pllOutRefClk   : slv(1 downto 0);
   signal pllLock        : slv(1 downto 0);
   signal pllRefClkLost  : slv(1 downto 0);
   signal pllReset       : slv(1 downto 0);
   signal lockedStrobe   : Slv2Array(3 downto 0);
   signal gtQPllReset    : Slv2Array(3 downto 0);

begin

   GEN_VEC :
   for i in 3 downto 0 generate
      GEN_SUB :
      for j in 1 downto 0 generate

         qPllOutClk(i)(j)     <= pllOutClk(j);
         qPllOutRefClk(i)(j)  <= pllOutRefClk(j);
         qpllRefClkLost(i)(j) <= pllRefClkLost(j);

         qpllLock(i)(j) <= pllLock(j) and not(lockedStrobe(i)(j));  -- trick the GT state machine of lock transition

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

      end generate GEN_SUB;
   end generate GEN_VEC;

   pllReset(0) <= gtQPllReset(0)(0) or gtQPllReset(1)(0) or gtQPllReset(2)(0) or gtQPllReset(3)(0) or stableRst;
   pllReset(1) <= stableRst;

   qPllRefClk     <= pgpRefClk & pgpRefClk;
   qPllLockDetClk <= stableClk & stableClk;

   U_QPLL : entity surf.Gtp7QuadPll
      generic map (
         TPD_G                => TPD_G,
         PLL0_FBDIV_IN_G      => FBDIV_IN_C,
         PLL0_FBDIV_45_IN_G   => FBDIV_45_IN_C,
         PLL0_REFCLK_DIV_IN_G => REFCLK_DIV_IN_C,
         PLL1_FBDIV_IN_G      => FBDIV_IN_C,
         PLL1_FBDIV_45_IN_G   => FBDIV_45_IN_C,
         PLL1_REFCLK_DIV_IN_G => REFCLK_DIV_IN_C)
      port map (
         qPllRefClk      => qPllRefClk,
         qPllOutClk      => pllOutClk,
         qPllOutRefClk   => pllOutRefClk,
         qPllLock        => pllLock,
         qPllLockDetClk  => qPllLockDetClk,
         qPllRefClkLost  => pllRefClkLost,
         qPllReset       => pllReset,
         -- AXI Lite interface
         axilClk         => axilClk,
         axilRst         => axilRst,
         axilReadMaster  => axilReadMaster,
         axilReadSlave   => axilReadSlave,
         axilWriteMaster => axilWriteMaster,
         axilWriteSlave  => axilWriteSlave);

end mapping;
