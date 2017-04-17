-------------------------------------------------------------------------------
-- File       : SrpV3Core.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-03-22
-- Last update: 2016-11-07
-------------------------------------------------------------------------------
-- Description: SLAC Register Protocol Version 3, AXI-Lite Interface
--
-- Documentation: https://confluence.slac.stanford.edu/x/cRmVD
--
-- Note: This module only supports 32-bit aligned addresses and 32-bit transactions.  
--       For non 32-bit aligned addresses or non 32-bit transactions, use
--       the SrpV3Axi.vhd module with the AxiToAxiLite.vhd bridge
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
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;
use work.AxiLitePkg.all;
use work.SrpV3Pkg.all;

entity SrpV3Core is
   generic (
      TPD_G               : time                    := 1 ns;
      PIPE_STAGES_G       : natural range 0 to 16   := 1;
      FIFO_PAUSE_THRESH_G : positive range 1 to 511 := 256;
      SLAVE_READY_EN_G    : boolean                 := false;
      GEN_SYNC_FIFO_G     : boolean                 := false;
      ALTERA_SYN_G        : boolean                 := false;
      ALTERA_RAM_G        : string                  := "M9K";
      SRP_CLK_FREQ_G      : real                    := 156.25E+6;  -- units of Hz
      AXI_STREAM_CONFIG_G : AxiStreamConfigType     := ssiAxiStreamConfig(2);
      UNALIGNED_ACCESS_G  : boolean                 := false;
      BYTE_ACCESS_G       : boolean                 := false;
      WRITE_EN_G          : boolean                 := true;       -- Write ops enabled
      READ_EN_G           : boolean                 := true        -- Read ops enabled
      );
   port (
      -- AXIS Slave Interface (sAxisClk domain) 
      sAxisClk    : in  sl;
      sAxisRst    : in  sl;
      sAxisMaster : in  AxiStreamMasterType;
      sAxisSlave  : out AxiStreamSlaveType;
      sAxisCtrl   : out AxiStreamCtrlType;
      -- AXIS Master Interface (mAxisClk domain) 
      mAxisClk    : in  sl;
      mAxisRst    : in  sl;
      mAxisMaster : out AxiStreamMasterType;
      mAxisSlave  : in  AxiStreamSlaveType;
      -- Master AXI-Lite Interface (axilClk domain)
      srpClk      : in  sl;
      srpRst      : in  sl;
      srpReq      : out SrpV3ReqType;
      srpAck      : in  SrpV3AckType;
      srpWrMaster : out AxiStreamMasterType;
      srpWrSlave  : in  AxiStreamSlaveType;
      srpRdMaster : in  AxiStreamMasterType;
      srpRdSlave  : out AxiStreamSlaveType);
end SrpV3Core;

architecture rtl of SrpV3Core is

   constant TIMEOUT_C : natural := (getTimeRatio(SRP_CLK_FREQ_G, 10.0) - 1);  -- 100 ms timeout

   constant SRP_AXIS_CONFIG_C : AxiStreamConfigType := (
      TSTRB_EN_C    => false,
      TDATA_BYTES_C => 4,
      TDEST_BITS_C  => AXI_STREAM_CONFIG_G.TDEST_BITS_C,
      TID_BITS_C    => AXI_STREAM_CONFIG_G.TID_BITS_C,
      TKEEP_MODE_C  => TKEEP_COMP_C,
      TUSER_BITS_C  => 2,
      TUSER_MODE_C  => TUSER_FIRST_LAST_C);

   type StateType is (
      IDLE_S,
      BLOWOFF_RX_S,
      BLOWOFF_READ_DATA_S,
      HDR_REQ_S,
      HDR_RESP_S,
      READ_S,
      WRITE_S,
      WAIT_ACK_S,
      FOOTER_S);

   type RegType is record
      timer       : natural range 0 to TIMEOUT_C;
      hdrCnt      : slv(3 downto 0);
      remVer      : slv(7 downto 0);
      timeoutSize : slv(7 downto 0);
      timeoutCnt  : slv(7 downto 0);
      txnCnt      : slv(29 downto 0);
      memResp     : slv(7 downto 0);
      timeout     : sl;
      eofe        : sl;
      frameError  : sl;
      verMismatch : sl;
      reqError    : sl;
      rxSlave     : AxiStreamSlaveType;
      txMaster    : AxiStreamMasterType;
      state       : StateType;
      srpReq      : SrpV3ReqType;
      srpWrMaster : AxiStreamMasterType;
      srpRdSlave  : AxiStreamSlaveType;
   end record RegType;
   constant REG_INIT_C : RegType := (
      timer       => 0,
      hdrCnt      => (others => '0'),
      remVer      => (others => '0'),
      timeoutSize => (others => '0'),
      timeoutCnt  => (others => '0'),
      txnCnt      => (others => '0'),
      memResp     => (others => '0'),
      timeout     => '0',
      eofe        => '0',
      frameError  => '0',
      verMismatch => '0',
      reqError    => '0',
      rxSlave     => AXI_STREAM_SLAVE_INIT_C,
      txMaster    => axiStreamMasterInit(SRP_AXIS_CONFIG_C),
      state       => IDLE_S,
      srpReq      => SRPV3_REQ_INIT_C,
      srpWrMaster => axiStreamMasterInit(SRP_AXIS_CONFIG_C),
      srpRdSlave  => AXI_STREAM_SLAVE_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal sCtrl          : AxiStreamCtrlType;
   signal rxMaster       : AxiStreamMasterType;
   signal rxSlave        : AxiStreamSlaveType;
   signal rxCtrl         : AxiStreamCtrlType;
   signal txSlave        : AxiStreamSlaveType;
   signal srpRdMasterInt : AxiStreamMasterType;
   signal srpRdSlaveInt  : AxiStreamSlaveType;
   signal srpWrMasterInt : AxiStreamMasterType;
   signal srpWrSlaveInt  : AxiStreamSlaveType;

   -- attribute dont_touch                    : string;
   -- attribute dont_touch of r               : signal is "TRUE";

begin

   sAxisCtrl <= sCtrl;

   RX_FIFO : entity work.SsiFifo
      generic map (
         -- General Configurations
         TPD_G                  => TPD_G,
         EN_FRAME_FILTER_G      => true,
         PIPE_STAGES_G          => PIPE_STAGES_G,
         SLAVE_READY_EN_G       => SLAVE_READY_EN_G,
         VALID_THOLD_G          => 0,  -- = 0 = only when frame ready                                                                 
         -- FIFO configurations
         BRAM_EN_G              => true,
         XIL_DEVICE_G           => "7SERIES",
         USE_BUILT_IN_G         => false,
         GEN_SYNC_FIFO_G        => GEN_SYNC_FIFO_G,
         ALTERA_SYN_G           => ALTERA_SYN_G,
         ALTERA_RAM_G           => ALTERA_RAM_G,
         FIFO_ADDR_WIDTH_G      => 9,   -- 2kB/FIFO = 32-bits x 512 entries
         CASCADE_SIZE_G         => 3,   -- 6kB = 3 FIFOs x 2 kB/FIFO
         CASCADE_PAUSE_SEL_G    => 2,   -- Set pause select on top FIFO
         FIFO_FIXED_THRESH_G    => true,
         FIFO_PAUSE_THRESH_G    => FIFO_PAUSE_THRESH_G,
         -- AXI Stream Port Configurations
         SLAVE_AXI_CONFIG_G     => AXI_STREAM_CONFIG_G,
         MASTER_AXI_CONFIG_G    => SRP_AXIS_CONFIG_C)
      port map (
         -- Slave Port
         sAxisClk    => sAxisClk,
         sAxisRst    => sAxisRst,
         sAxisMaster => sAxisMaster,
         sAxisSlave  => sAxisSlave,
         sAxisCtrl   => sCtrl,
         -- Master Port
         mAxisClk    => srpClk,
         mAxisRst    => srpRst,
         mAxisMaster => rxMaster,
         mAxisSlave  => rxSlave);

   GEN_SYNC_SLAVE : if (GEN_SYNC_FIFO_G = true) generate
      rxCtrl <= sCtrl;
   end generate;

   GEN_ASYNC_SLAVE : if (GEN_SYNC_FIFO_G = false) generate
      Sync_Ctrl : entity work.SynchronizerVector
         generic map (
            TPD_G   => TPD_G,
            WIDTH_G => 2,
            INIT_G  => "11")
         port map (
            clk        => srpClk,
            rst        => srpRst,
            dataIn(0)  => sCtrl.pause,
            dataIn(1)  => sCtrl.idle,
            dataOut(0) => rxCtrl.pause,
            dataOut(1) => rxCtrl.idle);
      Sync_Overflow : entity work.SynchronizerOneShot
         generic map (
            TPD_G => TPD_G)
         port map (
            clk     => srpClk,
            rst     => srpRst,
            dataIn  => sCtrl.overflow,
            dataOut => rxCtrl.overflow);
   end generate;

   comb : process (r, rxCtrl, rxMaster, srpAck, srpRdMasterInt, srpRst, srpWrSlaveInt, txSlave) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Set AxiStream defaults
      v.rxSlave := AXI_STREAM_SLAVE_INIT_C;

      if txSlave.tReady = '1' then
         v.txMaster.tValid := '0';
         v.txMaster.tLast  := '0';
         v.txMaster.tUser  := (others => '0');
      end if;

      v.srpRdSlave := AXI_STREAM_SLAVE_INIT_C;

      if (srpWrSlaveInt.tReady = '1') then
         v.srpWrMaster.tValid := '0';
         v.txMaster.tLast     := '0';
         v.txMaster.tUser     := (others => '0');
      end if;

      -- Timer is freerunning
      -- Reset to 0 when TIMEOUT_C reached
      if r.timer = TIMEOUT_C then
         v.timer := 0;
      else
         v.timer := r.timer + 1;
      end if;

      -- State Machine
      case r.state is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Reset error flags
            v.memResp     := (others => '0');
            v.timeout     := '0';
            v.eofe        := '0';
            v.frameError  := '0';
            v.verMismatch := '0';
            v.reqError    := '0';

            -- Reset SRP request
            v.srpReq := SRPV3_REQ_INIT_C;

            -- Reset other state registers
            v.timeoutSize := (others => '0');
            v.txnCnt      := (others => '0');
            v.hdrCnt      := (others => '0');

            -- Check for overflow
            if rxCtrl.overflow = '1' then
               v.state := BLOWOFF_RX_S;

            -- Check for extra read data (possibly from previous interrupted txn)
            elsif (srpRdMasterInt.tValid = '1') then
               v.state := BLOWOFF_READ_DATA_S;

            -- Check for valid data
            elsif rxMaster.tValid = '1' then
               -- Check for SOF
               if (ssiGetUserSof(SRP_AXIS_CONFIG_C, rxMaster) = '1') then
                  -- Ok to start processing the header
                  v.state := HDR_REQ_S;
               else
                  -- Blowoff any RX data if no SOF
                  v.state := BLOWOFF_RX_S;
               end if;
            end if;

         ----------------------------------------------------------------------
         when BLOWOFF_RX_S =>
            -- Dump rx data until tLast seen
            v.rxSlave.tReady := '1';
            if rxMaster.tValid = '1' and rxMaster.tLast = '1' then
               v.state := IDLE_S;
            end if;

         ----------------------------------------------------------------------
         when BLOWOFF_READ_DATA_S =>
            -- Dump read data until tLast seen
            v.srpRdSlave.tReady := '1';
            if srpRdMasterInt.tValid = '1' and srpRdMasterInt.tLast = '1' then
               v.state := IDLE_S;
            end if;

         ----------------------------------------------------------------------
         when HDR_REQ_S =>
            -- Check for valid data
            if rxMaster.tValid = '1' then
               -- Accept the data
               v.rxSlave.tReady := '1';

               -- Increment the header count
               v.hdrCnt := r.hdrCnt + 1;


               -- Check for tLast or EOFE
               if rxMaster.tLast = '1' then
                  -- Set the flags
                  v.frameError := '1';
                  -- Next State
                  v.state      := HDR_RESP_S;
               end if;

               -- Latch the request header fields based on which header word we're on
               case r.hdrCnt is
                  when X"0" =>
                     v.txMaster.tDest := rxMaster.tDest;
                     v.srpReq.remVer  := rxMaster.tData(7 downto 0);
                     v.srpReq.opCode  := rxMaster.tData(9 downto 8);
                     v.srpReq.spare   := rxMaster.tData(23 downto 10);
                     v.timeoutSize    := rxMaster.tData(31 downto 24);
                  when X"1" =>
                     v.srpReq.tid(31 downto 0) := rxMaster.tData(31 downto 0);
                  when X"2" =>
                     v.srpReq.addr(31 downto 0) := rxMaster.tData(31 downto 0);
                  when X"3" =>
                     v.srpReq.addr(63 downto 32) := rxMaster.tData(31 downto 0);
                  when X"4" =>
                     v.srpReq.reqSize(31 downto 0) := rxMaster.tData(31 downto 0);

                     -- Reset frame error that might have been assigned above due to tLast
                     -- We expect tLast here
                     v.frameError := '0';
                     -- Check for no tLast
                     if (rxMaster.tLast = '0') then
                        -- Check for OP-codes that should have tLast
                        if (r.srpReq.opCode = SRP_NULL_C) or (r.srpReq.opCode = SRP_READ_C) then
                           -- Set the flags
                           v.frameError := '1';
                        end if;
                     else
                        -- Check for OP-codes that should NOT have tLast
                        if (r.srpReq.opCode = SRP_POSTED_WRITE_C) or (r.srpReq.opCode = SRP_WRITE_C) then
                           -- Set the flags
                           v.frameError := '1';
                        end if;
                     end if;
                     -- Next State
                     v.hdrCnt := (others => '0');
                     v.state  := HDR_RESP_S;

                  when others => null;
               end case;

            end if;

         ----------------------------------------------------------------------
         when HDR_RESP_S =>
            -- Check if ready to move data
            if (v.txMaster.tValid = '0') then
               -- Check for posted write
               if r.srpReq.opCode /= SRP_POSTED_WRITE_C then
                  -- Set the flag
                  v.txMaster.tValid := '1';
               end if;
               -- Increment the counter
               v.hdrCnt := r.hdrCnt + 1;
               -- Check the counter
               case (r.hdrCnt) is
                  when x"0" =>
                     -- Set SOF
                     ssiSetUserSof(SRP_AXIS_CONFIG_C, v.txMaster, '1');
                     -- Set data bus
                     v.txMaster.tData(7 downto 0)   := SRP_VERSION_C;
                     v.txMaster.tData(9 downto 8)   := r.srpReq.opCode;
                     v.txMaster.tData(23 downto 10) := r.srpReq.spare;
                     v.txMaster.tData(31 downto 24) := r.timeoutSize;
                  when x"1" =>
                     v.txMaster.tData(31 downto 0) := r.srpReq.tid(31 downto 0);
                  when x"2" =>
                     v.txMaster.tData(31 downto 0) := r.srpReq.addr(31 downto 0);
                  when x"3" =>
                     v.txMaster.tData(31 downto 0) := r.srpReq.addr(63 downto 32);
                  when others =>
                     v.txMaster.tData(31 downto 0) := r.srpReq.reqSize(31 downto 0);
                     -- Reset the counter
                     v.hdrCnt                      := x"0";
                     -- Check for NULL
                     if r.srpReq.opCode = SRP_NULL_C then
                        -- Next State
                        v.state := FOOTER_S;
                     end if;

                     -- Check for framing error or EOFE
                     if (r.frameError = '1') or (r.eofe = '1') then
                        -- Next State
                        v.state := FOOTER_S;
                     end if;
                     -- Check for version mismatch
                     if r.srpReq.remVer /= SRP_VERSION_C then
                        -- Set the flags
                        v.verMismatch := '1';
                        -- Next State
                        v.state       := FOOTER_S;
                     end if;
                     -- Check for invalid reqSize with respect to writes
                     if ((r.srpReq.opCode = SRP_WRITE_C) or (r.srpReq.opCode = SRP_POSTED_WRITE_C)) and
                        (r.srpReq.reqSize(31 downto 12) /= 0) then
                        -- Set the flags
                        v.reqError := '1';
                        -- Next State
                        v.state    := FOOTER_S;
                     end if;

                     -- Need to double check all the cases here
                     -- Check for non 32-bit transaction request
                     if (r.srpReq.opCode /= SRP_NULL_C) then
                        if BYTE_ACCESS_G = false and r.srpReq.reqSize(1 downto 0) /= "11" then
                           v.reqError := '1';
                           v.state    := FOOTER_S;
                        end if;

                        -- Check for non 32-bit address alignment                     
                        if BYTE_ACCESS_G = false and UNALIGNED_ACCESS_G = false and r.srpReq.addr(1 downto 0) /= 0 then
                           v.reqError := '1';
                           v.state    := FOOTER_S;
                        end if;

                        -- Check that request op is enabled
                        if (READ_EN_G = false and r.srpReq.opCode = SRP_READ_C) then
                           v.reqError := '1';
                           v.state    := FOOTER_S;
                        end if;

                        if (WRITE_EN_G = false and (r.srpReq.opCode = SRP_WRITE_C or r.srpReq.opCode = SRP_POSTED_WRITE_C)) then
                           v.reqError := '1';
                           v.state    := FOOTER_S;
                        end if;
                     end if;

                     -------------------------------------------------------------------------------

                     -- If no error found above, procede with read or write request
                     if (v.state /= FOOTER_S) then
                        -- Issue an SRP request
                        v.srpReq.request := '1';

                        -- Reset the timer
                        v.timer      := 0;
                        v.timeoutCnt := (others => '0');

                        -- Check for read
                        if r.srpReq.opCode = SRP_READ_C then
                           v.state := READ_S;

                        -- Check for write
                        elsif (r.srpReq.opCode = SRP_WRITE_C or r.srpReq.opCode = SRP_POSTED_WRITE_C) then
                           v.state := WRITE_S;

                        else
                           -- Redundant null check but more opcodes could be added later
                           v.state := FOOTER_S;
                        end if;
                     end if;
               end case;
            end if;


         ----------------------------------------------------------------------
         when READ_S =>
            -- Send read data through to txMaster
            if (srpRdMasterInt.tValid = '1' and v.txMaster.tValid = '0') then
               v.srpRdSlave.tReady := '1';
               v.txMaster.tValid   := '1';

               -- Zero out data segments where tkeep not set
               -- There must be a more elegant way to do this
               for i in 3 downto 0 loop
                  if (srpRdMasterInt.tKeep(i) = '1') then
                     v.txMaster.tData((i+1)*8-1 downto i*8) := srpRdMasterInt.tData((i+1)*8-1 downto i*8);
                  else
                     v.txMaster.tData((i+1)*8-1 downto i*8) := (others => '0');
                  end if;
               end loop;


               -- Count each txn
               -- If tLast before cntSize, eofe
               -- if cntSize reached and no tlast, blead read data, eofe
               v.txnCnt := r.txnCnt + 1;
               if r.txnCnt = r.srpReq.reqSize(31 downto 2) and srpRdMasterInt.tLast = '1' then
                  -- Done when reqSize and tlast
                  v.state := WAIT_ACK_S;
               elsif (srpRdMasterInt.tLast = '1') then
                  -- tLast too early
                  v.state := WAIT_ACK_S;
                  v.eofe  := '1';       -- Should assign a memResp bit
               elsif (r.txnCnt = r.srpReq.reqSize(31 downto 2)) then
                  -- No tLast when expected
                  v.state := FOOTER_S;
                  v.eofe  := '1';       -- Should assign a memResp bit
               end if;
            end if;


            -- Check if timer enabled
            if r.timeoutSize /= 0 then
               -- Check 100 ms timer
               if r.timer = TIMEOUT_C then
                  -- Increment counter
                  v.timeoutCnt := r.timeoutCnt + 1;
                  -- Check the counter
                  if v.timeoutCnt = r.timeoutSize then
                     -- Set the flags
                     v.timeout := '1';
                     -- Next State
                     v.state   := FOOTER_S;
                  end if;
               end if;
            end if;

         ----------------------------------------------------------------------
         when WRITE_S =>
            -- Check for valid data and both tx and srpWr ready
            if (rxMaster.tValid = '1') and (v.txMaster.tValid = '0') and (v.srpWrMaster.tValid = '0')then
               -- Accept the data
               v.rxSlave.tReady := '1';

               -- Echo the write data back, but not if posted write
               v.txMaster.tValid             := toSl(r.srpReq.opCode /= SRP_POSTED_WRITE_C);
               v.txMaster.tData(31 downto 0) := rxMaster.tData(31 downto 0);

               -- Set the write data bus
               v.srpWrMaster.tValid             := '1';
               v.srpWrMaster.tData(31 downto 0) := rxMaster.tData(31 downto 0);
               v.srpWrMaster.tLast              := rxMaster.tLast;

               -- Set tkeep for last data word as it may not be a full word
               if (rxMaster.tLast = '1') then
                  v.srpWrMaster.tKeep := genTKeep(conv_integer(r.srpReq.reqSize(1 downto 0))+1);
               else
                  v.srpWrMaster.tKeep := genTKeep(4);
               end if;

               -- Count each txn
               -- If tLast before cntSize, frameError
               -- if cntSize reached and no tlast, blead write data, frame error
               v.txnCnt := r.txnCnt + 1;
               if r.txnCnt = r.srpReq.reqSize(31 downto 2) and rxMaster.tLast = '1' then
                  -- Done when reqSize reached and tlast
                  v.state := WAIT_ACK_S;
               elsif (r.txnCnt = r.srpReq.reqSize(31 downto 2) or rxMaster.tLast = '1') then
                  -- tLast too early or too late
                  -- Extra rxData will get blown off once IDLE_S state is reached
                  -- Due to missing SOF
                  v.state      := WAIT_ACK_S;
                  v.frameError := '1';
               end if;
            end if;


            -- Check if timer enabled
            if r.timeoutSize /= 0 then
               -- Check 100 ms timer
               if r.timer = TIMEOUT_C then
                  -- Increment counter
                  v.timeoutCnt := r.timeoutCnt + 1;
                  -- Check the counter
                  if v.timeoutCnt = r.timeoutSize then
                     -- Set the flags
                     v.timeout := '1';
                     -- Next State
                     v.state   := FOOTER_S;
                  end if;
               end if;
            end if;


         ----------------------------------------------------------------------
         when WAIT_ACK_S =>
            -- Wait for final ack from downstream
            if (srpAck.done = '1') then
               v.srpReq.request := '0';
               v.memResp        := srpAck.respCode;
            end if;

            -- Wait until both request and ack.done release before proceeding to footer
            if (r.srpReq.request = '0' and srpAck.done = '0') then
               v.state := FOOTER_S;
            end if;

            -- Check if timer enabled
            if r.timeoutSize /= 0 then
               -- Check 100 ms timer
               if r.timer = TIMEOUT_C then
                  -- Increment counter
                  v.timeoutCnt := r.timeoutCnt + 1;
                  -- Check the counter
                  if v.timeoutCnt = r.timeoutSize then
                     -- Set the flags
                     v.timeout := '1';
                     -- Next State
                     v.state   := FOOTER_S;
                  end if;
               end if;
            end if;

         ----------------------------------------------------------------------
         when FOOTER_S =>
            -- Might have arrived here after timeout with request still pending
            -- Release them now
            v.srpReq.request := '0';

            -- Check if ready to move data
            if (v.txMaster.tValid = '0') then
               -- Check for posted write
               if r.srpReq.opCode /= SRP_POSTED_WRITE_C then
                  -- Set the flags
                  v.txMaster.tValid := '1';
               end if;
               -- Set the footer data
               v.txMaster.tLast               := '1';
               v.txMaster.tData(7 downto 0)   := r.memResp;
               v.txMaster.tData(8)            := r.timeout;
               v.txMaster.tData(9)            := r.eofe;
               v.txMaster.tData(10)           := r.frameError;
               v.txMaster.tData(11)           := r.verMismatch;
               v.txMaster.tData(12)           := r.reqError;
               v.txMaster.tData(31 downto 13) := (others => '0');
               -- Next state
               v.state                        := IDLE_S;
            end if;

      end case;

      -- Update the EOFE flag
      if (rxMaster.tLast = '1') and (v.rxSlave.tReady = '1') then
         v.eofe := ssiGetUserEofe(SRP_AXIS_CONFIG_C, rxMaster);
      end if;

      -- Reset
      if (srpRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs    
      rxSlave        <= v.rxSlave;
      srpReq         <= r.srpReq;
      srpRdSlaveInt  <= v.srpRdSlave;
      srpWrMasterInt <= r.srpWrMaster;

   end process comb;

   seq : process (srpClk) is
   begin
      if (rising_edge(srpClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   TX_FIFO : entity work.AxiStreamFifoV2
      generic map (
         -- General Configurations
         TPD_G               => TPD_G,
         PIPE_STAGES_G       => PIPE_STAGES_G,
         SLAVE_READY_EN_G    => true,
         VALID_THOLD_G       => 1,
         -- FIFO configurations
         BRAM_EN_G           => true,
         XIL_DEVICE_G        => "7SERIES",
         USE_BUILT_IN_G      => false,
         GEN_SYNC_FIFO_G     => GEN_SYNC_FIFO_G,
         ALTERA_SYN_G        => ALTERA_SYN_G,
         ALTERA_RAM_G        => ALTERA_RAM_G,
         CASCADE_SIZE_G      => 1,
         FIFO_ADDR_WIDTH_G   => 9,
         -- AXI Stream Port Configurations
         SLAVE_AXI_CONFIG_G  => SRP_AXIS_CONFIG_C,
         MASTER_AXI_CONFIG_G => AXI_STREAM_CONFIG_G)
      port map (
         -- Slave Port
         sAxisClk    => srpClk,
         sAxisRst    => srpRst,
         sAxisMaster => r.txMaster,
         sAxisSlave  => txSlave,
         -- Master Port
         mAxisClk    => mAxisClk,
         mAxisRst    => mAxisRst,
         mAxisMaster => mAxisMaster,
         mAxisSlave  => mAxisSlave);

   -- Pipeline the rdData and wrData streams
   U_AxiStreamPipeline_rdData : entity work.AxiStreamPipeline
      generic map (
         TPD_G         => TPD_G,
         PIPE_STAGES_G => 0)
      port map (
         axisClk     => srpClk,          -- [in]
         axisRst     => srpRst,          -- [in]
         sAxisMaster => srpRdMaster,     -- [in]
         sAxisSlave  => srpRdSlave,      -- [out]
         mAxisMaster => srpRdMasterInt,  -- [out]
         mAxisSlave  => srpRdSlaveInt);  -- [in]

   U_AxiStreamPipeline_wrData : entity work.AxiStreamPipeline
      generic map (
         TPD_G         => TPD_G,
         PIPE_STAGES_G => 0)
      port map (
         axisClk     => srpClk,          -- [in]
         axisRst     => srpRst,          -- [in]
         sAxisMaster => srpWrMasterInt,  -- [in]
         sAxisSlave  => srpWrSlaveInt,   -- [out]
         mAxisMaster => srpWrMaster,     -- [out]
         mAxisSlave  => srpWrSlave);     -- [in]

end rtl;
