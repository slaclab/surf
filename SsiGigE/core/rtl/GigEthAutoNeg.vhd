---------------------------------------------------------------------------------
-- Title         : Gigabit Ethernet (1000 BASE X) autonegotiation
-- Project       : General Purpose Core
---------------------------------------------------------------------------------
-- File          : GigEthAutoNeg.vhd
-- Author        : Kurtis Nishimura, kurtisn@slac.stanford.edu
-- Created       : 05/22/2014
---------------------------------------------------------------------------------
-- Description:
-- Physical interface receive module for 1000 BASE-X.
---------------------------------------------------------------------------------
-- Copyright (c) 2015 SLAC National Accelerator Laboratory
---------------------------------------------------------------------------------
-- Modification history:
-- 05/22/2014: created.
---------------------------------------------------------------------------------

LIBRARY ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use work.StdRtlPkg.all;
use work.GigEthPkg.all;

entity GigEthAutoNeg is 
   generic (
      TPD_G         : time                 := 1 ns;
      SIM_SPEEDUP_G : boolean              := false;
      RX_LANE_CNT_G : integer range 1 to 1 := 1;
      PIPE_STAGES_G : integer range 1 to 8 := 2
   );
   port ( 

      -- System clock, reset & control
      ethRxClk          : in  sl;                               -- Master clock (62.5 MHz)
      ethRxClkRst       : in  sl;                               -- Synchronous reset input

      -- Link is ready
      ethRxLinkReady    : out sl;                               -- Local side has link
      -- Link is stable
      ethRxLinkSync     : in  sl;                               -- Synchronized

      -- Physical Interface Signals
      phyRxData         : in  slv(15 downto 0); -- PHY receive data
      phyRxDataK        : in  slv( 1 downto 0); -- PHY receive data is K character
      phyTxData         : out slv(15 downto 0); -- PHY transmit data
      phyTxDataK        : out slv( 1 downto 0)
   ); 

end GigEthAutoNeg;


-- Define architecture
architecture rtl of GigEthAutoNeg is

   type AutoNegStateType is (S_IDLE, S_AUTONEG_RESTART, S_ABILITY_DETECT,
                          S_ACK_DETECT, S_COMPLETE_ACK, S_IDLE_DETECT, S_LINK_UP);

   type slv16array is array (PIPE_STAGES_G-1 downto 0) of slv(15 downto 0);
   type slv2array is array (PIPE_STAGES_G-1 downto 0) of slv(1 downto 0);
   
   type RegType is record
      autoNegState  : AutoNegStateType;
      rxDataPipe    : slv16array;
      rxDataKPipe   : slv2array;
      txData        : slv(15 downto 0);
      toggleC1C2    : sl;
      toggleWord    : sl;
      timerCnt      : slv(19 downto 0);
      sendIdle      : sl;
      linkUp        : sl;
      newState      : sl;
   end record RegType;
   
   constant REG_INIT_C : RegType := (
      autoNegState  => S_IDLE,
      rxDataPipe    => (others => (others => '0')),
      rxDataKPipe   => (others => (others => '0')),
      txData        => (others => '0'),
      toggleC1C2    => '0',
      toggleWord    => '0',
      timerCnt      => (others => '0'),
      sendIdle      => '0',
      linkUp        => '0',
      newState      => '0'
   );
   
   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   -- Signals for outputs from the match unit
   signal abilityMatch     : sl;
   signal acknowledgeMatch : sl;
   signal consistencyMatch : sl;
   signal idleMatch        : sl;
   signal ability          : slv(15 downto 0);

   constant THIS_LINK_TIMER_C : natural := ite(SIM_SPEEDUP_G, 127, LINK_TIMER_C);
   
   -- attribute mark_debug : string;
   -- attribute mark_debug of r : signal is "true";

begin

   -- Match unit
   U_AbMatch : entity work.AbilityMatch
      port map (
         ethRxClk          => ethRxClk,
         ethRxClkRst       => ethRxClkRst,
         ethRxLinkSync     => ethRxLinkSync,
         newState          => r.newState,
         abilityMatch      => abilityMatch,
         ability           => ability,
         acknowledgeMatch  => acknowledgeMatch,
         consistencyMatch  => consistencyMatch,
         idleMatch         => idleMatch,
         phyRxData         => r.rxDataPipe(PIPE_STAGES_G-1),
         phyRxDataK        => r.rxDataKPipe(PIPE_STAGES_G-1)
      );


   comb : process(r,phyRxData,phyRxDataK,ethRxClkRst,ethRxLinkSync,abilityMatch,acknowledgeMatch,consistencyMatch,idleMatch,ability) is
      variable v : RegType;
   begin
      v := r;

      -- Pipeline for incoming data
      for i in PIPE_STAGES_G-1 downto 0 loop
         if (i /= 0) then
            v.rxDataPipe(i)    := v.rxDataPipe(i-1);
            v.rxDataKPipe(i)   := v.rxDataKPipe(i-1);
         else
            v.rxDataPipe(0)    := phyRxData;
            v.rxDataKPipe(0)   := phyRxDataK;
         end if;
      end loop;      

      -- Toggle the configuration bit if toggleWord is 1
      if (r.toggleWord = '1') then
         v.toggleC1C2 := not(r.toggleC1C2);
      end if;
      -- Always switch between /C(1,2)/ and ConfigReg
      v.toggleWord := not(r.toggleWord);

      -- Choose what to send here (idle or configuration)
      if (r.sendIdle = '0') then
         if (r.toggleWord = '0') then
            if (r.toggleC1C2 = '0') then
               phyTxData  <= OS_C1_C;
               phyTxDataK <= "01";
            else
               phyTxData  <= OS_C2_C;
               phyTxDataK <= "01";
            end if;
         else
            phyTxData  <= r.txData;
            phyTxDataK <= "00";
         end if;
      else
         phyTxData  <= OS_I2_C;
         phyTxDataK <= "01";
      end if;
      
      -- Combinatorial state logic
      case(r.autoNegState) is
         -- Just transmit breaklink until you get a restart
         when S_IDLE =>
            v.txData    := OS_BL_C;
            v.sendIdle  := '0';
            v.timerCnt  := (others => '0');
            v.linkUp    := '0';
            if (ethRxLinkSync = '1') then
               v.autoNegState := S_AUTONEG_RESTART;
            end if;
         -- Transmit breaklink for 10 ms
         when S_AUTONEG_RESTART =>
            v.sendIdle := '0';
            v.txData   := OS_BL_C;
            v.timerCnt := r.timerCnt + 1;
            if (r.timerCnt > THIS_LINK_TIMER_C) then
               v.timerCnt     := (others => '0');
               v.autoNegState := S_ABILITY_DETECT;
            end if;
         -- Transmit own configuration with no ack
         -- Exit when we see 3 consistent non-breaklink configs
         when S_ABILITY_DETECT =>
            v.sendIdle := '0';
            v.txData   := OS_CN_C;
            if (abilityMatch = '1' and ability /= 0) then
               v.autoNegState := S_ACK_DETECT;
            end if;
         -- Send configuration with ack bit
         -- Back to start on ackMatch and not(consistMatch)
         -- Success if we get ackMatch and consistencyMatch
         when S_ACK_DETECT => 
            v.sendIdle := '0';
            v.txData := OS_CA_C;
            if ( (acknowledgeMatch = '1' and consistencyMatch = '0') or 
                 (abilityMatch = '1' and ability = 0) ) then
               v.autoNegState := S_IDLE;
            elsif (acknowledgeMatch = '1' and consistencyMatch = '1') then
               v.autoNegState := S_COMPLETE_ACK;
            end if;
         -- Just send configuration with ack bit for timeout period 
         -- (we're not trying to do next pages [yet])
         when S_COMPLETE_ACK => 
            v.sendIdle := '0';
            v.txData   := OS_CA_C;
            if (abilityMatch = '1' and ability = 0) then
               v.autoNegState := S_IDLE;
            end if;
            if (r.timerCnt < THIS_LINK_TIMER_C) then
               v.timerCnt     := r.timerCnt + 1;
            elsif (abilityMatch = '0' or ability /= 0) then
               v.timerCnt     := (others => '0');
               v.autoNegState := S_IDLE_DETECT;
            end if;
         -- Send idles
         when S_IDLE_DETECT =>
            v.sendIdle := '1';
            if (abilityMatch = '1' and ability = 0) then
               v.autoNegState := S_IDLE;
            end if;
            if (r.timerCnt < THIS_LINK_TIMER_C) then
               v.timerCnt     := r.timerCnt + 1;
            elsif (idleMatch = '1') then
               v.timerCnt     := (others => '0');
               v.autoNegState := S_LINK_UP;
            end if;
         when S_LINK_UP =>
            v.sendIdle := '1';
            v.linkUp   := '1';
            if (abilityMatch = '1') then
               v.autoNegState := S_IDLE;
            end if;            
         when others =>
      end case;

      -- If we lose sync, always go back to the start
      if (ethRxLinkSync = '0') then
         v.autoNegState := S_IDLE;
      end if;      
      
      -- Check for new state condition
      if (v.autoNegState /= r.autoNegState) then
         v.newState := '1';
      else 
         v.newState := '0';
      end if;
      
      -- Reset logic
      if (ethRxClkRst = '1') then
         v := REG_INIT_C;
      end if;

      ethRxLinkReady <= r.linkUp;
      
      rin <= v;

   end process;

   seq : process (ethRxClk) is
   begin
      if (rising_edge(ethRxClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;   

end rtl;

