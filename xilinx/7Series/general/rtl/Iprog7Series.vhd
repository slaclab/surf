-------------------------------------------------------------------------------
-- File       : Iprog7Series.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-11-01
-- Last update: 2015-09-10
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:   Uses the ICAP primitive to internally 
--                toggle the PROG_B via IPROG command
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

entity Iprog7Series is
   generic (
      TPD_G          : time    := 1 ns;
      USE_SLOWCLK_G  : boolean := false;
      BUFR_CLK_DIV_G : string  := "8");
   port (
      clk         : in sl;
      rst         : in sl;
      slowClk     : in sl               := '0';
      start       : in sl;              -- Should be asserted and held until reboot
      bootAddress : in slv(31 downto 0) := X"00000000");
end Iprog7Series;

architecture rtl of Iprog7Series is

   signal icapClk    : sl;
   signal icapClkRst : sl;
   signal icapCsl    : sl;
   signal icapRnw    : sl;
   signal icapI      : slv(31 downto 0);

begin

   SLOWCLK_GEN : if (USE_SLOWCLK_G) generate
      icapClk <= slowClk;
   end generate SLOWCLK_GEN;

   DIVCLK_GEN : if (not USE_SLOWCLK_G) generate
      BUFR_ICPAPE2 : BUFR
         generic map (
            BUFR_DIVIDE => BUFR_CLK_DIV_G)
         port map (
            CE  => '1',
            CLR => '0',
            I   => clk,
            O   => icapClk);
   end generate DIVCLK_GEN;

   -- Synchronize reset to icapClk
   RstSync_Inst : entity work.RstSync
      generic map (
         TPD_G => TPD_G)
      port map (
         clk      => icapClk,
         asyncRst => rst,
         syncRst  => icapClkRst);


   -- IPROG logic
   Iprog7SeriesCore_1 : entity work.Iprog7SeriesCore
      generic map (
         TPD_G         => TPD_G,
         SYNC_RELOAD_G => true)
      port map (
         reload     => start,
         reloadAddr => bootAddress,
         icapClk    => icapClk,
         icapClkRst => icapClkRst,
         icapReq    => open,
         icapGrant  => '1',             -- Dedicated ICAP so always grant
         icapCsl    => icapCsl,
         icapRnw    => icapRnw,
         icapI      => icapI);

   -- ICAP Primative
   ICAPE2_Inst : ICAPE2
      generic map (
         DEVICE_ID         => x"03651093",  -- Specifies the pre-programmed Device ID value to be used for simulation purposes
         ICAP_WIDTH        => "X32",  -- Specifies the input and output data width to be used with the ICAPE2 Possible values: (X8,X16 or X32)
         SIM_CFG_FILE_NAME => "NONE")  -- Specifies the Raw Bitstream (RBT) file to be parsed by the simulation model
      port map (
         O     => open,                 -- 32-bit output: Configuration data output bus
         CLK   => icapClk,              -- 1-bit input: Clock Input
         CSIB  => icapCsl,              -- 1-bit input: Active-Low ICAP Enable
         I     => icapI,                -- 32-bit input: Configuration data input bus
         RDWRB => icapRnw);             -- 1-bit input: Read/Write Select input


end rtl;
