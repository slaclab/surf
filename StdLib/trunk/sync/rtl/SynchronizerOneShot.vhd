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
      TPD_G          : time := 1 ns;    -- Simulation FF output delay
      IN_POLARITY_G  : sl   := '1';     -- 0 for active LOW, 1 for active HIGH
      OUT_POLARITY_G : sl   := '1');    -- 0 for active LOW, 1 for active HIGH
   port (
      clk     : in  sl;                 -- clock to be sync'ed to
      dataIn  : in  sl;                 -- trigger to be sync'd
      dataOut : out sl);                -- synced one-shot pulse
end SynchronizerOneShot;

architecture mapping of SynchronizerOneShot is
   
   signal syncRst,
      pulse : sl;
   
begin

   RstSync_Inst : entity work.RstSync
      generic map (
         TPD_G         => TPD_G,
         IN_POLARITY_G => IN_POLARITY_G)   
      port map (
         clk      => clk,
         asyncRst => dataIn,
         syncRst  => syncRst); 

   SynchronizerEdge_Inst : entity work.SynchronizerEdge
      generic map (
         TPD_G      => TPD_G)    
      port map (
         clk        => clk,
         dataIn     => syncRst,
         risingEdge => pulse);

   dataOut <= pulse when(OUT_POLARITY_G='1') else not(pulse);

end architecture mapping;
