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
library unisim;
use unisim.vcomponents.all;

entity ClinkTop is
   generic (
      TPD_G              : time                 := 1 ns;
      CHAN_COUNT_G       : integer range 1 to 2 := 1;
      UART_READY_EN_G    : boolean              := true;
      DATA_AXIS_CONFIG_G : AxiStreamConfigType  := AXI_STREAM_CONFIG_INIT_C;
      UART_AXIS_CONFIG_G : AxiStreamConfigType  := AXI_STREAM_CONFIG_INIT_C);
   port (
      -- Connector 0, Half 0, Control for Base,Medium,Full,Deca
      cbl0Half0P      : inout slv(4 downto 0); -- 15, 17,  5,  6,  3
      cbl0Half0M      : inout slv(4 downto 0); --  2,  4, 18, 19, 16
      -- Connector 0, Half 1, Data X for Base,Medium,Full,Deca
      cbl0Half1P      : inout slv(4 downto 0); --  8, 10, 11, 12,  9
      cbl0Half1M      : inout slv(4 downto 0); -- 21, 23, 24, 25, 22
      -- Connector 0, Serial out
      cbl0SerP        : out   sl; -- 20
      cbl0SerM        : out   sl; -- 7
      -- Connector 1, Half 0, Control Base, Data Z for Med, Full, Deca
      cbl1Half0P      : inout slv(4 downto 0); --  2,  4,  5,  6, 3
      cbl1Half0M      : inout slv(4 downto 0); -- 15, 17, 18, 19 16
      -- Connector 1, Half 1, Data X for Base, Data Y for Med, Full, Deca
      cbl1Half1P      : inout slv(4 downto 0); --  8, 10, 11, 12,  9
      cbl1Half1M      : inout slv(4 downto 0); -- 21, 23, 24, 25, 22
      -- Connector 1, Serial out
      cbl1SerP        : out   sl; -- 20
      cbl1SerM        : out   sl; -- 7
      -- Delay clock and reset, 200Mhz
      dlyClk          : in  sl; 
      dlyRst          : in  sl; 
      -- System clock and reset, > 100 Mhz
      sysClk          : in  sl;
      sysRst          : in  sl;
      -- Camera Control Bits, async
      camCtrl         : in  Slv4Array(CHAN_COUNT_G-1 downto 0);
      -- Camera data
      dataClk         : in  sl;
      dataRst         : in  sl;
      dataMasters     : out AxiStreamMasterArray(CHAN_COUNT_G-1 downto 0);
      dataSlaves      : in  AxiStreamSlaveArray(CHAN_COUNT_G-1 downto 0);
      -- UART data
      uartClk         : in  sl;
      uartRst         : in  sl;
      sUartMasters    : in  AxiStreamMasterArray(CHAN_COUNT_G-1 downto 0);
      sUartSlaves     : out AxiStreamSlaveArray(CHAN_COUNT_G-1 downto 0);
      sUartCtrls      : out AxiStreamCtrlArray(CHAN_COUNT_G-1 downto 0);
      mUartMasters    : out AxiStreamMasterArray(CHAN_COUNT_G-1 downto 0);
      mUartSlaves     : in  AxiStreamSlaveArray(CHAN_COUNT_G-1 downto 0);
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
      chanConfig      : ClChanConfigArray(1 downto 0);
      linkConfig      : ClLinkConfigType;
      axilReadSlave   : AxiLiteReadSlaveType;
      axilWriteSlave  : AxiLiteWriteSlaveType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      chanConfig      => (others=>CL_CHAN_CONFIG_INIT_C),
      linkConfig      => CL_LINK_CONFIG_INIT_C,
      axilReadSlave   => AXI_LITE_READ_SLAVE_INIT_C,
      axilWriteSlave  => AXI_LITE_WRITE_SLAVE_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal chanStatus     : ClChanStatusArray(1 downto 0);
   signal linkStatus     : ClLinkStatusArray(2 downto 0);
   signal parData        : Slv28Array(2 downto 0);
   signal parValid       : slv(2 downto 0);
   signal frameReady     : slv(1 downto 0);
   signal intReadMaster  : AxiLiteReadMasterType;
   signal intReadSlave   : AxiLiteReadSlaveType;
   signal intWriteMaster : AxiLiteWriteMasterType;
   signal intWriteSlave  : AxiLiteWriteSlaveType;

   attribute MARK_DEBUG : string;
   attribute MARK_DEBUG of r : signal is "TRUE";

   attribute IODELAY_GROUP                 : string;
   attribute IODELAY_GROUP of U_IDelayCtrl : label is "CLINK_CORE";

begin

   ----------------------------------------
   -- IO Modules
   ----------------------------------------
   U_IdelayCtrl : IDELAYCTRL
      port map (
         RDY    => open,    -- 1-bit output: Ready output
         REFCLK => dlyClk,  -- 1-bit input: Reference clock input
         RST    => dlyRst); -- 1-bit input: Active high reset input

   -- Connector 0, Half 0, Control for Base,Medium,Full,Deca
   U_Cbl0Half0: entity work.ClinkCtrl
      generic map (
         TPD_G              => TPD_G,
         UART_READY_EN_G    => UART_READY_EN_G,
         UART_AXIS_CONFIG_G => UART_AXIS_CONFIG_G)
      port map (
         cblHalfP     => cbl0Half0P,
         cblHalfM     => cbl0Half0M,
         cblSerP      => cbl0SerP,
         cblSerM      => cbl0SerM,
         dlyClk       => dlyClk,
         dlyRst       => dlyRst,
         sysClk       => sysClk,
         sysRst       => sysRst,
         camCtrl      => camCtrl(0),
         chanConfig   => r.chanConfig(0),
         uartClk      => uartClk,
         uartRst      => uartRst,
         sUartMaster  => sUartMasters(0),
         sUartSlave   => sUartSlaves(0),
         sUartCtrl    => sUartCtrls(0),
         mUartMaster  => mUartMasters(0),
         mUartSlave   => mUartSlaves(0));

   -- Connector 0, Half 1, Data X for Base,Medium,Full,Deca
   U_Cbl0Half1: entity work.ClinkData
      generic map ( TPD_G => TPD_G)
      port map (
         cblHalfP   => cbl0Half1P,
         cblHalfM   => cbl0Half1M,
         dlyClk     => dlyClk,
         dlyRst     => dlyRst,
         sysClk     => sysClk,
         sysRst     => sysRst,
         linkConfig => r.linkConfig,
         linkStatus => linkStatus(0),
         parData    => parData(0),
         parValid   => parValid(0),
         parReady   => frameReady(0));

   -- Dual channel enable
   U_DualCtrlEn: if CHAN_COUNT_G = 2 generate

      -- Connector 1, Half 0, Control Base, Data Z for Med, Full, Deca
      U_Cbl1Half0: entity work.ClinkCtrl
         generic map (
            TPD_G              => TPD_G,
            UART_READY_EN_G    => UART_READY_EN_G,
            UART_AXIS_CONFIG_G => UART_AXIS_CONFIG_G)
         port map (
            cblHalfP     => cbl1Half0P,
            cblHalfM     => cbl1Half0M,
            cblSerP      => cbl1SerP,
            cblSerM      => cbl1SerM,
            dlyClk       => dlyClk,
            dlyRst       => dlyRst,
            sysClk       => sysClk,
            sysRst       => sysRst,
            camCtrl      => camCtrl(1),
            chanConfig   => r.chanConfig(1),
            uartClk      => uartClk,
            uartRst      => uartRst,
            sUartMaster  => sUartMasters(1),
            sUartSlave   => sUartSlaves(1),
            sUartCtrl    => sUartCtrls(1),
            mUartMaster  => mUartMasters(1),
            mUartSlave   => mUartSlaves(1));

      -- Unused signals
      linkStatus(2) <= CL_LINK_STATUS_INIT_C;
      parData(2)    <= (others=>'0');
      parValid(2)   <= '0';

   end generate;

   -- Dual channel disable
   U_DualCtrlDis: if CHAN_COUNT_G = 1 generate

      -- Connector 1, Half 0, Control Base, Data Z for Med, Full, Deca
      U_Cbl1Half0: entity work.ClinkData
         generic map ( 
            TPD_G    => TPD_G,
            INV_34_G => true)
         port map (
            cblHalfP   => cbl1Half0P,
            cblHalfM   => cbl1Half0M,
            dlyClk     => dlyClk,
            dlyRst     => dlyRst,
            sysClk     => sysClk,
            sysRst     => sysRst,
            linkConfig => r.linkConfig,
            linkStatus => linkStatus(2),
            parData    => parData(2),
            parValid   => parValid(2),
            parReady   => frameReady(0));

      U_SerOut: OBUFDS
         port map (
            I  => '0',
            O  => cbl1SerP,
            OB => cbl1SerM);

   end generate;

   -- Connector 1, Half 1, Data X for Base, Data Y for Med, Full, Deca
   U_Cbl1Half1: entity work.ClinkData
      generic map ( TPD_G => TPD_G )
      port map (
         cblHalfP   => cbl1Half1P,
         cblHalfM   => cbl1Half1M,
         dlyClk     => dlyClk,
         dlyRst     => dlyRst,
         sysClk     => sysClk,
         sysRst     => sysRst,
         linkConfig => r.linkConfig,
         linkStatus => linkStatus(1),
         parData    => parData(1),
         parValid   => parValid(1),
         parReady   => frameReady(1));

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
         chanConfig    => r.chanConfig(0),
         chanStatus    => chanStatus(0),
         linkStatus    => linkStatus,
         parData       => parData,
         parValid      => parValid,
         parReady      => frameReady(0),
         dataClk       => dataClk,
         dataRst       => dataRst,
         dataMaster    => dataMasters(0),
         dataSlave     => dataSlaves(0));

   -- Dual data processing enable
   U_DualFrameEn: if CHAN_COUNT_G = 2 generate

      U_Framer1 : entity work.ClinkFraming
         generic map (
            TPD_G              => TPD_G,
            DATA_AXIS_CONFIG_G => DATA_AXIS_CONFIG_G)
         port map (
            sysClk        => sysClk,
            sysRst        => sysRst,
            chanConfig    => r.chanConfig(1),
            chanStatus    => chanStatus(1),
            linkStatus(0) => linkStatus(1),
            linkStatus(1) => CL_LINK_STATUS_INIT_C,
            linkStatus(2) => CL_LINK_STATUS_INIT_C,
            parData(0)    => parData(1),
            parData(1)    => (others=>'0'),
            parData(2)    => (others=>'0'),
            parValid(0)   => parValid(1),
            parValid(1)   => '0',
            parValid(2)   => '0',
            parReady      => frameReady(1),
            dataClk       => dataClk,
            dataRst       => dataRst,
            dataMaster    => dataMasters(1),
            dataSlave     => dataSlaves(1));

   end generate;

   -- Dual data processing disable
   U_DualFrameDis: if CHAN_COUNT_G = 1 generate
      chanStatus(1)  <= CL_CHAN_STATUS_INIT_C;
      frameReady(1)  <= frameReady(0);
   end generate;

   ---------------------------------
   -- AXIL Clock Transition
   ---------------------------------
   U_AxilAsync: entity work.AxiLiteAsync
      generic map (
         TPD_G            => TPD_G,
         COMMON_CLK_G     => false)
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
   comb : process (r, sysRst, intReadMaster, intWriteMaster, chanStatus, linkStatus) is

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
      axiSlaveRegisterR(axilEp, x"000",  0, toSlv(CHAN_COUNT_G,4));
      axiSlaveRegister (axilEp, x"004",  0, v.linkConfig.reset);

      -- Common Status
      axiSlaveRegisterR(axilEp, x"010",  0, linkStatus(0).locked);
      axiSlaveRegisterR(axilEp, x"010",  1, linkStatus(1).locked);
      axiSlaveRegisterR(axilEp, x"010",  2, linkStatus(2).locked);
      axiSlaveRegisterR(axilEp, x"014",  0, linkStatus(0).shiftCnt);
      axiSlaveRegisterR(axilEp, x"014",  8, linkStatus(1).shiftCnt);
      axiSlaveRegisterR(axilEp, x"014", 16, linkStatus(2).shiftCnt);
      axiSlaveRegisterR(axilEp, x"018",  0, linkStatus(0).delay);
      axiSlaveRegisterR(axilEp, x"018",  8, linkStatus(1).delay);
      axiSlaveRegisterR(axilEp, x"018", 16, linkStatus(2).delay);

      -- Channel A Config
      axiSlaveRegister (axilEp, x"100",  0, v.chanConfig(0).linkMode);
      axiSlaveRegister (axilEp, x"104",  0, v.chanConfig(0).dataMode);
      axiSlaveRegister (axilEp, x"108",  0, v.chanConfig(0).frameMode);
      axiSlaveRegister (axilEp, x"10C",  0, v.chanConfig(0).tapCount);
      axiSlaveRegister (axilEp, x"110",  0, v.chanConfig(0).dataEn);
      axiSlaveRegister (axilEp, x"114",  0, v.chanConfig(0).serBaud);
      axiSlaveRegister (axilEp, x"118",  0, v.chanConfig(0).swCamCtrlEn);
      axiSlaveRegister (axilEp, x"11C",  0, v.chanConfig(0).swCamCtrl);

      -- Channel A Status
      axiSlaveRegisterR(axilEp, x"120",  0, chanStatus(0).running);
      axiSlaveRegisterR(axilEp, x"124",  0, chanStatus(0).frameCount);
      axiSlaveRegisterR(axilEp, x"128",  0, chanStatus(0).dropCount);

      -- Channel B Config
      axiSlaveRegister (axilEp, x"200",  0, v.chanConfig(1).linkMode);
      axiSlaveRegister (axilEp, x"204",  0, v.chanConfig(1).dataMode);
      axiSlaveRegister (axilEp, x"208",  0, v.chanConfig(1).frameMode);
      axiSlaveRegister (axilEp, x"20C",  0, v.chanConfig(1).tapCount);
      axiSlaveRegister (axilEp, x"210",  0, v.chanConfig(1).dataEn);
      axiSlaveRegister (axilEp, x"214",  0, v.chanConfig(1).serBaud);
      axiSlaveRegister (axilEp, x"218",  0, v.chanConfig(1).swCamCtrlEn);
      axiSlaveRegister (axilEp, x"21C",  0, v.chanConfig(1).swCamCtrl);

      -- Channel B Status
      axiSlaveRegisterR(axilEp, x"220",  0, chanStatus(1).running);
      axiSlaveRegisterR(axilEp, x"224",  0, chanStatus(1).frameCount);
      axiSlaveRegisterR(axilEp, x"228",  0, chanStatus(1).dropCount);

      axiSlaveDefault(axilEp, v.axilWriteSlave, v.axilReadSlave, AXI_RESP_DECERR_C);

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

