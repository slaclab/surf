-------------------------------------------------------------------------------
-- Title      : SRPv3 Protocol: https://confluence.slac.stanford.edu/x/cRmVD
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: SLAC Register Protocol Version 3, AXI-Lite Interface
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


library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;
use surf.SsiPkg.all;
use surf.AxiLitePkg.all;
use ieee.math_real.all;

entity SrpV3AxiLite is
   generic (
      TPD_G                 : time                    := 1 ns;
      INT_PIPE_STAGES_G     : natural range 0 to 16   := 1;
      PIPE_STAGES_G         : natural range 0 to 16   := 1;
      FIFO_PAUSE_THRESH_G   : positive range 1 to 511 := 256;
      FIFO_SYNTH_MODE_G     : string                  := "inferred";
      FIFO_ADDR_WIDTH_G     : integer range 9 to 48   := 9;  -- Need at least 9 to avoid logjams on large txns
      TX_VALID_THOLD_G      : positive range 1 to 511 := 500;  -- >1 = only when frame ready or # entries
      TX_VALID_BURST_MODE_G : boolean                 := true;       -- only used in VALID_THOLD_G>1
      SLAVE_READY_EN_G      : boolean                 := false;
      GEN_SYNC_FIFO_G       : boolean                 := false;
      ENABLE_TIMER_G        : boolean                 := true;
      AXIL_CLK_FREQ_G       : real                    := 156.25E+6;  -- units of Hz
      AXI_STREAM_CONFIG_G   : AxiStreamConfigType);
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
      prot             : slv(2 downto 0);
      timeoutSize      : slv(7 downto 0);
      timeoutCnt       : slv(7 downto 0);
      tid              : slv(31 downto 0);
      tidDly           : slv(31 downto 0);  -- simulation debug only
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
      rxRst            : sl;
      overflowDet      : sl;
      skip             : sl;                -- simulation debug only
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
      prot             => (others => '0'),
      timeoutSize      => (others => '0'),
      timeoutCnt       => (others => '0'),
      tid              => (others => '0'),
      tidDly           => (others => '1'),
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
      rxRst            => '1',
      overflowDet      => '0',
      skip             => '0',
      mAxilWriteMaster => AXI_LITE_WRITE_MASTER_INIT_C,
      mAxilReadMaster  => AXI_LITE_READ_MASTER_INIT_C,
      rxSlave          => AXI_STREAM_SLAVE_INIT_C,
      txMaster         => AXI_STREAM_MASTER_INIT_C,
      state            => IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal axisMaster : AxiStreamMasterType;
   signal axisSlave  : AxiStreamSlaveType;

   signal sCtrl : AxiStreamCtrlType;

   signal rxMaster     : AxiStreamMasterType;
   signal rxSlave      : AxiStreamSlaveType;
   signal rxCtrl       : AxiStreamCtrlType;
   signal rxTLastTUser : slv(7 downto 0);
   signal txSlave      : AxiStreamSlaveType;
   signal sAxisRxRst   : sl;
   signal sRstTmp      : sl;
   signal sRst         : sl;
--    signal rxRstTmp     : sl;
--    signal rxRst        : sl;

   -- attribute dont_touch                 : string;
   -- attribute dont_touch of r            : signal is "TRUE";
   -- attribute dont_touch of axisMaster   : signal is "TRUE";
   -- attribute dont_touch of axisSlave    : signal is "TRUE";
   -- attribute dont_touch of sCtrl        : signal is "TRUE";
   -- attribute dont_touch of rxMaster     : signal is "TRUE";
   -- attribute dont_touch of rxSlave      : signal is "TRUE";
   -- attribute dont_touch of rxCtrl       : signal is "TRUE";
   -- attribute dont_touch of rxTLastTUser : signal is "TRUE";
   -- attribute dont_touch of txSlave      : signal is "TRUE";
   -- attribute dont_touch of rst          : signal is "TRUE";
   -- attribute dont_touch of sRst         : signal is "TRUE";
   -- attribute dont_touch of rxRst        : signal is "TRUE";

begin

   sAxisCtrl <= sCtrl;

--    Sync_Rst_2 : entity surf.RstSync
--       generic map (
--          TPD_G => TPD_G)
--       port map (
--          clk      => axilClk,
--          asyncRst => rxRstTmp,
--          syncRst  => rxRst);


   U_Limiter : entity surf.SsiFrameLimiter
      generic map (
         TPD_G               => TPD_G,
         EN_TIMEOUT_G        => false,
         FRAME_LIMIT_G       => integer(ceil(4116.0/real(AXI_STREAM_CONFIG_G.TDATA_BYTES_C))),  -- (20B HDR + 4096B payload)/TDATA_BYTES_C
         COMMON_CLK_G        => true,
         SLAVE_FIFO_G        => false,
         MASTER_FIFO_G       => false,
         SLAVE_READY_EN_G    => SLAVE_READY_EN_G,
         SLAVE_AXI_CONFIG_G  => AXI_STREAM_CONFIG_G,
         MASTER_AXI_CONFIG_G => AXI_STREAM_CONFIG_G)
      port map (
         -- Slave Port
         sAxisClk    => sAxisClk,
         sAxisRst    => sRst,
         sAxisMaster => sAxisMaster,
         sAxisSlave  => sAxisSlave,
         -- Master Port
         mAxisClk    => sAxisClk,
         mAxisRst    => sRst,
         mAxisMaster => axisMaster,
         mAxisSlave  => axisSlave);

   RX_FIFO : entity surf.AxiStreamFifoV2
      generic map (
         -- General Configurations
         TPD_G               => TPD_G,
         INT_PIPE_STAGES_G   => INT_PIPE_STAGES_G,
         PIPE_STAGES_G       => PIPE_STAGES_G,
         SLAVE_READY_EN_G    => SLAVE_READY_EN_G,
         VALID_THOLD_G       => 0,                  -- = 0 = only when frame ready
         -- FIFO configurations
         SYNTH_MODE_G        => FIFO_SYNTH_MODE_G,
         MEMORY_TYPE_G       => "block",
         GEN_SYNC_FIFO_G     => GEN_SYNC_FIFO_G,
         INT_WIDTH_SELECT_G  => "CUSTOM",
         INT_DATA_WIDTH_G    => 16,                 -- 128-bit
         FIFO_ADDR_WIDTH_G   => FIFO_ADDR_WIDTH_G,  -- 8kB/FIFO = 128-bits x 512 entries
         FIFO_FIXED_THRESH_G => true,
         FIFO_PAUSE_THRESH_G => FIFO_PAUSE_THRESH_G,
         -- AXI Stream Port Configurations
         SLAVE_AXI_CONFIG_G  => AXI_STREAM_CONFIG_G,
         MASTER_AXI_CONFIG_G => AXIS_CONFIG_C)
      port map (
         -- Slave Port
         sAxisClk    => sAxisClk,
         sAxisRst    => sRst,
         sAxisMaster => axisMaster,
         sAxisSlave  => axisSlave,
         sAxisCtrl   => sCtrl,
         -- Master Port
         mAxisClk    => axilClk,
         mAxisRst    => r.rxRst,
         mAxisMaster => rxMaster,
         mAxisSlave  => rxSlave,
         mTLastTUser => rxTLastTUser);

   GEN_SYNC_SLAVE : if (GEN_SYNC_FIFO_G = true) generate
      rxCtrl     <= sCtrl;
      sAxisRxRst <= r.rxRst;
   end generate;

   GEN_ASYNC_SLAVE : if (GEN_SYNC_FIFO_G = false) generate
      Sync_Ctrl : entity surf.SynchronizerVector
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
      Sync_Overflow : entity surf.SynchronizerOneShot
         generic map (
            TPD_G => TPD_G)
         port map (
            clk     => axilClk,
            rst     => axilRst,
            dataIn  => sCtrl.overflow,
            dataOut => rxCtrl.overflow);
      Sync_Rst : entity surf.RstSync
         generic map (
            TPD_G => TPD_G)
         port map (
            clk      => sAxisClk,
            asyncRst => r.rxRst,
            syncRst  => sAxisRxRst);
   end generate;

   sRstTmp <= sAxisRxRst or sAxisRst;

   Sync_Rst_1 : entity surf.RstSync
      generic map (
         TPD_G => TPD_G)
      port map (
         clk      => sAxisClk,
         asyncRst => sRstTmp,
         syncRst  => sRst);


   comb : process (axilRst, mAxilReadSlave, mAxilWriteSlave, r, rxCtrl,
                   rxMaster, rxTLastTUser, txSlave) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Reset the flags
      v.rxRst   := '0';
      v.skip    := '0';
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

      -- Check for overflow
      if (rxCtrl.overflow = '1') and (r.rxRst = '0') and (SLAVE_READY_EN_G = false) then
         -- Set the flag
         v.overflowDet := '1';
      end if;

      -- State Machine
      case r.state is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Reset error flags
            v.memResp                  := (others => '0');
            --v.timeout                  := '0'; <--- if timeout ever happens then latch the timeout (don't reset) to inform SW that "hardware bus lock"
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
            if r.overflowDet = '1' then
               -- Reset the flag
               v.overflowDet := '0';
               -- Reset the FIFO
               v.rxRst       := '1';
            -- Check for valid data
            elsif (rxMaster.tValid = '1') and (r.rxRst = '0') then
               -- Accept the data
               v.rxSlave.tReady := '1';
               -- Check for SOF and no EOFE
               if (ssiGetUserSof(AXIS_CONFIG_C, rxMaster) = '1') and (rxTLastTUser(SSI_EOFE_C) = '0') then
                  -- Latch the AXIS TDEST
                  v.txMaster.tDest := rxMaster.tDest;
                  -- Latch the header information
                  v.remVer         := rxMaster.tData(7 downto 0);
                  v.opCode         := rxMaster.tData(9 downto 8);
                  v.ignoreMemResp  := rxMaster.tData(14);
                  v.prot           := rxMaster.tData(23 downto 21);
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
               end if;
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
                     v.txMaster.tData(20 downto 15) := (others => '0');  -- Reserved
                     v.txMaster.tData(23 downto 21) := r.prot;
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
                     -- Check for framing error or EOFE or timeout (A.K.A. "hardware bus lock")
                     if (r.frameError = '1') or (r.eofe = '1') or (r.timeout = '1') then
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
               v.txMaster.tData(13)           := r.timeout;
               v.txMaster.tData(31 downto 14) := (others => '0');
               -- Debugging code for chipscope
               v.tidDly                       := r.tid;
               if ((r.tidDly + 1) /= r.tid) then
                  v.skip := '1';
               end if;
               -- Next state
               v.state := IDLE_S;
            end if;
         ----------------------------------------------------------------------
         when AXIL_RD_REQ_S =>
            -- Check if ready to move data
            if (v.txMaster.tValid = '0') then
               -- Set the read address buses
               v.mAxilReadMaster.araddr  := r.addr(31 downto 0);
               -- Start AXI-Lite transaction
               v.mAxilReadMaster.arvalid := '1';
               v.mAxilReadMaster.rready  := '1';
               -- Update the Protection control
               v.mAxilReadMaster.arprot  := r.prot;
               -- Reset the timer
               v.timer                   := 0;
               v.timeoutCnt              := (others => '0');
               -- Next state
               v.state                   := AXIL_RD_RESP_S;
            end if;
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
            if (r.timeoutSize /= 0) and ENABLE_TIMER_G then
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
                  -- Update the Protection control
                  v.mAxilWriteMaster.awprot     := r.prot;
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
            if (r.timeoutSize /= 0) and ENABLE_TIMER_G then
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

      -- Combinatorial outputs before the reset
      rxSlave <= v.rxSlave;

      -- Reset
      if (axilRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Registered Outputs
      mAxilWriteMaster <= r.mAxilWriteMaster;
      mAxilReadMaster  <= r.mAxilReadMaster;
--      rxRstTmp         <= r.rxRst or axilRst;

   end process comb;

   seq : process (axilClk) is
   begin
      if (rising_edge(axilClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   TX_FIFO : entity surf.AxiStreamFifoV2
      generic map (
         -- General Configurations
         TPD_G               => TPD_G,
         INT_PIPE_STAGES_G   => INT_PIPE_STAGES_G,
         PIPE_STAGES_G       => PIPE_STAGES_G,
         SLAVE_READY_EN_G    => true,
         VALID_THOLD_G       => TX_VALID_THOLD_G,
         VALID_BURST_MODE_G  => TX_VALID_BURST_MODE_G,
         -- FIFO configurations
         SYNTH_MODE_G        => FIFO_SYNTH_MODE_G,
         MEMORY_TYPE_G       => "block",
         GEN_SYNC_FIFO_G     => GEN_SYNC_FIFO_G,
         INT_WIDTH_SELECT_G  => "CUSTOM",
         INT_DATA_WIDTH_G    => 16,                 -- 128-bit
         FIFO_ADDR_WIDTH_G   => FIFO_ADDR_WIDTH_G,  -- 8kB/FIFO = 128-bits x 512 entries
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
