-------------------------------------------------------------------------------
-- Title      : PgpCardG4 Wrapper for AXI PCIe Core
-------------------------------------------------------------------------------
-- File       : AxiPcieCrossbarIpCoreWrapper.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-02-14
-- Last update: 2016-02-14
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- This file is part of 'AxiPcieCore'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'AxiPcieCore', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;
use work.AxiPkg.all;

entity AxiPcieCrossbarIpCoreWrapper is
   generic (
      TPD_G : time := 1 ns);
   port (
      -- Clock and Reset
      axiClk           : in  sl;
      axiRst           : in  sl;
      -- Slaves
      sAxiWriteMasters : in  AxiWriteMasterArray(15 downto 0);
      sAxiWriteSlaves  : out AxiWriteSlaveArray(15 downto 0);
      sAxiReadMasters  : in  AxiReadMasterArray(15 downto 0);
      sAxiReadSlaves   : out AxiReadSlaveArray(15 downto 0);
      -- Master
      mAxiWriteMaster  : out AxiWriteMasterType;
      mAxiWriteSlave   : in  AxiWriteSlaveType;
      mAxiReadMaster   : out AxiReadMasterType;
      mAxiReadSlave    : in  AxiReadSlaveType);      
end AxiPcieCrossbarIpCoreWrapper;

architecture mapping of AxiPcieCrossbarIpCoreWrapper is

   component AxiPcieCrossbarIpCore
      port (
         INTERCONNECT_ACLK    : in  std_logic;
         INTERCONNECT_ARESETN : in  std_logic;
         S00_AXI_ARESET_OUT_N : out std_logic;
         S00_AXI_ACLK         : in  std_logic;
         S00_AXI_AWID         : in  std_logic_vector(0 downto 0);
         S00_AXI_AWADDR       : in  std_logic_vector(31 downto 0);
         S00_AXI_AWLEN        : in  std_logic_vector(7 downto 0);
         S00_AXI_AWSIZE       : in  std_logic_vector(2 downto 0);
         S00_AXI_AWBURST      : in  std_logic_vector(1 downto 0);
         S00_AXI_AWLOCK       : in  std_logic;
         S00_AXI_AWCACHE      : in  std_logic_vector(3 downto 0);
         S00_AXI_AWPROT       : in  std_logic_vector(2 downto 0);
         S00_AXI_AWQOS        : in  std_logic_vector(3 downto 0);
         S00_AXI_AWVALID      : in  std_logic;
         S00_AXI_AWREADY      : out std_logic;
         S00_AXI_WDATA        : in  std_logic_vector(127 downto 0);
         S00_AXI_WSTRB        : in  std_logic_vector(15 downto 0);
         S00_AXI_WLAST        : in  std_logic;
         S00_AXI_WVALID       : in  std_logic;
         S00_AXI_WREADY       : out std_logic;
         S00_AXI_BID          : out std_logic_vector(0 downto 0);
         S00_AXI_BRESP        : out std_logic_vector(1 downto 0);
         S00_AXI_BVALID       : out std_logic;
         S00_AXI_BREADY       : in  std_logic;
         S00_AXI_ARID         : in  std_logic_vector(0 downto 0);
         S00_AXI_ARADDR       : in  std_logic_vector(31 downto 0);
         S00_AXI_ARLEN        : in  std_logic_vector(7 downto 0);
         S00_AXI_ARSIZE       : in  std_logic_vector(2 downto 0);
         S00_AXI_ARBURST      : in  std_logic_vector(1 downto 0);
         S00_AXI_ARLOCK       : in  std_logic;
         S00_AXI_ARCACHE      : in  std_logic_vector(3 downto 0);
         S00_AXI_ARPROT       : in  std_logic_vector(2 downto 0);
         S00_AXI_ARQOS        : in  std_logic_vector(3 downto 0);
         S00_AXI_ARVALID      : in  std_logic;
         S00_AXI_ARREADY      : out std_logic;
         S00_AXI_RID          : out std_logic_vector(0 downto 0);
         S00_AXI_RDATA        : out std_logic_vector(127 downto 0);
         S00_AXI_RRESP        : out std_logic_vector(1 downto 0);
         S00_AXI_RLAST        : out std_logic;
         S00_AXI_RVALID       : out std_logic;
         S00_AXI_RREADY       : in  std_logic;
         S01_AXI_ARESET_OUT_N : out std_logic;
         S01_AXI_ACLK         : in  std_logic;
         S01_AXI_AWID         : in  std_logic_vector(0 downto 0);
         S01_AXI_AWADDR       : in  std_logic_vector(31 downto 0);
         S01_AXI_AWLEN        : in  std_logic_vector(7 downto 0);
         S01_AXI_AWSIZE       : in  std_logic_vector(2 downto 0);
         S01_AXI_AWBURST      : in  std_logic_vector(1 downto 0);
         S01_AXI_AWLOCK       : in  std_logic;
         S01_AXI_AWCACHE      : in  std_logic_vector(3 downto 0);
         S01_AXI_AWPROT       : in  std_logic_vector(2 downto 0);
         S01_AXI_AWQOS        : in  std_logic_vector(3 downto 0);
         S01_AXI_AWVALID      : in  std_logic;
         S01_AXI_AWREADY      : out std_logic;
         S01_AXI_WDATA        : in  std_logic_vector(127 downto 0);
         S01_AXI_WSTRB        : in  std_logic_vector(15 downto 0);
         S01_AXI_WLAST        : in  std_logic;
         S01_AXI_WVALID       : in  std_logic;
         S01_AXI_WREADY       : out std_logic;
         S01_AXI_BID          : out std_logic_vector(0 downto 0);
         S01_AXI_BRESP        : out std_logic_vector(1 downto 0);
         S01_AXI_BVALID       : out std_logic;
         S01_AXI_BREADY       : in  std_logic;
         S01_AXI_ARID         : in  std_logic_vector(0 downto 0);
         S01_AXI_ARADDR       : in  std_logic_vector(31 downto 0);
         S01_AXI_ARLEN        : in  std_logic_vector(7 downto 0);
         S01_AXI_ARSIZE       : in  std_logic_vector(2 downto 0);
         S01_AXI_ARBURST      : in  std_logic_vector(1 downto 0);
         S01_AXI_ARLOCK       : in  std_logic;
         S01_AXI_ARCACHE      : in  std_logic_vector(3 downto 0);
         S01_AXI_ARPROT       : in  std_logic_vector(2 downto 0);
         S01_AXI_ARQOS        : in  std_logic_vector(3 downto 0);
         S01_AXI_ARVALID      : in  std_logic;
         S01_AXI_ARREADY      : out std_logic;
         S01_AXI_RID          : out std_logic_vector(0 downto 0);
         S01_AXI_RDATA        : out std_logic_vector(127 downto 0);
         S01_AXI_RRESP        : out std_logic_vector(1 downto 0);
         S01_AXI_RLAST        : out std_logic;
         S01_AXI_RVALID       : out std_logic;
         S01_AXI_RREADY       : in  std_logic;
         S02_AXI_ARESET_OUT_N : out std_logic;
         S02_AXI_ACLK         : in  std_logic;
         S02_AXI_AWID         : in  std_logic_vector(0 downto 0);
         S02_AXI_AWADDR       : in  std_logic_vector(31 downto 0);
         S02_AXI_AWLEN        : in  std_logic_vector(7 downto 0);
         S02_AXI_AWSIZE       : in  std_logic_vector(2 downto 0);
         S02_AXI_AWBURST      : in  std_logic_vector(1 downto 0);
         S02_AXI_AWLOCK       : in  std_logic;
         S02_AXI_AWCACHE      : in  std_logic_vector(3 downto 0);
         S02_AXI_AWPROT       : in  std_logic_vector(2 downto 0);
         S02_AXI_AWQOS        : in  std_logic_vector(3 downto 0);
         S02_AXI_AWVALID      : in  std_logic;
         S02_AXI_AWREADY      : out std_logic;
         S02_AXI_WDATA        : in  std_logic_vector(127 downto 0);
         S02_AXI_WSTRB        : in  std_logic_vector(15 downto 0);
         S02_AXI_WLAST        : in  std_logic;
         S02_AXI_WVALID       : in  std_logic;
         S02_AXI_WREADY       : out std_logic;
         S02_AXI_BID          : out std_logic_vector(0 downto 0);
         S02_AXI_BRESP        : out std_logic_vector(1 downto 0);
         S02_AXI_BVALID       : out std_logic;
         S02_AXI_BREADY       : in  std_logic;
         S02_AXI_ARID         : in  std_logic_vector(0 downto 0);
         S02_AXI_ARADDR       : in  std_logic_vector(31 downto 0);
         S02_AXI_ARLEN        : in  std_logic_vector(7 downto 0);
         S02_AXI_ARSIZE       : in  std_logic_vector(2 downto 0);
         S02_AXI_ARBURST      : in  std_logic_vector(1 downto 0);
         S02_AXI_ARLOCK       : in  std_logic;
         S02_AXI_ARCACHE      : in  std_logic_vector(3 downto 0);
         S02_AXI_ARPROT       : in  std_logic_vector(2 downto 0);
         S02_AXI_ARQOS        : in  std_logic_vector(3 downto 0);
         S02_AXI_ARVALID      : in  std_logic;
         S02_AXI_ARREADY      : out std_logic;
         S02_AXI_RID          : out std_logic_vector(0 downto 0);
         S02_AXI_RDATA        : out std_logic_vector(127 downto 0);
         S02_AXI_RRESP        : out std_logic_vector(1 downto 0);
         S02_AXI_RLAST        : out std_logic;
         S02_AXI_RVALID       : out std_logic;
         S02_AXI_RREADY       : in  std_logic;
         S03_AXI_ARESET_OUT_N : out std_logic;
         S03_AXI_ACLK         : in  std_logic;
         S03_AXI_AWID         : in  std_logic_vector(0 downto 0);
         S03_AXI_AWADDR       : in  std_logic_vector(31 downto 0);
         S03_AXI_AWLEN        : in  std_logic_vector(7 downto 0);
         S03_AXI_AWSIZE       : in  std_logic_vector(2 downto 0);
         S03_AXI_AWBURST      : in  std_logic_vector(1 downto 0);
         S03_AXI_AWLOCK       : in  std_logic;
         S03_AXI_AWCACHE      : in  std_logic_vector(3 downto 0);
         S03_AXI_AWPROT       : in  std_logic_vector(2 downto 0);
         S03_AXI_AWQOS        : in  std_logic_vector(3 downto 0);
         S03_AXI_AWVALID      : in  std_logic;
         S03_AXI_AWREADY      : out std_logic;
         S03_AXI_WDATA        : in  std_logic_vector(127 downto 0);
         S03_AXI_WSTRB        : in  std_logic_vector(15 downto 0);
         S03_AXI_WLAST        : in  std_logic;
         S03_AXI_WVALID       : in  std_logic;
         S03_AXI_WREADY       : out std_logic;
         S03_AXI_BID          : out std_logic_vector(0 downto 0);
         S03_AXI_BRESP        : out std_logic_vector(1 downto 0);
         S03_AXI_BVALID       : out std_logic;
         S03_AXI_BREADY       : in  std_logic;
         S03_AXI_ARID         : in  std_logic_vector(0 downto 0);
         S03_AXI_ARADDR       : in  std_logic_vector(31 downto 0);
         S03_AXI_ARLEN        : in  std_logic_vector(7 downto 0);
         S03_AXI_ARSIZE       : in  std_logic_vector(2 downto 0);
         S03_AXI_ARBURST      : in  std_logic_vector(1 downto 0);
         S03_AXI_ARLOCK       : in  std_logic;
         S03_AXI_ARCACHE      : in  std_logic_vector(3 downto 0);
         S03_AXI_ARPROT       : in  std_logic_vector(2 downto 0);
         S03_AXI_ARQOS        : in  std_logic_vector(3 downto 0);
         S03_AXI_ARVALID      : in  std_logic;
         S03_AXI_ARREADY      : out std_logic;
         S03_AXI_RID          : out std_logic_vector(0 downto 0);
         S03_AXI_RDATA        : out std_logic_vector(127 downto 0);
         S03_AXI_RRESP        : out std_logic_vector(1 downto 0);
         S03_AXI_RLAST        : out std_logic;
         S03_AXI_RVALID       : out std_logic;
         S03_AXI_RREADY       : in  std_logic;
         S04_AXI_ARESET_OUT_N : out std_logic;
         S04_AXI_ACLK         : in  std_logic;
         S04_AXI_AWID         : in  std_logic_vector(0 downto 0);
         S04_AXI_AWADDR       : in  std_logic_vector(31 downto 0);
         S04_AXI_AWLEN        : in  std_logic_vector(7 downto 0);
         S04_AXI_AWSIZE       : in  std_logic_vector(2 downto 0);
         S04_AXI_AWBURST      : in  std_logic_vector(1 downto 0);
         S04_AXI_AWLOCK       : in  std_logic;
         S04_AXI_AWCACHE      : in  std_logic_vector(3 downto 0);
         S04_AXI_AWPROT       : in  std_logic_vector(2 downto 0);
         S04_AXI_AWQOS        : in  std_logic_vector(3 downto 0);
         S04_AXI_AWVALID      : in  std_logic;
         S04_AXI_AWREADY      : out std_logic;
         S04_AXI_WDATA        : in  std_logic_vector(127 downto 0);
         S04_AXI_WSTRB        : in  std_logic_vector(15 downto 0);
         S04_AXI_WLAST        : in  std_logic;
         S04_AXI_WVALID       : in  std_logic;
         S04_AXI_WREADY       : out std_logic;
         S04_AXI_BID          : out std_logic_vector(0 downto 0);
         S04_AXI_BRESP        : out std_logic_vector(1 downto 0);
         S04_AXI_BVALID       : out std_logic;
         S04_AXI_BREADY       : in  std_logic;
         S04_AXI_ARID         : in  std_logic_vector(0 downto 0);
         S04_AXI_ARADDR       : in  std_logic_vector(31 downto 0);
         S04_AXI_ARLEN        : in  std_logic_vector(7 downto 0);
         S04_AXI_ARSIZE       : in  std_logic_vector(2 downto 0);
         S04_AXI_ARBURST      : in  std_logic_vector(1 downto 0);
         S04_AXI_ARLOCK       : in  std_logic;
         S04_AXI_ARCACHE      : in  std_logic_vector(3 downto 0);
         S04_AXI_ARPROT       : in  std_logic_vector(2 downto 0);
         S04_AXI_ARQOS        : in  std_logic_vector(3 downto 0);
         S04_AXI_ARVALID      : in  std_logic;
         S04_AXI_ARREADY      : out std_logic;
         S04_AXI_RID          : out std_logic_vector(0 downto 0);
         S04_AXI_RDATA        : out std_logic_vector(127 downto 0);
         S04_AXI_RRESP        : out std_logic_vector(1 downto 0);
         S04_AXI_RLAST        : out std_logic;
         S04_AXI_RVALID       : out std_logic;
         S04_AXI_RREADY       : in  std_logic;
         S05_AXI_ARESET_OUT_N : out std_logic;
         S05_AXI_ACLK         : in  std_logic;
         S05_AXI_AWID         : in  std_logic_vector(0 downto 0);
         S05_AXI_AWADDR       : in  std_logic_vector(31 downto 0);
         S05_AXI_AWLEN        : in  std_logic_vector(7 downto 0);
         S05_AXI_AWSIZE       : in  std_logic_vector(2 downto 0);
         S05_AXI_AWBURST      : in  std_logic_vector(1 downto 0);
         S05_AXI_AWLOCK       : in  std_logic;
         S05_AXI_AWCACHE      : in  std_logic_vector(3 downto 0);
         S05_AXI_AWPROT       : in  std_logic_vector(2 downto 0);
         S05_AXI_AWQOS        : in  std_logic_vector(3 downto 0);
         S05_AXI_AWVALID      : in  std_logic;
         S05_AXI_AWREADY      : out std_logic;
         S05_AXI_WDATA        : in  std_logic_vector(127 downto 0);
         S05_AXI_WSTRB        : in  std_logic_vector(15 downto 0);
         S05_AXI_WLAST        : in  std_logic;
         S05_AXI_WVALID       : in  std_logic;
         S05_AXI_WREADY       : out std_logic;
         S05_AXI_BID          : out std_logic_vector(0 downto 0);
         S05_AXI_BRESP        : out std_logic_vector(1 downto 0);
         S05_AXI_BVALID       : out std_logic;
         S05_AXI_BREADY       : in  std_logic;
         S05_AXI_ARID         : in  std_logic_vector(0 downto 0);
         S05_AXI_ARADDR       : in  std_logic_vector(31 downto 0);
         S05_AXI_ARLEN        : in  std_logic_vector(7 downto 0);
         S05_AXI_ARSIZE       : in  std_logic_vector(2 downto 0);
         S05_AXI_ARBURST      : in  std_logic_vector(1 downto 0);
         S05_AXI_ARLOCK       : in  std_logic;
         S05_AXI_ARCACHE      : in  std_logic_vector(3 downto 0);
         S05_AXI_ARPROT       : in  std_logic_vector(2 downto 0);
         S05_AXI_ARQOS        : in  std_logic_vector(3 downto 0);
         S05_AXI_ARVALID      : in  std_logic;
         S05_AXI_ARREADY      : out std_logic;
         S05_AXI_RID          : out std_logic_vector(0 downto 0);
         S05_AXI_RDATA        : out std_logic_vector(127 downto 0);
         S05_AXI_RRESP        : out std_logic_vector(1 downto 0);
         S05_AXI_RLAST        : out std_logic;
         S05_AXI_RVALID       : out std_logic;
         S05_AXI_RREADY       : in  std_logic;
         S06_AXI_ARESET_OUT_N : out std_logic;
         S06_AXI_ACLK         : in  std_logic;
         S06_AXI_AWID         : in  std_logic_vector(0 downto 0);
         S06_AXI_AWADDR       : in  std_logic_vector(31 downto 0);
         S06_AXI_AWLEN        : in  std_logic_vector(7 downto 0);
         S06_AXI_AWSIZE       : in  std_logic_vector(2 downto 0);
         S06_AXI_AWBURST      : in  std_logic_vector(1 downto 0);
         S06_AXI_AWLOCK       : in  std_logic;
         S06_AXI_AWCACHE      : in  std_logic_vector(3 downto 0);
         S06_AXI_AWPROT       : in  std_logic_vector(2 downto 0);
         S06_AXI_AWQOS        : in  std_logic_vector(3 downto 0);
         S06_AXI_AWVALID      : in  std_logic;
         S06_AXI_AWREADY      : out std_logic;
         S06_AXI_WDATA        : in  std_logic_vector(127 downto 0);
         S06_AXI_WSTRB        : in  std_logic_vector(15 downto 0);
         S06_AXI_WLAST        : in  std_logic;
         S06_AXI_WVALID       : in  std_logic;
         S06_AXI_WREADY       : out std_logic;
         S06_AXI_BID          : out std_logic_vector(0 downto 0);
         S06_AXI_BRESP        : out std_logic_vector(1 downto 0);
         S06_AXI_BVALID       : out std_logic;
         S06_AXI_BREADY       : in  std_logic;
         S06_AXI_ARID         : in  std_logic_vector(0 downto 0);
         S06_AXI_ARADDR       : in  std_logic_vector(31 downto 0);
         S06_AXI_ARLEN        : in  std_logic_vector(7 downto 0);
         S06_AXI_ARSIZE       : in  std_logic_vector(2 downto 0);
         S06_AXI_ARBURST      : in  std_logic_vector(1 downto 0);
         S06_AXI_ARLOCK       : in  std_logic;
         S06_AXI_ARCACHE      : in  std_logic_vector(3 downto 0);
         S06_AXI_ARPROT       : in  std_logic_vector(2 downto 0);
         S06_AXI_ARQOS        : in  std_logic_vector(3 downto 0);
         S06_AXI_ARVALID      : in  std_logic;
         S06_AXI_ARREADY      : out std_logic;
         S06_AXI_RID          : out std_logic_vector(0 downto 0);
         S06_AXI_RDATA        : out std_logic_vector(127 downto 0);
         S06_AXI_RRESP        : out std_logic_vector(1 downto 0);
         S06_AXI_RLAST        : out std_logic;
         S06_AXI_RVALID       : out std_logic;
         S06_AXI_RREADY       : in  std_logic;
         S07_AXI_ARESET_OUT_N : out std_logic;
         S07_AXI_ACLK         : in  std_logic;
         S07_AXI_AWID         : in  std_logic_vector(0 downto 0);
         S07_AXI_AWADDR       : in  std_logic_vector(31 downto 0);
         S07_AXI_AWLEN        : in  std_logic_vector(7 downto 0);
         S07_AXI_AWSIZE       : in  std_logic_vector(2 downto 0);
         S07_AXI_AWBURST      : in  std_logic_vector(1 downto 0);
         S07_AXI_AWLOCK       : in  std_logic;
         S07_AXI_AWCACHE      : in  std_logic_vector(3 downto 0);
         S07_AXI_AWPROT       : in  std_logic_vector(2 downto 0);
         S07_AXI_AWQOS        : in  std_logic_vector(3 downto 0);
         S07_AXI_AWVALID      : in  std_logic;
         S07_AXI_AWREADY      : out std_logic;
         S07_AXI_WDATA        : in  std_logic_vector(127 downto 0);
         S07_AXI_WSTRB        : in  std_logic_vector(15 downto 0);
         S07_AXI_WLAST        : in  std_logic;
         S07_AXI_WVALID       : in  std_logic;
         S07_AXI_WREADY       : out std_logic;
         S07_AXI_BID          : out std_logic_vector(0 downto 0);
         S07_AXI_BRESP        : out std_logic_vector(1 downto 0);
         S07_AXI_BVALID       : out std_logic;
         S07_AXI_BREADY       : in  std_logic;
         S07_AXI_ARID         : in  std_logic_vector(0 downto 0);
         S07_AXI_ARADDR       : in  std_logic_vector(31 downto 0);
         S07_AXI_ARLEN        : in  std_logic_vector(7 downto 0);
         S07_AXI_ARSIZE       : in  std_logic_vector(2 downto 0);
         S07_AXI_ARBURST      : in  std_logic_vector(1 downto 0);
         S07_AXI_ARLOCK       : in  std_logic;
         S07_AXI_ARCACHE      : in  std_logic_vector(3 downto 0);
         S07_AXI_ARPROT       : in  std_logic_vector(2 downto 0);
         S07_AXI_ARQOS        : in  std_logic_vector(3 downto 0);
         S07_AXI_ARVALID      : in  std_logic;
         S07_AXI_ARREADY      : out std_logic;
         S07_AXI_RID          : out std_logic_vector(0 downto 0);
         S07_AXI_RDATA        : out std_logic_vector(127 downto 0);
         S07_AXI_RRESP        : out std_logic_vector(1 downto 0);
         S07_AXI_RLAST        : out std_logic;
         S07_AXI_RVALID       : out std_logic;
         S07_AXI_RREADY       : in  std_logic;
         S08_AXI_ARESET_OUT_N : out std_logic;
         S08_AXI_ACLK         : in  std_logic;
         S08_AXI_AWID         : in  std_logic_vector(0 downto 0);
         S08_AXI_AWADDR       : in  std_logic_vector(31 downto 0);
         S08_AXI_AWLEN        : in  std_logic_vector(7 downto 0);
         S08_AXI_AWSIZE       : in  std_logic_vector(2 downto 0);
         S08_AXI_AWBURST      : in  std_logic_vector(1 downto 0);
         S08_AXI_AWLOCK       : in  std_logic;
         S08_AXI_AWCACHE      : in  std_logic_vector(3 downto 0);
         S08_AXI_AWPROT       : in  std_logic_vector(2 downto 0);
         S08_AXI_AWQOS        : in  std_logic_vector(3 downto 0);
         S08_AXI_AWVALID      : in  std_logic;
         S08_AXI_AWREADY      : out std_logic;
         S08_AXI_WDATA        : in  std_logic_vector(127 downto 0);
         S08_AXI_WSTRB        : in  std_logic_vector(15 downto 0);
         S08_AXI_WLAST        : in  std_logic;
         S08_AXI_WVALID       : in  std_logic;
         S08_AXI_WREADY       : out std_logic;
         S08_AXI_BID          : out std_logic_vector(0 downto 0);
         S08_AXI_BRESP        : out std_logic_vector(1 downto 0);
         S08_AXI_BVALID       : out std_logic;
         S08_AXI_BREADY       : in  std_logic;
         S08_AXI_ARID         : in  std_logic_vector(0 downto 0);
         S08_AXI_ARADDR       : in  std_logic_vector(31 downto 0);
         S08_AXI_ARLEN        : in  std_logic_vector(7 downto 0);
         S08_AXI_ARSIZE       : in  std_logic_vector(2 downto 0);
         S08_AXI_ARBURST      : in  std_logic_vector(1 downto 0);
         S08_AXI_ARLOCK       : in  std_logic;
         S08_AXI_ARCACHE      : in  std_logic_vector(3 downto 0);
         S08_AXI_ARPROT       : in  std_logic_vector(2 downto 0);
         S08_AXI_ARQOS        : in  std_logic_vector(3 downto 0);
         S08_AXI_ARVALID      : in  std_logic;
         S08_AXI_ARREADY      : out std_logic;
         S08_AXI_RID          : out std_logic_vector(0 downto 0);
         S08_AXI_RDATA        : out std_logic_vector(127 downto 0);
         S08_AXI_RRESP        : out std_logic_vector(1 downto 0);
         S08_AXI_RLAST        : out std_logic;
         S08_AXI_RVALID       : out std_logic;
         S08_AXI_RREADY       : in  std_logic;
         S09_AXI_ARESET_OUT_N : out std_logic;
         S09_AXI_ACLK         : in  std_logic;
         S09_AXI_AWID         : in  std_logic_vector(0 downto 0);
         S09_AXI_AWADDR       : in  std_logic_vector(31 downto 0);
         S09_AXI_AWLEN        : in  std_logic_vector(7 downto 0);
         S09_AXI_AWSIZE       : in  std_logic_vector(2 downto 0);
         S09_AXI_AWBURST      : in  std_logic_vector(1 downto 0);
         S09_AXI_AWLOCK       : in  std_logic;
         S09_AXI_AWCACHE      : in  std_logic_vector(3 downto 0);
         S09_AXI_AWPROT       : in  std_logic_vector(2 downto 0);
         S09_AXI_AWQOS        : in  std_logic_vector(3 downto 0);
         S09_AXI_AWVALID      : in  std_logic;
         S09_AXI_AWREADY      : out std_logic;
         S09_AXI_WDATA        : in  std_logic_vector(127 downto 0);
         S09_AXI_WSTRB        : in  std_logic_vector(15 downto 0);
         S09_AXI_WLAST        : in  std_logic;
         S09_AXI_WVALID       : in  std_logic;
         S09_AXI_WREADY       : out std_logic;
         S09_AXI_BID          : out std_logic_vector(0 downto 0);
         S09_AXI_BRESP        : out std_logic_vector(1 downto 0);
         S09_AXI_BVALID       : out std_logic;
         S09_AXI_BREADY       : in  std_logic;
         S09_AXI_ARID         : in  std_logic_vector(0 downto 0);
         S09_AXI_ARADDR       : in  std_logic_vector(31 downto 0);
         S09_AXI_ARLEN        : in  std_logic_vector(7 downto 0);
         S09_AXI_ARSIZE       : in  std_logic_vector(2 downto 0);
         S09_AXI_ARBURST      : in  std_logic_vector(1 downto 0);
         S09_AXI_ARLOCK       : in  std_logic;
         S09_AXI_ARCACHE      : in  std_logic_vector(3 downto 0);
         S09_AXI_ARPROT       : in  std_logic_vector(2 downto 0);
         S09_AXI_ARQOS        : in  std_logic_vector(3 downto 0);
         S09_AXI_ARVALID      : in  std_logic;
         S09_AXI_ARREADY      : out std_logic;
         S09_AXI_RID          : out std_logic_vector(0 downto 0);
         S09_AXI_RDATA        : out std_logic_vector(127 downto 0);
         S09_AXI_RRESP        : out std_logic_vector(1 downto 0);
         S09_AXI_RLAST        : out std_logic;
         S09_AXI_RVALID       : out std_logic;
         S09_AXI_RREADY       : in  std_logic;
         S10_AXI_ARESET_OUT_N : out std_logic;
         S10_AXI_ACLK         : in  std_logic;
         S10_AXI_AWID         : in  std_logic_vector(0 downto 0);
         S10_AXI_AWADDR       : in  std_logic_vector(31 downto 0);
         S10_AXI_AWLEN        : in  std_logic_vector(7 downto 0);
         S10_AXI_AWSIZE       : in  std_logic_vector(2 downto 0);
         S10_AXI_AWBURST      : in  std_logic_vector(1 downto 0);
         S10_AXI_AWLOCK       : in  std_logic;
         S10_AXI_AWCACHE      : in  std_logic_vector(3 downto 0);
         S10_AXI_AWPROT       : in  std_logic_vector(2 downto 0);
         S10_AXI_AWQOS        : in  std_logic_vector(3 downto 0);
         S10_AXI_AWVALID      : in  std_logic;
         S10_AXI_AWREADY      : out std_logic;
         S10_AXI_WDATA        : in  std_logic_vector(127 downto 0);
         S10_AXI_WSTRB        : in  std_logic_vector(15 downto 0);
         S10_AXI_WLAST        : in  std_logic;
         S10_AXI_WVALID       : in  std_logic;
         S10_AXI_WREADY       : out std_logic;
         S10_AXI_BID          : out std_logic_vector(0 downto 0);
         S10_AXI_BRESP        : out std_logic_vector(1 downto 0);
         S10_AXI_BVALID       : out std_logic;
         S10_AXI_BREADY       : in  std_logic;
         S10_AXI_ARID         : in  std_logic_vector(0 downto 0);
         S10_AXI_ARADDR       : in  std_logic_vector(31 downto 0);
         S10_AXI_ARLEN        : in  std_logic_vector(7 downto 0);
         S10_AXI_ARSIZE       : in  std_logic_vector(2 downto 0);
         S10_AXI_ARBURST      : in  std_logic_vector(1 downto 0);
         S10_AXI_ARLOCK       : in  std_logic;
         S10_AXI_ARCACHE      : in  std_logic_vector(3 downto 0);
         S10_AXI_ARPROT       : in  std_logic_vector(2 downto 0);
         S10_AXI_ARQOS        : in  std_logic_vector(3 downto 0);
         S10_AXI_ARVALID      : in  std_logic;
         S10_AXI_ARREADY      : out std_logic;
         S10_AXI_RID          : out std_logic_vector(0 downto 0);
         S10_AXI_RDATA        : out std_logic_vector(127 downto 0);
         S10_AXI_RRESP        : out std_logic_vector(1 downto 0);
         S10_AXI_RLAST        : out std_logic;
         S10_AXI_RVALID       : out std_logic;
         S10_AXI_RREADY       : in  std_logic;
         S11_AXI_ARESET_OUT_N : out std_logic;
         S11_AXI_ACLK         : in  std_logic;
         S11_AXI_AWID         : in  std_logic_vector(0 downto 0);
         S11_AXI_AWADDR       : in  std_logic_vector(31 downto 0);
         S11_AXI_AWLEN        : in  std_logic_vector(7 downto 0);
         S11_AXI_AWSIZE       : in  std_logic_vector(2 downto 0);
         S11_AXI_AWBURST      : in  std_logic_vector(1 downto 0);
         S11_AXI_AWLOCK       : in  std_logic;
         S11_AXI_AWCACHE      : in  std_logic_vector(3 downto 0);
         S11_AXI_AWPROT       : in  std_logic_vector(2 downto 0);
         S11_AXI_AWQOS        : in  std_logic_vector(3 downto 0);
         S11_AXI_AWVALID      : in  std_logic;
         S11_AXI_AWREADY      : out std_logic;
         S11_AXI_WDATA        : in  std_logic_vector(127 downto 0);
         S11_AXI_WSTRB        : in  std_logic_vector(15 downto 0);
         S11_AXI_WLAST        : in  std_logic;
         S11_AXI_WVALID       : in  std_logic;
         S11_AXI_WREADY       : out std_logic;
         S11_AXI_BID          : out std_logic_vector(0 downto 0);
         S11_AXI_BRESP        : out std_logic_vector(1 downto 0);
         S11_AXI_BVALID       : out std_logic;
         S11_AXI_BREADY       : in  std_logic;
         S11_AXI_ARID         : in  std_logic_vector(0 downto 0);
         S11_AXI_ARADDR       : in  std_logic_vector(31 downto 0);
         S11_AXI_ARLEN        : in  std_logic_vector(7 downto 0);
         S11_AXI_ARSIZE       : in  std_logic_vector(2 downto 0);
         S11_AXI_ARBURST      : in  std_logic_vector(1 downto 0);
         S11_AXI_ARLOCK       : in  std_logic;
         S11_AXI_ARCACHE      : in  std_logic_vector(3 downto 0);
         S11_AXI_ARPROT       : in  std_logic_vector(2 downto 0);
         S11_AXI_ARQOS        : in  std_logic_vector(3 downto 0);
         S11_AXI_ARVALID      : in  std_logic;
         S11_AXI_ARREADY      : out std_logic;
         S11_AXI_RID          : out std_logic_vector(0 downto 0);
         S11_AXI_RDATA        : out std_logic_vector(127 downto 0);
         S11_AXI_RRESP        : out std_logic_vector(1 downto 0);
         S11_AXI_RLAST        : out std_logic;
         S11_AXI_RVALID       : out std_logic;
         S11_AXI_RREADY       : in  std_logic;
         S12_AXI_ARESET_OUT_N : out std_logic;
         S12_AXI_ACLK         : in  std_logic;
         S12_AXI_AWID         : in  std_logic_vector(0 downto 0);
         S12_AXI_AWADDR       : in  std_logic_vector(31 downto 0);
         S12_AXI_AWLEN        : in  std_logic_vector(7 downto 0);
         S12_AXI_AWSIZE       : in  std_logic_vector(2 downto 0);
         S12_AXI_AWBURST      : in  std_logic_vector(1 downto 0);
         S12_AXI_AWLOCK       : in  std_logic;
         S12_AXI_AWCACHE      : in  std_logic_vector(3 downto 0);
         S12_AXI_AWPROT       : in  std_logic_vector(2 downto 0);
         S12_AXI_AWQOS        : in  std_logic_vector(3 downto 0);
         S12_AXI_AWVALID      : in  std_logic;
         S12_AXI_AWREADY      : out std_logic;
         S12_AXI_WDATA        : in  std_logic_vector(127 downto 0);
         S12_AXI_WSTRB        : in  std_logic_vector(15 downto 0);
         S12_AXI_WLAST        : in  std_logic;
         S12_AXI_WVALID       : in  std_logic;
         S12_AXI_WREADY       : out std_logic;
         S12_AXI_BID          : out std_logic_vector(0 downto 0);
         S12_AXI_BRESP        : out std_logic_vector(1 downto 0);
         S12_AXI_BVALID       : out std_logic;
         S12_AXI_BREADY       : in  std_logic;
         S12_AXI_ARID         : in  std_logic_vector(0 downto 0);
         S12_AXI_ARADDR       : in  std_logic_vector(31 downto 0);
         S12_AXI_ARLEN        : in  std_logic_vector(7 downto 0);
         S12_AXI_ARSIZE       : in  std_logic_vector(2 downto 0);
         S12_AXI_ARBURST      : in  std_logic_vector(1 downto 0);
         S12_AXI_ARLOCK       : in  std_logic;
         S12_AXI_ARCACHE      : in  std_logic_vector(3 downto 0);
         S12_AXI_ARPROT       : in  std_logic_vector(2 downto 0);
         S12_AXI_ARQOS        : in  std_logic_vector(3 downto 0);
         S12_AXI_ARVALID      : in  std_logic;
         S12_AXI_ARREADY      : out std_logic;
         S12_AXI_RID          : out std_logic_vector(0 downto 0);
         S12_AXI_RDATA        : out std_logic_vector(127 downto 0);
         S12_AXI_RRESP        : out std_logic_vector(1 downto 0);
         S12_AXI_RLAST        : out std_logic;
         S12_AXI_RVALID       : out std_logic;
         S12_AXI_RREADY       : in  std_logic;
         S13_AXI_ARESET_OUT_N : out std_logic;
         S13_AXI_ACLK         : in  std_logic;
         S13_AXI_AWID         : in  std_logic_vector(0 downto 0);
         S13_AXI_AWADDR       : in  std_logic_vector(31 downto 0);
         S13_AXI_AWLEN        : in  std_logic_vector(7 downto 0);
         S13_AXI_AWSIZE       : in  std_logic_vector(2 downto 0);
         S13_AXI_AWBURST      : in  std_logic_vector(1 downto 0);
         S13_AXI_AWLOCK       : in  std_logic;
         S13_AXI_AWCACHE      : in  std_logic_vector(3 downto 0);
         S13_AXI_AWPROT       : in  std_logic_vector(2 downto 0);
         S13_AXI_AWQOS        : in  std_logic_vector(3 downto 0);
         S13_AXI_AWVALID      : in  std_logic;
         S13_AXI_AWREADY      : out std_logic;
         S13_AXI_WDATA        : in  std_logic_vector(127 downto 0);
         S13_AXI_WSTRB        : in  std_logic_vector(15 downto 0);
         S13_AXI_WLAST        : in  std_logic;
         S13_AXI_WVALID       : in  std_logic;
         S13_AXI_WREADY       : out std_logic;
         S13_AXI_BID          : out std_logic_vector(0 downto 0);
         S13_AXI_BRESP        : out std_logic_vector(1 downto 0);
         S13_AXI_BVALID       : out std_logic;
         S13_AXI_BREADY       : in  std_logic;
         S13_AXI_ARID         : in  std_logic_vector(0 downto 0);
         S13_AXI_ARADDR       : in  std_logic_vector(31 downto 0);
         S13_AXI_ARLEN        : in  std_logic_vector(7 downto 0);
         S13_AXI_ARSIZE       : in  std_logic_vector(2 downto 0);
         S13_AXI_ARBURST      : in  std_logic_vector(1 downto 0);
         S13_AXI_ARLOCK       : in  std_logic;
         S13_AXI_ARCACHE      : in  std_logic_vector(3 downto 0);
         S13_AXI_ARPROT       : in  std_logic_vector(2 downto 0);
         S13_AXI_ARQOS        : in  std_logic_vector(3 downto 0);
         S13_AXI_ARVALID      : in  std_logic;
         S13_AXI_ARREADY      : out std_logic;
         S13_AXI_RID          : out std_logic_vector(0 downto 0);
         S13_AXI_RDATA        : out std_logic_vector(127 downto 0);
         S13_AXI_RRESP        : out std_logic_vector(1 downto 0);
         S13_AXI_RLAST        : out std_logic;
         S13_AXI_RVALID       : out std_logic;
         S13_AXI_RREADY       : in  std_logic;
         S14_AXI_ARESET_OUT_N : out std_logic;
         S14_AXI_ACLK         : in  std_logic;
         S14_AXI_AWID         : in  std_logic_vector(0 downto 0);
         S14_AXI_AWADDR       : in  std_logic_vector(31 downto 0);
         S14_AXI_AWLEN        : in  std_logic_vector(7 downto 0);
         S14_AXI_AWSIZE       : in  std_logic_vector(2 downto 0);
         S14_AXI_AWBURST      : in  std_logic_vector(1 downto 0);
         S14_AXI_AWLOCK       : in  std_logic;
         S14_AXI_AWCACHE      : in  std_logic_vector(3 downto 0);
         S14_AXI_AWPROT       : in  std_logic_vector(2 downto 0);
         S14_AXI_AWQOS        : in  std_logic_vector(3 downto 0);
         S14_AXI_AWVALID      : in  std_logic;
         S14_AXI_AWREADY      : out std_logic;
         S14_AXI_WDATA        : in  std_logic_vector(127 downto 0);
         S14_AXI_WSTRB        : in  std_logic_vector(15 downto 0);
         S14_AXI_WLAST        : in  std_logic;
         S14_AXI_WVALID       : in  std_logic;
         S14_AXI_WREADY       : out std_logic;
         S14_AXI_BID          : out std_logic_vector(0 downto 0);
         S14_AXI_BRESP        : out std_logic_vector(1 downto 0);
         S14_AXI_BVALID       : out std_logic;
         S14_AXI_BREADY       : in  std_logic;
         S14_AXI_ARID         : in  std_logic_vector(0 downto 0);
         S14_AXI_ARADDR       : in  std_logic_vector(31 downto 0);
         S14_AXI_ARLEN        : in  std_logic_vector(7 downto 0);
         S14_AXI_ARSIZE       : in  std_logic_vector(2 downto 0);
         S14_AXI_ARBURST      : in  std_logic_vector(1 downto 0);
         S14_AXI_ARLOCK       : in  std_logic;
         S14_AXI_ARCACHE      : in  std_logic_vector(3 downto 0);
         S14_AXI_ARPROT       : in  std_logic_vector(2 downto 0);
         S14_AXI_ARQOS        : in  std_logic_vector(3 downto 0);
         S14_AXI_ARVALID      : in  std_logic;
         S14_AXI_ARREADY      : out std_logic;
         S14_AXI_RID          : out std_logic_vector(0 downto 0);
         S14_AXI_RDATA        : out std_logic_vector(127 downto 0);
         S14_AXI_RRESP        : out std_logic_vector(1 downto 0);
         S14_AXI_RLAST        : out std_logic;
         S14_AXI_RVALID       : out std_logic;
         S14_AXI_RREADY       : in  std_logic;
         S15_AXI_ARESET_OUT_N : out std_logic;
         S15_AXI_ACLK         : in  std_logic;
         S15_AXI_AWID         : in  std_logic_vector(0 downto 0);
         S15_AXI_AWADDR       : in  std_logic_vector(31 downto 0);
         S15_AXI_AWLEN        : in  std_logic_vector(7 downto 0);
         S15_AXI_AWSIZE       : in  std_logic_vector(2 downto 0);
         S15_AXI_AWBURST      : in  std_logic_vector(1 downto 0);
         S15_AXI_AWLOCK       : in  std_logic;
         S15_AXI_AWCACHE      : in  std_logic_vector(3 downto 0);
         S15_AXI_AWPROT       : in  std_logic_vector(2 downto 0);
         S15_AXI_AWQOS        : in  std_logic_vector(3 downto 0);
         S15_AXI_AWVALID      : in  std_logic;
         S15_AXI_AWREADY      : out std_logic;
         S15_AXI_WDATA        : in  std_logic_vector(127 downto 0);
         S15_AXI_WSTRB        : in  std_logic_vector(15 downto 0);
         S15_AXI_WLAST        : in  std_logic;
         S15_AXI_WVALID       : in  std_logic;
         S15_AXI_WREADY       : out std_logic;
         S15_AXI_BID          : out std_logic_vector(0 downto 0);
         S15_AXI_BRESP        : out std_logic_vector(1 downto 0);
         S15_AXI_BVALID       : out std_logic;
         S15_AXI_BREADY       : in  std_logic;
         S15_AXI_ARID         : in  std_logic_vector(0 downto 0);
         S15_AXI_ARADDR       : in  std_logic_vector(31 downto 0);
         S15_AXI_ARLEN        : in  std_logic_vector(7 downto 0);
         S15_AXI_ARSIZE       : in  std_logic_vector(2 downto 0);
         S15_AXI_ARBURST      : in  std_logic_vector(1 downto 0);
         S15_AXI_ARLOCK       : in  std_logic;
         S15_AXI_ARCACHE      : in  std_logic_vector(3 downto 0);
         S15_AXI_ARPROT       : in  std_logic_vector(2 downto 0);
         S15_AXI_ARQOS        : in  std_logic_vector(3 downto 0);
         S15_AXI_ARVALID      : in  std_logic;
         S15_AXI_ARREADY      : out std_logic;
         S15_AXI_RID          : out std_logic_vector(0 downto 0);
         S15_AXI_RDATA        : out std_logic_vector(127 downto 0);
         S15_AXI_RRESP        : out std_logic_vector(1 downto 0);
         S15_AXI_RLAST        : out std_logic;
         S15_AXI_RVALID       : out std_logic;
         S15_AXI_RREADY       : in  std_logic;
         M00_AXI_ARESET_OUT_N : out std_logic;
         M00_AXI_ACLK         : in  std_logic;
         M00_AXI_AWID         : out std_logic_vector(3 downto 0);
         M00_AXI_AWADDR       : out std_logic_vector(31 downto 0);
         M00_AXI_AWLEN        : out std_logic_vector(7 downto 0);
         M00_AXI_AWSIZE       : out std_logic_vector(2 downto 0);
         M00_AXI_AWBURST      : out std_logic_vector(1 downto 0);
         M00_AXI_AWLOCK       : out std_logic;
         M00_AXI_AWCACHE      : out std_logic_vector(3 downto 0);
         M00_AXI_AWPROT       : out std_logic_vector(2 downto 0);
         M00_AXI_AWQOS        : out std_logic_vector(3 downto 0);
         M00_AXI_AWVALID      : out std_logic;
         M00_AXI_AWREADY      : in  std_logic;
         M00_AXI_WDATA        : out std_logic_vector(255 downto 0);
         M00_AXI_WSTRB        : out std_logic_vector(31 downto 0);
         M00_AXI_WLAST        : out std_logic;
         M00_AXI_WVALID       : out std_logic;
         M00_AXI_WREADY       : in  std_logic;
         M00_AXI_BID          : in  std_logic_vector(3 downto 0);
         M00_AXI_BRESP        : in  std_logic_vector(1 downto 0);
         M00_AXI_BVALID       : in  std_logic;
         M00_AXI_BREADY       : out std_logic;
         M00_AXI_ARID         : out std_logic_vector(3 downto 0);
         M00_AXI_ARADDR       : out std_logic_vector(31 downto 0);
         M00_AXI_ARLEN        : out std_logic_vector(7 downto 0);
         M00_AXI_ARSIZE       : out std_logic_vector(2 downto 0);
         M00_AXI_ARBURST      : out std_logic_vector(1 downto 0);
         M00_AXI_ARLOCK       : out std_logic;
         M00_AXI_ARCACHE      : out std_logic_vector(3 downto 0);
         M00_AXI_ARPROT       : out std_logic_vector(2 downto 0);
         M00_AXI_ARQOS        : out std_logic_vector(3 downto 0);
         M00_AXI_ARVALID      : out std_logic;
         M00_AXI_ARREADY      : in  std_logic;
         M00_AXI_RID          : in  std_logic_vector(3 downto 0);
         M00_AXI_RDATA        : in  std_logic_vector(255 downto 0);
         M00_AXI_RRESP        : in  std_logic_vector(1 downto 0);
         M00_AXI_RLAST        : in  std_logic;
         M00_AXI_RVALID       : in  std_logic;
         M00_AXI_RREADY       : out std_logic);
   end component;

   signal axiRstL : sl;

begin

   axiRstL <= not(axiRst);

   -------------------
   -- AXI PCIe IP Core
   -------------------
   U_AxiCrossbar : AxiPcieCrossbarIpCore
      port map (
         INTERCONNECT_ACLK    => axiClk,
         INTERCONNECT_ARESETN => axiRstL,
         -- SLAVE[0]
         S00_AXI_ARESET_OUT_N => open,
         S00_AXI_ACLK         => axiClk,
         S00_AXI_AWID(0)      => '0',
         S00_AXI_AWADDR       => sAxiWriteMasters(0).awaddr(31 downto 0),
         S00_AXI_AWLEN        => sAxiWriteMasters(0).awlen,
         S00_AXI_AWSIZE       => sAxiWriteMasters(0).awsize,
         S00_AXI_AWBURST      => sAxiWriteMasters(0).awburst,
         S00_AXI_AWLOCK       => sAxiWriteMasters(0).awlock(0),
         S00_AXI_AWCACHE      => sAxiWriteMasters(0).awcache,
         S00_AXI_AWPROT       => sAxiWriteMasters(0).awprot,
         S00_AXI_AWQOS        => sAxiWriteMasters(0).awqos,
         S00_AXI_AWVALID      => sAxiWriteMasters(0).awvalid,
         S00_AXI_AWREADY      => sAxiWriteSlaves(0).awready,
         S00_AXI_WDATA        => sAxiWriteMasters(0).wdata(127 downto 0),
         S00_AXI_WSTRB        => sAxiWriteMasters(0).wstrb(15 downto 0),
         S00_AXI_WLAST        => sAxiWriteMasters(0).wlast,
         S00_AXI_WVALID       => sAxiWriteMasters(0).wvalid,
         S00_AXI_WREADY       => sAxiWriteSlaves(0).wready,
         S00_AXI_BID          => sAxiWriteSlaves(0).bid(0 downto 0),
         S00_AXI_BRESP        => sAxiWriteSlaves(0).bresp,
         S00_AXI_BVALID       => sAxiWriteSlaves(0).bvalid,
         S00_AXI_BREADY       => sAxiWriteMasters(0).bready,
         S00_AXI_ARID(0)      => '0',
         S00_AXI_ARADDR       => sAxiReadMasters(0).araddr(31 downto 0),
         S00_AXI_ARLEN        => sAxiReadMasters(0).arlen,
         S00_AXI_ARSIZE       => sAxiReadMasters(0).arsize,
         S00_AXI_ARBURST      => sAxiReadMasters(0).arburst,
         S00_AXI_ARLOCK       => sAxiReadMasters(0).arlock(0),
         S00_AXI_ARCACHE      => sAxiReadMasters(0).arcache,
         S00_AXI_ARPROT       => sAxiReadMasters(0).arprot,
         S00_AXI_ARQOS        => sAxiReadMasters(0).arqos,
         S00_AXI_ARVALID      => sAxiReadMasters(0).arvalid,
         S00_AXI_ARREADY      => sAxiReadSlaves(0).arready,
         S00_AXI_RID          => sAxiReadSlaves(0).rid(0 downto 0),
         S00_AXI_RDATA        => sAxiReadSlaves(0).rdata(127 downto 0),
         S00_AXI_RRESP        => sAxiReadSlaves(0).rresp,
         S00_AXI_RLAST        => sAxiReadSlaves(0).rlast,
         S00_AXI_RVALID       => sAxiReadSlaves(0).rvalid,
         S00_AXI_RREADY       => sAxiReadMasters(0).rready,
         -- SLAVE[1]
         S01_AXI_ARESET_OUT_N => open,
         S01_AXI_ACLK         => axiClk,
         S01_AXI_AWID(0)      => '0',
         S01_AXI_AWADDR       => sAxiWriteMasters(1).awaddr(31 downto 0),
         S01_AXI_AWLEN        => sAxiWriteMasters(1).awlen,
         S01_AXI_AWSIZE       => sAxiWriteMasters(1).awsize,
         S01_AXI_AWBURST      => sAxiWriteMasters(1).awburst,
         S01_AXI_AWLOCK       => sAxiWriteMasters(1).awlock(0),
         S01_AXI_AWCACHE      => sAxiWriteMasters(1).awcache,
         S01_AXI_AWPROT       => sAxiWriteMasters(1).awprot,
         S01_AXI_AWQOS        => sAxiWriteMasters(1).awqos,
         S01_AXI_AWVALID      => sAxiWriteMasters(1).awvalid,
         S01_AXI_AWREADY      => sAxiWriteSlaves(1).awready,
         S01_AXI_WDATA        => sAxiWriteMasters(1).wdata(127 downto 0),
         S01_AXI_WSTRB        => sAxiWriteMasters(1).wstrb(15 downto 0),
         S01_AXI_WLAST        => sAxiWriteMasters(1).wlast,
         S01_AXI_WVALID       => sAxiWriteMasters(1).wvalid,
         S01_AXI_WREADY       => sAxiWriteSlaves(1).wready,
         S01_AXI_BID          => sAxiWriteSlaves(1).bid(0 downto 0),
         S01_AXI_BRESP        => sAxiWriteSlaves(1).bresp,
         S01_AXI_BVALID       => sAxiWriteSlaves(1).bvalid,
         S01_AXI_BREADY       => sAxiWriteMasters(1).bready,
         S01_AXI_ARID(0)      => '0',
         S01_AXI_ARADDR       => sAxiReadMasters(1).araddr(31 downto 0),
         S01_AXI_ARLEN        => sAxiReadMasters(1).arlen,
         S01_AXI_ARSIZE       => sAxiReadMasters(1).arsize,
         S01_AXI_ARBURST      => sAxiReadMasters(1).arburst,
         S01_AXI_ARLOCK       => sAxiReadMasters(1).arlock(0),
         S01_AXI_ARCACHE      => sAxiReadMasters(1).arcache,
         S01_AXI_ARPROT       => sAxiReadMasters(1).arprot,
         S01_AXI_ARQOS        => sAxiReadMasters(1).arqos,
         S01_AXI_ARVALID      => sAxiReadMasters(1).arvalid,
         S01_AXI_ARREADY      => sAxiReadSlaves(1).arready,
         S01_AXI_RID          => sAxiReadSlaves(1).rid(0 downto 0),
         S01_AXI_RDATA        => sAxiReadSlaves(1).rdata(127 downto 0),
         S01_AXI_RRESP        => sAxiReadSlaves(1).rresp,
         S01_AXI_RLAST        => sAxiReadSlaves(1).rlast,
         S01_AXI_RVALID       => sAxiReadSlaves(1).rvalid,
         S01_AXI_RREADY       => sAxiReadMasters(1).rready,
         -- SLAVE[2]
         S02_AXI_ARESET_OUT_N => open,
         S02_AXI_ACLK         => axiClk,
         S02_AXI_AWID(0)      => '0',
         S02_AXI_AWADDR       => sAxiWriteMasters(2).awaddr(31 downto 0),
         S02_AXI_AWLEN        => sAxiWriteMasters(2).awlen,
         S02_AXI_AWSIZE       => sAxiWriteMasters(2).awsize,
         S02_AXI_AWBURST      => sAxiWriteMasters(2).awburst,
         S02_AXI_AWLOCK       => sAxiWriteMasters(2).awlock(0),
         S02_AXI_AWCACHE      => sAxiWriteMasters(2).awcache,
         S02_AXI_AWPROT       => sAxiWriteMasters(2).awprot,
         S02_AXI_AWQOS        => sAxiWriteMasters(2).awqos,
         S02_AXI_AWVALID      => sAxiWriteMasters(2).awvalid,
         S02_AXI_AWREADY      => sAxiWriteSlaves(2).awready,
         S02_AXI_WDATA        => sAxiWriteMasters(2).wdata(127 downto 0),
         S02_AXI_WSTRB        => sAxiWriteMasters(2).wstrb(15 downto 0),
         S02_AXI_WLAST        => sAxiWriteMasters(2).wlast,
         S02_AXI_WVALID       => sAxiWriteMasters(2).wvalid,
         S02_AXI_WREADY       => sAxiWriteSlaves(2).wready,
         S02_AXI_BID          => sAxiWriteSlaves(2).bid(0 downto 0),
         S02_AXI_BRESP        => sAxiWriteSlaves(2).bresp,
         S02_AXI_BVALID       => sAxiWriteSlaves(2).bvalid,
         S02_AXI_BREADY       => sAxiWriteMasters(2).bready,
         S02_AXI_ARID(0)      => '0',
         S02_AXI_ARADDR       => sAxiReadMasters(2).araddr(31 downto 0),
         S02_AXI_ARLEN        => sAxiReadMasters(2).arlen,
         S02_AXI_ARSIZE       => sAxiReadMasters(2).arsize,
         S02_AXI_ARBURST      => sAxiReadMasters(2).arburst,
         S02_AXI_ARLOCK       => sAxiReadMasters(2).arlock(0),
         S02_AXI_ARCACHE      => sAxiReadMasters(2).arcache,
         S02_AXI_ARPROT       => sAxiReadMasters(2).arprot,
         S02_AXI_ARQOS        => sAxiReadMasters(2).arqos,
         S02_AXI_ARVALID      => sAxiReadMasters(2).arvalid,
         S02_AXI_ARREADY      => sAxiReadSlaves(2).arready,
         S02_AXI_RID          => sAxiReadSlaves(2).rid(0 downto 0),
         S02_AXI_RDATA        => sAxiReadSlaves(2).rdata(127 downto 0),
         S02_AXI_RRESP        => sAxiReadSlaves(2).rresp,
         S02_AXI_RLAST        => sAxiReadSlaves(2).rlast,
         S02_AXI_RVALID       => sAxiReadSlaves(2).rvalid,
         S02_AXI_RREADY       => sAxiReadMasters(2).rready,
         -- SLAVE[3]
         S03_AXI_ARESET_OUT_N => open,
         S03_AXI_ACLK         => axiClk,
         S03_AXI_AWID(0)      => '0',
         S03_AXI_AWADDR       => sAxiWriteMasters(3).awaddr(31 downto 0),
         S03_AXI_AWLEN        => sAxiWriteMasters(3).awlen,
         S03_AXI_AWSIZE       => sAxiWriteMasters(3).awsize,
         S03_AXI_AWBURST      => sAxiWriteMasters(3).awburst,
         S03_AXI_AWLOCK       => sAxiWriteMasters(3).awlock(0),
         S03_AXI_AWCACHE      => sAxiWriteMasters(3).awcache,
         S03_AXI_AWPROT       => sAxiWriteMasters(3).awprot,
         S03_AXI_AWQOS        => sAxiWriteMasters(3).awqos,
         S03_AXI_AWVALID      => sAxiWriteMasters(3).awvalid,
         S03_AXI_AWREADY      => sAxiWriteSlaves(3).awready,
         S03_AXI_WDATA        => sAxiWriteMasters(3).wdata(127 downto 0),
         S03_AXI_WSTRB        => sAxiWriteMasters(3).wstrb(15 downto 0),
         S03_AXI_WLAST        => sAxiWriteMasters(3).wlast,
         S03_AXI_WVALID       => sAxiWriteMasters(3).wvalid,
         S03_AXI_WREADY       => sAxiWriteSlaves(3).wready,
         S03_AXI_BID          => sAxiWriteSlaves(3).bid(0 downto 0),
         S03_AXI_BRESP        => sAxiWriteSlaves(3).bresp,
         S03_AXI_BVALID       => sAxiWriteSlaves(3).bvalid,
         S03_AXI_BREADY       => sAxiWriteMasters(3).bready,
         S03_AXI_ARID(0)      => '0',
         S03_AXI_ARADDR       => sAxiReadMasters(3).araddr(31 downto 0),
         S03_AXI_ARLEN        => sAxiReadMasters(3).arlen,
         S03_AXI_ARSIZE       => sAxiReadMasters(3).arsize,
         S03_AXI_ARBURST      => sAxiReadMasters(3).arburst,
         S03_AXI_ARLOCK       => sAxiReadMasters(3).arlock(0),
         S03_AXI_ARCACHE      => sAxiReadMasters(3).arcache,
         S03_AXI_ARPROT       => sAxiReadMasters(3).arprot,
         S03_AXI_ARQOS        => sAxiReadMasters(3).arqos,
         S03_AXI_ARVALID      => sAxiReadMasters(3).arvalid,
         S03_AXI_ARREADY      => sAxiReadSlaves(3).arready,
         S03_AXI_RID          => sAxiReadSlaves(3).rid(0 downto 0),
         S03_AXI_RDATA        => sAxiReadSlaves(3).rdata(127 downto 0),
         S03_AXI_RRESP        => sAxiReadSlaves(3).rresp,
         S03_AXI_RLAST        => sAxiReadSlaves(3).rlast,
         S03_AXI_RVALID       => sAxiReadSlaves(3).rvalid,
         S03_AXI_RREADY       => sAxiReadMasters(3).rready,
         -- SLAVE[4]
         S04_AXI_ARESET_OUT_N => open,
         S04_AXI_ACLK         => axiClk,
         S04_AXI_AWID(0)      => '0',
         S04_AXI_AWADDR       => sAxiWriteMasters(4).awaddr(31 downto 0),
         S04_AXI_AWLEN        => sAxiWriteMasters(4).awlen,
         S04_AXI_AWSIZE       => sAxiWriteMasters(4).awsize,
         S04_AXI_AWBURST      => sAxiWriteMasters(4).awburst,
         S04_AXI_AWLOCK       => sAxiWriteMasters(4).awlock(0),
         S04_AXI_AWCACHE      => sAxiWriteMasters(4).awcache,
         S04_AXI_AWPROT       => sAxiWriteMasters(4).awprot,
         S04_AXI_AWQOS        => sAxiWriteMasters(4).awqos,
         S04_AXI_AWVALID      => sAxiWriteMasters(4).awvalid,
         S04_AXI_AWREADY      => sAxiWriteSlaves(4).awready,
         S04_AXI_WDATA        => sAxiWriteMasters(4).wdata(127 downto 0),
         S04_AXI_WSTRB        => sAxiWriteMasters(4).wstrb(15 downto 0),
         S04_AXI_WLAST        => sAxiWriteMasters(4).wlast,
         S04_AXI_WVALID       => sAxiWriteMasters(4).wvalid,
         S04_AXI_WREADY       => sAxiWriteSlaves(4).wready,
         S04_AXI_BID          => sAxiWriteSlaves(4).bid(0 downto 0),
         S04_AXI_BRESP        => sAxiWriteSlaves(4).bresp,
         S04_AXI_BVALID       => sAxiWriteSlaves(4).bvalid,
         S04_AXI_BREADY       => sAxiWriteMasters(4).bready,
         S04_AXI_ARID(0)      => '0',
         S04_AXI_ARADDR       => sAxiReadMasters(4).araddr(31 downto 0),
         S04_AXI_ARLEN        => sAxiReadMasters(4).arlen,
         S04_AXI_ARSIZE       => sAxiReadMasters(4).arsize,
         S04_AXI_ARBURST      => sAxiReadMasters(4).arburst,
         S04_AXI_ARLOCK       => sAxiReadMasters(4).arlock(0),
         S04_AXI_ARCACHE      => sAxiReadMasters(4).arcache,
         S04_AXI_ARPROT       => sAxiReadMasters(4).arprot,
         S04_AXI_ARQOS        => sAxiReadMasters(4).arqos,
         S04_AXI_ARVALID      => sAxiReadMasters(4).arvalid,
         S04_AXI_ARREADY      => sAxiReadSlaves(4).arready,
         S04_AXI_RID          => sAxiReadSlaves(4).rid(0 downto 0),
         S04_AXI_RDATA        => sAxiReadSlaves(4).rdata(127 downto 0),
         S04_AXI_RRESP        => sAxiReadSlaves(4).rresp,
         S04_AXI_RLAST        => sAxiReadSlaves(4).rlast,
         S04_AXI_RVALID       => sAxiReadSlaves(4).rvalid,
         S04_AXI_RREADY       => sAxiReadMasters(4).rready,
         -- SLAVE[5]
         S05_AXI_ARESET_OUT_N => open,
         S05_AXI_ACLK         => axiClk,
         S05_AXI_AWID(0)      => '0',
         S05_AXI_AWADDR       => sAxiWriteMasters(5).awaddr(31 downto 0),
         S05_AXI_AWLEN        => sAxiWriteMasters(5).awlen,
         S05_AXI_AWSIZE       => sAxiWriteMasters(5).awsize,
         S05_AXI_AWBURST      => sAxiWriteMasters(5).awburst,
         S05_AXI_AWLOCK       => sAxiWriteMasters(5).awlock(0),
         S05_AXI_AWCACHE      => sAxiWriteMasters(5).awcache,
         S05_AXI_AWPROT       => sAxiWriteMasters(5).awprot,
         S05_AXI_AWQOS        => sAxiWriteMasters(5).awqos,
         S05_AXI_AWVALID      => sAxiWriteMasters(5).awvalid,
         S05_AXI_AWREADY      => sAxiWriteSlaves(5).awready,
         S05_AXI_WDATA        => sAxiWriteMasters(5).wdata(127 downto 0),
         S05_AXI_WSTRB        => sAxiWriteMasters(5).wstrb(15 downto 0),
         S05_AXI_WLAST        => sAxiWriteMasters(5).wlast,
         S05_AXI_WVALID       => sAxiWriteMasters(5).wvalid,
         S05_AXI_WREADY       => sAxiWriteSlaves(5).wready,
         S05_AXI_BID          => sAxiWriteSlaves(5).bid(0 downto 0),
         S05_AXI_BRESP        => sAxiWriteSlaves(5).bresp,
         S05_AXI_BVALID       => sAxiWriteSlaves(5).bvalid,
         S05_AXI_BREADY       => sAxiWriteMasters(5).bready,
         S05_AXI_ARID(0)      => '0',
         S05_AXI_ARADDR       => sAxiReadMasters(5).araddr(31 downto 0),
         S05_AXI_ARLEN        => sAxiReadMasters(5).arlen,
         S05_AXI_ARSIZE       => sAxiReadMasters(5).arsize,
         S05_AXI_ARBURST      => sAxiReadMasters(5).arburst,
         S05_AXI_ARLOCK       => sAxiReadMasters(5).arlock(0),
         S05_AXI_ARCACHE      => sAxiReadMasters(5).arcache,
         S05_AXI_ARPROT       => sAxiReadMasters(5).arprot,
         S05_AXI_ARQOS        => sAxiReadMasters(5).arqos,
         S05_AXI_ARVALID      => sAxiReadMasters(5).arvalid,
         S05_AXI_ARREADY      => sAxiReadSlaves(5).arready,
         S05_AXI_RID          => sAxiReadSlaves(5).rid(0 downto 0),
         S05_AXI_RDATA        => sAxiReadSlaves(5).rdata(127 downto 0),
         S05_AXI_RRESP        => sAxiReadSlaves(5).rresp,
         S05_AXI_RLAST        => sAxiReadSlaves(5).rlast,
         S05_AXI_RVALID       => sAxiReadSlaves(5).rvalid,
         S05_AXI_RREADY       => sAxiReadMasters(5).rready,
         -- SLAVE[6]
         S06_AXI_ARESET_OUT_N => open,
         S06_AXI_ACLK         => axiClk,
         S06_AXI_AWID(0)      => '0',
         S06_AXI_AWADDR       => sAxiWriteMasters(6).awaddr(31 downto 0),
         S06_AXI_AWLEN        => sAxiWriteMasters(6).awlen,
         S06_AXI_AWSIZE       => sAxiWriteMasters(6).awsize,
         S06_AXI_AWBURST      => sAxiWriteMasters(6).awburst,
         S06_AXI_AWLOCK       => sAxiWriteMasters(6).awlock(0),
         S06_AXI_AWCACHE      => sAxiWriteMasters(6).awcache,
         S06_AXI_AWPROT       => sAxiWriteMasters(6).awprot,
         S06_AXI_AWQOS        => sAxiWriteMasters(6).awqos,
         S06_AXI_AWVALID      => sAxiWriteMasters(6).awvalid,
         S06_AXI_AWREADY      => sAxiWriteSlaves(6).awready,
         S06_AXI_WDATA        => sAxiWriteMasters(6).wdata(127 downto 0),
         S06_AXI_WSTRB        => sAxiWriteMasters(6).wstrb(15 downto 0),
         S06_AXI_WLAST        => sAxiWriteMasters(6).wlast,
         S06_AXI_WVALID       => sAxiWriteMasters(6).wvalid,
         S06_AXI_WREADY       => sAxiWriteSlaves(6).wready,
         S06_AXI_BID          => sAxiWriteSlaves(6).bid(0 downto 0),
         S06_AXI_BRESP        => sAxiWriteSlaves(6).bresp,
         S06_AXI_BVALID       => sAxiWriteSlaves(6).bvalid,
         S06_AXI_BREADY       => sAxiWriteMasters(6).bready,
         S06_AXI_ARID(0)      => '0',
         S06_AXI_ARADDR       => sAxiReadMasters(6).araddr(31 downto 0),
         S06_AXI_ARLEN        => sAxiReadMasters(6).arlen,
         S06_AXI_ARSIZE       => sAxiReadMasters(6).arsize,
         S06_AXI_ARBURST      => sAxiReadMasters(6).arburst,
         S06_AXI_ARLOCK       => sAxiReadMasters(6).arlock(0),
         S06_AXI_ARCACHE      => sAxiReadMasters(6).arcache,
         S06_AXI_ARPROT       => sAxiReadMasters(6).arprot,
         S06_AXI_ARQOS        => sAxiReadMasters(6).arqos,
         S06_AXI_ARVALID      => sAxiReadMasters(6).arvalid,
         S06_AXI_ARREADY      => sAxiReadSlaves(6).arready,
         S06_AXI_RID          => sAxiReadSlaves(6).rid(0 downto 0),
         S06_AXI_RDATA        => sAxiReadSlaves(6).rdata(127 downto 0),
         S06_AXI_RRESP        => sAxiReadSlaves(6).rresp,
         S06_AXI_RLAST        => sAxiReadSlaves(6).rlast,
         S06_AXI_RVALID       => sAxiReadSlaves(6).rvalid,
         S06_AXI_RREADY       => sAxiReadMasters(6).rready,
         -- SLAVE[7]
         S07_AXI_ARESET_OUT_N => open,
         S07_AXI_ACLK         => axiClk,
         S07_AXI_AWID(0)      => '0',
         S07_AXI_AWADDR       => sAxiWriteMasters(7).awaddr(31 downto 0),
         S07_AXI_AWLEN        => sAxiWriteMasters(7).awlen,
         S07_AXI_AWSIZE       => sAxiWriteMasters(7).awsize,
         S07_AXI_AWBURST      => sAxiWriteMasters(7).awburst,
         S07_AXI_AWLOCK       => sAxiWriteMasters(7).awlock(0),
         S07_AXI_AWCACHE      => sAxiWriteMasters(7).awcache,
         S07_AXI_AWPROT       => sAxiWriteMasters(7).awprot,
         S07_AXI_AWQOS        => sAxiWriteMasters(7).awqos,
         S07_AXI_AWVALID      => sAxiWriteMasters(7).awvalid,
         S07_AXI_AWREADY      => sAxiWriteSlaves(7).awready,
         S07_AXI_WDATA        => sAxiWriteMasters(7).wdata(127 downto 0),
         S07_AXI_WSTRB        => sAxiWriteMasters(7).wstrb(15 downto 0),
         S07_AXI_WLAST        => sAxiWriteMasters(7).wlast,
         S07_AXI_WVALID       => sAxiWriteMasters(7).wvalid,
         S07_AXI_WREADY       => sAxiWriteSlaves(7).wready,
         S07_AXI_BID          => sAxiWriteSlaves(7).bid(0 downto 0),
         S07_AXI_BRESP        => sAxiWriteSlaves(7).bresp,
         S07_AXI_BVALID       => sAxiWriteSlaves(7).bvalid,
         S07_AXI_BREADY       => sAxiWriteMasters(7).bready,
         S07_AXI_ARID(0)      => '0',
         S07_AXI_ARADDR       => sAxiReadMasters(7).araddr(31 downto 0),
         S07_AXI_ARLEN        => sAxiReadMasters(7).arlen,
         S07_AXI_ARSIZE       => sAxiReadMasters(7).arsize,
         S07_AXI_ARBURST      => sAxiReadMasters(7).arburst,
         S07_AXI_ARLOCK       => sAxiReadMasters(7).arlock(0),
         S07_AXI_ARCACHE      => sAxiReadMasters(7).arcache,
         S07_AXI_ARPROT       => sAxiReadMasters(7).arprot,
         S07_AXI_ARQOS        => sAxiReadMasters(7).arqos,
         S07_AXI_ARVALID      => sAxiReadMasters(7).arvalid,
         S07_AXI_ARREADY      => sAxiReadSlaves(7).arready,
         S07_AXI_RID          => sAxiReadSlaves(7).rid(0 downto 0),
         S07_AXI_RDATA        => sAxiReadSlaves(7).rdata(127 downto 0),
         S07_AXI_RRESP        => sAxiReadSlaves(7).rresp,
         S07_AXI_RLAST        => sAxiReadSlaves(7).rlast,
         S07_AXI_RVALID       => sAxiReadSlaves(7).rvalid,
         S07_AXI_RREADY       => sAxiReadMasters(7).rready,
         -- SLAVE[8]
         S08_AXI_ARESET_OUT_N => open,
         S08_AXI_ACLK         => axiClk,
         S08_AXI_AWID(0)      => '0',
         S08_AXI_AWADDR       => sAxiWriteMasters(8).awaddr(31 downto 0),
         S08_AXI_AWLEN        => sAxiWriteMasters(8).awlen,
         S08_AXI_AWSIZE       => sAxiWriteMasters(8).awsize,
         S08_AXI_AWBURST      => sAxiWriteMasters(8).awburst,
         S08_AXI_AWLOCK       => sAxiWriteMasters(8).awlock(0),
         S08_AXI_AWCACHE      => sAxiWriteMasters(8).awcache,
         S08_AXI_AWPROT       => sAxiWriteMasters(8).awprot,
         S08_AXI_AWQOS        => sAxiWriteMasters(8).awqos,
         S08_AXI_AWVALID      => sAxiWriteMasters(8).awvalid,
         S08_AXI_AWREADY      => sAxiWriteSlaves(8).awready,
         S08_AXI_WDATA        => sAxiWriteMasters(8).wdata(127 downto 0),
         S08_AXI_WSTRB        => sAxiWriteMasters(8).wstrb(15 downto 0),
         S08_AXI_WLAST        => sAxiWriteMasters(8).wlast,
         S08_AXI_WVALID       => sAxiWriteMasters(8).wvalid,
         S08_AXI_WREADY       => sAxiWriteSlaves(8).wready,
         S08_AXI_BID          => sAxiWriteSlaves(8).bid(0 downto 0),
         S08_AXI_BRESP        => sAxiWriteSlaves(8).bresp,
         S08_AXI_BVALID       => sAxiWriteSlaves(8).bvalid,
         S08_AXI_BREADY       => sAxiWriteMasters(8).bready,
         S08_AXI_ARID(0)      => '0',
         S08_AXI_ARADDR       => sAxiReadMasters(8).araddr(31 downto 0),
         S08_AXI_ARLEN        => sAxiReadMasters(8).arlen,
         S08_AXI_ARSIZE       => sAxiReadMasters(8).arsize,
         S08_AXI_ARBURST      => sAxiReadMasters(8).arburst,
         S08_AXI_ARLOCK       => sAxiReadMasters(8).arlock(0),
         S08_AXI_ARCACHE      => sAxiReadMasters(8).arcache,
         S08_AXI_ARPROT       => sAxiReadMasters(8).arprot,
         S08_AXI_ARQOS        => sAxiReadMasters(8).arqos,
         S08_AXI_ARVALID      => sAxiReadMasters(8).arvalid,
         S08_AXI_ARREADY      => sAxiReadSlaves(8).arready,
         S08_AXI_RID          => sAxiReadSlaves(8).rid(0 downto 0),
         S08_AXI_RDATA        => sAxiReadSlaves(8).rdata(127 downto 0),
         S08_AXI_RRESP        => sAxiReadSlaves(8).rresp,
         S08_AXI_RLAST        => sAxiReadSlaves(8).rlast,
         S08_AXI_RVALID       => sAxiReadSlaves(8).rvalid,
         S08_AXI_RREADY       => sAxiReadMasters(8).rready,
         -- SLAVE[9]
         S09_AXI_ARESET_OUT_N => open,
         S09_AXI_ACLK         => axiClk,
         S09_AXI_AWID(0)      => '0',
         S09_AXI_AWADDR       => sAxiWriteMasters(9).awaddr(31 downto 0),
         S09_AXI_AWLEN        => sAxiWriteMasters(9).awlen,
         S09_AXI_AWSIZE       => sAxiWriteMasters(9).awsize,
         S09_AXI_AWBURST      => sAxiWriteMasters(9).awburst,
         S09_AXI_AWLOCK       => sAxiWriteMasters(9).awlock(0),
         S09_AXI_AWCACHE      => sAxiWriteMasters(9).awcache,
         S09_AXI_AWPROT       => sAxiWriteMasters(9).awprot,
         S09_AXI_AWQOS        => sAxiWriteMasters(9).awqos,
         S09_AXI_AWVALID      => sAxiWriteMasters(9).awvalid,
         S09_AXI_AWREADY      => sAxiWriteSlaves(9).awready,
         S09_AXI_WDATA        => sAxiWriteMasters(9).wdata(127 downto 0),
         S09_AXI_WSTRB        => sAxiWriteMasters(9).wstrb(15 downto 0),
         S09_AXI_WLAST        => sAxiWriteMasters(9).wlast,
         S09_AXI_WVALID       => sAxiWriteMasters(9).wvalid,
         S09_AXI_WREADY       => sAxiWriteSlaves(9).wready,
         S09_AXI_BID          => sAxiWriteSlaves(9).bid(0 downto 0),
         S09_AXI_BRESP        => sAxiWriteSlaves(9).bresp,
         S09_AXI_BVALID       => sAxiWriteSlaves(9).bvalid,
         S09_AXI_BREADY       => sAxiWriteMasters(9).bready,
         S09_AXI_ARID(0)      => '0',
         S09_AXI_ARADDR       => sAxiReadMasters(9).araddr(31 downto 0),
         S09_AXI_ARLEN        => sAxiReadMasters(9).arlen,
         S09_AXI_ARSIZE       => sAxiReadMasters(9).arsize,
         S09_AXI_ARBURST      => sAxiReadMasters(9).arburst,
         S09_AXI_ARLOCK       => sAxiReadMasters(9).arlock(0),
         S09_AXI_ARCACHE      => sAxiReadMasters(9).arcache,
         S09_AXI_ARPROT       => sAxiReadMasters(9).arprot,
         S09_AXI_ARQOS        => sAxiReadMasters(9).arqos,
         S09_AXI_ARVALID      => sAxiReadMasters(9).arvalid,
         S09_AXI_ARREADY      => sAxiReadSlaves(9).arready,
         S09_AXI_RID          => sAxiReadSlaves(9).rid(0 downto 0),
         S09_AXI_RDATA        => sAxiReadSlaves(9).rdata(127 downto 0),
         S09_AXI_RRESP        => sAxiReadSlaves(9).rresp,
         S09_AXI_RLAST        => sAxiReadSlaves(9).rlast,
         S09_AXI_RVALID       => sAxiReadSlaves(9).rvalid,
         S09_AXI_RREADY       => sAxiReadMasters(9).rready,
         -- SLAVE[10]
         S10_AXI_ARESET_OUT_N => open,
         S10_AXI_ACLK         => axiClk,
         S10_AXI_AWID(0)      => '0',
         S10_AXI_AWADDR       => sAxiWriteMasters(10).awaddr(31 downto 0),
         S10_AXI_AWLEN        => sAxiWriteMasters(10).awlen,
         S10_AXI_AWSIZE       => sAxiWriteMasters(10).awsize,
         S10_AXI_AWBURST      => sAxiWriteMasters(10).awburst,
         S10_AXI_AWLOCK       => sAxiWriteMasters(10).awlock(0),
         S10_AXI_AWCACHE      => sAxiWriteMasters(10).awcache,
         S10_AXI_AWPROT       => sAxiWriteMasters(10).awprot,
         S10_AXI_AWQOS        => sAxiWriteMasters(10).awqos,
         S10_AXI_AWVALID      => sAxiWriteMasters(10).awvalid,
         S10_AXI_AWREADY      => sAxiWriteSlaves(10).awready,
         S10_AXI_WDATA        => sAxiWriteMasters(10).wdata(127 downto 0),
         S10_AXI_WSTRB        => sAxiWriteMasters(10).wstrb(15 downto 0),
         S10_AXI_WLAST        => sAxiWriteMasters(10).wlast,
         S10_AXI_WVALID       => sAxiWriteMasters(10).wvalid,
         S10_AXI_WREADY       => sAxiWriteSlaves(10).wready,
         S10_AXI_BID          => sAxiWriteSlaves(10).bid(0 downto 0),
         S10_AXI_BRESP        => sAxiWriteSlaves(10).bresp,
         S10_AXI_BVALID       => sAxiWriteSlaves(10).bvalid,
         S10_AXI_BREADY       => sAxiWriteMasters(10).bready,
         S10_AXI_ARID(0)      => '0',
         S10_AXI_ARADDR       => sAxiReadMasters(10).araddr(31 downto 0),
         S10_AXI_ARLEN        => sAxiReadMasters(10).arlen,
         S10_AXI_ARSIZE       => sAxiReadMasters(10).arsize,
         S10_AXI_ARBURST      => sAxiReadMasters(10).arburst,
         S10_AXI_ARLOCK       => sAxiReadMasters(10).arlock(0),
         S10_AXI_ARCACHE      => sAxiReadMasters(10).arcache,
         S10_AXI_ARPROT       => sAxiReadMasters(10).arprot,
         S10_AXI_ARQOS        => sAxiReadMasters(10).arqos,
         S10_AXI_ARVALID      => sAxiReadMasters(10).arvalid,
         S10_AXI_ARREADY      => sAxiReadSlaves(10).arready,
         S10_AXI_RID          => sAxiReadSlaves(10).rid(0 downto 0),
         S10_AXI_RDATA        => sAxiReadSlaves(10).rdata(127 downto 0),
         S10_AXI_RRESP        => sAxiReadSlaves(10).rresp,
         S10_AXI_RLAST        => sAxiReadSlaves(10).rlast,
         S10_AXI_RVALID       => sAxiReadSlaves(10).rvalid,
         S10_AXI_RREADY       => sAxiReadMasters(10).rready,
         -- SLAVE[11]
         S11_AXI_ARESET_OUT_N => open,
         S11_AXI_ACLK         => axiClk,
         S11_AXI_AWID(0)      => '0',
         S11_AXI_AWADDR       => sAxiWriteMasters(11).awaddr(31 downto 0),
         S11_AXI_AWLEN        => sAxiWriteMasters(11).awlen,
         S11_AXI_AWSIZE       => sAxiWriteMasters(11).awsize,
         S11_AXI_AWBURST      => sAxiWriteMasters(11).awburst,
         S11_AXI_AWLOCK       => sAxiWriteMasters(11).awlock(0),
         S11_AXI_AWCACHE      => sAxiWriteMasters(11).awcache,
         S11_AXI_AWPROT       => sAxiWriteMasters(11).awprot,
         S11_AXI_AWQOS        => sAxiWriteMasters(11).awqos,
         S11_AXI_AWVALID      => sAxiWriteMasters(11).awvalid,
         S11_AXI_AWREADY      => sAxiWriteSlaves(11).awready,
         S11_AXI_WDATA        => sAxiWriteMasters(11).wdata(127 downto 0),
         S11_AXI_WSTRB        => sAxiWriteMasters(11).wstrb(15 downto 0),
         S11_AXI_WLAST        => sAxiWriteMasters(11).wlast,
         S11_AXI_WVALID       => sAxiWriteMasters(11).wvalid,
         S11_AXI_WREADY       => sAxiWriteSlaves(11).wready,
         S11_AXI_BID          => sAxiWriteSlaves(11).bid(0 downto 0),
         S11_AXI_BRESP        => sAxiWriteSlaves(11).bresp,
         S11_AXI_BVALID       => sAxiWriteSlaves(11).bvalid,
         S11_AXI_BREADY       => sAxiWriteMasters(11).bready,
         S11_AXI_ARID(0)      => '0',
         S11_AXI_ARADDR       => sAxiReadMasters(11).araddr(31 downto 0),
         S11_AXI_ARLEN        => sAxiReadMasters(11).arlen,
         S11_AXI_ARSIZE       => sAxiReadMasters(11).arsize,
         S11_AXI_ARBURST      => sAxiReadMasters(11).arburst,
         S11_AXI_ARLOCK       => sAxiReadMasters(11).arlock(0),
         S11_AXI_ARCACHE      => sAxiReadMasters(11).arcache,
         S11_AXI_ARPROT       => sAxiReadMasters(11).arprot,
         S11_AXI_ARQOS        => sAxiReadMasters(11).arqos,
         S11_AXI_ARVALID      => sAxiReadMasters(11).arvalid,
         S11_AXI_ARREADY      => sAxiReadSlaves(11).arready,
         S11_AXI_RID          => sAxiReadSlaves(11).rid(0 downto 0),
         S11_AXI_RDATA        => sAxiReadSlaves(11).rdata(127 downto 0),
         S11_AXI_RRESP        => sAxiReadSlaves(11).rresp,
         S11_AXI_RLAST        => sAxiReadSlaves(11).rlast,
         S11_AXI_RVALID       => sAxiReadSlaves(11).rvalid,
         S11_AXI_RREADY       => sAxiReadMasters(11).rready,
         -- SLAVE[12]
         S12_AXI_ARESET_OUT_N => open,
         S12_AXI_ACLK         => axiClk,
         S12_AXI_AWID(0)      => '0',
         S12_AXI_AWADDR       => sAxiWriteMasters(12).awaddr(31 downto 0),
         S12_AXI_AWLEN        => sAxiWriteMasters(12).awlen,
         S12_AXI_AWSIZE       => sAxiWriteMasters(12).awsize,
         S12_AXI_AWBURST      => sAxiWriteMasters(12).awburst,
         S12_AXI_AWLOCK       => sAxiWriteMasters(12).awlock(0),
         S12_AXI_AWCACHE      => sAxiWriteMasters(12).awcache,
         S12_AXI_AWPROT       => sAxiWriteMasters(12).awprot,
         S12_AXI_AWQOS        => sAxiWriteMasters(12).awqos,
         S12_AXI_AWVALID      => sAxiWriteMasters(12).awvalid,
         S12_AXI_AWREADY      => sAxiWriteSlaves(12).awready,
         S12_AXI_WDATA        => sAxiWriteMasters(12).wdata(127 downto 0),
         S12_AXI_WSTRB        => sAxiWriteMasters(12).wstrb(15 downto 0),
         S12_AXI_WLAST        => sAxiWriteMasters(12).wlast,
         S12_AXI_WVALID       => sAxiWriteMasters(12).wvalid,
         S12_AXI_WREADY       => sAxiWriteSlaves(12).wready,
         S12_AXI_BID          => sAxiWriteSlaves(12).bid(0 downto 0),
         S12_AXI_BRESP        => sAxiWriteSlaves(12).bresp,
         S12_AXI_BVALID       => sAxiWriteSlaves(12).bvalid,
         S12_AXI_BREADY       => sAxiWriteMasters(12).bready,
         S12_AXI_ARID(0)      => '0',
         S12_AXI_ARADDR       => sAxiReadMasters(12).araddr(31 downto 0),
         S12_AXI_ARLEN        => sAxiReadMasters(12).arlen,
         S12_AXI_ARSIZE       => sAxiReadMasters(12).arsize,
         S12_AXI_ARBURST      => sAxiReadMasters(12).arburst,
         S12_AXI_ARLOCK       => sAxiReadMasters(12).arlock(0),
         S12_AXI_ARCACHE      => sAxiReadMasters(12).arcache,
         S12_AXI_ARPROT       => sAxiReadMasters(12).arprot,
         S12_AXI_ARQOS        => sAxiReadMasters(12).arqos,
         S12_AXI_ARVALID      => sAxiReadMasters(12).arvalid,
         S12_AXI_ARREADY      => sAxiReadSlaves(12).arready,
         S12_AXI_RID          => sAxiReadSlaves(12).rid(0 downto 0),
         S12_AXI_RDATA        => sAxiReadSlaves(12).rdata(127 downto 0),
         S12_AXI_RRESP        => sAxiReadSlaves(12).rresp,
         S12_AXI_RLAST        => sAxiReadSlaves(12).rlast,
         S12_AXI_RVALID       => sAxiReadSlaves(12).rvalid,
         S12_AXI_RREADY       => sAxiReadMasters(12).rready,
         -- SLAVE[13]
         S13_AXI_ARESET_OUT_N => open,
         S13_AXI_ACLK         => axiClk,
         S13_AXI_AWID(0)      => '0',
         S13_AXI_AWADDR       => sAxiWriteMasters(13).awaddr(31 downto 0),
         S13_AXI_AWLEN        => sAxiWriteMasters(13).awlen,
         S13_AXI_AWSIZE       => sAxiWriteMasters(13).awsize,
         S13_AXI_AWBURST      => sAxiWriteMasters(13).awburst,
         S13_AXI_AWLOCK       => sAxiWriteMasters(13).awlock(0),
         S13_AXI_AWCACHE      => sAxiWriteMasters(13).awcache,
         S13_AXI_AWPROT       => sAxiWriteMasters(13).awprot,
         S13_AXI_AWQOS        => sAxiWriteMasters(13).awqos,
         S13_AXI_AWVALID      => sAxiWriteMasters(13).awvalid,
         S13_AXI_AWREADY      => sAxiWriteSlaves(13).awready,
         S13_AXI_WDATA        => sAxiWriteMasters(13).wdata(127 downto 0),
         S13_AXI_WSTRB        => sAxiWriteMasters(13).wstrb(15 downto 0),
         S13_AXI_WLAST        => sAxiWriteMasters(13).wlast,
         S13_AXI_WVALID       => sAxiWriteMasters(13).wvalid,
         S13_AXI_WREADY       => sAxiWriteSlaves(13).wready,
         S13_AXI_BID          => sAxiWriteSlaves(13).bid(0 downto 0),
         S13_AXI_BRESP        => sAxiWriteSlaves(13).bresp,
         S13_AXI_BVALID       => sAxiWriteSlaves(13).bvalid,
         S13_AXI_BREADY       => sAxiWriteMasters(13).bready,
         S13_AXI_ARID(0)      => '0',
         S13_AXI_ARADDR       => sAxiReadMasters(13).araddr(31 downto 0),
         S13_AXI_ARLEN        => sAxiReadMasters(13).arlen,
         S13_AXI_ARSIZE       => sAxiReadMasters(13).arsize,
         S13_AXI_ARBURST      => sAxiReadMasters(13).arburst,
         S13_AXI_ARLOCK       => sAxiReadMasters(13).arlock(0),
         S13_AXI_ARCACHE      => sAxiReadMasters(13).arcache,
         S13_AXI_ARPROT       => sAxiReadMasters(13).arprot,
         S13_AXI_ARQOS        => sAxiReadMasters(13).arqos,
         S13_AXI_ARVALID      => sAxiReadMasters(13).arvalid,
         S13_AXI_ARREADY      => sAxiReadSlaves(13).arready,
         S13_AXI_RID          => sAxiReadSlaves(13).rid(0 downto 0),
         S13_AXI_RDATA        => sAxiReadSlaves(13).rdata(127 downto 0),
         S13_AXI_RRESP        => sAxiReadSlaves(13).rresp,
         S13_AXI_RLAST        => sAxiReadSlaves(13).rlast,
         S13_AXI_RVALID       => sAxiReadSlaves(13).rvalid,
         S13_AXI_RREADY       => sAxiReadMasters(13).rready,
         -- SLAVE[14]
         S14_AXI_ARESET_OUT_N => open,
         S14_AXI_ACLK         => axiClk,
         S14_AXI_AWID(0)      => '0',
         S14_AXI_AWADDR       => sAxiWriteMasters(14).awaddr(31 downto 0),
         S14_AXI_AWLEN        => sAxiWriteMasters(14).awlen,
         S14_AXI_AWSIZE       => sAxiWriteMasters(14).awsize,
         S14_AXI_AWBURST      => sAxiWriteMasters(14).awburst,
         S14_AXI_AWLOCK       => sAxiWriteMasters(14).awlock(0),
         S14_AXI_AWCACHE      => sAxiWriteMasters(14).awcache,
         S14_AXI_AWPROT       => sAxiWriteMasters(14).awprot,
         S14_AXI_AWQOS        => sAxiWriteMasters(14).awqos,
         S14_AXI_AWVALID      => sAxiWriteMasters(14).awvalid,
         S14_AXI_AWREADY      => sAxiWriteSlaves(14).awready,
         S14_AXI_WDATA        => sAxiWriteMasters(14).wdata(127 downto 0),
         S14_AXI_WSTRB        => sAxiWriteMasters(14).wstrb(15 downto 0),
         S14_AXI_WLAST        => sAxiWriteMasters(14).wlast,
         S14_AXI_WVALID       => sAxiWriteMasters(14).wvalid,
         S14_AXI_WREADY       => sAxiWriteSlaves(14).wready,
         S14_AXI_BID          => sAxiWriteSlaves(14).bid(0 downto 0),
         S14_AXI_BRESP        => sAxiWriteSlaves(14).bresp,
         S14_AXI_BVALID       => sAxiWriteSlaves(14).bvalid,
         S14_AXI_BREADY       => sAxiWriteMasters(14).bready,
         S14_AXI_ARID(0)      => '0',
         S14_AXI_ARADDR       => sAxiReadMasters(14).araddr(31 downto 0),
         S14_AXI_ARLEN        => sAxiReadMasters(14).arlen,
         S14_AXI_ARSIZE       => sAxiReadMasters(14).arsize,
         S14_AXI_ARBURST      => sAxiReadMasters(14).arburst,
         S14_AXI_ARLOCK       => sAxiReadMasters(14).arlock(0),
         S14_AXI_ARCACHE      => sAxiReadMasters(14).arcache,
         S14_AXI_ARPROT       => sAxiReadMasters(14).arprot,
         S14_AXI_ARQOS        => sAxiReadMasters(14).arqos,
         S14_AXI_ARVALID      => sAxiReadMasters(14).arvalid,
         S14_AXI_ARREADY      => sAxiReadSlaves(14).arready,
         S14_AXI_RID          => sAxiReadSlaves(14).rid(0 downto 0),
         S14_AXI_RDATA        => sAxiReadSlaves(14).rdata(127 downto 0),
         S14_AXI_RRESP        => sAxiReadSlaves(14).rresp,
         S14_AXI_RLAST        => sAxiReadSlaves(14).rlast,
         S14_AXI_RVALID       => sAxiReadSlaves(14).rvalid,
         S14_AXI_RREADY       => sAxiReadMasters(14).rready,
         -- SLAVE[15]
         S15_AXI_ARESET_OUT_N => open,
         S15_AXI_ACLK         => axiClk,
         S15_AXI_AWID(0)      => '0',
         S15_AXI_AWADDR       => sAxiWriteMasters(15).awaddr(31 downto 0),
         S15_AXI_AWLEN        => sAxiWriteMasters(15).awlen,
         S15_AXI_AWSIZE       => sAxiWriteMasters(15).awsize,
         S15_AXI_AWBURST      => sAxiWriteMasters(15).awburst,
         S15_AXI_AWLOCK       => sAxiWriteMasters(15).awlock(0),
         S15_AXI_AWCACHE      => sAxiWriteMasters(15).awcache,
         S15_AXI_AWPROT       => sAxiWriteMasters(15).awprot,
         S15_AXI_AWQOS        => sAxiWriteMasters(15).awqos,
         S15_AXI_AWVALID      => sAxiWriteMasters(15).awvalid,
         S15_AXI_AWREADY      => sAxiWriteSlaves(15).awready,
         S15_AXI_WDATA        => sAxiWriteMasters(15).wdata(127 downto 0),
         S15_AXI_WSTRB        => sAxiWriteMasters(15).wstrb(15 downto 0),
         S15_AXI_WLAST        => sAxiWriteMasters(15).wlast,
         S15_AXI_WVALID       => sAxiWriteMasters(15).wvalid,
         S15_AXI_WREADY       => sAxiWriteSlaves(15).wready,
         S15_AXI_BID          => sAxiWriteSlaves(15).bid(0 downto 0),
         S15_AXI_BRESP        => sAxiWriteSlaves(15).bresp,
         S15_AXI_BVALID       => sAxiWriteSlaves(15).bvalid,
         S15_AXI_BREADY       => sAxiWriteMasters(15).bready,
         S15_AXI_ARID(0)      => '0',
         S15_AXI_ARADDR       => sAxiReadMasters(15).araddr(31 downto 0),
         S15_AXI_ARLEN        => sAxiReadMasters(15).arlen,
         S15_AXI_ARSIZE       => sAxiReadMasters(15).arsize,
         S15_AXI_ARBURST      => sAxiReadMasters(15).arburst,
         S15_AXI_ARLOCK       => sAxiReadMasters(15).arlock(0),
         S15_AXI_ARCACHE      => sAxiReadMasters(15).arcache,
         S15_AXI_ARPROT       => sAxiReadMasters(15).arprot,
         S15_AXI_ARQOS        => sAxiReadMasters(15).arqos,
         S15_AXI_ARVALID      => sAxiReadMasters(15).arvalid,
         S15_AXI_ARREADY      => sAxiReadSlaves(15).arready,
         S15_AXI_RID          => sAxiReadSlaves(15).rid(0 downto 0),
         S15_AXI_RDATA        => sAxiReadSlaves(15).rdata(127 downto 0),
         S15_AXI_RRESP        => sAxiReadSlaves(15).rresp,
         S15_AXI_RLAST        => sAxiReadSlaves(15).rlast,
         S15_AXI_RVALID       => sAxiReadSlaves(15).rvalid,
         S15_AXI_RREADY       => sAxiReadMasters(15).rready,
         -- MASTER         
         M00_AXI_ARESET_OUT_N => open,
         M00_AXI_ACLK         => axiClk,
         M00_AXI_AWID         => mAxiWriteMaster.awid(3 downto 0),
         M00_AXI_AWADDR       => mAxiWriteMaster.awaddr(31 downto 0),
         M00_AXI_AWLEN        => mAxiWriteMaster.awlen,
         M00_AXI_AWSIZE       => mAxiWriteMaster.awsize,
         M00_AXI_AWBURST      => mAxiWriteMaster.awburst,
         M00_AXI_AWLOCK       => mAxiWriteMaster.awlock(0),
         M00_AXI_AWCACHE      => mAxiWriteMaster.awcache,
         M00_AXI_AWPROT       => mAxiWriteMaster.awprot,
         M00_AXI_AWQOS        => mAxiWriteMaster.awqos,
         M00_AXI_AWVALID      => mAxiWriteMaster.awvalid,
         M00_AXI_AWREADY      => mAxiWriteSlave.awready,
         M00_AXI_WDATA        => mAxiWriteMaster.wdata(255 downto 0),
         M00_AXI_WSTRB        => mAxiWriteMaster.wstrb(31 downto 0),
         M00_AXI_WLAST        => mAxiWriteMaster.wlast,
         M00_AXI_WVALID       => mAxiWriteMaster.wvalid,
         M00_AXI_WREADY       => mAxiWriteSlave.wready,
         M00_AXI_BID          => mAxiWriteSlave.bid(3 downto 0),
         M00_AXI_BRESP        => mAxiWriteSlave.bresp,
         M00_AXI_BVALID       => mAxiWriteSlave.bvalid,
         M00_AXI_BREADY       => mAxiWriteMaster.bready,
         M00_AXI_ARID         => mAxiReadMaster.arid(3 downto 0),
         M00_AXI_ARADDR       => mAxiReadMaster.araddr(31 downto 0),
         M00_AXI_ARLEN        => mAxiReadMaster.arlen,
         M00_AXI_ARSIZE       => mAxiReadMaster.arsize,
         M00_AXI_ARBURST      => mAxiReadMaster.arburst,
         M00_AXI_ARLOCK       => mAxiReadMaster.arlock(0),
         M00_AXI_ARCACHE      => mAxiReadMaster.arcache,
         M00_AXI_ARPROT       => mAxiReadMaster.arprot,
         M00_AXI_ARQOS        => mAxiReadMaster.arqos,
         M00_AXI_ARVALID      => mAxiReadMaster.arvalid,
         M00_AXI_ARREADY      => mAxiReadSlave.arready,
         M00_AXI_RID          => mAxiReadSlave.rid(3 downto 0),
         M00_AXI_RDATA        => mAxiReadSlave.rdata(255 downto 0),
         M00_AXI_RRESP        => mAxiReadSlave.rresp,
         M00_AXI_RLAST        => mAxiReadSlave.rlast,
         M00_AXI_RVALID       => mAxiReadSlave.rvalid,
         M00_AXI_RREADY       => mAxiReadMaster.rready);

end mapping;
