-------------------------------------------------------------------------------
-- Title      : PgpCardG3 Wrapper for AXI PCIe Core
-------------------------------------------------------------------------------
-- File       : AxiPciePgpCardG3Core.vhd
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
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;
use work.AxiPkg.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;
use work.AxiPciePkg.all;

library unisim;
use unisim.vcomponents.all;

entity AxiPciePgpCardG3Core is
   generic (
      TPD_G            : time                   := 1 ns;
      AXI_ERROR_RESP_G : slv(1 downto 0)        := AXI_RESP_DECERR_C;
      DMA_SIZE_G       : positive range 1 to 16 := 1;
      AXIS_CONFIG_G    : AxiStreamConfigArray);
   port (
      -- System Clock and Reset
      sysClk       : out   sl;          -- 125 MHz
      sysRst       : out   sl;
      -- DMA Interfaces
      dmaClk       : in    slv(DMA_SIZE_G-1 downto 0);
      dmaRst       : in    slv(DMA_SIZE_G-1 downto 0);
      dmaObMasters : out   AxiStreamMasterArray(DMA_SIZE_G-1 downto 0);
      dmaObSlaves  : in    AxiStreamSlaveArray(DMA_SIZE_G-1 downto 0);
      dmaIbMasters : in    AxiStreamMasterArray(DMA_SIZE_G-1 downto 0);
      dmaIbSlaves  : out   AxiStreamSlaveArray(DMA_SIZE_G-1 downto 0);
      -- Boot Memory Ports 
      flashAddr    : out   slv(28 downto 0);
      flashData    : inout slv(15 downto 0);
      flashCe      : out   sl;
      flashOe      : out   sl;
      flashWe      : out   sl;
      -- PCIe Ports 
      pciRstL      : in    sl;
      pciRefClkP   : in    sl;
      pciRefClkN   : in    sl;
      pciRxP       : in    slv(3 downto 0);
      pciRxN       : in    slv(3 downto 0);
      pciTxP       : out   slv(3 downto 0);
      pciTxN       : out   slv(3 downto 0));        
end AxiPciePgpCardG3Core;

architecture mapping of AxiPciePgpCardG3Core is

   signal dmaReadMaster  : AxiReadMasterType;
   signal dmaReadSlave   : AxiReadSlaveType;
   signal dmaWriteMaster : AxiWriteMasterType;
   signal dmaWriteSlave  : AxiWriteSlaveType;

   signal regReadMaster  : AxiReadMasterType;
   signal regReadSlave   : AxiReadSlaveType;
   signal regWriteMaster : AxiWriteMasterType;
   signal regWriteSlave  : AxiWriteSlaveType;

   signal sysReadMasters  : AxiLiteReadMasterArray(1 downto 0);
   signal sysReadSlaves   : AxiLiteReadSlaveArray(1 downto 0);
   signal sysWriteMasters : AxiLiteWriteMasterArray(1 downto 0);
   signal sysWriteSlaves  : AxiLiteWriteSlaveArray(1 downto 0);

   signal interrupt : slv(DMA_SIZE_G-1 downto 0);
   signal flashDin  : slv(15 downto 0);
   signal flashDout : slv(15 downto 0);
   signal flashTri  : sl;

   signal axiClk : sl;
   signal axiRst : sl;
   signal dmaIrq : sl;
   
begin

   sysClk <= axiClk;
   sysRst <= axiRst;
   dmaIrq <= uOr(interrupt);

   ---------------
   -- AXI PCIe PHY
   ---------------   
   U_AxiPciePhy : entity work.AxiPciePgpCardG3IpCoreWrapper
      generic map (
         TPD_G => TPD_G)   
      port map (
         -- AXI4 Interfaces
         axiClk         => axiClk,
         axiRst         => axiRst,
         dmaReadMaster  => dmaReadMaster,
         dmaReadSlave   => dmaReadSlave,
         dmaWriteMaster => dmaWriteMaster,
         dmaWriteSlave  => dmaWriteSlave,
         regReadMaster  => regReadMaster,
         regReadSlave   => regReadSlave,
         regWriteMaster => regWriteMaster,
         regWriteSlave  => regWriteSlave,
         phyReadMaster  => sysReadMasters(1),
         phyReadSlave   => sysReadSlaves(1),
         phyWriteMaster => sysWriteMasters(1),
         phyWriteSlave  => sysWriteSlaves(1),
         -- Interrupt Interface
         dmaIrq         => dmaIrq,
         -- PCIe Ports 
         pciRstL        => pciRstL,
         pciRefClkP     => pciRefClkP,
         pciRefClkN     => pciRefClkN,
         pciRxP         => pciRxP,
         pciRxN         => pciRxN,
         pciTxP         => pciTxP,
         pciTxN         => pciTxN);

   ---------------
   -- AXI PCIe REG
   --------------- 
   U_REG : entity work.AxiPcieReg
      generic map (
         TPD_G            => TPD_G,
         AXI_CLK_FREQ_G   => 125.0E+6,  -- units of Hz
         AXI_ERROR_RESP_G => AXI_ERROR_RESP_G,
         XIL_DEVICE_G     => "7SERIES",
         DMA_SIZE_G       => DMA_SIZE_G)
      port map (
         -- AXI4 Interfaces
         axiClk          => axiClk,
         axiRst          => axiRst,
         regReadMaster   => regReadMaster,
         regReadSlave    => regReadSlave,
         regWriteMaster  => regWriteMaster,
         regWriteSlave   => regWriteSlave,
         sysReadMasters  => sysReadMasters,
         sysReadSlaves   => sysReadSlaves,
         sysWriteMasters => sysWriteMasters,
         sysWriteSlaves  => sysWriteSlaves,
         -- Interrupts
         interrupt       => interrupt,
         -- Boot Memory Ports 
         flashAddr       => flashAddr,
         flashCe         => flashCe,
         flashOe         => flashOe,
         flashWe         => flashWe,
         flashDin        => flashDin,
         flashDout       => flashDout,
         flashTri        => flashTri);       

   GEN_IOBUF :
   for i in 15 downto 0 generate
      IOBUF_inst : IOBUF
         port map (
            O  => flashDout(i),         -- Buffer output
            IO => flashData(i),         -- Buffer inout port (connect directly to top-level port)
            I  => flashDin(i),          -- Buffer input
            T  => flashTri);            -- 3-state enable input, high=input, low=output     
   end generate GEN_IOBUF;

   ---------------
   -- AXI PCIe DMA
   ---------------   
   U_AxiPcieDma : entity work.AxiPcieDma
      generic map (
         TPD_G            => TPD_G,
         DMA_SIZE_G       => DMA_SIZE_G,
         USE_IP_CORE_G    => false,
         AXI_ERROR_RESP_G => AXI_ERROR_RESP_G,
         AXIS_CONFIG_G    => AXIS_CONFIG_G)
      port map (
         -- Clock and reset
         axiClk          => axiClk,
         axiRst          => axiRst,
         -- AXI4 Interfaces
         axiReadMaster   => dmaReadMaster,
         axiReadSlave    => dmaReadSlave,
         axiWriteMaster  => dmaWriteMaster,
         axiWriteSlave   => dmaWriteSlave,
         -- AXI4-Lite Interfaces
         axilReadMaster  => sysReadMasters(0),
         axilReadSlave   => sysReadSlaves(0),
         axilWriteMaster => sysWriteMasters(0),
         axilWriteSlave  => sysWriteSlaves(0),
         -- Interrupts
         interrupt       => interrupt,
         -- DMA Interfaces
         dmaClk          => dmaClk,
         dmaRst          => dmaRst,
         dmaObMasters    => dmaObMasters,
         dmaObSlaves     => dmaObSlaves,
         dmaIbMasters    => dmaIbMasters,
         dmaIbSlaves     => dmaIbSlaves);          

end mapping;
