-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : AxiLiteEmptyVector.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-08-18
-- Last update: 2015-08-18
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2015 SLAC National Accelerator Laboratory
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
