-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Rogue Side Band Simulation Module
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

entity RogueSideBand is
   port (
      clock   : in std_logic;
      reset   : in std_logic;
      portNum : in std_logic_vector(15 downto 0);

      txOpCode   : in  std_logic_vector(7 downto 0);
      txOpCodeEn : in  std_logic;
      txRemData  : in  std_logic_vector(7 downto 0);
      rxOpCode   : out std_logic_vector(7 downto 0);
      rxOpCodeEn : out std_logic;
      rxRemData  : out std_logic_vector(7 downto 0));
end RogueSideBand;

-- Define architecture
architecture RogueSideBand of RogueSideBand is

------------------------------------------------------------------------
-- GHDL lacks the AxiSim VHPI interface, so this fork binds the C model
-- via VHPIDIRECT (below) instead. VHPI original:
-- axi/simlink/vcs/RogueSideBand.vhd
------------------------------------------------------------------------

   -- GHDL foreign function return types must be a plain type mark, not an
   -- inline-constrained subtype indication.
   subtype Word8 is std_logic_vector(7 downto 0);

   impure function rogueSideBandCreate return integer;
   attribute foreign of rogueSideBandCreate : function is
      "VHPIDIRECT libRogueSideBand.so rogueSideBandCreate";

   impure function rogueSideBandCreate return integer is
   begin
      assert false report "rogueSideBandCreate: VHPIDIRECT stub body should never execute" severity failure;
      return 0;
   end function rogueSideBandCreate;

   -- Per-edge update procedure: all "in" parameters, called every
   -- rising_edge(clock). The C-side FSM (unchanged from RogueSideBand.c)
   -- decides internally whether to latch reset/port or move data.
   procedure rogueSideBandUpdate (
      handle     : integer;
      clkRst     : std_logic;
      portNum    : std_logic_vector(15 downto 0);
      txOpCode   : std_logic_vector(7 downto 0);
      txOpCodeEn : std_logic;
      txRemData  : std_logic_vector(7 downto 0));
   attribute foreign of rogueSideBandUpdate : procedure is
      "VHPIDIRECT libRogueSideBand.so rogueSideBandUpdate";

   procedure rogueSideBandUpdate (
      handle     : integer;
      clkRst     : std_logic;
      portNum    : std_logic_vector(15 downto 0);
      txOpCode   : std_logic_vector(7 downto 0);
      txOpCodeEn : std_logic;
      txRemData  : std_logic_vector(7 downto 0)) is
   begin
      -- Body is never executed once the foreign symbol resolves.
      assert false report "rogueSideBandUpdate: VHPIDIRECT stub body should never execute" severity failure;
   end procedure rogueSideBandUpdate;

   -- One handle-based getter per output port.
   impure function rogueSideBandGetRxOpCode (handle : integer) return Word8;
   attribute foreign of rogueSideBandGetRxOpCode : function is
      "VHPIDIRECT libRogueSideBand.so rogueSideBandGetRxOpCode";

   impure function rogueSideBandGetRxOpCode (handle : integer) return Word8 is
   begin
      assert false report "rogueSideBandGetRxOpCode: VHPIDIRECT stub body should never execute" severity failure;
      return (others => '0');
   end function rogueSideBandGetRxOpCode;

   impure function rogueSideBandGetRxOpCodeEn (handle : integer) return std_logic;
   attribute foreign of rogueSideBandGetRxOpCodeEn : function is
      "VHPIDIRECT libRogueSideBand.so rogueSideBandGetRxOpCodeEn";

   impure function rogueSideBandGetRxOpCodeEn (handle : integer) return std_logic is
   begin
      assert false report "rogueSideBandGetRxOpCodeEn: VHPIDIRECT stub body should never execute" severity failure;
      return '0';
   end function rogueSideBandGetRxOpCodeEn;

   impure function rogueSideBandGetRxRemData (handle : integer) return Word8;
   attribute foreign of rogueSideBandGetRxRemData : function is
      "VHPIDIRECT libRogueSideBand.so rogueSideBandGetRxRemData";

   impure function rogueSideBandGetRxRemData (handle : integer) return Word8 is
   begin
      assert false report "rogueSideBandGetRxRemData: VHPIDIRECT stub body should never execute" severity failure;
      return (others => '0');
   end function rogueSideBandGetRxRemData;

begin

   UpdateProc : process (clock) is
      variable handle : integer := 0;
   begin
      if rising_edge(clock) then
         if handle = 0 then
            handle := rogueSideBandCreate;
            assert handle > 0 report "rogueSideBandCreate returned an invalid handle" severity failure;
         end if;

         rogueSideBandUpdate(handle, reset, portNum, txOpCode, txOpCodeEn, txRemData);
         rxOpCode   <= rogueSideBandGetRxOpCode(handle);
         rxOpCodeEn <= rogueSideBandGetRxOpCodeEn(handle);
         rxRemData  <= rogueSideBandGetRxRemData(handle);
      end if;
   end process UpdateProc;

end RogueSideBand;
