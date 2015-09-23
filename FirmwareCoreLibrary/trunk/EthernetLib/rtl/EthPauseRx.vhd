-------------------------------------------------------------------------------
-- Title         : Generic Ethernet Pause Frame Detector
-- Project       : Ethernet MAC
-------------------------------------------------------------------------------
-- File          : EthPauseRx.vhd
-- Author        : Ryan Herbst, rherbst@slac.stanford.edu
-- Created       : 09/21/2015
-------------------------------------------------------------------------------
-- Description:
-- Generic pause frame receiver for Ethernet MACs. Pause frames are dropped
-- from the incoming data stream.
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

entity EthPauseRx is 
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

      -- Pause Values
      rxPauseReq       : out sl;
      rxPauseValue     : out slv(15 downto 0)
   );
end EthPauseRx;


-- Define architecture
architecture EthPauseRx of EthPauseRx is

   type StateType is ( FILL_S, PAUSE_S, PASS_S);

   type RegType is record
      state       : StateType;
      pauseValue  : slv(15 downto 0);
      pauseEn     : sl;
      r0Master    : AxiStreamMasterType;
      r1Master    : AxiStreamMasterType;
      r2Master    : AxiStreamMasterType;
      outMaster   : AxiStreamMasterType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      state       => FILL_S,
      pauseValue  => (others=>'0'),
      pauseEn     => '0',
      r0Master    => AXI_STREAM_MASTER_INIT_C,
      r1Master    => AXI_STREAM_MASTER_INIT_C,
      r2Master    => AXI_STREAM_MASTER_INIT_C,
      outMaster   => AXI_STREAM_MASTER_INIT_C
   );

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   comb : process (ethClkRst, sAxisMaster, r) is
      variable v : RegType;
   begin

      v := r;

      v.r0Master := sAxisMaster;

      -- State
      case r.state is

         -- Prefill pipeline
         when FILL_S =>

            v.outMaster.tValid := '0';

            if r.r1Master.tValid != '1' then
               v.r1Master := r.r0Master;
            end if;

            if r.r2Master.tValid != '1' then
               v.r1Master := r.r0Master;
               v.r2Master := r.r1Master;
            end if;

            -- Pipeline is full
            if r.r0Master.tValid = '1' and r.r1Master.tValid = '1' and r.r2Master.tValid = '1' then
          
               -- Detect pause frame 
               if r.r2Master.tData(47 downto  0) = x"010000c28001" and -- Det MAC
                  r.r1Master.tData(63 downto 32) = x"01000888" then    -- Mac Type, Mac OpCode

                  v.pauseVal(7  downto 0) := r.r0Master.tData(15 downto 8);
                  v.pauseVal(15 downto 8) := r.r0Master.tData(7  downto 0);

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
         case PAUSE_S =>
            v.r1Master.tValid  := '0';
            v.r2Master.tValid  := '0';
            v.outMaster.tValid := '0';

            if r.r0Master.tValid = '1' and r.r0Master.tLast = '1' then
               v.pauseEn := not axiStreamGetUserBit(EMAC_AXIS_CONFIG_C, r.r0Master, EMAC_EOFE_BIT_G);
               v.state   := FILL_S;
            end if;

         -- Frame pass
         case PASS_S =>
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

      if ethClkRst = '1' then
         v := REG_INIT_C;
      end if;

      rin <= v;

      mAxisMaster  <= r.outMaster;
      rxPauseReq   <= r.pauseEn;
      rxPauseValue <= r.pauseVal;

   end process;


   seq : process (ethClk) is
   begin
      if rising_edge(ethClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end EthPauseRx;

