-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Rogue Stream Module
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
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity RogueTcpStream is
   port (
      clock   : in std_logic;
      reset   : in std_logic;
      portNum : in std_logic_vector(15 downto 0);
      ssi     : in std_logic;

      obValid    : out std_logic;
      obReady    : in  std_logic;
      obDataLow  : out std_logic_vector(31 downto 0);
      obDataHigh : out std_logic_vector(31 downto 0);
      obUserLow  : out std_logic_vector(31 downto 0);
      obUserHigh : out std_logic_vector(31 downto 0);
      obKeep     : out std_logic_vector(7 downto 0);
      obLast     : out std_logic;

      ibValid    : in  std_logic;
      ibReady    : out std_logic;
      ibDataLow  : in  std_logic_vector(31 downto 0);
      ibDataHigh : in  std_logic_vector(31 downto 0);
      ibUserLow  : in  std_logic_vector(31 downto 0);
      ibUserHigh : in  std_logic_vector(31 downto 0);
      ibKeep     : in  std_logic_vector(7 downto 0);
      ibLast     : in  std_logic);
end RogueTcpStream;

-- Define architecture
architecture RogueTcpStream of RogueTcpStream is

------------------------------------------------------------------------
-- GHDL lacks the AxiSim VHPI interface, so this fork binds the C model
-- via VHPIDIRECT (below) instead. VHPI original:
-- axi/simlink/vcs/RogueTcpStream.vhd
------------------------------------------------------------------------

   -- GHDL foreign function return types must be a plain type mark, not an
   -- inline-constrained subtype indication.
   subtype Word32 is std_logic_vector(31 downto 0);
   subtype Word8 is std_logic_vector(7 downto 0);

   -- Per-edge update procedure: all "in" parameters, called every
   -- rising_edge(clock). The C-side FSM (unchanged from RogueTcpStream.c)
   -- decides internally whether to latch reset/port/ssi or move data.
   procedure rogueTcpStreamUpdate (
      clkRst     : std_logic;
      portNum    : std_logic_vector(15 downto 0);
      ssi        : std_logic;
      obReady    : std_logic;
      ibValid    : std_logic;
      ibDataLow  : std_logic_vector(31 downto 0);
      ibDataHigh : std_logic_vector(31 downto 0);
      ibUserLow  : std_logic_vector(31 downto 0);
      ibUserHigh : std_logic_vector(31 downto 0);
      ibKeep     : std_logic_vector(7 downto 0);
      ibLast     : std_logic);
   attribute foreign of rogueTcpStreamUpdate : procedure is
      "VHPIDIRECT libRogueTcpStream.so rogueTcpStreamUpdate";

   procedure rogueTcpStreamUpdate (
      clkRst     : std_logic;
      portNum    : std_logic_vector(15 downto 0);
      ssi        : std_logic;
      obReady    : std_logic;
      ibValid    : std_logic;
      ibDataLow  : std_logic_vector(31 downto 0);
      ibDataHigh : std_logic_vector(31 downto 0);
      ibUserLow  : std_logic_vector(31 downto 0);
      ibUserHigh : std_logic_vector(31 downto 0);
      ibKeep     : std_logic_vector(7 downto 0);
      ibLast     : std_logic) is
   begin
      -- Body is never executed once the foreign symbol resolves.
      assert false report "rogueTcpStreamUpdate: VHPIDIRECT stub body should never execute" severity failure;
   end procedure rogueTcpStreamUpdate;

   -- One zero-arg getter per output port.
   impure function rogueTcpStreamGetObValid return std_logic;
   attribute foreign of rogueTcpStreamGetObValid : function is
      "VHPIDIRECT libRogueTcpStream.so rogueTcpStreamGetObValid";

   impure function rogueTcpStreamGetObValid return std_logic is
   begin
      assert false report "rogueTcpStreamGetObValid: VHPIDIRECT stub body should never execute" severity failure;
      return '0';
   end function rogueTcpStreamGetObValid;

   impure function rogueTcpStreamGetObDataLow return Word32;
   attribute foreign of rogueTcpStreamGetObDataLow : function is
      "VHPIDIRECT libRogueTcpStream.so rogueTcpStreamGetObDataLow";

   impure function rogueTcpStreamGetObDataLow return Word32 is
   begin
      assert false report "rogueTcpStreamGetObDataLow: VHPIDIRECT stub body should never execute" severity failure;
      return (others => '0');
   end function rogueTcpStreamGetObDataLow;

   impure function rogueTcpStreamGetObDataHigh return Word32;
   attribute foreign of rogueTcpStreamGetObDataHigh : function is
      "VHPIDIRECT libRogueTcpStream.so rogueTcpStreamGetObDataHigh";

   impure function rogueTcpStreamGetObDataHigh return Word32 is
   begin
      assert false report "rogueTcpStreamGetObDataHigh: VHPIDIRECT stub body should never execute" severity failure;
      return (others => '0');
   end function rogueTcpStreamGetObDataHigh;

   impure function rogueTcpStreamGetObUserLow return Word32;
   attribute foreign of rogueTcpStreamGetObUserLow : function is
      "VHPIDIRECT libRogueTcpStream.so rogueTcpStreamGetObUserLow";

   impure function rogueTcpStreamGetObUserLow return Word32 is
   begin
      assert false report "rogueTcpStreamGetObUserLow: VHPIDIRECT stub body should never execute" severity failure;
      return (others => '0');
   end function rogueTcpStreamGetObUserLow;

   impure function rogueTcpStreamGetObUserHigh return Word32;
   attribute foreign of rogueTcpStreamGetObUserHigh : function is
      "VHPIDIRECT libRogueTcpStream.so rogueTcpStreamGetObUserHigh";

   impure function rogueTcpStreamGetObUserHigh return Word32 is
   begin
      assert false report "rogueTcpStreamGetObUserHigh: VHPIDIRECT stub body should never execute" severity failure;
      return (others => '0');
   end function rogueTcpStreamGetObUserHigh;

   impure function rogueTcpStreamGetObKeep return Word8;
   attribute foreign of rogueTcpStreamGetObKeep : function is
      "VHPIDIRECT libRogueTcpStream.so rogueTcpStreamGetObKeep";

   impure function rogueTcpStreamGetObKeep return Word8 is
   begin
      assert false report "rogueTcpStreamGetObKeep: VHPIDIRECT stub body should never execute" severity failure;
      return (others => '0');
   end function rogueTcpStreamGetObKeep;

   impure function rogueTcpStreamGetObLast return std_logic;
   attribute foreign of rogueTcpStreamGetObLast : function is
      "VHPIDIRECT libRogueTcpStream.so rogueTcpStreamGetObLast";

   impure function rogueTcpStreamGetObLast return std_logic is
   begin
      assert false report "rogueTcpStreamGetObLast: VHPIDIRECT stub body should never execute" severity failure;
      return '0';
   end function rogueTcpStreamGetObLast;

   impure function rogueTcpStreamGetIbReady return std_logic;
   attribute foreign of rogueTcpStreamGetIbReady : function is
      "VHPIDIRECT libRogueTcpStream.so rogueTcpStreamGetIbReady";

   impure function rogueTcpStreamGetIbReady return std_logic is
   begin
      assert false report "rogueTcpStreamGetIbReady: VHPIDIRECT stub body should never execute" severity failure;
      return '0';
   end function rogueTcpStreamGetIbReady;

begin

   UpdateProc : process (clock) is
   begin
      if rising_edge(clock) then
         rogueTcpStreamUpdate(reset, portNum, ssi, obReady, ibValid, ibDataLow, ibDataHigh, ibUserLow, ibUserHigh, ibKeep, ibLast);
         obValid    <= rogueTcpStreamGetObValid;
         obDataLow  <= rogueTcpStreamGetObDataLow;
         obDataHigh <= rogueTcpStreamGetObDataHigh;
         obUserLow  <= rogueTcpStreamGetObUserLow;
         obUserHigh <= rogueTcpStreamGetObUserHigh;
         obKeep     <= rogueTcpStreamGetObKeep;
         obLast     <= rogueTcpStreamGetObLast;
         ibReady    <= rogueTcpStreamGetIbReady;
      end if;
   end process UpdateProc;

end RogueTcpStream;
