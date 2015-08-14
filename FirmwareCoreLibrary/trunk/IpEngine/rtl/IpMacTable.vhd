-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : IpMacTable.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-08-11
-- Last update: 2015-08-13
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2014 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;
use work.IpEngineDefPkg.all;

entity IpMacTable is
   generic (
      TPD_G         : time                    := 1 ns;
      ARP_TIMEOUT_G : slv(31 downto 0)        := x"09502F90";  -- In units of clock cycles (Default: 156.25 MHz clock = 1 seconds)
      MAC_TIMEOUT_G : slv(31 downto 0)        := x"FFFFFFFF";  -- In units of clock cycles (Default: 156.25 MHz clock = 27 seconds)
      APP_SIZE_G    : positive range 1 to 32  := 1;
      DEST_SIZE_G   : positive range 1 to 256 := 16);
   port (
      -- Interface to ARP Engine
      ibArpMacMaster   : out AxiStreamMasterType;              -- Request via IP only
      ibArpMacSlave    : in  AxiStreamSlaveType;
      obArpMacMaster   : in  AxiStreamMasterType;              -- Respond with IP + MAC
      obArpMacSlave    : out AxiStreamSlaveType;
      -- Interface to IPV4 Engine
      obIpV4DestMaster : in  AxiStreamMasterType;              -- Request via IP + MAC
      obIpV4DestSlave  : out AxiStreamSlaveType;
      ibIpV4DestMaster : out AxiStreamMasterType;              -- Respond with DEST
      ibIpV4DestSlave  : in  AxiStreamSlaveType;
      obIpV4MacMaster  : in  AxiStreamMasterType;              -- Request via DEST
      obIpV4MacSlave   : out AxiStreamSlaveType;
      ibIpV4MacMaster  : out AxiStreamMasterType;              -- Respond with IP + MAC
      ibIpV4MacSlave   : in  AxiStreamSlaveType;
      -- Interface to Protocol's Client Engine 
      obAppDestMasters : in  AxiStreamMasterArray(APP_SIZE_G-1 downto 0);  -- Request via IP only
      obAppDestSlaves  : out AxiStreamSlaveArray(APP_SIZE_G-1 downto 0);
      ibAppDestMasters : out AxiStreamMasterArray(APP_SIZE_G-1 downto 0);  -- Respond with DEST
      ibAppDestSlaves  : in  AxiStreamSlaveArray(APP_SIZE_G-1 downto 0);
      -- Clock and Reset
      clk              : in  sl;
      rst              : in  sl);
end IpMacTable;

architecture rtl of IpMacTable is

   constant ADDR_WIDTH_C : positive := bitSize(DEST_SIZE_G-1);
   constant DATA_WIDTH_C : positive := 80;  -- 48-bit MAC + 32-bit IP

   type AddrArray is array (2 downto 0) of slv(ADDR_WIDTH_C-1 downto 0);
   type DataArray is array (2 downto 0) of slv(DATA_WIDTH_C-1 downto 0);

   type WriteStateType is (
      ARP_IDLE_S,
      IPV4_IDLE_S,
      ARP_FILL_SCAN_S,
      IPV4_FILL_SCAN_S,
      ARP_EMPTY_SCAN_S,
      IPV4_EMPTY_SCAN_S); 

   type ReadStateType is (
      IDLE_S,
      FILL_SCAN_S);       

   type RegType is record
      cnt              : natural range 0 to APP_SIZE_G-1;
      cntDly           : natural range 0 to APP_SIZE_G-1;
      wEn              : sl;
      wAddr            : slv(ADDR_WIDTH_C-1 downto 0);
      wData            : slv(DATA_WIDTH_C-1 downto 0);
      rAddr            : AddrArray;
      ibArpMacMasters  : AxiStreamMasterArray(APP_SIZE_G-1 downto 0);
      obArpMacSlave    : AxiStreamSlaveType;
      obIpV4DestSlave  : AxiStreamSlaveType;
      ibIpV4DestMaster : AxiStreamMasterType;
      obIpV4MacSlave   : AxiStreamSlaveType;
      ibIpV4MacMaster  : AxiStreamMasterType;
      obAppDestSlaves  : AxiStreamSlaveArray(APP_SIZE_G-1 downto 0);
      ibAppDestMasters : AxiStreamMasterArray(APP_SIZE_G-1 downto 0);
      macTimers        : Slv32Array(DEST_SIZE_G-1 downto 0);
      arpTimers        : Slv32Array(APP_SIZE_G-1 downto 0);
      wState           : WriteStateType;
      rState           : ReadStateType;
   end record RegType;
   constant REG_INIT_C : RegType := (
      cnt              => 0,
      cntDly           => 0,
      wEn              => '0',
      wAddr            => (others => '0'),
      wData            => (others => '0'),
      rAddr            => (others => (others => '0')),
      ibArpMacMasters  => (others => IP_MAC_MASTER_INIT_C),
      obArpMacSlave    => AXI_STREAM_SLAVE_INIT_C,
      obIpV4DestSlave  => AXI_STREAM_SLAVE_INIT_C,
      ibIpV4DestMaster => IP_MAC_MASTER_INIT_C,
      obIpV4MacSlave   => AXI_STREAM_SLAVE_INIT_C,
      ibIpV4MacMaster  => IP_MAC_MASTER_INIT_C,
      obAppDestSlaves  => (others => AXI_STREAM_SLAVE_INIT_C),
      ibAppDestMasters => (others => IP_MAC_MASTER_INIT_C),
      macTimers        => (others => (others => '0')),
      arpTimers        => (others => (others => '0')),
      wState           => ARP_IDLE_S,
      rState           => IDLE_S);      

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal ibArpMacSlaves : AxiStreamSlaveArray(APP_SIZE_G-1 downto 0);
   signal rAddr          : AddrArray;
   signal rData          : DataArray;
   
begin

   comb : process (ibAppDestSlaves, ibArpMacSlaves, ibIpV4DestSlave, ibIpV4MacSlave,
                   obAppDestMasters, obArpMacMaster, obIpV4DestMaster, obIpV4MacMaster, r, rData,
                   rst) is
      variable v     : RegType;
      variable i     : natural;
      variable valid : slv(DEST_SIZE_G-1 downto 0);
   begin
      -- Latch the current value
      v := r;

      -- Reset the flags
      v.wEn           := '0';
      v.obArpMacSlave := AXI_STREAM_SLAVE_INIT_C;
      for i in APP_SIZE_G-1 downto 0 loop
         if ibArpMacSlaves(i).tReady = '1' then
            v.ibArpMacMasters(i) := IP_MAC_MASTER_INIT_C;
         end if;
      end loop;
      v.obIpV4DestSlave := AXI_STREAM_SLAVE_INIT_C;
      if ibIpV4DestSlave.tReady = '1' then
         v.ibIpV4DestMaster := IP_MAC_MASTER_INIT_C;
      end if;
      v.obIpV4MacSlave := AXI_STREAM_SLAVE_INIT_C;
      if ibIpV4MacSlave.tReady = '1' then
         v.ibIpV4MacMaster := IP_MAC_MASTER_INIT_C;
      end if;
      for i in APP_SIZE_G-1 downto 0 loop
         v.obAppDestSlaves(i) := AXI_STREAM_SLAVE_INIT_C;
         if ibAppDestSlaves(i).tReady = '1' then
            v.ibAppDestMasters(i) := IP_MAC_MASTER_INIT_C;
         end if;
      end loop;

      -- Update the timers and valid flags
      for i in DEST_SIZE_G-1 downto 0 loop
         if r.macTimers(i) /= 0 then
            -- Decrement the timers
            v.macTimers(i) := r.macTimers(i) - 1;
            -- Set the flag
            valid(i)       := '1';
         else
            -- Reset the flag
            valid(i) := '0';
         end if;
      end loop;
      for i in APP_SIZE_G-1 downto 0 loop
         if r.arpTimers(i) /= 0 then
            -- Decrement the timers
            v.arpTimers(i) := r.arpTimers(i) - 1;
         end if;
      end loop;

      -- State Machine
      case r.wState is
         ----------------------------------------------------------------------
         when ARP_IDLE_S =>
            -- Reset the address
            v.wAddr    := (others => '0');
            -- Preset the address
            v.rAddr(0) := (others => '1');
            -- Check for write request
            if (obArpMacMaster.tValid = '1') then
               -- Next state
               v.wState := ARP_FILL_SCAN_S;
            else
               -- Next state
               v.wState := IPV4_IDLE_S;
            end if;
         ----------------------------------------------------------------------
         when IPV4_IDLE_S =>
            -- Reset the address
            v.wAddr    := (others => '0');
            -- Preset the address
            v.rAddr(0) := (others => '1');
            -- Check for write request
            if (obIpV4DestMaster.tValid = '1') then
               -- Next state
               v.wState := IPV4_FILL_SCAN_S;
            else
               -- Next state
               v.wState := ARP_IDLE_S;
            end if;
         ----------------------------------------------------------------------
         when ARP_FILL_SCAN_S =>
            -- Increment the address
            v.rAddr(0) := r.rAddr(0) + 1;
            -- Compare the new ARP IP/MAC with table index
            if rData(0) = obArpMacMaster.tData(DATA_WIDTH_C-1 downto 0) then
               -- Accept the data
               v.obArpMacSlave.tReady                := '1';
               -- Preset the timer
               v.macTimers(conv_integer(v.rAddr(0))) := MAC_TIMEOUT_G;
               -- Next state
               v.wState                              := IPV4_IDLE_S;
            elsif v.rAddr(0) = DEST_SIZE_G-1 then
               -- Next state
               v.wState := ARP_EMPTY_SCAN_S;
            end if;
         ----------------------------------------------------------------------
         when IPV4_FILL_SCAN_S =>
            if v.ibIpV4DestMaster.tValid = '0' then
               -- Increment the address
               v.rAddr(0) := r.rAddr(0) + 1;
               -- Compare the new ARP IP/MAC with table index
               if rData(0) = obIpV4DestMaster.tData(DATA_WIDTH_C-1 downto 0) then
                  -- Accept the data
                  v.obIpV4DestSlave.tReady                          := '1';
                  -- Respond with DEST
                  v.ibIpV4DestMaster.tValid                         := '1';
                  v.ibIpV4DestMaster.tDest(ADDR_WIDTH_C-1 downto 0) := v.rAddr(0);
                  -- Preset the timer
                  v.macTimers(conv_integer(v.rAddr(0)))             := MAC_TIMEOUT_G;
                  -- Next state
                  v.wState                                          := ARP_IDLE_S;
               elsif v.rAddr(0) = DEST_SIZE_G-1 then
                  -- Next state
                  v.wState := IPV4_EMPTY_SCAN_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when ARP_EMPTY_SCAN_S =>
            -- Check if empty
            if valid(conv_integer(r.wAddr)) = '0' then
               -- Accept the data
               v.obArpMacSlave.tReady             := '1';
               -- Write the data to the RAM
               v.wEn                              := '1';
               v.wData                            := obArpMacMaster.tData(DATA_WIDTH_C-1 downto 0);
               -- Preset the timer
               v.macTimers(conv_integer(r.wAddr)) := MAC_TIMEOUT_G;
               -- Next state
               v.wState                           := IPV4_IDLE_S;
            elsif r.wAddr = DEST_SIZE_G-1 then
               -- Dump the data
               v.obArpMacSlave.tReady := '1';
               -- Next state
               v.wState               := IPV4_IDLE_S;
            else
               -- Increment the address
               v.wAddr := r.wAddr + 1;
            end if;
         ----------------------------------------------------------------------
         when IPV4_EMPTY_SCAN_S =>
            if v.ibIpV4DestMaster.tValid = '0' then
               -- Check if empty
               if valid(conv_integer(r.wAddr)) = '0' then
                  -- Accept the data
                  v.obIpV4DestSlave.tReady                          := '1';
                  -- Write the data to the RAM
                  v.wEn                                             := '1';
                  v.wData                                           := obIpV4DestMaster.tData(DATA_WIDTH_C-1 downto 0);
                  -- Respond with DEST
                  v.ibIpV4DestMaster.tValid                         := '1';
                  v.ibIpV4DestMaster.tDest(ADDR_WIDTH_C-1 downto 0) := r.wAddr;
                  -- Preset the timer
                  v.macTimers(conv_integer(r.wAddr))                := MAC_TIMEOUT_G;
                  -- Next state
                  v.wState                                          := ARP_IDLE_S;
               elsif r.wAddr = DEST_SIZE_G-1 then
                  -- Dump the data
                  v.obIpV4DestSlave.tReady  := '1';
                  -- Respond with ERROR!!!!
                  v.ibIpV4DestMaster.tValid := '1';
                  ssiSetUserEofe(IP_ENGINE_CONFIG_C, v.ibIpV4DestMaster, '1');
                  -- Next state
                  v.wState                  := ARP_IDLE_S;
               else
                  -- Increment the address
                  v.wAddr := r.wAddr + 1;
               end if;
            end if;
      ----------------------------------------------------------------------
      end case;

      -- State Machine
      case r.rState is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Increment the counter
            v.cnt := r.cnt + 1;
            if r.cnt = APP_SIZE_G-1 then
               v.cnt := 0;
            end if;
            -- Keep a delayed copy for next state
            v.cntDly := r.cnt;
            -- Check for a request
            if (obAppDestMasters(r.cnt).tValid = '1') and (v.ibAppDestMasters(r.cnt).tValid = '0') then
               -- Preset the address
               v.rAddr(1) := (others => '1');
               -- Next state
               v.rState   := FILL_SCAN_S;
            end if;
         ----------------------------------------------------------------------
         when FILL_SCAN_S =>
            -- Increment the counter
            v.rAddr(1) := r.rAddr(1) + 1;
            -- Check if the IP address matches and valid table index
            if (obAppDestMasters(r.cntDly).tData(79 downto 48) = rData(1)(79 downto 48)) and (valid(conv_integer(v.rAddr(1))) = '1') then
               -- Accept the data
               v.obAppDestSlaves(r.cntDly).tReady                          := '1';
               -- Respond with DEST
               v.ibAppDestMasters(r.cntDly).tValid                         := '1';
               v.ibAppDestMasters(r.cntDly).tDest(ADDR_WIDTH_C-1 downto 0) := v.rAddr(1);
               -- Reset the timer
               v.arpTimers(r.cntDly)                                       := (others => '0');
               -- Next state
               v.rState                                                    := IDLE_S;
            elsif v.rAddr(1) = APP_SIZE_G-1 then
               -- Check the timer and ready to push data
               if (r.arpTimers(r.cntDly) = 0) and (v.ibArpMacMasters(r.cntDly).tValid = '0') then
                  -- Preset the timer
                  v.arpTimers(r.cntDly)       := ARP_TIMEOUT_G;
                  -- Forward the request to the ARP module
                  v.ibArpMacMasters(r.cntDly) := obAppDestMasters(r.cntDly);
               end if;
               -- Next state
               v.rState := IDLE_S;
            end if;
      ----------------------------------------------------------------------
      end case;

      -- Update the "Request via DEST" read address
      v.rAddr(2) := obIpV4MacMaster.tDest(ADDR_WIDTH_C-1 downto 0);

      -- Check for a request
      if (obIpV4MacMaster.tValid = '1') and (v.ibIpV4MacMaster.tValid = '0') then
         -- Accept the data
         v.obIpV4MacSlave.tReady  := '1';
         -- Respond to the request
         v.ibIpV4MacMaster.tValid := '1';
         -- Check for valid table index
         if valid(conv_integer(v.rAddr(2))) = '1' then
            -- Respond with IP + MAC
            v.ibIpV4MacMaster.tData(DATA_WIDTH_C-1 downto 0) := rData(2);
         else
            -- Respond with ERROR!!!!
            ssiSetUserEofe(IP_ENGINE_CONFIG_C, v.ibIpV4MacMaster, '1');
         end if;
      end if;

      -- Reset
      if (rst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs 
      obArpMacSlave    <= v.obArpMacSlave;
      obIpV4DestSlave  <= v.obIpV4DestSlave;
      ibIpV4DestMaster <= r.ibIpV4DestMaster;
      obIpV4MacSlave   <= v.obIpV4MacSlave;
      ibIpV4MacMaster  <= r.ibIpV4MacMaster;
      obAppDestSlaves  <= v.obAppDestSlaves;
      ibAppDestMasters <= r.ibAppDestMasters;
      rAddr            <= v.rAddr;
      
   end process comb;

   seq : process (clk) is
   begin
      if rising_edge(clk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   U_QuadPortRam : entity work.QuadPortRam
      generic map (
         TPD_G        => TPD_G,
         REG_EN_G     => false,
         DATA_WIDTH_G => DATA_WIDTH_C,
         ADDR_WIDTH_G => ADDR_WIDTH_C)
      port map (
         -- Port A (Read/Write)
         clka  => clk,
         wea   => r.wEn,
         addra => r.wAddr,
         dina  => r.wData,
         -- Port B (Read Only)
         addrb => rAddr(0),
         doutb => rData(0),
         -- Port C (Read Only)
         addrc => rAddr(1),
         doutc => rData(1),
         -- Port D (Read Only)
         addrd => rAddr(2),
         doutd => rData(2));   

   U_AxiStreamMux : entity work.AxiStreamMux
      generic map (
         TPD_G         => TPD_G,
         NUM_SLAVES_G  => APP_SIZE_G,
         PIPE_STAGES_G => 1)
      port map (
         -- Clock and reset
         axisClk      => clk,
         axisRst      => rst,
         -- Slaves
         sAxisMasters => r.ibArpMacMasters,
         sAxisSlaves  => ibArpMacSlaves,
         -- Master
         mAxisMaster  => ibArpMacMaster,
         mAxisSlave   => ibArpMacSlave);

end rtl;
