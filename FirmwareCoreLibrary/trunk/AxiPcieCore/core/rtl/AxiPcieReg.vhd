-------------------------------------------------------------------------------
-- Title      : AXI PCIe Core
-------------------------------------------------------------------------------
-- File       : AxiPcieReg.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-11-10
-- Last update: 2016-02-13
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2016 SLAC National Accelerator Laboratory
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
      AXI_CLK_FREQ_G   : real                   := 125.0E+6;   -- units of Hz
      AXI_ERROR_RESP_G : slv(1 downto 0)        := AXI_RESP_DECERR_C;
      XIL_DEVICE_G     : string                 := "7SERIES";  -- Either "7SERIES" or "ULTRASCALE"
      DMA_SIZE_G       : positive range 1 to 16 := 1);
   port (
      -- AXI4 Interfaces
      axiClk          : in  sl;
      axiRst          : in  sl;
      regReadMaster   : in  AxiReadMasterType;
      regReadSlave    : out AxiReadSlaveType;
      regWriteMaster  : in  AxiWriteMasterType;
      regWriteSlave   : out AxiWriteSlaveType;
      sysReadMasters  : out AxiLiteReadMasterArray(1 downto 0);
      sysReadSlaves   : in  AxiLiteReadSlaveArray(1 downto 0);
      sysWriteMasters : out AxiLiteWriteMasterArray(1 downto 0);
      sysWriteSlaves  : in  AxiLiteWriteSlaveArray(1 downto 0);
      -- Interrupts
      interrupt       : in  slv(DMA_SIZE_G-1 downto 0);
      -- Boot Memory Ports 
      flashAddr       : out slv(28 downto 0);
      flashCe         : out sl;
      flashOe         : out sl;
      flashWe         : out sl;
      flashTri        : out sl;
      flashDin        : out slv(15 downto 0);
      flashDout       : in  slv(15 downto 0));
end AxiPcieReg;

architecture mapping of AxiPcieReg is

   constant NUM_AXI_MASTERS_C : natural := 4;

   constant DMA_INDEX_C     : natural := 0;
   constant PHY_INDEX_C     : natural := 1;
   constant VERSION_INDEX_C : natural := 2;
   constant BOOT_INDEX_C    : natural := 3;

   constant DMA_ADDR_C     : slv(31 downto 0) := x"00000000";
   constant PHY_ADDR_C     : slv(31 downto 0) := x"00010000";
   constant VERSION_ADDR_C : slv(31 downto 0) := x"00020000";
   constant BOOT_ADDR_C    : slv(31 downto 0) := x"00030000";
   
   constant AXI_CROSSBAR_MASTERS_CONFIG_C : AxiLiteCrossbarMasterConfigArray(NUM_AXI_MASTERS_C-1 downto 0) := (
      DMA_INDEX_C     => (
         baseAddr     => DMA_ADDR_C,
         addrBits     => 16,
         connectivity => x"FFFF"),
      PHY_INDEX_C     => (
         baseAddr     => PHY_ADDR_C,
         addrBits     => 16,
         connectivity => x"FFFF"),
      VERSION_INDEX_C => (
         baseAddr     => VERSION_ADDR_C,
         addrBits     => 16,
         connectivity => x"FFFF"),
      BOOT_INDEX_C    => (
         baseAddr     => BOOT_ADDR_C,
         addrBits     => 16,
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

   signal userValues   : Slv32Array(0 to 63) := (others => x"00000000");
   signal flashAddress : slv(30 downto 0);
   
begin

   userValues(0)                        <= toSlv(DMA_SIZE_G, 32);
   userValues(1)(DMA_SIZE_G-1 downto 0) <= interrupt;

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

   ----------------------------------------------
   -- Map the AXI-Lite to DMA Engine and PCIe PHY
   ----------------------------------------------
   sysWriteMasters(1 downto 0) <= axilWriteMasters(1 downto 0);
   axilWriteSlaves(1 downto 0) <= sysWriteSlaves;
   sysReadMasters(1 downto 0)  <= axilReadMasters(1 downto 0);
   axilReadSlaves(1 downto 0)  <= sysReadSlaves;

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

end mapping;
