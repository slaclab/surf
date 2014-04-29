library ieee;
use ieee.std_logic_1164.all;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;

library unisim;
use unisim.vcomponents.all;

use work.StdRtlPkg.all;
use work.AxiPkg.all;

entity AxiSimSlaveWrap is
   generic (
      TPD_G      : time                   := 1 ns:
      SLAVE_ID_G : integer range 0 to 255 := 0
   );
   port (

      -- AXI Clock/Rst
      axiClk            : in  sl;

      -- Slave
      slvAxiReadMaster  : in  AxiReadMasterType;
      slvAxiReadSlave   : out AxiReadSlaveType;
      slvAxiWriteMaster : in  AxiWriteMasterType;
      slvAxiWriteSlave  : out AxiWriteSlaveType
   );
end AxiSimSlaveWrap;

architecture structure of AxiSimSlaveWrap is

   signal slaveId : slv(7 downto 0);

begin

   slaveId <= conv_std_logic_vector(SLAVE_ID_G,8);

   U_AxiSlave : AxiSimSlave
      port map (
         axiClk          => axiClk,
         slaveId         => slaveId,
         arvalid         => slvAxiReadMaster.arvalid,
         arready         => slvAxiReadSlave.arready,
         araddr          => slvAxiReadMaster.araddr,
         arid            => slvAxiReadMaster.arid,
         arlen           => slvAxiReadMaster.arlen,
         arsize          => slvAxiReadMaster.arsize,
         arburst         => slvAxiReadMaster.arburst,
         arlock          => slvAxiReadMaster.arlock,
         arprot          => slvAxiReadMaster.arprot,
         arcache         => slvAxiReadMaster.arcache,
         rready          => slvAxiReadMaster.rready,
         rdataH          => slvAxiReadSlave.rdata(63 downto 32),
         rdataL          => slvAxiReadSlave.rdata(31 downto  0),
         rlast           => slvAxiReadSlave.rlast,
         rvalid          => slvAxiReadSlave.rvalid,
         rid             => slvAxiReadSlave.rid,
         rresp           => slvAxiReadSlave.rresp,
         awvalid         => slvAxiWriteMaster.awvalid,
         awready         => slvAxiWriteSlave.awready,
         awaddr          => slvAxiWriteMaster.awaddr,
         awid            => slvAxiWriteMaster.awid,
         awlen           => slvAxiWriteMaster.awlen,
         awsize          => slvAxiWriteMaster.awsize,
         awburst         => slvAxiWriteMaster.awburst,
         awlock          => slvAxiWriteMaster.awlock,
         awcache         => slvAxiWriteMaster.awcache,
         awprot          => slvAxiWriteMaster.awprot,
         wready          => slvAxiWriteSlave.wready,
         wdataH          => slvAxiWriteMaster.wdata(63 downto 32),
         wdataL          => slvAxiWriteMaster.wdata(31 downto 0),
         wlast           => slvAxiWriteMaster.wlast,
         wvalid          => slvAxiWriteMaster.wvalid,
         wid             => slvAxiWriteMaster.wid,
         wstrb           => slvAxiWriteMaster.wstrb,
         bready          => slvAxiWriteMaster.bready,
         bresp           => slvAxiWriteSlave.bresp,
         bvalid          => slvAxiWriteSlave.bvalid,
         bid             => slvAxiWriteSlave.bid
      );

end architecture structure;

