-------------------------------------------------------------------------------
-- File       : AxiPkg.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-04-02
-- Last update: 2016-04-26
-------------------------------------------------------------------------------
-- Description: AXI4 Package File
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
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;

package AxiPkg is

   -------------------------------------
   -- AXI bus, read master signal record
   -------------------------------------
   type AxiReadMasterType is record
      -- Read Address channel
      arvalid  : sl;                    -- Address valid
      araddr   : slv(63 downto 0);      -- Address
      arid     : slv(31 downto 0);      -- Address ID
      arlen    : slv(7 downto 0);       -- Transfer count
      arsize   : slv(2 downto 0);       -- Bytes per transfer
      arburst  : slv(1 downto 0);       -- Burst Type
      arlock   : slv(1 downto 0);       -- Lock control
      arprot   : slv(2 downto 0);       -- Protection control
      arcache  : slv(3 downto 0);       -- Cache control
      arqos    : slv(3 downto 0);       -- QoS value                                        
      arregion : slv(3 downto 0);       -- Region identifier                                       
      -- Read data channel
      rready   : sl;                    -- Master is ready for data
   end record;
   type AxiReadMasterArray is array (natural range<>) of AxiReadMasterType;
   constant AXI_READ_MASTER_INIT_C : AxiReadMasterType := (
      arvalid  => '0',
      araddr   => (others => '0'),
      arid     => (others => '0'),
      arlen    => (others => '0'),
      arsize   => (others => '0'),
      arburst  => (others => '0'),
      arlock   => (others => '0'),
      arprot   => (others => '0'),
      arcache  => (others => '0'),
      arqos    => (others => '0'),
      arregion => (others => '0'),
      rready   => '0');
   constant AXI_READ_MASTER_FORCE_C : AxiReadMasterType := (
      arvalid  => '0',
      araddr   => (others => '0'),
      arid     => (others => '0'),
      arlen    => (others => '0'),
      arsize   => (others => '0'),
      arburst  => (others => '0'),
      arlock   => (others => '0'),
      arprot   => (others => '0'),
      arcache  => (others => '0'),
      arqos    => (others => '0'),
      arregion => (others => '0'),
      rready   => '1');

   ------------------------------------
   -- AXI bus, read slave signal record
   ------------------------------------
   type AxiReadSlaveType is record
      -- Read Address channel
      arready : sl;                     -- Slave is ready for address
      -- Read data channel
      rdata   : slv(1023 downto 0);     -- Read data from slave
      rlast   : sl;                     -- Read data last strobe
      rvalid  : sl;                     -- Read data is valid
      rid     : slv(31 downto 0);       -- Read ID tag
      rresp   : slv(1 downto 0);        -- Read data result
   end record;
   type AxiReadSlaveArray is array (natural range<>) of AxiReadSlaveType;
   constant AXI_READ_SLAVE_INIT_C : AxiReadSlaveType := (
      arready => '0',
      rdata   => (others => '0'),
      rlast   => '0',
      rvalid  => '0',
      rid     => (others => '0'),
      rresp   => (others => '0'));
   constant AXI_READ_SLAVE_FORCE_C : AxiReadSlaveType := (
      arready => '1',
      rdata   => (others => '0'),
      rlast   => '0',
      rvalid  => '0',
      rid     => (others => '0'),
      rresp   => (others => '0'));

   --------------------------------------
   -- AXI bus, write master signal record
   --------------------------------------
   type AxiWriteMasterType is record
      -- Write address channel
      awvalid  : sl;                    -- Address valid
      awaddr   : slv(63 downto 0);      -- Address
      awid     : slv(31 downto 0);      -- Address ID
      awlen    : slv(7 downto 0);       -- Transfer count (burst length)
      awsize   : slv(2 downto 0);       -- Bytes per transfer
      awburst  : slv(1 downto 0);       -- Burst Type
      awlock   : slv(1 downto 0);       -- Lock control
      awprot   : slv(2 downto 0);       -- Protection control
      awcache  : slv(3 downto 0);       -- Cache control
      awqos    : slv(3 downto 0);       -- QoS value                                        
      awregion : slv(3 downto 0);       -- Region identifier                                       
      -- Write data channel
      wdata    : slv(1023 downto 0);    -- Write data
      wlast    : sl;                    -- Write data is last
      wvalid   : sl;                    -- Write data is valid
      wid      : slv(31 downto 0);      -- Write ID tag
      wstrb    : slv(127 downto 0);     -- Write enable strobes, 1 per byte
      -- Write ack channel
      bready   : sl;                    -- Write master is ready for status
   end record;
   type AxiWriteMasterArray is array (natural range<>) of AxiWriteMasterType;
   constant AXI_WRITE_MASTER_INIT_C : AxiWriteMasterType := (
      awvalid  => '0',
      awaddr   => (others => '0'),
      awid     => (others => '0'),
      awlen    => (others => '0'),
      awsize   => (others => '0'),
      awburst  => (others => '0'),
      awlock   => (others => '0'),
      awprot   => (others => '0'),
      awcache  => (others => '0'),
      awqos    => (others => '0'),
      awregion => (others => '0'),
      wdata    => (others => '0'),
      wlast    => '0',
      wvalid   => '0',
      wid      => (others => '0'),
      wstrb    => (others => '0'),
      bready   => '0');
   constant AXI_WRITE_MASTER_FORCE_C : AxiWriteMasterType := (
      awvalid  => '0',
      awaddr   => (others => '0'),
      awid     => (others => '0'),
      awlen    => (others => '0'),
      awsize   => (others => '0'),
      awburst  => (others => '0'),
      awlock   => (others => '0'),
      awprot   => (others => '0'),
      awcache  => (others => '0'),
      awqos    => (others => '0'),
      awregion => (others => '0'),
      wdata    => (others => '0'),
      wlast    => '0',
      wvalid   => '0',
      wid      => (others => '0'),
      wstrb    => (others => '0'),
      bready   => '1');

   -------------------------------------
   -- AXI bus, write slave signal record
   -------------------------------------
   type AxiWriteSlaveType is record
      -- Write address channel
      awready : sl;                     -- Write slave is ready for address
      -- Write data channel
      wready  : sl;                     -- Write slave is ready for data
      -- Write ack channel
      bresp   : slv(1 downto 0);        -- Write access status
      bvalid  : sl;                     -- Write status valid
      bid     : slv(31 downto 0);       -- Channel ID
   end record;
   type AxiWriteSlaveArray is array (natural range<>) of AxiWriteSlaveType;
   constant AXI_WRITE_SLAVE_INIT_C : AxiWriteSlaveType := (
      awready => '0',
      wready  => '0',
      bresp   => (others => '0'),
      bvalid  => '0',
      bid     => (others => '0'));
   constant AXI_WRITE_SLAVE_FORCE_C : AxiWriteSlaveType := (
      awready => '1',
      wready  => '1',
      bresp   => (others => '0'),
      bvalid  => '0',
      bid     => (others => '0'));

   ------------------------
   -- AXI bus, fifo control
   ------------------------
   type AxiCtrlType is record
      pause    : sl;
      overflow : sl;
   end record AxiCtrlType;
   type AxiCtrlArray is array (natural range<>) of AxiCtrlType;
   constant AXI_CTRL_INIT_C : AxiCtrlType := (
      pause    => '1',
      overflow => '0');
   constant AXI_CTRL_UNUSED_C : AxiCtrlType := (
      pause    => '0',
      overflow => '0');

   ------------------------
   -- AXI bus configuration
   ------------------------
   type AxiConfigType is record
      ADDR_WIDTH_C : positive range 12 to 64;
      DATA_BYTES_C : positive range 1 to 128;
      ID_BITS_C    : positive range 1 to 32;
      LEN_BITS_C   : natural range 0 to 8;
   end record AxiConfigType;

   function axiConfig (
      constant ADDR_WIDTH_C : in positive range 12 to 64 := 32;
      constant DATA_BYTES_C : in positive range 1 to 128 := 4;
      constant ID_BITS_C    : in positive range 1 to 32  := 12;
      constant LEN_BITS_C   : in natural range 0 to 8   := 4)
      return AxiConfigType;

   constant AXI_CONFIG_INIT_C : AxiConfigType := axiConfig(
      ADDR_WIDTH_C => 32,
      DATA_BYTES_C => 4,
      ID_BITS_C    => 12,
      LEN_BITS_C   => 4);

   function axiWriteMasterInit (
      constant AXI_CONFIG_C : in AxiConfigType;
      bready                : in sl              := '0';
      constant AXI_BURST_C  : in slv(1 downto 0) := "01";
      constant AXI_CACHE_C  : in slv(3 downto 0) := "1111")

      return AxiWriteMasterType;

   function axiReadMasterInit (
      constant AXI_CONFIG_C : in AxiConfigType;
      constant AXI_BURST_C  : in slv(1 downto 0) := "01";
      constant AXI_CACHE_C  : in slv(3 downto 0) := "1111")
      return AxiReadMasterType;

   function ite(i : boolean; t : AxiConfigType; e : AxiConfigType) return AxiConfigType;

   -- Calculate number of txns in a burst based on number of bytes and bus configuration
   -- Returned value is number of txns-1, so can be assigned to AWLEN/ARLEN
   function getAxiLen (
      axiConfig  : AxiConfigType;
      burstBytes : integer range 1 to 4096 := 4096)
      return slv;

   -- Calculate number of txns in a burst based upon burst size, total remaining bytes,
   -- current address and bus configuration.
   -- Address is used to set a transaction size aligned to 4k boundaries
   -- Returned value is number of txns-1, so can be assigned to AWLEN/ARLEN
   function getAxiLen (
      axiConfig  : AxiConfigType;
      burstBytes : integer range 1 to 4096 := 4096;
      totalBytes : slv;
      address    : slv)
      return slv;

   -- Caclulate the byte count for a read request
   function getAxiReadBytes (
      axiConfig  : AxiConfigType;
      axiRead    : AxiReadMasterType)
      return slv;

end package AxiPkg;

package body AxiPkg is

   function axiConfig (
      constant ADDR_WIDTH_C : in positive range 12 to 64 := 32;
      constant DATA_BYTES_C : in positive range 1 to 128 := 4;
      constant ID_BITS_C    : in positive range 1 to 32  := 12;
      constant LEN_BITS_C   : in natural range 0 to 8   := 4)
      return AxiConfigType is
      variable ret : AxiConfigType;
   begin
      ret := (
         ADDR_WIDTH_C => ADDR_WIDTH_C,
         DATA_BYTES_C => DATA_BYTES_C,
         ID_BITS_C    => ID_BITS_C,
         LEN_BITS_C   => LEN_BITS_C);
      return ret;
   end function axiConfig;

   function axiWriteMasterInit (
      constant AXI_CONFIG_C : in AxiConfigType;
      bready                : in sl              := '0';
      constant AXI_BURST_C  : in slv(1 downto 0) := "01";
      constant AXI_CACHE_C  : in slv(3 downto 0) := "1111")
      return AxiWriteMasterType is
      variable ret : AxiWriteMasterType;
   begin
      ret         := AXI_WRITE_MASTER_INIT_C;
      ret.awsize  := toSlv(log2(AXI_CONFIG_C.DATA_BYTES_C), 3);
      ret.awlen   := getAxiLen(AXI_CONFIG_C, 4096);
      ret.bready  := bready;
      ret.awburst := AXI_BURST_C;
      ret.awcache := AXI_CACHE_C;
      return ret;
   end function axiWriteMasterInit;

   function axiReadMasterInit (
      constant AXI_CONFIG_C : in AxiConfigType;
      constant AXI_BURST_C  : in slv(1 downto 0) := "01";
      constant AXI_CACHE_C  : in slv(3 downto 0) := "1111")
      return AxiReadMasterType is
      variable ret : AxiReadMasterType;
   begin
      ret         := AXI_READ_MASTER_INIT_C;
      ret.arsize  := toSlv(log2(AXI_CONFIG_C.DATA_BYTES_C), 3);
      ret.arlen   := getAxiLen(AXI_CONFIG_C, 4096);
      ret.arburst := AXI_BURST_C;
      ret.arcache := AXI_CACHE_C;
      return ret;
   end function axiReadMasterInit;

   function ite (i : boolean; t : AxiConfigType; e : AxiConfigType) return AxiConfigType is
   begin
      if (i) then return t; else return e; end if;
   end function ite;

   function getAxiLen (
      axiConfig  : AxiConfigType;
      burstBytes : integer range 1 to 4096 := 4096)
      return slv is
   begin
      -- burstBytes / data bytes width is number of txns required.
      -- Subtract by 1 for A*LEN value for even divides.
      -- Convert to SLV and truncate to size of A*LEN port for this AXI bus
      -- This limits number of txns appropriately based on size of len port
      -- Then resize to 8 bits because our records define A*LEN as 8 bits always.
      return resize(toSlv(wordCount(burstBytes,axiConfig.DATA_BYTES_C)-1, axiConfig.LEN_BITS_C), 8);
   end function getAxiLen;

   -- Calculate number of txns in a burst based upon burst size, total remaining bytes,
   -- current address and bus configuration.
   -- Address is used to set a transaction size aligned to 4k boundaries
   -- Returned value is number of txns-1, so can be assigned to AWLEN/ARLEN
   function getAxiLen (
      axiConfig  : AxiConfigType;
      burstBytes : integer range 1 to 4096 := 4096;
      totalBytes : slv;
      address    : slv)
      return slv is
      variable max  : natural;
      variable req  : natural;
      variable min  : natural;
      variable maxLen : slv(7 downto 0);
   begin

      -- Check for 4kB boundary
      max := 4096 - conv_integer(address(11 downto 0));
      
      -- Check the SLV range to prevent negative integer during typecasting 
      if (totalBytes'HIGH >= 31) then
         -- Check if the upper bits are non-zero
         if (totalBytes(totalBytes'HIGH downto 31) /= 0) then
            req := burstBytes;      
         else
            req := minimum(conv_integer(totalBytes(30 downto 0)),burstBytes);      
         end if;
      else
         req := minimum(conv_integer(totalBytes),burstBytes);      
      end if;
      
      -- Find the minimum value between the request and max size
      min  := minimum(req,max);
      
      -- -- Debug prints for simulation
      -- assert false report "burstBytes = " & integer'image(burstBytes) severity note;
      -- assert false report "max = " & integer'image(max) severity note;
      -- assert false report "req = " & integer'image(req) severity note;
      -- assert false report "min = " & integer'image(min) severity note;

      -- Return the AXI Length value
      return getAxiLen(axiConfig,min);

   end function getAxiLen;

   -- Calculate the byte count for a read request
   function getAxiReadBytes (
      axiConfig  : AxiConfigType;
      axiRead    : AxiReadMasterType)
      return slv is
      constant addrLsb : natural := bitSize(AxiConfig.DATA_BYTES_C-1);
      variable tempSlv : slv(AxiConfig.LEN_BITS_C+addrLsb downto 0);
   begin
      tempSlv := (others=>'0');

      tempSlv(AxiConfig.LEN_BITS_C+addrLsb downto addrLsb) 
         := axiRead.arlen(AxiConfig.LEN_BITS_C-1 downto 0) + toSlv(1,AxiConfig.LEN_BITS_C+1);

      tempSlv := tempSlv - axiRead.araddr(addrLsb-1 downto 0);

      return(tempSlv);
   end function getAxiReadBytes;

end package body AxiPkg;

