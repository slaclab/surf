-------------------------------------------------------------------------------
-- File       : RawEthFramerWrapper.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-05-23
-- Last update: 2016-05-26
-------------------------------------------------------------------------------
-- Description: Wrapper for RawEthFramer Module
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Firmware Standard Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'SLAC Firmware Standard Library', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;

entity RawEthFramerWrapper is
   generic (
      TPD_G            : time             := 1 ns;
      ETH_TYPE_G       : slv(15 downto 0) := x"0010";  --  0x1000 (big-Endian configuration)
      AXI_ERROR_RESP_G : slv(1 downto 0)  := AXI_RESP_DECERR_C);      
   port (
      -- Local Configurations
      localMac        : in  slv(47 downto 0);          --  big-Endian configuration
      -- Interface to Ethernet Media Access Controller (MAC)
      obMacMaster     : in  AxiStreamMasterType;
      obMacSlave      : out AxiStreamSlaveType;
      ibMacMaster     : out AxiStreamMasterType;
      ibMacSlave      : in  AxiStreamSlaveType;
      -- Interface to Application engine(s)
      ibAppMaster     : out AxiStreamMasterType;
      ibAppSlave      : in  AxiStreamSlaveType;
      obAppMaster     : in  AxiStreamMasterType;
      obAppSlave      : out AxiStreamSlaveType;
      -- AXI-Lite Interface
      axilReadMaster  : in  AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
      axilWriteSlave  : out AxiLiteWriteSlaveType;
      -- Clock and Reset
      clk             : in  sl;
      rst             : in  sl);
end RawEthFramerWrapper;

architecture mapping of RawEthFramerWrapper is

   signal tDest     : slv(7 downto 0);
   signal remoteMac : slv(47 downto 0);

begin

   -----------------------------
   -- Raw Ethernet Framer Engine
   -----------------------------
   U_Core : entity work.RawEthFramer
      generic map (
         TPD_G      => TPD_G,
         ETH_TYPE_G => ETH_TYPE_G) 
      port map (
         -- Local Configurations
         localMac    => localMac,
         remoteMac   => remoteMac,
         tDest       => tDest,
         -- Interface to Ethernet Media Access Controller (MAC)
         obMacMaster => obMacMaster,
         obMacSlave  => obMacSlave,
         ibMacMaster => ibMacMaster,
         ibMacSlave  => ibMacSlave,
         -- Interface to Application engine(s)
         ibAppMaster => ibAppMaster,
         ibAppSlave  => ibAppSlave,
         obAppMaster => obAppMaster,
         obAppSlave  => obAppSlave,
         -- Clock and Reset
         clk         => clk,
         rst         => rst); 

   -----------------
   -- Remote MAC LUT
   -----------------
   U_RemoteMacLut : entity work.AxiDualPortRam
      generic map (
         TPD_G            => TPD_G,
         BRAM_EN_G        => true,
         REG_EN_G         => false,
         MODE_G           => "read-first",
         AXI_WR_EN_G      => true,
         SYS_WR_EN_G      => false,
         SYS_BYTE_WR_EN_G => false,
         COMMON_CLK_G     => true,
         ADDR_WIDTH_G     => 8,
         DATA_WIDTH_G     => 48,
         INIT_G           => "0",
         AXI_ERROR_RESP_G => AXI_ERROR_RESP_G)
      port map (
         -- AXI-Lite Interface
         axiClk         => clk,
         axiRst         => rst,
         axiReadMaster  => axilReadMaster,
         axiReadSlave   => axilReadSlave,
         axiWriteMaster => axilWriteMaster,
         axiWriteSlave  => axilWriteSlave,
         -- Standard Port
         clk            => clk,
         rst            => rst,
         addr           => tDest,
         dout           => remoteMac);         

end mapping;
