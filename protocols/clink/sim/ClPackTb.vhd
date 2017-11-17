-------------------------------------------------------------------------------
-- File       : ClinkTb.vhd
-- Created    : 2017-11-13
-------------------------------------------------------------------------------
-- Description: Simulation Testbed for Clink
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Firmware Standard Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'SLAC Firmware Standard Library', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
------------------------------------------------------------------------------

library ieee;
use work.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
library unisim;

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;

entity ClPackTb is end ClPackTb;

-- Define architecture
architecture test of ClPackTb is

   constant INT_CONFIG_C : AxiStreamConfigType := (
      TSTRB_EN_C    => false,
      TDATA_BYTES_C => 16, -- 128 bits
      TDEST_BITS_C  => 0,
      TID_BITS_C    => 0,
      TKEEP_MODE_C  => TKEEP_COMP_C,
      TUSER_BITS_C  => 2,
      TUSER_MODE_C  => TUSER_FIRST_LAST_C);

   constant CLK_PERIOD_C   : time    := 5.000 ns;
   constant TPD_G          : time    := 1 ns;

   signal sysClk        : sl;
   signal sysRst        : sl;

   signal i3ByteCounter    : integer;
   signal i3ByteInMaster   : AxiStreamMasterType;
   signal i3ByteInSlave    : AxiStreamSlaveType;
   signal i3ByteOutMaster  : AxiStreamMasterType;
   signal i3ByteOutSlave   : AxiStreamSlaveType;

   signal i4ByteCounter    : integer;
   signal i4ByteInMaster   : AxiStreamMasterType;
   signal i4ByteInSlave    : AxiStreamSlaveType;
   signal i4ByteOutMaster  : AxiStreamMasterType;
   signal i4ByteOutSlave   : AxiStreamSlaveType;

   signal i6ByteCounter    : integer;
   signal i6ByteInMaster   : AxiStreamMasterType;
   signal i6ByteInSlave    : AxiStreamSlaveType;
   signal i6ByteOutMaster  : AxiStreamMasterType;
   signal i6ByteOutSlave   : AxiStreamSlaveType;

   signal i8ByteCounter    : integer;
   signal i8ByteInMaster   : AxiStreamMasterType;
   signal i8ByteInSlave    : AxiStreamSlaveType;
   signal i8ByteOutMaster  : AxiStreamMasterType;
   signal i8ByteOutSlave   : AxiStreamSlaveType;

   signal i10ByteCounter   : integer;
   signal i10ByteInMaster  : AxiStreamMasterType;
   signal i10ByteInSlave   : AxiStreamSlaveType;
   signal i10ByteOutMaster : AxiStreamMasterType;
   signal i10ByteOutSlave  : AxiStreamSlaveType;

begin

   -----------------------------
   -- Generate a Clock and Reset
   -----------------------------
   U_ClkRst : entity work.ClkRst
      generic map (
         CLK_PERIOD_G      => CLK_PERIOD_C,
         RST_START_DELAY_G => 0 ns,     -- Wait this long into simulation before asserting reset
         RST_HOLD_TIME_G   => 10030 ns)  -- Hold reset for this long)
      port map (
         clkP => sysClk,
         clkN => open,
         rst  => sysRst,
         rstL => open);  

   process ( sysClk ) begin
      if rising_edge(sysClk) then
         if sysRst = '1' then
            i3ByteCounter    <= 0 after TPD_G;
            i3ByteInMaster   <= AXI_STREAM_MASTER_INIT_C after TPD_G;
            i4ByteCounter    <= 0 after TPD_G;
            i4ByteInMaster   <= AXI_STREAM_MASTER_INIT_C after TPD_G;
            i6ByteCounter    <= 0 after TPD_G;
            i6ByteInMaster   <= AXI_STREAM_MASTER_INIT_C after TPD_G;
            i8ByteCounter    <= 0 after TPD_G;
            i8ByteInMaster   <= AXI_STREAM_MASTER_INIT_C after TPD_G;
            i10ByteCounter   <= 0 after TPD_G;
            i10ByteInMaster  <= AXI_STREAM_MASTER_INIT_C after TPD_G;
         else

            i3ByteInMaster.tValid  <= '1'; 
            i4ByteInMaster.tValid  <= '1'; 
            i6ByteInMaster.tValid  <= '1'; 
            i8ByteInMaster.tValid  <= '1'; 
            i10ByteInMaster.tValid <= '1'; 

            -- 3 byte
            for i in 0 to 2 loop
               i3ByteInMaster.tData(i*8+7 downto i*8) <= toSlv(i3ByteCounter+i,8);
            end loop;
            i3ByteCounter <= i3ByteCounter + 3;
            
            -- 4 byte
            for i in 0 to 3 loop
               i4ByteInMaster.tData(i*8+7 downto i*8) <= toSlv(i4ByteCounter+i,8);
            end loop;
            i4ByteCounter <= i4ByteCounter + 4;

            -- 6 byte
            for i in 0 to 5 loop
               i6ByteInMaster.tData(i*8+7 downto i*8) <= toSlv(i6ByteCounter+i,8);
            end loop;
            i6ByteCounter <= i6ByteCounter + 6;

            -- 8 byte
            for i in 0 to 7 loop
               i8ByteInMaster.tData(i*8+7 downto i*8) <= toSlv(i8ByteCounter+i,8);
            end loop;
            i8ByteCounter <= i8ByteCounter + 8;

            -- 10 byte
            for i in 0 to 9 loop
               i10ByteInMaster.tData(i*8+7 downto i*8) <= toSlv(i10ByteCounter+i,8);
            end loop;
            i10ByteCounter <= i10ByteCounter + 10;
         end if;
      end if;
   end process;


--   U_3Byte: entity work.AxiStreamPacker
--      generic map (
--         TPD_G               => TPD_G,
--         HEADER_PASS_EN_G    => false,
--         AXI_STREAM_CONFIG_G => INT_CONFIG_C,
--         RANGE_HIGH_G        => 23,
--         RANGE_LOW_G         => 0)
--      port map (
--         axisClk          => sysClk,
--         axisRst          => sysRst,
--         rawAxisMaster    => i8ByteInMaster,
--         rawAxisSlave     => i8ByteInslave,
--         rawAxisCtrl      => open,
--         packedAxisMaster => i8ByteOutMaster,
--         packedAxisSlave  => i8ByteOutSlave,
--         packedAxisCtrl   => AXI_STREAM_CTRL_INIT_C);

--   U_4Byte: entity work.AxiStreamPacker
--      generic map (
--         TPD_G               => TPD_G,
--         HEADER_PASS_EN_G    => false,
--         AXI_STREAM_CONFIG_G => INT_CONFIG_C,
--         RANGE_HIGH_G        => 27,
--         RANGE_LOW_G         => 0)
--      port map (
--         axisClk          => sysClk,
--         axisRst          => sysRst,
--         rawAxisMaster    => i4ByteInMaster,
--         rawAxisSlave     => i4ByteInslave,
--         rawAxisCtrl      => open,
--         packedAxisMaster => i4ByteOutMaster,
--         packedAxisSlave  => i4ByteOutSlave,
--         packedAxisCtrl   => AXI_STREAM_CTRL_INIT_C);

--   U_6Byte: entity work.AxiStreamPacker
--      generic map (
--         TPD_G               => TPD_G,
--         HEADER_PASS_EN_G    => false,
--         AXI_STREAM_CONFIG_G => INT_CONFIG_C,
--         RANGE_HIGH_G        => 47,
--         RANGE_LOW_G         => 0)
--      port map (
--         axisClk          => sysClk,
--         axisRst          => sysRst,
--         rawAxisMaster    => i6ByteInMaster,
--         rawAxisSlave     => i6ByteInslave,
--         rawAxisCtrl      => open,
--         packedAxisMaster => i6ByteOutMaster,
--         packedAxisSlave  => i6ByteOutSlave,
--         packedAxisCtrl   => AXI_STREAM_CTRL_INIT_C);

   U_8Byte: entity work.AxiStreamPacker
      generic map (
         TPD_G               => TPD_G,
         HEADER_PASS_EN_G    => false,
         AXI_STREAM_CONFIG_G => INT_CONFIG_C,
         RANGE_HIGH_G        => 63,
         RANGE_LOW_G         => 0)
      port map (
         axisClk          => sysClk,
         axisRst          => sysRst,
         rawAxisMaster    => i8ByteInMaster,
         rawAxisSlave     => i8ByteInslave,
         rawAxisCtrl      => open,
         packedAxisMaster => i8ByteOutMaster,
         packedAxisSlave  => i8ByteOutSlave,
         packedAxisCtrl   => AXI_STREAM_CTRL_INIT_C);

   U_10Byte: entity work.AxiStreamPacker
      generic map (
         TPD_G               => TPD_G,
         HEADER_PASS_EN_G    => false,
         AXI_STREAM_CONFIG_G => INT_CONFIG_C,
         RANGE_HIGH_G        => 79,
         RANGE_LOW_G         => 0)
      port map (
         axisClk          => sysClk,
         axisRst          => sysRst,
         rawAxisMaster    => i10ByteInMaster,
         rawAxisSlave     => i10ByteInslave,
         rawAxisCtrl      => open,
         packedAxisMaster => i10ByteOutMaster,
         packedAxisSlave  => i10ByteOutSlave,
         packedAxisCtrl   => AXI_STREAM_CTRL_INIT_C);

   i3ByteOutSlave   <= AXI_STREAM_SLAVE_FORCE_C;
   i4ByteOutSlave   <= AXI_STREAM_SLAVE_FORCE_C;
   i6ByteOutSlave   <= AXI_STREAM_SLAVE_FORCE_C;
   i8ByteOutSlave   <= AXI_STREAM_SLAVE_FORCE_C;
   i10ByteOutSlave  <= AXI_STREAM_SLAVE_FORCE_C;

end test;

