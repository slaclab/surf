-------------------------------------------------------------------------------
-- Title      : JTAG Support
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Simulation Test bench for AxisToJtagStub
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
use ieee.numeric_std.all;


library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;
use surf.AxisToJtagPkg.all;

entity AxisToJtagStubTb is
end entity AxisToJtagStubTb;

architecture AxisToJtagStubTbImpl of AxisToJtagStubTb is

   signal clk : sl := '0';
   signal rst : sl := '1';

   signal mAxisReq : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal mAxisRep : AxiStreamMasterType;
   signal sAxisReq : AxiStreamSlaveType;
   signal sAxisRep : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;

   signal run : boolean := true;

   signal ini : natural := 0;

   signal rxs : natural := 0;

begin
   process
   begin
      if ( run ) then
         clk <= not clk;
         wait for 5 ns;
      else
         wait;
      end if;
   end process;

   U_TX : process(clk) is
      variable stage : natural;
   begin
      if ( rising_edge(clk) ) then

         stage := ini + 1;

         case (stage) is
            when 0 | 1 | 2 | 3 =>
            when 4             => rst <= '0';
            when 5             =>
            when 6             =>
               mAxisReq.tData(31 downto 0) <= (others => '0');
               mAxisReq.tValid             <= '1';
               mAxisReq.tLast              <= '1';
            when 7             =>
               if ( sAxisReq.tReady = '0' ) then
                  stage := ini;
               else
                  mAxisReq.tValid <= '0';
               end if; when 8             => when 9             =>
               mAxisReq.tData(31 downto 0) <= (others => '1');
               mAxisReq.tValid             <= '1';
               mAxisReq.tLast              <= '0';
               if ( sAxisReq.tReady = '0' ) then
                  stage := ini;
               end if;
            when 10            =>
               if ( sAxisReq.tReady = '0' ) then
                  stage := ini;
               end if;
            when 11            =>
               if ( sAxisReq.tReady = '0' ) then
                  stage := ini;
               else
                  mAxisReq.tLast <= '1';
               end if;
            when 12            =>
               if ( sAxisReq.tReady = '0' ) then
                  stage := ini;
               else
                  mAxisReq.tValid <= '0';
               end if;
            when others =>
         end case;

         ini <= stage;
      end if;
   end process U_TX;

   U_RX : process(clk) is
      variable stage : natural;
   begin
      if ( rising_edge(clk) ) then
         stage := rxs + 1;

         case (rxs) is
            when 0 =>
               sAxisRep.tReady <= '1';
            when 1 =>
               if ( mAxisRep.tValid = '0' ) then
                  stage := rxs;
               else
                  assert ( mAxisRep.tLast = '1' )
                     report "Reply without TLAST" severity failure;
                  assert ( getCommand( mAxisRep.tData ) = CMD_ERROR_C )
                     report "Expected ERROR" severity failure;
                  assert ( getLen( mAxisRep.tData ) = ERR_NOT_PRESENT_C )
                     report "Unexpected error code" severity failure;
                  sAxisRep.tReady <= '0';
               end if;

            when 2 =>
               sAxisRep.tReady <= '1';

            when 3 =>

               if ( mAxisRep.tValid = '0' ) then
                  stage := rxs;
               else
                  assert ( mAxisRep.tLast = '1' )
                     report "Reply without TLAST" severity failure;
                  assert ( getCommand( mAxisRep.tData ) = CMD_ERROR_C )
                     report "Expected ERROR" severity failure;
                  assert ( getLen( mAxisRep.tData ) = ERR_BAD_VERSION_C )
                     report "Unexpected error code" severity failure;
                  assert ( getVersion( mAxisRep.tData ) = PRO_VERSN_C )
                     report "Bad version in reply" severity failure;
                  sAxisRep.tReady <= '0';
               end if;

            when 4 =>

            when others =>
               run <= false;
               report "TEST PASSED";
         end case;

         rxs <= stage;
      end if;
   end process U_RX;

   U_dut : entity surf.AxisJtagDebugBridge(AxisJtagDebugBridgeStub)
      port map (
         axisClk  => clk,
         axisRst  => rst,

         mAxisReq => mAxisReq,
         sAxisReq => sAxisReq,

         mAxisTdo => mAxisRep,
         sAxisTdo => sAxisRep
      );

end architecture AxisToJtagStubTbImpl;
