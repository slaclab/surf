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
      txData      : out slv(31 downto 0);
      txDataK     : out slv(3 downto 0);
      swTrig      : in  slv(TRIG_WIDTH_G-1 downto 0);
      txTrig      : in  slv(TRIG_WIDTH_G-1 downto 0);
      txTrigDrop  : out slv(TRIG_WIDTH_G-1 downto 0));
end entity CoaXPressTx;

architecture mapping of CoaXPressTx is

   signal cfgMaster : AxiStreamMasterType;
   signal cfgSlave  : AxiStreamSlaveType;

   signal trigger : slv(TRIG_WIDTH_G-1 downto 0);

begin

   trigger <= txTrig or swTrig;

   U_Fifo : entity surf.AxiStreamFifoV2
      generic map (
         -- General Configurations
         TPD_G               => TPD_G,
         -- FIFO configurations
         MEMORY_TYPE_G       => "block",
         GEN_SYNC_FIFO_G     => false,
         FIFO_ADDR_WIDTH_G   => 9,
         -- AXI Stream Port Configurations
         SLAVE_AXI_CONFIG_G  => ssiAxiStreamConfig(dataBytes => 4),
         MASTER_AXI_CONFIG_G => ssiAxiStreamConfig(dataBytes => 4))
      port map (
         -- Slave Port
         sAxisClk    => cfgClk,
         sAxisRst    => cfgRst,
         sAxisMaster => cfgTxMaster,
         sAxisSlave  => cfgTxSlave,
         -- Master Port
         mAxisClk    => txClk,
         mAxisRst    => txRst,
         mAxisMaster => cfgMaster,
         mAxisSlave  => cfgSlave);

   U_Fsm : entity surf.CoaXPressTxFsm
      generic map (
         TPD_G        => TPD_G,
         TRIG_WIDTH_G => TRIG_WIDTH_G)
      port map (
         -- Clock and Reset
         txClk      => txClk,
         txRst      => txRst,
         -- Config Interface
         cfgMaster  => cfgMaster,
         cfgSlave   => cfgSlave,
         -- Trigger Interface
         txTrig     => trigger,
         txTrigDrop => txTrigDrop,
         -- TX PHY Interface
         txData     => txData,
         txDataK    => txDataK);

end mapping;
