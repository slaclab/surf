-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: AXI-Lite Wrapper on AXI4 Monitor Module
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
use surf.AxiLitePkg.all;
use surf.AxiPkg.all;

entity AxiMonAxiL is
   generic (
      TPD_G           : time     := 1 ns;
      COMMON_CLK_G    : boolean  := false;      -- true if axiClk = axilClk
      AXI_CLK_FREQ_G  : real     := 156.25E+6;  -- units of Hz
      AXI_NUM_SLOTS_G : positive := 1;
      AXI_CONFIG_G    : AxiConfigType);
   port (
      -- AXI4 Memory Interfaces
      axiClk           : in  sl;
      axiRst           : in  sl;
      axiWriteMasters  : in  AxiWriteMasterArray(AXI_NUM_SLOTS_G-1 downto 0);
      axiWriteSlaves   : in  AxiWriteSlaveArray(AXI_NUM_SLOTS_G-1 downto 0);
      axiReadMasters   : in  AxiReadMasterArray(AXI_NUM_SLOTS_G-1 downto 0);
      axiReadSlaves    : in  AxiReadSlaveArray(AXI_NUM_SLOTS_G-1 downto 0);
      -- AXI-Lite for register access
      axilClk          : in  sl;
      axilRst          : in  sl;
      sAxilWriteMaster : in  AxiLiteWriteMasterType;
      sAxilWriteSlave  : out AxiLiteWriteSlaveType;
      sAxilReadMaster  : in  AxiLiteReadMasterType;
      sAxilReadSlave   : out AxiLiteReadSlaveType);
end AxiMonAxiL;

architecture mapping of AxiMonAxiL is

   constant AXIS_CONFIG_C : AxiStreamConfigType := (
      TSTRB_EN_C    => AXI_STREAM_CONFIG_INIT_C.TSTRB_EN_C,
      TDATA_BYTES_C => AXI_CONFIG_G.DATA_BYTES_C,
      TDEST_BITS_C  => AXI_STREAM_CONFIG_INIT_C.TDEST_BITS_C,
      TID_BITS_C    => AXI_STREAM_CONFIG_INIT_C.TID_BITS_C,
      TKEEP_MODE_C  => AXI_STREAM_CONFIG_INIT_C.TKEEP_MODE_C,
      TUSER_BITS_C  => AXI_STREAM_CONFIG_INIT_C.TUSER_BITS_C,
      TUSER_MODE_C  => AXI_STREAM_CONFIG_INIT_C.TUSER_MODE_C);

   signal axisMasters : AxiStreamMasterArray(2*AXI_NUM_SLOTS_G-1 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
   signal axisSlaves  : AxiStreamSlaveArray(2*AXI_NUM_SLOTS_G-1 downto 0)  := (others => AXI_STREAM_SLAVE_FORCE_C);

begin

   GEN_VEC : for i in 0 to (AXI_NUM_SLOTS_G-1) generate

      -------------------------------------
      -- Remap AXI4.WRITE[i] to AXIS[2*i+0]
      -------------------------------------
      axisMasters(2*i+0).tValid                                      <= axiWriteMasters(i).wvalid;
      axisMasters(2*i+0).tStrb(AXI_CONFIG_G.DATA_BYTES_C-1 downto 0) <= axiWriteMasters(i).wstrb(AXI_CONFIG_G.DATA_BYTES_C-1 downto 0);
      axisMasters(2*i+0).tKeep(AXI_CONFIG_G.DATA_BYTES_C-1 downto 0) <= axiWriteMasters(i).wstrb(AXI_CONFIG_G.DATA_BYTES_C-1 downto 0);
      axisMasters(2*i+0).tLast                                       <= axiWriteMasters(i).wlast;
      axisSlaves(2*i+0).tReady                                       <= axiWriteSlaves(i).wready;

      ------------------------------------
      -- Remap AXI4.READ[i] to AXIS[2*i+1]
      ------------------------------------
      axisMasters(2*i+1).tValid                                      <= axiReadSlaves(i).rvalid;
      axisMasters(2*i+1).tStrb(AXI_CONFIG_G.DATA_BYTES_C-1 downto 0) <= (others => '1');
      axisMasters(2*i+1).tKeep(AXI_CONFIG_G.DATA_BYTES_C-1 downto 0) <= (others => '1');
      axisMasters(2*i+1).tLast                                       <= axiReadSlaves(i).rlast;
      axisSlaves(2*i+1).tReady                                       <= axiReadMasters(i).rready;

   end generate;

   ----------------------------------------------------------------------
   -- Re-propose the existing AXI stream monitor as a AXI4 memory monitor
   ----------------------------------------------------------------------
   U_Monitor : entity surf.AxiStreamMonAxiL
      generic map(
         TPD_G            => TPD_G,
         COMMON_CLK_G     => COMMON_CLK_G,
         AXIS_CLK_FREQ_G  => AXI_CLK_FREQ_G,
         AXIS_NUM_SLOTS_G => 2*AXI_NUM_SLOTS_G,
         AXIS_CONFIG_G    => AXIS_CONFIG_C)
      port map(
         -- AXIS Stream Interface
         axisClk          => axiClk,
         axisRst          => axiRst,
         axisMasters      => axisMasters,
         axisSlaves       => axisSlaves,
         -- AXI lite slave port for register access
         axilClk          => axilClk,
         axilRst          => axilRst,
         sAxilWriteMaster => sAxilWriteMaster,
         sAxilWriteSlave  => sAxilWriteSlave,
         sAxilReadMaster  => sAxilReadMaster,
         sAxilReadSlave   => sAxilReadSlave);

end mapping;
