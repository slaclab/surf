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

   attribute FOREIGN of RogueTcpStream : architecture is
      "vhpi:RogueSimLinkVhpi:VhpiGenericElab:RogueTcpStreamInit:RogueTcpStream";

begin

end RogueTcpStream;
