-------------------------------------------------------------------------------
-- File       : AxiXadcMinimumCore.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-10-21
-- Last update: 2014-10-21
-------------------------------------------------------------------------------
-- Description: Example of a simple XADC IP core w/ AXI-Lite
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

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;

entity AxiXadcMinimumCore is
   generic (
      TPD_G : time := 1 ns);
   port (
      -- XADC Ports
      vPIn           : in  sl;
      vNIn           : in  sl;
      -- AXI-Lite Register Interface
      axiReadMaster  : in  AxiLiteReadMasterType;
      axiReadSlave   : out AxiLiteReadSlaveType;
      axiWriteMaster : in  AxiLiteWriteMasterType;
      axiWriteSlave  : out AxiLiteWriteSlaveType;
      -- Clocks and Resets
      axiClk         : in  sl;
      axiRst         : in  sl);
end entity AxiXadcMinimumCore;

architecture mapping of AxiXadcMinimumCore is

   component AxiXadcMinimum
      port (
         s_axi_aclk    : in  sl;
         s_axi_aresetn : in  sl;
         s_axi_awaddr  : in  slv(10 downto 0);
         s_axi_awvalid : in  sl;
         s_axi_awready : out sl;
         s_axi_wdata   : in  slv(31 downto 0);
         s_axi_wstrb   : in  slv(3 downto 0);
         s_axi_wvalid  : in  sl;
         s_axi_wready  : out sl;
         s_axi_bresp   : out slv(1 downto 0);
         s_axi_bvalid  : out sl;
         s_axi_bready  : in  sl;
         s_axi_araddr  : in  slv(10 downto 0);
         s_axi_arvalid : in  sl;
         s_axi_arready : out sl;
         s_axi_rdata   : out slv(31 downto 0);
         s_axi_rresp   : out slv(1 downto 0);
         s_axi_rvalid  : out sl;
         s_axi_rready  : in  sl;
         ip2intc_irpt  : out sl;
         vp_in         : in  sl;
         vn_in         : in  sl;
         channel_out   : out slv(4 downto 0);
         eoc_out       : out sl;
         alarm_out     : out sl;
         eos_out       : out sl;
         busy_out      : out sl);
   end component;
   attribute SYN_BLACK_BOX                       : boolean;
   attribute SYN_BLACK_BOX of AxiXadcMinimum     : component is true;
   attribute BLACK_BOX_PAD_PIN                   : string;
   attribute BLACK_BOX_PAD_PIN of AxiXadcMinimum : component is "s_axi_aclk,s_axi_aresetn,s_axi_awaddr[10:0],s_axi_awvalid,s_axi_awready,s_axi_wdata[31:0],s_axi_wstrb[3:0],s_axi_wvalid,s_axi_wready,s_axi_bresp[1:0],s_axi_bvalid,s_axi_bready,s_axi_araddr[10:0],s_axi_arvalid,s_axi_arready,s_axi_rdata[31:0],s_axi_rresp[1:0],s_axi_rvalid,s_axi_rready,ip2intc_irpt,vp_in,vn_in,channel_out[4:0],eoc_out,alarm_out,eos_out,busy_out";

   signal axiRstL : sl;

begin

   axiRstL <= not axiRst;
   AxiXadcCore_1 : AxiXadcMinimum
      port map (
         s_axi_aclk    => axiClk,
         s_axi_aresetn => axiRstL,
         s_axi_awaddr  => axiWriteMaster.awaddr(10 downto 0),
         s_axi_awvalid => axiWriteMaster.awvalid,
         s_axi_awready => axiWriteSlave.awready,
         s_axi_wdata   => axiWriteMaster.wdata,
         s_axi_wstrb   => axiWriteMaster.wstrb,
         s_axi_wvalid  => axiWriteMaster.wvalid,
         s_axi_wready  => axiWriteSlave.wready,
         s_axi_bresp   => axiWriteSlave.bresp,
         s_axi_bvalid  => axiWriteSlave.bvalid,
         s_axi_bready  => axiWriteMaster.bready,
         s_axi_araddr  => axiReadMaster.araddr(10 downto 0),
         s_axi_arvalid => axiReadMaster.arvalid,
         s_axi_arready => axiReadSlave.arready,
         s_axi_rdata   => axiReadSlave.rdata,
         s_axi_rresp   => axiReadSlave.rresp,
         s_axi_rvalid  => axiReadSlave.rvalid,
         s_axi_rready  => axiReadMaster.rready,
         ip2intc_irpt  => open,
         vp_in         => vpIn,
         vn_in         => vnIn,
         channel_out   => open,
         eoc_out       => open,
         alarm_out     => open,
         eos_out       => open,
         busy_out      => open);  

end architecture mapping;
