-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
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
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;


library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;
use surf.SsiPkg.all;

entity Caui4GtyIpWrapper is
   generic (
      TPD_G              : time     := 1 ns;
      SIM_SPEEDUP_G      : boolean  := false;
      REFCLK_TYPE_G      : boolean  := true;  -- false = 156.25 MHz, true = 161.1328125 MHz
      MAX_PAYLOAD_SIZE_G : positive := 8192);
   port (
      -- Stable Clock and Reset Reference
      stableClk    : in  sl;            -- 156.25 MHz
      stableRst    : in  sl;
      -- PHY Clock and Reset
      phyClk       : out sl;
      phyRst       : out sl;
      -- Rx PHY Interface
      phyRxMaster  : out AxiStreamMasterType;
      -- Tx PHY Interface
      phyTxMaster  : in  AxiStreamMasterType;
      phyTxSlave   : out AxiStreamSlaveType;
      -- Misc Debug Interfaces
      phyReady     : out sl;
      loopback     : in  slv(2 downto 0)       := (others => '0');
      rxPolarity   : in  slv(3 downto 0)       := (others => '0');
      txPolarity   : in  slv(3 downto 0)       := (others => '0');
      txDiffCtrl   : in  Slv5Array(3 downto 0) := (others => "11000");
      txPreCursor  : in  Slv5Array(3 downto 0) := (others => "00000");
      txPostCursor : in  Slv5Array(3 downto 0) := (others => "00000");
      -- GT FPGA Ports
      gtRefClkP    : in  sl;
      gtRefClkN    : in  sl;
      gtRxP        : in  slv(3 downto 0);
      gtRxN        : in  slv(3 downto 0);
      gtTxP        : out slv(3 downto 0);
      gtTxN        : out slv(3 downto 0));
end entity Caui4GtyIpWrapper;

architecture mapping of Caui4GtyIpWrapper is

   constant TX_FIFO_ADDR_WIDTH_C : positive := log2(MAX_PAYLOAD_SIZE_G/64)+1;

   component Caui4GtyIpCore156MHz
      port (
         gt_txp_out                           : out std_logic_vector(3 downto 0);
         gt_txn_out                           : out std_logic_vector(3 downto 0);
         gt_rxp_in                            : in  std_logic_vector(3 downto 0);
         gt_rxn_in                            : in  std_logic_vector(3 downto 0);
         gt_txusrclk2                         : out std_logic;
         gt_loopback_in                       : in  std_logic_vector(11 downto 0);
         gt_eyescanreset                      : in  std_logic_vector(3 downto 0);
         gt_eyescantrigger                    : in  std_logic_vector(3 downto 0);
         gt_rxcdrhold                         : in  std_logic_vector(3 downto 0);
         gt_rxpolarity                        : in  std_logic_vector(3 downto 0);
         gt_rxrate                            : in  std_logic_vector(11 downto 0);
         gt_txdiffctrl                        : in  std_logic_vector(19 downto 0);
         gt_txpolarity                        : in  std_logic_vector(3 downto 0);
         gt_txinhibit                         : in  std_logic_vector(3 downto 0);
         gt_txpippmen                         : in  std_logic_vector(3 downto 0);
         gt_txpippmsel                        : in  std_logic_vector(3 downto 0);
         gt_txpostcursor                      : in  std_logic_vector(19 downto 0);
         gt_txprbsforceerr                    : in  std_logic_vector(3 downto 0);
         gt_txprecursor                       : in  std_logic_vector(19 downto 0);
         gt_eyescandataerror                  : out std_logic_vector(3 downto 0);
         gt_ref_clk_out                       : out std_logic;
         gt_rxrecclkout                       : out std_logic_vector(3 downto 0);
         gt_powergoodout                      : out std_logic_vector(3 downto 0);
         gt_txbufstatus                       : out std_logic_vector(7 downto 0);
         gt_rxdfelpmreset                     : in  std_logic_vector(3 downto 0);
         gt_rxlpmen                           : in  std_logic_vector(3 downto 0);
         gt_rxprbscntreset                    : in  std_logic_vector(3 downto 0);
         gt_rxprbserr                         : out std_logic_vector(3 downto 0);
         gt_rxprbssel                         : in  std_logic_vector(15 downto 0);
         gt_rxresetdone                       : out std_logic_vector(3 downto 0);
         gt_txprbssel                         : in  std_logic_vector(15 downto 0);
         gt_txresetdone                       : out std_logic_vector(3 downto 0);
         gt_rxbufstatus                       : out std_logic_vector(11 downto 0);
         gtwiz_reset_tx_datapath              : in  std_logic;
         gtwiz_reset_rx_datapath              : in  std_logic;
         gt_drpclk                            : in  std_logic;
         gt0_drpdo                            : out std_logic_vector(15 downto 0);
         gt0_drprdy                           : out std_logic;
         gt0_drpen                            : in  std_logic;
         gt0_drpwe                            : in  std_logic;
         gt0_drpaddr                          : in  std_logic_vector(9 downto 0);
         gt0_drpdi                            : in  std_logic_vector(15 downto 0);
         gt1_drpdo                            : out std_logic_vector(15 downto 0);
         gt1_drprdy                           : out std_logic;
         gt1_drpen                            : in  std_logic;
         gt1_drpwe                            : in  std_logic;
         gt1_drpaddr                          : in  std_logic_vector(9 downto 0);
         gt1_drpdi                            : in  std_logic_vector(15 downto 0);
         gt2_drpdo                            : out std_logic_vector(15 downto 0);
         gt2_drprdy                           : out std_logic;
         gt2_drpen                            : in  std_logic;
         gt2_drpwe                            : in  std_logic;
         gt2_drpaddr                          : in  std_logic_vector(9 downto 0);
         gt2_drpdi                            : in  std_logic_vector(15 downto 0);
         gt3_drpdo                            : out std_logic_vector(15 downto 0);
         gt3_drprdy                           : out std_logic;
         gt3_drpen                            : in  std_logic;
         gt3_drpwe                            : in  std_logic;
         gt3_drpaddr                          : in  std_logic_vector(9 downto 0);
         gt3_drpdi                            : in  std_logic_vector(15 downto 0);
         ctl_tx_rsfec_enable                  : in  std_logic;
         ctl_rx_rsfec_enable                  : in  std_logic;
         ctl_rsfec_ieee_error_indication_mode : in  std_logic;
         ctl_rx_rsfec_enable_correction       : in  std_logic;
         ctl_rx_rsfec_enable_indication       : in  std_logic;
         stat_rx_rsfec_am_lock0               : out std_logic;
         stat_rx_rsfec_am_lock1               : out std_logic;
         stat_rx_rsfec_am_lock2               : out std_logic;
         stat_rx_rsfec_am_lock3               : out std_logic;
         stat_rx_rsfec_corrected_cw_inc       : out std_logic;
         stat_rx_rsfec_cw_inc                 : out std_logic;
         stat_rx_rsfec_err_count0_inc         : out std_logic_vector(2 downto 0);
         stat_rx_rsfec_err_count1_inc         : out std_logic_vector(2 downto 0);
         stat_rx_rsfec_err_count2_inc         : out std_logic_vector(2 downto 0);
         stat_rx_rsfec_err_count3_inc         : out std_logic_vector(2 downto 0);
         stat_rx_rsfec_hi_ser                 : out std_logic;
         stat_rx_rsfec_lane_alignment_status  : out std_logic;
         stat_rx_rsfec_lane_fill_0            : out std_logic_vector(13 downto 0);
         stat_rx_rsfec_lane_fill_1            : out std_logic_vector(13 downto 0);
         stat_rx_rsfec_lane_fill_2            : out std_logic_vector(13 downto 0);
         stat_rx_rsfec_lane_fill_3            : out std_logic_vector(13 downto 0);
         stat_rx_rsfec_lane_mapping           : out std_logic_vector(7 downto 0);
         stat_rx_rsfec_uncorrected_cw_inc     : out std_logic;
         sys_reset                            : in  std_logic;
         gt_ref_clk_p                         : in  std_logic;
         gt_ref_clk_n                         : in  std_logic;
         init_clk                             : in  std_logic;
         common0_drpaddr                      : in  std_logic_vector(15 downto 0);
         common0_drpdi                        : in  std_logic_vector(15 downto 0);
         common0_drpwe                        : in  std_logic;
         common0_drpen                        : in  std_logic;
         common0_drprdy                       : out std_logic;
         common0_drpdo                        : out std_logic_vector(15 downto 0);
         rx_axis_tvalid                       : out std_logic;
         rx_axis_tdata                        : out std_logic_vector(511 downto 0);
         rx_axis_tlast                        : out std_logic;
         rx_axis_tkeep                        : out std_logic_vector(63 downto 0);
         rx_axis_tuser                        : out std_logic;
         rx_otn_bip8_0                        : out std_logic_vector(7 downto 0);
         rx_otn_bip8_1                        : out std_logic_vector(7 downto 0);
         rx_otn_bip8_2                        : out std_logic_vector(7 downto 0);
         rx_otn_bip8_3                        : out std_logic_vector(7 downto 0);
         rx_otn_bip8_4                        : out std_logic_vector(7 downto 0);
         rx_otn_data_0                        : out std_logic_vector(65 downto 0);
         rx_otn_data_1                        : out std_logic_vector(65 downto 0);
         rx_otn_data_2                        : out std_logic_vector(65 downto 0);
         rx_otn_data_3                        : out std_logic_vector(65 downto 0);
         rx_otn_data_4                        : out std_logic_vector(65 downto 0);
         rx_otn_ena                           : out std_logic;
         rx_otn_lane0                         : out std_logic;
         rx_otn_vlmarker                      : out std_logic;
         rx_preambleout                       : out std_logic_vector(55 downto 0);
         usr_rx_reset                         : out std_logic;
         gt_rxusrclk2                         : out std_logic;
         stat_rx_aligned                      : out std_logic;
         stat_rx_aligned_err                  : out std_logic;
         stat_rx_bad_code                     : out std_logic_vector(2 downto 0);
         stat_rx_bad_fcs                      : out std_logic_vector(2 downto 0);
         stat_rx_bad_preamble                 : out std_logic;
         stat_rx_bad_sfd                      : out std_logic;
         stat_rx_bip_err_0                    : out std_logic;
         stat_rx_bip_err_1                    : out std_logic;
         stat_rx_bip_err_10                   : out std_logic;
         stat_rx_bip_err_11                   : out std_logic;
         stat_rx_bip_err_12                   : out std_logic;
         stat_rx_bip_err_13                   : out std_logic;
         stat_rx_bip_err_14                   : out std_logic;
         stat_rx_bip_err_15                   : out std_logic;
         stat_rx_bip_err_16                   : out std_logic;
         stat_rx_bip_err_17                   : out std_logic;
         stat_rx_bip_err_18                   : out std_logic;
         stat_rx_bip_err_19                   : out std_logic;
         stat_rx_bip_err_2                    : out std_logic;
         stat_rx_bip_err_3                    : out std_logic;
         stat_rx_bip_err_4                    : out std_logic;
         stat_rx_bip_err_5                    : out std_logic;
         stat_rx_bip_err_6                    : out std_logic;
         stat_rx_bip_err_7                    : out std_logic;
         stat_rx_bip_err_8                    : out std_logic;
         stat_rx_bip_err_9                    : out std_logic;
         stat_rx_block_lock                   : out std_logic_vector(19 downto 0);
         stat_rx_broadcast                    : out std_logic;
         stat_rx_fragment                     : out std_logic_vector(2 downto 0);
         stat_rx_framing_err_0                : out std_logic_vector(1 downto 0);
         stat_rx_framing_err_1                : out std_logic_vector(1 downto 0);
         stat_rx_framing_err_10               : out std_logic_vector(1 downto 0);
         stat_rx_framing_err_11               : out std_logic_vector(1 downto 0);
         stat_rx_framing_err_12               : out std_logic_vector(1 downto 0);
         stat_rx_framing_err_13               : out std_logic_vector(1 downto 0);
         stat_rx_framing_err_14               : out std_logic_vector(1 downto 0);
         stat_rx_framing_err_15               : out std_logic_vector(1 downto 0);
         stat_rx_framing_err_16               : out std_logic_vector(1 downto 0);
         stat_rx_framing_err_17               : out std_logic_vector(1 downto 0);
         stat_rx_framing_err_18               : out std_logic_vector(1 downto 0);
         stat_rx_framing_err_19               : out std_logic_vector(1 downto 0);
         stat_rx_framing_err_2                : out std_logic_vector(1 downto 0);
         stat_rx_framing_err_3                : out std_logic_vector(1 downto 0);
         stat_rx_framing_err_4                : out std_logic_vector(1 downto 0);
         stat_rx_framing_err_5                : out std_logic_vector(1 downto 0);
         stat_rx_framing_err_6                : out std_logic_vector(1 downto 0);
         stat_rx_framing_err_7                : out std_logic_vector(1 downto 0);
         stat_rx_framing_err_8                : out std_logic_vector(1 downto 0);
         stat_rx_framing_err_9                : out std_logic_vector(1 downto 0);
         stat_rx_framing_err_valid_0          : out std_logic;
         stat_rx_framing_err_valid_1          : out std_logic;
         stat_rx_framing_err_valid_10         : out std_logic;
         stat_rx_framing_err_valid_11         : out std_logic;
         stat_rx_framing_err_valid_12         : out std_logic;
         stat_rx_framing_err_valid_13         : out std_logic;
         stat_rx_framing_err_valid_14         : out std_logic;
         stat_rx_framing_err_valid_15         : out std_logic;
         stat_rx_framing_err_valid_16         : out std_logic;
         stat_rx_framing_err_valid_17         : out std_logic;
         stat_rx_framing_err_valid_18         : out std_logic;
         stat_rx_framing_err_valid_19         : out std_logic;
         stat_rx_framing_err_valid_2          : out std_logic;
         stat_rx_framing_err_valid_3          : out std_logic;
         stat_rx_framing_err_valid_4          : out std_logic;
         stat_rx_framing_err_valid_5          : out std_logic;
         stat_rx_framing_err_valid_6          : out std_logic;
         stat_rx_framing_err_valid_7          : out std_logic;
         stat_rx_framing_err_valid_8          : out std_logic;
         stat_rx_framing_err_valid_9          : out std_logic;
         stat_rx_got_signal_os                : out std_logic;
         stat_rx_hi_ber                       : out std_logic;
         stat_rx_inrangeerr                   : out std_logic;
         stat_rx_internal_local_fault         : out std_logic;
         stat_rx_jabber                       : out std_logic;
         stat_rx_local_fault                  : out std_logic;
         stat_rx_mf_err                       : out std_logic_vector(19 downto 0);
         stat_rx_mf_len_err                   : out std_logic_vector(19 downto 0);
         stat_rx_mf_repeat_err                : out std_logic_vector(19 downto 0);
         stat_rx_misaligned                   : out std_logic;
         stat_rx_multicast                    : out std_logic;
         stat_rx_oversize                     : out std_logic;
         stat_rx_packet_1024_1518_bytes       : out std_logic;
         stat_rx_packet_128_255_bytes         : out std_logic;
         stat_rx_packet_1519_1522_bytes       : out std_logic;
         stat_rx_packet_1523_1548_bytes       : out std_logic;
         stat_rx_packet_1549_2047_bytes       : out std_logic;
         stat_rx_packet_2048_4095_bytes       : out std_logic;
         stat_rx_packet_256_511_bytes         : out std_logic;
         stat_rx_packet_4096_8191_bytes       : out std_logic;
         stat_rx_packet_512_1023_bytes        : out std_logic;
         stat_rx_packet_64_bytes              : out std_logic;
         stat_rx_packet_65_127_bytes          : out std_logic;
         stat_rx_packet_8192_9215_bytes       : out std_logic;
         stat_rx_packet_bad_fcs               : out std_logic;
         stat_rx_packet_large                 : out std_logic;
         stat_rx_packet_small                 : out std_logic_vector(2 downto 0);
         ctl_rx_enable                        : in  std_logic;
         ctl_rx_force_resync                  : in  std_logic;
         ctl_rx_test_pattern                  : in  std_logic;
         core_rx_reset                        : in  std_logic;
         rx_clk                               : in  std_logic;
         stat_rx_received_local_fault         : out std_logic;
         stat_rx_remote_fault                 : out std_logic;
         stat_rx_status                       : out std_logic;
         stat_rx_stomped_fcs                  : out std_logic_vector(2 downto 0);
         stat_rx_synced                       : out std_logic_vector(19 downto 0);
         stat_rx_synced_err                   : out std_logic_vector(19 downto 0);
         stat_rx_test_pattern_mismatch        : out std_logic_vector(2 downto 0);
         stat_rx_toolong                      : out std_logic;
         stat_rx_total_bytes                  : out std_logic_vector(6 downto 0);
         stat_rx_total_good_bytes             : out std_logic_vector(13 downto 0);
         stat_rx_total_good_packets           : out std_logic;
         stat_rx_total_packets                : out std_logic_vector(2 downto 0);
         stat_rx_truncated                    : out std_logic;
         stat_rx_undersize                    : out std_logic_vector(2 downto 0);
         stat_rx_unicast                      : out std_logic;
         stat_rx_vlan                         : out std_logic;
         stat_rx_pcsl_demuxed                 : out std_logic_vector(19 downto 0);
         stat_rx_pcsl_number_0                : out std_logic_vector(4 downto 0);
         stat_rx_pcsl_number_1                : out std_logic_vector(4 downto 0);
         stat_rx_pcsl_number_10               : out std_logic_vector(4 downto 0);
         stat_rx_pcsl_number_11               : out std_logic_vector(4 downto 0);
         stat_rx_pcsl_number_12               : out std_logic_vector(4 downto 0);
         stat_rx_pcsl_number_13               : out std_logic_vector(4 downto 0);
         stat_rx_pcsl_number_14               : out std_logic_vector(4 downto 0);
         stat_rx_pcsl_number_15               : out std_logic_vector(4 downto 0);
         stat_rx_pcsl_number_16               : out std_logic_vector(4 downto 0);
         stat_rx_pcsl_number_17               : out std_logic_vector(4 downto 0);
         stat_rx_pcsl_number_18               : out std_logic_vector(4 downto 0);
         stat_rx_pcsl_number_19               : out std_logic_vector(4 downto 0);
         stat_rx_pcsl_number_2                : out std_logic_vector(4 downto 0);
         stat_rx_pcsl_number_3                : out std_logic_vector(4 downto 0);
         stat_rx_pcsl_number_4                : out std_logic_vector(4 downto 0);
         stat_rx_pcsl_number_5                : out std_logic_vector(4 downto 0);
         stat_rx_pcsl_number_6                : out std_logic_vector(4 downto 0);
         stat_rx_pcsl_number_7                : out std_logic_vector(4 downto 0);
         stat_rx_pcsl_number_8                : out std_logic_vector(4 downto 0);
         stat_rx_pcsl_number_9                : out std_logic_vector(4 downto 0);
         stat_tx_bad_fcs                      : out std_logic;
         stat_tx_broadcast                    : out std_logic;
         stat_tx_frame_error                  : out std_logic;
         stat_tx_local_fault                  : out std_logic;
         stat_tx_multicast                    : out std_logic;
         stat_tx_packet_1024_1518_bytes       : out std_logic;
         stat_tx_packet_128_255_bytes         : out std_logic;
         stat_tx_packet_1519_1522_bytes       : out std_logic;
         stat_tx_packet_1523_1548_bytes       : out std_logic;
         stat_tx_packet_1549_2047_bytes       : out std_logic;
         stat_tx_packet_2048_4095_bytes       : out std_logic;
         stat_tx_packet_256_511_bytes         : out std_logic;
         stat_tx_packet_4096_8191_bytes       : out std_logic;
         stat_tx_packet_512_1023_bytes        : out std_logic;
         stat_tx_packet_64_bytes              : out std_logic;
         stat_tx_packet_65_127_bytes          : out std_logic;
         stat_tx_packet_8192_9215_bytes       : out std_logic;
         stat_tx_packet_large                 : out std_logic;
         stat_tx_packet_small                 : out std_logic;
         stat_tx_total_bytes                  : out std_logic_vector(5 downto 0);
         stat_tx_total_good_bytes             : out std_logic_vector(13 downto 0);
         stat_tx_total_good_packets           : out std_logic;
         stat_tx_total_packets                : out std_logic;
         stat_tx_unicast                      : out std_logic;
         stat_tx_vlan                         : out std_logic;
         ctl_tx_enable                        : in  std_logic;
         ctl_tx_send_idle                     : in  std_logic;
         ctl_tx_send_rfi                      : in  std_logic;
         ctl_tx_send_lfi                      : in  std_logic;
         ctl_tx_test_pattern                  : in  std_logic;
         core_tx_reset                        : in  std_logic;
         tx_axis_tready                       : out std_logic;
         tx_axis_tvalid                       : in  std_logic;
         tx_axis_tdata                        : in  std_logic_vector(511 downto 0);
         tx_axis_tlast                        : in  std_logic;
         tx_axis_tkeep                        : in  std_logic_vector(63 downto 0);
         tx_axis_tuser                        : in  std_logic;
         tx_ovfout                            : out std_logic;
         tx_unfout                            : out std_logic;
         tx_preamblein                        : in  std_logic_vector(55 downto 0);
         usr_tx_reset                         : out std_logic;
         core_drp_reset                       : in  std_logic;
         drp_clk                              : in  std_logic;
         drp_addr                             : in  std_logic_vector(9 downto 0);
         drp_di                               : in  std_logic_vector(15 downto 0);
         drp_en                               : in  std_logic;
         drp_do                               : out std_logic_vector(15 downto 0);
         drp_rdy                              : out std_logic;
         drp_we                               : in  std_logic
         );
   end component;

   component Caui4GtyIpCore161MHz
      port (
         gt_txp_out                           : out std_logic_vector(3 downto 0);
         gt_txn_out                           : out std_logic_vector(3 downto 0);
         gt_rxp_in                            : in  std_logic_vector(3 downto 0);
         gt_rxn_in                            : in  std_logic_vector(3 downto 0);
         gt_txusrclk2                         : out std_logic;
         gt_loopback_in                       : in  std_logic_vector(11 downto 0);
         gt_eyescanreset                      : in  std_logic_vector(3 downto 0);
         gt_eyescantrigger                    : in  std_logic_vector(3 downto 0);
         gt_rxcdrhold                         : in  std_logic_vector(3 downto 0);
         gt_rxpolarity                        : in  std_logic_vector(3 downto 0);
         gt_rxrate                            : in  std_logic_vector(11 downto 0);
         gt_txdiffctrl                        : in  std_logic_vector(19 downto 0);
         gt_txpolarity                        : in  std_logic_vector(3 downto 0);
         gt_txinhibit                         : in  std_logic_vector(3 downto 0);
         gt_txpippmen                         : in  std_logic_vector(3 downto 0);
         gt_txpippmsel                        : in  std_logic_vector(3 downto 0);
         gt_txpostcursor                      : in  std_logic_vector(19 downto 0);
         gt_txprbsforceerr                    : in  std_logic_vector(3 downto 0);
         gt_txprecursor                       : in  std_logic_vector(19 downto 0);
         gt_eyescandataerror                  : out std_logic_vector(3 downto 0);
         gt_ref_clk_out                       : out std_logic;
         gt_rxrecclkout                       : out std_logic_vector(3 downto 0);
         gt_powergoodout                      : out std_logic_vector(3 downto 0);
         gt_txbufstatus                       : out std_logic_vector(7 downto 0);
         gt_rxdfelpmreset                     : in  std_logic_vector(3 downto 0);
         gt_rxlpmen                           : in  std_logic_vector(3 downto 0);
         gt_rxprbscntreset                    : in  std_logic_vector(3 downto 0);
         gt_rxprbserr                         : out std_logic_vector(3 downto 0);
         gt_rxprbssel                         : in  std_logic_vector(15 downto 0);
         gt_rxresetdone                       : out std_logic_vector(3 downto 0);
         gt_txprbssel                         : in  std_logic_vector(15 downto 0);
         gt_txresetdone                       : out std_logic_vector(3 downto 0);
         gt_rxbufstatus                       : out std_logic_vector(11 downto 0);
         gtwiz_reset_tx_datapath              : in  std_logic;
         gtwiz_reset_rx_datapath              : in  std_logic;
         gt_drpclk                            : in  std_logic;
         gt0_drpdo                            : out std_logic_vector(15 downto 0);
         gt0_drprdy                           : out std_logic;
         gt0_drpen                            : in  std_logic;
         gt0_drpwe                            : in  std_logic;
         gt0_drpaddr                          : in  std_logic_vector(9 downto 0);
         gt0_drpdi                            : in  std_logic_vector(15 downto 0);
         gt1_drpdo                            : out std_logic_vector(15 downto 0);
         gt1_drprdy                           : out std_logic;
         gt1_drpen                            : in  std_logic;
         gt1_drpwe                            : in  std_logic;
         gt1_drpaddr                          : in  std_logic_vector(9 downto 0);
         gt1_drpdi                            : in  std_logic_vector(15 downto 0);
         gt2_drpdo                            : out std_logic_vector(15 downto 0);
         gt2_drprdy                           : out std_logic;
         gt2_drpen                            : in  std_logic;
         gt2_drpwe                            : in  std_logic;
         gt2_drpaddr                          : in  std_logic_vector(9 downto 0);
         gt2_drpdi                            : in  std_logic_vector(15 downto 0);
         gt3_drpdo                            : out std_logic_vector(15 downto 0);
         gt3_drprdy                           : out std_logic;
         gt3_drpen                            : in  std_logic;
         gt3_drpwe                            : in  std_logic;
         gt3_drpaddr                          : in  std_logic_vector(9 downto 0);
         gt3_drpdi                            : in  std_logic_vector(15 downto 0);
         ctl_tx_rsfec_enable                  : in  std_logic;
         ctl_rx_rsfec_enable                  : in  std_logic;
         ctl_rsfec_ieee_error_indication_mode : in  std_logic;
         ctl_rx_rsfec_enable_correction       : in  std_logic;
         ctl_rx_rsfec_enable_indication       : in  std_logic;
         stat_rx_rsfec_am_lock0               : out std_logic;
         stat_rx_rsfec_am_lock1               : out std_logic;
         stat_rx_rsfec_am_lock2               : out std_logic;
         stat_rx_rsfec_am_lock3               : out std_logic;
         stat_rx_rsfec_corrected_cw_inc       : out std_logic;
         stat_rx_rsfec_cw_inc                 : out std_logic;
         stat_rx_rsfec_err_count0_inc         : out std_logic_vector(2 downto 0);
         stat_rx_rsfec_err_count1_inc         : out std_logic_vector(2 downto 0);
         stat_rx_rsfec_err_count2_inc         : out std_logic_vector(2 downto 0);
         stat_rx_rsfec_err_count3_inc         : out std_logic_vector(2 downto 0);
         stat_rx_rsfec_hi_ser                 : out std_logic;
         stat_rx_rsfec_lane_alignment_status  : out std_logic;
         stat_rx_rsfec_lane_fill_0            : out std_logic_vector(13 downto 0);
         stat_rx_rsfec_lane_fill_1            : out std_logic_vector(13 downto 0);
         stat_rx_rsfec_lane_fill_2            : out std_logic_vector(13 downto 0);
         stat_rx_rsfec_lane_fill_3            : out std_logic_vector(13 downto 0);
         stat_rx_rsfec_lane_mapping           : out std_logic_vector(7 downto 0);
         stat_rx_rsfec_uncorrected_cw_inc     : out std_logic;
         sys_reset                            : in  std_logic;
         gt_ref_clk_p                         : in  std_logic;
         gt_ref_clk_n                         : in  std_logic;
         init_clk                             : in  std_logic;
         common0_drpaddr                      : in  std_logic_vector(15 downto 0);
         common0_drpdi                        : in  std_logic_vector(15 downto 0);
         common0_drpwe                        : in  std_logic;
         common0_drpen                        : in  std_logic;
         common0_drprdy                       : out std_logic;
         common0_drpdo                        : out std_logic_vector(15 downto 0);
         rx_axis_tvalid                       : out std_logic;
         rx_axis_tdata                        : out std_logic_vector(511 downto 0);
         rx_axis_tlast                        : out std_logic;
         rx_axis_tkeep                        : out std_logic_vector(63 downto 0);
         rx_axis_tuser                        : out std_logic;
         rx_otn_bip8_0                        : out std_logic_vector(7 downto 0);
         rx_otn_bip8_1                        : out std_logic_vector(7 downto 0);
         rx_otn_bip8_2                        : out std_logic_vector(7 downto 0);
         rx_otn_bip8_3                        : out std_logic_vector(7 downto 0);
         rx_otn_bip8_4                        : out std_logic_vector(7 downto 0);
         rx_otn_data_0                        : out std_logic_vector(65 downto 0);
         rx_otn_data_1                        : out std_logic_vector(65 downto 0);
         rx_otn_data_2                        : out std_logic_vector(65 downto 0);
         rx_otn_data_3                        : out std_logic_vector(65 downto 0);
         rx_otn_data_4                        : out std_logic_vector(65 downto 0);
         rx_otn_ena                           : out std_logic;
         rx_otn_lane0                         : out std_logic;
         rx_otn_vlmarker                      : out std_logic;
         rx_preambleout                       : out std_logic_vector(55 downto 0);
         usr_rx_reset                         : out std_logic;
         gt_rxusrclk2                         : out std_logic;
         stat_rx_aligned                      : out std_logic;
         stat_rx_aligned_err                  : out std_logic;
         stat_rx_bad_code                     : out std_logic_vector(2 downto 0);
         stat_rx_bad_fcs                      : out std_logic_vector(2 downto 0);
         stat_rx_bad_preamble                 : out std_logic;
         stat_rx_bad_sfd                      : out std_logic;
         stat_rx_bip_err_0                    : out std_logic;
         stat_rx_bip_err_1                    : out std_logic;
         stat_rx_bip_err_10                   : out std_logic;
         stat_rx_bip_err_11                   : out std_logic;
         stat_rx_bip_err_12                   : out std_logic;
         stat_rx_bip_err_13                   : out std_logic;
         stat_rx_bip_err_14                   : out std_logic;
         stat_rx_bip_err_15                   : out std_logic;
         stat_rx_bip_err_16                   : out std_logic;
         stat_rx_bip_err_17                   : out std_logic;
         stat_rx_bip_err_18                   : out std_logic;
         stat_rx_bip_err_19                   : out std_logic;
         stat_rx_bip_err_2                    : out std_logic;
         stat_rx_bip_err_3                    : out std_logic;
         stat_rx_bip_err_4                    : out std_logic;
         stat_rx_bip_err_5                    : out std_logic;
         stat_rx_bip_err_6                    : out std_logic;
         stat_rx_bip_err_7                    : out std_logic;
         stat_rx_bip_err_8                    : out std_logic;
         stat_rx_bip_err_9                    : out std_logic;
         stat_rx_block_lock                   : out std_logic_vector(19 downto 0);
         stat_rx_broadcast                    : out std_logic;
         stat_rx_fragment                     : out std_logic_vector(2 downto 0);
         stat_rx_framing_err_0                : out std_logic_vector(1 downto 0);
         stat_rx_framing_err_1                : out std_logic_vector(1 downto 0);
         stat_rx_framing_err_10               : out std_logic_vector(1 downto 0);
         stat_rx_framing_err_11               : out std_logic_vector(1 downto 0);
         stat_rx_framing_err_12               : out std_logic_vector(1 downto 0);
         stat_rx_framing_err_13               : out std_logic_vector(1 downto 0);
         stat_rx_framing_err_14               : out std_logic_vector(1 downto 0);
         stat_rx_framing_err_15               : out std_logic_vector(1 downto 0);
         stat_rx_framing_err_16               : out std_logic_vector(1 downto 0);
         stat_rx_framing_err_17               : out std_logic_vector(1 downto 0);
         stat_rx_framing_err_18               : out std_logic_vector(1 downto 0);
         stat_rx_framing_err_19               : out std_logic_vector(1 downto 0);
         stat_rx_framing_err_2                : out std_logic_vector(1 downto 0);
         stat_rx_framing_err_3                : out std_logic_vector(1 downto 0);
         stat_rx_framing_err_4                : out std_logic_vector(1 downto 0);
         stat_rx_framing_err_5                : out std_logic_vector(1 downto 0);
         stat_rx_framing_err_6                : out std_logic_vector(1 downto 0);
         stat_rx_framing_err_7                : out std_logic_vector(1 downto 0);
         stat_rx_framing_err_8                : out std_logic_vector(1 downto 0);
         stat_rx_framing_err_9                : out std_logic_vector(1 downto 0);
         stat_rx_framing_err_valid_0          : out std_logic;
         stat_rx_framing_err_valid_1          : out std_logic;
         stat_rx_framing_err_valid_10         : out std_logic;
         stat_rx_framing_err_valid_11         : out std_logic;
         stat_rx_framing_err_valid_12         : out std_logic;
         stat_rx_framing_err_valid_13         : out std_logic;
         stat_rx_framing_err_valid_14         : out std_logic;
         stat_rx_framing_err_valid_15         : out std_logic;
         stat_rx_framing_err_valid_16         : out std_logic;
         stat_rx_framing_err_valid_17         : out std_logic;
         stat_rx_framing_err_valid_18         : out std_logic;
         stat_rx_framing_err_valid_19         : out std_logic;
         stat_rx_framing_err_valid_2          : out std_logic;
         stat_rx_framing_err_valid_3          : out std_logic;
         stat_rx_framing_err_valid_4          : out std_logic;
         stat_rx_framing_err_valid_5          : out std_logic;
         stat_rx_framing_err_valid_6          : out std_logic;
         stat_rx_framing_err_valid_7          : out std_logic;
         stat_rx_framing_err_valid_8          : out std_logic;
         stat_rx_framing_err_valid_9          : out std_logic;
         stat_rx_got_signal_os                : out std_logic;
         stat_rx_hi_ber                       : out std_logic;
         stat_rx_inrangeerr                   : out std_logic;
         stat_rx_internal_local_fault         : out std_logic;
         stat_rx_jabber                       : out std_logic;
         stat_rx_local_fault                  : out std_logic;
         stat_rx_mf_err                       : out std_logic_vector(19 downto 0);
         stat_rx_mf_len_err                   : out std_logic_vector(19 downto 0);
         stat_rx_mf_repeat_err                : out std_logic_vector(19 downto 0);
         stat_rx_misaligned                   : out std_logic;
         stat_rx_multicast                    : out std_logic;
         stat_rx_oversize                     : out std_logic;
         stat_rx_packet_1024_1518_bytes       : out std_logic;
         stat_rx_packet_128_255_bytes         : out std_logic;
         stat_rx_packet_1519_1522_bytes       : out std_logic;
         stat_rx_packet_1523_1548_bytes       : out std_logic;
         stat_rx_packet_1549_2047_bytes       : out std_logic;
         stat_rx_packet_2048_4095_bytes       : out std_logic;
         stat_rx_packet_256_511_bytes         : out std_logic;
         stat_rx_packet_4096_8191_bytes       : out std_logic;
         stat_rx_packet_512_1023_bytes        : out std_logic;
         stat_rx_packet_64_bytes              : out std_logic;
         stat_rx_packet_65_127_bytes          : out std_logic;
         stat_rx_packet_8192_9215_bytes       : out std_logic;
         stat_rx_packet_bad_fcs               : out std_logic;
         stat_rx_packet_large                 : out std_logic;
         stat_rx_packet_small                 : out std_logic_vector(2 downto 0);
         ctl_rx_enable                        : in  std_logic;
         ctl_rx_force_resync                  : in  std_logic;
         ctl_rx_test_pattern                  : in  std_logic;
         core_rx_reset                        : in  std_logic;
         rx_clk                               : in  std_logic;
         stat_rx_received_local_fault         : out std_logic;
         stat_rx_remote_fault                 : out std_logic;
         stat_rx_status                       : out std_logic;
         stat_rx_stomped_fcs                  : out std_logic_vector(2 downto 0);
         stat_rx_synced                       : out std_logic_vector(19 downto 0);
         stat_rx_synced_err                   : out std_logic_vector(19 downto 0);
         stat_rx_test_pattern_mismatch        : out std_logic_vector(2 downto 0);
         stat_rx_toolong                      : out std_logic;
         stat_rx_total_bytes                  : out std_logic_vector(6 downto 0);
         stat_rx_total_good_bytes             : out std_logic_vector(13 downto 0);
         stat_rx_total_good_packets           : out std_logic;
         stat_rx_total_packets                : out std_logic_vector(2 downto 0);
         stat_rx_truncated                    : out std_logic;
         stat_rx_undersize                    : out std_logic_vector(2 downto 0);
         stat_rx_unicast                      : out std_logic;
         stat_rx_vlan                         : out std_logic;
         stat_rx_pcsl_demuxed                 : out std_logic_vector(19 downto 0);
         stat_rx_pcsl_number_0                : out std_logic_vector(4 downto 0);
         stat_rx_pcsl_number_1                : out std_logic_vector(4 downto 0);
         stat_rx_pcsl_number_10               : out std_logic_vector(4 downto 0);
         stat_rx_pcsl_number_11               : out std_logic_vector(4 downto 0);
         stat_rx_pcsl_number_12               : out std_logic_vector(4 downto 0);
         stat_rx_pcsl_number_13               : out std_logic_vector(4 downto 0);
         stat_rx_pcsl_number_14               : out std_logic_vector(4 downto 0);
         stat_rx_pcsl_number_15               : out std_logic_vector(4 downto 0);
         stat_rx_pcsl_number_16               : out std_logic_vector(4 downto 0);
         stat_rx_pcsl_number_17               : out std_logic_vector(4 downto 0);
         stat_rx_pcsl_number_18               : out std_logic_vector(4 downto 0);
         stat_rx_pcsl_number_19               : out std_logic_vector(4 downto 0);
         stat_rx_pcsl_number_2                : out std_logic_vector(4 downto 0);
         stat_rx_pcsl_number_3                : out std_logic_vector(4 downto 0);
         stat_rx_pcsl_number_4                : out std_logic_vector(4 downto 0);
         stat_rx_pcsl_number_5                : out std_logic_vector(4 downto 0);
         stat_rx_pcsl_number_6                : out std_logic_vector(4 downto 0);
         stat_rx_pcsl_number_7                : out std_logic_vector(4 downto 0);
         stat_rx_pcsl_number_8                : out std_logic_vector(4 downto 0);
         stat_rx_pcsl_number_9                : out std_logic_vector(4 downto 0);
         stat_tx_bad_fcs                      : out std_logic;
         stat_tx_broadcast                    : out std_logic;
         stat_tx_frame_error                  : out std_logic;
         stat_tx_local_fault                  : out std_logic;
         stat_tx_multicast                    : out std_logic;
         stat_tx_packet_1024_1518_bytes       : out std_logic;
         stat_tx_packet_128_255_bytes         : out std_logic;
         stat_tx_packet_1519_1522_bytes       : out std_logic;
         stat_tx_packet_1523_1548_bytes       : out std_logic;
         stat_tx_packet_1549_2047_bytes       : out std_logic;
         stat_tx_packet_2048_4095_bytes       : out std_logic;
         stat_tx_packet_256_511_bytes         : out std_logic;
         stat_tx_packet_4096_8191_bytes       : out std_logic;
         stat_tx_packet_512_1023_bytes        : out std_logic;
         stat_tx_packet_64_bytes              : out std_logic;
         stat_tx_packet_65_127_bytes          : out std_logic;
         stat_tx_packet_8192_9215_bytes       : out std_logic;
         stat_tx_packet_large                 : out std_logic;
         stat_tx_packet_small                 : out std_logic;
         stat_tx_total_bytes                  : out std_logic_vector(5 downto 0);
         stat_tx_total_good_bytes             : out std_logic_vector(13 downto 0);
         stat_tx_total_good_packets           : out std_logic;
         stat_tx_total_packets                : out std_logic;
         stat_tx_unicast                      : out std_logic;
         stat_tx_vlan                         : out std_logic;
         ctl_tx_enable                        : in  std_logic;
         ctl_tx_send_idle                     : in  std_logic;
         ctl_tx_send_rfi                      : in  std_logic;
         ctl_tx_send_lfi                      : in  std_logic;
         ctl_tx_test_pattern                  : in  std_logic;
         core_tx_reset                        : in  std_logic;
         tx_axis_tready                       : out std_logic;
         tx_axis_tvalid                       : in  std_logic;
         tx_axis_tdata                        : in  std_logic_vector(511 downto 0);
         tx_axis_tlast                        : in  std_logic;
         tx_axis_tkeep                        : in  std_logic_vector(63 downto 0);
         tx_axis_tuser                        : in  std_logic;
         tx_ovfout                            : out std_logic;
         tx_unfout                            : out std_logic;
         tx_preamblein                        : in  std_logic_vector(55 downto 0);
         usr_tx_reset                         : out std_logic;
         core_drp_reset                       : in  std_logic;
         drp_clk                              : in  std_logic;
         drp_addr                             : in  std_logic_vector(9 downto 0);
         drp_di                               : in  std_logic_vector(15 downto 0);
         drp_en                               : in  std_logic;
         drp_do                               : out std_logic_vector(15 downto 0);
         drp_rdy                              : out std_logic;
         drp_we                               : in  std_logic
         );
   end component;

   type StateType is (
      INIT_S,
      WAIT_S,
      DONE_S);

   type RegType is record
      phyRdy          : sl;
      ctl_rx_enable   : sl;
      ctl_tx_enable   : sl;
      ctl_tx_send_rfi : sl;
      state           : StateType;
   end record RegType;
   constant REG_INIT_C : RegType := (
      phyRdy          => '0',
      ctl_rx_enable   => '0',
      ctl_tx_enable   => '0',
      ctl_tx_send_rfi => '0',
      state           => INIT_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal txusrclk2    : sl;
   signal usr_tx_reset : sl;
   signal usr_rx_reset : sl;

   signal stat_rx_aligned     : sl;
   signal stat_rx_aligned_err : sl;

   signal phyClock : sl;
   signal phyReset : sl;

   signal gtLoopback     : slv(11 downto 0);
   signal gtTxdiffctrl   : slv(19 downto 0);
   signal gtTxPreCursor  : slv(19 downto 0);
   signal gtTxPostCursor : slv(19 downto 0);
   signal stableReset    : sl;

   signal rxAxis   : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal rxMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal txMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal txSlave  : AxiStreamSlaveType;

begin

   assert (isPowerOf2(MAX_PAYLOAD_SIZE_G) = true)
      report "MAX_PAYLOAD_SIZE_G must be power of 2" severity failure;

   U_PwrUpRst : entity surf.PwrUpRst
      generic map(
         TPD_G         => TPD_G,
         SIM_SPEEDUP_G => SIM_SPEEDUP_G)
      port map (
         arst   => stableRst,
         clk    => stableClk,
         rstOut => stableReset);

   U_phyClk : entity surf.ClockManagerUltraScale
      generic map(
         TPD_G             => TPD_G,
         TYPE_G            => "PLL",
         INPUT_BUFG_G      => false,
         FB_BUFG_G         => true,
         RST_IN_POLARITY_G => '1',
         NUM_CLOCKS_G      => 1,
         -- MMCM attributes
         CLKIN_PERIOD_G    => 3.1,      -- 322.58 MHz
         DIVCLK_DIVIDE_G   => 4,
         CLKFBOUT_MULT_G   => 17,       -- 1.371 GHz = 17 x 322.58 MHz / 4
         CLKOUT0_DIVIDE_G  => 7)        -- 195.85 MHz = 1.371 GHz / 7
      port map(
         -- Clock Input
         clkIn     => txusrclk2,
         rstIn     => usr_tx_reset,
         -- Clock Outputs
         clkOut(0) => phyClock,
         -- Reset Outputs
         rstOut(0) => phyReset);

   phyClk <= phyClock;
   phyRst <= phyReset;

   gtLoopback     <= loopback & loopback & loopback & loopback;
   gtTxdiffctrl   <= txDiffCtrl(3) & txDiffCtrl(2) & txDiffCtrl(1) & txDiffCtrl(0);
   gtTxPreCursor  <= txPreCursor(3) & txPreCursor(2) & txPreCursor(1) & txPreCursor(0);
   gtTxPostCursor <= txPostCursor(3) & txPostCursor(2) & txPostCursor(1) & txPostCursor(0);

   RX_AXIS : process (txusrclk2) is
      variable master : AxiStreamMasterType;
   begin
      if rising_edge(txusrclk2) then
         -- Init
         master := rxAxis;
         -- Set the EOFE of all bytes
         for i in 63 downto 1 loop
            master.tUser(8*i) := rxAxis.tUser(0);
         end loop;
         -- Check if not aligned
         if (stat_rx_aligned_err = '1') or (stat_rx_aligned = '0') then
            master.tValid := '0';
         end if;
         -- Outputs
         rxMaster <= master after TPD_G;
      end if;
   end process;

   U_RX_FIFO : entity surf.AxiStreamFifoV2
      generic map (
         -- General Configurations
         TPD_G               => TPD_G,
         SLAVE_READY_EN_G    => false,
         INT_PIPE_STAGES_G   => 0,
         PIPE_STAGES_G       => 0,
         -- FIFO configurations
         MEMORY_TYPE_G       => "block",
         GEN_SYNC_FIFO_G     => false,
         FIFO_ADDR_WIDTH_G   => 9,
         -- AXI Stream Port Configurations
         SLAVE_AXI_CONFIG_G  => ssiAxiStreamConfig(64),
         MASTER_AXI_CONFIG_G => ssiAxiStreamConfig(64))
      port map (
         -- Slave Port
         sAxisClk    => txusrclk2,
         sAxisRst    => usr_rx_reset,
         sAxisMaster => rxMaster,
         -- Master Port
         mAxisClk    => phyClock,
         mAxisRst    => phyReset,
         mAxisMaster => phyRxMaster,
         mAxisSlave  => AXI_STREAM_SLAVE_FORCE_C);

   U_TX_FIFO : entity surf.AxiStreamFifoV2
      generic map (
         -- General Configurations
         TPD_G               => TPD_G,
         SLAVE_READY_EN_G    => true,
         VALID_THOLD_G       => 0,  -- HOLD until full packet without gaps can be sent
         INT_PIPE_STAGES_G   => 0,
         PIPE_STAGES_G       => 1,      -- Help with making timing
         -- FIFO configurations
         MEMORY_TYPE_G       => ite((TX_FIFO_ADDR_WIDTH_C > 5), "block", "distributed"),
         GEN_SYNC_FIFO_G     => false,
         FIFO_ADDR_WIDTH_G   => TX_FIFO_ADDR_WIDTH_C,
         -- AXI Stream Port Configurations
         SLAVE_AXI_CONFIG_G  => ssiAxiStreamConfig(64),
         MASTER_AXI_CONFIG_G => ssiAxiStreamConfig(64))
      port map (
         -- Slave Port
         sAxisClk    => phyClock,
         sAxisRst    => phyReset,
         sAxisMaster => phyTxMaster,
         sAxisSlave  => phyTxSlave,
         -- Master Port
         mAxisClk    => txusrclk2,
         mAxisRst    => usr_tx_reset,
         mAxisMaster => txMaster,
         mAxisSlave  => txSlave);

   USE_REFCLK156MHz : if (REFCLK_TYPE_G = false) generate
      U_CAUI4 : Caui4GtyIpCore156MHz
         port map (
            gt_txp_out                           => gtTxP,
            gt_txn_out                           => gtTxN,
            gt_rxp_in                            => gtRxP,
            gt_rxn_in                            => gtRxN,
            gt_txusrclk2                         => txusrclk2,
            gt_loopback_in                       => gtLoopback,
            gt_eyescanreset                      => (others => '0'),
            gt_eyescantrigger                    => (others => '0'),
            gt_rxcdrhold                         => (others => '0'),
            gt_rxpolarity                        => rxPolarity(3 downto 0),
            gt_rxrate                            => (others => '0'),
            gt_txdiffctrl                        => gtTxdiffctrl,
            gt_txpolarity                        => txPolarity(3 downto 0),
            gt_txinhibit                         => (others => '0'),
            gt_txpippmen                         => (others => '0'),
            gt_txpippmsel                        => (others => '1'),  -- Same as Caui4GtyIpCore_trans_debug example design
            gt_txpostcursor                      => gtTxPostCursor,
            gt_txprbsforceerr                    => (others => '0'),
            gt_txprecursor                       => gtTxPreCursor,
            gt_eyescandataerror                  => open,
            gt_ref_clk_out                       => open,
            gt_rxrecclkout                       => open,
            gt_powergoodout                      => open,
            gt_txbufstatus                       => open,
            gt_rxdfelpmreset                     => (others => '0'),
            gt_rxlpmen                           => (others => '1'),  -- Same as Caui4GtyIpCore_trans_debug example design
            gt_rxprbscntreset                    => (others => '0'),
            gt_rxprbserr                         => open,
            gt_rxprbssel                         => (others => '0'),
            gt_rxresetdone                       => open,
            gt_txprbssel                         => (others => '0'),
            gt_txresetdone                       => open,
            gt_rxbufstatus                       => open,
            gtwiz_reset_tx_datapath              => stableReset,
            gtwiz_reset_rx_datapath              => stableReset,
            gt_drpclk                            => stableClk,
            gt0_drpdo                            => open,
            gt0_drprdy                           => open,
            gt0_drpen                            => '0',
            gt0_drpwe                            => '0',
            gt0_drpaddr                          => (others => '0'),
            gt0_drpdi                            => (others => '0'),
            gt1_drpdo                            => open,
            gt1_drprdy                           => open,
            gt1_drpen                            => '0',
            gt1_drpwe                            => '0',
            gt1_drpaddr                          => (others => '0'),
            gt1_drpdi                            => (others => '0'),
            gt2_drpdo                            => open,
            gt2_drprdy                           => open,
            gt2_drpen                            => '0',
            gt2_drpwe                            => '0',
            gt2_drpaddr                          => (others => '0'),
            gt2_drpdi                            => (others => '0'),
            gt3_drpdo                            => open,
            gt3_drprdy                           => open,
            gt3_drpen                            => '0',
            gt3_drpwe                            => '0',
            gt3_drpaddr                          => (others => '0'),
            gt3_drpdi                            => (others => '0'),
            ctl_tx_rsfec_enable                  => '1',
            ctl_rx_rsfec_enable                  => '1',
            ctl_rsfec_ieee_error_indication_mode => '1',
            ctl_rx_rsfec_enable_correction       => '1',
            ctl_rx_rsfec_enable_indication       => '1',
            stat_rx_rsfec_am_lock0               => open,
            stat_rx_rsfec_am_lock1               => open,
            stat_rx_rsfec_am_lock2               => open,
            stat_rx_rsfec_am_lock3               => open,
            stat_rx_rsfec_corrected_cw_inc       => open,
            stat_rx_rsfec_cw_inc                 => open,
            stat_rx_rsfec_err_count0_inc         => open,
            stat_rx_rsfec_err_count1_inc         => open,
            stat_rx_rsfec_err_count2_inc         => open,
            stat_rx_rsfec_err_count3_inc         => open,
            stat_rx_rsfec_hi_ser                 => open,
            stat_rx_rsfec_lane_alignment_status  => stat_rx_aligned,
            stat_rx_rsfec_lane_fill_0            => open,
            stat_rx_rsfec_lane_fill_1            => open,
            stat_rx_rsfec_lane_fill_2            => open,
            stat_rx_rsfec_lane_fill_3            => open,
            stat_rx_rsfec_lane_mapping           => open,
            stat_rx_rsfec_uncorrected_cw_inc     => stat_rx_aligned_err,
            sys_reset                            => stableReset,
            gt_ref_clk_p                         => gtRefClkP,
            gt_ref_clk_n                         => gtRefClkN,
            init_clk                             => stableClk,
            common0_drpaddr                      => (others => '0'),
            common0_drpdi                        => (others => '0'),
            common0_drpwe                        => '0',
            common0_drpen                        => '0',
            common0_drprdy                       => open,
            common0_drpdo                        => open,
            rx_axis_tvalid                       => rxAxis.tvalid,
            rx_axis_tdata                        => rxAxis.tdata(511 downto 0),
            rx_axis_tlast                        => rxAxis.tlast,
            rx_axis_tkeep                        => rxAxis.tkeep,
            rx_axis_tuser                        => rxAxis.tuser(0),
            rx_otn_bip8_0                        => open,
            rx_otn_bip8_1                        => open,
            rx_otn_bip8_2                        => open,
            rx_otn_bip8_3                        => open,
            rx_otn_bip8_4                        => open,
            rx_otn_data_0                        => open,
            rx_otn_data_1                        => open,
            rx_otn_data_2                        => open,
            rx_otn_data_3                        => open,
            rx_otn_data_4                        => open,
            rx_preambleout                       => open,
            usr_rx_reset                         => usr_rx_reset,
            gt_rxusrclk2                         => open,
            -- stat_rx_aligned                      => stat_rx_aligned,
            -- stat_rx_aligned_err                  => stat_rx_aligned_err,
            stat_rx_bad_code                     => open,
            stat_rx_bad_fcs                      => open,
            stat_rx_block_lock                   => open,
            stat_rx_fragment                     => open,
            stat_rx_framing_err_0                => open,
            stat_rx_framing_err_1                => open,
            stat_rx_framing_err_10               => open,
            stat_rx_framing_err_11               => open,
            stat_rx_framing_err_12               => open,
            stat_rx_framing_err_13               => open,
            stat_rx_framing_err_14               => open,
            stat_rx_framing_err_15               => open,
            stat_rx_framing_err_16               => open,
            stat_rx_framing_err_17               => open,
            stat_rx_framing_err_18               => open,
            stat_rx_framing_err_19               => open,
            stat_rx_framing_err_2                => open,
            stat_rx_framing_err_3                => open,
            stat_rx_framing_err_4                => open,
            stat_rx_framing_err_5                => open,
            stat_rx_framing_err_6                => open,
            stat_rx_framing_err_7                => open,
            stat_rx_framing_err_8                => open,
            stat_rx_framing_err_9                => open,
            stat_rx_mf_err                       => open,
            stat_rx_mf_len_err                   => open,
            stat_rx_mf_repeat_err                => open,
            stat_rx_packet_small                 => open,
            ctl_rx_enable                        => r.ctl_rx_enable,
            ctl_rx_force_resync                  => '0',
            ctl_rx_test_pattern                  => '0',
            core_rx_reset                        => stableReset,
            rx_clk                               => txusrclk2,
            stat_rx_stomped_fcs                  => open,
            stat_rx_synced                       => open,
            stat_rx_synced_err                   => open,
            stat_rx_test_pattern_mismatch        => open,
            stat_rx_total_bytes                  => open,
            stat_rx_total_good_bytes             => open,
            stat_rx_total_packets                => open,
            stat_rx_undersize                    => open,
            stat_rx_pcsl_demuxed                 => open,
            stat_rx_pcsl_number_0                => open,
            stat_rx_pcsl_number_1                => open,
            stat_rx_pcsl_number_10               => open,
            stat_rx_pcsl_number_11               => open,
            stat_rx_pcsl_number_12               => open,
            stat_rx_pcsl_number_13               => open,
            stat_rx_pcsl_number_14               => open,
            stat_rx_pcsl_number_15               => open,
            stat_rx_pcsl_number_16               => open,
            stat_rx_pcsl_number_17               => open,
            stat_rx_pcsl_number_18               => open,
            stat_rx_pcsl_number_19               => open,
            stat_rx_pcsl_number_2                => open,
            stat_rx_pcsl_number_3                => open,
            stat_rx_pcsl_number_4                => open,
            stat_rx_pcsl_number_5                => open,
            stat_rx_pcsl_number_6                => open,
            stat_rx_pcsl_number_7                => open,
            stat_rx_pcsl_number_8                => open,
            stat_rx_pcsl_number_9                => open,
            stat_tx_bad_fcs                      => open,
            stat_tx_broadcast                    => open,
            stat_tx_frame_error                  => open,
            stat_tx_local_fault                  => open,
            stat_tx_multicast                    => open,
            stat_tx_packet_1024_1518_bytes       => open,
            stat_tx_packet_128_255_bytes         => open,
            stat_tx_packet_1519_1522_bytes       => open,
            stat_tx_packet_1523_1548_bytes       => open,
            stat_tx_packet_1549_2047_bytes       => open,
            stat_tx_packet_2048_4095_bytes       => open,
            stat_tx_packet_256_511_bytes         => open,
            stat_tx_packet_4096_8191_bytes       => open,
            stat_tx_packet_512_1023_bytes        => open,
            stat_tx_packet_64_bytes              => open,
            stat_tx_packet_65_127_bytes          => open,
            stat_tx_packet_8192_9215_bytes       => open,
            stat_tx_packet_large                 => open,
            stat_tx_packet_small                 => open,
            stat_tx_total_bytes                  => open,
            stat_tx_total_good_bytes             => open,
            stat_tx_total_good_packets           => open,
            stat_tx_total_packets                => open,
            stat_tx_unicast                      => open,
            stat_tx_vlan                         => open,
            ctl_tx_enable                        => r.ctl_tx_enable,
            ctl_tx_send_idle                     => '0',
            ctl_tx_send_rfi                      => r.ctl_tx_send_rfi,
            ctl_tx_send_lfi                      => '0',
            ctl_tx_test_pattern                  => '0',
            core_tx_reset                        => stableReset,
            tx_axis_tready                       => txSlave.tready,
            tx_axis_tvalid                       => txMaster.tvalid,
            tx_axis_tdata                        => txMaster.tdata(511 downto 0),
            tx_axis_tlast                        => txMaster.tlast,
            tx_axis_tkeep                        => txMaster.tkeep(63 downto 0),
            tx_axis_tuser                        => '0',  -- Unclear if I want to have the MAC drop EOFE
            tx_ovfout                            => open,
            tx_unfout                            => open,
            tx_preamblein                        => (others => '0'),  -- tx_preamblein is driven as 0
            usr_tx_reset                         => usr_tx_reset,
            core_drp_reset                       => stableReset,
            drp_clk                              => stableClk,
            drp_addr                             => (others => '0'),
            drp_di                               => (others => '0'),
            drp_en                               => '0',
            drp_do                               => open,
            drp_rdy                              => open,
            drp_we                               => '0');
   end generate;

   USE_REFCLK161MHz : if (REFCLK_TYPE_G = true) generate
      U_CAUI4 : Caui4GtyIpCore161MHz
         port map (
            gt_txp_out                           => gtTxP,
            gt_txn_out                           => gtTxN,
            gt_rxp_in                            => gtRxP,
            gt_rxn_in                            => gtRxN,
            gt_txusrclk2                         => txusrclk2,
            gt_loopback_in                       => gtLoopback,
            gt_eyescanreset                      => (others => '0'),
            gt_eyescantrigger                    => (others => '0'),
            gt_rxcdrhold                         => (others => '0'),
            gt_rxpolarity                        => rxPolarity(3 downto 0),
            gt_rxrate                            => (others => '0'),
            gt_txdiffctrl                        => gtTxdiffctrl,
            gt_txpolarity                        => txPolarity(3 downto 0),
            gt_txinhibit                         => (others => '0'),
            gt_txpippmen                         => (others => '0'),
            gt_txpippmsel                        => (others => '1'),  -- Same as Caui4GtyIpCore_trans_debug example design
            gt_txpostcursor                      => gtTxPostCursor,
            gt_txprbsforceerr                    => (others => '0'),
            gt_txprecursor                       => gtTxPreCursor,
            gt_eyescandataerror                  => open,
            gt_ref_clk_out                       => open,
            gt_rxrecclkout                       => open,
            gt_powergoodout                      => open,
            gt_txbufstatus                       => open,
            gt_rxdfelpmreset                     => (others => '0'),
            gt_rxlpmen                           => (others => '1'),  -- Same as Caui4GtyIpCore_trans_debug example design
            gt_rxprbscntreset                    => (others => '0'),
            gt_rxprbserr                         => open,
            gt_rxprbssel                         => (others => '0'),
            gt_rxresetdone                       => open,
            gt_txprbssel                         => (others => '0'),
            gt_txresetdone                       => open,
            gt_rxbufstatus                       => open,
            gtwiz_reset_tx_datapath              => stableReset,
            gtwiz_reset_rx_datapath              => stableReset,
            gt_drpclk                            => stableClk,
            gt0_drpdo                            => open,
            gt0_drprdy                           => open,
            gt0_drpen                            => '0',
            gt0_drpwe                            => '0',
            gt0_drpaddr                          => (others => '0'),
            gt0_drpdi                            => (others => '0'),
            gt1_drpdo                            => open,
            gt1_drprdy                           => open,
            gt1_drpen                            => '0',
            gt1_drpwe                            => '0',
            gt1_drpaddr                          => (others => '0'),
            gt1_drpdi                            => (others => '0'),
            gt2_drpdo                            => open,
            gt2_drprdy                           => open,
            gt2_drpen                            => '0',
            gt2_drpwe                            => '0',
            gt2_drpaddr                          => (others => '0'),
            gt2_drpdi                            => (others => '0'),
            gt3_drpdo                            => open,
            gt3_drprdy                           => open,
            gt3_drpen                            => '0',
            gt3_drpwe                            => '0',
            gt3_drpaddr                          => (others => '0'),
            gt3_drpdi                            => (others => '0'),
            ctl_tx_rsfec_enable                  => '1',
            ctl_rx_rsfec_enable                  => '1',
            ctl_rsfec_ieee_error_indication_mode => '1',
            ctl_rx_rsfec_enable_correction       => '1',
            ctl_rx_rsfec_enable_indication       => '1',
            stat_rx_rsfec_am_lock0               => open,
            stat_rx_rsfec_am_lock1               => open,
            stat_rx_rsfec_am_lock2               => open,
            stat_rx_rsfec_am_lock3               => open,
            stat_rx_rsfec_corrected_cw_inc       => open,
            stat_rx_rsfec_cw_inc                 => open,
            stat_rx_rsfec_err_count0_inc         => open,
            stat_rx_rsfec_err_count1_inc         => open,
            stat_rx_rsfec_err_count2_inc         => open,
            stat_rx_rsfec_err_count3_inc         => open,
            stat_rx_rsfec_hi_ser                 => open,
            stat_rx_rsfec_lane_alignment_status  => stat_rx_aligned,
            stat_rx_rsfec_lane_fill_0            => open,
            stat_rx_rsfec_lane_fill_1            => open,
            stat_rx_rsfec_lane_fill_2            => open,
            stat_rx_rsfec_lane_fill_3            => open,
            stat_rx_rsfec_lane_mapping           => open,
            stat_rx_rsfec_uncorrected_cw_inc     => stat_rx_aligned_err,
            sys_reset                            => stableReset,
            gt_ref_clk_p                         => gtRefClkP,
            gt_ref_clk_n                         => gtRefClkN,
            init_clk                             => stableClk,
            common0_drpaddr                      => (others => '0'),
            common0_drpdi                        => (others => '0'),
            common0_drpwe                        => '0',
            common0_drpen                        => '0',
            common0_drprdy                       => open,
            common0_drpdo                        => open,
            rx_axis_tvalid                       => rxAxis.tvalid,
            rx_axis_tdata                        => rxAxis.tdata(511 downto 0),
            rx_axis_tlast                        => rxAxis.tlast,
            rx_axis_tkeep                        => rxAxis.tkeep,
            rx_axis_tuser                        => rxAxis.tuser(0),
            rx_otn_bip8_0                        => open,
            rx_otn_bip8_1                        => open,
            rx_otn_bip8_2                        => open,
            rx_otn_bip8_3                        => open,
            rx_otn_bip8_4                        => open,
            rx_otn_data_0                        => open,
            rx_otn_data_1                        => open,
            rx_otn_data_2                        => open,
            rx_otn_data_3                        => open,
            rx_otn_data_4                        => open,
            rx_preambleout                       => open,
            usr_rx_reset                         => usr_rx_reset,
            gt_rxusrclk2                         => open,
            -- stat_rx_aligned                      => stat_rx_aligned,
            -- stat_rx_aligned_err                  => stat_rx_aligned_err,
            stat_rx_bad_code                     => open,
            stat_rx_bad_fcs                      => open,
            stat_rx_block_lock                   => open,
            stat_rx_fragment                     => open,
            stat_rx_framing_err_0                => open,
            stat_rx_framing_err_1                => open,
            stat_rx_framing_err_10               => open,
            stat_rx_framing_err_11               => open,
            stat_rx_framing_err_12               => open,
            stat_rx_framing_err_13               => open,
            stat_rx_framing_err_14               => open,
            stat_rx_framing_err_15               => open,
            stat_rx_framing_err_16               => open,
            stat_rx_framing_err_17               => open,
            stat_rx_framing_err_18               => open,
            stat_rx_framing_err_19               => open,
            stat_rx_framing_err_2                => open,
            stat_rx_framing_err_3                => open,
            stat_rx_framing_err_4                => open,
            stat_rx_framing_err_5                => open,
            stat_rx_framing_err_6                => open,
            stat_rx_framing_err_7                => open,
            stat_rx_framing_err_8                => open,
            stat_rx_framing_err_9                => open,
            stat_rx_mf_err                       => open,
            stat_rx_mf_len_err                   => open,
            stat_rx_mf_repeat_err                => open,
            stat_rx_packet_small                 => open,
            ctl_rx_enable                        => r.ctl_rx_enable,
            ctl_rx_force_resync                  => '0',
            ctl_rx_test_pattern                  => '0',
            core_rx_reset                        => stableReset,
            rx_clk                               => txusrclk2,
            stat_rx_stomped_fcs                  => open,
            stat_rx_synced                       => open,
            stat_rx_synced_err                   => open,
            stat_rx_test_pattern_mismatch        => open,
            stat_rx_total_bytes                  => open,
            stat_rx_total_good_bytes             => open,
            stat_rx_total_packets                => open,
            stat_rx_undersize                    => open,
            stat_rx_pcsl_demuxed                 => open,
            stat_rx_pcsl_number_0                => open,
            stat_rx_pcsl_number_1                => open,
            stat_rx_pcsl_number_10               => open,
            stat_rx_pcsl_number_11               => open,
            stat_rx_pcsl_number_12               => open,
            stat_rx_pcsl_number_13               => open,
            stat_rx_pcsl_number_14               => open,
            stat_rx_pcsl_number_15               => open,
            stat_rx_pcsl_number_16               => open,
            stat_rx_pcsl_number_17               => open,
            stat_rx_pcsl_number_18               => open,
            stat_rx_pcsl_number_19               => open,
            stat_rx_pcsl_number_2                => open,
            stat_rx_pcsl_number_3                => open,
            stat_rx_pcsl_number_4                => open,
            stat_rx_pcsl_number_5                => open,
            stat_rx_pcsl_number_6                => open,
            stat_rx_pcsl_number_7                => open,
            stat_rx_pcsl_number_8                => open,
            stat_rx_pcsl_number_9                => open,
            stat_tx_bad_fcs                      => open,
            stat_tx_broadcast                    => open,
            stat_tx_frame_error                  => open,
            stat_tx_local_fault                  => open,
            stat_tx_multicast                    => open,
            stat_tx_packet_1024_1518_bytes       => open,
            stat_tx_packet_128_255_bytes         => open,
            stat_tx_packet_1519_1522_bytes       => open,
            stat_tx_packet_1523_1548_bytes       => open,
            stat_tx_packet_1549_2047_bytes       => open,
            stat_tx_packet_2048_4095_bytes       => open,
            stat_tx_packet_256_511_bytes         => open,
            stat_tx_packet_4096_8191_bytes       => open,
            stat_tx_packet_512_1023_bytes        => open,
            stat_tx_packet_64_bytes              => open,
            stat_tx_packet_65_127_bytes          => open,
            stat_tx_packet_8192_9215_bytes       => open,
            stat_tx_packet_large                 => open,
            stat_tx_packet_small                 => open,
            stat_tx_total_bytes                  => open,
            stat_tx_total_good_bytes             => open,
            stat_tx_total_good_packets           => open,
            stat_tx_total_packets                => open,
            stat_tx_unicast                      => open,
            stat_tx_vlan                         => open,
            ctl_tx_enable                        => r.ctl_tx_enable,
            ctl_tx_send_idle                     => '0',
            ctl_tx_send_rfi                      => r.ctl_tx_send_rfi,
            ctl_tx_send_lfi                      => '0',
            ctl_tx_test_pattern                  => '0',
            core_tx_reset                        => stableReset,
            tx_axis_tready                       => txSlave.tready,
            tx_axis_tvalid                       => txMaster.tvalid,
            tx_axis_tdata                        => txMaster.tdata(511 downto 0),
            tx_axis_tlast                        => txMaster.tlast,
            tx_axis_tkeep                        => txMaster.tkeep(63 downto 0),
            tx_axis_tuser                        => '0',  -- Unclear if I want to have the MAC drop EOFE
            tx_ovfout                            => open,
            tx_unfout                            => open,
            tx_preamblein                        => (others => '0'),  -- tx_preamblein is driven as 0
            usr_tx_reset                         => usr_tx_reset,
            core_drp_reset                       => stableReset,
            drp_clk                              => stableClk,
            drp_addr                             => (others => '0'),
            drp_di                               => (others => '0'),
            drp_en                               => '0',
            drp_do                               => open,
            drp_rdy                              => open,
            drp_we                               => '0');
   end generate;

   comb : process (r, stat_rx_aligned, stat_rx_aligned_err, usr_rx_reset) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- State Machine: Refer to PG203 on page206 (Integrated 100G Ethernet v2.6)
      case r.state is
         ----------------------------------------------------------------------
         when INIT_S =>
            -- 1. Assert the below signals:
            v.ctl_rx_enable   := '1';
            v.ctl_tx_send_rfi := '1';
            -- Next state
            v.state           := WAIT_S;
         ----------------------------------------------------------------------
         when WAIT_S =>
            -- 2. Wait for RX_aligned then deassert / assert the below signals:
            if (stat_rx_aligned = '1') then
               v.ctl_tx_send_rfi := '0';
               v.ctl_tx_enable   := '1';
               -- Next state: Disabled TX/RX flow control in the Vivado IDE, skip to step 4.
               v.state           := DONE_S;
            end if;
         ----------------------------------------------------------------------
         when DONE_S =>
            -- 4. Data transmission and reception can be performed.
            v.phyRdy := '1';
            -- Check for error or not aligned
            if (stat_rx_aligned_err = '1') or (stat_rx_aligned = '0') then
               -- Reset the state machine to re-align
               v := REG_INIT_C;
            end if;
      ----------------------------------------------------------------------
      end case;

      -- Reset
      if (usr_rx_reset = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

   end process comb;

   seq : process (txusrclk2) is
   begin
      if rising_edge(txusrclk2) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   U_SyncBits : entity surf.Synchronizer
      generic map(
         TPD_G => TPD_G)
      port map (
         clk     => phyClock,
         -- Inputs
         dataIn  => r.phyRdy,
         -- Outputs
         dataOut => phyReady);

end mapping;
