-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : RawEthFramerTx.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-05-23
-- Last update: 2016-05-24
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

entity RawEthFramerTx is
   generic (
      TPD_G         : time             := 1 ns;
      REMOTE_SIZE_G : positive         := 1;
      ETH_TYPE_G    : slv(15 downto 0) := x"0010");            --  0x1000 (big-Endian configuration)
   port (
      -- Local Configurations
      localMac    : in  slv(47 downto 0);                      --  big-Endian configuration
      remoteMac   : in  Slv48Array(REMOTE_SIZE_G-1 downto 0);  --  big-Endian configuration
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

   constant AXIS_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(8, TKEEP_COMP_C, TUSER_FIRST_LAST_C, 8, 2);

   type StateType is (
      IDLE_S,
      HDR_S,
      MOVE_S,
      LAST_S); 

   type RegType is record
      tData       : slv(47 downto 0);
      tKeep       : slv(5 downto 0);
      eofe        : sl;
      obAppSlave  : AxiStreamSlaveType;
      ibMacMaster : AxiStreamMasterType;
      state       : StateType;
   end record RegType;
   constant REG_INIT_C : RegType := (
      tData       => (others => '0'),
      tKeep       => (others => '1'),
      eofe        => '0',
      obAppSlave  => AXI_STREAM_SLAVE_INIT_C,
      ibMacMaster => AXI_STREAM_MASTER_INIT_C,
      state       => IDLE_S);     

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   -- attribute dont_touch             : string;
   -- attribute dont_touch of r        : signal is "TRUE";
   
begin

   comb : process (ibMacSlave, localMac, obAppMaster, r, remoteMac, rst) is
      variable v     : RegType;
      variable index : natural;
   begin
      -- Latch the current value
      v := r;

      -- Reset the flags
      v.obAppSlave := AXI_STREAM_SLAVE_INIT_C;
      if ibMacSlave.tReady = '1' then
         v.ibMacMaster.tValid := '0';
         v.ibMacMaster.tLast  := '0';
         v.ibMacMaster.tUser  := (others => '0');
         v.ibMacMaster.tKeep  := x"00FF";
      end if;

      -- Convert to integer 
      index := conv_integer(obAppMaster.tDest);

      -- State Machine
      case r.state is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Check if ready to move data
            if (obAppMaster.tValid = '1') and (v.ibMacMaster.tValid = '0') then
               -- Check for SOF
               if (ssiGetUserSof(AXIS_CONFIG_C, obAppMaster) = '1') then
                  -- Check for valid DEST mac
                  if (remoteMac(index) /= 0) then
                     -- Move the data
                     v.ibMacMaster.tValid              := '1';
                     -- Start writing the header
                     v.ibMacMaster.tData(47 downto 0)  := remoteMac(index);
                     v.ibMacMaster.tData(63 downto 48) := localMac(15 downto 0);
                     -- Set the SOF
                     ssiSetUserSof(AXIS_CONFIG_C, v.ibMacMaster, '1');
                     -- Next state
                     v.state                           := HDR_S;
                  else
                     -- Blowoff data
                     v.obAppSlave.tReady := '1';
                  end if;
               else
                  -- Blowoff data
                  v.obAppSlave.tReady := '1';
               end if;
            end if;
         ----------------------------------------------------------------------
         when HDR_S =>
            -- Check if ready to move data
            if (obAppMaster.tValid = '1') and (v.ibMacMaster.tValid = '0') then
               -- Accept the data
               v.obAppSlave.tReady               := '1';
               -- Move the data
               v.ibMacMaster.tValid              := '1';
               -- Finish writing the header
               v.ibMacMaster.tData(31 downto 0)  := localMac(47 downto 16);
               v.ibMacMaster.tData(47 downto 32) := ETH_TYPE_G;
               v.ibMacMaster.tKeep(5 downto 0)   := (others => '1');
               -- Update tData/tKeep with current information
               v.ibMacMaster.tData(63 downto 48) := obAppMaster.tData(15 downto 0);
               v.ibMacMaster.tKeep(7 downto 6)   := obAppMaster.tKeep(1 downto 0);
               -- Save information for next tValid cycle
               v.tData                           := obAppMaster.tData(63 downto 16);
               v.tKeep                           := obAppMaster.tKeep(7 downto 2);
               -- Get EOFE
               v.eofe                            := ssiGetUserEofe(AXIS_CONFIG_C, obAppMaster);
               -- Check for tLast
               if obAppMaster.tLast = '1' then
                  -- Check if no straddling data
                  if v.tKeep /= "111111" then
                     -- Set EOF
                     v.ibMacMaster.tLast := '1';
                     -- Set the EOFE
                     ssiSetUserEofe(AXIS_CONFIG_C, v.ibMacMaster, v.eofe);
                     -- Next state
                     v.state             := IDLE_S;
                  else
                     -- Next state
                     v.state := LAST_S;
                  end if;
               else
                  -- Next state
                  v.state := MOVE_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when MOVE_S =>
            -- Check if ready to move data
            if (obAppMaster.tValid = '1') and (v.ibMacMaster.tValid = '0') then
               -- Accept the data
               v.obAppSlave.tReady               := '1';
               -- Move the data
               v.ibMacMaster.tValid              := '1';
               -- Update tData/tKeep with overlapped information
               v.ibMacMaster.tData(47 downto 0)  := r.tData;
               v.ibMacMaster.tKeep(5 downto 0)   := r.tKeep;
               -- Update tData/tKeep with current information
               v.ibMacMaster.tData(63 downto 48) := obAppMaster.tData(15 downto 0);
               v.ibMacMaster.tKeep(7 downto 6)   := obAppMaster.tKeep(1 downto 0);
               -- Save information for next tValid cycle
               v.tData                           := obAppMaster.tData(63 downto 16);
               v.tKeep                           := obAppMaster.tKeep(7 downto 2);
               -- Get EOFE
               v.eofe                            := ssiGetUserEofe(AXIS_CONFIG_C, obAppMaster);
               -- Check for tLast
               if obAppMaster.tLast = '1' then
                  -- Check if no straddling data
                  if v.tKeep /= "111111" then
                     -- Set EOF
                     v.ibMacMaster.tLast := '1';
                     -- Set the EOFE
                     ssiSetUserEofe(AXIS_CONFIG_C, v.ibMacMaster, v.eofe);
                     -- Next state
                     v.state             := IDLE_S;
                  else
                     -- Next state
                     v.state := LAST_S;
                  end if;
               end if;
            end if;

         ----------------------------------------------------------------------
         when LAST_S =>
            -- Check if ready to move data
            if (v.ibMacMaster.tValid = '0') then
               -- Move the data
               v.ibMacMaster.tValid              := '1';
               -- Update tData/tKeep with overlapped information
               v.ibMacMaster.tData(47 downto 0)  := r.tData;
               v.ibMacMaster.tKeep(5 downto 0)   := r.tKeep;
               -- Update tData/tKeep with current information
               v.ibMacMaster.tData(63 downto 48) := (others => '0');
               v.ibMacMaster.tKeep(7 downto 6)   := (others => '0');
               -- Set EOF
               v.ibMacMaster.tLast               := '1';
               -- Set the EOFE
               ssiSetUserEofe(AXIS_CONFIG_C, v.ibMacMaster, r.eofe);
               -- Next state
               v.state                           := IDLE_S;
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
      
   end process comb;

   seq : process (clk) is
   begin
      if rising_edge(clk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;
