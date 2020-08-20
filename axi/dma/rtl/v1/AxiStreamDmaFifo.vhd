-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
-- Generic AXI Stream FIFO (one frame at a time transfers, no TDEST interleaving)
-- using an AXI4 memory for the buffering of the AXI stream frames
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
use surf.AxiLitePkg.all;
use surf.AxiPkg.all;
use surf.AxiDmaPkg.all;
use surf.SsiPkg.all;

entity AxiStreamDmaFifo is
   generic (
      TPD_G              : time                := 1 ns;
      START_AFTER_RST_G  : sl                  := '1';  -- '1' still start the DMA REQs after RST; '0' will wait for AXI-Lite to start this
      DROP_ERR_FRAME_G   : sl                  := '1';  -- '1' will drop the AXIS if error detect
      SOF_INSERT_G       : sl                  := '1';  -- Inserts SsiPkg's SOF bit
      PEND_THRESH_G      : natural             := 0;   -- In units of bytes
      -- FIFO Configuration
      MAX_FRAME_WIDTH_G  : positive            := 14;  -- Maximum AXI Stream frame size (units of address bits)
      AXI_BUFFER_WIDTH_G : positive            := 28;  -- Total AXI Memory for FIFO buffering (units of address bits)
      -- AXI Stream Configurations
      AXIS_CONFIG_G      : AxiStreamConfigType;
      -- AXI4 Configurations
      AXI_BASE_ADDR_G    : slv(63 downto 0)    := x"0000_0000_0000_0000";  -- Memory Base Address Offset
      AXI_CONFIG_G       : AxiConfigType;
      AXI_BURST_G        : slv(1 downto 0)     := "01";
      AXI_CACHE_G        : slv(3 downto 0)     := "1111");
   port (
      -- Clock and Reset
      axiClk          : in  sl;
      axiRst          : in  sl;
      -- AXI4 Interface
      axiReadMaster   : out AxiReadMasterType;
      axiReadSlave    : in  AxiReadSlaveType;
      axiWriteMaster  : out AxiWriteMasterType;
      axiWriteSlave   : in  AxiWriteSlaveType;
      -- AXI Stream Interface
      sAxisMaster     : in  AxiStreamMasterType;
      sAxisSlave      : out AxiStreamSlaveType;
      mAxisMaster     : out AxiStreamMasterType;
      mAxisSlave      : in  AxiStreamSlaveType;
      -- Optional: AXI-Lite Interface
      axilReadMaster  : in  AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
      axilWriteSlave  : out AxiLiteWriteSlaveType);
end AxiStreamDmaFifo;

architecture rtl of AxiStreamDmaFifo is

   constant BYP_SHIFT_C : boolean := true;  -- APP DMA driver enforces alignment, which means shift not required

   constant BIT_DIFF_C     : positive := AXI_BUFFER_WIDTH_G-MAX_FRAME_WIDTH_G;
   constant ADDR_WIDTH_C   : positive := ite((BIT_DIFF_C <= 10), BIT_DIFF_C, 10);
   constant CASCADE_SIZE_C : positive := ite((BIT_DIFF_C <= 10), 1, 2**(BIT_DIFF_C-10));

   constant LOCAL_AXI_READ_DMA_READ_REQ_SIZE_C : integer := MAX_FRAME_WIDTH_G+(2*AXIS_CONFIG_G.TUSER_BITS_C)+AXIS_CONFIG_G.TDEST_BITS_C+AXIS_CONFIG_G.TID_BITS_C;

   -- Using a local version (instead of AxiDmaPkg generalized functions) that's better logic optimized for this module
   function localToSlv (r : AxiReadDmaReqType) return slv is
      variable retValue : slv(LOCAL_AXI_READ_DMA_READ_REQ_SIZE_C-1 downto 0) := (others => '0');
      variable i        : integer                                            := 0;
   begin
      assignSlv(i, retValue, r.size(MAX_FRAME_WIDTH_G-1 downto 0));

      -- Check for none-zero TDEST bits
      if (AXIS_CONFIG_G.TUSER_BITS_C /= 0) then
         assignSlv(i, retValue, r.firstUser(AXIS_CONFIG_G.TUSER_BITS_C-1 downto 0));
         assignSlv(i, retValue, r.lastUser(AXIS_CONFIG_G.TUSER_BITS_C-1 downto 0));
      end if;

      -- Check for none-zero TDEST bits
      if (AXIS_CONFIG_G.TDEST_BITS_C /= 0) then
         assignSlv(i, retValue, r.dest(AXIS_CONFIG_G.TDEST_BITS_C-1 downto 0));
      end if;

      -- Check for none-zero TID bits
      if (AXIS_CONFIG_G.TID_BITS_C /= 0) then
         assignSlv(i, retValue, r.id(AXIS_CONFIG_G.TID_BITS_C-1 downto 0));
      end if;

      return(retValue);
   end function;

   function localToAxiReadDmaReq (din : slv; valid : sl) return AxiReadDmaReqType is
      variable desc : AxiReadDmaReqType := AXI_READ_DMA_REQ_INIT_C;
      variable i    : integer           := 0;
   begin
      desc.request := valid;
      assignRecord(i, din, desc.size(MAX_FRAME_WIDTH_G-1 downto 0));

      -- Check for none-zero TDEST bits
      if (AXIS_CONFIG_G.TUSER_BITS_C /= 0) then
         assignRecord(i, din, desc.firstUser(AXIS_CONFIG_G.TUSER_BITS_C-1 downto 0));
         assignRecord(i, din, desc.lastUser(AXIS_CONFIG_G.TUSER_BITS_C-1 downto 0));
      end if;

      -- Check for none-zero TDEST bits
      if (AXIS_CONFIG_G.TDEST_BITS_C /= 0) then
         assignRecord(i, din, desc.dest(AXIS_CONFIG_G.TDEST_BITS_C-1 downto 0));
      end if;

      -- Check for none-zero TID bits
      if (AXIS_CONFIG_G.TID_BITS_C /= 0) then
         assignRecord(i, din, desc.id(AXIS_CONFIG_G.TID_BITS_C-1 downto 0));
      end if;

      return(desc);
   end function;

   type RegType is record
      rstCnt         : sl;
      insertSof      : sl;
      online         : sl;
      dropOnErr      : sl;
      baseAddr       : slv(63 downto 0);
      swCache        : slv(3 downto 0);
      maxSize        : slv(31 downto 0);
      errorCnt       : slv(31 downto 0);
      rdQueueReady   : sl;
      wrQueueValid   : sl;
      wrQueueData    : slv(LOCAL_AXI_READ_DMA_READ_REQ_SIZE_C-1 downto 0);
      wrIndex        : slv(BIT_DIFF_C-1 downto 0);
      rdIndex        : slv(BIT_DIFF_C-1 downto 0);
      frameCnt       : slv(BIT_DIFF_C-1 downto 0);
      frameCntMax    : slv(BIT_DIFF_C-1 downto 0);
      wrReq          : AxiWriteDmaReqType;
      rdReq          : AxiReadDmaReqType;
      axilReadSlave  : AxiLiteReadSlaveType;
      axilWriteSlave : AxiLiteWriteSlaveType;
   end record;
   constant REG_INIT_C : RegType := (
      rstCnt         => '0',
      insertSof      => SOF_INSERT_G,
      online         => START_AFTER_RST_G,
      dropOnErr      => DROP_ERR_FRAME_G,
      baseAddr       => AXI_BASE_ADDR_G,
      maxSize        => toSlv(2**MAX_FRAME_WIDTH_G, 32),
      swCache        => AXI_CACHE_G,
      errorCnt       => (others => '0'),
      rdQueueReady   => '0',
      wrQueueValid   => '0',
      wrQueueData    => (others => '0'),
      wrIndex        => (others => '0'),
      rdIndex        => (others => '0'),
      frameCnt       => (others => '0'),
      frameCntMax    => (others => '0'),
      wrReq          => AXI_WRITE_DMA_REQ_INIT_C,
      rdReq          => AXI_READ_DMA_REQ_INIT_C,
      axilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
      axilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal wrAck : AxiWriteDmaAckType;
   signal rdAck : AxiReadDmaAckType;

   signal wrQueueAfull : sl;
   signal rdQueueRst   : sl;
   signal rdQueueReset : sl;
   signal rdQueueValid : sl;
   signal rdQueueReady : sl;
   signal rdQueueData  : slv(LOCAL_AXI_READ_DMA_READ_REQ_SIZE_C-1 downto 0);

begin

   assert (MAX_FRAME_WIDTH_G >= 12)     -- 4kB alignment
      report "MAX_FRAME_WIDTH_G must >= 12" severity failure;

   assert (AXI_BUFFER_WIDTH_G > MAX_FRAME_WIDTH_G)
      report "AXI_BUFFER_WIDTH_G must greater than MAX_FRAME_WIDTH_G" severity failure;

   ---------------------
   -- Inbound Controller
   ---------------------
   U_IbDma : entity surf.AxiStreamDmaWrite
      generic map (
         TPD_G          => TPD_G,
         AXI_READY_EN_G => true,
         AXIS_CONFIG_G  => AXIS_CONFIG_G,
         AXI_CONFIG_G   => AXI_CONFIG_G,
         AXI_BURST_G    => AXI_BURST_G,
         AXI_CACHE_G    => AXI_CACHE_G,
         SW_CACHE_EN_G  => true,
         BYP_SHIFT_G    => BYP_SHIFT_C)
      port map (
         axiClk         => axiClk,
         axiRst         => axiRst,
         dmaReq         => r.wrReq,
         dmaAck         => wrAck,
         swCache        => r.swCache,
         axisMaster     => sAxisMaster,
         axisSlave      => sAxisSlave,
         axiWriteMaster => axiWriteMaster,
         axiWriteSlave  => axiWriteSlave);

   ----------------------
   -- Outbound Controller
   ----------------------
   U_ObDma : entity surf.AxiStreamDmaRead
      generic map (
         TPD_G           => TPD_G,
         AXIS_READY_EN_G => true,
         AXIS_CONFIG_G   => AXIS_CONFIG_G,
         AXI_CONFIG_G    => AXI_CONFIG_G,
         AXI_BURST_G     => AXI_BURST_G,
         AXI_CACHE_G     => AXI_CACHE_G,
         SW_CACHE_EN_G   => true,
         PEND_THRESH_G   => PEND_THRESH_G,
         BYP_SHIFT_G     => BYP_SHIFT_C)
      port map (
         axiClk        => axiClk,
         axiRst        => axiRst,
         dmaReq        => r.rdReq,
         dmaAck        => rdAck,
         swCache       => r.swCache,
         axisMaster    => mAxisMaster,
         axisSlave     => mAxisSlave,
         axisCtrl      => AXI_STREAM_CTRL_UNUSED_C,
         axiReadMaster => axiReadMaster,
         axiReadSlave  => axiReadSlave);

   -------------
   -- Read Queue
   -------------
   U_ReadQueue : entity surf.FifoCascade
      generic map (
         TPD_G           => TPD_G,
         FWFT_EN_G       => true,
         GEN_SYNC_FIFO_G => true,
         MEMORY_TYPE_G   => "block",
         DATA_WIDTH_G    => LOCAL_AXI_READ_DMA_READ_REQ_SIZE_C,
         CASCADE_SIZE_G  => CASCADE_SIZE_C,
         ADDR_WIDTH_G    => ADDR_WIDTH_C)
      port map (
         rst         => rdQueueReset,
         -- Write Interface
         wr_clk      => axiClk,
         wr_en       => r.wrQueueValid,
         almost_full => wrQueueAfull,
         din         => r.wrQueueData,
         -- Read Interface
         rd_clk      => axiClk,
         valid       => rdQueueValid,
         rd_en       => rdQueueReady,
         dout        => rdQueueData);

   comb : process (axiRst, axilReadMaster, axilWriteMaster, r, rdAck,
                   rdQueueData, rdQueueValid, wrAck, wrQueueAfull) is
      variable v        : RegType;
      variable varRdReq : AxiReadDmaReqType;
      variable axilEp   : AxiLiteEndPointType;
   begin
      -- Latch the current value
      v := r;

      -- Init() variables
      varRdReq := AXI_READ_DMA_REQ_INIT_C;

      -- Reset flags
      v.wrQueueValid := '0';
      v.rdQueueReady := '0';
      v.rstCnt       := '0';

      --------------------------------------------------------------------------------

      -- Check if ready for next DMA Write REQ
      if (wrQueueAfull = '0') and (r.wrReq.request = '0') and (wrAck.done = '0') and (wrAck.idle = '1') then

         -- Send the DMA Write REQ
         v.wrReq.request := r.online;

         -- Set base address offset
         v.wrReq.address := r.baseAddr;

         -- Update the address with respect to buffer index
         v.wrReq.address(AXI_BUFFER_WIDTH_G-1 downto MAX_FRAME_WIDTH_G) := r.wrIndex;

         -- Set the max buffer size
         v.wrReq.maxSize := r.maxSize;

      -- Wait for the DMA Write ACK
      elsif (r.wrReq.request = '1') and (wrAck.done = '1') and (r.online = '1') then

         -- Reset the flag
         v.wrReq.request := '0';

         -- Generate the DMA READ REQ (rdReq.address set during the queue reader process)
         varRdReq.size      := wrAck.size;
         varRdReq.firstUser := wrAck.firstUser;
         varRdReq.lastUser  := wrAck.lastUser;
         varRdReq.dest      := wrAck.dest;
         varRdReq.id        := wrAck.id;

         -- Set EOFE if error detected
         varRdReq.lastUser(SSI_EOFE_C) := wrAck.lastUser(SSI_EOFE_C) or wrAck.overflow or wrAck.writeError;

         -- Forward the DMA READ REQ into the read queue
         v.wrQueueValid := '1';
         v.wrQueueData  := localToSlv(varRdReq);

         -- Increment the write index
         v.wrIndex := r.wrIndex + 1;

         -- Check if error in WRITE ACK or AXIS EOFE
         if (varRdReq.lastUser(SSI_EOFE_C) = '1') then

            -- Increment the counter
            v.errorCnt := r.errorCnt + 1;

            -- Check if we drop error AXI stream frames
            if (r.dropOnErr = '1') then

               -- Prevent the DMA READ REQ from going into the read queue
               v.wrQueueValid := '0';

               -- Keep the write index
               v.wrIndex := r.wrIndex;

            end if;

         end if;

      end if;

      --------------------------------------------------------------------------------

      -- Check if ready for next DMA READ REQ
      if (rdQueueValid = '1') and (r.rdReq.request = '0') and (rdAck.done = '0') and (rdAck.idle = '1') then

         -- Accept the FIFO data
         v.rdQueueReady := r.online;

         -- Send the DMA Read REQ
         v.rdReq := localToAxiReadDmaReq(rdQueueData, r.online);

         -- Overwrite address with rdIndex to help optimize the U_ReadQueue logic
         v.rdReq.address                                                := r.baseAddr;
         v.rdReq.address(AXI_BUFFER_WIDTH_G-1 downto MAX_FRAME_WIDTH_G) := r.rdIndex;

         -- Check if adding SOF
         if (r.insertSof = '1') then
            v.rdReq.firstUser(SSI_SOF_C) := '1';
         end if;

      -- Wait for the DMA READ ACK
      elsif (r.rdReq.request = '1') and (rdAck.done = '1') and (r.online = '1') then

         -- Reset the flag
         v.rdReq.request := '0';

         -- Increment the read index
         v.rdIndex := r.rdIndex + 1;

      end if;

      --------------------------------------------------------------------------------

      -- Determine the transaction type
      axiSlaveWaitTxn(axilEp, axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave);

      -- Map the read registers
      axiSlaveRegisterR(axilEp, x"00", 0, toSlv(1, 4));  -- Version 1
      axiSlaveRegister (axilEp, x"00", 4, v.online);
      axiSlaveRegister (axilEp, x"00", 5, v.dropOnErr);
      axiSlaveRegister (axilEp, x"00", 6, v.insertSof);
      axiSlaveRegisterR(axilEp, x"00", 8, START_AFTER_RST_G);
      axiSlaveRegisterR(axilEp, x"00", 9, DROP_ERR_FRAME_G);
      axiSlaveRegisterR(axilEp, x"00", 10, SOF_INSERT_G);
      axiSlaveRegisterR(axilEp, x"00", 12, AXI_CACHE_G);
      axiSlaveRegister (axilEp, x"00", 16, v.swCache);
      axiSlaveRegisterR(axilEp, x"00", 20, AXI_BURST_G);

      axiSlaveRegister (axilEp, x"04", 0, v.maxSize);

      axiSlaveRegister (axilEp, x"20", 0, v.baseAddr);  -- [0x20:0x3F]

      axiSlaveRegisterR(axilEp, x"40", 0, r.frameCnt);

      axiSlaveRegisterR(axilEp, x"80", 0, r.errorCnt);
      axiSlaveRegisterR(axilEp, x"84", 0, r.frameCntMax);

      axiSlaveRegisterR(axilEp, x"C0", 0, toSlv(AXIS_CONFIG_G.TDEST_BITS_C, 8));
      axiSlaveRegisterR(axilEp, x"C0", 8, toSlv(AXIS_CONFIG_G.TID_BITS_C, 8));
      axiSlaveRegisterR(axilEp, x"C0", 16, toSlv(AXIS_CONFIG_G.TUSER_BITS_C, 8));
      axiSlaveRegisterR(axilEp, x"C0", 24, toSlv(AXIS_CONFIG_G.TDATA_BYTES_C, 8));

      axiSlaveRegisterR(axilEp, x"C4", 0, toSlv(AXI_CONFIG_G.LEN_BITS_C, 8));
      axiSlaveRegisterR(axilEp, x"C4", 8, toSlv(AXI_CONFIG_G.ID_BITS_C, 8));
      axiSlaveRegisterR(axilEp, x"C4", 16, toSlv(AXI_CONFIG_G.DATA_BYTES_C, 8));
      axiSlaveRegisterR(axilEp, x"C4", 24, toSlv(AXI_CONFIG_G.ADDR_WIDTH_C, 8));

      axiSlaveRegisterR(axilEp, x"C8", 0, toSlv(MAX_FRAME_WIDTH_G, 8));
      axiSlaveRegisterR(axilEp, x"C8", 8, toSlv(AXI_BUFFER_WIDTH_G, 8));

      axiSlaveRegister (axilEp, x"FC", 0, v.rstCnt);

      -- Closeout the transaction
      axiSlaveDefault(axilEp, v.axilWriteSlave, v.axilReadSlave, AXI_RESP_DECERR_C);

      --------------------------------------------------------------------------------

      -- Update the frame counter (number of AXI frames in the AxiDmaFifo buffer
      v.frameCnt := r.wrIndex - r.rdIndex;

      -- Update the max frame count
      if (r.frameCnt > r.frameCntMax) then
         v.frameCntMax := r.frameCnt;
      end if;

      -- Check for status counter reset
      if r.rstCnt = '1' then
         v.errorCnt    := (others => '0');
         v.frameCntMax := (others => '0');
      end if;

      -- Check for invalid max size
      if (v.maxSize > 2**MAX_FRAME_WIDTH_G) then
         -- Set to max size that's supported by FW build configuration
         v.maxSize := toSlv(2**MAX_FRAME_WIDTH_G, 32);
      end if;

      -- Check for read queue reset
      if (r.online = '0') then

         -- Reset the DMA Write REQ flag
         v.wrReq.request := '0';

         -- Reset index counters
         v.wrIndex := (others => '0');
         v.rdIndex := (others => '0');

      end if;

      --------------------------------------------------------------------------------

      -- Outputs
      axilWriteSlave <= r.axilWriteSlave;
      axilReadSlave  <= r.axilReadSlave;
      rdQueueReady   <= v.rdQueueReady;
      rdQueueRst     <= not(r.online);

      -- Reset
      if (axiRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

   end process comb;

   seq : process (axiClk) is
   begin
      if rising_edge(axiClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   U_rdQueueReset : entity surf.RstPipeline
      generic map (
         TPD_G => TPD_G)
      port map (
         clk    => axiClk,
         rstIn  => rdQueueRst,
         rstOut => rdQueueReset);

end rtl;
