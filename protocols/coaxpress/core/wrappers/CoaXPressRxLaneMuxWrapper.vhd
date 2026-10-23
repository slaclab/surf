-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing wrapper for CoaXPressRxLaneMux
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

entity CoaXPressRxLaneMuxWrapper is
   generic (
      NUM_LANES_G : positive range 1 to 8 := 1);
   port (
      rxClk       : in  sl;
      rxRst       : in  sl;
      rxFsmRst    : in  sl;
      numOfLane   : in  slv(2 downto 0);
      sAxisTValid : in  slv(NUM_LANES_G-1 downto 0);
      sAxisTData  : in  slv(32*NUM_LANES_G*NUM_LANES_G-1 downto 0);
      sAxisTKeep  : in  slv(4*NUM_LANES_G*NUM_LANES_G-1 downto 0);
      sAxisTLast  : in  slv(NUM_LANES_G-1 downto 0);
      sAxisTReady : out slv(NUM_LANES_G-1 downto 0);
      mAxisTValid : out sl;
      mAxisTData  : out slv(32*NUM_LANES_G-1 downto 0);
      mAxisTKeep  : out slv(4*NUM_LANES_G-1 downto 0);
      mAxisTLast  : out sl;
      mAxisTReady : in  sl);
end entity CoaXPressRxLaneMuxWrapper;

architecture rtl of CoaXPressRxLaneMuxWrapper is

   signal rxMasters : AxiStreamMasterArray(NUM_LANES_G-1 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
   signal rxSlaves  : AxiStreamSlaveArray(NUM_LANES_G-1 downto 0)  := (others => AXI_STREAM_SLAVE_FORCE_C);
   signal mAxisMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal mAxisSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;

begin

   -- Rebuild the per-lane record array from the concatenated cocotb ports.
   sAxisComb : process (sAxisTData, sAxisTKeep, sAxisTLast, sAxisTValid) is
      variable masters : AxiStreamMasterArray(NUM_LANES_G-1 downto 0);
   begin
      masters := (others => AXI_STREAM_MASTER_INIT_C);
      for i in 0 to NUM_LANES_G-1 loop
         masters(i).tValid := sAxisTValid(i);
         masters(i).tData(32*NUM_LANES_G-1 downto 0) :=
            sAxisTData(32*NUM_LANES_G*(i+1)-1 downto 32*NUM_LANES_G*i);
         masters(i).tKeep(4*NUM_LANES_G-1 downto 0) :=
            sAxisTKeep(4*NUM_LANES_G*(i+1)-1 downto 4*NUM_LANES_G*i);
         masters(i).tLast := sAxisTLast(i);
      end loop;
      rxMasters <= masters;
   end process sAxisComb;

   sAxisReadyGen : for i in 0 to NUM_LANES_G-1 generate
      sAxisTReady(i) <= rxSlaves(i).tReady;
   end generate sAxisReadyGen;

   -- Flatten the mux output back to simple handshaked ports.
   mAxisSlave.tReady <= mAxisTReady;
   mAxisTValid       <= mAxisMaster.tValid;
   mAxisTData        <= mAxisMaster.tData(32*NUM_LANES_G-1 downto 0);
   mAxisTKeep        <= mAxisMaster.tKeep(4*NUM_LANES_G-1 downto 0);
   mAxisTLast        <= mAxisMaster.tLast;

   -- Instantiate the real lane mux with the rebuilt arrays.
   U_DUT : entity surf.CoaXPressRxLaneMux
      generic map (
         TPD_G       => 1 ns,
         NUM_LANES_G => NUM_LANES_G)
      port map (
         rxClk     => rxClk,
         rxRst     => rxRst,
         rxFsmRst  => rxFsmRst,
         numOfLane => numOfLane,
         rxMasters => rxMasters,
         rxSlaves  => rxSlaves,
         rxMaster  => mAxisMaster,
         rxSlave   => mAxisSlave);

end architecture rtl;
