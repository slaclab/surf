-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing wrapper for surf.Pgp2fcAlignmentController
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;

entity Pgp2fcAlignmentControllerWrapper is
   port (
      clk                 : in  sl;
      rst                 : in  sl;
      linkAlignOverride   : in  sl               := '0';
      linkAlignSlide      : in  sl               := '0';
      linkAlignPhaseReq   : in  sl               := '0';
      protocolError       : in  sl               := '0';
      rxReady             : in  sl               := '1';
      axilReadDone        : in  sl               := '0';
      axilReadData        : in  slv(31 downto 0) := (others => '0');
      linkAligned         : out sl;
      linkAlignSlideDone  : out sl;
      linkAlignPhase      : out sl;
      linkAlignPhaseValid : out sl;
      rxReset             : out sl;
      rxSlide             : out sl;
      axilReadRequest     : out sl;
      axilReadAddress     : out slv(31 downto 0));
end entity Pgp2fcAlignmentControllerWrapper;

architecture rtl of Pgp2fcAlignmentControllerWrapper is

   signal mAxilReadMaster  : AxiLiteReadMasterType;
   signal mAxilWriteMaster : AxiLiteWriteMasterType;
   signal mAxilReadSlave   : AxiLiteReadSlaveType  := AXI_LITE_READ_SLAVE_INIT_C;

begin

   axilReadRequest <= mAxilReadMaster.arvalid;
   axilReadAddress <= mAxilReadMaster.araddr;

   mAxilReadSlave.arready <= '1';
   mAxilReadSlave.rvalid  <= axilReadDone;
   mAxilReadSlave.rdata   <= axilReadData;
   mAxilReadSlave.rresp   <= AXI_RESP_OK_C;

   U_DUT : entity surf.Pgp2fcAlignmentController
      port map (
         stableClk         => clk,
         stableRst         => rst,
         linkAligned       => linkAligned,
         linkAlignOverride => linkAlignOverride,
         linkAlignSlide    => linkAlignSlide,
         linkAlignSlideDone => linkAlignSlideDone,
         linkAlignPhaseReq  => linkAlignPhaseReq,
         linkAlignPhase     => linkAlignPhase,
         linkAlignPhaseValid => linkAlignPhaseValid,
         protocolError      => protocolError,
         rxClk              => clk,
         rxReset            => rxReset,
         rxSlide            => rxSlide,
         rxReady            => rxReady,
         axilClk            => clk,
         axilRst            => rst,
         mAxilReadMaster    => mAxilReadMaster,
         mAxilReadSlave     => mAxilReadSlave,
         mAxilWriteMaster   => mAxilWriteMaster,
         mAxilWriteSlave    => AXI_LITE_WRITE_SLAVE_INIT_C);

end architecture rtl;
