-------------------------------------------------------------------------------
-- File       : AxiDac7654Core.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-09-23
-- Last update: 2014-09-25
-------------------------------------------------------------------------------
-- Description: AXI-Lite interface to DAC7654 DAC IC
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
use work.AxiDac7654Pkg.all;

entity AxiDac7654Core is
   generic (
      TPD_G              : time                  := 1 ns;
      AXI_CLK_FREQ_G     : real                  := 125.0E+6;  -- units of Hz
      STATUS_CNT_WIDTH_G : natural range 1 to 32 := 32;
      AXI_ERROR_RESP_G   : slv(1 downto 0)       := AXI_RESP_SLVERR_C);
   port (
      -- DAC Ports
      dacIn          : in  AxiDac7654InType;
      dacOut         : out AxiDac7654OutType;
      -- AXI-Lite Register Interface (axiClk domain)      
      axiClk         : in  sl;
      axiRst         : in  sl;
      axiReadMaster  : in  AxiLiteReadMasterType;
      axiReadSlave   : out AxiLiteReadSlaveType;
      axiWriteMaster : in  AxiLiteWriteMasterType;
      axiWriteSlave  : out AxiLiteWriteSlaveType);
end AxiDac7654Core;

architecture mapping of AxiDac7654Core is
   
   signal status : AxiDac7654StatusType;
   signal config : AxiDac7654ConfigType;
   
begin

   AxiDac7654Reg_Inst : entity work.AxiDac7654Reg
      generic map(
         TPD_G              => TPD_G,
         STATUS_CNT_WIDTH_G => STATUS_CNT_WIDTH_G,
         AXI_ERROR_RESP_G   => AXI_ERROR_RESP_G)
      port map(
         -- AXI-Lite Register Interface    
         axiClk         => axiClk,
         axiRst         => axiRst,
         axiReadMaster  => axiReadMaster,
         axiReadSlave   => axiReadSlave,
         axiWriteMaster => axiWriteMaster,
         axiWriteSlave  => axiWriteSlave,
         -- Register Inputs/Outputs
         status         => status,
         config         => config);

   AxiDac7654Spi_Inst : entity work.AxiDac7654Spi
      generic map(
         TPD_G          => TPD_G,
         AXI_CLK_FREQ_G => AXI_CLK_FREQ_G)
      port map (
         -- Parallel interface
         spiIn   => config.spi,
         spiOut  => status.spi,
         --DAC I/O ports
         dacCs   => dacOut.cs,
         dacSck  => dacOut.sck,
         dacSdi  => dacOut.sdi,
         dacSdo  => dacIn.sdo,
         dacLoad => dacOut.load,
         dacLdac => dacOut.ldac,
         dacRst  => dacOut.rst,
         --Global Signals
         axiClk  => axiClk,
         axiRst  => axiRst);        

end mapping;
