-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: IP Integrator Wrapper for surf.AxiVersion
-------------------------------------------------------------------------------
-- TCL Command: create_bd_cell -type module -reference AxiDualPortRamIpIntegrator AxiDualPortRam_0
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
use surf.AxiLitePkg.all;

entity AxiDualPortRamIpIntegrator is
   generic (
      EN_ERROR_RESP     : boolean              := false;
      SYNTH_MODE        : string               := "inferred";
      MEMORY_TYPE       : string               := "block";
      MEMORY_INIT_FILE  : string               := "none";  -- Used for MEMORY_TYPE="XPM only
      MEMORY_INIT_PARAM : string               := "0";  -- Used for MEMORY_TYPE="XPM only
      READ_LATENCY      : natural range 0 to 3 := 3;
      AXI_WR_EN         : boolean              := true;
      SYS_WR_EN         : boolean              := false;
      SYS_BYTE_WR_EN    : boolean              := false;
      COMMON_CLK        : boolean              := false;
      ADDR_WIDTH        : positive             := 5;
      DATA_WIDTH        : positive             := 32;
      INIT              : slv                  := "0");
   port (
      -- AXI-Lite Interface
      S_AXI_ACLK    : in  std_logic;
      S_AXI_ARESETN : in  std_logic;
      S_AXI_AWADDR  : in  std_logic_vector(ADDR_WIDTH+1 downto 0);
      S_AXI_AWPROT  : in  std_logic_vector(2 downto 0);
      S_AXI_AWVALID : in  std_logic;
      S_AXI_AWREADY : out std_logic;
      S_AXI_WDATA   : in  std_logic_vector(31 downto 0);
      S_AXI_WSTRB   : in  std_logic_vector(3 downto 0);
      S_AXI_WVALID  : in  std_logic;
      S_AXI_WREADY  : out std_logic;
      S_AXI_BRESP   : out std_logic_vector(1 downto 0);
      S_AXI_BVALID  : out std_logic;
      S_AXI_BREADY  : in  std_logic;
      S_AXI_ARADDR  : in  std_logic_vector(ADDR_WIDTH+1 downto 0);
      S_AXI_ARPROT  : in  std_logic_vector(2 downto 0);
      S_AXI_ARVALID : in  std_logic;
      S_AXI_ARREADY : out std_logic;
      S_AXI_RDATA   : out std_logic_vector(31 downto 0);
      S_AXI_RRESP   : out std_logic_vector(1 downto 0);
      S_AXI_RVALID  : out std_logic;
      S_AXI_RREADY  : in  std_logic;
      -- RAM Interface
      S_RAM_CLK     : in  std_logic                                     := '0';
      S_RAM_EN      : in  std_logic                                     := '1';
      S_RAM_WE      : in  std_logic_vector((DATA_WIDTH/8)-1 downto 0) := (others => '0');
      S_RAM_RST     : in  std_logic                                     := '0';
      S_RAM_ADDR    : in  std_logic_vector(ADDR_WIDTH-1 downto 0)     := (others => '0');
      S_RAM_DIN     : in  std_logic_vector(DATA_WIDTH-1 downto 0)     := (others => '0');
      S_RAM_DOUT    : out std_logic_vector(DATA_WIDTH-1 downto 0));
end AxiDualPortRamIpIntegrator;

architecture mapping of AxiDualPortRamIpIntegrator is

   signal axilClk         : sl;
   signal axilRst         : sl;
   signal axilReadMaster  : AxiLiteReadMasterType;
   signal axilReadSlave   : AxiLiteReadSlaveType;
   signal axilWriteMaster : AxiLiteWriteMasterType;
   signal axilWriteSlave  : AxiLiteWriteSlaveType;

   signal clk  : sl;
   signal en   : sl;
   signal we   : slv((DATA_WIDTH/8)-1 downto 0);
   signal rst  : sl;
   signal addr : slv(ADDR_WIDTH-1 downto 0);
   signal din  : slv(DATA_WIDTH-1 downto 0);
   signal dout : slv(DATA_WIDTH-1 downto 0);

   signal uOrWe     : sl;
   signal intWe     : sl;
   signal intWeByte : slv(wordCount(DATA_WIDTH, 8)-1 downto 0);

begin

   U_ShimLayerAxiLite : entity surf.SlaveAxiLiteIpIntegrator
      generic map (
         EN_ERROR_RESP => EN_ERROR_RESP,
         HAS_WSTRB       => 1,          -- Using write strobe
         ADDR_WIDTH    => ADDR_WIDTH+2)
      port map (
         -- IP Integrator AXI-Lite Interface
         S_AXI_ACLK      => S_AXI_ACLK,
         S_AXI_ARESETN   => S_AXI_ARESETN,
         S_AXI_AWADDR    => S_AXI_AWADDR,
         S_AXI_AWPROT    => S_AXI_AWPROT,
         S_AXI_AWVALID   => S_AXI_AWVALID,
         S_AXI_AWREADY   => S_AXI_AWREADY,
         S_AXI_WDATA     => S_AXI_WDATA,
         S_AXI_WSTRB     => S_AXI_WSTRB,
         S_AXI_WVALID    => S_AXI_WVALID,
         S_AXI_WREADY    => S_AXI_WREADY,
         S_AXI_BRESP     => S_AXI_BRESP,
         S_AXI_BVALID    => S_AXI_BVALID,
         S_AXI_BREADY    => S_AXI_BREADY,
         S_AXI_ARADDR    => S_AXI_ARADDR,
         S_AXI_ARPROT    => S_AXI_ARPROT,
         S_AXI_ARVALID   => S_AXI_ARVALID,
         S_AXI_ARREADY   => S_AXI_ARREADY,
         S_AXI_RDATA     => S_AXI_RDATA,
         S_AXI_RRESP     => S_AXI_RRESP,
         S_AXI_RVALID    => S_AXI_RVALID,
         S_AXI_RREADY    => S_AXI_RREADY,
         -- SURF AXI-Lite Interface
         axilClk         => axilClk,
         axilRst         => axilRst,
         axilReadMaster  => axilReadMaster,
         axilReadSlave   => axilReadSlave,
         axilWriteMaster => axilWriteMaster,
         axilWriteSlave  => axilWriteSlave);

   U_ShimLayerRam : entity surf.SlaveRamIpIntegrator
      generic map (
         READ_LATENCY => READ_LATENCY,
         ADDR_WIDTH   => ADDR_WIDTH,
         DATA_WIDTH   => DATA_WIDTH)
      port map (
         -- IP Integrator RAM Interface
         S_RAM_CLK  => S_RAM_CLK,
         S_RAM_EN   => S_RAM_EN,
         S_RAM_WE   => S_RAM_WE,
         S_RAM_RST  => S_RAM_RST,
         S_RAM_ADDR => S_RAM_ADDR,
         S_RAM_DIN  => S_RAM_DIN,
         S_RAM_DOUT => S_RAM_DOUT,
         -- SURF RAM Interface
         clk        => clk,
         en         => en,
         we         => we,
         rst        => rst,
         addr       => addr,
         din        => din,
         dout       => dout);

   U_AxiDualPortRam : entity surf.AxiDualPortRam
      generic map (
         SYNTH_MODE_G        => SYNTH_MODE,
         MEMORY_TYPE_G       => MEMORY_TYPE,
         MEMORY_INIT_FILE_G  => MEMORY_INIT_FILE,
         MEMORY_INIT_PARAM_G => MEMORY_INIT_PARAM,
         READ_LATENCY_G      => READ_LATENCY,
         AXI_WR_EN_G         => AXI_WR_EN,
         SYS_WR_EN_G         => SYS_WR_EN,
         SYS_BYTE_WR_EN_G    => SYS_BYTE_WR_EN,
         COMMON_CLK_G        => COMMON_CLK,
         ADDR_WIDTH_G        => ADDR_WIDTH,
         DATA_WIDTH_G        => DATA_WIDTH,
         INIT_G              => INIT)
      port map (
         -- AXI-Lite Interface
         axiClk         => axilClk,
         axiRst         => axilRst,
         axiReadMaster  => axilReadMaster,
         axiReadSlave   => axilReadSlave,
         axiWriteMaster => axilWriteMaster,
         axiWriteSlave  => axilWriteSlave,
         -- Standard Port
         clk            => clk,
         en             => en,
         we             => intWe,
         weByte         => intWeByte,
         rst            => rst,
         addr           => addr,
         din            => din,
         dout           => dout);

   uOrWe     <= uOr(WE);
   intWe     <= uOrWe;
   intWeByte <= WE when(SYS_BYTE_WR_EN) else (others => uOrWe);

end mapping;
