-------------------------------------------------------------------------------
-- Title      : AXI PCIe Core
-------------------------------------------------------------------------------
-- File       : AxiPcieAxiToTlp.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-11-09
-- Last update: 2015-11-09
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: AXI-to-TLP Bridge
-------------------------------------------------------------------------------
-- Copyright (c) 2015 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;
use work.AxiPkg.all;
use work.AxiStreamPkg.all;
use work.AxiPciePkg.all;
use work.SsiPkg.all;

entity AxiPcieAxiToTlp is
   generic (
      TPD_G : time := 1 ns);
   port (
      -- AXI Interface
      axiWriteMaster   : in  AxiWriteMasterType;
      axiWriteSlave    : out AxiWriteSlaveType;
      -- PCIe Interface
      dmaRxTranFromPci : in  TranFromPcieType;
      dmaRxIbMaster    : out AxiStreamMasterType;
      dmaRxIbSlave     : in  AxiStreamSlaveType;
      -- Clock and Resets
      pciClk           : in  sl;
      pciRst           : in  sl);       
end AxiPcieAxiToTlp;

architecture rtl of AxiPcieAxiToTlp is

   type StateType is (
      IDLE_S,
      SEND_IO_REQ_HDR_S,
      MOVE_S,
      LAST_S);    

   type RegType is record
      tranLength    : slv(9 downto 0);
      address       : slv(31 downto 0);
      wdata         : slv(95 downto 0);
      dmaRxIbMaster : AxiStreamMasterType;
      axiWriteSlave : AxiWriteSlaveType;
      state         : StateType;
   end record RegType;
   
   constant REG_INIT_C : RegType := (
      tranLength    => (others => '0'),
      address       => (others => '0'),
      wdata         => (others => '0'),
      dmaRxIbMaster => AXI_STREAM_MASTER_INIT_C,
      axiWriteSlave => AXI_WRITE_SLAVE_INIT_C,
      state         => IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   -- attribute dont_touch : string;
   -- attribute dont_touch of r : signal is "true";
   
begin
   
   comb : process (axiWriteMaster, dmaRxIbSlave, dmaRxTranFromPci, pciRst, r) is
      variable v         : RegType;
      variable i         : natural;
      variable increment : natural;
   begin
      -- Latch the current value
      v := r;

      -- Reset signals
      v.axiWriteSlave.awready := '0';
      v.axiWriteSlave.wready  := '0';
      if axiWriteMaster.bready = '1' then
         v.axiWriteSlave.bvalid  := '0';
      end if;      
      if dmaRxIbSlave.tReady = '1' then
         v.dmaRxIbMaster.tValid := '0';
         v.dmaRxIbMaster.tLast  := '0';
      end if;

      case r.state is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Check for new transaction
            if (axiWriteMaster.awvalid = '1') then
               -- Accept the address
               v.axiWriteSlave.awready  := '1';
               -- Set the address
               v.address                := axiWriteMaster.awaddr;
               -- Set the PCIe transfer length (Only transfer 128-bit data words)
               v.tranLength(9 downto 2) := axiWriteMaster.awlen;
               v.tranLength(1 downto 0) := "11";
               -- Next state
               v.state                  := SEND_IO_REQ_HDR_S;
            end if;
         ----------------------------------------------------------------------
         when SEND_IO_REQ_HDR_S =>
            -- Check if ready to move data 
            if (v.dmaRxIbMaster.tValid = '0') and (axiWriteMaster.wvalid = '1') then
               -- Ready for data
               v.axiWriteSlave.wready               := '1';
               v.dmaRxIbMaster.tValid               := '1';
               -- Set AXIS tKeep
               v.dmaRxIbMaster.tKeep                := x"FFFF";
               -- Track the unused data 
               v.wdata                              := axiWriteMaster.wdata(127 downto 32);
               ------------------------------------------------------
               -- generated a TLP 3-DW data transfer with payload 
               --
               -- data(127:96) = D0  
               -- data(095:64) = H2  
               -- data(063:32) = H1
               -- data(031:00) = H0                 
               ------------------------------------------------------                                      
               --D0
               v.dmaRxIbMaster.tData(127 downto 96) := axiWriteMaster.wdata(31 downto 0);
               --H2
               v.dmaRxIbMaster.tData(95 downto 66)  := r.address(31 downto 2);
               v.dmaRxIbMaster.tData(65 downto 64)  := "00";  --PCIe reserved
               --H1
               v.dmaRxIbMaster.tData(63 downto 48)  := dmaRxTranFromPci.locId;  -- Requester ID
               v.dmaRxIbMaster.tData(47 downto 40)  := dmaRxTranFromPci.tag;    -- Tag
               v.dmaRxIbMaster.tData(39 downto 36)  := "1111";   -- Last DW Byte Enable
               v.dmaRxIbMaster.tData(35 downto 32)  := "1111";   -- First DW Byte Enable
               --H0
               v.dmaRxIbMaster.tData(31)            := '0';   --PCIe reserved
               v.dmaRxIbMaster.tData(30 downto 29)  := "10";  -- FMT = Memory write, 3-DW header with payload
               v.dmaRxIbMaster.tData(28 downto 24)  := "00000";  -- Type = Memory read or write
               v.dmaRxIbMaster.tData(23)            := '0';   --PCIe reserved
               v.dmaRxIbMaster.tData(22 downto 20)  := "000";    -- TC = 0
               v.dmaRxIbMaster.tData(19 downto 16)  := "0000";   --PCIe reserved
               v.dmaRxIbMaster.tData(15)            := '0';   -- TD = 0
               v.dmaRxIbMaster.tData(14)            := '0';   -- EP = 0
               v.dmaRxIbMaster.tData(13 downto 12)  := "00";  -- Attr = 0
               v.dmaRxIbMaster.tData(11 downto 10)  := "00";  --PCIe reserved
               v.dmaRxIbMaster.tData(9 downto 0)    := r.tranLength+1;  -- Transaction length
               -- Check for last transfer
               if r.tranLength = 3 then
                  -- Next state
                  v.state := LAST_S;
               else
                  -- Next state
                  v.state := MOVE_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when MOVE_S =>
            -- Check if ready to move data 
            if (v.dmaRxIbMaster.tValid = '0') and (axiWriteMaster.wvalid = '1') then
               -- Ready for data
               v.axiWriteSlave.wready               := '1';
               v.dmaRxIbMaster.tValid               := '1';
               -- Set AXIS tKeep
               v.dmaRxIbMaster.tKeep                := x"FFFF";
               -- Track the unused data 
               v.wdata                              := axiWriteMaster.wdata(127 downto 32);
               -- Set the data bus
               v.dmaRxIbMaster.tData(127 downto 96) := axiWriteMaster.wdata(31 downto 0);
               v.dmaRxIbMaster.tData(95 downto 0)   := r.wdata;
               -- Decrement the counter
               v.tranLength                         := r.tranLength - 4;
               -- Check for last transfer
               if v.tranLength = 3 then
                  -- Next state
                  v.state := LAST_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when LAST_S =>
            -- Check if ready to move data 
            if (v.dmaRxIbMaster.tValid = '0') then
               -- Ready for data
               v.dmaRxIbMaster.tValid               := '1';
               -- Set AXIS tKeep
               v.dmaRxIbMaster.tKeep                := x"0FFF";
               -- Set the data bus
               v.dmaRxIbMaster.tData(127 downto 96) := (others => '0');
               v.dmaRxIbMaster.tData(95 downto 0)   := r.wdata;
               -- Set EOF
               v.dmaRxIbMaster.tLast                := '1';
               -- Acknowledge the transfer
               v.axiWriteSlave.bvalid               := '1';
               -- Next state
               v.state                              := IDLE_S;
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
      axiWriteSlave <= v.axiWriteSlave;
      dmaRxIbMaster <= r.dmaRxIbMaster;
      
   end process comb;

   seq : process (pciClk) is
   begin
      if rising_edge(pciClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;
