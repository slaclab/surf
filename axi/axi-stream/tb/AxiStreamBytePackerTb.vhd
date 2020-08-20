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

   constant SRC_CONFIG_C : AxiStreamConfigType := (
      TSTRB_EN_C    => false,
      TDATA_BYTES_C => 16, -- 128 bits
      TDEST_BITS_C  => 0,
      TID_BITS_C    => 0,
      TKEEP_MODE_C  => TKEEP_COMP_C,
      TUSER_BITS_C  => 2,
      TUSER_MODE_C  => TUSER_FIRST_LAST_C);

   constant DST_CONFIG_C : AxiStreamConfigType := (
      TSTRB_EN_C    => false,
      TDATA_BYTES_C => 16, -- 128 bits
      TDEST_BITS_C  => 0,
      TID_BITS_C    => 0,
      TKEEP_MODE_C  => TKEEP_COMP_C,
      TUSER_BITS_C  => 2,
      TUSER_MODE_C  => TUSER_FIRST_LAST_C);

   constant CLK_PERIOD_C : time := 5.000 ns;
   constant TPD_G        : time := 1 ns;

   signal axiClk : sl;
   signal axiRst : sl;

   signal testInMaster    : AxiStreamMasterArray(15 downto 0);
   signal testOutMaster   : AxiStreamMasterArray(15 downto 0);
   signal testFail        : slv(15 downto 0);

begin

   -----------------------------
   -- Generate a Clock and Reset
   -----------------------------
   U_ClkRst : entity surf.ClkRst
      generic map (
         CLK_PERIOD_G      => CLK_PERIOD_C,
         RST_START_DELAY_G => 0 ns,     -- Wait this long into simulation before asserting reset
         RST_HOLD_TIME_G   => 10030 ns)  -- Hold reset for this long)
      port map (
         clkP => axiClk,
         clkN => open,
         rst  => axiRst,
         rstL => open);

   U_TestGen : for i in 0 to 15 generate

      U_PackTx : entity surf.AxiStreamBytePackerTbTx
         generic map (
            TPD_G         => TPD_G,
            BYTE_SIZE_C   => i+1,
            AXIS_CONFIG_G => SRC_CONFIG_C)
         port map (
            axiClk      => axiClk,
            axiRst      => axiRst,
            mAxisMaster => testInMaster(i));

      U_Pack: entity surf.AxiStreamBytePacker
         generic map (
            TPD_G           => TPD_G,
            SLAVE_CONFIG_G  => SRC_CONFIG_C,
            MASTER_CONFIG_G => DST_CONFIG_C)
         port map (
            axiClk       => axiClk,
            axiRst       => axiRst,
            sAxisMaster  => testInMaster(i),
            mAxisMaster  => testOutMaster(i));

      U_PackRx : entity surf.AxiStreamBytePackerTbRx
         generic map (
            TPD_G         => TPD_G,
            BYTE_SIZE_C   => i+1,
            AXIS_CONFIG_G => DST_CONFIG_C)
         port map (
            axiClk      => axiClk,
            axiRst      => axiRst,
            sAxisMaster => testOutMaster(i),
            fail        => testFail(i));
   end generate;

end test;

