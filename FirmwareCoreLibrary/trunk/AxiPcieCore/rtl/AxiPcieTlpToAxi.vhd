-------------------------------------------------------------------------------
-- Title      : AXI PCIe Core
-------------------------------------------------------------------------------
-- File       : AxiPcieTlpToAxi.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-11-09
-- Last update: 2015-11-16
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

entity AxiPcieTlpToAxi is
   generic (
      TPD_G : time := 1 ns);
   port (
      -- AXI Interface
      axiReadMaster    : in  AxiReadMasterType;
      axiReadSlave     : out AxiReadSlaveType;
      -- PCIe Interface
      dmaTxTranFromPci : in  TranFromPcieType;
      dmaTxObMaster    : in  AxiStreamMasterType;
      dmaTxObSlave     : out AxiStreamSlaveType;
      dmaTxIbMaster    : out AxiStreamMasterType;
      dmaTxIbSlave     : in  AxiStreamSlaveType;
      -- Clock and Resets
      pciClk           : in  sl;
      pciRst           : in  sl);       
end AxiPcieTlpToAxi;

architecture rtl of AxiPcieTlpToAxi is

   type StateType is (
      IDLE_S,
      MOVE_S);    

   type RegType is record
      reqRdy        : sl;
      reqAddr       : slv(29 downto 0);
      tranLength    : slv(9 downto 0);
      address       : slv(31 downto 0);
      rdata         : slv(31 downto 0);
      dmaTxIbMaster : AxiStreamMasterType;
      rxSlave       : AxiStreamSlaveType;
      axiReadSlave  : AxiReadSlaveType;
      state         : StateType;
   end record RegType;
   
   constant REG_INIT_C : RegType := (
      reqRdy        => '0',
      reqAddr       => (others => '0'),
      tranLength    => (others => '0'),
      address       => (others => '0'),
      rdata         => (others => '0'),
      dmaTxIbMaster => AXI_STREAM_MASTER_INIT_C,
      rxSlave       => AXI_STREAM_SLAVE_INIT_C,
      axiReadSlave  => AXI_READ_SLAVE_INIT_C,
      state         => IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal axisMaster : AxiStreamMasterType;
   signal rxMaster   : AxiStreamMasterType;
   signal rxSlave    : AxiStreamSlaveType;

   -- attribute dont_touch : string;
   -- attribute dont_touch of r : signal is "true";
   
begin

   FIFO_RX : entity work.AxiStreamFifo
      generic map (
         -- General Configurations
         TPD_G               => TPD_G,
         PIPE_STAGES_G       => 0,
         SLAVE_READY_EN_G    => true,
         VALID_THOLD_G       => 1,
         -- FIFO configurations
         BRAM_EN_G           => true,
         USE_BUILT_IN_G      => false,
         GEN_SYNC_FIFO_G     => true,
         CASCADE_SIZE_G      => 1,
         FIFO_ADDR_WIDTH_G   => 9,
         FIFO_FIXED_THRESH_G => true,
         FIFO_PAUSE_THRESH_G => 256,
         -- AXI Stream Port Configurations
         SLAVE_AXI_CONFIG_G  => PCIE_AXIS_CONFIG_C,
         MASTER_AXI_CONFIG_G => PCIE_AXIS_CONFIG_C)            
      port map (
         -- Slave Port
         sAxisClk    => pciClk,
         sAxisRst    => pciRst,
         sAxisMaster => dmaTxObMaster,
         sAxisSlave  => dmaTxObSlave,
         -- Master Port
         mAxisClk    => pciClk,
         mAxisRst    => pciRst,
         mAxisMaster => axisMaster,
         mAxisSlave  => rxSlave);  

   -- Reverse the data order
   rxMaster <= reverseOrderPcie(axisMaster);

   comb : process (axiReadMaster, dmaTxIbSlave, dmaTxTranFromPci, pciRst, r, rxMaster) is
      variable v         : RegType;
      variable reqLength : slv(9 downto 0);
   begin
      -- Latch the current value
      v := r;

      -- Reset signals
      v.axiReadSlave.arready := '0';
      if axiReadMaster.rready = '1' then
         v.axiReadSlave.rvalid := '0';
         v.axiReadSlave.rlast  := '0';
      end if;
      if dmaTxIbSlave.tReady = '1' then
         v.dmaTxIbMaster.tValid := '0';
         v.dmaTxIbMaster.tlast  := '0';
      end if;

      -- Check if ready to make memory request
      if (v.dmaTxIbMaster.tValid = '0') and (axiReadMaster.arvalid = '1') and (r.reqRdy = '0') then
         -- Accept the memory request
         v.axiReadSlave.arready               := '1';
         -- Set the flag
         v.reqRdy                             := '1';
         v.reqAddr                            := axiReadMaster.araddr(31 downto 2);
         -- Set the PCIe request length (Only transfer 128-bit data words)
         reqLength(9 downto 2)                := axiReadMaster.arlen;
         reqLength(1 downto 0)                := "11";
         ------------------------------------------------------
         -- generated a TLP 3-DW data transfer without payload 
         --
         -- data(127:96) = Ignored  
         -- data(095:64) = H2  
         -- data(063:32) = H1
         -- data(031:00) = H0                 
         ------------------------------------------------------                                      
         -- Empty field
         v.dmaTxIbMaster.tData(127 downto 96) := (others => '0');
         --H2
         v.dmaTxIbMaster.tData(95 downto 66)  := axiReadMaster.araddr(31 downto 2);
         v.dmaTxIbMaster.tData(65 downto 64)  := "00";  --PCIe reserved
         --H1
         v.dmaTxIbMaster.tData(63 downto 48)  := dmaTxTranFromPci.locId;  -- Requester ID
         v.dmaTxIbMaster.tData(47 downto 40)  := dmaTxTranFromPci.tag;    -- Tag
         v.dmaTxIbMaster.tData(39 downto 36)  := "1111";   -- Last DW Byte Enable
         v.dmaTxIbMaster.tData(35 downto 32)  := "1111";   -- First DW Byte Enable
         --H0
         v.dmaTxIbMaster.tData(31)            := '0';   --PCIe reserved
         v.dmaTxIbMaster.tData(30 downto 29)  := "00";  -- FMT = Memory read, 3-DW header w/out payload
         v.dmaTxIbMaster.tData(28 downto 24)  := "00000";  -- Type = Memory read or write
         v.dmaTxIbMaster.tData(23)            := '0';   --PCIe reserved
         v.dmaTxIbMaster.tData(22 downto 20)  := "000";    -- TC = 0
         v.dmaTxIbMaster.tData(19 downto 16)  := "0000";   --PCIe reserved
         v.dmaTxIbMaster.tData(15)            := '0';   -- TD = 0
         v.dmaTxIbMaster.tData(14)            := '0';   -- EP = 0
         v.dmaTxIbMaster.tData(13 downto 12)  := "00";  -- Attr = 0
         v.dmaTxIbMaster.tData(11 downto 10)  := "00";  --PCIe reserved
         v.dmaTxIbMaster.tData(9 downto 0)    := reqLength+1;             -- Transaction length
         -- Write the header to FIFO
         v.dmaTxIbMaster.tValid               := '1';
         -- Set the EOF bit
         v.dmaTxIbMaster.tLast                := '1';
         -- Set AXIS tKeep
         v.dmaTxIbMaster.tKeep                := x"0FFF";
      end if;

      case r.state is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Check if ready to move data 
            if (rxMaster.tValid = '1') then
               -- Accept the data 
               v.rxSlave.tReady := '1';
               -- Check for TLP SOF
               if ssiGetUserSof(PCIE_AXIS_CONFIG_C, rxMaster) = '1' then
                  -- Check for request address
                  if rxMaster.tData(95 downto 66) = r.reqAddr then
                     -- Reset the flag
                     v.reqRdy := '0';
                  end if;
                  -- Track the unused data 
                  v.rdata := rxMaster.tData(127 downto 96);
                  -- Next state
                  v.state := MOVE_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when MOVE_S =>
            -- Check if ready to move data 
            if (v.axiReadSlave.rvalid = '0') and (rxMaster.tValid = '1') then
               -- Ready for data
               v.rxSlave.tReady                    := '1';
               v.axiReadSlave.rvalid               := '1';
               -- Set the data bus
               v.axiReadSlave.rdata(127 downto 32) := rxMaster.tData(95 downto 0);
               v.axiReadSlave.rdata(31 downto 0)   := r.rdata;
               -- Track the unused data 
               v.rdata                             := rxMaster.tData(127 downto 96);
               -- Check for tLast
               if rxMaster.tLast = '1' then
                  -- Set the flag
                  v.axiReadSlave.rlast := '1';
                  -- Next state
                  v.state              := IDLE_S;
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
      axiReadSlave  <= v.axiReadSlave;
      rxSlave       <= v.rxSlave;
      dmaTxIbMaster <= r.dmaTxIbMaster;
      
   end process comb;

   seq : process (pciClk) is
   begin
      if rising_edge(pciClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;
