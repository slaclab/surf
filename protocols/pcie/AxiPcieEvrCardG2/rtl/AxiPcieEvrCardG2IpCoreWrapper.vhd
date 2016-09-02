-------------------------------------------------------------------------------
-- Title      : EvrCardG2 Wrapper for AXI PCIe Core
-------------------------------------------------------------------------------
-- File       : AxiPcieEvrCardG2IpCoreWrapper.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-02-12
-- Last update: 2016-02-12
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
use work.AxiLitePkg.all;

library unisim;
use unisim.vcomponents.all;

entity AxiPcieEvrCardG2IpCoreWrapper is
   generic (
      TPD_G : time := 1 ns);
   port (
      -- AXI4 Interfaces
      axiClk         : out sl;
      axiRst         : out sl;
      dmaReadMaster  : in  AxiReadMasterType;
      dmaReadSlave   : out AxiReadSlaveType;
      dmaWriteMaster : in  AxiWriteMasterType;
      dmaWriteSlave  : out AxiWriteSlaveType;
      regReadMaster  : out AxiReadMasterType;
      regReadSlave   : in  AxiReadSlaveType;
      regWriteMaster : out AxiWriteMasterType;
      regWriteSlave  : in  AxiWriteSlaveType;
      phyReadMaster  : in  AxiLiteReadMasterType;
      phyReadSlave   : out AxiLiteReadSlaveType;
      phyWriteMaster : in  AxiLiteWriteMasterType;
      phyWriteSlave  : out AxiLiteWriteSlaveType;
      -- Interrupt Interface
      dmaIrq         : in  sl;
      -- PCIe Ports 
      pciRstL        : in  sl;
      pciRefClkP     : in  sl;
      pciRefClkN     : in  sl;
      pciRxP         : in  slv(3 downto 0);
      pciRxN         : in  slv(3 downto 0);
      pciTxP         : out slv(3 downto 0);
      pciTxN         : out slv(3 downto 0));  
end AxiPcieEvrCardG2IpCoreWrapper;

architecture mapping of AxiPcieEvrCardG2IpCoreWrapper is

   component AxiPcieEvrCardG2IpCore
      port (
         axi_aresetn       : in  std_logic;
         axi_aclk_out      : out std_logic;
         axi_ctl_aclk_out  : out std_logic;
         mmcm_lock         : out std_logic;
         interrupt_out     : out std_logic;
         INTX_MSI_Request  : in  std_logic;
         INTX_MSI_Grant    : out std_logic;
         MSI_enable        : out std_logic;
         MSI_Vector_Num    : in  std_logic_vector(4 downto 0);
         MSI_Vector_Width  : out std_logic_vector(2 downto 0);
         s_axi_awid        : in  std_logic_vector(3 downto 0);
         s_axi_awaddr      : in  std_logic_vector(31 downto 0);
         s_axi_awregion    : in  std_logic_vector(3 downto 0);
         s_axi_awlen       : in  std_logic_vector(7 downto 0);
         s_axi_awsize      : in  std_logic_vector(2 downto 0);
         s_axi_awburst     : in  std_logic_vector(1 downto 0);
         s_axi_awvalid     : in  std_logic;
         s_axi_awready     : out std_logic;
         s_axi_wdata       : in  std_logic_vector(127 downto 0);
         s_axi_wstrb       : in  std_logic_vector(15 downto 0);
         s_axi_wlast       : in  std_logic;
         s_axi_wvalid      : in  std_logic;
         s_axi_wready      : out std_logic;
         s_axi_bid         : out std_logic_vector(3 downto 0);
         s_axi_bresp       : out std_logic_vector(1 downto 0);
         s_axi_bvalid      : out std_logic;
         s_axi_bready      : in  std_logic;
         s_axi_arid        : in  std_logic_vector(3 downto 0);
         s_axi_araddr      : in  std_logic_vector(31 downto 0);
         s_axi_arregion    : in  std_logic_vector(3 downto 0);
         s_axi_arlen       : in  std_logic_vector(7 downto 0);
         s_axi_arsize      : in  std_logic_vector(2 downto 0);
         s_axi_arburst     : in  std_logic_vector(1 downto 0);
         s_axi_arvalid     : in  std_logic;
         s_axi_arready     : out std_logic;
         s_axi_rid         : out std_logic_vector(3 downto 0);
         s_axi_rdata       : out std_logic_vector(127 downto 0);
         s_axi_rresp       : out std_logic_vector(1 downto 0);
         s_axi_rlast       : out std_logic;
         s_axi_rvalid      : out std_logic;
         s_axi_rready      : in  std_logic;
         m_axi_awaddr      : out std_logic_vector(31 downto 0);
         m_axi_awlen       : out std_logic_vector(7 downto 0);
         m_axi_awsize      : out std_logic_vector(2 downto 0);
         m_axi_awburst     : out std_logic_vector(1 downto 0);
         m_axi_awprot      : out std_logic_vector(2 downto 0);
         m_axi_awvalid     : out std_logic;
         m_axi_awready     : in  std_logic;
         m_axi_awlock      : out std_logic;
         m_axi_awcache     : out std_logic_vector(3 downto 0);
         m_axi_wdata       : out std_logic_vector(127 downto 0);
         m_axi_wstrb       : out std_logic_vector(15 downto 0);
         m_axi_wlast       : out std_logic;
         m_axi_wvalid      : out std_logic;
         m_axi_wready      : in  std_logic;
         m_axi_bresp       : in  std_logic_vector(1 downto 0);
         m_axi_bvalid      : in  std_logic;
         m_axi_bready      : out std_logic;
         m_axi_araddr      : out std_logic_vector(31 downto 0);
         m_axi_arlen       : out std_logic_vector(7 downto 0);
         m_axi_arsize      : out std_logic_vector(2 downto 0);
         m_axi_arburst     : out std_logic_vector(1 downto 0);
         m_axi_arprot      : out std_logic_vector(2 downto 0);
         m_axi_arvalid     : out std_logic;
         m_axi_arready     : in  std_logic;
         m_axi_arlock      : out std_logic;
         m_axi_arcache     : out std_logic_vector(3 downto 0);
         m_axi_rdata       : in  std_logic_vector(127 downto 0);
         m_axi_rresp       : in  std_logic_vector(1 downto 0);
         m_axi_rlast       : in  std_logic;
         m_axi_rvalid      : in  std_logic;
         m_axi_rready      : out std_logic;
         pci_exp_txp       : out std_logic_vector(3 downto 0);
         pci_exp_txn       : out std_logic_vector(3 downto 0);
         pci_exp_rxp       : in  std_logic_vector(3 downto 0);
         pci_exp_rxn       : in  std_logic_vector(3 downto 0);
         REFCLK            : in  std_logic;
         s_axi_ctl_awaddr  : in  std_logic_vector(31 downto 0);
         s_axi_ctl_awvalid : in  std_logic;
         s_axi_ctl_awready : out std_logic;
         s_axi_ctl_wdata   : in  std_logic_vector(31 downto 0);
         s_axi_ctl_wstrb   : in  std_logic_vector(3 downto 0);
         s_axi_ctl_wvalid  : in  std_logic;
         s_axi_ctl_wready  : out std_logic;
         s_axi_ctl_bresp   : out std_logic_vector(1 downto 0);
         s_axi_ctl_bvalid  : out std_logic;
         s_axi_ctl_bready  : in  std_logic;
         s_axi_ctl_araddr  : in  std_logic_vector(31 downto 0);
         s_axi_ctl_arvalid : in  std_logic;
         s_axi_ctl_arready : out std_logic;
         s_axi_ctl_rdata   : out std_logic_vector(31 downto 0);
         s_axi_ctl_rresp   : out std_logic_vector(1 downto 0);
         s_axi_ctl_rvalid  : out std_logic;
         s_axi_ctl_rready  : in  std_logic);
   end component;

   signal sysReadMaster  : AxiLiteReadMasterType;
   signal sysReadSlave   : AxiLiteReadSlaveType;
   signal sysWriteMaster : AxiLiteWriteMasterType;
   signal sysWriteSlave  : AxiLiteWriteSlaveType;

   signal pciRefClk   : sl;
   signal pciRstLSync : sl;
   signal clk         : sl;
   signal rstL        : sl;
   signal rst         : sl;
   signal sysClk      : sl;
   signal sysRst      : sl;
   signal mmcmLock    : sl;
   
begin

   axiClk <= clk;
   axiRst <= rst;

   ------------------
   -- Clock and Reset
   ------------------
   U_IBUFDS_GTE2 : IBUFDS_GTE2
      port map(
         I     => pciRefClkP,
         IB    => pciRefClkN,
         CEB   => '0',
         O     => pciRefClk,
         ODIV2 => open);        

   U_RstSync0 : entity work.RstSync
      generic map (
         TPD_G          => TPD_G,
         IN_POLARITY_G  => '0',
         OUT_POLARITY_G => '0') 
      port map (
         clk      => clk,
         asyncRst => pciRstL,
         syncRst  => pciRstLSync);               

   process(clk)
   begin
      if rising_edge(clk) then
         rstL <= pciRstLSync and mmcmLock;
      end if;
   end process;

   rst <= not(rstL);

   U_RstSync1 : entity work.RstSync
      generic map (
         TPD_G          => TPD_G,
         IN_POLARITY_G  => '1',
         OUT_POLARITY_G => '1') 
      port map (
         clk      => sysClk,
         asyncRst => rst,
         syncRst  => sysRst);    

   ---------------------------------------- 
   -- Synchronize the AXI-Lite transactions
   ---------------------------------------- 
   U_AxiLiteAsync : entity work.AxiLiteAsync
      generic map (
         TPD_G => TPD_G)
      port map (
         -- Slave Port
         sAxiClk         => clk,
         sAxiClkRst      => rst,
         sAxiReadMaster  => phyReadMaster,
         sAxiReadSlave   => phyReadSlave,
         sAxiWriteMaster => phyWriteMaster,
         sAxiWriteSlave  => phyWriteSlave,
         -- Master Port
         mAxiClk         => sysClk,
         mAxiClkRst      => sysRst,
         mAxiReadMaster  => sysReadMaster,
         mAxiReadSlave   => sysReadSlave,
         mAxiWriteMaster => sysWriteMaster,
         mAxiWriteSlave  => sysWriteSlave); 

   -------------------
   -- AXI PCIe IP Core
   -------------------
   U_AxiPcie : AxiPcieEvrCardG2IpCore
      port map (
         -- Clocks and Resets
         axi_aresetn       => rstL,
         axi_aclk_out      => clk,
         axi_ctl_aclk_out  => sysClk,
         mmcm_lock         => mmcmLock,
         -- Interrupt Interface
         interrupt_out     => open,
         INTX_MSI_Request  => dmaIrq,
         INTX_MSI_Grant    => open,
         MSI_enable        => open,
         MSI_Vector_Num    => (others => '0'),
         MSI_Vector_Width  => open,
         -- Slave AXI4 Interface
         s_axi_awid        => dmaWriteMaster.awid(3 downto 0),
         s_axi_awaddr      => dmaWriteMaster.awaddr(31 downto 0),
         s_axi_awregion    => dmaWriteMaster.awregion,
         s_axi_awlen       => dmaWriteMaster.awlen(7 downto 0),
         s_axi_awsize      => dmaWriteMaster.awsize(2 downto 0),
         s_axi_awburst     => dmaWriteMaster.awburst(1 downto 0),
         s_axi_awvalid     => dmaWriteMaster.awvalid,
         s_axi_awready     => dmaWriteSlave.awready,
         s_axi_wdata       => dmaWriteMaster.wdata(127 downto 0),
         s_axi_wstrb       => dmaWriteMaster.wstrb(15 downto 0),
         s_axi_wlast       => dmaWriteMaster.wlast,
         s_axi_wvalid      => dmaWriteMaster.wvalid,
         s_axi_wready      => dmaWriteSlave.wready,
         s_axi_bid         => dmaWriteSlave.bid(3 downto 0),
         s_axi_bresp       => dmaWriteSlave.bresp(1 downto 0),
         s_axi_bvalid      => dmaWriteSlave.bvalid,
         s_axi_bready      => dmaWriteMaster.bready,
         s_axi_arid        => dmaReadMaster.arid(3 downto 0),
         s_axi_araddr      => dmaReadMaster.araddr(31 downto 0),
         s_axi_arregion    => dmaReadMaster.arregion,
         s_axi_arlen       => dmaReadMaster.arlen(7 downto 0),
         s_axi_arsize      => dmaReadMaster.arsize(2 downto 0),
         s_axi_arburst     => dmaReadMaster.arburst(1 downto 0),
         s_axi_arvalid     => dmaReadMaster.arvalid,
         s_axi_arready     => dmaReadSlave.arready,
         s_axi_rid         => dmaReadSlave.rid(3 downto 0),
         s_axi_rdata       => dmaReadSlave.rdata(127 downto 0),
         s_axi_rresp       => dmaReadSlave.rresp(1 downto 0),
         s_axi_rlast       => dmaReadSlave.rlast,
         s_axi_rvalid      => dmaReadSlave.rvalid,
         s_axi_rready      => dmaReadMaster.rready,
         -- Master AXI4 Interface
         m_axi_awaddr      => regWriteMaster.awaddr(31 downto 0),
         m_axi_awlen       => regWriteMaster.awlen(7 downto 0),
         m_axi_awsize      => regWriteMaster.awsize(2 downto 0),
         m_axi_awburst     => regWriteMaster.awburst(1 downto 0),
         m_axi_awprot      => regWriteMaster.awprot,
         m_axi_awvalid     => regWriteMaster.awvalid,
         m_axi_awready     => regWriteSlave.awready,
         m_axi_awlock      => regWriteMaster.awlock(0),
         m_axi_awcache     => regWriteMaster.awcache,
         m_axi_wdata       => regWriteMaster.wdata(127 downto 0),
         m_axi_wstrb       => regWriteMaster.wstrb(15 downto 0),
         m_axi_wlast       => regWriteMaster.wlast,
         m_axi_wvalid      => regWriteMaster.wvalid,
         m_axi_wready      => regWriteSlave.wready,
         m_axi_bresp       => regWriteSlave.bresp(1 downto 0),
         m_axi_bvalid      => regWriteSlave.bvalid,
         m_axi_bready      => regWriteMaster.bready,
         m_axi_araddr      => regReadMaster.araddr(31 downto 0),
         m_axi_arlen       => regReadMaster.arlen(7 downto 0),
         m_axi_arsize      => regReadMaster.arsize(2 downto 0),
         m_axi_arburst     => regReadMaster.arburst(1 downto 0),
         m_axi_arprot      => regReadMaster.arprot,
         m_axi_arvalid     => regReadMaster.arvalid,
         m_axi_arready     => regReadSlave.arready,
         m_axi_arlock      => regReadMaster.arlock(0),
         m_axi_arcache     => regReadMaster.arcache,
         m_axi_rdata       => regReadSlave.rdata(127 downto 0),
         m_axi_rresp       => regReadSlave.rresp(1 downto 0),
         m_axi_rlast       => regReadSlave.rlast,
         m_axi_rvalid      => regReadSlave.rvalid,
         m_axi_rready      => regReadMaster.rready,
         -- PCIe PHY Interface
         pci_exp_txp       => pciTxP,
         pci_exp_txn       => pciTxN,
         pci_exp_rxp       => pciRxP,
         pci_exp_rxn       => pciRxN,
         REFCLK            => pciRefClk,
         -- Slave AXI4-Lite Interface
         s_axi_ctl_awaddr  => sysWriteMaster.awaddr,
         s_axi_ctl_awvalid => sysWriteMaster.awvalid,
         s_axi_ctl_awready => sysWriteSlave.awready,
         s_axi_ctl_wdata   => sysWriteMaster.wdata,
         s_axi_ctl_wstrb   => sysWriteMaster.wstrb,
         s_axi_ctl_wvalid  => sysWriteMaster.wvalid,
         s_axi_ctl_wready  => sysWriteSlave.wready,
         s_axi_ctl_bresp   => sysWriteSlave.bresp,
         s_axi_ctl_bvalid  => sysWriteSlave.bvalid,
         s_axi_ctl_bready  => sysWriteMaster.bready,
         s_axi_ctl_araddr  => sysReadMaster.araddr,
         s_axi_ctl_arvalid => sysReadMaster.arvalid,
         s_axi_ctl_arready => sysReadSlave.arready,
         s_axi_ctl_rdata   => sysReadSlave.rdata,
         s_axi_ctl_rresp   => sysReadSlave.rresp,
         s_axi_ctl_rvalid  => sysReadSlave.rvalid,
         s_axi_ctl_rready  => sysReadMaster.rready);

end mapping;
