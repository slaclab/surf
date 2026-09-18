-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Coherent PHC snapshot mailbox for an independent reader clock.
--
-- Transfers a reader request into the PHC domain through a SURF asynchronous
-- FIFO, captures time and status together on one PHC edge, and returns that
-- immutable snapshot through a second FIFO. The response contains seconds,
-- nanoseconds, fractional nanoseconds, generation, raw ticks and validity.
-- readRequest is accepted only with readReady; readValid pulses when the
-- response is published, with readSequence identifying the local request.
--
-- Only one request is outstanding. Each FIFO write is retained until its write
-- acknowledgement, allowing requests and responses to survive a stopped peer
-- clock or delayed reset recovery. Reset from either side cancels both
-- directions of the mailbox session; SURF reset synchronizers release each
-- domain locally. A read-side reset never resets the PHC itself.
--
-- This optional block provides an observation snapshot, not a continuously
-- advancing clock replica. It is instantiated separately from PtpEndpoint's
-- same-clock AXI-Lite snapshots. Consumers must qualify returned data with
-- readValid and interpret time validity and generation from that snapshot.
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
use ieee.numeric_std.all;

library surf;
use surf.StdRtlPkg.all;
use surf.PtpPkg.all;

entity PtpPhcRead is
   generic (
      TPD_G : time := 1 ns);
   port (
      -- PHC clock domain and snapshot source.
      phcClk         : in  sl;
      phcRst         : in  sl;
      phcTime        : in  PtpTimeType;
      phcStatus      : in  PtpPhcStatusType;
      captureAbort   : in  sl;

      -- Independent reader clock domain and request/response interface.
      readClk        : in  sl;
      readRst        : in  sl;
      readRequest    : in  sl;
      readReady      : out sl;
      readValid      : out sl;
      readTime       : out PtpTimeType;
      readGeneration : out slv(31 downto 0);
      readTicks      : out slv(63 downto 0);
      readTimeValid  : out sl;
      readSequence   : out slv(31 downto 0));
end entity PtpPhcRead;

architecture rtl of PtpPhcRead is

   -- Private FIFO layout, least significant field first. Both packing and
   -- unpacking use these boundaries; time/status field widths own the size.
   constant VALID_BIT_C       : natural := 0;
   constant TICKS_LOW_C       : natural := VALID_BIT_C+1;
   constant GENERATION_LOW_C  : natural := TICKS_LOW_C+PTP_PHC_STATUS_INIT_C.ticks'length;
   constant FRACTION_LOW_C    : natural := GENERATION_LOW_C+PTP_PHC_STATUS_INIT_C.generation'length;
   constant NANOSECONDS_LOW_C : natural := FRACTION_LOW_C+PTP_TIME_INIT_C.fraction'length;
   constant SECONDS_LOW_C     : natural := NANOSECONDS_LOW_C+PTP_TIME_INIT_C.nanoseconds'length;
   constant WIDTH_C           : positive := SECONDS_LOW_C+PTP_TIME_INIT_C.seconds'length;

   -- Retain four storage locations for each small distributed CDC FIFO.
   -- This is a storage choice, not request concurrency: busy admits only one
   -- transaction until its response returns, regardless of FIFO capacity.
   constant FIFO_ADDR_BITS_C : positive := 2;

   signal reset         : sl;
   signal localReset    : sl;
   signal phcReset      : sl;
   signal requestAck    : sl;
   signal responseTake  : sl;
   signal responseWrite : sl;
   signal responseAck   : sl;
   signal requestFull   : sl;
   signal requestValid  : sl;
   signal requestWrite  : sl;
   signal requestTake   : sl;
   signal responseFull  : sl;
   signal responseValid : sl;
   signal responseData  : slv(WIDTH_C-1 downto 0);

   type RegType is record
      -- Current-edge request admission, published from v.
      readReady      : sl;
      busy           : sl;
      requestPending : sl;
      valid          : sl;
      sequenceId     : unsigned(31 downto 0);
      data           : slv(WIDTH_C-1 downto 0);
   end record;

   constant REG_INIT_C : RegType := (
      readReady      => '0',
      busy           => '0',
      requestPending => '0',
      valid          => '0',
      sequenceId     => (others => '0'),
      data           => (others => '0'));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   type PhcRegType is record
      pending : sl;
      data    : slv(WIDTH_C-1 downto 0);
   end record;

   constant PHC_REG_INIT_C : PhcRegType := (
      pending => '0',
      data    => (others => '0'));

   signal p   : PhcRegType := PHC_REG_INIT_C;
   signal pin : PhcRegType;

begin

   -- Either domain reset cancels the entire mailbox session, including both
   -- FIFO directions. Assertion reaches stopped domains asynchronously; local
   -- release uses SURF reset synchronizers. A read-side reset never resets PHC.
   reset <= phcRst or readRst;

   U_ReadReset : entity surf.RstSync
      generic map (
         TPD_G => TPD_G)
      port map (
         clk      => readClk,      -- [in]
         asyncRst => reset,        -- [in]
         syncRst  => localReset);  -- [out]

   U_PhcReset : entity surf.RstSync
      generic map (
         TPD_G => TPD_G)
      port map (
         clk      => phcClk,     -- [in]
         asyncRst => reset,      -- [in]
         syncRst  => phcReset);  -- [out]

   U_Request : entity surf.FifoAsync
      generic map (
         TPD_G         => TPD_G,
         RST_ASYNC_G   => true,
         MEMORY_TYPE_G => "distributed",
         FWFT_EN_G     => true,
         DATA_WIDTH_G  => 1,
         ADDR_WIDTH_G  => FIFO_ADDR_BITS_C)
      port map (
         rst           => reset,         -- [in]
         wr_clk        => readClk,       -- [in]
         wr_en         => requestWrite,  -- [in]
         din           => "1",           -- [in]
         wr_data_count => open,          -- [out]
         wr_ack        => requestAck,    -- [out]
         overflow      => open,          -- [out]
         prog_full     => open,          -- [out]
         almost_full   => open,          -- [out]
         full          => requestFull,   -- [out]
         not_full      => open,          -- [out]
         rd_clk        => phcClk,        -- [in]
         rd_en         => requestTake,   -- [in]
         dout          => open,          -- [out]
         rd_data_count => open,          -- [out]
         valid         => requestValid,  -- [out]
         underflow     => open,          -- [out]
         prog_empty    => open,          -- [out]
         almost_empty  => open,          -- [out]
         empty         => open);         -- [out]

   U_Response : entity surf.FifoAsync
      generic map (
         TPD_G         => TPD_G,
         RST_ASYNC_G   => true,
         MEMORY_TYPE_G => "distributed",
         FWFT_EN_G     => true,
         DATA_WIDTH_G  => WIDTH_C,
         ADDR_WIDTH_G  => FIFO_ADDR_BITS_C)
      port map (
         rst           => reset,          -- [in]
         wr_clk        => phcClk,         -- [in]
         wr_en         => responseWrite,  -- [in]
         din           => p.data,         -- [in]
         wr_data_count => open,           -- [out]
         wr_ack        => responseAck,    -- [out]
         overflow      => open,           -- [out]
         prog_full     => open,           -- [out]
         almost_full   => open,           -- [out]
         full          => responseFull,   -- [out]
         not_full      => open,           -- [out]
         rd_clk        => readClk,        -- [in]
         rd_en         => responseTake,   -- [in]
         dout          => responseData,   -- [out]
         rd_data_count => open,           -- [out]
         valid         => responseValid,  -- [out]
         underflow     => open,           -- [out]
         prog_empty    => open,           -- [out]
         almost_empty  => open,           -- [out]
         empty         => open);          -- [out]

   comb : process (r, readRequest, requestAck, requestFull, responseValid,
                   responseData, localReset, reset) is
      variable v               : RegType;
      variable requestWriteNow : sl;
      variable responseTakeNow : sl;
      variable readValidNow    : sl;
   begin
      v := r;

      -- Retire a FIFO write only on its acknowledgement. A non-full FIFO may
      -- still be waiting for the other clock domain to finish reset recovery.
      v.valid := '0';
      if requestAck = '1' then
         v.requestPending := '0';
      end if;

      -- Accept one application request, then keep its FIFO token pending until
      -- acknowledged. Test r.busy so a returning response cannot admit a new
      -- request on the same edge and reuse its completion sequence.
      v.readReady     := '0';
      requestWriteNow := '0';
      responseTakeNow := '0';
      if localReset = '0' and reset = '0' then
         if r.busy = '0' and r.sequenceId /= x"FFFFFFFF" then
            v.readReady := '1';
            if readRequest = '1' then
               v.requestPending := '1';
               v.busy           := '1';
               v.sequenceId     := r.sequenceId + 1;
            end if;
         end if;
         if r.requestPending = '1' and requestAck = '0' and requestFull = '0' then
            requestWriteNow := '1';
         end if;

         -- Capture a returning response only for the outstanding request.
         if responseValid = '1' and r.busy = '1' then
            responseTakeNow := '1';
            v.data          := responseData;
            v.valid         := '1';
            v.busy          := '0';
         end if;
      end if;

      -- Reset must withdraw a published response even with a stopped clock.
      -- Keep this immediate session cancellation separate from payload storage.
      readValidNow := r.valid and not localReset and not reset;

      rin                  <= v;
      readReady            <= v.readReady;
      requestWrite         <= requestWriteNow;
      responseTake         <= responseTakeNow;
      readValid            <= readValidNow;
      readTime.seconds     <= r.data(WIDTH_C-1 downto SECONDS_LOW_C);
      readTime.nanoseconds <= r.data(SECONDS_LOW_C-1 downto NANOSECONDS_LOW_C);
      readTime.fraction    <= r.data(NANOSECONDS_LOW_C-1 downto FRACTION_LOW_C);
      readGeneration       <= r.data(FRACTION_LOW_C-1 downto GENERATION_LOW_C);
      readTicks            <= r.data(GENERATION_LOW_C-1 downto TICKS_LOW_C);
      readTimeValid        <= r.data(VALID_BIT_C);
      readSequence         <= slv(r.sequenceId);
   end process comb;

   phcComb : process (p, requestValid, responseAck, responseFull, captureAbort,
                      phcReset, reset, phcTime, phcStatus) is
      variable v                : PhcRegType;
      variable requestTakeNow   : sl;
      variable responseWriteNow : sl;
   begin
      v := p;

      -- Hold a captured response through FIFO reset recovery/backpressure.
      if responseAck = '1' then
         v.pending := '0';
      end if;
      requestTakeNow   := '0';
      responseWriteNow := '0';
      if phcReset = '0' and reset = '0' then
         if p.pending = '1' then
            if responseAck = '0' and responseFull = '0' then
               responseWriteNow := '1';
            end if;
         elsif requestValid = '1' and captureAbort = '0' then
            -- Sample all fields at this PHC edge. A discontinuity defers the
            -- request; it cannot produce a partially old/new snapshot.
            requestTakeNow                                    := '1';
            v.pending                                         := '1';
            v.data(WIDTH_C-1 downto SECONDS_LOW_C)            := phcTime.seconds;
            v.data(SECONDS_LOW_C-1 downto NANOSECONDS_LOW_C)  := phcTime.nanoseconds;
            v.data(NANOSECONDS_LOW_C-1 downto FRACTION_LOW_C) := phcTime.fraction;
            v.data(FRACTION_LOW_C-1 downto GENERATION_LOW_C)  := phcStatus.generation;
            v.data(GENERATION_LOW_C-1 downto TICKS_LOW_C)     := phcStatus.ticks;
            v.data(VALID_BIT_C)                               := phcStatus.timeValid;
         end if;
      end if;
      pin           <= v;
      requestTake   <= requestTakeNow;
      responseWrite <= responseWriteNow;
   end process phcComb;

   phcSeq : process (phcClk, phcReset) is
   begin
      if phcReset = '1' then
         p <= PHC_REG_INIT_C after TPD_G;
      elsif rising_edge(phcClk) then
         p <= pin after TPD_G;
      end if;
   end process phcSeq;
   seq : process (readClk, localReset) is
   begin
      if localReset = '1' then
         r <= REG_INIT_C after TPD_G;
      elsif rising_edge(readClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end architecture rtl;
