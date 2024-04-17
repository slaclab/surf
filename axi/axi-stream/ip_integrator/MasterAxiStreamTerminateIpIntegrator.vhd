-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: IP Integrator Wrapper for terminating a MASTER AXI stream bus
-------------------------------------------------------------------------------
-- TCL Command: create_bd_cell -type module -reference MasterAxiStreamTerminateIpIntegrator MasterAxisTerm_0
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

entity MasterAxiStreamTerminateIpIntegrator is
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
      M_AXIS_ACLK    : in  std_logic := '0';
      M_AXIS_ARESETN : in  std_logic := '0';
      M_AXIS_TVALID  : out std_logic;
      M_AXIS_TDATA   : out std_logic_vector((8*TDATA_NUM_BYTES)-1 downto 0);
      M_AXIS_TSTRB   : out std_logic_vector(TDATA_NUM_BYTES-1 downto 0);
      M_AXIS_TKEEP   : out std_logic_vector(TDATA_NUM_BYTES-1 downto 0);
      M_AXIS_TLAST   : out std_logic;
      M_AXIS_TDEST   : out std_logic_vector(TDEST_WIDTH-1 downto 0);
      M_AXIS_TID     : out std_logic_vector(TID_WIDTH-1 downto 0);
      M_AXIS_TUSER   : out std_logic_vector(TUSER_WIDTH-1 downto 0);
      M_AXIS_TREADY  : in  std_logic := '1');
end MasterAxiStreamTerminateIpIntegrator;

architecture mapping of MasterAxiStreamTerminateIpIntegrator is

begin

   U_ShimLayer : entity surf.MasterAxiStreamIpIntegrator
      generic map (
         HAS_TLAST       => HAS_TLAST,
         HAS_TKEEP       => HAS_TKEEP,
         HAS_TSTRB       => HAS_TSTRB,
         HAS_TREADY      => HAS_TREADY,
         TUSER_WIDTH     => TUSER_WIDTH,
         TID_WIDTH       => TID_WIDTH,
         TDEST_WIDTH     => TDEST_WIDTH,
         TDATA_NUM_BYTES => TDATA_NUM_BYTES)
      port map (
         -- IP Integrator AXI Stream Interface
         M_AXIS_ACLK    => M_AXIS_ACLK,
         M_AXIS_ARESETN => M_AXIS_ARESETN,
         M_AXIS_TVALID  => M_AXIS_TVALID,
         M_AXIS_TDATA   => M_AXIS_TDATA,
         M_AXIS_TSTRB   => M_AXIS_TSTRB,
         M_AXIS_TKEEP   => M_AXIS_TKEEP,
         M_AXIS_TLAST   => M_AXIS_TLAST,
         M_AXIS_TDEST   => M_AXIS_TDEST,
         M_AXIS_TID     => M_AXIS_TID,
         M_AXIS_TUSER   => M_AXIS_TUSER,
         M_AXIS_TREADY  => M_AXIS_TREADY,
         -- SURF AXI Stream Interface
         axisClk        => open,
         axisRst        => open,
         axisMaster     => AXI_STREAM_MASTER_INIT_C,
         axisSlave      => open);

end mapping;
