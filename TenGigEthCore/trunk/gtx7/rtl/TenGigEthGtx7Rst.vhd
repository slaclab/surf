-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : TenGigEthGtx7Rst.vhd
-- Author     : Larry Ruckman <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-03-30
-- Last update: 2015-03-30
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2015 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;

library unisim;
use unisim.vcomponents.all;

entity TenGigEthGtx7Rst is
   generic (
      TPD_G : time := 1 ns);
   port (
      -- Clocks and Resets
      extRst     : in  sl;              -- async reset
      phyClk     : in  sl;
      phyRst     : in  sl;
      txClk322   : in  sl;
      txUsrClk   : out sl;
      txUsrClk2  : out sl;
      gtTxRst    : out sl;
      gtRxRst    : out sl;
      txUsrRdy   : out sl;
      rstCntDone : out sl;
      -- Quad PLL Ports
      qplllock   : in  sl;
      qpllRst    : out sl);      
end TenGigEthGtx7Rst;

architecture rtl of TenGigEthGtx7Rst is

   signal txClock : sl;
   signal txReset : sl;
   signal txReady : sl;

   signal rstCnt   : slv(7 downto 0) := x"00";
   signal rstPulse : slv(3 downto 0) := "1110";

begin

   txUsrClk  <= txClock;
   txUsrClk2 <= txClock;

   rstCntDone <= rstCnt(7);
   gtTxRst    <= rstPulse(0);
   gtRxRst    <= rstPulse(0);
   qpllRst    <= rstPulse(0);

   CLK312_BUFG : BUFG
      port map (
         I => txClk322,
         O => txClock);  

   Synchronizer_1 : entity work.Synchronizer
      generic map(
         TPD_G          => TPD_G,
         RST_ASYNC_G    => true,
         RST_POLARITY_G => '0',
         STAGES_G       => 4,
         INIT_G         => "0000")
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
         STAGES_G       => 4,
         INIT_G         => "1111")
      port map (
         clk     => txClock,
         rst     => rstPulse(0),
         dataIn  => '0',
         dataOut => txReset);  

   process(phyClk)
   begin
      if rising_edge(phyClk) then
         -- Hold off release the GT resets until 500ns after configuration.
         -- 128 ticks at 6.4ns period will be >> 500 ns.
         if rstCnt(7) = '0' then
            rstCnt <= rstCnt + 1 after TPD_G;
         else
            rstCnt <= rstCnt after TPD_G;
         end if;
         -- Check for reset
         if phyRst = '1' then
            rstPulse <= "1110" after TPD_G;
         elsif rstCnt(7) = '1' then
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
