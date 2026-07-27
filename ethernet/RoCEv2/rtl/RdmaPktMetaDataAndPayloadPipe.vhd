-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
--   Pure structural wrapper: exposes a metadata FIFO (649-bit RdmaPktMetaData)
--   and a payload FIFO (290-bit DataStream) as an entity interface.  No rules,
--   no local registers, no FSM.  Instantiated twice inside mkQP:
--     reqPktPipe  (incoming RQ packet pipe, written by TransportLayer)
--     respPktPipe (incoming SQ response packet pipe, written by TransportLayer)
--
--   SURF components instantiated:
--     U_MetaDataQ : surf.Fifo  (DATA_WIDTH_G=649, FWFT, sync)
--       source: surf/base/fifo/rtl/Fifo.vhd
--     U_PayloadQ  : surf.Fifo  (DATA_WIDTH_G=290, FWFT, sync)
--       source: surf/base/fifo/rtl/Fifo.vhd
--
--   DataStream width resolution (OQ-FSM-H2DS-02, resolved Stage 4):
--     DataTypes.bsv:183-188: data(256) + byteEn(32) + isFirst(1) + isLast(1)
--     = 290 bits.  The Stage-1 inventory value of 321 is incorrect; all
--     DataStream-carrying FIFOs in this project use DATA_WIDTH_G=290.
--
--   FIFO clear (OQ-FSM-06 / OQ-FSM-NPWRPO-02, resolved in RESOLVED.md):
--     clrEn_i is a level, held HIGH for the full duration of QP reset by the
--     parent mkQP.resetAndClear rule (fire_when_enabled, no_implicit_conditions).
--     surf.FifoSync is level-sensitive on rst; holding it continuously pins
--     both FIFOs logically empty each cycle.  No pulse-generator needed.
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

entity RdmaPktMetaDataAndPayloadPipe is
   generic (
      TPD_G             : time                   := 1 ns;
      RST_POLARITY_G    : sl                     := '1';
      RST_ASYNC_G       : boolean                := false;
      FIFO_ADDR_WIDTH_G : positive range 4 to 48 := 4);  -- depth = 2**G entries per FIFO
   port (
      clk            : in  sl;
      rst            : in  sl := not RST_POLARITY_G;
      -- clear() method: level-asserted for full duration of QP reset
      clrEn_i        : in  sl := '0';
      -- Metadata FIFO — write side (pktPipeIn.pktMetaData.put)
      metaWrEn_i     : in  sl := '0';
      metaDin_i      : in  slv(648 downto 0);  -- RdmaPktMetaData, 649 bits
      metaRdy_o      : out sl;          -- notFull (= write-side readiness)
      -- Metadata FIFO — read side (pktPipeOut.pktMetaData.first / .deq)
      metaValid_o    : out sl;          -- notEmpty
      metaDout_o     : out slv(648 downto 0);
      metaRdEn_i     : in  sl := '0';
      -- Payload FIFO — write side (pktPipeIn.payload.put)
      payloadWrEn_i  : in  sl := '0';
      payloadDin_i   : in  slv(289 downto 0);  -- DataStream, 290 bits (resolved OQ-FSM-H2DS-02)
      payloadRdy_o   : out sl;          -- notFull
      -- Payload FIFO — read side (pktPipeOut.payload.first / .deq)
      payloadValid_o : out sl;          -- notEmpty
      payloadDout_o  : out slv(289 downto 0);
      payloadRdEn_i  : in  sl := '0');
end entity RdmaPktMetaDataAndPayloadPipe;

architecture rtl of RdmaPktMetaDataAndPayloadPipe is

   -- Normalised active-high reset (for FIFO rst port, which is always active-high)
   signal rstActiveHigh : sl;
   -- Combined FIFO clear: global hardware reset OR BSV clear() method level
   signal fifoRst       : sl;

begin

   rstActiveHigh <= rst when (RST_POLARITY_G = '1') else not rst;

   -- Level-clear: fifoRst held '1' for the full duration of clrEn_i='1'.
   -- surf.FifoSync re-applies REG_INIT_C (empty state) every cycle rst is
   -- asserted; releasing rst makes both FIFOs usable on the very next cycle.
   fifoRst <= rstActiveHigh or clrEn_i;

   --------------------------------------------------------------------------
   -- U_MetaDataQ : metaDataQ
   --   BSV: FIFOF#(RdmaPktMetaData) via mkFIFO (FWFT, depth 2)
   --   Width: 649 bits — see RdmaPktMetaData derivation in FSM spec
   --------------------------------------------------------------------------
   U_MetaDataQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',
         RST_ASYNC_G     => false,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => 649,
         ADDR_WIDTH_G    => FIFO_ADDR_WIDTH_G)
      port map (
         rst      => fifoRst,
         wr_clk   => clk,
         wr_en    => metaWrEn_i,
         din      => metaDin_i,
         not_full => metaRdy_o,
         rd_clk   => clk,
         rd_en    => metaRdEn_i,
         dout     => metaDout_o,
         valid    => metaValid_o);

   --------------------------------------------------------------------------
   -- U_PayloadQ : payloadQ
   --   BSV: FIFOF#(DataStream) via mkFIFO (FWFT, depth 2)
   --   Width: 290 bits — data[255:0]+byteEn[31:0]+isFirst[1]+isLast[0]
   --   (OQ-FSM-H2DS-02 closed: DataTypes.bsv 256+32+1+1=290, not 321)
   --------------------------------------------------------------------------
   U_PayloadQ : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         RST_POLARITY_G  => '1',
         RST_ASYNC_G     => false,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => true,
         MEMORY_TYPE_G   => "distributed",
         DATA_WIDTH_G    => 290,
         ADDR_WIDTH_G    => FIFO_ADDR_WIDTH_G)
      port map (
         rst      => fifoRst,
         wr_clk   => clk,
         wr_en    => payloadWrEn_i,
         din      => payloadDin_i,
         not_full => payloadRdy_o,
         rd_clk   => clk,
         rd_en    => payloadRdEn_i,
         dout     => payloadDout_o,
         valid    => payloadValid_o);

end architecture rtl;
