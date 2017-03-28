-------------------------------------------------------------------------------
-- File       : SaltDelayCtrl.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-06-16
-- Last update: 2016-06-21
-------------------------------------------------------------------------------
-- Description: Wrapper for IDELAYCTRL
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

use work.StdRtlPkg.all;

library UNISIM;
use UNISIM.vcomponents.all;

entity SaltDelayCtrl is
   generic (
      TPD_G           : time    := 1 ns;
      SIM_DEVICE_G    : string  := "7SERIES";  -- Either "7SERIES" or "ULTRASCALE"
      REF_RST_SYNC_G  : boolean := true;       -- Synchronize refRst to refClk.
      IODELAY_GROUP_G : string  := "SALT_IODELAY_GRP");
   port (
      iDelayCtrlRdy : out sl;
      refClk        : in  sl;
      refRst        : in  sl);
end SaltDelayCtrl;

architecture mapping of SaltDelayCtrl is

   signal syncRst : sl;

   attribute dont_touch            : string;
   attribute dont_touch of syncRst : signal is "TRUE";

   attribute IODELAY_GROUP                          : string;
   attribute IODELAY_GROUP of SALT_IDELAY_CTRL_Inst : label is IODELAY_GROUP_G;

   attribute KEEP_HIERARCHY                          : string;
   attribute KEEP_HIERARCHY of SALT_IDELAY_CTRL_Inst : label is "TRUE";
   attribute KEEP_HIERARCHY of RstSync_Inst          : label is "TRUE";

begin

   RstSync_Inst : entity work.RstSync
      generic map (
         TPD_G         => TPD_G,
         BYPASS_SYNC_G => not REF_RST_SYNC_G)
      port map (
         clk      => refClk,
         asyncRst => refRst,
         syncRst  => syncRst);

   SALT_IDELAY_CTRL_Inst : IDELAYCTRL
      generic map (
         SIM_DEVICE => SIM_DEVICE_G)
      port map (
         RDY    => iDelayCtrlRdy,       -- 1-bit output: Ready output
         REFCLK => refClk,              -- 1-bit input: Reference clock input
         RST    => syncRst);            -- 1-bit input: Active high reset input

end mapping;
