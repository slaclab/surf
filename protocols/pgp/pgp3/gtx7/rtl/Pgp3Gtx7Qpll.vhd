-------------------------------------------------------------------------------
-- Title      : PGPv3: https://confluence.slac.stanford.edu/x/OndODQ
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: PGPv3 GTX7's QPLL Wrapper
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

entity Pgp3Gtx7Qpll is
   generic (
      TPD_G         : time           := 1 ns;
      EN_DRP_G      : boolean        := true;
      REFCLK_FREQ_G : real           := 312.5E+6;
      RATE_G        : string         := "10.3125Gbps");  -- or "6.25Gbps" or "3.125Gbps"
   port (
      -- Stable Clock and Reset
      stableClk       : in  sl;         -- GT needs a stable clock to "boot up"
      stableRst       : in  sl;
      -- QPLL Clocking
      pgpRefClk       : in  sl;
      qpllLock        : out slv(3 downto 0);
      qpllClk         : out slv(3 downto 0);
      qpllRefclk      : out slv(3 downto 0);
      qpllRefClkLost  : out slv(3 downto 0);
      qpllRst         : in  slv(3 downto 0);
      -- AXI-Lite Interface
      axilClk         : in  sl                     := '0';
      axilRst         : in  sl                     := '0';
      axilReadMaster  : in  AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
      axilReadSlave   : out AxiLiteReadSlaveType   := AXI_LITE_READ_SLAVE_EMPTY_DECERR_C;
      axilWriteMaster : in  AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
      axilWriteSlave  : out AxiLiteWriteSlaveType  := AXI_LITE_WRITE_SLAVE_EMPTY_DECERR_C);
end Pgp3Gtx7Qpll;

architecture mapping of Pgp3Gtx7Qpll is

   impure function GenQpllfbdivTop return integer is
   begin
      -------------------------------
      -- RATE_G = 10.3125Gbps
      -------------------------------
      if ((RATE_G = "10.3125Gbps")) then
         if (REFCLK_FREQ_G = 312.5E+6) then
            return 66;
         elsif (REFCLK_FREQ_G = 156.25E+6) then
            return 66;
         else
            return -1;
         end if;
      -----------------------------
      -- RATE_G = 6.25Gbps or 3.125Gbps
      -----------------------------
      else
         if (REFCLK_FREQ_G = 312.5E+6) then
            return 40;
         elsif (REFCLK_FREQ_G = 156.25E+6) then
            return 40;
         elsif (REFCLK_FREQ_G = 250.0E+6) then
            return 100;
         elsif (REFCLK_FREQ_G = 125.0E+6) then
            return 100;
         else
            return -1;
         end if;
      end if;
   end function;

   impure function GenQplFfbdivTop (qpllfbdivTop : in positive) return bit_vector is
   begin
      if (qpllfbdivTop = 16) then
         return "0000100000";
      elsif (qpllfbdivTop = 20) then
         return "0000110000";
      elsif (qpllfbdivTop = 32) then
         return "0001100000";
      elsif (qpllfbdivTop = 40) then
         return "0010000000";
      elsif (qpllfbdivTop = 64) then
         return "0011100000";
      elsif (qpllfbdivTop = 66) then
         return "0101000000";
      elsif (qpllfbdivTop = 80) then
         return "0100100000";
      elsif (qpllfbdivTop = 100) then
         return "0101110000";
      else
         return "0000000000";
      end if;
   end function;

   impure function GenQpllFbdivRatio (qpllfbdivTop : in positive) return bit is
   begin
      if (qpllfbdivTop = 16) then
         return '1';
      elsif (qpllfbdivTop = 20) then
         return '1';
      elsif (qpllfbdivTop = 32) then
         return '1';
      elsif (qpllfbdivTop = 40) then
         return '1';
      elsif (qpllfbdivTop = 64) then
         return '1';
      elsif (qpllfbdivTop = 66) then
         return '0';
      elsif (qpllfbdivTop = 80) then
         return '1';
      elsif (qpllfbdivTop = 100) then
         return '1';
      else
         return '1';
      end if;
   end function;

   impure function GenRefclkDiv return integer is
   begin
      -------------------------------
      -- RATE_G = 10.3125Gbps
      -------------------------------
      if (RATE_G = "10.3125Gbps") then
         if (REFCLK_FREQ_G = 312.5E+6) then
            return 2;
         elsif (REFCLK_FREQ_G = 156.25E+6) then
            return 1;
         else
            return -1;
         end if;
      -----------------------------
      -- RATE_G = 6.25Gbps or 3.125Gbps
      -----------------------------
      else
         if (REFCLK_FREQ_G = 312.5E+6) then
            return 2;
         elsif (REFCLK_FREQ_G = 156.25E+6) then
            return 1;
         elsif (REFCLK_FREQ_G = 250.0E+6) then
            return 4;
         elsif (REFCLK_FREQ_G = 125.0E+6) then
            return 2;
         else
            return -1;
         end if;
      end if;
   end function;

   constant QPLL_CFG_C         : bit_vector := ite((RATE_G = "10.3125Gbps"), x"0680181", x"06801C1");
   constant QPLL_FBDIV_TOP_C   : positive   := GenQpllfbdivTop;
   constant QPLL_FBDIV_C       : bit_vector := GenQplFfbdivTop(QPLL_FBDIV_TOP_C);
   constant QPLL_FBDIV_RATIO_C : bit        := GenQpllFbdivRatio(QPLL_FBDIV_TOP_C);
   constant QPLL_REFCLK_DIV_C  : positive   := GenRefclkDiv;

   signal pllOutClk     : sl;
   signal pllOutRefClk  : sl;
   signal pllLock       : sl;
   signal pllRefClkLost : sl;
   signal pllReset      : sl;
   signal lockedStrobe  : slv(3 downto 0);
   signal gtQPllReset   : slv(3 downto 0);

begin

   GEN_VEC :
   for i in 3 downto 0 generate

      qpllClk(i)        <= pllOutClk;
      qpllRefclk(i)     <= pllOutRefClk;
      qpllRefClkLost(i) <= pllRefClkLost;
      qpllLock(i)       <= pllLock and not(lockedStrobe(i));  -- trick the GT state machine of lock transition

      ----------------------------------------------------------------------------
      -- Prevent the gtQPllRst of this lane disrupting the other lanes in the QUAD
      ----------------------------------------------------------------------------
      U_PwrUpRst : entity surf.PwrUpRst
         generic map (
            TPD_G      => TPD_G,
            DURATION_G => 12500)
         port map (
            arst   => qpllRst(i),
            clk    => stableClk,
            rstOut => lockedStrobe(i));

      gtQPllReset(i) <= qpllRst(i) and not (pllLock);

   end generate GEN_VEC;

   pllReset <= uOr(gtQPllReset) or stableRst;

   U_QPLL : entity surf.Gtx7QuadPll
      generic map (
         TPD_G              => TPD_G,
         EN_DRP_G           => EN_DRP_G,
         QPLL_CFG_G         => QPLL_CFG_C,
         QPLL_FBDIV_G       => QPLL_FBDIV_C,
         QPLL_FBDIV_RATIO_G => QPLL_FBDIV_RATIO_C,
         QPLL_REFCLK_DIV_G  => QPLL_REFCLK_DIV_C)
      port map (
         qPllRefClk      => pgpRefClk,
         qPllOutClk      => pllOutClk,
         qPllOutRefClk   => pllOutRefClk,
         qPllLock        => pllLock,
         qPllLockDetClk  => stableClk,
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
