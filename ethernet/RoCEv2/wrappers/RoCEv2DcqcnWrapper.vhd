-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing wrapper for RoCEv2Dcqcn (DCQCN collapse bench).
--
--   Flattens the VHDL record ports of the RoCEv2Dcqcn DCQCN block (AXI-Stream
--   ingress/egress and AXI-Lite) into plain std_logic/std_logic_vector ports so a
--   cocotb testbench can drive/observe every channel. The DUT has NO work/DMA/comp
--   records (those belong to the RoCEv2 host-logic core, not the DCQCN block), so
--   those ports are intentionally absent. A flat scalar 'cnp' input substitutes for
--   the RoCEv2Engine.cnp_received source: the bench pulses it to trigger the rate
--   state machine. The egress 'M_AXIS_*' stream is exposed flat so a cocotb counting
--   sink can tally TokenBucket-paced beats per window (the throughput predicate).
--   The DUT is wired single-clock (axisClk = clk) at the default 32-byte RoCEv2
--   stream width and default LINE_RATE_G/CLK_FREQ_G. The AXI-Lite shim mirrors
--   RoCEv2AxiStreamRdmaCoreWrapper.
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

library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;
use surf.SsiPkg.all;
use surf.AxiLitePkg.all;
use surf.RoCEv2Pkg.all;

entity RoCEv2DcqcnWrapper is
   generic (
      TPD_G : time := 1 ns);
   port (
      clk                       : in  sl;
      rst                       : in  sl;
      -- CNP injection (TB-driven scalar; substitutes RoCEv2Engine.cnp_received)
      cnp                       : in  sl;
      -- Inbound payload stream (TB AxiStreamSource drives; 32-byte beats)
      S_AXIS_TVALID             : in  sl;
      S_AXIS_TDATA              : in  slv(255 downto 0);
      S_AXIS_TKEEP              : in  slv(31 downto 0);
      S_AXIS_TLAST              : in  sl;
      S_AXIS_TREADY             : out sl;
      -- Egress payload stream (TB counting sink observes valid, drives ready high)
      M_AXIS_TVALID             : out sl;
      M_AXIS_TDATA              : out slv(255 downto 0);
      M_AXIS_TKEEP              : out slv(31 downto 0);
      M_AXIS_TLAST              : out sl;
      M_AXIS_TREADY             : in  sl;
      -- AXI-Lite (cocotbext-axi AxiLiteMaster drives the AXI4-Lite bus)
      S_AXIL_AWADDR             : in  slv(31 downto 0);
      S_AXIL_AWPROT             : in  slv(2 downto 0);
      S_AXIL_AWVALID            : in  sl;
      S_AXIL_AWREADY            : out sl;
      S_AXIL_WDATA              : in  slv(31 downto 0);
      S_AXIL_WSTRB              : in  slv(3 downto 0);
      S_AXIL_WVALID             : in  sl;
      S_AXIL_WREADY             : out sl;
      S_AXIL_BRESP              : out slv(1 downto 0);
      S_AXIL_BVALID             : out sl;
      S_AXIL_BREADY             : in  sl;
      S_AXIL_ARADDR             : in  slv(31 downto 0);
      S_AXIL_ARPROT             : in  slv(2 downto 0);
      S_AXIL_ARVALID            : in  sl;
      S_AXIL_ARREADY            : out sl;
      S_AXIL_RDATA              : out slv(31 downto 0);
      S_AXIL_RRESP              : out slv(1 downto 0);
      S_AXIL_RVALID             : out sl;
      S_AXIL_RREADY             : in  sl);
end entity RoCEv2DcqcnWrapper;

architecture rtl of RoCEv2DcqcnWrapper is

   signal axilClk         : sl;
   signal axilRst         : sl;
   signal axilReadMaster  : AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
   signal axilReadSlave   : AxiLiteReadSlaveType   := AXI_LITE_READ_SLAVE_INIT_C;
   signal axilWriteMaster : AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
   signal axilWriteSlave  : AxiLiteWriteSlaveType  := AXI_LITE_WRITE_SLAVE_INIT_C;

   signal sAxisMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal sAxisSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;
   signal mAxisMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal mAxisSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;

begin

   ----------------------------------------------------------------------------
   -- AXI-Lite shim (flat AXI4-Lite <-> AxiLite record)
   ----------------------------------------------------------------------------
   U_ShimLayer : entity surf.SlaveAxiLiteIpIntegrator
      generic map (
         EN_ERROR_RESP => true,
         FREQ_HZ       => 156250000,
         ADDR_WIDTH    => 32)
      port map (
         S_AXI_ACLK      => clk,
         S_AXI_ARESETN   => not rst,
         S_AXI_AWADDR    => S_AXIL_AWADDR,
         S_AXI_AWPROT    => S_AXIL_AWPROT,
         S_AXI_AWVALID   => S_AXIL_AWVALID,
         S_AXI_AWREADY   => S_AXIL_AWREADY,
         S_AXI_WDATA     => S_AXIL_WDATA,
         S_AXI_WSTRB     => S_AXIL_WSTRB,
         S_AXI_WVALID    => S_AXIL_WVALID,
         S_AXI_WREADY    => S_AXIL_WREADY,
         S_AXI_BRESP     => S_AXIL_BRESP,
         S_AXI_BVALID    => S_AXIL_BVALID,
         S_AXI_BREADY    => S_AXIL_BREADY,
         S_AXI_ARADDR    => S_AXIL_ARADDR,
         S_AXI_ARPROT    => S_AXIL_ARPROT,
         S_AXI_ARVALID   => S_AXIL_ARVALID,
         S_AXI_ARREADY   => S_AXIL_ARREADY,
         S_AXI_RDATA     => S_AXIL_RDATA,
         S_AXI_RRESP     => S_AXIL_RRESP,
         S_AXI_RVALID    => S_AXIL_RVALID,
         S_AXI_RREADY    => S_AXIL_RREADY,
         axilClk         => axilClk,
         axilRst         => axilRst,
         axilReadMaster  => axilReadMaster,
         axilReadSlave   => axilReadSlave,
         axilWriteMaster => axilWriteMaster,
         axilWriteSlave  => axilWriteSlave);

   ----------------------------------------------------------------------------
   -- Record <-> flat packing
   ----------------------------------------------------------------------------
   -- Slave (ingress) payload stream (TB drives)
   sAxisComb : process (S_AXIS_TVALID, S_AXIS_TDATA, S_AXIS_TKEEP, S_AXIS_TLAST) is
      variable v : AxiStreamMasterType;
   begin
      v                     := AXI_STREAM_MASTER_INIT_C;
      v.tValid              := S_AXIS_TVALID;
      v.tData(255 downto 0) := S_AXIS_TDATA;
      v.tKeep(31 downto 0)  := S_AXIS_TKEEP;
      v.tLast               := S_AXIS_TLAST;
      sAxisMaster           <= v;
   end process sAxisComb;
   S_AXIS_TREADY <= sAxisSlave.tReady;

   -- Master (egress) payload stream (TB counting sink observes + drives ready)
   M_AXIS_TVALID     <= mAxisMaster.tValid;
   M_AXIS_TDATA      <= mAxisMaster.tData(255 downto 0);
   M_AXIS_TKEEP      <= mAxisMaster.tKeep(31 downto 0);
   M_AXIS_TLAST      <= mAxisMaster.tLast;
   mAxisSlave.tReady <= M_AXIS_TREADY;

   ----------------------------------------------------------------------------
   -- DUT: RoCEv2Dcqcn (single-clock: axisClk = clk) at default LINE_RATE_G/
   -- CLK_FREQ_G (cannot be runtime-rewritten). The bench pulses 'cnp' to
   -- drive the rate state machine and observes the TokenBucket-paced egress.
   ----------------------------------------------------------------------------
   U_DUT : entity surf.RoCEv2Dcqcn
      generic map (
         TPD_G         => TPD_G,
         AXIS_CONFIG_G => ssiAxiStreamConfig(dataBytes => TDATA_ROCE_NUM_BYTES_C, tKeepMode => TKEEP_NORMAL_C, tDestBits => 0))
      port map (
         axisClk         => clk,
         axisRst         => rst,
         cnp             => cnp,
         axilReadMaster  => axilReadMaster,
         axilReadSlave   => axilReadSlave,
         axilWriteMaster => axilWriteMaster,
         axilWriteSlave  => axilWriteSlave,
         sAxisMaster     => sAxisMaster,
         sAxisSlave      => sAxisSlave,
         mAxisMaster     => mAxisMaster,
         mAxisSlave      => mAxisSlave);

end architecture rtl;
