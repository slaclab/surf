-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : AxiAd5780Core.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-04-18
-- Last update: 2014-04-18
-- Platform   : Vivado 2013.3
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: AXI-Lite interface to AD5780 DAC IC
-------------------------------------------------------------------------------
-- Copyright (c) 2014 SLAC National Accelerator Laboratory
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
      AXI_ERROR_RESP_G   : slv(1 downto 0)       := AXI_RESP_SLVERR_C);
   port (
      -- DAC Ports
      dacIn          : in  AxiAd5780InType;
      dacOut         : out AxiAd5780OutType;
      -- DAC Data Interface (axiClk domain)
      dacValid       : in  sl;
      dacData        : in  slv(17 downto 0);               --2's complement
      -- AXI-Lite Register Interface (axiClk domain)
      axiReadMaster  : in  AxiLiteReadMasterType;
      axiReadSlave   : out AxiLiteReadSlaveType;
      axiWriteMaster : in  AxiLiteWriteMasterType;
      axiWriteSlave  : out AxiLiteWriteSlaveType;
      -- Clocks and Resets
      axiClk         : in  sl;
      axiRst         : in  sl;
      dacClk         : in  sl);         --up to 70 MHz reference clock
end AxiAd5780Core;

architecture rtl of AxiAd5780Core is
   
   signal status : AxiAd5780StatusType;
   signal config : AxiAd5780ConfigType;

   signal dacValidMux : sl;
   signal dacDataMux  : slv(17 downto 0);
   
begin

   status.dacValid <= dacValid;
   status.dacData  <= dacData;

   AxiAd5780Reg_Inst : entity work.AxiAd5780Reg
      generic map(
         TPD_G              => TPD_G,
         STATUS_CNT_WIDTH_G => STATUS_CNT_WIDTH_G,
         USE_DSP48_G        => USE_DSP48_G,
         AXI_CLK_FREQ_G     => AXI_CLK_FREQ_G,
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
         axiRst         => axiRst);

   process(axiClk)
   begin
      if rising_edge(axiClk) then
         if config.debugMux = '1' then
            dacValidMux <= '1'              after TPD_G;
            dacDataMux  <= config.debugData after TPD_G;
         else
            dacValidMux <= status.dacValid after TPD_G;
            dacDataMux  <= status.dacData  after TPD_G;
         end if;
      end if;
   end process;

   AxiAd5780Ser_Inst : entity work.AxiAd5780Ser
      generic map(
         TPD_G => TPD_G)
      port map(
         -- DAC Ports
         dacIn    => dacIn,
         dacOut   => dacOut,
         -- DAC Data Interface (axiClk domain)
         dacValid => dacValidMux,
         dacData  => dacDataMux,
         -- Clocks and Resets
         axiClk   => axiClk,
         axiRst   => axiRst,
         dacClk   => dacClk); 

end rtl;
