-------------------------------------------------------------------------------
-- Title      : AXI-4 Package File
-------------------------------------------------------------------------------
-- File       : AxiPkg.vhd
-- Author     : Ryan Herbst <rherbst@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-04-02
-- Last update: 2015-10-02
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Package file for AXI Busses
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
   end record AxiConfigType;

   constant AXI_CONFIG_INIT_C : AxiConfigType := (
      ADDR_WIDTH_C => 32,
      DATA_BYTES_C => 4,
      ID_BITS_C    => 12);

   function ite(i : boolean; t : AxiConfigType; e : AxiConfigType) return AxiConfigType;

end package AxiPkg;

package body AxiPkg is

   function ite (i : boolean; t : AxiConfigType; e : AxiConfigType) return AxiConfigType is
   begin
      if (i) then return t; else return e; end if;
   end function ite;

end package body AxiPkg;
