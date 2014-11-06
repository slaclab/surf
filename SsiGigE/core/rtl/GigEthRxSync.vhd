---------------------------------------------------------------------------------
-- Title         : Gigabit Ethernet (1000 BASE X) link initialization
-- Project       : General Purpose Core
---------------------------------------------------------------------------------
-- File          : GigEthRxSync.vhd
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

entity GigEthRxSync is 
   generic (
      TPD_G         : time                 := 1 ns;
      PIPE_STAGES_G : integer range 1 to 8 := 2
   );
   port ( 

      -- System clock, reset & control
      ethRxClk          : in  sl;                               -- Master clock
      ethRxClkRst       : in  sl;                               -- Synchronous reset input

      -- Link is ready
      ethRxLinkReady    : out sl;                               -- Local side has link

      -- Error Flags, one pulse per event
      ethRxLinkDown     : out sl;                               -- A link down event has occured
      ethRxLinkError    : out sl;                               -- A link error has occured

      -- -- Opcode Receive Interface
      -- pgpRxOpCodeEn     : out sl;                               -- Opcode receive enable
      -- pgpRxOpCode       : out slv(7 downto 0);                  -- Opcode receive value

      -- -- Sideband data
      -- pgpRemLinkReady   : out sl;                               -- Far end side has link
      -- pgpRemData        : out slv(7 downto 0);                  -- Far end side User Data

      -- -- Cell Receive Interface
      -- cellRxPause       : out sl;                               -- Cell data pause
      -- cellRxSOC         : out sl;                               -- Cell data start of cell
      -- cellRxSOF         : out sl;                               -- Cell data start of frame
      -- cellRxEOC         : out sl;                               -- Cell data end of cell
      -- cellRxEOF         : out sl;                               -- Cell data end of frame
      -- cellRxEOFE        : out sl;                               -- Cell data end of frame error
      -- cellRxData        : out slv(RX_LANE_CNT_G*16-1 downto 0); -- Cell data data

      -- Physical Interface Signals
      phyRxPolarity     : out sl;               -- PHY receive signal polarity
      phyRxData         : in  slv(15 downto 0); -- PHY receive data
      phyRxDataK        : in  slv( 1 downto 0); -- PHY receive data is K character
      phyRxDispErr      : in  slv( 1 downto 0); -- PHY receive data has disparity error
      phyRxDecErr       : in  slv( 1 downto 0); -- PHY receive data not in table
      phyRxReady        : in  sl;               -- PHY receive interface is ready
      phyRxInit         : out sl                -- PHY receive interface init;
   ); 

end GigEthRxSync;


-- Define architecture
architecture rtl of GigEthRxSync is

   -- LOS : loss of sync
   -- CD  : combined CommaDetect / AcquireSync state
   -- SA  : sync acquired state   
   type InitStateType is (S_LOS, S_CD, S_SA);
   type slv16array is array (PIPE_STAGES_G-1 downto 0) of slv(15 downto 0);
   type slv2array is array (PIPE_STAGES_G-1 downto 0) of slv(1 downto 0);
   
   type RegType is record
      syncState     : InitStateType;
      rxDataPipe    : slv16array;
      rxDataKPipe   : slv2array;
      rxDispErrPipe : slv2array;
      rxDecErrPipe  : slv2array;
      rxLinkReady   : sl;
      commaCnt      : slv(1 downto 0);
      cgGoodCnt     : slv(1 downto 0);
      cgBadCnt      : slv(1 downto 0);
   end record RegType;
   
   constant REG_INIT_C : RegType := (
      syncState     => S_LOS,
      rxDataPipe    => (others => (others => '0')),
      rxDataKPipe   => (others => (others => '0')),
      rxDispErrPipe => (others => (others => '0')),
      rxDecErrPipe  => (others => (others => '0')),
      rxLinkReady   => '0',
      commaCnt      => (others => '0'),
      cgGoodCnt     => (others => '0'),
      cgBadCnt      => (others => '0')
   );

   -- 8B10B Characters
   constant K_COM_C  : slv(7 downto 0) := "10111100"; -- K28.5, 0xBC

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   comb : process(r,phyRxData,phyRxDecErr,phyRxDispErr,phyRxDataK,ethRxClkRst) is
      variable v : RegType;
   begin
      v := r;

      -- Pipeline for incoming data
      for i in PIPE_STAGES_G-1 downto 0 loop
         if (i /= 0) then
            v.rxDataPipe(i)    := v.rxDataPipe(i-1);
            v.rxDataKPipe(i)   := v.rxDataKPipe(i-1);
            v.rxDispErrPipe(i) := v.rxDispErrPipe(i-1);
            v.rxDecErrPipe(i)  := v.rxDecErrPipe(i-1);
         else
            v.rxDataPipe(0)    := phyRxData;
            v.rxDataKPipe(0)   := phyRxDataK;
            v.rxDispErrPipe(0) := phyRxDispErr;
            v.rxDecErrPipe(0)  := phyRxDecErr;
         end if;
      end loop;
      

      -- Combinatorial state logic
      case(r.syncState) is
         -- Loss of Sync State
         when S_LOS =>
            v.rxLinkReady := '0';
            v.commaCnt    := (others => '0');
            v.cgGoodCnt   := (others => '0');
            v.cgBadCnt    := (others => '0');
            if (r.rxDataKPipe(PIPE_STAGES_G-1)(0) = '1' and r.rxDataPipe(PIPE_STAGES_G-1)(7 downto 0) = K_COM_C) then
               v.syncState := S_CD;
            end if;
         -- Comma detect state (note the GT should only align commas to byte 0 automatically)
         -- If we see 3 commas in the lowest byte without any errors, we're synced.
         when S_CD =>
            if (r.rxDecErrPipe(PIPE_STAGES_G-1) /= "00" or r.rxDispErrPipe(PIPE_STAGES_G-1) /= "00") then
               v.syncState := S_LOS;
            elsif (r.rxDataKPipe(PIPE_STAGES_G-1)(0) = '1' and r.rxDataPipe(PIPE_STAGES_G-1)(7 downto 0) = K_COM_C) then
               v.commaCnt := r.commaCnt + 1;
               if (r.commaCnt = "10") then
                  v.syncState := S_SA;
               end if;
            end if;
         -- Sync acquired state
         -- Monitor for:  1) cggood: valid data or a comma with rx false
         --               2) cgbad:  !valid data or comma in wrong position
         when S_SA =>
            v.rxLinkReady := '1';
            -- Bad code group conditions: decode error, disparity error, comma in wrong byte
            if (r.rxDecErrPipe(PIPE_STAGES_G-1) /= "00" or r.rxDispErrPipe(PIPE_STAGES_G-1) /= "00" or 
                (r.rxDataKPipe(PIPE_STAGES_G-1) = "10" and r.rxDataPipe(PIPE_STAGES_G-1)(15 downto 8) = K_COM_C) ) then
                  if (r.cgBadCnt = "11") then
                     v.syncState := S_LOS;
                  else
                     v.cgBadCnt := r.cgBadCnt + 1;
                  end if;
            else
               if (r.cgBadCnt > 0) then
                  if (r.cgGoodCnt = "11") then
                     v.cgBadCnt  := r.cgBadCnt - 1;
                     v.cgGoodCnt := "00";
                  else
                     v.cgGoodCnt := r.cgGoodCnt + 1;
                  end if;
               end if;
            end if;
         -- Others
         when others =>
            v.syncState := S_LOS;
      end case;

      if (ethRxClkRst = '1') then
         v := REG_INIT_C;
      end if;
      
      rin <= v;

      ethRxLinkReady <= r.rxLinkReady;
      ethRxLinkDown  <= not(r.rxLinkReady);
      ethRxLinkError <= not(r.rxLinkReady);
      phyRxPolarity  <= '0';
      phyRxInit      <= '0';
      
   end process;

   seq : process (ethRxClk) is
   begin
      if (rising_edge(ethRxClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;   

end rtl;

