-------------------------------------------------------------------------------
-- Title         : AXI-4 Package File
-- File          : AxiPkg.vhd
-- Author        : Ryan Herbst, rherbst@slac.stanford.edu
-- Created       : 04/02/2013
-------------------------------------------------------------------------------
-- Description:
-- Package file for AXI Busses
-------------------------------------------------------------------------------
-- Copyright (c) 2013 by Ryan Herbst. All rights reserved.
-------------------------------------------------------------------------------
-- Modification history:
-- 04/02/2013: created.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

use work.StdRtlPkg.all;

package AxiPkg is

   --------------------------------------------------------
   -- AXI bus, read master signal record
   --------------------------------------------------------

   -- Base Record
   type AxiReadMasterType is record

      -- Read Address channel
      arvalid        : sl;               -- Address valid
      araddr         : slv(31 downto 0); -- Address
      arid           : slv(11 downto 0); -- Channel ID
                                         -- 12 bits for master GP
                                         -- 6  bits for slave GP
                                         -- 3  bits for ACP
                                         -- 6  bits for HP
      arlen          : slv(3  downto 0); -- Transfer count, 0x0=1, 0xF=16
      arsize         : slv(2  downto 0); -- Bytes per transfer, 0x0=1, 0x7=8
      arburst        : slv(1  downto 0); -- Burst Type
                                         -- 0x0 = Fixed address
                                         -- 0x1 = Incrementing address
                                         -- 0x2 = Wrap at cache boundary
      arlock         : slv(1  downto 0); -- Lock control
                                         -- 0x0 = Normal access
                                         -- 0x1 = Exclusive access
                                         -- 0x2 = Locked access
      arprot         : slv(2  downto 0); -- Protection control
                                         -- Bit 0 : 0 = Normal, 1 = Priveleged
                                         -- Bit 1 : 0 = Secure, 1 = Non-secure
                                         -- Bit 2 : 0 = Data access, 1 = Instruction
      arcache        : slv(3  downto 0); -- Cache control
                                         -- Bit 0 : Bufferable
                                         -- Bit 1 : Cachable  
                                         -- Bit 2 : Read allocate enable
                                         -- Bit 3 : Write allocate enable

      -- Read data channel
      rready         : sl;               -- Master is ready for data

   end record;

   -- Initialization constants
   constant AXI_READ_MASTER_INIT_C : AxiReadMasterType := ( 
      arvalid        => '0',
      araddr         => x"00000000",
      arid           => x"000",
      arlen          => "0000",
      arsize         => "000",
      arburst        => "00",
      arlock         => "00",
      arprot         => "000",
      arcache        => "0000",
      rready         => '0'
   );

   -- Array
   type AxiReadMasterArray is array (natural range<>) of AxiReadMasterType;


   --------------------------------------------------------
   -- AXI bus, read slave signal record
   --------------------------------------------------------

   -- Base Record
   type AxiReadSlaveType is record

      -- Read Address channel
      arready : sl;               -- Slave is ready for address

      -- Read data channel
      rdata   : slv(63 downto 0); -- Read data from slave
                                  -- 32 bits for GP ports
                                  -- 64 bits for other ports
      rlast   : sl;               -- Read data last strobe
      rvalid  : sl;               -- Read data is valid
      rid     : slv(11 downto 0); -- Read data ID
                                  -- 12 for master GP 
                                  -- 6 for slave GP 
                                  -- 3 for ACP 
                                  -- 6 for HP
      rresp   : slv(1  downto 0); -- Read data result
                                  -- 0x0 = Okay
                                  -- 0x1 = Exclusive access okay
                                  -- 0x2 = Slave indicated error 
                                  -- 0x3 = Decode error

   end record;

   -- Initialization constants
   constant AXI_READ_SLAVE_INIT_C : AxiReadSlaveType := ( 
      arready => '0',
      rdata   => x"0000000000000000",
      rlast   => '0',
      rvalid  => '0',
      rid     => x"000",
      rresp   => "00"
   );

   -- Array
   type AxiReadSlaveArray is array (natural range<>) of AxiReadSlaveType;


   --------------------------------------------------------
   -- AXI bus, write master signal record
   --------------------------------------------------------

   -- Base Record
   type AxiWriteMasterType is record

      -- Write address channel
      awvalid        : sl;               -- Write address is valid
      awaddr         : slv(31 downto 0); -- Write address
      awid           : slv(11 downto 0); -- Channel ID
                                         -- 12 bits for master GP
                                         -- 6  bits for slave GP
                                         -- 3  bits for ACP
                                         -- 6  bits for HP
      awlen          : slv(3  downto 0); -- Transfer count, 0x0=1, 0xF=16
      awsize         : slv(2  downto 0); -- Bytes per transfer, 0x0=1, 0x7=8
      awburst        : slv(1  downto 0); -- Burst Type
                                         -- 0x0 = Fixed address
                                         -- 0x1 = Incrementing address
                                         -- 0x2 = Wrap at cache boundary
      awlock         : slv(1  downto 0); -- Lock control
                                         -- 0x0 = Normal access
                                         -- 0x1 = Exclusive access
                                         -- 0x2 = Locked access
      awprot         : slv(2  downto 0); -- Protection control
                                         -- Bit 0 : 0 = Normal, 1 = Priveleged
                                         -- Bit 1 : 0 = Secure, 1 = Non-secure
                                         -- Bit 2 : 0 = Data access, 1 = Instruction
      awcache        : slv(3  downto 0); -- Cache control
                                         -- Bit 0 : Bufferable
                                         -- Bit 1 : Cachable  
                                         -- Bit 2 : Read allocate enable
                                         -- Bit 3 : Write allocate enable

      -- Write data channel
      wdata          : slv(63 downto 0); -- Write data
                                         -- 32-bits for master and slave GP
                                         -- 64-bit for others
      wlast          : sl;               -- Write data is last
      wvalid         : sl;               -- Write data is valid
      wstrb          : slv(7  downto 0); -- Write enable strobes, 1 per byte
                                         -- 4-bits for master and slave GP
                                         -- 8-bits for others
      wid            : slv(11 downto 0); -- Channel ID
                                         -- 12 bits for master GP
                                         -- 6  bits for slave GP
                                         -- 3  bits for ACP
                                         -- 6  bits for HP

      -- Write ack channel
      bready         : sl;               -- Write master is ready for status

   end record;

   -- Initialization constants
   constant AXI_WRITE_MASTER_INIT_C : AxiWriteMasterType := ( 
      awvalid        => '0',
      awaddr         => x"00000000",
      awid           => x"000",
      awlen          => "0000",
      awsize         => "000",
      awburst        => "00",
      awlock         => "00",
      awcache        => "0000",
      awprot         => "000",
      wdata          => x"0000000000000000",
      wlast          => '0',
      wvalid         => '0',
      wid            => x"000",
      wstrb          => "00000000",
      bready         => '0'
   );

   -- Array
   type AxiWriteMasterArray is array (natural range<>) of AxiWriteMasterType;


   --------------------------------------------------------
   -- AXI bus, write slave signal record
   --------------------------------------------------------

   -- Base Record
   type AxiWriteSlaveType is record

      -- Write address channel
      awready : sl;               -- Write slave is ready for address

      -- Write data channel
      wready  : sl;               -- Write slave is ready for data

      -- Write ack channel
      bresp   : slv(1  downto 0); -- Write acess status
                                  -- 0x0 = Okay
                                  -- 0x1 = Exclusive access okay
                                  -- 0x2 = Slave indicated error 
                                  -- 0x3 = Decode error
      bvalid  : sl;               -- Write status valid
      bid     : slv(11 downto 0); -- Channel ID
                                  -- 12 bits for master GP
                                  -- 6  bits for slave GP
                                  -- 3  bits for ACP
                                  -- 6  bits for HP

   end record;

   -- Initialization constants
   constant AXI_WRITE_SLAVE_INIT_C : AxiWriteSlaveType := ( 
      awready => '0',
      wready  => '0',
      bresp   => "00",
      bvalid  => '0',
      bid     => x"000"
   );

   -- Array
   type AxiWriteSlaveArray is array (natural range<>) of AxiWriteSlaveType;


   --------------------------------------------------------
   -- AXI bus, fifo control
   --------------------------------------------------------

   type AxiCtrlType is record
      pause    : sl;
      overflow : sl;
   end record AxiCtrlType;

   constant AXI_CTRL_INIT_C : AxiCtrlType := (
      pause    => '1',
      overflow => '0');

   constant AXI_CTRL_UNUSED_C : AxiCtrlType := (
      pause    => '0',
      overflow => '0');

   type AxiCtrlArray is array (natural range<>) of AxiCtrlType;

   --------------------------------------------------------
   -- AXI bus configuration
   --------------------------------------------------------

   type AxiConfigType is record
      DATA_BYTES_C      : natural range 1 to 8;
      ID_BITS_C         : natural range 0 to 12;
   end record AxiConfigType;

   constant AXI_CONFIG_INIT_C : AxiConfigType := (
      DATA_BYTES_C      => 4,
      ID_BITS_C         => 12);

end AxiPkg;

