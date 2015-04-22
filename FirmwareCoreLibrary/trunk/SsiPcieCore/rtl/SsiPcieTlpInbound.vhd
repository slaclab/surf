-------------------------------------------------------------------------------
-- Title      : SSI PCIe Core
-------------------------------------------------------------------------------
-- File       : SsiPcieTlpInbound.vhd
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
use work.SsiPciePkg.all;

entity SSiPcieTlpInbound is
   generic (
      TPD_G      : time                   := 1 ns;
      DMA_SIZE_G : positive range 1 to 16 := 1);
   port (
      -- Inbound DMA Interface
      regIbMaster   : in  AxiStreamMasterType;
      regIbSlave    : out AxiStreamSlaveType;
      dmaTxIbMaster : in  AxiStreamMasterArray(DMA_SIZE_G-1 downto 0);
      dmaTxIbSlave  : out AxiStreamSlaveArray(DMA_SIZE_G-1 downto 0);
      dmaRxIbMaster : in  AxiStreamMasterArray(DMA_SIZE_G-1 downto 0);
      dmaRxIbSlave  : out AxiStreamSlaveArray(DMA_SIZE_G-1 downto 0);
      -- PCIe Interface
      trnPending    : out sl;
      mAxisMaster   : out AxiStreamMasterType;
      mAxisSlave    : in  AxiStreamSlaveType;
      -- Clock and Resets
      pciClk        : in  sl;
      pciRst        : in  sl);       
end SsiPcieTlpInbound;

architecture rtl of SsiPcieTlpInbound is

   type StateType is (
      IDLE_S,
      DMA_S);    

   type RegType is record
      trnPending : sl;
      arbCnt     : natural range 0 to DMA_SIZE_G-1;
      chPntr     : natural range 0 to DMA_SIZE_G-1;
      regIbSlave : AxiStreamSlaveType;
      dmaIbSlave : AxiStreamSlaveArray(DMA_SIZE_G-1 downto 0);
      txMaster   : AxiStreamMasterType;
      state      : StateType;
   end record RegType;
   
   constant REG_INIT_C : RegType := (
      trnPending => '0',
      arbCnt     => 0,
      chPntr     => 0,
      regIbSlave => AXI_STREAM_SLAVE_INIT_C,
      dmaIbSlave => (others => AXI_STREAM_SLAVE_INIT_C),
      txMaster   => AXI_STREAM_MASTER_INIT_C,
      state      => IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal dmaIbMaster : AxiStreamMasterArray(DMA_SIZE_G-1 downto 0);
   signal dmaIbSlave  : AxiStreamSlaveArray(DMA_SIZE_G-1 downto 0);
   
begin

   GEN_MUX :
   for i in 0 to DMA_SIZE_G-1 generate
      AxiStreamMux_Inst : entity work.AxiStreamMux
         generic map (
            TPD_G        => TPD_G,
            NUM_SLAVES_G => 2)
         port map (
            -- Clock and reset
            axisClk         => pciClk,
            axisRst         => pciRst,
            -- Slaves
            sAxisMasters(0) => dmaTxIbMaster(i),
            sAxisMasters(1) => dmaRxIbMaster(i),
            sAxisSlaves(0)  => dmaTxIbSlave(i),
            sAxisSlaves(1)  => dmaRxIbSlave(i),
            -- Master
            mAxisMaster     => dmaIbMaster(i),
            mAxisSlave      => dmaIbSlave(i));
   end generate GEN_MUX;

   comb : process (dmaIbMaster, mAxisSlave, pciRst, r, regIbMaster) is
      variable v : RegType;
      variable i : natural;
   begin
      -- Latch the current value
      v := r;

      -- Reset strobing signals
      v.trnPending        := '0';
      v.regIbSlave.tReady := '0';
      for i in 0 to DMA_SIZE_G-1 loop
         v.dmaIbSlave(i).tReady := '0';
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
         if dmaIbMaster(i).tValid = '1' then
            v.trnPending := '1';
         end if;
      end loop;

      case r.state is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Check if target is ready for data
            if v.txMaster.tValid = '0' then
               -- Highest priority: Register access
               if regIbMaster.tValid = '1' then
                  -- Ready for data
                  v.regIbSlave.tReady := '1';
                  v.txMaster          := regIbMaster;
               else
                  -- Check for DMA data
                  if dmaIbMaster(r.arbCnt).tValid = '1' then
                     -- Select the register path
                     v.chPntr                      := r.arbCnt;
                     -- Ready for data
                     v.dmaIbSlave(r.arbCnt).tReady := '1';
                     v.txMaster                    := dmaIbMaster(r.arbCnt);
                     -- Check for not(tLast)
                     if dmaIbMaster(r.arbCnt).tLast = '0'then
                        -- Next state
                        v.state := DMA_S;
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
         when DMA_S =>
            -- Check if target is ready for data
            if (v.txMaster.tValid = '0') and (dmaIbMaster(r.chPntr).tValid = '1') then
               -- Ready for data
               v.dmaIbSlave(r.chPntr).tReady := '1';
               v.txMaster                    := dmaIbMaster(r.chPntr);
               -- Check for tLast
               if dmaIbMaster(r.chPntr).tLast = '1' then
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
      trnPending  <= r.trnPending;
      regIbSlave  <= v.regIbSlave;
      dmaIbSlave  <= v.dmaIbSlave;
      mAxisMaster <= r.txMaster;

   end process comb;

   seq : process (pciClk) is
   begin
      if rising_edge(pciClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;
   
end rtl;
