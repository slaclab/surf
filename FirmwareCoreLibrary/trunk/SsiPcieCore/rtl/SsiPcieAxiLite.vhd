-------------------------------------------------------------------------------
-- Title      : SSI PCIe Core
-------------------------------------------------------------------------------
-- File       : SsiPcieAxiLite.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-04-22
-- Last update: 2015-05-15
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: SSI PCIe AXI-Lite Core Module
-------------------------------------------------------------------------------
-- Copyright (c) 2015 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;
use work.SsiPciePkg.all;

entity SsiPcieAxiLite is
   generic (
      TPD_G            : time                   := 1 ns;
      DMA_SIZE_G       : positive range 1 to 16 := 1;
      BAR_SIZE_G       : positive range 1 to 4  := 1;
      BAR_MASK_G       : Slv32Array(3 downto 0) := (others => x"FFF00000");
      AXI_ERROR_RESP_G : slv(1 downto 0)        := AXI_RESP_OK_C);
   port (
      -- System Signals
      serialNumber        : in  slv(63 downto 0);
      cardRst             : out sl;
      dmaLoopback         : out slv(DMA_SIZE_G-1 downto 0);
      -- External AXI-Lite Interface
      mAxiLiteWriteMaster : out AxiLiteWriteMasterArray(BAR_SIZE_G-1 downto 0);
      mAxiLiteWriteSlave  : in  AxiLiteWriteSlaveArray(BAR_SIZE_G-1 downto 0);
      mAxiLiteReadMaster  : out AxiLiteReadMasterArray(BAR_SIZE_G-1 downto 0);
      mAxiLiteReadSlave   : in  AxiLiteReadSlaveArray(BAR_SIZE_G-1 downto 0);
      -- PCIe Interface
      cfgFromPci          : in  PcieCfgOutType;
      irqActive           : in  sl;
      irqIntEnable        : out sl;
      irqExtEnable        : out sl;
      regTranFromPci      : in  TranFromPcieType;
      regObMaster         : in  AxiStreamMasterType;
      regObSlave          : out AxiStreamSlaveType;
      regIbMaster         : out AxiStreamMasterType;
      regIbSlave          : in  AxiStreamSlaveType;
      -- RX DMA Descriptor Interface
      dmaRxDescToPci      : in  DescToPcieArray(DMA_SIZE_G-1 downto 0);
      dmaRxDescFromPci    : out DescFromPcieArray(DMA_SIZE_G-1 downto 0);
      -- TX DMA Descriptor Interface
      dmaTxDescToPci      : in  DescToPcieArray(DMA_SIZE_G-1 downto 0);
      dmaTxDescFromPci    : out DescFromPcieArray(DMA_SIZE_G-1 downto 0);
      -- Interrupt Signals
      irqReq              : out sl;
      -- Clock and Resets
      pciClk              : in  sl;
      pciRst              : in  sl);
end SsiPcieAxiLite;

architecture mapping of SsiPcieAxiLite is

   constant NUM_AXI_MASTERS_C : natural := 3;

   constant SYS_INDEX_C     : natural := 0;
   constant RX_DESC_INDEX_C : natural := 1;
   constant TX_DESC_INDEX_C : natural := 2;

   constant SYS_ADDR_C     : slv(31 downto 0) := X"00000000";
   constant RX_DESC_ADDR_C : slv(31 downto 0) := X"00000400";
   constant TX_DESC_ADDR_C : slv(31 downto 0) := X"00000800";

   constant AXI_CROSSBAR_MASTERS_CONFIG_C : AxiLiteCrossbarMasterConfigArray(NUM_AXI_MASTERS_C-1 downto 0) := (
      SYS_INDEX_C     => (
         baseAddr     => SYS_ADDR_C,
         addrBits     => 10,
         connectivity => X"0001"),
      RX_DESC_INDEX_C => (
         baseAddr     => RX_DESC_ADDR_C,
         addrBits     => 10,
         connectivity => X"0001"),
      TX_DESC_INDEX_C => (
         baseAddr     => TX_DESC_ADDR_C,
         addrBits     => 10,
         connectivity => X"0001"));

   signal sAxiReadMaster  : AxiLiteReadMasterType;
   signal sAxiReadSlave   : AxiLiteReadSlaveType;
   signal sAxiWriteMaster : AxiLiteWriteMasterType;
   signal sAxiWriteSlave  : AxiLiteWriteSlaveType;

   signal mAxiWriteMasters : AxiLiteWriteMasterArray(NUM_AXI_MASTERS_C-1 downto 0);
   signal mAxiWriteSlaves  : AxiLiteWriteSlaveArray(NUM_AXI_MASTERS_C-1 downto 0);
   signal mAxiReadMasters  : AxiLiteReadMasterArray(NUM_AXI_MASTERS_C-1 downto 0);
   signal mAxiReadSlaves   : AxiLiteReadSlaveArray(NUM_AXI_MASTERS_C-1 downto 0);

   signal rxDmaIrqReq : sl;
   signal txDmaIrqReq : sl;

   signal cardReset : sl;
   signal cntRst    : sl;
   
begin

   cardRst <= cardReset;
   irqReq  <= rxDmaIrqReq or txDmaIrqReq;

   ----------------------
   -- Register Controller
   ----------------------
   SsiPcieAxiLiteMaster_Inst : entity work.SsiPcieAxiLiteMaster
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
         -- External AXI-Lite Interface
         mExtWriteMaster => mAxiLiteWriteMaster,
         mExtWriteSlave  => mAxiLiteWriteSlave,
         mExtReadMaster  => mAxiLiteReadMaster,
         mExtReadSlave   => mAxiLiteReadSlave,
         -- Internal AXI-Lite Interface
         mIntWriteMaster => sAxiWriteMaster,
         mIntWriteSlave  => sAxiWriteSlave,
         mIntReadMaster  => sAxiReadMaster,
         mIntReadSlave   => sAxiReadSlave,
         -- Global Signals
         pciClk          => pciClk,
         pciRst          => pciRst);

   -------------------------
   -- AXI-Lite Crossbar Core
   -------------------------  
   AxiLiteCrossbar_Inst : entity work.AxiLiteCrossbar
      generic map (
         TPD_G              => TPD_G,
         NUM_SLAVE_SLOTS_G  => 1,
         NUM_MASTER_SLOTS_G => NUM_AXI_MASTERS_C,
         DEC_ERROR_RESP_G   => AXI_ERROR_RESP_G,
         MASTERS_CONFIG_G   => AXI_CROSSBAR_MASTERS_CONFIG_C)
      port map (
         axiClk              => pciClk,
         axiClkRst           => pciRst,
         sAxiWriteMasters(0) => sAxiWriteMaster,
         sAxiWriteSlaves(0)  => sAxiWriteSlave,
         sAxiReadMasters(0)  => sAxiReadMaster,
         sAxiReadSlaves(0)   => sAxiReadSlave,
         mAxiWriteMasters    => mAxiWriteMasters,
         mAxiWriteSlaves     => mAxiWriteSlaves,
         mAxiReadMasters     => mAxiReadMasters,
         mAxiReadSlaves      => mAxiReadSlaves);            

   -----------------------
   -- PCI System Module
   -----------------------
   SsiPcieSysReg_Inst : entity work.SsiPcieSysReg
      generic map (
         TPD_G            => TPD_G,
         DMA_SIZE_G       => DMA_SIZE_G,
         BAR_SIZE_G       => BAR_SIZE_G,
         BAR_MASK_G       => BAR_MASK_G,
         AXI_ERROR_RESP_G => AXI_ERROR_RESP_G)
      port map (
         -- PCIe Interface
         cfgFromPci     => cfgFromPci,
         irqActive      => irqActive,
         irqIntEnable   => irqIntEnable,
         irqExtEnable   => irqExtEnable,
         dmaLoopback    => dmaLoopback,
         -- AXI-Lite Register Interface
         axiReadMaster  => mAxiReadMasters(SYS_INDEX_C),
         axiReadSlave   => mAxiReadSlaves(SYS_INDEX_C),
         axiWriteMaster => mAxiWriteMasters(SYS_INDEX_C),
         axiWriteSlave  => mAxiWriteSlaves(SYS_INDEX_C),
         -- System Signals
         serialNumber   => serialNumber,
         cardRst        => cardReset,
         cntRst         => cntRst,
         -- Global Signals
         pciClk         => pciClk,
         pciRst         => pciRst);            

   -----------------------
   -- RX Descriptor Module
   -----------------------
   SsiPcieRxDesc_Inst : entity work.SsiPcieRxDesc
      generic map (
         TPD_G            => TPD_G,
         DMA_SIZE_G       => DMA_SIZE_G,
         AXI_ERROR_RESP_G => AXI_ERROR_RESP_G)
      port map (
         -- RX DMA Interface
         dmaDescToPci   => dmaRxDescToPci,
         dmaDescFromPci => dmaRxDescFromPci,
         -- AXI-Lite Register Interface
         axiReadMaster  => mAxiReadMasters(RX_DESC_INDEX_C),
         axiReadSlave   => mAxiReadSlaves(RX_DESC_INDEX_C),
         axiWriteMaster => mAxiWriteMasters(RX_DESC_INDEX_C),
         axiWriteSlave  => mAxiWriteSlaves(RX_DESC_INDEX_C),
         -- IRQ Request
         irqReq         => rxDmaIrqReq,
         -- Counter reset
         cntRst         => cntRst,
         -- Global Signals
         pciClk         => pciClk,
         pciRst         => cardReset);

   -----------------------
   -- TX Descriptor Module
   -----------------------
   SsiPcieTxDesc_Inst : entity work.SsiPcieTxDesc
      generic map (
         TPD_G            => TPD_G,
         DMA_SIZE_G       => DMA_SIZE_G,
         AXI_ERROR_RESP_G => AXI_ERROR_RESP_G)
      port map (
         -- TX DMA Interface
         dmaDescToPci   => dmaTxDescToPci,
         dmaDescFromPci => dmaTxDescFromPci,
         -- AXI-Lite Register Interface
         axiReadMaster  => mAxiReadMasters(TX_DESC_INDEX_C),
         axiReadSlave   => mAxiReadSlaves(TX_DESC_INDEX_C),
         axiWriteMaster => mAxiWriteMasters(TX_DESC_INDEX_C),
         axiWriteSlave  => mAxiWriteSlaves(TX_DESC_INDEX_C),
         -- IRQ Request
         irqReq         => txDmaIrqReq,
         -- Counter reset
         cntRst         => cntRst,
         -- Global Signals
         pciClk         => pciClk,
         pciRst         => cardReset);

end mapping;
