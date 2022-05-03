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
      dataClk        : in  sl;
      dataRst        : in  sl;
      dataMaster     : out AxiStreamMasterType;
      dataSlave      : in  AxiStreamSlaveType;
      -- Config Interface (cfgClk domain)
      cfgClk         : in  sl;
      cfgRst         : in  sl;
      cfgObMaster    : out AxiStreamMasterType;
      cfgObSlave     : in  AxiStreamSlaveType;
      -- Rx Interface (rxClk domain)
      rxClk          : in  slv(NUM_LANES_G-1 downto 0);
      rxRst          : in  slv(NUM_LANES_G-1 downto 0);
      rxFifoRst      : in  sl;
      rxCfgDrop      : out sl;
      rxDataDrop     : out sl;
      rxFifoOverflow : out slv(NUM_LANES_G-1 downto 0);
      rxData         : in  slv32Array(NUM_LANES_G-1 downto 0);
      rxDataK        : in  Slv4Array(NUM_LANES_G-1 downto 0);
      rxLinkUp       : in  slv(NUM_LANES_G-1 downto 0));
end entity CoaXPressRx;

architecture mapping of CoaXPressRx is

   signal rxCfgMaster  : AxiStreamMasterType;
   signal rxDataMaster : AxiStreamMasterType;

   signal data  : slv32Array(NUM_LANES_G-1 downto 0);
   signal dataK : Slv4Array(NUM_LANES_G-1 downto 0);

   signal rxValid : slv(NUM_LANES_G-1 downto 0);
   signal rxReady : slv(NUM_LANES_G-1 downto 0);

   signal fifoRst : sl;
   signal fifWr   : slv(NUM_LANES_G-1 downto 0);

begin

   fifoRst <= uOr(not(rxLinkUp)) or rxFifoRst;

   GEN_LANE : for i in NUM_LANES_G-1 downto 0 generate

      -- Don't write the IDLEs
      fifWr(i) <= '0' when(rxData(i) = CXP_IDLE_C) and (rxDataK(i) = CXP_IDLE_K_C) else '1';

      U_Fifo : entity surf.FifoAsync
         generic map (
            TPD_G         => TPD_G,
            MEMORY_TYPE_G => "block",
            FWFT_EN_G     => true,
            PIPE_STAGES_G => 0,
            DATA_WIDTH_G  => 36,
            ADDR_WIDTH_G  => 10)
         port map (
            rst                => fifoRst,
            -- Write Ports
            wr_clk             => rxClk(i),
            wr_en              => fifWr(i),
            din(31 downto 0)   => rxData(i),
            din(35 downto 32)  => rxDataK(i),
            overflow           => rxFifoOverflow(i),
            -- Read Ports
            rd_clk             => rxClk(0),
            valid              => rxValid(i),
            rd_en              => rxReady(i),
            dout(31 downto 0)  => data(i),
            dout(35 downto 32) => dataK(i));

   end generate GEN_LANE;

   -------------
   -- FSM Module
   -------------
   U_Fsm : entity surf.CoaXPressRxFsm
      generic map (
         TPD_G       => TPD_G,
         NUM_LANES_G => NUM_LANES_G)
      port map (
         -- Clock and Reset
         rxClk      => rxClk(0),
         rxRst      => rxRst(0),
         -- Config Interface
         cfgMaster  => rxCfgMaster,
         -- Data Interface
         dataMaster => rxDataMaster,
         -- TX PHY Interface
         rxValid    => rxValid,
         rxReady    => rxReady,
         rxData     => data,
         rxDataK    => dataK,
         rxLinkUp   => rxLinkUp);

   --------------
   -- Config FIFO
   --------------
   U_cfgOb : entity surf.SsiFifo
      generic map (
         -- General Configurations
         TPD_G               => TPD_G,
         SLAVE_READY_EN_G    => false,
         -- FIFO configurations
         MEMORY_TYPE_G       => "block",
         GEN_SYNC_FIFO_G     => false,
         FIFO_ADDR_WIDTH_G   => 9,
         -- AXI Stream Port Configurations
         SLAVE_AXI_CONFIG_G  => ssiAxiStreamConfig(4),
         MASTER_AXI_CONFIG_G => AXIS_CONFIG_G)
      port map (
         -- Slave Port
         sAxisClk       => rxClk(0),
         sAxisRst       => rxRst(0),
         sAxisMaster    => rxCfgMaster,
         sAxisDropFrame => rxCfgDrop,
         -- Master Port
         mAxisClk       => cfgClk,
         mAxisRst       => cfgRst,
         mAxisMaster    => cfgObMaster,
         mAxisSlave     => cfgObSlave);

   ------------
   -- Data FIFO
   ------------
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
         sAxisMaster    => rxDataMaster,
         sAxisDropFrame => rxDataDrop,
         -- Master Port
         mAxisClk       => dataClk,
         mAxisRst       => dataRst,
         mAxisMaster    => dataMaster,
         mAxisSlave     => dataSlave);

end mapping;
