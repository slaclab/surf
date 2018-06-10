-------------------------------------------------------------------------------
-- File       : UartAxiLiteMasterTb.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-06-27
-- Last update: 2016-06-28
-------------------------------------------------------------------------------
-- Description: Testbench for design "UartAxiLiteMaster"
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

use work.StdRtlPkg.all;
use work.TextUtilPkg.all;
use work.AxiLitePkg.all;

----------------------------------------------------------------------------------------------------

entity UartAxiLiteMasterTb is

end entity UartAxiLiteMasterTb;

----------------------------------------------------------------------------------------------------

architecture sim of UartAxiLiteMasterTb is

   -- component generics
   constant TPD_G             : time                  := 1 ns;
   constant CLK_FREQ_G        : real                  := 125.0e6;
   constant BAUD_RATE_G       : integer               := 115200;
   constant FIFO_BRAM_EN_G    : boolean               := false;
   constant FIFO_ADDR_WIDTH_G : integer range 4 to 48 := 5;

   -- component ports
   signal axilWriteMaster : AxiLiteWriteMasterType;  -- [out]
   signal axilWriteSlave  : AxiLiteWriteSlaveType;   -- [in]
   signal axilReadMaster  : AxiLiteReadMasterType;   -- [out]
   signal axilReadSlave   : AxiLiteReadSlaveType;    -- [in]
   signal tx              : sl;                      -- [out]
   signal rx              : sl;                      -- [in]

   signal clk     : sl;                                  -- [in]
   signal rst     : sl;                                  -- [in]
   signal wrData  : slv(7 downto 0) := (others => '0');  -- [in]
   signal wrValid : sl              := '0';              -- [in]
   signal wrReady : sl;                                  -- [out]
   signal rdData  : slv(7 downto 0);                     -- [out]
   signal rdValid : sl;                                  -- [out]
   signal rdReady : sl              := '1';              -- [in]

begin

   U_ClkRst_1 : entity work.ClkRst
      generic map (
         CLK_PERIOD_G      => (1.0/CLK_FREQ_G)* 1 sec,
         CLK_DELAY_G       => 1 ns,
         RST_START_DELAY_G => 0 ns,
         RST_HOLD_TIME_G   => 5 us,
         SYNC_RESET_G      => true)
      port map (
         clkP => clk,
         rst  => rst);


   U_UartWrapper_1 : entity work.UartWrapper
      generic map (
         TPD_G             => TPD_G,
         CLK_FREQ_G        => CLK_FREQ_G,
         BAUD_RATE_G       => BAUD_RATE_G,
         FIFO_BRAM_EN_G    => FIFO_BRAM_EN_G,
         FIFO_ADDR_WIDTH_G => FIFO_ADDR_WIDTH_G)
      port map (
         clk     => clk,                -- [in]
         rst     => rst,                -- [in]
         wrData  => wrData,             -- [in]
         wrValid => wrValid,            -- [in]
         wrReady => wrReady,            -- [out]
         rdData  => rdData,             -- [out]
         rdValid => rdValid,            -- [out]
         rdReady => rdReady,            -- [in]
         tx      => tx,                 -- [out]
         rx      => rx);                -- [in]  

   -- component instantiation
   U_UartAxiLiteMaster : entity work.UartAxiLiteMaster
      generic map (
         TPD_G             => TPD_G,
         AXIL_CLK_FREQ_G   => CLK_FREQ_G,
         BAUD_RATE_G       => BAUD_RATE_G,
         FIFO_BRAM_EN_G    => FIFO_BRAM_EN_G,
         FIFO_ADDR_WIDTH_G => FIFO_ADDR_WIDTH_G)
      port map (
         axilClk          => clk,              -- [in]
         axilRst          => rst,              -- [in]
         mAxilWriteMaster => axilWriteMaster,  -- [out]
         mAxilWriteSlave  => axilWriteSlave,   -- [in]
         mAxilReadMaster  => axilReadMaster,   -- [out]
         mAxilReadSlave   => axilReadSlave,    -- [in]
         tx               => rx,               -- [out]
         rx               => tx);              -- [in]


   U_AxiDualPortRam_1 : entity work.AxiDualPortRam
      generic map (
         TPD_G        => TPD_G,
         BRAM_EN_G    => false,
         REG_EN_G     => false,
         AXI_WR_EN_G  => true,
         SYS_WR_EN_G  => false,
         COMMON_CLK_G => true,
         ADDR_WIDTH_G => 12,
         DATA_WIDTH_G => 32)
      port map (
         axiClk         => clk,              -- [in]
         axiRst         => rst,              -- [in]
         axiReadMaster  => axilReadMaster,   -- [in]
         axiReadSlave   => axilReadSlave,    -- [out]
         axiWriteMaster => axilWriteMaster,  -- [in]
         axiWriteSlave  => axilWriteSlave);  -- [out]

   test : process is
      function hexStrToSlv (s : string) return slv is
         variable tmp  : string(1 to s'length) := resize(s, s'length);
         variable char : character;
         variable ret  : slv(s'length*4-1 downto 0);
      begin
         for i in tmp'range loop
            ret(ret'high downto 4) := ret(ret'high-4 downto 0);
            case tmp(i) is
               when '0'    => ret(3 downto 0) := toSlv(0, 4);
               when '1'    => ret(3 downto 0) := toSlv(1, 4);
               when '2'    => ret(3 downto 0) := toSlv(2, 4);
               when '3'    => ret(3 downto 0) := toSlv(3, 4);
               when '4'    => ret(3 downto 0) := toSlv(4, 4);
               when '5'    => ret(3 downto 0) := toSlv(5, 4);
               when '6'    => ret(3 downto 0) := toSlv(6, 4);
               when '7'    => ret(3 downto 0) := toSlv(7, 4);
               when '8'    => ret(3 downto 0) := toSlv(8, 4);
               when '9'    => ret(3 downto 0) := toSlv(9, 4);
               when 'A'    => ret(3 downto 0) := toSlv(10, 4);
               when 'a'    => ret(3 downto 0) := toSlv(10, 4);
               when 'B'    => ret(3 downto 0) := toSlv(11, 4);
               when 'b'    => ret(3 downto 0) := toSlv(11, 4);
               when 'C'    => ret(3 downto 0) := toSlv(12, 4);
               when 'c'    => ret(3 downto 0) := toSlv(12, 4);
               when 'D'    => ret(3 downto 0) := toSlv(13, 4);
               when 'd'    => ret(3 downto 0) := toSlv(13, 4);
               when 'E'    => ret(3 downto 0) := toSlv(14, 4);
               when 'e'    => ret(3 downto 0) := toSlv(14, 4);
               when 'F'    => ret(3 downto 0) := toSlv(15, 4);
               when 'f'    => ret(3 downto 0) := toSlv(15, 4);
               when others => ret(3 downto 0) := toSlv(0, 4);
            end case;

         end loop;
         return ret;

      end function;

      procedure sendString (
         s : in string) is
      begin
         print("Sending: " & s);
         wait until clk = '1';
         wait until clk = '1';         
         
         for i in s'range loop
            wrData  <= toSlv(character'pos(s(i)), 8);
            wrValid <= '1';
            wait until clk = '1';
            
            if (wrReady = '1') then
               wrValid <= '0';
               wait until clk = '1';
            else
               wait until clk = '1';                              
               while (wrReady = '0') loop
                  wait until clk = '1';
               end loop;

               wrValid <= '0';
               wait until clk = '1';
            end if;
         end loop;
      end procedure sendString;

      procedure receiveString (
         s : inout string)
      is
         variable i : integer := 1;
      begin
         while (true) loop
            wait until clk = '1';
            if (rdValid = '1') then
               s(i) := character'val(conv_integer(rdData));
               if (s(i) = CR or s(i) = LF) then
                  exit;
               end if;
               i:=i+1;
            end if;
         end loop;
         print("Received: " & s);

      end procedure receiveString;

      procedure uartRegWrite (
         wrAddr : in slv(31 downto 0);
         wrData : in slv(31 downto 0))
      is
         variable s     : string(1 to 20);
         variable reply : string(1 to 24);
      begin
         s := "W " & hstr(wrAddr) & " " & hstr(wrData) & CR;
         sendString(s);
         receiveString(reply);
      end procedure uartRegWrite;

      procedure uartRegRead (
         rdAddr : in    slv(31 downto 0);
         rdData : inout slv(31 downto 0))
      is
         variable s     : string(1 to 11);
         variable reply : string(1 to 30);
         variable tmp : integer;
      begin
         s      := "R " & hstr(rdAddr) & CR;
         sendString(s);
         receiveString(reply);
         tmp := int(reply(12 to 19), 16);
         print(reply(12 to 19));
         print(str(tmp));
         rdData := toSlv(tmp, 32);
         print("Read Data: " & hstr(rdData));
      end procedure;

      variable addr : slv(31 downto 0);
      variable data : slv(31 downto 0);
   begin
      wait until rst = '1';
      wait until rst = '0';
      wait for 1 us;
      wait until clk = '1';

      uartRegWrite(X"12345670", X"08765432");
      uartRegWrite(X"03030300", X"12345678");      
      uartRegRead(X"12345670", data);
      uartRegRead(X"03030300", data);      


   end process test;


end architecture sim;

----------------------------------------------------------------------------------------------------
