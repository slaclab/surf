-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Wrapper for simple BRAM based frame buffer with AXI Stream interface
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Firmware Standard Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the
-- top-level directory of this distribution and at:
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
-- No part of 'SLAC Firmware Standard Library', including this file,
-- may be copied, modified, propagated, or distributed except according to
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

-- Notes ----------------------------------------------------------------------
-- Some TODOs remain and are indicated by comments in the code.
--
-- -- Safe buffering --
-- Asynchronous write/read with only two buffers and without the ability to
-- backpressure the input data interface did not appear to be possible (in some
-- edge cases, something has to block somewhere). Such issues should be avoided
-- by the use of three buffers (not sure if this can be called ping-pong
-- buffering anymore).
-- A further mode where read/write goes to the same buffer is available.
-- This mode will use only a third of the memory resources but requires the
-- user to ensure that timing of reads/writes does not overlap (or perhaps in
-- some cases one does not care).
-- Toggle between the two using the SAFE_BUFFS_G generic.
--
-- -- Frame end conditions and signaling --
-- A frame ends when dataFrameTxLast is asserted (last transmission of the
-- frame) or the buffer is full. One cycle after this happens the
-- dataFrameRxDone signal is asserted, signaling that a new frame has been
-- received and is ready for readout. A readout request (getFrameTrig)
-- to read out this frame over AXI-Stream can be issued during this cycle
-- or later to get the latest frame. In the safe buffer mode, the always the
-- latest completely received frame is provided.
-- The user may exteranlly connect dataFrameRxDone (out) to getFrameTrig (in)
-- to trigger a frame dump over AXI-Stream as soon as a new frame is available.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;
use surf.AxiLitePkg.all;
use surf.SsiPkg.all;

entity AxiStreamFrameBuffer is
   generic (
      TPD_G               : time     := 1 ns;
      RST_POLARITY_G      : sl       := '1';  -- '1' for active HIGH reset, '0' for active LOW reset
      RST_ASYNC_G         : boolean  := false;
      SYNTH_MODE_G        : string   := "inferred";
      MEMORY_TYPE_G       : string   := "block";
      -- TODO: Better name for that?
      SAFE_BUFFS_G        : boolean  := true;  -- If 'false' write/read target the same buffer
      COMMON_CLK_G        : boolean  := false;  -- true if dataClk=axilClk
      DATA_BYTES_G        : positive := 16;
      RAM_ADDR_WIDTH_G    : positive := 9;
      -- AXI Stream Configurations
      INT_PIPE_STAGES_G   : natural  := 1;
      PIPE_STAGES_G       : natural  := 1;
      GEN_SYNC_FIFO_G     : boolean  := false;
      FIFO_MEMORY_TYPE_G  : string   := "block";
      FIFO_ADDR_WIDTH_G   : positive := 9;
      AXI_STREAM_CONFIG_G : AxiStreamConfigType);
   port (
      -- Data to store in frame buffer (dataClk domain)
      dataClk         : in  sl;
      dataRst         : in  sl := '0';
      dataValid       : in  sl := '1';
      dataValue       : in  slv(8*DATA_BYTES_G-1 downto 0);
      dataFrameTxLast : in  sl := '0';  -- Signal end of frame
      dataFrameRxDone : out sl := '0';  -- Asserted on end of frame (due to dataFrameTxLast or buffer full)
      -- AXI-Lite interface (axilClk domain)
      axilClk         : in  sl;
      axilRst         : in  sl;
      axilReadMaster  : in  AxiLiteReadMasterType;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType;
      axilWriteSlave  : out AxiLiteWriteSlaveType;
      -- AXI-Stream Interface (axisClk domain)
      getFrameTrig    : in  sl;
      axisClk         : in  sl;
      axisRst         : in  sl;
      axisMaster      : out AxiStreamMasterType;
      axisSlave       : in  AxiStreamSlaveType);
end entity AxiStreamFrameBuffer;

architecture rtl of AxiStreamFrameBuffer is

   constant AXIS_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(
      dataBytes => DATA_BYTES_G,
      tKeepMode => TKEEP_FIXED_C,
      tUserMode => TUSER_FIRST_LAST_C,
      tDestBits => 0,
      tUserBits => 2,
      tIdBits   => 0);

   function get_n_buffs return integer is
   begin
      if SAFE_BUFFS_G then return 3; else return 1; end if;
   end function;

   constant N_BUFFS_C : integer := get_n_buffs;

   ------------------------------
   -- Stream clock domain signals
   ------------------------------
   type ramRdArray is array (natural range <>) of slv(8*DATA_BYTES_G-1 downto 0);
   signal ramRdDataArr : ramRdArray(2 downto 0);
   signal ramRdData    : slv(8*DATA_BYTES_G-1 downto 0);

   type DataRegType is record
      ramWrEn         : sl;
      ramWrEnMask     : slv(2 downto 0);
      ramRdEnMask     : slv(2 downto 0);
      ramRdEnMaskNext : slv(2 downto 0);
      rdSetupDone     : sl;
      ramWrAddr       : slv(RAM_ADDR_WIDTH_G-1 downto 0);
      ramWrAddrNext   : slv(RAM_ADDR_WIDTH_G-1 downto 0);
      rdFinalAddr     : slv(RAM_ADDR_WIDTH_G-1 downto 0);
      rdFinalAddrNext : slv(RAM_ADDR_WIDTH_G-1 downto 0);
      ramWrData       : slv(8*DATA_BYTES_G-1 downto 0);
      dataFrameTxLast : sl;
      dataFrameRxDone : sl;
   end record;

   constant DATA_REG_INIT_C : DataRegType := (
      ramWrEn         => '0',
      ramWrEnMask     => "001",
      ramRdEnMask     => "100",
      ramRdEnMaskNext => "100",
      rdSetupDone     => '0',
      ramWrAddr       => (others => '0'),
      ramWrAddrNext   => (others => '0'),
      rdFinalAddr     => (others => '0'),
      rdFinalAddrNext => (others => '0'),
      ramWrData       => (others => '0'),
      dataFrameTxLast => '0',
      dataFrameRxDone => '0');

   signal dataR   : DataRegType := DATA_REG_INIT_C;
   signal dataRin : DataRegType;

   --------------------------------
   -- AXI-Lite clock domain signals
   --------------------------------
   type AxisStateType is (
      IDLE_S,
      WAIT_RD_SETUP_S,
      MOVE_S);

   type AxilRegType is record
      softTrig       : sl;
      rdReq          : sl;
      rdFinalAddr    : slv(RAM_ADDR_WIDTH_G-1 downto 0);
      ramRdAddr      : slv(RAM_ADDR_WIDTH_G-1 downto 0);
      rdEn           : slv(2 downto 0);
      axilReadSlave  : AxiLiteReadSlaveType;
      axilWriteSlave : AxiLiteWriteSlaveType;
      txMaster       : AxiStreamMasterType;
      axisState      : AxisStateType;
      dataStateIdx   : slv(1 downto 0);
   end record;

   constant AXIL_REG_INIT_C : AxilRegType := (
      softTrig       => '0',
      rdReq          => '0',
      rdFinalAddr    => (others => '0'),
      ramRdAddr      => (others => '0'),
      rdEn           => "000",
      axilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
      axilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C,
      txMaster       => axiStreamMasterInit(AXIS_CONFIG_C),
      axisState      => IDLE_S,
      dataStateIdx   => (others => '0'));

   signal axilR   : AxilRegType := AXIL_REG_INIT_C;
   signal axilRin : AxilRegType;

   signal axilRstSync : sl;
   signal dataRstSync : sl;

   signal rdFinalAddrSync : slv(RAM_ADDR_WIDTH_G-1 downto 0);
   signal rdSetupDoneSync : sl;

   signal getFrameTrigSync : sl;
   signal rdReqSync        : sl;

   signal txSlave : AxiStreamSlaveType;

begin

   ----------------------
   -- Instantiate the RAM
   ----------------------

   GEN_RAM : for i in N_BUFFS_C - 1 downto 0 generate
      GEN_XPM : if (SYNTH_MODE_G = "xpm") generate
         U_Ram : entity surf.SimpleDualPortRamXpm
            generic map (
               TPD_G          => TPD_G,
               RST_POLARITY_G => RST_POLARITY_G,
               COMMON_CLK_G   => COMMON_CLK_G,
               MEMORY_TYPE_G  => MEMORY_TYPE_G,
               READ_LATENCY_G => 2,
               DATA_WIDTH_G   => 8*DATA_BYTES_G,
               ADDR_WIDTH_G   => RAM_ADDR_WIDTH_G)
            port map (
               -- Port A
               clka   => dataClk,
               wea(0) => dataR.ramWrEn and dataR.ramWrEnMask(i),
               addra  => dataR.ramWrAddr,
               dina   => dataR.ramWrData,
               -- Port B
               clkb   => axilClk,
               addrb  => axilR.ramRdAddr,
               doutb  => ramRdDataArr(i));
      end generate;

      GEN_ALTERA : if (SYNTH_MODE_G = "altera_mf") generate
         U_Ram : entity surf.SimpleDualPortRamAlteraMf
            generic map (
               TPD_G          => TPD_G,
               RST_POLARITY_G => RST_POLARITY_G,
               COMMON_CLK_G   => COMMON_CLK_G,
               MEMORY_TYPE_G  => MEMORY_TYPE_G,
               READ_LATENCY_G => 2,
               DATA_WIDTH_G   => 8*DATA_BYTES_G,
               ADDR_WIDTH_G   => RAM_ADDR_WIDTH_G)
            port map (
               -- Port A
               clka   => dataClk,
               wea(0) => dataR.ramWrEn and dataR.ramWrEnMask(i),
               addra  => dataR.ramWrAddr,
               dina   => dataR.ramWrData,
               -- Port B
               clkb   => axilClk,
               addrb  => axilR.ramRdAddr,
               doutb  => ramRdDataArr(i));
      end generate;

      GEN_INFERRED : if (SYNTH_MODE_G = "inferred") generate
         U_Ram : entity surf.SimpleDualPortRam
            generic map (
               TPD_G          => TPD_G,
               RST_POLARITY_G => RST_POLARITY_G,
               RST_ASYNC_G    => RST_ASYNC_G,
               MEMORY_TYPE_G  => MEMORY_TYPE_G,
               DOB_REG_G      => true,
               DATA_WIDTH_G   => 8*DATA_BYTES_G,
               ADDR_WIDTH_G   => RAM_ADDR_WIDTH_G)
            port map (
               -- Port A
               clka  => dataClk,
               wea   => dataR.ramWrEn and dataR.ramWrEnMask(i),
               addra => dataR.ramWrAddr,
               dina  => dataR.ramWrData,
               -- Port B
               clkb  => axilClk,
               addrb => axilR.ramRdAddr,
               doutb => ramRdDataArr(i));
      end generate;
   end generate GEN_RAM;

   ----------------------------
   -- Synchronize reset signals
   ----------------------------

   U_RstSync_axilRst : entity surf.RstSync
      generic map (
         TPD_G          => TPD_G,
         IN_POLARITY_G  => RST_POLARITY_G,
         OUT_POLARITY_G => RST_POLARITY_G)
      port map (
         clk      => dataClk,
         asyncRst => axilRst,
         syncRst  => axilRstSync);

   U_RstSync_dataRst : entity surf.RstSync
      generic map (
         TPD_G          => TPD_G,
         IN_POLARITY_G  => RST_POLARITY_G,
         OUT_POLARITY_G => RST_POLARITY_G)
      port map (
         clk      => axilClk,
         asyncRst => dataRst,
         syncRst  => dataRstSync);

   -----------------------------
   -- Data process (data inputs)
   -----------------------------

   dataComb : process (dataR, dataRst, axilRstSync, dataValid, dataValue, dataFrameTxLast,
                       rdReqSync) is
      variable v : DataRegType;
   begin
      -- Latch the current value
      v := dataR;

      -- Reset strobes
      v.ramWrEn         := '0';
      v.rdSetupDone     := '0';
      v.dataFrameRxDone := '0';

      -- Register data value to help with making timing
      v.ramWrData       := dataValue;
      v.dataFrameTxLast := dataFrameTxLast;


      -- Check if last frame was the final frame or if the buffer is full.
      if (dataR.dataFrameTxLast = '1') or (dataR.ramWrAddr = 2**RAM_ADDR_WIDTH_G - 1) then

         -- Masks only used/updated in safe buffers mode
         if SAFE_BUFFS_G then
            -- Set next buffer for writing to the buffer that is not currently set
            -- for neither read nor write.
            v.ramWrEnMask     := not (dataR.ramWrEnMask or dataR.ramRdEnMask);
            -- The next buffer for reading is the last buffer written to so
            -- always the newest frame can be obtained.
            v.ramRdEnMaskNext := dataR.ramWrEnMask;
         end if;

         -- Keep track of last address written to during last write so the
         -- correct numbers of words can be read on the next read.
         v.rdFinalAddrNext := dataR.ramWrAddr;

         -- Reset value for address is all ones so that in first write cycle after
         -- reset which happens before the frame end condition is satisfied at least
         -- once we wrap around after incrementing and land on address 0.
         v.ramWrAddr     := (others => '0');
         v.ramWrAddrNext := (others => '0');

         -- Signal frame receive done and new frame available for readout.
         -- The next write can actually proceed in the same cycle as this signal
         -- is asserted in.
         v.dataFrameRxDone := '1';

      end if;

      -- Only write if data valid. There may be still data received for the
      -- clock cycle where dataFramTxLast = '1' and it is possible to receive the
      -- start with the next frame immediately in the frame where write masks
      -- are updated.
      if (dataValid = '1') then

         -- Strobe write enable
         v.ramWrEn := '1';

         -- Increment write address. Reference v, not r as this might have
         -- been reset by the frame end condition above.
         v.ramWrAddr     := v.ramWrAddrNext;  -- Mini-pipeline
         v.ramWrAddrNext := v.ramWrAddrNext + 1;

      end if;

      -- If readout requested, set read mask to the next read mask
      if (rdReqSync = '1') then
         -- Masks only used/updated in safe buffers mode
         if SAFE_BUFFS_G then
            -- Actually apply the next read mask. Do this from v, not r,
            -- as read can start as early as the next next cycle where
            -- a different write mask may be used.
            v.ramRdEnMask := v.ramRdEnMaskNext;
         end if;
         -- Drive the read final address signal
         v.rdFinalAddr := dataR.rdFinalAddrNext;
         -- Signal to the axi-stream process that it can start reading by
         -- strobing rdSetupDone (must be synchronized to other clock domain).
         v.rdSetupDone := '1';
      end if;

      -- Outputs
      dataFrameRxDone <= dataR.dataFrameRxDone;

      -- Synchronous Reset
      if (RST_ASYNC_G = false and dataRst = RST_POLARITY_G) or (axilRstSync = '1') then
         v := DATA_REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      dataRin <= v;

   end process;

   dataSeq : process (dataClk, dataRst) is
   begin
      if (RST_ASYNC_G) and (dataRst = RST_POLARITY_G) then
         dataR <= DATA_REG_INIT_C after TPD_G;
      elsif rising_edge(dataClk) then
         dataR <= dataRin after TPD_G;
      end if;
   end process;

   -- Multiplexing the read lines is only required when using multiple buffers.
   GEN_RAM_RD_DATA_MUX : if SAFE_BUFFS_G generate
      -- Assign active ram output lines array (hot-one mask to integer)
      ramRdData <= ramRdDataArr(0) when dataR.ramRdEnMask = "001" else
                   ramRdDataArr(1) when dataR.ramRdEnMask = "010" else
                   ramRdDataArr(2);
   else generate
      ramRdData <= ramRdDataArr(0);
   end generate GEN_RAM_RD_DATA_MUX;

   -------------------------------------------------------------
   -- Synchronization of signals between data/AXI-lite processes
   -------------------------------------------------------------

   -- Synchronize final read address
   U_SyncVec_axilClk_rdFinalAddr : entity surf.SynchronizerVector
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G,
         WIDTH_G        => RAM_ADDR_WIDTH_G)
      port map (
         clk     => axilClk,
         dataIn  => dataR.rdFinalAddr,
         dataOut => rdFinalAddrSync);

   -- Synchronize read setup done strobe
   U_Sync_axilClk_rdSetupDone : entity work.SynchronizerOneShot
      generic map(
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G
         )
      port map(
         clk     => axilClk,
         dataIn  => dataR.rdSetupDone,
         dataOut => rdSetupDoneSync);

   -- Synchronize read request strobe
   U_Sync_axilClk_rdReq : entity work.SynchronizerOneShot
      generic map(
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G
         )
      port map(
         clk     => dataClk,
         dataIn  => axilR.rdReq,
         dataOut => rdReqSync);

   U_Sync_axilClk_getFrameTrig : entity work.Synchronizer
      generic map(
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G
         )
      port map(
         clk     => axilClk,
         dataIn  => getFrameTrig,
         dataOut => getFrameTrigSync);

   -------------------------------
   -- Main AXI-Lite/Stream process
   -------------------------------

   axiComb : process (axilR, axilReadMaster, axilRst, dataRstSync, axilWriteMaster,
                      getFrameTrigSync, ramRdData, rdFinalAddrSync, rdSetupDoneSync, txSlave) is
      variable v      : AxilRegType;
      variable axilEp : AxiLiteEndpointType;
   begin
      -- Latch the current value
      v := axilR;

      -- Reset strobes
      v.rdReq := '0';

      ------------------------
      -- AXI-Lite Transactions
      ------------------------

      -- Determine the transaction type
      axiSlaveWaitTxn(axilEp, axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave);

      -- TODO: I thought softTrig is a trigger from software but it does not seem
      -- to be for the ring buffer??? Maybe this is a relict from an older version
      -- where the soft trigger could only do one at a time and now one can request
      -- a burst of n triggers?
      axiSlaveRegisterR(axilEp, x"0", 0, axilR.rdFinalAddr);
      axiSlaveRegisterR(axilEp, x"0", 20, toSlv(RAM_ADDR_WIDTH_G, 8));
      axiSlaveRegisterR(axilEp, x"0", 30, axilR.dataStateIdx);
      axiSlaveRegister(axilEp, x"4", 0, v.softTrig);

      -- Close the transaction
      axiSlaveDefault(axilEp, v.axilWriteSlave, v.axilReadSlave, AXI_RESP_DECERR_C);

      ------------------------
      -- AXI-Stream
      ------------------------

      -- Update Shift Register.
      -- Required to match the read delay of the ram.
      v.rdEn(0) := '0';
      v.rdEn(1) := axilR.rdEn(0);
      v.rdEn(2) := axilR.rdEn(1);

      -- AXI Stream Flow Control
      if (txSlave.tReady = '1') then
         v.txMaster := axiStreamMasterInit(AXIS_CONFIG_C);
      end if;

      case axilR.axisState is
         ----------------------------------------------------------------------
         when IDLE_S =>
            v.dataStateIdx := "00";

            -- Check for trigger event
            if (getFrameTrigSync = '1') or (v.softTrig = '1') then
               -- Issue a read request (strobe)
               v.rdReq     := '1';
               -- Proceed to wait for data process to prepare readout
               v.axisState := WAIT_RD_SETUP_S;
            end if;
         ----------------------------------------------------------------------
         when WAIT_RD_SETUP_S =>
            v.dataStateIdx := "01";
            if (rdSetupDoneSync = '1') then
               -- Latch read final address
               v.rdFinalAddr := rdFinalAddrSync;
               -- Reset read address
               v.ramRdAddr   := (others => '0');
               -- Queue up the first read by writing to shift register
               v.rdEn(0)     := '1';
               -- Start moving data
               v.axisState   := MOVE_S;
            end if;
         ----------------------------------------------------------------------
         when MOVE_S =>
            v.dataStateIdx := "10";

            -- Check if ready to move data
            -- TODO: Why don't we do axilR.rdEn(2) = '1', i.e. pipeline the read?
            -- Checking for all zeros should mean we just wait for three cycles
            -- before read for every read...
            if (v.txMaster.tValid = '0') and (axilR.rdEn = 0) then

               -- Send the data
               v.txMaster.tValid                           := '1';
               v.txMaster.tData(8*DATA_BYTES_G-1 downto 0) := ramRdData;

               -- Check for Start Of Frame (SOF)
               if (axilR.ramRdAddr = 0) then

                  -- Set the SOF bit
                  ssiSetUserSof(AXIS_CONFIG_C, v.txMaster, '1');

               end if;

               -- Check for End of Frame (EOF), i.e. the last address.
               if (axilR.ramRdAddr = axilR.rdFinalAddr) then

                  -- Set the EOF bit
                  v.txMaster.tLast := '1';

                  -- Transmission completed, move back to idle
                  v.axisState := IDLE_S;

               else
                  -- Increment the read address
                  v.ramRdAddr := axilR.ramRdAddr + 1;
               end if;

            end if;
      ----------------------------------------------------------------------
      end case;

      -- Check for external data reset
      if (dataRstSync = '1') then
         -- Return to idle
         -- TODO: Is it a problem if we never close out the axis transmission,
         -- i.e. never assert tLast?
         v.axisState := IDLE_S;
      end if;

      -- Check for change in address
      if (axilR.ramRdAddr /= v.ramRdAddr) then
         -- Queue up the next read by writing to shift register
         v.rdEn(0) := '1';
      end if;

      -- Outputs
      axilReadSlave  <= axilR.axilReadSlave;
      axilWriteSlave <= axilR.axilWriteSlave;

      -- Synchronous Reset
      if (RST_ASYNC_G = false and axilRst = RST_POLARITY_G) then
         v := AXIL_REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      axilRin <= v;

   end process;

   axiSeq : process (axilClk, axilRst) is
   begin
      if (RST_ASYNC_G) and (axilRst = RST_POLARITY_G) then
         axilR <= AXIL_REG_INIT_C after TPD_G;
      elsif rising_edge(axilClk) then
         axilR <= axilRin after TPD_G;
      end if;
   end process;

   -----------------------------------------------------------
   -- TX fifo for transition from AXI-Lite to AXI-Stream clock
   -----------------------------------------------------------

   TX_FIFO : entity surf.AxiStreamFifoV2
      generic map (
         -- General Configurations
         TPD_G               => TPD_G,
         RST_POLARITY_G      => RST_POLARITY_G,
         RST_ASYNC_G         => RST_ASYNC_G,
         INT_PIPE_STAGES_G   => INT_PIPE_STAGES_G,
         PIPE_STAGES_G       => PIPE_STAGES_G,
         SLAVE_READY_EN_G    => true,
         -- FIFO configurations
         SYNTH_MODE_G        => SYNTH_MODE_G,
         MEMORY_TYPE_G       => FIFO_MEMORY_TYPE_G,
         GEN_SYNC_FIFO_G     => GEN_SYNC_FIFO_G,
         FIFO_ADDR_WIDTH_G   => FIFO_ADDR_WIDTH_G,
         -- AXI Stream Port Configurations
         SLAVE_AXI_CONFIG_G  => AXIS_CONFIG_C,
         MASTER_AXI_CONFIG_G => AXI_STREAM_CONFIG_G)
      port map (
         -- Slave Port
         sAxisClk    => axilClk,
         sAxisRst    => axilRst,
         sAxisMaster => axilR.txMaster,
         sAxisSlave  => txSlave,
         -- Master Port
         mAxisClk    => axisClk,
         mAxisRst    => axisRst,
         mAxisMaster => axisMaster,
         mAxisSlave  => axisSlave);

end architecture rtl;
