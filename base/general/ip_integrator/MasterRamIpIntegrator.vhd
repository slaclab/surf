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

entity MasterRamIpIntegrator is
   generic (
      INTERFACENAME : string               := "M_RAM";
      READ_LATENCY  : natural range 0 to 3 := 1;
      ADDR_WIDTH    : positive             := 5;
      DATA_WIDTH    : positive             := 32);
   port (
      -- IP Integrator RAM Interface
      M_RAM_CLK  : out std_logic;
      M_RAM_EN   : out std_logic;
      M_RAM_WE   : out std_logic_vector((DATA_WIDTH/8)-1 downto 0);
      M_RAM_RST  : out std_logic;
      M_RAM_ADDR : out std_logic_vector(ADDR_WIDTH-1 downto 0);
      M_RAM_DIN  : out std_logic_vector(DATA_WIDTH-1 downto 0);
      M_RAM_DOUT : in  std_logic_vector(DATA_WIDTH-1 downto 0)     := (others => '0');
      -- SURF RAM Interface
      clk        : in  std_logic                                   := '0';
      en         : in  std_logic                                   := '1';
      we         : in  std_logic_vector((DATA_WIDTH/8)-1 downto 0) := (others => '0');
      rst        : in  std_logic                                   := '0';
      addr       : in  std_logic_vector(ADDR_WIDTH-1 downto 0)     := (others => '0');
      din        : in  std_logic_vector(DATA_WIDTH-1 downto 0)     := (others => '0');
      dout       : out std_logic_vector(DATA_WIDTH-1 downto 0));
end MasterRamIpIntegrator;

architecture mapping of MasterRamIpIntegrator is

   attribute X_INTERFACE_INFO      : string;
   attribute X_INTERFACE_PARAMETER : string;

   attribute X_INTERFACE_INFO of M_RAM_CLK  : signal is "xilinx.com:interface:bram:1.0 " & INTERFACENAME & " CLK";
   attribute X_INTERFACE_INFO of M_RAM_EN   : signal is "xilinx.com:interface:bram:1.0 " & INTERFACENAME & " EN";
   attribute X_INTERFACE_INFO of M_RAM_WE   : signal is "xilinx.com:interface:bram:1.0 " & INTERFACENAME & " WE";
   attribute X_INTERFACE_INFO of M_RAM_RST  : signal is "xilinx.com:interface:bram:1.0 " & INTERFACENAME & " RST";
   attribute X_INTERFACE_INFO of M_RAM_ADDR : signal is "xilinx.com:interface:bram:1.0 " & INTERFACENAME & " ADDR";
   attribute X_INTERFACE_INFO of M_RAM_DIN  : signal is "xilinx.com:interface:bram:1.0 " & INTERFACENAME & " DIN";
   attribute X_INTERFACE_INFO of M_RAM_DOUT : signal is "xilinx.com:interface:bram:1.0 " & INTERFACENAME & " DOUT";

   attribute X_INTERFACE_PARAMETER of M_RAM_ADDR : signal is
      "XIL_INTERFACENAME " & INTERFACENAME & ", " &
      "MEM_SIZE " & integer'image(2**ADDR_WIDTH) & ", " &
      "MEM_WIDTH " & integer'image(DATA_WIDTH) & ", " &
      "MEM_ECC NONE, " &
      "MASTER_TYPE OTHER, " &
      "READ_LATENCY " & integer'image(READ_LATENCY);

begin

   assert (DATA_WIDTH mod 8 = 0) report "DATA_WIDTH must be a multiple of 8" severity failure;

   M_RAM_CLK  <= clk;
   M_RAM_EN   <= en;
   M_RAM_WE   <= we;
   M_RAM_RST  <= rst;
   M_RAM_ADDR <= addr;
   M_RAM_DIN  <= din;
   dout       <= M_RAM_DOUT;

end mapping;
