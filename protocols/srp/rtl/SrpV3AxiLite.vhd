-------------------------------------------------------------------------------
-- File       : SrpV3AxiLite.vhd
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

entity SrpV3AxiLite is
   generic (
      TPD_G               : time                    := 1 ns;
      PIPE_STAGES_G       : natural range 0 to 16   := 0;
      FIFO_PAUSE_THRESH_G : positive range 1 to 511 := 256;
      SLAVE_READY_EN_G    : boolean                 := false;
      GEN_SYNC_FIFO_G     : boolean                 := false;
      ALTERA_SYN_G        : boolean                 := false;
      ALTERA_RAM_G        : string                  := "M9K";
      AXIL_CLK_FREQ_G     : real                    := 156.25E+6;  -- units of Hz
      AXI_STREAM_CONFIG_G : AxiStreamConfigType     := ssiAxiStreamConfig(2));
   port (
      -- AXIS Slave Interface (sAxisClk domain) 
      sAxisClk         : in  sl;
      sAxisRst         : in  sl;
      sAxisMaster      : in  AxiStreamMasterType;
      sAxisSlave       : out AxiStreamSlaveType;
      sAxisCtrl        : out AxiStreamCtrlType;
      -- AXIS Master Interface (mAxisClk domain) 
      mAxisClk         : in  sl;
      mAxisRst         : in  sl;
      mAxisMaster      : out AxiStreamMasterType;
      mAxisSlave       : in  AxiStreamSlaveType;
      -- Master AXI-Lite Interface (axilClk domain)
      axilClk          : in  sl;
      axilRst          : in  sl;
      mAxilWriteMaster : out AxiLiteWriteMasterType;
      mAxilWriteSlave  : in  AxiLiteWriteSlaveType;
      mAxilReadMaster  : out AxiLiteReadMasterType;
      mAxilReadSlave   : in  AxiLiteReadSlaveType);
end SrpV3AxiLite;

architecture rtl of SrpV3AxiLite is

   constant AXIS_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(4, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 8);
   constant TIMEOUT_C     : natural             := (getTimeRatio(AXIL_CLK_FREQ_G, 10.0) - 1);  -- 100 ms timeout

   constant SRP_VERSION_C      : slv(7 downto 0) := x"03";
   constant NON_POSTED_READ_C  : slv(1 downto 0) := "00";
   constant NON_POSTED_WRITE_C : slv(1 downto 0) := "01";
   constant POSTED_WRITE_C     : slv(1 downto 0) := "10";
   constant NULL_C             : slv(1 downto 0) := "11";
   
   type StateType is (
      IDLE_S,
      BLOWOFF_S,
      HDR_REQ0_S,
      HDR_REQ1_S,
      HDR_REQ2_S,
      HDR_REQ3_S,
      HDR_RESP_S,
      FOOTER_S,
      AXIL_RD_REQ_S,
      AXIL_RD_RESP_S,
      AXIL_WR_REQ_S,
      AXIL_WR_RESP_S);

   type RegType is record
      timer            : natural range 0 to TIMEOUT_C;
      hdrCnt           : slv(3 downto 0);
      remVer           : slv(7 downto 0);
      opCode           : slv(1 downto 0);
      timeoutSize      : slv(7 downto 0);
      timeoutCnt       : slv(7 downto 0);
      tid              : slv(31 downto 0);
      addr             : slv(63 downto 0);
      reqSize          : slv(31 downto 0);
      cnt              : slv(29 downto 0);
      cntSize          : slv(29 downto 0);
      memResp          : slv(7 downto 0);
      timeout          : sl;
      eofe             : sl;
      frameError       : sl;
      verMismatch      : sl;
      reqSizeError     : sl;
      ignoreMemResp    : sl;
      mAxilWriteMaster : AxiLiteWriteMasterType;
      mAxilReadMaster  : AxiLiteReadMasterType;
      rxSlave          : AxiStreamSlaveType;
      txMaster         : AxiStreamMasterType;
      state            : StateType;
   end record RegType;
   constant REG_INIT_C : RegType := (
      timer            => 0,
      hdrCnt           => (others => '0'),
      remVer           => (others => '0'),
      opCode           => (others => '0'),
      timeoutSize      => (others => '0'),
      timeoutCnt       => (others => '0'),
      tid              => (others => '0'),
      addr             => (others => '0'),
      reqSize          => (others => '0'),
      cnt              => (others => '0'),
      cntSize          => (others => '0'),
      memResp          => (others => '0'),
      timeout          => '0',
      eofe             => '0',
      frameError       => '0',
      verMismatch      => '0',
      reqSizeError     => '0',
      ignoreMemResp    => '0',
      mAxilWriteMaster => AXI_LITE_WRITE_MASTER_INIT_C,
      mAxilReadMaster  => AXI_LITE_READ_MASTER_INIT_C,
      rxSlave          => AXI_STREAM_SLAVE_INIT_C,
      txMaster         => AXI_STREAM_MASTER_INIT_C,
      state            => IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal sCtrl    : AxiStreamCtrlType;
   signal rxMaster : AxiStreamMasterType;
   signal rxSlave  : AxiStreamSlaveType;
   signal rxCtrl   : AxiStreamCtrlType;
   signal txSlave  : AxiStreamSlaveType;

   -- attribute dont_touch                    : string;
   -- attribute dont_touch of r               : signal is "TRUE";

begin

   sAxisCtrl <= sCtrl;

   RX_FIFO : entity work.SsiFifo
      generic map (
         -- General Configurations
         TPD_G               => TPD_G,
         EN_FRAME_FILTER_G   => true,
         PIPE_STAGES_G       => PIPE_STAGES_G,
         SLAVE_READY_EN_G    => SLAVE_READY_EN_G,
         VALID_THOLD_G       => 0,  -- = 0 = only when frame ready                                                                 
         -- FIFO configurations
         BRAM_EN_G           => true,
         XIL_DEVICE_G        => "7SERIES",
         USE_BUILT_IN_G      => false,
         GEN_SYNC_FIFO_G     => GEN_SYNC_FIFO_G,
         ALTERA_SYN_G        => ALTERA_SYN_G,
         ALTERA_RAM_G        => ALTERA_RAM_G,
         FIFO_ADDR_WIDTH_G   => 9,      -- 2kB/FIFO = 32-bits x 512 entries
         CASCADE_SIZE_G      => 3,      -- 6kB = 3 FIFOs x 2 kB/FIFO
         CASCADE_PAUSE_SEL_G => 2,      -- Set pause select on top FIFO
         FIFO_FIXED_THRESH_G => true,
         FIFO_PAUSE_THRESH_G => FIFO_PAUSE_THRESH_G,
         -- AXI Stream Port Configurations
         SLAVE_AXI_CONFIG_G  => AXI_STREAM_CONFIG_G,
         MASTER_AXI_CONFIG_G => AXIS_CONFIG_C)
      port map (
         -- Slave Port
         sAxisClk    => sAxisClk,
         sAxisRst    => sAxisRst,
         sAxisMaster => sAxisMaster,
         sAxisSlave  => sAxisSlave,
         sAxisCtrl   => sCtrl,
         -- Master Port
         mAxisClk    => axilClk,
         mAxisRst    => axilRst,
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
            clk        => axilClk,
            rst        => axilRst,
            dataIn(0)  => sCtrl.pause,
            dataIn(1)  => sCtrl.idle,
            dataOut(0) => rxCtrl.pause,
            dataOut(1) => rxCtrl.idle);   
      Sync_Overflow : entity work.SynchronizerOneShot
         generic map (
            TPD_G => TPD_G)
         port map (
            clk     => axilClk,
            rst     => axilRst,
            dataIn  => sCtrl.overflow,
            dataOut => rxCtrl.overflow);            
   end generate;

   comb : process (axilRst, mAxilReadSlave, mAxilWriteSlave, r, rxCtrl, rxMaster, txSlave) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Reset the flags    
      v.rxSlave := AXI_STREAM_SLAVE_INIT_C;
      if txSlave.tReady = '1' then
         v.txMaster.tValid := '0';
         v.txMaster.tLast  := '0';
         v.txMaster.tUser  := (others => '0');
      end if;

      -- Check the timer
      if r.timer = TIMEOUT_C then
         -- Reset the timer
         v.timer := 0;
      else
         -- Increment the timer
         v.timer := r.timer + 1;
      end if;

      -- State Machine
      case r.state is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Reset error flags
            v.memResp                  := (others => '0');
            v.timeout                  := '0';
            v.eofe                     := '0';
            v.frameError               := '0';
            v.verMismatch              := '0';
            v.reqSizeError             := '0';
            -- Reset all AXI-Lite flags
            v.mAxilReadMaster.arvalid  := '0';
            v.mAxilReadMaster.rready   := '0';
            v.mAxilWriteMaster.awvalid := '0';
            v.mAxilWriteMaster.wvalid  := '0';
            v.mAxilWriteMaster.bready  := '0';
            v.cnt                      := (others => '0');
            -- Check for overflow
            if rxCtrl.overflow = '1' then
               -- Next state
               v.state := BLOWOFF_S;
            -- Check for valid data
            elsif rxMaster.tValid = '1' then
               -- Check for SOF
               if (ssiGetUserSof(AXIS_CONFIG_C, rxMaster) = '1') then
                  -- Accept the data
                  v.rxSlave.tReady := '1';
                  -- Latch the AXIS TDEST
                  v.txMaster.tDest := rxMaster.tDest;
                  -- Latch the header information
                  v.remVer         := rxMaster.tData(7 downto 0);
                  v.opCode         := rxMaster.tData(9 downto 8);
                  v.ignoreMemResp  := rxMaster.tData(14);
                  v.timeoutSize    := rxMaster.tData(31 downto 24);
                  -- Reset other header fields
                  v.tid            := (others => '0');
                  v.addr           := (others => '0');
                  v.reqSize        := (others => '0');
                  -- Check for tLast
                  if (rxMaster.tLast = '1') then
                     -- Set the flags
                     v.frameError := '1';
                     -- Next State
                     v.state      := HDR_RESP_S;
                  else
                     -- Next State
                     v.state := HDR_REQ0_S;
                  end if;
               else
                  -- Next state
                  v.state := BLOWOFF_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when BLOWOFF_S =>
            -- Accept the data
            v.rxSlave.tReady := '1';
            -- Check for EOF
            if rxMaster.tLast = '1' then
               -- Next state
               v.state := IDLE_S;
            end if;
         ----------------------------------------------------------------------
         when HDR_REQ0_S =>
            -- Check for valid data
            if rxMaster.tValid = '1' then
               -- Accept the data
               v.rxSlave.tReady   := '1';
               -- Latch the request header field
               v.tid(31 downto 0) := rxMaster.tData(31 downto 0);
               -- Check for tLast
               if rxMaster.tLast = '1' then
                  -- Set the flags
                  v.frameError := '1';
                  -- Next State
                  v.state      := HDR_RESP_S;
               else
                  -- Next State
                  v.state := HDR_REQ1_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when HDR_REQ1_S =>
            -- Check for valid data
            if rxMaster.tValid = '1' then
               -- Accept the data
               v.rxSlave.tReady    := '1';
               -- Latch the request header field
               v.addr(31 downto 0) := rxMaster.tData(31 downto 0);
               -- Check for tLast
               if rxMaster.tLast = '1' then
                  -- Set the flags
                  v.frameError := '1';
                  -- Next State
                  v.state      := HDR_RESP_S;
               else
                  -- Next State
                  v.state := HDR_REQ2_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when HDR_REQ2_S =>
            -- Check for valid data
            if rxMaster.tValid = '1' then
               -- Accept the data
               v.rxSlave.tReady     := '1';
               -- Latch the request header field
               v.addr(63 downto 32) := rxMaster.tData(31 downto 0);
               -- Check for tLast
               if rxMaster.tLast = '1' then
                  -- Set the flags
                  v.frameError := '1';
                  -- Next State
                  v.state      := HDR_RESP_S;
               else
                  -- Next State
                  v.state := HDR_REQ3_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when HDR_REQ3_S =>
            -- Check for valid data
            if rxMaster.tValid = '1' then
               -- Accept the data
               v.rxSlave.tReady       := '1';
               -- Latch the request header field
               v.reqSize(31 downto 0) := rxMaster.tData(31 downto 0);
               -- Check for no tLast
               if (rxMaster.tLast = '0') then
                  -- Check for OP-codes that should have tLast
                  if (r.opCode = NULL_C) or (r.opCode = NON_POSTED_READ_C) then
                     -- Set the flags
                     v.frameError := '1';
                  end if;
               else
                  -- Check for OP-codes that should NOT have tLast
                  if (r.opCode = POSTED_WRITE_C) or (r.opCode = NON_POSTED_WRITE_C) then
                     -- Set the flags
                     v.frameError := '1';
                  end if;
               end if;
               -- Next State
               v.state := HDR_RESP_S;
            end if;
         ----------------------------------------------------------------------
         when HDR_RESP_S =>
            -- Check if ready to move data
            if (v.txMaster.tValid = '0') then
               -- Check for posted write
               if r.opCode /= POSTED_WRITE_C then
                  -- Set the flag
                  v.txMaster.tValid := '1';
               end if;
               -- Increment the counter
               v.hdrCnt := r.hdrCnt + 1;
               -- Check the counter
               case (r.hdrCnt) is
                  when x"0" =>
                     -- Set SOF
                     ssiSetUserSof(AXIS_CONFIG_C, v.txMaster, '1');
                     -- Set data bus
                     v.txMaster.tData(7 downto 0)   := SRP_VERSION_C;
                     v.txMaster.tData(9 downto 8)   := r.opCode;
                     v.txMaster.tData(10)           := '0';  -- UnalignedAccess: 0 = not supported (only 32-bit alignment)
                     v.txMaster.tData(11)           := '0';  -- MinAccessSize:   0 = 32-bit (4 byte) transactions only
                     v.txMaster.tData(12)           := '0';  -- WriteEn:         0 = write operations are not supported
                     v.txMaster.tData(13)           := '0';  -- ReadEn:          0 = read operations are not supported
                     v.txMaster.tData(14)           := r.ignoreMemResp;
                     v.txMaster.tData(23 downto 15) := (others => '0');  -- Reserved
                     v.txMaster.tData(31 downto 24) := r.timeoutSize;
                  when x"1" => v.txMaster.tData(31 downto 0) := r.tid(31 downto 0);
                  when x"2" => v.txMaster.tData(31 downto 0) := r.addr(31 downto 0);
                  when x"3" => v.txMaster.tData(31 downto 0) := r.addr(63 downto 32);
                  when others =>
                     v.txMaster.tData(31 downto 0) := r.reqSize(31 downto 0);
                     -- Reset the counter
                     v.hdrCnt                      := x"0";
                     -- Check for NULL
                     if r.opCode = NULL_C then
                        -- Next State
                        v.state := FOOTER_S;
                     end if;
                     -- Check for framing error or EOFE
                     if (r.frameError = '1') or (r.eofe = '1') then
                        -- Next State
                        v.state := FOOTER_S;
                     end if;
                     -- Check for version mismatch
                     if r.remVer /= SRP_VERSION_C then
                        -- Set the flags
                        v.verMismatch := '1';
                        -- Next State
                        v.state       := FOOTER_S;
                     end if;
                     -- Check for invalid reqSize with respect to writes
                     if ((r.opCode = NON_POSTED_WRITE_C) or (r.opCode = POSTED_WRITE_C)) and (r.reqSize(31 downto 12) /= 0) then
                        -- Set the flags
                        v.reqSizeError := '1';
                        -- Next State
                        v.state        := FOOTER_S;
                     end if;
                     -- Check for invalid address size (AXI-Lite only support 32-bit address space)
                     if (r.addr(63 downto 32) /= 0) then
                        -- Set the flags
                        v.memResp(7) := '1';
                        -- Next State
                        v.state      := FOOTER_S;
                     end if;
                     -- Check for non 32-bit address alignment
                     if r.addr(1 downto 0) /= 0 then
                        -- Set the flags
                        v.memResp(6) := '1';
                        -- Next State
                        v.state      := FOOTER_S;
                     end if;
                     -- Check for non 32-bit transaction request
                     if r.reqSize(1 downto 0) /= "11" then
                        -- Set the flags
                        v.memResp(5) := '1';
                        -- Next State
                        v.state      := FOOTER_S;
                     end if;
                     -- If no error or NULL found above, then proceed with read or write request
                     if (v.state /= FOOTER_S) then
                        -- Set the counter size
                        v.cntSize := r.reqSize(31 downto 2);
                        -- Check for read
                        if r.opCode = NON_POSTED_READ_C then
                           -- Next State
                           v.state := AXIL_RD_REQ_S;
                        -- Else it is a write
                        else
                           -- Next State
                           v.state := AXIL_WR_REQ_S;
                        end if;
                     end if;
               end case;
            end if;
         ----------------------------------------------------------------------
         when FOOTER_S =>
            -- Check if ready to move data
            if (v.txMaster.tValid = '0') then
               -- Check for posted write
               if r.opCode /= POSTED_WRITE_C then
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
               v.txMaster.tData(12)           := r.reqSizeError;
               v.txMaster.tData(31 downto 13) := (others => '0');
               -- Next state
               v.state                        := IDLE_S;
            end if;
         ----------------------------------------------------------------------
         when AXIL_RD_REQ_S =>
            -- Set the read address buses
            v.mAxilReadMaster.araddr  := r.addr(31 downto 0);
            -- Start AXI-Lite transaction
            v.mAxilReadMaster.arvalid := '1';
            v.mAxilReadMaster.rready  := '1';
            -- Reset the timer
            v.timer                   := 0;
            v.timeoutCnt              := (others => '0');
            -- Next state
            v.state                   := AXIL_RD_RESP_S;
         ----------------------------------------------------------------------
         when AXIL_RD_RESP_S =>
            -- Check if ready to move data
            if (v.txMaster.tValid = '0') then
               -- Check slave.arready flag
               if mAxilReadSlave.arready = '1' then
                  -- Reset the flag
                  v.mAxilReadMaster.arvalid := '0';
               end if;
               -- Check slave.rvalid flag
               if mAxilReadSlave.rvalid = '1' then
                  -- Reset the flag
                  v.mAxilReadMaster.rready := '0';
                  -- Latch the memory bus responds
                  if (r.ignoreMemResp = '0') then
                     v.memResp(1 downto 0) := mAxilReadSlave.rresp;
                  end if;
                  -- Check for a valid responds
                  if mAxilReadSlave.rresp = AXI_RESP_OK_C then
                     -- Move the data
                     v.txMaster.tValid             := '1';
                     v.txMaster.tData(31 downto 0) := mAxilReadSlave.rdata;
                  elsif (r.ignoreMemResp = '1') then
                     -- Move the data
                     v.txMaster.tValid             := '1';
                     v.txMaster.tData(31 downto 0) := (others => '1');
                  end if;
               end if;
               -- Check if transaction is done
               if (v.mAxilReadMaster.arvalid = '0') and (v.mAxilReadMaster.rready = '0') then
                  -- Check for memory bus error 
                  if v.memResp /= 0 then
                     -- Next State
                     v.state := FOOTER_S;
                  else
                     -- Increment the counter
                     v.cnt := r.cnt + 1;
                     -- Check the counter
                     if r.cnt = r.cntSize then
                        -- Next State
                        v.state := FOOTER_S;
                     else
                        -- Increment the address
                        v.addr(31 downto 2) := r.addr(31 downto 2) + 1;
                        -- Next state
                        v.state             := AXIL_RD_REQ_S;
                     end if;
                  end if;
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
         when AXIL_WR_REQ_S =>
            -- Check for valid data and ready to move data
            if (rxMaster.tValid = '1') and (v.txMaster.tValid = '0') then
               -- Accept the data
               v.rxSlave.tReady := '1';
               -- Check for framing error
               if (rxMaster.tLast = '1') and (r.cnt /= r.cntSize) then
                  -- Set the flags
                  v.frameError := '1';
                  -- Next State
                  v.state      := FOOTER_S;
               -- Check for framing error
               elsif (rxMaster.tLast = '0') and (r.cnt = r.cntSize) then
                  -- Set the flags
                  v.frameError := '1';
                  -- Next State
                  v.state      := FOOTER_S;
               else
                  -- Check for posted write
                  if r.opCode /= POSTED_WRITE_C then
                     -- Set the flags
                     v.txMaster.tValid := '1';
                  end if;
                  -- Echo the write data back
                  v.txMaster.tData(31 downto 0) := rxMaster.tData(31 downto 0);
                  -- Set the write address buses
                  v.mAxilWriteMaster.awaddr     := r.addr(31 downto 0);
                  -- Set the write data bus
                  v.mAxilWriteMaster.wdata      := rxMaster.tData(31 downto 0);
                  -- Start AXI-Lite transaction
                  v.mAxilWriteMaster.awvalid    := '1';
                  v.mAxilWriteMaster.wvalid     := '1';
                  v.mAxilWriteMaster.bready     := '1';
                  -- Reset the timer
                  v.timer                       := 0;
                  v.timeoutCnt                  := (others => '0');
                  -- Next state
                  v.state                       := AXIL_WR_RESP_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when AXIL_WR_RESP_S =>
            -- Check the slave.awready flag
            if mAxilWriteSlave.awready = '1' then
               -- Reset the flag
               v.mAxilWriteMaster.awvalid := '0';
            end if;
            -- Check the slave.wready flag
            if mAxilWriteSlave.wready = '1' then
               -- Reset the flag
               v.mAxilWriteMaster.wvalid := '0';
            end if;
            -- Check the slave.bvalid flag
            if mAxilWriteSlave.bvalid = '1' then
               -- Reset the flag
               v.mAxilWriteMaster.bready := '0';
               -- Latch the memory bus responds
               if (r.ignoreMemResp = '0') then
                  v.memResp(1 downto 0) := mAxilWriteSlave.bresp;
               end if;
            end if;
            -- Check if transaction is done
            if (v.mAxilWriteMaster.awvalid = '0') and(v.mAxilWriteMaster.wvalid = '0') and (v.mAxilWriteMaster.bready = '0') then
               -- Check for memory bus error 
               if v.memResp /= 0 then
                  -- Next State
                  v.state := FOOTER_S;
               else
                  -- Increment the counter
                  v.cnt := r.cnt + 1;
                  -- Check the counter
                  if r.cnt = r.cntSize then
                     -- Next State
                     v.state := FOOTER_S;
                  else
                     -- Increment the address
                     v.addr(31 downto 2) := r.addr(31 downto 2) + 1;
                     -- Next state
                     v.state             := AXIL_WR_REQ_S;
                  end if;
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
      end case;

      -- Update the EOFE flag
      if (rxMaster.tLast = '1') and (v.rxSlave.tReady = '1') then
         v.eofe := ssiGetUserEofe(AXIS_CONFIG_C, rxMaster);
      end if;

      -- Reset
      if (axilRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs    
      rxSlave          <= v.rxSlave;
      mAxilWriteMaster <= r.mAxilWriteMaster;
      mAxilReadMaster  <= r.mAxilReadMaster;

   end process comb;

   seq : process (axilClk) is
   begin
      if (rising_edge(axilClk)) then
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
         SLAVE_AXI_CONFIG_G  => AXIS_CONFIG_C,
         MASTER_AXI_CONFIG_G => AXI_STREAM_CONFIG_G)
      port map (
         -- Slave Port
         sAxisClk    => axilClk,
         sAxisRst    => axilRst,
         sAxisMaster => r.txMaster,
         sAxisSlave  => txSlave,
         -- Master Port
         mAxisClk    => mAxisClk,
         mAxisRst    => mAxisRst,
         mAxisMaster => mAxisMaster,
         mAxisSlave  => mAxisSlave);

end rtl;
