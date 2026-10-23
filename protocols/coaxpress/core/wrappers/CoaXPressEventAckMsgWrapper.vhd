-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing wrapper for CoaXPressEventAckMsg
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

entity CoaXPressEventAckMsgWrapper is
   port (
      clk            : in  sl;
      rst            : in  sl;
      eventAck       : in  sl;
      eventTag       : in  slv(7 downto 0);
      eventAckTReady : in  sl;
      eventAckTValid : out sl;
      eventAckTData  : out slv(7 downto 0);
      eventAckTK     : out sl;
      eventAckTLast  : out sl);
end entity CoaXPressEventAckMsgWrapper;

architecture rtl of CoaXPressEventAckMsgWrapper is

   signal eventAckMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal eventAckSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;

begin

   -- Flatten the byte-wide AXI stream so cocotb can monitor serialized output.
   eventAckSlave.tReady <= eventAckTReady;
   eventAckTValid       <= eventAckMaster.tValid;
   eventAckTData        <= eventAckMaster.tData(7 downto 0);
   eventAckTK           <= eventAckMaster.tUser(0);
   eventAckTLast        <= eventAckMaster.tLast;

   -- Instantiate the real event-ack message generator behind the flat ports.
   U_DUT : entity surf.CoaXPressEventAckMsg
      generic map (
         TPD_G => 1 ns)
      port map (
         clk            => clk,
         rst            => rst,
         eventAck       => eventAck,
         eventTag       => eventTag,
         eventAckMaster => eventAckMaster,
         eventAckSlave  => eventAckSlave);

end architecture rtl;
