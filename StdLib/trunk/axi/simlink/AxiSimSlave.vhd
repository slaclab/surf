
LIBRARY ieee;
USE work.ALL;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity AxiSimSlave is port (
      axiClk         : in  sl;
      slaveId        : in  slv(7  downto 0);
      arvalid        : in  sl;
      arready        : out sl;
      araddr         : in  slv(31 downto 0);
      arid           : in  slv(11 downto 0);
      arlen          : in  slv(3  downto 0);
      arsize         : in  slv(2  downto 0);
      arburst        : in  slv(1  downto 0);
      arlock         : in  slv(1  downto 0);
      arprot         : in  slv(2  downto 0);
      arcache        : in  slv(3  downto 0);
      rready         : in  sl;
      rdataH         : out slv(31 downto 0);
      rdataL         : out slv(31 downto 0);
      rlast          : out sl;
      rvalid         : out sl;
      rid            : out slv(11 downto 0);
      rresp          : out slv(1  downto 0);
      awvalid        : in  sl;
      awready        : out sl;
      awaddr         : in  slv(31 downto 0);
      awid           : in  slv(11 downto 0);
      awlen          : in  slv(3  downto 0);
      awsize         : in  slv(2  downto 0);
      awburst        : in  slv(1  downto 0);
      awlock         : in  slv(1  downto 0);
      awcache        : in  slv(3  downto 0);
      awprot         : in  slv(2  downto 0);
      wready         : out sl;
      wdataH         : in  slv(31 downto 0);
      wdataL         : in  slv(31 downto 0);
      wlast          : in  sl;
      wvalid         : in  sl;
      wid            : in  slv(11 downto 0);
      wstrb          : in  slv(7  downto 0);
      bready         : in  sl;
      bresp          : out slv(1  downto 0);
      bvalid         : out sl;
      bid            : out slv(11 downto 0)
   );
end AxiSimSlave;

-- Define architecture
architecture AxiSimSlave of AxiSimSlave is
   Attribute FOREIGN of AxiSimSlave: architecture is 
      "vhpi:SimSw_lib:AxiSimSlaveElab:AxiSimSlaveInit:AxiSimSlave";
begin
end AxiSimSlave;

