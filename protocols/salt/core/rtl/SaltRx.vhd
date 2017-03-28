-------------------------------------------------------------------------------
-- File       : SaltRx.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-09-01
-- Last update: 2015-09-04
-------------------------------------------------------------------------------
-- Description: SALT RX Engine Module
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
use work.SaltPkg.all;

entity SaltRx is
   generic (
      TPD_G               : time                := 1 ns;
      COMMON_RX_CLK_G     : boolean             := false;  -- Set to true if mAxisClk and clk are the same clock
      MASTER_AXI_CONFIG_G : AxiStreamConfigType := ssiAxiStreamConfig(4));
   port (
      -- Master Port
      mAxisClk    : in  sl;
      mAxisRst    : in  sl;
      mAxisMaster : out AxiStreamMasterType;
      mAxisSlave  : in  AxiStreamSlaveType;
      -- GMII Interface
      rxEn        : in  sl;
      rxErr       : in  sl;
      rxData      : in  slv(7 downto 0);
      clk         : in  sl;
      rst         : in  sl);       
end SaltRx;

architecture rtl of SaltRx is

   type StateType is (
      IDLE_S,
      LENGTH_S,
      MOVE_S,
      CHECKSUM_S,
      DONE_S); 

   type RegType is record
      sof      : sl;
      eofe     : sl;
      align    : sl;
      seqCnt   : slv(7 downto 0);
      tDest    : slv(7 downto 0);
      length   : slv(15 downto 0);
      cnt      : slv(15 downto 0);
      checksum : slv(31 downto 0);
      alignCnt : natural range 0 to 3;
      dly      : AxiStreamMasterArray(1 downto 0);
      rxMaster : AxiStreamMasterType;
      txMaster : AxiStreamMasterType;
      state    : StateType;
   end record RegType;
   constant REG_INIT_C : RegType := (
      sof      => '1',
      eofe     => '0',
      align    => '0',
      seqCnt   => (others => '0'),
      tDest    => (others => '0'),
      length   => (others => '0'),
      cnt      => (others => '0'),
      checksum => (others => '0'),
      alignCnt => 0,
      dly      => (others => AXI_STREAM_MASTER_INIT_C),
      txMaster => AXI_STREAM_MASTER_INIT_C,
      rxMaster => AXI_STREAM_MASTER_INIT_C,
      state    => IDLE_S);      

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal txMaster : AxiStreamMasterType;
   signal txSlave  : AxiStreamSlaveType;

begin

   comb : process (r, rst, rxData, rxEn, rxErr, txSlave) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Reset the flags
      v.rxMaster.tValid := '0';
      if txSlave.tReady = '1' then
         v.txMaster.tValid := '0';
         v.txMaster.tLast  := '0';
         v.txMaster.tUser  := (others => '0');
      end if;

      -- Set the error flag
      v.rxMaster.tUser(SSI_EOFE_C) := rxErr;

      -- Check for valid inbound
      if rxEn = '1' then
         -- Shift the data
         v.rxMaster.tData(31 downto 24) := rxData;
         v.rxMaster.tData(23 downto 0)  := r.rxMaster.tData(31 downto 8);
         -- Check if we are phase aligning
         if (r.align = '1') then
            -- Check for preamble and SFD
            if v.rxMaster.tData(31 downto 0) = SFD_C then
               -- Reset the flag
               v.align    := '0';
               -- Reset the counter
               v.alignCnt := 0;
            end if;
         else
            -- Check the counter
            if r.alignCnt = 3 then
               -- Reset the counter
               v.alignCnt        := 0;
               -- Forward the word
               v.rxMaster.tValid := '1';
            else
               -- Increment the counter
               v.alignCnt := r.alignCnt + 1;
            end if;
         end if;
      else
         -- Need to re-align
         v.align          := '1';
         v.rxMaster.tData := (others => '0');
      end if;

      -- State Machine
      case r.state is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Check for valid data
            if r.rxMaster.tValid = '1' then
               -- Reset the flags
               v.dly(0).tValid := '0';
               v.dly(1).tValid := '0';
               -- Check for SOF header
               if r.rxMaster.tData(31 downto 0) = SOF_C then
                  -- Set the flag
                  v.sof    := '1';
                  v.eofe   := '0';
                  -- Reset the counter
                  v.seqCnt := x"00";
                  -- Next state
                  v.state  := LENGTH_S;
               elsif (r.rxMaster.tData(31 downto 0) = SOC_C) and (r.eofe = '0') then
                  -- Increment the counter
                  v.seqCnt := r.seqCnt + 1;
                  -- Next state
                  v.state  := LENGTH_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when LENGTH_S =>
            -- Check for valid data
            if r.rxMaster.tValid = '1' then
               -- Latch the length and tDest
               v.length   := r.rxMaster.tData(15 downto 0);
               v.tDest    := r.rxMaster.tData(23 downto 16);
               -- Update checksum
               v.checksum := r.rxMaster.tData(31 downto 0);
               -- Check for invalid lengths or invalid sequence counter
               if (v.length = 0) or (v.length > SALT_MAX_WORDS_C) or (r.rxMaster.tData(31 downto 24) /= r.seqCnt) then
                  -- Set the error flag
                  v.eofe  := '1';
                  -- Next state
                  v.state := IDLE_S;
               else
                  -- Next state
                  v.state := MOVE_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when MOVE_S =>
            -- Check for valid data
            if (r.rxMaster.tValid = '1') and (v.txMaster.tValid = '0') then
               -- Move the delay data
               v.txMaster.tValid           := r.dly(1).tValid;
               v.txMaster.tData            := r.dly(1).tData;
               v.dly(1).tValid             := r.dly(0).tValid;
               v.dly(1).tData              := r.dly(0).tData;
               -- Create the delayed data
               v.dly(0).tValid             := '1';
               v.dly(0).tData(31 downto 0) := r.rxMaster.tData(31 downto 0);
               -- Check for SOF bit
               if r.sof = '1' then
                  -- Reset the flag
                  v.sof := '0';
                  -- Set the SOF bit
                  ssiSetUserSof(SSI_SALT_CONFIG_C, v.txMaster, '1');
               end if;
               -- Check the length
               if r.cnt = r.length then
                  -- Reset the counter
                  v.cnt   := (others => '0');
                  -- Next state
                  v.state := CHECKSUM_S;
               else
                  -- Increment the counter
                  v.cnt      := r.cnt + 1;
                  -- Update checksum
                  v.checksum := r.checksum + r.rxMaster.tData(31 downto 0);
               end if;
            end if;
         ----------------------------------------------------------------------
         when CHECKSUM_S =>
            -- Check for valid checksum
            if r.dly(0).tData(31 downto 0) = not(r.checksum) then
               -- Next state
               v.state := DONE_S;
            else
               -- Set the error flag
               v.eofe  := '1';
               -- Next state
               v.state := IDLE_S;
            end if;
         ----------------------------------------------------------------------
         when DONE_S =>
            -- Check for valid data
            if (r.rxMaster.tValid = '1') and (v.txMaster.tValid = '0') then
               -- Move the delay data
               v.txMaster.tValid := r.dly(1).tValid;
               v.txMaster.tData  := r.dly(1).tData;
               -- Check for EOC footer
               if r.rxMaster.tData(31 downto 0) = EOC_C then
                  -- No operation
                  null;
               elsif r.rxMaster.tData(31 downto 0) = EOF_C then
                  -- Set EOF flag
                  v.txMaster.tLast := '1';
                  -- Set EOFE
                  ssiSetUserEofe(SSI_SALT_CONFIG_C, v.txMaster, r.eofe);
               elsif r.rxMaster.tData(31 downto 0) = EOFE_C then
                  -- Set EOF flag
                  v.txMaster.tLast := '1';
                  -- Set EOFE
                  ssiSetUserEofe(SSI_SALT_CONFIG_C, v.txMaster, '1');
               else
                  -- Set the error flag
                  v.eofe := '1';
               end if;
               -- Next state
               v.state := IDLE_S;
            end if;
      ----------------------------------------------------------------------
      end case;

      -- Check for GMII frame error
      if (r.rxMaster.tValid = '1') and (r.rxMaster.tUser(SSI_EOFE_C) = '1') then
         -- Set the error flag
         v.eofe := '1';
      end if;

      -- Overwrite the destination field
      v.txMaster.tDest := r.tDest;

      -- Reset
      if (rst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs        
      txMaster <= r.txMaster;

   end process comb;

   seq : process (clk) is
   begin
      if rising_edge(clk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   FIFO_TX : entity work.SsiFifo
      generic map (
         -- General Configurations
         TPD_G               => TPD_G,
         PIPE_STAGES_G       => 0,
         VALID_THOLD_G       => 1,
         EN_FRAME_FILTER_G   => true,
         -- FIFO configurations
         BRAM_EN_G           => true,
         USE_BUILT_IN_G      => false,
         GEN_SYNC_FIFO_G     => COMMON_RX_CLK_G,
         CASCADE_SIZE_G      => 1,
         FIFO_ADDR_WIDTH_G   => 9,
         -- AXI Stream Port Configurations
         SLAVE_AXI_CONFIG_G  => SSI_SALT_CONFIG_C,
         MASTER_AXI_CONFIG_G => MASTER_AXI_CONFIG_G)            
      port map (
         -- Slave Port
         sAxisClk    => clk,
         sAxisRst    => rst,
         sAxisMaster => txMaster,
         sAxisSlave  => txSlave,
         -- Master Port
         mAxisClk    => mAxisClk,
         mAxisRst    => mAxisRst,
         mAxisMaster => mAxisMaster,
         mAxisSlave  => mAxisSlave);   

end rtl;
