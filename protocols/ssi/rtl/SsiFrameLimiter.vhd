-------------------------------------------------------------------------------
-- File       : SsiFrameLimiter.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-05-20
-- Last update: 2016-09-20
-------------------------------------------------------------------------------
-- Description: Limits the amount of data being sent across a SSI AXIS bus 
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

entity SsiFrameLimiter is
   generic (
      TPD_G               : time                := 1 ns;
      EN_TIMEOUT_G        : boolean             := true;
      MAXIS_CLK_FREQ_G    : real                := 156.25E+06;  -- In units of Hz
      TIMEOUT_G           : real                := 1.0E-3;      -- In units of seconds
      FRAME_LIMIT_G       : positive            := 1024;  -- In units of MASTER_AXI_CONFIG_G.TDATA_BYTES_C
      COMMON_CLK_G        : boolean             := false;  -- True if sAxisClk and mAxisClk are the same clock
      SLAVE_FIFO_G        : boolean             := false;
      MASTER_FIFO_G       : boolean             := false;
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
      mAxisMaster : out AxiStreamMasterType;
      mAxisSlave  : in  AxiStreamSlaveType);      
end SsiFrameLimiter;

architecture rtl of SsiFrameLimiter is

   constant TIMEOUT_C : natural := getTimeRatio(MAXIS_CLK_FREQ_G * TIMEOUT_G, 1.0);

   type StateType is (
      IDLE_S,
      MOVE_S); 

   type RegType is record
      cnt      : natural range 0 to FRAME_LIMIT_G-1;
      timer    : natural range 0 to TIMEOUT_C-1;
      rxSlave  : AxiStreamSlaveType;
      txMaster : AxiStreamMasterType;
      state    : StateType;
   end record RegType;
   constant REG_INIT_C : RegType := (
      cnt      => 0,
      timer    => 0,
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

   BYPASS_FIFO_RX : if ((SLAVE_FIFO_G = false) and (COMMON_CLK_G = true) and (SLAVE_AXI_CONFIG_G = MASTER_AXI_CONFIG_G)) generate
      rxMaster   <= sAxisMaster;
      sAxisSlave <= rxSlave;
   end generate;

   GEN_FIFO_RX : if ((SLAVE_FIFO_G = true) or (COMMON_CLK_G = false) or (SLAVE_AXI_CONFIG_G /= MASTER_AXI_CONFIG_G)) generate
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

   comb : process (mAxisRst, r, rxMaster, txSlave) is
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
            -- Reset the counter
            v.cnt := 0;
            -- Check if ready to move data
            if (v.txMaster.tValid = '0') and (rxMaster.tValid = '1') then
               -- Check for SOF
               if ssiGetUserSof(MASTER_AXI_CONFIG_G, rxMaster) = '1' then
                  -- Next state
                  v.state := MOVE_S;
               else
                  -- Blowoff the data
                  v.rxSlave.tReady := '1';
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
               -- Check for EOF
               if rxMaster.tLast = '1' then
                  -- Next state
                  v.state := IDLE_S;
               -- Check if reach limiter value
               elsif r.cnt = (FRAME_LIMIT_G-1) then
                  -- Set EOF and EOFE
                  v.txMaster.tLast := '1';
                  ssiSetUserEofe(MASTER_AXI_CONFIG_G, v.txMaster, '1');
                  -- Next state
                  v.state          := IDLE_S;
               else
                  -- Increment the counter
                  v.cnt := r.cnt + 1;
               end if;
            end if;
      ----------------------------------------------------------------------
      end case;

      -- Check if timeout is enabled
      if EN_TIMEOUT_G then
         -- Check if in (or going into) IDLE state
         if (r.state = IDLE_S) or (v.state = IDLE_S) then
            -- Reset the timer
            v.timer := 0;
         else
            -- Check the timer
            if (r.timer /= (TIMEOUT_C-1)) then
               -- Increment the timer
               v.timer := r.timer + 1;
            else
               -- Check ready to move data 
               if (v.txMaster.tValid = '0') then
                  -- Set EOF and EOFE
                  v.txMaster.tValid := '1';
                  v.txMaster.tLast  := '1';
                  ssiSetUserEofe(MASTER_AXI_CONFIG_G, v.txMaster, '1');
                  -- Next state
                  v.state           := IDLE_S;
               end if;
            end if;
         end if;
      end if;

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
