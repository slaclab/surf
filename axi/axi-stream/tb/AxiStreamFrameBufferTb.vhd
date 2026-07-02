-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Simulation Testbed for testing the AxiStreamFrameBuffer module
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

entity AxiStreamFrameBufferTb is end AxiStreamFrameBufferTb;

architecture testbed of AxiStreamFrameBufferTb is

   constant CLK_PERIOD_C : time := 10 ns;
   constant TPD_C        : time := CLK_PERIOD_C/4;

   constant AXIS_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(dataBytes => 2);

   type RegType is record
      data       : slv(15 downto 0);
      dataValid  : sl;
      frameDone  : sl;
      cnt        : slv(11 downto 0);
      dataRdTrig : sl;
      axilRdTrig : sl;
   end record;

   constant REG_INIT_C : RegType := (
      data       => (others => '0'),
      dataValid  => '0',
      frameDone  => '0',
      cnt        => (others => '0'),
      dataRdTrig => '0',
      axilRdTrig => '0');

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal dataClk : sl := '0';
   signal dataRst : sl := '1';
   signal axiClk  : sl := '0';
   signal axiRst  : sl := '1';

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
   U_DataClkRst : entity surf.ClkRst
      generic map (
         CLK_PERIOD_G      => CLK_PERIOD_C,
         RST_START_DELAY_G => 0 ns,  -- Wait this long into simulation before asserting reset
         RST_HOLD_TIME_G   => 1000 ns)  -- Hold reset for this long
      port map (
         clkP => dataClk,
         clkN => open,
         rst  => dataRst,
         rstL => open);

   U_AxiClkRst : entity surf.ClkRst
      generic map (
         CLK_PERIOD_G      => CLK_PERIOD_C/3.1415,  -- Make clocks more or less async
         RST_START_DELAY_G => 0 ns,  -- Wait this long into simulation before asserting reset
         RST_HOLD_TIME_G   => 1000 ns)  -- Hold reset for this long
      port map (
         clkP => axiClk,
         clkN => open,
         rst  => axiRst,
         rstL => open);

   --------------------------
   -- Design Under Test (DUT)
   --------------------------
   U_DUT : entity surf.AxiStreamFrameBuffer
      generic map (
         TPD_G               => TPD_C,
         COMMON_CLK_G        => false,  -- true if dataClk=axilClk
         DATA_BYTES_G        => 2,      -- 16-bit data
         -- RAM_ADDR_WIDTH_G    => 11,    -- 2048 samples deep
         RAM_ADDR_WIDTH_G    => 10,     -- 1024 samples deep
         SAFE_BUFFS_G        => true,
         -- AXI Stream Configurations
         GEN_SYNC_FIFO_G     => true,   -- true if axisClk=axilClk
         AXI_STREAM_CONFIG_G => AXIS_CONFIG_C)
      port map (
         -- Data to store in frame buffer (dataClk domain)
         dataClk         => dataClk,
         dataRst         => dataRst,
         dataValue       => r.data,
         dataValid       => r.dataValid,
         dataFrameTxLast => r.frameDone,
         dataRdTrig      => r.dataRdTrig,
         -- AXI-Lite interface (axilClk domain)
         axilClk         => axiClk,
         axilRst         => axiRst,
         axilReadMaster  => axilReadMaster,
         axilReadSlave   => axilReadSlave,
         axilWriteMaster => axilWriteMaster,
         axilWriteSlave  => axilWriteSlave,
         axilRdTrig      => r.axilRdTrig,
         -- AXI-Stream Interface (axilClk domain)
         axisClk         => axiClk,
         axisRst         => axiRst,
         axisMaster      => axisMaster,
         axisSlave       => axisSlave);

   comb : process (r, dataRst) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Reset the strobes
      v.frameDone  := '0';
      v.dataRdTrig := '0';
      v.axilRdTrig := '0';

      -- Check if increment the counter
      if (r.cnt /= x"FFF") then

         -- Increment the counter
         v.cnt := r.cnt + 1;

         -- Generate data
         if r.cnt < 2048 then
            v.data      := r.data + 1;
            v.dataValid := '1';
         else
            v.data      := (others => '0');
            v.dataValid := '0';
         end if;

         -- Frame done issued half way through, to check continous frame
         -- recording and done flag functionality. Data will go on for
         -- another buffer length to allow for check of the buffer full
         -- frame end condition.
         if (r.cnt = 1023) then
            -- Set the flag
            v.frameDone := '1';
         end if;

         -- Check for the readout trigger event
         if (r.cnt = 1023) then
            -- Set the flag
            v.dataRdTrig := '1';
         end if;

         -- Test trigger signal synchronous to axilClk.
         -- Stretch to make sure it registers.
         if (r.cnt > 1500) and (r.cnt < (1500 + 32)) then
            -- Set the flag
            v.axilRdTrig := '1';
         end if;

      end if;

      -- Start hammering the trigger line to see if the module reacts
      -- correctly and starts next readout immediately after last one
      -- completed.
      if (r.cnt > 2048 + 512) then
         -- Set the flag
         v.dataRdTrig := '1';
      end if;

      -- Synchronous Reset
      if (dataRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

   end process comb;

   seq : process (dataClk) is
   begin
      if (rising_edge(dataClk)) then
         r <= rin after TPD_C;
      end if;
   end process seq;

end testbed;
