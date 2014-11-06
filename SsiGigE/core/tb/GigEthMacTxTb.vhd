library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.GigEthPkg.all;

entity GigEthMacTxTb is end GigEthMacTxTb;

architecture testbed of GigEthMacTxTb is

   constant CLK_PERIOD_C : time := 8 ns;
   constant TPD_C        : time := CLK_PERIOD_C/4;

   signal clk,
      rst : sl := '0';

   signal dataIn        : slv(7 downto 0) := x"00";
   signal dataValid     : sl := '0';
   signal dataAck       : sl := '0';
   signal ethMacDataOut : EthMacDataType;
   signal count         : slv(7 downto 0);
   
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
         userDataAck       => dataAck,
         -- Data out to the GTX
         ethMacDataOut     => ethMacDataOut
      );
      
   process(clk,rst) begin
      if rising_edge(clk) then
         if (rst = '1') then
            dataValid <= '0';
            dataIn    <= x"00";
            count     <= (others => '0');
         else 
            count <= count+1;
            -- Example ARP packet, no checksum
            case CONV_INTEGER(count-10) is
               when  0 => dataIn <= x"FF";
               when  1 => dataIn <= x"FF";
               when  2 => dataIn <= x"FF";
               when  3 => dataIn <= x"FF";
               when  4 => dataIn <= x"FF";
               when  5 => dataIn <= x"FF";
               when  6 => dataIn <= x"00";
               when  7 => dataIn <= x"E0";
               when  8 => dataIn <= x"B3";
               when  9 => dataIn <= x"10";
               when 10 => dataIn <= x"00";
               when 11 => dataIn <= x"F8";
               when 12 => dataIn <= x"54";
               when 13 => dataIn <= x"08";
               when 14 => dataIn <= x"06";
               when 15 => dataIn <= x"00";
               when 16 => dataIn <= x"01";
               when 17 => dataIn <= x"08";
               when 18 => dataIn <= x"00";
               when 19 => dataIn <= x"06";
               when 20 => dataIn <= x"04";
               when 21 => dataIn <= x"00";
               when 22 => dataIn <= x"01";
               when 23 => dataIn <= x"00";
               when 24 => dataIn <= x"E0";
               when 25 => dataIn <= x"B3";               
               when 26 => dataIn <= x"10";
               when 27 => dataIn <= x"F8";
               when 28 => dataIn <= x"54";
               when 29 => dataIn <= x"C0";
               when 30 => dataIn <= x"A8";
               when 31 => dataIn <= x"01";
               when 32 => dataIn <= x"02";
               when 33 => dataIn <= x"FF";
               when 34 => dataIn <= x"FF";
               when 35 => dataIn <= x"FF";
               when 36 => dataIn <= x"FF";
               when others => dataIn <= x"AA";
            end case;
            if (count-10 <= 36) then
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
