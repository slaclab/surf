-------------------------------------------------------------------------------
-- File       : SemWrapper.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2017-02-08
-- Last update: 2017-02-08
-------------------------------------------------------------------------------
-- Description: Wrapper for 7-series SEM module
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
use work.SemPkg.all;

library unisim;
use unisim.vcomponents.all;

entity SemWrapper is
   generic (
      TPD_G : time := 1 ns);
   port (
      -- Clock and Reset
      semClk         : in  sl;
      semRst         : in  sl;
      -- IPROG Interface
      fpgaReload     : in  sl               := '0';
      fpgaReloadAddr : in  slv(31 downto 0) := (others => '0');
      -- SEM Interface
      semIb          : in  SemIbType;
      semOb          : out SemObType);
end entity SemWrapper;

architecture mapping of SemWrapper is

   component SemCore
      port (
         status_heartbeat      : out std_logic;
         status_initialization : out std_logic;
         status_observation    : out std_logic;
         status_correction     : out std_logic;
         status_classification : out std_logic;
         status_injection      : out std_logic;
         status_essential      : out std_logic;
         status_uncorrectable  : out std_logic;
         monitor_txdata        : out std_logic_vector(7 downto 0);
         monitor_txwrite       : out std_logic;
         monitor_txfull        : in  std_logic;
         monitor_rxdata        : in  std_logic_vector(7 downto 0);
         monitor_rxread        : out std_logic;
         monitor_rxempty       : in  std_logic;
         inject_strobe         : in  std_logic;
         inject_address        : in  std_logic_vector(39 downto 0);
         icap_o                : in  std_logic_vector(31 downto 0);
         icap_csib             : out std_logic;
         icap_rdwrb            : out std_logic;
         icap_i                : out std_logic_vector(31 downto 0);
         icap_clk              : in  std_logic;
         icap_request          : out std_logic;
         icap_grant            : in  std_logic;
         fecc_crcerr           : in  std_logic;
         fecc_eccerr           : in  std_logic;
         fecc_eccerrsingle     : in  std_logic;
         fecc_syndromevalid    : in  std_logic;
         fecc_syndrome         : in  std_logic_vector(12 downto 0);
         fecc_far              : in  std_logic_vector(25 downto 0);
         fecc_synbit           : in  std_logic_vector(4 downto 0);
         fecc_synword          : in  std_logic_vector(6 downto 0));
   end component;

   signal fecc_crcerr        : sl;
   signal fecc_eccerr        : sl;
   signal fecc_eccerrsingle  : sl;
   signal fecc_syndromevalid : sl;
   signal fecc_syndrome      : slv(12 downto 0);
   signal fecc_far           : slv(25 downto 0);
   signal fecc_synbit        : slv(4 downto 0);
   signal fecc_synword       : slv(6 downto 0);

   signal icap_o : slv(31 downto 0);

   signal icap_i     : slv(31 downto 0);
   signal icap_csib  : sl;
   signal icap_rdwrb : sl;

   signal sem_icap_csib  : sl;
   signal sem_icap_rdwrb : sl;
   signal sem_icap_i     : slv(31 downto 0);

   signal iprogIcapReq   : sl;
   signal iprogIcapGrant : sl;
   signal iprogIcapCsl   : sl;
   signal iprogIcapRnw   : sl;
   signal iprogIcapI     : slv(31 downto 0);

begin

   U_FRAME_ECCE2 : FRAME_ECCE2
      generic map (
         FRAME_RBT_IN_FILENAME => "NONE",
         FARSRC                => "EFAR")
      port map (
         CRCERROR       => fecc_crcerr,
         ECCERROR       => fecc_eccerr,
         ECCERRORSINGLE => fecc_eccerrsingle,
         FAR            => fecc_far,
         SYNBIT         => fecc_synbit,
         SYNDROME       => fecc_syndrome,
         SYNDROMEVALID  => fecc_syndromevalid,
         SYNWORD        => fecc_synword);

   U_ICAPE2 : ICAPE2
      generic map (
         SIM_CFG_FILE_NAME => "NONE",
         DEVICE_ID         => X"FFFFFFFF",
         ICAP_WIDTH        => "X32")
      port map (
         O     => icap_o,
         CLK   => semClk,
         CSIB  => icap_csib,
         I     => icap_i,
         RDWRB => icap_rdwrb);

   U_IPROG : entity work.Iprog7SeriesCore
      generic map (
         TPD_G         => TPD_G,
         SYNC_RELOAD_G => true)
      port map (
         reload     => fpgaReload,
         reloadAddr => fpgaReloadAddr,
         icapClk    => semClk,
         icapClkRst => semRst,
         icapReq    => semOb.iprogIcapReq,
         icapGrant  => iprogIcapGrant,
         icapCsl    => iprogIcapCsl,
         icapRnw    => iprogIcapRnw,
         icapI      => iprogIcapI);

   icap_rdwrb <= iprogIcapRnw when (iprogIcapGrant = '1') else sem_icap_rdwrb;
   icap_csib  <= iprogIcapCsl when (iprogIcapGrant = '1') else sem_icap_csib;
   icap_i     <= iprogIcapI   when (iprogIcapGrant = '1') else sem_icap_i;

   U_SemCore : SemCore
      port map (
         -- Status Vector
         status_heartbeat      => semOb.heartbeat,
         status_initialization => semOb.initialization,
         status_observation    => semOb.observation,
         status_correction     => semOb.correction,
         status_classification => semOb.classification,
         status_injection      => semOb.injection,
         status_essential      => semOb.essential,
         status_uncorrectable  => semOb.uncorrectable,
         -- Byte Stream Interface
         monitor_txdata        => semOb.txData,
         monitor_txwrite       => semOb.txWrite,
         monitor_txfull        => semIb.txFull,
         monitor_rxdata        => semIb.rxData,
         monitor_rxread        => semOb.rxRead,
         monitor_rxempty       => semIb.rxEmpty,
         -- Test Injection Interface
         inject_strobe         => semIb.injectStrobe,
         inject_address        => semIb.injectAddress,
         -- ICAPE2 Interface
         icap_o                => icap_o,
         icap_csib             => sem_icap_csib,
         icap_rdwrb            => sem_icap_rdwrb,
         icap_i                => sem_icap_i,
         icap_clk              => semClk,
         icap_request          => open,
         icap_grant            => '1',
         -- FRAME_ECCE2 Interface
         fecc_crcerr           => fecc_crcerr,
         fecc_eccerr           => fecc_eccerr,
         fecc_eccerrsingle     => fecc_eccerrsingle,
         fecc_syndromevalid    => fecc_syndromevalid,
         fecc_syndrome         => fecc_syndrome,
         fecc_far              => fecc_far,
         fecc_synbit           => fecc_synbit,
         fecc_synword          => fecc_synword);

end mapping;
