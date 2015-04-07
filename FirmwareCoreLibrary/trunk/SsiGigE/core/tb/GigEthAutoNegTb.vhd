library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;

entity GigEthAutoNegTb is end GigEthAutoNegTb;

architecture testbed of GigEthAutoNegTb is

   constant CLK_PERIOD_C : time := 8 ns;
   constant TPD_C        : time := CLK_PERIOD_C/4;

   signal clk,
      rst : sl := '0';

   signal txDataB  : slv(15 downto 0);
   signal txDataKB : slv(1 downto 0);
   signal txDataA  : slv(15 downto 0);
   signal txDataKA : slv(1 downto 0);
   signal sync     : sl;
   signal doneA    : sl;
   signal doneB    : sl;
   
begin

   -- Generate clocks and resets
   ClkRst_Inst : entity work.ClkRst
      generic map (
         CLK_PERIOD_G      => CLK_PERIOD_C,
         RST_START_DELAY_G => 0 ns,     -- Wait this long into simulation before asserting reset
         RST_HOLD_TIME_G   => 745 ns)   -- Hold reset for this long)
      port map (
         clkP => clk,
         clkN => open,
         rst  => rst,
         rstL => open); 

   sync <= '1';
         
   U_GigEthAutoNeg_A : entity work.GigEthAutoNeg
      port map (
         -- System clock, reset & control
         ethRxClk          => clk,
         ethRxClkRst       => rst,
         -- Link is ready
         ethRxLinkReady    => doneA,
         -- Link is stable
         ethRxLinkSync     => sync,
         -- Physical Interface Signals
         phyRxData         => txDataB,
         phyRxDataK        => txDataKB,
         phyTxData         => txDataA,
         phyTxDataK        => txDataKA
      );
   U_GigEthAutoNeg_B : entity work.GigEthAutoNeg         
      port map (
         -- System clock, reset & control
         ethRxClk          => clk,
         ethRxClkRst       => rst,
         -- Link is ready
         ethRxLinkReady    => doneB,
         -- Link is stable
         ethRxLinkSync     => sync,
         -- Physical Interface Signals
         phyRxData         => txDataA,
         phyRxDataK        => txDataKA,
         phyTxData         => txDataB,
         phyTxDataK        => txDataKB
      );   

   -- process(failed, passed)
   -- begin
      -- if failed = '1' then
         -- assert false
            -- report "Simulation Failed!" severity failure;
      -- end if;
      -- if passed = '1' then
         -- assert false
            -- report "Simulation Passed!" severity failure;
      -- end if;
   -- end process;

end testbed;
