-------------------------------------------------------------------------------
-- Title      : 1GbE/10GbE Ethernet MAC
-------------------------------------------------------------------------------
-- File       : EthMacRxFilter.vhd
-- Author     : Ryan Herbst <rherbst@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-09-21
-- Last update: 2016-09-09
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:
-- Generic frame filter for Ethernet MACs. 
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

entity EthMacRxFilter is
   generic (
      TPD_G     : time    := 1 ns;
      FILT_EN_G : boolean := false);
   port (
      -- Clock and Reset
      ethClk      : in  sl;
      ethRst      : in  sl;
      -- Incoming data from MAC
      sAxisMaster : in  AxiStreamMasterType;
      -- Outgoing data 
      mAxisMaster : out AxiStreamMasterType;
      mAxisCtrl   : in  AxiStreamCtrlType;
      -- Configuration
      dropOnPause : in  sl;
      macAddress  : in  slv(47 downto 0);
      filtEnable  : in  sl);
end EthMacRxFilter;

architecture rtl of EthMacRxFilter is

   type StateType is (
      HEAD_S,
      DROP_S,
      PASS_S);

   type RegType is record
      state     : StateType;
      regMaster : AxiStreamMasterType;
      outMaster : AxiStreamMasterType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      state     => HEAD_S,
      regMaster => AXI_STREAM_MASTER_INIT_C,
      outMaster => AXI_STREAM_MASTER_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   -- attribute dont_touch      : string;
   -- attribute dont_touch of r : signal is "true";   

begin

   U_FiltEnGen : if (FILT_EN_G = true) generate

      comb : process (dropOnPause, ethRst, filtEnable, mAxisCtrl, macAddress, r, sAxisMaster) is
         variable v : RegType;
      begin
         -- Latch the current value
         v := r;

         -- Pipeline
         v.regMaster := sAxisMaster;
         v.outMaster := r.regMaster;

         -- State Machine
         case r.state is

            -- Waiting for header
            when HEAD_S =>

               -- Frame is present
               if r.regMaster.tValid = '1' then

                  -- Drop frames when pause is asserted to avoid downstream errors
                  if mAxisCtrl.pause = '1' and dropOnPause = '1' then
                     v.state            := DROP_S;
                     v.outMaster.tValid := '0';

                  -- Local match, broadcast or multicast
                  elsif filtEnable = '0' or
                     r.regMaster.tData(47 downto 0) = macAddress or         -- Local
                     r.regMaster.tData(0) = '1' or                          -- Multicast
                     r.regMaster.tData(47 downto 0) = x"FFFFFFFFFFFF" then  -- Broadcast

                     v.state := PASS_S;

                  -- Drop frame
                  else
                     v.state            := DROP_S;
                     v.outMaster.tValid := '0';
                  end if;
               end if;

            -- Dropping frame
            when DROP_S =>
               v.outMaster.tValid := '0';

               if r.regMaster.tValid = '1' and r.regMaster.tLast = '1' then
                  v.state := HEAD_S;
               end if;

            -- Pass frame
            when PASS_S =>
               if r.regMaster.tValid = '1' and r.regMaster.tLast = '1' then
                  v.state := HEAD_S;
               end if;

            -- Default
            when others =>
               v.state := HEAD_S;

         end case;

         -- Reset
         if ethRst = '1' then
            v := REG_INIT_C;
         end if;

         -- Register the variable for next clock cycle
         rin <= v;

         -- Outputs 
         mAxisMaster <= r.outMaster;

      end process;

      seq : process (ethClk) is
      begin
         if rising_edge(ethClk) then
            r <= rin after TPD_G;
         end if;
      end process seq;
      
   end generate;

   U_FiltDisGen : if (FILT_EN_G = false) generate
      mAxisMaster <= sAxisMaster;
   end generate;

end rtl;

