-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- Description: Simulation Testbed for AxiStreamBytePacker
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
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;


library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;

entity AxiStreamBytePackerTb is end AxiStreamBytePackerTb;

-- Define architecture
architecture test of AxiStreamBytePackerTb is

   constant SWEEP_SIZE_C : positive := 4;

   constant SRC_CONFIG_C : AxiStreamConfigType := (
      TSTRB_EN_C    => false,
      TDATA_BYTES_C => SWEEP_SIZE_C,
      TDEST_BITS_C  => 0,
      TID_BITS_C    => 0,
      TKEEP_MODE_C  => TKEEP_COMP_C,
      TUSER_BITS_C  => 2,
      TUSER_MODE_C  => TUSER_FIRST_LAST_C);

   constant DST_CONFIG_C : AxiStreamConfigType := (
      TSTRB_EN_C    => false,
      TDATA_BYTES_C => 2*SWEEP_SIZE_C,
      TDEST_BITS_C  => 0,
      TID_BITS_C    => 0,
      TKEEP_MODE_C  => TKEEP_COMP_C,
      TUSER_BITS_C  => 2,
      TUSER_MODE_C  => TUSER_FIRST_LAST_C);

   constant CLK_PERIOD_C : time := 5.000 ns;
   constant TPD_C        : time := 1 ns;

   signal axiClk : sl := '0';
   signal axiRst : sl := '0';

   signal testInMaster  : AxiStreamMasterArray(SWEEP_SIZE_C-1 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
   signal testOutMaster : AxiStreamMasterArray(SWEEP_SIZE_C-1 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
   signal testFail      : slv(SWEEP_SIZE_C-1 downto 0)                  := (others => '0');

begin

   -----------------------------
   -- Generate a Clock and Reset
   -----------------------------
   U_ClkRst : entity surf.ClkRst
      generic map (
         CLK_PERIOD_G      => CLK_PERIOD_C,
         RST_START_DELAY_G => 0 ns,
         RST_HOLD_TIME_G   => 100 ns)
      port map (
         clkP => axiClk,
         clkN => open,
         rst  => axiRst,
         rstL => open);

   U_TestGen : for i in 0 to SWEEP_SIZE_C-1 generate

      U_PackTx : entity surf.AxiStreamBytePackerTbTx
         generic map (
            TPD_G         => TPD_C,
            BYTE_SIZE_C   => i+1,
            AXIS_CONFIG_G => SRC_CONFIG_C)
         port map (
            axiClk      => axiClk,
            axiRst      => axiRst,
            mAxisMaster => testInMaster(i));

      U_Pack : entity surf.AxiStreamBytePacker
         generic map (
            TPD_G           => TPD_C,
            SLAVE_CONFIG_G  => SRC_CONFIG_C,
            MASTER_CONFIG_G => DST_CONFIG_C)
         port map (
            axiClk      => axiClk,
            axiRst      => axiRst,
            sAxisMaster => testInMaster(i),
            mAxisMaster => testOutMaster(i));

      U_PackRx : entity surf.AxiStreamBytePackerTbRx
         generic map (
            TPD_G         => TPD_C,
            BYTE_SIZE_C   => i+1,
            AXIS_CONFIG_G => DST_CONFIG_C)
         port map (
            axiClk      => axiClk,
            axiRst      => axiRst,
            sAxisMaster => testOutMaster(i),
            fail        => testFail(i));
   end generate;

end test;

