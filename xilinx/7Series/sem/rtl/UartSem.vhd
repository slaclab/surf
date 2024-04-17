-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
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


library surf;
use surf.StdRtlPkg.all;
use surf.SemPkg.all;

entity UartSem is
   generic (
      TPD_G             : time     := 1 ns;
      CLK_FREQ_G        : real     := 100.0E+6;
      BAUD_RATE_G       : positive := 115200;
      MEMORY_TYPE_G     : string   := "block";
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
   U_Sem : entity surf.SemWrapper
      generic map (
         TPD_G => TPD_G)
      port map (
         -- Clock and Reset
         semClk => semClk,
         semRst => semRst,
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
   U_Uart : entity surf.UartWrapper
      generic map (
         TPD_G             => TPD_G,
         CLK_FREQ_G        => CLK_FREQ_G,
         BAUD_RATE_G       => BAUD_RATE_G,
         MEMORY_TYPE_G     => MEMORY_TYPE_G,
         FIFO_ADDR_WIDTH_G => FIFO_ADDR_WIDTH_G)
      port map (
         -- Clock and Reset
         clk     => semClk,
         rst     => semRst,
         -- Write Interface
         wrData  => semOb.txData,
         wrValid => semOb.txWrite,
         wrReady => wrReady,
         -- Read Interface
         rdData  => semIb.rxData,
         rdValid => rdValid,
         rdReady => semOb.rxRead,
         -- UART Serial Interface
         tx      => uartTx,
         rx      => uartRx);

end mapping;
