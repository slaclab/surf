-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: IP Integrator Wrapper for terminating a SLAVE AXI stream bus
-------------------------------------------------------------------------------
-- TCL Command: create_bd_cell -type module -reference SlaveAxiStreamTerminateIpIntegrator SlaveAxisTerm_0
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

entity SlaveAxiStreamTerminateIpIntegrator is
   generic (
      INTERFACENAME   : string                 := "S_AXIS";
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
      S_AXIS_TVALID  : in  std_logic                                        := '0';
      S_AXIS_TDATA   : in  std_logic_vector((8*TDATA_NUM_BYTES)-1 downto 0) := (others => '0');
      S_AXIS_TSTRB   : in  std_logic_vector(TDATA_NUM_BYTES-1 downto 0)     := (others => '0');
      S_AXIS_TKEEP   : in  std_logic_vector(TDATA_NUM_BYTES-1 downto 0)     := (others => '0');
      S_AXIS_TLAST   : in  std_logic                                        := '0';
      S_AXIS_TDEST   : in  std_logic_vector(TDEST_WIDTH-1 downto 0)         := (others => '0');
      S_AXIS_TID     : in  std_logic_vector(TID_WIDTH-1 downto 0)           := (others => '0');
      S_AXIS_TUSER   : in  std_logic_vector(TUSER_WIDTH-1 downto 0)         := (others => '0');
      S_AXIS_TREADY  : out std_logic);
end SlaveAxiStreamTerminateIpIntegrator;

architecture mapping of SlaveAxiStreamTerminateIpIntegrator is

begin

   U_ShimLayer : entity surf.SlaveAxiStreamIpIntegrator
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
         S_AXIS_TVALID  => S_AXIS_TVALID,
         S_AXIS_TDATA   => S_AXIS_TDATA,
         S_AXIS_TSTRB   => S_AXIS_TSTRB,
         S_AXIS_TKEEP   => S_AXIS_TKEEP,
         S_AXIS_TLAST   => S_AXIS_TLAST,
         S_AXIS_TDEST   => S_AXIS_TDEST,
         S_AXIS_TID     => S_AXIS_TID,
         S_AXIS_TUSER   => S_AXIS_TUSER,
         S_AXIS_TREADY  => S_AXIS_TREADY,
         -- SURF AXI Stream Interface
         axisClk        => open,
         axisRst        => open,
         axisMaster     => open,
         axisSlave      => AXI_STREAM_SLAVE_FORCE_C);

end mapping;
