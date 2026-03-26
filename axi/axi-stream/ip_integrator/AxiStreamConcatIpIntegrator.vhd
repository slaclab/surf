library ieee;
use ieee.std_logic_1164.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;

entity AxiStreamConcatIpIntegrator is
   generic (
      TPD_G                        : time                  := 1 ns;
      RST_POLARITY_G               : sl                    := '1';
      RST_ASYNC_G                  : boolean               := false;
      DATA_BYTES_G                 : positive              := 4;
      TUSER_WIDTH_G                : positive range 1 to 8 := 2;
      MAX_NUMBER_SUB_FRAMES_G      : positive              := 4;
      SUPER_FRAME_BYTE_THRESHOLD_G : natural               := 32;
      MAX_CLK_GAP_G                : natural               := 8;
      INPUT_PIPE_STAGES_G          : natural               := 0;
      OUTPUT_PIPE_STAGES_G         : natural               := 0);
   port (
      axisClk                 : in  sl;
      axisRst                 : in  sl;
      forceTerm               : in  sl                             := '0';
      superFrameByteThreshold : in  slv(31 downto 0)               := (others => '0');
      maxSubFrames            : in  slv(15 downto 0)               := (others => '0');
      maxClkGap               : in  slv(31 downto 0)               := (others => '0');
      idle                    : out sl;
      S_AXIS_TVALID           : in  sl                             := '0';
      S_AXIS_TDATA            : in  slv(DATA_BYTES_G*8-1 downto 0) := (others => '0');
      S_AXIS_TKEEP            : in  slv(DATA_BYTES_G-1 downto 0)   := (others => '1');
      S_AXIS_TLAST            : in  sl                             := '0';
      S_AXIS_TDEST            : in  slv(7 downto 0)                := (others => '0');
      S_AXIS_TID              : in  slv(7 downto 0)                := (others => '0');
      S_AXIS_TUSER            : in  slv(TUSER_WIDTH_G-1 downto 0)  := (others => '0');
      S_AXIS_TREADY           : out sl;
      M_AXIS_TVALID           : out sl;
      M_AXIS_TDATA            : out slv(DATA_BYTES_G*8-1 downto 0);
      M_AXIS_TKEEP            : out slv(DATA_BYTES_G-1 downto 0);
      M_AXIS_TLAST            : out sl;
      M_AXIS_TDEST            : out slv(7 downto 0);
      M_AXIS_TID              : out slv(7 downto 0);
      M_AXIS_TUSER            : out slv(TUSER_WIDTH_G-1 downto 0);
      M_AXIS_TREADY           : in  sl                             := '0');
end entity AxiStreamConcatIpIntegrator;

architecture rtl of AxiStreamConcatIpIntegrator is

   constant AXIS_CONFIG_C : AxiStreamConfigType := (
      TSTRB_EN_C    => false,
      TDATA_BYTES_C => DATA_BYTES_G,
      TDEST_BITS_C  => 8,
      TID_BITS_C    => 8,
      TKEEP_MODE_C  => TKEEP_FIXED_C,
      TUSER_BITS_C  => TUSER_WIDTH_G,
      TUSER_MODE_C  => TUSER_FIRST_LAST_C);

   signal axisAResetN : sl := '1';
   signal sAxisMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal sAxisSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;
   signal mAxisMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal mAxisSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;

begin

   axisAResetN <= not axisRst when (RST_POLARITY_G = '1') else axisRst;

   U_ShimLayerSlave : entity surf.SlaveAxiStreamIpIntegrator
      generic map (
         INTERFACENAME   => "S_AXIS",
         HAS_TLAST       => 1,
         HAS_TKEEP       => 1,
         HAS_TSTRB       => 0,
         HAS_TREADY      => 1,
         TUSER_WIDTH     => TUSER_WIDTH_G,
         TID_WIDTH       => 8,
         TDEST_WIDTH     => 8,
         TDATA_NUM_BYTES => DATA_BYTES_G)
      port map (
         S_AXIS_ACLK    => axisClk,
         S_AXIS_ARESETN => axisAResetN,
         S_AXIS_TVALID  => S_AXIS_TVALID,
         S_AXIS_TDATA   => S_AXIS_TDATA,
         S_AXIS_TSTRB   => (others => '0'),
         S_AXIS_TKEEP   => S_AXIS_TKEEP,
         S_AXIS_TLAST   => S_AXIS_TLAST,
         S_AXIS_TDEST   => S_AXIS_TDEST,
         S_AXIS_TID     => S_AXIS_TID,
         S_AXIS_TUSER   => S_AXIS_TUSER,
         S_AXIS_TREADY  => S_AXIS_TREADY,
         axisClk        => open,
         axisRst        => open,
         axisMaster     => sAxisMaster,
         axisSlave      => sAxisSlave);

   U_ShimLayerMaster : entity surf.MasterAxiStreamIpIntegrator
      generic map (
         INTERFACENAME   => "M_AXIS",
         HAS_TLAST       => 1,
         HAS_TKEEP       => 1,
         HAS_TSTRB       => 0,
         HAS_TREADY      => 1,
         TUSER_WIDTH     => TUSER_WIDTH_G,
         TID_WIDTH       => 8,
         TDEST_WIDTH     => 8,
         TDATA_NUM_BYTES => DATA_BYTES_G)
      port map (
         M_AXIS_ACLK    => axisClk,
         M_AXIS_ARESETN => axisAResetN,
         M_AXIS_TVALID  => M_AXIS_TVALID,
         M_AXIS_TDATA   => M_AXIS_TDATA,
         M_AXIS_TSTRB   => open,
         M_AXIS_TKEEP   => M_AXIS_TKEEP,
         M_AXIS_TLAST   => M_AXIS_TLAST,
         M_AXIS_TDEST   => M_AXIS_TDEST,
         M_AXIS_TID     => M_AXIS_TID,
         M_AXIS_TUSER   => M_AXIS_TUSER,
         M_AXIS_TREADY  => M_AXIS_TREADY,
         axisClk        => open,
         axisRst        => open,
         axisMaster     => mAxisMaster,
         axisSlave      => mAxisSlave);

   U_DUT : entity surf.AxiStreamConcat
      generic map (
         TPD_G                        => TPD_G,
         RST_POLARITY_G               => RST_POLARITY_G,
         RST_ASYNC_G                  => RST_ASYNC_G,
         MAX_NUMBER_SUB_FRAMES_G      => MAX_NUMBER_SUB_FRAMES_G,
         SUPER_FRAME_BYTE_THRESHOLD_G => SUPER_FRAME_BYTE_THRESHOLD_G,
         MAX_CLK_GAP_G                => MAX_CLK_GAP_G,
         AXIS_CONFIG_G                => AXIS_CONFIG_C,
         INPUT_PIPE_STAGES_G          => INPUT_PIPE_STAGES_G,
         OUTPUT_PIPE_STAGES_G         => OUTPUT_PIPE_STAGES_G)
      port map (
         axisClk                 => axisClk,
         axisRst                 => axisRst,
         forceTerm               => forceTerm,
         superFrameByteThreshold => superFrameByteThreshold,
         maxSubFrames            => maxSubFrames,
         maxClkGap               => maxClkGap,
         idle                    => idle,
         sAxisMaster             => sAxisMaster,
         sAxisSlave              => sAxisSlave,
         mAxisMaster             => mAxisMaster,
         mAxisSlave              => mAxisSlave);

end architecture rtl;
