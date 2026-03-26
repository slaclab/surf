library ieee;
use ieee.std_logic_1164.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;

entity AxiStreamFlushIpIntegrator is
   generic (
      TPD_G          : time                  := 1 ns;
      RST_POLARITY_G : sl                    := '1';
      RST_ASYNC_G    : boolean               := false;
      DATA_BYTES_G   : positive              := 4;
      TUSER_WIDTH_G  : positive range 1 to 8 := 2;
      SSI_EN_G       : boolean               := false);
   port (
      axisClk       : in  sl;
      axisRst       : in  sl;
      flushEn       : in  sl                             := '0';
      M_AXIS_PAUSE  : in  sl                             := '0';
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
      M_AXIS_TREADY : in  sl                             := '1');
end entity AxiStreamFlushIpIntegrator;

architecture rtl of AxiStreamFlushIpIntegrator is

   constant AXIS_CONFIG_C : AxiStreamConfigType := (
      TSTRB_EN_C    => false,
      TDATA_BYTES_C => DATA_BYTES_G,
      TDEST_BITS_C  => 8,
      TID_BITS_C    => 8,
      TKEEP_MODE_C  => TKEEP_NORMAL_C,
      TUSER_BITS_C  => TUSER_WIDTH_G,
      TUSER_MODE_C  => TUSER_NORMAL_C);

   signal axisAResetN : sl := '1';
   signal sAxisMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal sAxisSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;
   signal mAxisMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal mAxisCtrl   : AxiStreamCtrlType   := AXI_STREAM_CTRL_UNUSED_C;

begin

   axisAResetN <= not axisRst when (RST_POLARITY_G = '1') else axisRst;

   mAxisCtrl.pause    <= M_AXIS_PAUSE;
   mAxisCtrl.overflow <= '0';
   mAxisCtrl.idle     <= '0';

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
         axisSlave      => open);

   U_DUT : entity surf.AxiStreamFlush
      generic map (
         TPD_G         => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G   => RST_ASYNC_G,
         AXIS_CONFIG_G => AXIS_CONFIG_C,
         SSI_EN_G      => SSI_EN_G)
      port map (
         axisClk     => axisClk,
         axisRst     => axisRst,
         flushEn     => flushEn,
         sAxisMaster => sAxisMaster,
         sAxisSlave  => sAxisSlave,
         mAxisMaster => mAxisMaster,
         mAxisCtrl   => mAxisCtrl);

end architecture rtl;
