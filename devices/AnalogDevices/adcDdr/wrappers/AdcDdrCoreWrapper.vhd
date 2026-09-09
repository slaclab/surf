-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Flattened simulation wrapper for surf.AdcDdrCore
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
use surf.AdcDdrPkg.all;

entity AdcDdrCoreWrapper is
   generic (
      TPD_G            : time               := 1 ns;
      AXIL_BASE_ADDR_G : slv(31 downto 0)   := x"00000000";
      PATTERN_CHECK_G  : boolean            := true;
      NEGATE_G         : boolean            := false);
   port (
      axilClk           : in  sl;
      axilRst           : in  sl;
      S_AXI_AWADDR      : in  slv(31 downto 0);
      S_AXI_AWPROT      : in  slv(2 downto 0);
      S_AXI_AWVALID     : in  sl;
      S_AXI_AWREADY     : out sl;
      S_AXI_WDATA       : in  slv(31 downto 0);
      S_AXI_WSTRB       : in  slv(3 downto 0);
      S_AXI_WVALID      : in  sl;
      S_AXI_WREADY      : out sl;
      S_AXI_BRESP       : out slv(1 downto 0);
      S_AXI_BVALID      : out sl;
      S_AXI_BREADY      : in  sl;
      S_AXI_ARADDR      : in  slv(31 downto 0);
      S_AXI_ARPROT      : in  slv(2 downto 0);
      S_AXI_ARVALID     : in  sl;
      S_AXI_ARREADY     : out sl;
      S_AXI_RDATA       : out slv(31 downto 0);
      S_AXI_RRESP       : out slv(1 downto 0);
      S_AXI_RVALID      : out sl;
      S_AXI_RREADY      : in  sl;
      captureClk        : in  sl;
      captureRst        : in  sl;
      delayReady        : in  sl              := '0';
      fcoWord           : in  slv(13 downto 0);
      fcoValid          : in  sl;
      sampleValid       : in  sl;
      sampleIn          : in  slv(31 downto 0);
      bitSlip           : out sl;
      dataDelayValue    : out slv(31 downto 0);
      dataDelayLoad     : out slv(1 downto 0);
      fcoDelayValue     : out slv(15 downto 0);
      fcoDelayLoad      : out sl;
      phyReset          : out sl;
      streamClk         : in  sl;
      streamRst         : in  sl;
      streamValid       : out slv(1 downto 0);
      streamData        : out slv(31 downto 0);
      streamKeep        : out slv(3 downto 0);
      streamDest        : out slv(15 downto 0);
      streamLast        : out slv(1 downto 0);
      streamUser        : out slv(15 downto 0));
end entity AdcDdrCoreWrapper;

architecture rtl of AdcDdrCoreWrapper is

   signal axilReadMaster  : AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
   signal axilReadSlave   : AxiLiteReadSlaveType   := AXI_LITE_READ_SLAVE_INIT_C;
   signal axilWriteMaster : AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
   signal axilWriteSlave  : AxiLiteWriteSlaveType  := AXI_LITE_WRITE_SLAVE_INIT_C;
   signal sAxiAResetN     : sl                     := '1';
   signal dataDelayWrite  : AdcDdrDelayArray(1 downto 0);
   signal fcoDelayWrite   : AdcDdrDelayArray(0 downto 0);
   signal sampleArray     : Slv16Array(1 downto 0);
   signal streamArray     : AxiStreamMasterArray(1 downto 0);
   signal bitSlipInt      : slv(0 downto 0);

begin

   sAxiAResetN <= not axilRst;

   U_ShimLayer : entity surf.SlaveAxiLiteIpIntegrator
      generic map (
         EN_ERROR_RESP => true,
         HAS_PROT      => 1,
         HAS_WSTRB     => 1,
         ADDR_WIDTH    => 32)
      port map (
         S_AXI_ACLK      => axilClk,
         S_AXI_ARESETN   => sAxiAResetN,
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
         axilClk         => open,
         axilRst         => open,
         axilReadMaster  => axilReadMaster,
         axilReadSlave   => axilReadSlave,
         axilWriteMaster => axilWriteMaster,
         axilWriteSlave  => axilWriteSlave);

   sampleArray(0)    <= sampleIn(15 downto 0);
   sampleArray(1)    <= sampleIn(31 downto 16);

   U_DUT : entity surf.AdcDdrCore
      generic map (
         TPD_G                  => TPD_G,
         AXIL_BASE_ADDR_G       => AXIL_BASE_ADDR_G,
         DATA_LANES_G           => 2,
         FCO_LANES_G            => 1,
         CHANNELS_G             => 2,
         SAMPLE_WIDTH_G         => 14,
         SERIALIZATION_FACTOR_G => 14,
         PATTERN_CHECK_G        => PATTERN_CHECK_G,
         NEGATE_G               => NEGATE_G)
      port map (
         axilClk          => axilClk,
         axilRst          => axilRst,
         axilReadMaster   => axilReadMaster,
         axilReadSlave    => axilReadSlave,
         axilWriteMaster  => axilWriteMaster,
         axilWriteSlave   => axilWriteSlave,
         captureClk       => captureClk,
         captureRst       => captureRst,
         delayReady       => delayReady,
         fcoWord           => (0 => "00" & fcoWord),
         fcoValid          => (0 => fcoValid),
         sampleValid      => sampleValid,
         sampleIn         => sampleArray,
         phyReset         => phyReset,
         bitSlip          => bitSlipInt,
         dataDelayWrite   => dataDelayWrite,
         fcoDelayWrite    => fcoDelayWrite,
         streamClk        => streamClk,
         streamRst        => streamRst,
         streams          => streamArray);

   bitSlip <= bitSlipInt(0);
   GEN_FLATTEN : for i in 1 downto 0 generate
      dataDelayValue((i*16)+15 downto i*16) <= resize(dataDelayWrite(i).value, 16);
      dataDelayLoad(i)                     <= dataDelayWrite(i).load;
      streamValid(i)                       <= streamArray(i).tValid;
      streamData((i*16)+15 downto i*16)    <= streamArray(i).tData(15 downto 0);
      streamKeep((i*2)+1 downto i*2)       <= streamArray(i).tKeep(1 downto 0);
      streamDest((i*8)+7 downto i*8)       <= streamArray(i).tDest;
      streamLast(i)                        <= streamArray(i).tLast;
      streamUser((i*8)+7 downto i*8)       <= streamArray(i).tUser(7 downto 0);
   end generate;
   fcoDelayValue <= resize(fcoDelayWrite(0).value, 16);
   fcoDelayLoad  <= fcoDelayWrite(0).load;

end architecture rtl;
