-------------------------------------------------------------------------------
-- Title      : SSI PCIe Core
-------------------------------------------------------------------------------
-- File       : SsiPcieAxiLiteMaster.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-04-22
-- Last update: 2015-06-11
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: SSI PCIe to AXI-Lite Bridge Module
--
-- Note: Only support bar = 0 register transactions
-- Note: Memory IO bursting not supported.  
--       Only one 32-bit word transaction at a time.
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
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;
use work.SsiPciePkg.all;

entity SsiPcieAxiLiteMaster is
   generic (
      TPD_G      : time                   := 1 ns;
      BAR_SIZE_G : positive range 1 to 4  := 1;
      BAR_MASK_G : Slv32Array(3 downto 0) := (others => x"FFF00000")); 
   port (
      -- PCI Interface
      regTranFromPci  : in  TranFromPcieType;
      regObMaster     : in  AxiStreamMasterType;
      regObSlave      : out AxiStreamSlaveType;
      regIbMaster     : out AxiStreamMasterType;
      regIbSlave      : in  AxiStreamSlaveType;
      -- External AXI-Lite Interface
      mExtWriteMaster : out AxiLiteWriteMasterArray(BAR_SIZE_G-1 downto 0);
      mExtWriteSlave  : in  AxiLiteWriteSlaveArray(BAR_SIZE_G-1 downto 0);
      mExtReadMaster  : out AxiLiteReadMasterArray(BAR_SIZE_G-1 downto 0);
      mExtReadSlave   : in  AxiLiteReadSlaveArray(BAR_SIZE_G-1 downto 0);
      -- Internal AXI-Lite Interface
      mIntWriteMaster : out AxiLiteWriteMasterType;
      mIntWriteSlave  : in  AxiLiteWriteSlaveType;
      mIntReadMaster  : out AxiLiteReadMasterType;
      mIntReadSlave   : in  AxiLiteReadSlaveType;
      -- Global Signals
      pciClk          : in  sl;
      pciRst          : in  sl);
end SsiPcieAxiLiteMaster;

architecture rtl of SsiPcieAxiLiteMaster is

   constant PIO_CPLD_FMT_TYPE_C : slv(6 downto 0)  := "1001010";
   constant PIO_CPL_FMT_TYPE_C  : slv(6 downto 0)  := "0001010";
   constant INT_BAR_MASK_C      : slv(31 downto 0) := x"FFFFF000";

   function GenAddr (
      hdr  : PcieHdrType;
      mask : slv(31 downto 0))
      return slv(31 downto 0) is
      variable i      : natural;
      variable retVar : slv(31 downto 0);
   begin
      -- Setup for 32-bit alignment
      retVar(1 downto 0) := "00";
      -- Loop through the bit field
      for i in 31 downto 2 loop
         retVar(i) := hdr.addr(i) and not(mask(i));
      end loop;
      -- Forward the updated address value
      return(retVar);
   end function;

   type stateType is (
      IDLE_S,
      RD_AXI_LITE_TRANS_S,
      ACK_HDR_S,
      WR_AXI_LITE_TRANS_S);    

   type RegType is record
      rdData          : slv(31 downto 0);
      hdr             : PcieHdrType;
      mExtWriteMaster : AxiLiteWriteMasterArray(BAR_SIZE_G-1 downto 0);
      mExtReadMaster  : AxiLiteReadMasterArray(BAR_SIZE_G-1 downto 0);
      mIntWriteMaster : AxiLiteWriteMasterType;
      mIntReadMaster  : AxiLiteReadMasterType;
      regObSlave      : AxiStreamSlaveType;
      txMaster        : AxiStreamMasterType;
      state           : StateType;
   end record RegType;
   
   constant REG_INIT_C : RegType := (
      rdData          => (others => '0'),
      hdr             => PCIE_HDR_INIT_C,
      mExtWriteMaster => (others => AXI_LITE_WRITE_MASTER_INIT_C),
      mExtReadMaster  => (others => AXI_LITE_READ_MASTER_INIT_C),
      mIntWriteMaster => AXI_LITE_WRITE_MASTER_INIT_C,
      mIntReadMaster  => AXI_LITE_READ_MASTER_INIT_C,
      regObSlave      => AXI_STREAM_SLAVE_INIT_C,
      txMaster        => AXI_STREAM_MASTER_INIT_C,
      state           => IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   -- attribute dont_touch : string;
   -- attribute dont_touch of r : signal is "true";
   
begin
   
   comb : process (mExtReadSlave, mExtWriteSlave, mIntReadSlave, mIntWriteSlave, pciRst, r,
                   regIbSlave, regObMaster, regTranFromPci) is
      variable v      : RegType;
      variable header : PcieHdrType;
      variable bar    : natural;
   begin
      -- Latch the current value
      v := r;

      -- Reset strobing signals
      v.regObSlave.tReady := '0';

      -- Update tValid register
      if regIbSlave.tReady = '1' then
         v.txMaster.tValid := '0';
      end if;

      -- Create integer version of bar
      bar := conv_integer(r.hdr.bar);

      -- Decode the current header for the FIFO
      header := getPcieHdr(regObMaster);

      case r.state is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Reset the read data bus
            v.rdData := (others => '1');
            -- Check for FIFO data
            if regObMaster.tValid = '1' then
               -- ACK the FIFO tValid
               v.regObSlave.tReady := '1';
               -- Latch the header
               v.hdr               := header;
               -- Check for valid read operation
               if (header.fmt(1) = '0') and ((header.bar < BAR_SIZE_G) or (header.bar = 4)) then
                  if header.bar = 4 then
                     -- Set the read address buses
                     v.mIntReadMaster.araddr  := GenAddr(header, INT_BAR_MASK_C);
                     -- Start AXI-Lite transaction
                     v.mIntReadMaster.arvalid := '1';
                     v.mIntReadMaster.rready  := '1';
                  else
                     -- Set the read address buses
                     v.mExtReadMaster(conv_integer(header.bar)).araddr  := GenAddr(header, BAR_MASK_G(conv_integer(header.bar)));
                     -- Start AXI-Lite transaction
                     v.mExtReadMaster(conv_integer(header.bar)).arvalid := '1';
                     v.mExtReadMaster(conv_integer(header.bar)).rready  := '1';
                  end if;
                  -- Next state
                  v.state := RD_AXI_LITE_TRANS_S;
               else
                  -- Next state
                  v.state := ACK_HDR_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when RD_AXI_LITE_TRANS_S =>
            if bar = 4 then
               -- Check if we need to clear the arvalid flag
               if mIntReadSlave.arready = '1' then
                  v.mIntReadMaster.arvalid := '0';
               end if;
               -- Check if we need to clear the rready flag
               if mIntReadSlave.rvalid = '1' then
                  v.mIntReadMaster.rready := '0';
                  -- Check for a valid responds
                  if mIntReadSlave.rresp = AXI_RESP_OK_C then
                     v.rdData := mIntReadSlave.rdata;
                  end if;
               end if;
               -- Check if transaction is done
               if v.mIntReadMaster.arvalid = '0' and
                  v.mIntReadMaster.rready = '0' then
                  -- Next State
                  v.state := ACK_HDR_S;
               end if;
            else
               -- Check if we need to clear the arvalid flag
               if mExtReadSlave(bar).arready = '1' then
                  v.mExtReadMaster(bar).arvalid := '0';
               end if;
               -- Check if we need to clear the rready flag
               if mExtReadSlave(bar).rvalid = '1' then
                  v.mExtReadMaster(bar).rready := '0';
                  -- Check for a valid responds
                  if mExtReadSlave(bar).rresp = AXI_RESP_OK_C then
                     v.rdData := mExtReadSlave(bar).rdata;
                  end if;
               end if;
               -- Check if transaction is done
               if v.mExtReadMaster(bar).arvalid = '0' and
                  v.mExtReadMaster(bar).rready = '0' then
                  -- Next State
                  v.state := ACK_HDR_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when ACK_HDR_S =>
            -- Check if target is ready for data
            if v.txMaster.tValid = '0' then
               -- Check for read operation
               if r.hdr.fmt(1) = '0' then
                  -- Write to the FIFO
                  v.txMaster.tValid                := '1';
                  -- Set the EOF bit
                  v.txMaster.tLast                 := '1';
                  -- TLP = DW0/H2/H1/H0
                  v.txMaster.tKeep                 := x"FFFF";
                  --DW0 (Reordered Data)
                  v.txMaster.tData(103 downto 96)  := r.rdData(31 downto 24);
                  v.txMaster.tData(111 downto 104) := r.rdData(23 downto 16);
                  v.txMaster.tData(119 downto 112) := r.rdData(15 downto 8);
                  v.txMaster.tData(127 downto 120) := r.rdData(7 downto 0);
                  --H2
                  v.txMaster.tData(95 downto 80)   := r.hdr.ReqId;  -- Echo back requester ID
                  v.txMaster.tData(79 downto 72)   := r.hdr.Tag;    -- Echo back Tag               
                  v.txMaster.tData(71)             := '0';   -- PCIe Reserved
                  v.txMaster.tData(70 downto 64)   := r.hdr.addr(6 downto 2) & "00";
                  --H1
                  v.txMaster.tData(63 downto 48)   := regTranFromPci.locId;  -- Send Completer ID                  
                  v.txMaster.tData(47 downto 45)   := "000";        -- Success
                  v.txMaster.tData(44)             := '0';   -- PCIe Reserved
                  v.txMaster.tData(43 downto 32)   := x"004";
                  --H0
                  v.txMaster.tData(31)             := '0';   -- PCIe Reserved               
                  v.txMaster.tData(30 downto 24)   := PIO_CPLD_FMT_TYPE_C;
                  v.txMaster.tData(23)             := '0';   -- PCIe Reserved
                  v.txMaster.tData(22 downto 20)   := r.hdr.tc;     -- Echo back TC bit
                  v.txMaster.tData(19 downto 16)   := "0000";       -- PCIe Reserved
                  v.txMaster.tData(15)             := '0';   -- TD Field
                  v.txMaster.tData(14)             := '0';   -- EP Field
                  v.txMaster.tData(13 downto 12)   := r.hdr.attr;   -- Echo back ATTR
                  v.txMaster.tData(11 downto 10)   := "00";  -- PCIe Reserved                  
                  v.txMaster.tData(9 downto 0)     := toSlv(1, 10);
               end if;
               -------------------------------------------------------------------
               -- Note: Memory write operation are "posted" only, which should not
               --       respond with a completion TLP (Refer to page 179 of 
               --       "PCI Express System Architecture" ISBN: 0-321-15630-7)
               -------------------------------------------------------------------           
               -- Check for valid write operation
               if (r.hdr.fmt(1) = '1') and ((bar < BAR_SIZE_G) or (bar = 4)) then
                  if bar = 4 then
                     -- Set the write address buses
                     v.mIntWriteMaster.awaddr  := GenAddr(r.hdr, INT_BAR_MASK_C);
                     -- Set the write data buses
                     v.mIntWriteMaster.wdata   := r.hdr.data;
                     v.mIntWriteMaster.wstrb   := r.hdr.FirstDwBe;
                     -- Start AXI-Lite transaction
                     v.mIntWriteMaster.awvalid := '1';
                     v.mIntWriteMaster.wvalid  := '1';
                     v.mIntWriteMaster.bready  := '1';
                  else
                     -- Set the write address buses
                     v.mExtWriteMaster(bar).awaddr  := GenAddr(r.hdr, BAR_MASK_G(bar));
                     -- Set the write data buses
                     v.mExtWriteMaster(bar).wdata   := r.hdr.data;
                     v.mExtWriteMaster(bar).wstrb   := r.hdr.FirstDwBe;
                     -- Start AXI-Lite transaction
                     v.mExtWriteMaster(bar).awvalid := '1';
                     v.mExtWriteMaster(bar).wvalid  := '1';
                     v.mExtWriteMaster(bar).bready  := '1';
                  end if;
                  -- Next state
                  v.state := WR_AXI_LITE_TRANS_S;
               else
                  -- Next state
                  v.state := IDLE_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when WR_AXI_LITE_TRANS_S =>
            if bar = 4 then
               -- Check if we need to clear the awvalid flag
               if mIntWriteSlave.awready = '1' then
                  v.mIntWriteMaster.awvalid := '0';
               end if;
               -- Check if we need to clear the wvalid flag
               if mIntWriteSlave.wready = '1' then
                  v.mIntWriteMaster.wvalid := '0';
               end if;
               -- Check if we need to clear the bready flag
               if mIntWriteSlave.bvalid = '1' then
                  v.mIntWriteMaster.bready := '0';
               end if;
               -- Check if transaction is done
               if v.mIntWriteMaster.awvalid = '0' and
                  v.mIntWriteMaster.wvalid = '0' and
                  v.mIntWriteMaster.bready = '0' then
                  -- Next state
                  v.state := IDLE_S;
               end if;
            else
               -- Check if we need to clear the awvalid flag
               if mExtWriteSlave(bar).awready = '1' then
                  v.mExtWriteMaster(bar).awvalid := '0';
               end if;
               -- Check if we need to clear the wvalid flag
               if mExtWriteSlave(bar).wready = '1' then
                  v.mExtWriteMaster(bar).wvalid := '0';
               end if;
               -- Check if we need to clear the bready flag
               if mExtWriteSlave(bar).bvalid = '1' then
                  v.mExtWriteMaster(bar).bready := '0';
               end if;
               -- Check if transaction is done
               if v.mExtWriteMaster(bar).awvalid = '0' and
                  v.mExtWriteMaster(bar).wvalid = '0' and
                  v.mExtWriteMaster(bar).bready = '0' then
                  -- Next state
                  v.state := IDLE_S;
               end if;
            end if;
      ----------------------------------------------------------------------
      end case;

      -- Reset
      if (pciRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs
      regObSlave      <= v.regObSlave;
      regIbMaster     <= r.txMaster;
      mIntWriteMaster <= r.mIntWriteMaster;
      mIntReadMaster  <= r.mIntReadMaster;
      mExtWriteMaster <= r.mExtWriteMaster;
      mExtReadMaster  <= r.mExtReadMaster;
      
   end process comb;

   seq : process (pciClk) is
   begin
      if rising_edge(pciClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;
