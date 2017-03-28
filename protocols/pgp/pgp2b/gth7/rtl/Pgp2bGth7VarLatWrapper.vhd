-------------------------------------------------------------------------------
-- File       : Pgp2bGth7VarLatWrapper.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-04-01
-- Last update: 2016-08-24
-------------------------------------------------------------------------------
-- Description: Example PGP 3.125 Gbps front end wrapper
-- Note: Default generic configurations are for the Diligent NetFPGA-SUME development board
-- Note: Default uses FPGA fabric clock = 156.25 MHz reference clock
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
use work.AxiStreamPkg.all;
use work.Pgp2bPkg.all;
use work.AxiLitePkg.all;

library unisim;
use unisim.vcomponents.all;

entity Pgp2bGth7VarLatWrapper is
   generic (
      TPD_G             : time                 := 1 ns;
      -- CPLL Configurations (Defaults: pgpClk = 156.25 MHz Configuration)
      CPLL_FBDIV_G      : natural              := 4;
      CPLL_FBDIV_45_G   : natural              := 5;
      CPLL_REFCLK_DIV_G : natural              := 1;
      -- MGT Configurations (Defaults: pgpClk = 156.25 MHz Configuration)
      RXOUT_DIV_G       : natural              := 2;
      TXOUT_DIV_G       : natural              := 2;
      RX_CLK25_DIV_G    : natural              := 7;
      TX_CLK25_DIV_G    : natural              := 7;
      RX_OS_CFG_G       : bit_vector           := "0000010000000";           -- Set by wizard
      RXCDR_CFG_G       : bit_vector           := x"0002007FE1000C2200018";  -- Set by wizard
      RXDFEXYDEN_G      : sl                   := '1';                       -- Set by wizard 
      -- PGP Settings
      VC_INTERLEAVE_G   : integer              := 0;  -- No interleave Frames
      PAYLOAD_CNT_TOP_G : integer              := 7;  -- Top bit for payload counter
      NUM_VC_EN_G       : integer range 1 to 4 := 4;
      AXI_ERROR_RESP_G  : slv(1 downto 0)      := AXI_RESP_DECERR_C;
      TX_ENABLE_G       : boolean              := true;                      -- Enable TX direction
      RX_ENABLE_G       : boolean              := true);                     -- Enable RX direction
   port (
      -- Clocks and Reset
      pgpClk          : in  sl;
      pgpRst          : in  sl;
      -- Non VC TX Signals
      pgpTxIn         : in  Pgp2bTxInType;
      pgpTxOut        : out Pgp2bTxOutType;
      -- Non VC RX Signals
      pgpRxIn         : in  Pgp2bRxInType;
      pgpRxOut        : out Pgp2bRxOutType;
      -- Frame TX Interface
      pgpTxMasters    : in  AxiStreamMasterArray(3 downto 0);
      pgpTxSlaves     : out AxiStreamSlaveArray(3 downto 0);
      -- Frame RX Interface
      pgpRxMasters    : out AxiStreamMasterArray(3 downto 0);
      pgpRxCtrl       : in  AxiStreamCtrlArray(3 downto 0);
      -- GT Pins
      gtTxP           : out sl;
      gtTxN           : out sl;
      gtRxP           : in  sl;
      gtRxN           : in  sl;
      -- Debug Interface 
      txPreCursor     : in  slv(4 downto 0)        := (others => '0');
      txPostCursor    : in  slv(4 downto 0)        := (others => '0');
      txDiffCtrl      : in  slv(3 downto 0)        := "1000";
      -- AXI-Lite Interface 
      axilClk         : in  sl                     := '0';
      axilRst         : in  sl                     := '0';
      axilReadMaster  : in  AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
      axilWriteSlave  : out AxiLiteWriteSlaveType);  
end Pgp2bGth7VarLatWrapper;

architecture mapping of Pgp2bGth7VarLatWrapper is

begin
   
   Pgp2bGth7VarLat_Inst : entity work.Pgp2bGth7VarLat
      generic map (
         TPD_G             => TPD_G,
         -- CPLL Configurations
         TX_PLL_G          => "CPLL",
         RX_PLL_G          => "CPLL",
         CPLL_REFCLK_SEL_G => "111",
         CPLL_FBDIV_G      => CPLL_FBDIV_G,
         CPLL_FBDIV_45_G   => CPLL_FBDIV_45_G,
         CPLL_REFCLK_DIV_G => CPLL_REFCLK_DIV_G,
         -- MGT Configurations
         RXOUT_DIV_G       => RXOUT_DIV_G,
         TXOUT_DIV_G       => TXOUT_DIV_G,
         RX_CLK25_DIV_G    => RX_CLK25_DIV_G,
         TX_CLK25_DIV_G    => TX_CLK25_DIV_G,
         RX_OS_CFG_G       => RX_OS_CFG_G,
         RXCDR_CFG_G       => RXCDR_CFG_G,
         RXDFEXYDEN_G      => RXDFEXYDEN_G,
         -- VC Configuration
         VC_INTERLEAVE_G   => VC_INTERLEAVE_G,
         PAYLOAD_CNT_TOP_G => PAYLOAD_CNT_TOP_G,
         NUM_VC_EN_G       => NUM_VC_EN_G,
         AXI_ERROR_RESP_G  => AXI_ERROR_RESP_G,
         TX_ENABLE_G       => TX_ENABLE_G,
         RX_ENABLE_G       => RX_ENABLE_G)          
      port map (
         -- GT Clocking
         stableClk        => pgpClk,
         gtCPllRefClk     => pgpClk,
         gtCPllLock       => open,
         gtQPllRefClk     => '0',
         gtQPllClk        => '0',
         gtQPllLock       => '1',
         gtQPllRefClkLost => '0',
         gtQPllReset      => open,
         -- GT Serial IO
         gtTxP            => gtTxP,
         gtTxN            => gtTxN,
         gtRxP            => gtRxP,
         gtRxN            => gtRxN,
         -- Tx Clocking
         pgpTxReset       => pgpRst,
         pgpTxRecClk      => open,
         pgpTxClk         => pgpClk,
         pgpTxMmcmReset   => open,
         pgpTxMmcmLocked  => '1',
         -- Rx clocking
         pgpRxReset       => pgpRst,
         pgpRxRecClk      => open,
         pgpRxClk         => pgpClk,
         pgpRxMmcmReset   => open,
         pgpRxMmcmLocked  => '1',
         -- Non VC TX Signals
         pgpTxIn          => pgpTxIn,
         pgpTxOut         => pgpTxOut,
         -- Non VC RX Signals
         pgpRxIn          => pgpRxIn,
         pgpRxOut         => pgpRxOut,
         -- Frame TX Interface
         pgpTxMasters     => pgpTxMasters,
         pgpTxSlaves      => pgpTxSlaves,
         -- Frame RX Interface
         pgpRxMasters     => pgpRxMasters,
         pgpRxCtrl        => pgpRxCtrl,
         -- Debug Interface 
         txPreCursor      => txPreCursor,
         txPostCursor     => txPostCursor,
         txDiffCtrl       => txDiffCtrl,
         -- AXI-Lite Interface 
         axilClk          => axilClk,
         axilRst          => axilRst,
         axilReadMaster   => axilReadMaster,
         axilReadSlave    => axilReadSlave,
         axilWriteMaster  => axilWriteMaster,
         axilWriteSlave   => axilWriteSlave);                 

end mapping;
