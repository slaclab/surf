-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
--   Stateless per-QP demultiplexer (NO state machine, NO RegType).  Two
--   independent, conflict-free BSV rules each dequeue one request from an input
--   PipeOut and enqueue it, unchanged, into one of MAX_QP per-QP output FIFOs
--   selected by the request's sqpn:
--
--     dispatchWorkReq : workReqPipeIn  -> U_WorkReqOutVec[getIndexQP(wr.sqpn)]
--     dispatchRecvReq : recvReqPipeIn  -> U_RecvReqOutVec[getIndexQP(rr.sqpn)]
--
--   getIndexQP(qpn) = unpack(truncateLSB(qpn)) = the top QP_INDEX_WIDTH bits of
--   the 24-bit sqpn (QP_INDEX_WIDTH = TLog#(MAX_QP) = 2 for MAX_QP = 4).
--
--   Because the module has no mkReg/mkRegU (state_registers: []), there is no
--   sequential FSM state and therefore no RegType / two-process FSM here.  All
--   storage lives in the 2*MAX_QP surf.Fifo instances; the routing is pure
--   combinational Mealy logic (deq + one-hot wrEn demux), committed on the next
--   rising edge by each FIFO's own register.  This is exactly what the Stage-3
--   FSM spec directs ("emit combinational routing + the FIFO instances, with an
--   empty/absent RegType").
--
--   Struct widths traced from src-bsv (first field at MSB, BSV pack convention):
--     WorkReq = 601 b ; sqpn field occupies bits [303:280] -> route = [303:302]
--     RecvReq = 216 b ; sqpn field occupies bits  [23:0]   -> route =  [23:22]
--
--   Per-QP output vectors are flattened buses: element i of an N-wide bus
--   occupies ((i+1)*W-1 downto i*W).
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

entity WorkReqAndRecvReqDispatcher is
   generic (
      TPD_G    : time     := 1 ns;
      MAX_QP_G : positive := 4;         -- Settings.bsv: typedef 4 MAX_QP
      EN_TX_G  : boolean  := true;      -- false = no requester: skip WorkReq FIFOs
      EN_RX_G  : boolean  := true);     -- false = no responder: skip RecvReq FIFOs
   port (
      clk : in sl;
      rst : in sl;                      -- active-high synchronous reset

      -- workReqPipeIn : PipeOut#(WorkReq)   (WorkReq = 601 b)
      workReqValid_i : in  sl;                    -- notEmpty
      workReqData_i  : in  slv(600 downto 0);     -- first (WorkReq packed)
      workReqDeq_o   : out sl;                    -- deq

      -- recvReqPipeIn : PipeOut#(RecvReq)   (RecvReq = 216 b)
      recvReqValid_i : in  sl;                    -- notEmpty
      recvReqData_i  : in  slv(215 downto 0);     -- first (RecvReq packed)
      recvReqDeq_o   : out sl;                    -- deq

      -- workReqPipeOut : Vector#(MAX_QP, PipeOut#(WorkReq))  (read faces)
      workReqOutValid_o : out slv(MAX_QP_G-1 downto 0);             -- per-QP notEmpty
      workReqOutData_o  : out slv(MAX_QP_G*601-1 downto 0);         -- per-QP first
      workReqOutRdEn_i  : in  slv(MAX_QP_G-1 downto 0);             -- per-QP deq (downstream)

      -- recvReqPipeOut : Vector#(MAX_QP, PipeOut#(RecvReq))  (read faces)
      recvReqOutValid_o : out slv(MAX_QP_G-1 downto 0);             -- per-QP notEmpty
      recvReqOutData_o  : out slv(MAX_QP_G*216-1 downto 0);         -- per-QP first
      recvReqOutRdEn_i  : in  slv(MAX_QP_G-1 downto 0));            -- per-QP deq (downstream)
end entity WorkReqAndRecvReqDispatcher;

architecture rtl of WorkReqAndRecvReqDispatcher is

   -- Struct widths (Headers.bsv / DataTypes.bsv traced)
   constant WORK_REQ_WIDTH_C  : integer := 601;
   constant RECV_REQ_WIDTH_C  : integer := 216;
   constant QPN_WIDTH_C       : integer := 24;       -- Headers.bsv QPN_WIDTH

   -- getIndexQP = top TLog#(MAX_QP) bits of sqpn (UInt#(QP_INDEX_WIDTH))
   constant QP_INDEX_WIDTH_C  : integer := log2(MAX_QP_G);

   -- sqpn field LSB position within each packed struct word
   constant WR_SQPN_LOW_C : integer := 280;          -- WorkReq.sqpn = [303:280]
   constant RR_SQPN_LOW_C : integer := 0;            -- RecvReq.sqpn = [23:0]

   -- surf.Fifo geometry (match project convention: FWFT sync block, min depth)
   constant FIFO_ADDR_WIDTH_C : integer := 4;        -- depth = 16 entries

   -- WorkReq routing / FIFO write-side nets
   signal wrQpIdx        : unsigned(QP_INDEX_WIDTH_C-1 downto 0);
   signal workReqAccept  : sl;                                   -- rule dispatchWorkReq fires
   signal workReqWrEn    : slv(MAX_QP_G-1 downto 0);
   signal workReqNotFull : slv(MAX_QP_G-1 downto 0);

   -- RecvReq routing / FIFO write-side nets
   signal rrQpIdx        : unsigned(QP_INDEX_WIDTH_C-1 downto 0);
   signal recvReqAccept  : sl;                                   -- rule dispatchRecvReq fires
   signal recvReqWrEn    : slv(MAX_QP_G-1 downto 0);
   signal recvReqNotFull : slv(MAX_QP_G-1 downto 0);

begin

   ---------------------------------------------------------------------------
   -- Compile-time guard: getIndexQP indexing assumes MAX_QP is a power of two
   -- so that QP_INDEX_WIDTH = TLog#(MAX_QP) addresses exactly MAX_QP FIFOs.
   -- isPowerOf2 (not 2**QP_INDEX_WIDTH_C = MAX_QP_G): SURF log2(1)=1 makes the
   -- power form fail at MAX_QP_G=1, where the index is forced to 0 instead.
   ---------------------------------------------------------------------------
   assert isPowerOf2(MAX_QP_G)
      report "WorkReqAndRecvReqDispatcher: MAX_QP_G must be a power of two"
      severity failure;

   ---------------------------------------------------------------------------
   -- dispatchWorkReq : combinational QP-index demux (Mealy)
   --   qpIndex      = top QP_INDEX_WIDTH bits of WorkReq.sqpn
   --   accept (deq) = input notEmpty AND selected output FIFO not_full
   --   wrEn[i]      = accept AND (qpIndex = i)   (one-hot enq)
   ---------------------------------------------------------------------------
   -- forced to 0 at MAX_QP_G=1 (0-bit BSV index, MetaData.bsv:349)
   wrQpIdx <= unsigned(ite(MAX_QP_G > 1,
                 workReqData_i(WR_SQPN_LOW_C + QPN_WIDTH_C - 1 downto
                               WR_SQPN_LOW_C + QPN_WIDTH_C - QP_INDEX_WIDTH_C),
                 "0"));

   workReqAccept <= workReqValid_i and workReqNotFull(to_integer(wrQpIdx));
   workReqDeq_o  <= workReqAccept;

   GEN_WR : for i in 0 to MAX_QP_G-1 generate
      workReqWrEn(i) <= workReqAccept when (to_integer(wrQpIdx) = i) else '0';
   end generate GEN_WR;

   ---------------------------------------------------------------------------
   -- dispatchRecvReq : independent, conflict-free with dispatchWorkReq
   ---------------------------------------------------------------------------
   -- forced to 0 at MAX_QP_G=1 (0-bit BSV index, MetaData.bsv:349)
   rrQpIdx <= unsigned(ite(MAX_QP_G > 1,
                 recvReqData_i(RR_SQPN_LOW_C + QPN_WIDTH_C - 1 downto
                               RR_SQPN_LOW_C + QPN_WIDTH_C - QP_INDEX_WIDTH_C),
                 "0"));

   recvReqAccept <= recvReqValid_i and recvReqNotFull(to_integer(rrQpIdx));
   recvReqDeq_o  <= recvReqAccept;

   GEN_RR : for i in 0 to MAX_QP_G-1 generate
      recvReqWrEn(i) <= recvReqAccept when (to_integer(rrQpIdx) = i) else '0';
   end generate GEN_RR;

   ---------------------------------------------------------------------------
   -- U_WorkReqOutVec[i] : surf.Fifo  (BSV replicateM(mkFIFOF) of WorkReq)
   --   src : base/fifo/rtl/Fifo.vhd
   --   wr  : dispatchWorkReq (one-hot)        rd : exported PipeOut read face
   ---------------------------------------------------------------------------
   -- Pruned when EN_TX_G=false (upstream ties workReqValid_i='0', so the
   -- routing glue above constant-folds; notFull tied '1' keeps it inert).
   GEN_NO_WORK_FIFO : if not EN_TX_G generate
      workReqOutValid_o <= (others => '0');
      workReqOutData_o  <= (others => '0');
      workReqNotFull    <= (others => '1');
   end generate GEN_NO_WORK_FIFO;

   GEN_WORK_FIFO : if EN_TX_G generate
      GEN_WORK_FIFO_VEC : for i in 0 to MAX_QP_G-1 generate
         U_WorkReqOutVec : entity surf.Fifo
            generic map (
               TPD_G           => TPD_G,
               RST_POLARITY_G  => '1',
               RST_ASYNC_G     => false,
               GEN_SYNC_FIFO_G => true,
               FWFT_EN_G       => true,
               MEMORY_TYPE_G   => "distributed",
               DATA_WIDTH_G    => WORK_REQ_WIDTH_C,
               ADDR_WIDTH_G    => FIFO_ADDR_WIDTH_C)
            port map (
               rst           => rst,
               wr_clk        => clk,
               wr_en         => workReqWrEn(i),
               din           => workReqData_i,
               not_full      => workReqNotFull(i),
               full          => open,
               wr_ack        => open,
               overflow      => open,
               prog_full     => open,
               almost_full   => open,
               wr_data_count => open,
               rd_clk        => clk,
               rd_en         => workReqOutRdEn_i(i),
               dout          => workReqOutData_o((i+1)*WORK_REQ_WIDTH_C-1 downto i*WORK_REQ_WIDTH_C),
               valid         => workReqOutValid_o(i),
               underflow     => open,
               prog_empty    => open,
               almost_empty  => open,
               empty         => open,
               rd_data_count => open);
      end generate GEN_WORK_FIFO_VEC;
   end generate GEN_WORK_FIFO;

   ---------------------------------------------------------------------------
   -- U_RecvReqOutVec[i] : surf.Fifo  (BSV replicateM(mkFIFOF) of RecvReq)
   --   src : base/fifo/rtl/Fifo.vhd
   --   wr  : dispatchRecvReq (one-hot)        rd : exported PipeOut read face
   ---------------------------------------------------------------------------
   -- Pruned when EN_RX_G=false (upstream ties recvReqValid_i='0').
   GEN_NO_RECV_FIFO : if not EN_RX_G generate
      recvReqOutValid_o <= (others => '0');
      recvReqOutData_o  <= (others => '0');
      recvReqNotFull    <= (others => '1');
   end generate GEN_NO_RECV_FIFO;

   GEN_RECV_FIFO : if EN_RX_G generate
      GEN_RECV_FIFO_VEC : for i in 0 to MAX_QP_G-1 generate
         U_RecvReqOutVec : entity surf.Fifo
            generic map (
               TPD_G           => TPD_G,
               RST_POLARITY_G  => '1',
               RST_ASYNC_G     => false,
               GEN_SYNC_FIFO_G => true,
               FWFT_EN_G       => true,
               MEMORY_TYPE_G   => "distributed",
               DATA_WIDTH_G    => RECV_REQ_WIDTH_C,
               ADDR_WIDTH_G    => FIFO_ADDR_WIDTH_C)
            port map (
               rst           => rst,
               wr_clk        => clk,
               wr_en         => recvReqWrEn(i),
               din           => recvReqData_i,
               not_full      => recvReqNotFull(i),
               full          => open,
               wr_ack        => open,
               overflow      => open,
               prog_full     => open,
               almost_full   => open,
               wr_data_count => open,
               rd_clk        => clk,
               rd_en         => recvReqOutRdEn_i(i),
               dout          => recvReqOutData_o((i+1)*RECV_REQ_WIDTH_C-1 downto i*RECV_REQ_WIDTH_C),
               valid         => recvReqOutValid_o(i),
               underflow     => open,
               prog_empty    => open,
               almost_empty  => open,
               empty         => open,
               rd_data_count => open);
      end generate GEN_RECV_FIFO_VEC;
   end generate GEN_RECV_FIFO;

end architecture rtl;
