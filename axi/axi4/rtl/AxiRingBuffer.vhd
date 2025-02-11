-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Wrapper for simple AXI4 memory based ring buffer with AXI Stream interface
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
use surf.AxiPkg.all;
use surf.AxiStreamPkg.all;
use surf.AxiLitePkg.all;
use surf.SsiPkg.all;

entity AxiRingBuffer is
   generic (
      TPD_G                  : time                     := 1 ns;
      SYNTH_MODE_G           : string                   := "inferred";
      MEMORY_TYPE_G          : string                   := "block";
      -- Ring buffer Configurations
      DATA_BYTES_G           : positive                 := 8;  -- Units of bits
      RING_BUFF_ADDR_WIDTH_G : positive                 := 9;  -- Units of 2^(data words)
      -- AXI4 Configurations
      AXI_BASE_ADDR_G        : slv(63 downto 0)         := (others => '0');
      BURST_BYTES_G          : positive range 1 to 4096 := 4096;
      -- AXI Stream Configurations
      AXI_STREAM_CONFIG_G    : AxiStreamConfigType);
   port (
      -- Data to store in ring buffer (dataClk domain)
      dataClk         : in  sl;
      dataRst         : in  sl := '0';
      dataValid       : in  sl := '1';
      dataValue       : in  slv(8*DATA_BYTES_G-1 downto 0);
      extTrig         : in  sl := '0';
      -- AXI Ring Buffer Memory Interface (dataClk domain)
      mAxiWriteMaster : out AxiWriteMasterType;
      mAxiWriteSlave  : in  AxiWriteSlaveType;
      mAxiReadMaster  : out AxiReadMasterType;
      mAxiReadSlave   : in  AxiReadSlaveType;
      -- AXI-Lite Register Interface (axilClk domain)
      axilClk         : in  sl;
      axilRst         : in  sl;
      axilReadMaster  : in  AxiLiteReadMasterType;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType;
      axilWriteSlave  : out AxiLiteWriteSlaveType;
      -- AXI-Stream Result Interface (axisClk domain)
      axisClk         : in  sl;
      axisRst         : in  sl;
      axisMaster      : out AxiStreamMasterType;
      axisSlave       : in  AxiStreamSlaveType);
end entity AxiRingBuffer;

architecture rtl of AxiRingBuffer is

   constant DATA_BITSIZE_C  : positive := log2(DATA_BYTES_G);
   constant BURST_BITSIZE_C : positive := log2(BURST_BYTES_G);
   constant MEM_BITSIZE_C   : positive := RING_BUFF_ADDR_WIDTH_G+DATA_BITSIZE_C;

   subtype AXI_BURST_RANGE_C is integer range BURST_BITSIZE_C-1 downto 0;
   subtype AXI_BUF_RANGE_C is integer range MEM_BITSIZE_C-1 downto 0;

   constant AXI_CONFIG_C : AxiConfigType := (
      ADDR_WIDTH_C => 64,
      DATA_BYTES_C => DATA_BYTES_G,
      ID_BITS_C    => 1,
      LEN_BITS_C   => 8);

   constant AXI_WR_MST_INIT_C : AxiWriteMasterType := (
      awvalid  => '0',
      awaddr   => AXI_BASE_ADDR_G,
      awid     => (others => '0'),
      awlen    => getAxiLen(AXI_CONFIG_C, BURST_BYTES_G),
      awsize   => toSlv(DATA_BITSIZE_C, 3),
      awburst  => "01",
      awlock   => (others => '0'),
      awprot   => (others => '0'),
      awcache  => "0000",
      awqos    => (others => '0'),
      awregion => (others => '0'),
      wdata    => (others => '0'),
      wlast    => '0',
      wvalid   => '0',
      wid      => (others => '0'),
      wstrb    => (others => '1'),
      bready   => '1');

   constant AXI_RD_MST_INIT_C : AxiReadMasterType := (
      arvalid  => '0',
      araddr   => AXI_BASE_ADDR_G,
      arid     => (others => '0'),
      arlen    => getAxiLen(AXI_CONFIG_C, BURST_BYTES_G),
      arsize   => toSlv(DATA_BITSIZE_C, 3),
      arburst  => "01",
      arlock   => (others => '0'),
      arprot   => (others => '0'),
      arcache  => "0000",
      arqos    => (others => '0'),
      arregion => (others => '0'),
      rready   => '0');

   constant AXIS_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(
      dataBytes => DATA_BYTES_G,
      tKeepMode => TKEEP_FIXED_C,
      tUserMode => TUSER_FIRST_LAST_C,
      tDestBits => 0,
      tUserBits => 2,
      tIdBits   => 0);

   type StateType is (
      WR_AXI_S,
      WR_BRAM_S,
      RD_AXI_ADDR_S,
      RD_AXI_DATA_S,
      RD_BRAM_S);

   type RegType is record
      -- Monitor Signals
      cntRst         : sl;
      readoutCnt     : slv(31 downto 0);
      dropTrigCnt    : slv(7 downto 0);
      wrErrCnt       : slv(7 downto 0);
      -- Data/Trigger Signals
      dataValid      : sl;
      dataValue      : slv(8*DATA_BYTES_G-1 downto 0);
      extTrig        : sl;
      softTrig       : sl;
      continuousMode : sl;
      -- BRAM signals
      bramWe         : sl;
      bramWrCnt      : slv(BURST_BITSIZE_C-1 downto 0);
      bramAddr       : slv(BURST_BITSIZE_C-1 downto 0);
      bramWrDat      : slv(8*DATA_BYTES_G-1 downto 0);
      bramLat        : slv(1 downto 0);
      -- Ring buffer controls
      ready          : sl;
      armed          : sl;
      memIdx         : slv(AXI_BUF_RANGE_C);
      startIdx       : slv(AXI_BUF_RANGE_C);
      rdWrdCnt       : slv(RING_BUFF_ADDR_WIDTH_G-1 downto 0);
      wrdOffset      : slv(AXI_BURST_RANGE_C);
      -- AXI/State Signals
      axiWriteMaster : AxiWriteMasterType;
      mAxiReadMaster : AxiReadMasterType;
      txMaster       : AxiStreamMasterType;
      readSlave      : AxiLiteReadSlaveType;
      writeSlave     : AxiLiteWriteSlaveType;
      state          : StateType;
   end record RegType;
   constant REG_INIT_C : RegType := (
      -- Monitor Signals
      cntRst         => '0',
      readoutCnt     => (others => '0'),
      dropTrigCnt    => (others => '0'),
      wrErrCnt       => (others => '0'),
      -- Data/Trigger Signals
      dataValid      => '0',
      dataValue      => (others => '0'),
      extTrig        => '0',
      softTrig       => '0',
      continuousMode => '0',
      -- BRAM signals
      bramWe         => '0',
      bramWrCnt      => (others => '0'),
      bramAddr       => (others => '0'),
      bramWrDat      => (others => '0'),
      bramLat        => (others => '0'),
      -- Ring buffer controls
      ready          => '0',
      armed          => '0',
      memIdx         => (others => '0'),
      startIdx       => (others => '0'),
      rdWrdCnt       => (others => '0'),
      wrdOffset      => (others => '0'),
      -- AXI/State Signals
      axiWriteMaster => AXI_WR_MST_INIT_C,
      mAxiReadMaster => AXI_RD_MST_INIT_C,
      txMaster       => axiStreamMasterInit(AXIS_CONFIG_C),
      readSlave      => AXI_LITE_READ_SLAVE_INIT_C,
      writeSlave     => AXI_LITE_WRITE_SLAVE_INIT_C,
      state          => WR_AXI_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal axiWriteMaster : AxiWriteMasterType := AXI_WRITE_MASTER_INIT_C;
   signal axiWriteSlave  : AxiWriteSlaveType  := AXI_WRITE_SLAVE_INIT_C;

   signal readMaster  : AxiLiteReadMasterType;
   signal writeMaster : AxiLiteWriteMasterType;

   signal bramData : slv(8*DATA_BYTES_G-1 downto 0);

   signal txSlave : AxiStreamSlaveType;

begin

   assert (isPowerOf2(DATA_BYTES_G) = true)
      report "DATA_BYTES_G must be power of 2" severity failure;

   assert (isPowerOf2(BURST_BYTES_G) = true)
      report "BURST_BYTES_G must be power of 2" severity failure;

   U_AxiLiteAsync : entity surf.AxiLiteAsync
      generic map (
         TPD_G           => TPD_G,
         COMMON_CLK_G    => false,
         NUM_ADDR_BITS_G => 8)
      port map (
         -- Slave Interface
         sAxiClk         => axilClk,
         sAxiClkRst      => axilRst,
         sAxiReadMaster  => axilReadMaster,
         sAxiReadSlave   => axilReadSlave,
         sAxiWriteMaster => axilWriteMaster,
         sAxiWriteSlave  => axilWriteSlave,
         -- Master Interface
         mAxiClk         => dataClk,
         mAxiClkRst      => dataRst,
         mAxiReadMaster  => readMaster,
         mAxiReadSlave   => r.readSlave,
         mAxiWriteMaster => writeMaster,
         mAxiWriteSlave  => r.writeSlave);

   comb : process (axiWriteSlave, bramData, dataRst, dataValid, dataValue,
                   extTrig, mAxiReadSlave, r, readMaster, txSlave, writeMaster) is
      variable v       : RegType;
      variable axilEp  : AxiLiteEndPointType;
      variable trigger : sl;
   begin
      -- Latch the current value
      v := r;

      -- Reset strobes
      v.cntRst   := '0';
      v.bramWe   := '0';
      v.softTrig := '0';

      -- Update shift register
      v.bramLat := '0' & r.bramLat(1);

      ----------------------------------------------------------------------
      --                AXI-Lite Register Logic
      ----------------------------------------------------------------------

      -- Determine the transaction type
      axiSlaveWaitTxn(axilEp, writeMaster, readMaster, v.writeSlave, v.readSlave);

      -- Map the registers
      axiSlaveRegisterR(axilEp, x"00", 0, AXI_BASE_ADDR_G);  -- 64-bits

      axiSlaveRegisterR(axilEp, x"08", 0, toSlv(DATA_BYTES_G, 8));
      axiSlaveRegisterR(axilEp, x"08", 8, toSlv(BURST_BYTES_G, 8));
      axiSlaveRegisterR(axilEp, x"08", 16, toSlv(RING_BUFF_ADDR_WIDTH_G, 8));

      axiSlaveRegisterR(axilEp, x"0C", 0, toSlv(DATA_BITSIZE_C, 8));
      axiSlaveRegisterR(axilEp, x"0C", 8, toSlv(BURST_BITSIZE_C, 8));
      axiSlaveRegisterR(axilEp, x"0C", 16, toSlv(MEM_BITSIZE_C, 8));

      axiSlaveRegisterR(axilEp, x"10", 0, r.readoutCnt);
      axiSlaveRegisterR(axilEp, x"14", 0, r.dropTrigCnt);
      axiSlaveRegisterR(axilEp, x"18", 0, r.wrErrCnt);

      axiSlaveRegister (axilEp, x"80", 0, v.continuousMode);
      axiSlaveRegister (axilEp, x"F8", 0, v.softTrig);
      axiSlaveRegister (axilEp, x"FC", 0, v.cntRst);

      -- Closeout the transaction
      axiSlaveDefault(axilEp, v.writeSlave, v.readSlave, AXI_RESP_DECERR_C);

      ----------------------------------------------------------------------
      --                Ring Buffer logic
      ----------------------------------------------------------------------

      -- Register to help make timing
      v.dataValid := dataValid;
      v.dataValue := dataValue;
      v.extTrig   := extTrig;

      -- Update the trigger
      trigger := r.extTrig or r.softTrig;
      if (r.continuousMode = '1') and (r.ready = '1') and (r.armed = '0') then
         trigger := '1';
      end if;

      -- Write AXI Flow Control
      v.axiWriteMaster.bready := '1';   -- Always accepting response
      if axiWriteSlave.awready = '1' then
         v.axiWriteMaster.awvalid := '0';
      end if;
      if axiWriteSlave.wready = '1' then
         v.axiWriteMaster.wvalid := '0';
         v.axiWriteMaster.wlast  := '0';
      end if;

      -- Read AXI Flow Control
      v.mAxiReadMaster.rready := '0';
      if mAxiReadSlave.arready = '1' then
         v.mAxiReadMaster.arvalid := '0';
      end if;

      -- AXI Stream Flow Control
      if (txSlave.tReady = '1') then
         v.txMaster.tValid := '0';
         v.txMaster.tLast  := '0';
         v.txMaster.tUser  := (others => '0');
      end if;

      case r.state is
         ----------------------------------------------------------------------
         when WR_AXI_S =>
            -- Reset signals
            v.bramWrCnt := (others => '0');
            v.rdWrdCnt  := (others => '0');

            -- Check for trigger
            if (trigger = '1') then

               -- Check if we are ready to accept triggers
               if (r.ready = '1') and (r.armed = '0') then

                  -- Set the flags
                  v.armed := '1';

                  -- Increment the counter
                  v.readoutCnt := r.readoutCnt + 1;

                  -- Save the write index offset
                  v.wrdOffset := r.memIdx(AXI_BURST_RANGE_C);

               else
                  -- Increment the counter
                  v.dropTrigCnt := r.dropTrigCnt + 1;
               end if;

            end if;

            -- Check if data if valid
            if (r.dataValid = '1') then

               -- Check if ready to move write data
               if (v.axiWriteMaster.awvalid = '0') and (v.axiWriteMaster.wvalid = '0') then

                  -- Increment the counter
                  v.memIdx := r.memIdx + DATA_BYTES_G;

                  -- Check for first write
                  if (r.memIdx(AXI_BURST_RANGE_C) = 0) then
                     -- Write Address channel
                     v.axiWriteMaster.awvalid                 := '1';
                     v.axiWriteMaster.awaddr(AXI_BUF_RANGE_C) := r.memIdx;
                  end if;

                  -- Write Data channel
                  v.axiWriteMaster.wvalid                           := '1';
                  v.axiWriteMaster.wdata(8*DATA_BYTES_G-1 downto 0) := r.dataValue;

                  -- Check for last write
                  if (v.memIdx(AXI_BURST_RANGE_C) = 0) then

                     -- Terminate the frame
                     v.axiWriteMaster.wlast := '1';

                     -- Check if we have received a trigger
                     if (v.armed = '1') then
                        -- Next state
                        v.state := WR_BRAM_S;
                     end if;

                  end if;

               end if;

               -- Check if entire ring buffer filled
               if (v.memIdx = 0) then
                  -- Set the flag
                  v.ready := '1';
               end if;

            else
               -- Increment the counter
               v.wrErrCnt := r.wrErrCnt + 1;
            end if;
         ----------------------------------------------------------------------
         when WR_BRAM_S =>
            -- Reset signals
            v.ready := '0';
            v.armed := '0';

            -- Latch the read start address
            v.startIdx := r.memIdx;

            -- Check if data if valid
            if (r.dataValid = '1') then

               -- Increment the counter
               v.bramWrCnt := r.bramWrCnt + 1;

               -- Write to local BRAM memory
               v.bramWe    := '1';
               v.bramAddr  := r.bramWrCnt;
               v.bramWrDat := r.dataValue;

               -- Check for last write
               if (v.bramWrCnt = 0) then
                  -- Next state
                  v.state := RD_AXI_ADDR_S;
               end if;

            end if;
         ----------------------------------------------------------------------
         when RD_AXI_ADDR_S =>
            -- Reset signals
            v.bramAddr := (others => '0');

            -- Check if ready
            if (v.mAxiReadMaster.arvalid = '0') then

               -- Write Address channel
               v.mAxiReadMaster.arvalid                 := '1';
               v.mAxiReadMaster.araddr(AXI_BUF_RANGE_C) := r.memIdx;

               -- Next State
               v.state := RD_AXI_DATA_S;

            end if;
         ----------------------------------------------------------------------
         when RD_AXI_DATA_S =>
            -- Check for new data
            if (mAxiReadSlave.rvalid = '1') and (v.txMaster.tValid = '0') then

               -- Accept the data
               v.mAxiReadMaster.rready := '1';

               -- Increment the counter
               v.memIdx := r.memIdx + DATA_BYTES_G;

               -- Set the data bus
               v.txMaster.tData(8*DATA_BYTES_G-1 downto 0) := mAxiReadSlave.rdata(8*DATA_BYTES_G-1 downto 0);

               -- Check word offset
               if (r.wrdOffset = 0) then

                  -- Send the data valid
                  v.txMaster.tValid := '1';

                  -- Increment the counter
                  v.rdWrdCnt := r.rdWrdCnt + 1;

                  -- Check for Start Of Frame (SOF)
                  if (r.rdWrdCnt = 0) then
                     -- Set the SOF bit
                     ssiSetUserSof(AXIS_CONFIG_C, v.txMaster, '1');
                  end if;

                  -- Set the EOF bit
                  if (v.rdWrdCnt = 0) then

                     -- Terminate the frame
                     v.txMaster.tLast := '1';

                     -- Reset the memory index
                     v.memIdx := (others => '0');

                     -- Next state
                     v.state := WR_AXI_S;

                  -- Check if done reading the AXI4 memory interface
                  elsif (r.startIdx = v.memIdx) then

                     -- Next state
                     v.state := RD_BRAM_S;

                  -- Check for last transfer
                  elsif (mAxiReadSlave.rlast = '1') then

                     -- Next State
                     v.state := RD_AXI_ADDR_S;

                  end if;

               else

                  -- Decrement the counter
                  v.wrdOffset := r.wrdOffset - DATA_BYTES_G;

                  -- Check for last transfer
                  if (mAxiReadSlave.rlast = '1') then
                     -- Next State
                     v.state := RD_AXI_ADDR_S;
                  end if;

               end if;

            end if;
         ----------------------------------------------------------------------
         when RD_BRAM_S =>
            -- Check for new data
            if (r.bramLat = 0) and (v.txMaster.tValid = '0') then

               -- Set the lat wait
               v.bramLat := (others => '1');

               -- Increment the counters
               v.bramAddr := r.bramAddr + 1;
               v.rdWrdCnt := r.rdWrdCnt + 1;

               -- Send the data
               v.txMaster.tValid                           := '1';
               v.txMaster.tData(8*DATA_BYTES_G-1 downto 0) := bramData;

               -- Set the EOF bit
               if (v.rdWrdCnt = 0) then

                  -- Terminate the frame
                  v.txMaster.tLast := '1';

                  -- Reset the memory index
                  v.memIdx := (others => '0');

                  -- Next state
                  v.state := WR_AXI_S;

               end if;

            end if;
      ----------------------------------------------------------------------
      end case;

      -- Check for missed triggers
      if (trigger = '1') and (r.state /= WR_AXI_S) then
         -- Increment the counter
         v.dropTrigCnt := r.dropTrigCnt + 1;
      end if;

      -- Prevent roll overs of error counters
      if (v.dropTrigCnt = 0) then
         v.dropTrigCnt := r.dropTrigCnt;
      end if;
      if (v.wrErrCnt = 0) then
         v.wrErrCnt := r.wrErrCnt;
      end if;

      -- Check for counter reset
      if (r.cntRst = '1') then
         v.readoutCnt  := (others => '0');
         v.dropTrigCnt := (others => '0');
         v.wrErrCnt    := (others => '0');
      end if;

      ----------------------------------------------------------------------
      --                Outputs
      ----------------------------------------------------------------------

      -- AXI4 Write Outputs
      axiWriteMaster        <= r.axiWriteMaster;
      axiWriteMaster.bready <= v.axiWriteMaster.bready;

      -- AXI4 Read Outputs
      mAxiReadMaster        <= r.mAxiReadMaster;
      mAxiReadMaster.rready <= v.mAxiReadMaster.rready;

      -- Reset
      if (dataRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

   end process comb;

   seq : process (dataClk) is
   begin
      if rising_edge(dataClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   GEN_XPM : if (SYNTH_MODE_G = "xpm") generate
      U_BRAM : entity surf.SimpleDualPortRamXpm
         generic map(
            TPD_G          => TPD_G,
            COMMON_CLK_G   => true,
            MEMORY_TYPE_G  => MEMORY_TYPE_G,
            READ_LATENCY_G => 2,
            DATA_WIDTH_G   => 8*DATA_BYTES_G,
            ADDR_WIDTH_G   => BURST_BITSIZE_C)
         port map (
            -- Port A
            clka   => dataClk,
            wea(0) => r.bramWe,
            addra  => r.bramAddr,
            dina   => r.bramWrDat,
            -- Port B
            clkb   => dataClk,
            addrb  => r.bramAddr,
            doutb  => bramData);
   end generate;

   GEN_INFERRED : if (SYNTH_MODE_G = "inferred") generate
      U_BRAM : entity surf.SimpleDualPortRam
         generic map(
            TPD_G         => TPD_G,
            MEMORY_TYPE_G => MEMORY_TYPE_G,
            DOB_REG_G     => true,
            DATA_WIDTH_G  => 8*DATA_BYTES_G,
            ADDR_WIDTH_G  => BURST_BITSIZE_C)
         port map (
            -- Port A
            clka  => dataClk,
            wea   => r.bramWe,
            addra => r.bramAddr,
            dina  => r.bramWrDat,
            -- Port B
            clkb  => dataClk,
            addrb => r.bramAddr,
            doutb => bramData);
   end generate;

   AXI_TX_FIFO : entity surf.AxiWritePathFifo
      generic map (
         -- General Configurations
         TPD_G                  => TPD_G,
         -- General FIFO configurations
         GEN_SYNC_FIFO_G        => true,
         -- Address FIFO Config
         ADDR_MEMORY_TYPE_G     => "distributed",
         ADDR_FIFO_ADDR_WIDTH_G => 4,
         -- Data FIFO Config
         DATA_MEMORY_TYPE_G     => "block",
         DATA_FIFO_ADDR_WIDTH_G => 9,
         -- Response FIFO Config
         RESP_MEMORY_TYPE_G     => "distributed",
         RESP_FIFO_ADDR_WIDTH_G => 4,
         -- BUS Config
         AXI_CONFIG_G           => AXI_CONFIG_C)
      port map (
         -- Slave Port
         sAxiClk         => dataClk,
         sAxiRst         => dataRst,
         sAxiWriteMaster => axiWriteMaster,
         sAxiWriteSlave  => axiWriteSlave,
         -- Master Port
         mAxiClk         => dataClk,
         mAxiRst         => dataRst,
         mAxiWriteMaster => mAxiWriteMaster,
         mAxiWriteSlave  => mAxiWriteSlave);

   AXIS_TX_FIFO : entity surf.AxiStreamFifoV2
      generic map (
         -- General Configurations
         TPD_G               => TPD_G,
         -- FIFO configurations
         GEN_SYNC_FIFO_G     => false,
         -- AXI Stream Port Configurations
         SLAVE_AXI_CONFIG_G  => AXIS_CONFIG_C,
         MASTER_AXI_CONFIG_G => AXI_STREAM_CONFIG_G)
      port map (
         -- Slave Port
         sAxisClk    => dataClk,
         sAxisRst    => dataRst,
         sAxisMaster => r.txMaster,
         sAxisSlave  => txSlave,
         -- Master Port
         mAxisClk    => axisClk,
         mAxisRst    => axisRst,
         mAxisMaster => axisMaster,
         mAxisSlave  => axisSlave);

end rtl;
