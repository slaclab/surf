-------------------------------------------------------------------------------
-- File       : ClinkGroup.vhd
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
use work.AxiLitePkg.all;

entity ClinkGroup is
   generic (
      TPD_G : time := 1 ns);
   port (
      -- Input clock
      clinkClkIn      : in  sl;
      -- Async reset
      resetIn         : in  sl;
      -- Clock Outputs
      clinkClk        : out sl;
      clinkRst        : out sl;
      -- Data Input
      clinkSerData    : in  slv(3 downto 0);
      -- Clink shift, clinkClk
      clinkLocked     : out sl;
      -- Data Output, clinkClk
      clinkParData    : out slv(27 downto 0);
      -- AXI-Lite Interface 
      axilClk         : in  sl                     := '0';
      axilRst         : in  sl                     := '0';
      axilReadMaster  : in  AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
      axilWriteSlave  : out AxiLiteWriteSlaveType);      
end ClinkGroup;

architecture structure of ClinkGroup is

   signal intShift    : sl;
   signal iclinkClk   : sl;
   signal iclinkRst   : sl;
   signal iclinkClk7x : sl;

begin

   -- Outputs
   clinkClk   <= iclinkClk;
   clinkRst   <= iclinkRst;

   -- Clink clocks
   U_ClinkClk: entity work.ClinkClk
      generic map ( TPD_G => TPD_G )
      port map (
         clinkClkIn      => clinkClkIn,
         resetIn         => resetIn,
         clinkClk        => iclinkClk,
         clinkRst        => iclinkRst,
         clinkClk7x      => iclinkClk7x,
         clinkShift      => intShift,
         clinkLocked     => clinkLocked,
         axilClk         => axilClk,
         axilRst         => axilRst,
         axilReadMaster  => axilReadMaster,
         axilReadSlave   => axilReadSlave,
         axilWriteMaster => axilWriteMaster,
         axilWriteSlave  => axilWriteSlave);

   -- Clink Data In
   U_DinGen: for i in 0 to 3 generate
      U_Din: entity work.ClinkDin
         generic map (TPD_G => TPD_G)
         port map (
            clinkClk       => iclinkClk,
            clinkRst       => iclinkRst,
            clinkClk7x     => iclinkClk7x,
            clinkSerData   => clinkSerData(i),
            clinkShift     => intShift,
            clinkParData   => clinkParData(i*7+6 downto i*7));
   end generate;

end structure;

