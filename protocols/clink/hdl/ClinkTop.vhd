-------------------------------------------------------------------------------
-- File       : ClinkTop.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2017-11-13
-------------------------------------------------------------------------------
-- Description:
-- CameraLink Channel
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

entity ClinkTop is
   generic (
      TPD_G              : time                := 1 ns;
      SYS_CLK_FREQ_G     : real                := 125.0e6;
      SSI_EN_G           : boolean             := true; -- Insert SOF
      DATA_AXIS_CONFIG_G : AxiStreamConfigType := AXI_STREAM_CONFIG_INIT_C;
      UART_AXIS_CONFIG_G : AxiStreamConfigType := AXI_STREAM_CONFIG_INIT_C);
   port (
      -- Cable Input/Output
      cbl0Half0P      : inout slv(4 downto 0); --  2,  4,  5,  6, 3
      cbl0Half0M      : inout slv(4 downto 0); -- 15, 17, 18, 19 16
      cbl0Half1P      : in    slv(4 downto 0); --  8, 10, 11, 12,  9
      cbl0Half1M      : in    slv(4 downto 0); -- 21, 23, 24, 25, 22
      cbl0SerP        : out   sl; -- 20
      cbl0SerM        : out   sl; -- 7
      cbl1Half0P      : inout slv(4 downto 0); --  2,  4,  5,  6, 3
      cbl1Half0M      : inout slv(4 downto 0); -- 15, 17, 18, 19 16
      cbl1Half1P      : in    slv(4 downto 0); --  8, 10, 11, 12,  9
      cbl1Half1M      : in    slv(4 downto 0); -- 21, 23, 24, 25, 22
      cbl1SerP        : out   sl; -- 20
      cbl1SerM        : out   sl; -- 7
      -- System clock and reset, must be 100Mhz or greater
      sysClk          : in  sl;
      sysRst          : in  sl;
      -- Axi-Lite Interface
      axilReadMaster  : in  AxiLiteReadMasterType;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType;
      axilWriteSlave  : out AxiLiteWriteSlaveType;
      -- Camera Control Bits
      camCtrl         : in  slv(7 downto 0);
      -- Camera data
      dataMaster      : out AxiStreamMasterArray(1 downto 0);
      dataSlave       : in  AxiStreamSlaveArray(1 downto 0);
      -- UART data
      serRxMaster     : in  AxiStreamMasterArray(1 downto 0);
      serRxSlave      : out AxiStreamSlaveArray(1 downto 0);
      serTxMaster     : out AxiStreamMasterArray(1 downto 0);
      serTxSlave      : in  AxiStreamSlaveArray(1 downto 0));
end ClinkTop;

architecture structure of ClinkTop is

   constant INT_CONFIG_C : AxiStreamConfigType := (
      TSTRB_EN_C    => false,
      TDATA_BYTES_C => 1,
      TDEST_BITS_C  => 0,
      TID_BITS_C    => 0,
      TKEEP_MODE_C  => TKEEP_COMP_C,
      TUSER_BITS_C  => 2,
      TUSER_MODE_C  => TUSER_FIRST_LAST_C);

   signal intCtrl   : Slv4Array(1 downto 0);
   signal serBaud   : Slv24Array(1 downto 0);
   signal locked    : slv(2 downto 0);
   signal parData   : Slv28Array(2 downto 0);
   signal parValid  : slv(2 downto 0);
   signal parReady  : slv(2 downto 0);
   signal dualCable : sl;

begin

   ----------------------------------------
   -- IO Modules
   ----------------------------------------

   -- Cable 0, half 0
   U_Cbl0Half0: entity work.ClinkCtrl
      generic map (
         TPD_G              => TPD_G,
         SYS_CLK_FREQ_G     => SYS_CLK_FREQ_G,
         UART_AXIS_CONFIG_G => UART_AXIS_CONFIG_G)
      port map (
         cblHalfP     => cbl0Half0P,
         cblHalfM     => cbl0Half0M,
         cblSerP      => cbl0SerP,
         cblSerM      => cbl0SerM,
         sysClk       => sysClk,
         sysRst       => sysRst,
         camCtrl      => intCtrl(0),
         serBaud      => serBaud(0),
         serRxMaster  => serRxMaster(0),
         serRxSlave   => serRxSlave(0),
         serTxMaster  => serTxMaster(0),
         serTxSlave   => serTxSlave(0),

   -- Cable 0, half 1
   U_Cbl0Half1: entity work.ClinkData
      generic map ( TPD_G => TPD_G )
      port map (
         cblHalfP  => cbl0Half1P,
         cblHalfM  => cbl0Half1M,
         sysClk    => sysClk,
         sysRst    => sysRst,
         locked    => locked(0),
         parData   => parData(0),
         parValid  => parValid(0),
         parReady  => parReady(0));

   -- Cable 0, half 0
   U_Cbl1Half0: entity work.ClinkDual
      generic map (
         TPD_G              => TPD_G,
         SYS_CLK_FREQ_G     => SYS_CLK_FREQ_G,
         UART_AXIS_CONFIG_G => UART_AXIS_CONFIG_G)
      port map (
         cblHalfP     => cbl1Half0P,
         cblHalfM     => cbl1Half0M,
         cblSerP      => cbl1SerP,
         cblSerM      => cbl1SerM,
         sysClk       => sysClk,
         sysRst       => sysRst,
         camCtrl      => intCtrl(1),
         serBaud      => serBaud(1),
         locked       => locked(1),
         ctrlMode     => dualCable,
         parData      => parData(1),
         parValid     => parValid(1),
         parReady     => parReady(1),
         serRxMaster  => serRxMaster(1),
         serRxSlave   => serRxSlave(1),
         serTxMaster  => serTxMaster(1),
         serTxSlave   => serTxSlave(1));

   -- Cable 1, half 1
   U_Cbl1Half1: entity work.ClinkData
      generic map ( TPD_G => TPD_G )
      port map (
         cblHalfP  => cbl1Half1P,
         cblHalfM  => cbl1Half1M,
         sysClk    => sysClk,
         sysRst    => sysRst,
         locked    => locked(2),
         parData   => parData(2),
         parValid  => parValid(2),
         parReady  => parReady(2));

   ---------------------------------
   -- Data Processing
   ---------------------------------
   constant INT_CONFIG_C 
   signal parData   : Slv28Array(2 downto 0);
   signal parValid  : slv(2 downto 0);
   signal parReady  : slv(2 downto 0);

   dataMaster   : out AxiStreamMasterArray(1 downto 0);
   dataSlave    : in  AxiStreamSlaveArray(1 downto 0);

   DATA_AXIS_CONFIG_G : AxiStreamConfigType := AXI_STREAM_CONFIG_INIT_C;

   ---------------------------------
   -- Registers
   ---------------------------------
      camCtrl      : in  slv(7 downto 0);

   intCtrl   : Slv4Array(1 downto 0);
   serBaud   : Slv24Array(1 downto 0);
   locked    : slv(2 downto 0);
   dualCable : sl;


      axilReadMaster  : in  AxiLiteReadMasterType;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType;
      axilWriteSlave  : out AxiLiteWriteSlaveType;


end architecture rtl;

