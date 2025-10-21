-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
-- Block serves as an FIFO that buffers a user-selectable number of frames
-- (defined by TLAST). Useful for benchmarking latency of IPs.
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
use surf.AxiStreamPkg.all;
use surf.AxiLitePkg.all;

entity AxiStreamBatchingFifo is
   generic (
        -- General Configurations
      TPD_G               : time                  := 1 ns;
      FIFO_ADDR_WIDTH_G   : integer range 4 to 48 := 9;
        -- AXI Stream Port Configurations
      SLAVE_AXI_CONFIG_G  : AxiStreamConfigType;
      MASTER_AXI_CONFIG_G : AxiStreamConfigType);
   port (
        -- Control Port
      axilClk          : in  sl;
      axilRst          : in  sl;
      sAxilWriteMaster : in  AxiLiteWriteMasterType;
      sAxilWriteSlave  : out AxiLiteWriteSlaveType;
      sAxilReadMaster  : in  AxiLiteReadMasterType;
      sAxilReadSlave   : out AxiLiteReadSlaveType;

        -- Slave Port
      sAxisClk         : in  sl;
      sAxisRst         : in  sl;
      sAxisMaster      : in  AxiStreamMasterType;
      sAxisSlave       : out AxiStreamSlaveType;

        -- Master Port
      mAxisClk         : in  sl;
      mAxisRst         : in  sl;
      mAxisMaster      : out AxiStreamMasterType;
      mAxisSlave       : in  AxiStreamSlaveType);
end AxiStreamBatchingFifo;

architecture rtl of AxiStreamBatchingFifo is

   signal batchSizeAxiL   : slv(31 downto 0);
   signal batchSize       : slv(31 downto 0);

   signal axisMasterSync : AxiStreamMasterType;
   signal axisSlaveSync  : AxiStreamSlaveType;

   signal axisMasterFifo : AxiStreamMasterType;
   signal axisSlaveFifo  : AxiStreamSlaveType;

   type RegType is record
      frameBatched : slv(31 downto 0);
      frameToSend  : slv(31 downto 0);
      sending      : sl;
   end record;

   constant REG_INIT_C : RegType := (
      frameBatched => (others => '0'),
      frameToSend  => (others => '0'),
      sending      => '0'
    );

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal rAxilWriteSlave   : AxiLiteWriteSlaveType := AXI_LITE_WRITE_SLAVE_INIT_C;
   signal rAxilReadSlave    : AxiLiteReadSlaveType  := AXI_LITE_READ_SLAVE_INIT_C;
   signal rinAxilWriteSlave : AxiLiteWriteSlaveType := AXI_LITE_WRITE_SLAVE_INIT_C;
   signal rinAxilReadSlave  : AxiLiteReadSlaveType  := AXI_LITE_READ_SLAVE_INIT_C;

   signal combAxisMaster : AxiStreamMasterType;
   signal combAxisSlave  : AxiStreamSlaveType;

begin

    ----------------------------------
    ------- CONTROL  INTERFACE -------
    ----------------------------------

   comb_axil : process (sAxilReadMaster, sAxilWriteMaster, axilRst, rAxilWriteSlave, rAxilReadSlave) is
      variable vAxilWriteSlave : AxiLiteWriteSlaveType := AXI_LITE_WRITE_SLAVE_INIT_C;
      variable vAxilReadSlave  : AxiLiteReadSlaveType  := AXI_LITE_READ_SLAVE_INIT_C;
      variable regCon          : AxiLiteEndPointType;
      variable vBatchSize      : slv(31 downto 0);
   begin

      -- Latch input values
      vAxilWriteSlave := rAxilWriteSlave;
      vAxilReadSlave  := rAxilReadSlave;

      -- Determine the transaction type
      axiSlaveWaitTxn(regCon, sAxilWriteMaster, sAxilReadMaster, vAxilWriteSlave, vAxilReadSlave);

      -- Read batch size
      axiSlaveRegister(regCon, "0000", 0, vBatchSize); -- 2-bit wide because only one reg

      -- Closeout the transaction
      axiSlaveDefault(regCon, vAxilWriteSlave, vAxilReadSlave, AXI_RESP_DECERR_C);

      -- Synchronous reset
      if (axilRst = '1') then
         vAxilWriteSlave := AXI_LITE_WRITE_SLAVE_INIT_C;
         vAxilReadSlave  := AXI_LITE_READ_SLAVE_INIT_C;
      end if;

      -- Combinatory output
      rinAxilReadSlave  <= vAxilReadSlave;
      rinAxilWriteSlave <= vAxilWriteSlave;
      batchSizeAxiL     <= vBatchSize;

      -- Outputs
      sAxilReadSlave  <= rAxilReadSlave;
      sAxilWriteSlave <= rAxilWriteSlave;
   end process comb_axil;

   seq_axil : process (axilClk) is
   begin
      if rising_edge(axilClk) then
         rAxilReadSlave  <= rinAxilReadSlave  after TPD_G;
         rAxilWriteSlave <= rinAxilWriteSlave after TPD_G;
      end if;
   end process seq_axil;

    ----------------------------------
    ----- END CONTROL  INTERFACE -----
    ----------------------------------


    ----------------------------------
    ----- CLOCK DOMAIN CROSSINGS -----
    ----------------------------------
    -- All control signals need to be brought into the mAxisClk domain
    -- State of the main FIFO becomes more consistent

   U_Axis_CDC : entity surf.AxiStreamFifoV2
      generic map(
         TPD_G               => TPD_G,
         MEMORY_TYPE_G       => "auto",
         GEN_SYNC_FIFO_G     => false,
         FIFO_ADDR_WIDTH_G   => 5,                  -- Shallow, just for sync
         SLAVE_AXI_CONFIG_G  => SLAVE_AXI_CONFIG_G,
         MASTER_AXI_CONFIG_G => SLAVE_AXI_CONFIG_G) -- Do not change shape
      port map(
         sAxisClk    => sAxisClk,
         sAxisRst    => sAxisRst,
         sAxisMaster => sAxisMaster,
         sAxisSlave  => sAxisSlave,

         mAxisClk    => mAxisClk,
         mAxisRst    => mAxisRst,
         mAxisMaster => axisMasterSync,
         mAxisSlave  => axisSlaveSync );

   U_BatchSize_CDC : entity surf.SynchronizerFifo
      generic map(
         TPD_G        => TPD_G,
         DATA_WIDTH_G => 32,
         INIT_G       => x"0000_0001")
      port map(
         wr_clk  => axilClk,
         din     => batchSizeAxiL,
         rd_clk  => mAxisClk,
         dout    => batchSize);

    ----------------------------------
    --- END CLOCK DOMAIN CROSSINGS ---
    ----------------------------------


    ----------------------------------
    --------- MAIN DATA FIFO ---------
    ----------------------------------

   U_Data_FIFO : entity surf.AxiStreamFifoV2
      generic map(
         TPD_G               => TPD_G,
         FIFO_ADDR_WIDTH_G   => FIFO_ADDR_WIDTH_G,
         GEN_SYNC_FIFO_G     => true,
         SLAVE_AXI_CONFIG_G  => SLAVE_AXI_CONFIG_G,
         MASTER_AXI_CONFIG_G => MASTER_AXI_CONFIG_G)
      port map(
            -- Slave Port
         sAxisClk    => mAxisClk,
         sAxisRst    => mAxisRst,
         sAxisMaster => axisMasterSync,
         sAxisSlave  => axisSlaveSync,

            -- Master Port
         mAxisClk    => mAxisClk,
         mAxisRst    => mAxisRst,
         mAxisMaster => axisMasterFifo,
         mAxisSlave  => axisSlaveFifo );

    ----------------------------------
    ------- END MAIN DATA FIFO -------
    ----------------------------------

    -- These signals are not responsible for hanshakes and can
    -- just be forwarded
   combAxisMaster.tData <= axisMasterFifo.tData;
   combAxisMaster.tStrb <= axisMasterFifo.tStrb;
   combAxisMaster.tKeep <= axisMasterFifo.tKeep;
   combAxisMaster.tLast <= axisMasterFifo.tLast;
   combAxisMaster.tDest <= axisMasterFifo.tDest;
   combAxisMaster.tId   <= axisMasterFifo.tId;
   combAxisMaster.tUser <= axisMasterFifo.tUser;

   comb : process (r, axisMasterFifo, axisSlaveFifo, axisMasterSync, axisSlaveSync, batchSize, combAxisSlave) is
      variable v               : RegType;
      variable isAcceptedFrame : sl;
      variable isOutputFrame   : sl;
   begin
      -- Latch current state
      v := r;

      -- Check if there is a frame accepted
      isAcceptedFrame := axisMasterSync.tValid and axisMasterSync.tLast and axisSlaveSync.tReady;
      isOutputFrame   := r.sending and axisMasterFifo.tValid and axisMasterFifo.tLast and axisSlaveFifo.tReady;

      -- Update counters
      if isAcceptedFrame = '1' then
         v.frameBatched := r.frameBatched + 1;
      else
         v.frameBatched := r.frameBatched;
      end if;

      if isOutputFrame = '1' then
         v.frameBatched := v.frameBatched - 1;
         v.frameToSend  := r.frameToSend  - 1;
      end if;

      if v.frameToSend = 0 then
         v.sending := '0';
      end if;

      if r.sending = '0' and r.frameBatched >= batchSize then
         v.sending     := '1';
         v.frameToSend := batchSize;
      end if;

      combAxisMaster.tValid   <= r.sending and axisMasterFifo.tValid;
      axisSlaveFifo.tReady <= r.sending and combAxisSlave.tReady;

      rin <= v;
   end process comb;

   seq : process(mAxisClk) is
   begin
      if rising_edge(mAxisClk) then
         if mAxisRst = '1' then
            r <= REG_INIT_C after TPD_G;
         else
            r <= rin after TPD_G;
         end if;
      end if;
   end process seq;

   -- Avoid having combinatorial outputs on the output
   -- AxiStream by adding a pipeline stage
   U_Output_Pipeline : entity surf.AxiStreamPipeline
      generic map(
         TPD_G             => TPD_G)
      port map(
         axisClk => mAxisClk,
         axisRst => mAxisRst,

         sAxisMaster => combAxisMaster,
         sAxisSlave  => combAxisSlave,

         mAxisMaster => mAxisMaster,
         mAxisSlave  => mAxisSlave);

end rtl;
