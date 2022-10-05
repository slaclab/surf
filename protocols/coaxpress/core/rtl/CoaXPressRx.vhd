-------------------------------------------------------------------------------
-- Title      : CoaXPress Protocol: http://jiia.org/wp-content/themes/jiia/pdf/standard_dl/coaxpress/CXP-001-2021.pdf
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: CoaXPress Receive
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
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;
use surf.SsiPkg.all;
use surf.CoaXPressPkg.all;

entity CoaXPressRx is
   generic (
      TPD_G              : time                   := 1 ns;
      NUM_LANES_G        : positive               := 1;
      RX_FSM_CNT_WIDTH_C : positive range 1 to 24 := 16;  -- Optimize this down w.r.t camera to help make timing in CoaXPressRxHsFsm.vhd
      AXIS_CONFIG_G      : AxiStreamConfigType);
   port (
      -- Data Interface (dataClk domain)
      dataClk        : in  sl;
      dataRst        : in  sl;
      dataMaster     : out AxiStreamMasterType;
      dataSlave      : in  AxiStreamSlaveType;
      imageHdrMaster : out AxiStreamMasterType;
      imageHdrSlave  : in  AxiStreamSlaveType;
      -- Config Interface (cfgClk domain)
      cfgClk         : in  sl;
      cfgRst         : in  sl;
      cfgRxMaster    : out AxiStreamMasterType;
      -- Event ACK Interface (cfgClk domain)
      eventAck       : out sl;
      eventTag       : out slv(7 downto 0);
      -- Trigger ACK Interface (txClk domain)
      txClk          : in  sl;
      txRst          : in  sl;
      trigAck        : out sl;
      -- Rx Interface (rxClk domain)
      rxClk          : in  slv(NUM_LANES_G-1 downto 0);
      rxRst          : in  slv(NUM_LANES_G-1 downto 0);
      rxData         : in  slv32Array(NUM_LANES_G-1 downto 0);
      rxDataK        : in  Slv4Array(NUM_LANES_G-1 downto 0);
      rxLinkUp       : in  slv(NUM_LANES_G-1 downto 0);
      rxOverflow     : out sl;
      rxFsmError     : out sl;
      rxFsmRst       : in  sl;          -- (rxClk(0) domain only)
      rxNumberOfLane : in  slv(2 downto 0));  -- (rxClk(0) domain only)
end entity CoaXPressRx;

architecture mapping of CoaXPressRx is

   constant NARROW_AXIS_CONFIG_C : AxiStreamConfigType := (
      TSTRB_EN_C    => false,
      TDATA_BYTES_C => 4,               -- 32-bits
      TDEST_BITS_C  => 0,
      TID_BITS_C    => 0,
      TKEEP_MODE_C  => TKEEP_NORMAL_C,
      TUSER_BITS_C  => 1,
      TUSER_MODE_C  => TUSER_NORMAL_C);

   constant WIDE_AXIS_CONFIG_C : AxiStreamConfigType := (
      TSTRB_EN_C    => NARROW_AXIS_CONFIG_C.TSTRB_EN_C,
      TDATA_BYTES_C => 4*NUM_LANES_G,   -- NUM_LANES_G x 32-bits
      TDEST_BITS_C  => NARROW_AXIS_CONFIG_C.TDEST_BITS_C,
      TID_BITS_C    => NARROW_AXIS_CONFIG_C.TID_BITS_C,
      TKEEP_MODE_C  => NARROW_AXIS_CONFIG_C.TKEEP_MODE_C,
      TUSER_BITS_C  => NARROW_AXIS_CONFIG_C.TUSER_BITS_C,
      TUSER_MODE_C  => NARROW_AXIS_CONFIG_C.TUSER_MODE_C);

   signal ioAck       : slv(NUM_LANES_G-1 downto 0);
   signal eventAckVec : slv(NUM_LANES_G-1 downto 0);
   signal eventTagVec : Slv8Array(NUM_LANES_G-1 downto 0);
   signal cfgMasters  : AxiStreamMasterArray(NUM_LANES_G-1 downto 0);

   signal dataMasters : AxiStreamMasterArray(NUM_LANES_G-1 downto 0);
   signal dataCtrls   : AxiStreamCtrlArray(NUM_LANES_G-1 downto 0);

   signal rxMasters : AxiStreamMasterArray(NUM_LANES_G-1 downto 0);
   signal rxSlaves  : AxiStreamSlaveArray(NUM_LANES_G-1 downto 0);

   signal rxMaster : AxiStreamMasterType;
   signal rxSlave  : AxiStreamSlaveType;
   signal rxCtrl   : AxiStreamCtrlType;

   signal fsmMaster : AxiStreamMasterType;
   signal hdrMaster : AxiStreamMasterType;
   signal hdrCtrl   : AxiStreamCtrlType;

   signal dataIntMaster : AxiStreamMasterType;
   signal dataIntSlave  : AxiStreamSlaveType;

   signal overflowData : slv(NUM_LANES_G-1 downto 0);

begin

   rxOverflow <= uOr(overflowData) or rxCtrl.overflow or hdrCtrl.overflow;

   GEN_LANE : for i in NUM_LANES_G-1 downto 0 generate

      U_Lane : entity surf.CoaXPressRxLane
         generic map (
            TPD_G => TPD_G)
         port map (
            -- Clock and Reset
            rxClk      => rxClk(i),
            rxRst      => rxRst(i),
            -- Config Interface
            cfgMaster  => cfgMasters(i),
            -- Data Interface
            dataMaster => dataMasters(i),
            -- ACK Interface
            ioAck      => ioAck(i),
            eventAck   => eventAckVec(i),
            eventTag   => eventTagVec(i),
            -- RX PHY Interface
            rxData     => rxData(i),
            rxDataK    => rxDataK(i),
            rxLinkUp   => rxLinkUp(i));

      U_Data : entity surf.AxiStreamFifoV2
         generic map (
            -- General Configurations
            TPD_G               => TPD_G,
            SLAVE_READY_EN_G    => false,
            -- FIFO configurations
            GEN_SYNC_FIFO_G     => false,
            FIFO_ADDR_WIDTH_G   => 10,
            -- AXI Stream Port Configurations
            SLAVE_AXI_CONFIG_G  => NARROW_AXIS_CONFIG_C,
            MASTER_AXI_CONFIG_G => WIDE_AXIS_CONFIG_C)
         port map (
            -- Slave Port
            sAxisClk    => rxClk(i),
            sAxisRst    => rxRst(i),
            sAxisMaster => dataMasters(i),
            sAxisCtrl   => dataCtrls(i),
            -- Master Port
            mAxisClk    => rxClk(0),
            mAxisRst    => rxFsmRst,
            mAxisMaster => rxMasters(i),
            mAxisSlave  => rxSlaves(i));

      overflowData(i) <= dataCtrls(i).overflow;

   end generate GEN_LANE;

   U_Mux : entity surf.CoaXPressRxLaneMux
      generic map (
         TPD_G       => TPD_G,
         NUM_LANES_G => NUM_LANES_G)
      port map (
         -- Clock and Reset
         rxClk     => rxClk(0),
         rxRst     => rxRst(0),
         -- Config Interface
         rxFsmRst  => rxFsmRst,
         numOfLane => rxNumberOfLane,
         -- Inbound Streams Interface
         rxMasters => rxMasters,
         rxSlaves  => rxSlaves,
         -- Outbound Stream Interface
         rxMaster  => rxMaster,
         rxSlave   => rxSlave);

   U_Fsm : entity surf.CoaXPressRxHsFsm
      generic map (
         TPD_G              => TPD_G,
         RX_FSM_CNT_WIDTH_C => RX_FSM_CNT_WIDTH_C,
         NUM_LANES_G        => NUM_LANES_G)
      port map (
         -- Clock and Reset
         rxClk      => rxClk(0),
         rxRst      => rxRst(0),
         -- Config/Status Interface
         rxFsmRst   => rxFsmRst,
         rxFsmError => rxFsmError,
         -- Inbound Stream Interface
         rxMaster   => rxMaster,
         rxSlave    => rxSlave,
         -- Outbound Image header Interface
         hdrMaster  => hdrMaster,
         -- Outbound Camera Data Interface
         dataMaster => fsmMaster);

   U_Hdr : entity surf.AxiStreamFifoV2
      generic map (
         -- General Configurations
         TPD_G               => TPD_G,
         SLAVE_READY_EN_G    => false,
         -- FIFO configurations
         MEMORY_TYPE_G       => "distributed",
         GEN_SYNC_FIFO_G     => false,
         FIFO_ADDR_WIDTH_G   => 4,
         -- AXI Stream Port Configurations
         SLAVE_AXI_CONFIG_G  => ssiAxiStreamConfig(dataBytes => (224/8), tDestBits => 0),
         MASTER_AXI_CONFIG_G => AXIS_CONFIG_G)
      port map (
         -- Slave Port
         sAxisClk    => rxClk(0),
         sAxisRst    => rxRst(0),
         sAxisMaster => hdrMaster,
         sAxisCtrl   => hdrCtrl,
         -- Master Port
         mAxisClk    => dataClk,
         mAxisRst    => dataRst,
         mAxisMaster => imageHdrMaster,
         mAxisSlave  => imageHdrSlave);

   U_DataFifo : entity surf.AxiStreamFifoV2
      generic map (
         TPD_G               => TPD_G,
         SLAVE_READY_EN_G    => false,
         GEN_SYNC_FIFO_G     => false,
         FIFO_ADDR_WIDTH_G   => 9,
         SLAVE_AXI_CONFIG_G  => ssiAxiStreamConfig(dataBytes => (4*NUM_LANES_G), tDestBits => 0),
         MASTER_AXI_CONFIG_G => AXIS_CONFIG_G)
      port map (
         -- INbound Interface
         sAxisClk    => rxClk(0),
         sAxisRst    => rxRst(0),
         sAxisMaster => fsmMaster,
         sAxisCtrl   => rxCtrl,
         -- Outbound Interface
         mAxisClk    => dataClk,
         mAxisRst    => dataRst,
         mAxisMaster => dataIntMaster,
         mAxisSlave  => dataIntSlave);

   U_DataSof : entity surf.SsiInsertSof
      generic map (
         -- General Configurations
         TPD_G               => TPD_G,
         -- FIFO configurations
         COMMON_CLK_G        => true,
         SLAVE_FIFO_G        => false,
         MASTER_FIFO_G       => false,
         -- AXI Stream Port Configurations
         SLAVE_AXI_CONFIG_G  => AXIS_CONFIG_G,
         MASTER_AXI_CONFIG_G => AXIS_CONFIG_G)
      port map (
         -- Slave Port
         sAxisClk    => dataClk,
         sAxisRst    => dataRst,
         sAxisMaster => dataIntMaster,
         sAxisSlave  => dataIntSlave,
         -- Master Port
         mAxisClk    => dataClk,
         mAxisRst    => dataRst,
         mAxisMaster => dataMaster,
         mAxisSlave  => dataSlave);

   U_Config : entity surf.AxiStreamFifoV2
      generic map (
         -- General Configurations
         TPD_G               => TPD_G,
         SLAVE_READY_EN_G    => false,
         -- FIFO configurations
         MEMORY_TYPE_G       => "distributed",
         GEN_SYNC_FIFO_G     => false,
         FIFO_ADDR_WIDTH_G   => 4,
         -- AXI Stream Port Configurations
         SLAVE_AXI_CONFIG_G  => ssiAxiStreamConfig(dataBytes => 8, tDestBits => 0),
         MASTER_AXI_CONFIG_G => ssiAxiStreamConfig(dataBytes => 8, tDestBits => 0))
      port map (
         -- Slave Port
         sAxisClk    => rxClk(0),
         sAxisRst    => rxRst(0),
         sAxisMaster => cfgMasters(0),
         -- Master Port
         mAxisClk    => cfgClk,
         mAxisRst    => cfgRst,
         mAxisMaster => cfgRxMaster,
         mAxisSlave  => AXI_STREAM_SLAVE_FORCE_C);

   U_trigAck : entity surf.SynchronizerOneShot
      generic map (
         TPD_G => TPD_G)
      port map (
         clk     => txClk,
         dataIn  => ioAck(0),
         dataOut => trigAck);

   U_eventAck : entity surf.SynchronizerFifo
      generic map (
         TPD_G        => TPD_G,
         DATA_WIDTH_G => 8)
      port map (
         -- Asynchronous Reset
         rst    => rxRst(0),
         -- Write Ports (wr_clk domain)
         wr_clk => rxClk(0),
         wr_en  => eventAckVec(0),
         din    => eventTagVec(0),
         -- Read Ports (rd_clk domain)
         rd_clk => cfgClk,
         valid  => eventAck,
         dout   => eventTag);

end mapping;
