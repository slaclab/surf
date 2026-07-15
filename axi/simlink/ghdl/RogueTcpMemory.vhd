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

entity RogueTcpMemory is
   port (
      clock   : in std_logic;
      reset   : in std_logic;
      portNum : in std_logic_vector(15 downto 0);

      -- axiReadMaster
      araddr  : out std_logic_vector(31 downto 0);
      arprot  : out std_logic_vector(2 downto 0);
      arvalid : out std_logic;
      rready  : out std_logic;

      -- axiReadSlave
      arready : in std_logic;
      rdata   : in std_logic_vector(31 downto 0);
      rresp   : in std_logic_vector(1 downto 0);
      rvalid  : in std_logic;

      -- axiWriteMaster
      awaddr  : out std_logic_vector(31 downto 0);
      awprot  : out std_logic_vector(2 downto 0);
      awvalid : out std_logic;
      wdata   : out std_logic_vector(31 downto 0);
      wstrb   : out std_logic_vector(3 downto 0);
      wvalid  : out std_logic;
      bready  : out std_logic;

      -- axiWriteSlave
      awready : in std_logic;
      wready  : in std_logic;
      bresp   : in std_logic_vector(1 downto 0);
      bvalid  : in std_logic);
end RogueTcpMemory;

-- Define architecture
architecture RogueTcpMemory of RogueTcpMemory is

------------------------------------------------------------------------
-- GHDL lacks the AxiSim VHPI interface, so this fork binds the C model
-- via VHPIDIRECT (below) instead. VHPI original:
-- axi/simlink/vcs/RogueTcpMemory.vhd
------------------------------------------------------------------------

   -- GHDL foreign function return types must be a plain type mark, not an
   -- inline-constrained subtype indication.
   subtype Word32 is std_logic_vector(31 downto 0);
   subtype Word4 is std_logic_vector(3 downto 0);
   subtype Word3 is std_logic_vector(2 downto 0);

   impure function rogueTcpMemoryCreate return integer;
   attribute foreign of rogueTcpMemoryCreate : function is
      "VHPIDIRECT libRogueTcpMemory.so rogueTcpMemoryCreate";

   impure function rogueTcpMemoryCreate return integer is
   begin
      assert false report "rogueTcpMemoryCreate: VHPIDIRECT stub body should never execute" severity failure;
      return 0;
   end function rogueTcpMemoryCreate;

   -- Per-edge update procedure: all "in" parameters, called every
   -- rising_edge(clock). The C-side FSM (unchanged from RogueTcpMemory.c)
   -- decides internally whether to latch reset/port or run the AXI-Lite
   -- transaction FSM.
   procedure rogueTcpMemoryUpdate (
      handle  : integer;
      clkRst  : std_logic;
      portNum : std_logic_vector(15 downto 0);
      arready : std_logic;
      rdata   : std_logic_vector(31 downto 0);
      rresp   : std_logic_vector(1 downto 0);
      rvalid  : std_logic;
      awready : std_logic;
      wready  : std_logic;
      bresp   : std_logic_vector(1 downto 0);
      bvalid  : std_logic);
   attribute foreign of rogueTcpMemoryUpdate : procedure is
      "VHPIDIRECT libRogueTcpMemory.so rogueTcpMemoryUpdate";

   procedure rogueTcpMemoryUpdate (
      handle  : integer;
      clkRst  : std_logic;
      portNum : std_logic_vector(15 downto 0);
      arready : std_logic;
      rdata   : std_logic_vector(31 downto 0);
      rresp   : std_logic_vector(1 downto 0);
      rvalid  : std_logic;
      awready : std_logic;
      wready  : std_logic;
      bresp   : std_logic_vector(1 downto 0);
      bvalid  : std_logic) is
   begin
      -- Body is never executed once the foreign symbol resolves.
      assert false report "rogueTcpMemoryUpdate: VHPIDIRECT stub body should never execute" severity failure;
   end procedure rogueTcpMemoryUpdate;

   -- One handle-based getter per output port.
   impure function rogueTcpMemoryGetAraddr (handle : integer) return Word32;
   attribute foreign of rogueTcpMemoryGetAraddr : function is
      "VHPIDIRECT libRogueTcpMemory.so rogueTcpMemoryGetAraddr";

   impure function rogueTcpMemoryGetAraddr (handle : integer) return Word32 is
   begin
      assert false report "rogueTcpMemoryGetAraddr: VHPIDIRECT stub body should never execute" severity failure;
      return (others => '0');
   end function rogueTcpMemoryGetAraddr;

   impure function rogueTcpMemoryGetArprot (handle : integer) return Word3;
   attribute foreign of rogueTcpMemoryGetArprot : function is
      "VHPIDIRECT libRogueTcpMemory.so rogueTcpMemoryGetArprot";

   impure function rogueTcpMemoryGetArprot (handle : integer) return Word3 is
   begin
      assert false report "rogueTcpMemoryGetArprot: VHPIDIRECT stub body should never execute" severity failure;
      return (others => '0');
   end function rogueTcpMemoryGetArprot;

   impure function rogueTcpMemoryGetArvalid (handle : integer) return std_logic;
   attribute foreign of rogueTcpMemoryGetArvalid : function is
      "VHPIDIRECT libRogueTcpMemory.so rogueTcpMemoryGetArvalid";

   impure function rogueTcpMemoryGetArvalid (handle : integer) return std_logic is
   begin
      assert false report "rogueTcpMemoryGetArvalid: VHPIDIRECT stub body should never execute" severity failure;
      return '0';
   end function rogueTcpMemoryGetArvalid;

   impure function rogueTcpMemoryGetRready (handle : integer) return std_logic;
   attribute foreign of rogueTcpMemoryGetRready : function is
      "VHPIDIRECT libRogueTcpMemory.so rogueTcpMemoryGetRready";

   impure function rogueTcpMemoryGetRready (handle : integer) return std_logic is
   begin
      assert false report "rogueTcpMemoryGetRready: VHPIDIRECT stub body should never execute" severity failure;
      return '0';
   end function rogueTcpMemoryGetRready;

   impure function rogueTcpMemoryGetAwaddr (handle : integer) return Word32;
   attribute foreign of rogueTcpMemoryGetAwaddr : function is
      "VHPIDIRECT libRogueTcpMemory.so rogueTcpMemoryGetAwaddr";

   impure function rogueTcpMemoryGetAwaddr (handle : integer) return Word32 is
   begin
      assert false report "rogueTcpMemoryGetAwaddr: VHPIDIRECT stub body should never execute" severity failure;
      return (others => '0');
   end function rogueTcpMemoryGetAwaddr;

   impure function rogueTcpMemoryGetAwprot (handle : integer) return Word3;
   attribute foreign of rogueTcpMemoryGetAwprot : function is
      "VHPIDIRECT libRogueTcpMemory.so rogueTcpMemoryGetAwprot";

   impure function rogueTcpMemoryGetAwprot (handle : integer) return Word3 is
   begin
      assert false report "rogueTcpMemoryGetAwprot: VHPIDIRECT stub body should never execute" severity failure;
      return (others => '0');
   end function rogueTcpMemoryGetAwprot;

   impure function rogueTcpMemoryGetAwvalid (handle : integer) return std_logic;
   attribute foreign of rogueTcpMemoryGetAwvalid : function is
      "VHPIDIRECT libRogueTcpMemory.so rogueTcpMemoryGetAwvalid";

   impure function rogueTcpMemoryGetAwvalid (handle : integer) return std_logic is
   begin
      assert false report "rogueTcpMemoryGetAwvalid: VHPIDIRECT stub body should never execute" severity failure;
      return '0';
   end function rogueTcpMemoryGetAwvalid;

   impure function rogueTcpMemoryGetWdata (handle : integer) return Word32;
   attribute foreign of rogueTcpMemoryGetWdata : function is
      "VHPIDIRECT libRogueTcpMemory.so rogueTcpMemoryGetWdata";

   impure function rogueTcpMemoryGetWdata (handle : integer) return Word32 is
   begin
      assert false report "rogueTcpMemoryGetWdata: VHPIDIRECT stub body should never execute" severity failure;
      return (others => '0');
   end function rogueTcpMemoryGetWdata;

   impure function rogueTcpMemoryGetWstrb (handle : integer) return Word4;
   attribute foreign of rogueTcpMemoryGetWstrb : function is
      "VHPIDIRECT libRogueTcpMemory.so rogueTcpMemoryGetWstrb";

   impure function rogueTcpMemoryGetWstrb (handle : integer) return Word4 is
   begin
      assert false report "rogueTcpMemoryGetWstrb: VHPIDIRECT stub body should never execute" severity failure;
      return (others => '0');
   end function rogueTcpMemoryGetWstrb;

   impure function rogueTcpMemoryGetWvalid (handle : integer) return std_logic;
   attribute foreign of rogueTcpMemoryGetWvalid : function is
      "VHPIDIRECT libRogueTcpMemory.so rogueTcpMemoryGetWvalid";

   impure function rogueTcpMemoryGetWvalid (handle : integer) return std_logic is
   begin
      assert false report "rogueTcpMemoryGetWvalid: VHPIDIRECT stub body should never execute" severity failure;
      return '0';
   end function rogueTcpMemoryGetWvalid;

   impure function rogueTcpMemoryGetBready (handle : integer) return std_logic;
   attribute foreign of rogueTcpMemoryGetBready : function is
      "VHPIDIRECT libRogueTcpMemory.so rogueTcpMemoryGetBready";

   impure function rogueTcpMemoryGetBready (handle : integer) return std_logic is
   begin
      assert false report "rogueTcpMemoryGetBready: VHPIDIRECT stub body should never execute" severity failure;
      return '0';
   end function rogueTcpMemoryGetBready;

begin

   UpdateProc : process (clock) is
      variable handle : integer := 0;
   begin
      if rising_edge(clock) then
         if handle = 0 then
            handle := rogueTcpMemoryCreate;
            assert handle > 0 report "rogueTcpMemoryCreate returned an invalid handle" severity failure;
         end if;

         rogueTcpMemoryUpdate(handle, reset, portNum, arready, rdata, rresp, rvalid, awready, wready, bresp, bvalid);
         araddr  <= rogueTcpMemoryGetAraddr(handle);
         arprot  <= rogueTcpMemoryGetArprot(handle);
         arvalid <= rogueTcpMemoryGetArvalid(handle);
         rready  <= rogueTcpMemoryGetRready(handle);
         awaddr  <= rogueTcpMemoryGetAwaddr(handle);
         awprot  <= rogueTcpMemoryGetAwprot(handle);
         awvalid <= rogueTcpMemoryGetAwvalid(handle);
         wdata   <= rogueTcpMemoryGetWdata(handle);
         wstrb   <= rogueTcpMemoryGetWstrb(handle);
         wvalid  <= rogueTcpMemoryGetWvalid(handle);
         bready  <= rogueTcpMemoryGetBready(handle);
      end if;
   end process UpdateProc;

end RogueTcpMemory;
