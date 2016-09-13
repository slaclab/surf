-------------------------------------------------------------------------------
-- Title      : 1GbE/10GbE Ethernet MAC
-------------------------------------------------------------------------------
-- File       : EthMacRxBypass.vhd
-- Author     : Ryan Herbst <rherbst@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-01-04
-- Last update: 2016-09-09
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:
-- Generic bypass frame extractor.
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Ethernet Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'SLAC Ethernet Library', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.AxiStreamPkg.all;
use work.StdRtlPkg.all;
use work.EthMacPkg.all;

entity EthMacRxBypass is
   generic (
      TPD_G          : time             := 1 ns;
      BYP_EN_G       : boolean          := false;
      BYP_ETH_TYPE_G : slv(15 downto 0) := x"0000");
   port (
      -- Clock and Reset
      ethClk      : in  sl;
      ethRst      : in  sl;
      -- Incoming data from MAC
      sAxisMaster : in  AxiStreamMasterType;
      -- Outgoing primary data 
      mPrimMaster : out AxiStreamMasterType;
      -- Outgoing bypass data 
      mBypMaster  : out AxiStreamMasterType);
end EthMacRxBypass;

architecture rtl of EthMacRxBypass is

   type StateType is (
      HEAD_S,
      PRIM_S,
      BYP_S);

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
      bypMaster  => AXI_STREAM_MASTER_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   -- attribute dont_touch      : string;
   -- attribute dont_touch of r : signal is "true";   
   
begin

   U_BypRxEnGen : if (BYP_EN_G = true) generate

      comb : process (ethRst, r, sAxisMaster) is
         variable v : RegType;
      begin
         -- Latch the current value
         v := r;

         -- Pipeline
         v.regMasterA := sAxisMaster;
         v.regMasterB := r.regMasterA;
         v.primMaster := r.regMasterB;
         v.bypMaster  := r.regMasterB;

         -- Clear valid
         v.primMaster.tValid := '0';
         v.bypMaster.tValid  := '0';

         -- State Machine
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

         -- Reset
         if ethRst = '1' then
            v := REG_INIT_C;
         end if;

         -- Register the variable for next clock cycle
         rin <= v;

         -- Outputs 
         mPrimMaster <= r.primMaster;
         mBypMaster  <= r.bypMaster;

      end process;

      seq : process (ethClk) is
      begin
         if rising_edge(ethClk) then
            r <= rin after TPD_G;
         end if;
      end process seq;
      
   end generate;

   U_BypRxDisGen : if (BYP_EN_G = false) generate
      mPrimMaster <= sAxisMaster;
      mBypMaster  <= AXI_STREAM_MASTER_INIT_C;
   end generate;

end rtl;
