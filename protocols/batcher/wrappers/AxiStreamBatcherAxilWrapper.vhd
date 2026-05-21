-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing wrapper for surf.AxiStreamBatcherAxil
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
use surf.AxiLitePkg.all;
use surf.AxiStreamPkg.all;

entity AxiStreamBatcherAxilWrapper is
   generic (
      TPD_G                        : time                  := 1 ns;
      VERSION_G                    : positive range 1 to 2 := 2;
      DATA_BYTES_G                 : positive range 2 to 8 := 8;
      MAX_NUMBER_SUB_FRAMES_G      : positive              := 32;
      SUPER_FRAME_BYTE_THRESHOLD_G : natural               := 8192;
      MAX_CLK_GAP_G                : natural               := 256;
      INPUT_PIPE_STAGES_G          : natural               := 0;
      OUTPUT_PIPE_STAGES_G         : natural               := 1;
      AXIL_ADDR_WIDTH_G            : positive              := 12);
   port (
      axisClk       : in  sl;
      axisRst       : in  sl;
      idle          : out sl;
      S_AXIS_TVALID : in  sl;
      S_AXIS_TDATA  : in  slv(8*DATA_BYTES_G-1 downto 0);
      S_AXIS_TKEEP  : in  slv(DATA_BYTES_G-1 downto 0);
      S_AXIS_TLAST  : in  sl;
      S_AXIS_TDEST  : in  slv(7 downto 0);
      S_AXIS_TID    : in  slv(7 downto 0);
      S_AXIS_TUSER  : in  slv(8*DATA_BYTES_G-1 downto 0);
      S_AXIS_TREADY : out sl;
      M_AXIS_TVALID : out sl;
      M_AXIS_TDATA  : out slv(8*DATA_BYTES_G-1 downto 0);
      M_AXIS_TKEEP  : out slv(DATA_BYTES_G-1 downto 0);
      M_AXIS_TLAST  : out sl;
      M_AXIS_TDEST  : out slv(7 downto 0);
      M_AXIS_TID    : out slv(7 downto 0);
      M_AXIS_TUSER  : out slv(8*DATA_BYTES_G-1 downto 0);
      M_AXIS_TREADY : in  sl;
      S_AXI_AWADDR  : in  slv(AXIL_ADDR_WIDTH_G-1 downto 0);
      S_AXI_AWPROT  : in  slv(2 downto 0);
      S_AXI_AWVALID : in  sl;
      S_AXI_AWREADY : out sl;
      S_AXI_WDATA   : in  slv(31 downto 0);
      S_AXI_WSTRB   : in  slv(3 downto 0);
      S_AXI_WVALID  : in  sl;
      S_AXI_WREADY  : out sl;
      S_AXI_BRESP   : out slv(1 downto 0);
      S_AXI_BVALID  : out sl;
      S_AXI_BREADY  : in  sl;
      S_AXI_ARADDR  : in  slv(AXIL_ADDR_WIDTH_G-1 downto 0);
      S_AXI_ARPROT  : in  slv(2 downto 0);
      S_AXI_ARVALID : in  sl;
      S_AXI_ARREADY : out sl;
      S_AXI_RDATA   : out slv(31 downto 0);
      S_AXI_RRESP   : out slv(1 downto 0);
      S_AXI_RVALID  : out sl;
      S_AXI_RREADY  : in  sl);
end entity AxiStreamBatcherAxilWrapper;

architecture rtl of AxiStreamBatcherAxilWrapper is

   constant AXIS_CONFIG_C : AxiStreamConfigType := (
      TSTRB_EN_C    => false,
      TDATA_BYTES_C => DATA_BYTES_G,
      TDEST_BITS_C  => 8,
      TID_BITS_C    => 0,
      TKEEP_MODE_C  => TKEEP_NORMAL_C,
      TUSER_BITS_C  => 8,
      TUSER_MODE_C  => TUSER_FIRST_LAST_C);

   signal axilRstN        : sl;
   signal axilClk         : sl;
   signal axilRst         : sl;
   signal axilReadMaster  : AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
   signal axilReadSlave   : AxiLiteReadSlaveType   := AXI_LITE_READ_SLAVE_INIT_C;
   signal axilWriteMaster : AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
   signal axilWriteSlave  : AxiLiteWriteSlaveType  := AXI_LITE_WRITE_SLAVE_INIT_C;
   signal sAxisMaster     : AxiStreamMasterType    := AXI_STREAM_MASTER_INIT_C;
   signal sAxisSlave      : AxiStreamSlaveType     := AXI_STREAM_SLAVE_INIT_C;
   signal mAxisMaster     : AxiStreamMasterType    := AXI_STREAM_MASTER_INIT_C;
   signal mAxisSlave      : AxiStreamSlaveType     := AXI_STREAM_SLAVE_INIT_C;

begin

   axilRstN <= not axisRst;

   ------------------------
   -- AXI-Lite bus shim  --
   ------------------------
   U_AXIL : entity surf.SlaveAxiLiteIpIntegrator
      generic map (
         HAS_PROT   => 1,
         HAS_WSTRB  => 1,
         ADDR_WIDTH => AXIL_ADDR_WIDTH_G)
      port map (
         S_AXI_ACLK      => axisClk,          -- [in]
         S_AXI_ARESETN   => axilRstN,         -- [in]
         S_AXI_AWADDR    => S_AXI_AWADDR,     -- [in]
         S_AXI_AWPROT    => S_AXI_AWPROT,     -- [in]
         S_AXI_AWVALID   => S_AXI_AWVALID,    -- [in]
         S_AXI_AWREADY   => S_AXI_AWREADY,    -- [out]
         S_AXI_WDATA     => S_AXI_WDATA,      -- [in]
         S_AXI_WSTRB     => S_AXI_WSTRB,      -- [in]
         S_AXI_WVALID    => S_AXI_WVALID,     -- [in]
         S_AXI_WREADY    => S_AXI_WREADY,     -- [out]
         S_AXI_BRESP     => S_AXI_BRESP,      -- [out]
         S_AXI_BVALID    => S_AXI_BVALID,     -- [out]
         S_AXI_BREADY    => S_AXI_BREADY,     -- [in]
         S_AXI_ARADDR    => S_AXI_ARADDR,     -- [in]
         S_AXI_ARPROT    => S_AXI_ARPROT,     -- [in]
         S_AXI_ARVALID   => S_AXI_ARVALID,    -- [in]
         S_AXI_ARREADY   => S_AXI_ARREADY,    -- [out]
         S_AXI_RDATA     => S_AXI_RDATA,      -- [out]
         S_AXI_RRESP     => S_AXI_RRESP,      -- [out]
         S_AXI_RVALID    => S_AXI_RVALID,     -- [out]
         S_AXI_RREADY    => S_AXI_RREADY,     -- [in]
         axilClk         => axilClk,          -- [out]
         axilRst         => axilRst,          -- [out]
         axilReadMaster  => axilReadMaster,   -- [out]
         axilReadSlave   => axilReadSlave,    -- [in]
         axilWriteMaster => axilWriteMaster,  -- [out]
         axilWriteSlave  => axilWriteSlave);  -- [in]

   ------------------------
   -- AXI Stream shims  --
   ------------------------
   comb : process (M_AXIS_TREADY, S_AXIS_TDATA, S_AXIS_TDEST, S_AXIS_TID,
                   S_AXIS_TKEEP, S_AXIS_TLAST, S_AXIS_TUSER, S_AXIS_TVALID,
                   mAxisMaster, sAxisSlave) is
      variable vS : AxiStreamMasterType;
      variable vM : AxiStreamSlaveType;
   begin
      vS                                   := AXI_STREAM_MASTER_INIT_C;
      vS.tValid                           := S_AXIS_TVALID;
      vS.tData                            := (others => '0');
      vS.tData(8*DATA_BYTES_G-1 downto 0) := S_AXIS_TDATA;
      vS.tStrb                            := (others => '0');
      vS.tStrb(DATA_BYTES_G-1 downto 0)   := S_AXIS_TKEEP;
      vS.tKeep                            := (others => '0');
      vS.tKeep(DATA_BYTES_G-1 downto 0)   := S_AXIS_TKEEP;
      vS.tLast                            := S_AXIS_TLAST;
      vS.tDest                            := (others => '0');
      vS.tDest(7 downto 0)                := S_AXIS_TDEST;
      vS.tId                              := (others => '0');
      vS.tId(7 downto 0)                  := S_AXIS_TID;
      vS.tUser                            := (others => '0');
      vS.tUser(8*DATA_BYTES_G-1 downto 0) := S_AXIS_TUSER;

      vM        := AXI_STREAM_SLAVE_INIT_C;
      vM.tReady := M_AXIS_TREADY;

      sAxisMaster <= vS;
      mAxisSlave  <= vM;

      S_AXIS_TREADY <= sAxisSlave.tReady;
      M_AXIS_TVALID <= mAxisMaster.tValid;
      M_AXIS_TDATA  <= mAxisMaster.tData(8*DATA_BYTES_G-1 downto 0);
      M_AXIS_TKEEP  <= mAxisMaster.tKeep(DATA_BYTES_G-1 downto 0);
      M_AXIS_TLAST  <= mAxisMaster.tLast;
      M_AXIS_TDEST  <= mAxisMaster.tDest(7 downto 0);
      M_AXIS_TID    <= mAxisMaster.tId(7 downto 0);
      M_AXIS_TUSER  <= mAxisMaster.tUser(8*DATA_BYTES_G-1 downto 0);
   end process comb;

   ---------------------
   -- DUT instancing  --
   ---------------------
   U_DUT : entity surf.AxiStreamBatcherAxil
      generic map (
         TPD_G                        => TPD_G,
         VERSION_G                    => VERSION_G,
         COMMON_CLOCK_G               => true,
         MAX_NUMBER_SUB_FRAMES_G      => MAX_NUMBER_SUB_FRAMES_G,
         SUPER_FRAME_BYTE_THRESHOLD_G => SUPER_FRAME_BYTE_THRESHOLD_G,
         MAX_CLK_GAP_G                => MAX_CLK_GAP_G,
         AXIS_CONFIG_G                => AXIS_CONFIG_C,
         INPUT_PIPE_STAGES_G          => INPUT_PIPE_STAGES_G,
         OUTPUT_PIPE_STAGES_G         => OUTPUT_PIPE_STAGES_G)
      port map (
         axisClk         => axisClk,           -- [in]
         axisRst         => axisRst,           -- [in]
         idle            => idle,              -- [out]
         sAxisMaster     => sAxisMaster,       -- [in]
         sAxisSlave      => sAxisSlave,        -- [out]
         mAxisMaster     => mAxisMaster,       -- [out]
         mAxisSlave      => mAxisSlave,        -- [in]
         axilClk         => axilClk,           -- [in]
         axilRst         => axilRst,           -- [in]
         axilReadMaster  => axilReadMaster,    -- [in]
         axilReadSlave   => axilReadSlave,     -- [out]
         axilWriteMaster => axilWriteMaster,   -- [in]
         axilWriteSlave  => axilWriteSlave);   -- [out]

end architecture rtl;
