-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : XauiGthUltraScaleWrapper.vhd
-- Author     : Larry Ruckman <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-04-08
-- Last update: 2015-09-08
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: GTH Ultra Scale Wrapper for 10 GigE XAUI
-------------------------------------------------------------------------------
-- Copyright (c) 2015 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.AxiLitePkg.all;
use work.XauiPkg.all;

library unisim;
use unisim.vcomponents.all;

entity XauiGthUltraScaleWrapper is
   -- Defaults:
   -- 9 bits = 4kbytes
   -- 255 x 8 = 2kbytes (not enough for pause)
   -- 11 bits = 16kbytes 
   generic (
      TPD_G            : time                := 1 ns;
      -- DMA/MAC Configurations
      IB_ADDR_WIDTH_G  : natural             := 11;
      OB_ADDR_WIDTH_G  : natural             := 9;
      PAUSE_THOLD_G    : natural             := 512;
      VALID_THOLD_G    : natural             := 255;
      EOH_BIT_G        : natural             := 0;
      ERR_BIT_G        : natural             := 1;
      HEADER_SIZE_G    : natural             := 16;
      SHIFT_EN_G       : boolean             := false;
      -- XAUI Configurations
      XAUI_20GIGE_G    : boolean             := false;
      REF_CLK_FREQ_G   : real                := 156.25E+6;  -- Support 125MHz, 156.25MHz, or 312.5MHz
      -- AXI-Lite Configurations
      AXI_ERROR_RESP_G : slv(1 downto 0)     := AXI_RESP_SLVERR_C;
      -- AXI Streaming Configurations
      -- Note: Only support 64-bit AXIS configurations on the XMAC module
      AXIS_CONFIG_G    : AxiStreamConfigType := AXI_STREAM_CONFIG_INIT_C);
   port (
      -- Local Configurations
      localMac           : in  slv(47 downto 0)       := MAC_ADDR_INIT_C;
      -- Streaming DMA Interface 
      dmaClk             : in  sl;
      dmaRst             : in  sl;
      dmaIbMaster        : out AxiStreamMasterType;
      dmaIbSlave         : in  AxiStreamSlaveType;
      dmaObMaster        : in  AxiStreamMasterType;
      dmaObSlave         : out AxiStreamSlaveType;
      -- Slave AXI-Lite Interface 
      axiLiteClk         : in  sl                     := '0';
      axiLiteRst         : in  sl                     := '0';
      axiLiteReadMaster  : in  AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
      axiLiteReadSlave   : out AxiLiteReadSlaveType;
      axiLiteWriteMaster : in  AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
      axiLiteWriteSlave  : out AxiLiteWriteSlaveType;
      -- Misc. Signals
      extRst             : in  sl                     := '0';
      phyClk             : out sl;
      phyRst             : out sl;
      phyReady           : out sl;
      -- MGT Clock Port (125MHz, 156.25MHz, or 312.5MHz)
      gtClkP             : in  sl;
      gtClkN             : in  sl;
      -- MGT Ports
      gtTxP              : out slv(3 downto 0);
      gtTxN              : out slv(3 downto 0);
      gtRxP              : in  slv(3 downto 0);
      gtRxN              : in  slv(3 downto 0));  
end XauiGthUltraScaleWrapper;

architecture mapping of XauiGthUltraScaleWrapper is

   signal refClk : sl;

begin

   IBUFDS_GTE3_Inst : IBUFDS_GTE3
      port map (
         I     => gtClkP,
         IB    => gtClkN,
         CEB   => '0',
         ODIV2 => open,
         O     => refClk);   

   ----------------------
   -- 10 GigE XAUI Module
   ----------------------
   XauiGthUltraScale_Inst : entity work.XauiGthUltraScale
      generic map (
         TPD_G            => TPD_G,
         -- DMA/MAC Configurations
         IB_ADDR_WIDTH_G  => IB_ADDR_WIDTH_G,
         OB_ADDR_WIDTH_G  => OB_ADDR_WIDTH_G,
         PAUSE_THOLD_G    => PAUSE_THOLD_G,
         VALID_THOLD_G    => VALID_THOLD_G,
         EOH_BIT_G        => EOH_BIT_G,
         ERR_BIT_G        => ERR_BIT_G,
         HEADER_SIZE_G    => HEADER_SIZE_G,
         SHIFT_EN_G       => SHIFT_EN_G,
         -- XAUI Configurations
         XAUI_20GIGE_G    => XAUI_20GIGE_G,
         REF_CLK_FREQ_G   => REF_CLK_FREQ_G,
         -- AXI-Lite Configurations
         AXI_ERROR_RESP_G => AXI_ERROR_RESP_G,
         -- AXI Streaming Configurations
         AXIS_CONFIG_G    => AXIS_CONFIG_G)       
      port map (
         -- Local Configurations
         localMac           => localMac,
         -- Clocks and resets
         dmaClk             => dmaClk,
         dmaRst             => dmaRst,
         dmaIbMaster        => dmaIbMaster,
         dmaIbSlave         => dmaIbSlave,
         dmaObMaster        => dmaObMaster,
         dmaObSlave         => dmaObSlave,
         -- Slave AXI-Lite Interface 
         axiLiteClk         => axiLiteClk,
         axiLiteRst         => axiLiteRst,
         axiLiteReadMaster  => axiLiteReadMaster,
         axiLiteReadSlave   => axiLiteReadSlave,
         axiLiteWriteMaster => axiLiteWriteMaster,
         axiLiteWriteSlave  => axiLiteWriteSlave,
         -- Misc. Signals
         extRst             => extRst,
         phyClk             => phyClk,
         phyRst             => phyRst,
         phyReady           => phyReady,
         -- MGT Ports
         refClk             => refClk,
         gtTxP              => gtTxP,
         gtTxN              => gtTxN,
         gtRxP              => gtRxP,
         gtRxN              => gtRxN);  

end mapping;
