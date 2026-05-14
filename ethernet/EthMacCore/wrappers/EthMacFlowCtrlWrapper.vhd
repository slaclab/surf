-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing wrapper for EthMacFlowCtrl
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

entity EthMacFlowCtrlWrapper is
   generic (
      TPD_G          : time    := 1 ns;
      RST_POLARITY_G : sl      := '1';
      RST_ASYNC_G    : boolean := false;
      BYP_EN_G       : boolean := false);
   port (
      ethClk       : in  sl;
      ethRst       : in  sl;
      primPause    : in  sl;
      primOverflow : in  sl;
      bypPause     : in  sl;
      bypOverflow  : in  sl;
      flowPause    : out sl;
      flowOverflow : out sl);
end entity EthMacFlowCtrlWrapper;

architecture rtl of EthMacFlowCtrlWrapper is

   signal primCtrl : AxiStreamCtrlType := AXI_STREAM_CTRL_INIT_C;
   signal bypCtrl  : AxiStreamCtrlType := AXI_STREAM_CTRL_INIT_C;
   signal flowCtrl : AxiStreamCtrlType := AXI_STREAM_CTRL_INIT_C;

begin

   -- Flatten the small `AxiStreamCtrlType` record into individual pause and
   -- overflow bits so cocotb can drive the public control contract directly.
   primCtrl.pause    <= primPause;
   primCtrl.overflow <= primOverflow;
   primCtrl.idle     <= '0';

   bypCtrl.pause    <= bypPause;
   bypCtrl.overflow <= bypOverflow;
   bypCtrl.idle     <= '0';

   -- Instantiate the real DUT.
   U_DUT : entity surf.EthMacFlowCtrl
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G,
         BYP_EN_G       => BYP_EN_G)
      port map (
         ethClk   => ethClk,
         ethRst   => ethRst,
         primCtrl => primCtrl,
         bypCtrl  => bypCtrl,
         flowCtrl => flowCtrl);

   -- Re-expand the output record so the test can observe the merged flow
   -- control result without record-field access.
   flowPause    <= flowCtrl.pause;
   flowOverflow <= flowCtrl.overflow;

end architecture rtl;
