-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
-- Asynchronous bridge for AXI Lite bus. Allows AXI transactions to cross
-- a clock boundary.
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
use surf.AxiLitePkg.all;

entity AxiLiteAsync is
   generic (
      TPD_G            : time                  := 1 ns;
      RST_POLARITY_G   : sl                    := '1';  -- '1' for active HIGH reset, '0' for active LOW reset
      RST_ASYNC_G      : boolean               := false;
      AXI_ERROR_RESP_G : slv(1 downto 0)       := AXI_RESP_SLVERR_C;
      COMMON_CLK_G     : boolean               := false;
      NUM_ADDR_BITS_G  : natural               := 32;
      PIPE_STAGES_G    : integer range 0 to 16 := 0);
   port (
      -- Slave Port
      sAxiClk         : in  sl;
      sAxiClkRst      : in  sl;
      sAxiReadMaster  : in  AxiLiteReadMasterType;
      sAxiReadSlave   : out AxiLiteReadSlaveType;
      sAxiWriteMaster : in  AxiLiteWriteMasterType;
      sAxiWriteSlave  : out AxiLiteWriteSlaveType;
      -- Master Port
      mAxiClk         : in  sl;
      mAxiClkRst      : in  sl;
      mAxiReadMaster  : out AxiLiteReadMasterType;
      mAxiReadSlave   : in  AxiLiteReadSlaveType;
      mAxiWriteMaster : out AxiLiteWriteMasterType;
      mAxiWriteSlave  : in  AxiLiteWriteSlaveType);
end AxiLiteAsync;

architecture STRUCTURE of AxiLiteAsync is

   signal sRst   : sl;                  -- Slave rst sync'd to slave clk
   signal m2sRst : sl;                  -- Master rst sync'd to slave clk

   signal readSlaveToMastDin   : slv(NUM_ADDR_BITS_G+2 downto 0);
   signal readSlaveToMastDout  : slv(NUM_ADDR_BITS_G+2 downto 0);
   signal readSlaveToMastFull  : sl;
   signal readSlaveToMastValid : sl;
   signal readSlaveToMastRead  : sl;
   signal readSlaveToMastWrite : sl;

   signal readMastToSlaveDin   : slv(33 downto 0);
   signal readMastToSlaveDout  : slv(33 downto 0);
   signal readMastToSlaveFull  : sl;
   signal readMastToSlaveValid : sl;
   signal readMastToSlaveRead  : sl;
   signal readMastToSlaveWrite : sl;

   signal writeAddrSlaveToMastDin   : slv(NUM_ADDR_BITS_G+2 downto 0);
   signal writeAddrSlaveToMastDout  : slv(NUM_ADDR_BITS_G+2 downto 0);
   signal writeAddrSlaveToMastFull  : sl;
   signal writeAddrSlaveToMastValid : sl;
   signal writeAddrSlaveToMastRead  : sl;
   signal writeAddrSlaveToMastWrite : sl;

   signal writeDataSlaveToMastDin   : slv(35 downto 0);
   signal writeDataSlaveToMastDout  : slv(35 downto 0);
   signal writeDataSlaveToMastFull  : sl;
   signal writeDataSlaveToMastValid : sl;
   signal writeDataSlaveToMastRead  : sl;
   signal writeDataSlaveToMastWrite : sl;

   signal writeMastToSlaveDin   : slv(1 downto 0);
   signal writeMastToSlaveDout  : slv(1 downto 0);
   signal writeMastToSlaveFull  : sl;
   signal writeMastToSlaveValid : sl;
   signal writeMastToSlaveRead  : sl;
   signal writeMastToSlaveWrite : sl;

   -- Depth of every channel FIFO instantiated below
   constant FIFO_ADDR_WIDTH_C : positive := 4;

   -- Reset terms normalized to active HIGH, independent of RST_POLARITY_G
   signal m2sRstActive  : sl;
   signal mAxiRstActive : sl;

   -- Registered active-HIGH reset request for every FIFO in the bridge
   signal fifoRstReq : sl;
   signal fifoRst    : sl;

   -- Slave side handshakes, kept local so the error responder can observe them
   signal sArReady : sl;
   signal sRValid  : sl;
   signal sAwReady : sl;
   signal sWReady  : sl;
   signal sBValid  : sl;

   type RegType is record
      errMode : sl;                     -- Answering locally with AXI_ERROR_RESP_G
      rPend   : sl;                     -- Read accepted, not yet answered
      awPend  : sl;                     -- Write address accepted, not yet answered
      wPend   : sl;                     -- Write data accepted, not yet answered
   end record RegType;

   constant REG_INIT_C : RegType := (
      errMode => '0',
      rPend   => '0',
      awPend  => '0',
      wPend   => '0');

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   GEN_SYNC : if (COMMON_CLK_G = true) generate

      mAxiReadMaster  <= sAxiReadMaster;
      sAxiReadSlave   <= mAxiReadSlave;
      mAxiWriteMaster <= sAxiWriteMaster;
      sAxiWriteSlave  <= mAxiWriteSlave;

   end generate;

   GEN_ASYNC : if (COMMON_CLK_G = false) generate

      -- Synchronize the local reset release before it controls fifoRst
      LOC_S_RstSync : entity surf.RstSync
         generic map (
            TPD_G          => TPD_G,
            IN_POLARITY_G  => RST_POLARITY_G,
            OUT_POLARITY_G => RST_POLARITY_G)
         port map (
            clk      => sAxiClk,
            asyncRst => sAxiClkRst,
            syncRst  => sRst);

      -- Synchronize the remote reset into the slave/control clock domain
      LOC_M2S_RstSync : entity surf.RstSync
         generic map (
            TPD_G          => TPD_G,
            IN_POLARITY_G  => RST_POLARITY_G,
            OUT_POLARITY_G => RST_POLARITY_G,
            OUT_REG_RST_G  => false)
         port map (
            clk      => sAxiClk,
            asyncRst => mAxiClkRst,
            syncRst  => m2sRst);

      -- Normalize reset indications to active HIGH
      m2sRstActive  <= '1' when (m2sRst = RST_POLARITY_G) else '0';
      mAxiRstActive <= '1' when (mAxiClkRst = RST_POLARITY_G) else '0';

      -- Build one glitch-free FIFO reset request in the slave/control domain.
      -- The local reset asserts it asynchronously, so the FIFOs are reset even
      -- if sAxiClk is stopped.  The remote reset is synchronized above before it
      -- sets this register.  Deassertion is synchronous and delayed until error
      -- mode has drained every abandoned transaction.  FifoAsync then
      -- resynchronizes this single registered request into both FIFO domains.
      fifoRstReq <= m2sRstActive or r.errMode;

      U_FifoRstReg : entity surf.RegisterVector
         generic map (
            TPD_G          => TPD_G,
            RST_POLARITY_G => RST_POLARITY_G,
            RST_ASYNC_G    => true,
            WIDTH_G        => 1,
            INIT_G         => "1")
         port map (
            clk      => sAxiClk,    -- [in]
            rst      => sRst,       -- [in]
            sig_i(0) => fifoRstReq, -- [in]
            reg_o(0) => fifoRst);   -- [out]

      -- Transaction tracking and local error responder.
      --
      -- One transaction per channel is in flight at a time, matching
      -- AxiLiteCrossbar, whose per-slot state machine does not release a slot
      -- until the response completes. The ready outputs below enforce that bound
      -- rather than assuming the master honours it.
      --
      -- The same state decides what the bridge owes the slave side while the
      -- remote domain is in reset, when each access is answered locally instead
      -- of being forwarded. That keeps AXI-Lite ordering intact, because a read
      -- response only follows an accepted AR and a write response only follows
      -- both an accepted AW and W, and it covers the transaction discarded by
      -- fifoRst above, which still owes the slave side a response.
      comb : process (m2sRstActive, r, sArReady, sAwReady, sAxiClkRst,
                      sAxiReadMaster, sAxiWriteMaster, sBValid, sRValid, sWReady) is
         variable v     : RegType;
         variable arTxn : sl;
         variable rTxn  : sl;
         variable awTxn : sl;
         variable wTxn  : sl;
         variable bTxn  : sl;
      begin
         -- Latch the current value
         v := r;

         -- Slave side handshakes
         arTxn := sAxiReadMaster.arvalid and sArReady;
         rTxn  := sRValid and sAxiReadMaster.rready;
         awTxn := sAxiWriteMaster.awvalid and sAwReady;
         wTxn  := sAxiWriteMaster.wvalid and sWReady;
         bTxn  := sBValid and sAxiWriteMaster.bready;

         -- Read accepted but not yet answered. Set and clear are mutually
         -- exclusive because ARREADY is held low while the read is pending.
         if (arTxn = '1') then
            v.rPend := '1';
         elsif (rTxn = '1') then
            v.rPend := '0';
         end if;

         -- Write address accepted but not yet answered
         if (awTxn = '1') then
            v.awPend := '1';
         elsif (bTxn = '1') then
            v.awPend := '0';
         end if;

         -- Write data accepted but not yet answered
         if (wTxn = '1') then
            v.wPend := '1';
         elsif (bTxn = '1') then
            v.wPend := '0';
         end if;

         -- Enter error mode when the remote domain resets and stay there until
         -- the abandoned transaction has been answered
         if (m2sRstActive = '1') then
            v.errMode := '1';
         elsif (v.rPend = '0') and (v.awPend = '0') and (v.wPend = '0') then
            v.errMode := '0';
         end if;

         -- Synchronous Reset
         if (RST_ASYNC_G = false) and (sAxiClkRst = RST_POLARITY_G) then
            v := REG_INIT_C;
         end if;

         -- Register the variable for the next clock cycle
         rin <= v;

      end process comb;

      seq : process (sAxiClk, sAxiClkRst) is
      begin
         if (RST_ASYNC_G) and (sAxiClkRst = RST_POLARITY_G) then
            r <= REG_INIT_C after TPD_G;
         elsif rising_edge(sAxiClk) then
            r <= rin after TPD_G;
         end if;
      end process seq;

      ------------------------------------
      -- Read: Slave to Master
      ------------------------------------

      -- Read Slave To Master FIFO
      U_ReadSlaveToMastFifo : entity surf.FifoASync
         generic map (
            TPD_G          => TPD_G,
            RST_POLARITY_G => '1',
            RST_ASYNC_G    => RST_ASYNC_G,
            MEMORY_TYPE_G  => "distributed",  -- Use Dist Ram
            FWFT_EN_G      => true,
            SYNC_STAGES_G  => 3,
            PIPE_STAGES_G  => PIPE_STAGES_G,
            DATA_WIDTH_G   => NUM_ADDR_BITS_G+3,
            ADDR_WIDTH_G   => FIFO_ADDR_WIDTH_C,
            INIT_G         => "0",
            FULL_THRES_G   => 15,
            EMPTY_THRES_G  => 1)
         port map (
            rst           => fifoRst,
            wr_clk        => sAxiClk,
            wr_en         => readSlaveToMastWrite,
            din           => readSlaveToMastDin,
            wr_data_count => open,
            wr_ack        => open,
            overflow      => open,
            prog_full     => open,
            almost_full   => open,
            full          => readSlaveToMastFull,
            not_full      => open,
            rd_clk        => mAxiClk,
            rd_en         => readSlaveToMastRead,
            dout          => readSlaveToMastDout,
            rd_data_count => open,
            valid         => readSlaveToMastValid,
            underflow     => open,
            prog_empty    => open,
            almost_empty  => open,
            empty         => open
            );

      -- Data In
      readSlaveToMastDin(2 downto 0)                 <= sAxiReadMaster.arprot;
      readSlaveToMastDin(NUM_ADDR_BITS_G+2 downto 3) <= sAxiReadMaster.araddr(NUM_ADDR_BITS_G-1 downto 0);

      -- Write control and ready generation. The request is never queued while the
      -- bridge is answering locally, otherwise an access already reported as
      -- failed would still reach the master side.
      sArReady              <= (not r.rPend) when (r.errMode = '1') else ((not readSlaveToMastFull) and (not r.rPend));
      sAxiReadSlave.arready <= sArReady;
      readSlaveToMastWrite  <= sAxiReadMaster.arvalid and sArReady and (not r.errMode);

      -- Data Out
      mAxiReadMaster.arprot <= readSlaveToMastDout(2 downto 0);

      process (readSlaveToMastDout)
      begin
         mAxiReadMaster.araddr                             <= (others => '0');
         mAxiReadMaster.araddr(NUM_ADDR_BITS_G-1 downto 0) <= readSlaveToMastDout(NUM_ADDR_BITS_G+2 downto 3);
      end process;

      -- Read control and valid
      mAxiReadMaster.arvalid <= readSlaveToMastValid;
      readSlaveToMastRead    <= mAxiReadSlave.arready;

      ------------------------------------
      -- Read: Master To Slave
      ------------------------------------

      -- Read Master To Slave FIFO
      U_ReadMastToSlaveFifo : entity surf.FifoASync
         generic map (
            TPD_G          => TPD_G,
            RST_POLARITY_G => '1',
            RST_ASYNC_G    => RST_ASYNC_G,
            MEMORY_TYPE_G  => "distributed",  -- Use Dist Ram
            FWFT_EN_G      => true,
            SYNC_STAGES_G  => 3,
            PIPE_STAGES_G  => PIPE_STAGES_G,
            DATA_WIDTH_G   => 34,
            ADDR_WIDTH_G   => FIFO_ADDR_WIDTH_C,
            INIT_G         => "0",
            FULL_THRES_G   => 15,
            EMPTY_THRES_G  => 1)
         port map (
            rst           => fifoRst,
            wr_clk        => mAxiClk,
            wr_en         => readMastToSlaveWrite,
            din           => readMastToSlaveDin,
            wr_data_count => open,
            wr_ack        => open,
            overflow      => open,
            prog_full     => open,
            almost_full   => open,
            full          => readMastToSlaveFull,
            not_full      => open,
            rd_clk        => sAxiClk,
            rd_en         => readMastToSlaveRead,
            dout          => readMastToSlaveDout,
            rd_data_count => open,
            valid         => readMastToSlaveValid,
            underflow     => open,
            prog_empty    => open,
            almost_empty  => open,
            empty         => open
            );

      -- Data In
      readMastToSlaveDin(1 downto 0)  <= mAxiReadSlave.rresp;
      readMastToSlaveDin(33 downto 2) <= mAxiReadSlave.rdata;

      -- Write control and ready generation
      mAxiReadMaster.rready <= '1' when (mAxiRstActive = '1') else (not readMastToSlaveFull);
      readMastToSlaveWrite  <= mAxiReadSlave.rvalid and (not readMastToSlaveFull);

      -- Data Out
      sAxiReadSlave.rresp <= AXI_ERROR_RESP_G when (r.errMode = '1') else readMastToSlaveDout(1 downto 0);
      sAxiReadSlave.rdata <= readMastToSlaveDout(33 downto 2);

      -- Read control and valid. Answering locally requires an accepted AR, so the
      -- response can never arrive ahead of its request.
      sRValid              <= r.rPend when (r.errMode = '1') else readMastToSlaveValid;
      sAxiReadSlave.rvalid <= sRValid;
      readMastToSlaveRead  <= sAxiReadMaster.rready;

      ------------------------------------
      -- Write Addr : Slave To Master
      ------------------------------------

      -- Write Addr Master To Slave FIFO
      U_WriteAddrSlaveToMastFifo : entity surf.FifoASync
         generic map (
            TPD_G          => TPD_G,
            RST_POLARITY_G => '1',
            RST_ASYNC_G    => RST_ASYNC_G,
            MEMORY_TYPE_G  => "distributed",  -- Use Dist Ram
            FWFT_EN_G      => true,
            SYNC_STAGES_G  => 3,
            PIPE_STAGES_G  => PIPE_STAGES_G,
            DATA_WIDTH_G   => NUM_ADDR_BITS_G+3,
            ADDR_WIDTH_G   => FIFO_ADDR_WIDTH_C,
            INIT_G         => "0",
            FULL_THRES_G   => 15,
            EMPTY_THRES_G  => 1)
         port map (
            rst           => fifoRst,
            wr_clk        => sAxiClk,
            wr_en         => writeAddrSlaveToMastWrite,
            din           => writeAddrSlaveToMastDin,
            wr_data_count => open,
            wr_ack        => open,
            overflow      => open,
            prog_full     => open,
            almost_full   => open,
            full          => writeAddrSlaveToMastFull,
            not_full      => open,
            rd_clk        => mAxiClk,
            rd_en         => writeAddrSlaveToMastRead,
            dout          => writeAddrSlaveToMastDout,
            rd_data_count => open,
            valid         => writeAddrSlaveToMastValid,
            underflow     => open,
            prog_empty    => open,
            almost_empty  => open,
            empty         => open
            );

      -- Data In
      writeAddrSlaveToMastDin(2 downto 0)                 <= sAxiWriteMaster.awprot;
      writeAddrSlaveToMastDin(NUM_ADDR_BITS_G+2 downto 3) <= sAxiWriteMaster.awaddr(NUM_ADDR_BITS_G-1 downto 0);

      -- Write control and ready generation
      sAwReady                  <= (not r.awPend) when (r.errMode = '1') else ((not writeAddrSlaveToMastFull) and (not r.awPend));
      sAxiWriteSlave.awready    <= sAwReady;
      writeAddrSlaveToMastWrite <= sAxiWriteMaster.awvalid and sAwReady and (not r.errMode);

      -- Data Out
      mAxiWriteMaster.awprot <= writeAddrSlaveToMastDout(2 downto 0);

      process (writeAddrSlaveToMastDout)
      begin
         mAxiWriteMaster.awaddr                             <= (others => '0');
         mAxiWriteMaster.awaddr(NUM_ADDR_BITS_G-1 downto 0) <= writeAddrSlaveToMastDout(NUM_ADDR_BITS_G+2 downto 3);
      end process;

      -- Read control and valid
      mAxiWriteMaster.awvalid  <= writeAddrSlaveToMastValid;
      writeAddrSlaveToMastRead <= mAxiWriteSlave.awready;

      ------------------------------------
      -- Write Data : Slave to Master
      ------------------------------------

      -- Write Data Slave To Master FIFO
      U_WriteDataSlaveToMastFifo : entity surf.FifoASync
         generic map (
            TPD_G          => TPD_G,
            RST_POLARITY_G => '1',
            RST_ASYNC_G    => RST_ASYNC_G,
            MEMORY_TYPE_G  => "distributed",  -- Use Dist Ram
            FWFT_EN_G      => true,
            SYNC_STAGES_G  => 3,
            PIPE_STAGES_G  => PIPE_STAGES_G,
            DATA_WIDTH_G   => 36,
            ADDR_WIDTH_G   => FIFO_ADDR_WIDTH_C,
            INIT_G         => "0",
            FULL_THRES_G   => 15,
            EMPTY_THRES_G  => 1)
         port map (
            rst           => fifoRst,
            wr_clk        => sAxiClk,
            wr_en         => writeDataSlaveToMastWrite,
            din           => writeDataSlaveToMastDin,
            wr_data_count => open,
            wr_ack        => open,
            overflow      => open,
            prog_full     => open,
            almost_full   => open,
            full          => writeDataSlaveToMastFull,
            not_full      => open,
            rd_clk        => mAxiClk,
            rd_en         => writeDataSlaveToMastRead,
            dout          => writeDataSlaveToMastDout,
            rd_data_count => open,
            valid         => writeDataSlaveToMastValid,
            underflow     => open,
            prog_empty    => open,
            almost_empty  => open,
            empty         => open
            );

      -- Data In
      writeDataSlaveToMastDin(3 downto 0)  <= sAxiWriteMaster.wstrb;
      writeDataSlaveToMastDin(35 downto 4) <= sAxiWriteMaster.wdata;

      -- Write control and ready generation
      sWReady                   <= (not r.wPend) when (r.errMode = '1') else ((not writeDataSlaveToMastFull) and (not r.wPend));
      sAxiWriteSlave.wready     <= sWReady;
      writeDataSlaveToMastWrite <= sAxiWriteMaster.wvalid and sWReady and (not r.errMode);

      -- Data Out
      mAxiWriteMaster.wstrb <= writeDataSlaveToMastDout(3 downto 0);
      mAxiWriteMaster.wdata <= writeDataSlaveToMastDout(35 downto 4);

      -- Read control and valid
      mAxiWriteMaster.wvalid   <= writeDataSlaveToMastValid;
      writeDataSlaveToMastRead <= mAxiWriteSlave.wready;

      ------------------------------------
      -- Write: Status Master To Slave
      ------------------------------------

      -- Write Status Master To Slave FIFO
      U_WriteMastToSlaveFifo : entity surf.FifoASync
         generic map (
            TPD_G          => TPD_G,
            RST_POLARITY_G => '1',
            RST_ASYNC_G    => RST_ASYNC_G,
            MEMORY_TYPE_G  => "distributed",  -- Use Dist Ram
            FWFT_EN_G      => true,
            SYNC_STAGES_G  => 3,
            PIPE_STAGES_G  => PIPE_STAGES_G,
            DATA_WIDTH_G   => 2,
            ADDR_WIDTH_G   => FIFO_ADDR_WIDTH_C,
            INIT_G         => "0",
            FULL_THRES_G   => 15,
            EMPTY_THRES_G  => 1)
         port map (
            rst           => fifoRst,
            wr_clk        => mAxiClk,
            wr_en         => writeMastToSlaveWrite,
            din           => writeMastToSlaveDin,
            wr_data_count => open,
            wr_ack        => open,
            overflow      => open,
            prog_full     => open,
            almost_full   => open,
            full          => writeMastToSlaveFull,
            not_full      => open,
            rd_clk        => sAxiClk,
            rd_en         => writeMastToSlaveRead,
            dout          => writeMastToSlaveDout,
            rd_data_count => open,
            valid         => writeMastToSlaveValid,
            underflow     => open,
            prog_empty    => open,
            almost_empty  => open,
            empty         => open
            );

      -- Data In
      writeMastToSlaveDin <= mAxiWriteSlave.bresp;

      -- Write control and ready generation
      mAxiWriteMaster.bready <= not writeMastToSlaveFull;
      writeMastToSlaveWrite  <= mAxiWriteSlave.bvalid and (not writeMastToSlaveFull);

      -- Data Out
      sAxiWriteSlave.bresp <= AXI_ERROR_RESP_G when (r.errMode = '1') else writeMastToSlaveDout;

      -- Read control and valid. Answering locally requires both an accepted AW and
      -- an accepted W, so the two channels can still arrive in either order.
      sBValid               <= (r.awPend and r.wPend) when (r.errMode = '1') else writeMastToSlaveValid;
      sAxiWriteSlave.bvalid <= sBValid;
      writeMastToSlaveRead  <= sAxiWriteMaster.bready;

   end generate;

end architecture STRUCTURE;
