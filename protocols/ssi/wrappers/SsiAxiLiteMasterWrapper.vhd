-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing wrapper for SsiAxiLiteMaster
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
use surf.SsiPkg.all;

entity SsiAxiLiteMasterWrapper is
   port (
      axisClk        : in  sl;
      axisRst        : in  sl;
      sAxisTValid    : in  sl;
      sAxisTData     : in  slv(63 downto 0);
      sAxisTKeep     : in  slv(7 downto 0);
      sAxisTLast     : in  sl;
      sAxisSof       : in  sl;
      sAxisEofe      : in  sl;
      sAxisTReady    : out sl;
      mAxisTValid    : out sl;
      mAxisTData     : out slv(63 downto 0);
      mAxisTKeep     : out slv(7 downto 0);
      mAxisTLast     : out sl;
      mAxisSof       : out sl;
      mAxisEofe      : out sl;
      mAxisTReady    : in  sl;
      M_AXIL_AWADDR  : out slv(31 downto 0);
      M_AXIL_AWPROT  : out slv(2 downto 0);
      M_AXIL_AWVALID : out sl;
      M_AXIL_AWREADY : in  sl;
      M_AXIL_WDATA   : out slv(31 downto 0);
      M_AXIL_WSTRB   : out slv(3 downto 0);
      M_AXIL_WVALID  : out sl;
      M_AXIL_WREADY  : in  sl;
      M_AXIL_BRESP   : in  slv(1 downto 0);
      M_AXIL_BVALID  : in  sl;
      M_AXIL_BREADY  : out sl;
      M_AXIL_ARADDR  : out slv(31 downto 0);
      M_AXIL_ARPROT  : out slv(2 downto 0);
      M_AXIL_ARVALID : out sl;
      M_AXIL_ARREADY : in  sl;
      M_AXIL_RDATA   : in  slv(31 downto 0);
      M_AXIL_RRESP   : in  slv(1 downto 0);
      M_AXIL_RVALID  : in  sl;
      M_AXIL_RREADY  : out sl);
end entity SsiAxiLiteMasterWrapper;

architecture rtl of SsiAxiLiteMasterWrapper is

   constant AXIS_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(
      dataBytes => 4,
      tKeepMode => TKEEP_COMP_C,
      tUserMode => TUSER_FIRST_LAST_C,
      tUserBits => 2);

   signal sAxisMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal sAxisSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;
   signal mAxisMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal mAxisSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;

   signal mAxiLiteWriteMaster : AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
   signal mAxiLiteWriteSlave  : AxiLiteWriteSlaveType  := AXI_LITE_WRITE_SLAVE_INIT_C;
   signal mAxiLiteReadMaster  : AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
   signal mAxiLiteReadSlave   : AxiLiteReadSlaveType   := AXI_LITE_READ_SLAVE_INIT_C;

begin

   sAxisComb : process (sAxisEofe, sAxisSof, sAxisTData, sAxisTKeep, sAxisTLast, sAxisTValid) is
      variable v : AxiStreamMasterType;
   begin
      v := AXI_STREAM_MASTER_INIT_C;
      v.tValid := sAxisTValid;
      v.tData(31 downto 0) := sAxisTData(31 downto 0);
      v.tKeep(3 downto 0) := sAxisTKeep(3 downto 0);
      v.tLast := sAxisTLast;
      ssiSetUserSof(AXIS_CONFIG_C, v, sAxisSof);
      ssiSetUserEofe(AXIS_CONFIG_C, v, sAxisEofe);
      sAxisMaster <= v;
   end process sAxisComb;

   sAxisTReady <= sAxisSlave.tReady;
   mAxisSlave.tReady <= mAxisTReady;

   mAxisView : process (mAxisMaster) is
      variable dataV : slv(63 downto 0);
      variable keepV : slv(7 downto 0);
   begin
      dataV := (others => '0');
      keepV := (others => '0');

      dataV(31 downto 0) := mAxisMaster.tData(31 downto 0);
      keepV(3 downto 0) := mAxisMaster.tKeep(3 downto 0);

      mAxisTValid <= mAxisMaster.tValid;
      mAxisTData <= dataV;
      mAxisTKeep <= keepV;
      mAxisTLast <= mAxisMaster.tLast;
      mAxisSof <= ssiGetUserSof(AXIS_CONFIG_C, mAxisMaster);
      mAxisEofe <= ssiGetUserEofe(AXIS_CONFIG_C, mAxisMaster);
   end process mAxisView;

   M_AXIL_AWADDR <= mAxiLiteWriteMaster.awaddr;
   M_AXIL_AWPROT <= mAxiLiteWriteMaster.awprot;
   M_AXIL_AWVALID <= mAxiLiteWriteMaster.awvalid;
   M_AXIL_WDATA <= mAxiLiteWriteMaster.wdata;
   M_AXIL_WSTRB <= mAxiLiteWriteMaster.wstrb;
   M_AXIL_WVALID <= mAxiLiteWriteMaster.wvalid;
   M_AXIL_BREADY <= mAxiLiteWriteMaster.bready;
   M_AXIL_ARADDR <= mAxiLiteReadMaster.araddr;
   M_AXIL_ARPROT <= mAxiLiteReadMaster.arprot;
   M_AXIL_ARVALID <= mAxiLiteReadMaster.arvalid;
   M_AXIL_RREADY <= mAxiLiteReadMaster.rready;

   mAxiLiteWriteSlave.awready <= M_AXIL_AWREADY;
   mAxiLiteWriteSlave.wready <= M_AXIL_WREADY;
   mAxiLiteWriteSlave.bresp <= M_AXIL_BRESP;
   mAxiLiteWriteSlave.bvalid <= M_AXIL_BVALID;
   mAxiLiteReadSlave.arready <= M_AXIL_ARREADY;
   mAxiLiteReadSlave.rdata <= M_AXIL_RDATA;
   mAxiLiteReadSlave.rresp <= M_AXIL_RRESP;
   mAxiLiteReadSlave.rvalid <= M_AXIL_RVALID;

   U_DUT : entity surf.SsiAxiLiteMaster
      generic map (
         TPD_G                => 1 ns,
         RESP_THOLD_G         => 1,
         SLAVE_READY_EN_G     => true,
         EN_32BIT_ADDR_G      => false,
         MEMORY_TYPE_G        => "distributed",
         GEN_SYNC_FIFO_G      => true,
         FIFO_ADDR_WIDTH_G    => 4,
         FIFO_PAUSE_THRESH_G  => 1,
         AXI_STREAM_CONFIG_G  => AXIS_CONFIG_C)
      port map (
         sAxisClk            => axisClk,
         sAxisRst            => axisRst,
         sAxisMaster         => sAxisMaster,
         sAxisSlave          => sAxisSlave,
         sAxisCtrl           => open,
         mAxisClk            => axisClk,
         mAxisRst            => axisRst,
         mAxisMaster         => mAxisMaster,
         mAxisSlave          => mAxisSlave,
         axiLiteClk          => axisClk,
         axiLiteRst          => axisRst,
         mAxiLiteWriteMaster => mAxiLiteWriteMaster,
         mAxiLiteWriteSlave  => mAxiLiteWriteSlave,
         mAxiLiteReadMaster  => mAxiLiteReadMaster,
         mAxiLiteReadSlave   => mAxiLiteReadSlave);

end architecture rtl;
