-------------------------------------------------------------------------------
-- Title      : SSI PCIe Core
-------------------------------------------------------------------------------
-- File       : SsiPcieTlpInbound.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-04-22
-- Last update: 2015-06-10
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: SSI PCIe Inbound TLP Packet Controller
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
use work.SsiPciePkg.all;

entity SSiPcieTlpInbound is
   generic (
      TPD_G      : time                   := 1 ns;
      DMA_SIZE_G : positive range 1 to 16 := 1);
   port (
      -- Inbound DMA Interface
      regIbMaster    : in  AxiStreamMasterType;
      regIbSlave     : out AxiStreamSlaveType;
      dmaTxIbMasters : in  AxiStreamMasterArray(DMA_SIZE_G-1 downto 0);
      dmaTxIbSlaves  : out AxiStreamSlaveArray(DMA_SIZE_G-1 downto 0);
      dmaRxIbMasters : in  AxiStreamMasterArray(DMA_SIZE_G-1 downto 0);
      dmaRxIbSlaves  : out AxiStreamSlaveArray(DMA_SIZE_G-1 downto 0);
      -- PCIe Interface
      trnPending     : out sl;
      mAxisMaster    : out AxiStreamMasterType;
      mAxisSlave     : in  AxiStreamSlaveType;
      -- Clock and Resets
      pciClk         : in  sl;
      pciRst         : in  sl);       
end SsiPcieTlpInbound;

architecture rtl of SsiPcieTlpInbound is

   type StateType is (
      IDLE_S,
      DMA_RX_S);    

   type RegType is record
      trnPending    : sl;
      arbCnt        : natural range 0 to DMA_SIZE_G-1;
      chPntr        : natural range 0 to DMA_SIZE_G-1;
      regIbSlave    : AxiStreamSlaveType;
      dmaTxIbSlaves : AxiStreamSlaveArray(DMA_SIZE_G-1 downto 0);
      dmaRxIbSlaves : AxiStreamSlaveArray(DMA_SIZE_G-1 downto 0);
      txMaster      : AxiStreamMasterType;
      state         : StateType;
   end record RegType;
   
   constant REG_INIT_C : RegType := (
      trnPending    => '0',
      arbCnt        => 0,
      chPntr        => 0,
      regIbSlave    => AXI_STREAM_SLAVE_INIT_C,
      dmaTxIbSlaves => (others => AXI_STREAM_SLAVE_INIT_C),
      dmaRxIbSlaves => (others => AXI_STREAM_SLAVE_INIT_C),
      txMaster      => AXI_STREAM_MASTER_INIT_C,
      state         => IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   -- attribute dont_touch : string;
   -- attribute dont_touch of r : signal is "true";
   
begin

   comb : process (dmaRxIbMasters, dmaTxIbMasters, mAxisSlave, pciRst, r, regIbMaster) is
      variable v : RegType;
      variable i : natural;
   begin
      -- Latch the current value
      v := r;

      -- Reset strobing signals
      v.trnPending        := '0';
      v.regIbSlave.tReady := '0';
      for i in 0 to DMA_SIZE_G-1 loop
         v.dmaTxIbSlaves(i).tReady := '0';
         v.dmaRxIbSlaves(i).tReady := '0';
      end loop;

      -- Update tValid register
      if mAxisSlave.tReady = '1' then
         v.txMaster.tValid := '0';
      end if;

      -- Check if there is a pending transaction
      if regIbMaster.tValid = '1' then
         v.trnPending := '1';
      end if;
      for i in 0 to DMA_SIZE_G-1 loop
         if dmaTxIbMasters(i).tValid = '1' then
            v.trnPending := '1';
         end if;
         if dmaRxIbMasters(i).tValid = '1' then
            v.trnPending := '1';
         end if;
      end loop;

      case r.state is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Check if target is ready for data
            if v.txMaster.tValid = '0' then
               -- 1st priority: Register access (single 32-bit MEM IO access only)
               if regIbMaster.tValid = '1' then
                  -- Ready for data
                  v.regIbSlave.tReady := '1';
                  v.txMaster          := regIbMaster;
               -- 2nd priority: TX DMA's Memory Requesting
               elsif dmaTxIbMasters(r.arbCnt).tValid = '1' then
                  -- Ready for data
                  v.dmaTxIbSlaves(r.arbCnt).tReady := '1';
                  v.txMaster                       := dmaTxIbMasters(r.arbCnt);
               else
                  -- Check for RX DMA data
                  if dmaRxIbMasters(r.arbCnt).tValid = '1' then
                     -- Select the register path
                     v.chPntr                         := r.arbCnt;
                     -- Ready for data
                     v.dmaRxIbSlaves(r.arbCnt).tReady := '1';
                     v.txMaster                       := dmaRxIbMasters(r.arbCnt);
                     -- Check for not(tLast)
                     if dmaRxIbMasters(r.arbCnt).tLast = '0'then
                        -- Next state
                        v.state := DMA_RX_S;
                     end if;
                  end if;
                  -- Increment counters
                  if r.arbCnt = DMA_SIZE_G-1 then
                     v.arbCnt := 0;
                  else
                     v.arbCnt := r.arbCnt + 1;
                  end if;
               end if;
            end if;
         ----------------------------------------------------------------------
         when DMA_RX_S =>
            -- Check if target is ready for data
            if (v.txMaster.tValid = '0') and (dmaRxIbMasters(r.chPntr).tValid = '1') then
               -- Ready for data
               v.dmaRxIbSlaves(r.chPntr).tReady := '1';
               v.txMaster                       := dmaRxIbMasters(r.chPntr);
               -- Check for tLast
               if dmaRxIbMasters(r.chPntr).tLast = '1' then
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
      trnPending    <= r.trnPending;
      regIbSlave    <= v.regIbSlave;
      dmaTxIbSlaves <= v.dmaTxIbSlaves;
      dmaRxIbSlaves <= v.dmaRxIbSlaves;
      mAxisMaster   <= r.txMaster;

   end process comb;

   seq : process (pciClk) is
   begin
      if rising_edge(pciClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;
   
end rtl;
