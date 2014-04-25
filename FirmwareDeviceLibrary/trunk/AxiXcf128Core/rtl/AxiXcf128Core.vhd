-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : AxiXcf128Core.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-04-24
-- Last update: 2014-04-24
-- Platform   : Vivado 2013.3
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: AXI-Lite interface to XCF128 FLASH IC
--
--    Note: Set the addrBits on the crossbar for this module to 4 bits wide
-------------------------------------------------------------------------------
-- Copyright (c) 2014 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.AxiXcf128Pkg.all;

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
   
   xcfInOut.data <= config.data when(config.tristate = '0') else (others => 'Z');
   status.data   <= xcfInOut.data;

   xcfOut.ce    <= config.ce;
   xcfOut.oe    <= config.oe;
   xcfOut.we    <= config.we;
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
