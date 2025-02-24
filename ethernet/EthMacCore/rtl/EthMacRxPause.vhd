-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
-- Generic pause frame receiver for Ethernet MACs. Pause frames are dropped
-- from the incoming data stream.
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

library surf;
use surf.AxiStreamPkg.all;
use surf.StdRtlPkg.all;
use surf.EthMacPkg.all;

entity EthMacRxPause is
   generic (
      TPD_G      : time    := 1 ns;
      PAUSE_EN_G : boolean := true);
   port (
      -- Clock and Reset
      ethClk       : in  sl;
      ethRst       : in  sl;
      -- Incoming data from MAC
      sAxisMaster  : in  AxiStreamMasterType;
      -- Outgoing data
      mAxisMaster  : out AxiStreamMasterType;
      -- Pause Values
      rxPauseReq   : out sl;
      rxPauseValue : out slv(15 downto 0));
end EthMacRxPause;

architecture rtl of EthMacRxPause is

   type StateType is (
      IDLE_S,
      PAUSE_S,
      DUMP_S,
      PASS_S);

   type RegType is record
      pauseEn     : sl;
      pauseValue  : slv(15 downto 0);
      mAxisMaster : AxiStreamMasterType;
      state       : StateType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      pauseEn     => '0',
      pauseValue  => (others => '0'),
      mAxisMaster => AXI_STREAM_MASTER_INIT_C,
      state       => IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   -- attribute dont_touch      : string;
   -- attribute dont_touch of r : signal is "true";

begin

   U_RxPauseGen : if (PAUSE_EN_G = true) generate

      comb : process (ethRst, r, sAxisMaster) is
         variable v : RegType;
         variable i : natural;
      begin
         -- Latch the current value
         v := r;

         -- Reset flags
         v.pauseEn            := '0';
         v.mAxisMaster.tValid := '0';

         -- State Machine
         case r.state is
            ----------------------------------------------------------------------
            when IDLE_S =>
               -- Check for data
               if (sAxisMaster.tValid = '1') then
                  -- Check for pause frame
                  if (sAxisMaster.tData(47 downto 0) = x"01_00_00_C2_80_01") and  -- DST MAC (Pause MAC Address)
                     (sAxisMaster.tData(127 downto 96) = x"01_00_08_88") then  -- Mac Type, Mac OpCode
                     -- Check for no EOF
                     if (sAxisMaster.tLast = '0') then
                        -- Next State
                        v.state := PAUSE_S;
                     end if;
                  else
                     -- Move the data
                     v.mAxisMaster := sAxisMaster;
                     -- Check for no EOF
                     if (sAxisMaster.tLast = '0') then
                        -- Next State
                        v.state := PASS_S;
                     end if;
                  end if;
               end if;
            ----------------------------------------------------------------------
            when PAUSE_S =>
               --------------------------------------------------------------------------------------------------------------------
               -- Refer to https://hasanmansur1.files.wordpress.com/2012/12/ethernet-flow-control-pause-frame-framing-structure.png
               --------------------------------------------------------------------------------------------------------------------
               -- Check for data
               if (sAxisMaster.tValid = '1') then
                  -- Latch the pause data
                  v.pauseValue(7 downto 0)  := sAxisMaster.tData(15 downto 8);
                  v.pauseValue(15 downto 8) := sAxisMaster.tData(7 downto 0);
                  -- Check for a EOF
                  if (sAxisMaster.tLast = '1') then
                     -- Set the pause
                     v.pauseEn := not axiStreamGetUserBit(INT_EMAC_AXIS_CONFIG_C, sAxisMaster, EMAC_EOFE_BIT_C);
                     -- Next State
                     v.state   := IDLE_S;
                  else
                     -- Next State
                     v.state := DUMP_S;
                  end if;
               end if;
            ----------------------------------------------------------------------
            when DUMP_S =>
               -- Check for a valid EOF
               if (sAxisMaster.tValid = '1') and (sAxisMaster.tLast = '1') then
                  -- Set the pause
                  v.pauseEn := not axiStreamGetUserBit(INT_EMAC_AXIS_CONFIG_C, sAxisMaster, EMAC_EOFE_BIT_C);
                  -- Next State
                  v.state   := IDLE_S;
               end if;
            ----------------------------------------------------------------------
            when PASS_S =>
               -- Move the data
               v.mAxisMaster := sAxisMaster;
               -- Check for a valid EOF
               if (sAxisMaster.tValid = '1') and (sAxisMaster.tLast = '1') then
                  -- Next State
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
         mAxisMaster  <= r.mAxisMaster;
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
      rxPauseReq   <= '0';
      rxPauseValue <= (others => '0');
   end generate;

end rtl;
