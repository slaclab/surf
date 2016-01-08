-------------------------------------------------------------------------------
-- Title         : ARM Based RCE Generation 3, Package File
-- File          : AxiLitePkg.vhd
-- Author        : Ryan Herbst, rherbst@slac.stanford.edu
-- Created       : 04/02/2013
-------------------------------------------------------------------------------
-- Description:
-- Package file for ARM based rce generation 3 processor core.
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Firmware Standard Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'SLAC Firmware Standard Library', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------
-- Modification history:
-- 04/02/2013: created.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.NUMERIC_STD.all;
use work.StdRtlPkg.all;
use work.TextUtilPkg.all;

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
   --          3) Any access that is unaligned, for example, where AWADDRP[1:0] is not equal to 2’b00, 
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

   -- Array
   type AxiLiteWriteSlaveArray is array (natural range<>) of AxiLiteWriteSlaveType;

   type AxiLiteStatusType is record
      writeEnable : sl;
      readEnable  : sl;
   end record AxiLiteStatusType;

   constant AXI_LITE_STATUS_INIT_C : AxiLiteStatusType := (
      writeEnable => '0',
      readEnable  => '0');

   -------------------------------------------------------------------------------------------------
   -- Crossbar Config Generic Types
   -------------------------------------------------------------------------------------------------
   type AxiLiteCrossbarMasterConfigType is record
      baseAddr     : slv(31 downto 0);
--      highAddr     : slv(31 downto 0);
      addrBits     : natural;
      connectivity : slv(15 downto 0);
   end record;

   type AxiLiteCrossbarMasterConfigArray is array (natural range <>) of AxiLiteCrossbarMasterConfigType;

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
      axiResp                : in    slv(1 downto 0) := AXI_RESP_OK_C);

   -------------------------------------------------------------------------------------------------
   -- Slave AXI Processing functions
   -------------------------------------------------------------------------------------------------

   -- Generate evenly distributed address map
   function genAxiLiteConfig (num      : positive;
                              base     : slv(31 downto 0);
                              baseBot  : integer range 0 to 32;
                              addrBits : integer range 0 to 32)
      return AxiLiteCrossbarMasterConfigArray;


   -------------------------------------------------------------------------------------------------
   -- Simulation procedures
   -------------------------------------------------------------------------------------------------
   procedure axiLiteBusSimWrite (
      signal axiClk          : in  sl;
      signal axilWriteMaster : out AxiLiteWriteMasterType;
      signal axilWriteSlave  : in  AxiLiteWriteSlaveType;
      addr            : in  slv(31 downto 0);
      data            : in  slv(31 downto 0);
      debug           : in  boolean := false);
   
   procedure axiLiteBusSimRead (
      signal axiClk         : in  sl;
      signal axilReadMaster : out AxiLiteReadMasterType;
      signal axilReadSlave  : in  AxiLiteReadSlaveType;
      addr           : in  slv(31 downto 0);
      data           : out slv(31 downto 0);
      debug          : in  boolean := false);


end AxiLitePkg;

package body AxiLitePkg is

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

      axiWriteSlave.awready := '0';
      axiWriteSlave.wready  := '0';

      -- Incomming Write txn and last txn has concluded
      if (axiWriteMaster.awvalid = '1' and axiWriteMaster.wvalid = '1' and axiWriteSlave.bvalid = '0') then
         writeEnable := '1';
      end if;

      -- Reset resp valid
      if (axiWriteMaster.bready = '1') then
         axiWriteSlave.bvalid := '0';
      end if;
   end procedure;

   procedure axiSlaveWaitReadTxn (
      signal axiReadMaster  : in    AxiLiteReadMasterType;
      variable axiReadSlave : inout AxiLiteReadSlaveType;
      variable readEnable   : inout sl) is
   begin
      ----------------------------------------------------------------------------------------------
      -- AXI Read Logic
      ----------------------------------------------------------------------------------------------
      readEnable := '0';

      axiReadSlave.arready := '0';

      -- Incomming read txn and last txn has concluded
      if (axiReadMaster.arvalid = '1' and axiReadSlave.rvalid = '0') then
         readEnable := '1';
--         axiReadSlave.rdata := (others => '0');
      end if;

      -- Reset rvalid upon rready
      if (axiReadMaster.rready = '1') then
         axiReadSlave.rvalid := '0';
         axiReadSlave.rdata := (others => '0');
      end if;
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
      axiWriteSlave.bvalid  := '1';
      axiWriteSlave.bresp   := axiResp;
   end procedure;

   procedure axiSlaveReadResponse (
      variable axiReadSlave : inout AxiLiteReadSlaveType;
      axiResp               : in    slv(1 downto 0) := AXI_RESP_OK_C) is
   begin
      axiReadSlave.arready := '1';      -- not sure this is necessary
      axiReadSlave.rvalid  := '1';
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
      axiResp                : in    slv(1 downto 0) := AXI_RESP_OK_C) is
   begin
      if (axiStatus.writeEnable = '1' and axiWriteSlave.awready = '0') then
         axiSlaveWriteResponse(axiWriteSlave, axiResp);
      end if;

      if (axiStatus.readEnable = '1' and axiReadSlave.arready = '0') then
         axiSlaveReadResponse(axiReadSlave, axiResp);
      end if;
   end procedure;

   -------------------------------------------------------------------------------------------------
   -- Slave AXI Processing functions
   -------------------------------------------------------------------------------------------------

   -- Generate evenly distributed address map
   function genAxiLiteConfig (num      : positive;
                              base     : slv(31 downto 0);
                              baseBot  : integer range 0 to 32;
                              addrBits : integer range 0 to 32)
      return AxiLiteCrossbarMasterConfigArray is
      variable retConf : AxiLiteCrossbarMasterConfigArray(num-1 downto 0);
      variable addr    : slv(31 downto 0);
   begin

      -- Init
      addr                     := base;
      addr(baseBot-1 downto 0) := (others => '0');

      -- Generate records
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
      signal axiClk          : in  sl;
      signal axilWriteMaster : out AxiLiteWriteMasterType;
      signal axilWriteSlave  : in  AxiLiteWriteSlaveType;
      addr            : in  slv(31 downto 0);
      data            : in  slv(31 downto 0);
      debug           : in  boolean := false) is
   begin
      -- Put the req on the bus
      wait until axiClk = '1';
      axilWriteMaster.awaddr  <= addr;
      axilWriteMaster.wdata   <= data;
      axilWriteMaster.awprot  <= (others => '0');
      axilWriteMaster.wstrb   <= (others => '1');
      axilWriteMaster.awvalid <= '1';
      axilWriteMaster.wvalid  <= '1';
      axilWriteMaster.bready  <= '1';


      -- Wait for a response
      while (axilWriteSlave.bvalid = '0') loop
         -- Clear control signals when acked
         if axilWriteSlave.awready = '1' then
            axilWriteMaster.awvalid <= '0';
         end if;
         if axilWriteSlave.wready = '1' then
            axilWriteMaster.wvalid <= '0';
         end if;


         wait until axiClk = '1';
      end loop;

      -- Done. Check for errors
      wait until axiClk = '1';
      axilWriteMaster.bready <= '0';
      if (axilWriteSlave.bresp = AXI_RESP_SLVERR_C) then
         report "AxiLitePkg::axiLiteBusSimWrite(): - BRESP = SLAVE_ERROR" severity error;
      elsif (axilWriteSlave.bresp = AXI_RESP_DECERR_C) then
         report "AxiLitePkg::axiLiteBusSimWrite(): BRESP = DECODE_ERROR" severity error;
      else
         print(debug, "AxiLitePkg::axiLiteBusSimWrite( addr:" & hstr(addr) & ", data: " & hstr(data) & ")");
      end if;

   end procedure axiLiteBusSimWrite;


   procedure axiLiteBusSimRead (
      signal axiClk         : in  sl;
      signal axilReadMaster : out AxiLiteReadMasterType;
      signal axilReadSlave  : in  AxiLiteReadSlaveType;
      addr           : in  slv(31 downto 0);
      data           : out slv(31 downto 0);
      debug          : in  boolean := false) is
   begin
      -- Put the write req on the bus
      wait until axiClk = '1';
      axilReadMaster.araddr  <= addr;
      axilReadMaster.arprot  <= (others => '0');
      axilReadMaster.arvalid <= '1';
      axilReadMaster.rready  <= '1';


      -- Wait for a response
      while (axilReadSlave.rvalid = '0') loop
         -- Clear control signals when acked
         if axilReadSlave.arready = '1' then
            axilReadMaster.arvalid <= '0';
         end if;

         wait until axiClk = '1';
      end loop;

      -- Done. Check for errors
      wait until axiClk = '1';
      axilReadMaster.rready <= '0';
      if (axilReadSlave.rresp = AXI_RESP_SLVERR_C) then
         report "AxiLitePkg::axiLiteBusSimRead(): - RRESP = SLAVE_ERROR" severity error;
      elsif (axilReadSlave.rresp = AXI_RESP_DECERR_C) then
         report "AxiLitePkg::axiLiteBusSimRead(): RRESP = DECODE_ERROR" severity error;
      else
         data := axilReadSlave.rdata;
         print(debug, "AxiLitePkg::axiLiteBusSimRead( addr:" & hstr(addr) & ", data: " & hstr(axilReadSlave.rdata) & ")");
      end if;


   end procedure axiLiteBusSimRead;

end package body AxiLitePkg;

