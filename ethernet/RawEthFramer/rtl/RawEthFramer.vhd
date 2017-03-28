-------------------------------------------------------------------------------
-- File       : RawEthFramer.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-05-23
-- Last update: 2016-05-26
-------------------------------------------------------------------------------
-- Description: Top-level Raw L2 Ethernet Framer
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

entity RawEthFramer is
   generic (
      TPD_G      : time             := 1 ns;
      ETH_TYPE_G : slv(15 downto 0) := x"0010");  --  0x1000 (big-Endian configuration)
   port (
      -- Local Configurations
      localMac    : in  slv(47 downto 0);         --  big-Endian configuration
      remoteMac   : in  slv(47 downto 0);         --  big-Endian configuration
      tDest       : out slv(7 downto 0);
      -- Interface to Ethernet Media Access Controller (MAC)
      obMacMaster : in  AxiStreamMasterType;
      obMacSlave  : out AxiStreamSlaveType;
      ibMacMaster : out AxiStreamMasterType;
      ibMacSlave  : in  AxiStreamSlaveType;
      -- Interface to Application engine(s)
      ibAppMaster : out AxiStreamMasterType;
      ibAppSlave  : in  AxiStreamSlaveType;
      obAppMaster : in  AxiStreamMasterType;
      obAppSlave  : out AxiStreamSlaveType;
      -- Clock and Reset
      clk         : in  sl;
      rst         : in  sl);
end RawEthFramer;

architecture rtl of RawEthFramer is

   type StateType is (
      IDLE_S,
      RX_S,
      TX_S);

   type RegType is record
      rxAck : sl;
      txAck : sl;
      rxMac : slv(47 downto 0);
      txMac : slv(47 downto 0);
      rdEn  : sl;
      tDest : slv(7 downto 0);
      state : StateType;
   end record RegType;
   constant REG_INIT_C : RegType := (
      rxAck => '0',
      txAck => '0',
      rxMac => (others => '0'),
      txMac => (others => '0'),
      rdEn  => '0',
      tDest => (others => '0'),
      state => IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal rxReq  : sl;
   signal txReq  : sl;
   signal rxDest : slv(7 downto 0);
   signal txDest : slv(7 downto 0);
   signal rxAck  : sl;
   signal txAck  : sl;
   signal rxMac  : slv(47 downto 0);
   signal txMac  : slv(47 downto 0);

   -- attribute dont_touch           : string;
   -- attribute dont_touch of r      : signal is "TRUE";

begin

   U_Tx : entity work.RawEthFramerTx
      generic map (
         TPD_G      => TPD_G,
         ETH_TYPE_G => ETH_TYPE_G) 
      port map (
         -- Local Configurations
         localMac    => localMac,
         remoteMac   => txMac,
         tDest       => txDest,
         req         => txReq,
         ack         => txAck,
         -- Interface to Ethernet Media Access Controller (MAC)
         ibMacMaster => ibMacMaster,
         ibMacSlave  => ibMacSlave,
         -- Interface to Application engine(s)
         obAppMaster => obAppMaster,
         obAppSlave  => obAppSlave,
         -- Clock and Reset
         clk         => clk,
         rst         => rst);

   U_Rx : entity work.RawEthFramerRx
      generic map (
         TPD_G      => TPD_G,
         ETH_TYPE_G => ETH_TYPE_G) 
      port map (
         -- Local Configurations
         localMac    => localMac,
         remoteMac   => rxMac,
         tDest       => rxDest,
         req         => rxReq,
         ack         => rxAck,
         -- Interface to Ethernet Media Access Controller (MAC)
         obMacMaster => obMacMaster,
         obMacSlave  => obMacSlave,
         -- Interface to Application engine(s)
         ibAppMaster => ibAppMaster,
         ibAppSlave  => ibAppSlave,
         -- Clock and Reset
         clk         => clk,
         rst         => rst); 

   comb : process (r, remoteMac, rst, rxDest, rxReq, txDest, txReq) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Reset the flags
      v.rxAck := '0';
      v.txAck := '0';

      -- shift Register
      v.rdEn := '0';

      -- State Machine
      case r.state is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Check for RX request
            if (r.rxAck = '0') and (rxReq = '1') then
               -- Set the flag
               v.rdEn  := '1';
               -- Set the data bus
               v.tDest := rxDest;
               -- Next state
               v.state := RX_S;
            elsif (r.txAck = '0') and (txReq = '1') then
               -- Set the flag
               v.rdEn  := '1';
               -- Set the data bus
               v.tDest := txDest;
               -- Next state
               v.state := TX_S;
            end if;
         ----------------------------------------------------------------------
         when RX_S =>
            -- Check if data is ready
            if r.rdEn = '0' then
               -- Set the flag
               v.rxAck := '1';
               -- Set the data bus
               v.rxMac := remoteMac;
               -- Next state
               v.state := IDLE_S;
            end if;
         ----------------------------------------------------------------------
         when TX_S =>
            -- Check if data is ready
            if r.rdEn = '0' then
               -- Set the flag
               v.txAck := '1';
               -- Set the data bus
               v.txMac := remoteMac;
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
      tDest <= v.tDest;
      rxAck <= v.rxAck;
      txAck <= v.txAck;
      rxMac <= v.rxMac;
      txMac <= v.txMac;
      
   end process comb;

   seq : process (clk) is
   begin
      if rising_edge(clk) then
         r <= rin after TPD_G;
      end if;
   end process seq;
   
end rtl;
