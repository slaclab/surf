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
      phcClk         : in  sl;
      phcRst         : in  sl;
      phcTime        : in  PtpTimeType;
      phcStatus      : in  PtpPhcStatusType;
      captureAbort   : in  sl;
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

   constant WIDTH_C : positive := 209;

   signal reset         : sl;
   signal localReset    : sl;
   signal phcReset      : sl;
   signal requestAccept : sl;
   signal requestAck    : sl;
   signal responseWrite : sl;
   signal responseAck   : sl;
   signal requestFull   : sl;
   signal requestValid  : sl;
   signal requestWrite  : sl;
   signal requestTake   : sl;
   signal responseFull  : sl;
   signal responseValid : sl;
   signal responseTake  : sl;
   signal responseData  : slv(WIDTH_C-1 downto 0);
   signal snapshot      : slv(WIDTH_C-1 downto 0);

   type RegType is record
      busy           : sl;
      requestPending : sl;
      valid          : sl;
      sequenceId     : unsigned(31 downto 0);
      data           : slv(WIDTH_C-1 downto 0);
   end record;

   constant REG_INIT_C : RegType := (
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

   -- FIFO full alone does not prove its opposite clock domain has completed
   -- reset recovery. Hold each write until wr_ack, which also handles a stopped
   -- peer clock; suppress the next write while that acknowledgement is visible.
   readReady     <= not r.busy and not localReset and not reset
      when r.sequenceId /= x"FFFFFFFF" else '0';
   requestAccept <= readRequest and not r.busy and not localReset and not reset
      when r.sequenceId /= x"FFFFFFFF" else '0';
   requestWrite  <= r.requestPending and not requestAck and not requestFull and not localReset and not reset;
   requestTake   <= requestValid and not p.pending and not captureAbort and not phcReset and not reset;
   responseWrite <= p.pending and not responseAck and not responseFull and not phcReset and not reset;
   responseTake  <= responseValid and r.busy and not localReset and not reset;
   snapshot      <= phcTime.seconds & phcTime.nanoseconds & phcTime.fraction &
      phcStatus.generation & phcStatus.ticks & phcStatus.timeValid;

   U_Request : entity surf.FifoAsync
      generic map (
         TPD_G         => TPD_G,
         RST_ASYNC_G   => true,
         MEMORY_TYPE_G => "distributed",
         FWFT_EN_G     => true,
         DATA_WIDTH_G  => 1,
         ADDR_WIDTH_G  => 2)
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
         ADDR_WIDTH_G  => 2)
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

   comb : process (r, requestAccept, requestAck, responseTake, responseData) is
      variable v : RegType;
   begin
      v := r;

      v.valid := '0';
      if requestAck = '1' then
         v.requestPending := '0';
      end if;
      if requestAccept = '1' then
         v.requestPending := '1';
         v.busy           := '1';
         v.sequenceId     := r.sequenceId + 1;
      end if;
      if responseTake = '1' then
         v.data  := responseData;
         v.valid := '1';
         v.busy  := '0';
      end if;
      rin <= v;
   end process comb;
   phcComb : process (p, requestTake, responseAck, snapshot) is
      variable v : PhcRegType;
   begin
      v := p;
      if responseAck = '1' then
         v.pending := '0';
      end if;
      if requestTake = '1' then
         v.pending := '1';
         v.data    := snapshot;
      end if;
      pin <= v;
   end process phcComb;
   phcSeq : process (phcClk, phcReset) is
   begin
      if phcReset = '1' then
         p <= PHC_REG_INIT_C after TPD_G;
      elsif rising_edge(phcClk) then
         p <= pin after TPD_G;
      end if;
   end process phcSeq;
   readValid            <= r.valid and not localReset and not reset;
   readTime.seconds     <= r.data(208 downto 161);
   readTime.nanoseconds <= r.data(160 downto 129);
   readTime.fraction    <= r.data(128 downto 97);
   readGeneration       <= r.data(96 downto 65);
   readTicks            <= r.data(64 downto 1);
   readTimeValid        <= r.data(0);
   readSequence         <= slv(r.sequenceId);
   seq : process (readClk, localReset) is
   begin
      if localReset = '1' then
         r <= REG_INIT_C after TPD_G;
      elsif rising_edge(readClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end architecture rtl;
