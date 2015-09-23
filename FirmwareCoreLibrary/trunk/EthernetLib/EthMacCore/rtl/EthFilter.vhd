-------------------------------------------------------------------------------
-- Title         : Generic Ethernet Filter
-- Project       : Ethernet MAC
-------------------------------------------------------------------------------
-- File          : EthFilter.vhd
-- Author        : Ryan Herbst, rherbst@slac.stanford.edu
-- Created       : 09/21/2015
-------------------------------------------------------------------------------
-- Description:
-- Generic frame filter for Ethernet MACs. 
-------------------------------------------------------------------------------
-- Copyright (c) 2008 by Ryan Herbst. All rights reserved.
-------------------------------------------------------------------------------
-- Modification history:
-- 09/21/2015: created.
-------------------------------------------------------------------------------

LIBRARY ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.AxiStreamPkg.all;
use work.StdRtlPkg.all;
use work.EthPkg.all;

entity EthFilter is 
   generic (
      TPD_G : time := 1 ns
   );
   port ( 

      -- Ethernet Clock
      ethClk           : in  sl;
      ethClkRst        : in  sl;

      -- Imcoming data from MAC
      sAxisMaster      : in  AxiStreamMasterType;

      -- Outgoing data 
      mAxisMaster      : out AxiStreamMasterType;

      -- Configuration
      macAddress       : in  slv(47 downto 0);
      filtEnable       : in  sl
   );
end EthFilter;


-- Define architecture
architecture EthFilter of EthFilter is

   type StateType is ( HEAD_S, DROP_S, PASS_S);

   type RegType is record
      state      : StateType;
      regMaster  : AxiStreamMasterType;
      outMaster  : AxiStreamMasterType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      state      => HEAD_S,
      regMaster  => AXI_STREAM_MASTER_INIT_C,
      outMaster  => AXI_STREAM_MASTER_INIT_C
   );

   signal r      : RegType := REG_INIT_C;
   signal rin    : RegType;
   signal intMac : slv(47 downto 0);

begin

   -- Convert MAC for match
   intMac(47 downto 40) <= intMac(7  downto  0);
   intMac(39 downto 32) <= intMac(15 downto  8);
   intMac(31 downto 24) <= intMac(23 downto 16);
   intMac(23 downto 16) <= intMac(31 downto 24);
   intMac(15 downto  8) <= intMac(39 downto 32);
   intMac(7  downto  0) <= intMac(47 downto 40);

   comb : process (ethClkRst, sAxisMaster, r, filtEnable, intMac) is
      variable v : RegType;
   begin

      v := r;

      -- Pipeline
      v.regMaster := sAxisMaster;
      v.outMaster := r.regMaster;

      -- State
      case r.state is

         -- Waiting for header
         when HEAD_S =>

            -- Frame is present
            if r.regMaster.tValid = '1' then

               -- Local match, broadcast or multicast
               if filtEnable = '0' or 
                  r.regMaster.tData(47 downto  0) = intMac          or     -- Local
                  r.regMaster.tData(40)           = '1'             or     -- Multicast
                  r.regMaster.tData(47 downto  0) = x"FFFFFFFFFFFF" ) then -- Broadcast

                  v.state := S_PASS;

               -- Drop frame
               else
                  v.state            := S_DROP;
                  v.outMaster.tValid := '0';
               end if;
            end if;

         -- Dropping frame
         when HEAD_S =>
            v.outMaster.tValid := '0';

            if r.regMaster.tValid = '1' and r.regMaster.tLast = '1' then
               v.state := S_HEAD;
            end if;

         -- Pass frame
         when PASS_S =>
            if r.regMaster.tValid = '1' and r.regMaster.tLast = '1' then
               v.state := S_HEAD;
            end if;

         -- Default
         when others =>
            v.state := FILL_S;

      end case;

      if ethClkRst = '1' then
         v := REG_INIT_C;
      end if;

      rin <= v;

      mAxisMaster  <= r.outMaster;

   end process;

   seq : process (ethClk) is
   begin
      if rising_edge(ethClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end EthFilter;

