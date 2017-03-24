-------------------------------------------------------------------------------
-- File       : AxiXcf128Core.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-04-24
-- Last update: 2015-01-13
-------------------------------------------------------------------------------
-- Description: AXI-Lite interface to XCF128 FLASH IC
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
use ieee.numeric_std.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.AxiXcf128Pkg.all;

library unisim;
use unisim.vcomponents.all;

entity AxiXcf128Core is
   generic (
      TPD_G            : time            := 1 ns;
      AXI_CLK_FREQ_G   : real            := 200.0E+6;  -- units of Hz
      AXI_ERROR_RESP_G : slv(1 downto 0) := AXI_RESP_SLVERR_C);
   port (
      -- XCF128 Ports
      xcfInOut       : inout AxiXcf128InOutType;
      xcfOut         : out   AxiXcf128OutType;
      -- AXI-Lite Register Interface
      axiReadMaster  : in    AxiLiteReadMasterType;
      axiReadSlave   : out   AxiLiteReadSlaveType;
      axiWriteMaster : in    AxiLiteWriteMasterType;
      axiWriteSlave  : out   AxiLiteWriteSlaveType;
      -- Clocks and Resets
      axiClk         : in    sl;
      axiRst         : in    sl);
end AxiXcf128Core;

architecture mapping of AxiXcf128Core is

   signal status : AxiXcf128StatusType;
   signal config : AxiXcf128ConfigType;
   
begin

   GEN_IOBUF :
   for i in 15 downto 0 generate
      IOBUF_inst : IOBUF
         port map (
            O  => status.data(i),       -- Buffer output
            IO => xcfInOut.data(i),     -- Buffer inout port (connect directly to top-level port)
            I  => config.data(i),       -- Buffer input
            T  => config.tristate);     -- 3-state enable input, high=input, low=output     
   end generate GEN_IOBUF;

   xcfOut.ceL   <= config.ceL;
   xcfOut.oeL   <= config.oeL;
   xcfOut.weL   <= config.weL;
   xcfOut.latch <= config.latch;
   xcfOut.addr  <= config.addr;

   AxiXcf128Reg_Inst : entity work.AxiXcf128Reg
      generic map(
         TPD_G            => TPD_G,
         AXI_CLK_FREQ_G   => AXI_CLK_FREQ_G,
         AXI_ERROR_RESP_G => AXI_ERROR_RESP_G)
      port map(
         -- AXI-Lite Register Interface
         axiReadMaster  => axiReadMaster,
         axiReadSlave   => axiReadSlave,
         axiWriteMaster => axiWriteMaster,
         axiWriteSlave  => axiWriteSlave,
         -- Register Inputs/Outputs
         status         => status,
         config         => config,
         -- Clock and Reset
         axiClk         => axiClk,
         axiRst         => axiRst);    

end mapping;
