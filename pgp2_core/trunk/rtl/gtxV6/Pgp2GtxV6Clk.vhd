-------------------------------------------------------------------------------
-- Title         : Pretty Good Protocol, V2, Clock Generation Block
-- Project       : General Purpose Core
-------------------------------------------------------------------------------
-- File          : Pgp2GtxV6Clk.vhd
-- Author        : Ryan Herbst, rherbst@slac.stanford.edu
-- Created       : 08/08/2009
-------------------------------------------------------------------------------
-- Description:
-- PGP Clock Module. Contains DCM to support PGP clocking for GTP in Virtex5.
-- Used to generate global buffer clocks at the PGP interface rate and the 2X
-- clock required for the internal GTP logic.
-- Will also generate an optional user global clock and reset for external 
-- logic use.
-------------------------------------------------------------------------------
-- Copyright (c) 2006 by Ryan Herbst. All rights reserved.
-------------------------------------------------------------------------------
-- Modification history:
-- 08/08/2009: created.
-------------------------------------------------------------------------------

LIBRARY ieee;
use work.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use work.Pgp2GtxV6Package.all;
Library UNISIM;
use UNISIM.VCOMPONENTS.ALL;

entity Pgp2GtxV6Clk is 
   generic (
      UserFxDiv  : integer := 5; -- DCM FX Output Divide
      UserFxMult : integer := 4  -- DCM FX Output Divide, 4/5 * 156.25 = 125Mhz
   );
   port (

      -- Reference Clock Input. 
      -- This is provided as an output from the GTP tile.
      pgpRefClk     : in  std_logic;

      -- Power On Reset Input
      ponResetL     : in  std_logic;

      -- Locally Generated Reset
      locReset      : in  std_logic;

      -- Global Clock & Reset For PGP Logic, 156.25Mhz
      pgpClk        : out std_logic;
      pgpReset      : out std_logic;

      -- 2x clock required by the GTP internal logic
      pgpClk2x      : out std_logic;

      -- Global Clock & Reset For User Logic
      userClk       : out std_logic;
      userReset     : out std_logic;

      -- Inputs clocks for reset generation connect
      -- to pgpClk and userClk
      pgpClkIn      : in  std_logic;
      userClkIn     : in  std_logic
   );

end Pgp2GtxV6Clk;


-- Define architecture
architecture Pgp2GtxV6Clk of Pgp2GtxV6Clk is

   -- Local Signals
   signal ponReset     : std_logic;
   signal tmpPgpClk    : std_logic;
   signal intPgpClk    : std_logic;
   signal intPgpClk_out : std_logic;
   signal tmpPgpClk2x  : std_logic;
   signal intPgpClk2x  : std_logic;
   signal intPgpRst    : std_logic;
   signal tmpLocClk    : std_logic;
   signal intUsrClk    : std_logic;
   signal intUsrRst    : std_logic;
   signal syncPgpRstIn : std_logic_vector(2 downto 0);
   signal pgpRstCnt    : std_logic_vector(3 downto 0);
   signal syncLocRstIn : std_logic_vector(2 downto 0);
   signal locRstCnt    : std_logic_vector(3 downto 0);
   signal dcmLock      : std_logic;
   signal resetIn      : std_logic;
   signal s6fb_out     : std_logic;
   signal s6fb         : std_logic;
   signal v6fb_out     : std_logic;
   signal v6fb         : std_logic;



   signal intUsrClkt      : std_logic;
   signal intPgpClk2xt      : std_logic;
   signal intPgpClkt      : std_logic;
   signal pgpRefClkt      : std_logic;
   signal pgpRefClkb      : std_logic;

   -- Register delay for simulation
   constant tpd:time := 0.5 ns;

begin

   -- Output Generated Clock And Reset Signals
   pgpClk     <= intPgpClk;
   pgpClk2x   <= intPgpClk2x;
   pgpReset   <= intPgpRst;
   userClk    <= intUsrClk;
   userReset  <= intUsrRst;

   -- Invert power on reset
   ponReset <= not ponResetL;

 -- Clocking primitive
  --------------------------------------
  
  -- Instantiation of the DCM primitive
  --    * Unused inputs are tied off
  --    * Unused outputs are labeled unused
  
    mmcm_adv_i  : MMCM_ADV
    generic map
    (
         COMPENSATION     =>  "ZHOLD",
         CLKFBOUT_MULT_F  =>  15.0,
         DIVCLK_DIVIDE    =>  1,
         CLKFBOUT_PHASE   =>  0.0, 
         CLKIN1_PERIOD    =>  16.0,          --62.6MHz
         CLKIN2_PERIOD    =>  10.0,          -- Not used
         CLKOUT0_DIVIDE_F =>  7.5,
         CLKOUT0_PHASE    =>  0.0,
         CLKOUT1_DIVIDE   =>  6,
         CLKOUT1_PHASE    =>  0.0,
         CLKOUT2_DIVIDE   =>  1,
         CLKOUT2_PHASE    =>  0.0,
         CLKOUT3_DIVIDE   =>  1,
         CLKOUT3_PHASE    =>  0.0,
         CLOCK_HOLD       =>  TRUE         
    )
    port map
    (
         CLKIN1          =>  pgpRefClk,
         CLKIN2          =>  '0',
         CLKINSEL        =>  '1',
         CLKFBIN         =>  v6fb,
         CLKOUT0         =>  tmpLocClk,
         CLKOUT0B        =>  open,
         CLKOUT1         =>  tmpPgpClk,
         CLKOUT1B        =>  open,
         CLKOUT2         =>  open,
         CLKOUT2B        =>  open,
         CLKOUT3         =>  open,
         CLKOUT3B        =>  open,
         CLKOUT4         =>  open,
         CLKOUT5         =>  open,
         CLKOUT6         =>  open,
         CLKFBOUT        =>  v6fb_out,
         CLKFBOUTB       =>  open,
         CLKFBSTOPPED    =>  open,
         CLKINSTOPPED    =>  open,
         DO              =>  open,
         DRDY            =>  open,
         DADDR           =>  (Others => '0'),
         DCLK            =>  '0',
         DEN             =>  '0',
         DI              =>  (Others => '0'),
         DWE             =>  '0',
         LOCKED          =>  dcmLock,
         PSCLK           =>  '0',
         PSEN            =>  '0',        
         PSINCDEC        =>  '0', 
         PSDONE          =>  open,         
         PWRDWN          =>  '0',
         RST             =>  ponReset     
    );	 
	 
  clkf_bufv6 : BUFG
  port map
   (O => v6fb,
    I => v6fb_out);
  
   -- Global Buffer For PGP Clock
   U_PgpClkBuff: BUFG port map (
      O => intPgpClk,
      I => tmpPgpClk
   );


   -- Global Buffer For PGP 2x Clock
   U_PgpClk2xBuff: BUFG port map (
      O => intPgpClk2x,
      I => tmpPgpClk2x
   );


   -- Global Buffer For User Clock
   U_LocClkBuff: BUFG port map (
      O => intUsrClk,
      I => tmpLocClk
   );
 
   -- Generate reset input
   resetIn <= (not dcmLock) or ponReset or locReset;

   -- PGP Clock Synced Reset
   process ( pgpClkIn, resetIn ) begin
      if resetIn = '1' then
         syncPgpRstIn <= (others=>'0') after tpd;
         pgpRstCnt    <= (others=>'0') after tpd;
         intPgpRst    <= '1'           after tpd;
      elsif rising_edge(pgpClkIn) then

         -- Sync local reset, lock and power on reset to local clock
         -- Negative asserted signal
         syncPgpRstIn(0) <= '1'             after tpd;
         syncPgpRstIn(1) <= syncPgpRstIn(0) after tpd;
         syncPgpRstIn(2) <= syncPgpRstIn(1) after tpd;

         -- Reset counter on reset
         if syncPgpRstIn(2) = '0' then
            pgpRstCnt <= (others=>'0') after tpd;
            intPgpRst <= '1' after tpd;

         -- Count Up To Max Value
         elsif pgpRstCnt = "1111" then
            intPgpRst <= '0' after tpd;

         -- Increment counter
         else
            intPgpRst <= '1' after tpd;
            pgpRstCnt <= pgpRstCnt + 1 after tpd;
         end if;
      end if;
   end process;

   
   -- Local User Clock Synced Reset
   process ( userClkIn, resetIn ) begin
      if resetIn = '1' then
         syncLocRstIn <= (others=>'0') after tpd;
         locRstCnt    <= (others=>'0') after tpd;
         intUsrRst    <= '1'           after tpd;
      elsif rising_edge(userClkIn) then

         -- Sync local reset, lock and power on reset to local clock
         -- Negative asserted signal
         syncLocRstIn(0) <= '1'             after tpd;
         syncLocRstIn(1) <= syncLocRstIn(0) after tpd;
         syncLocRstIn(2) <= syncLocRstIn(1) after tpd;

         -- Reset counter on reset
         if syncLocRstIn(2) = '0' then
            locRstCnt <= (others=>'0') after tpd;
            intUsrRst <= '1' after tpd;

         -- Count Up To Max Value
         elsif locRstCnt = "1111" then
            intUsrRst <= '0' after tpd;

         -- Increment counter
         else
            intUsrRst <= '1' after tpd;
            locRstCnt <= locRstCnt + 1 after tpd;
         end if;
      end if;
   end process;

end Pgp2GtxV6Clk;

