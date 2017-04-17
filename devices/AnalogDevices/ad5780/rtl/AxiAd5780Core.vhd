-------------------------------------------------------------------------------
-- File       : AxiAd5780Core.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-04-18
-- Last update: 2014-05-18
-------------------------------------------------------------------------------
-- Description: AXI-Lite interface to AD5780 DAC IC
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
use work.AxiAd5780Pkg.all;

entity AxiAd5780Core is
   generic (
      TPD_G              : time                  := 1 ns;
      STATUS_CNT_WIDTH_G : natural range 1 to 32 := 32;
      USE_DSP48_G        : string                := "no";  -- "no" for no DSP48 implementation, "yes" to use DSP48 slices      
      AXI_CLK_FREQ_G     : real                  := 200.0E+6;  -- units of Hz
      SPI_CLK_FREQ_G     : real                  := 25.0E+6;   -- units of Hz
      AXI_ERROR_RESP_G   : slv(1 downto 0)       := AXI_RESP_SLVERR_C);
   port (
      -- DAC Ports
      dacIn          : in  AxiAd5780InType;
      dacOut         : out AxiAd5780OutType;
      -- DAC Data Interface (axiClk domain)
      dacData        : in  slv(17 downto 0);               -- 2's complement by default
      -- AXI-Lite Register Interface (axiClk domain)
      axiReadMaster  : in  AxiLiteReadMasterType;
      axiReadSlave   : out AxiLiteReadSlaveType;
      axiWriteMaster : in  AxiLiteWriteMasterType;
      axiWriteSlave  : out AxiLiteWriteSlaveType;
      -- Clocks and Resets
      axiClk         : in  sl;
      axiRst         : in  sl);
end AxiAd5780Core;

architecture rtl of AxiAd5780Core is
   
   signal status : AxiAd5780StatusType;
   signal config : AxiAd5780ConfigType;

   signal dacRst     : sl;
   signal dacDataMux : slv(17 downto 0);
   
begin

   status.dacData <= dacData;

   AxiAd5780Reg_Inst : entity work.AxiAd5780Reg
      generic map(
         TPD_G              => TPD_G,
         STATUS_CNT_WIDTH_G => STATUS_CNT_WIDTH_G,
         USE_DSP48_G        => USE_DSP48_G,
         AXI_CLK_FREQ_G     => AXI_CLK_FREQ_G,
         SPI_CLK_FREQ_G     => SPI_CLK_FREQ_G,
         AXI_ERROR_RESP_G   => AXI_ERROR_RESP_G)
      port map(
         -- AXI-Lite Register Interface    
         axiReadMaster  => axiReadMaster,
         axiReadSlave   => axiReadSlave,
         axiWriteMaster => axiWriteMaster,
         axiWriteSlave  => axiWriteSlave,
         -- Register Inputs/Outputs
         status         => status,
         config         => config,
         -- Clock and reset
         axiClk         => axiClk,
         axiRst         => axiRst,
         dacRst         => dacRst);

   process(axiClk)
   begin
      if rising_edge(axiClk) then
         if config.debugMux = '1' then
            dacDataMux <= config.debugData after TPD_G;
         else
            dacDataMux <= status.dacData after TPD_G;
         end if;
      end if;
   end process;

   AxiAd5780Ser_Inst : entity work.AxiAd5780Ser
      generic map(
         TPD_G          => TPD_G,
         AXI_CLK_FREQ_G => AXI_CLK_FREQ_G)         
      port map(
         -- DAC Ports
         dacIn         => dacIn,
         dacOut        => dacOut,
         -- DAC Data Interface (axiClk domain)
         halfSckPeriod => config.halfSckPeriod,
         sdoDisable    => config.sdoDisable,
         binaryOffset  => config.binaryOffset,
         dacTriState   => config.dacTriState,
         opGnd         => config.opGnd,
         rbuf          => config.rbuf,
         dacData       => dacDataMux,
         dacUpdated    => status.dacUpdated,
         -- Clocks and Resets
         axiClk        => axiClk,
         axiRst        => axiRst,
         dacRst        => dacRst); 

end rtl;
