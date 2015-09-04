-------------------------------------------------------------------------------
-- Title      : SLAC Asynchronous Logic Transceiver (SALT)
-------------------------------------------------------------------------------
-- File       : SaltDelayCtrl.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-06-16
-- Last update: 2015-09-04
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
      IODELAY_GROUP_G : string := "SALT_IODELAY_GRP");   
   port (
      iDelayCtrlRdy : out sl;
      refClk        : in  sl;
      refRst        : in  sl);      
end SaltDelayCtrl;

architecture mapping of SaltDelayCtrl is
   
   attribute IODELAY_GROUP                          : string;
   attribute IODELAY_GROUP of SALT_IDELAY_CTRL_Inst : label is IODELAY_GROUP_G;
   
begin
   
   SALT_IDELAY_CTRL_Inst : IDELAYCTRL
      port map (
         RDY    => iDelayCtrlRdy,       -- 1-bit output: Ready output
         REFCLK => refClk,              -- 1-bit input: Reference clock input
         RST    => refRst);             -- 1-bit input: Active high reset input

end mapping;
