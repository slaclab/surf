-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Multi-instance VHPIDIRECT Rogue test harness
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Firmware Standard Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the
-- top-level directory of this distribution and at:
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
-- No part of 'SLAC Firmware Standard Library', including this file,
-- may be copied, modified, propagated, or distributed except according to
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------
-- Test methodology:
-- - Instantiate four Stream and two each Memory and SideBand VHPIDIRECT models.
-- - Drive eight distinct port numbers while holding all model interfaces idle.
-- - Check from cocotb that every instance advances and drives resolved outputs.
-- This exercises per-instance handles, distinct ZMQ ownership, and simultaneous
-- loading of all three model shared objects in one GHDL elaboration.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity RogueVhpiDirectMultiTb is
   port (
      clock          : in  std_logic;
      reset          : in  std_logic;
      streamPort0    : in  std_logic_vector(15 downto 0);
      streamPort1    : in  std_logic_vector(15 downto 0);
      streamPort2    : in  std_logic_vector(15 downto 0);
      streamPort3    : in  std_logic_vector(15 downto 0);
      memoryPort0    : in  std_logic_vector(15 downto 0);
      memoryPort1    : in  std_logic_vector(15 downto 0);
      sideBandPort0  : in  std_logic_vector(15 downto 0);
      sideBandPort1  : in  std_logic_vector(15 downto 0);
      streamObValid0 : out std_logic;
      streamIbReady0 : out std_logic;
      streamObValid1 : out std_logic;
      streamIbReady1 : out std_logic;
      streamObValid2 : out std_logic;
      streamIbReady2 : out std_logic;
      streamObValid3 : out std_logic;
      streamIbReady3 : out std_logic;
      memoryArValid0 : out std_logic;
      memoryBReady0  : out std_logic;
      memoryArValid1 : out std_logic;
      memoryBReady1  : out std_logic;
      sideBandRxEn0  : out std_logic;
      sideBandRxEn1  : out std_logic);
end RogueVhpiDirectMultiTb;

architecture test of RogueVhpiDirectMultiTb is

begin

   U_STREAM_0 : entity work.RogueTcpStream
      port map (
         clock      => clock,             -- [in]
         reset      => reset,             -- [in]
         portNum    => streamPort0,       -- [in]
         ssi        => '0',               -- [in]
         obValid    => streamObValid0,    -- [out]
         obReady    => '0',               -- [in]
         obDataLow  => open,              -- [out]
         obDataHigh => open,              -- [out]
         obUserLow  => open,              -- [out]
         obUserHigh => open,              -- [out]
         obKeep     => open,              -- [out]
         obLast     => open,              -- [out]
         ibValid    => '0',               -- [in]
         ibReady    => streamIbReady0,    -- [out]
         ibDataLow  => (others => '0'),   -- [in]
         ibDataHigh => (others => '0'),   -- [in]
         ibUserLow  => (others => '0'),   -- [in]
         ibUserHigh => (others => '0'),   -- [in]
         ibKeep     => (others => '0'),   -- [in]
         ibLast     => '0');              -- [in]

   U_STREAM_1 : entity work.RogueTcpStream
      port map (
         clock      => clock,             -- [in]
         reset      => reset,             -- [in]
         portNum    => streamPort1,       -- [in]
         ssi        => '0',               -- [in]
         obValid    => streamObValid1,    -- [out]
         obReady    => '0',               -- [in]
         obDataLow  => open,              -- [out]
         obDataHigh => open,              -- [out]
         obUserLow  => open,              -- [out]
         obUserHigh => open,              -- [out]
         obKeep     => open,              -- [out]
         obLast     => open,              -- [out]
         ibValid    => '0',               -- [in]
         ibReady    => streamIbReady1,    -- [out]
         ibDataLow  => (others => '0'),   -- [in]
         ibDataHigh => (others => '0'),   -- [in]
         ibUserLow  => (others => '0'),   -- [in]
         ibUserHigh => (others => '0'),   -- [in]
         ibKeep     => (others => '0'),   -- [in]
         ibLast     => '0');              -- [in]

   U_STREAM_2 : entity work.RogueTcpStream
      port map (
         clock      => clock,             -- [in]
         reset      => reset,             -- [in]
         portNum    => streamPort2,       -- [in]
         ssi        => '0',               -- [in]
         obValid    => streamObValid2,    -- [out]
         obReady    => '0',               -- [in]
         obDataLow  => open,              -- [out]
         obDataHigh => open,              -- [out]
         obUserLow  => open,              -- [out]
         obUserHigh => open,              -- [out]
         obKeep     => open,              -- [out]
         obLast     => open,              -- [out]
         ibValid    => '0',               -- [in]
         ibReady    => streamIbReady2,    -- [out]
         ibDataLow  => (others => '0'),   -- [in]
         ibDataHigh => (others => '0'),   -- [in]
         ibUserLow  => (others => '0'),   -- [in]
         ibUserHigh => (others => '0'),   -- [in]
         ibKeep     => (others => '0'),   -- [in]
         ibLast     => '0');              -- [in]

   U_STREAM_3 : entity work.RogueTcpStream
      port map (
         clock      => clock,             -- [in]
         reset      => reset,             -- [in]
         portNum    => streamPort3,       -- [in]
         ssi        => '0',               -- [in]
         obValid    => streamObValid3,    -- [out]
         obReady    => '0',               -- [in]
         obDataLow  => open,              -- [out]
         obDataHigh => open,              -- [out]
         obUserLow  => open,              -- [out]
         obUserHigh => open,              -- [out]
         obKeep     => open,              -- [out]
         obLast     => open,              -- [out]
         ibValid    => '0',               -- [in]
         ibReady    => streamIbReady3,    -- [out]
         ibDataLow  => (others => '0'),   -- [in]
         ibDataHigh => (others => '0'),   -- [in]
         ibUserLow  => (others => '0'),   -- [in]
         ibUserHigh => (others => '0'),   -- [in]
         ibKeep     => (others => '0'),   -- [in]
         ibLast     => '0');              -- [in]

   U_MEMORY_0 : entity work.RogueTcpMemory
      port map (
         clock   => clock,                -- [in]
         reset   => reset,                -- [in]
         portNum => memoryPort0,          -- [in]
         araddr  => open,                 -- [out]
         arprot  => open,                 -- [out]
         arvalid => memoryArValid0,       -- [out]
         rready  => open,                 -- [out]
         arready => '0',                  -- [in]
         rdata   => (others => '0'),      -- [in]
         rresp   => (others => '0'),      -- [in]
         rvalid  => '0',                  -- [in]
         awaddr  => open,                 -- [out]
         awprot  => open,                 -- [out]
         awvalid => open,                 -- [out]
         wdata   => open,                 -- [out]
         wstrb   => open,                 -- [out]
         wvalid  => open,                 -- [out]
         bready  => memoryBReady0,        -- [out]
         awready => '0',                  -- [in]
         wready  => '0',                  -- [in]
         bresp   => (others => '0'),      -- [in]
         bvalid  => '0');                 -- [in]

   U_MEMORY_1 : entity work.RogueTcpMemory
      port map (
         clock   => clock,                -- [in]
         reset   => reset,                -- [in]
         portNum => memoryPort1,          -- [in]
         araddr  => open,                 -- [out]
         arprot  => open,                 -- [out]
         arvalid => memoryArValid1,       -- [out]
         rready  => open,                 -- [out]
         arready => '0',                  -- [in]
         rdata   => (others => '0'),      -- [in]
         rresp   => (others => '0'),      -- [in]
         rvalid  => '0',                  -- [in]
         awaddr  => open,                 -- [out]
         awprot  => open,                 -- [out]
         awvalid => open,                 -- [out]
         wdata   => open,                 -- [out]
         wstrb   => open,                 -- [out]
         wvalid  => open,                 -- [out]
         bready  => memoryBReady1,        -- [out]
         awready => '0',                  -- [in]
         wready  => '0',                  -- [in]
         bresp   => (others => '0'),      -- [in]
         bvalid  => '0');                 -- [in]

   U_SIDE_BAND_0 : entity work.RogueSideBand
      port map (
         clock      => clock,             -- [in]
         reset      => reset,             -- [in]
         portNum    => sideBandPort0,     -- [in]
         txOpCode   => (others => '0'),   -- [in]
         txOpCodeEn => '0',               -- [in]
         txRemData  => (others => '0'),   -- [in]
         rxOpCode   => open,              -- [out]
         rxOpCodeEn => sideBandRxEn0,     -- [out]
         rxRemData  => open);             -- [out]

   U_SIDE_BAND_1 : entity work.RogueSideBand
      port map (
         clock      => clock,             -- [in]
         reset      => reset,             -- [in]
         portNum    => sideBandPort1,     -- [in]
         txOpCode   => (others => '0'),   -- [in]
         txOpCodeEn => '0',               -- [in]
         txRemData  => (others => '0'),   -- [in]
         rxOpCode   => open,              -- [out]
         rxOpCodeEn => sideBandRxEn1,     -- [out]
         rxRemData  => open);             -- [out]

end test;
