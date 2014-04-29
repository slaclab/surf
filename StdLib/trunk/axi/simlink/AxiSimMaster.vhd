
LIBRARY ieee;
USE work.ALL;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity AxiSimMaster is port (
      axiClk         : in  sl;
      masterId       : in  slv(7  downto 0);
      arvalid        : out sl;
      arready        : in  sl;
      araddr         : out slv(31 downto 0);
      arid           : out slv(11 downto 0);
      arlen          : out slv(3  downto 0);
      arsize         : out slv(2  downto 0);
      arburst        : out slv(1  downto 0);
      arlock         : out slv(1  downto 0);
      arprot         : out slv(2  downto 0);
      arcache        : out slv(3  downto 0);
      rready         : out sl;
      rdataH         : in  slv(31 downto 0);
      rdataL         : in  slv(31 downto 0);
      rlast          : in  sl;
      rvalid         : in  sl;
      rid            : in  slv(11 downto 0);
      rresp          : in  slv(1  downto 0);
      awvalid        : out sl;
      awready        : in  sl;
      awaddr         : out slv(31 downto 0);
      awid           : out slv(11 downto 0);
      awlen          : out slv(3  downto 0);
      awsize         : out slv(2  downto 0);
      awburst        : out slv(1  downto 0);
      awlock         : out slv(1  downto 0);
      awcache        : out slv(3  downto 0);
      awprot         : out slv(2  downto 0);
      wready         : in  sl;
      wdataH         : out slv(31 downto 0);
      wdataL         : out slv(31 downto 0);
      wlast          : out sl;
      wvalid         : out sl;
      wid            : out slv(11 downto 0);
      wstrb          : out slv(7  downto 0);
      bready         : out sl;
      bresp          : in  slv(1  downto 0);
      bvalid         : in  sl;
      bid            : in  slv(11 downto 0)
   );
end AxiSimMaster;

-- Define architecture
architecture AxiSimMaster of AxiSimMaster is
   Attribute FOREIGN of AxiSimMaster: architecture is 
      "vhpi:SimSw_lib:AxiSimMasterElab:AxiSimMasterInit:AxiSimMaster";
begin
end AxiSimMaster;

