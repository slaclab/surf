-------------------------------------------------------------------------------
-- Title      : SSI PCIe Core
-------------------------------------------------------------------------------
-- File       : SsiPcieDmaLoopBack.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-04-22
-- Last update: 2015-04-22
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: SSI PCIe Inbound TLP Packet Controller
-------------------------------------------------------------------------------
-- Copyright (c) 2015 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;

entity SsiPcieDmaLoopBack is
   generic (
      TPD_G         : time                   := 1 ns;
      LOOPBACK_EN_G : boolean                := true;  -- true = synthesis loopback capability
      DMA_SIZE_G    : positive range 1 to 16 := 1);
   port (
      dmaLoopback : in  sl;
      -- External DMA Interface
      dmaIbMaster : in  AxiStreamMasterType;
      dmaIbSlave  : out AxiStreamSlaveType;
      dmaObMaster : out AxiStreamMasterType;
      dmaObSlave  : in  AxiStreamSlaveType;
      -- Internal DMA Interface
      ibMaster    : out AxiStreamMasterType;
      ibSlave     : in  AxiStreamSlaveType;
      obMaster    : in  AxiStreamMasterType;
      obSlave     : out AxiStreamSlaveType;
      -- Clock and Resets
      pciClk      : in  sl;
      pciRst      : in  sl);       
end SsiPcieDmaLoopBack;

architecture rtl of SsiPcieDmaLoopBack is

   signal loopbackMaster : AxiStreamMasterType;
   signal loopbackSlave  : AxiStreamSlaveType;
   
begin

   GEN_LOOPBACK : if (LOOPBACK_EN_G = true) generate
      
      dmaObMaster.tValid <= obMaster.tValid and not(dmaLoopback);
      dmaObMaster.tData  <= obMaster.tData;
      dmaObMaster.tStrb  <= obMaster.tStrb;
      dmaObMaster.tKeep  <= obMaster.tKeep;
      dmaObMaster.tLast  <= obMaster.tLast;
      dmaObMaster.tDest  <= obMaster.tDest;
      dmaObMaster.tId    <= obMaster.tId;
      dmaObMaster.tUser  <= obMaster.tUser;

      loopbackMaster.tValid <= obMaster.tValid and (dmaLoopback);
      loopbackMaster.tData  <= obMaster.tData;
      loopbackMaster.tStrb  <= obMaster.tStrb;
      loopbackMaster.tKeep  <= obMaster.tKeep;
      loopbackMaster.tLast  <= obMaster.tLast;
      loopbackMaster.tDest  <= obMaster.tDest;
      loopbackMaster.tId    <= obMaster.tId;
      loopbackMaster.tUser  <= obMaster.tUser;

      obSlave <= dmaObSlave when(dmaLoopback = '0') else loopbackSlave;

      AxiStreamMux_Inst : entity work.AxiStreamMux
         generic map (
            TPD_G        => TPD_G,
            NUM_SLAVES_G => 2)
         port map (
            -- Clock and reset
            axisClk         => pciClk,
            axisRst         => pciRst,
            -- Slaves
            sAxisMasters(0) => dmaIbMaster,
            sAxisMasters(1) => loopbackMaster,
            sAxisSlaves(0)  => dmaIbSlave,
            sAxisSlaves(1)  => loopbackSlave,
            -- MUX Address
            sAxisAuto       => '0',
            sAxisAddr(0)    => dmaLoopback,
            -- Master
            mAxisMaster     => ibMaster,
            mAxisSlave      => ibSlave);   

   end generate;

   GEN_NO_LOOPBACK : if (LOOPBACK_EN_G = false) generate
      
      ibMaster    <= dmaIbMaster;
      dmaIbSlave  <= ibSlave;
      dmaObMaster <= obMaster;
      obSlave     <= dmaObSlave;
      
   end generate;

end rtl;
