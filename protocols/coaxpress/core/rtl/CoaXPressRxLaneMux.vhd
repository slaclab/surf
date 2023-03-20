-------------------------------------------------------------------------------
-- Title      : CoaXPress Protocol: http://jiia.org/wp-content/themes/jiia/pdf/standard_dl/coaxpress/CXP-001-2021.pdf
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: CoaXPress RX Lane Mux
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
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;

entity CoaXPressRxLaneMux is
   generic (
      TPD_G       : time     := 1 ns;
      NUM_LANES_G : positive := 1);
   port (
      -- Clock and Reset
      rxClk     : in  sl;
      rxRst     : in  sl;
      -- Config Interface (rxClk domain)
      rxFsmRst  : in  sl;
      numOfLane : in  slv(2 downto 0);
      -- Inbound Streams Interface
      rxMasters : in  AxiStreamMasterArray(NUM_LANES_G-1 downto 0);
      rxSlaves  : out AxiStreamSlaveArray(NUM_LANES_G-1 downto 0);
      -- Outbound Stream Interface
      rxMaster  : out AxiStreamMasterType;
      rxSlave   : in  AxiStreamSlaveType);
end entity CoaXPressRxLaneMux;

architecture rtl of CoaXPressRxLaneMux is

   type RegType is record
      numOfLane  : slv(2 downto 0);
      lane       : natural range 0 to NUM_LANES_G-1;
      rxSlaves   : AxiStreamSlaveArray(NUM_LANES_G-1 downto 0);
      pipeMaster : AxiStreamMasterType;
   end record RegType;
   constant REG_INIT_C : RegType := (
      numOfLane  => (others => '0'),
      lane       => 0,
      rxSlaves   => (others => AXI_STREAM_SLAVE_FORCE_C),
      pipeMaster => AXI_STREAM_MASTER_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal pipeSlave : AxiStreamSlaveType;

   -- attribute dont_touch      : string;
   -- attribute dont_touch of r : signal is "TRUE";

begin

   comb : process (numOfLane, pipeSlave, r, rxFsmRst, rxMasters, rxRst) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Flow Control
      for i in 0 to NUM_LANES_G-1 loop
         v.rxSlaves(i).tReady := '0';
      end loop;
      if (pipeSlave.tReady = '1') then
         v.pipeMaster.tValid := '0';
      end if;

      -- Check for limit of configuration
      if (numOfLane < NUM_LANES_G) then
         v.numOfLane := numOfLane;
      else
         v.numOfLane := toSlv(NUM_LANES_G-1, 3);
      end if;

      -- Check for valid data
      if (rxMasters(r.lane).tValid = '1') and (v.pipeMaster.tValid = '0') then

         -- Accept inbound data
         v.rxSlaves(r.lane).tReady := '1';

         -- Move the outbound data
         v.pipeMaster := rxMasters(r.lane);

         -- Check for tLast and more than 1 lane
         if (rxMasters(r.lane).tLast = '1') and (NUM_LANES_G > 1) then

            -- Check for roll over
            if (r.lane = r.numOfLane) then
               -- Reset counter
               v.lane := 0;
            else
               -- Increment counter
               v.lane := r.lane + 1;
            end if;

         end if;

      end if;

      -- Outputs
      rxSlaves <= v.rxSlaves;

      -- Reset
      if (rxRst = '1') or (rxFsmRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

   end process comb;

   seq : process (rxClk) is
   begin
      if (rising_edge(rxClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   U_Pipeline : entity surf.AxiStreamPipeline
      generic map (
         TPD_G         => TPD_G,
         PIPE_STAGES_G => 1)
      port map (
         axisClk     => rxClk,
         axisRst     => rxRst,
         sAxisMaster => r.pipeMaster,
         sAxisSlave  => pipeSlave,
         mAxisMaster => rxMaster,
         mAxisSlave  => rxSlave);

end rtl;
