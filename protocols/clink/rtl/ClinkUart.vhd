-------------------------------------------------------------------------------
-- File       : ClinkUart.vhd
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
-- CameraLink UART RX/TX
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
use work.AxiStreamPkg.all;
use work.SsiPkg.all;

entity ClinkUart is
   generic (
      TPD_G              : time                := 1 ns;
      UART_READY_EN_G    : boolean             := true;
      UART_AXIS_CONFIG_G : AxiStreamConfigType := AXI_STREAM_CONFIG_INIT_C);
   port (
      -- Clock and reset, 200Mhz
      intClk      : in  sl;
      intRst      : in  sl;
      -- Configurations
      baud        : in  slv(23 downto 0);  -- Baud rate (units of bps)
      throttle    : in  slv(15 downto 0);  -- TX Throttle (units of us)
      -- Data In/Out
      uartClk     : in  sl;
      uartRst     : in  sl;
      sUartMaster : in  AxiStreamMasterType;
      sUartSlave  : out AxiStreamSlaveType;
      sUartCtrl   : out AxiStreamCtrlType;
      mUartMaster : out AxiStreamMasterType;
      mUartSlave  : in  AxiStreamSlaveType;
      -- Serial data
      rxIn        : in  sl;
      txOut       : out sl);
end ClinkUart;

architecture rtl of ClinkUart is

   constant INT_FREQ_C : integer := 200000000;

   constant INT_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(dataBytes => 4, tDestBits => 0);

   type RegType is record
      count : integer;
      clkEn : sl;
   end record RegType;

   constant REG_INIT_C : RegType := (
      count => 0,
      clkEn => '0');

   signal r   : RegType := REG_INIT_C;
   signal rin : Regtype;

   signal rdData  : slv(7 downto 0);
   signal rdValid : sl;

   signal txMasters : AxiStreamMasterArray(1 downto 0);
   signal txSlaves  : AxiStreamSlaveArray(1 downto 0);
   signal rxMaster  : AxiStreamMasterType;

begin

   -----------------------------------
   -- Baud rate generation
   -----------------------------------
   comb : process (baud, intRst, r) is
      variable v : RegType;
   begin
      v := r;

      -- 16x (add min of 1 to ensure data moves when baud=0)
      v.count := r.count + conv_integer(baud & x"1");
      v.clkEn := '0';

      if r.count >= INT_FREQ_C then
         v.count := 0;
         v.clkEn := '1';
      end if;

      if (intRst = '1') then
         v := REG_INIT_C;
      end if;

      rin <= v;
   end process;

   seq : process (intClk) is
   begin
      if (rising_edge(intClk)) then
         r <= rin;
      end if;
   end process;

   -------------------------------------------------------------------------------------------------
   -- Transmit FIFO
   -------------------------------------------------------------------------------------------------
   U_TxFifo : entity work.AxiStreamFifoV2
      generic map (
         TPD_G               => TPD_G,
         GEN_SYNC_FIFO_G     => false,
         FIFO_ADDR_WIDTH_G   => 9,
         SLAVE_READY_EN_G    => UART_READY_EN_G,
         SLAVE_AXI_CONFIG_G  => UART_AXIS_CONFIG_G,
         MASTER_AXI_CONFIG_G => INT_CONFIG_C)
      port map (
         sAxisClk    => uartClk,
         sAxisRst    => uartRst,
         sAxisMaster => sUartMaster,
         sAxisSlave  => sUartSlave,
         sAxisCtrl   => sUartCtrl,
         mAxisClk    => intClk,
         mAxisRst    => intRst,
         mAxisMaster => txMasters(0),
         mAxisSlave  => txSlaves(0));

   U_TxThrottle : entity work.ClinkUartThrottle
      generic map (
         TPD_G => TPD_G)
      port map (
         -- Clock and reset, 200Mhz
         intClk      => intClk,
         intRst      => intRst,
         -- Throttle Config (units of us)
         throttle    => throttle,
         -- Data In/Out
         sUartMaster => txMasters(0),
         sUartSlave  => txSlaves(0),
         mUartMaster => txMasters(1),
         mUartSlave  => txSlaves(1));

   -------------------------------------------------------------------------------------------------
   -- UART transmitter
   -------------------------------------------------------------------------------------------------
   U_UartTx_1 : entity work.UartTx
      generic map (
         TPD_G => TPD_G)
      port map (
         clk     => intClk,                          -- [in]
         rst     => intRst,                          -- [in]
         baud16x => r.clkEn,                         -- [in]
         wrData  => txMasters(1).tData(7 downto 0),  -- [in]
         wrValid => txMasters(1).tValid,             -- [in]
         wrReady => txSlaves(1).tReady,              -- [out]
         tx      => txOut);                          -- [out]

   -------------------------------------------------------------------------------------------------
   -- UART Receiver
   -------------------------------------------------------------------------------------------------
   U_UartRx_1 : entity work.UartRx
      generic map (
         TPD_G => TPD_G)
      port map (
         clk     => intClk,             -- [in]
         rst     => intRst,             -- [in]
         baud16x => r.clkEn,            -- [in]
         rdData  => rdData,             -- [out]
         rdValid => rdValid,            -- [out]
         rdReady => '1',                -- [in]
         rx      => rxIn);              -- [in]

   process (rdData, rdValid) is
      variable mst : AxiStreamMasterType;
   begin

      mst := AXI_STREAM_MASTER_INIT_C;

      mst.tData(7 downto 0) := rdData;

      mst.tValid := rdValid;
      mst.tLast  := '1';

      ssiSetUserSof (INT_CONFIG_C, mst, '1');

      rxMaster <= mst;

   end process;

   -------------------------------------------------------------------------------------------------
   -- Receive FIFO
   -------------------------------------------------------------------------------------------------
   U_RxFifo : entity work.AxiStreamFifoV2
      generic map (
         TPD_G               => TPD_G,
         GEN_SYNC_FIFO_G     => false,
         FIFO_ADDR_WIDTH_G   => 9,
         SLAVE_READY_EN_G    => false,
         SLAVE_AXI_CONFIG_G  => INT_CONFIG_C,
         MASTER_AXI_CONFIG_G => UART_AXIS_CONFIG_G)
      port map (
         sAxisClk    => intClk,
         sAxisRst    => intRst,
         sAxisMaster => rxMaster,
         mAxisClk    => uartClk,
         mAxisRst    => uartRst,
         mAxisMaster => mUartMaster,
         mAxisSlave  => mUartSlave);

end architecture rtl;

