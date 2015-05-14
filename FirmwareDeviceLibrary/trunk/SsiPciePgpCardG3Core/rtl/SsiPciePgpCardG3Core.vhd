-------------------------------------------------------------------------------
-- Title      : PgpCardG3 Wrapper for SSI PCIe Core
-------------------------------------------------------------------------------
-- File       : SsiPciePgpCardG3Core.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-04-24
-- Last update: 2015-05-14
-- Platform   : Vivado 2014.4
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2015 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;
use work.SsiPciePkg.all;

entity SsiPciePgpCardG3Core is
   generic (
      TPD_G         : time             := 1 ns;
      LOOPBACK_EN_G : boolean          := true;  -- true = synthesis loopback capability
      BAR_MASK_G    : slv(31 downto 0) := x"FFFF0000";
      DMA_SIZE_G    : positive         := 8);
   port (
      -- System Interface
      serialNumber        : in  slv(63 downto 0);
      cardRst             : out sl;
      pciLinkUp           : out sl;
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
      -- Clock and reset
      pciClk              : out sl;
      pciRst              : out sl;
      -- PCIe Ports 
      pciRstL             : in  sl;
      pciRefClkP          : in  sl;
      pciRefClkN          : in  sl;
      pciRxP              : in  slv(3 downto 0);
      pciRxN              : in  slv(3 downto 0);
      pciTxP              : out slv(3 downto 0);
      pciTxN              : out slv(3 downto 0));      
end SsiPciePgpCardG3Core;

architecture mapping of SsiPciePgpCardG3Core is

   signal pciClock    : sl;
   signal pciReset    : sl;
   signal cfgFromPci  : PcieCfgOutType;
   signal cfgToPci    : PcieCfgInType;
   signal pciIbMaster : AxiStreamMasterType;
   signal pciIbSlave  : AxiStreamSlaveType;
   signal pciObMaster : AxiStreamMasterType;
   signal pciObSlave  : AxiStreamSlaveType;

begin

   pciClk <= pciClock;
   pciRst <= pciReset;

   SsiPciePgpCardG3FrontEnd_Inst : entity work.SsiPciePgpCardG3FrontEnd
      generic map (
         TPD_G => TPD_G)
      port map (
         -- PCIe Interface      
         cfgFromPci  => cfgFromPci,
         cfgToPci    => cfgToPci,
         pciIbMaster => pciIbMaster,
         pciIbSlave  => pciIbSlave,
         pciObMaster => pciObMaster,
         pciObSlave  => pciObSlave,
         -- Clock and Resets
         pciClk      => pciClock,
         pciRst      => pciReset,
         pciLinkUp   => pciLinkUp,
         -- PCIe Ports 
         pciRstL     => pciRstL,
         pciRefClkP  => pciRefClkP,
         pciRefClkN  => pciRefClkN,
         pciRxP      => pciRxP,
         pciRxN      => pciRxN,
         pciTxP      => pciTxP,
         pciTxN      => pciTxN);           

   SsiPcieCore_Inst : entity work.SsiPcieCore
      generic map (
         TPD_G            => TPD_G,
         BAR_MASK_G       => BAR_MASK_G,
         DMA_SIZE_G       => DMA_SIZE_G,
         LOOPBACK_EN_G    => LOOPBACK_EN_G,
         AXI_ERROR_RESP_G => AXI_RESP_OK_C)
      port map (
         -- System Interface
         userIrqReq          => '0',
         serialNumber        => serialNumber,
         cardRst             => cardRst,
         -- AXI-Lite Interface (0x7FFFFFFF:0x00000C00)
         mAxiLiteWriteMaster => mAxiLiteWriteMaster,
         mAxiLiteWriteSlave  => mAxiLiteWriteSlave,
         mAxiLiteReadMaster  => mAxiLiteReadMaster,
         mAxiLiteReadSlave   => mAxiLiteReadSlave,
         -- DMA Interface
         dmaIbMasters        => dmaIbMasters,
         dmaIbSlaves         => dmaIbSlaves,
         dmaObMasters        => dmaObMasters,
         dmaObSlaves         => dmaObSlaves,
         -- PCIe Interface      
         cfgFromPci          => cfgFromPci,
         cfgToPci            => cfgToPci,
         pciIbMaster         => pciIbMaster,
         pciIbSlave          => pciIbSlave,
         pciObMaster         => pciObMaster,
         pciObSlave          => pciObSlave,
         -- Clock and Resets
         pciClk              => pciClock,
         pciRst              => pciReset);   

end mapping;
