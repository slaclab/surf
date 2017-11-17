-------------------------------------------------------------------------------
-- File       : ClinkCtrl.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2017-11-13
-------------------------------------------------------------------------------
-- Description:
-- CameraLink control interface.
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
library unisim;
use unisim.vcomponents.all;

entity ClinkCtrl is
   generic (
      TPD_G              : time                := 1 ns;
      SYS_CLK_FREQ_G     : real                := 125.0e6;
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
      -- Config
      serBaud     : in  slv(23 downto 0);
      -- UART data
      serRxMaster : in  AxiStreamMasterType;
      serRxSlave  : out AxiStreamSlaveType;
      serTxMaster : out AxiStreamMasterType;
      serTxSlave  : in  AxiStreamSlaveType);
end ClinkCtrl;

architecture structure of ClinkCtrl is
   signal cableOut   : slv(4 downto 0);
   signal cableIn    : slv(4 downto 0);
   signal cableDirIn : slv(4 downto 0);
   signal cblSerOut  : sl;
begin

   -------------------------------
   -- IO Buffers
   -------------------------------
   U_CableBuffGen : for i in 0 to 4 generate
      U_CableBuff: IOBUFDS
         port map(
            I   => cableOut(i),
            O   => cableIn(i),
            T   => cableDirIn(i),
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
   clbDirIn(2) <= '0';
   cblOut(2)   <= camCtrl(0);

   clbDirIn(3) <= '0';
   cblOut(3)   <= not camCtrl(1);

   clbDirIn(0) <= '0';
   cblOut(0)   <= camCtrl(2);

   clbDirIn(4) <= '0';
   cblOut(4)   <= not camCtrl(3);

   -------------------------------
   -- UART
   -------------------------------
   U_Uart: entity work.ClinkUart
      generic map (
         TPD_G         => TPD_G,
         CLK_FREQ_G    => SYS_CLK_FREQ_G,
         AXIS_CONFIG_G => UART_AXIS_CONFIG_G)
      port map (
         clk           => sysCLk,
         rst           => sysRst,
         baud          => serBaud,
         sAxisMaster   => serTxMaster,
         sAxisSlave    => serTxSlave,
         mAxisMaster   => serRxMaster,
         mAxisSlave    => serRxSlave,
         rxIn          => cblIn(1),
         txOut         => cblSerOut);

   cblDirIn(1) <= '1';

end architecture rtl;

