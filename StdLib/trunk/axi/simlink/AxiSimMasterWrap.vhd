library ieee;
use ieee.std_logic_1164.all;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;

library unisim;
use unisim.vcomponents.all;

use work.StdRtlPkg.all;
use work.AxiPkg.all;

entity AxiSimMasterWrap is
   generic (
      TPD_G       : time                   := 1 ns;
      MASTER_ID_G : integer range 0 to 255 := 0
   );
   port (

      -- AXI Clock/Rst
      axiClk            : in  sl;

      -- Master
      mstAxiReadMaster  : out AxiReadMasterType;
      mstAxiReadSlave   : in  AxiReadSlaveType;
      mstAxiWriteMaster : out AxiWriteMasterType;
      mstAxiWriteSlave  : in  AxiWriteSlaveType
   );
end AxiSimMasterWrap;

architecture structure of AxiSimMasterWrap is

   signal masterId : slv(7 downto 0);

begin

   masterId <= conv_std_logic_vector(MASTER_ID_G,8);

   U_AxiMaster : AxiSimMaster 
      port map (
         axiClk          => axiClk,
         masterId        => masterId,
         arvalid         => mstAxiReadMaster.arvalid,
         arready         => mstAxiReadSlave.arready,
         araddr          => mstAxiReadMaster.araddr,
         arid            => mstAxiReadMaster.arid,
         arlen           => mstAxiReadMaster.arlen,
         arsize          => mstAxiReadMaster.arsize,
         arburst         => mstAxiReadMaster.arburst,
         arlock          => mstAxiReadMaster.arlock,
         arprot          => mstAxiReadMaster.arprot,
         arcache         => mstAxiReadMaster.arcache,
         rready          => mstAxiReadMaster.rready,
         rdataH          => mstAxiReadSlave.rdata(63 downto 32),
         rdataL          => mstAxiReadSlave.rdata(31 downto  0),
         rlast           => mstAxiReadSlave.rlast,
         rvalid          => mstAxiReadSlave.rvalid,
         rid             => mstAxiReadSlave.rid,
         rresp           => mstAxiReadSlave.rresp,
         awvalid         => mstAxiWriteMaster.awvalid,
         awready         => mstAxiWriteSlave.awready,
         awaddr          => mstAxiWriteMaster.awaddr,
         awid            => mstAxiWriteMaster.awid,
         awlen           => mstAxiWriteMaster.awlen,
         awsize          => mstAxiWriteMaster.awsize,
         awburst         => mstAxiWriteMaster.awburst,
         awlock          => mstAxiWriteMaster.awlock,
         awcache         => mstAxiWriteMaster.awcache,
         awprot          => mstAxiWriteMaster.awprot,
         wready          => mstAxiWriteSlave.wready,
         wdataH          => mstAxiWriteMaster.wdata(63 downto 32),
         wdataL          => mstAxiWriteMaster.wdata(31 downto 0),
         wlast           => mstAxiWriteMaster.wlast,
         wvalid          => mstAxiWriteMaster.wvalid,
         wid             => mstAxiWriteMaster.wid,
         wstrb           => mstAxiWriteMaster.wstrb,
         bready          => mstAxiWriteMaster.bready,
         bresp           => mstAxiWriteSlave.bresp,
         bvalid          => mstAxiWriteSlave.bvalid,
         bid             => mstAxiWriteSlave.bid
      );

end architecture structure;

