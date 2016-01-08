-------------------------------------------------------------------------------
-- Title      : SSI PCIe Core
-------------------------------------------------------------------------------
-- File       : SsiPcieTxDmaFifoMux.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-04-22
-- Last update: 2015-04-22
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: SSI PCIe TX DMA Engine's data MUX
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
use work.AxiStreamPkg.all;
use work.SsiPkg.all;
use work.SsiPciePkg.all;

entity SsiPcieTxDmaFifoMux is
   generic (
      TPD_G : time := 1 ns);
   port (
      pciClk      : in  sl;
      pciRst      : in  sl;
      -- Slave Port
      sAxisMaster : in  AxiStreamMasterType;
      sAxisSlave  : out AxiStreamSlaveType;
      -- Master Port
      mAxisMaster : out AxiStreamMasterType;
      mAxisSlave  : in  AxiStreamSlaveType);        
end SsiPcieTxDmaFifoMux;

architecture rtl of SsiPcieTxDmaFifoMux is

   type StateType is (
      WORD0_S,
      WORD1_S,
      WORD2_S,
      WORD3_S);    

   type RegType is record
      rxSlave  : AxiStreamSlaveType;
      txMaster : AxiStreamMasterType;
      saved    : AxiStreamMasterType;
      state    : StateType;
   end record RegType;
   
   constant REG_INIT_C : RegType := (
      rxSlave  => AXI_STREAM_SLAVE_INIT_C,
      txMaster => AXI_STREAM_MASTER_INIT_C,
      saved    => AXI_STREAM_MASTER_INIT_C,
      state    => WORD0_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal txSlave : AxiStreamSlaveType;
   
   -- attribute dont_touch : string;
   -- attribute dont_touch of r : signal is "true";
   
begin

   comb : process (pciRst, r, sAxisMaster, txSlave) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Reset strobing signals
      v.rxSlave.tReady := '0';      
      
      -- Update tValid register
      if txSlave.tReady = '1' then
         v.txMaster.tValid := '0';
         v.txMaster.tLast  := '0';
         v.txMaster.tUser  := (others => '0');
      end if;

      -- Only 32-bit transfers
      v.txMaster.tKeep := x"000F";

      case r.state is
         ----------------------------------------------------------------------
         when WORD0_S =>
            -- Check if need to move data
            if (v.txMaster.tValid = '0') and (sAxisMaster.tValid = '1') then
               -- Ready for data
               v.rxSlave.tReady              := '1';
               -- Write to the FIFO
               v.txMaster.tValid             := '1';
               v.txMaster.tData(31 downto 0) := sAxisMaster.tData(31 downto 0);
               v.txMaster.tDest              := sAxisMaster.tDest;
               -- Check if we have more data to transfer
               if sAxisMaster.tKeep(7 downto 4) = x"F" then
                  -- Latch the values
                  v.saved := sAxisMaster;
                  -- Next state
                  v.state := WORD1_S;
               else
                  -- Pass SOF and EOF
                  v.txMaster.tLast              := sAxisMaster.tLast;
                  v.txMaster.tUser(31 downto 0) := sAxisMaster.tUser(31 downto 0);
               end if;
            end if;
         ----------------------------------------------------------------------
         when WORD1_S =>
            -- Check if need to move data
            if (v.txMaster.tValid = '0') then
               -- Write to the FIFO
               v.txMaster.tValid             := '1';
               v.txMaster.tData(31 downto 0) := r.saved.tData(63 downto 32);
               -- Check if we have more data to transfer
               if r.saved.tKeep(11 downto 8) = x"F" then
                  -- Next state
                  v.state := WORD2_S;
               else
                  -- Pass the EOF
                  v.txMaster.tLast := r.saved.tLast;
                  -- Next state
                  v.state          := WORD0_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when WORD2_S =>
            -- Check if need to move data
            if (v.txMaster.tValid = '0') then
               -- Write to the FIFO
               v.txMaster.tValid             := '1';
               v.txMaster.tData(31 downto 0) := r.saved.tData(95 downto 64);
               -- Check if we have more data to transfer
               if r.saved.tKeep(15 downto 12) = x"F" then
                  -- Next state
                  v.state := WORD3_S;
               else
                  -- Pass the EOF
                  v.txMaster.tLast := r.saved.tLast;
                  -- Next state
                  v.state          := WORD0_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when WORD3_S =>
            -- Check if need to move data
            if (v.txMaster.tValid = '0') then
               -- Write to the FIFO
               v.txMaster.tValid             := '1';
               v.txMaster.tData(31 downto 0) := r.saved.tData(127 downto 96);
               -- Pass the EOF
               v.txMaster.tLast              := r.saved.tLast;
               -- Next state
               v.state                       := WORD0_S;
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
      sAxisSlave <= v.rxSlave;
      
   end process comb;

   seq : process (pciClk) is
   begin
      if rising_edge(pciClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   FIFO_TX : entity work.AxiStreamFifo
      generic map (
         -- General Configurations
         TPD_G               => TPD_G,
         PIPE_STAGES_G       => 0,
         SLAVE_READY_EN_G    => true,
         VALID_THOLD_G       => 1,
         -- FIFO configurations
         BRAM_EN_G           => false,
         USE_BUILT_IN_G      => false,
         GEN_SYNC_FIFO_G     => true,
         CASCADE_SIZE_G      => 1,
         FIFO_ADDR_WIDTH_G   => 4,
         -- AXI Stream Port Configurations
         SLAVE_AXI_CONFIG_G  => ssiAxiStreamConfig(4),
         MASTER_AXI_CONFIG_G => PCIE_AXIS_CONFIG_C)            
      port map (
         -- Slave Port
         sAxisClk    => pciClk,
         sAxisRst    => pciRst,
         sAxisMaster => r.txMaster,
         sAxisSlave  => txSlave,
         -- Master Port
         mAxisClk    => pciClk,
         mAxisRst    => pciRst,
         mAxisMaster => mAxisMaster,
         mAxisSlave  => mAxisSlave);             

end rtl;
