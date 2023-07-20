-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: AXI-Lite Package File
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
use ieee.NUMERIC_STD.all;

library surf;
use surf.StdRtlPkg.all;
use surf.TextUtilPkg.all;

package AxiLitePkg is

   -------------------------------------------------------------------------------------------------
   -- AXI bus response codes
   -------------------------------------------------------------------------------------------------
   constant AXI_RESP_OK_C : slv(1 downto 0) := "00";  -- Access ok

   constant AXI_RESP_EXOKAY_C : slv(1 downto 0) := "01";  -- Exclusive access ok
   -- Note: There are no "exclusive access" in AXI-Lite.  This is just a placeholder constant.

   constant AXI_RESP_SLVERR_C : slv(1 downto 0) := "10";  -- Slave Error
   -- Note: A SLVERR response is returned to the master if the AXI peripheral interface receives any
   --       of the following unsupported accesses:
   --
   --          1) Any accesses with AWSIZE information other than 32-bit receives a SLVERR response.
   --          2) Any accesses with AWLEN information other than zero receives a SLVERR response.
   --          3) Any access that is unaligned, for example, where AWADDRP[1:0] is not equal to 2'b00,
   --             returns a SLVERR response where a read access returns all zeros and a write access
   --             does not modify the address location.
   --          4) Any write access that attempts to make use of the WSTRB lines,
   --             for example where any bits of WSTRB[3:0] are 0, returns a SLVERR response
   --             and does not modify the address location.

   constant AXI_RESP_DECERR_C : slv(1 downto 0) := "11";  -- Decode Error
   -- Note: Any transaction that does not decode to a legal master interface destination,
   --       or programmers view register, receives a DECERR response. For an AHB master,
   --       the AXI DECERR is mapped back to an AHB ERROR.

   --------------------------------------------------------
   -- AXI bus, read master signal record
   --------------------------------------------------------

   -- Base Record
   type AxiLiteReadMasterType is record
      -- Read Address channel
      araddr  : slv(31 downto 0);
      arprot  : slv(2 downto 0);
      arvalid : sl;
      -- Read data channel
      rready  : sl;
   end record;

   -- Initialization constants
   constant AXI_LITE_READ_MASTER_INIT_C : AxiLiteReadMasterType := (
      araddr  => (others => '0'),
      arprot  => (others => '0'),
      arvalid => '0',
      rready  => '1'
      );

   -- Array
   type AxiLiteReadMasterArray is array (natural range<>) of AxiLiteReadMasterType;


   --------------------------------------------------------
   -- AXI bus, read slave signal record
   --------------------------------------------------------

   -- Base Record
   type AxiLiteReadSlaveType is record
      -- Read Address channel
      arready : sl;
      -- Read data channel
      rdata   : slv(31 downto 0);
      rresp   : slv(1 downto 0);
      rvalid  : sl;
   end record;

   -- Initialization constants
   constant AXI_LITE_READ_SLAVE_INIT_C : AxiLiteReadSlaveType := (
      arready => '0',
      rdata   => (others => '0'),
      rresp   => (others => '0'),
      rvalid  => '0'
      );

   function axiLiteReadSlaveEmptyInit (
      rresp : slv(1 downto 0)  := AXI_RESP_OK_C;
      rdata : slv(31 downto 0) := (others => '0'))
      return AxiLiteReadSlaveType;

   constant AXI_LITE_READ_SLAVE_EMPTY_OK_C     : AxiLiteReadSlaveType := axiLiteReadSlaveEmptyInit(rresp => AXI_RESP_OK_C);
   constant AXI_LITE_READ_SLAVE_EMPTY_SLVERR_C : AxiLiteReadSlaveType := axiLiteReadSlaveEmptyInit(rresp => AXI_RESP_SLVERR_C);
   constant AXI_LITE_READ_SLAVE_EMPTY_DECERR_C : AxiLiteReadSlaveType := axiLiteReadSlaveEmptyInit(rresp => AXI_RESP_DECERR_C);

   -- Array
   type AxiLiteReadSlaveArray is array (natural range<>) of AxiLiteReadSlaveType;


   --------------------------------------------------------
   -- AXI bus, write master signal record
   --------------------------------------------------------

   -- Base Record
   type AxiLiteWriteMasterType is record
      -- Write address channel
      awaddr  : slv(31 downto 0);
      awprot  : slv(2 downto 0);
      awvalid : sl;
      -- Write data channel
      wdata   : slv(31 downto 0);
      wstrb   : slv(3 downto 0);
      wvalid  : sl;
      -- Write ack channel
      bready  : sl;
   end record;

   -- Initialization constants
   constant AXI_LITE_WRITE_MASTER_INIT_C : AxiLiteWriteMasterType := (
      awaddr  => (others => '0'),
      awprot  => (others => '0'),
      awvalid => '0',
      wdata   => (others => '0'),
      wstrb   => (others => '1'),
      wvalid  => '0',
      bready  => '1'
      );

   -- Array
   type AxiLiteWriteMasterArray is array (natural range<>) of AxiLiteWriteMasterType;


   --------------------------------------------------------
   -- AXI bus, write slave signal record
   --------------------------------------------------------

   -- Base Record
   type AxiLiteWriteSlaveType is record
      -- Write address channel
      awready : sl;
      -- Write data channel
      wready  : sl;
      -- Write ack channel
      bresp   : slv(1 downto 0);
      bvalid  : sl;

   end record;

   -- Initialization constants
   constant AXI_LITE_WRITE_SLAVE_INIT_C : AxiLiteWriteSlaveType := (
      awready => '0',
      wready  => '0',
      bresp   => (others => '0'),
      bvalid  => '0'
      );

   function axiLiteWriteSlaveEmptyInit (
      bresp : slv(1 downto 0) := AXI_RESP_OK_C)
      return AxiLiteWriteSlaveType;

   constant AXI_LITE_WRITE_SLAVE_EMPTY_OK_C     : AxiLiteWriteSlaveType := axiLiteWriteSlaveEmptyInit(bresp => AXI_RESP_OK_C);
   constant AXI_LITE_WRITE_SLAVE_EMPTY_SLVERR_C : AxiLiteWriteSlaveType := axiLiteWriteSlaveEmptyInit(bresp => AXI_RESP_SLVERR_C);
   constant AXI_LITE_WRITE_SLAVE_EMPTY_DECERR_C : AxiLiteWriteSlaveType := axiLiteWriteSlaveEmptyInit(bresp => AXI_RESP_DECERR_C);


   -- Array
   type AxiLiteWriteSlaveArray is array (natural range<>) of AxiLiteWriteSlaveType;

   type AxiLiteStatusType is record
      writeEnable : sl;
      readEnable  : sl;
   end record AxiLiteStatusType;

   constant AXI_LITE_STATUS_INIT_C : AxiLiteStatusType := (
      writeEnable => '0',
      readEnable  => '0');

   --------------------------------------------------------
   -- AXI bus, read/write endpoint record, RTH 1/27/2016
   --------------------------------------------------------
   type AxiLiteEndpointType is record
      axiReadMaster  : AxiLiteReadMasterType;
      axiReadSlave   : AxiLiteReadSlaveType;
      axiWriteMaster : AxiLiteWriteMasterType;
      axiWriteSlave  : AxiLiteWriteSlaveType;
      axiStatus      : AxiLiteStatusType;
   end record AxiLiteEndpointType;

   constant AXI_LITE_ENDPOINT_INIT_C : AxiLiteEndpointType := (
      axiReadMaster  => AXI_LITE_READ_MASTER_INIT_C,
      axiReadSlave   => AXI_LITE_READ_SLAVE_INIT_C,
      axiWriteMaster => AXI_LITE_WRITE_MASTER_INIT_C,
      axiWriteSlave  => AXI_LITE_WRITE_SLAVE_INIT_C,
      axiStatus      => AXI_LITE_STATUS_INIT_C);

   ----------------------------------------------------------------------------------
   -- Constants for endpoint abstractions (migrated from legacy AxiLiteMasterPkg.vhd)
   ----------------------------------------------------------------------------------
   type AxiLiteReqType is record
      request : sl;
      rnw     : sl;
      address : slv(31 downto 0);
      wrData  : slv(31 downto 0);
   end record AxiLiteReqType;

   constant AXI_LITE_REQ_INIT_C : AxiLiteReqType := (
      request => '0',
      rnw     => '1',
      address => (others => '0'),
      wrData  => (others => '0'));

   type AxiLiteAckType is record
      done   : sl;
      resp   : slv(1 downto 0);
      rdData : slv(31 downto 0);
   end record AxiLiteAckType;

   constant AXI_LITE_ACK_INIT_C : AxiLiteAckType := (
      done   => '0',
      resp   => (others => '0'),
      rdData => (others => '0'));

   -------------------------------------------------------------------------------------------------
   -- Crossbar Config Generic Types
   -------------------------------------------------------------------------------------------------
   type AxiLiteCrossbarMasterConfigType is record
      baseAddr     : slv(31 downto 0);
      addrBits     : natural range 1 to 32;
      connectivity : slv(15 downto 0);
   end record;

   type AxiLiteCrossbarMasterConfigArray is array (natural range <>) of AxiLiteCrossbarMasterConfigType;

   constant AXIL_XBAR_CFG_DEFAULT_C : AxiLiteCrossbarMasterConfigArray(0 to 3) := (
      0                  => (baseAddr => X"00000000",
            addrBits     => 16,
            connectivity => X"FFFF"),
      1                  => (baseAddr => X"00010000",
            addrBits     => 16,
            connectivity => X"FFFF"),
      2                  => (baseAddr => X"00020000",
            addrBits     => 16,
            connectivity => X"FFFF"),
      3                  => (baseAddr => X"00030000",
            addrBits     => 16,
            connectivity => X"FFFF"));

   -------------------------------------------------------------------------------------------------
   -- Initilize masters with uppder address bits already set to configuration base address
   -------------------------------------------------------------------------------------------------
   function axiWriteMasterInit (constant config : AxiLiteCrossbarMasterConfigArray) return AxiLiteWriteMasterArray;
   function axiWriteMasterInit (constant config : AxiLiteCrossbarMasterConfigType) return AxiLiteWriteMasterType;
   function axiReadMasterInit (constant config  : AxiLiteCrossbarMasterConfigArray) return AxiLiteReadMasterArray;
   function axiReadMasterInit (constant config  : AxiLiteCrossbarMasterConfigType) return AxiLiteReadMasterType;


   -------------------------------------------------------------------------------------------------
   -- Slave AXI Processing procedures
   -------------------------------------------------------------------------------------------------

   procedure axiSlaveWaitWriteTxn (
      signal axiWriteMaster  : in    AxiLiteWriteMasterType;
      variable axiWriteSlave : inout AxiLiteWriteSlaveType;
      variable writeEnable   : inout sl);

   procedure axiSlaveWaitReadTxn (
      signal axiReadMaster  : in    AxiLiteReadMasterType;
      variable axiReadSlave : inout AxiLiteReadSlaveType;
      variable readEnable   : inout sl);

   procedure axiSlaveWaitTxn (
      signal axiWriteMaster  : in    AxiLiteWriteMasterType;
      signal axiReadMaster   : in    AxiLiteReadMasterType;
      variable axiWriteSlave : inout AxiLiteWriteSlaveType;
      variable axiReadSlave  : inout AxiLiteReadSlaveType;
      variable axiStatus     : inout AxiLiteStatusType);

   procedure axiSlaveWriteResponse (
      variable axiWriteSlave : inout AxiLiteWriteSlaveType;
      axiResp                : in    slv(1 downto 0) := AXI_RESP_OK_C);

   procedure axiSlaveReadResponse (
      variable axiReadSlave : inout AxiLiteReadSlaveType;
      axiResp               : in    slv(1 downto 0) := AXI_RESP_OK_C);

   -------------------------------------------------------------------------------------------------
   -- Address decode procedures
   -------------------------------------------------------------------------------------------------
   procedure axiSlaveRegister (
      signal axiWriteMaster  : in    AxiLiteWriteMasterType;
      signal axiReadMaster   : in    AxiLiteReadMasterType;
      variable axiWriteSlave : inout AxiLiteWriteSlaveType;
      variable axiReadSlave  : inout AxiLiteReadSlaveType;
      variable axiStatus     : in    AxiLiteStatusType;
      addr                   : in    slv;
      offset                 : in    integer;
      reg                    : inout slv;
      constAssign            : in    boolean := false;
      constVal               : in    slv     := "0");

   procedure axiSlaveRegister (
      signal axiReadMaster  : in    AxiLiteReadMasterType;
      variable axiReadSlave : inout AxiLiteReadSlaveType;
      variable axiStatus    : in    AxiLiteStatusType;
      addr                  : in    slv;
      offset                : in    integer;
      reg                   : in    slv);

   procedure axiSlaveRegister (
      signal axiWriteMaster  : in    AxiLiteWriteMasterType;
      signal axiReadMaster   : in    AxiLiteReadMasterType;
      variable axiWriteSlave : inout AxiLiteWriteSlaveType;
      variable axiReadSlave  : inout AxiLiteReadSlaveType;
      variable axiStatus     : in    AxiLiteStatusType;
      addr                   : in    slv;
      offset                 : in    integer;
      reg                    : inout sl;
      constAssign            : in    boolean := false;
      constVal               : in    sl      := '0');

   procedure axiSlaveRegister (
      signal axiReadMaster  : in    AxiLiteReadMasterType;
      variable axiReadSlave : inout AxiLiteReadSlaveType;
      variable axiStatus    : in    AxiLiteStatusType;
      addr                  : in    slv;
      offset                : in    integer;
      reg                   : in    sl);

   procedure axiSlaveDefault (
      signal axiWriteMaster  : in    AxiLiteWriteMasterType;
      signal axiReadMaster   : in    AxiLiteReadMasterType;
      variable axiWriteSlave : inout AxiLiteWriteSlaveType;
      variable axiReadSlave  : inout AxiLiteReadSlaveType;
      variable axiStatus     : in    AxiLiteStatusType;
      axiResp                : in    slv(1 downto 0) := AXI_RESP_OK_C;
      extTxn                 : in    sl              := '0');


   -------------------------------------------------------------------------------------------------
   -- Simplified Address decode procedures, RTH 1/27/2016
   -------------------------------------------------------------------------------------------------
   procedure axiSlaveWaitTxn (
      variable ep            : inout AxiLiteEndpointType;
      signal axiWriteMaster  : in    AxiLiteWriteMasterType;
      signal axiReadMaster   : in    AxiLiteReadMasterType;
      variable axiWriteSlave : in    AxiLiteWriteSlaveType;
      variable axiReadSlave  : in    AxiLiteReadSlaveType);

   procedure axiSlaveRegister (
      variable ep : inout AxiLiteEndpointType;
      addr        : in    slv;
      offset      : in    integer;
      reg         : inout slv;
      constVal    : in    slv);

   procedure axiSlaveRegister (
      variable ep : inout AxiLiteEndpointType;
      addr        : in    slv;
      offset      : in    integer;
      reg         : inout slv);

   procedure axiSlaveRegisterR (
      variable ep : inout AxiLiteEndpointType;
      addr        : in    slv;
      offset      : in    integer;
      reg         : in    slv);

   procedure axiSlaveRegister (
      variable ep : inout AxiLiteEndpointType;
      addr        : in    slv;
      offset      : in    integer;
      reg         : inout sl;
      constVal    : in    sl);

   procedure axiSlaveRegister (
      variable ep : inout AxiLiteEndpointType;
      addr        : in    slv;
      offset      : in    integer;
      reg         : inout sl);

   procedure axiSlaveRegisterR (
      variable ep : inout AxiLiteEndpointType;
      addr        : in    slv;
      offset      : in    integer;
      reg         : in    sl);

   procedure axiSlaveRegister (
      variable ep : inout AxiLiteEndpointType;
      addr        : in    slv;
      regs        : inout slv32Array);

   procedure axiSlaveRegisterR (
      variable ep : inout AxiLiteEndpointType;
      addr        : in    slv;
      regs        : in    slv32Array);

   procedure axiWrDetect (
      variable ep : inout AxiLiteEndpointType;
      addr        : in    slv;
      reg         : inout sl);

   procedure axiRdDetect (
      variable ep : inout AxiLiteEndpointType;
      addr        : in    slv;
      reg         : inout sl);


   procedure axiSlaveDefault (
      variable ep            : inout AxiLiteEndpointType;
      variable axiWriteSlave : inout AxiLiteWriteSlaveType;
      variable axiReadSlave  : inout AxiLiteReadSlaveType;
      axiResp                : in    slv(1 downto 0) := AXI_RESP_OK_C;
      extTxn                 : in    sl              := '0');


   -------------------------------------------------------------------------------------------------
   -- Slave AXI Processing functions
   -------------------------------------------------------------------------------------------------

   -- Generate evenly distributed address map
   function genAxiLiteConfig (num      : positive;
                              base     : slv(31 downto 0);
                              baseBot  : integer range 1 to 32;
                              addrBits : integer range 0 to 31)
      return AxiLiteCrossbarMasterConfigArray;


   -------------------------------------------------------------------------------------------------
   -- Simulation procedures
   -------------------------------------------------------------------------------------------------
   procedure axiLiteBusSimWrite (
      signal axilClk         : in  sl;
      signal axilWriteMaster : out AxiLiteWriteMasterType;
      signal axilWriteSlave  : in  AxiLiteWriteSlaveType;
      addr                   : in  slv(31 downto 0);
      data                   : in  slv;
      debug                  : in  boolean := false);

   procedure axiLiteBusSimRead (
      signal axilClk        : in  sl;
      signal axilReadMaster : out AxiLiteReadMasterType;
      signal axilReadSlave  : in  AxiLiteReadSlaveType;
      addr                  : in  slv(31 downto 0);
      data                  : out slv;
      debug                 : in  boolean := false);

   function ite(i : boolean; t : AxiLiteReadMasterType; e : AxiLiteReadMasterType) return AxiLiteReadMasterType;
   function ite(i : boolean; t : AxiLiteReadSlaveType; e : AxiLiteReadSlaveType) return AxiLiteReadSlaveType;
   function ite(i : boolean; t : AxiLiteWriteMasterType; e : AxiLiteWriteMasterType) return AxiLiteWriteMasterType;
   function ite(i : boolean; t : AxiLiteWriteSlaveType; e : AxiLiteWriteSlaveType) return AxiLiteWriteSlaveType;

end AxiLitePkg;

package body AxiLitePkg is

   function axiLiteReadSlaveEmptyInit (
      rresp : slv(1 downto 0)  := AXI_RESP_OK_C;
      rdata : slv(31 downto 0) := (others => '0'))
      return AxiLiteReadSlaveType is
   begin
      return (arready => '1',
              rdata   => rdata,
              rresp   => rresp,
              rvalid  => '1');
   end function axiLiteReadSlaveEmptyInit;

   function axiLiteWriteSlaveEmptyInit (
      bresp : slv(1 downto 0) := AXI_RESP_OK_C)
      return AxiLiteWriteSlaveType is
   begin
      return (awready => '1',
              wready  => '1',
              bresp   => bresp,
              bvalid  => '1');
   end function axiLiteWriteSlaveEmptyInit;

   function axiReadMasterInit (constant config : AxiLiteCrossbarMasterConfigType) return AxiLiteReadMasterType is
      variable ret : AxiLiteReadMasterType;
   begin
      ret        := AXI_LITE_READ_MASTER_INIT_C;
      ret.araddr := config.baseAddr;
      return ret;
   end function axiReadMasterInit;

   function axiReadMasterInit (constant config : AxiLiteCrossbarMasterConfigArray) return AxiLiteReadMasterArray is
      variable ret : AxiLiteReadMasterArray(config'range);
   begin
      for i in config'range loop
         ret(i) := axiReadMasterInit(config(i));
      end loop;
      return ret;
   end function axiReadMasterInit;

   function axiWriteMasterInit (constant config : AxiLiteCrossbarMasterConfigType) return AxiLiteWriteMasterType is
      variable ret : AxiLiteWriteMasterType;
   begin
      ret        := AXI_LITE_WRITE_MASTER_INIT_C;
      ret.awaddr := config.baseAddr;
      return ret;
   end function axiWriteMasterInit;

   function axiWriteMasterInit (constant config : AxiLiteCrossbarMasterConfigArray) return AxiLiteWriteMasterArray is
      variable ret : AxiLiteWriteMasterArray(config'range);
   begin
      for i in config'range loop
         ret(i) := axiWriteMasterInit(config(i));
      end loop;
      return ret;
   end function axiWriteMasterInit;

   procedure axiSlaveWaitWriteTxn (
      signal axiWriteMaster  : in    AxiLiteWriteMasterType;
      variable axiWriteSlave : inout AxiLiteWriteSlaveType;
      variable writeEnable   : inout sl) is
   begin
      ----------------------------------------------------------------------------------------------
      -- AXI Write Logic
      ----------------------------------------------------------------------------------------------
      writeEnable := '0';

      -- Reset resp valid
      if (axiWriteMaster.bready = '1') then
         axiWriteSlave.bvalid := '0';
      end if;

      -- Check if last cycle accepted write address and write data
      if (axiWriteSlave.awready = '1') and (axiWriteSlave.wready = '1') then

         -- Prevent AXI_ERRS_BRESP_AW: A slave must not give a write response before the write address. Spec: section A3.3.1 and figure A3-7.
         axiWriteSlave.bvalid := '1';

      else

         -- Incoming Write txn and last txn has concluded
         if (axiWriteMaster.awvalid = '1' and axiWriteMaster.wvalid = '1' and axiWriteSlave.bvalid = '0') then
            writeEnable := '1';
         end if;

      end if;

      axiWriteSlave.awready := '0';
      axiWriteSlave.wready  := '0';

   end procedure axiSlaveWaitWriteTxn;

   procedure axiSlaveWaitReadTxn (
      signal axiReadMaster  : in    AxiLiteReadMasterType;
      variable axiReadSlave : inout AxiLiteReadSlaveType;
      variable readEnable   : inout sl) is
   begin
      ----------------------------------------------------------------------------------------------
      -- AXI Read Logic
      ----------------------------------------------------------------------------------------------
      readEnable := '0';

      -- Check if last cycle accepted read address
      if (axiReadSlave.arready = '1') then

         -- Prevent AXI_AUXM_RCAM_UNDERFLOW: Read CAM underflow.
         axiReadSlave.rvalid := '1';

      else

         -- Reset rvalid upon rready
         if (axiReadMaster.rready = '1') then
            axiReadSlave.rvalid := '0';
            axiReadSlave.rdata  := (others => '0');
         end if;

         -- Incoming read txn and last txn has concluded
         if (axiReadMaster.arvalid = '1' and axiReadSlave.rvalid = '0') then
            readEnable := '1';
         end if;

      end if;

      axiReadSlave.arready := '0';

   end procedure axiSlaveWaitReadTxn;

   procedure axiSlaveWaitTxn (
      signal axiWriteMaster  : in    AxiLiteWriteMasterType;
      signal axiReadMaster   : in    AxiLiteReadMasterType;
      variable axiWriteSlave : inout AxiLiteWriteSlaveType;
      variable axiReadSlave  : inout AxiLiteReadSlaveType;
      variable axiStatus     : inout AxiLiteStatusType) is
   begin
      axiSlaveWaitWriteTxn(axiWriteMaster, axiWriteSlave, axiStatus.writeEnable);
      axiSlaveWaitReadTxn(axiReadMaster, axiReadSlave, axiStatus.readEnable);
   end procedure;

   procedure axiSlaveWriteResponse (
      variable axiWriteSlave : inout AxiLiteWriteSlaveType;
      axiResp                : in    slv(1 downto 0) := AXI_RESP_OK_C) is
   begin
      axiWriteSlave.awready := '1';
      axiWriteSlave.wready  := '1';
      axiWriteSlave.bvalid  := '0';     -- bvalid set in axiSlaveWaitWriteTxn
      axiWriteSlave.bresp   := axiResp;
   end procedure;

   procedure axiSlaveReadResponse (
      variable axiReadSlave : inout AxiLiteReadSlaveType;
      axiResp               : in    slv(1 downto 0) := AXI_RESP_OK_C) is
   begin
      axiReadSlave.arready := '1';      -- not sure this is necessary
      axiReadSlave.rvalid  := '0';      -- rvalid set in axiSlaveWaitReadTxn
      axiReadSlave.rresp   := axiResp;
   end procedure;

   -------------------------------------------------------------------------------------------------
   -- Procedures for simplified address decoding
   -------------------------------------------------------------------------------------------------
   procedure axiSlaveRegister (
      signal axiWriteMaster  : in    AxiLiteWriteMasterType;
      signal axiReadMaster   : in    AxiLiteReadMasterType;
      variable axiWriteSlave : inout AxiLiteWriteSlaveType;
      variable axiReadSlave  : inout AxiLiteReadSlaveType;
      variable axiStatus     : in    AxiLiteStatusType;
      addr                   : in    slv;
      offset                 : in    integer;
      reg                    : inout slv;
      constAssign            : in    boolean := false;
      constVal               : in    slv     := "0") is
   begin
      -- Read must come first so as not to overwrite the variable if read and write happen at once
      if (axiStatus.readEnable = '1') then
         if (std_match(axiReadMaster.araddr(addr'length-1 downto 0), addr)) then
            axiReadSlave.rdata(offset+reg'length-1 downto offset) := reg;
            axiSlaveReadResponse(axiReadSlave);
         end if;
      end if;

      if (axiStatus.writeEnable = '1') then
         if (std_match(axiWriteMaster.awaddr(addr'length-1 downto 0), addr)) then
            if (constAssign) then
               reg := constVal;
            else
               reg := axiWriteMaster.wdata(offset+reg'length-1 downto offset);
            end if;
            axiSlaveWriteResponse(axiWriteSlave);
         end if;
      end if;

   end procedure;

   procedure axiSlaveRegister (
      signal axiReadMaster  : in    AxiLiteReadMasterType;
      variable axiReadSlave : inout AxiLiteReadSlaveType;
      variable axiStatus    : in    AxiLiteStatusType;
      addr                  : in    slv;
      offset                : in    integer;
      reg                   : in    slv) is
   begin
      if (axiStatus.readEnable = '1') then
         if (std_match(axiReadMaster.araddr(addr'length-1 downto 0), addr)) then
            axiReadSlave.rdata(offset+reg'length-1 downto offset) := reg;
            axiSlaveReadResponse(axiReadSlave);
         end if;
      end if;
   end procedure;

   procedure axiSlaveRegister (
      signal axiWriteMaster  : in    AxiLiteWriteMasterType;
      signal axiReadMaster   : in    AxiLiteReadMasterType;
      variable axiWriteSlave : inout AxiLiteWriteSlaveType;
      variable axiReadSlave  : inout AxiLiteReadSlaveType;
      variable axiStatus     : in    AxiLiteStatusType;
      addr                   : in    slv;
      offset                 : in    integer;
      reg                    : inout sl;
      constAssign            : in    boolean := false;
      constVal               : in    sl      := '0')
   is
      variable tmpReg : slv(0 downto 0);
      variable tmpVal : slv(0 downto 0);
   begin
      tmpReg(0) := reg;
      tmpVal(0) := constVal;
      axiSlaveRegister(axiWriteMaster, axiReadMaster, axiWriteSlave, axiReadSlave, axiStatus, addr, offset, tmpReg, constAssign, tmpVal);
      reg       := tmpReg(0);
   end procedure;

   procedure axiSlaveRegister (
      signal axiReadMaster  : in    AxiLiteReadMasterType;
      variable axiReadSlave : inout AxiLiteReadSlaveType;
      variable axiStatus    : in    AxiLiteStatusType;
      addr                  : in    slv;
      offset                : in    integer;
      reg                   : in    sl)
   is
      variable tmp : slv(0 downto 0);
   begin
      tmp(0) := reg;
      axiSlaveRegister(axiReadMaster, axiReadSlave, axiStatus, addr, offset, tmp);
   end procedure;

   procedure axiSlaveDefault (
      signal axiWriteMaster  : in    AxiLiteWriteMasterType;
      signal axiReadMaster   : in    AxiLiteReadMasterType;
      variable axiWriteSlave : inout AxiLiteWriteSlaveType;
      variable axiReadSlave  : inout AxiLiteReadSlaveType;
      variable axiStatus     : in    AxiLiteStatusType;
      axiResp                : in    slv(1 downto 0) := AXI_RESP_OK_C;
      extTxn                 : in    sl              := '0') is
   begin
      if (axiStatus.writeEnable = '1' and axiWriteSlave.awready = '0' and extTxn = '0') then
         axiSlaveWriteResponse(axiWriteSlave, axiResp);
      end if;

      if (axiStatus.readEnable = '1' and axiReadSlave.arready = '0' and extTxn = '0') then
         axiSlaveReadResponse(axiReadSlave, axiResp);
      end if;
   end procedure;

   -------------------------------------------------------------------------------------------------
   -- Simplified Address decode procedures, RTH 1/27/2016
   -------------------------------------------------------------------------------------------------
   procedure axiSlaveWaitTxn (
      variable ep            : inout AxiLiteEndpointType;
      signal axiWriteMaster  : in    AxiLiteWriteMasterType;
      signal axiReadMaster   : in    AxiLiteReadMasterType;
      variable axiWriteSlave : in    AxiLiteWriteSlaveType;
      variable axiReadSlave  : in    AxiLiteReadSlaveType) is
   begin
      ep := AXI_LITE_ENDPOINT_INIT_C;

      ep.axiWriteMaster := axiWriteMaster;
      ep.axiReadMaster  := axiReadMaster;
      ep.axiWriteSlave  := axiWriteSlave;
      ep.axiReadSlave   := axiReadSlave;

      axiSlaveWaitTxn(axiWriteMaster, axiReadMaster,
                      ep.axiWriteSlave, ep.axiReadSlave,
                      ep.axiStatus);
   end procedure;

   procedure axiSlaveRegisterLegacy (
      variable ep : inout AxiLiteEndpointType;
      addr        : in    slv;
      offset      : in    integer;
      reg         : inout slv;
      constVal    : in    slv)
   is
      -- Need to remap addr range to be (length-1 downto 0)
      constant ADDR_LEN_C   : integer                    := addr'length;
      constant ADDR_C       : slv(ADDR_LEN_C-1 downto 0) := addr;
      -- Offset as measured from addr[1:0]="00"
      constant ABS_OFFSET_C : integer                    := offset + (to_integer(unsigned(ADDR_C(1 downto 0)))*8);
      -- Normalized address and offset (for when addr[1:0]!=00)
      constant NORMAL_ADDR_C : slv(ADDR_LEN_C-1 downto 0) := ite(ABS_OFFSET_C /= 0,
                                                                 slv((unsigned(slv(ADDR_C))) + ((ABS_OFFSET_C/32)*4)),
                                                                 ADDR_C);
      constant NORMAL_OFFSET_C : integer := ABS_OFFSET_C mod 32;
      -- Most significant register bit before wrapping to the next word address
      constant REG_HIGH_BIT_C  : integer := minimum(31-NORMAL_OFFSET_C+reg'low, reg'high);
      -- Most significant data bus bit to be used in this recursion (max out at 31)
      constant BUS_HIGH_BIT_C  : integer := minimum(NORMAL_OFFSET_C+reg'length-1, 31);

      variable strobeMask : slv(3 downto 0) := (others => '-');
   begin

      for i in BUS_HIGH_BIT_C downto NORMAL_OFFSET_C loop
         strobeMask(i/8) := '1';
      end loop;

      -- Read must come first so as not to overwrite the variable if read and write happen at once
      if (ep.axiStatus.readEnable = '1') then
         if (std_match(ep.axiReadMaster.araddr(ADDR_LEN_C-1 downto 2), NORMAL_ADDR_C(ADDR_LEN_C-1 downto 2))) then
            ep.axiReadSlave.rdata(BUS_HIGH_BIT_C downto NORMAL_OFFSET_C) := reg(REG_HIGH_BIT_C downto reg'low);
            axiSlaveReadResponse(ep.axiReadSlave);
         end if;
      end if;

      if (ep.axiStatus.writeEnable = '1') then
         if (std_match(ep.axiWriteMaster.awaddr(ADDR_LEN_C-1 downto 2), NORMAL_ADDR_C(ADDR_LEN_C-1 downto 2)) and
             std_match(ep.axiWriteMaster.wstrb, strobeMask)) then
            if (constVal /= "X") then
               reg(REG_HIGH_BIT_C downto reg'low) := resize(constVal,(REG_HIGH_BIT_C-reg'low)+1);
            else
               reg(REG_HIGH_BIT_C downto reg'low) := ep.axiWriteMaster.wdata(BUS_HIGH_BIT_C downto NORMAL_OFFSET_C);
            end if;
            axiSlaveWriteResponse(ep.axiWriteSlave);
         end if;
      end if;

   end procedure;

   procedure axiSlaveRegisterLegacy (
      variable ep : inout AxiLiteEndpointType;
      addr        : in    slv;
      offset      : in    integer;
      reg         : inout slv)
   is
      -- Need to remap addr range to be (length-1 downto 0)
      constant ADDR_LEN_C   : integer                    := addr'length;
      constant ADDR_C       : slv(ADDR_LEN_C-1 downto 0) := addr;
      -- Offset as measured from addr[1:0]="00"
      constant ABS_OFFSET_C : integer                    := offset + (to_integer(unsigned(ADDR_C(1 downto 0)))*8);
      -- Normalized address and offset (for when addr[1:0]!=00)
      constant NORMAL_ADDR_C : slv(ADDR_LEN_C-1 downto 0) := ite(ABS_OFFSET_C /= 0,
                                                                 slv((unsigned(slv(ADDR_C))) + ((ABS_OFFSET_C/32)*4)),
                                                                 ADDR_C);
      constant NORMAL_OFFSET_C : integer := ABS_OFFSET_C mod 32;
      -- Most significant register bit before wrapping to the next word address
      constant REG_HIGH_BIT_C  : integer := minimum(31-NORMAL_OFFSET_C+reg'low, reg'high);
      -- Most significant data bus bit to be used in this recursion (max out at 31)
      constant BUS_HIGH_BIT_C  : integer := minimum(NORMAL_OFFSET_C+reg'length-1, 31);

      variable strobeMask : slv(3 downto 0) := (others => '-');
   begin

      for i in BUS_HIGH_BIT_C downto NORMAL_OFFSET_C loop
         strobeMask(i/8) := '1';
      end loop;

      -- Read must come first so as not to overwrite the variable if read and write happen at once
      if (ep.axiStatus.readEnable = '1') then
         if (std_match(ep.axiReadMaster.araddr(ADDR_LEN_C-1 downto 2), NORMAL_ADDR_C(ADDR_LEN_C-1 downto 2))) then
            ep.axiReadSlave.rdata(BUS_HIGH_BIT_C downto NORMAL_OFFSET_C) := reg(REG_HIGH_BIT_C downto reg'low);
            axiSlaveReadResponse(ep.axiReadSlave);
         end if;
      end if;

      if (ep.axiStatus.writeEnable = '1') then
         if (std_match(ep.axiWriteMaster.awaddr(ADDR_LEN_C-1 downto 2), NORMAL_ADDR_C(ADDR_LEN_C-1 downto 2)) and
             std_match(ep.axiWriteMaster.wstrb, strobeMask)) then
            -- if (constVal /= "X") then
               -- reg(REG_HIGH_BIT_C downto reg'low) := resize(constVal,(REG_HIGH_BIT_C-reg'low)+1);
            -- else
               reg(REG_HIGH_BIT_C downto reg'low) := ep.axiWriteMaster.wdata(BUS_HIGH_BIT_C downto NORMAL_OFFSET_C);
            -- end if;
            axiSlaveWriteResponse(ep.axiWriteSlave);
         end if;
      end if;

   end procedure;

   procedure axiSlaveRegister (
      variable ep : inout AxiLiteEndpointType;
      addr        : in    slv;
      offset      : in    integer;
      reg         : inout slv;
      constVal    : in    slv)
   is
      variable highbit : integer;
   begin

      for i in ((reg'length-1)/32) downto 0 loop
         if i = ((reg'length-1)/32) then
            highbit := ((reg'length-1) mod 32) + (32*i) + reg'low;
         else
            highbit := 31 + (32*i) + reg'low;
         end if;
         axiSlaveRegisterLegacy(ep, slv(unsigned(addr)+(4*i)), offset, reg(highbit downto (32*i)+reg'low), constVal);
      end loop;

   end procedure;

   procedure axiSlaveRegister (
      variable ep : inout AxiLiteEndpointType;
      addr        : in    slv;
      offset      : in    integer;
      reg         : inout slv)
   is
      variable highbit : integer;
   begin

      for i in ((reg'length-1)/32) downto 0 loop
         if i = ((reg'length-1)/32) then
            highbit := ((reg'length-1) mod 32) + (32*i) + reg'low;
         else
            highbit := 31 + (32*i) + reg'low;
         end if;
         axiSlaveRegisterLegacy(ep, slv(unsigned(addr)+(4*i)), offset, reg(highbit downto (32*i)+reg'low));
      end loop;

   end procedure;

   procedure axiSlaveRegisterR (
      variable ep : inout AxiLiteEndpointType;
      addr        : in    slv;
      offset      : in    integer;
      reg         : in    slv)
   is
      variable regTmp : slv(reg'length-1 downto 0);
   begin
      regTmp := reg;
      if (ep.axiStatus.readEnable = '1') then
         axiSlaveRegister(ep, addr, offset, regTmp, "X");
      end if;
   end procedure;

   procedure axiSlaveRegister (
      variable ep : inout AxiLiteEndpointType;
      addr        : in    slv;
      offset      : in    integer;
      reg         : inout sl;
      constVal    : in    sl)
   is
      variable tmpReg : slv(0 downto 0);
      variable tmpVal : slv(0 downto 0);
   begin
      tmpReg(0) := reg;
      tmpVal(0) := constVal;
      axiSlaveRegister(ep, addr, offset, tmpReg, tmpVal);
      reg       := tmpReg(0);
   end procedure;

   procedure axiSlaveRegister (
      variable ep : inout AxiLiteEndpointType;
      addr        : in    slv;
      offset      : in    integer;
      reg         : inout sl)
   is
      variable tmpReg : slv(0 downto 0);
   begin
      tmpReg(0) := reg;
      axiSlaveRegister(ep, addr, offset, tmpReg);
      reg       := tmpReg(0);
   end procedure;

   procedure axiSlaveRegisterR (
      variable ep : inout AxiLiteEndpointType;
      addr        : in    slv;
      offset      : in    integer;
      reg         : in    sl)
   is
      variable tmp : slv(0 downto 0);
   begin
      tmp(0) := reg;
      axiSlaveRegisterR(ep, addr, offset, tmp);
   end procedure;

   procedure axiSlaveRegister (
      variable ep : inout AxiLiteEndpointType;
      addr        : in    slv;
      regs        : inout slv32Array)
   is
   begin
      for i in regs'range loop
         axiSlaveRegister(ep, slv(unsigned(addr) + to_unsigned(i*4, addr'length)), 0, regs(i));
      end loop;

   end procedure;

   procedure axiSlaveRegisterR (
      variable ep : inout AxiLiteEndpointType;
      addr        : in    slv;
      regs        : in    slv32Array)
   is
   begin
      for i in regs'range loop
         axiSlaveRegisterR(ep, slv(unsigned(addr) + to_unsigned(i*4, addr'length)), 0, regs(i));
      end loop;

   end procedure;

   procedure axiWrDetect (
      variable ep : inout AxiLiteEndpointType;
      addr        : in    slv;
      reg         : inout sl)
   is
      -- Need to remap addr range to be (length-1 downto 0)
      constant ADDR_LEN_C : integer                    := addr'length;
      constant ADDR_C     : slv(ADDR_LEN_C-1 downto 0) := addr;
   begin
      if (ep.axiStatus.writeEnable = '1') then
         if std_match(ep.axiWriteMaster.awaddr(ADDR_LEN_C-1 downto 2), ADDR_C(ADDR_LEN_C-1 downto 2)) then
            reg := '1';
            axiSlaveWriteResponse(ep.axiWriteSlave);
         end if;
      end if;
   end procedure;

   procedure axiRdDetect (
      variable ep : inout AxiLiteEndpointType;
      addr        : in    slv;
      reg         : inout sl)
   is
      -- Need to remap addr range to be (length-1 downto 0)
      constant ADDR_LEN_C : integer                    := addr'length;
      constant ADDR_C     : slv(ADDR_LEN_C-1 downto 0) := addr;
   begin
      if (ep.axiStatus.readEnable = '1') then
         if std_match(ep.axiReadMaster.aRaddr(ADDR_LEN_C-1 downto 2), ADDR_C(ADDR_LEN_C-1 downto 2)) then
            reg := '1';
            axiSlaveReadResponse(ep.axiReadSlave);
         end if;
      end if;
   end procedure;

   procedure axiSlaveDefault (
      variable ep            : inout AxiLiteEndpointType;
      variable axiWriteSlave : inout AxiLiteWriteSlaveType;
      variable axiReadSlave  : inout AxiLiteReadSlaveType;
      axiResp                : in    slv(1 downto 0) := AXI_RESP_OK_C;
      extTxn                 : in    sl              := '0') is
   begin
      if (ep.axiStatus.writeEnable = '1' and ep.axiWriteSlave.awready = '0' and extTxn = '0') then
         axiSlaveWriteResponse(ep.axiWriteSlave, axiResp);
      end if;

      if (ep.axiStatus.readEnable = '1' and ep.axiReadSlave.arready = '0' and extTxn = '0') then
         axiSlaveReadResponse(ep.axiReadSlave, axiResp);
      end if;
      axiWriteSlave := ep.axiWriteSlave;
      axiReadSlave  := ep.axiReadSlave;
   end procedure;


   -------------------------------------------------------------------------------------------------
   -- Slave AXI Processing functions
   -------------------------------------------------------------------------------------------------

   -- Generate evenly distributed address map
   function genAxiLiteConfig (num      : positive;
                              base     : slv(31 downto 0);
                              baseBot  : integer range 1 to 32;
                              addrBits : integer range 0 to 31)
      return AxiLiteCrossbarMasterConfigArray is
      variable retConf : AxiLiteCrossbarMasterConfigArray(num-1 downto 0);
      variable addr    : slv(31 downto 0);
   begin

      -------------------------------------------------------------------------------------------
      -- Note: These asserts only work in synthesis (not simulation)
      -- https://forums.xilinx.com/t5/Synthesis/VHDL-assert-statement-within-function/td-p/413463
      -------------------------------------------------------------------------------------------

      -- Compare the baseBot to addrBits
      assert (baseBot > addrBits)
         report "AxiLitePkg.genAxiLiteConfig(): (baseBot > addrBits) condition not meet"
         & lf & "num      = " & integer'image(num)
         & lf & "base     = 0x" & hstr(base)
         & lf & "baseBot  = " & integer'image(baseBot)
         & lf & "addrBits = " & integer'image(addrBits)
         severity error;

      -- Check that there is enough bits for the number of buses
      assert (2**(baseBot-addrBits) >= num)
         report "AxiLitePkg.genAxiLiteConfig(): (2**(baseBot-addrBits) >= num) condition not meet"
         & lf & "num      = " & integer'image(num)
         & lf & "base     = 0x" & hstr(base)
         & lf & "baseBot  = " & integer'image(baseBot)
         & lf & "addrBits = " & integer'image(addrBits)
         severity error;

      -------------------------------------------------------------------------------------------
      -- Init
      -------------------------------------------------------------------------------------------
      addr                     := base;
      addr(baseBot-1 downto 0) := (others => '0');

      -------------------------------------------------------------------------------------------
      -- Generate records
      -------------------------------------------------------------------------------------------
      for i in 0 to num-1 loop
         addr(baseBot-1 downto addrBits) := toSlv(i, baseBot-addrBits);
         retConf(i).baseAddr             := addr;
         retConf(i).addrBits             := addrBits;
         retConf(i).connectivity         := x"FFFF";
      end loop;

      return retConf;
   end function;


   -------------------------------------------------------------------------------------------------
   -- Simulation procedures
   -------------------------------------------------------------------------------------------------

   procedure axiLiteBusSimWrite (
      signal axilClk         : in  sl;
      signal axilWriteMaster : out AxiLiteWriteMasterType;
      signal axilWriteSlave  : in  AxiLiteWriteSlaveType;
      addr                   : in  slv(31 downto 0);
      data                   : in  slv;
      debug                  : in  boolean := false)
   is
      variable dataTmp : slv(31 downto 0);
      variable addrTmp : slv(31 downto 0);
   begin
      dataTmp := resize(data, 32);

      wait until axilClk = '1';
      axilWriteMaster.awaddr  <= addr;
      axilWriteMaster.wdata   <= dataTmp;
      axilWriteMaster.awprot  <= (others => '0');
      axilWriteMaster.wstrb   <= (others => '1');
      axilWriteMaster.awvalid <= '1';
      axilWriteMaster.wvalid  <= '1';
      axilWriteMaster.bready  <= '1';


      wait until axilClk = '1';
      -- Wait for a response
      while (axilWriteSlave.bvalid = '0') loop
         -- Clear control signals when acked
         if axilWriteSlave.awready = '1' then
            axilWriteMaster.awvalid <= '0';
         end if;
         if axilWriteSlave.wready = '1' then
            axilWriteMaster.wvalid <= '0';
         end if;

         wait until axilClk = '1';
      end loop;

      -- Clear control signals if bvalid and ready arrive at the same time
      if axilWriteSlave.awready = '1' then
         axilWriteMaster.awvalid <= '0';
      end if;
      if axilWriteSlave.wready = '1' then
         axilWriteMaster.wvalid <= '0';
      end if;

      -- Done. Check for errors
      axilWriteMaster.bready <= '0';

      print(debug, "AxiLitePkg::axiLiteBusSimWrite(addr:" & hstr(addr) & ", data: " & hstr(dataTmp) & ")");
      if (axilWriteSlave.bresp = AXI_RESP_SLVERR_C) then
         report "AxiLitePkg::axiLiteBusSimWrite( addr:" & hstr(addr) & "): - BRESP = SLAVE_ERROR" severity warning;
      elsif (axilWriteSlave.bresp = AXI_RESP_DECERR_C) then
         report "AxiLitePkg::axiLiteBusSimWrite( addr:" & hstr(addr) & "): BRESP = DECODE_ERROR" severity warning;
      end if;


      -- If data size is greater than 32, make a recursive call to write the next word
      if (data'length > 32) then
         addrTmp := slv(unsigned(addr) + 4);
         axiLiteBusSimWrite(axilClk, axilWriteMaster, axilWriteSlave, addrTmp, data(data'high downto 32), debug);
      end if;

   end procedure axiLiteBusSimWrite;


   procedure axiLiteBusSimRead (
      signal axilClk        : in  sl;
      signal axilReadMaster : out AxiLiteReadMasterType;
      signal axilReadSlave  : in  AxiLiteReadSlaveType;
      addr                  : in  slv(31 downto 0);
      data                  : out slv;
      debug                 : in  boolean := false)
   is
      variable dataTmp : slv(31 downto 0);
      variable addrTmp : slv(31 downto 0);
   begin
      -- Put the write req on the bus
      wait until axilClk = '1';
      axilReadMaster.araddr  <= addr;
      axilReadMaster.arprot  <= (others => '0');
      axilReadMaster.arvalid <= '1';
      axilReadMaster.rready  <= '1';

      wait until axilClk = '1';
      -- Wait for a response
      while (axilReadSlave.rvalid = '0') loop
         -- Clear control signals when acked
         if axilReadSlave.arready = '1' then
            axilReadMaster.arvalid <= '0';
         end if;

         wait until axilClk = '1';
      end loop;

      -- Clear control signals when acked
      if axilReadSlave.arready = '1' then
         axilReadMaster.arvalid <= '0';
      end if;

      -- Done. Check for errors
      if (axilReadSlave.rresp = AXI_RESP_SLVERR_C) then
         report "AxiLitePkg::axiLiteBusSimRead( addr:" & hstr(addr) & "): RRESP = SLAVE_ERROR" severity warning;
      elsif (axilReadSlave.rresp = AXI_RESP_DECERR_C) then
         report "AxiLitePkg::axiLiteBusSimRead( addr:" & hstr(addr) & "): RRESP = DECODE_ERROR" severity warning;
      else
         dataTmp := axilReadSlave.rdata;
         print(debug, "AxiLitePkg::axiLiteBusSimRead( addr:" & hstr(addr) & ", data: " & hstr(axilReadSlave.rdata) & ")");
      end if;
      axilReadMaster.rready <= '0';

      if (data'length > 32) then
         addrTmp                           := slv(unsigned(addr) + 4);
         data(data'low+31 downto data'low) := dataTmp;
         axiLiteBusSimRead(axilClk, axilReadMaster, axilReadSlave, addrTmp, data(data'high downto 32), debug);
      else
         data := resize(dataTmp, data'length);
      end if;


   end procedure axiLiteBusSimRead;

   function ite (i : boolean; t : AxiLiteReadMasterType; e : AxiLiteReadMasterType) return AxiLiteReadMasterType is
   begin
      if (i) then return t; else return e; end if;
   end function ite;

   function ite (i : boolean; t : AxiLiteReadSlaveType; e : AxiLiteReadSlaveType) return AxiLiteReadSlaveType is
   begin
      if (i) then return t; else return e; end if;
   end function ite;

   function ite (i : boolean; t : AxiLiteWriteMasterType; e : AxiLiteWriteMasterType) return AxiLiteWriteMasterType is
   begin
      if (i) then return t; else return e; end if;
   end function ite;

   function ite (i : boolean; t : AxiLiteWriteSlaveType; e : AxiLiteWriteSlaveType) return AxiLiteWriteSlaveType is
   begin
      if (i) then return t; else return e; end if;
   end function ite;


end package body AxiLitePkg;

