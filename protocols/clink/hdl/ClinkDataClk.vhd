-------------------------------------------------------------------------------
-- File       : ClinkDataClk.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-10-28
-- Last update: 2016-08-24
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

use work.StdRtlPkg.all;

entity ClinkDataClk is
   generic ( 
      TPD_G         : time    := 1 ns;
      REG_BUFF_EN_G : boolean := false);
   port (
      clkIn      : in  sl;
      rstIn      : in  sl;
      clinkClk7x : out sl;
      clinkClk   : out sl;
      clinkRst   : out sl);
end entity ClinkDataClk;

architecture rtl of ClinkDataClk is

   signal clkInLoc   : sl;
   signal clkOutMmcm : slv(1 downto 0);
   signal clkOutLoc  : slv(1 downto 0);
   signal clkFbOut   : sl;
   signal clkFbIn    : sl;
   signal lockedLoc  : sl;
   signal genReset   : sl;

begin

   U_Mmcm : MMCME2_ADV
      generic map (
         BANDWIDTH          => "OPTIMIZED",
         CLKOUT4_CASCADE    => false,
         STARTUP_WAIT       => false,
         CLKIN1_PERIOD      => 11.764,  -- 85Mhz
         DIVCLK_DIVIDE      => 1,  
         CLKFBOUT_MULT_F    => 14.0,  -- 1190Mhz
         CLKOUT0_DIVIDE_F   => 14.0,  -- 85Mhz
         CLKOUT1_DIVIDE     => 2)     -- 595Mhz
      port map (
         DCLK     => '0',
         DRDY     => open,
         DEN      => '0',
         DWE      => '0',
         DADDR    => (others=>'0'),
         DI       => (others=>'0'),
         DO       => open,
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

   U_RegGen: if REG_BUFF_EN_G generate

      U_BufIn : BUFR
         port map (
            CE  => '0',
            CLR => '0',
            I   => clkIn,
            O   => clkInLoc);

      U_BufFb : BUFR
         port map (
            CE  => '0',
            CLR => '0',
            I   => clkFbOut,
            O   => clkFbIn);

      U_BufOut : BUFR
         port map (
            CE  => '0',
            CLR => '0',
            I   => clkOutMmcm(0),
            O   => clkOutLoc(0));

      U_BufIo : BUFIO
         port map (
            I   => clkOutMmcm(1),
            O   => clkOutLoc(1));

   end generate;

   U_GlbGen: if not REG_BUFF_EN_G generate

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
            I   => clkOutMmcm(1),
            O   => clkOutLoc(1));

   end generate;

   genReset <= lockedLoc and (not rstIn);

   U_RstSync : entity work.RstSync
      generic map (
         TPD_G           => TPD_G,
         IN_POLARITY_G   => '0',
         OUT_POLARITY_G  => '1',
         BYPASS_SYNC_G   => false)
      port map (
         clk      => clkOutLoc(0),
         asyncRst => genReset,
         syncRst  => clinkRst);

   clinkClk   <= clkOutLoc(0);
   clinkClk7x <= clkOutLoc(1);

end architecture rtl;

