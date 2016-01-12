-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : UdpEngineTx.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-08-20
-- Last update: 2016-01-12
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Ethernet Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'SLAC Ethernet Library', including this file, 
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
use work.IpV4EnginePkg.all;
use work.UdpEnginePkg.all;

entity UdpEngineTx is
   generic (
      -- Simulation Generics
      TPD_G              : time          := 1 ns;
      SIM_ERROR_HALT_G   : boolean       := false;
      -- UDP General Generic
      TX_MTU_G           : positive      := 1500;
      TX_FORWARD_EOFE_G  : boolean       := false;
      TX_CALC_CHECKSUM_G : boolean       := true;
      SIZE_G             : positive      := 1;
      PORT_G             : PositiveArray := (0 => 8192));
   port (
      -- Interface to IPV4 Engine  
      obUdpMaster : out AxiStreamMasterType;
      obUdpSlave  : in  AxiStreamSlaveType;
      -- Interface to User Application
      localIp     : in  slv(31 downto 0);
      remotePort  : in  Slv16Array(SIZE_G-1 downto 0);
      remoteIp    : in  Slv32Array(SIZE_G-1 downto 0);
      remoteMac   : in  Slv48Array(SIZE_G-1 downto 0);
      ibMasters   : in  AxiStreamMasterArray(SIZE_G-1 downto 0);
      ibSlaves    : out AxiStreamSlaveArray(SIZE_G-1 downto 0);
      -- Clock and Reset
      clk         : in  sl;
      rst         : in  sl);
end UdpEngineTx;

architecture rtl of UdpEngineTx is

   -- Add a padding of 128 bytes to prevent buffer back pressuring
   -- Divide by 16 because 16 bytes per 128-bit word
   constant MAX_DATAGRAM_SIZE_C : positive := TX_MTU_G-40;
   constant FIFO_ADDR_SIZE_C    : natural  := (MAX_DATAGRAM_SIZE_C+128)/16;
   constant FIFO_ADDR_WIDTH_C   : positive := bitSize(FIFO_ADDR_SIZE_C-1);

   type StateType is (
      IDLE_S,
      HDR0_S,
      HDR1_S,
      BUFFER_S,
      LAST_S,
      ADD_LEN_S,
      CHECKSUM_S,
      MOVE_S); 

   type RegType is record
      flushBuffer : sl;
      eofe        : sl;
      rxByteCnt   : natural range 0 to 2*MAX_DATAGRAM_SIZE_C;
      tKeep       : slv(15 downto 0);
      tData       : slv(127 downto 0);
      tLast       : sl;
      sum0        : Slv32Array(3 downto 0);
      sum1        : Slv32Array(1 downto 0);
      sum2        : slv(31 downto 0);
      accum       : slv(31 downto 0);
      sum4        : slv(31 downto 0);
      cnt         : natural range 0 to 7;
      chPntr      : natural range 0 to SIZE_G-1;
      index       : natural range 0 to SIZE_G-1;
      ibValid     : sl;
      ibChecksum  : slv(15 downto 0);
      checksum    : slv(15 downto 0);
      ibSlaves    : AxiStreamSlaveArray(SIZE_G-1 downto 0);
      txMaster    : AxiStreamMasterType;
      mSlave      : AxiStreamSlaveType;
      sMaster     : AxiStreamMasterType;
      state       : StateType;
   end record RegType;
   constant REG_INIT_C : RegType := (
      flushBuffer => '1',
      eofe        => '0',
      rxByteCnt   => 0,
      tKeep       => (others => '0'),
      tData       => (others => '0'),
      tLast       => '0',
      sum0        => (others => (others => '0')),
      sum1        => (others => (others => '0')),
      sum2        => (others => '0'),
      accum       => (others => '0'),
      sum4        => (others => '0'),
      cnt         => 0,
      chPntr      => 0,
      index       => 0,
      ibValid     => '0',
      ibChecksum  => (others => '0'),
      checksum    => (others => '0'),
      ibSlaves    => (others => AXI_STREAM_SLAVE_INIT_C),
      txMaster    => AXI_STREAM_MASTER_INIT_C,
      mSlave      => AXI_STREAM_SLAVE_INIT_C,
      sMaster     => AXI_STREAM_MASTER_INIT_C,
      state       => IDLE_S);      

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal sMaster  : AxiStreamMasterType;
   signal sSlave   : AxiStreamSlaveType;
   signal mMaster  : AxiStreamMasterType;
   signal mSlave   : AxiStreamSlaveType;
   signal txMaster : AxiStreamMasterType;
   signal txSlave  : AxiStreamSlaveType;

   -- attribute dont_touch             : string;
   -- attribute dont_touch of r        : signal is "TRUE";
   -- attribute dont_touch of sMaster  : signal is "TRUE";
   -- attribute dont_touch of sSlave   : signal is "TRUE";
   -- attribute dont_touch of mMaster  : signal is "TRUE";
   -- attribute dont_touch of mSlave   : signal is "TRUE";
   -- attribute dont_touch of txMaster : signal is "TRUE";
   -- attribute dont_touch of txSlave  : signal is "TRUE";
   
begin

   DATAGRAM_BUFFER : entity work.AxiStreamFifo
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
         FIFO_ADDR_WIDTH_G   => FIFO_ADDR_WIDTH_C,
         -- AXI Stream Port Configurations
         SLAVE_AXI_CONFIG_G  => IP_ENGINE_CONFIG_C,
         MASTER_AXI_CONFIG_G => IP_ENGINE_CONFIG_C)            
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

   comb : process (ibMasters, localIp, mMaster, r, remoteIp, remoteMac, remotePort, rst, sSlave,
                   txSlave) is
      variable v           : RegType;
      variable i           : natural;
      variable lPort       : slv(15 downto 0);
      variable localPort   : slv(15 downto 0);
      variable tKeepMask   : slv(15 downto 0);
      variable len         : slv(15 downto 0);
      variable udpLength   : slv(15 downto 0);
      variable udpChecksum : slv(15 downto 0);
   begin
      -- Latch the current value
      v := r;

      -- Reset the flags
      v.flushBuffer := '0';
      tKeepMask     := (others => '0');
      v.ibSlaves    := (others => AXI_STREAM_SLAVE_INIT_C);
      if txSlave.tReady = '1' then
         v.txMaster.tValid := '0';
         v.txMaster.tLast  := '0';
         v.txMaster.tUser  := (others => '0');
         v.txMaster.tKeep  := (others => '1');
      end if;
      v.mSlave := AXI_STREAM_SLAVE_INIT_C;
      if sSlave.tReady = '1' then
         v.sMaster.tValid := '0';
         v.sMaster.tLast  := '0';
         v.sMaster.tUser  := (others => '0');
         v.sMaster.tKeep  := (others => '1');
      end if;

      -- Convert into a big Endian SLVs
      lPort                    := toSlv(PORT_G(r.chPntr), 16);
      localPort(15 downto 8)   := lPort(7 downto 0);
      localPort(7 downto 0)    := lPort(15 downto 8);
      len                      := toSlv(r.rxByteCnt, 16);
      udpLength(15 downto 8)   := len(7 downto 0);
      udpLength(7 downto 0)    := len(15 downto 8);
      udpChecksum(15 downto 8) := r.checksum(7 downto 0);
      udpChecksum(7 downto 0)  := r.checksum(15 downto 8);

      -- State Machine
      case r.state is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Reset flags/accumulators
            v.flushBuffer := '1';
            v.eofe        := '0';
            v.sum0        := (others => (others => '0'));
            v.sum1        := (others => (others => '0'));
            v.sum2        := (others => '0');
            v.accum       := (others => '0');
            v.sum4        := (others => '0');
            -- Check for roll over
            if r.index = SIZE_G-1 then
               -- Reset the counter
               v.index := 0;
            else
               -- Increment the counter
               v.index := r.index + 1;
            end if;
            -- Check for data and remote MAC is non-zero
            if (ibMasters(r.index).tValid = '1') and (remoteMac(r.index) /= 0) and (r.flushBuffer = '1') then
               -- Check for SOF
               if (ssiGetUserSof(IP_ENGINE_CONFIG_C, ibMasters(r.index)) = '1') then
                  -- Latch the index
                  v.chPntr := r.index;
                  -- Next state
                  v.state  := HDR0_S;
               else
                  -- Blow off the data
                  v.ibSlaves(r.index).tReady := '1';
               end if;
            end if;
         ----------------------------------------------------------------------
         when HDR0_S =>
            -- Check if ready to move data
            if v.sMaster.tValid = '0' then
               -- Write the first header
               v.sMaster.tValid               := '1';
               v.sMaster.tData(47 downto 0)   := remoteMac(r.chPntr);   -- Destination MAC address
               v.sMaster.tData(63 downto 48)  := x"0000";  -- All 0s
               v.sMaster.tData(95 downto 64)  := localIp;  -- Source IP address
               v.sMaster.tData(127 downto 96) := remoteIp(r.chPntr);  -- Destination IP address               
               ssiSetUserSof(IP_ENGINE_CONFIG_C, v.sMaster, '1');
               -- Process checksum
               GetUdpChecksum (
                  -- Inbound tKeep and tData
                  x"FF00",
                  v.sMaster.tData,
                  -- Summation Signals
                  r.sum0, v.sum0,
                  r.sum1, v.sum1,
                  r.sum2, v.sum2,
                  r.accum, v.accum,
                  r.sum4, v.sum4,
                  -- Checksum generation and comparison
                  v.ibValid,
                  r.ibChecksum,
                  v.checksum);                 
               -- Next state
               v.state := HDR1_S;
            end if;
         ----------------------------------------------------------------------
         when HDR1_S =>
            -- Check if ready to move data
            if (ibMasters(r.chPntr).tValid = '1') and (v.sMaster.tValid = '0') then
               -- Accept the data
               v.ibSlaves(r.chPntr).tReady    := '1';
               -- Write the Second header
               v.sMaster.tValid               := '1';
               v.sMaster.tData(7 downto 0)    := x"00";    -- All 0s
               v.sMaster.tData(15 downto 8)   := UDP_C;    -- Protocol Type = UDP
               v.sMaster.tData(31 downto 16)  := x"0000";  -- IPv4 Pseudo header length = TBD
               v.sMaster.tData(47 downto 32)  := localPort;           -- Source port
               v.sMaster.tData(63 downto 48)  := remotePort(r.chPntr);  -- Destination port
               v.sMaster.tData(79 downto 64)  := x"0000";  -- UDP length = TBD
               v.sMaster.tData(95 downto 80)  := x"0000";  -- UDP checksum  = TBD              
               v.sMaster.tData(127 downto 96) := ibMasters(r.chPntr).tData(31 downto 0);  -- UDP Datagram     
               v.sMaster.tKeep(11 downto 0)   := x"FFF";
               v.sMaster.tKeep(15 downto 12)  := ibMasters(r.chPntr).tKeep(3 downto 0);  -- UDP Datagram  
               -- Track the number of bytes received
               tKeepMask                      := x"0" & v.sMaster.tKeep(15 downto 4);
               v.rxByteCnt                    := getTKeep(tKeepMask);
               -- Process checksum
               GetUdpChecksum (
                  -- Inbound tKeep and tData
                  v.sMaster.tKeep,
                  v.sMaster.tData,
                  -- Summation Signals
                  r.sum0, v.sum0,
                  r.sum1, v.sum1,
                  r.sum2, v.sum2,
                  r.accum, v.accum,
                  r.sum4, v.sum4,
                  -- Checksum generation and comparison
                  v.ibValid,
                  r.ibChecksum,
                  v.checksum);  
               -- Track the leftovers
               v.tData(95 downto 0)   := ibMasters(r.chPntr).tData(127 downto 32);
               v.tData(127 downto 96) := (others => '0');
               v.tKeep(11 downto 0)   := ibMasters(r.chPntr).tKeep(15 downto 4);
               v.tKeep(15 downto 12)  := (others => '0');
               v.tLast                := ibMasters(r.chPntr).tLast;
               v.eofe                 := ssiGetUserEofe(IP_ENGINE_CONFIG_C, ibMasters(r.chPntr));
               -- Check for tLast
               if (v.tLast = '1') then
                  -- Check the leftover tKeep is not empty
                  if v.tKeep /= 0 then
                     -- Next state
                     v.state := LAST_S;
                  else
                     v.sMaster.tLast := '1';
                     -- Next state
                     v.state         := ADD_LEN_S;
                  end if;
               else
                  -- Next state
                  v.state := BUFFER_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when BUFFER_S =>
            -- Check if ready to move data
            if (ibMasters(r.chPntr).tValid = '1') and (v.sMaster.tValid = '0') then
               -- Accept the data
               v.ibSlaves(r.chPntr).tReady    := '1';
               -- Write the Second header
               v.sMaster.tValid               := '1';
               -- Move the data
               v.sMaster.tData(95 downto 0)   := r.tData(95 downto 0);
               v.sMaster.tData(127 downto 96) := ibMasters(r.chPntr).tData(31 downto 0);
               v.sMaster.tKeep(11 downto 0)   := r.tKeep(11 downto 0);
               v.sMaster.tKeep(15 downto 12)  := ibMasters(r.chPntr).tKeep(3 downto 0);
               -- Track the leftovers                                 
               v.tData(95 downto 0)           := ibMasters(r.chPntr).tData(127 downto 32);
               v.tKeep(11 downto 0)           := ibMasters(r.chPntr).tKeep(15 downto 4);
               -- Track the number of bytes received
               v.rxByteCnt                    := r.rxByteCnt + getTKeep(v.sMaster.tKeep);
               -- Process checksum
               GetUdpChecksum (
                  -- Inbound tKeep and tData
                  v.sMaster.tKeep,
                  v.sMaster.tData,
                  -- Summation Signals
                  r.sum0, v.sum0,
                  r.sum1, v.sum1,
                  r.sum2, v.sum2,
                  r.accum, v.accum,
                  r.sum4, v.sum4,
                  -- Checksum generation and comparison
                  v.ibValid,
                  r.ibChecksum,
                  v.checksum);                 
               -- Check for tLast
               if (ibMasters(r.chPntr).tLast = '1') or (v.rxByteCnt > MAX_DATAGRAM_SIZE_C) then
                  -- Update the EOFE bit
                  v.eofe := ssiGetUserEofe(IP_ENGINE_CONFIG_C, ibMasters(r.chPntr));
                  -- Check for overflow
                  if (v.rxByteCnt > MAX_DATAGRAM_SIZE_C) then
                     v.eofe := '1';
                  end if;
                  -- Check the leftover tKeep is not empty
                  if v.tKeep /= 0 then
                     -- Next state
                     v.state := LAST_S;
                  else
                     v.sMaster.tLast := '1';
                     -- Next state
                     v.state         := ADD_LEN_S;
                  end if;
               end if;
            end if;
         ----------------------------------------------------------------------
         when LAST_S =>
            -- Check for data
            if (v.sMaster.tValid = '0') then
               -- Move the data
               v.sMaster.tValid := '1';
               v.sMaster.tData  := r.tData;
               v.sMaster.tKeep  := r.tKeep;
               v.sMaster.tLast  := '1';
               -- Track the number of bytes received
               v.rxByteCnt      := r.rxByteCnt + getTKeep(v.sMaster.tKeep);
               -- Process checksum
               GetUdpChecksum (
                  -- Inbound tKeep and tData
                  v.sMaster.tKeep,
                  v.sMaster.tData,
                  -- Summation Signals
                  r.sum0, v.sum0,
                  r.sum1, v.sum1,
                  r.sum2, v.sum2,
                  r.accum, v.accum,
                  r.sum4, v.sum4,
                  -- Checksum generation and comparison
                  v.ibValid,
                  r.ibChecksum,
                  v.checksum);   
               -- Check for overflow
               if (v.rxByteCnt > MAX_DATAGRAM_SIZE_C) then
                  v.eofe := '1';
               end if;
               -- Next state
               v.state := ADD_LEN_S;
            end if;
         ----------------------------------------------------------------------
         when ADD_LEN_S =>
            v.tData(15 downto 0)  := udpLength;            -- IPv4 Pseudo header length
            v.tData(31 downto 16) := udpLength;            -- UDP length
            v.tKeep(3 downto 0)   := (others => '1');
            v.tKeep(15 downto 4)  := (others => '0');
            -- Process checksum
            GetUdpChecksum (
               -- Inbound tKeep and tData
               v.tKeep,
               v.tData,
               -- Summation Signals
               r.sum0, v.sum0,
               r.sum1, v.sum1,
               r.sum2, v.sum2,
               r.accum, v.accum,
               r.sum4, v.sum4,
               -- Checksum generation and comparison
               v.ibValid,
               r.ibChecksum,
               v.checksum);     
            -- Check if we need to generate a check sum
            if (TX_CALC_CHECKSUM_G = true) then
               -- Next state
               v.state := CHECKSUM_S;
            else
               -- Send a zero checksum
               v.checksum := (others => '0');
               -- Check for errors
               if (r.eofe = '1') and (TX_FORWARD_EOFE_G = false) then
                  -- Next state
                  v.state := IDLE_S;
               else
                  -- Next state
                  v.state := MOVE_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when CHECKSUM_S =>
            -- Process checksum
            GetUdpChecksum (
               -- Inbound tKeep and tData
               (others => '0'),         -- tKeep
               (others => '0'),         -- tData
               -- Summation Signals
               r.sum0, v.sum0,
               r.sum1, v.sum1,
               r.sum2, v.sum2,
               r.accum, v.accum,
               r.sum4, v.sum4,
               -- Checksum generation and comparison
               v.ibValid,
               r.ibChecksum,
               v.checksum);       
            -- Check the counter
            if r.cnt = 7 then
               -- Reset the counter
               v.cnt := 0;
               -- Check for errors
               if (r.eofe = '1') and (TX_FORWARD_EOFE_G = false) then
                  -- Next state
                  v.state := IDLE_S;
               else
                  -- Next state
                  v.state := MOVE_S;
               end if;
            else
               -- Increment the counter
               v.cnt := r.cnt + 1;
            end if;
         ----------------------------------------------------------------------
         when MOVE_S =>
            -- Check for data
            if (mMaster.tValid = '1') and (v.txMaster.tValid = '0') then
               -- Accept the data
               v.mSlave.tReady := '1';
               -- Move data
               v.txMaster      := mMaster;
               -- Check the counter
               if r.cnt /= 5 then
                  -- Increment the counter
                  v.cnt := r.cnt + 1;
               end if;
               -- Check for first header
               if r.cnt = 0 then
                  ssiSetUserSof(IP_ENGINE_CONFIG_C, v.txMaster, '1');
               end if;
               -- Check for second header
               if r.cnt = 1 then
                  -- Overwrite the TBD header fields
                  v.txMaster.tData(31 downto 16) := udpLength;        -- IPv4 Pseudo header length
                  v.txMaster.tData(79 downto 64) := udpLength;        -- UDP length
                  v.txMaster.tData(95 downto 80) := udpChecksum;      -- UDP checksum
               end if;
               -- Check for EOF
               if mMaster.tLast = '1' then
                  -- Reset the counter
                  v.cnt := 0;
                  -- Set EOFE
                  if r.eofe = '1' then
                     ssiSetUserEofe(IP_ENGINE_CONFIG_C, v.txMaster, '1');
                  end if;
                  -- Next state
                  v.state := IDLE_S;
               end if;
            end if;
      ----------------------------------------------------------------------
      end case;

      -- Check the simulation error printing
      if SIM_ERROR_HALT_G and (r.eofe = '1') then
         report "UdpEngineTx: Error Detected" severity failure;
      end if;

      -- Reset
      if (rst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs        
      mSlave   <= v.mSlave;
      sMaster  <= r.sMaster;
      ibSlaves <= v.ibSlaves;
      txMaster <= r.txMaster;
      
   end process comb;

   seq : process (clk) is
   begin
      if rising_edge(clk) then
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
         SLAVE_AXI_CONFIG_G  => IP_ENGINE_CONFIG_C,
         MASTER_AXI_CONFIG_G => IP_ENGINE_CONFIG_C)            
      port map (
         -- Slave Port
         sAxisClk    => clk,
         sAxisRst    => rst,
         sAxisMaster => txMaster,
         sAxisSlave  => txSlave,
         -- Master Port
         mAxisClk    => clk,
         mAxisRst    => rst,
         mAxisMaster => obUdpMaster,
         mAxisSlave  => obUdpSlave);     

end rtl;
