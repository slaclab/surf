-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing wrapper for CoaXPressTxLsFsm
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

entity CoaXPressTxLsFsmWrapper is
   port (
      txClk        : in  sl;
      txRst        : in  sl;
      cfgTValid    : in  sl;
      cfgTData     : in  slv(7 downto 0);
      cfgTUser     : in  sl;
      cfgTReady    : out sl;
      txTrig       : in  sl;
      txTrigInv    : in  sl;
      txPulseWidth : in  slv(31 downto 0);
      txRate       : in  sl;
      txTrigDrop   : out sl;
      txStrobe     : out sl;
      txData       : out slv(7 downto 0);
      txDataK      : out sl);
end entity CoaXPressTxLsFsmWrapper;

architecture rtl of CoaXPressTxLsFsmWrapper is

   signal cfgMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal cfgSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;

begin

   -- Drive the DUT's byte-wide AXI-stream config input from scalar ports.
   cfgMaster.tValid           <= cfgTValid;
   cfgMaster.tData(7 downto 0) <= cfgTData;
   cfgMaster.tUser(0)         <= cfgTUser;
   cfgTReady                  <= cfgSlave.tReady;

   -- Instantiate the real low-speed transmit FSM behind the flat ports.
   U_DUT : entity surf.CoaXPressTxLsFsm
      generic map (
         TPD_G => 1 ns)
      port map (
         txClk        => txClk,
         txRst        => txRst,
         cfgMaster    => cfgMaster,
         cfgSlave     => cfgSlave,
         txTrig       => txTrig,
         txTrigInv    => txTrigInv,
         txPulseWidth => txPulseWidth,
         txTrigDrop   => txTrigDrop,
         txRate       => txRate,
         txStrobe     => txStrobe,
         txData       => txData,
         txDataK      => txDataK);

end architecture rtl;
