-------------------------------------------------------------------------------
-- Title      : SSI PCIe Core
-------------------------------------------------------------------------------
-- File       : SsiPcieCore.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-04-22
-- Last update: 2015-04-22
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: SSI PCIe Core, Top Level
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
      DMA_SIZE_G       : positive range 1 to 16 := 1;
      LOOPBACK_EN_G    : boolean                := true;  -- true = synthesis loopback capability
      AXI_ERROR_RESP_G : slv(1 downto 0)        := AXI_RESP_OK_C);
   port (
      -- System Interface
      userIrqReq     : in  sl := '0';
      serialNumber   : in  slv(63 downto 0);
      cardRst        : out sl;
      -- AXI-Lite Interface (0x7FFFFFFF:0x00000C00)
      axiWriteMaster : out AxiLiteWriteMasterType;
      axiWriteSlave  : in  AxiLiteWriteSlaveType;
      axiReadMaster  : out AxiLiteReadMasterType;
      axiReadSlave   : in  AxiLiteReadSlaveType;
      -- DMA Interface
      dmaIbMasters   : in  AxiStreamMasterArray(DMA_SIZE_G-1 downto 0);
      dmaIbSlaves    : out AxiStreamSlaveArray(DMA_SIZE_G-1 downto 0);
      dmaObMasters   : out AxiStreamMasterArray(DMA_SIZE_G-1 downto 0);
      dmaObSlaves    : in  AxiStreamSlaveArray(DMA_SIZE_G-1 downto 0);
      -- PCIe Interface      
      cfgFromPci     : in  PcieCfgOutType;
      cfgToPci       : out PcieCfgInType;
      pciIbMaster    : in  AxiStreamMasterType;
      pciIbSlave     : out AxiStreamSlaveType;
      pciObMaster    : out AxiStreamMasterType;
      pciObSlave     : in  AxiStreamSlaveType;
      -- Clock and Resets
      pciClk         : in  sl;
      pciRst         : in  sl);
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
   signal irqRequest : sl;
   signal coreIrqReq : sl;
   signal irqEnable  : sl;
   signal irqActive  : sl;

   -- DMA Loopback Signals
   signal dmaLoopback : slv(DMA_SIZE_G-1 downto 0);
   signal ibMasters   : AxiStreamMasterArray(DMA_SIZE_G-1 downto 0);
   signal IbSlaves    : AxiStreamSlaveArray(DMA_SIZE_G-1 downto 0);
   signal obMasters   : AxiStreamMasterArray(DMA_SIZE_G-1 downto 0);
   signal obSlaves    : AxiStreamSlaveArray(DMA_SIZE_G-1 downto 0);
   
begin

   -----------------
   -- TLP Controller
   -----------------
   SsiPcieTlpCtrl_Inst : entity work.SsiPcieTlpCtrl
      generic map (
         TPD_G      => TPD_G,
         DMA_SIZE_G => DMA_SIZE_G)
      port map (
         -- PCIe Interface
         trnPending       => cfgToPci.TrnPending,
         cfgTurnoffOk     => cfgToPci.cfgTurnoffOk,
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
         DMA_SIZE_G       => DMA_SIZE_G,
         AXI_ERROR_RESP_G => AXI_ERROR_RESP_G)
      port map (
         -- System Signals
         serialNumber     => serialNumber,
         cardRst          => cardRst,
         dmaLoopback      => dmaLoopback,
         -- External AXI-Lite (0x7FFFFFFF:0x00000C00)
         axiWriteMaster   => axiWriteMaster,
         axiWriteSlave    => axiWriteSlave,
         axiReadMaster    => axiReadMaster,
         axiReadSlave     => axiReadSlave,
         -- PCIe Interface
         cfgFromPci       => cfgFromPci,
         irqEnable        => irqEnable,
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
         irqEnable    => irqEnable,
         coreIrqReq   => coreIrqReq,
         userIrqReq   => userIrqReq,
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
