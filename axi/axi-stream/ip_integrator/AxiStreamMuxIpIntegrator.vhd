library ieee;
use ieee.std_logic_1164.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;

entity AxiStreamMuxIpIntegrator is
   generic (
      TPD_G           : time                   := 1 ns;
      RST_POLARITY_G  : sl                     := '1';
      RST_ASYNC_G     : boolean                := false;
      DATA_BYTES_G    : positive               := 4;
      TUSER_WIDTH_G   : positive range 1 to 8  := 1;
      PIPE_STAGES_G   : natural                := 0;
      MODE_G          : string                 := "INDEXED";
      TDEST_ROUTE_0_G : natural range 0 to 255 := 0;
      TDEST_ROUTE_1_G : natural range 0 to 255 := 1;
      TID_MODE_G      : string                 := "PASSTHROUGH";
      TID_ROUTE_0_G   : natural range 0 to 255 := 0;
      TID_ROUTE_1_G   : natural range 0 to 255 := 1;
      PRIORITY_0_G    : integer                := 0;
      PRIORITY_1_G    : integer                := 0;
      TDEST_LOW_G     : integer range 0 to 7   := 0);
   port (
      axisClk        : in  sl;
      axisRst        : in  sl;
      disableSel     : in  slv(1 downto 0)                := (others => '0');
      S0_AXIS_TVALID : in  sl                             := '0';
      S0_AXIS_TDATA  : in  slv(DATA_BYTES_G*8-1 downto 0) := (others => '0');
      S0_AXIS_TKEEP  : in  slv(DATA_BYTES_G-1 downto 0)   := (others => '0');
      S0_AXIS_TLAST  : in  sl                             := '0';
      S0_AXIS_TDEST  : in  slv(7 downto 0)                := (others => '0');
      S0_AXIS_TID    : in  slv(7 downto 0)                := (others => '0');
      S0_AXIS_TUSER  : in  slv(TUSER_WIDTH_G-1 downto 0)  := (others => '0');
      S0_AXIS_TREADY : out sl;
      S1_AXIS_TVALID : in  sl                             := '0';
      S1_AXIS_TDATA  : in  slv(DATA_BYTES_G*8-1 downto 0) := (others => '0');
      S1_AXIS_TKEEP  : in  slv(DATA_BYTES_G-1 downto 0)   := (others => '0');
      S1_AXIS_TLAST  : in  sl                             := '0';
      S1_AXIS_TDEST  : in  slv(7 downto 0)                := (others => '0');
      S1_AXIS_TID    : in  slv(7 downto 0)                := (others => '0');
      S1_AXIS_TUSER  : in  slv(TUSER_WIDTH_G-1 downto 0)  := (others => '0');
      S1_AXIS_TREADY : out sl;
      M_AXIS_TVALID  : out sl;
      M_AXIS_TDATA   : out slv(DATA_BYTES_G*8-1 downto 0);
      M_AXIS_TKEEP   : out slv(DATA_BYTES_G-1 downto 0);
      M_AXIS_TLAST   : out sl;
      M_AXIS_TDEST   : out slv(7 downto 0);
      M_AXIS_TID     : out slv(7 downto 0);
      M_AXIS_TUSER   : out slv(TUSER_WIDTH_G-1 downto 0);
      M_AXIS_TREADY  : in  sl                             := '0');
end entity AxiStreamMuxIpIntegrator;

architecture rtl of AxiStreamMuxIpIntegrator is

   constant PRIORITY_C : IntegerArray(1 downto 0) := (
      0 => PRIORITY_0_G,
      1 => PRIORITY_1_G);

   constant TDEST_ROUTES_C : Slv8Array(1 downto 0) := (
      0 => toSlv(TDEST_ROUTE_0_G, 8),
      1 => toSlv(TDEST_ROUTE_1_G, 8));

   constant TID_ROUTES_C : Slv8Array(1 downto 0) := (
      0 => toSlv(TID_ROUTE_0_G, 8),
      1 => toSlv(TID_ROUTE_1_G, 8));

   signal axisAResetN  : sl := '1';
   signal sAxisMasters : AxiStreamMasterArray(1 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
   signal sAxisSlaves  : AxiStreamSlaveArray(1 downto 0) := (others => AXI_STREAM_SLAVE_INIT_C);
   signal mAxisMaster  : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal mAxisSlave   : AxiStreamSlaveType := AXI_STREAM_SLAVE_INIT_C;

begin

   axisAResetN <= not axisRst when (RST_POLARITY_G = '1') else axisRst;

   U_ShimLayerSlave0 : entity surf.SlaveAxiStreamIpIntegrator
      generic map (
         INTERFACENAME   => "S0_AXIS",
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
         S_AXIS_TVALID  => S0_AXIS_TVALID,
         S_AXIS_TDATA   => S0_AXIS_TDATA,
         S_AXIS_TSTRB   => (others => '0'),
         S_AXIS_TKEEP   => S0_AXIS_TKEEP,
         S_AXIS_TLAST   => S0_AXIS_TLAST,
         S_AXIS_TDEST   => S0_AXIS_TDEST,
         S_AXIS_TID     => S0_AXIS_TID,
         S_AXIS_TUSER   => S0_AXIS_TUSER,
         S_AXIS_TREADY  => S0_AXIS_TREADY,
         axisClk        => open,
         axisRst        => open,
         axisMaster     => sAxisMasters(0),
         axisSlave      => sAxisSlaves(0));

   U_ShimLayerSlave1 : entity surf.SlaveAxiStreamIpIntegrator
      generic map (
         INTERFACENAME   => "S1_AXIS",
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
         S_AXIS_TVALID  => S1_AXIS_TVALID,
         S_AXIS_TDATA   => S1_AXIS_TDATA,
         S_AXIS_TSTRB   => (others => '0'),
         S_AXIS_TKEEP   => S1_AXIS_TKEEP,
         S_AXIS_TLAST   => S1_AXIS_TLAST,
         S_AXIS_TDEST   => S1_AXIS_TDEST,
         S_AXIS_TID     => S1_AXIS_TID,
         S_AXIS_TUSER   => S1_AXIS_TUSER,
         S_AXIS_TREADY  => S1_AXIS_TREADY,
         axisClk        => open,
         axisRst        => open,
         axisMaster     => sAxisMasters(1),
         axisSlave      => sAxisSlaves(1));

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

   U_DUT : entity surf.AxiStreamMux
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G,
         PIPE_STAGES_G  => PIPE_STAGES_G,
         NUM_SLAVES_G   => 2,
         MODE_G         => MODE_G,
         TDEST_ROUTES_G => TDEST_ROUTES_C,
         TID_MODE_G     => TID_MODE_G,
         TID_ROUTES_G   => TID_ROUTES_C,
         PRIORITY_G     => PRIORITY_C,
         TDEST_LOW_G    => TDEST_LOW_G)
      port map (
         axisClk      => axisClk,
         axisRst      => axisRst,
         disableSel   => disableSel,
         rearbitrate  => '0',
         ileaveRearb  => (others => '0'),
         sAxisMasters => sAxisMasters,
         sAxisSlaves  => sAxisSlaves,
         mAxisMaster  => mAxisMaster,
         mAxisSlave   => mAxisSlave);

end architecture rtl;
