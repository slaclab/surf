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

entity SsiPcieAxiLite is
   generic (
      TPD_G            : time                   := 1 ns;
      DMA_SIZE_G       : positive range 1 to 16 := 1;
      BAR_SIZE_G       : positive range 1 to 4  := 1;
      BAR_MASK_G       : Slv32Array(3 downto 0) := (others => x"FFF00000"));
   port (
      -- System Signals
      serialNumber        : in  slv(63 downto 0);
      cardRst             : out sl;
      -- External AXI-Lite Interface
      mAxiLiteWriteMaster : out AxiLiteWriteMasterArray(BAR_SIZE_G-1 downto 0);
      mAxiLiteWriteSlave  : in  AxiLiteWriteSlaveArray(BAR_SIZE_G-1 downto 0);
      mAxiLiteReadMaster  : out AxiLiteReadMasterArray(BAR_SIZE_G-1 downto 0);
      mAxiLiteReadSlave   : in  AxiLiteReadSlaveArray(BAR_SIZE_G-1 downto 0);
      -- PCIe Interface
      irqEnable           : in  slv(BAR_SIZE_G-1 downto 0);
      irqReq              : in  slv(BAR_SIZE_G-1 downto 0);
      irqActive           : in  sl;
      cfgFromPci          : in  PcieCfgOutType;
      regTranFromPci      : in  TranFromPcieType;
      regObMaster         : in  AxiStreamMasterType;
      regObSlave          : out AxiStreamSlaveType;
      regIbMaster         : out AxiStreamMasterType;
      regIbSlave          : in  AxiStreamSlaveType;
      -- Clock and Resets
      pciClk              : in  sl;
      pciRst              : in  sl);
end SsiPcieAxiLite;

architecture mapping of SsiPcieAxiLite is

   signal axiReadMaster  : AxiLiteReadMasterType;
   signal axiReadSlave   : AxiLiteReadSlaveType;
   signal axiWriteMaster : AxiLiteWriteMasterType;
   signal axiWriteSlave  : AxiLiteWriteSlaveType;
   
begin

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
         mIntWriteMaster => axiWriteMaster,
         mIntWriteSlave  => axiWriteSlave,
         mIntReadMaster  => axiReadMaster,
         mIntReadSlave   => axiReadSlave,
         -- Global Signals
         pciClk          => pciClk,
         pciRst          => pciRst);
       
   -----------------------
   -- PCI System Module
   -----------------------
   SsiPcieSysReg_Inst : entity work.SsiPcieSysReg
      generic map (
         TPD_G            => TPD_G,
         DMA_SIZE_G       => DMA_SIZE_G,
         BAR_SIZE_G       => BAR_SIZE_G,
         BAR_MASK_G       => BAR_MASK_G)
      port map (
         -- PCIe Interface
         irqEnable      => irqEnable,
         irqReq         => irqReq,       
         irqActive      => irqActive,
         cfgFromPci     => cfgFromPci,
         -- AXI-Lite Register Interface
         axiReadMaster  => axiReadMaster,
         axiReadSlave   => axiReadSlave,
         axiWriteMaster => axiWriteMaster,
         axiWriteSlave  => axiWriteSlave,
         -- System Signals
         serialNumber   => serialNumber,
         cardRst        => cardRst,
         -- Global Signals
         pciClk         => pciClk,
         pciRst         => pciRst);            
         
end mapping;
