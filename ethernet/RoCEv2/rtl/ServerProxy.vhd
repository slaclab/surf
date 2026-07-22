-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Purpose: Generic server proxy -- buffers requests from srvPort through
--          U_ReqQ to cltPort, and buffers responses from cltPort through
--          U_RespQ to srvPort. No FSM state; purely structural pass-through.
-- OQ-FSM-18: REQ_WIDTH_G / RESP_WIDTH_G are generics; concrete widths for
--             DmaReadProxy / DmaWriteProxy / PermCheckProxy are resolved at
--             the instantiation sites in QueuePair.bsv (QueuePair.vhd Stage 4).
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

entity ServerProxy is
   generic (
      TPD_G        : time    := 1 ns;
      REQ_WIDTH_G  : natural := 16;   -- Bits#(reqType, reqSz) from BSV proviso
      RESP_WIDTH_G : natural := 16);  -- Bits#(respType, respSz) from BSV proviso
   port (
      -- Clock and synchronous active-high reset
      clk          : in  sl;
      rst          : in  sl;
      -- srvPort side: upstream caller drives requests and accepts responses
      srvReqValid  : in  sl;
      srvReqData   : in  slv(REQ_WIDTH_G-1 downto 0);
      srvReqReady  : out sl;                            -- = U_ReqQ.not_full
      srvRespValid : out sl;                            -- = U_RespQ.valid
      srvRespData  : out slv(RESP_WIDTH_G-1 downto 0); -- = U_RespQ.dout
      srvRespReady : in  sl;
      -- cltPort side: entity presents requests to and accepts responses from downstream
      cltReqValid  : out sl;                            -- = U_ReqQ.valid
      cltReqData   : out slv(REQ_WIDTH_G-1 downto 0);  -- = U_ReqQ.dout
      cltReqReady  : in  sl;
      cltRespValid : in  sl;
      cltRespData  : in  slv(RESP_WIDTH_G-1 downto 0);
      cltRespReady : out sl);                           -- = U_RespQ.not_full
end entity ServerProxy;

architecture rtl of ServerProxy is

   -- No live FSM state: mkServerProxy has no mkReg / mkRegU.
   -- Placeholder keeps the two-process template structurally complete.
   type RegType is record
      placeholder : sl;
   end record RegType;

   constant REG_INIT_C : RegType := (placeholder => '0');

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   -- Outputs from U_ReqQ (request FIFO)
   signal reqQNotFull : sl;
   signal reqQValid   : sl;
   signal reqQDout    : slv(REQ_WIDTH_G-1 downto 0);

   -- Control inputs to U_ReqQ
   signal reqQWrEn : sl;
   signal reqQRdEn : sl;

   -- Outputs from U_RespQ (response FIFO)
   signal respQNotFull : sl;
   signal respQValid   : sl;
   signal respQDout    : slv(RESP_WIDTH_G-1 downto 0);

   -- Control inputs to U_RespQ
   signal respQWrEn : sl;
   signal respQRdEn : sl;

begin

   ---------------------------------------------------------------------------
   -- Request FIFO: srvPort.request.put -> cltPort.request.get
   -- FWFT_EN_G=true: valid/dout map directly to BSV mkFIFOF !empty / first.
   -- ADDR_WIDTH_G=4 (depth=16) is the SURF minimum; BSV mkFIFOF is depth-2.
   ---------------------------------------------------------------------------
   U_ReqQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',
         RST_ASYNC_G     => false,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         SYNTH_MODE_G    => "inferred",
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => REQ_WIDTH_G,
         ADDR_WIDTH_G    => 4)
      port map (
         rst      => rst,
         wr_clk   => clk,
         wr_en    => reqQWrEn,
         din      => srvReqData,
         not_full => reqQNotFull,
         rd_clk   => clk,
         rd_en    => reqQRdEn,
         dout     => reqQDout,
         valid    => reqQValid);

   ---------------------------------------------------------------------------
   -- Response FIFO: cltPort.response.put -> srvPort.response.get
   ---------------------------------------------------------------------------
   U_RespQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',
         RST_ASYNC_G     => false,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         SYNTH_MODE_G    => "inferred",
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => RESP_WIDTH_G,
         ADDR_WIDTH_G    => 4)
      port map (
         rst      => rst,
         wr_clk   => clk,
         wr_en    => respQWrEn,
         din      => cltRespData,
         not_full => respQNotFull,
         rd_clk   => clk,
         rd_en    => respQRdEn,
         dout     => respQDout,
         valid    => respQValid);

   ---------------------------------------------------------------------------
   -- Combinatorial process: six BSV SURF-drive wire assignments.
   -- All outputs are purely combinatorial (Mealy-degenerate); no r fields
   -- contribute to any output.
   ---------------------------------------------------------------------------
   comb : process (r, rst, srvReqValid, srvRespReady, cltReqReady, cltRespValid,
                   reqQNotFull, reqQValid, reqQDout,
                   respQNotFull, respQValid, respQDout) is
      variable v : RegType;
   begin
      v := r;

      -- FIFO write/read enables: BSV mkFIFOF enq/deq with implicit !full / !empty guards
      reqQWrEn  <= srvReqValid  and reqQNotFull;
      reqQRdEn  <= cltReqReady  and reqQValid;
      respQWrEn <= cltRespValid and respQNotFull;
      respQRdEn <= srvRespReady and respQValid;

      -- srvPort outputs (wired from FIFO status / data)
      srvReqReady  <= reqQNotFull;
      srvRespValid <= respQValid;
      srvRespData  <= respQDout;

      -- cltPort outputs (wired from FIFO status / data)
      cltReqValid  <= reqQValid;
      cltReqData   <= reqQDout;
      cltRespReady <= respQNotFull;

      -- Synchronous reset (no-op for placeholder; FIFOs reset via their own rst port)
      if (rst = '1') then
         v := REG_INIT_C;
      end if;

      rin <= v;
   end process comb;

   seq : process (clk) is
   begin
      if rising_edge(clk) then
         r <= rin;
      end if;
   end process seq;

end architecture rtl;
