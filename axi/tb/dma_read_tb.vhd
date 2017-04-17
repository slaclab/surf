-------------------------------------------------------------------------------
-- File       : dma_read_tb.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-05-02
-- Last update: 2016-09-06
-------------------------------------------------------------------------------
-- Description: Simulation Testbed for DMA read
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
use unisim.vcomponents.all;

use work.StdRtlPkg.all;
use work.AxiPkg.all;
use work.AxiDmaPkg.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;

entity dma_read_tb is end dma_read_tb;

-- Define architecture
architecture dma_read_tb of dma_read_tb is

   constant CLK_PERIOD_C   : time    := 4 ns;
   constant TPD_G          : time    := CLK_PERIOD_C/4;
   constant USE_PEND_C     : boolean := true;
   constant BACKPRESSURE_C : boolean := true;

   constant AXIS_CONFIG_C : AxiStreamConfigType := (
      TSTRB_EN_C    => false,
      TDATA_BYTES_C => 8,
      TDEST_BITS_C  => 8,
      TID_BITS_C    => 0,
      TKEEP_MODE_C  => TKEEP_COMP_C,
      TUSER_BITS_C  => 8,
      TUSER_MODE_C  => TUSER_FIRST_LAST_C);

   constant AXI_CONFIG_C : AxiConfigType := (
      ADDR_WIDTH_C => 32,
      DATA_BYTES_C => 8,
      ID_BITS_C    => 8,
      LEN_BITS_C   => 4);

   type StateType is (
      INIT_S,
      REQ_S,
      CHECK_S,
      HANDSHAKE_S,
      DONE_S);

   type RegType is record
      sof       : sl;
      passed    : sl;
      passedDly : sl;
      failed    : slv(7 downto 0);
      failedDly : slv(7 downto 0);
      byteCnt   : slv(31 downto 0);
      dmaReq    : AxiReadDmaReqType;
      axisSlave : AxiStreamSlaveType;
      state     : StateType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      sof       => '1',
      passed    => '0',
      passedDly => '0',
      failed    => (others => '0'),
      failedDly => (others => '0'),
      byteCnt   => (others => '0'),
      dmaReq    => AXI_READ_DMA_REQ_INIT_C,
      axisSlave => AXI_STREAM_SLAVE_INIT_C,
      state     => INIT_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal axiClk        : sl;
   signal axiClkRst     : sl;
   signal dmaAck        : AxiReadDmaAckType;
   signal axisMaster    : AxiStreamMasterType;
   signal axisSlave     : AxiStreamSlaveType;
   signal axiReadMaster : AxiReadMasterType;
   signal axiReadSlave  : AxiReadSlaveType;

begin

   -----------------------------
   -- Generate a Clock and Reset
   -----------------------------
   U_ClkRst : entity work.ClkRst
      generic map (
         CLK_PERIOD_G      => CLK_PERIOD_C,
         RST_START_DELAY_G => 0 ns,     -- Wait this long into simulation before asserting reset
         RST_HOLD_TIME_G   => 1000 ns)  -- Hold reset for this long)
      port map (
         clkP => axiClk,
         clkN => open,
         rst  => axiClkRst,
         rstL => open);  

   ---------------------------------
   -- Emulate the AXI Read Interface
   ---------------------------------
   U_AxiReadEmulate : entity work.AxiReadEmulate
      generic map (
         TPD_G        => TPD_G,
         AXI_CONFIG_G => AXI_CONFIG_C) 
      port map (
         axiClk        => axiClk,
         axiRst        => axiClkRst,
         axiReadMaster => axiReadMaster,
         axiReadSlave  => axiReadSlave);         

   -----------------------------
   -- Module that's being tested
   -----------------------------
   U_AxiStreamDmaRead : entity work.AxiStreamDmaRead
      generic map (
         TPD_G           => TPD_G,
         AXIS_READY_EN_G => true,
         AXIS_CONFIG_G   => AXIS_CONFIG_C,
         AXI_CONFIG_G    => AXI_CONFIG_C,
         AXI_BURST_G     => "01",
         AXI_CACHE_G     => "1111",
         PEND_THRESH_G   => ite(USE_PEND_C, 512, 0))
      port map (
         axiClk        => axiClk,
         axiRst        => axiClkRst,
         dmaReq        => r.dmaReq,
         dmaAck        => dmaAck,
         axisMaster    => axisMaster,
         axisSlave     => axisSlave,
         axisCtrl      => AXI_STREAM_CTRL_UNUSED_C,
         axiReadMaster => axiReadMaster,
         axiReadSlave  => axiReadSlave);         

   comb : process (axiClkRst, axisMaster, dmaAck, r) is
      variable v : RegType;
   begin
      -- Latch the current value   
      v := r;

      -- Check if back pressuring
      if (BACKPRESSURE_C) then
         -- Toggle
         v.axisSlave.tReady := not(r.axisSlave.tReady);
      else
         -- Never back pressure
         v.axisSlave.tReady := '1';
      end if;

      -- Keep a delayed copy
      v.passedDly := r.passed;
      v.failedDly := r.failed;

      -- State machine
      case r.state is
         ----------------------------------------------------------------------
         when INIT_S =>
            -- Initial the DMA request bus
            v.dmaReq           := AXI_READ_DMA_REQ_INIT_C;
            v.dmaReq.address   := toSlv(0, 64);
            v.dmaReq.size      := toSlv(1, 32);
            v.dmaReq.firstUser := toSlv(2, 8);
            v.dmaReq.lastUser  := toSlv(3, 8);
            v.dmaReq.dest      := toSlv(4, 8);
            v.dmaReq.id        := toSlv(5, 8);
            -- Next state
            v.state            := REQ_S;
         ----------------------------------------------------------------------
         when REQ_S =>
            -- Check the done flag
            if (dmaAck.done = '0') then
               -- Set the flags
               v.dmaReq.request := '1';
               v.sof            := '1';
               -- Reset the counter
               v.byteCnt        := (others => '0');
               -- Next state
               v.state          := CHECK_S;
            end if;
         ----------------------------------------------------------------------
         when CHECK_S =>
            -- Check for data
            if (v.axisSlave.tReady = '1') and (axisMaster.tValid = '1') then
               -- Check for SOF
               if r.sof = '1' then
                  -- Reset the flag
                  v.sof := '0';
                  -- Check the firstUser
                  if (r.dmaReq.firstUser(AXIS_CONFIG_C.TUSER_BITS_C-1 downto 0) /= axiStreamGetUserField(AXIS_CONFIG_C, axisMaster, 0)) then
                     -- Check for the non-byte 1 case because lastUser can overwrite firstUser if only 1 byte is transferred 
                     if (r.dmaReq.size /= 1) then
                        -- Error detected
                        v.failed(0) := '1';
                     end if;
                  end if;
               end if;
               -- Check the tDest
               if (r.dmaReq.dest(AXIS_CONFIG_C.TDEST_BITS_C-1 downto 0) /= axisMaster.tDest(AXIS_CONFIG_C.TDEST_BITS_C-1 downto 0)) then
                  -- Error detected
                  v.failed(1) := '1';
               end if;
               -- Check the tId
               if (r.dmaReq.id(AXIS_CONFIG_C.TDEST_BITS_C-1 downto 0) /= axisMaster.tId(AXIS_CONFIG_C.TDEST_BITS_C-1 downto 0)) then
                  -- Error detected
                  v.failed(2) := '1';
               end if;
               -- Increment the byte counter
               v.byteCnt := r.byteCnt + getTKeep(axisMaster.tKeep);
               -- Check for EOF
               if (axisMaster.tLast = '1') then
                  -- Check the firstUser
                  if (r.dmaReq.lastUser(AXIS_CONFIG_C.TUSER_BITS_C-1 downto 0) /= axiStreamGetUserField(AXIS_CONFIG_C, axisMaster, -1)) then
                     -- Error detected
                     v.failed(3) := '1';
                  end if;
                  -- Check for invalid DMA size
                  if (r.dmaReq.size /= v.byteCnt) then
                     -- Error detected
                     v.failed(4) := '1';
                  end if;
                  -- Next state
                  v.state := HANDSHAKE_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when HANDSHAKE_S =>
            -- Check the done flag
            if (dmaAck.done = '1') then
               -- Reset the flag
               v.dmaReq.request   := '0';
               -- Modify the DMA inputs
               v.dmaReq.address   := r.dmaReq.address + 1;
               v.dmaReq.size      := r.dmaReq.size + 1;
               v.dmaReq.firstUser := r.dmaReq.firstUser + 1;
               v.dmaReq.lastUser  := r.dmaReq.lastUser + 1;
               v.dmaReq.dest      := r.dmaReq.dest + 1;
               v.dmaReq.id        := r.dmaReq.id + 1;
               -- Check for last DMA transfer
               if (r.dmaReq.address = 3000) then
                  -- Next state
                  v.state := DONE_S;
               else
                  -- Next state
                  v.state := REQ_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when DONE_S =>
            v.passed := '1';
      ----------------------------------------------------------------------
      end case;

      -- Reset      
      if (axiClkRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle      
      rin <= v;

      -- Outputs
      axisSlave <= v.axisSlave;

   end process comb;

   seq : process (axiClk) is
   begin
      if (rising_edge(axiClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   process(r)
   begin
      if uOr(r.failedDly) = '1' then
         assert false
            report "Simulation Failed!" severity failure;
      end if;
      if r.passedDly = '1' then
         assert false
            report "Simulation Passed!" severity failure;
      end if;
   end process;

end dma_read_tb;
