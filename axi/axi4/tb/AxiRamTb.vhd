-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Simulation Testbed for testing the AxiRamTb module
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
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;


library surf;
use surf.StdRtlPkg.all;
use surf.AxiPkg.all;
use surf.AxiLitePkg.all;

entity AxiRamTb is end AxiRamTb;

architecture testbed of AxiRamTb is

   constant CLK_PERIOD_C : time := 10 ns;
   constant TPD_G        : time := CLK_PERIOD_C/4;

   constant AXI_CONFIG_C : AxiConfigType := (
      ADDR_WIDTH_C => 16,
      DATA_BYTES_C => 8,
      ID_BITS_C    => 4,
      LEN_BITS_C   => 8);

   constant START_ADDR_C : slv(AXI_CONFIG_C.ADDR_WIDTH_C-1 downto 0) := (others => '0');
   constant STOP_ADDR_C  : slv(AXI_CONFIG_C.ADDR_WIDTH_C-1 downto 0) := (others => '1');

   signal clk  : sl := '0';
   signal rst  : sl := '0';
   signal rstL : sl := '1';

   signal memReady    : sl := '0';
   signal memError    : sl := '0';
   signal memReadyDly : sl := '0';
   signal memErrorDly : sl := '0';

   signal axiWriteMaster : AxiWriteMasterType := AXI_WRITE_MASTER_INIT_C;
   signal axiWriteSlave  : AxiWriteSlaveType  := AXI_WRITE_SLAVE_INIT_C;
   signal axiReadMaster  : AxiReadMasterType  := AXI_READ_MASTER_INIT_C;
   signal axiReadSlave   : AxiReadSlaveType   := AXI_READ_SLAVE_INIT_C;

begin

   ---------------------------
   -- Generate clock and reset
   ---------------------------
   U_ClkRst : entity surf.ClkRst
      generic map (
         CLK_PERIOD_G      => CLK_PERIOD_C,
         RST_START_DELAY_G => 0 ns,  -- Wait this long into simulation before asserting reset
         RST_HOLD_TIME_G   => 1000 ns)  -- Hold reset for this long)
      port map (
         clkP => clk,
         clkN => open,
         rst  => rst,
         rstL => rstL);

   -------------
   -- AXI Memory
   -------------
   U_MEM : entity surf.AxiRam
      generic map (
         TPD_G          => TPD_G,
         ------------------------------
         -- Select Either XPM or inferred
         ------------------------------
         SYNTH_MODE_G   => "inferred",
         -- SYNTH_MODE_G => "xpm",
         ------------------------------
         -- LUT RAM
         ------------------------------
         -- MEMORY_TYPE_G  => "distributed",
         -- READ_LATENCY_G => 0,
         ------------------------------
         -- BRAM
         ------------------------------
         MEMORY_TYPE_G => "block",
         READ_LATENCY_G => 2,
         ------------------------------
         AXI_CONFIG_G   => AXI_CONFIG_C)
      port map (
         -- Clock and Reset
         axiClk          => clk,
         axiRst          => rst,
         -- Slave Write Interface
         sAxiWriteMaster => axiWriteMaster,
         sAxiWriteSlave  => axiWriteSlave,
         -- Slave Read Interface
         sAxiReadMaster  => axiReadMaster,
         sAxiReadSlave   => axiReadSlave);

   ----------------
   -- Memory Tester
   ----------------
   U_AxiMemTester : entity surf.AxiMemTester
      generic map (
         TPD_G        => TPD_G,
         START_ADDR_G => START_ADDR_C,
         STOP_ADDR_G  => STOP_ADDR_C,
         AXI_CONFIG_G => AXI_CONFIG_C)
      port map (
         -- AXI-Lite Interface
         axilClk         => clk,
         axilRst         => rst,
         axilReadMaster  => AXI_LITE_READ_MASTER_INIT_C,
         axilReadSlave   => open,
         axilWriteMaster => AXI_LITE_WRITE_MASTER_INIT_C,
         axilWriteSlave  => open,
         memReady        => memReady,
         memError        => memError,
         -- DDR Memory Interface
         axiClk          => clk,
         axiRst          => rst,
         start           => rstL,
         axiWriteMaster  => axiWriteMaster,
         axiWriteSlave   => axiWriteSlave,
         axiReadMaster   => axiReadMaster,
         axiReadSlave    => axiReadSlave);

   ---------------------
   -- Report the Results
   ---------------------
   process(clk)
   begin
      if rising_edge(clk) then
         memErrorDly <= memError after TPD_G;
         memReadyDly <= memReady after TPD_G;
         if (memErrorDly = '1') then
            assert false
               report "Simulation Failed!" severity failure;
         end if;
         if (memReadyDly = '1') then
            assert false
               report "Simulation Passed!" severity failure;
         end if;
      end if;
   end process;

end testbed;
