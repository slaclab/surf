-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Common shim layer between IP Integrator interface and surf AXI Stream interface
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

entity MasterAxiStreamIpIntegrator is
   generic (
      INTERFACENAME   : string                 := "M_AXIS";
      HAS_TLAST       : natural range 0 to 1   := 1;
      HAS_TKEEP       : natural range 0 to 1   := 1;
      HAS_TSTRB       : natural range 0 to 1   := 0;
      HAS_TREADY      : natural range 0 to 1   := 1;
      TUSER_WIDTH     : natural range 1 to 8   := 2;
      TID_WIDTH       : natural range 1 to 8   := 1;
      TDEST_WIDTH     : natural range 1 to 8   := 1;
      TDATA_NUM_BYTES : natural range 1 to 128 := 1);
   port (
      -- IP Integrator AXI Stream Interface
      M_AXIS_ACLK    : in  std_logic           := '0';
      M_AXIS_ARESETN : in  std_logic           := '0';
      M_AXIS_TVALID  : out std_logic;
      M_AXIS_TDATA   : out std_logic_vector((8*TDATA_NUM_BYTES)-1 downto 0);
      M_AXIS_TSTRB   : out std_logic_vector(TDATA_NUM_BYTES-1 downto 0);
      M_AXIS_TKEEP   : out std_logic_vector(TDATA_NUM_BYTES-1 downto 0);
      M_AXIS_TLAST   : out std_logic;
      M_AXIS_TDEST   : out std_logic_vector(TDEST_WIDTH-1 downto 0);
      M_AXIS_TID     : out std_logic_vector(TID_WIDTH-1 downto 0);
      M_AXIS_TUSER   : out std_logic_vector(TUSER_WIDTH-1 downto 0);
      M_AXIS_TREADY  : in  std_logic           := '1';
      -- SURF AXI Stream Interface
      axisClk        : out sl;
      axisRst        : out sl;
      axisMaster     : in  AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
      axisSlave      : out AxiStreamSlaveType);
end MasterAxiStreamIpIntegrator;

architecture mapping of MasterAxiStreamIpIntegrator is

   attribute X_INTERFACE_INFO      : string;
   attribute X_INTERFACE_PARAMETER : string;

   attribute X_INTERFACE_INFO of M_AXIS_TVALID     : signal is "xilinx.com:interface:axis:1.0 " & INTERFACENAME & " TVALID";
   attribute X_INTERFACE_INFO of M_AXIS_TLAST      : signal is "xilinx.com:interface:axis:1.0 " & INTERFACENAME & " TLAST";
   attribute X_INTERFACE_INFO of M_AXIS_TDATA      : signal is "xilinx.com:interface:axis:1.0 " & INTERFACENAME & " TDATA";
   attribute X_INTERFACE_INFO of M_AXIS_TKEEP      : signal is "xilinx.com:interface:axis:1.0 " & INTERFACENAME & " TKEEP";
   attribute X_INTERFACE_INFO of M_AXIS_TREADY     : signal is "xilinx.com:interface:axis:1.0 " & INTERFACENAME & " TREADY";
   attribute X_INTERFACE_PARAMETER of M_AXIS_TDATA : signal is
      "XIL_INTERFACENAME " & INTERFACENAME & ", " &
      "LAYERED_METADATA undef, " &
      "HAS_TLAST " & integer'image(HAS_TLAST) & ", " &
      "HAS_TKEEP " & integer'image(HAS_TKEEP) & ", " &
      "HAS_TSTRB " & integer'image(HAS_TSTRB) & ", " &
      "HAS_TREADY " & integer'image(HAS_TREADY) & ", " &
      "TUSER_WIDTH " & integer'image(TUSER_WIDTH) & ", " &
      "TID_WIDTH " & integer'image(TID_WIDTH) & ", " &
      "TDEST_WIDTH " & integer'image(TDEST_WIDTH) & ", " &
      "TDATA_NUM_BYTES " & integer'image(TDATA_NUM_BYTES);

   attribute X_INTERFACE_INFO of M_AXIS_ARESETN      : signal is "xilinx.com:signal:reset:1.0 RST." & INTERFACENAME & "_ARESETN RST";
   attribute X_INTERFACE_PARAMETER of M_AXIS_ARESETN : signal is
      "XIL_INTERFACENAME RST." & INTERFACENAME & "_ARESETN, " &
      "POLARITY ACTIVE_LOW";

   attribute X_INTERFACE_INFO of M_AXIS_ACLK      : signal is "xilinx.com:signal:clock:1.0 CLK." & INTERFACENAME & "_ACLK CLK";
   attribute X_INTERFACE_PARAMETER of M_AXIS_ACLK : signal is
      "XIL_INTERFACENAME CLK." & INTERFACENAME & "_ACLK, " &
      "ASSOCIATED_BUSIF " & INTERFACENAME & ", " &
      "ASSOCIATED_RESET " & INTERFACENAME & "_ARESETN";

   signal M_AXIS_Master : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal M_AXIS_Slave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;

begin

   axisClk <= M_AXIS_ACLK;

   M_AXIS_Master <= axisMaster;
   axisSlave     <= M_AXIS_Slave;

   U_RstSync : entity surf.RstSync
      generic map (
         IN_POLARITY_G  => '0',
         OUT_POLARITY_G => '1')
      port map (
         clk      => M_AXIS_ACLK,
         asyncRst => M_AXIS_ARESETN,
         syncRst  => axisRst);

   M_AXIS_TVALID <= M_AXIS_Master.tValid;
   M_AXIS_TDATA  <= M_AXIS_Master.tData((8*TDATA_NUM_BYTES)-1 downto 0);
   M_AXIS_TSTRB  <= M_AXIS_Master.tStrb(TDATA_NUM_BYTES-1 downto 0) when(HAS_TSTRB /= 0) else (others => '1');
   M_AXIS_TKEEP  <= M_AXIS_Master.tKeep(TDATA_NUM_BYTES-1 downto 0) when(HAS_TKEEP /= 0) else (others => '1');
   M_AXIS_TLAST  <= M_AXIS_Master.tLast                             when(HAS_TLAST /= 0) else '0';
   M_AXIS_TDEST  <= M_AXIS_Master.tDest(TDEST_WIDTH-1 downto 0);
   M_AXIS_TID    <= M_AXIS_Master.tId(TID_WIDTH-1 downto 0);
   M_AXIS_TUSER  <= M_AXIS_Master.tUser(TUSER_WIDTH-1 downto 0);

   M_AXIS_Slave.tReady <= M_AXIS_TREADY when(HAS_TREADY /= 0) else '1';

end mapping;
