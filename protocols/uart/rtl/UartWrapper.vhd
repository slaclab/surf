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

entity UartWrapper is

   generic (
      TPD_G             : time                  := 1 ns;
      CLK_FREQ_G        : real                  := 125.0e6;
      BAUD_RATE_G       : integer               := 115200;
      BAUD_MULT_G       : integer range 1 to 16 := 16;
      STOP_BITS_G       : integer range 1 to 2  := 1;
      PARITY_G          : string                := "NONE";  -- "NONE" "ODD" "EVEN"
      DATA_WIDTH_G      : integer range 5 to 8  := 8;
      MEMORY_TYPE_G     : string                := "distributed";
      FIFO_ADDR_WIDTH_G : integer range 4 to 48 := 4);
   port (
      clk     : in  sl;
      rst     : in  sl;
      -- Transmit parallel interface
      wrData  : in  slv(7 downto 0);
      wrValid : in  sl;
      wrReady : out sl;
      -- Receive parallel interface
      rdData  : out slv(7 downto 0);
      rdValid : out sl;
      rdReady : in  sl;
      -- Serial IO
      tx      : out sl;
      rx      : in  sl);

end entity UartWrapper;

architecture rtl of UartWrapper is

   signal uartTxData  : slv(7 downto 0);
   signal uartTxValid : sl;
   signal uartTxReady : sl;
   signal uartTxRdEn  : sl;
   signal fifoTxData  : slv(7 downto 0);
   signal fifoTxValid : sl;
   signal fifoTxReady : sl;

   signal uartRxData     : slv(7 downto 0);
   signal uartRxValid    : sl;
   signal uartRxValidInt : sl;
   signal uartRxReady    : sl;
   signal fifoRxData     : slv(7 downto 0);
   signal fifoRxValid    : sl;
   signal fifoRxReady    : sl;
   signal fifoRxRdEn     : sl;

   signal baudClkEn : sl;

begin

   -------------------------------------------------------------------------------------------------
   -- Tie parallel IO to internal signals
   -------------------------------------------------------------------------------------------------


   -------------------------------------------------------------------------------------------------
   -- Baud Rate Generator.
   -- Create a clock enable that is BAUD_MULT_G x the baud rate.
   -- UartTx and UartRx use this.
   -------------------------------------------------------------------------------------------------
   U_UartBrg_1 : entity surf.UartBrg
      generic map (
         CLK_FREQ_G   => CLK_FREQ_G,
         BAUD_RATE_G  => BAUD_RATE_G,
         MULTIPLIER_G => BAUD_MULT_G)
      port map (
         clk       => clk,              -- [in]
         rst       => rst,              -- [in]
         baudClkEn => baudClkEn);       -- [out]

   -------------------------------------------------------------------------------------------------
   -- UART transmitter
   -------------------------------------------------------------------------------------------------
   U_UartTx_1 : entity surf.UartTx
      generic map (
         TPD_G        => TPD_G,
         STOP_BITS_G  => STOP_BITS_G,
         PARITY_G     => PARITY_G,
         BAUD_MULT_G  => BAUD_MULT_G,
         DATA_WIDTH_G => DATA_WIDTH_G)
      port map (
         clk       => clk,              -- [in]
         rst       => rst,              -- [in]
         baudClkEn => baudClkEn,        -- [in]
         wrData    => uartTxData,       -- [in]
         wrValid   => uartTxValid,      -- [in]
         wrReady   => uartTxReady,      -- [out]
         tx        => tx);              -- [out]

   -------------------------------------------------------------------------------------------------
   -- FIFO to feed UART transmitter
   -------------------------------------------------------------------------------------------------
   wrReady     <= fifoTxReady;
   fifoTxData  <= wrData;
   fifoTxValid <= wrValid and fifoTxReady;
   uartTxRdEn  <= uartTxReady and uartTxValid;
   U_Fifo_Tx : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         GEN_SYNC_FIFO_G => true,
         MEMORY_TYPE_G   => MEMORY_TYPE_G,
         FWFT_EN_G       => true,
         PIPE_STAGES_G   => 0,
         DATA_WIDTH_G    => DATA_WIDTH_G,
         ADDR_WIDTH_G    => FIFO_ADDR_WIDTH_G)
      port map (
         rst      => rst,               -- [in]
         wr_clk   => clk,               -- [in]
         wr_en    => fifoTxValid,       -- [in]
         din      => fifoTxData,        -- [in]
         not_full => fifoTxReady,       -- [out]
         rd_clk   => clk,               -- [in]
         rd_en    => uartTxRdEn,        -- [in]
         dout     => uartTxData,        -- [out]
         valid    => uartTxValid);      -- [out]

   -------------------------------------------------------------------------------------------------
   -- UART Receiver
   -------------------------------------------------------------------------------------------------
   U_UartRx_1 : entity surf.UartRx
      generic map (
         TPD_G        => TPD_G,
         PARITY_G     => PARITY_G,
         BAUD_MULT_G  => BAUD_MULT_G,
         DATA_WIDTH_G => DATA_WIDTH_G)
      port map (
         clk       => clk,              -- [in]
         rst       => rst,              -- [in]
         baudClkEn => baudClkEn,        -- [in]
         rdData    => uartRxData,       -- [out]
         rdValid   => uartRxValid,      -- [out]
         rdReady   => uartRxReady,      -- [in]
         rx        => rx);              -- [in]

   -------------------------------------------------------------------------------------------------
   -- FIFO for UART Received data
   -------------------------------------------------------------------------------------------------
   fifoRxRdEn     <= fifoRxReady and fifoRxValid;
   uartRxValidInt <= uartRxValid and uartRxReady;

   rdData      <= fifoRxData;
   rdValid     <= fifoRxValid;
   fifoRxReady <= rdReady;

   U_Fifo_Rx : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         GEN_SYNC_FIFO_G => true,
         MEMORY_TYPE_G   => MEMORY_TYPE_G,
         FWFT_EN_G       => true,
         PIPE_STAGES_G   => 0,
         DATA_WIDTH_G    => DATA_WIDTH_G,
         ADDR_WIDTH_G    => FIFO_ADDR_WIDTH_G)
      port map (
         rst      => rst,               -- [in]
         wr_clk   => clk,               -- [in]
         wr_en    => uartRxValidInt,    -- [in]
         din      => uartRxData,        -- [in]
         not_full => uartRxReady,       -- [out]
         rd_clk   => clk,               -- [in]
         rd_en    => fifoRxRdEn,        -- [in]
         dout     => fifoRxData,        -- [out]
         valid    => fifoRxValid);      -- [out]

end architecture rtl;
