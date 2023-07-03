-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: IP Integrator Wrapper for surf.AxiStreamFifoV2
-------------------------------------------------------------------------------
-- TCL Command: create_bd_cell -type module -reference AxiStreamFifoV2IpIntegrator AxiStreamFifoV2_0
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

entity AxiStreamFifoV2IpIntegrator is
   generic (
      -- IP Integrator Slave AXI Stream Configuration
      S_INTERFACENAME   : string                 := "S_AXIS";
      S_HAS_TLAST       : natural range 0 to 1   := 1;
      S_HAS_TKEEP       : natural range 0 to 1   := 1;
      S_HAS_TSTRB       : natural range 0 to 1   := 0;
      S_HAS_TREADY      : natural range 0 to 1   := 1;
      S_TUSER_WIDTH     : natural range 1 to 8   := 2;
      S_TID_WIDTH       : natural range 1 to 8   := 1;
      S_TDEST_WIDTH     : natural range 1 to 8   := 1;
      S_TDATA_NUM_BYTES : natural range 1 to 128 := 1;

      -- IP Integrator Master AXI Stream Configuration
      M_INTERFACENAME   : string                 := "M_AXIS";
      M_HAS_TLAST       : natural range 0 to 1   := 1;
      M_HAS_TKEEP       : natural range 0 to 1   := 1;
      M_HAS_TSTRB       : natural range 0 to 1   := 0;
      M_HAS_TREADY      : natural range 0 to 1   := 1;
      M_TUSER_WIDTH     : natural range 1 to 8   := 2;
      M_TID_WIDTH       : natural range 1 to 8   := 1;
      M_TDEST_WIDTH     : natural range 1 to 8   := 1;
      M_TDATA_NUM_BYTES : natural range 1 to 128 := 1;

      -- General Configurations
      RST_ASYNC        : boolean                    := false;
      INT_PIPE_STAGES  : natural range 0 to 16      := 0;  -- Internal FIFO setting
      PIPE_STAGES      : natural range 0 to 16      := 1;
      VALID_BURST_MODE : boolean                    := false;  -- only used in VALID_THOLD_G>1
      VALID_THOLD      : integer range 0 to (2**24) := 1;  -- =1 = normal operation
                                        -- =0 = only when frame ready
                                                           -- >1 = only when frame ready or # entries

      -- FIFO configurations
      GEN_SYNC_FIFO     : boolean                    := false;
      FIFO_ADDR_WIDTH   : integer range 4 to 48      := 9;
      FIFO_FIXED_THRESH : boolean                    := true;
      FIFO_PAUSE_THRESH : integer range 1 to (2**24) := 1;
      SYNTH_MODE        : string                     := "inferred";
      MEMORY_TYPE       : string                     := "block";

      -- Internal FIFO width select, "WIDE", "NARROW" or "CUSTOM"
      -- WIDE uses wider of slave / master. NARROW  uses narrower.
      -- CUSOTM uses passed FIFO_DATA_WIDTH_G
      INT_WIDTH_SELECT : string                := "WIDE";
      INT_DATA_WIDTH   : natural range 1 to 16 := 16;

      -- If VALID_THOLD_G /=1, FIFO that stores on tLast txns can be smaller.
      -- Set to 0 for same size as primary fifo (default)
      -- Set >4 for custom size.
      -- Use at own risk. Overflow of tLast fifo is not checked
      LAST_FIFO_ADDR_WIDTH : integer range 0 to 48 := 0;

      -- Index = 0 is output, index = n is input
      CASCADE_PAUSE_SEL : integer range 0 to (2**24) := 0;
      CASCADE_SIZE      : integer range 1 to (2**24) := 1);
   port (
      -- IP Integrator Slave AXI Stream Interface
      S_AXIS_ACLK     : in  std_logic                                          := '0';
      S_AXIS_ARESETN  : in  std_logic                                          := '0';
      S_AXIS_TVALID   : in  std_logic                                          := '0';
      S_AXIS_TDATA    : in  std_logic_vector((8*S_TDATA_NUM_BYTES)-1 downto 0) := (others => '0');
      S_AXIS_TSTRB    : in  std_logic_vector(S_TDATA_NUM_BYTES-1 downto 0)     := (others => '0');
      S_AXIS_TKEEP    : in  std_logic_vector(S_TDATA_NUM_BYTES-1 downto 0)     := (others => '0');
      S_AXIS_TLAST    : in  std_logic                                          := '0';
      S_AXIS_TDEST    : in  std_logic_vector(S_TDEST_WIDTH-1 downto 0)         := (others => '0');
      S_AXIS_TID      : in  std_logic_vector(S_TID_WIDTH-1 downto 0)           := (others => '0');
      S_AXIS_TUSER    : in  std_logic_vector(S_TUSER_WIDTH-1 downto 0)         := (others => '0');
      S_AXIS_TREADY   : out std_logic;
      -- IP Integrator Master AXI Stream Interface
      M_AXIS_ACLK     : in  std_logic                                          := '0';
      M_AXIS_ARESETN  : in  std_logic                                          := '0';
      M_AXIS_TVALID   : out std_logic;
      M_AXIS_TDATA    : out std_logic_vector((8*M_TDATA_NUM_BYTES)-1 downto 0);
      M_AXIS_TSTRB    : out std_logic_vector(M_TDATA_NUM_BYTES-1 downto 0);
      M_AXIS_TKEEP    : out std_logic_vector(M_TDATA_NUM_BYTES-1 downto 0);
      M_AXIS_TLAST    : out std_logic;
      M_AXIS_TDEST    : out std_logic_vector(M_TDEST_WIDTH-1 downto 0);
      M_AXIS_TID      : out std_logic_vector(M_TID_WIDTH-1 downto 0);
      M_AXIS_TUSER    : out std_logic_vector(M_TUSER_WIDTH-1 downto 0);
      M_AXIS_TREADY   : in  std_logic                                          := '1';
      -- Misc. Interfaces
      fifoPauseThresh : in  std_logic_vector(FIFO_ADDR_WIDTH-1 downto 0)       := (others => '1');
      fifoWrCnt       : out std_logic_vector(FIFO_ADDR_WIDTH-1 downto 0);
      fifoFull        : out std_logic;
      sAxisPause      : out std_logic;
      sAxisOverflow   : out std_logic;
      sAxisIdle       : out std_logic;
      mTLastTUser     : out std_logic_vector(7 downto 0));
end AxiStreamFifoV2IpIntegrator;

architecture mapping of AxiStreamFifoV2IpIntegrator is

   constant S_AXI_CONFIG_C : AxiStreamConfigType := (
      TSTRB_EN_C    => ite(S_HAS_TSTRB = 1, true, false),
      TDATA_BYTES_C => S_TDATA_NUM_BYTES,
      TDEST_BITS_C  => S_TDEST_WIDTH,
      TID_BITS_C    => S_TID_WIDTH,
      TKEEP_MODE_C  => ite(S_HAS_TKEEP = 1, TKEEP_NORMAL_C, TKEEP_FIXED_C),
      TUSER_BITS_C  => S_TUSER_WIDTH,
      TUSER_MODE_C  => TUSER_NORMAL_C);

   constant M_AXI_CONFIG_C : AxiStreamConfigType := (
      TSTRB_EN_C    => ite(M_HAS_TSTRB = 1, true, false),
      TDATA_BYTES_C => M_TDATA_NUM_BYTES,
      TDEST_BITS_C  => M_TDEST_WIDTH,
      TID_BITS_C    => M_TID_WIDTH,
      TKEEP_MODE_C  => ite(M_HAS_TKEEP = 1, TKEEP_NORMAL_C, TKEEP_FIXED_C),
      TUSER_BITS_C  => M_TUSER_WIDTH,
      TUSER_MODE_C  => TUSER_NORMAL_C);

   signal sAxisClk    : sl                  := '0';
   signal sAxisRst    : sl                  := '0';
   signal sAxisMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal sAxisSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;
   signal sAxisCtrl   : AxiStreamCtrlType   := AXI_STREAM_CTRL_UNUSED_C;

   signal mAxisClk    : sl                  := '0';
   signal mAxisRst    : sl                  := '0';
   signal mAxisMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal mAxisSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;

begin

   U_ShimLayerSlave : entity surf.SlaveAxiStreamIpIntegrator
      generic map (
         INTERFACENAME   => S_INTERFACENAME,
         HAS_TLAST       => S_HAS_TLAST,
         HAS_TKEEP       => S_HAS_TKEEP,
         HAS_TSTRB       => S_HAS_TSTRB,
         HAS_TREADY      => S_HAS_TREADY,
         TUSER_WIDTH     => S_TUSER_WIDTH,
         TID_WIDTH       => S_TID_WIDTH,
         TDEST_WIDTH     => S_TDEST_WIDTH,
         TDATA_NUM_BYTES => S_TDATA_NUM_BYTES)
      port map (
         -- IP Integrator AXI Stream Interface
         S_AXIS_ACLK    => S_AXIS_ACLK,
         S_AXIS_ARESETN => S_AXIS_ARESETN,
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
         axisClk        => sAxisClk,
         axisRst        => sAxisRst,
         axisMaster     => sAxisMaster,
         axisSlave      => sAxisSlave);

   U_AxiStreamFifoV2 : entity surf.AxiStreamFifoV2
      generic map (
         RST_ASYNC_G            => RST_ASYNC,
         INT_PIPE_STAGES_G      => INT_PIPE_STAGES,
         PIPE_STAGES_G          => PIPE_STAGES,
         SLAVE_READY_EN_G       => ite(S_HAS_TREADY = 1, true, false),
         VALID_THOLD_G          => VALID_THOLD,
         VALID_BURST_MODE_G     => VALID_BURST_MODE,
         GEN_SYNC_FIFO_G        => GEN_SYNC_FIFO,
         FIFO_ADDR_WIDTH_G      => FIFO_ADDR_WIDTH,
         FIFO_FIXED_THRESH_G    => FIFO_FIXED_THRESH,
         FIFO_PAUSE_THRESH_G    => FIFO_PAUSE_THRESH,
         SYNTH_MODE_G           => SYNTH_MODE,
         MEMORY_TYPE_G          => MEMORY_TYPE,
         INT_WIDTH_SELECT_G     => INT_WIDTH_SELECT,
         INT_DATA_WIDTH_G       => INT_DATA_WIDTH,
         LAST_FIFO_ADDR_WIDTH_G => LAST_FIFO_ADDR_WIDTH,
         CASCADE_PAUSE_SEL_G    => CASCADE_PAUSE_SEL,
         CASCADE_SIZE_G         => CASCADE_SIZE,
         SLAVE_AXI_CONFIG_G     => S_AXI_CONFIG_C,
         MASTER_AXI_CONFIG_G    => M_AXI_CONFIG_C)
      port map (
         -- Slave Port
         sAxisClk        => sAxisClk,
         sAxisRst        => sAxisRst,
         sAxisMaster     => sAxisMaster,
         sAxisSlave      => sAxisSlave,
         sAxisCtrl       => sAxisCtrl,
         -- FIFO status & config
         fifoPauseThresh => fifoPauseThresh,
         fifoWrCnt       => fifoWrCnt,
         fifoFull        => fifoFull,
         -- Master Port
         mAxisClk        => mAxisClk,
         mAxisRst        => mAxisRst,
         mAxisMaster     => mAxisMaster,
         mAxisSlave      => mAxisSlave,
         mTLastTUser     => mTLastTUser);

   sAxisPause    <= sAxisCtrl.pause;
   sAxisOverflow <= sAxisCtrl.overflow;
   sAxisIdle     <= sAxisCtrl.idle;

   U_ShimLayerMaster : entity surf.MasterAxiStreamIpIntegrator
      generic map (
         INTERFACENAME   => M_INTERFACENAME,
         HAS_TLAST       => M_HAS_TLAST,
         HAS_TKEEP       => M_HAS_TKEEP,
         HAS_TSTRB       => M_HAS_TSTRB,
         HAS_TREADY      => M_HAS_TREADY,
         TUSER_WIDTH     => M_TUSER_WIDTH,
         TID_WIDTH       => M_TID_WIDTH,
         TDEST_WIDTH     => M_TDEST_WIDTH,
         TDATA_NUM_BYTES => M_TDATA_NUM_BYTES)
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
         axisClk        => mAxisClk,
         axisRst        => mAxisRst,
         axisMaster     => mAxisMaster,
         axisSlave      => mAxisSlave);

end mapping;
