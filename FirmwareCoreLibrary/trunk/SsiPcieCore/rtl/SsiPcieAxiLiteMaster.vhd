-------------------------------------------------------------------------------
-- Title      : SSI PCIe Core
-------------------------------------------------------------------------------
-- File       : SsiPcieAxiLiteMaster.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-04-22
-- Last update: 2015-04-22
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: SSI PCIe to AXI-Lite Bridge Module
--
-- Note: Only support bar = 0 register transactions
-- Note: Memory IO bursting not supported.  
--       Only one 32-bit word transaction at a time.
-------------------------------------------------------------------------------
-- Copyright (c) 2015 SLAC National Accelerator Laboratory
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
      TPD_G : time := 1 ns); 
   port (
      -- PCI Interface
      regTranFromPci      : in  TranFromPcieType;
      regObMaster         : in  AxiStreamMasterType;
      regObSlave          : out AxiStreamSlaveType;
      regIbMaster         : out AxiStreamMasterType;
      regIbSlave          : in  AxiStreamSlaveType;
      -- AXI-Lite Interface
      mAxiLiteWriteMaster : out AxiLiteWriteMasterType;
      mAxiLiteWriteSlave  : in  AxiLiteWriteSlaveType;
      mAxiLiteReadMaster  : out AxiLiteReadMasterType;
      mAxiLiteReadSlave   : in  AxiLiteReadSlaveType;
      -- Global Signals
      pciClk              : in  sl;
      pciRst              : in  sl);
end SsiPcieAxiLiteMaster;

architecture rtl of SsiPcieAxiLiteMaster is

   type stateType is (
      IDLE_S,
      RD_AXI_LITE_TRANS_S,
      ACK_HDR_S,
      WR_AXI_LITE_TRANS_S);   

   type RegType is record
      rdData      : slv(31 downto 0);
      hdr         : PcieHdrType;
      writeMaster : AxiLiteWriteMasterType;
      readMaster  : AxiLiteReadMasterType;
      regObSlave  : AxiStreamSlaveType;
      txMaster    : AxiStreamMasterType;
      state       : StateType;
   end record RegType;
   
   constant REG_INIT_C : RegType := (
      rdData      => (others => '0'),
      hdr         => PCIE_HDR_INIT_C,
      writeMaster => AXI_LITE_WRITE_MASTER_INIT_C,
      readMaster  => AXI_LITE_READ_MASTER_INIT_C,
      regObSlave  => AXI_STREAM_SLAVE_INIT_C,
      txMaster    => AXI_STREAM_MASTER_INIT_C,
      state       => IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin
   
   comb : process (mAxiLiteReadSlave, mAxiLiteWriteSlave, pciRst, r, regIbSlave, regObMaster,
                   regTranFromPci) is
      variable v      : RegType;
      variable header : PcieHdrType;
   begin
      -- Latch the current value
      v := r;

      -- Reset strobing signals
      v.regObSlave.tReady := '0';

      -- Update tValid register
      if regIbSlave.tReady = '1' then
         v.txMaster.tValid := '0';
      end if;

      -- Decode the current header for the FIFO
      header := getPcieHdr(regObMaster);

      case r.state is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Check for FIFO data
            if regObMaster.tValid = '1' then
               -- ACK the FIFO tValid
               v.regObSlave.tReady := '1';
               -- Latch the header
               v.hdr               := header;
               -- Check for valid read operation
               if (header.fmt(1) = '0') and (header.bar = 0) then
                  -- Set the read address buses
                  v.readMaster.araddr(1 downto 0)  := "00";             -- 32-bit alignment
                  v.readMaster.araddr(31 downto 2) := header.addr;
                  -- Start AXI-Lite transaction
                  v.readMaster.arvalid             := '1';
                  v.readMaster.rready              := '1';
                  -- Next state
                  v.state                          := RD_AXI_LITE_TRANS_S;
               else
                  -- Next state
                  v.state := ACK_HDR_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when RD_AXI_LITE_TRANS_S =>
            -- Check if we need to clear the arvalid flag
            if mAxiLiteReadSlave.arready = '1' then
               v.readMaster.arvalid := '0';
            end if;
            -- Check if we need to clear the rready flag
            if mAxiLiteReadSlave.rvalid = '1' then
               v.readMaster.rready := '0';
               v.rdData            := mAxiLiteReadSlave.rdata;
            end if;
            -- Check if transaction is done
            if v.readMaster.arvalid = '0' and
               v.readMaster.rready = '0' then
               -- Next State
               v.state := ACK_HDR_S;
            end if;
         ----------------------------------------------------------------------
         when ACK_HDR_S =>
            -- Check if target is ready for data
            if v.txMaster.tValid = '0' then
               ------------------------------------------------------
               -- Generate a 3-DW completion TPL             
               ------------------------------------------------------
               --DW0
               if(r.hdr.bar /= 0) then
                  v.txMaster.tData(127 downto 96) := (others => '0');
               elsif r.hdr.fmt(1) = '1' then           --echo back write data
                  -- Reorder Data
                  v.txMaster.tData(103 downto 96)  := r.hdr.data(31 downto 24);
                  v.txMaster.tData(111 downto 104) := r.hdr.data(23 downto 16);
                  v.txMaster.tData(119 downto 112) := r.hdr.data(15 downto 8);
                  v.txMaster.tData(127 downto 120) := r.hdr.data(7 downto 0);
               else                     --send read data 
                  -- Reorder Data
                  v.txMaster.tData(103 downto 96)  := r.rdData(31 downto 24);
                  v.txMaster.tData(111 downto 104) := r.rdData(23 downto 16);
                  v.txMaster.tData(119 downto 112) := r.rdData(15 downto 8);
                  v.txMaster.tData(127 downto 120) := r.rdData(7 downto 0);
               end if;
               --H2
               v.txMaster.tData(95 downto 80) := r.hdr.ReqId;           -- Echo back requester ID
               v.txMaster.tData(79 downto 72) := r.hdr.Tag;             -- Echo back Tag
               v.txMaster.tData(71)           := '0';  -- PCIe Reserved
               v.txMaster.tData(70 downto 64) := r.hdr.addr(6 downto 2) & "00";  -- Send back Lower Address
               --H1
               v.txMaster.tData(63 downto 48) := regTranFromPci.locId;  -- Send Completer ID
               -- Check for write operation
               if r.hdr.xType /= 0 then
                  v.txMaster.tData(47 downto 45) := "001";              -- Unsupported
               else
                  v.txMaster.tData(47 downto 45) := "000";              -- Success
               end if;
               v.txMaster.tData(44)           := '0';  --The BCM field is always zero, except when a packet origins from a bridge with PCI-X. So it’s zero.
               v.txMaster.tData(43 downto 32) := x"004";   --Byte Count - sending 4 bytes
               --H0
               v.txMaster.tData(31)           := '0';  -- PCIe Reserved
               -- Check for write operation
               if r.hdr.fmt(1) = '1' then
                  v.txMaster.tData(30 downto 29) := "00";
               else
                  v.txMaster.tData(30 downto 29) := "10";
               end if;
               v.txMaster.tData(28 downto 24) := "01010";  --Type=0x0A for completion TLP
               v.txMaster.tData(23)           := '0';  -- PCIe Reserved
               v.txMaster.tData(22 downto 20) := r.hdr.tc;              -- Echo back TC bit
               v.txMaster.tData(19 downto 16) := "0000";   -- PCIe Reserved
               v.txMaster.tData(15)           := r.hdr.td;              -- Echo back TD bit
               v.txMaster.tData(14)           := r.hdr.ep;              -- Echo back EP bit
               v.txMaster.tData(13 downto 12) := r.hdr.attr;            -- Echo back ATTR
               v.txMaster.tData(11 downto 10) := "00";     -- PCIe Reserved
               v.txMaster.tData(9 downto 0)   := r.hdr.xLength;         -- Echo back the length
               ------------------------------------------------------  
               -- Write to the FIFO
               v.txMaster.tValid              := '1';
               -- Set the EOF bit
               v.txMaster.tLast               := '1';
               -- Check for write operation
               if r.hdr.fmt(1) = '1' then
                  v.txMaster.tKeep := x"0FFF";
               else
                  v.txMaster.tKeep := x"FFFF";
               end if;
               -- Check for valid write operation
               if (r.hdr.fmt(1) = '1') and (r.hdr.bar = 0) then
                  -- Set the write address buses
                  v.writeMaster.awaddr(1 downto 0)  := "00";            -- 32-bit alignment
                  v.writeMaster.awaddr(31 downto 2) := r.hdr.addr;
                  -- Set the write data buses
                  v.writeMaster.wdata               := r.hdr.data;
                  -- Start AXI-Lite transaction
                  v.writeMaster.awvalid             := '1';
                  v.writeMaster.wvalid              := '1';
                  v.writeMaster.bready              := '1';
                  -- Next state
                  v.state                           := WR_AXI_LITE_TRANS_S;
               else
                  -- Next state
                  v.state := IDLE_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when WR_AXI_LITE_TRANS_S =>
            -- Check if we need to clear the awvalid flag
            if mAxiLiteWriteSlave.awready = '1' then
               v.writeMaster.awvalid := '0';
            end if;
            -- Check if we need to clear the wvalid flag
            if mAxiLiteWriteSlave.wready = '1' then
               v.writeMaster.wvalid := '0';
            end if;
            -- Check if we need to clear the bready flag
            if mAxiLiteWriteSlave.bvalid = '1' then
               v.writeMaster.bready := '0';
            end if;
            -- Check if transaction is done
            if v.writeMaster.awvalid = '0' and
               v.writeMaster.wvalid = '0' and
               v.writeMaster.bready = '0' then
               -- Next state
               v.state := IDLE_S;
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
      mAxiLiteWriteMaster <= r.writeMaster;
      mAxiLiteReadMaster  <= r.readMaster;
      regObSlave          <= v.regObSlave;
      regIbMaster         <= r.txMaster;
      
   end process comb;

   seq : process (pciClk) is
   begin
      if rising_edge(pciClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;
