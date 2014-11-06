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

entity GigEthUdpFrameTxTb is end GigEthUdpFrameTxTb;

architecture testbed of GigEthUdpFrameTxTb is

   constant CLK_PERIOD_C : time := 8 ns;
   constant TPD_C        : time := CLK_PERIOD_C/4;

   signal ethClk125MHz    : sl;
   signal ethClk125MHzRst : sl;

   signal userTxValid     : sl;
   signal userTxReady     : sl;
   signal userTxData      : slv(31 downto 0);
   signal userTxSOF       : sl;
   signal userTxEOF       : sl;
   signal userTxVc        : slv(1 downto 0);
   
   signal udpTxValid      : sl;
   signal udpTxFast       : sl;
   signal udpTxReady      : sl;
   signal udpTxData       : slv(7 downto 0);
   signal udpTxLength     : slv(15 downto 0);
   
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
         userTxVc   <= "01";
         udpTxReady <= '1';
         case conv_integer(count-10) is
            when  0 => userTxValid <= '1'; userTxData <= x"DEADBEEF"; userTxSOF <= '1'; userTxEOF <= '0';
            when  1 => userTxValid <= '1'; userTxData <= x"12345678"; userTxSOF <= '0'; userTxEOF <= '0';
            when  2 => userTxValid <= '1'; userTxData <= x"FEEDDEED"; userTxSOF <= '0'; userTxEOF <= '0';
            when  3 => userTxValid <= '1'; userTxData <= x"BADEFEBA"; userTxSOF <= '0'; userTxEOF <= '0';
            when  4 => userTxValid <= '1'; userTxData <= x"F00D1234"; userTxSOF <= '0'; userTxEOF <= '1';
            when others => userTxValid <= '0'; userTxData <= x"A5A5A5A5"; userTxSOF <= '0'; userTxEOF <= '0';
         end case;
      end if;
   end process;
   
   -- UDP Frame TX/RX
   U_GigEthUdpFrameTx : entity work.GigEthUdpFrameTx
    port map ( 
      -- Ethernet clock & reset
      gtpClk           => ethClk125MHz,
      gtpClkRst        => ethClk125MHzRst,
      -- User Transmit Interface
      userTxValid      => userTxValid, --: in  std_logic;
      userTxReady      => userTxReady, --: out std_logic;
      userTxData       => userTxData,  --: in  std_logic_vector(31 downto 0);    -- Ethernet TX Data
      userTxSOF        => userTxSOF,   --: in  std_logic;                        -- Ethernet TX Start of Frame
      userTxEOF        => userTxEOF,   --: in  std_logic;                        -- Ethernet TX End of Frame
      userTxVc         => userTxVc,    --: in  std_logic_vector(1  downto 0);    -- Ethernet TX Virtual Channel
      -- UDP Block Transmit Interface (connection to MAC)
      udpTxValid       => udpTxValid,  --: out std_logic;
      udpTxFast        => udpTxFast,   --: out std_logic;
      udpTxReady       => udpTxReady,  --: in  std_logic;
      udpTxData        => udpTxData,   --: out std_logic_vector(7  downto 0);
      udpTxLength      => udpTxLength  --: out std_logic_vector(15 downto 0)
   );

   -- Dump packets out
   process (ethClk125MHz) 
      variable s : line;
   begin
      if rising_edge(ethClk125MHz) then
         if udpTxValid = '1' then
            hwrite(s,udpTxData);
            writeline(output,s);
         end if;
      end if;
   end process;
         
end testbed;





