-------------------------------------------------------------------------------
-- File       : ClinkDual.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2017-11-13
-------------------------------------------------------------------------------
-- Description:
-- CameraLink control or data interface.
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
library unisim;
use unisim.vcomponents.all;

entity ClinkDual is
   generic (
      TPD_G              : time                := 1 ns;
      SYS_CLK_FREQ_G     : real                := 125.0e6;
      UART_READY_EN_G    : boolean             := true;
      UART_AXIS_CONFIG_G : AxiStreamConfigType := AXI_STREAM_CONFIG_INIT_C);
   port (
      -- Cable In/Out
      cblHalfP    : inout slv(4 downto 0); --  2,  4,  5,  6, 3 /  8, 10, 11, 12,  9
      cblHalfM    : inout slv(4 downto 0); -- 15, 17, 18, 19 16 / 21, 23, 24, 25, 22
      cblSerP     : out   sl; -- 20
      cblSerM     : out   sl; -- 7
      -- System clock and reset, must be 100Mhz or greater
      sysClk      : in  sl;
      sysRst      : in  sl;
      -- Camera Control Bits
      camCtrl     : in  slv(3 downto 0);
      -- Config/status
      serBaud     : in  slv(23 downto 0);
      locked      : out sl;
      ctrlMode    : in  sl;
      -- Data output
      parData     : out slv(27 downto 0);
      parValid    : out sl;
      parReady    : in  sl := '1';
      -- UART data
      sUartMaster : in  AxiStreamMasterType;
      sUartSlave  : out AxiStreamSlaveType;
      sUartCtrl   : out AxiStreamCtrlType;
      mUartMaster : out AxiStreamMasterType;
      mUartSlave  : in  AxiStreamSlaveType);
end ClinkDual;

architecture rtl of ClinkDual is

   signal dataMode   : sl;
   signal uartRst    : sl;
   signal dataRst    : sl;
   signal cblOut     : slv(4 downto 0);
   signal cblIn      : slv(4 downto 0);
   signal cblDirIn   : slv(4 downto 0);
   signal cblSerOut  : sl;

begin

   dataMode <= not ctrlMode;
   uartRst  <= sysRst or dataMode;
   dataRst  <= sysRst or ctrlMode;

   -------------------------------
   -- IO Buffers
   -------------------------------
   U_CableBuffGen : for i in 0 to 4 generate
      U_CableBuff: IOBUFDS
         port map(
            I   => cblOut(i),
            O   => cblIn(i),
            T   => cblDirIn(i),
            IO  => cblHalfP(i),
            IOB => cblHalfM(i));
   end generate;

   U_SerOut: OBUFDS
      port map (
         I  => cblSerOut,
         O  => cblSerP,
         OB => cblSerM);

   -------------------------------
   -- Camera control bits
   -------------------------------
   cblDirIn(2) <= dataMode;
   cblOut(2)   <= camCtrl(0);

   cblDirIn(3) <= dataMode;
   cblOut(3)   <= not camCtrl(1);

   cblDirIn(0) <= dataMode;
   cblOut(0)   <= camCtrl(2);

   cblDirIn(4) <= dataMode;
   cblOut(4)   <= not camCtrl(3);

   -------------------------------
   -- UART
   -------------------------------
   U_Uart: entity work.ClinkUart
      generic map (
         TPD_G              => TPD_G,
         CLK_FREQ_G         => SYS_CLK_FREQ_G,
         UART_READY_EN_G    => UART_READY_EN_G,
         UART_AXIS_CONFIG_G => UART_AXIS_CONFIG_G)
      port map (
         clk           => sysCLk,
         rst           => uartRst,
         baud          => serBaud,
         sUartMaster   => sUartMaster,
         sUartSlave    => sUartSlave,
         sUartCtrl     => sUartCtrl,
         mUartMaster   => mUartMaster,
         mUartSlave    => mUartSlave,
         rxIn          => cblIn(1),
         txOut         => cblSerOut);

   cblDirIn(1) <= '1';

   -------------------------------
   -- Data
   -------------------------------
   U_DeSerial : entity work.ClinkDeSerial
      generic map ( TPD_G => TPD_G )
      port map (
         clkIn     => cblIn(0),
         dataIn    => cblIn(4 downto 1),
         sysClk    => sysClk,
         sysRst    => dataRst,
         locked    => locked,
         parData   => parData,
         parValid  => parValid,
         parReady  => parReady);

end architecture rtl;

