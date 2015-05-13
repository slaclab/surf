-------------------------------------------------------------------------------
-- Title      : SSI PCIe Core
-------------------------------------------------------------------------------
-- File       : SsiPcieCore.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-04-22
-- Last update: 2015-05-12
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
--    SSI PCIe Core, Top Level
--
--    Supports up to 16x independent DMA channels
--    Each DMA has 16x virtual channels
--
--    Supports the following Xilinx IP Core PCIe configurations:
--       1) Generation 1: x1, x2, x4 and x8 lanes
--       2) Generation 2: x1, x2, x4 and x8 lanes
--       3) Generation 3: x1, x2, and x4
--
--    External User interrupt is support in the firmware.  However, the default 
--    PCIe Linux driver can not be used.  To support this feature in software, 
--    you will have to copy the SSI PCIe Linux driver then modify the interrupt 
--    routine.
--
---------------------------------------------------------------------------------
-- SsiPcieCore Linux Driver:
--    Vendor ID = 0x1A4A
--    Devide ID = 0x2030
---------------------------------------------------------------------------------
-- Note: Assumes 128-bit AXIS interface to Xilinx IP core.
---------------------------------------------------------------------------------
-- Note: Unable able to support PCIe GEN3 8x lanes 
--       because it requires 256-bit AXIS bus (out of range for AxiStreamPkg.vhd)
-------------------------------------------------------------------------------
-- Copyright (c) 2015 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;
use work.SsiPciePkg.all;

entity SsiPcieCore is
   generic (
      TPD_G            : time                   := 1 ns;
      BAR_MASK_G       : slv(31 downto 0)       := x"FFFF0000";
      DMA_SIZE_G       : positive range 1 to 16 := 1;
      LOOPBACK_EN_G    : boolean                := true;  -- true = synthesis loopback capability
      AXI_ERROR_RESP_G : slv(1 downto 0)        := AXI_RESP_OK_C);
   port (
      -- System Interface
      userIrqReq          : in  sl := '0';  -- Must be '0' for default PCIe Linux driver
      serialNumber        : in  slv(63 downto 0);
      cardRst             : out sl;
      -- AXI-Lite Interface (0x7FFFFFFF:0x00000C00)
      mAxiLiteWriteMaster : out AxiLiteWriteMasterType;
      mAxiLiteWriteSlave  : in  AxiLiteWriteSlaveType;
      mAxiLiteReadMaster  : out AxiLiteReadMasterType;
      mAxiLiteReadSlave   : in  AxiLiteReadSlaveType;
      -- DMA Interface
      dmaIbMasters        : in  AxiStreamMasterArray(DMA_SIZE_G-1 downto 0);
      dmaIbSlaves         : out AxiStreamSlaveArray(DMA_SIZE_G-1 downto 0);
      dmaObMasters        : out AxiStreamMasterArray(DMA_SIZE_G-1 downto 0);
      dmaObSlaves         : in  AxiStreamSlaveArray(DMA_SIZE_G-1 downto 0);
      -- PCIe Interface      
      cfgFromPci          : in  PcieCfgOutType;
      cfgToPci            : out PcieCfgInType;
      pciIbMaster         : out AxiStreamMasterType;
      pciIbSlave          : in  AxiStreamSlaveType;
      pciObMaster         : in  AxiStreamMasterType;
      pciObSlave          : out AxiStreamSlaveType;
      -- Clock and Resets
      pciClk              : in  sl;
      pciRst              : in  sl);
end SsiPcieCore;

architecture mapping of SsiPcieCore is

   -- Register Signals
   signal regTranFromPci : TranFromPcieType;
   signal regObMaster    : AxiStreamMasterType;
   signal regObSlave     : AxiStreamSlaveType;
   signal regIbMaster    : AxiStreamMasterType;
   signal regIbSlave     : AxiStreamSlaveType;

   -- RX DMA Descriptor Signals
   signal dmaRxDescToPci   : DescToPcieArray(DMA_SIZE_G-1 downto 0);
   signal dmaRxDescFromPci : DescFromPcieArray(DMA_SIZE_G-1 downto 0);

   -- TX DMA Descriptor Signals
   signal dmaTxDescToPci   : DescToPcieArray(DMA_SIZE_G-1 downto 0);
   signal dmaTxDescFromPci : DescFromPcieArray(DMA_SIZE_G-1 downto 0);

   -- RX DMA Signals   
   signal dmaRxTranFromPci : TranFromPcieArray(DMA_SIZE_G-1 downto 0);
   signal dmaRxIbMaster    : AxiStreamMasterArray(DMA_SIZE_G-1 downto 0);
   signal dmaRxIbSlave     : AxiStreamSlaveArray(DMA_SIZE_G-1 downto 0);

   -- TX DMA Signals   
   signal dmaTxTranFromPci : TranFromPcieArray(DMA_SIZE_G-1 downto 0);
   signal dmaTxIbMaster    : AxiStreamMasterArray(DMA_SIZE_G-1 downto 0);
   signal dmaTxIbSlave     : AxiStreamSlaveArray(DMA_SIZE_G-1 downto 0);
   signal dmaTxObMaster    : AxiStreamMasterArray(DMA_SIZE_G-1 downto 0);
   signal dmaTxObSlave     : AxiStreamSlaveArray(DMA_SIZE_G-1 downto 0);

   -- Interrupt Signals
   signal irqRequest   : sl;
   signal coreIrqReq   : sl;
   signal irqIntEnable : sl;
   signal irqExtEnable : sl;
   signal irqActive    : sl;

   -- DMA Loopback Signals
   signal dmaLoopback : slv(DMA_SIZE_G-1 downto 0);
   signal ibMasters   : AxiStreamMasterArray(DMA_SIZE_G-1 downto 0);
   signal IbSlaves    : AxiStreamSlaveArray(DMA_SIZE_G-1 downto 0);
   signal obMasters   : AxiStreamMasterArray(DMA_SIZE_G-1 downto 0);
   signal obSlaves    : AxiStreamSlaveArray(DMA_SIZE_G-1 downto 0);
   
begin

   cfgToPci.serialNumber <= serialNumber;

   -----------------
   -- TLP Controller
   -----------------
   SsiPcieTlpCtrl_Inst : entity work.SsiPcieTlpCtrl
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
         dmaTxObMaster    => dmaTxObMaster,
         dmaTxObSlave     => dmaTxObSlave,
         dmaTxIbMaster    => dmaTxIbMaster,
         dmaTxIbSlave     => dmaTxIbSlave,
         dmaRxIbMaster    => dmaRxIbMaster,
         dmaRxIbSlave     => dmaRxIbSlave,
         -- Clock and Resets
         pciClk           => pciClk,
         pciRst           => pciRst);   

   ----------------------
   -- Register Controller
   ----------------------   
   SsiPcieAxiLite_Inst : entity work.SsiPcieAxiLite
      generic map (
         TPD_G            => TPD_G,
         BAR_MASK_G       => BAR_MASK_G,
         DMA_SIZE_G       => DMA_SIZE_G,
         AXI_ERROR_RESP_G => AXI_ERROR_RESP_G)
      port map (
         -- System Signals
         serialNumber     => serialNumber,
         cardRst          => cardRst,
         dmaLoopback      => dmaLoopback,
         -- External AXI-Lite (0x7FFFFFFF:0x00000C00)
         axiWriteMaster   => mAxiLiteWriteMaster,
         axiWriteSlave    => mAxiLiteWriteSlave,
         axiReadMaster    => mAxiLiteReadMaster,
         axiReadSlave     => mAxiLiteReadSlave,
         -- PCIe Interface
         cfgFromPci       => cfgFromPci,
         irqIntEnable     => irqIntEnable,
         irqExtEnable     => irqExtEnable,
         irqActive        => irqActive,
         regTranFromPci   => regTranFromPci,
         regObMaster      => regObMaster,
         regObSlave       => regObSlave,
         regIbMaster      => regIbMaster,
         regIbSlave       => regIbSlave,
         -- RX DMA Descriptor Interface
         dmaRxDescToPci   => dmaRxDescToPci,
         dmaRxDescFromPci => dmaRxDescFromPci,
         -- TX DMA Descriptor Interface
         dmaTxDescToPci   => dmaTxDescToPci,
         dmaTxDescFromPci => dmaTxDescFromPci,
         -- Interrupt Signals
         irqReq           => coreIrqReq,
         -- Clock and Resets
         pciClk           => pciClk,
         pciRst           => pciRst);

   ----------------------
   -- Interrupt Controller
   ----------------------   
   SsiPcieIrqCtrl_Inst : entity work.SsiPcieIrqCtrl
      generic map (
         TPD_G => TPD_G)
      port map (
         -- Interrupt Interface
         irqIntEnable => irqIntEnable,
         irqExtEnable => irqExtEnable,
         intIrqReq    => coreIrqReq,
         extIrqReq    => userIrqReq,
         irqAck       => cfgFromPci.irqAck,
         irqActive    => irqActive,
         cfgIrqReq    => cfgToPci.irqReq,
         cfgIrqAssert => cfgToPci.irqAssert,
         -- Clock and Resets
         pciClk       => pciClk,
         pciRst       => pciRst);         

   GEN_DMA_CH :
   for i in 0 to DMA_SIZE_G-1 generate
      ---------------
      -- DMA Loopback
      ---------------
      SsiPcieDmaLoopBack_Inst : entity work.SsiPcieDmaLoopBack
         generic map (
            TPD_G         => TPD_G,
            LOOPBACK_EN_G => LOOPBACK_EN_G,
            DMA_SIZE_G    => DMA_SIZE_G)
         port map (
            dmaLoopback => dmaLoopback(i),
            -- External DMA Interface
            dmaIbMaster => dmaIbMasters(i),
            dmaIbSlave  => dmaIbSlaves(i),
            dmaObMaster => dmaObMasters(i),
            dmaObSlave  => dmaObSlaves(i),
            -- Internal DMA Interface
            ibMaster    => ibMasters(i),
            ibSlave     => ibSlaves(i),
            obMaster    => obMasters(i),
            obSlave     => obSlaves(i),
            -- Clock and Resets
            pciClk      => pciClk,
            pciRst      => pciRst);    

      ----------------
      -- TX DMA Engine
      ----------------            
      SsiPcieTxDma_Inst : entity work.SsiPcieTxDma
         generic map (
            TPD_G => TPD_G)
         port map (
            -- PCIe Interface
            dmaDescToPci   => dmaTxDescToPci(i),
            dmaDescFromPci => dmaTxDescFromPci(i),
            dmaTranFromPci => dmaTxTranFromPci(i),
            dmaIbMaster    => dmaTxIbMaster(i),
            dmaIbSlave     => dmaTxIbSlave(i),
            dmaObMaster    => dmaTxObMaster(i),
            dmaObSlave     => dmaTxObSlave(i),
            -- DMA Output
            mAxisMaster    => obMasters(i),
            mAxisSlave     => obSlaves(i),
            -- Clock and Resets
            pciClk         => pciClk,
            pciRst         => pciRst); 

      ----------------
      -- RX DMA Engine
      ----------------            
      SsiPcieRxDma_Inst : entity work.SsiPcieRxDma
         generic map (
            TPD_G => TPD_G)
         port map (
            -- PCIe Interface
            dmaDescToPci   => dmaRxDescToPci(i),
            dmaDescFromPci => dmaRxDescFromPci(i),
            dmaTranFromPci => dmaRxTranFromPci(i),
            dmaIbMaster    => dmaRxIbMaster(i),
            dmaIbSlave     => dmaRxIbSlave(i),
            dmaChannel     => toSlv(i, 4),
            -- DMA Input
            sAxisMaster    => ibMasters(i),
            sAxisSlave     => ibSlaves(i),
            -- Clock and Resets
            pciClk         => pciClk,
            pciRst         => pciRst);             

   end generate GEN_DMA_CH;
   
end mapping;
