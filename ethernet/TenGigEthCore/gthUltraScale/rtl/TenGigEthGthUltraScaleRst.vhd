-------------------------------------------------------------------------------
-- File       : TenGigEthGthUltraScaleRst.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-05-04
-- Last update: 2015-12-03
-------------------------------------------------------------------------------
-- Description: 10GBASE-R Ethernet Reset Module
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

use work.StdRtlPkg.all;

library unisim;
use unisim.vcomponents.all;

entity TenGigEthGthUltraScaleRst is
   generic (
      TPD_G : time := 1 ns);
   port (
      extRst      : in  sl;
      coreClk     : in  sl;
      coreRst     : out sl;
      phyClk      : out sl;
      phyRst      : out sl;
      txBufgGtRst : in  sl;
      qplllock    : in  sl;
      txClk322    : in  sl;
      txUsrClk    : out sl;
      txUsrClk2   : out sl;
      gtTxRst     : out sl;
      gtRxRst     : out sl;
      txUsrRdy    : out sl;
      rstCntDone  : out sl);      
end TenGigEthGthUltraScaleRst;

architecture rtl of TenGigEthGthUltraScaleRst is

   signal coreReset : sl;
   signal phyReset  : sl;
   signal txClockGt : sl;
   signal txClock   : sl;
   signal txReset   : sl;
   signal txReady   : sl;

   signal rstCnt   : slv(15 downto 0) := (others => '0');
   signal rstPulse : slv(3 downto 0)  := "1110";

begin

   -- Clock Outputs
   txUsrClk2 <= txClock;
   phyClk    <= txClock;

   -- Reset Outputs
   coreRst    <= coreReset;
   phyRst     <= txReset;
   rstCntDone <= rstCnt(15);
   gtTxRst    <= rstPulse(0);
   gtRxRst    <= rstPulse(0);

   Synchronizer_0 : entity work.Synchronizer
      generic map(
         TPD_G          => TPD_G,
         RST_ASYNC_G    => true,
         RST_POLARITY_G => '1',
         STAGES_G       => 5,
         INIT_G         => "11111")
      port map (
         clk     => coreClk,
         rst     => extRst,
         dataIn  => '0',
         dataOut => coreReset);    

   CLK312_BUFG_GT : BUFG_GT
      port map (
         I       => txclk322,
         CE      => '1',
         CEMASK  => '1',
         CLR     => txBufgGtRst,
         CLRMASK => '0',
         DIV     => "000",
         O       => txUsrClk);   

   CLK156_BUFG_GT : BUFG_GT
      port map (
         I       => txclk322,
         CE      => '1',
         CEMASK  => '1',
         CLR     => txBufgGtRst,
         CLRMASK => '0',
         DIV     => "001",
         O       => txClockGt);   

   CLK156_BUFG : BUFG
      port map (
         I => txClockGt,
         O => txClock);           

   Synchronizer_1 : entity work.Synchronizer
      generic map(
         TPD_G          => TPD_G,
         RST_ASYNC_G    => true,
         RST_POLARITY_G => '0',
         STAGES_G       => 5,
         INIT_G         => "00000")
      port map (
         clk     => txClock,
         rst     => qPllLock,
         dataIn  => '1',
         dataOut => txReady);           

   Synchronizer_2 : entity work.Synchronizer
      generic map(
         TPD_G          => TPD_G,
         RST_ASYNC_G    => true,
         RST_POLARITY_G => '1',
         STAGES_G       => 5,
         INIT_G         => "11111")
      port map (
         clk     => txClock,
         rst     => rstPulse(0),
         dataIn  => '0',
         dataOut => txReset);  

   process(coreClk)
   begin
      if rising_edge(coreClk) then
         -- Hold off release the GT resets until 500ns after configuration.
         -- 256 ticks at the minimum possible 2.56ns period (390MHz) will be >> 500 ns.
         if rstCnt(15) = '0' then
            rstCnt <= rstCnt + 1 after TPD_G;
         else
            rstCnt <= rstCnt after TPD_G;
         end if;
         -- Check for reset
         if coreReset = '1' then
            rstPulse <= "1110" after TPD_G;
         elsif rstCnt(15) = '1' then
            rstPulse(3)          <= '0'                  after TPD_G;
            rstPulse(2 downto 0) <= rstPulse(3 downto 1) after TPD_G;
         end if;
      end if;
   end process;

   process(txClock)
   begin
      if rising_edge(txClock) then
         if txReset = '1' then
            txUsrRdy <= '0' after TPD_G;
         else
            txUsrRdy <= txReady after TPD_G;
         end if;
      end if;
   end process;

end rtl;
