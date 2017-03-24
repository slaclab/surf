-------------------------------------------------------------------------------
-- File       : AxiLiteEmptyVector.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-08-18
-- Last update: 2015-08-18
-------------------------------------------------------------------------------
-- Description: Wrapper for a multiple AxiLiteEmpty modules
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

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;

entity AxiLiteEmptyVector is
   generic (
      TPD_G   : time := 1 ns;
      WIDTH_G : positive);
   port (
      axiClk          : in  sl;
      axiRst          : in  sl;
      axiReadMasters  : in  AxiLiteReadMasterArray(WIDTH_G-1 downto 0);
      axiReadSlaves   : out AxiLiteReadSlaveArray(WIDTH_G-1 downto 0);
      axiWriteMasters : in  AxiLiteWriteMasterArray(WIDTH_G-1 downto 0);
      axiWriteSlaves  : out AxiLiteWriteSlaveArray(WIDTH_G-1 downto 0));
end AxiLiteEmptyVector;

architecture mapping of AxiLiteEmptyVector is

begin

   GEN_VEC :
   for i in (WIDTH_G-1) downto 0 generate
      
      AxiLiteEmpty_Inst : entity work.AxiLiteEmpty
         generic map (
            TPD_G => TPD_G)      
         port map (
            axiClk         => axiClk,
            axiClkRst      => axiRst,
            axiReadMaster  => axiReadMasters(i),
            axiReadSlave   => axiReadSlaves(i),
            axiWriteMaster => axiWriteMasters(i),
            axiWriteSlave  => axiWriteSlaves(i));      

   end generate GEN_VEC;

end architecture mapping;
