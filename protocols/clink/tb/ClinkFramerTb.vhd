-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
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
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;
use surf.ClinkPkg.all;

entity ClinkFramerTb is end ClinkFramerTb;

-- Define architecture
architecture test of ClinkFramerTb is

   constant AXIS_CONFIG_C : AxiStreamConfigType := (
      TSTRB_EN_C    => false,
      TDATA_BYTES_C => 16,              -- 128 bits
      TDEST_BITS_C  => 0,
      TID_BITS_C    => 0,
      TKEEP_MODE_C  => TKEEP_COMP_C,
      TUSER_BITS_C  => 2,
      TUSER_MODE_C  => TUSER_FIRST_LAST_C);

   constant CLK_PERIOD_C : time := 5.000 ns;
   constant TPD_G        : time := 1 ns;

   signal sysClk : sl;
   signal sysRst : sl;

   signal parData  : Slv28Array(2 downto 0);
   signal parValid : slv(2 downto 0);
   signal parReady : sl;

   signal dataMaster : AxiStreamMasterType;
   signal dataSlave  : AxiStreamSlaveType;

   signal testCount : slv(7 downto 0);

   signal sUartMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal sUartSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;
   signal mUartMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal loopback    : sl;

   signal chanConfig : ClChanConfigType              := CL_CHAN_CONFIG_INIT_C;
   signal chanStatus : ClChanStatusType              := CL_CHAN_STATUS_INIT_C;
   signal linkStatus : ClLinkStatusArray(2 downto 0) := (others => CL_LINK_STATUS_INIT_C);

begin

   -----------------------------
   -- Generate a Clock and Reset
   -----------------------------
   U_ClkRst : entity surf.ClkRst
      generic map (
         CLK_PERIOD_G      => CLK_PERIOD_C,
         RST_START_DELAY_G => 0 ns,  -- Wait this long into simulation before asserting reset
         RST_HOLD_TIME_G   => 10030 ns)  -- Hold reset for this long)
      port map (
         clkP => sysClk,
         clkN => open,
         rst  => sysRst,
         rstL => open);

   chanConfig.linkMode  <= CLM_DECA_C;
   chanConfig.dataMode  <= CDM_8BIT_C;
   chanConfig.dataEn    <= '1';
   linkStatus(0).locked <= '1';
   linkStatus(1).locked <= '1';
   linkStatus(2).locked <= '1';

   process (sysClk)
   begin
      if rising_edge(sysClk) then
         if sysRst = '1' then
            parData   <= (others => (others => '0')) after TPD_G;
            parValid  <= (others => '0')             after TPD_G;
            testCount <= (others => '0')             after TPD_G;
         else

            parValid <= parValid xor "111" after TPD_G;

            if parValid(0) = '1' then

               if testCount = 255 then
                  testCount <= (others => '0') after TPD_G;
               else
                  testCount <= testCount + 1 after TPD_G;
               end if;

               if testCount > 10 and testCount <= 20 then
                  parData(0)(25) <= '1' after TPD_G;  -- fv
                  parData(0)(24) <= '1' after TPD_G;  -- lv
                  parData(1)(27) <= '1' after TPD_G;  -- lv
                  parData(2)(27) <= '1' after TPD_G;  -- lv
               else
                  parData(0)(25) <= '0' after TPD_G;  -- fv
                  parData(0)(24) <= '0' after TPD_G;  -- lv
                  parData(1)(27) <= '0' after TPD_G;  -- lv
                  parData(2)(27) <= '0' after TPD_G;  -- lv
               end if;
            end if;

            sUartMaster.tValid <= '0' after TPD_G;
            if sUartSlave.tReady = '1' then
               sUartMaster.tValid            <= '1'                               after TPD_G;
               sUartMaster.tData(7 downto 0) <= sUartMaster.tData(7 downto 0) + 1 after TPD_G;
            end if;

         end if;
      end if;
   end process;


   U_Framing : entity surf.ClinkFraming
      generic map (
         TPD_G              => TPD_G,
         DATA_AXIS_CONFIG_G => AXIS_CONFIG_C)
      port map (
         sysClk     => sysClk,
         sysRst     => sysRst,
         -- Config and status
         chanConfig => chanConfig,
         chanStatus => chanStatus,
         linkStatus => linkStatus,
         -- Data interface
         parData    => parData,
         parValid   => parValid,
         parReady   => parReady,
         -- Camera data
         dataClk    => sysClk,
         dataRst    => sysRst,
         dataMaster => dataMaster,
         dataSlave  => dataSlave);

   dataSlave <= AXI_STREAM_SLAVE_FORCE_C;

   U_Uart : entity surf.ClinkUart
      generic map (
         TPD_G              => TPD_G,
         UART_AXIS_CONFIG_G => AXIS_CONFIG_C)
      port map (
         -- Clock and reset, 200Mhz
         intClk      => sysClk,
         intRst      => sysRst,
         -- Configurations
         baud        => toSlv(9600, 24),
         throttle    => toSlv(1, 16),
         -- Data In/Out
         uartClk     => sysClk,
         uartRst     => sysRst,
         sUartMaster => sUartMaster,
         sUartSlave  => sUartSlave,
         mUartMaster => mUartMaster,
         mUartSlave  => AXI_STREAM_SLAVE_FORCE_C,
         -- Serial data
         rxIn        => loopback,
         txOut       => loopback);

end test;

