-------------------------------------------------------------------------------
-- File       : RogueTcpSideBand.vhd
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Wrapper for Rogue Sideband Simulation Module
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
use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;

entity RogueTcpSideBandWrap is
   generic (
      TPD_G      : time                     := 1 ns;
      PORT_NUM_G : natural range 0 to 65535 := 1
      );
   port (
      sysClk     : in  sl;
      sysRst     : in  sl;
      -- Outboard Sideband
      obOpCode   : out std_logic_vector(7 downto 0);
      obOpCodeEn : out std_logic;
      obRemData  : out std_logic_vector(7 downto 0);
      -- Inbound Sideband
      ibOpCode   : in  std_logic_vector(7 downto 0);
      ibOpCodeEn : in  std_logic;
      ibRemData  : in  std_logic_vector(7 downto 0));
end RogueTcpSideBandWrap;

-- Define architecture
architecture RogueTcpSideBandWrap of RogueTcpSideBandWrap is

begin

   -- Sim Core
   U_RogueTcpSideBand : entity work.RogueTcpSideBand
      port map(
         clock      => sysClk,
         reset      => sysRst,
         portNum    => toSlv(PORT_NUM_G, 16),
         -- Outboard Sideband
         obOpCode   => obOpCode,
         obOpCodeEn => obOpCodeEn,
         obRemData  => obRemData,
         -- Inbound Sideband
         ibOpCode   => ibOpCode,
         ibOpCodeEn => ibOpCodeEn,
         ibRemData  => ibRemData);

end RogueTcpSideBandWrap;

