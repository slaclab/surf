library ieee;
use ieee.std_logic_1164.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;

entity AxiStreamPrbsFlowCtrlIpIntegrator is
   generic (
      TPD_G          : time                  := 1 ns;
      RST_POLARITY_G : sl                    := '1';
      RST_ASYNC_G    : boolean               := false;
      PIPE_STAGES_G  : natural range 0 to 1  := 0;
      DATA_BYTES_G   : positive              := 4;
      TUSER_WIDTH_G  : positive range 1 to 8 := 1);
   port (
      clk           : in  sl;
      rst           : in  sl;
      threshold     : in  slv(31 downto 0)               := (others => '0');
      S_AXIS_TVALID : in  sl                             := '0';
      S_AXIS_TDATA  : in  slv(DATA_BYTES_G*8-1 downto 0) := (others => '0');
      S_AXIS_TKEEP  : in  slv(DATA_BYTES_G-1 downto 0)   := (others => '0');
      S_AXIS_TLAST  : in  sl                             := '0';
      S_AXIS_TDEST  : in  slv(7 downto 0)                := (others => '0');
      S_AXIS_TID    : in  slv(7 downto 0)                := (others => '0');
      S_AXIS_TUSER  : in  slv(TUSER_WIDTH_G-1 downto 0)  := (others => '0');
      S_AXIS_TREADY : out sl;
      M_AXIS_TVALID : out sl;
      M_AXIS_TDATA  : out slv(DATA_BYTES_G*8-1 downto 0);
      M_AXIS_TKEEP  : out slv(DATA_BYTES_G-1 downto 0);
      M_AXIS_TLAST  : out sl;
      M_AXIS_TDEST  : out slv(7 downto 0);
      M_AXIS_TID    : out slv(7 downto 0);
      M_AXIS_TUSER  : out slv(TUSER_WIDTH_G-1 downto 0);
      M_AXIS_TREADY : in  sl                             := '0');
end entity AxiStreamPrbsFlowCtrlIpIntegrator;

architecture rtl of AxiStreamPrbsFlowCtrlIpIntegrator is

   signal axisAResetN : sl := '1';
   signal sAxisMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal sAxisSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;
   signal mAxisMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal mAxisSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;

begin

   axisAResetN <= not rst when (RST_POLARITY_G = '1') else rst;

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
         S_AXIS_ACLK    => clk,
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
         M_AXIS_ACLK    => clk,
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

   U_DUT : entity surf.AxiStreamPrbsFlowCtrl
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G,
         PIPE_STAGES_G  => PIPE_STAGES_G)
      port map (
         clk         => clk,
         rst         => rst,
         threshold   => threshold,
         sAxisMaster => sAxisMaster,
         sAxisSlave  => sAxisSlave,
         mAxisMaster => mAxisMaster,
         mAxisSlave  => mAxisSlave);

end architecture rtl;
