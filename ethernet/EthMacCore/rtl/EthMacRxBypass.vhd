-------------------------------------------------------------------------------
-- File       : EthMacRxBypass.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-01-04
-- Last update: 2016-09-14
-------------------------------------------------------------------------------
-- Description: RX bypass frame extractor.
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
      IDLE_S,
      PRIM_S,
      BYP_S);

   type RegType is record
      mPrimMaster : AxiStreamMasterType;
      mBypMaster  : AxiStreamMasterType;
      state       : StateType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      mPrimMaster => AXI_STREAM_MASTER_INIT_C,
      mBypMaster  => AXI_STREAM_MASTER_INIT_C,
      state       => IDLE_S);

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

         -- Clear valid
         v.mBypMaster.tValid  := '0';
         v.mPrimMaster.tValid := '0';

         -- State Machine
         case r.state is
            ----------------------------------------------------------------------         
            when IDLE_S =>
               -- Check for data
               if sAxisMaster.tValid = '1' then
                  -- Check for bypass EtherType
                  if sAxisMaster.tData(111 downto 96) = BYP_ETH_TYPE_G then
                     -- Move data
                     v.mBypMaster := sAxisMaster;
                     -- Check for no EOF
                     if sAxisMaster.tLast = '0' then
                        -- Next state
                        v.state := BYP_S;
                     end if;
                  else
                     -- Move data
                     v.mPrimMaster := sAxisMaster;
                     -- Check for no EOF
                     if sAxisMaster.tLast = '0' then
                        -- Next state
                        v.state := PRIM_S;
                     end if;
                  end if;
               end if;
            ----------------------------------------------------------------------         
            when BYP_S =>
               -- Move data
               v.mBypMaster := sAxisMaster;
               -- Check for a valid EOF
               if (sAxisMaster.tValid = '1') and (sAxisMaster.tLast = '1') then
                  -- Next state
                  v.state := IDLE_S;
               end if;
            ----------------------------------------------------------------------         
            when PRIM_S =>
               -- Move data
               v.mPrimMaster := sAxisMaster;
               -- Check for a valid EOF
               if (sAxisMaster.tValid = '1') and (sAxisMaster.tLast = '1') then
                  -- Next state
                  v.state := IDLE_S;
               end if;
         ----------------------------------------------------------------------         
         end case;

         -- Reset
         if ethRst = '1' then
            v := REG_INIT_C;
         end if;

         -- Register the variable for next clock cycle
         rin <= v;

         -- Outputs 
         mPrimMaster <= r.mPrimMaster;
         mBypMaster  <= r.mBypMaster;

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
