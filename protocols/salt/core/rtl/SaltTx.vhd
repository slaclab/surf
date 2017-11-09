-------------------------------------------------------------------------------
-- File       : SaltTx.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-09-01
-- Last update: 2017-11-08
-------------------------------------------------------------------------------
-- Description: SALT TX Engine Module
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

entity SaltTx is
   generic (
      TPD_G              : time                := 1 ns;
      COMMON_TX_CLK_G    : boolean             := false;  -- Set to true if sAxisClk and clk are the same clock
      SLAVE_AXI_CONFIG_G : AxiStreamConfigType := ssiAxiStreamConfig(4));
   port (
      -- Slave Port
      sAxisClk    : in  sl;
      sAxisRst    : in  sl;
      sAxisMaster : in  AxiStreamMasterType;
      sAxisSlave  : out AxiStreamSlaveType;
      -- GMII Interface
      clk         : in  sl;
      rst         : in  sl;
      txPktSent   : out sl;
      txEn        : out sl;
      txData      : out slv(7 downto 0));
end SaltTx;

architecture rtl of SaltTx is

   type StateType is (
      IDLE_S,
      BUFFER_S,
      PREAMBLE_S,
      SFD_S,
      HEADER_S,
      LENGTH_S,
      MOVE_S,
      CHECKSUM_S,
      FOOTER_S);

   type RegType is record
      flushBuffer : sl;
      sof         : sl;
      eof         : sl;
      eofe        : sl;
      txPktSent   : sl;
      seqCnt      : slv(7 downto 0);
      tDest       : slv(7 downto 0);
      cnt         : slv(15 downto 0);
      length      : slv(15 downto 0);
      checksum    : slv(31 downto 0);
      txMaster    : AxiStreamMasterType;
      rxSlave     : AxiStreamSlaveType;
      sMaster     : AxiStreamMasterType;
      mSlave      : AxiStreamSlaveType;
      state       : StateType;
   end record RegType;
   constant REG_INIT_C : RegType := (
      flushBuffer => '1',
      sof         => '0',
      eof         => '0',
      eofe        => '0',
      txPktSent   => '0',
      seqCnt      => (others => '0'),
      tDest       => (others => '0'),
      cnt         => (others => '0'),
      length      => (others => '0'),
      checksum    => (others => '0'),
      txMaster    => AXI_STREAM_MASTER_INIT_C,
      rxSlave     => AXI_STREAM_SLAVE_INIT_C,
      sMaster     => AXI_STREAM_MASTER_INIT_C,
      mSlave      => AXI_STREAM_SLAVE_INIT_C,
      state       => IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal rxMaster : AxiStreamMasterType;
   signal rxSlave  : AxiStreamSlaveType;
   signal sMaster  : AxiStreamMasterType;
   signal sSlave   : AxiStreamSlaveType;
   signal mMaster  : AxiStreamMasterType;
   signal mSlave   : AxiStreamSlaveType;
   signal txMaster : AxiStreamMasterType;
   signal txSlave  : AxiStreamSlaveType;

begin

   FIFO_RX : entity work.AxiStreamFifoV2
      generic map (
         -- General Configurations
         TPD_G               => TPD_G,
         PIPE_STAGES_G       => 0,
         SLAVE_READY_EN_G    => true,
         VALID_THOLD_G       => 1,
         -- FIFO configurations
         BRAM_EN_G           => false,
         USE_BUILT_IN_G      => false,
         GEN_SYNC_FIFO_G     => COMMON_TX_CLK_G,
         CASCADE_SIZE_G      => 1,
         FIFO_ADDR_WIDTH_G   => 4,
         FIFO_PAUSE_THRESH_G => ((2**4)-2),
         -- AXI Stream Port Configurations
         SLAVE_AXI_CONFIG_G  => SLAVE_AXI_CONFIG_G,
         MASTER_AXI_CONFIG_G => SSI_SALT_CONFIG_C)
      port map (
         -- Slave Port
         sAxisClk    => sAxisClk,
         sAxisRst    => sAxisRst,
         sAxisMaster => sAxisMaster,
         sAxisSlave  => sAxisSlave,
         -- Master Port
         mAxisClk    => clk,
         mAxisRst    => rst,
         mAxisMaster => rxMaster,
         mAxisSlave  => rxSlave);

   DATAGRAM_BUFFER : entity work.AxiStreamFifoV2
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
         -- AXI Stream Port Configurations
         SLAVE_AXI_CONFIG_G  => SSI_SALT_CONFIG_C,
         MASTER_AXI_CONFIG_G => SSI_SALT_CONFIG_C)
      port map (
         -- Slave Port
         sAxisClk    => clk,
         sAxisRst    => r.flushBuffer,
         sAxisMaster => sMaster,
         sAxisSlave  => sSlave,
         -- Master Port
         mAxisClk    => clk,
         mAxisRst    => r.flushBuffer,
         mAxisMaster => mMaster,
         mAxisSlave  => mSlave);

   comb : process (mMaster, r, rst, rxMaster, sSlave, txSlave) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Reset the flags
      v.flushBuffer := '0';
      v.rxSlave     := AXI_STREAM_SLAVE_INIT_C;
      if txSlave.tReady = '1' then
         v.txMaster.tValid := '0';
         v.txMaster.tLast  := '0';
         v.txMaster.tUser  := (others => '0');
      end if;
      v.mSlave := AXI_STREAM_SLAVE_INIT_C;
      if sSlave.tReady = '1' then
         v.sMaster.tValid := '0';
         v.sMaster.tLast  := '0';
         v.sMaster.tUser  := (others => '0');
      end if;

      -- State Machine
      case r.state is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Reset flags/accumulators
            v.flushBuffer := '1';
            v.sof         := '0';
            v.eof         := '0';
            v.eofe        := '0';
            v.txPktSent   := '0';
            v.length      := (others => '0');
            v.checksum    := (others => '0');
            v.cnt         := (others => '0');
            -- Check for data
            if (rxMaster.tValid = '1') then
               -- Check for SOF
               if ssiGetUserSof(SSI_SALT_CONFIG_C, rxMaster) = '1' then
                  -- Set the flag
                  v.sof    := '1';
                  -- Reset the counter
                  v.seqCnt := x"00";
                  -- Latch the destination
                  v.tDest  := rxMaster.tDest;
               else
                  -- Increment the counter
                  v.seqCnt := r.seqCnt + 1;
               end if;
               -- Next state
               v.state := BUFFER_S;
            end if;
         ----------------------------------------------------------------------
         when BUFFER_S =>
            -- Check if ready to move data
            if (rxMaster.tValid = '1') and (v.sMaster.tValid = '0') then
               -- Accept the data
               v.rxSlave.tReady := '1';
               -- Move the data
               v.sMaster        := rxMaster;
               -- Mask off tLast for intergap monitoring
               v.sMaster.tLast  := '0';
               -- Increment the counter
               v.length         := r.length + 1;
               -- Check for EOF
               if rxMaster.tLast = '1' then
                  -- Set the flags
                  v.eof   := '1';
                  v.eofe  := ssiGetUserEofe(SSI_SALT_CONFIG_C, rxMaster);
                  -- Next state
                  v.state := PREAMBLE_S;
               elsif v.length = SALT_MAX_WORDS_C then
                  -- Next state
                  v.state := PREAMBLE_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when PREAMBLE_S =>
            -- Check if ready to move data
            if (v.txMaster.tValid = '0') then
               -- Write the preamble 
               v.txMaster.tValid             := '1';
               v.txMaster.tData(31 downto 0) := PREAMBLE_C;
               -- Next state
               v.state                       := SFD_S;
            end if;
         ----------------------------------------------------------------------
         when SFD_S =>
            -- Check if ready to move data
            if (v.txMaster.tValid = '0') then
               -- Write the preamble 
               v.txMaster.tValid             := '1';
               v.txMaster.tData(31 downto 0) := SFD_C;
               -- Next state
               v.state                       := HEADER_S;
            end if;
         ----------------------------------------------------------------------
         when HEADER_S =>
            -- Check if ready to move data
            if (v.txMaster.tValid = '0') then
               -- Write the header
               v.txMaster.tValid := '1';
               if r.sof = '1' then
                  v.txMaster.tData(31 downto 0) := SOF_C;
               else
                  v.txMaster.tData(31 downto 0) := SOC_C;
               end if;
               -- Next state
               v.state := LENGTH_S;
            end if;
         ----------------------------------------------------------------------
         when LENGTH_S =>
            -- Check if ready to move data
            if (v.txMaster.tValid = '0') then
               -- Move the data            
               v.txMaster.tValid              := '1';
               v.txMaster.tData(15 downto 0)  := r.length;
               v.txMaster.tData(23 downto 16) := r.tDest;
               v.txMaster.tData(31 downto 24) := r.seqCnt;
               -- Update checksum
               v.checksum                     := v.txMaster.tData(31 downto 0);
               -- Next state
               v.state                        := MOVE_S;
            end if;
         ----------------------------------------------------------------------
         when MOVE_S =>
            -- Check for valid data
            if (mMaster.tValid = '1') and (v.txMaster.tValid = '0') then
               -- Accept the data
               v.mSlave.tReady               := '1';
               -- Move the data
               v.txMaster.tValid             := '1';
               v.txMaster.tdata(31 downto 0) := mMaster.tdata(31 downto 0);
               -- Update checksum
               v.checksum                    := r.checksum + mMaster.tData(31 downto 0);
               -- Increment the counter
               v.cnt                         := r.cnt + 1;
               -- Check the length
               if v.cnt = r.length then
                  -- Flush the buffer
                  v.flushBuffer := '1';
                  -- Next state
                  v.state       := CHECKSUM_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when CHECKSUM_S =>
            -- Check if ready to move data
            if (v.txMaster.tValid = '0') then
               -- Move the data            
               v.txMaster.tValid             := '1';
               v.txMaster.tData(31 downto 0) := not(r.checksum);  -- one's complement                        
               -- Next state
               v.state                       := FOOTER_S;
            end if;
         ----------------------------------------------------------------------
         when FOOTER_S =>
            -- Check if ready to move data
            if (v.txMaster.tValid = '0') then
               -- Write the footer
               v.txMaster.tValid := '1';
               v.txMaster.tLast  := '1';
               v.txPktSent       := '1';
               -- Check for EOF
               if r.eof = '0' then
                  v.txMaster.tData(31 downto 0) := EOC_C;
               else
                  if r.eofe = '0' then
                     v.txMaster.tData(31 downto 0) := EOF_C;
                  else
                     v.txMaster.tData(31 downto 0) := EOFE_C;
                  end if;
               end if;
               -- Next state
               v.state := IDLE_S;
            end if;
      ----------------------------------------------------------------------
      end case;

      -- Reset
      if (rst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs        
      mSlave    <= v.mSlave;
      sMaster   <= r.sMaster;
      rxSlave   <= v.rxSlave;
      txMaster  <= r.txMaster;
      txPktSent <= r.txPktSent;

   end process comb;

   seq : process (clk) is
   begin
      if rising_edge(clk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   U_TxResize : entity work.SaltTxResize
      generic map (
         TPD_G => TPD_G)
      port map (
         -- Clock and Reset
         clk      => clk,
         rst      => rst,
         -- AXI Stream Interface
         rxMaster => txMaster,
         rxSlave  => txSlave,
         -- GMII Interface
         txEn     => txEn,
         txData   => txData);

end rtl;
