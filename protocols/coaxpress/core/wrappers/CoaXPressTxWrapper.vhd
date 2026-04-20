-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing wrapper for CoaXPressTx
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

library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;

entity CoaXPressTxWrapper is
   port (
      cfgClk       : in  sl;
      cfgRst       : in  sl;
      cfgTValid    : in  sl;
      cfgTData     : in  slv(7 downto 0);
      cfgTUser     : in  sl;
      cfgTLast     : in  sl;
      cfgTReady    : out sl;
      eventAck     : in  sl;
      eventTag     : in  slv(7 downto 0);
      txClk        : in  sl;
      txRst        : in  sl;
      txLsRate     : in  sl;
      txLsValid    : out sl;
      txLsData     : out slv(7 downto 0);
      txLsDataK    : out sl;
      txTrigInv    : in  sl;
      txPulseWidth : in  slv(31 downto 0);
      swTrig       : in  sl;
      txTrig       : in  sl;
      txTrigDrop   : out sl);
end entity CoaXPressTxWrapper;

architecture rtl of CoaXPressTxWrapper is

   signal cfgTxMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal cfgTxSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;

begin

   -- Flatten the byte-wide config AXI stream onto cocotb scalar ports.
   cfgTxMaster.tValid           <= cfgTValid;
   cfgTxMaster.tData(7 downto 0) <= cfgTData;
   cfgTxMaster.tKeep(0)         <= '1';
   cfgTxMaster.tUser(0)         <= cfgTUser;
   cfgTxMaster.tLast            <= cfgTLast;
   cfgTReady                    <= cfgTxSlave.tReady;

   U_DUT : entity surf.CoaXPressTx
      generic map (
         TPD_G => 1 ns)
      port map (
         cfgClk       => cfgClk,
         cfgRst       => cfgRst,
         cfgTxMaster  => cfgTxMaster,
         cfgTxSlave   => cfgTxSlave,
         eventAck     => eventAck,
         eventTag     => eventTag,
         txClk        => txClk,
         txRst        => txRst,
         txLsRate     => txLsRate,
         txLsValid    => txLsValid,
         txLsData     => txLsData,
         txLsDataK    => txLsDataK,
         txTrigInv    => txTrigInv,
         txPulseWidth => txPulseWidth,
         swTrig       => swTrig,
         txTrig       => txTrig,
         txTrigDrop   => txTrigDrop);

end architecture rtl;
