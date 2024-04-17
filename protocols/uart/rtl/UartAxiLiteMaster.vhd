-------------------------------------------------------------------------------
-- Title      : UART Memory Protocol: https://confluence.slac.stanford.edu/x/uSDoDQ
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Ties together everything needed for a full duplex UART.
-- This includes Baud Rate Generator, Transmitter, Receiver and FIFOs.
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

library surf;
use surf.StdRtlPkg.all;
use surf.TextUtilPkg.all;
use surf.AxiLitePkg.all;

entity UartAxiLiteMaster is
   generic (
      TPD_G             : time                  := 1 ns;
      AXIL_CLK_FREQ_G   : real                  := 125.0e6;
      BAUD_RATE_G       : integer               := 115200;
      STOP_BITS_G       : integer range 1 to 2  := 1;
      PARITY_G          : string                := "NONE";  -- "NONE" "ODD" "EVEN"
      DATA_WIDTH_G      : integer range 5 to 8  := 8;
      MEMORY_TYPE_G     : string                := "distributed";
      FIFO_ADDR_WIDTH_G : integer range 4 to 48 := 5);
   port (
      axilClk          : in  sl;
      axilRst          : in  sl;
      -- Transmit parallel interface
      mAxilWriteMaster : out AxiLiteWriteMasterType;
      mAxilWriteSlave  : in  AxiLiteWriteSlaveType;
      mAxilReadMaster  : out AxiLiteReadMasterType;
      mAxilReadSlave   : in  AxiLiteReadSlaveType;
      -- Serial IO
      tx               : out sl;
      rx               : in  sl);
end entity UartAxiLiteMaster;

architecture mapping of UartAxiLiteMaster is

   signal uartRxData  : slv(7 downto 0);
   signal uartRxValid : sl;
   signal uartRxReady : sl;

   signal uartTxData  : slv(7 downto 0);
   signal uartTxValid : sl;
   signal uartTxReady : sl;

begin

   -----------
   -- UART PHY
   -----------
   U_UartWrapper_1 : entity surf.UartWrapper
      generic map (
         TPD_G             => TPD_G,
         CLK_FREQ_G        => AXIL_CLK_FREQ_G,
         BAUD_RATE_G       => BAUD_RATE_G,
         STOP_BITS_G       => STOP_BITS_G,
         PARITY_G          => PARITY_G,
         DATA_WIDTH_G      => DATA_WIDTH_G,
         MEMORY_TYPE_G     => MEMORY_TYPE_G,
         FIFO_ADDR_WIDTH_G => FIFO_ADDR_WIDTH_G)
      port map (
         clk     => axilClk,            -- [in]
         rst     => axilRst,            -- [in]
         wrData  => uartTxData,         -- [in]
         wrValid => uartTxValid,        -- [in]
         wrReady => uartTxReady,        -- [out]
         rdData  => uartRxData,         -- [out]
         rdValid => uartRxValid,        -- [out]
         rdReady => uartRxReady,        -- [in]
         tx      => tx,                 -- [out]
         rx      => rx);                -- [in]

   -----------------------
   -- Finite State Machine
   -----------------------
   U_Fsm : entity surf.UartAxiLiteMasterFsm
      generic map (
         TPD_G => TPD_G)
      port map (
         -- Clock and Reset
         axilClk          => axilClk,
         axilRst          => axilRst,
         -- UART TX Streaming Byte Interface
         uartTxValid      => uartTxValid,
         uartTxData       => uartTxData,
         uartTxReady      => uartTxReady,
         -- UART RX Streaming Byte Interface
         uartRxValid      => uartRxValid,
         uartRxData       => uartRxData,
         uartRxReady      => uartRxReady,
         -- AXI-Lite interface
         mAxilWriteMaster => mAxilWriteMaster,
         mAxilWriteSlave  => mAxilWriteSlave,
         mAxilReadMaster  => mAxilReadMaster,
         mAxilReadSlave   => mAxilReadSlave);

end mapping;
