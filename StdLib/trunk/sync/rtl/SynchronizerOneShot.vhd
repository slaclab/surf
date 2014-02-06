-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : SynchronizerOneShot.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-02-06
-- Last update: 2014-02-06
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: One-Shot Pulser that has to cross clock domains
-------------------------------------------------------------------------------
-- Copyright (c) 2014 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;

entity SynchronizerOneShot is
   generic (
      TPD_G : time := 1 ns);            -- Simulation FF output delay      
   port (
      clk     : in  sl;                 -- clock to be sync'ed to
      dataIn  : in  sl;                 -- trigger to be sync'd
      dataOut : out sl);                -- synced one-shot pulse
end SynchronizerOneShot;

architecture mapping of SynchronizerOneShot is
   
   signal pulse : sl;
   
begin

   RstSync_Inst : entity work.RstSync
      generic map (
         TPD_G => TPD_G)   
      port map (
         clk      => clk,
         asyncRst => dataIn,
         syncRst  => pulse); 

   SynchronizerEdge_Inst : entity work.SynchronizerEdge
      generic map (
         TPD_G => TPD_G)   
      port map (
         clk        => clk,
         dataIn     => pulse,
         risingEdge => dataOut);  

end architecture mapping;
