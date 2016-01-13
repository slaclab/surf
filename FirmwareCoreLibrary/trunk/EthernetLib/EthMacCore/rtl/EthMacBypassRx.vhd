-------------------------------------------------------------------------------
-- Title         : Generic Ethernet Bypass Extractor
-- Project       : Ethernet MAC
-------------------------------------------------------------------------------
-- File          : EthMacBypassRx.vhd
-- Author        : Ryan Herbst, rherbst@slac.stanford.edu
-- Created       : 01/04/2016
-------------------------------------------------------------------------------
-- Description:
-- Generic bypass frame extractor.
-------------------------------------------------------------------------------
-- Copyright (c) 2016 by Ryan Herbst. All rights reserved.
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

entity EthMacBypassRx is 
   generic (
      TPD_G           : time             := 1 ns;
      BYP_ETH_TYPE_G  : slv(15 downto 0) := x"0000"
   );
   port ( 

      -- Ethernet Clock
      ethClk           : in  sl;
      ethClkRst        : in  sl;

      -- Imcoming data from MAC
      sAxisMaster      : in  AxiStreamMasterType;

      -- Outgoing primary data 
      mPrimMaster      : out AxiStreamMasterType;

      -- Outgoing bypass data 
      mBypMaster       : out AxiStreamMasterType
   );
end EthMacBypassRx;


-- Define architecture
architecture EthMacBypassRx of EthMacBypassRx is

   type StateType is ( HEAD_S, PRIM_S, BYP_S);

   type RegType is record
      state      : StateType;
      regMasterA : AxiStreamMasterType;
      regMasterB : AxiStreamMasterType;
      primMaster : AxiStreamMasterType;
      bypMaster  : AxiStreamMasterType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      state      => HEAD_S,
      regMasterA => AXI_STREAM_MASTER_INIT_C,
      regMasterB => AXI_STREAM_MASTER_INIT_C,
      primMaster => AXI_STREAM_MASTER_INIT_C,
      bypMaster  => AXI_STREAM_MASTER_INIT_C
   );

   signal r      : RegType := REG_INIT_C;
   signal rin    : RegType;

begin

   comb : process (ethClkRst, sAxisMaster, r) is
      variable v : RegType;
   begin

      v := r;

      -- Pipeline
      v.regMasterA := sAxisMaster;
      v.regMasterB := r.regMasterA;
      v.primMaster := r.regMasterB;
      v.bypMaster  := r.regMasterB;

      -- Clear valid
      v.primMaster.tValid := '0';
      v.bypMaster.tValid  := '0';

      -- State
      case r.state is

         -- Waiting for header
         when HEAD_S =>

            -- Frame is present
            if r.regMasterB.tValid = '1' then

               -- ID matches bypass
               if r.regMasterA.tData(47 downto 32) = BYP_ETH_TYPE_G then
                  v.state            := BYP_S;
                  v.bypMaster.tValid := '1';
               else
                  v.state             := PRIM_S;
                  v.primMaster.tValid := '1';
               end if;
            end if;

         -- Bypass
         when BYP_S =>
            v.bypMaster.tValid := r.regMasterB.tValid;

            if r.regMasterB.tValid = '1' and r.regMasterB.tLast = '1' then
               v.state := HEAD_S;
            end if;

         -- Prim
         when PRIM_S =>
            v.primMaster.tValid := r.regMasterB.tValid;

            if r.regMasterB.tValid = '1' and r.regMasterB.tLast = '1' then
               v.state := HEAD_S;
            end if;

      end case;

      if ethClkRst = '1' then
         v := REG_INIT_C;
      end if;

      rin <= v;

      mPrimMaster <= r.primMaster;
      mBypMaster  <= r.bypMaster;

   end process;

   seq : process (ethClk) is
   begin
      if rising_edge(ethClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end EthMacBypassRx;

