-------------------------------------------------------------------------------
-- File       : ClinkTop.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2017-11-13
-------------------------------------------------------------------------------
-- Description:
-- CameraLink Top Level
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
use work.ClinkPkg.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;

entity ClinkTop is
   generic (
      TPD_G              : time                := 1 ns;
      SYS_CLK_FREQ_G     : real                := 125.0e6;
      AXI_ERROR_RESP_G   : slv(1 downto 0)     := AXI_RESP_DECERR_C;
      AXI_COMMON_CLK_G   : boolean             := false;
      UART_READY_EN_G    : boolean             := true;
      DATA_AXIS_CONFIG_G : AxiStreamConfigType := AXI_STREAM_CONFIG_INIT_C;
      UART_AXIS_CONFIG_G : AxiStreamConfigType := AXI_STREAM_CONFIG_INIT_C);
   port (
      -- Connector 0, Half 0, Control for Base,Medium,Full,Deca
      cbl0Half0P      : inout slv(4 downto 0); -- 15, 17,  5,  6,  3
      cbl0Half0M      : inout slv(4 downto 0); --  2,  4, 18, 19, 16
      -- Connector 0, Half 1, Data X for Base,Medium,Full,Deca
      cbl0Half1P      : in    slv(4 downto 0); --  8, 10, 11, 12,  9
      cbl0Half1M      : in    slv(4 downto 0); -- 21, 23, 24, 25, 22
      -- Connector 0, Serial out
      cbl0SerP        : out   sl; -- 20
      cbl0SerM        : out   sl; -- 7
      -- Connector 1, Half 0, Control Base, Data Z for Med, Full, Deca
      cbl1Half0P      : inout slv(4 downto 0); --  2,  4,  5,  6, 3
      cbl1Half0M      : inout slv(4 downto 0); -- 15, 17, 18, 19 16
      -- Connector 1, Half 1, Data X for Base, Data Y for Med, Full, Deca
      cbl1Half1P      : in    slv(4 downto 0); --  8, 10, 11, 12,  9
      cbl1Half1M      : in    slv(4 downto 0); -- 21, 23, 24, 25, 22
      -- Connector 1, Serial out
      cbl1SerP        : out   sl; -- 20
      cbl1SerM        : out   sl; -- 7
      -- System clock and reset, must be 100Mhz or greater
      sysClk          : in  sl;
      sysRst          : in  sl;
      -- Camera Control Bits
      camCtrl         : in  Slv4Array(1 downto 0);
      -- Camera data
      dataMasters     : out AxiStreamMasterArray(1 downto 0);
      dataSlaves      : in  AxiStreamSlaveArray(1 downto 0);
      -- UART data
      sUartMasters    : in  AxiStreamMasterArray(1 downto 0);
      sUartSlaves     : out AxiStreamSlaveArray(1 downto 0);
      sUartCtrls      : out AxiStreamCtrlArray(1 downto 0);
      mUartMasters    : out AxiStreamMasterArray(1 downto 0);
      mUartSlaves     : in  AxiStreamSlaveArray(1 downto 0);
      -- Axi-Lite Interface
      axilClk         : in  sl;
      axilRst         : in  sl;
      axilReadMaster  : in  AxiLiteReadMasterType;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType;
      axilWriteSlave  : out AxiLiteWriteSlaveType);
end ClinkTop;

architecture rtl of ClinkTop is

   type RegType is record
      swConfig        : ClConfigArray(1 downto 0);
      config          : ClConfigArray(1 downto 0);
      axilReadSlave   : AxiLiteReadSlaveType;
      axilWriteSlave  : AxiLiteWriteSlaveType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      swConfig        => (others=>CL_CONFIG_INIT_C),
      config          => (others=>CL_CONFIG_INIT_C),
      axilReadSlave   => AXI_LITE_READ_SLAVE_INIT_C,
      axilWriteSlave  => AXI_LITE_WRITE_SLAVE_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal status         : ClStatusArray(1 downto 0);
   signal locked         : slv(2 downto 0);
   signal shiftCnt       : Slv8Array(2 downto 0);
   signal parData        : Slv28Array(2 downto 0);
   signal parValid       : slv(2 downto 0);
   signal parReady       : sl;
   signal frameReady     : slv(1 downto 0);
   signal intReadMaster  : AxiLiteReadMasterType;
   signal intReadSlave   : AxiLiteReadSlaveType;
   signal intWriteMaster : AxiLiteWriteMasterType;
   signal intWriteSlave  : AxiLiteWriteSlaveType;

begin

   ----------------------------------------
   -- IO Modules
   ----------------------------------------

   -- Connector 0, Half 0, Control for Base,Medium,Full,Deca
   U_Cbl0Half0: entity work.ClinkCtrl
      generic map (
         TPD_G              => TPD_G,
         SYS_CLK_FREQ_G     => SYS_CLK_FREQ_G,
         UART_READY_EN_G    => UART_READY_EN_G,
         UART_AXIS_CONFIG_G => UART_AXIS_CONFIG_G)
      port map (
         cblHalfP     => cbl0Half0P,
         cblHalfM     => cbl0Half0M,
         cblSerP      => cbl0SerP,
         cblSerM      => cbl0SerM,
         sysClk       => sysClk,
         sysRst       => sysRst,
         camCtrl      => camCtrl(0),
         config       => r.config(0),
         sUartMaster  => sUartMasters(0),
         sUartSlave   => sUartSlaves(0),
         sUartCtrl    => sUartCtrls(0),
         mUartMaster  => mUartMasters(0),
         mUartSlave   => mUartSlaves(0));

   -- Connector 0, Half 1, Data X for Base,Medium,Full,Deca
   U_Cbl0Half1: entity work.ClinkData
      generic map ( TPD_G => TPD_G )
      port map (
         cblHalfP  => cbl0Half1P,
         cblHalfM  => cbl0Half1M,
         sysClk    => sysClk,
         sysRst    => sysRst,
         locked    => locked(0),
         shiftCnt  => shiftCnt(0),
         parData   => parData(0),
         parValid  => parValid(0),
         parReady  => frameReady(0));

   -- Connector 1, Half 0, Control Base, Data Z for Med, Full, Deca
   U_Cbl1Half0: entity work.ClinkDual
      generic map (
         TPD_G              => TPD_G,
         SYS_CLK_FREQ_G     => SYS_CLK_FREQ_G,
         UART_READY_EN_G    => UART_READY_EN_G,
         UART_AXIS_CONFIG_G => UART_AXIS_CONFIG_G)
      port map (
         cblHalfP     => cbl1Half0P,
         cblHalfM     => cbl1Half0M,
         cblSerP      => cbl1SerP,
         cblSerM      => cbl1SerM,
         sysClk       => sysClk,
         sysRst       => sysRst,
         camCtrl      => camCtrl(1),
         config       => r.config(1),
         locked       => locked(2),
         shiftCnt     => shiftCnt(2),
         parData      => parData(2),
         parValid     => parValid(2),
         parReady     => frameReady(0),
         sUartMaster  => sUartMasters(1),
         sUartSlave   => sUartSlaves(1),
         sUartCtrl    => sUartCtrls(1),
         mUartMaster  => mUartMasters(1),
         mUartSlave   => mUartSlaves(1));

   -- Connector 1, Half 1, Data X for Base, Data Y for Med, Full, Deca
   U_Cbl1Half1: entity work.ClinkData
      generic map ( TPD_G => TPD_G )
      port map (
         cblHalfP  => cbl1Half1P,
         cblHalfM  => cbl1Half1M,
         sysClk    => sysClk,
         sysRst    => sysRst,
         locked    => locked(1),
         shiftCnt  => shiftCnt(1),
         parData   => parData(1),
         parValid  => parValid(1),
         parReady  => parReady);

   -- Ready generation
   parReady <= frameReady(1) when r.config(1).enable = '1' else frameReady(0);

   ---------------------------------
   -- Data Processing
   ---------------------------------
   U_Framer0 : entity work.ClinkFraming
      generic map (
         TPD_G              => TPD_G,
         DATA_AXIS_CONFIG_G => DATA_AXIS_CONFIG_G)
      port map (
         sysClk        => sysClk,
         sysRst        => sysRst,
         config        => r.config(0),
         status        => status(0),
         locked        => locked,
         parData       => parData,
         parValid      => parValid,
         parReady      => frameReady(0),
         dataMaster    => dataMasters(0),
         dataSlave     => dataSlaves(0));

   U_Framer1 : entity work.ClinkFraming
      generic map (
         TPD_G              => TPD_G,
         DATA_AXIS_CONFIG_G => DATA_AXIS_CONFIG_G)
      port map (
         sysClk        => sysClk,
         sysRst        => sysRst,
         config        => r.config(1),
         status        => status(1),
         locked(0)     => locked(1),
         locked(1)     => '0',
         locked(2)     => '0',
         parData(0)    => parData(1),
         parData(1)    => (others=>'0'),
         parData(2)    => (others=>'0'),
         parValid(0)   => parValid(1),
         parValid(1)   => '0',
         parValid(2)   => '0',
         parReady      => frameReady(1),
         dataMaster    => dataMasters(1),
         dataSlave     => dataSlaves(1));

   ---------------------------------
   -- AXIL Clock Transition
   ---------------------------------
   U_AxilAsync: entity work.AxiLiteAsync
      generic map (
         TPD_G            => TPD_G,
         AXI_ERROR_RESP_G => AXI_ERROR_RESP_G,
         COMMON_CLK_G     => AXI_COMMON_CLK_G)
      port map (
         sAxiClk         => axilClk,
         sAxiClkRst      => axilRst,
         sAxiReadMaster  => axilReadMaster,
         sAxiReadSlave   => axilReadSlave,
         sAxiWriteMaster => axilWriteMaster,
         sAxiWriteSlave  => axilWriteSlave,
         mAxiClk         => sysClk,
         mAxiClkRst      => sysRst,
         mAxiReadMaster  => intReadMaster,
         mAxiReadSlave   => intReadSlave,
         mAxiWriteMaster => intWriteMaster,
         mAxiWriteSlave  => intWriteSlave);

   ---------------------------------
   -- Registers
   ---------------------------------
   comb : process (r, sysRst, intReadMaster, intWriteMaster, locked, shiftCnt, status) is

      variable v      : RegType;
      variable axilEp : AxiLiteEndpointType;
   begin

      -- Latch the current value
      v := r;

      ------------------------      
      -- AXI-Lite Transactions
      ------------------------      

      -- Determine the transaction type
      axiSlaveWaitTxn(axilEp, intWriteMaster, intReadMaster, v.axilWriteSlave, v.axilReadSlave);

      -- Common Config
      axiSlaveRegister (axilEp, x"000",  0, v.config(0).linkMode);

      -- Common Status
      axiSlaveRegisterR(axilEp, x"004",  0, locked);
      axiSlaveRegisterR(axilEp, x"008",  0, shiftCnt(0));
      axiSlaveRegisterR(axilEp, x"008",  8, shiftCnt(1));
      axiSlaveRegisterR(axilEp, x"008", 16, shiftCnt(2));

      -- Channel A Config
      axiSlaveRegisterR(axilEp, x"100",  0, r.config(0).linkMode);
      axiSlaveRegister (axilEp, x"104",  0, v.swConfig(0).dataMode);
      axiSlaveRegister (axilEp, x"108",  0, v.swConfig(0).frameMode);
      axiSlaveRegister (axilEp, x"10C",  0, v.swConfig(0).dataEn);

      axiSlaveRegister (axilEp, x"110",  0, v.swConfig(0).serBaud);
      axiSlaveRegister (axilEp, x"114",  0, v.swConfig(0).swCamCtrlEn);
      axiSlaveRegister (axilEp, x"118",  0, v.swConfig(0).swCamCtrl);

      -- Channel A Status
      axiSlaveRegisterR(axilEp, x"120",  0, status(0).running);
      axiSlaveRegisterR(axilEp, x"124",  0, status(0).frameCount);
      axiSlaveRegisterR(axilEp, x"128",  0, status(0).dropCount);

      -- Channel B Config
      axiSlaveRegisterR(axilEp, x"200",  0, r.config(1).linkMode);
      axiSlaveRegister (axilEp, x"204",  0, v.swConfig(1).dataMode);
      axiSlaveRegister (axilEp, x"208",  0, v.swConfig(1).frameMode);
      axiSlaveRegister (axilEp, x"20C",  0, v.swConfig(1).dataEn);

      axiSlaveRegister (axilEp, x"210",  0, v.swConfig(1).serBaud);
      axiSlaveRegister (axilEp, x"214",  0, v.swConfig(1).swCamCtrlEn);
      axiSlaveRegister (axilEp, x"218",  0, v.swConfig(1).swCamCtrl);

      -- Channel B Status
      axiSlaveRegisterR(axilEp, x"220",  0, status(1).running);
      axiSlaveRegisterR(axilEp, x"224",  0, status(1).frameCount);
      axiSlaveRegisterR(axilEp, x"228",  0, status(1).dropCount);

      axiSlaveDefault(axilEp, v.axilWriteSlave, v.axilReadSlave, AXI_ERROR_RESP_G);

      ------------------------------
      -- Configuration Extraction
      ------------------------------
      v.config(0)        := r.swConfig(0);
      v.config(0).enable := '1';
      v.config(1)        := CL_CONFIG_INIT_C;

      if r.config(0).linkMode = CLM_BASE_C then
         v.config(1)          := r.swConfig(1);
         v.config(1).linkMode := CLM_BASE_C;
         v.config(1).enable   := '1';
      else
      end if;

      -------------
      -- Reset
      -------------
      if (sysRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs 
      intReadSlave  <= r.axilReadSlave;
      intWriteSlave <= r.axilWriteSlave;

   end process comb;

   seq : process (sysClk) is
   begin
      if (rising_edge(sysClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end architecture rtl;

