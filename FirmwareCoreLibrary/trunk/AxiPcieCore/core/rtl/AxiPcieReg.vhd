-------------------------------------------------------------------------------
-- Title      : AXI PCIe Core
-------------------------------------------------------------------------------
-- File       : AxiPcieReg.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-02-12
-- Last update: 2016-09-06
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
use work.AxiMicronP30Pkg.all;

entity AxiPcieReg is
   generic (
      TPD_G            : time                   := 1 ns;
      DRIVER_TYPE_ID_G : slv(31 downto 0)       := x"00000000";
      AXI_APP_BUS_EN_G : boolean                := false;
      AXI_CLK_FREQ_G   : real                   := 125.0E+6;   -- units of Hz
      AXI_ERROR_RESP_G : slv(1 downto 0)        := AXI_RESP_OK_C;
      XIL_DEVICE_G     : string                 := "7SERIES";  -- Either "7SERIES" or "ULTRASCALE"
      DMA_SIZE_G       : positive range 1 to 16 := 1);
   port (
      -- AXI4 Interfaces
      axiClk             : in  sl;
      axiRst             : in  sl;
      regReadMaster      : in  AxiReadMasterType;
      regReadSlave       : out AxiReadSlaveType;
      regWriteMaster     : in  AxiWriteMasterType;
      regWriteSlave      : out AxiWriteSlaveType;
      -- DMA AXI-Lite Interfaces [0x00020000:0x0002FFFF]
      dmaCtrlReadMaster  : out AxiLiteReadMasterType;
      dmaCtrlReadSlave   : in  AxiLiteReadSlaveType;
      dmaCtrlWriteMaster : out AxiLiteWriteMasterType;
      dmaCtrlWriteSlave  : in  AxiLiteWriteSlaveType;
      -- PHY AXI-Lite Interfaces [0x00030000:0x0003FFFF]
      phyReadMaster      : out AxiLiteReadMasterType;
      phyReadSlave       : in  AxiLiteReadSlaveType;
      phyWriteMaster     : out AxiLiteWriteMasterType;
      phyWriteSlave      : in  AxiLiteWriteSlaveType;
      -- (Optional) Application AXI-Lite Interfaces [0x00080000:0x000FFFFF]
      appReadMaster      : out AxiLiteReadMasterType;
      appReadSlave       : in  AxiLiteReadSlaveType  := AXI_LITE_READ_SLAVE_INIT_C;
      appWriteMaster     : out AxiLiteWriteMasterType;
      appWriteSlave      : in  AxiLiteWriteSlaveType := AXI_LITE_WRITE_SLAVE_INIT_C;
      -- Interrupts
      interrupt          : in  slv(DMA_SIZE_G-1 downto 0);
      -- Boot Memory Ports 
      flashAddr          : out slv(28 downto 0);
      flashCe            : out sl;
      flashOe            : out sl;
      flashWe            : out sl;
      flashTri           : out sl;
      flashDin           : out slv(15 downto 0);
      flashDout          : in  slv(15 downto 0));
end AxiPcieReg;

architecture mapping of AxiPcieReg is

   constant NUM_AXI_MASTERS_C : natural := 5;

   constant VERSION_INDEX_C : natural := 0;
   constant BOOT_INDEX_C    : natural := 1;
   constant DMA_INDEX_C     : natural := 2;
   constant PHY_INDEX_C     : natural := 3;
   constant APP_INDEX_C     : natural := 4;

   constant VERSION_ADDR_C : slv(31 downto 0) := x"00000000";
   constant BOOT_ADDR_C    : slv(31 downto 0) := x"00010000";
   constant DMA_ADDR_C     : slv(31 downto 0) := x"00020000";
   constant PHY_ADDR_C     : slv(31 downto 0) := x"00030000";
   constant APP_ADDR_C     : slv(31 downto 0) := x"00080000";
   
   constant AXI_CROSSBAR_MASTERS_CONFIG_C : AxiLiteCrossbarMasterConfigArray(NUM_AXI_MASTERS_C-1 downto 0) := (
      VERSION_INDEX_C => (
         baseAddr     => VERSION_ADDR_C,
         addrBits     => 16,
         connectivity => x"FFFF"),
      BOOT_INDEX_C    => (
         baseAddr     => BOOT_ADDR_C,
         addrBits     => 16,
         connectivity => x"FFFF"),
      DMA_INDEX_C     => (
         baseAddr     => DMA_ADDR_C,
         addrBits     => 16,
         connectivity => x"FFFF"),
      PHY_INDEX_C     => (
         baseAddr     => PHY_ADDR_C,
         addrBits     => 16,
         connectivity => x"FFFF"),
      APP_INDEX_C     => (
         baseAddr     => APP_ADDR_C,
         addrBits     => 19,
         connectivity => x"FFFF"));          

   signal axilReadMaster  : AxiLiteReadMasterType;
   signal maskReadMaster  : AxiLiteReadMasterType;
   signal axilReadSlave   : AxiLiteReadSlaveType;
   signal axilWriteMaster : AxiLiteWriteMasterType;
   signal maskWriteMaster : AxiLiteWriteMasterType;
   signal axilWriteSlave  : AxiLiteWriteSlaveType;

   signal axilReadMasters  : AxiLiteReadMasterArray(NUM_AXI_MASTERS_C-1 downto 0);
   signal axilReadSlaves   : AxiLiteReadSlaveArray(NUM_AXI_MASTERS_C-1 downto 0);
   signal axilWriteMasters : AxiLiteWriteMasterArray(NUM_AXI_MASTERS_C-1 downto 0);
   signal axilWriteSlaves  : AxiLiteWriteSlaveArray(NUM_AXI_MASTERS_C-1 downto 0);

   signal userValues   : Slv32Array(63 downto 0) := (others => x"00000000");
   signal flashAddress : slv(30 downto 0);
   
begin

   ---------------------------------------------------------------------------------------------
   -- Driver Polls the userValues to determine the firmware's configurations and interrupt state
   ---------------------------------------------------------------------------------------------
   userValues(0)(DMA_SIZE_G-1 downto 0) <= interrupt;
   userValues(1)                        <= toSlv(DMA_SIZE_G, 32);
   userValues(2)                        <= x"00000001" when(AXI_APP_BUS_EN_G)         else x"00000000";
   userValues(3)                        <= DRIVER_TYPE_ID_G;
   userValues(62)                       <= x"00000001" when(XIL_DEVICE_G = "7SERIES") else x"00000000";
   userValues(63)                       <= toSlv(getTimeRatio(AXI_CLK_FREQ_G, 1.0), 32);

   -------------------------          
   -- AXI-to-AXI-Lite Bridge
   -------------------------          
   U_AxiToAxiLite : entity work.AxiToAxiLite
      generic map (
         TPD_G => TPD_G)
      port map (
         axiClk          => axiClk,
         axiClkRst       => axiRst,
         axiReadMaster   => regReadMaster,
         axiReadSlave    => regReadSlave,
         axiWriteMaster  => regWriteMaster,
         axiWriteSlave   => regWriteSlave,
         axilReadMaster  => axilReadMaster,
         axilReadSlave   => axilReadSlave,
         axilWriteMaster => axilWriteMaster,
         axilWriteSlave  => axilWriteSlave); 

   ---------------------------------------
   -- Mask off upper address for 1 MB BAR0
   ---------------------------------------
   maskWriteMaster.awaddr  <= x"000" & axilWriteMaster.awaddr(19 downto 0);
   maskWriteMaster.awprot  <= axilWriteMaster.awprot;
   maskWriteMaster.awvalid <= axilWriteMaster.awvalid;
   maskWriteMaster.wdata   <= axilWriteMaster.wdata;
   maskWriteMaster.wstrb   <= axilWriteMaster.wstrb;
   maskWriteMaster.wvalid  <= axilWriteMaster.wvalid;
   maskWriteMaster.bready  <= axilWriteMaster.bready;
   maskReadMaster.araddr   <= x"000" & axilReadMaster.araddr(19 downto 0);
   maskReadMaster.arprot   <= axilReadMaster.arprot;
   maskReadMaster.arvalid  <= axilReadMaster.arvalid;
   maskReadMaster.rready   <= axilReadMaster.rready;

   --------------------
   -- AXI-Lite Crossbar
   --------------------
   U_XBAR : entity work.AxiLiteCrossbar
      generic map (
         TPD_G              => TPD_G,
         DEC_ERROR_RESP_G   => AXI_ERROR_RESP_G,
         NUM_SLAVE_SLOTS_G  => 1,
         NUM_MASTER_SLOTS_G => NUM_AXI_MASTERS_C,
         MASTERS_CONFIG_G   => AXI_CROSSBAR_MASTERS_CONFIG_C)
      port map (
         axiClk              => axiClk,
         axiClkRst           => axiRst,
         sAxiWriteMasters(0) => maskWriteMaster,
         sAxiWriteSlaves(0)  => axilWriteSlave,
         sAxiReadMasters(0)  => maskReadMaster,
         sAxiReadSlaves(0)   => axilReadSlave,
         mAxiWriteMasters    => axilWriteMasters,
         mAxiWriteSlaves     => axilWriteSlaves,
         mAxiReadMasters     => axilReadMasters,
         mAxiReadSlaves      => axilReadSlaves);         

   --------------------------
   -- AXI-Lite Version Module
   --------------------------   
   U_Version : entity work.AxiVersion
      generic map (
         TPD_G            => TPD_G,
         AXI_ERROR_RESP_G => AXI_ERROR_RESP_G,
         EN_DEVICE_DNA_G  => true,
         XIL_DEVICE_G     => XIL_DEVICE_G)
      port map (
         -- AXI-Lite Interface
         axiClk         => axiClk,
         axiRst         => axiRst,
         axiReadMaster  => axilReadMasters(VERSION_INDEX_C),
         axiReadSlave   => axilReadSlaves(VERSION_INDEX_C),
         axiWriteMaster => axilWriteMasters(VERSION_INDEX_C),
         axiWriteSlave  => axilWriteSlaves(VERSION_INDEX_C),
         -- Optional: user values
         userValues     => userValues);

   -----------------------------         
   -- AXI-Lite Boot Flash Module
   -----------------------------         
   U_AxiMicronP30 : entity work.AxiMicronP30Reg
      generic map (
         TPD_G            => TPD_G,
         AXI_ERROR_RESP_G => AXI_ERROR_RESP_G,
         AXI_CLK_FREQ_G   => AXI_CLK_FREQ_G)
      port map (
         -- FLASH Interface 
         flashAddr      => flashAddress,
         flashCeL       => flashCe,
         flashOeL       => flashOe,
         flashWeL       => flashWe,
         flashDin       => flashDin,
         flashDout      => flashDout,
         flashTri       => flashTri,
         -- AXI-Lite Register Interface
         axiReadMaster  => axilReadMasters(BOOT_INDEX_C),
         axiReadSlave   => axilReadSlaves(BOOT_INDEX_C),
         axiWriteMaster => axilWriteMasters(BOOT_INDEX_C),
         axiWriteSlave  => axilWriteSlaves(BOOT_INDEX_C),
         -- Clocks and Resets
         axiClk         => axiClk,
         axiRst         => axiRst);  

   flashAddr <= flashAddress(28 downto 0);

   ---------------------------------
   -- Map the AXI-Lite to DMA Engine
   ---------------------------------
   dmaCtrlWriteMaster           <= axilWriteMasters(DMA_INDEX_C);
   axilWriteSlaves(DMA_INDEX_C) <= dmaCtrlWriteSlave;
   dmaCtrlReadMaster            <= axilReadMasters(DMA_INDEX_C);
   axilReadSlaves(DMA_INDEX_C)  <= dmaCtrlReadSlave;

   -------------------------------
   -- Map the AXI-Lite to PCIe PHY
   -------------------------------
   phyWriteMaster               <= axilWriteMasters(PHY_INDEX_C);
   axilWriteSlaves(PHY_INDEX_C) <= phyWriteSlave;
   phyReadMaster                <= axilReadMasters(PHY_INDEX_C);
   axilReadSlaves(PHY_INDEX_C)  <= phyReadSlave;

   ----------------------------------
   -- Map the AXI-Lite to Application
   ----------------------------------   
   BYPASS_APP : if (AXI_APP_BUS_EN_G = false) generate
      
      appReadMaster  <= AXI_LITE_READ_MASTER_INIT_C;
      appWriteMaster <= AXI_LITE_WRITE_MASTER_INIT_C;

      U_AxiLiteEmpty : entity work.AxiLiteEmpty
         generic map (
            TPD_G            => TPD_G,
            AXI_ERROR_RESP_G => AXI_ERROR_RESP_G)
         port map (
            -- AXI-Lite Interface
            axiClk         => axiClk,
            axiClkRst      => axiRst,
            axiReadMaster  => axilReadMasters(APP_INDEX_C),
            axiReadSlave   => axilReadSlaves(APP_INDEX_C),
            axiWriteMaster => axilWriteMasters(APP_INDEX_C),
            axiWriteSlave  => axilWriteSlaves(APP_INDEX_C));   
   end generate;

   GEN_APP : if (AXI_APP_BUS_EN_G = true) generate
      appWriteMaster               <= axilWriteMasters(APP_INDEX_C);
      axilWriteSlaves(APP_INDEX_C) <= appWriteSlave;
      appReadMaster                <= axilReadMasters(APP_INDEX_C);
      axilReadSlaves(APP_INDEX_C)  <= appReadSlave;
   end generate;
   
end mapping;
