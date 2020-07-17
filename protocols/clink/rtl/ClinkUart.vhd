-------------------------------------------------------------------------------
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

library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;
use surf.SsiPkg.all;

entity ClinkUart is
   generic (
      TPD_G              : time    := 1 ns;
      UART_READY_EN_G    : boolean := true;
      UART_AXIS_CONFIG_G : AxiStreamConfigType);
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
      count     : integer;
      baudClkEn : sl;
   end record RegType;

   constant REG_INIT_C : RegType := (
      count     => 0,
      baudClkEn => '0');

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

      -- Reset strobe
      v.baudClkEn := '0';

      -- Check for 0 baud rate condition
      if (baud = 0) then
         -- Keep pipeline moving
         v.count := r.count + 1;
      else
         -- MULTIPLIER_G = 16
         v.count := r.count + conv_integer(baud & b"0000");
      end if;

      -- Check for max count
      if r.count >= INT_FREQ_C then
         v.count     := 0;
         v.baudClkEn := '1';
      end if;

      -- Reset
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
   U_TxFifo : entity surf.AxiStreamFifoV2
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

   U_TxThrottle : entity surf.ClinkUartThrottle
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
   U_UartTx_1 : entity surf.UartTx
      generic map (
         TPD_G => TPD_G)
      port map (
         clk       => intClk,                          -- [in]
         rst       => intRst,                          -- [in]
         baudClkEn => r.baudClkEn,                     -- [in]
         wrData    => txMasters(1).tData(7 downto 0),  -- [in]
         wrValid   => txMasters(1).tValid,             -- [in]
         wrReady   => txSlaves(1).tReady,              -- [out]
         tx        => txOut);                          -- [out]

   -------------------------------------------------------------------------------------------------
   -- UART Receiver
   -------------------------------------------------------------------------------------------------
   U_UartRx_1 : entity surf.UartRx
      generic map (
         TPD_G => TPD_G)
      port map (
         clk       => intClk,           -- [in]
         rst       => intRst,           -- [in]
         baudClkEn => r.baudClkEn,      -- [in]
         rdData    => rdData,           -- [out]
         rdValid   => rdValid,          -- [out]
         rdReady   => '1',              -- [in]
         rx        => rxIn);            -- [in]

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
   U_RxFifo : entity surf.AxiStreamFifoV2
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

