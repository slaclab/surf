-------------------------------------------------------------------------------
-- Title         : Generic Ethernet Bypass Mux
-- Project       : Ethernet MAC
-------------------------------------------------------------------------------
-- File          : EthMacBypassMux.vhd
-- Author        : Ryan Herbst, rherbst@slac.stanford.edu
-- Created       : 01/04/2016
-------------------------------------------------------------------------------
-- Description:
-- Mux stage to allow high priority bypass traffic to override primary path
-- traffic.
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Ethernet Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'SLAC Ethernet Library', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------
-- Modification history:
-- 01/04/2016: created.
-------------------------------------------------------------------------------

LIBRARY ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.AxiStreamPkg.all;
use work.StdRtlPkg.all;
use work.EthMacPkg.all;

entity EthMacBypassMux is 
   generic (
      TPD_G : time := 1 ns
   );
   port ( 

      -- Clocks
      ethClk       : in  sl;
      ethClkRst    : in  sl;

      -- Incoming primary traffic
      sPrimMaster  : in  AxiStreamMasterType;
      sPrimSlave   : out AxiStreamSlaveType;

      -- Incoming bypass traffic
      sBypMaster   : in  AxiStreamMasterType;
      sBypSlave    : out AxiStreamSlaveType;

      -- Outgoing data to MAC
      mAxisMaster  : out AxiStreamMasterType;
      mAxisSlave   : in  AxiStreamSlaveType
   );
end EthMacBypassMux;


-- Define architecture
architecture EthMacBypassMux of EthMacBypassMux is

   type StateType is ( IDLE_S, PRIM_S, BYP_S, DUMP_S );

   type RegType is record
      state       : StateType;
      dump        : sl;
      outMaster   : AxiStreamMasterType;
      primSlave   : AxiStreamSlaveType;
      bypSlave    : AxiStreamSlaveType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      state       => IDLE_S,
      dump        => '1',
      outMaster   => AXI_STREAM_MASTER_INIT_C,
      primSlave   => AXI_STREAM_SLAVE_INIT_C,
      bypSlave    => AXI_STREAM_SLAVE_INIT_C
   );

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   attribute dont_touch : string;
   attribute dont_touch of r  : signal is "true";

begin

   comb : process (ethClkRst, sPrimMaster, sBypMaster, mAxisSlave, r) is 
      variable v : RegType;
   begin

      v := r;

      -- Clear tvalid on ready assertion
      if mAxisSlave.tReady = '1' then
         v.outMaster.tValid := '0';
      end if;

      -- Clear ready
      v.primSlave.tReady :='0';
      v.bypSlave.tReady  :='0';

      -- State
      case r.state is

         -- IDLE, wait for frame
         when IDLE_S =>
            v.dump := '0';

            -- Bypass frame request
            if sBypMaster.tValid = '1' then
               v.state := BYP_S;

            -- Primary frame request
            elsif sPrimMaster.tValid = '1' then
               v.state := PRIM_S;

            end if;

         -- Passing primary data
         when PRIM_S =>

            -- Fill chain
            if v.outMaster.tValid = '0' then
               v.primSlave.tReady := '1';
               v.outMaster        := sPrimMaster;

               -- Last of frame
               if sPrimMaster.tValid = '1' and sPrimMaster.tLast = '1' then
                  v.state := IDLE_S;

               -- Bypass preempt
               elsif sBypMaster.tValid = '1' then
                  v.state           := BYP_S;
                  v.dump            := '1';
                  v.outMaster.tLast := '1';

                  -- Mark frame in error
                  axiStreamSetUserBit(EMAC_AXIS_CONFIG_C, v.outMaster, EMAC_EOFE_BIT_C, '1');
               end if;
            end if;

         -- Sending preempt data
         when BYP_S =>

            -- Assert ready when dumping
            v.primSlave.tReady := r.dump;

            -- Detect last dump of primary data
            if sPrimMaster.tValid = '1' and sPrimMaster.tLast = '1' then
               v.dump := '0';
            end if;

            -- Fill chain
            if v.outMaster.tValid = '0' then
               v.bypSlave.tReady := '1';
               v.outMaster       := sBypMaster;

               -- Last of frame
               if sBypMaster.tValid = '1' and sBypMaster.tLast = '1' then

                  -- Still dumping primary data
                  if v.dump = '1' then
                     v.state := DUMP_S;

                  else
                     v.state := IDLE_S;
                  end if;
               end if;
            end if;

         -- Dump data
         when DUMP_S =>

            -- Accept all data
            v.primSlave.tReady := '1';

            -- Dump until last primary data
            if sPrimMaster.tValid = '1' and sPrimMaster.tLast = '1' then
               v.state := IDLE_S;
            end if;

      end case;

      if ethClkRst = '1' then
         v := REG_INIT_C;
      end if;

      rin <= v;

      mAxisMaster <= r.outMaster;
      sPrimSlave  <= v.primSlave;
      sBypSlave   <= v.bypSlave;

   end process;

   seq : process (ethClk) is
   begin
      if rising_edge(ethClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end EthMacBypassMux;

