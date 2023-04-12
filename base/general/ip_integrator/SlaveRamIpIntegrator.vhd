-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Common shim layer between IP Integrator interface and surf RAM interface
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

entity SlaveRamIpIntegrator is
   generic (
      INTERFACENAME : string               := "S_RAM";
      READ_LATENCY  : natural range 0 to 3 := 1;
      ADDR_WIDTH    : positive             := 5;
      DATA_WIDTH    : positive             := 32);
   port (
      -- IP Integrator RAM Interface
      S_RAM_CLK  : in  std_logic                                   := '0';
      S_RAM_EN   : in  std_logic                                   := '1';
      S_RAM_WE   : in  std_logic_vector((DATA_WIDTH/8)-1 downto 0) := (others => '0');
      S_RAM_RST  : in  std_logic                                   := '0';
      S_RAM_ADDR : in  std_logic_vector(ADDR_WIDTH-1 downto 0)     := (others => '0');
      S_RAM_DIN  : in  std_logic_vector(DATA_WIDTH-1 downto 0)     := (others => '0');
      S_RAM_DOUT : out std_logic_vector(DATA_WIDTH-1 downto 0);
      -- SURF RAM Interface
      clk        : out std_logic;
      en         : out std_logic;
      we         : out std_logic_vector((DATA_WIDTH/8)-1 downto 0);
      rst        : out std_logic;
      addr       : out std_logic_vector(ADDR_WIDTH-1 downto 0);
      din        : out std_logic_vector(DATA_WIDTH-1 downto 0);
      dout       : in  std_logic_vector(DATA_WIDTH-1 downto 0)     := (others => '0'));
end SlaveRamIpIntegrator;

architecture mapping of SlaveRamIpIntegrator is

   attribute X_INTERFACE_INFO      : string;
   attribute X_INTERFACE_PARAMETER : string;

   attribute X_INTERFACE_INFO of S_RAM_CLK  : signal is "xilinx.com:interface:bram:1.0 " & INTERFACENAME & " CLK";
   attribute X_INTERFACE_INFO of S_RAM_EN   : signal is "xilinx.com:interface:bram:1.0 " & INTERFACENAME & " EN";
   attribute X_INTERFACE_INFO of S_RAM_WE   : signal is "xilinx.com:interface:bram:1.0 " & INTERFACENAME & " WE";
   attribute X_INTERFACE_INFO of S_RAM_RST  : signal is "xilinx.com:interface:bram:1.0 " & INTERFACENAME & " RST";
   attribute X_INTERFACE_INFO of S_RAM_ADDR : signal is "xilinx.com:interface:bram:1.0 " & INTERFACENAME & " ADDR";
   attribute X_INTERFACE_INFO of S_RAM_DIN  : signal is "xilinx.com:interface:bram:1.0 " & INTERFACENAME & " DIN";
   attribute X_INTERFACE_INFO of S_RAM_DOUT : signal is "xilinx.com:interface:bram:1.0 " & INTERFACENAME & " DOUT";

   attribute X_INTERFACE_PARAMETER of S_RAM_ADDR : signal is
      "XIL_INTERFACENAME " & INTERFACENAME & ", " &
      "MEM_SIZE " & integer'image(2**ADDR_WIDTH) & ", " &
      "MEM_WIDTH " & integer'image(DATA_WIDTH) & ", " &
      "MEM_ECC NONE, " &
      "MASTER_TYPE OTHER, " &
      "READ_LATENCY " & integer'image(READ_LATENCY);

begin

   assert (DATA_WIDTH mod 8 = 0) report "DATA_WIDTH must be a multiple of 8" severity failure;

   clk        <= S_RAM_CLK;
   en         <= S_RAM_EN;
   we         <= S_RAM_WE;
   rst        <= S_RAM_RST;
   addr       <= S_RAM_ADDR;
   din        <= S_RAM_DIN;
   S_RAM_DOUT <= dout;

end mapping;
