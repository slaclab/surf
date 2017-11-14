-------------------------------------------------------------------------------
-- File       : ClinkDin.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2017-11-13
-------------------------------------------------------------------------------
-- Description:
-- CameraLink data input. Single data input bit.
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

entity ClinkDin is
   generic (
      TPD_G : time := 1 ns);
   port (
      clinkClk        : in  sl;
      clinkRst        : in  sl;
      clinkClk7x      : in  sl; -- 7X clock input
      -- Data Input
      clinkSerData    : in  sl;
      -- Clink shift, clinkClk
      clinkShift      : in  sl;
      -- Data Output, clinkClk
      clinkParData    : out slv(6 downto 0));
end ClinkDin;

architecture structure of ClinkDin is

   signal clinkClk7xInv : sl;

begin

   -- Invert clock
   clinkClk7xInv <= not clinkClk7x;

   -- ISERDESE2: Input SERial/DESerializer with bitslip
   -- 7 Series
   -- Xilinx HDL Libraries Guide, version 2012.2
   U_Iserdes : ISERDESE2
      generic map (
         DATA_RATE         => "SDR",        -- DDR, SDR
         DATA_WIDTH        => 7,            -- Parallel data width (2-8,10,14)
         DYN_CLKDIV_INV_EN => "FALSE",
         DYN_CLK_INV_EN    => "FALSE",
         INTERFACE_TYPE    => "NETWORKING", -- MEMORY, MEMORY_DDR3, MEMORY_QDR, NETWORKING, OVERSAMPLE
         IOBDELAY          => "NONE",       -- NONE, BOTH, IBUF, IFD
         NUM_CE            => 1,            -- Number of clock enables (1,2)
         OFB_USED          => "FALSE",      -- Select OFB path (FALSE, TRUE)
         SERDES_MODE       => "MASTER"      -- MASTER, SLAVE
      )
      port map (
         Q1           => clinkParData(0),
         Q2           => clinkParData(1),
         Q3           => clinkParData(2),
         Q4           => clinkParData(3),
         Q5           => clinkParData(4),
         Q6           => clinkParData(5),
         Q7           => clinkParData(6),
         BITSLIP      => clinkShift,
         CE1          => '1',
         CE2          => '1',
         CLKDIVP      => '0',
         CLK          => clinkClk7x,
         CLKB         => clinkClk7xInv,
         CLKDIV       => clinkClk,
         OCLK         => '0',
         DYNCLKDIVSEL => '0',
         DYNCLKSEL    => '0',
         D            => clinkSerData,
         DDLY         => '0',
         OFB          => '0',
         OCLKB        => '0',
         RST          => clinkRst,
         SHIFTIN1     => '0',
         SHIFTIN2     => '0'
      );

end structure;

