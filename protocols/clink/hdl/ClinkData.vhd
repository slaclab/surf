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
use work.ClinkPkg.all;
library unisim;
use unisim.vcomponents.all;

entity ClinkData is
   generic (
      TPD_G       : time    := 1 ns;
      INVERT_34_G : boolean := false);
   port (
      -- Cable Input
      cblHalfP   : inout slv(4 downto 0); --  8, 10, 11, 12,  9
      cblHalfM   : inout slv(4 downto 0); -- 21, 23, 24, 25, 22
      -- Delay clock and reset, 200Mhz
      dlyClk     : in  sl; 
      dlyRst     : in  sl; 
      -- System clock and reset, must be 100Mhz or greater
      sysClk     : in  sl;
      sysRst     : in  sl;
      -- Status and config
      linkConfig : in  ClLinkConfigType;
      linkStatus : out ClLinkStatusType;
      -- Data output
      parData    : out slv(27 downto 0);
      parValid   : out sl;
      parReady   : in  sl := '1');
end ClinkData;

architecture rtl of ClinkData is
   signal cblIn : slv(4 downto 0);
begin

   -------------------------------
   -- In Buffers
   -------------------------------
   U_CableBuffGen: for i in 0 to 4 generate
--      U_CableBuff : IOBUFDS_DCIEN
--         generic map (
--            DIFF_TERM       => "TRUE",    -- Differential termination (TRUE/FALSE)
--            IBUF_LOW_PWR    => "FALSE",   -- Low Power - TRUE, HIGH Performance = FALSE
--            IOSTANDARD      => "LVDS_25", -- Specify the I/O standard
--            SLEW            => "FAST",    -- Specify the output slew rate
--            USE_IBUFDISABLE => "FALSE")   -- Use IBUFDISABLE function "TRUE" or "FALSE"
--         port map (
--            I    => '0',
--            O    => cblIn(i),
--            T    => '1',
--            IO   => cblHalfP(i),
--            IOB  => cblHalfM(i),
--            DCITERMDISABLE => '0',
--            IBUFDISABLE    => '0');

      U_CableBuff: IOBUFDS
         port map(
            I   => '0',
            O   => cblIn(i),
            T   => '1',
            IO  => cblHalfP(i),
            IOB => cblHalfM(i));

   end generate;

   -------------------------------
   -- Data
   -------------------------------
   U_DeSerial : entity work.ClinkDeSerial
      generic map ( 
         TPD_G       => TPD_G,
         INVERT_34_G => INVERT_34_G)
      port map (
         cblIn      => cblIn,
         dlyClk     => dlyClk,
         dlyRst     => dlyRst,
         sysClk     => sysClk,
         sysRst     => sysRst,
         linkConfig => linkConfig,
         linkStatus => linkStatus,
         parData    => parData,
         parValid   => parValid,
         parReady   => parReady);

end architecture rtl;

