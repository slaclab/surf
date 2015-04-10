-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : TcpHls.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-04-10
-- Last update: 2015-04-10
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- 
-------------------------------------------------------------------------------
-- Copyright (c) 2015 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;

entity TcpHls is
   generic (
      TPD_G : time := 1 ns);
   port (
      axiClk         : in  sl;
      axiRst         : in  sl;
      axiReadMaster  : in  AxiLiteReadMasterType;
      axiReadSlave   : out AxiLiteReadSlaveType;
      axiWriteMaster : in  AxiLiteWriteMasterType;
      axiWriteSlave  : out AxiLiteWriteSlaveType);
end TcpHls;

architecture rtl of TcpHls is

   component TcpHlsCore
      port (
         s_axi_BUS_A_AWVALID : in  std_logic;
         s_axi_BUS_A_AWREADY : out std_logic;
         s_axi_BUS_A_AWADDR  : in  std_logic_vector(5 downto 0);
         s_axi_BUS_A_WVALID  : in  std_logic;
         s_axi_BUS_A_WREADY  : out std_logic;
         s_axi_BUS_A_WDATA   : in  std_logic_vector(31 downto 0);
         s_axi_BUS_A_WSTRB   : in  std_logic_vector(3 downto 0);
         s_axi_BUS_A_ARVALID : in  std_logic;
         s_axi_BUS_A_ARREADY : out std_logic;
         s_axi_BUS_A_ARADDR  : in  std_logic_vector(5 downto 0);
         s_axi_BUS_A_RVALID  : out std_logic;
         s_axi_BUS_A_RREADY  : in  std_logic;
         s_axi_BUS_A_RDATA   : out std_logic_vector(31 downto 0);
         s_axi_BUS_A_RRESP   : out std_logic_vector(1 downto 0);
         s_axi_BUS_A_BVALID  : out std_logic;
         s_axi_BUS_A_BREADY  : in  std_logic;
         s_axi_BUS_A_BRESP   : out std_logic_vector(1 downto 0);
         ap_clk              : in  std_logic;
         ap_rst_n            : in  std_logic;
         interrupt           : out std_logic);
   end component;

   signal axiRstL : sl;
   
begin

   axiRstL <= not(axiRst);

   TcpHlsCore_inst : TcpHlsCore
      port map (
         s_axi_BUS_A_AWVALID => axiWriteMaster.awvalid,
         s_axi_BUS_A_AWREADY => axiWriteSlave.awready,
         s_axi_BUS_A_AWADDR  => axiWriteMaster.awaddr(5 downto 0),
         s_axi_BUS_A_WVALID  => axiWriteMaster.wvalid,
         s_axi_BUS_A_WREADY  => axiWriteSlave.wready,
         s_axi_BUS_A_WDATA   => axiWriteMaster.wdata,
         s_axi_BUS_A_WSTRB   => axiWriteMaster.wstrb,
         s_axi_BUS_A_ARVALID => axiReadMaster.arvalid,
         s_axi_BUS_A_ARREADY => axiReadSlave.arready,
         s_axi_BUS_A_ARADDR  => axiReadMaster.araddr(5 downto 0),
         s_axi_BUS_A_RVALID  => axiReadSlave.rvalid,
         s_axi_BUS_A_RREADY  => axiReadMaster.rready,
         s_axi_BUS_A_RDATA   => axiReadSlave.rdata,
         s_axi_BUS_A_RRESP   => axiReadSlave.rresp,
         s_axi_BUS_A_BVALID  => axiWriteSlave.bvalid,
         s_axi_BUS_A_BREADY  => axiWriteMaster.bready,
         s_axi_BUS_A_BRESP   => axiWriteSlave.bresp,
         ap_clk              => axiClk,
         ap_rst_n            => axiRstL,
         interrupt           => open);         

end rtl;
