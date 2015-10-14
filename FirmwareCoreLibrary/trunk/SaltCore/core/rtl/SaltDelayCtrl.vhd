-------------------------------------------------------------------------------
-- Title      : SLAC Asynchronous Logic Transceiver (SALT)
-------------------------------------------------------------------------------
-- File       : SaltDelayCtrl.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-06-16
-- Last update: 2015-10-14
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Wrapper for IDELAYCTRL
-------------------------------------------------------------------------------
-- Copyright (c) 2015 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;

library UNISIM;
use UNISIM.vcomponents.all;

entity SaltDelayCtrl is
   generic (
      TPD_G           : time   := 1 ns;
      SIM_DEVICE_G    : string := "7SERIES";  -- Either "7SERIES" or "ULTRASCALE"
      IODELAY_GROUP_G : string := "SALT_IODELAY_GRP");   
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
         TPD_G => TPD_G)
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
