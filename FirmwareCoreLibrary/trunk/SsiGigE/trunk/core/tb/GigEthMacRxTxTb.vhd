library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.GigEthPkg.all;

entity GigEthMacRxTxTb is end GigEthMacRxTxTb;

architecture testbed of GigEthMacRxTxTb is

   constant CLK_PERIOD_C : time := 8 ns;
   constant TPD_C        : time := CLK_PERIOD_C/4;

   signal clk,
      rst : sl := '0';

   signal dataIn        : slv(7 downto 0) := x"00";
   signal dataValid     : sl := '0';
   signal ethMacDataOut : EthMacDataType;
   signal count         : slv(7 downto 0);
   
   signal rxDataOut     : slv(7 downto 0);
   signal rxDataValid   : sl;
   signal rxDataGood    : sl;
   signal rxDataBad     : sl;
   
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
         
   U_GigEthMacTx : entity work.GigEthMacTx
      port map (
         -- 125 MHz ethernet clock in
         ethTxClk          => clk,
         ethTxRst          => rst,
         -- User data to be sent
         userDataIn        => dataIn,
         userDataValid     => dataValid,
         userDataFirstByte => '0',
         userDataAck       => open,
         -- Data out to the GTX
         ethMacDataOut     => ethMacDataOut
      );

   U_GigEthMacRx : entity work.GigEthMacRx
      port map (
         -- 125 MHz ethernet clock in
         ethRxClk          => clk,
         ethRxRst          => rst,
         -- Incoming data from the 16-to-8 mux
         ethMacDataIn      => ethMacDataOut,
         -- Outgoing bytes and flags to the applications
         ethMacRxData      => rxDataOut,
         ethMacRxValid     => rxDataValid,
         ethMacRxGoodFrame => rxDataGood,
         ethMacRxBadFrame  => rxDataBad
      );

      
   process(clk,rst) begin
      if rising_edge(clk) then
         if (rst = '1') then
            dataValid <= '0';
            dataIn    <= x"00";
            count     <= (others => '0');
         else 
            count <= count+1;
            dataIn    <= count;
            if (count > 10 and count < 20) then
               dataValid <= '1';
            else
               dataValid <= '0';
            end if;
         end if;
      end if;
   end process;

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
