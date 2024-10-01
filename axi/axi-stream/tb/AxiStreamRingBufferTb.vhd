-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Simulation Testbed for testing the AxiStreamRingBuffer module
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
use surf.AxiLitePkg.all;
use surf.AxiStreamPkg.all;
use surf.SsiPkg.all;

entity AxiStreamRingBufferTb is end AxiStreamRingBufferTb;

architecture testbed of AxiStreamRingBufferTb is

   constant CLK_PERIOD_C : time := 10 ns;
   constant TPD_C        : time := CLK_PERIOD_C/4;

   constant AXIS_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(dataBytes => 2);

   type RegType is record
      extTrig : sl;
      data    : slv(15 downto 0);
      cnt     : slv(11 downto 0);
   end record;

   constant REG_INIT_C : RegType := (
      extTrig => '0',
      data    => (others => '0'),
      cnt     => (others => '0'));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal clk : sl := '0';
   signal rst : sl := '1';

   signal axilWriteMaster : AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
   signal axilWriteSlave  : AxiLiteWriteSlaveType  := AXI_LITE_WRITE_SLAVE_INIT_C;
   signal axilReadMaster  : AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
   signal axilReadSlave   : AxiLiteReadSlaveType   := AXI_LITE_READ_SLAVE_INIT_C;

   signal axisMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal axisSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;

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
         rstL => open);

   --------------------------
   -- Design Under Test (DUT)
   --------------------------
   U_DUT : entity surf.AxiStreamRingBuffer
      generic map (
         TPD_G               => TPD_C,
         COMMON_CLK_G        => true,   -- true if dataClk=axilClk
         DATA_BYTES_G        => 2,      -- 16-bit data
         RAM_ADDR_WIDTH_G    => 10,     -- 1k samples deep
         -- AXI Stream Configurations
         GEN_SYNC_FIFO_G     => true,   -- true if axisClk=axilClk
         AXI_STREAM_CONFIG_G => AXIS_CONFIG_C)
      port map (
         -- Data to store in ring buffer (dataClk domain)
         dataClk         => clk,
         dataValue       => r.data,
         extTrig         => r.extTrig,
         -- AXI-Lite interface (axilClk domain)
         axilClk         => clk,
         axilRst         => rst,
         axilReadMaster  => axilReadMaster,
         axilReadSlave   => axilReadSlave,
         axilWriteMaster => axilWriteMaster,
         axilWriteSlave  => axilWriteSlave,
         -- AXI-Stream Interface (axilClk domain)
         axisClk         => clk,
         axisRst         => rst,
         axisMaster      => axisMaster,
         axisSlave       => axisSlave);

   comb : process (r, rst) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Reset the strobes
      v.extTrig := '0';

      -- Check if increment the counter
      if (r.cnt /= x"FFF") then

         -- Increment the counter
         v.cnt := r.cnt + 1;

         -- Check if making data pattern
         if r.cnt < 1024 then
            v.data := r.data + 1;
         else
            v.data := (others => '0');
         end if;

         -- check for the trigger event
         if (r.cnt = 1111) then
            -- Set the flag
            v.extTrig := '1';
         end if;

      end if;

      -- Synchronous Reset
      if (rst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

   end process comb;

   seq : process (clk) is
   begin
      if (rising_edge(clk)) then
         r <= rin after TPD_C;
      end if;
   end process seq;

end testbed;
