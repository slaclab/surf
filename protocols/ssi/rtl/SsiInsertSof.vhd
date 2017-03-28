-------------------------------------------------------------------------------
-- File       : SsiInsertSof.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-08-18
-- Last update: 2015-10-23
-------------------------------------------------------------------------------
-- Description: Inserts the SOF for converting a generic AXIS into a SSI bus
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Firmware Standard Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'SLAC Firmware Standard Library', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;

entity SsiInsertSof is
   generic (
      TPD_G               : time                := 1 ns;
      TUSER_MASK_G        : slv(127 downto 0)   := (others => '1');  -- '1' = masked off bit
      COMMON_CLK_G        : boolean             := false;  -- True if sAxisClk and mAxisClk are the same clock
      INSERT_USER_HDR_G   : boolean             := false;  -- If True the module adds one user header word (mUserHdr = user header data)
      SLAVE_FIFO_G        : boolean             := true;
      MASTER_FIFO_G       : boolean             := true;
      SLAVE_AXI_CONFIG_G  : AxiStreamConfigType := AXI_STREAM_CONFIG_INIT_C;
      MASTER_AXI_CONFIG_G : AxiStreamConfigType := AXI_STREAM_CONFIG_INIT_C);       
   port (
      -- Slave Port
      sAxisClk    : in  sl;
      sAxisRst    : in  sl;
      sAxisMaster : in  AxiStreamMasterType;
      sAxisSlave  : out AxiStreamSlaveType;
      -- Master Port
      mAxisClk    : in  sl;
      mAxisRst    : in  sl;
      mUserHdr    : in  slv(127 downto 0) := (others => '0');
      mAxisMaster : out AxiStreamMasterType;
      mAxisSlave  : in  AxiStreamSlaveType);      
end SsiInsertSof;

architecture rtl of SsiInsertSof is

   type StateType is (
      IDLE_S,
      MOVE_S); 

   type RegType is record
      rxSlave  : AxiStreamSlaveType;
      txMaster : AxiStreamMasterType;
      state    : StateType;
   end record RegType;
   constant REG_INIT_C : RegType := (
      rxSlave  => AXI_STREAM_SLAVE_INIT_C,
      txMaster => AXI_STREAM_MASTER_INIT_C,
      state    => IDLE_S);      

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal rxMaster : AxiStreamMasterType;
   signal rxSlave  : AxiStreamSlaveType;
   signal txMaster : AxiStreamMasterType;
   signal txSlave  : AxiStreamSlaveType;

begin

   BYPASS_FIFO_RX : if ( (SLAVE_FIFO_G = false) and (COMMON_CLK_G = true) and (SLAVE_AXI_CONFIG_G = MASTER_AXI_CONFIG_G) ) generate
      rxMaster   <= sAxisMaster;
      sAxisSlave <= rxSlave;
   end generate;

   GEN_FIFO_RX : if ( (SLAVE_FIFO_G = true) or (COMMON_CLK_G = false) or (SLAVE_AXI_CONFIG_G /= MASTER_AXI_CONFIG_G) ) generate
      FIFO_RX : entity work.AxiStreamFifo
         generic map (
            -- General Configurations
            TPD_G               => TPD_G,
            PIPE_STAGES_G       => 0,
            SLAVE_READY_EN_G    => true,
            VALID_THOLD_G       => 1,
            -- FIFO configurations
            BRAM_EN_G           => false,
            USE_BUILT_IN_G      => false,
            GEN_SYNC_FIFO_G     => COMMON_CLK_G,
            CASCADE_SIZE_G      => 1,
            FIFO_ADDR_WIDTH_G   => 4,
            -- AXI Stream Port Configurations
            SLAVE_AXI_CONFIG_G  => SLAVE_AXI_CONFIG_G,
            MASTER_AXI_CONFIG_G => MASTER_AXI_CONFIG_G)            
         port map (
            -- Slave Port
            sAxisClk    => sAxisClk,
            sAxisRst    => sAxisRst,
            sAxisMaster => sAxisMaster,
            sAxisSlave  => sAxisSlave,
            -- Master Port
            mAxisClk    => mAxisClk,
            mAxisRst    => mAxisRst,
            mAxisMaster => rxMaster,
            mAxisSlave  => rxSlave);   
   end generate;


   comb : process (mAxisRst, mUserHdr, r, rxMaster, txSlave) is
      variable v : RegType;
      variable i : natural;
   begin
      -- Latch the current value
      v := r;

      -- Reset the flags
      v.rxSlave := AXI_STREAM_SLAVE_INIT_C;
      if txSlave.tReady = '1' then
         v.txMaster.tValid := '0';
      end if;

      -- State Machine
      case r.state is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Check if ready to move data
            if (v.txMaster.tValid = '0') and (rxMaster.tValid = '1') then
               if INSERT_USER_HDR_G = false then
                  -- Accept the data
                  v.rxSlave.tReady := '1';
                  -- Move the data
                  v.txMaster       := rxMaster;
                  -- Mask off the TUSER bits
                  for i in 127 downto 0 loop
                     if TUSER_MASK_G(i) = '1' then
                        v.txMaster.tUser(i) := '0';
                     end if;
                  end loop;
                  -- Insert the SOF bit
                  ssiSetUserSof(MASTER_AXI_CONFIG_G, v.txMaster, '1');
                  -- Check for no EOF
                  if (rxMaster.tLast = '0') then
                     -- Next state
                     v.state := MOVE_S;
                  end if;
               else
                  -- Insert User Header
                  v.txMaster        := AXI_STREAM_MASTER_INIT_C;
                  v.txMaster.tValid := '1';
                  v.txMaster.tData  := mUserHdr;
                  v.txMaster.tDest  := rxMaster.tDest;
                  -- Insert the SOF bit
                  ssiSetUserSof(MASTER_AXI_CONFIG_G, v.txMaster, '1');
                  -- Next state
                  v.state           := MOVE_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when MOVE_S =>
            -- Check if ready to move data
            if (v.txMaster.tValid = '0') and (rxMaster.tValid = '1') then
               -- Accept the data
               v.rxSlave.tReady := '1';
               -- Move the data
               v.txMaster       := rxMaster;
               -- Mask off the TUSER bits
               for i in 127 downto 0 loop
                  if TUSER_MASK_G(i) = '1' then
                     v.txMaster.tUser(i) := '0';
                  end if;
               end loop;
               -- Mask off the SOF bits
               ssiSetUserSof(MASTER_AXI_CONFIG_G, v.txMaster, '0');
               -- Check for EOF
               if (rxMaster.tLast = '1') then
                  -- Next state
                  v.state := IDLE_S;
               end if;
            end if;
      ----------------------------------------------------------------------
      end case;

      -- Reset
      if (mAxisRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs              
      rxSlave  <= v.rxSlave;
      txMaster <= r.txMaster;

   end process comb;

   seq : process (mAxisClk) is
   begin
      if rising_edge(mAxisClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   BYPASS_FIFO_TX : if (MASTER_FIFO_G = false) generate
      mAxisMaster <= txMaster;
      txSlave     <= mAxisSlave;
   end generate;

   GEN_FIFO_TX : if (MASTER_FIFO_G = true) generate
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
            SLAVE_AXI_CONFIG_G  => MASTER_AXI_CONFIG_G,
            MASTER_AXI_CONFIG_G => MASTER_AXI_CONFIG_G)            
         port map (
            -- Slave Port
            sAxisClk    => mAxisClk,
            sAxisRst    => mAxisRst,
            sAxisMaster => txMaster,
            sAxisSlave  => txSlave,
            -- Master Port
            mAxisClk    => mAxisClk,
            mAxisRst    => mAxisRst,
            mAxisMaster => mAxisMaster,
            mAxisSlave  => mAxisSlave);   
   end generate;
   
end rtl;
