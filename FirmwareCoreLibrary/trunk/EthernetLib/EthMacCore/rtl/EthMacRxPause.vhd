-------------------------------------------------------------------------------
-- Title      : 1GbE/10GbE Ethernet MAC
-------------------------------------------------------------------------------
-- File       : EthMacRxPause.vhd
-- Author     : Ryan Herbst <rherbst@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-09-21
-- Last update: 2016-09-09
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:
-- Generic pause frame receiver for Ethernet MACs. Pause frames are dropped
-- from the incoming data stream.
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

entity EthMacRxPause is
   generic (
      TPD_G      : time                  := 1 ns;
      PAUSE_EN_G : boolean               := true;
      VLAN_EN_G  : boolean               := false;
      VLAN_CNT_G : positive range 1 to 8 := 1);          
   port (
      -- Clock and Reset
      ethClk       : in  sl;
      ethRst       : in  sl;
      -- Incoming data from MAC
      sAxisMaster  : in  AxiStreamMasterType;
      -- Outgoing data 
      mAxisMaster  : out AxiStreamMasterType;
      mAxisMasters : out AxiStreamMasterArray(VLAN_CNT_G-1 downto 0);
      -- Pause Values
      rxPauseReq   : out sl;
      rxPauseValue : out slv(15 downto 0));
end EthMacRxPause;

architecture rtl of EthMacRxPause is

   type StateType is (
      FILL_S,
      PAUSE_S,
      PASS_S,
      DROP_S);

   type RegType is record
      state      : StateType;
      pauseValue : slv(15 downto 0);
      pauseEn    : sl;
      r0Master   : AxiStreamMasterType;
      r1Master   : AxiStreamMasterType;
      r2Master   : AxiStreamMasterType;
      outMaster  : AxiStreamMasterType;
      outMasters : AxiStreamMasterArray(VLAN_CNT_G-1 downto 0);
   end record RegType;

   constant REG_INIT_C : RegType := (
      state      => FILL_S,
      pauseValue => (others => '0'),
      pauseEn    => '0',
      r0Master   => AXI_STREAM_MASTER_INIT_C,
      r1Master   => AXI_STREAM_MASTER_INIT_C,
      r2Master   => AXI_STREAM_MASTER_INIT_C,
      outMaster  => AXI_STREAM_MASTER_INIT_C,
      outMasters => (others => AXI_STREAM_MASTER_INIT_C));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   -- attribute dont_touch      : string;
   -- attribute dont_touch of r : signal is "true";   

begin

   U_RxPauseGen : if (PAUSE_EN_G = true) generate

      comb : process (ethRst, r, sAxisMaster) is
         variable v : RegType;
      begin
         -- Latch the current value
         v := r;

         -- Pipeline
         v.r0Master := sAxisMaster;

         -- Clear valid
         v.pauseEn := '0';

         -- State Machine
         case r.state is

            -- Pre-fill pipeline
            when FILL_S =>

               v.outMaster.tValid := '0';

               if r.r1Master.tValid /= '1' then
                  v.r1Master := r.r0Master;
               end if;

               if r.r2Master.tValid /= '1' then
                  v.r1Master := r.r0Master;
                  v.r2Master := r.r1Master;
               end if;

               -- Pipeline is full
               if r.r0Master.tValid = '1' and r.r1Master.tValid = '1' and r.r2Master.tValid = '1' then

                  -- Detect pause frame 
                  if r.r2Master.tData(47 downto 0) = x"010000c28001" and  -- Det MAC
                     r.r1Master.tData(63 downto 32) = x"01000888" then    -- Mac Type, Mac OpCode

                     v.pauseValue(7 downto 0)  := r.r0Master.tData(15 downto 8);
                     v.pauseValue(15 downto 8) := r.r0Master.tData(7 downto 0);

                     v.r1Master.tValid := '0';
                     v.r2Master.tValid := '0';
                     v.state           := PAUSE_S;
                  else
                     v.r1Master  := r.r0Master;
                     v.r2Master  := r.r1Master;
                     v.outMaster := r.r2Master;
                     v.state     := PASS_S;
                  end if;
               end if;

            -- Pause frame dump
            when PAUSE_S =>
               v.r1Master.tValid  := '0';
               v.r2Master.tValid  := '0';
               v.outMaster.tValid := '0';

               if r.r0Master.tValid = '1' and r.r0Master.tLast = '1' then
                  v.pauseEn := not axiStreamGetUserBit(EMAC_AXIS_CONFIG_C, r.r0Master, EMAC_EOFE_BIT_C);
                  v.state   := FILL_S;
               end if;

            -- Frame pass
            when PASS_S =>
               v.r1Master  := r.r0Master;
               v.r2Master  := r.r1Master;
               v.outMaster := r.r2Master;

               if r.r2Master.tValid = '1' and r.r2Master.tLast = '1' then
                  v.state := FILL_S;
               end if;

            -- Default
            when others =>
               v.state := FILL_S;

         end case;

         -- Reset
         if ethRst = '1' then
            v := REG_INIT_C;
         end if;

         -- Register the variable for next clock cycle
         rin <= v;

         -- Outputs
         mAxisMaster  <= r.outMaster;
         mAxisMasters <= r.outMasters;
         rxPauseReq   <= r.pauseEn;
         rxPauseValue <= r.pauseValue;

      end process;

      seq : process (ethClk) is
      begin
         if rising_edge(ethClk) then
            r <= rin after TPD_G;
         end if;
      end process seq;
      
   end generate;

   U_BypRxPause : if (PAUSE_EN_G = false) generate
      mAxisMaster  <= sAxisMaster;
      mAxisMasters <= (others => AXI_STREAM_MASTER_INIT_C);
      rxPauseReq   <= '0';
      rxPauseValue <= (others => '0');
   end generate;
   
end rtl;
