-------------------------------------------------------------------------------
-- Title      : 10G Ethernet MAC Core
-------------------------------------------------------------------------------
-- File       : XMacCore.vhd
-- Author     : Ryan Herbst <rherbst@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-02-12
-- Last update: 2015-02-12
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 10G Ethernet MAC Core
-------------------------------------------------------------------------------
-- This file is part of 'SLAC RCE 10G Ethernet Core'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'SLAC RCE 10G Ethernet Core', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.AxiStreamPkg.all;
use work.XMacPkg.all;
use work.StdRtlPkg.all;

entity XMacCore is
   -- Defaults:
   -- 9 bits = 4kbytes
   -- 255 x 8 = 2kbytes (not enough for pause)
   -- 11 bits = 16kbytes 
   generic (
      TPD_G           : time                := 1 ns;
      IB_ADDR_WIDTH_G : integer             := 11;
      OB_ADDR_WIDTH_G : integer             := 9;
      PAUSE_THOLD_G   : integer             := 512;
      VALID_THOLD_G   : integer             := 255;
      EOH_BIT_G       : integer             := 0;
      ERR_BIT_G       : integer             := 1;
      HEADER_SIZE_G   : integer             := 16;
      SHIFT_EN_G      : boolean             := false;
      AXIS_CONFIG_G   : AxiStreamConfigType := AXI_STREAM_CONFIG_INIT_C);      
   port (
      -- Streaming DMA Interface 
      dmaClk      : in  sl;
      dmaRst      : in  sl;
      dmaIbMaster : out AxiStreamMasterType;
      dmaIbSlave  : in  AxiStreamSlaveType;
      dmaObMaster : in  AxiStreamMasterType;
      dmaObSlave  : out AxiStreamSlaveType;
      -- PHY Interface
      phyClk      : in  sl;
      phyRst      : in  sl;
      phyReady    : in  sl;
      phyRxd      : in  slv(63 downto 0);
      phyRxc      : in  slv(7 downto 0);
      phyTxd      : out slv(63 downto 0);
      phyTxc      : out slv(7 downto 0);
      phyConfig   : in  XMacConfig;
      phyStatus   : out XMacStatus);
end XMacCore;

architecture mapping of XMacCore is

   signal rxPauseReq   : sl;
   signal rxPauseSet   : sl;
   signal rxPauseValue : slv(15 downto 0);

begin

   phyStatus.rxPauseReq   <= rxPauseReq;
   phyStatus.rxPauseSet   <= rxPauseSet;
   phyStatus.rxPauseValue <= rxPauseValue;

   ---------
   -- RX MAC
   ---------
   U_XMacImport : entity work.XMacImport
      generic map (
         TPD_G         => TPD_G,
         PAUSE_THOLD_G => PAUSE_THOLD_G,
         ADDR_WIDTH_G  => IB_ADDR_WIDTH_G,
         EOH_BIT_G     => EOH_BIT_G,
         ERR_BIT_G     => ERR_BIT_G,
         HEADER_SIZE_G => HEADER_SIZE_G,
         SHIFT_EN_G    => SHIFT_EN_G,
         AXIS_CONFIG_G => AXIS_CONFIG_G)
      port map (
         -- Streaming DMA Interface 
         dmaClk       => dmaClk,
         dmaClkRst    => dmaRst,
         dmaIbMaster  => dmaIbMaster,
         dmaIbSlave   => dmaIbSlave,
         -- PHY Interface
         phyClk       => phyClk,
         phyRst       => phyRst,
         phyRxd       => phyRxd,
         phyRxc       => phyRxc,
         phyReady     => phyReady,
         -- PHY Configuration
         macAddress   => phyConfig.macAddress,
         byteSwap     => phyConfig.byteSwap,
         rxShift      => phyConfig.rxShift,
         rxShiftEn    => phyConfig.rxShiftEn,
         -- PHY Pause Interface
         rxPauseReq   => rxPauseReq,
         rxPauseSet   => rxPauseSet,
         rxPauseValue => rxPauseValue,
         -- PHY Status         
         rxCountEn    => phyStatus.rxCountEn,
         rxOverFlow   => phyStatus.rxOverFlow,
         rxCrcError   => phyStatus.rxCrcError);

   ---------
   -- TX MAC
   ---------
   U_XMacExport : entity work.XMacExport
      generic map (
         TPD_G         => TPD_G,
         ADDR_WIDTH_G  => OB_ADDR_WIDTH_G,
         VALID_THOLD_G => VALID_THOLD_G,
         SHIFT_EN_G    => SHIFT_EN_G,
         AXIS_CONFIG_G => AXIS_CONFIG_G)
      port map (
         -- Streaming DMA Interface 
         dmaClk         => dmaClk,
         dmaClkRst      => dmaRst,
         dmaObMaster    => dmaObMaster,
         dmaObSlave     => dmaObSlave,
         -- PHY Interface
         phyClk         => phyClk,
         phyRst         => phyRst,
         phyTxd         => phyTxd,
         phyTxc         => phyTxc,
         phyReady       => phyReady,
         -- PHY Configuration
         interFrameGap  => phyConfig.txInterFrameGap,
         pauseTime      => phyConfig.txPauseTime,
         macAddress     => phyConfig.macAddress,
         byteSwap       => phyConfig.byteSwap,
         txShift        => phyConfig.txShift,
         txShiftEn      => phyConfig.txShiftEn,
         -- PHY Pause Interface
         rxPauseReq     => rxPauseReq,
         rxPauseSet     => rxPauseSet,
         rxPauseValue   => rxPauseValue,
         -- PHY Status
         txCountEn      => phyStatus.txCountEn,
         txUnderRun     => phyStatus.txUnderRun,
         txLinkNotReady => phyStatus.txLinkNotReady);

end architecture mapping;
