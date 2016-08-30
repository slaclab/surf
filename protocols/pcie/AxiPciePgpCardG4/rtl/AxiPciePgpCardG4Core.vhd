-------------------------------------------------------------------------------
-- Title      : PgpCardG4 Wrapper for AXI PCIe Core
-------------------------------------------------------------------------------
-- File       : AxiPciePgpCardG4Core.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-02-12
-- Last update: 2016-02-16
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

entity AxiPciePgpCardG4Core is
   generic (
      TPD_G         : time                   := 1 ns;
      DMA_SIZE_G    : positive range 1 to 16 := 1;
      AXIS_CONFIG_G : AxiStreamConfigArray);
   port (
      -- System Clock and Reset
      sysClk       : out   sl;          -- 250 MHz
      sysRst       : out   sl;
      -- DMA Interfaces
      dmaClk       : in    slv(DMA_SIZE_G-1 downto 0);
      dmaRst       : in    slv(DMA_SIZE_G-1 downto 0);
      dmaObMasters : out   AxiStreamMasterArray(DMA_SIZE_G-1 downto 0);
      dmaObSlaves  : in    AxiStreamSlaveArray(DMA_SIZE_G-1 downto 0);
      dmaIbMasters : in    AxiStreamMasterArray(DMA_SIZE_G-1 downto 0);
      dmaIbSlaves  : out   AxiStreamSlaveArray(DMA_SIZE_G-1 downto 0);
      -- Boot Memory Ports 
      flashAddr    : out   slv(23 downto 0);
      flashData    : inout slv(15 downto 4);
      flashOe      : out   sl;
      flashWe      : out   sl;
      -- PCIe Ports 
      pciRstL      : in    sl;
      pciRefClkP   : in    sl;
      pciRefClkN   : in    sl;
      pciRxP       : in    slv(7 downto 0);
      pciRxN       : in    slv(7 downto 0);
      pciTxP       : out   slv(7 downto 0);
      pciTxN       : out   slv(7 downto 0));        
end AxiPciePgpCardG4Core;

architecture mapping of AxiPciePgpCardG4Core is

   constant AXI_ERROR_RESP_C : slv(1 downto 0) := AXI_RESP_OK_C;  -- Always return OK to a MMAP()

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

   signal interrupt    : slv(DMA_SIZE_G-1 downto 0);
   signal flashAddress : slv(28 downto 0);
   signal flashDin     : slv(15 downto 0);
   signal flashDout    : slv(15 downto 0);
   signal flashTri     : sl;

   signal axiClk  : sl;
   signal axiRst  : sl;
   signal dmaIrq  : sl;
   signal flashCe : sl;
   
begin

   sysClk <= axiClk;
   sysRst <= axiRst;
   dmaIrq <= uOr(interrupt);

   ---------------
   -- AXI PCIe PHY
   ---------------   
   U_AxiPciePhy : entity work.AxiPciePgpCardG4IpCoreWrapper
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
         AXI_CLK_FREQ_G   => 250.0E+6,  -- units of Hz
         AXI_ERROR_RESP_G => AXI_ERROR_RESP_C,
         XIL_DEVICE_G     => "ULTRASCALE",
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
         flashAddr       => flashAddress,
         flashCe         => flashCe,
         flashOe         => flashOe,
         flashWe         => flashWe,
         flashDin        => flashDin,
         flashDout       => flashDout,
         flashTri        => flashTri);

   flashAddr <= flashAddress(23 downto 0);

   U_STARTUPE3 : STARTUPE3
      generic map (
         PROG_USR      => "FALSE",  -- Activate program event security feature. Requires encrypted bitstreams.
         SIM_CCLK_FREQ => 0.0)          -- Set the Configuration Clock Frequency(ns) for simulation
      port map (
         CFGCLK    => open,             -- 1-bit output: Configuration main clock output
         CFGMCLK   => open,  -- 1-bit output: Configuration internal oscillator clock output
         DI        => flashDout(3 downto 0),  -- 4-bit output: Allow receiving on the D[3:0] input pins
         EOS       => open,  -- 1-bit output: Active high output signal indicating the End Of Startup.
         PREQ      => open,             -- 1-bit output: PROGRAM request to fabric output         
         DO        => flashDin(3 downto 0),  -- 4-bit input: Allows control of the D[3:0] pin outputs
         DTS       => (others => flashTri),  -- 4-bit input: Allows tristate of the D[3:0] pins
         FCSBO     => flashCe,          -- 1-bit input: Contols the FCS_B pin for flash access
         FCSBTS    => '0',              -- 1-bit input: Tristate the FCS_B pin
         GSR       => '0',  -- 1-bit input: Global Set/Reset input (GSR cannot be used for the port name)
         GTS       => '0',  -- 1-bit input: Global 3-state input (GTS cannot be used for the port name)
         KEYCLEARB => '0',  -- 1-bit input: Clear AES Decrypter Key input from Battery-Backed RAM (BBRAM)
         PACK      => '0',              -- 1-bit input: PROGRAM acknowledge input
         USRCCLKO  => '1',              -- 1-bit input: User CCLK input
         USRCCLKTS => '1',              -- 1-bit input: User CCLK 3-state enable input
         USRDONEO  => '1',              -- 1-bit input: User DONE pin output control
         USRDONETS => '1');  -- 1-bit input: User DONE 3-state enable output              

   GEN_IOBUF :
   for i in 15 downto 4 generate
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
         USE_IP_CORE_G    => true,
         AXI_ERROR_RESP_G => AXI_ERROR_RESP_C,
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
