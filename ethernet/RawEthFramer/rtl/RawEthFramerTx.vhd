-------------------------------------------------------------------------------
-- File       : RawEthFramerTx.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-05-23
-- Last update: 2016-05-26
-------------------------------------------------------------------------------
-- Description: Raw L2 Ethernet Framer's TX Engine
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
use work.RawEthFramerPkg.all;

entity RawEthFramerTx is
   generic (
      TPD_G      : time             := 1 ns;
      ETH_TYPE_G : slv(15 downto 0) := x"0010");  --  0x1000 (big-Endian configuration)
   port (
      -- Local Configurations
      localMac    : in  slv(47 downto 0);         --  big-Endian configuration
      remoteMac   : in  slv(47 downto 0);         --  big-Endian configuration
      tDest       : out slv(7 downto 0);
      req         : out sl;
      ack         : in  sl;
      -- Interface to Ethernet Media Access Controller (MAC)
      ibMacMaster : out AxiStreamMasterType;
      ibMacSlave  : in  AxiStreamSlaveType;
      -- Interface to Application engine(s)
      obAppMaster : in  AxiStreamMasterType;
      obAppSlave  : out AxiStreamSlaveType;
      -- Clock and Reset
      clk         : in  sl;
      rst         : in  sl);
end RawEthFramerTx;

architecture rtl of RawEthFramerTx is

   type StateType is (
      IDLE_S,
      TDEST_S,
      CACHE_S,
      MOVE_S); 

   type RegType is record
      bcf         : sl;
      req         : sl;
      tDest       : slv(7 downto 0);
      wen         : sl;
      wrAddr      : slv(2 downto 0);
      wrData      : slv(63 downto 0);
      rdAddr      : slv(15 downto 0);
      minByteCnt  : natural range 0 to 64;
      eof         : sl;
      eofe        : sl;
      obAppSlave  : AxiStreamSlaveType;
      ibMacMaster : AxiStreamMasterType;
      state       : StateType;
   end record RegType;
   constant REG_INIT_C : RegType := (
      bcf         => '0',
      req         => '0',
      tDest       => (others => '0'),
      wen         => '0',
      wrAddr      => (others => '0'),
      wrData      => (others => '0'),
      rdAddr      => (others => '0'),
      minByteCnt  => 0,
      eof         => '0',
      eofe        => '0',
      obAppSlave  => AXI_STREAM_SLAVE_INIT_C,
      ibMacMaster => AXI_STREAM_MASTER_INIT_C,
      state       => IDLE_S);     

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal rdData : slv(63 downto 0);

   -- attribute dont_touch           : string;
   -- attribute dont_touch of r      : signal is "TRUE";
   -- attribute dont_touch of rdData : signal is "TRUE";
   
begin

   U_MinEthCache : entity work.QuadPortRam
      generic map (
         TPD_G        => TPD_G,
         REG_EN_G     => false,         -- 1 cycle read
         DATA_WIDTH_G => 64,
         ADDR_WIDTH_G => 3)
      port map (
         -- Port A (Read/Write)
         clka  => clk,
         wea   => r.wen,
         addra => r.wrAddr,
         dina  => r.wrData,
         -- Port B (Read Only)
         clkb  => clk,
         addrb => r.rdAddr(2 downto 0),
         doutb => rdData);

   comb : process (ack, ibMacSlave, localMac, obAppMaster, r, rdData, remoteMac, rst) is
      variable v     : RegType;
      variable i     : natural;
      variable tKeep : slv(15 downto 0);
   begin
      -- Latch the current value
      v := r;

      -- Reset the flags
      v.wen        := '0';
      v.obAppSlave := AXI_STREAM_SLAVE_INIT_C;
      if ibMacSlave.tReady = '1' then
         v.ibMacMaster.tValid := '0';
         v.ibMacMaster.tLast  := '0';
         v.ibMacMaster.tUser  := (others => '0');
         v.ibMacMaster.tKeep  := x"00FF";
      end if;

      -- Update variables
      tKeep := x"00" & obAppMaster.tKeep(7 downto 0);

      -- State Machine
      case r.state is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Check if ready to move data
            if (obAppMaster.tValid = '1') and (v.ibMacMaster.tValid = '0') then
               -- Check for SOF
               if (ssiGetUserSof(RAW_ETH_CONFIG_INIT_C, obAppMaster) = '1') then
                  -- Latch the routing information
                  v.bcf   := ssiGetUserBcf(RAW_ETH_CONFIG_INIT_C, obAppMaster);
                  v.tDest := obAppMaster.tDest;
                  -- Set the flag
                  v.req   := not(v.bcf);
                  -- Next state
                  v.state := TDEST_S;
               else
                  -- Accept the data
                  v.obAppSlave.tReady := '1';
               end if;
            end if;
         ----------------------------------------------------------------------
         when TDEST_S =>
            if (ack = '1') or (r.bcf = '1') then
               -- Accept the data
               v.obAppSlave.tReady := '1';
               -- Reset the flag
               v.req               := '0';
               -- Check for valid DST MAC or broadcast 
               if (remoteMac /= 0) or (r.bcf = '1') then
                  -- Write to cache
                  v.wen    := '1';
                  v.wrAddr := toSlv(2, 3);
                  for i in 7 downto 0 loop
                     if tKeep(i) = '1' then
                        v.wrData(7+(8*i) downto (8*i)) := obAppMaster.tData(7+(8*i) downto (8*i));
                     else
                        v.wrData(7+(8*i) downto (8*i)) := x"00";  -- zero padding                    
                     end if;
                  end loop;
                  -- Update the min. ETH Byte counter
                  v.minByteCnt := 16 + getTKeep(tKeep);           -- include header offset
                  -- Check for tLast
                  if obAppMaster.tLast = '1' then
                     -- Set EOF
                     v.eof   := '1';
                     -- Get EOFE
                     v.eofe  := ssiGetUserEofe(RAW_ETH_CONFIG_INIT_C, obAppMaster);
                     -- Next state
                     v.state := MOVE_S;
                  else
                     -- Next state
                     v.state := CACHE_S;
                  end if;
                  ------------------
                  -- Write HDR[0] --
                  ------------------
                  -- Set the SOF
                  ssiSetUserSof(RAW_ETH_CONFIG_INIT_C, v.ibMacMaster, '1');
                  -- Move the data
                  v.ibMacMaster.tValid := '1';
                  -- Check for broadcast message
                  if (r.bcf = '1') then
                     v.ibMacMaster.tData(47 downto 0) := (others => '1');
                  else
                     v.ibMacMaster.tData(47 downto 0) := remoteMac;
                  end if;
                  v.ibMacMaster.tData(63 downto 48) := localMac(15 downto 0);
                  -- Preset the address
                  v.rdAddr                          := toSlv(1, 16);
               else
                  -- Next state
                  v.state := IDLE_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when CACHE_S =>
            -- Check if ready to move data
            if (obAppMaster.tValid = '1') and (v.ibMacMaster.tValid = '0') then
               -- Accept the data
               v.obAppSlave.tReady := '1';
               -- Write to cache
               v.wen               := '1';
               v.wrAddr            := r.wrAddr + 1;
               for i in 7 downto 0 loop
                  if tKeep(i) = '1' then
                     v.wrData(7+(8*i) downto (8*i)) := obAppMaster.tData(7+(8*i) downto (8*i));
                  else
                     v.wrData(7+(8*i) downto (8*i)) := x"00";     -- zero padding           
                  end if;
               end loop;
               -- Update the min. ETH Byte counter
               v.minByteCnt := r.minByteCnt + getTKeep(tKeep);
               -- Check for tLast
               if obAppMaster.tLast = '1' then
                  -- Set EOF
                  v.eof   := '1';
                  -- Get EOFE
                  v.eofe  := ssiGetUserEofe(RAW_ETH_CONFIG_INIT_C, obAppMaster);
                  -- Next state
                  v.state := MOVE_S;
               elsif r.wrAddr = 6 then
                  -- Reset EOF
                  v.eof   := '0';
                  -- Next state
                  v.state := MOVE_S;
               end if;
               -- Check if next state is MOVE_S
               if v.state = MOVE_S then
                  ------------------
                  -- Write HDR[1] --
                  ------------------               
                  -- Move the data
                  v.ibMacMaster.tValid              := '1';
                  v.ibMacMaster.tData(31 downto 0)  := localMac(47 downto 16);
                  v.ibMacMaster.tData(47 downto 32) := ETH_TYPE_G;
                  -- Check for eof during caching
                  if v.eof = '0' then
                     v.ibMacMaster.tData(54 downto 48) := (others => '0');
                  else
                     v.ibMacMaster.tData(54 downto 48) := toSlv(v.minByteCnt, 7);
                  end if;
                  -- Check for broadcast message
                  if (r.bcf = '1') then
                     v.ibMacMaster.tData(63 downto 55) := (others => '1');
                  else
                     v.ibMacMaster.tData(63 downto 55) := r.tDest & '0';
                  end if;
                  -- Preset the address
                  v.rdAddr := toSlv(2, 16);
               end if;
            end if;
         ----------------------------------------------------------------------
         when MOVE_S =>
            -- Check if ready to move data
            if (v.ibMacMaster.tValid = '0') then
               -- Increment the counter
               v.rdAddr := r.rdAddr + 1;
               -- Check for HDR[1]
               if r.rdAddr = 1 then
                  -- Move the data
                  v.ibMacMaster.tValid              := '1';
                  v.ibMacMaster.tData(31 downto 0)  := localMac(47 downto 16);
                  v.ibMacMaster.tData(47 downto 32) := ETH_TYPE_G;
                  -- Check for eof during caching
                  if r.eof = '0' then
                     v.ibMacMaster.tData(54 downto 48) := (others => '0');
                  else
                     v.ibMacMaster.tData(54 downto 48) := toSlv(r.minByteCnt, 7);
                  end if;
                  -- Check for broadcast message
                  if (r.bcf = '1') then
                     v.ibMacMaster.tData(63 downto 55) := (others => '1');
                  else
                     v.ibMacMaster.tData(63 downto 55) := r.tDest & '0';
                  end if;
               elsif r.rdAddr(15 downto 3) = 0 then
                  -- Move the data
                  v.ibMacMaster.tValid             := '1';
                  v.ibMacMaster.tData(63 downto 0) := rdData;
                  -- Check for eof during caching
                  if r.eof = '1' then
                     -- Check for last transfer
                     if r.rdAddr(2 downto 0) = r.wrAddr then
                        -- Set EOF
                        v.ibMacMaster.tLast := '1';
                        -- Set the EOFE
                        ssiSetUserEofe(RAW_ETH_CONFIG_INIT_C, v.ibMacMaster, r.eofe);
                        -- Next state
                        v.state             := IDLE_S;
                     end if;
                  end if;
               elsif (obAppMaster.tValid = '1') then
                  -- Accept the data
                  v.obAppSlave.tReady              := '1';
                  -- Move the data
                  v.ibMacMaster.tValid             := '1';
                  v.ibMacMaster.tData(63 downto 0) := obAppMaster.tData(63 downto 0);
                  v.ibMacMaster.tKeep(7 downto 0)  := obAppMaster.tKeep(7 downto 0);
                  -- Check for tLast
                  if obAppMaster.tLast = '1' then
                     -- Set EOF
                     v.ibMacMaster.tLast := '1';
                     -- Get the EOFE
                     v.eofe              := ssiGetUserEofe(RAW_ETH_CONFIG_INIT_C, obAppMaster);
                     -- Set the EOFE
                     ssiSetUserEofe(RAW_ETH_CONFIG_INIT_C, v.ibMacMaster, v.eofe);
                     -- Next state
                     v.state             := IDLE_S;
                  end if;
               end if;
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
      obAppSlave  <= v.obAppSlave;
      ibMacMaster <= r.ibMacMaster;
      tDest       <= v.tDest;
      req         <= v.req;
      
   end process comb;

   seq : process (clk) is
   begin
      if rising_edge(clk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;
