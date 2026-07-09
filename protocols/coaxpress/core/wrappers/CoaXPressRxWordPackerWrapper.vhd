-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing wrapper for CoaXPressRxWordPacker
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

entity CoaXPressRxWordPackerWrapper is
   generic (
      NUM_LANES_G : positive range 1 to 8 := 1);
   port (
      rxClk       : in  sl;
      rxRst       : in  sl;
      sAxisTValid : in  sl;
      sAxisTData  : in  slv(32*NUM_LANES_G-1 downto 0);
      sAxisTKeep  : in  slv(4*NUM_LANES_G-1 downto 0);
      sAxisTLast  : in  sl;
      mAxisTValid : out sl;
      mAxisTData  : out slv(32*NUM_LANES_G-1 downto 0);
      mAxisTKeep  : out slv(4*NUM_LANES_G-1 downto 0);
      mAxisTLast  : out sl);
end entity CoaXPressRxWordPackerWrapper;

architecture rtl of CoaXPressRxWordPackerWrapper is

   signal sAxisMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal mAxisMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;

begin

   -- Present the flat cocotb stimulus as one AXI-stream record.
   sAxisComb : process (sAxisTData, sAxisTKeep, sAxisTLast, sAxisTValid) is
      variable v : AxiStreamMasterType;
   begin
      v        := AXI_STREAM_MASTER_INIT_C;
      v.tValid := sAxisTValid;
      v.tData(32*NUM_LANES_G-1 downto 0) := sAxisTData;
      v.tKeep(4*NUM_LANES_G-1 downto 0)  := sAxisTKeep;
      v.tLast  := sAxisTLast;
      sAxisMaster <= v;
   end process sAxisComb;

   -- Flatten the packed output beat back to simple scalar ports.
   mAxisTValid <= mAxisMaster.tValid;
   mAxisTData  <= mAxisMaster.tData(32*NUM_LANES_G-1 downto 0);
   mAxisTKeep  <= mAxisMaster.tKeep(4*NUM_LANES_G-1 downto 0);
   mAxisTLast  <= mAxisMaster.tLast;

   -- Instantiate the real word packer behind the shim.
   U_DUT : entity surf.CoaXPressRxWordPacker
      generic map (
         TPD_G       => 1 ns,
         NUM_LANES_G => NUM_LANES_G)
      port map (
         rxClk       => rxClk,
         rxRst       => rxRst,
         sAxisMaster => sAxisMaster,
         mAxisMaster => mAxisMaster);

end architecture rtl;
