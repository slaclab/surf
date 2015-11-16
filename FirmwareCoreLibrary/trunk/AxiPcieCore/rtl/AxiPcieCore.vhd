-------------------------------------------------------------------------------
-- Title      : AXI PCIe Core
-------------------------------------------------------------------------------
-- File       : AxiPcieCore.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-04-22
-- Last update: 2015-11-16
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
--    AXI PCIe Core, Top Level
--
--    Supports up to 16x independent DMA channels
--
--    Supports the following Xilinx IP Core PCIe configurations:
--       1) Generation 1: x1, x2, x4 and x8 lanes
--       2) Generation 2: x1, x2, x4 and x8 lanes
--       3) Generation 3: x1, x2, x4 and x8 lanes
--
--    32-bit AXI-Lite interface to User Logic
--    128-bit AXI interface to User Logic
--    128-bit AXIS interface to Xilinx IP core.
--
---------------------------------------------------------------------------------
-- Note: For PCIe GEN3 8x lanes support, requires converting the 256-bit AXIS bus
--       to a 128-bit and doubling the local clock reference to prevent 
--       reduced performace
-------------------------------------------------------------------------------
-- Copyright (c) 2015 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;
use work.AxiPkg.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;
use work.AxiPciePkg.all;

entity AxiPcieCore is
   generic (
      TPD_G      : time                   := 1 ns;
      DMA_SIZE_G : positive range 1 to 16 := 1;
      BAR_SIZE_G : positive range 1 to 4  := 1;
      BAR_MASK_G : Slv32Array(3 downto 0) := (others => x"FFF00000"));  -- 1MB BAR mask by default
   port (
      -- System Interface
      irqEnable        : in  sl               := '0';
      irqReq           : in  sl               := '0';
      irqActive        : out sl;
      serialNumber     : in  slv(63 downto 0) := (others => '0');
      -- AXI-Lite Interface
      axilWriteMasters : out AxiLiteWriteMasterArray(BAR_SIZE_G-1 downto 0);
      axilWriteSlaves  : in  AxiLiteWriteSlaveArray(BAR_SIZE_G-1 downto 0);
      axilReadMasters  : out AxiLiteReadMasterArray(BAR_SIZE_G-1 downto 0);
      axilReadSlaves   : in  AxiLiteReadSlaveArray(BAR_SIZE_G-1 downto 0);
      -- AXI Interface
      axiReadMasters   : in  AxiReadMasterArray(DMA_SIZE_G-1 downto 0);
      axiReadSlaves    : out AxiReadSlaveArray(DMA_SIZE_G-1 downto 0);
      axiWriteMasters  : in  AxiWriteMasterArray(DMA_SIZE_G-1 downto 0);
      axiWriteSlaves   : out AxiWriteSlaveArray(DMA_SIZE_G-1 downto 0);
      -- PCIe Interface      
      cfgFromPci       : in  PcieCfgOutType;
      cfgToPci         : out PcieCfgInType;
      pciIbMaster      : out AxiStreamMasterType;
      pciIbSlave       : in  AxiStreamSlaveType;
      pciObMaster      : in  AxiStreamMasterType;
      pciObSlave       : out AxiStreamSlaveType;
      -- Clock and Resets
      pciClk           : in  sl;
      pciRst           : in  sl);
end AxiPcieCore;

architecture mapping of AxiPcieCore is

   signal regTranFromPci   : TranFromPcieType;
   signal regObMaster      : AxiStreamMasterType;
   signal regObSlave       : AxiStreamSlaveType;
   signal regIbMaster      : AxiStreamMasterType;
   signal regIbSlave       : AxiStreamSlaveType;
   signal dmaTxTranFromPci : TranFromPcieArray(DMA_SIZE_G-1 downto 0);
   signal dmaRxTranFromPci : TranFromPcieArray(DMA_SIZE_G-1 downto 0);
   signal dmaTxObMasters   : AxiStreamMasterArray(DMA_SIZE_G-1 downto 0);
   signal dmaTxObSlaves    : AxiStreamSlaveArray(DMA_SIZE_G-1 downto 0);
   signal dmaTxIbMasters   : AxiStreamMasterArray(DMA_SIZE_G-1 downto 0);
   signal dmaTxIbSlaves    : AxiStreamSlaveArray(DMA_SIZE_G-1 downto 0);
   signal dmaRxIbMasters   : AxiStreamMasterArray(DMA_SIZE_G-1 downto 0);
   signal dmaRxIbSlaves    : AxiStreamSlaveArray(DMA_SIZE_G-1 downto 0);
   
begin

   cfgToPci.serialNumber <= serialNumber;

   -----------------
   -- TLP Controller
   -----------------
   U_TlpCtrl : entity work.AxiPcieTlpCtrl
      generic map (
         TPD_G      => TPD_G,
         DMA_SIZE_G => DMA_SIZE_G)
      port map (
         -- PCIe Interface
         trnPending       => cfgToPci.trnPending,
         cfgTurnoffOk     => cfgToPci.turnoffOk,
         cfgFromPci       => cfgFromPci,
         pciIbMaster      => pciIbMaster,
         pciIbSlave       => pciIbSlave,
         pciObMaster      => pciObMaster,
         pciObSlave       => pciObSlave,
         -- Register Interface
         regTranFromPci   => regTranFromPci,
         regObMaster      => regObMaster,
         regObSlave       => regObSlave,
         regIbMaster      => regIbMaster,
         regIbSlave       => regIbSlave,
         -- DMA Interface      
         dmaTxTranFromPci => dmaTxTranFromPci,
         dmaRxTranFromPci => dmaRxTranFromPci,
         dmaTxObMasters   => dmaTxObMasters,
         dmaTxObSlaves    => dmaTxObSlaves,
         dmaTxIbMasters   => dmaTxIbMasters,
         dmaTxIbSlaves    => dmaTxIbSlaves,
         dmaRxIbMasters   => dmaRxIbMasters,
         dmaRxIbSlaves    => dmaRxIbSlaves,
         -- Clock and Resets
         pciClk           => pciClk,
         pciRst           => pciRst);   

   GEN_VEC :
   for i in (DMA_SIZE_G-1) downto 0 generate

      ---------------------------   
      -- RX DMA AXI-to-TLP Bridge
      ---------------------------   
      U_AxiToTlp : entity work.AxiPcieTlpToAxi
         generic map (
            TPD_G => TPD_G)   
         port map (
            -- AXI Interface
            axiReadMaster    => axiReadMasters(i),
            axiReadSlave     => axiReadSlaves(i),
            -- PCIe Interface            
            dmaTxTranFromPci => dmaTxTranFromPci(i),
            dmaTxObMaster    => dmaTxObMasters(i),
            dmaTxObSlave     => dmaTxObSlaves(i),
            dmaTxIbMaster    => dmaTxIbMasters(i),
            dmaTxIbSlave     => dmaTxIbSlaves(i),
            -- Clock and Resets
            pciClk           => pciClk,
            pciRst           => pciRst);  

      ---------------------------   
      -- TX DMA TLP-to-AXI Bridge
      ---------------------------   
      U_TlpToAxi : entity work.AxiPcieAxiToTlp
         generic map (
            TPD_G => TPD_G)   
         port map (
            -- AXI Interface
            axiWriteMaster   => axiWriteMasters(i),
            axiWriteSlave    => axiWriteSlaves(i),
            -- PCIe Interface
            dmaRxTranFromPci => dmaRxTranFromPci(i),
            dmaRxIbMaster    => dmaRxIbMasters(i),
            dmaRxIbSlave     => dmaRxIbSlaves(i),
            -- Clock and Resets
            pciClk           => pciClk,
            pciRst           => pciRst);     

   end generate GEN_VEC;

   ----------------------
   -- Register Controller
   ----------------------   
   U_RegMaster : entity work.AxiPcieAxiLiteMaster
      generic map (
         TPD_G      => TPD_G,
         BAR_SIZE_G => BAR_SIZE_G,
         BAR_MASK_G => BAR_MASK_G)   
      port map (
         -- PCI Interface         
         regTranFromPci  => regTranFromPci,
         regObMaster     => regObMaster,
         regObSlave      => regObSlave,
         regIbMaster     => regIbMaster,
         regIbSlave      => regIbSlave,
         -- AXI-Lite Interface
         axilWriteMaster => axilWriteMasters,
         axilWriteSlave  => axilWriteSlaves,
         axilReadMaster  => axilReadMasters,
         axilReadSlave   => axilReadSlaves,
         -- Global Signals
         pciClk          => pciClk,
         pciRst          => pciRst);   

   ----------------------
   -- Interrupt Controller
   ----------------------   
   U_IrqCtrl : entity work.AxiPcieIrqCtrl
      generic map (
         TPD_G => TPD_G)
      port map (
         -- Interrupt Interface
         irqEnable    => irqEnable,
         irqReq       => irqReq,
         irqAck       => cfgFromPci.irqAck,
         irqActive    => irqActive,
         cfgIrqReq    => cfgToPci.irqReq,
         cfgIrqAssert => cfgToPci.irqAssert,
         -- Clock and Resets
         pciClk       => pciClk,
         pciRst       => pciRst);         

end mapping;
