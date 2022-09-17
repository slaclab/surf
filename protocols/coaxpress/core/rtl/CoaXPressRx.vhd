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
      TPD_G         : time     := 1 ns;
      NUM_LANES_G   : positive := 1;
      AXIS_CONFIG_G : AxiStreamConfigType);
   port (
      -- Data Interface (dataClk domain)
      dataClk     : in  sl;
      dataRst     : in  sl;
      dataMaster  : out AxiStreamMasterType;
      dataSlave   : in  AxiStreamSlaveType;
      -- Config Interface (cfgClk domain)
      cfgClk      : in  sl;
      cfgRst      : in  sl;
      cfgRxMaster : out AxiStreamMasterType;
      -- Event ACK Interface (cfgClk domain)
      eventAck    : out sl;
      eventTag    : out slv(7 downto 0);
      -- Trigger ACK Interface (txClk domain)
      txClk       : in  sl;
      txRst       : in  sl;
      trigAck     : out sl;
      -- Rx Interface (rxClk domain)
      rxClk       : in  slv(NUM_LANES_G-1 downto 0);
      rxRst       : in  slv(NUM_LANES_G-1 downto 0);
      rxData      : in  slv32Array(NUM_LANES_G-1 downto 0);
      rxDataK     : in  Slv4Array(NUM_LANES_G-1 downto 0);
      rxLinkUp    : in  slv(NUM_LANES_G-1 downto 0));
end entity CoaXPressRx;

architecture mapping of CoaXPressRx is

   signal ioAck       : slv(NUM_LANES_G-1 downto 0);
   signal eventAckVec : slv(NUM_LANES_G-1 downto 0);
   signal eventTagVec : Slv8Array(NUM_LANES_G-1 downto 0);
   signal cfgMasters  : AxiStreamMasterArray(NUM_LANES_G-1 downto 0);
   signal dataMasters : AxiStreamMasterArray(NUM_LANES_G-1 downto 0);

begin

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

   end generate GEN_LANE;

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
         SLAVE_AXI_CONFIG_G  => ssiAxiStreamConfig(dataBytes => 8),
         MASTER_AXI_CONFIG_G => ssiAxiStreamConfig(dataBytes => 8))
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

   U_Data : entity surf.SsiFifo
      generic map (
         -- General Configurations
         TPD_G               => TPD_G,
         SLAVE_READY_EN_G    => false,
         -- FIFO configurations
         MEMORY_TYPE_G       => "block",
         GEN_SYNC_FIFO_G     => false,
         FIFO_ADDR_WIDTH_G   => 9,
         -- AXI Stream Port Configurations
         SLAVE_AXI_CONFIG_G  => ssiAxiStreamConfig(4*NUM_LANES_G),
         MASTER_AXI_CONFIG_G => AXIS_CONFIG_G)
      port map (
         -- Slave Port
         sAxisClk       => rxClk(0),
         sAxisRst       => rxRst(0),
         sAxisMaster    => dataMasters(0),
         sAxisDropFrame => open,
         -- Master Port
         mAxisClk       => dataClk,
         mAxisRst       => dataRst,
         mAxisMaster    => dataMaster,
         mAxisSlave     => dataSlave);

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
