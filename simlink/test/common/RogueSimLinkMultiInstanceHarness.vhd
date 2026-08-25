-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Backend-neutral GHDL/VCS multi-instance SimLink test harness
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
-- - Instantiate four Stream and two each Memory and SideBand VHPI models.
-- - Drive tagged traffic through every instance and check it returns only on
--   the matching flattened interface and ZeroMQ endpoint.
-- This exercises per-instance handles, distinct ZMQ ownership, and simultaneous
-- loading all three models in one GHDL or VCS elaboration.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity RogueSimLinkMultiInstanceHarness is
   port (
      clock          : in  std_logic;
      reset          : in  std_logic;
      streamPort0    : in  std_logic_vector(15 downto 0);
      streamPort1    : in  std_logic_vector(15 downto 0);
      streamPort2    : in  std_logic_vector(15 downto 0);
      streamPort3    : in  std_logic_vector(15 downto 0);
      streamObReady  : in  std_logic_vector(3 downto 0);
      streamObData   : out std_logic_vector(255 downto 0);
      streamObKeep   : out std_logic_vector(31 downto 0);
      streamObLast   : out std_logic_vector(3 downto 0);
      streamIbValid  : in  std_logic_vector(3 downto 0);
      streamIbData   : in  std_logic_vector(255 downto 0);
      streamIbKeep   : in  std_logic_vector(31 downto 0);
      streamIbLast   : in  std_logic_vector(3 downto 0);
      memoryPort0    : in  std_logic_vector(15 downto 0);
      memoryPort1    : in  std_logic_vector(15 downto 0);
      memoryArAddr   : out std_logic_vector(63 downto 0);
      memoryArReady  : in  std_logic_vector(1 downto 0);
      memoryRData    : in  std_logic_vector(63 downto 0);
      memoryRResp    : in  std_logic_vector(3 downto 0);
      memoryRValid   : in  std_logic_vector(1 downto 0);
      memoryAwAddr   : out std_logic_vector(63 downto 0);
      memoryAwValid  : out std_logic_vector(1 downto 0);
      memoryWData    : out std_logic_vector(63 downto 0);
      memoryWValid   : out std_logic_vector(1 downto 0);
      memoryAwReady  : in  std_logic_vector(1 downto 0);
      memoryWReady   : in  std_logic_vector(1 downto 0);
      memoryBResp    : in  std_logic_vector(3 downto 0);
      memoryBValid   : in  std_logic_vector(1 downto 0);
      sideBandPort0  : in  std_logic_vector(15 downto 0);
      sideBandPort1  : in  std_logic_vector(15 downto 0);
      sideBandTxCode : in  std_logic_vector(15 downto 0);
      sideBandTxEn   : in  std_logic_vector(1 downto 0);
      sideBandTxData : in  std_logic_vector(15 downto 0);
      sideBandRxCode : out std_logic_vector(15 downto 0);
      sideBandRxData : out std_logic_vector(15 downto 0);
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
end RogueSimLinkMultiInstanceHarness;

architecture harness of RogueSimLinkMultiInstanceHarness is

begin

   U_STREAM_0 : entity work.RogueTcpStream
      port map (
         clock      => clock,             -- [in]
         reset      => reset,             -- [in]
         portNum    => streamPort0,       -- [in]
         ssi        => '0',               -- [in]
         obValid    => streamObValid0,    -- [out]
         obReady    => streamObReady(0),  -- [in]
         obData     => streamObData(63 downto 0),  -- [out]
         obUser     => open,              -- [out]
         obKeep     => streamObKeep(7 downto 0),  -- [out]
         obLast     => streamObLast(0),   -- [out]
         ibValid    => streamIbValid(0),  -- [in]
         ibReady    => streamIbReady0,    -- [out]
         ibData     => streamIbData(63 downto 0),  -- [in]
         ibUser     => (others => '0'),   -- [in]
         ibKeep     => streamIbKeep(7 downto 0),  -- [in]
         ibLast     => streamIbLast(0));  -- [in]

   U_STREAM_1 : entity work.RogueTcpStream
      port map (
         clock      => clock,             -- [in]
         reset      => reset,             -- [in]
         portNum    => streamPort1,       -- [in]
         ssi        => '0',               -- [in]
         obValid    => streamObValid1,    -- [out]
         obReady    => streamObReady(1),  -- [in]
         obData     => streamObData(127 downto 64),  -- [out]
         obUser     => open,              -- [out]
         obKeep     => streamObKeep(15 downto 8),  -- [out]
         obLast     => streamObLast(1),   -- [out]
         ibValid    => streamIbValid(1),  -- [in]
         ibReady    => streamIbReady1,    -- [out]
         ibData     => streamIbData(127 downto 64),  -- [in]
         ibUser     => (others => '0'),   -- [in]
         ibKeep     => streamIbKeep(15 downto 8),  -- [in]
         ibLast     => streamIbLast(1));  -- [in]

   U_STREAM_2 : entity work.RogueTcpStream
      port map (
         clock      => clock,             -- [in]
         reset      => reset,             -- [in]
         portNum    => streamPort2,       -- [in]
         ssi        => '0',               -- [in]
         obValid    => streamObValid2,    -- [out]
         obReady    => streamObReady(2),  -- [in]
         obData     => streamObData(191 downto 128),  -- [out]
         obUser     => open,              -- [out]
         obKeep     => streamObKeep(23 downto 16),  -- [out]
         obLast     => streamObLast(2),   -- [out]
         ibValid    => streamIbValid(2),  -- [in]
         ibReady    => streamIbReady2,    -- [out]
         ibData     => streamIbData(191 downto 128),  -- [in]
         ibUser     => (others => '0'),   -- [in]
         ibKeep     => streamIbKeep(23 downto 16),  -- [in]
         ibLast     => streamIbLast(2));  -- [in]

   U_STREAM_3 : entity work.RogueTcpStream
      port map (
         clock      => clock,             -- [in]
         reset      => reset,             -- [in]
         portNum    => streamPort3,       -- [in]
         ssi        => '0',               -- [in]
         obValid    => streamObValid3,    -- [out]
         obReady    => streamObReady(3),  -- [in]
         obData     => streamObData(255 downto 192),  -- [out]
         obUser     => open,              -- [out]
         obKeep     => streamObKeep(31 downto 24),  -- [out]
         obLast     => streamObLast(3),   -- [out]
         ibValid    => streamIbValid(3),  -- [in]
         ibReady    => streamIbReady3,    -- [out]
         ibData     => streamIbData(255 downto 192),  -- [in]
         ibUser     => (others => '0'),   -- [in]
         ibKeep     => streamIbKeep(31 downto 24),  -- [in]
         ibLast     => streamIbLast(3));  -- [in]

   U_MEMORY_0 : entity work.RogueTcpMemory
      port map (
         clock   => clock,                -- [in]
         reset   => reset,                -- [in]
         portNum => memoryPort0,          -- [in]
         araddr  => memoryArAddr(31 downto 0),  -- [out]
         arprot  => open,                 -- [out]
         arvalid => memoryArValid0,       -- [out]
         rready  => open,                 -- [out]
         arready => memoryArReady(0),     -- [in]
         rdata   => memoryRData(31 downto 0),  -- [in]
         rresp   => memoryRResp(1 downto 0),  -- [in]
         rvalid  => memoryRValid(0),      -- [in]
         awaddr  => memoryAwAddr(31 downto 0),  -- [out]
         awprot  => open,                 -- [out]
         awvalid => memoryAwValid(0),     -- [out]
         wdata   => memoryWData(31 downto 0),  -- [out]
         wstrb   => open,                 -- [out]
         wvalid  => memoryWValid(0),      -- [out]
         bready  => memoryBReady0,        -- [out]
         awready => memoryAwReady(0),     -- [in]
         wready  => memoryWReady(0),      -- [in]
         bresp   => memoryBResp(1 downto 0),  -- [in]
         bvalid  => memoryBValid(0));     -- [in]

   U_MEMORY_1 : entity work.RogueTcpMemory
      port map (
         clock   => clock,                -- [in]
         reset   => reset,                -- [in]
         portNum => memoryPort1,          -- [in]
         araddr  => memoryArAddr(63 downto 32),  -- [out]
         arprot  => open,                 -- [out]
         arvalid => memoryArValid1,       -- [out]
         rready  => open,                 -- [out]
         arready => memoryArReady(1),     -- [in]
         rdata   => memoryRData(63 downto 32),  -- [in]
         rresp   => memoryRResp(3 downto 2),  -- [in]
         rvalid  => memoryRValid(1),      -- [in]
         awaddr  => memoryAwAddr(63 downto 32),  -- [out]
         awprot  => open,                 -- [out]
         awvalid => memoryAwValid(1),     -- [out]
         wdata   => memoryWData(63 downto 32),  -- [out]
         wstrb   => open,                 -- [out]
         wvalid  => memoryWValid(1),      -- [out]
         bready  => memoryBReady1,        -- [out]
         awready => memoryAwReady(1),     -- [in]
         wready  => memoryWReady(1),      -- [in]
         bresp   => memoryBResp(3 downto 2),  -- [in]
         bvalid  => memoryBValid(1));     -- [in]

   U_SIDE_BAND_0 : entity work.RogueSideBand
      port map (
         clock      => clock,             -- [in]
         reset      => reset,             -- [in]
         portNum    => sideBandPort0,     -- [in]
         txOpCode   => sideBandTxCode(7 downto 0),  -- [in]
         txOpCodeEn => sideBandTxEn(0),   -- [in]
         txRemData  => sideBandTxData(7 downto 0),  -- [in]
         rxOpCode   => sideBandRxCode(7 downto 0),  -- [out]
         rxOpCodeEn => sideBandRxEn0,     -- [out]
         rxRemData  => sideBandRxData(7 downto 0));  -- [out]

   U_SIDE_BAND_1 : entity work.RogueSideBand
      port map (
         clock      => clock,             -- [in]
         reset      => reset,             -- [in]
         portNum    => sideBandPort1,     -- [in]
         txOpCode   => sideBandTxCode(15 downto 8),  -- [in]
         txOpCodeEn => sideBandTxEn(1),   -- [in]
         txRemData  => sideBandTxData(15 downto 8),  -- [in]
         rxOpCode   => sideBandRxCode(15 downto 8),  -- [out]
         rxOpCodeEn => sideBandRxEn1,     -- [out]
         rxRemData  => sideBandRxData(15 downto 8));  -- [out]

end harness;
