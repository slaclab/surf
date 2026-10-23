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

entity RogueTcpStream is
   generic (
      TDATA_BYTES_G : positive range 1 to 128 := 8);
   port (
      clock   : in std_logic;
      reset   : in std_logic;
      portNum : in std_logic_vector(15 downto 0);
      ssi     : in std_logic;

      obValid : out std_logic;
      obReady : in  std_logic;
      obData  : out std_logic_vector((TDATA_BYTES_G*8)-1 downto 0);
      obUser  : out std_logic_vector((TDATA_BYTES_G*8)-1 downto 0);
      obKeep  : out std_logic_vector(TDATA_BYTES_G-1 downto 0);
      obLast  : out std_logic;

      ibValid : in  std_logic;
      ibReady : out std_logic;
      ibData  : in  std_logic_vector((TDATA_BYTES_G*8)-1 downto 0);
      ibUser  : in  std_logic_vector((TDATA_BYTES_G*8)-1 downto 0);
      ibKeep  : in  std_logic_vector(TDATA_BYTES_G-1 downto 0);
      ibLast  : in  std_logic);
end RogueTcpStream;

architecture RogueTcpStream of RogueTcpStream is

   subtype DataVector is std_logic_vector((TDATA_BYTES_G*8)-1 downto 0);
   subtype KeepVector is std_logic_vector(TDATA_BYTES_G-1 downto 0);

   impure function rogueTcpStreamCreate return integer;
   attribute foreign of rogueTcpStreamCreate : function is
      "VHPIDIRECT libRogueSimLinkVhpiDirect.so rogueTcpStreamCreate";
   impure function rogueTcpStreamCreate return integer is
   begin
      assert false report "rogueTcpStreamCreate: VHPIDIRECT stub body should never execute" severity failure;
      return 0;
   end function rogueTcpStreamCreate;

   procedure rogueTcpStreamUpdate (
      handle    : integer;
      dataBytes : integer;
      clkRst    : std_logic;
      portNum   : std_logic_vector(15 downto 0);
      ssi       : std_logic;
      obReady   : std_logic;
      ibValid   : std_logic;
      ibData    : DataVector;
      ibUser    : DataVector;
      ibKeep    : KeepVector;
      ibLast    : std_logic);
   attribute foreign of rogueTcpStreamUpdate : procedure is
      "VHPIDIRECT libRogueSimLinkVhpiDirect.so rogueTcpStreamUpdate";
   procedure rogueTcpStreamUpdate (
      handle    : integer;
      dataBytes : integer;
      clkRst    : std_logic;
      portNum   : std_logic_vector(15 downto 0);
      ssi       : std_logic;
      obReady   : std_logic;
      ibValid   : std_logic;
      ibData    : DataVector;
      ibUser    : DataVector;
      ibKeep    : KeepVector;
      ibLast    : std_logic) is
   begin
      assert false report "rogueTcpStreamUpdate: VHPIDIRECT stub body should never execute" severity failure;
   end procedure rogueTcpStreamUpdate;

   impure function rogueTcpStreamGetObValid (handle : integer) return std_logic;
   attribute foreign of rogueTcpStreamGetObValid : function is
      "VHPIDIRECT libRogueSimLinkVhpiDirect.so rogueTcpStreamGetObValid";
   impure function rogueTcpStreamGetObValid (handle : integer) return std_logic is
   begin
      assert false report "rogueTcpStreamGetObValid: VHPIDIRECT stub body should never execute" severity failure;
      return '0';
   end function rogueTcpStreamGetObValid;

   impure function rogueTcpStreamGetObData (handle : integer) return DataVector;
   attribute foreign of rogueTcpStreamGetObData : function is
      "VHPIDIRECT libRogueSimLinkVhpiDirect.so rogueTcpStreamGetObData";
   impure function rogueTcpStreamGetObData (handle : integer) return DataVector is
   begin
      assert false report "rogueTcpStreamGetObData: VHPIDIRECT stub body should never execute" severity failure;
      return (others => '0');
   end function rogueTcpStreamGetObData;

   impure function rogueTcpStreamGetObUser (handle : integer) return DataVector;
   attribute foreign of rogueTcpStreamGetObUser : function is
      "VHPIDIRECT libRogueSimLinkVhpiDirect.so rogueTcpStreamGetObUser";
   impure function rogueTcpStreamGetObUser (handle : integer) return DataVector is
   begin
      assert false report "rogueTcpStreamGetObUser: VHPIDIRECT stub body should never execute" severity failure;
      return (others => '0');
   end function rogueTcpStreamGetObUser;

   impure function rogueTcpStreamGetObKeep (handle : integer) return KeepVector;
   attribute foreign of rogueTcpStreamGetObKeep : function is
      "VHPIDIRECT libRogueSimLinkVhpiDirect.so rogueTcpStreamGetObKeep";
   impure function rogueTcpStreamGetObKeep (handle : integer) return KeepVector is
   begin
      assert false report "rogueTcpStreamGetObKeep: VHPIDIRECT stub body should never execute" severity failure;
      return (others => '0');
   end function rogueTcpStreamGetObKeep;

   impure function rogueTcpStreamGetObLast (handle : integer) return std_logic;
   attribute foreign of rogueTcpStreamGetObLast : function is
      "VHPIDIRECT libRogueSimLinkVhpiDirect.so rogueTcpStreamGetObLast";
   impure function rogueTcpStreamGetObLast (handle : integer) return std_logic is
   begin
      assert false report "rogueTcpStreamGetObLast: VHPIDIRECT stub body should never execute" severity failure;
      return '0';
   end function rogueTcpStreamGetObLast;

   impure function rogueTcpStreamGetIbReady (handle : integer) return std_logic;
   attribute foreign of rogueTcpStreamGetIbReady : function is
      "VHPIDIRECT libRogueSimLinkVhpiDirect.so rogueTcpStreamGetIbReady";
   impure function rogueTcpStreamGetIbReady (handle : integer) return std_logic is
   begin
      assert false report "rogueTcpStreamGetIbReady: VHPIDIRECT stub body should never execute" severity failure;
      return '0';
   end function rogueTcpStreamGetIbReady;

begin

   UpdateProc : process (clock) is
      variable handle : integer := 0;
   begin
      if rising_edge(clock) then
         if handle = 0 then
            handle := rogueTcpStreamCreate;
            assert handle > 0 report "rogueTcpStreamCreate returned an invalid handle" severity failure;
         end if;

         rogueTcpStreamUpdate(handle, TDATA_BYTES_G, reset, portNum, ssi,
                              obReady, ibValid, ibData, ibUser, ibKeep, ibLast);
         obValid <= rogueTcpStreamGetObValid(handle);
         obData  <= rogueTcpStreamGetObData(handle);
         obUser  <= rogueTcpStreamGetObUser(handle);
         obKeep  <= rogueTcpStreamGetObKeep(handle);
         obLast  <= rogueTcpStreamGetObLast(handle);
         ibReady <= rogueTcpStreamGetIbReady(handle);
      end if;
   end process UpdateProc;

end RogueTcpStream;
