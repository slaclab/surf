-------------------------------------------------------------------------------
-- Title      : SSI PCIe Core
-------------------------------------------------------------------------------
-- File       : SsiPciePkg.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-04-22
-- Last update: 2015-08-17
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Package file for SSI PCIe Core
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
use work.AxiStreamPkg.all;
use work.SsiPkg.all;

package SsiPciePkg is

   constant PCIE_AXIS_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(16);

   -- Max transfer length, words
   constant PCIE_MAX_RX_TRANS_LENGTH_C : integer := 32;  -- 128 Bytes, smallest to ensure comparability
   constant PCIE_MAX_TX_TRANS_LENGTH_C : integer := 256;  -- Request large amounts of data, will be broken up

   ------------------------------------------------------------------------
   -- TranToPci Types/Constants                             
   ------------------------------------------------------------------------          
   -- Transaction FIFO Interface, To PCI
   type TranToPcieType is record
      txReq  : sl;                      -- Transaction Request
      trPend : sl;                      -- Transaction is pending
   end record;
   type TranToPcieArray is array (integer range<>) of TranToPcieType;

   ------------------------------------------------------------------------
   -- TranFromPci Types/Constants                             
   ------------------------------------------------------------------------              
   -- Transaction FIFO Interface, From PCI
   type TranFromPcieType is record
      locId : slv(15 downto 0);         -- Assigned local ID
      tag   : slv(7 downto 0);          -- Assigned tag
   end record;
   type TranFromPcieArray is array (integer range<>) of TranFromPcieType;
   constant TRAN_FROM_PCIE_INIT_C : TranFromPcieType := (
      locId => (others => '0'),
      tag   => (others => '0'));   

   ------------------------------------------------------------------------
   -- DescToPci Types/Constants                             
   ------------------------------------------------------------------------                  
   type DescToPcieType is record
      newReq       : sl;                -- Request for new descriptor address
      doneReq      : sl;                -- Transfer done request
      doneFrameErr : sl;                -- Status for descriptor     (Rx Only)
      doneTranEofe : sl;                -- Status for descriptor     (Rx Only)
      doneDmaCh    : slv(3 downto 0);   -- Status for descriptor     (Rx Only)
      doneSubCh    : slv(3 downto 0);   -- Status for descriptor     (Rx Only)    
      doneAddr     : slv(31 downto 2);  -- Address for descriptor
      doneLength   : slv(23 downto 0);  -- Length in dwords, 1 based (Rx Only)
   end record;
   type DescToPcieArray is array (integer range<>) of DescToPcieType;
   constant DESC_TO_PCIE_INIT_C : DescToPcieType := (
      newReq       => '0',
      doneReq      => '0',
      doneFrameErr => '0',
      doneTranEofe => '0',
      doneDmaCh    => (others => '0'),
      doneSubCh    => (others => '0'),
      doneAddr     => (others => '0'),
      doneLength   => (others => '0'));

   ------------------------------------------------------------------------
   -- DescFromPci Types/Constants                             
   ------------------------------------------------------------------------                      
   type DescFromPcieType is record
      newAck    : sl;                   -- New descriptor ack
      newAddr   : slv(31 downto 2);     -- Address for descriptor
      newLength : slv(23 downto 0);     -- Length in dwords, 1 based (TX Only)
      newDmaCh  : slv(3 downto 0);      -- Control word              (TX Only)
      newSubCh  : slv(3 downto 0);      -- Control word              (TX Only)
      doneAck   : sl;                   -- Descriptor done ack
      maxFrame  : slv(23 downto 0);     -- Max Frame Length, dwords, 1 based
   end record;
   type DescFromPcieArray is array (integer range<>) of DescFromPcieType;

   ------------------------------------------------------------------------
   -- CfgIn Types/Constants                             
   ------------------------------------------------------------------------        
   type PcieCfgInType is record
      irqReq       : sl;
      irqAssert    : sl;
      trnPending   : sl;
      turnoffOk    : sl;
      serialNumber : slv(63 downto 0);
   end record;

   ------------------------------------------------------------------------
   -- CfgOut Types/Constants                             
   ------------------------------------------------------------------------            
   type PcieCfgOutType is record
      toTurnOff      : sl;
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

end package SsiPciePkg;

package body SsiPciePkg is

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

end package body SsiPciePkg;
