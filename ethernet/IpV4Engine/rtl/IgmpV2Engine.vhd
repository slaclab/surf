-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Igmp Engine (A.K.A. "ping" protocol)
-------------------------------------------------------------------------------
-- TODO: Add Leave Group messaging (Message Type = 0x17) support
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

library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;
use surf.SsiPkg.all;
use surf.EthMacPkg.all;

entity IgmpV2Engine is
   generic (
      TPD_G         : time     := 1 ns;
      IGMP_GRP_SIZE : positive := 1;
      CLK_FREQ_G    : real     := 156.25E+06);  -- In units of Hz
   port (
      -- Local Configurations
      localIp      : in  slv(31 downto 0);      --  big-Endian configuration
      igmpIp       : in  Slv32Array(IGMP_GRP_SIZE-1 downto 0);  --  big-Endian configuration
      -- Interface to Igmp Engine
      ibIgmpMaster : in  AxiStreamMasterType;
      ibIgmpSlave  : out AxiStreamSlaveType;
      obIgmpMaster : out AxiStreamMasterType;
      obIgmpSlave  : in  AxiStreamSlaveType;
      -- Clock and Reset
      clk          : in  sl;
      rst          : in  sl);
end IgmpV2Engine;

architecture rtl of IgmpV2Engine is

   constant TIMER_100MS_C : natural := getTimeRatio(CLK_FREQ_G, 10.0);  -- units of 0.1 second

   type RxStateType is (
      RX_IDLE_S,
      RX_MSG_S);

   type TxStateType is (
      TX_IDLE_S,
      TX_MSG_S);

   type RegType is record
      txCnt        : natural range 0 to IGMP_GRP_SIZE-1;
      cnt          : natural range 0 to TIMER_100MS_C;
      sendReport   : slv(IGMP_GRP_SIZE-1 downto 0);
      rndCnt       : slv(7 downto 0);
      timer        : slv(7 downto 0);
      obIgmpMaster : AxiStreamMasterType;
      rxState      : RxStateType;
      txState      : TxStateType;
   end record RegType;
   constant REG_INIT_C : RegType := (
      txCnt        => 0,
      cnt          => 0,
      sendReport   => (others => '1'),  -- Send report message at power up
      rndCnt       => (others => '0'),
      timer        => (others => '1'),  -- Power up delay before sending report messages
      obIgmpMaster => AXI_STREAM_MASTER_INIT_C,
      rxState      => RX_IDLE_S,
      txState      => TX_IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   -- attribute dont_touch      : string;
   -- attribute dont_touch of r : signal is "TRUE";

begin

   comb : process (ibIgmpMaster, igmpIp, localIp, obIgmpSlave, r, rst) is
      variable v      : RegType;
      variable rxXsum : slv(17 downto 0);
      variable txXsum : slv(17 downto 0);
   begin
      -- Latch the current value
      v := r;

      ------------------------------------------------
      -- Notes: Non-Standard IPv4 Pseudo Header Format
      ------------------------------------------------
      -- tData[0][47:0]   = Remote MAC Address
      -- tData[0][63:48]  = zeros
      -- tData[0][95:64]  = Remote IP Address
      -- tData[0][127:96] = Local IP address
      -- tData[1][7:0]    = zeros
      -- tData[1][15:8]   = Protocol Type = Igmp
      -- tData[1][31:16]  = IPv4 Pseudo header length
      -- tData[1][39:32]  = Type of message
      -- tData[1][47:40]  = Max Resp Time
      -- tData[1][63:48]  = Checksum
      -- tData[1][95:64]  = Group Address
      ------------------------------------------------

      -- Calculate the RX checksum
      rxXsum := resize(ibIgmpMaster.tData(39 downto 32) & ibIgmpMaster.tData(47 downto 40), 18);
      rxXsum := resize(ibIgmpMaster.tData(71 downto 64) & ibIgmpMaster.tData(79 downto 72), 18) + rxXsum;
      rxXsum := resize(ibIgmpMaster.tData(87 downto 80) & ibIgmpMaster.tData(95 downto 88), 18) + rxXsum;
      rxXsum := resize(rxXsum(17 downto 16), 18) + resize(rxXsum(15 downto 0), 18);
      rxXsum := not(rxXsum);

      -- Increment the "random" timer
      v.rndCnt := r.rndCnt + 1;

      -- RX State Machine
      case r.rxState is
         ----------------------------------------------------------------------
         when RX_IDLE_S =>
            -- Check for data with SOF and no EOF
            if (ibIgmpMaster.tValid = '1') and (ssiGetUserSof(EMAC_AXIS_CONFIG_C, ibIgmpMaster) = '1') and (ibIgmpMaster.tLast = '0') then
               -- Next state
               v.rxState := RX_MSG_S;
            end if;
         ----------------------------------------------------------------------
         when RX_MSG_S =>
            -- Check for data
            if (ibIgmpMaster.tValid = '1') then

               -- Next state
               v.rxState := RX_IDLE_S;

               -- Check for valid checksum
               if (rxXsum(15 downto 8) = ibIgmpMaster.tData(55 downto 48)) and (rxXsum(7 downto 0) = ibIgmpMaster.tData(63 downto 56)) then

                  -- Check for Membership Query message
                  if (ibIgmpMaster.tData(39 downto 32) = x"11") and (ibIgmpMaster.tData(95 downto 64) = 0) then
                     -- Loop through the group addresses
                     for i in IGMP_GRP_SIZE-1 downto 0 loop
                        -- Check if matches group address
                        if (igmpIp(i) /= 0) then
                           -- Reset the flag
                           v.sendReport(i) := '1';
                        end if;
                        -- Set the "random" timer
                        v.timer := ibIgmpMaster.tData(47 downto 40);
                        if resize(r.rndCnt(7 downto i), 8) < ibIgmpMaster.tData(47 downto 40) then
                           v.timer := resize(r.rndCnt(7 downto i), 8);
                        end if;
                     end loop;
                  end if;

                  -- Check for Membership Report message
                  if (ibIgmpMaster.tData(39 downto 32) = x"16") then
                     -- Loop through the group addresses
                     for i in IGMP_GRP_SIZE-1 downto 0 loop
                        -- Check if matches group address
                        if (igmpIp(i) = ibIgmpMaster.tData(95 downto 64)) then
                           -- Reset the flag
                           v.sendReport(i) := '0';
                        end if;
                     end loop;
                  end if;

               end if;
            end if;
      ----------------------------------------------------------------------
      end case;

      -- Check for timeout
      if (r.cnt = (TIMER_100MS_C-1)) then
         -- Reset the counter
         v.cnt := 0;
         -- Check if need to decrement timer
         if (r.timer /= 0) then
            v.timer := r.timer - 1;
         end if;
      else
         -- Increment the timer
         v.cnt := r.cnt + 1;
      end if;

      -- Reset the flags
      if obIgmpSlave.tReady = '1' then
         v.obIgmpMaster.tValid := '0';
         v.obIgmpMaster.tLast  := '0';
         v.obIgmpMaster.tUser  := (others => '0');
         v.obIgmpMaster.tKeep  := (others => '1');
      end if;

      -- Calculate the TX checksum
      txXsum := resize(x"16" & x"00", 18);
      txXsum := resize(r.obIgmpMaster.tData(103 downto 96) & r.obIgmpMaster.tData(111 downto 104), 18) + txXsum;
      txXsum := resize(r.obIgmpMaster.tData(119 downto 112) & r.obIgmpMaster.tData(127 downto 120), 18) + txXsum;
      txXsum := resize(txXsum(17 downto 16), 18) + resize(txXsum(15 downto 0), 18);
      txXsum := not(txXsum);

      -- TX State Machine
      case r.txState is
         ----------------------------------------------------------------------
         when TX_IDLE_S =>
            -- Check for timeout
            if (r.timer = 0) then

               -- Check if ready to move data
               if (v.obIgmpMaster.tValid = '0') then

                  -- Setup the IPv4 base header
                  ssiSetUserSof(EMAC_AXIS_CONFIG_C, v.obIgmpMaster, '1');
                  v.obIgmpMaster.tData(47 downto 0)   := igmpIp(r.txCnt)(31 downto 8) & x"5E_00_01";  -- IPv4mcast
                  v.obIgmpMaster.tData(95 downto 64)  := localIp;  -- SRC IP
                  v.obIgmpMaster.tData(127 downto 96) := igmpIp(r.txCnt);  -- DST IP

                  -- Check if need to send report and non-zero group IP
                  if (r.sendReport(r.txCnt) = '1') and (igmpIp(r.txCnt) /= 0) then

                     -- Clear the flag
                     v.sendReport(r.txCnt) := '0';

                     -- Send the IPv4 base header
                     v.obIgmpMaster.tValid := '1';

                     -- Next state
                     v.txState := TX_MSG_S;

                  end if;

                  -- Increment counter
                  if (r.txCnt = IGMP_GRP_SIZE-1) then
                     v.txCnt := 0;
                  else
                     v.txCnt := r.txCnt + 1;
                  end if;

               end if;
            end if;
         ----------------------------------------------------------------------
         when TX_MSG_S =>
            -- Check if ready to move data
            if (v.obIgmpMaster.tValid = '0') then

               -- Next state
               v.txState := TX_IDLE_S;

               -- Send the Membership Report message
               v.obIgmpMaster.tValid              := '1';
               v.obIgmpMaster.tLast               := '1';
               v.obIgmpMaster.tKeep               := resize(x"FFF", AXI_STREAM_MAX_TKEEP_WIDTH_C);  -- 96-bit word
               v.obIgmpMaster.tData(39 downto 32) := x"16";  -- IGMPv2 Membership Report
               v.obIgmpMaster.tData(47 downto 40) := x"00";  -- Max Resp Time
               v.obIgmpMaster.tData(55 downto 48) := txXsum(15 downto 8);  -- Checksum[15:8]
               v.obIgmpMaster.tData(63 downto 56) := txXsum(7 downto 0);  -- Checksum[7:0]
               v.obIgmpMaster.tData(95 downto 64) := r.obIgmpMaster.tData(127 downto 96);  -- DST IP = Group Address

            end if;
      ----------------------------------------------------------------------
      end case;

      -- Outputs
      ibIgmpSlave  <= AXI_STREAM_SLAVE_FORCE_C;
      obIgmpMaster <= r.obIgmpMaster;

      -- Reset
      if (rst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

   end process comb;

   seq : process (clk) is
   begin
      if rising_edge(clk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;
