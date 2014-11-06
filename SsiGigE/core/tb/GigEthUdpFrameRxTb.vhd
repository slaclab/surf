library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.GigEthPkg.all;
use work.EthClientPackage.all;

use ieee.std_logic_textio.all;
library std;
use std.textio.all;

entity GigEthUdpFrameRxTb is end GigEthUdpFrameRxTb;

architecture testbed of GigEthUdpFrameRxTb is

   constant CLK_PERIOD_C : time := 8 ns;
   constant TPD_C        : time := CLK_PERIOD_C/4;

   signal ethClk125MHz    : sl;
   signal ethClk125MHzRst : sl;
   
   signal udpRxValid      : sl;
   signal udpRxData       : slv(7  downto 0);
   signal udpRxGood       : sl;
   signal udpRxError      : sl;
   signal udpRxCount      : slv(15 downto 0);
   
   signal userRxValid     : sl;
   signal userRxData      : slv(31 downto 0);
   signal userRxSOF       : sl;
   signal userRxEOF       : sl;
   signal userRxEOFE      : sl;
   signal userRxVc        : slv(1 downto 0);
   
   signal count : slv(15 downto 0) := (others => '0');
   
begin

   -- Generate clocks and resets
   ClkRst_Inst : entity work.ClkRst
      generic map (
         CLK_PERIOD_G      => CLK_PERIOD_C,
         RST_START_DELAY_G => 0 ns,     -- Wait this long into simulation before asserting reset
         RST_HOLD_TIME_G   => 10 ns)   -- Hold reset for this long)
      port map (
         clkP => ethClk125MHz,
         clkN => open,
         rst  => ethClk125MHzRst,
         rstL => open); 
         
   -- Dummy packet
   process(ethClk125MHz) begin
      if rising_edge(ethClk125MHz) then
         if (ethClk125MhzRst = '1') then
            count <= (others => '0');
         else
            if (count < 38) then
               count <= count + 1;         
            end if;
         end if;
         -- UDP packet here
         case conv_integer(count-10) is
            when  0 => udpRxData <= x"21";
            when  1 => udpRxData <= x"00";
            when  2 => udpRxData <= x"00";
            when  3 => udpRxData <= x"00";
            when  4 => udpRxData <= x"00";
            when  5 => udpRxData <= x"1A";
            when  6 => udpRxData <= x"D6";
            when  7 => udpRxData <= x"7D";
            when  8 => udpRxData <= x"C0";
            when  9 => udpRxData <= x"08";
            when 10 => udpRxData <= x"00";
            when 11 => udpRxData <= x"00";
            when 12 => udpRxData <= x"00";
            when 13 => udpRxData <= x"00";
            when 14 => udpRxData <= x"00";
            when 15 => udpRxData <= x"00";
            when 16 => udpRxData <= x"04";
            when 17 => udpRxData <= x"80";
            when 18 => udpRxData <= x"00";
            when 19 => udpRxData <= x"00";
            when 20 => udpRxData <= x"00";
            when 21 => udpRxData <= x"00";
            when 22 => udpRxData <= x"00";
            when 23 => udpRxData <= x"FF";
            when others => udpRxData <= x"AA";
         end case;
         if (conv_integer(count-10) <= 23) then
            udpRxValid <= '1';
         else
            udpRxValid <= '0';
         end if;
         if (conv_integer(count-10) = 24) then
            udpRxGood <= '1';
         else
            udpRxGood <= '0';
         end if;
         udpRxError <= '0';
         udpRxCount <= x"0018";
      end if;
   end process;
   
   -- UDP Frame TX/RX
   U_GigEthUdpFrameRx : entity work.GigEthUdpFrameRx
    port map ( 
      -- Ethernet clock & reset
      gtpClk           => ethClk125MHz,
      gtpClkRst        => ethClk125MHzRst,
      -- User Receive Interface (connection out to user interfaces)
      userRxValid      => userRxValid,
      userRxData       => userRxData,
      userRxSOF        => userRxSOF,
      userRxEOF        => userRxEOF,
      userRxEOFE       => userRxEOFE,
      userRxVc         => userRxVc,
      -- UDP Block Receive Interface (connection from MAC)
      udpRxValid       => udpRxValid,
      udpRxData        => udpRxData,
      udpRxGood        => udpRxGood,
      udpRxError       => udpRxError,
      udpRxCount       => udpRxCount
   );

   -- Dump packets out
   process (ethClk125MHz) 
      variable s : line;
   begin
      if rising_edge(ethClk125MHz) then
         if userRxValid = '1' then
            hwrite(s,userRxData);
            writeline(output,s);
         end if;
      end if;
   end process;
         
end testbed;





