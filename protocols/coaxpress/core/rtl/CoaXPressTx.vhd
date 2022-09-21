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
      TPD_G : time := 1 ns);
   port (
      -- Config Interface (cfgClk domain)
      cfgClk       : in  sl;
      cfgRst       : in  sl;
      cfgTxMaster  : in  AxiStreamMasterType;
      cfgTxSlave   : out AxiStreamSlaveType;
      -- Event ACK Interface (cfgClk domain)
      eventAck     : in  sl;
      eventTag     : in  slv(7 downto 0);
      -- TX PHY Interface (txClk domain)
      txClk        : in  sl;
      txRst        : in  sl;
      txLsRate     : in  sl;
      txLsValid    : out sl;
      txLsData     : out slv(7 downto 0);
      txLsDataK    : out sl;
      -- Trigger Interface (txClk domain)
      txTrigInv    : in  sl;
      txPulseWidth : in  slv(31 downto 0);
      swTrig       : in  sl;
      txTrig       : in  sl;
      txTrigDrop   : out sl);
end entity CoaXPressTx;

architecture mapping of CoaXPressTx is

   signal eventAckMaster : AxiStreamMasterType;
   signal eventAckSlave  : AxiStreamSlaveType;

   signal txMaster : AxiStreamMasterType;
   signal txSlave  : AxiStreamSlaveType;

   signal cfgMaster : AxiStreamMasterType;
   signal cfgSlave  : AxiStreamSlaveType;

   signal trigger : sl;
   signal txIndex : slv(1 downto 0);

begin

   U_EventAckMsg : entity surf.CoaXPressEventAckMsg
      generic map (
         TPD_G => TPD_G)
      port map (
         -- Clock and Reset
         clk            => cfgClk,
         rst            => cfgRst,
         -- Event ACK Interface
         eventAck       => eventAck,
         eventTag       => eventTag,
         -- AXI Stream Interface
         eventAckMaster => eventAckMaster,
         eventAckSlave  => eventAckSlave);

   U_Mux : entity surf.AxiStreamMux
      generic map (
         TPD_G         => TPD_G,
         NUM_SLAVES_G  => 2,
         PIPE_STAGES_G => 1)
      port map (
         -- Clock and reset
         axisClk         => cfgClk,
         axisRst         => cfgRst,
         -- Slaves
         sAxisMasters(0) => cfgTxMaster,
         sAxisMasters(1) => eventAckMaster,
         sAxisSlaves(0)  => cfgTxSlave,
         sAxisSlaves(1)  => eventAckSlave,
         -- Master
         mAxisMaster     => txMaster,
         mAxisSlave      => txSlave);

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
         sAxisMaster => txMaster,
         sAxisSlave  => txSlave,
         -- Master Port
         mAxisClk    => txClk,
         mAxisRst    => txRst,
         mAxisMaster => cfgMaster,
         mAxisSlave  => cfgSlave);

   U_LsFsm : entity surf.CoaXPressTxLsFsm
      generic map (
         TPD_G => TPD_G)
      port map (
         -- Clock and Reset
         txClk        => txClk,
         txRst        => txRst,
         -- Config Interface
         cfgMaster    => cfgMaster,
         cfgSlave     => cfgSlave,
         -- Trigger Interface
         txTrigInv    => txTrigInv,
         txPulseWidth => txPulseWidth,
         txTrig       => trigger,
         txTrigDrop   => txTrigDrop,
         -- TX PHY Interface
         txRate       => txLsRate,
         txStrobe     => txLsValid,
         txData       => txLsData,
         txDataK      => txLsDataK);

   trigger <= txTrig or swTrig;

end mapping;
