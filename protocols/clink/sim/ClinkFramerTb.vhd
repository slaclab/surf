-------------------------------------------------------------------------------
-- File       : ClinkFramerTb.vhd
-------------------------------------------------------------------------------
-- Description: Simulation Testbed for clink framer
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
use work.ClinkPkg.all;

entity ClinkFramerTb is end ClinkFramerTb;

-- Define architecture
architecture test of ClinkFramerTb is

   constant AXIS_CONFIG_C : AxiStreamConfigType := (
      TSTRB_EN_C    => false,
      TDATA_BYTES_C => 16, -- 128 bits
      TDEST_BITS_C  => 0,
      TID_BITS_C    => 0,
      TKEEP_MODE_C  => TKEEP_COMP_C,
      TUSER_BITS_C  => 2,
      TUSER_MODE_C  => TUSER_FIRST_LAST_C);

   constant CLK_PERIOD_C : time := 5.000 ns;
   constant TPD_G        : time := 1 ns;

   signal sysClk : sl;
   signal sysRst : sl;

   signal linkMode     : slv(3 downto 0);
   signal dataMode     : slv(3 downto 0);
   signal dataEn       : sl;
   signal frameCount   : slv(31 downto 0);
   signal dropCount    : slv(31 downto 0);

   signal locked       : slv(2 downto 0);
   signal running      : sl;
   signal parData      : Slv28Array(2 downto 0);
   signal parValid     : slv(2 downto 0);
   signal parReady     : sl;

   signal dataMaster   : AxiStreamMasterType;
   signal dataSlave    : AxiStreamSlaveType;

   signal testCount    : slv(7 downto 0);

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

   linkMode <= CLM_DECA_C;
   dataMode <= CDM_8BIT_C;
   dataEn   <= '1';
   locked   <= (others=>'1');

   process ( sysClk ) begin
      if rising_edge(sysClk) then
         if sysRst = '1' then
            parData     <= (others=>(others=>'0')) after TPD_G;
            parValid    <= (others=>'0') after TPD_G;
            testCount   <= (others=>'0') after TPD_G;
         else

            parValid <= parValid xor "111" after TPD_G;

            if parValid(0) = '1' then

               if testCount = 255 then
                  testCount <= (others=>'0') after TPD_G;
               else
                  testCount <= testCount + 1 after TPD_G;
               end if;
   
               if testCount > 10 and testCount <= 20 then
                  parData(0)(25) <= '1' after TPD_G; -- fv
                  parData(0)(24) <= '1' after TPD_G; -- lv
                  parData(1)(27) <= '1' after TPD_G; -- lv
                  parData(2)(27) <= '1' after TPD_G; -- lv
               else
                  parData(0)(25) <= '0' after TPD_G; -- fv
                  parData(0)(24) <= '0' after TPD_G; -- lv
                  parData(1)(27) <= '0' after TPD_G; -- lv
                  parData(2)(27) <= '0' after TPD_G; -- lv
               end if;
            end if;
         end if;
      end if;
   end process;


   U_Framing: entity work.ClinkFraming
      generic map (
         TPD_G              => TPD_G,
         DATA_AXIS_CONFIG_G => AXIS_CONFIG_C)
      port map (
         sysClk       => sysClk,
         sysRst       => sysRst,
         -- Config and status
         linkMode      => linkMode,
         dataMode      => dataMode,
         dataEn        => dataEn,
         frameCount    => frameCount,
         dropCount     => dropCount,
         -- Data interface
         locked        => locked,
         running       => running,
         parData       => parData,
         parValid      => parValid,
         parReady      => parReady,
         -- Camera data
         dataMaster    => dataMaster,
         dataSlave     => dataSlave);

   dataSlave <= AXI_STREAM_SLAVE_FORCE_C;

   U_Uart : entity work.ClinkUart
      generic map (
         TPD_G              => TPD_G,
         CLK_FREQ_G         => 200.0e6)
      port map (
         clk             => sysClk,
         rst             => sysRst,
         baud            => toSlv(9600,24),
         sUartMaster     => AXI_STREAM_MASTER_INIT_C,
         sUartSlave      => open,
         sUartCtrl       => open,
         mUartMaster     => open,
         mUartSlave      => AXI_STREAM_SLAVE_INIT_C,
         rxIn            => '1',
         txOut           => open);

end test;

