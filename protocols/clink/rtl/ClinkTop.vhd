-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
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

library surf;
use surf.StdRtlPkg.all;
use surf.ClinkPkg.all;
use surf.AxiLitePkg.all;
use surf.AxiStreamPkg.all;
library unisim;
use unisim.vcomponents.all;

entity ClinkTop is
   generic (
      TPD_G              : time                 := 1 ns;
      XIL_DEVICE_G       : string               := "7SERIES";
      CHAN_COUNT_G       : integer range 1 to 2 := 1;
      UART_READY_EN_G    : boolean              := true;
      COMMON_AXIL_CLK_G  : boolean              := false;  -- true if axilClk=sysClk
      COMMON_DATA_CLK_G  : boolean              := false;  -- true if dataClk=sysClk
      DATA_AXIS_CONFIG_G : AxiStreamConfigType;
      UART_AXIS_CONFIG_G : AxiStreamConfigType;
      AXIL_BASE_ADDR_G   : slv(31 downto 0));
   port (
      -- Connector 0, Half 0, Control for Base,Medium,Full,Deca
      cbl0Half0P      : inout slv(4 downto 0);  -- 15, 17,  5,  6,  3
      cbl0Half0M      : inout slv(4 downto 0);  --  2,  4, 18, 19, 16
      -- Connector 0, Half 1, Data X for Base,Medium,Full,Deca
      cbl0Half1P      : inout slv(4 downto 0);  --  8, 10, 11, 12,  9
      cbl0Half1M      : inout slv(4 downto 0);  -- 21, 23, 24, 25, 22
      -- Connector 0, Serial out
      cbl0SerP        : out   sl;       -- 20
      cbl0SerM        : out   sl;       -- 7
      -- Connector 1, Half 0, Control Base, Data Z for Med, Full, Deca
      cbl1Half0P      : inout slv(4 downto 0);  --  2,  4,  5,  6, 3
      cbl1Half0M      : inout slv(4 downto 0);  -- 15, 17, 18, 19 16
      -- Connector 1, Half 1, Data X for Base, Data Y for Med, Full, Deca
      cbl1Half1P      : inout slv(4 downto 0);  --  8, 10, 11, 12,  9
      cbl1Half1M      : inout slv(4 downto 0);  -- 21, 23, 24, 25, 22
      -- Connector 1, Serial out
      cbl1SerP        : out   sl;       -- 20
      cbl1SerM        : out   sl;       -- 7
      -- Delay clock and reset, 200Mhz
      dlyClk          : in    sl;
      dlyRst          : in    sl;
      -- System clock and reset, > 100 Mhz
      sysClk          : in    sl;
      sysRst          : in    sl;
      -- Camera Control Bits & status, async
      camCtrl         : in    Slv4Array(CHAN_COUNT_G-1 downto 0);
      camStatus       : out   ClChanStatusArray(1 downto 0);
      -- Camera data
      dataClk         : in    sl;
      dataRst         : in    sl;
      dataMasters     : out   AxiStreamMasterArray(CHAN_COUNT_G-1 downto 0);
      dataSlaves      : in    AxiStreamSlaveArray(CHAN_COUNT_G-1 downto 0);
      -- UART data
      uartClk         : in    sl;
      uartRst         : in    sl;
      sUartMasters    : in    AxiStreamMasterArray(CHAN_COUNT_G-1 downto 0);
      sUartSlaves     : out   AxiStreamSlaveArray(CHAN_COUNT_G-1 downto 0);
      sUartCtrls      : out   AxiStreamCtrlArray(CHAN_COUNT_G-1 downto 0);
      mUartMasters    : out   AxiStreamMasterArray(CHAN_COUNT_G-1 downto 0);
      mUartSlaves     : in    AxiStreamSlaveArray(CHAN_COUNT_G-1 downto 0);
      -- Axi-Lite Interface
      axilClk         : in    sl;
      axilRst         : in    sl;
      axilReadMaster  : in    AxiLiteReadMasterType;
      axilReadSlave   : out   AxiLiteReadSlaveType;
      axilWriteMaster : in    AxiLiteWriteMasterType;
      axilWriteSlave  : out   AxiLiteWriteSlaveType);
end ClinkTop;

architecture rtl of ClinkTop is

   constant NUM_AXIL_MASTERS_C : natural := 4;

   constant MAIN_INDEX_C : natural := 0;
   constant DRP0_INDEX_C : natural := 1;
   constant DRP1_INDEX_C : natural := 2;
   constant DRP2_INDEX_C : natural := 3;

   constant XBAR_CONFIG_C : AxiLiteCrossbarMasterConfigArray(NUM_AXIL_MASTERS_C-1 downto 0) := genAxiLiteConfig(NUM_AXIL_MASTERS_C, AXIL_BASE_ADDR_G, 14, 12);

   signal intReadMaster  : AxiLiteReadMasterType;
   signal intReadSlave   : AxiLiteReadSlaveType;
   signal intWriteMaster : AxiLiteWriteMasterType;
   signal intWriteSlave  : AxiLiteWriteSlaveType;

   signal axilWriteMasters : AxiLiteWriteMasterArray(NUM_AXIL_MASTERS_C-1 downto 0);
   signal axilWriteSlaves  : AxiLiteWriteSlaveArray(NUM_AXIL_MASTERS_C-1 downto 0);
   signal axilReadMasters  : AxiLiteReadMasterArray(NUM_AXIL_MASTERS_C-1 downto 0);
   signal axilReadSlaves   : AxiLiteReadSlaveArray(NUM_AXIL_MASTERS_C-1 downto 0);

   signal chanConfig : ClChanConfigArray(1 downto 0);
   signal linkConfig : ClLinkConfigType;
   signal chanStatus : ClChanStatusArray(1 downto 0) := (others => CL_CHAN_STATUS_INIT_C);
   signal linkStatus : ClLinkStatusArray(2 downto 0) := (others => CL_LINK_STATUS_INIT_C);
   signal parData    : Slv28Array(2 downto 0);
   signal parValid   : slv(2 downto 0);
   signal frameReady : slv(1 downto 0);


   attribute IODELAY_GROUP                 : string;
   attribute IODELAY_GROUP of U_IDelayCtrl : label is "CLINK_CORE";

begin

   camStatus <= chanStatus;

   ---------------------
   -- IDELAYCTRL Modules
   ---------------------
   U_IdelayCtrl : IDELAYCTRL
      generic map (
         SIM_DEVICE => XIL_DEVICE_G)
      port map (
         RDY    => open,                -- 1-bit output: Ready output
         REFCLK => dlyClk,              -- 1-bit input: Reference clock input
         RST    => dlyRst);             -- 1-bit input: Active high reset input

   ----------------------------
   -- AXI-Lite Clock Transition
   ----------------------------
   U_AxilAsync : entity surf.AxiLiteAsync
      generic map (
         TPD_G        => TPD_G,
         COMMON_CLK_G => COMMON_AXIL_CLK_G)
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

   --------------------------
   -- AXI-Lite: Crossbar Core
   --------------------------
   U_XBAR : entity surf.AxiLiteCrossbar
      generic map (
         TPD_G              => TPD_G,
         NUM_SLAVE_SLOTS_G  => 1,
         NUM_MASTER_SLOTS_G => NUM_AXIL_MASTERS_C,
         MASTERS_CONFIG_G   => XBAR_CONFIG_C)
      port map (
         axiClk              => sysClk,
         axiClkRst           => sysRst,
         sAxiWriteMasters(0) => intWriteMaster,
         sAxiWriteSlaves(0)  => intWriteSlave,
         sAxiReadMasters(0)  => intReadMaster,
         sAxiReadSlaves(0)   => intReadSlave,
         mAxiWriteMasters    => axilWriteMasters,
         mAxiWriteSlaves     => axilWriteSlaves,
         mAxiReadMasters     => axilReadMasters,
         mAxiReadSlaves      => axilReadSlaves);

   ---------------------------
   -- AXI-Lite Register Module
   ---------------------------
   U_ClinkReg : entity surf.ClinkReg
      generic map (
         TPD_G        => TPD_G,
         CHAN_COUNT_G => CHAN_COUNT_G)
      port map (
         chanStatus      => chanStatus,
         linkStatus      => linkStatus,
         chanConfig      => chanConfig,
         linkConfig      => linkConfig,
         -- Axi-Lite Interface
         sysClk          => sysClk,
         sysRst          => sysRst,
         axilReadMaster  => axilReadMasters(MAIN_INDEX_C),
         axilReadSlave   => axilReadSlaves(MAIN_INDEX_C),
         axilWriteMaster => axilWriteMasters(MAIN_INDEX_C),
         axilWriteSlave  => axilWriteSlaves(MAIN_INDEX_C));

   ---------------------------------------------------------
   -- Connector 0, Half 0, Control for Base,Medium,Full,Deca
   ---------------------------------------------------------
   U_Cbl0Half0 : entity surf.ClinkCtrl
      generic map (
         TPD_G              => TPD_G,
         INV_34_G           => false,
         UART_READY_EN_G    => UART_READY_EN_G,
         UART_AXIS_CONFIG_G => UART_AXIS_CONFIG_G)
      port map (
         cblHalfP    => cbl0Half0P,
         cblHalfM    => cbl0Half0M,
         cblSerP     => cbl0SerP,
         cblSerM     => cbl0SerM,
         dlyClk      => dlyClk,
         dlyRst      => dlyRst,
         sysClk      => sysClk,
         sysRst      => sysRst,
         camCtrl     => camCtrl(0),
         chanConfig  => chanConfig(0),
         uartClk     => uartClk,
         uartRst     => uartRst,
         sUartMaster => sUartMasters(0),
         sUartSlave  => sUartSlaves(0),
         sUartCtrl   => sUartCtrls(0),
         mUartMaster => mUartMasters(0),
         mUartSlave  => mUartSlaves(0));

   --------------------------------------------------------
   -- Connector 0, Half 1, Data X for Base,Medium,Full,Deca
   --------------------------------------------------------
   U_Cbl0Half1 : entity surf.ClinkData
      generic map (
         TPD_G        => TPD_G,
         XIL_DEVICE_G => XIL_DEVICE_G)
      port map (
         cblHalfP        => cbl0Half1P,
         cblHalfM        => cbl0Half1M,
         dlyClk          => dlyClk,
         dlyRst          => dlyRst,
         sysClk          => sysClk,
         sysRst          => sysRst,
         linkConfig      => linkConfig,
         linkStatus      => linkStatus(0),
         parData         => parData(0),
         parValid        => parValid(0),
         parReady        => frameReady(0),
         -- AXI-Lite Interface
         axilReadMaster  => axilReadMasters(DRP0_INDEX_C),
         axilReadSlave   => axilReadSlaves(DRP0_INDEX_C),
         axilWriteMaster => axilWriteMasters(DRP0_INDEX_C),
         axilWriteSlave  => axilWriteSlaves(DRP0_INDEX_C));

   ----------------------
   -- Dual channel enable
   ----------------------
   U_DualCtrlEn : if (CHAN_COUNT_G = 2) generate

      ----------------------------------------------------------------
      -- Connector 1, Half 0, Control Base, Data Z for Med, Full, Deca
      ----------------------------------------------------------------
      U_Cbl1Half0 : entity surf.ClinkCtrl
         generic map (
            TPD_G              => TPD_G,
            INV_34_G           => true,
            UART_READY_EN_G    => UART_READY_EN_G,
            UART_AXIS_CONFIG_G => UART_AXIS_CONFIG_G)
         port map (
            cblHalfP    => cbl1Half0P,
            cblHalfM    => cbl1Half0M,
            cblSerP     => cbl1SerP,
            cblSerM     => cbl1SerM,
            dlyClk      => dlyClk,
            dlyRst      => dlyRst,
            sysClk      => sysClk,
            sysRst      => sysRst,
            camCtrl     => camCtrl(1),
            chanConfig  => chanConfig(1),
            uartClk     => uartClk,
            uartRst     => uartRst,
            sUartMaster => sUartMasters(1),
            sUartSlave  => sUartSlaves(1),
            sUartCtrl   => sUartCtrls(1),
            mUartMaster => mUartMasters(1),
            mUartSlave  => mUartSlaves(1));

      -----------------
      -- Unused signals
      -----------------
      linkStatus(2) <= CL_LINK_STATUS_INIT_C;
      parData(2)    <= (others => '0');
      parValid(2)   <= '0';
      U_UnusedDrp : entity surf.AxiDualPortRam
         generic map (
            TPD_G        => TPD_G,
            ADDR_WIDTH_G => 7,
            DATA_WIDTH_G => 16)
         port map (
            -- AXI-Lite Interface
            axiClk         => sysClk,
            axiRst         => sysRst,
            axiReadMaster  => axilReadMasters(DRP2_INDEX_C),
            axiReadSlave   => axilReadSlaves(DRP2_INDEX_C),
            axiWriteMaster => axilWriteMasters(DRP2_INDEX_C),
            axiWriteSlave  => axilWriteSlaves(DRP2_INDEX_C));

   end generate;

   -----------------------
   -- Dual channel disable
   -----------------------
   U_DualCtrlDis : if (CHAN_COUNT_G = 1) generate

      ----------------------------------------------------------------
      -- Connector 1, Half 0, Control Base, Data Z for Med, Full, Deca
      ----------------------------------------------------------------
      U_Cbl1Half0 : entity surf.ClinkData
         generic map (TPD_G => TPD_G)
         port map (
            cblHalfP        => cbl1Half0P,
            cblHalfM        => cbl1Half0M,
            dlyClk          => dlyClk,
            dlyRst          => dlyRst,
            sysClk          => sysClk,
            sysRst          => sysRst,
            linkConfig      => linkConfig,
            linkStatus      => linkStatus(2),
            parData         => parData(2),
            parValid        => parValid(2),
            parReady        => frameReady(0),
            -- AXI-Lite Interface
            axilReadMaster  => axilReadMasters(DRP2_INDEX_C),
            axilReadSlave   => axilReadSlaves(DRP2_INDEX_C),
            axilWriteMaster => axilWriteMasters(DRP2_INDEX_C),
            axilWriteSlave  => axilWriteSlaves(DRP2_INDEX_C));

      -----------------
      -- Unused signals
      -----------------
      U_SerOut : OBUFDS
         port map (
            I  => '0',
            O  => cbl1SerP,
            OB => cbl1SerM);

   end generate;

   -------------------------------------------------------------------
   -- Connector 1, Half 1, Data X for Base, Data Y for Med, Full, Deca
   -------------------------------------------------------------------
   U_Cbl1Half1 : entity surf.ClinkData
      generic map (TPD_G => TPD_G)
      port map (
         cblHalfP        => cbl1Half1P,
         cblHalfM        => cbl1Half1M,
         dlyClk          => dlyClk,
         dlyRst          => dlyRst,
         sysClk          => sysClk,
         sysRst          => sysRst,
         linkConfig      => linkConfig,
         linkStatus      => linkStatus(1),
         parData         => parData(1),
         parValid        => parValid(1),
         parReady        => frameReady(1),
         -- AXI-Lite Interface
         axilReadMaster  => axilReadMasters(DRP1_INDEX_C),
         axilReadSlave   => axilReadSlaves(DRP1_INDEX_C),
         axilWriteMaster => axilWriteMasters(DRP1_INDEX_C),
         axilWriteSlave  => axilWriteSlaves(DRP1_INDEX_C));

   ------------------
   -- Data Processing
   ------------------
   U_Framer0 : entity surf.ClinkFraming
      generic map (
         TPD_G              => TPD_G,
         COMMON_DATA_CLK_G  => COMMON_DATA_CLK_G,
         DATA_AXIS_CONFIG_G => DATA_AXIS_CONFIG_G)
      port map (
         sysClk     => sysClk,
         sysRst     => sysRst,
         chanConfig => chanConfig(0),
         chanStatus => chanStatus(0),
         linkStatus => linkStatus,
         parData    => parData,
         parValid   => parValid,
         parReady   => frameReady(0),
         dataClk    => dataClk,
         dataRst    => dataRst,
         dataMaster => dataMasters(0),
         dataSlave  => dataSlaves(0));

   ------------------------------
   -- Dual data processing enable
   ------------------------------
   U_DualFrameEn : if (CHAN_COUNT_G = 2) generate

      U_Framer1 : entity surf.ClinkFraming
         generic map (
            TPD_G              => TPD_G,
            COMMON_DATA_CLK_G  => COMMON_DATA_CLK_G,
            DATA_AXIS_CONFIG_G => DATA_AXIS_CONFIG_G)
         port map (
            sysClk        => sysClk,
            sysRst        => sysRst,
            chanConfig    => chanConfig(1),
            chanStatus    => chanStatus(1),
            linkStatus(0) => linkStatus(1),
            linkStatus(1) => CL_LINK_STATUS_INIT_C,
            linkStatus(2) => CL_LINK_STATUS_INIT_C,
            parData(0)    => parData(1),
            parData(1)    => (others => '0'),
            parData(2)    => (others => '0'),
            parValid(0)   => parValid(1),
            parValid(1)   => '0',
            parValid(2)   => '0',
            parReady      => frameReady(1),
            dataClk       => dataClk,
            dataRst       => dataRst,
            dataMaster    => dataMasters(1),
            dataSlave     => dataSlaves(1));

   end generate;

   -------------------------------
   -- Dual data processing disable
   -------------------------------
   U_DualFrameDis : if CHAN_COUNT_G = 1 generate
      chanStatus(1) <= CL_CHAN_STATUS_INIT_C;
      frameReady(1) <= frameReady(0);
   end generate;

end rtl;
