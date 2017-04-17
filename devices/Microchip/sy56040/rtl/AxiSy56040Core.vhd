-------------------------------------------------------------------------------
-- File       : AxiSy56040Core.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-06-12
-- Last update: 2015-06-12
-------------------------------------------------------------------------------
-- Description: AXI-Lite interface to Clock Crossbar
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
use work.AxiSy56040Pkg.all;

entity AxiSy56040Core is
   generic (
      TPD_G            : time                  := 1 ns;
      AXI_CLK_FREQ_G   : real                  := 200.0E+6;  -- units of Hz
      XBAR_DEFAULT_G   : Slv2Array(3 downto 0) := ("11", "10", "01", "00");
      AXI_ERROR_RESP_G : slv(1 downto 0)       := AXI_RESP_SLVERR_C);
   port (
      -- XBAR Ports 
      xBar           : out AxiSy56040OutType;
      -- AXI-Lite Register Interface
      axiReadMaster  : in  AxiLiteReadMasterType;
      axiReadSlave   : out AxiLiteReadSlaveType;
      axiWriteMaster : in  AxiLiteWriteMasterType;
      axiWriteSlave  : out AxiLiteWriteSlaveType;
      -- Clocks and Resets
      axiClk         : in  sl;
      axiRst         : in  sl);
end AxiSy56040Core;

architecture mapping of AxiSy56040Core is

begin

   AxiSy56040Reg_Inst : entity work.AxiSy56040Reg
      generic map (
         TPD_G            => TPD_G,
         AXI_CLK_FREQ_G   => AXI_CLK_FREQ_G,
         XBAR_DEFAULT_G   => XBAR_DEFAULT_G,
         AXI_ERROR_RESP_G => AXI_ERROR_RESP_G) 
      port map (
         -- XBAR Ports 
         xBarSin        => xBar.sin,
         xBarSout       => xBar.sout,
         xBarConfig     => xBar.config,
         xBarLoad       => xBar.load,
         -- AXI-Lite Register Interface
         axiReadMaster  => axiReadMaster,
         axiReadSlave   => axiReadSlave,
         axiWriteMaster => axiWriteMaster,
         axiWriteSlave  => axiWriteSlave,
         -- Clocks and Resets
         axiClk         => axiClk,
         axiRst         => axiRst); 

end mapping;
