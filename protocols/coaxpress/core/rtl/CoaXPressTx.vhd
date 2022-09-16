-------------------------------------------------------------------------------
-- Title      : CoaXPress Protocol: http://jiia.org/wp-content/themes/jiia/pdf/standard_dl/coaxpress/CXP-001-2021.pdf
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: CoaXPress Transmit
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
use surf.CoaXPressPkg.all;
use surf.SsiPkg.all;

entity CoaXPressTx is
   generic (
      TPD_G        : time                   := 1 ns;
      TRIG_WIDTH_G : positive range 1 to 16 := 1);
   port (
      -- Config Interface (cfgClk domain)
      cfgClk      : in  sl;
      cfgRst      : in  sl;
      cfgTxMaster : in  AxiStreamMasterType;
      cfgTxSlave  : out AxiStreamSlaveType;
      -- TX Interface (txClk domain)
      txClk       : in  sl;
      txRst       : in  sl;
      txLsRate    : in  sl;
      txLsValid   : out sl;
      txLsData    : out slv(7 downto 0);
      txLsDataK   : out sl;
      txHsData    : out slv(31 downto 0);
      txHsDataK   : out slv(3 downto 0);
      swTrig      : in  slv(TRIG_WIDTH_G-1 downto 0);
      txTrig      : in  slv(TRIG_WIDTH_G-1 downto 0);
      txTrigDrop  : out slv(TRIG_WIDTH_G-1 downto 0));
end entity CoaXPressTx;

architecture mapping of CoaXPressTx is

   signal txMasters : AxiStreamMasterArray(1 downto 0);
   signal txSlaves  : AxiStreamSlaveArray(1 downto 0);

   signal cfgMasters : AxiStreamMasterArray(1 downto 0);
   signal cfgSlaves  : AxiStreamSlaveArray(1 downto 0);
   signal trigger    : slv(TRIG_WIDTH_G-1 downto 0);
   signal lsTrig     : sl;

   signal txHsTrigDrop : slv(TRIG_WIDTH_G-1 downto 0);
   signal txLsTrigDrop : slv(TRIG_WIDTH_G-1 downto 0) := (others => '0');

begin

   trigger    <= txTrig or swTrig;
   lsTrig     <= uOr(trigger);
   txTrigDrop <= txHsTrigDrop or txLsTrigDrop;

   U_Repeater : entity surf.AxiStreamRepeater
      generic map (
         TPD_G         => TPD_G,
         NUM_MASTERS_G => 2)
      port map (
         -- Clock and reset
         axisClk      => cfgClk,
         axisRst      => cfgRst,
         -- Slave
         sAxisMaster  => cfgTxMaster,
         sAxisSlave   => cfgTxSlave,
         -- Masters
         mAxisMasters => txMasters,
         mAxisSlaves  => txSlaves);

   U_HsFifo : entity surf.AxiStreamFifoV2
      generic map (
         -- General Configurations
         TPD_G               => TPD_G,
         VALID_THOLD_G       => 0,      -- 0 = store/forward AXIS FIFO
         -- FIFO configurations
         MEMORY_TYPE_G       => "block",
         GEN_SYNC_FIFO_G     => false,
         FIFO_ADDR_WIDTH_G   => 9,
         -- AXI Stream Port Configurations
         SLAVE_AXI_CONFIG_G  => ssiAxiStreamConfig(dataBytes => 1),  -- 8-bit interface
         MASTER_AXI_CONFIG_G => ssiAxiStreamConfig(dataBytes => 4))  -- 32-bit interface
      port map (
         -- Slave Port
         sAxisClk    => cfgClk,
         sAxisRst    => cfgRst,
         sAxisMaster => txMasters(0),
         sAxisSlave  => txSlaves(0),
         -- Master Port
         mAxisClk    => txClk,
         mAxisRst    => txRst,
         mAxisMaster => cfgMasters(0),
         mAxisSlave  => cfgSlaves(0));

   U_HsFsm : entity surf.CoaXPressTxHsFsm
      generic map (
         TPD_G        => TPD_G,
         TRIG_WIDTH_G => TRIG_WIDTH_G)
      port map (
         -- Clock and Reset
         txClk      => txClk,
         txRst      => txRst,
         -- Config Interface
         cfgMaster  => cfgMasters(0),
         cfgSlave   => cfgSlaves(0),
         -- Trigger Interface
         txTrig     => trigger,
         txTrigDrop => txHsTrigDrop,
         -- TX PHY Interface
         txData     => txHsData,
         txDataK    => txHsDataK);

   U_LsFifo : entity surf.AxiStreamFifoV2
      generic map (
         -- General Configurations
         TPD_G               => TPD_G,
         VALID_THOLD_G       => 0,      -- 0 = store/forward AXIS FIFO
         -- FIFO configurations
         MEMORY_TYPE_G       => "block",
         GEN_SYNC_FIFO_G     => false,
         FIFO_ADDR_WIDTH_G   => 9,
         -- AXI Stream Port Configurations
         SLAVE_AXI_CONFIG_G  => ssiAxiStreamConfig(dataBytes => 1),  -- 8-bit interface
         MASTER_AXI_CONFIG_G => ssiAxiStreamConfig(dataBytes => 1))  -- 8-bit interface
      port map (
         -- Slave Port
         sAxisClk    => cfgClk,
         sAxisRst    => cfgRst,
         sAxisMaster => txMasters(1),
         sAxisSlave  => txSlaves(1),
         -- Master Port
         mAxisClk    => txClk,
         mAxisRst    => txRst,
         mAxisMaster => cfgMasters(1),
         mAxisSlave  => cfgSlaves(1));

   U_LsFsm : entity surf.CoaXPressTxLsFsm
      generic map (
         TPD_G => TPD_G)
      port map (
         -- Clock and Reset
         txClk      => txClk,
         txRst      => txRst,
         -- Config Interface
         cfgMaster  => cfgMasters(1),
         cfgSlave   => cfgSlaves(1),
         -- Trigger Interface
         txTrig     => lsTrig,
         txTrigDrop => txLsTrigDrop(0),
         -- TX PHY Interface
         txRate     => txLsRate,
         txStrobe   => txLsValid,
         txData     => txLsData,
         txDataK    => txLsDataK);

end mapping;
