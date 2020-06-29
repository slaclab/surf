-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: A wrapper over MMCM
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
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;
use ieee.math_real.all;

library unisim;
use unisim.vcomponents.all;


library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;

entity ClinkDataClk is
   generic (
      TPD_G         : time    := 1 ns;
      REG_BUFF_EN_G : boolean := false);
   port (
      clkIn           : in  sl;
      rstIn           : in  sl;
      clinkClk7x      : out sl;
      clinkClk        : out sl;
      clinkRst        : out sl;
      -- AXI-Lite Interface
      sysClk          : in  sl;
      sysRst          : in  sl;
      axilReadMaster  : in  AxiLiteReadMasterType;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType;
      axilWriteSlave  : out AxiLiteWriteSlaveType);
end entity ClinkDataClk;

architecture rtl of ClinkDataClk is

   signal clkInLoc   : sl;
   signal clkOutMmcm : slv(1 downto 0);
   signal clkOutLoc  : slv(1 downto 0);
   signal clkFbOut   : sl;
   signal clkFbIn    : sl;
   signal lockedLoc  : sl;
   signal genReset   : sl;

   signal drpRdy  : sl;
   signal drpEn   : sl;
   signal drpWe   : sl;
   signal drpAddr : slv(6 downto 0);
   signal drpDi   : slv(15 downto 0);
   signal drpDo   : slv(15 downto 0);

begin

   U_AxiLiteToDrp : entity surf.AxiLiteToDrp
      generic map (
         TPD_G            => TPD_G,
         COMMON_CLK_G     => true,
         EN_ARBITRATION_G => false,
         TIMEOUT_G        => 4096,
         ADDR_WIDTH_G     => 7,
         DATA_WIDTH_G     => 16)
      port map (
         -- AXI-Lite Port
         axilClk         => sysClk,
         axilRst         => sysRst,
         axilReadMaster  => axilReadMaster,
         axilReadSlave   => axilReadSlave,
         axilWriteMaster => axilWriteMaster,
         axilWriteSlave  => axilWriteSlave,
         -- DRP Interface
         drpClk          => sysClk,
         drpRst          => sysRst,
         drpRdy          => drpRdy,
         drpEn           => drpEn,
         drpWe           => drpWe,
         drpAddr         => drpAddr,
         drpDi           => drpDi,
         drpDo           => drpDo);

   U_Mmcm : MMCME3_ADV
      generic map (
         BANDWIDTH        => "OPTIMIZED",
         CLKOUT4_CASCADE  => "FALSE",
         STARTUP_WAIT     => "FALSE",
--         CLKIN1_PERIOD    => 40.0,      -- 25 MHz
--         DIVCLK_DIVIDE    => 1,
--         CLKFBOUT_MULT_F  => 42.0,      -- VCO = 1050MHz
--         CLKOUT0_DIVIDE_F => 42.0,      -- 25 MHz
--         CLKOUT1_DIVIDE   => 6)         -- 175MHz
         CLKIN1_PERIOD    => 11.764,  -- 85 MHz (CLKIN[min.] = 43 MHz, CLKIN[max] = 102 MHz)
         DIVCLK_DIVIDE    => 1,
         CLKFBOUT_MULT_F  => 14.0,  -- VCO = 1190MHz (VCO[min] = 600 MHz, VCO[max] = 1440 MHz)
         CLKOUT0_DIVIDE_F => 14.0,      -- 85 MHz = 1190MHz/14
         CLKOUT1_DIVIDE   => 2)         -- 595MHz = 1190MHz/2
      port map (
         DCLK     => sysClk,
         DRDY     => drpRdy,
         DEN      => drpEn,
         DWE      => drpWe,
         DADDR    => drpAddr,
         DI       => drpDi,
         DO       => drpDo,
         CDDCREQ  => '0',
         PSCLK    => '0',
         PSEN     => '0',
         PSINCDEC => '0',
         PWRDWN   => '0',
         RST      => rstIn,
         CLKIN1   => clkInLoc,
         CLKIN2   => '0',
         CLKINSEL => '1',
         CLKFBOUT => clkFbOut,
         CLKFBIN  => clkFbIn,
         LOCKED   => lockedLoc,
         CLKOUT0  => clkOutMmcm(0),
         CLKOUT1  => clkOutMmcm(1));

   U_RegGen : if REG_BUFF_EN_G generate

      U_BufIn : BUFG
         port map (
            I   => clkIn,
            O   => clkInLoc);

      U_BufFb : BUFG
         port map (
            I   => clkFbOut,
            O   => clkFbIn);

      U_BufOut : BUFG
         port map (
            I   => clkOutMmcm(0),
            O   => clkOutLoc(0));

      U_BufIo : BUFG
         port map (
            I => clkOutMmcm(1),
            O => clkOutLoc(1));

   end generate;

   U_GlbGen : if not REG_BUFF_EN_G generate

      U_BufIn : BUFG
         port map (
            I => clkIn,
            O => clkInLoc);

      U_BufFb : BUFG
         port map (
            I => clkFbOut,
            O => clkFbIn);

      U_BufOut : BUFG
         port map (
            I => clkOutMmcm(0),
            O => clkOutLoc(0));

      U_BufIo : BUFG
         port map (
            I => clkOutMmcm(1),
            O => clkOutLoc(1));

   end generate;

   genReset <= lockedLoc and (not rstIn);

   U_RstSync : entity surf.RstSync
      generic map (
         TPD_G          => TPD_G,
         IN_POLARITY_G  => '0',
         OUT_POLARITY_G => '1',
         BYPASS_SYNC_G  => false)
      port map (
         clk      => clkOutLoc(0),
         asyncRst => genReset,
         syncRst  => clinkRst);

   clinkClk   <= clkOutLoc(0);
   clinkClk7x <= clkOutLoc(1);

end rtl;
