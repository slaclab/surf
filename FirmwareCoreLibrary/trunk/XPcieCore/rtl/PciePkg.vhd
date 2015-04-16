-------------------------------------------------------------------------------
-- Title      : PCIe Core
-------------------------------------------------------------------------------
-- File       : PciePkg.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-04-15
-- Last update: 2015-04-15
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Package file for Xilinx PCIe Core
-------------------------------------------------------------------------------
-- Copyright (c) 2015 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;

package PciePkg is

   constant PCIE_AXIS_CONFIG_C : AxiStreamConfigType := (
      TSTRB_EN_C    => false,
      TDATA_BYTES_C => 16,              -- 128 bit interface
      TDEST_BITS_C  => 4,
      TID_BITS_C    => 0,
      TKEEP_MODE_C  => TKEEP_NORMAL_C,
      TUSER_BITS_C  => 2,               -- SOF, EOFE
      TUSER_MODE_C  => TUSER_NORMAL_C);   

   -- Max transfer length, words
   constant PCIE_MAX_RX_TRANS_LENGTH_C : integer := 32;  -- 128 Bytes, smallest to ensure comparability
   constant PCIE_MAX_TX_TRANS_LENGTH_C : integer := 256;  -- Request large amounts of data, will be broken up

   ------------------------------------------------------------------------
   -- TranToPci Types/Constants                             
   ------------------------------------------------------------------------          
   -- Transaction FIFO Interface, To PCI
   type PcieTranToPciType is record
      txReq  : sl;                      -- Transaction Request
      trPend : sl;                      -- Transaction is pending
   end record;
   type PcieTranToPciArray is array (integer range<>) of PcieTranToPciType;
  
   ------------------------------------------------------------------------
   -- TranFromPci Types/Constants                             
   ------------------------------------------------------------------------              
   -- Transaction FIFO Interface, From PCI
   type TranFromPcieType is record
      locId : slv(15 downto 0);         -- Assigned local ID
      tag   : slv(7 downto 0);          -- Assigned tag
   end record;
   type TranFromPcieArray is array (integer range<>) of TranFromPcieType;

   ------------------------------------------------------------------------
   -- DescToPci Types/Constants                             
   -- Note: This description is out of data and needs updating (LLR - 16APRIL2105)
   ------------------------------------------------------------------------                  
   -- Descriptor Interface, To PCI
   -- Status Value
   --   11 = fifoErr
   --   10 = frameErr
   --    9 = tranEofe
   --    8 = tranEofe or frameErr or fifoErr
   --  7:3 = DMA Channel ID
   --  2:0 = Sub Channel ID, Interface Specific
   type DescToPcieType is record
      newReq     : sl;                  -- Request for new descriptor address
      doneReq    : sl;                  -- Transfer done request
      doneAddr   : slv(31 downto 2);    -- Address for descriptor
      doneLength : slv(23 downto 0);    -- Length in dwords, 1 based (Rx Only)
      doneStatus : slv(11 downto 0);    -- Status for descriptor     (Rx Only)
   end record;
   type DescToPcieArray is array (integer range<>) of DescToPcieType;

   ------------------------------------------------------------------------
   -- DescFromPci Types/Constants                             
   ------------------------------------------------------------------------                      
   -- Descriptor Interface, From PCI
   -- Control Value
   --  7:3 = DMA Channel ID
   --  2:0 = Sub Channel ID, Interface Specific
   type PcieDescFromPciType is record
      newAck     : sl;                  -- New descriptor ack
      newAddr    : slv(31 downto 2);    -- Address for descriptor
      newLength  : slv(23 downto 0);    -- Length in dwords, 1 based (TX Only)
      newControl : slv(7 downto 0);     -- Control word              (TX Only)
      doneAck    : sl;                  -- Descriptor done ack
      maxFrame   : slv(23 downto 0);    -- Max Frame Length, dwords, 1 based
   end record;
   type DescFromPcieArray is array (integer range<>) of PcieDescFromPciType;

   ------------------------------------------------------------------------
   -- CfgIn Types/Constants                             
   ------------------------------------------------------------------------        
   type PcieCfgInType is record
      irqReq     : sl;
      irqAssert  : sl;
      TrnPending : sl;
   end record;
      
   ------------------------------------------------------------------------
   -- CfgOut Types/Constants                             
   ------------------------------------------------------------------------            
   type PcieCfgOutType is record
      cfgToTurnOff   : sl;
      irqAck         : sl;
      busNumber      : slv(7 downto 0);
      deviceNumber   : slv(4 downto 0);
      functionNumber : slv(2 downto 0);
      status         : slv(15 downto 0);
      command        : slv(15 downto 0);
      dStatus        : slv(15 downto 0);
      dCommand       : slv(15 downto 0);
      lStatus        : slv(15 downto 0);
      lCommand       : slv(15 downto 0);
      linkState      : slv(2 downto 0);
   end record;

   ------------------------------------------------------------------------
   -- 3-DW Header Types/Constants                             
   ------------------------------------------------------------------------
   type PcieHdrType is record
      bar       : slv(2 downto 0);
      xLength   : slv(9 downto 0);
      attr      : slv(1 downto 0);
      ep        : sl;
      td        : sl;
      tc        : slv(2 downto 0);
      xType     : slv(4 downto 0);
      fmt       : slv(1 downto 0);
      FirstDwBe : slv(3 downto 0);
      LastDwBe  : slv(3 downto 0);
      Tag       : slv(7 downto 0);
      ReqId     : slv(15 downto 0);
      addr      : slv(31 downto 2);
      data      : slv(31 downto 0);
   end record;
   constant PCIE_HDR_INIT_C : PcieHdrType := (
      bar       => (others => '0'),
      xLength   => (others => '0'),
      attr      => (others => '0'),
      ep        => '0',
      td        => '0',
      tc        => (others => '0'),
      xType     => (others => '0'),
      fmt       => (others => '0'),
      FirstDwBe => (others => '0'),
      LastDwBe  => (others => '0'),
      Tag       => (others => '0'),
      ReqId     => (others => '0'),
      addr      => (others => '0'),
      data      => (others => '0'));  

   function reverseOrderPcie (
      axisMaster : AxiStreamMasterType;
      enReverse  : slv(3 downto 0) := "1111")
      return AxiStreamMasterType;

   function getPcieHdr (
      axisMaster : AxiStreamMasterType)
      return PcieHdrType;

end package PciePkg;

package body PciePkg is

   function reverseOrderPcie (
      axisMaster : AxiStreamMasterType;
      enReverse  : slv(3 downto 0) := "1111")
      return AxiStreamMasterType is
      variable retVar : AxiStreamMasterType;
      variable i      : natural;
   begin
      -- Reverse the order for the PCIe data interface
      for i in 0 to 3 loop
         if enReverse(i) = '1' then
            retVar.tdata((32*i)+31 downto (32*i)+24) := axisMaster.tData((32*i)+7 downto (32*i)+0);
            retVar.tdata((32*i)+23 downto (32*i)+16) := axisMaster.tData((32*i)+15 downto (32*i)+8);
            retVar.tdata((32*i)+15 downto (32*i)+8)  := axisMaster.tData((32*i)+23 downto (32*i)+16);
            retVar.tdata((32*i)+7 downto (32*i)+0)   := axisMaster.tData((32*i)+31 downto (32*i)+24);
         else
            retVar.tdata((32*i)+31 downto (32*i)+0) := axisMaster.tData((32*i)+31 downto (32*i)+0);
         end if;
      end loop;
      -- Pass through the other Master AXIS signals
      retVar.tValid := axisMaster.tValid;
      retVar.tStrb  := axisMaster.tStrb;
      retVar.tKeep  := axisMaster.tKeep;
      retVar.tLast  := axisMaster.tLast;
      retVar.tDest  := axisMaster.tDest;
      retVar.tId    := axisMaster.tId;
      retVar.tUser  := axisMaster.tUser;
      return(retVar);
   end function;
   
   function getPcieHdr (
      axisMaster : AxiStreamMasterType)
      return PcieHdrType is
      variable retVar : PcieHdrType;
   begin
      retVar.addr      := axisMaster.tdata(95 downto 66);
      -- PCIe Reserved := axisMaster.tdata(65 downto 64)
      retVar.ReqId     := axisMaster.tdata(63 downto 48);
      retVar.Tag       := axisMaster.tdata(47 downto 40);
      retVar.LastDwBe  := axisMaster.tdata(39 downto 36);
      retVar.FirstDwBe := axisMaster.tdata(35 downto 32);
      -- PCIe Reserved := axisMaster.tdata(31)
      retVar.fmt       := axisMaster.tdata(30 downto 29);
      retVar.xType     := axisMaster.tdata(28 downto 24);
      -- PCIe Reserved := axisMaster.tdata(23)
      retVar.tc        := axisMaster.tdata(22 downto 20);
      -- PCIe Reserved := axisMaster.tdata(19 downto 16)
      retVar.td        := axisMaster.tdata(15);
      retVar.ep        := axisMaster.tdata(14);
      retVar.attr      := axisMaster.tdata(13 downto 12);
      -- PCIe Reserved := axisMaster.tdata(11 downto 10)
      retVar.xLength   := axisMaster.tdata(9 downto 0);

      -- Reorder Data
      retVar.data(31 downto 24) := axisMaster.tdata(103 downto 96);
      retVar.data(23 downto 16) := axisMaster.tdata(111 downto 104);
      retVar.data(15 downto 8)  := axisMaster.tdata(119 downto 112);
      retVar.data(7 downto 0)   := axisMaster.tdata(127 downto 120);
      -- BAR encoded in the tDest
      retVar.bar                := axisMaster.tDest(2 downto 0);
      return(retVar);
   end function;

end package body PciePkg;
