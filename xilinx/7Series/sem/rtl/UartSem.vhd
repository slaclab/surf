-------------------------------------------------------------------------------
-- File       : UartSem.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2017-02-08
-- Last update: 2017-02-08
-------------------------------------------------------------------------------
-- Description: UART wrapper for 7-series SEM module
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
use work.SemPkg.all;

entity UartSem is
   generic (
      TPD_G             : time     := 1 ns;
      CLK_FREQ_G        : real     := 100.0E+6;
      BAUD_RATE_G       : positive := 115200;
      FIFO_BRAM_EN_G    : boolean  := false;
      FIFO_ADDR_WIDTH_G : positive := 5);
   port (
      -- Clock and Reset
      semClk         : in  sl;
      semRst         : in  sl;
      -- IPROG Interface
      fpgaReload     : in  sl               := '0';
      fpgaReloadAddr : in  slv(31 downto 0) := (others => '0');
      -- UART Serial Interface
      uartTx         : out sl;
      uartRx         : in  sl);
end entity UartSem;

architecture mapping of UartSem is

   signal wrData  : sl;
   signal wrValid : sl;
   signal wrFull  : sl;
   signal wrReady : sl;

   signal rdData  : sl;
   signal rdValid : sl;
   signal rdEmpty : sl;
   signal rdReady : sl;

   signal semIb : SemIbType := SEM_IB_INIT_C;
   signal semOb : SemObType;

begin

   ------------------------------   
   --  Soft Error Mitigation Core
   ------------------------------   
   U_Sem : entity work.SemWrapper
      generic map (
         TPD_G => TPD_G)
      port map (
         -- Clock and Reset
         semClk => clk,
         semRst => rst,
         -- SEM Interface
         semIb  => semIb,
         semOb  => semOb);

   --------------
   -- Flowcontrol
   --------------
   semIb.txFull  <= not(wrReady);
   semIb.rxEmpty <= not(rdValid);

   --------------------
   --  UART Serdes Core
   --------------------
   U_Uart : entity work.UartWrapper
      generic map (
         TPD_G             => TPD_G,
         CLK_FREQ_G        => CLK_FREQ_G,
         BAUD_RATE_G       => BAUD_RATE_G,
         FIFO_BRAM_EN_G    => FIFO_BRAM_EN_G,
         FIFO_ADDR_WIDTH_G => FIFO_ADDR_WIDTH_G)
      port map (
         -- Clock and Reset
         clk     => clk,
         rst     => rst,
         -- Write Interface
         wrData  => semOb.txData,
         wrValid => semOb.txWrite,
         wrReady => wrReady,
         -- Read Interface
         rdData  => semIb.rxData,
         rdValid => rdValid,
         rdReady => semOb.rxRead,
         -- UART Serial Interface
         tx      => tx,
         rx      => rx);

end mapping;
