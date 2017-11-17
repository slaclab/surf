-------------------------------------------------------------------------------
-- File       : ClinkData.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2017-11-13
-------------------------------------------------------------------------------
-- Description:
-- CameraLink data de-serializer. 
-- Wrapper for ClinkDeSerial when used as dedicated data channel.
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
library unisim;
use unisim.vcomponents.all;

entity ClinkData is
   generic (
      TPD_G : time := 1 ns);
   port (
      -- Cable Input
      cblHalfP : in  slv(4 downto 0); --  8, 10, 11, 12,  9
      cblHalfM : in  slv(4 downto 0); -- 21, 23, 24, 25, 22
      -- System clock and reset, must be 100Mhz or greater
      sysClk   : in  sl;
      sysRst   : in  sl;
      -- Status
      locked   : out sl;
      -- Data output
      parData  : out slv(27 downto 0);
      parValid : out sl;
      parReady : in  sl := '1');
end ClinkData;

architecture structure of ClinkData is
   signal cableIn : slv(4 downto 0);
begin

   -------------------------------
   -- In Buffers
   -------------------------------
   U_CableBuffGen: for i in 0 to 4 generate
      U_CableBuff: IBUFDS
         port map (
            I  => cblHalfP(i),
            IB => cblHalfM(i),
            O  => cableIn(i));
   end generate;

   -------------------------------
   -- Data
   -------------------------------
   U_DeSerial : entity work.ClinkDeSerial
      generic map ( TPD_G => TPD_G )
      port map (
         clkIn     => cableIn(0),
         dataIn    => cableIn(4 downto 1),
         sysClk    => sysClk,
         sysRst    => sysRst,
         locked    => locked,
         parData   => parData,
         parValid  => parValid,
         parReady  => parReady);

end architecture rtl;

