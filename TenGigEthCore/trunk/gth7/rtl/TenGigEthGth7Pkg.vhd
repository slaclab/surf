-------------------------------------------------------------------------------
-- Title      : GTH7's 10G Ethernet Package
-------------------------------------------------------------------------------
-- File       : TenGigEthGth7Pkg.vhd
-- Author     : Ryan Herbst <rherbst@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-02-12
-- Last update: 2015-03-30
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: GTH7's 10G Ethernet: constants & types.
-------------------------------------------------------------------------------
-- Copyright (c) 2015 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;
use work.TenGigEthPkg.all;

package TenGigEthGth7Pkg is

   type TenGigEthGth7Config is record
      softRst                   : sl;
      phyConfig                 : TenGigEthMacConfig;
      pma_pmd_type              : slv(2 downto 0);
      pma_loopback              : sl;
      pma_reset                 : sl;
      global_tx_disable         : sl;
      pcs_loopback              : sl;
      pcs_reset                 : sl;
      test_patt_a_b             : slv(57 downto 0);
      data_patt_sel             : sl;
      test_patt_sel             : sl;
      rx_test_patt_en           : sl;
      tx_test_patt_en           : sl;
      prbs31_tx_en              : sl;
      prbs31_rx_en              : sl;
      timer_ctrl                : slv(15 downto 0);
      set_pma_link_status       : sl;
      set_pcs_link_status       : sl;
      clear_pcs_status2         : sl;
      clear_test_patt_err_count : sl;
      gtEyeScanReset            : sl;
      gtEyeScanTrigger          : sl;
      gtRxCdrHold               : sl;
      gtTxPrbsForceErr          : sl;
      gtTxPolarity              : sl;
      gtRxPolarity              : sl;
      gtTxPmaReset              : sl;
      gtRxPmaReset              : sl;
      gtRxDfelpmReset           : sl;
      gtRxlpmen                 : sl;
      gtRxRate                  : slv(2 downto 0);
      gtTxPreCursor             : slv(4 downto 0);
      gtTxPostCursor            : slv(4 downto 0);
      gtTxDiffCtrl              : slv(3 downto 0);
   end record;
   constant TEN_GIG_ETH_GTH7_CONFIG_INIT_C : TenGigEthGth7Config := (
      softRst                   => '0',
      phyConfig                 => TEN_GIG_ETH_MAC_CONFIG_INIT_C,
      pma_pmd_type              => "111",  --111 = 10GBASE-SR (Wavelength:850 nm & OM3:300m)
      pma_loopback              => '0',
      pma_reset                 => '0',
      global_tx_disable         => '0',
      pcs_loopback              => '0',
      pcs_reset                 => '0',
      test_patt_a_b             => (others => '0'),
      data_patt_sel             => '0',
      test_patt_sel             => '0',
      rx_test_patt_en           => '0',
      tx_test_patt_en           => '0',
      prbs31_tx_en              => '0',
      prbs31_rx_en              => '0',
      timer_ctrl                => x"4C4B",
      set_pma_link_status       => '0',
      set_pcs_link_status       => '0',
      clear_pcs_status2         => '0',
      clear_test_patt_err_count => '0',
      gtEyeScanReset            => '0',
      gtEyeScanTrigger          => '0',
      gtRxCdrHold               => '0',
      gtTxPrbsForceErr          => '0',
      gtTxPolarity              => '0',
      gtRxPolarity              => '0',
      gtTxPmaReset              => '0',
      gtRxPmaReset              => '0',
      gtRxDfelpmReset           => '0',
      gtRxlpmen                 => '0',
      gtRxRate                  => "000",
      gtTxPreCursor             => "00000",
      gtTxPostCursor            => "00000",
      gtTxDiffCtrl              => "1110");    

   type TenGigEthGth7Status is record
      phyReady                : sl;
      phyStatus               : TenGigEthMacStatus;
      txDisable               : sl;
      sigDet                  : sl;
      txFault                 : sl;
      gtTxRst                 : sl;
      gtRxRst                 : sl;
      txUsrRdy                : sl;
      rstCntDone              : sl;
      qplllock                : sl;
      core_status             : slv(7 downto 0);
      txRstdone               : sl;
      rxRstdone               : sl;
      pma_link_status         : sl;
      rx_sig_det              : sl;
      pcs_rx_link_status      : sl;
      pcs_rx_locked           : sl;
      pcs_hiber               : sl;
      teng_pcs_rx_link_status : sl;
      pcs_err_block_count     : slv(7 downto 0);
      pcs_ber_count           : slv(5 downto 0);
      pcs_rx_hiber_lh         : sl;
      pcs_rx_locked_ll        : sl;
      pcs_test_patt_err_count : slv(15 downto 0);
      gtEyeScanDataError      : sl;
      gtTxBufStatus           : slv(1 downto 0);
      gtRxBufStatus           : slv(2 downto 0);
      gtRxPrbsErr             : sl;
      gtTxResetDone           : sl;
      gtRxResetDone           : sl;
      gtDmonitorOut           : slv(7 downto 0);
   end record;
   
end TenGigEthGth7Pkg;
