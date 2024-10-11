-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Top-Level UDP/DHCP Module
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

entity ArpIpTable is

   generic (
      TPD_G          : time                    := 1 ns;
      CLK_FREQ_G     : real                    := 156.25E+06;
      COMM_TIMEOUT_G : positive                := 30;
      ENTRIES_G      : positive range 1 to 255 := 4);
   port (
      -- Clock and Reset
      clk                  : in  sl;
      rst                  : in  sl;
      -- Read LUT
      ipAddrIn             : in  slv(31 downto 0);
      pos                  : in  slv(7 downto 0);
      found                : out sl;
      macAddr              : out slv(47 downto 0);
      ipAddrOut            : out slv(31 downto 0);
      -- Refresh LUT
      clientRemoteDetIp    : in  slv(31 downto 0);
      clientRemoteDetValid : in  sl;
      -- Write LUT
      ipWrEn               : in  sl;
      IpWrAddr             : in  slv(31 downto 0);
      macWrEn              : in  sl;
      macWrAddr            : in  slv(47 downto 0));
end entity ArpIpTable;

architecture rtl of ArpIpTable is

   -- Write stuff
   type wRegType is record
      ipLutTable   : Slv32Array(ENTRIES_G-1 downto 0);
      macLutTable  : Slv48Array(ENTRIES_G-1 downto 0);
      fifoRdEn     : sl;
      fifoValid    : sl;
      overwrite    : boolean;
      writingNewIp : boolean;
      entryCount   : slv(7 downto 0);
   end record wRegType;

   constant W_REG_INIT_C : wRegType := (
      ipLutTable   => (others => (others => '0')),
      macLutTable  => (others => (others => '0')),
      fifoRdEn     => '0',
      fifoValid    => '0',
      overwrite    => false,
      writingNewIp => false,
      entryCount   => (others => '0')
      );

   signal wR   : wRegType := W_REG_INIT_C;
   signal wRin : wRegType;

   -- Read Stuff
   signal matchArray : slv(ENTRIES_G-1 downto 0);

   -- Expire stuff
   --constant TIMER_1_SEC_C : natural := getTimeRatio(CLK_FREQ_G, 1.0);
   constant TIMER_1_SEC_C : natural := 238;
   type TimerArray is array (natural range <>) of natural range 0 to COMM_TIMEOUT_G;
   type ExpStateType is (
      IDLE_S,
      MONITOR_S,
      EXPIRE_S
      );
   type ExpStateArray is array (natural range <>) of ExpStateType;

   type eRegType is record
      timerEn    : sl;
      state      : ExpStateArray(ENTRIES_G-1 downto 0);
      timer      : natural range 0 to (TIMER_1_SEC_C-1);
      arpTimers  : TimerArray(ENTRIES_G-1 downto 0);
      arbRequest : slv(ENTRIES_G-1 downto 0);
   end record eRegType;

   constant E_REG_INIT_C : eRegType :=
      (
         timerEn    => '0',
         state      => (others => IDLE_S),
         timer      => 0,
         arpTimers  => (others => 0),
         arbRequest => (others => '0')
         );

   signal eR   : eRegType := E_REG_INIT_C;
   signal eRin : eRegType;

   -- Arbiter
   signal arbSelected        : slv(bitSize(ENTRIES_G-1)-1 downto 0);
   signal arbSelectedResized : slv(7 downto 0);
   signal arbValid           : sl;

   -- FIFO
   signal fifoData  : slv(7 downto 0);
   signal fifoValid : sl;
   signal fifoEmpty : sl;

begin  -- architecture rtl

   -- Write process comb
   wrComb : process (arbSelected, arbValid, fifoData, fifoEmpty, fifoValid,
                     ipWrAddr, ipWrEn, macWrAddr, macWrEn, rst, wR) is
      variable v           : wRegType;
      variable wrAddInt    : integer;
      variable wrAddIntMac : integer;
   begin
      -- Latch the current value
      v := wR;

      -- Update flags
      v.overwrite    := false;
      v.fifoValid    := '0';
      v.writingNewIp := false;

      -- Write IP to LUT
      if ipWrEn = '1' or wR.overwrite then
         wrAddInt := conv_integer(wR.entryCount);
         if fifoEmpty = '0' and (not wR.overwrite) then
            v.fifoRdEn := '1';
         elsif wrAddInt < ENTRIES_G then
            v.ipLutTable(wrAddInt) := ipWrAddr;
            v.writingNewIp         := true;
            wrAddIntMac            := wrAddInt;
         end if;
      end if;

      -- Write MAC to LUT
      if macWrEn = '1' then
         -- wrAddInt := conv_integer(wR.entryCount);
         -- if wrAddInt < ENTRIES_G then
         v.macLutTable(wrAddIntMac) := macWrAddr;
         -- end if;

         -- Update write LUT pointer
         if wR.entryCount < ENTRIES_G - 1 then
            v.entryCount := wr.entryCount + 1;
         else
            v.entryCount := (others => '0');
         end if;
      end if;

      -- Overwrite LUT pointer if there are empty spaces
      if fifoValid = '1' then
         v.fifoValid := '1';
         v.fifoRdEn  := '0';
      end if;

      if wR.fifoValid = '1' then
         v.entryCount := fifoData;
         v.overwrite  := true;
      end if;

      -- Remove entry from LUT
      if arbValid = '1' then
         wrAddInt                := conv_integer(arbSelected);
         v.macLutTable(wrAddInt) := (others => '0');
         v.ipLutTable(wrAddInt)  := (others => '0');
      end if;

      -- Reset
      if (rst = '1') then
         v := W_REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      wRin <= v;

   end process wrComb;

   wrSeq : process (clk) is
   begin
      if rising_edge(clk) then
         wR <= wRin after TPD_G;
      end if;
   end process wrSeq;

   -- Read process
   -- Check for a match
   gen_compare : for i in 0 to ENTRIES_G-1 generate
      matchArray(i) <= '1' when (wR.ipLutTable(i) = ipAddrIn) else '0';
   end generate;

   -- Encode the position based on the match_array
   process(matchArray, pos, wr.macLutTable)
      variable ipFound      : sl := '0';
      variable posI         : integer;
      variable foundMacAddr : slv(47 downto 0);
      variable foundIpAddr  : slv(31 downto 0);
   begin
      ipFound      := '0';
      foundMacAddr := (others => '0');
      foundIpAddr  := (others => '0');
      if pos > 0 then
         posI := conv_integer(pos-1);
         if posI < ENTRIES_G then
            foundMacAddr := wr.macLutTable(posI);
            foundIpAddr  := wr.ipLutTable(posI);
            if uOr(foundMacAddr) = '0' or uOr(foundIpAddr) = '0' then
               ipFound := '0';
            else
               ipFound := '1';
            end if;
         else
            ipFound      := '0';
            foundMacAddr := (others => '0');
            foundIpAddr  := (others => '0');
            assert false report "Position in the LUT outside of bounds" severity error;
         end if;
      else
         for i in 0 to ENTRIES_G-1 loop
            if matchArray(i) = '1' then
               foundMacAddr := wr.macLutTable(i);
               ipFound      := '1';
               exit;                    -- Exit as soon as a match is found
            end if;
         end loop;
      end if;
      found     <= ipFound;
      macAddr   <= foundMacAddr;
      ipAddrOut <= foundIpAddr;
   end process;

   -- Expiration process
   expComb : process (arbSelected, arbValid, clientRemoteDetIp,
                      clientRemoteDetValid, eR, rst, wR) is
      variable v : eRegType;
   begin  -- process expComb
      -- Latch the current value
      v := eR;

      -- Reset the flags
      v.timerEn := '0';

      -- Increment the timer
      if eR.timer = (TIMER_1_SEC_C-1) then
         v.timer   := 0;
         v.timerEn := '1';
      else
         v.timer := eR.timer + 1;
      end if;

      -- Loop through the entries
      for i in 0 to ENTRIES_G-1 loop

         -- Update the timers
         if (eR.timerEn = '1') and (eR.arpTimers(i) /= 0) then
            -- Decrement the timers
            v.arpTimers(i) := eR.arpTimers(i) - 1;
         end if;

         case eR.state(i) is
            -------------------------------------------------------------------
            when IDLE_S =>
               if (uOr(wR.ipLutTable(i)) /= '0' and uOr(wR.macLutTable(i)) /= '0') then
                  -- Preset the timer
                  v.arpTimers(i) := COMM_TIMEOUT_G;
                  -- Next state
                  v.state(i)     := MONITOR_S;
               end if;
            ----------------------------------------------------------------
            when MONITOR_S =>
               if clientRemoteDetValid = '1' and clientRemoteDetIp = wR.ipLutTable(i) then
                  -- Preset the timer
                  v.arpTimers(i) := COMM_TIMEOUT_G;
               elsif wR.writingNewIp and conv_integer(wR.entryCount) = i then
                  -- Preset the timer
                  v.arpTimers(i) := COMM_TIMEOUT_G;
               elsif eR.arpTimers(i) = 0 then
                  -- Next state
                  v.state(i) := EXPIRE_S;
               end if;
               if (uOr(wR.ipLutTable(i)) = '0' and uOr(wR.macLutTable(i)) = '0') then
                  -- Next state
                  v.state(i) := IDLE_S;
               end if;
            ----------------------------------------------------------------
            when EXPIRE_S =>
               -- Raise hand
               v.arbRequest(i) := '1';
               if arbSelected = i and arbValid = '1' then
                  -- Lower hand
                  v.arbRequest(i) := '0';
                  -- Next state
                  v.state(i)      := IDLE_S;
               end if;
            ----------------------------------------------------------------
            when others =>
               -- Fallback on idle state
               v.state(i) := IDLE_S;
         ----------------------------------------------------------------
         end case;

      end loop;  -- i

      -- Reset
      if (rst = '1') then
         v := E_REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      eRin <= v;

   end process expComb;

   expSeq : process (clk) is
   begin
      if rising_edge(clk) then
         eR <= eRin after TPD_G;
      end if;
   end process expSeq;

   -- Arbiter
   U_Arbiter : entity surf.Arbiter
      generic map (
         TPD_G      => TPD_G,
         REQ_SIZE_G => ENTRIES_G)
      port map (
         clk      => clk,
         rst      => rst,
         req      => eRin.arbRequest,
         selected => arbSelected,
         valid    => arbValid,
         ack      => open);

   arbSelectedResized <= resize(arbSelected, 8);

   -- Empty spaces FIFO
   U_ExpFifo : entity surf.Fifo
      generic map (
         TPD_G           => TPD_G,
         GEN_SYNC_FIFO_G => true,
         FWFT_EN_G       => false,
         DATA_WIDTH_G    => 8,
         ADDR_WIDTH_G    => 8)
      port map (
         rst    => rst,
         -- Write ports
         wr_clk => clk,
         wr_en  => arbValid,
         din    => arbSelectedResized,
         wr_ack => open,
         -- Read ports
         rd_clk => clk,
         rd_en  => wR.fifoRdEn,
         dout   => fifoData,
         valid  => fifoValid,
         empty  => fifoEmpty);

end architecture rtl;
