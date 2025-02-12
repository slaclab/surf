-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Simulation Testbed for testing the AxiRingBufferTb module
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
use surf.AxiStreamPkg.all;
use surf.AxiLitePkg.all;
use surf.SsiPkg.all;

entity AxiRingBufferTb is end AxiRingBufferTb;

architecture testbed of AxiRingBufferTb is

   constant CLK_PERIOD_C : time := 10 ns;
   constant TPD_G        : time := CLK_PERIOD_C/4;

   constant DATA_BYTES_C           : positive := 4;   -- Units of bytes
   constant BURST_BYTES_C          : positive := 256;  -- Units of bytes
   constant RING_BUFF_ADDR_WIDTH_C : positive := 10;  -- Units of 2^(data words)

   constant DATA_BITSIZE_C : positive := log2(DATA_BYTES_C);
   constant MEM_BITSIZE_C  : positive := RING_BUFF_ADDR_WIDTH_C+DATA_BITSIZE_C;

   constant AXIS_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(
      dataBytes => DATA_BYTES_C,
      tKeepMode => TKEEP_FIXED_C,
      tUserMode => TUSER_FIRST_LAST_C,
      tDestBits => 0,
      tUserBits => 2,
      tIdBits   => 0);

   constant AXI_CONFIG_C : AxiConfigType := (
      ADDR_WIDTH_C => MEM_BITSIZE_C,
      DATA_BYTES_C => DATA_BYTES_C,
      ID_BITS_C    => 1,
      LEN_BITS_C   => 8);

   -- constant TRIG_INDEX_C : positive := 2000; -- wrdOffset=68
   -- constant TRIG_INDEX_C : positive := 2044; -- wrdOffset=244
   -- constant TRIG_INDEX_C : positive := 2045; -- wrdOffset=248
   -- constant TRIG_INDEX_C : positive := 2046; -- wrdOffset=252
   -- constant TRIG_INDEX_C : positive := 2047; -- wrdOffset=0
   -- constant TRIG_INDEX_C : positive := 2048; -- wrdOffset=4
   -- constant TRIG_INDEX_C : positive := 2049; -- wrdOffset=8
   constant TRIG_INDEX_C : positive := 2100;  -- wrdOffset=212

   type RegType is record
      passed        : sl;
      failed        : sl;
      extTrig       : sl;
      dataValue     : slv(8*DATA_BYTES_C-1 downto 0);
      expectedValue : slv(8*DATA_BYTES_C-1 downto 0);
   end record RegType;
   constant REG_INIT_C : RegType := (
      passed        => '0',
      failed        => '0',
      extTrig       => '0',
      dataValue     => (others => '0'),
      expectedValue => toSlv(TRIG_INDEX_C-959, 32));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal clk : sl := '0';
   signal rst : sl := '1';

   signal axiWriteMaster : AxiWriteMasterType := AXI_WRITE_MASTER_INIT_C;
   signal axiWriteSlave  : AxiWriteSlaveType  := AXI_WRITE_SLAVE_INIT_C;
   signal axiReadMaster  : AxiReadMasterType  := AXI_READ_MASTER_INIT_C;
   signal axiReadSlave   : AxiReadSlaveType   := AXI_READ_SLAVE_INIT_C;

   signal axisMaster : AxiStreamMasterType;

   signal passed : sl := '0';
   signal failed : sl := '0';

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
         rst  => rst);

   -------------
   -- AXI Memory
   -------------
   U_MEM : entity surf.AxiRam
      generic map (
         TPD_G        => TPD_G,
         AXI_CONFIG_G => AXI_CONFIG_C)
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

   --------------------
   -- Design Under Test
   --------------------
   U_DUT : entity surf.AxiRingBuffer
      generic map (
         TPD_G                  => TPD_G,
         -- Ring buffer Configurations
         DATA_BYTES_G           => DATA_BYTES_C,
         RING_BUFF_ADDR_WIDTH_G => RING_BUFF_ADDR_WIDTH_C,
         -- AXI4 Configurations
         BURST_BYTES_G          => BURST_BYTES_C,
         -- AXI Stream Configurations
         AXIS_CONFIG_G          => AXIS_CONFIG_C)
      port map (
         -- Data to store in ring buffer (dataClk domain)
         dataClk         => clk,
         dataRst         => rst,
         dataValue       => r.dataValue,
         extTrig         => r.extTrig,
         -- AXI Ring Buffer Memory Interface (dataClk domain)
         axiClk          => clk,
         axiRst          => rst,
         mAxiWriteMaster => axiWriteMaster,
         mAxiWriteSlave  => axiWriteSlave,
         mAxiReadMaster  => axiReadMaster,
         mAxiReadSlave   => axiReadSlave,
         -- AXI-Lite Register Interface (axilClk domain)
         axilClk         => clk,
         axilRst         => rst,
         axilReadMaster  => AXI_LITE_READ_MASTER_INIT_C,
         axilReadSlave   => open,
         axilWriteMaster => AXI_LITE_WRITE_MASTER_INIT_C,
         axilWriteSlave  => open,
         -- AXI-Stream Result Interface (axisClk domain)
         axisClk         => clk,
         axisRst         => rst,
         axisMaster      => axisMaster,
         axisSlave       => AXI_STREAM_SLAVE_FORCE_C);

   --------------------------------------
   -- Load waveofrm and check the Results
   --------------------------------------
   comb : process (axisMaster, r, rst) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Reset the strobe
      v.extTrig := '0';

      -- Increment the counter
      v.dataValue := r.dataValue + 1;

      -- Generate the trigger
      if (r.dataValue = TRIG_INDEX_C) then
         -- Set the flag
         v.extTrig := '1';
      end if;

      -- Check for data
      if (axisMaster.tValid = '1') then

         -- Increment the counter
         v.expectedValue := r.expectedValue + 1;

         -- Compare the data
         if (axisMaster.tData(8*DATA_BYTES_C-1 downto 0) /= r.expectedValue) then
            -- Set the flag
            v.failed := '1';

         elsif (axisMaster.tLast = '1') then
            -- Set the flag
            v.passed := '1';
         end if;

      end if;

      -- Outputs
      passed <= r.passed;
      failed <= r.failed;

      -- Reset
      if (rst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

   end process comb;

   seq : process (clk) is
   begin
      if rising_edge(clk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   process(failed, passed)
   begin
      if passed = '1' then
         assert false
            report "Simulation Passed!" severity failure;
      elsif failed = '1' then
         assert false
            report "Simulation Failed!" severity failure;
      end if;
   end process;

end testbed;
