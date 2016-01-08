-------------------------------------------------------------------------------
-- Title      : SSI PCIe Core
-------------------------------------------------------------------------------
-- File       : SsiPcieCore.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-04-22
-- Last update: 2015-06-10
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
-- This file is part of 'SLAC SSI PCI-E Core'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'SLAC SSI PCI-E Core', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;
use work.SsiPciePkg.all;

entity SsiPcieCore is
   generic (
      TPD_G      : time                   := 1 ns;
      DMA_SIZE_G : positive range 1 to 16 := 1;
      BAR_SIZE_G : positive range 1 to 4  := 1;
      BAR_MASK_G : Slv32Array(3 downto 0) := (others => x"FFF00000"));
   port (
      -- System Interface
      irqActive             : out sl;
      irqEnable           : in  slv(BAR_SIZE_G-1 downto 0) := (others => '0');
      irqReq              : in  slv(BAR_SIZE_G-1 downto 0) := (others => '0');
      serialNumber        : in  slv(63 downto 0);
      cardRst             : out sl;
      -- AXI-Lite Interface
      mAxiLiteWriteMaster : out AxiLiteWriteMasterArray(BAR_SIZE_G-1 downto 0);
      mAxiLiteWriteSlave  : in  AxiLiteWriteSlaveArray(BAR_SIZE_G-1 downto 0);
      mAxiLiteReadMaster  : out AxiLiteReadMasterArray(BAR_SIZE_G-1 downto 0);
      mAxiLiteReadSlave   : in  AxiLiteReadSlaveArray(BAR_SIZE_G-1 downto 0);
      -- DMA Interface      
      dmaTxTranFromPci    : out TranFromPcieArray(DMA_SIZE_G-1 downto 0);
      dmaRxTranFromPci    : out TranFromPcieArray(DMA_SIZE_G-1 downto 0);
      dmaTxObMasters      : out AxiStreamMasterArray(DMA_SIZE_G-1 downto 0);
      dmaTxObSlaves       : in  AxiStreamSlaveArray(DMA_SIZE_G-1 downto 0);
      dmaTxIbMasters      : in  AxiStreamMasterArray(DMA_SIZE_G-1 downto 0);
      dmaTxIbSlaves       : out AxiStreamSlaveArray(DMA_SIZE_G-1 downto 0);
      dmaRxIbMasters      : in  AxiStreamMasterArray(DMA_SIZE_G-1 downto 0);
      dmaRxIbSlaves       : out AxiStreamSlaveArray(DMA_SIZE_G-1 downto 0);
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

   signal regTranFromPci : TranFromPcieType;
   signal regObMaster    : AxiStreamMasterType;
   signal regObSlave     : AxiStreamSlaveType;
   signal regIbMaster    : AxiStreamMasterType;
   signal regIbSlave     : AxiStreamSlaveType;
   signal irqActiveInt      : sl;
   
begin

   cfgToPci.serialNumber <= serialNumber;
   irqActive             <= irqActiveInt;

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
         dmaTxObMasters   => dmaTxObMasters,
         dmaTxObSlaves    => dmaTxObSlaves,
         dmaTxIbMasters   => dmaTxIbMasters,
         dmaTxIbSlaves    => dmaTxIbSlaves,
         dmaRxIbMasters   => dmaRxIbMasters,
         dmaRxIbSlaves    => dmaRxIbSlaves,
         -- Clock and Resets
         pciClk           => pciClk,
         pciRst           => pciRst);   

   ----------------------
   -- Register Controller
   ----------------------   
   SsiPcieAxiLite_Inst : entity work.SsiPcieAxiLite
      generic map (
         TPD_G      => TPD_G,
         DMA_SIZE_G => DMA_SIZE_G,
         BAR_SIZE_G => BAR_SIZE_G,
         BAR_MASK_G => BAR_MASK_G)
      port map (
         -- System Signals
         serialNumber        => serialNumber,
         cardRst             => cardRst,
         -- External AXI-Lite Interface
         mAxiLiteWriteMaster => mAxiLiteWriteMaster,
         mAxiLiteWriteSlave  => mAxiLiteWriteSlave,
         mAxiLiteReadMaster  => mAxiLiteReadMaster,
         mAxiLiteReadSlave   => mAxiLiteReadSlave,
         -- PCIe Interface
         irqEnable           => irqEnable,
         irqReq              => irqReq,
         irqActive           => irqActiveInt,
         cfgFromPci          => cfgFromPci,
         regTranFromPci      => regTranFromPci,
         regObMaster         => regObMaster,
         regObSlave          => regObSlave,
         regIbMaster         => regIbMaster,
         regIbSlave          => regIbSlave,
         -- Clock and Resets
         pciClk              => pciClk,
         pciRst              => pciRst);

   ----------------------
   -- Interrupt Controller
   ----------------------   
   SsiPcieIrqCtrl_Inst : entity work.SsiPcieIrqCtrl
      generic map (
         TPD_G      => TPD_G,
         BAR_SIZE_G => BAR_SIZE_G)
      port map (
         -- Interrupt Interface
         irqEnable    => irqEnable,
         irqReq       => irqReq,
         irqAck       => cfgFromPci.irqAck,
         irqActive    => irqActiveInt,
         cfgIrqReq    => cfgToPci.irqReq,
         cfgIrqAssert => cfgToPci.irqAssert,
         -- Clock and Resets
         pciClk       => pciClk,
         pciRst       => pciRst);         

end mapping;
