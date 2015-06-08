// Copyright 1986-2014 Xilinx, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2014.4 (lin64) Build 1071353 Tue Nov 18 16:48:31 MST 2014
// Date        : Mon Jun  8 14:33:53 2015
// Host        : rdusr207 running 64-bit Red Hat Enterprise Linux Server release 5.11 (Tikanga)
// Command     : write_verilog -force -mode funcsim
//               /u1/ulegat/jesd204b/build/JesdDacKcu105/JesdDacKcu105_project.srcs/sources_1/ip/GthUltrascaleJesdCoregen/GthUltrascaleJesdCoregen_funcsim.v
// Design      : GthUltrascaleJesdCoregen
// Purpose     : This verilog netlist is a functional simulation representation of the design and should not be modified
//               or synthesized. This netlist cannot be used for SDF annotated simulation.
// Device      : xcku040-ffva1156-2-e
// --------------------------------------------------------------------------------
`timescale 1 ps / 1 ps

(* X_CORE_INFO = "GthUltrascaleJesdCoregen_gtwizard_top,Vivado 2014.4" *) (* CHECK_LICENSE_TYPE = "GthUltrascaleJesdCoregen,GthUltrascaleJesdCoregen_gtwizard_top,{}" *) (* CORE_GENERATION_INFO = "GthUltrascaleJesdCoregen,GthUltrascaleJesdCoregen_gtwizard_top,{x_ipProduct=Vivado 2014.4,x_ipVendor=xilinx.com,x_ipLibrary=ip,x_ipName=gtwizard_ultrascale,x_ipVersion=1.4,x_ipCoreRevision=1,x_ipLanguage=VHDL,x_ipSimLanguage=MIXED,C_CHANNEL_ENABLE=000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000,C_COMMON_SCALING_FACTOR=1,C_CPLL_VCO_FREQUENCY=2578.125,C_FORCE_COMMONS=0,C_FREERUN_FREQUENCY=185,C_GT_TYPE=0,C_GT_REV=0,C_INCLUDE_CPLL_CAL=2,C_LOCATE_COMMON=0,C_LOCATE_RESET_CONTROLLER=0,C_LOCATE_USER_DATA_WIDTH_SIZING=0,C_LOCATE_RX_BUFFER_BYPASS_CONTROLLER=0,C_LOCATE_RX_USER_CLOCKING=1,C_LOCATE_TX_BUFFER_BYPASS_CONTROLLER=0,C_LOCATE_TX_USER_CLOCKING=1,C_RESET_CONTROLLER_INSTANCE_CTRL=0,C_RX_BUFFBYPASS_MODE=0,C_RX_BUFFER_BYPASS_INSTANCE_CTRL=0,C_RX_BUFFER_MODE=1,C_RX_CB_DISP=00000000,C_RX_CB_K=00000000,C_RX_CB_MAX_LEVEL=1,C_RX_CB_LEN_SEQ=1,C_RX_CB_NUM_SEQ=0,C_RX_CB_VAL=00000000000000000000000000000000000000000000000000000000000000000000000000000000,C_RX_CC_DISP=00000000,C_RX_CC_ENABLE=0,C_RX_CC_K=00000000,C_RX_CC_LEN_SEQ=1,C_RX_CC_NUM_SEQ=0,C_RX_CC_PERIODICITY=5000,C_RX_CC_VAL=00000000000000000000000000000000000000000000000000000000000000000000000000000000,C_RX_COMMA_M_ENABLE=1,C_RX_COMMA_M_VAL=1010000011,C_RX_COMMA_P_ENABLE=1,C_RX_COMMA_P_VAL=0101111100,C_RX_DATA_DECODING=1,C_RX_ENABLE=1,C_RX_INT_DATA_WIDTH=40,C_RX_LINE_RATE=7.4,C_RX_MASTER_CHANNEL_IDX=18,C_RX_OUTCLK_BUFG_GT_DIV=1,C_RX_OUTCLK_FREQUENCY=185.0000000,C_RX_OUTCLK_SOURCE=1,C_RX_PLL_TYPE=0,C_RX_RECCLK_OUTPUT=0x000000000000000000000000000000000000000000000000,C_RX_REFCLK_FREQUENCY=370,C_RX_SLIDE_MODE=0,C_RX_USER_CLOCKING_CONTENTS=0,C_RX_USER_CLOCKING_INSTANCE_CTRL=0,C_RX_USER_CLOCKING_RATIO_FSRC_FUSRCLK=1,C_RX_USER_CLOCKING_RATIO_FUSRCLK_FUSRCLK2=1,C_RX_USER_CLOCKING_SOURCE=0,C_RX_USER_DATA_WIDTH=32,C_RX_USRCLK_FREQUENCY=185.0000000,C_RX_USRCLK2_FREQUENCY=185.0000000,C_SECONDARY_QPLL_ENABLE=0,C_SECONDARY_QPLL_REFCLK_FREQUENCY=257.8125,C_TOTAL_NUM_CHANNELS=2,C_TOTAL_NUM_COMMONS=1,C_TOTAL_NUM_COMMONS_EXAMPLE=0,C_TXPROGDIV_FREQ_ENABLE=0,C_TXPROGDIV_FREQ_SOURCE=0,C_TXPROGDIV_FREQ_VAL=185,C_TX_BUFFBYPASS_MODE=0,C_TX_BUFFER_BYPASS_INSTANCE_CTRL=0,C_TX_BUFFER_MODE=1,C_TX_DATA_ENCODING=1,C_TX_ENABLE=1,C_TX_INT_DATA_WIDTH=40,C_TX_LINE_RATE=7.4,C_TX_MASTER_CHANNEL_IDX=18,C_TX_OUTCLK_BUFG_GT_DIV=1,C_TX_OUTCLK_FREQUENCY=185.0000000,C_TX_OUTCLK_SOURCE=1,C_TX_PLL_TYPE=0,C_TX_REFCLK_FREQUENCY=370,C_TX_USER_CLOCKING_CONTENTS=0,C_TX_USER_CLOCKING_INSTANCE_CTRL=0,C_TX_USER_CLOCKING_RATIO_FSRC_FUSRCLK=1,C_TX_USER_CLOCKING_RATIO_FUSRCLK_FUSRCLK2=1,C_TX_USER_CLOCKING_SOURCE=0,C_TX_USER_DATA_WIDTH=32,C_TX_USRCLK_FREQUENCY=185.0000000,C_TX_USRCLK2_FREQUENCY=185.0000000}" *) 
(* DowngradeIPIdentifiedWarnings = "yes" *) 
(* NotValidForBitStream *)
module GthUltrascaleJesdCoregen
   (gtwiz_userclk_tx_active_in,
    gtwiz_userclk_rx_active_in,
    gtwiz_reset_clk_freerun_in,
    gtwiz_reset_all_in,
    gtwiz_reset_tx_pll_and_datapath_in,
    gtwiz_reset_tx_datapath_in,
    gtwiz_reset_rx_pll_and_datapath_in,
    gtwiz_reset_rx_datapath_in,
    gtwiz_reset_rx_cdr_stable_out,
    gtwiz_reset_tx_done_out,
    gtwiz_reset_rx_done_out,
    gtwiz_userdata_tx_in,
    gtwiz_userdata_rx_out,
    gtrefclk00_in,
    qpll0lock_out,
    qpll0outclk_out,
    qpll0outrefclk_out,
    gthrxn_in,
    gthrxp_in,
    rx8b10ben_in,
    rxcommadeten_in,
    rxmcommaalignen_in,
    rxpcommaalignen_in,
    rxpolarity_in,
    rxusrclk_in,
    rxusrclk2_in,
    tx8b10ben_in,
    txctrl0_in,
    txctrl1_in,
    txctrl2_in,
    txpolarity_in,
    txusrclk_in,
    txusrclk2_in,
    gthtxn_out,
    gthtxp_out,
    rxbyteisaligned_out,
    rxbyterealign_out,
    rxcommadet_out,
    rxctrl0_out,
    rxctrl1_out,
    rxctrl2_out,
    rxctrl3_out,
    rxoutclk_out,
    rxpmaresetdone_out,
    txoutclk_out,
    txpmaresetdone_out);
  input [0:0]gtwiz_userclk_tx_active_in;
  input [0:0]gtwiz_userclk_rx_active_in;
  input [0:0]gtwiz_reset_clk_freerun_in;
  input [0:0]gtwiz_reset_all_in;
  input [0:0]gtwiz_reset_tx_pll_and_datapath_in;
  input [0:0]gtwiz_reset_tx_datapath_in;
  input [0:0]gtwiz_reset_rx_pll_and_datapath_in;
  input [0:0]gtwiz_reset_rx_datapath_in;
  output [0:0]gtwiz_reset_rx_cdr_stable_out;
  output [0:0]gtwiz_reset_tx_done_out;
  output [0:0]gtwiz_reset_rx_done_out;
  input [63:0]gtwiz_userdata_tx_in;
  output [63:0]gtwiz_userdata_rx_out;
  input [0:0]gtrefclk00_in;
  output [0:0]qpll0lock_out;
  output [0:0]qpll0outclk_out;
  output [0:0]qpll0outrefclk_out;
  input [1:0]gthrxn_in;
  input [1:0]gthrxp_in;
  input [1:0]rx8b10ben_in;
  input [1:0]rxcommadeten_in;
  input [1:0]rxmcommaalignen_in;
  input [1:0]rxpcommaalignen_in;
  input [1:0]rxpolarity_in;
  input [1:0]rxusrclk_in;
  input [1:0]rxusrclk2_in;
  input [1:0]tx8b10ben_in;
  input [31:0]txctrl0_in;
  input [31:0]txctrl1_in;
  input [15:0]txctrl2_in;
  input [1:0]txpolarity_in;
  input [1:0]txusrclk_in;
  input [1:0]txusrclk2_in;
  output [1:0]gthtxn_out;
  output [1:0]gthtxp_out;
  output [1:0]rxbyteisaligned_out;
  output [1:0]rxbyterealign_out;
  output [1:0]rxcommadet_out;
  output [31:0]rxctrl0_out;
  output [31:0]rxctrl1_out;
  output [15:0]rxctrl2_out;
  output [15:0]rxctrl3_out;
  output [1:0]rxoutclk_out;
  output [1:0]rxpmaresetdone_out;
  output [1:0]txoutclk_out;
  output [1:0]txpmaresetdone_out;

  wire [1:0]gthrxn_in;
  wire [1:0]gthrxp_in;
  wire [1:0]gthtxn_out;
  wire [1:0]gthtxp_out;
  wire [0:0]gtrefclk00_in;
  wire [0:0]gtwiz_reset_all_in;
  wire [0:0]gtwiz_reset_clk_freerun_in;
  wire [0:0]gtwiz_reset_rx_cdr_stable_out;
  wire [0:0]gtwiz_reset_rx_datapath_in;
  wire [0:0]gtwiz_reset_rx_done_out;
  wire [0:0]gtwiz_reset_rx_pll_and_datapath_in;
  wire [0:0]gtwiz_reset_tx_datapath_in;
  wire [0:0]gtwiz_reset_tx_done_out;
  wire [0:0]gtwiz_reset_tx_pll_and_datapath_in;
  wire [0:0]gtwiz_userclk_rx_active_in;
  wire [0:0]gtwiz_userclk_tx_active_in;
  wire [63:0]gtwiz_userdata_rx_out;
  wire [63:0]gtwiz_userdata_tx_in;
  wire [0:0]qpll0lock_out;
  wire [0:0]qpll0outclk_out;
  wire [0:0]qpll0outrefclk_out;
  wire [1:0]rx8b10ben_in;
  wire [1:0]rxbyteisaligned_out;
  wire [1:0]rxbyterealign_out;
  wire [1:0]rxcommadet_out;
  wire [1:0]rxcommadeten_in;
  wire [31:0]rxctrl0_out;
  wire [31:0]rxctrl1_out;
  wire [15:0]rxctrl2_out;
  wire [15:0]rxctrl3_out;
  wire [1:0]rxmcommaalignen_in;
  wire [1:0]rxoutclk_out;
  wire [1:0]rxpcommaalignen_in;
  wire [1:0]rxpmaresetdone_out;
  wire [1:0]rxpolarity_in;
  wire [1:0]rxusrclk2_in;
  wire [1:0]rxusrclk_in;
  wire [1:0]tx8b10ben_in;
  wire [31:0]txctrl0_in;
  wire [31:0]txctrl1_in;
  wire [15:0]txctrl2_in;
  wire [1:0]txoutclk_out;
  wire [1:0]txpmaresetdone_out;
  wire [1:0]txpolarity_in;
  wire [1:0]txusrclk2_in;
  wire [1:0]txusrclk_in;
  wire [5:0]NLW_inst_bufgtce_out_UNCONNECTED;
  wire [5:0]NLW_inst_bufgtcemask_out_UNCONNECTED;
  wire [17:0]NLW_inst_bufgtdiv_out_UNCONNECTED;
  wire [5:0]NLW_inst_bufgtreset_out_UNCONNECTED;
  wire [5:0]NLW_inst_bufgtrstmask_out_UNCONNECTED;
  wire [1:0]NLW_inst_cpllfbclklost_out_UNCONNECTED;
  wire [1:0]NLW_inst_cplllock_out_UNCONNECTED;
  wire [1:0]NLW_inst_cpllrefclklost_out_UNCONNECTED;
  wire [33:0]NLW_inst_dmonitorout_out_UNCONNECTED;
  wire [15:0]NLW_inst_drpdo_common_out_UNCONNECTED;
  wire [31:0]NLW_inst_drpdo_out_UNCONNECTED;
  wire [0:0]NLW_inst_drprdy_common_out_UNCONNECTED;
  wire [1:0]NLW_inst_drprdy_out_UNCONNECTED;
  wire [1:0]NLW_inst_eyescandataerror_out_UNCONNECTED;
  wire [1:0]NLW_inst_gtpowergood_out_UNCONNECTED;
  wire [1:0]NLW_inst_gtrefclkmonitor_out_UNCONNECTED;
  wire [0:0]NLW_inst_gtwiz_buffbypass_rx_done_out_UNCONNECTED;
  wire [0:0]NLW_inst_gtwiz_buffbypass_rx_error_out_UNCONNECTED;
  wire [0:0]NLW_inst_gtwiz_buffbypass_tx_done_out_UNCONNECTED;
  wire [0:0]NLW_inst_gtwiz_buffbypass_tx_error_out_UNCONNECTED;
  wire [0:0]NLW_inst_gtwiz_reset_qpll0reset_out_UNCONNECTED;
  wire [0:0]NLW_inst_gtwiz_reset_qpll1reset_out_UNCONNECTED;
  wire [0:0]NLW_inst_gtwiz_userclk_rx_active_out_UNCONNECTED;
  wire [0:0]NLW_inst_gtwiz_userclk_rx_srcclk_out_UNCONNECTED;
  wire [0:0]NLW_inst_gtwiz_userclk_rx_usrclk2_out_UNCONNECTED;
  wire [0:0]NLW_inst_gtwiz_userclk_rx_usrclk_out_UNCONNECTED;
  wire [0:0]NLW_inst_gtwiz_userclk_tx_active_out_UNCONNECTED;
  wire [0:0]NLW_inst_gtwiz_userclk_tx_srcclk_out_UNCONNECTED;
  wire [0:0]NLW_inst_gtwiz_userclk_tx_usrclk2_out_UNCONNECTED;
  wire [0:0]NLW_inst_gtwiz_userclk_tx_usrclk_out_UNCONNECTED;
  wire [0:0]NLW_inst_gtytxn_out_UNCONNECTED;
  wire [0:0]NLW_inst_gtytxp_out_UNCONNECTED;
  wire [1:0]NLW_inst_pcierategen3_out_UNCONNECTED;
  wire [1:0]NLW_inst_pcierateidle_out_UNCONNECTED;
  wire [3:0]NLW_inst_pcierateqpllpd_out_UNCONNECTED;
  wire [3:0]NLW_inst_pcierateqpllreset_out_UNCONNECTED;
  wire [1:0]NLW_inst_pciesynctxsyncdone_out_UNCONNECTED;
  wire [1:0]NLW_inst_pcieusergen3rdy_out_UNCONNECTED;
  wire [1:0]NLW_inst_pcieuserphystatusrst_out_UNCONNECTED;
  wire [1:0]NLW_inst_pcieuserratestart_out_UNCONNECTED;
  wire [23:0]NLW_inst_pcsrsvdout_out_UNCONNECTED;
  wire [1:0]NLW_inst_phystatus_out_UNCONNECTED;
  wire [15:0]NLW_inst_pinrsrvdas_out_UNCONNECTED;
  wire [7:0]NLW_inst_pmarsvdout0_out_UNCONNECTED;
  wire [7:0]NLW_inst_pmarsvdout1_out_UNCONNECTED;
  wire [0:0]NLW_inst_qpll0fbclklost_out_UNCONNECTED;
  wire [0:0]NLW_inst_qpll0refclklost_out_UNCONNECTED;
  wire [0:0]NLW_inst_qpll1fbclklost_out_UNCONNECTED;
  wire [0:0]NLW_inst_qpll1lock_out_UNCONNECTED;
  wire [0:0]NLW_inst_qpll1outclk_out_UNCONNECTED;
  wire [0:0]NLW_inst_qpll1outrefclk_out_UNCONNECTED;
  wire [0:0]NLW_inst_qpll1refclklost_out_UNCONNECTED;
  wire [7:0]NLW_inst_qplldmonitor0_out_UNCONNECTED;
  wire [7:0]NLW_inst_qplldmonitor1_out_UNCONNECTED;
  wire [0:0]NLW_inst_refclkoutmonitor0_out_UNCONNECTED;
  wire [0:0]NLW_inst_refclkoutmonitor1_out_UNCONNECTED;
  wire [1:0]NLW_inst_resetexception_out_UNCONNECTED;
  wire [5:0]NLW_inst_rxbufstatus_out_UNCONNECTED;
  wire [1:0]NLW_inst_rxcdrlock_out_UNCONNECTED;
  wire [1:0]NLW_inst_rxcdrphdone_out_UNCONNECTED;
  wire [1:0]NLW_inst_rxchanbondseq_out_UNCONNECTED;
  wire [1:0]NLW_inst_rxchanisaligned_out_UNCONNECTED;
  wire [1:0]NLW_inst_rxchanrealign_out_UNCONNECTED;
  wire [9:0]NLW_inst_rxchbondo_out_UNCONNECTED;
  wire [0:0]NLW_inst_rxckcaldone_out_UNCONNECTED;
  wire [3:0]NLW_inst_rxclkcorcnt_out_UNCONNECTED;
  wire [1:0]NLW_inst_rxcominitdet_out_UNCONNECTED;
  wire [1:0]NLW_inst_rxcomsasdet_out_UNCONNECTED;
  wire [1:0]NLW_inst_rxcomwakedet_out_UNCONNECTED;
  wire [255:0]NLW_inst_rxdata_out_UNCONNECTED;
  wire [15:0]NLW_inst_rxdataextendrsvd_out_UNCONNECTED;
  wire [3:0]NLW_inst_rxdatavalid_out_UNCONNECTED;
  wire [1:0]NLW_inst_rxdlysresetdone_out_UNCONNECTED;
  wire [1:0]NLW_inst_rxelecidle_out_UNCONNECTED;
  wire [11:0]NLW_inst_rxheader_out_UNCONNECTED;
  wire [3:0]NLW_inst_rxheadervalid_out_UNCONNECTED;
  wire [13:0]NLW_inst_rxmonitorout_out_UNCONNECTED;
  wire [1:0]NLW_inst_rxosintdone_out_UNCONNECTED;
  wire [1:0]NLW_inst_rxosintstarted_out_UNCONNECTED;
  wire [1:0]NLW_inst_rxosintstrobedone_out_UNCONNECTED;
  wire [1:0]NLW_inst_rxosintstrobestarted_out_UNCONNECTED;
  wire [1:0]NLW_inst_rxoutclkfabric_out_UNCONNECTED;
  wire [1:0]NLW_inst_rxoutclkpcs_out_UNCONNECTED;
  wire [1:0]NLW_inst_rxphaligndone_out_UNCONNECTED;
  wire [1:0]NLW_inst_rxphalignerr_out_UNCONNECTED;
  wire [1:0]NLW_inst_rxprbserr_out_UNCONNECTED;
  wire [1:0]NLW_inst_rxprbslocked_out_UNCONNECTED;
  wire [1:0]NLW_inst_rxprgdivresetdone_out_UNCONNECTED;
  wire [1:0]NLW_inst_rxqpisenn_out_UNCONNECTED;
  wire [1:0]NLW_inst_rxqpisenp_out_UNCONNECTED;
  wire [1:0]NLW_inst_rxratedone_out_UNCONNECTED;
  wire [1:0]NLW_inst_rxrecclk0_sel_out_UNCONNECTED;
  wire [1:0]NLW_inst_rxrecclk1_sel_out_UNCONNECTED;
  wire [1:0]NLW_inst_rxrecclkout_out_UNCONNECTED;
  wire [1:0]NLW_inst_rxresetdone_out_UNCONNECTED;
  wire [1:0]NLW_inst_rxsliderdy_out_UNCONNECTED;
  wire [1:0]NLW_inst_rxslipdone_out_UNCONNECTED;
  wire [1:0]NLW_inst_rxslipoutclkrdy_out_UNCONNECTED;
  wire [1:0]NLW_inst_rxslippmardy_out_UNCONNECTED;
  wire [3:0]NLW_inst_rxstartofseq_out_UNCONNECTED;
  wire [5:0]NLW_inst_rxstatus_out_UNCONNECTED;
  wire [1:0]NLW_inst_rxsyncdone_out_UNCONNECTED;
  wire [1:0]NLW_inst_rxsyncout_out_UNCONNECTED;
  wire [1:0]NLW_inst_rxvalid_out_UNCONNECTED;
  wire [0:0]NLW_inst_sdm0finalout_out_UNCONNECTED;
  wire [0:0]NLW_inst_sdm0testdata_out_UNCONNECTED;
  wire [0:0]NLW_inst_sdm1finalout_out_UNCONNECTED;
  wire [0:0]NLW_inst_sdm1testdata_out_UNCONNECTED;
  wire [3:0]NLW_inst_txbufstatus_out_UNCONNECTED;
  wire [1:0]NLW_inst_txcomfinish_out_UNCONNECTED;
  wire [0:0]NLW_inst_txdccdone_out_UNCONNECTED;
  wire [1:0]NLW_inst_txdlysresetdone_out_UNCONNECTED;
  wire [1:0]NLW_inst_txoutclkfabric_out_UNCONNECTED;
  wire [1:0]NLW_inst_txoutclkpcs_out_UNCONNECTED;
  wire [1:0]NLW_inst_txphaligndone_out_UNCONNECTED;
  wire [1:0]NLW_inst_txphinitdone_out_UNCONNECTED;
  wire [1:0]NLW_inst_txprgdivresetdone_out_UNCONNECTED;
  wire [1:0]NLW_inst_txqpisenn_out_UNCONNECTED;
  wire [1:0]NLW_inst_txqpisenp_out_UNCONNECTED;
  wire [1:0]NLW_inst_txratedone_out_UNCONNECTED;
  wire [1:0]NLW_inst_txresetdone_out_UNCONNECTED;
  wire [1:0]NLW_inst_txsyncdone_out_UNCONNECTED;
  wire [1:0]NLW_inst_txsyncout_out_UNCONNECTED;

(* C_CHANNEL_ENABLE = "192'b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000" *) 
   (* C_COMMON_SCALING_FACTOR = "1" *) 
   (* C_CPLL_VCO_FREQUENCY = "2578.125000" *) 
   (* C_FORCE_COMMONS = "0" *) 
   (* C_FREERUN_FREQUENCY = "185.000000" *) 
   (* C_GT_REV = "0" *) 
   (* C_GT_TYPE = "0" *) 
   (* C_INCLUDE_CPLL_CAL = "2" *) 
   (* C_LOCATE_COMMON = "0" *) 
   (* C_LOCATE_RESET_CONTROLLER = "0" *) 
   (* C_LOCATE_RX_BUFFER_BYPASS_CONTROLLER = "0" *) 
   (* C_LOCATE_RX_USER_CLOCKING = "1" *) 
   (* C_LOCATE_TX_BUFFER_BYPASS_CONTROLLER = "0" *) 
   (* C_LOCATE_TX_USER_CLOCKING = "1" *) 
   (* C_LOCATE_USER_DATA_WIDTH_SIZING = "0" *) 
   (* C_RESET_CONTROLLER_INSTANCE_CTRL = "0" *) 
   (* C_RX_BUFFBYPASS_MODE = "0" *) 
   (* C_RX_BUFFER_BYPASS_INSTANCE_CTRL = "0" *) 
   (* C_RX_BUFFER_MODE = "1" *) 
   (* C_RX_CB_DISP = "8'b00000000" *) 
   (* C_RX_CB_K = "8'b00000000" *) 
   (* C_RX_CB_LEN_SEQ = "1" *) 
   (* C_RX_CB_MAX_LEVEL = "1" *) 
   (* C_RX_CB_NUM_SEQ = "0" *) 
   (* C_RX_CB_VAL = "80'b00000000000000000000000000000000000000000000000000000000000000000000000000000000" *) 
   (* C_RX_CC_DISP = "8'b00000000" *) 
   (* C_RX_CC_ENABLE = "0" *) 
   (* C_RX_CC_K = "8'b00000000" *) 
   (* C_RX_CC_LEN_SEQ = "1" *) 
   (* C_RX_CC_NUM_SEQ = "0" *) 
   (* C_RX_CC_PERIODICITY = "5000" *) 
   (* C_RX_CC_VAL = "80'b00000000000000000000000000000000000000000000000000000000000000000000000000000000" *) 
   (* C_RX_COMMA_M_ENABLE = "1" *) 
   (* C_RX_COMMA_M_VAL = "10'b1010000011" *) 
   (* C_RX_COMMA_P_ENABLE = "1" *) 
   (* C_RX_COMMA_P_VAL = "10'b0101111100" *) 
   (* C_RX_DATA_DECODING = "1" *) 
   (* C_RX_ENABLE = "1" *) 
   (* C_RX_INT_DATA_WIDTH = "40" *) 
   (* C_RX_LINE_RATE = "7.400000" *) 
   (* C_RX_MASTER_CHANNEL_IDX = "18" *) 
   (* C_RX_OUTCLK_BUFG_GT_DIV = "1" *) 
   (* C_RX_OUTCLK_FREQUENCY = "185.000000" *) 
   (* C_RX_OUTCLK_SOURCE = "1" *) 
   (* C_RX_PLL_TYPE = "0" *) 
   (* C_RX_RECCLK_OUTPUT = "192'b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000" *) 
   (* C_RX_REFCLK_FREQUENCY = "370.000000" *) 
   (* C_RX_SLIDE_MODE = "0" *) 
   (* C_RX_USER_CLOCKING_CONTENTS = "0" *) 
   (* C_RX_USER_CLOCKING_INSTANCE_CTRL = "0" *) 
   (* C_RX_USER_CLOCKING_RATIO_FSRC_FUSRCLK = "1" *) 
   (* C_RX_USER_CLOCKING_RATIO_FUSRCLK_FUSRCLK2 = "1" *) 
   (* C_RX_USER_CLOCKING_SOURCE = "0" *) 
   (* C_RX_USER_DATA_WIDTH = "32" *) 
   (* C_RX_USRCLK2_FREQUENCY = "185.000000" *) 
   (* C_RX_USRCLK_FREQUENCY = "185.000000" *) 
   (* C_SECONDARY_QPLL_ENABLE = "0" *) 
   (* C_SECONDARY_QPLL_REFCLK_FREQUENCY = "257.812500" *) 
   (* C_TOTAL_NUM_CHANNELS = "2" *) 
   (* C_TOTAL_NUM_COMMONS = "1" *) 
   (* C_TOTAL_NUM_COMMONS_EXAMPLE = "0" *) 
   (* C_TXPROGDIV_FREQ_ENABLE = "0" *) 
   (* C_TXPROGDIV_FREQ_SOURCE = "0" *) 
   (* C_TXPROGDIV_FREQ_VAL = "185.000000" *) 
   (* C_TX_BUFFBYPASS_MODE = "0" *) 
   (* C_TX_BUFFER_BYPASS_INSTANCE_CTRL = "0" *) 
   (* C_TX_BUFFER_MODE = "1" *) 
   (* C_TX_DATA_ENCODING = "1" *) 
   (* C_TX_ENABLE = "1" *) 
   (* C_TX_INT_DATA_WIDTH = "40" *) 
   (* C_TX_LINE_RATE = "7.400000" *) 
   (* C_TX_MASTER_CHANNEL_IDX = "18" *) 
   (* C_TX_OUTCLK_BUFG_GT_DIV = "1" *) 
   (* C_TX_OUTCLK_FREQUENCY = "185.000000" *) 
   (* C_TX_OUTCLK_SOURCE = "1" *) 
   (* C_TX_PLL_TYPE = "0" *) 
   (* C_TX_REFCLK_FREQUENCY = "370.000000" *) 
   (* C_TX_USER_CLOCKING_CONTENTS = "0" *) 
   (* C_TX_USER_CLOCKING_INSTANCE_CTRL = "0" *) 
   (* C_TX_USER_CLOCKING_RATIO_FSRC_FUSRCLK = "1" *) 
   (* C_TX_USER_CLOCKING_RATIO_FUSRCLK_FUSRCLK2 = "1" *) 
   (* C_TX_USER_CLOCKING_SOURCE = "0" *) 
   (* C_TX_USER_DATA_WIDTH = "32" *) 
   (* C_TX_USRCLK2_FREQUENCY = "185.000000" *) 
   (* C_TX_USRCLK_FREQUENCY = "185.000000" *) 
   GthUltrascaleJesdCoregen_GthUltrascaleJesdCoregen_gtwizard_top inst
       (.bgbypassb_in(1'b1),
        .bgmonitorenb_in(1'b1),
        .bgpdb_in(1'b1),
        .bgrcalovrd_in({1'b1,1'b1,1'b1,1'b1,1'b1}),
        .bgrcalovrdenb_in(1'b1),
        .bufgtce_out(NLW_inst_bufgtce_out_UNCONNECTED[5:0]),
        .bufgtcemask_out(NLW_inst_bufgtcemask_out_UNCONNECTED[5:0]),
        .bufgtdiv_out(NLW_inst_bufgtdiv_out_UNCONNECTED[17:0]),
        .bufgtreset_out(NLW_inst_bufgtreset_out_UNCONNECTED[5:0]),
        .bufgtrstmask_out(NLW_inst_bufgtrstmask_out_UNCONNECTED[5:0]),
        .cdrstepdir_in(1'b0),
        .cdrstepsq_in(1'b0),
        .cdrstepsx_in(1'b0),
        .cfgreset_in({1'b0,1'b0}),
        .clkrsvd0_in({1'b0,1'b0}),
        .clkrsvd1_in({1'b0,1'b0}),
        .cpllfbclklost_out(NLW_inst_cpllfbclklost_out_UNCONNECTED[1:0]),
        .cplllock_out(NLW_inst_cplllock_out_UNCONNECTED[1:0]),
        .cplllockdetclk_in({1'b0,1'b0}),
        .cplllocken_in({1'b0,1'b0}),
        .cpllpd_in({1'b1,1'b1}),
        .cpllrefclklost_out(NLW_inst_cpllrefclklost_out_UNCONNECTED[1:0]),
        .cpllrefclksel_in({1'b0,1'b0,1'b1,1'b0,1'b0,1'b1}),
        .cpllreset_in({1'b1,1'b1}),
        .dmonfiforeset_in({1'b0,1'b0}),
        .dmonitorclk_in({1'b0,1'b0}),
        .dmonitorout_out(NLW_inst_dmonitorout_out_UNCONNECTED[33:0]),
        .drpaddr_common_in({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .drpaddr_in({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .drpclk_common_in(1'b0),
        .drpclk_in({1'b0,1'b0}),
        .drpdi_common_in({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .drpdi_in({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .drpdo_common_out(NLW_inst_drpdo_common_out_UNCONNECTED[15:0]),
        .drpdo_out(NLW_inst_drpdo_out_UNCONNECTED[31:0]),
        .drpen_common_in(1'b0),
        .drpen_in({1'b0,1'b0}),
        .drprdy_common_out(NLW_inst_drprdy_common_out_UNCONNECTED[0]),
        .drprdy_out(NLW_inst_drprdy_out_UNCONNECTED[1:0]),
        .drpwe_common_in(1'b0),
        .drpwe_in({1'b0,1'b0}),
        .elpcaldvorwren_in(1'b0),
        .elpcalpaorwren_in(1'b0),
        .evoddphicaldone_in({1'b0,1'b0}),
        .evoddphicalstart_in({1'b0,1'b0}),
        .evoddphidrden_in({1'b0,1'b0}),
        .evoddphidwren_in({1'b0,1'b0}),
        .evoddphixrden_in({1'b0,1'b0}),
        .evoddphixwren_in({1'b0,1'b0}),
        .eyescandataerror_out(NLW_inst_eyescandataerror_out_UNCONNECTED[1:0]),
        .eyescanmode_in({1'b0,1'b0}),
        .eyescanreset_in({1'b0,1'b0}),
        .eyescantrigger_in({1'b0,1'b0}),
        .gtgrefclk0_in(1'b0),
        .gtgrefclk1_in(1'b0),
        .gtgrefclk_in({1'b0,1'b0}),
        .gthrxn_in(gthrxn_in),
        .gthrxp_in(gthrxp_in),
        .gthtxn_out(gthtxn_out),
        .gthtxp_out(gthtxp_out),
        .gtnorthrefclk00_in(1'b0),
        .gtnorthrefclk01_in(1'b0),
        .gtnorthrefclk0_in({1'b0,1'b0}),
        .gtnorthrefclk10_in(1'b0),
        .gtnorthrefclk11_in(1'b0),
        .gtnorthrefclk1_in({1'b0,1'b0}),
        .gtpowergood_out(NLW_inst_gtpowergood_out_UNCONNECTED[1:0]),
        .gtrefclk00_in(gtrefclk00_in),
        .gtrefclk01_in(1'b0),
        .gtrefclk0_in({1'b0,1'b0}),
        .gtrefclk10_in(1'b0),
        .gtrefclk11_in(1'b0),
        .gtrefclk1_in({1'b0,1'b0}),
        .gtrefclkmonitor_out(NLW_inst_gtrefclkmonitor_out_UNCONNECTED[1:0]),
        .gtresetsel_in({1'b0,1'b0}),
        .gtrsvd_in({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .gtrxreset_in({1'b0,1'b0}),
        .gtsouthrefclk00_in(1'b0),
        .gtsouthrefclk01_in(1'b0),
        .gtsouthrefclk0_in({1'b0,1'b0}),
        .gtsouthrefclk10_in(1'b0),
        .gtsouthrefclk11_in(1'b0),
        .gtsouthrefclk1_in({1'b0,1'b0}),
        .gttxreset_in({1'b0,1'b0}),
        .gtwiz_buffbypass_rx_done_out(NLW_inst_gtwiz_buffbypass_rx_done_out_UNCONNECTED[0]),
        .gtwiz_buffbypass_rx_error_out(NLW_inst_gtwiz_buffbypass_rx_error_out_UNCONNECTED[0]),
        .gtwiz_buffbypass_rx_reset_in(1'b0),
        .gtwiz_buffbypass_rx_start_user_in(1'b0),
        .gtwiz_buffbypass_tx_done_out(NLW_inst_gtwiz_buffbypass_tx_done_out_UNCONNECTED[0]),
        .gtwiz_buffbypass_tx_error_out(NLW_inst_gtwiz_buffbypass_tx_error_out_UNCONNECTED[0]),
        .gtwiz_buffbypass_tx_reset_in(1'b0),
        .gtwiz_buffbypass_tx_start_user_in(1'b0),
        .gtwiz_gthe3_cpll_cal_bufg_ce_in({1'b0,1'b0}),
        .gtwiz_gthe3_cpll_cal_cnt_tol_in({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .gtwiz_gthe3_cpll_cal_txoutclk_period_in({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .gtwiz_reset_all_in(gtwiz_reset_all_in),
        .gtwiz_reset_clk_freerun_in(gtwiz_reset_clk_freerun_in),
        .gtwiz_reset_qpll0lock_in(1'b0),
        .gtwiz_reset_qpll0reset_out(NLW_inst_gtwiz_reset_qpll0reset_out_UNCONNECTED[0]),
        .gtwiz_reset_qpll1lock_in(1'b0),
        .gtwiz_reset_qpll1reset_out(NLW_inst_gtwiz_reset_qpll1reset_out_UNCONNECTED[0]),
        .gtwiz_reset_rx_cdr_stable_out(gtwiz_reset_rx_cdr_stable_out),
        .gtwiz_reset_rx_datapath_in(gtwiz_reset_rx_datapath_in),
        .gtwiz_reset_rx_done_in(1'b0),
        .gtwiz_reset_rx_done_out(gtwiz_reset_rx_done_out),
        .gtwiz_reset_rx_pll_and_datapath_in(gtwiz_reset_rx_pll_and_datapath_in),
        .gtwiz_reset_tx_datapath_in(gtwiz_reset_tx_datapath_in),
        .gtwiz_reset_tx_done_in(1'b0),
        .gtwiz_reset_tx_done_out(gtwiz_reset_tx_done_out),
        .gtwiz_reset_tx_pll_and_datapath_in(gtwiz_reset_tx_pll_and_datapath_in),
        .gtwiz_userclk_rx_active_in(gtwiz_userclk_rx_active_in),
        .gtwiz_userclk_rx_active_out(NLW_inst_gtwiz_userclk_rx_active_out_UNCONNECTED[0]),
        .gtwiz_userclk_rx_reset_in(1'b0),
        .gtwiz_userclk_rx_srcclk_out(NLW_inst_gtwiz_userclk_rx_srcclk_out_UNCONNECTED[0]),
        .gtwiz_userclk_rx_usrclk2_out(NLW_inst_gtwiz_userclk_rx_usrclk2_out_UNCONNECTED[0]),
        .gtwiz_userclk_rx_usrclk_out(NLW_inst_gtwiz_userclk_rx_usrclk_out_UNCONNECTED[0]),
        .gtwiz_userclk_tx_active_in(gtwiz_userclk_tx_active_in),
        .gtwiz_userclk_tx_active_out(NLW_inst_gtwiz_userclk_tx_active_out_UNCONNECTED[0]),
        .gtwiz_userclk_tx_reset_in(1'b0),
        .gtwiz_userclk_tx_srcclk_out(NLW_inst_gtwiz_userclk_tx_srcclk_out_UNCONNECTED[0]),
        .gtwiz_userclk_tx_usrclk2_out(NLW_inst_gtwiz_userclk_tx_usrclk2_out_UNCONNECTED[0]),
        .gtwiz_userclk_tx_usrclk_out(NLW_inst_gtwiz_userclk_tx_usrclk_out_UNCONNECTED[0]),
        .gtwiz_userdata_rx_out(gtwiz_userdata_rx_out),
        .gtwiz_userdata_tx_in(gtwiz_userdata_tx_in),
        .gtyrxn_in(1'b0),
        .gtyrxp_in(1'b0),
        .gtytxn_out(NLW_inst_gtytxn_out_UNCONNECTED[0]),
        .gtytxp_out(NLW_inst_gtytxp_out_UNCONNECTED[0]),
        .loopback_in({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .looprsvd_in(1'b0),
        .lpbkrxtxseren_in({1'b0,1'b0}),
        .lpbktxrxseren_in({1'b0,1'b0}),
        .pcieeqrxeqadaptdone_in({1'b0,1'b0}),
        .pcierategen3_out(NLW_inst_pcierategen3_out_UNCONNECTED[1:0]),
        .pcierateidle_out(NLW_inst_pcierateidle_out_UNCONNECTED[1:0]),
        .pcierateqpllpd_out(NLW_inst_pcierateqpllpd_out_UNCONNECTED[3:0]),
        .pcierateqpllreset_out(NLW_inst_pcierateqpllreset_out_UNCONNECTED[3:0]),
        .pcierstidle_in({1'b0,1'b0}),
        .pciersttxsyncstart_in({1'b0,1'b0}),
        .pciesynctxsyncdone_out(NLW_inst_pciesynctxsyncdone_out_UNCONNECTED[1:0]),
        .pcieusergen3rdy_out(NLW_inst_pcieusergen3rdy_out_UNCONNECTED[1:0]),
        .pcieuserphystatusrst_out(NLW_inst_pcieuserphystatusrst_out_UNCONNECTED[1:0]),
        .pcieuserratedone_in({1'b0,1'b0}),
        .pcieuserratestart_out(NLW_inst_pcieuserratestart_out_UNCONNECTED[1:0]),
        .pcsrsvdin2_in({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .pcsrsvdin_in({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .pcsrsvdout_out(NLW_inst_pcsrsvdout_out_UNCONNECTED[23:0]),
        .phystatus_out(NLW_inst_phystatus_out_UNCONNECTED[1:0]),
        .pinrsrvdas_out(NLW_inst_pinrsrvdas_out_UNCONNECTED[15:0]),
        .pmarsvd0_in({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .pmarsvd1_in({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .pmarsvdin_in({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .pmarsvdout0_out(NLW_inst_pmarsvdout0_out_UNCONNECTED[7:0]),
        .pmarsvdout1_out(NLW_inst_pmarsvdout1_out_UNCONNECTED[7:0]),
        .qpll0clk_in({1'b0,1'b0}),
        .qpll0clkrsvd0_in(1'b0),
        .qpll0clkrsvd1_in(1'b0),
        .qpll0fbclklost_out(NLW_inst_qpll0fbclklost_out_UNCONNECTED[0]),
        .qpll0lock_out(qpll0lock_out),
        .qpll0lockdetclk_in(1'b0),
        .qpll0locken_in(1'b1),
        .qpll0outclk_out(qpll0outclk_out),
        .qpll0outrefclk_out(qpll0outrefclk_out),
        .qpll0pd_in(1'b0),
        .qpll0refclk_in({1'b0,1'b0}),
        .qpll0refclklost_out(NLW_inst_qpll0refclklost_out_UNCONNECTED[0]),
        .qpll0refclksel_in({1'b0,1'b0,1'b1}),
        .qpll0reset_in(1'b0),
        .qpll1clk_in({1'b0,1'b0}),
        .qpll1clkrsvd0_in(1'b0),
        .qpll1clkrsvd1_in(1'b0),
        .qpll1fbclklost_out(NLW_inst_qpll1fbclklost_out_UNCONNECTED[0]),
        .qpll1lock_out(NLW_inst_qpll1lock_out_UNCONNECTED[0]),
        .qpll1lockdetclk_in(1'b0),
        .qpll1locken_in(1'b0),
        .qpll1outclk_out(NLW_inst_qpll1outclk_out_UNCONNECTED[0]),
        .qpll1outrefclk_out(NLW_inst_qpll1outrefclk_out_UNCONNECTED[0]),
        .qpll1pd_in(1'b1),
        .qpll1refclk_in({1'b0,1'b0}),
        .qpll1refclklost_out(NLW_inst_qpll1refclklost_out_UNCONNECTED[0]),
        .qpll1refclksel_in({1'b0,1'b0,1'b1}),
        .qpll1reset_in(1'b1),
        .qplldmonitor0_out(NLW_inst_qplldmonitor0_out_UNCONNECTED[7:0]),
        .qplldmonitor1_out(NLW_inst_qplldmonitor1_out_UNCONNECTED[7:0]),
        .qpllrsvd1_in({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .qpllrsvd2_in({1'b0,1'b0,1'b0,1'b0,1'b0}),
        .qpllrsvd3_in({1'b0,1'b0,1'b0,1'b0,1'b0}),
        .qpllrsvd4_in({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .rcalenb_in(1'b1),
        .refclkoutmonitor0_out(NLW_inst_refclkoutmonitor0_out_UNCONNECTED[0]),
        .refclkoutmonitor1_out(NLW_inst_refclkoutmonitor1_out_UNCONNECTED[0]),
        .resetexception_out(NLW_inst_resetexception_out_UNCONNECTED[1:0]),
        .resetovrd_in({1'b0,1'b0}),
        .rstclkentx_in({1'b0,1'b0}),
        .rx8b10ben_in(rx8b10ben_in),
        .rxbufreset_in({1'b0,1'b0}),
        .rxbufstatus_out(NLW_inst_rxbufstatus_out_UNCONNECTED[5:0]),
        .rxbyteisaligned_out(rxbyteisaligned_out),
        .rxbyterealign_out(rxbyterealign_out),
        .rxcdrfreqreset_in({1'b0,1'b0}),
        .rxcdrhold_in({1'b0,1'b0}),
        .rxcdrlock_out(NLW_inst_rxcdrlock_out_UNCONNECTED[1:0]),
        .rxcdrovrden_in({1'b0,1'b0}),
        .rxcdrphdone_out(NLW_inst_rxcdrphdone_out_UNCONNECTED[1:0]),
        .rxcdrreset_in({1'b0,1'b0}),
        .rxcdrresetrsv_in({1'b0,1'b0}),
        .rxchanbondseq_out(NLW_inst_rxchanbondseq_out_UNCONNECTED[1:0]),
        .rxchanisaligned_out(NLW_inst_rxchanisaligned_out_UNCONNECTED[1:0]),
        .rxchanrealign_out(NLW_inst_rxchanrealign_out_UNCONNECTED[1:0]),
        .rxchbonden_in({1'b0,1'b0}),
        .rxchbondi_in({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .rxchbondlevel_in({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .rxchbondmaster_in({1'b0,1'b0}),
        .rxchbondo_out(NLW_inst_rxchbondo_out_UNCONNECTED[9:0]),
        .rxchbondslave_in({1'b0,1'b0}),
        .rxckcaldone_out(NLW_inst_rxckcaldone_out_UNCONNECTED[0]),
        .rxckcalreset_in(1'b0),
        .rxclkcorcnt_out(NLW_inst_rxclkcorcnt_out_UNCONNECTED[3:0]),
        .rxcominitdet_out(NLW_inst_rxcominitdet_out_UNCONNECTED[1:0]),
        .rxcommadet_out(rxcommadet_out),
        .rxcommadeten_in(rxcommadeten_in),
        .rxcomsasdet_out(NLW_inst_rxcomsasdet_out_UNCONNECTED[1:0]),
        .rxcomwakedet_out(NLW_inst_rxcomwakedet_out_UNCONNECTED[1:0]),
        .rxctrl0_out(rxctrl0_out),
        .rxctrl1_out(rxctrl1_out),
        .rxctrl2_out(rxctrl2_out),
        .rxctrl3_out(rxctrl3_out),
        .rxdata_out(NLW_inst_rxdata_out_UNCONNECTED[255:0]),
        .rxdataextendrsvd_out(NLW_inst_rxdataextendrsvd_out_UNCONNECTED[15:0]),
        .rxdatavalid_out(NLW_inst_rxdatavalid_out_UNCONNECTED[3:0]),
        .rxdccforcestart_in(1'b0),
        .rxdfeagcctrl_in({1'b0,1'b1,1'b0,1'b1}),
        .rxdfeagchold_in({1'b0,1'b0}),
        .rxdfeagcovrden_in({1'b0,1'b0}),
        .rxdfelfhold_in({1'b0,1'b0}),
        .rxdfelfovrden_in({1'b0,1'b0}),
        .rxdfelpmreset_in({1'b0,1'b0}),
        .rxdfetap10hold_in({1'b0,1'b0}),
        .rxdfetap10ovrden_in({1'b0,1'b0}),
        .rxdfetap11hold_in({1'b0,1'b0}),
        .rxdfetap11ovrden_in({1'b0,1'b0}),
        .rxdfetap12hold_in({1'b0,1'b0}),
        .rxdfetap12ovrden_in({1'b0,1'b0}),
        .rxdfetap13hold_in({1'b0,1'b0}),
        .rxdfetap13ovrden_in({1'b0,1'b0}),
        .rxdfetap14hold_in({1'b0,1'b0}),
        .rxdfetap14ovrden_in({1'b0,1'b0}),
        .rxdfetap15hold_in({1'b0,1'b0}),
        .rxdfetap15ovrden_in({1'b0,1'b0}),
        .rxdfetap2hold_in({1'b0,1'b0}),
        .rxdfetap2ovrden_in({1'b0,1'b0}),
        .rxdfetap3hold_in({1'b0,1'b0}),
        .rxdfetap3ovrden_in({1'b0,1'b0}),
        .rxdfetap4hold_in({1'b0,1'b0}),
        .rxdfetap4ovrden_in({1'b0,1'b0}),
        .rxdfetap5hold_in({1'b0,1'b0}),
        .rxdfetap5ovrden_in({1'b0,1'b0}),
        .rxdfetap6hold_in({1'b0,1'b0}),
        .rxdfetap6ovrden_in({1'b0,1'b0}),
        .rxdfetap7hold_in({1'b0,1'b0}),
        .rxdfetap7ovrden_in({1'b0,1'b0}),
        .rxdfetap8hold_in({1'b0,1'b0}),
        .rxdfetap8ovrden_in({1'b0,1'b0}),
        .rxdfetap9hold_in({1'b0,1'b0}),
        .rxdfetap9ovrden_in({1'b0,1'b0}),
        .rxdfeuthold_in({1'b0,1'b0}),
        .rxdfeutovrden_in({1'b0,1'b0}),
        .rxdfevphold_in({1'b0,1'b0}),
        .rxdfevpovrden_in({1'b0,1'b0}),
        .rxdfevsen_in({1'b0,1'b0}),
        .rxdfexyden_in({1'b1,1'b1}),
        .rxdlybypass_in({1'b1,1'b1}),
        .rxdlyen_in({1'b0,1'b0}),
        .rxdlyovrden_in({1'b0,1'b0}),
        .rxdlysreset_in({1'b0,1'b0}),
        .rxdlysresetdone_out(NLW_inst_rxdlysresetdone_out_UNCONNECTED[1:0]),
        .rxelecidle_out(NLW_inst_rxelecidle_out_UNCONNECTED[1:0]),
        .rxelecidlemode_in({1'b1,1'b1,1'b1,1'b1}),
        .rxgearboxslip_in({1'b0,1'b0}),
        .rxheader_out(NLW_inst_rxheader_out_UNCONNECTED[11:0]),
        .rxheadervalid_out(NLW_inst_rxheadervalid_out_UNCONNECTED[3:0]),
        .rxlatclk_in({1'b0,1'b0}),
        .rxlpmen_in({1'b0,1'b0}),
        .rxlpmgchold_in({1'b0,1'b0}),
        .rxlpmgcovrden_in({1'b0,1'b0}),
        .rxlpmhfhold_in({1'b0,1'b0}),
        .rxlpmhfovrden_in({1'b0,1'b0}),
        .rxlpmlfhold_in({1'b0,1'b0}),
        .rxlpmlfklovrden_in({1'b0,1'b0}),
        .rxlpmoshold_in({1'b0,1'b0}),
        .rxlpmosovrden_in({1'b0,1'b0}),
        .rxmcommaalignen_in(rxmcommaalignen_in),
        .rxmonitorout_out(NLW_inst_rxmonitorout_out_UNCONNECTED[13:0]),
        .rxmonitorsel_in({1'b0,1'b0,1'b0,1'b0}),
        .rxoobreset_in({1'b0,1'b0}),
        .rxoscalreset_in({1'b0,1'b0}),
        .rxoshold_in({1'b0,1'b0}),
        .rxosintcfg_in({1'b1,1'b1,1'b0,1'b1,1'b1,1'b1,1'b0,1'b1}),
        .rxosintdone_out(NLW_inst_rxosintdone_out_UNCONNECTED[1:0]),
        .rxosinten_in({1'b1,1'b1}),
        .rxosinthold_in({1'b0,1'b0}),
        .rxosintovrden_in({1'b0,1'b0}),
        .rxosintstarted_out(NLW_inst_rxosintstarted_out_UNCONNECTED[1:0]),
        .rxosintstrobe_in({1'b0,1'b0}),
        .rxosintstrobedone_out(NLW_inst_rxosintstrobedone_out_UNCONNECTED[1:0]),
        .rxosintstrobestarted_out(NLW_inst_rxosintstrobestarted_out_UNCONNECTED[1:0]),
        .rxosinttestovrden_in({1'b0,1'b0}),
        .rxosovrden_in({1'b0,1'b0}),
        .rxoutclk_out(rxoutclk_out),
        .rxoutclkfabric_out(NLW_inst_rxoutclkfabric_out_UNCONNECTED[1:0]),
        .rxoutclkpcs_out(NLW_inst_rxoutclkpcs_out_UNCONNECTED[1:0]),
        .rxoutclksel_in({1'b0,1'b1,1'b0,1'b0,1'b1,1'b0}),
        .rxpcommaalignen_in(rxpcommaalignen_in),
        .rxpcsreset_in({1'b0,1'b0}),
        .rxpd_in({1'b0,1'b0,1'b0,1'b0}),
        .rxphalign_in({1'b0,1'b0}),
        .rxphaligndone_out(NLW_inst_rxphaligndone_out_UNCONNECTED[1:0]),
        .rxphalignen_in({1'b0,1'b0}),
        .rxphalignerr_out(NLW_inst_rxphalignerr_out_UNCONNECTED[1:0]),
        .rxphdlypd_in({1'b1,1'b1}),
        .rxphdlyreset_in({1'b0,1'b0}),
        .rxphovrden_in({1'b0,1'b0}),
        .rxpllclksel_in({1'b1,1'b1,1'b1,1'b1}),
        .rxpmareset_in({1'b0,1'b0}),
        .rxpmaresetdone_out(rxpmaresetdone_out),
        .rxpolarity_in(rxpolarity_in),
        .rxprbscntreset_in({1'b0,1'b0}),
        .rxprbserr_out(NLW_inst_rxprbserr_out_UNCONNECTED[1:0]),
        .rxprbslocked_out(NLW_inst_rxprbslocked_out_UNCONNECTED[1:0]),
        .rxprbssel_in({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .rxprgdivresetdone_out(NLW_inst_rxprgdivresetdone_out_UNCONNECTED[1:0]),
        .rxprogdivreset_in({1'b0,1'b0}),
        .rxqpien_in({1'b0,1'b0}),
        .rxqpisenn_out(NLW_inst_rxqpisenn_out_UNCONNECTED[1:0]),
        .rxqpisenp_out(NLW_inst_rxqpisenp_out_UNCONNECTED[1:0]),
        .rxrate_in({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .rxratedone_out(NLW_inst_rxratedone_out_UNCONNECTED[1:0]),
        .rxratemode_in({1'b0,1'b0}),
        .rxrecclk0_sel_out(NLW_inst_rxrecclk0_sel_out_UNCONNECTED[1:0]),
        .rxrecclk1_sel_out(NLW_inst_rxrecclk1_sel_out_UNCONNECTED[1:0]),
        .rxrecclkout_out(NLW_inst_rxrecclkout_out_UNCONNECTED[1:0]),
        .rxresetdone_out(NLW_inst_rxresetdone_out_UNCONNECTED[1:0]),
        .rxslide_in({1'b0,1'b0}),
        .rxsliderdy_out(NLW_inst_rxsliderdy_out_UNCONNECTED[1:0]),
        .rxslipdone_out(NLW_inst_rxslipdone_out_UNCONNECTED[1:0]),
        .rxslipoutclk_in({1'b0,1'b0}),
        .rxslipoutclkrdy_out(NLW_inst_rxslipoutclkrdy_out_UNCONNECTED[1:0]),
        .rxslippma_in({1'b0,1'b0}),
        .rxslippmardy_out(NLW_inst_rxslippmardy_out_UNCONNECTED[1:0]),
        .rxstartofseq_out(NLW_inst_rxstartofseq_out_UNCONNECTED[3:0]),
        .rxstatus_out(NLW_inst_rxstatus_out_UNCONNECTED[5:0]),
        .rxsyncallin_in({1'b0,1'b0}),
        .rxsyncdone_out(NLW_inst_rxsyncdone_out_UNCONNECTED[1:0]),
        .rxsyncin_in({1'b0,1'b0}),
        .rxsyncmode_in({1'b0,1'b0}),
        .rxsyncout_out(NLW_inst_rxsyncout_out_UNCONNECTED[1:0]),
        .rxsysclksel_in({1'b1,1'b0,1'b1,1'b0}),
        .rxuserrdy_in({1'b1,1'b1}),
        .rxusrclk2_in(rxusrclk2_in),
        .rxusrclk_in(rxusrclk_in),
        .rxvalid_out(NLW_inst_rxvalid_out_UNCONNECTED[1:0]),
        .sdm0data_in(1'b0),
        .sdm0finalout_out(NLW_inst_sdm0finalout_out_UNCONNECTED[0]),
        .sdm0reset_in(1'b0),
        .sdm0testdata_out(NLW_inst_sdm0testdata_out_UNCONNECTED[0]),
        .sdm0width_in(1'b0),
        .sdm1data_in(1'b0),
        .sdm1finalout_out(NLW_inst_sdm1finalout_out_UNCONNECTED[0]),
        .sdm1reset_in(1'b0),
        .sdm1testdata_out(NLW_inst_sdm1testdata_out_UNCONNECTED[0]),
        .sdm1width_in(1'b0),
        .sigvalidclk_in({1'b0,1'b0}),
        .tstin_in({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .tx8b10bbypass_in({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .tx8b10ben_in(tx8b10ben_in),
        .txbufdiffctrl_in({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .txbufstatus_out(NLW_inst_txbufstatus_out_UNCONNECTED[3:0]),
        .txcomfinish_out(NLW_inst_txcomfinish_out_UNCONNECTED[1:0]),
        .txcominit_in({1'b0,1'b0}),
        .txcomsas_in({1'b0,1'b0}),
        .txcomwake_in({1'b0,1'b0}),
        .txctrl0_in(txctrl0_in),
        .txctrl1_in(txctrl1_in),
        .txctrl2_in(txctrl2_in),
        .txdata_in({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .txdataextendrsvd_in({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .txdccdone_out(NLW_inst_txdccdone_out_UNCONNECTED[0]),
        .txdccforcestart_in(1'b0),
        .txdccreset_in(1'b0),
        .txdeemph_in({1'b0,1'b0}),
        .txdetectrx_in({1'b0,1'b0}),
        .txdiffctrl_in({1'b1,1'b1,1'b0,1'b0,1'b1,1'b1,1'b0,1'b0}),
        .txdiffpd_in({1'b0,1'b0}),
        .txdlybypass_in({1'b1,1'b1}),
        .txdlyen_in({1'b0,1'b0}),
        .txdlyhold_in({1'b0,1'b0}),
        .txdlyovrden_in({1'b0,1'b0}),
        .txdlysreset_in({1'b0,1'b0}),
        .txdlysresetdone_out(NLW_inst_txdlysresetdone_out_UNCONNECTED[1:0]),
        .txdlyupdown_in({1'b0,1'b0}),
        .txelecidle_in({1'b0,1'b0}),
        .txelforcestart_in(1'b0),
        .txheader_in({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .txinhibit_in({1'b0,1'b0}),
        .txlatclk_in({1'b0,1'b0}),
        .txmaincursor_in({1'b1,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b1,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .txmargin_in({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .txoutclk_out(txoutclk_out),
        .txoutclkfabric_out(NLW_inst_txoutclkfabric_out_UNCONNECTED[1:0]),
        .txoutclkpcs_out(NLW_inst_txoutclkpcs_out_UNCONNECTED[1:0]),
        .txoutclksel_in({1'b0,1'b1,1'b0,1'b0,1'b1,1'b0}),
        .txpcsreset_in({1'b0,1'b0}),
        .txpd_in({1'b0,1'b0,1'b0,1'b0}),
        .txpdelecidlemode_in({1'b0,1'b0}),
        .txphalign_in({1'b0,1'b0}),
        .txphaligndone_out(NLW_inst_txphaligndone_out_UNCONNECTED[1:0]),
        .txphalignen_in({1'b0,1'b0}),
        .txphdlypd_in({1'b1,1'b1}),
        .txphdlyreset_in({1'b0,1'b0}),
        .txphdlytstclk_in({1'b0,1'b0}),
        .txphinit_in({1'b0,1'b0}),
        .txphinitdone_out(NLW_inst_txphinitdone_out_UNCONNECTED[1:0]),
        .txphovrden_in({1'b0,1'b0}),
        .txpippmen_in({1'b0,1'b0}),
        .txpippmovrden_in({1'b0,1'b0}),
        .txpippmpd_in({1'b0,1'b0}),
        .txpippmsel_in({1'b0,1'b0}),
        .txpippmstepsize_in({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .txpisopd_in({1'b0,1'b0}),
        .txpllclksel_in({1'b1,1'b1,1'b1,1'b1}),
        .txpmareset_in({1'b0,1'b0}),
        .txpmaresetdone_out(txpmaresetdone_out),
        .txpolarity_in(txpolarity_in),
        .txpostcursor_in({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .txpostcursorinv_in({1'b0,1'b0}),
        .txprbsforceerr_in({1'b0,1'b0}),
        .txprbssel_in({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .txprecursor_in({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .txprecursorinv_in({1'b0,1'b0}),
        .txprgdivresetdone_out(NLW_inst_txprgdivresetdone_out_UNCONNECTED[1:0]),
        .txprogdivreset_in({1'b0,1'b0}),
        .txqpibiasen_in({1'b0,1'b0}),
        .txqpisenn_out(NLW_inst_txqpisenn_out_UNCONNECTED[1:0]),
        .txqpisenp_out(NLW_inst_txqpisenp_out_UNCONNECTED[1:0]),
        .txqpistrongpdown_in({1'b0,1'b0}),
        .txqpiweakpup_in({1'b0,1'b0}),
        .txrate_in({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .txratedone_out(NLW_inst_txratedone_out_UNCONNECTED[1:0]),
        .txratemode_in({1'b0,1'b0}),
        .txresetdone_out(NLW_inst_txresetdone_out_UNCONNECTED[1:0]),
        .txsequence_in({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .txswing_in({1'b0,1'b0}),
        .txsyncallin_in({1'b0,1'b0}),
        .txsyncdone_out(NLW_inst_txsyncdone_out_UNCONNECTED[1:0]),
        .txsyncin_in({1'b0,1'b0}),
        .txsyncmode_in({1'b0,1'b0}),
        .txsyncout_out(NLW_inst_txsyncout_out_UNCONNECTED[1:0]),
        .txsysclksel_in({1'b1,1'b0,1'b1,1'b0}),
        .txuserrdy_in({1'b1,1'b1}),
        .txusrclk2_in(txusrclk2_in),
        .txusrclk_in(txusrclk_in));
endmodule

(* ORIG_REF_NAME = "GthUltrascaleJesdCoregen_gthe3_channel_wrapper" *) 
module GthUltrascaleJesdCoregen_GthUltrascaleJesdCoregen_gthe3_channel_wrapper
   (O1,
    gtpowergood_out,
    O2,
    txresetdone_out,
    O3,
    rxcdrlock_out,
    O4,
    rxresetdone_out,
    cpllfbclklost_out,
    cplllock_out,
    cpllrefclklost_out,
    drprdy_out,
    eyescandataerror_out,
    gthtxn_out,
    gthtxp_out,
    gtrefclkmonitor_out,
    pcierategen3_out,
    pcierateidle_out,
    pciesynctxsyncdone_out,
    pcieusergen3rdy_out,
    pcieuserphystatusrst_out,
    pcieuserratestart_out,
    phystatus_out,
    resetexception_out,
    rxbyteisaligned_out,
    rxbyterealign_out,
    rxcdrphdone_out,
    rxchanbondseq_out,
    rxchanisaligned_out,
    rxchanrealign_out,
    rxcominitdet_out,
    rxcommadet_out,
    rxcomsasdet_out,
    rxcomwakedet_out,
    rxdlysresetdone_out,
    rxelecidle_out,
    rxosintdone_out,
    rxosintstarted_out,
    rxosintstrobedone_out,
    rxosintstrobestarted_out,
    rxoutclk_out,
    rxoutclkfabric_out,
    rxoutclkpcs_out,
    rxphaligndone_out,
    rxphalignerr_out,
    rxpmaresetdone_out,
    rxprbserr_out,
    rxprbslocked_out,
    rxprgdivresetdone_out,
    rxqpisenn_out,
    rxqpisenp_out,
    rxratedone_out,
    rxrecclkout_out,
    rxsliderdy_out,
    rxslipdone_out,
    rxslipoutclkrdy_out,
    rxslippmardy_out,
    rxsyncdone_out,
    rxsyncout_out,
    rxvalid_out,
    txcomfinish_out,
    txdlysresetdone_out,
    txoutclk_out,
    txoutclkfabric_out,
    txoutclkpcs_out,
    txphaligndone_out,
    txphinitdone_out,
    txpmaresetdone_out,
    txprgdivresetdone_out,
    txqpisenn_out,
    txqpisenp_out,
    txratedone_out,
    txsyncdone_out,
    txsyncout_out,
    pcsrsvdout_out,
    rxdata_out,
    drpdo_out,
    rxctrl0_out,
    rxctrl1_out,
    dmonitorout_out,
    pcierateqpllpd_out,
    pcierateqpllreset_out,
    rxclkcorcnt_out,
    rxdatavalid_out,
    rxheadervalid_out,
    rxstartofseq_out,
    txbufstatus_out,
    bufgtce_out,
    bufgtcemask_out,
    bufgtreset_out,
    bufgtrstmask_out,
    rxbufstatus_out,
    rxstatus_out,
    rxchbondo_out,
    rxheader_out,
    rxmonitorout_out,
    pinrsrvdas_out,
    rxctrl2_out,
    rxctrl3_out,
    rxdataextendrsvd_out,
    bufgtdiv_out,
    cfgreset_in,
    clkrsvd0_in,
    clkrsvd1_in,
    cplllockdetclk_in,
    cplllocken_in,
    cpllpd_in,
    cpllreset_in,
    dmonfiforeset_in,
    dmonitorclk_in,
    drpclk_in,
    drpen_in,
    drpwe_in,
    evoddphicaldone_in,
    evoddphicalstart_in,
    evoddphidrden_in,
    evoddphidwren_in,
    evoddphixrden_in,
    evoddphixwren_in,
    eyescanmode_in,
    eyescanreset_in,
    eyescantrigger_in,
    gtgrefclk_in,
    gthrxn_in,
    gthrxp_in,
    gtnorthrefclk0_in,
    gtnorthrefclk1_in,
    gtrefclk0_in,
    gtrefclk1_in,
    gtresetsel_in,
    GTHE3_CHANNEL_GTRXRESET,
    gtsouthrefclk0_in,
    gtsouthrefclk1_in,
    GTHE3_CHANNEL_GTTXRESET,
    lpbkrxtxseren_in,
    lpbktxrxseren_in,
    pcieeqrxeqadaptdone_in,
    pcierstidle_in,
    pciersttxsyncstart_in,
    pcieuserratedone_in,
    qpll0outclk_out,
    qpll0outrefclk_out,
    qpll1outclk_out,
    qpll1outrefclk_out,
    resetovrd_in,
    rstclkentx_in,
    rx8b10ben_in,
    rxbufreset_in,
    rxcdrfreqreset_in,
    rxcdrhold_in,
    rxcdrovrden_in,
    rxcdrreset_in,
    rxcdrresetrsv_in,
    rxchbonden_in,
    rxchbondmaster_in,
    rxchbondslave_in,
    rxcommadeten_in,
    rxdfeagchold_in,
    rxdfeagcovrden_in,
    rxdfelfhold_in,
    rxdfelfovrden_in,
    rxdfelpmreset_in,
    rxdfetap10hold_in,
    rxdfetap10ovrden_in,
    rxdfetap11hold_in,
    rxdfetap11ovrden_in,
    rxdfetap12hold_in,
    rxdfetap12ovrden_in,
    rxdfetap13hold_in,
    rxdfetap13ovrden_in,
    rxdfetap14hold_in,
    rxdfetap14ovrden_in,
    rxdfetap15hold_in,
    rxdfetap15ovrden_in,
    rxdfetap2hold_in,
    rxdfetap2ovrden_in,
    rxdfetap3hold_in,
    rxdfetap3ovrden_in,
    rxdfetap4hold_in,
    rxdfetap4ovrden_in,
    rxdfetap5hold_in,
    rxdfetap5ovrden_in,
    rxdfetap6hold_in,
    rxdfetap6ovrden_in,
    rxdfetap7hold_in,
    rxdfetap7ovrden_in,
    rxdfetap8hold_in,
    rxdfetap8ovrden_in,
    rxdfetap9hold_in,
    rxdfetap9ovrden_in,
    rxdfeuthold_in,
    rxdfeutovrden_in,
    rxdfevphold_in,
    rxdfevpovrden_in,
    rxdfevsen_in,
    rxdfexyden_in,
    rxdlybypass_in,
    rxdlyen_in,
    rxdlyovrden_in,
    rxdlysreset_in,
    rxgearboxslip_in,
    rxlatclk_in,
    rxlpmen_in,
    rxlpmgchold_in,
    rxlpmgcovrden_in,
    rxlpmhfhold_in,
    rxlpmhfovrden_in,
    rxlpmlfhold_in,
    rxlpmlfklovrden_in,
    rxlpmoshold_in,
    rxlpmosovrden_in,
    rxmcommaalignen_in,
    rxoobreset_in,
    rxoscalreset_in,
    rxoshold_in,
    rxosinten_in,
    rxosinthold_in,
    rxosintovrden_in,
    rxosintstrobe_in,
    rxosinttestovrden_in,
    rxosovrden_in,
    rxpcommaalignen_in,
    rxpcsreset_in,
    rxphalign_in,
    rxphalignen_in,
    rxphdlypd_in,
    rxphdlyreset_in,
    rxphovrden_in,
    rxpmareset_in,
    rxpolarity_in,
    rxprbscntreset_in,
    GTHE3_CHANNEL_RXPROGDIVRESET,
    rxqpien_in,
    rxratemode_in,
    rxslide_in,
    rxslipoutclk_in,
    rxslippma_in,
    rxsyncallin_in,
    rxsyncin_in,
    rxsyncmode_in,
    GTHE3_CHANNEL_RXUSERRDY,
    rxusrclk_in,
    rxusrclk2_in,
    sigvalidclk_in,
    tx8b10ben_in,
    txcominit_in,
    txcomsas_in,
    txcomwake_in,
    txdeemph_in,
    txdetectrx_in,
    txdiffpd_in,
    txdlybypass_in,
    txdlyen_in,
    txdlyhold_in,
    txdlyovrden_in,
    txdlysreset_in,
    txdlyupdown_in,
    txelecidle_in,
    txinhibit_in,
    txlatclk_in,
    txpcsreset_in,
    txpdelecidlemode_in,
    txphalign_in,
    txphalignen_in,
    txphdlypd_in,
    txphdlyreset_in,
    txphdlytstclk_in,
    txphinit_in,
    txphovrden_in,
    txpippmen_in,
    txpippmovrden_in,
    txpippmpd_in,
    txpippmsel_in,
    txpisopd_in,
    txpmareset_in,
    txpolarity_in,
    txpostcursorinv_in,
    txprbsforceerr_in,
    txprecursorinv_in,
    GTHE3_CHANNEL_TXPROGDIVRESET,
    txqpibiasen_in,
    txqpistrongpdown_in,
    txqpiweakpup_in,
    txratemode_in,
    txswing_in,
    txsyncallin_in,
    txsyncin_in,
    txsyncmode_in,
    GTHE3_CHANNEL_TXUSERRDY,
    txusrclk_in,
    txusrclk2_in,
    gtwiz_userdata_tx_in,
    drpdi_in,
    gtrsvd_in,
    pcsrsvdin_in,
    txctrl0_in,
    txctrl1_in,
    rxdfeagcctrl_in,
    rxelecidlemode_in,
    rxmonitorsel_in,
    rxpd_in,
    rxpllclksel_in,
    rxsysclksel_in,
    txpd_in,
    txpllclksel_in,
    txsysclksel_in,
    cpllrefclksel_in,
    loopback_in,
    rxchbondlevel_in,
    rxoutclksel_in,
    rxrate_in,
    txbufdiffctrl_in,
    txmargin_in,
    txoutclksel_in,
    txrate_in,
    rxosintcfg_in,
    rxprbssel_in,
    txdiffctrl_in,
    txprbssel_in,
    pcsrsvdin2_in,
    pmarsvdin_in,
    rxchbondi_in,
    txpippmstepsize_in,
    txpostcursor_in,
    txprecursor_in,
    txheader_in,
    txmaincursor_in,
    txsequence_in,
    tx8b10bbypass_in,
    txctrl2_in,
    txdataextendrsvd_in,
    drpaddr_in);
  output O1;
  output [1:0]gtpowergood_out;
  output O2;
  output [1:0]txresetdone_out;
  output O3;
  output [1:0]rxcdrlock_out;
  output O4;
  output [1:0]rxresetdone_out;
  output [1:0]cpllfbclklost_out;
  output [1:0]cplllock_out;
  output [1:0]cpllrefclklost_out;
  output [1:0]drprdy_out;
  output [1:0]eyescandataerror_out;
  output [1:0]gthtxn_out;
  output [1:0]gthtxp_out;
  output [1:0]gtrefclkmonitor_out;
  output [1:0]pcierategen3_out;
  output [1:0]pcierateidle_out;
  output [1:0]pciesynctxsyncdone_out;
  output [1:0]pcieusergen3rdy_out;
  output [1:0]pcieuserphystatusrst_out;
  output [1:0]pcieuserratestart_out;
  output [1:0]phystatus_out;
  output [1:0]resetexception_out;
  output [1:0]rxbyteisaligned_out;
  output [1:0]rxbyterealign_out;
  output [1:0]rxcdrphdone_out;
  output [1:0]rxchanbondseq_out;
  output [1:0]rxchanisaligned_out;
  output [1:0]rxchanrealign_out;
  output [1:0]rxcominitdet_out;
  output [1:0]rxcommadet_out;
  output [1:0]rxcomsasdet_out;
  output [1:0]rxcomwakedet_out;
  output [1:0]rxdlysresetdone_out;
  output [1:0]rxelecidle_out;
  output [1:0]rxosintdone_out;
  output [1:0]rxosintstarted_out;
  output [1:0]rxosintstrobedone_out;
  output [1:0]rxosintstrobestarted_out;
  output [1:0]rxoutclk_out;
  output [1:0]rxoutclkfabric_out;
  output [1:0]rxoutclkpcs_out;
  output [1:0]rxphaligndone_out;
  output [1:0]rxphalignerr_out;
  output [1:0]rxpmaresetdone_out;
  output [1:0]rxprbserr_out;
  output [1:0]rxprbslocked_out;
  output [1:0]rxprgdivresetdone_out;
  output [1:0]rxqpisenn_out;
  output [1:0]rxqpisenp_out;
  output [1:0]rxratedone_out;
  output [1:0]rxrecclkout_out;
  output [1:0]rxsliderdy_out;
  output [1:0]rxslipdone_out;
  output [1:0]rxslipoutclkrdy_out;
  output [1:0]rxslippmardy_out;
  output [1:0]rxsyncdone_out;
  output [1:0]rxsyncout_out;
  output [1:0]rxvalid_out;
  output [1:0]txcomfinish_out;
  output [1:0]txdlysresetdone_out;
  output [1:0]txoutclk_out;
  output [1:0]txoutclkfabric_out;
  output [1:0]txoutclkpcs_out;
  output [1:0]txphaligndone_out;
  output [1:0]txphinitdone_out;
  output [1:0]txpmaresetdone_out;
  output [1:0]txprgdivresetdone_out;
  output [1:0]txqpisenn_out;
  output [1:0]txqpisenp_out;
  output [1:0]txratedone_out;
  output [1:0]txsyncdone_out;
  output [1:0]txsyncout_out;
  output [23:0]pcsrsvdout_out;
  output [255:0]rxdata_out;
  output [31:0]drpdo_out;
  output [31:0]rxctrl0_out;
  output [31:0]rxctrl1_out;
  output [33:0]dmonitorout_out;
  output [3:0]pcierateqpllpd_out;
  output [3:0]pcierateqpllreset_out;
  output [3:0]rxclkcorcnt_out;
  output [3:0]rxdatavalid_out;
  output [3:0]rxheadervalid_out;
  output [3:0]rxstartofseq_out;
  output [3:0]txbufstatus_out;
  output [5:0]bufgtce_out;
  output [5:0]bufgtcemask_out;
  output [5:0]bufgtreset_out;
  output [5:0]bufgtrstmask_out;
  output [5:0]rxbufstatus_out;
  output [5:0]rxstatus_out;
  output [9:0]rxchbondo_out;
  output [11:0]rxheader_out;
  output [13:0]rxmonitorout_out;
  output [15:0]pinrsrvdas_out;
  output [15:0]rxctrl2_out;
  output [15:0]rxctrl3_out;
  output [15:0]rxdataextendrsvd_out;
  output [17:0]bufgtdiv_out;
  input [1:0]cfgreset_in;
  input [1:0]clkrsvd0_in;
  input [1:0]clkrsvd1_in;
  input [1:0]cplllockdetclk_in;
  input [1:0]cplllocken_in;
  input [1:0]cpllpd_in;
  input [1:0]cpllreset_in;
  input [1:0]dmonfiforeset_in;
  input [1:0]dmonitorclk_in;
  input [1:0]drpclk_in;
  input [1:0]drpen_in;
  input [1:0]drpwe_in;
  input [1:0]evoddphicaldone_in;
  input [1:0]evoddphicalstart_in;
  input [1:0]evoddphidrden_in;
  input [1:0]evoddphidwren_in;
  input [1:0]evoddphixrden_in;
  input [1:0]evoddphixwren_in;
  input [1:0]eyescanmode_in;
  input [1:0]eyescanreset_in;
  input [1:0]eyescantrigger_in;
  input [1:0]gtgrefclk_in;
  input [1:0]gthrxn_in;
  input [1:0]gthrxp_in;
  input [1:0]gtnorthrefclk0_in;
  input [1:0]gtnorthrefclk1_in;
  input [1:0]gtrefclk0_in;
  input [1:0]gtrefclk1_in;
  input [1:0]gtresetsel_in;
  input [0:0]GTHE3_CHANNEL_GTRXRESET;
  input [1:0]gtsouthrefclk0_in;
  input [1:0]gtsouthrefclk1_in;
  input [0:0]GTHE3_CHANNEL_GTTXRESET;
  input [1:0]lpbkrxtxseren_in;
  input [1:0]lpbktxrxseren_in;
  input [1:0]pcieeqrxeqadaptdone_in;
  input [1:0]pcierstidle_in;
  input [1:0]pciersttxsyncstart_in;
  input [1:0]pcieuserratedone_in;
  input [0:0]qpll0outclk_out;
  input [0:0]qpll0outrefclk_out;
  input [0:0]qpll1outclk_out;
  input [0:0]qpll1outrefclk_out;
  input [1:0]resetovrd_in;
  input [1:0]rstclkentx_in;
  input [1:0]rx8b10ben_in;
  input [1:0]rxbufreset_in;
  input [1:0]rxcdrfreqreset_in;
  input [1:0]rxcdrhold_in;
  input [1:0]rxcdrovrden_in;
  input [1:0]rxcdrreset_in;
  input [1:0]rxcdrresetrsv_in;
  input [1:0]rxchbonden_in;
  input [1:0]rxchbondmaster_in;
  input [1:0]rxchbondslave_in;
  input [1:0]rxcommadeten_in;
  input [1:0]rxdfeagchold_in;
  input [1:0]rxdfeagcovrden_in;
  input [1:0]rxdfelfhold_in;
  input [1:0]rxdfelfovrden_in;
  input [1:0]rxdfelpmreset_in;
  input [1:0]rxdfetap10hold_in;
  input [1:0]rxdfetap10ovrden_in;
  input [1:0]rxdfetap11hold_in;
  input [1:0]rxdfetap11ovrden_in;
  input [1:0]rxdfetap12hold_in;
  input [1:0]rxdfetap12ovrden_in;
  input [1:0]rxdfetap13hold_in;
  input [1:0]rxdfetap13ovrden_in;
  input [1:0]rxdfetap14hold_in;
  input [1:0]rxdfetap14ovrden_in;
  input [1:0]rxdfetap15hold_in;
  input [1:0]rxdfetap15ovrden_in;
  input [1:0]rxdfetap2hold_in;
  input [1:0]rxdfetap2ovrden_in;
  input [1:0]rxdfetap3hold_in;
  input [1:0]rxdfetap3ovrden_in;
  input [1:0]rxdfetap4hold_in;
  input [1:0]rxdfetap4ovrden_in;
  input [1:0]rxdfetap5hold_in;
  input [1:0]rxdfetap5ovrden_in;
  input [1:0]rxdfetap6hold_in;
  input [1:0]rxdfetap6ovrden_in;
  input [1:0]rxdfetap7hold_in;
  input [1:0]rxdfetap7ovrden_in;
  input [1:0]rxdfetap8hold_in;
  input [1:0]rxdfetap8ovrden_in;
  input [1:0]rxdfetap9hold_in;
  input [1:0]rxdfetap9ovrden_in;
  input [1:0]rxdfeuthold_in;
  input [1:0]rxdfeutovrden_in;
  input [1:0]rxdfevphold_in;
  input [1:0]rxdfevpovrden_in;
  input [1:0]rxdfevsen_in;
  input [1:0]rxdfexyden_in;
  input [1:0]rxdlybypass_in;
  input [1:0]rxdlyen_in;
  input [1:0]rxdlyovrden_in;
  input [1:0]rxdlysreset_in;
  input [1:0]rxgearboxslip_in;
  input [1:0]rxlatclk_in;
  input [1:0]rxlpmen_in;
  input [1:0]rxlpmgchold_in;
  input [1:0]rxlpmgcovrden_in;
  input [1:0]rxlpmhfhold_in;
  input [1:0]rxlpmhfovrden_in;
  input [1:0]rxlpmlfhold_in;
  input [1:0]rxlpmlfklovrden_in;
  input [1:0]rxlpmoshold_in;
  input [1:0]rxlpmosovrden_in;
  input [1:0]rxmcommaalignen_in;
  input [1:0]rxoobreset_in;
  input [1:0]rxoscalreset_in;
  input [1:0]rxoshold_in;
  input [1:0]rxosinten_in;
  input [1:0]rxosinthold_in;
  input [1:0]rxosintovrden_in;
  input [1:0]rxosintstrobe_in;
  input [1:0]rxosinttestovrden_in;
  input [1:0]rxosovrden_in;
  input [1:0]rxpcommaalignen_in;
  input [1:0]rxpcsreset_in;
  input [1:0]rxphalign_in;
  input [1:0]rxphalignen_in;
  input [1:0]rxphdlypd_in;
  input [1:0]rxphdlyreset_in;
  input [1:0]rxphovrden_in;
  input [1:0]rxpmareset_in;
  input [1:0]rxpolarity_in;
  input [1:0]rxprbscntreset_in;
  input [0:0]GTHE3_CHANNEL_RXPROGDIVRESET;
  input [1:0]rxqpien_in;
  input [1:0]rxratemode_in;
  input [1:0]rxslide_in;
  input [1:0]rxslipoutclk_in;
  input [1:0]rxslippma_in;
  input [1:0]rxsyncallin_in;
  input [1:0]rxsyncin_in;
  input [1:0]rxsyncmode_in;
  input [0:0]GTHE3_CHANNEL_RXUSERRDY;
  input [1:0]rxusrclk_in;
  input [1:0]rxusrclk2_in;
  input [1:0]sigvalidclk_in;
  input [1:0]tx8b10ben_in;
  input [1:0]txcominit_in;
  input [1:0]txcomsas_in;
  input [1:0]txcomwake_in;
  input [1:0]txdeemph_in;
  input [1:0]txdetectrx_in;
  input [1:0]txdiffpd_in;
  input [1:0]txdlybypass_in;
  input [1:0]txdlyen_in;
  input [1:0]txdlyhold_in;
  input [1:0]txdlyovrden_in;
  input [1:0]txdlysreset_in;
  input [1:0]txdlyupdown_in;
  input [1:0]txelecidle_in;
  input [1:0]txinhibit_in;
  input [1:0]txlatclk_in;
  input [1:0]txpcsreset_in;
  input [1:0]txpdelecidlemode_in;
  input [1:0]txphalign_in;
  input [1:0]txphalignen_in;
  input [1:0]txphdlypd_in;
  input [1:0]txphdlyreset_in;
  input [1:0]txphdlytstclk_in;
  input [1:0]txphinit_in;
  input [1:0]txphovrden_in;
  input [1:0]txpippmen_in;
  input [1:0]txpippmovrden_in;
  input [1:0]txpippmpd_in;
  input [1:0]txpippmsel_in;
  input [1:0]txpisopd_in;
  input [1:0]txpmareset_in;
  input [1:0]txpolarity_in;
  input [1:0]txpostcursorinv_in;
  input [1:0]txprbsforceerr_in;
  input [1:0]txprecursorinv_in;
  input [0:0]GTHE3_CHANNEL_TXPROGDIVRESET;
  input [1:0]txqpibiasen_in;
  input [1:0]txqpistrongpdown_in;
  input [1:0]txqpiweakpup_in;
  input [1:0]txratemode_in;
  input [1:0]txswing_in;
  input [1:0]txsyncallin_in;
  input [1:0]txsyncin_in;
  input [1:0]txsyncmode_in;
  input [0:0]GTHE3_CHANNEL_TXUSERRDY;
  input [1:0]txusrclk_in;
  input [1:0]txusrclk2_in;
  input [63:0]gtwiz_userdata_tx_in;
  input [31:0]drpdi_in;
  input [31:0]gtrsvd_in;
  input [31:0]pcsrsvdin_in;
  input [31:0]txctrl0_in;
  input [31:0]txctrl1_in;
  input [3:0]rxdfeagcctrl_in;
  input [3:0]rxelecidlemode_in;
  input [3:0]rxmonitorsel_in;
  input [3:0]rxpd_in;
  input [3:0]rxpllclksel_in;
  input [3:0]rxsysclksel_in;
  input [3:0]txpd_in;
  input [3:0]txpllclksel_in;
  input [3:0]txsysclksel_in;
  input [5:0]cpllrefclksel_in;
  input [5:0]loopback_in;
  input [5:0]rxchbondlevel_in;
  input [5:0]rxoutclksel_in;
  input [5:0]rxrate_in;
  input [5:0]txbufdiffctrl_in;
  input [5:0]txmargin_in;
  input [5:0]txoutclksel_in;
  input [5:0]txrate_in;
  input [7:0]rxosintcfg_in;
  input [7:0]rxprbssel_in;
  input [7:0]txdiffctrl_in;
  input [7:0]txprbssel_in;
  input [9:0]pcsrsvdin2_in;
  input [9:0]pmarsvdin_in;
  input [9:0]rxchbondi_in;
  input [9:0]txpippmstepsize_in;
  input [9:0]txpostcursor_in;
  input [9:0]txprecursor_in;
  input [11:0]txheader_in;
  input [13:0]txmaincursor_in;
  input [13:0]txsequence_in;
  input [15:0]tx8b10bbypass_in;
  input [15:0]txctrl2_in;
  input [15:0]txdataextendrsvd_in;
  input [17:0]drpaddr_in;

  wire [0:0]GTHE3_CHANNEL_GTRXRESET;
  wire [0:0]GTHE3_CHANNEL_GTTXRESET;
  wire [0:0]GTHE3_CHANNEL_RXPROGDIVRESET;
  wire [0:0]GTHE3_CHANNEL_RXUSERRDY;
  wire [0:0]GTHE3_CHANNEL_TXPROGDIVRESET;
  wire [0:0]GTHE3_CHANNEL_TXUSERRDY;
  wire O1;
  wire O2;
  wire O3;
  wire O4;
  wire [5:0]bufgtce_out;
  wire [5:0]bufgtcemask_out;
  wire [17:0]bufgtdiv_out;
  wire [5:0]bufgtreset_out;
  wire [5:0]bufgtrstmask_out;
  wire [1:0]cfgreset_in;
  wire [1:0]clkrsvd0_in;
  wire [1:0]clkrsvd1_in;
  wire [1:0]cpllfbclklost_out;
  wire [1:0]cplllock_out;
  wire [1:0]cplllockdetclk_in;
  wire [1:0]cplllocken_in;
  wire [1:0]cpllpd_in;
  wire [1:0]cpllrefclklost_out;
  wire [5:0]cpllrefclksel_in;
  wire [1:0]cpllreset_in;
  wire [1:0]dmonfiforeset_in;
  wire [1:0]dmonitorclk_in;
  wire [33:0]dmonitorout_out;
  wire [17:0]drpaddr_in;
  wire [1:0]drpclk_in;
  wire [31:0]drpdi_in;
  wire [31:0]drpdo_out;
  wire [1:0]drpen_in;
  wire [1:0]drprdy_out;
  wire [1:0]drpwe_in;
  wire [1:0]evoddphicaldone_in;
  wire [1:0]evoddphicalstart_in;
  wire [1:0]evoddphidrden_in;
  wire [1:0]evoddphidwren_in;
  wire [1:0]evoddphixrden_in;
  wire [1:0]evoddphixwren_in;
  wire [1:0]eyescandataerror_out;
  wire [1:0]eyescanmode_in;
  wire [1:0]eyescanreset_in;
  wire [1:0]eyescantrigger_in;
  wire [1:0]gtgrefclk_in;
  wire [1:0]gthrxn_in;
  wire [1:0]gthrxp_in;
  wire [1:0]gthtxn_out;
  wire [1:0]gthtxp_out;
  wire [1:0]gtnorthrefclk0_in;
  wire [1:0]gtnorthrefclk1_in;
  wire [1:0]gtpowergood_out;
  wire [1:0]gtrefclk0_in;
  wire [1:0]gtrefclk1_in;
  wire [1:0]gtrefclkmonitor_out;
  wire [1:0]gtresetsel_in;
  wire [31:0]gtrsvd_in;
  wire [1:0]gtsouthrefclk0_in;
  wire [1:0]gtsouthrefclk1_in;
  wire [63:0]gtwiz_userdata_tx_in;
  wire [5:0]loopback_in;
  wire [1:0]lpbkrxtxseren_in;
  wire [1:0]lpbktxrxseren_in;
  wire [1:0]pcieeqrxeqadaptdone_in;
  wire [1:0]pcierategen3_out;
  wire [1:0]pcierateidle_out;
  wire [3:0]pcierateqpllpd_out;
  wire [3:0]pcierateqpllreset_out;
  wire [1:0]pcierstidle_in;
  wire [1:0]pciersttxsyncstart_in;
  wire [1:0]pciesynctxsyncdone_out;
  wire [1:0]pcieusergen3rdy_out;
  wire [1:0]pcieuserphystatusrst_out;
  wire [1:0]pcieuserratedone_in;
  wire [1:0]pcieuserratestart_out;
  wire [9:0]pcsrsvdin2_in;
  wire [31:0]pcsrsvdin_in;
  wire [23:0]pcsrsvdout_out;
  wire [1:0]phystatus_out;
  wire [15:0]pinrsrvdas_out;
  wire [9:0]pmarsvdin_in;
  wire [0:0]qpll0outclk_out;
  wire [0:0]qpll0outrefclk_out;
  wire [0:0]qpll1outclk_out;
  wire [0:0]qpll1outrefclk_out;
  wire [1:0]resetexception_out;
  wire [1:0]resetovrd_in;
  wire [1:0]rstclkentx_in;
  wire [1:0]rx8b10ben_in;
  wire [1:0]rxbufreset_in;
  wire [5:0]rxbufstatus_out;
  wire [1:0]rxbyteisaligned_out;
  wire [1:0]rxbyterealign_out;
  wire [1:0]rxcdrfreqreset_in;
  wire [1:0]rxcdrhold_in;
  wire [1:0]rxcdrlock_out;
  wire [1:0]rxcdrovrden_in;
  wire [1:0]rxcdrphdone_out;
  wire [1:0]rxcdrreset_in;
  wire [1:0]rxcdrresetrsv_in;
  wire [1:0]rxchanbondseq_out;
  wire [1:0]rxchanisaligned_out;
  wire [1:0]rxchanrealign_out;
  wire [1:0]rxchbonden_in;
  wire [9:0]rxchbondi_in;
  wire [5:0]rxchbondlevel_in;
  wire [1:0]rxchbondmaster_in;
  wire [9:0]rxchbondo_out;
  wire [1:0]rxchbondslave_in;
  wire [3:0]rxclkcorcnt_out;
  wire [1:0]rxcominitdet_out;
  wire [1:0]rxcommadet_out;
  wire [1:0]rxcommadeten_in;
  wire [1:0]rxcomsasdet_out;
  wire [1:0]rxcomwakedet_out;
  wire [31:0]rxctrl0_out;
  wire [31:0]rxctrl1_out;
  wire [15:0]rxctrl2_out;
  wire [15:0]rxctrl3_out;
  wire [255:0]rxdata_out;
  wire [15:0]rxdataextendrsvd_out;
  wire [3:0]rxdatavalid_out;
  wire [3:0]rxdfeagcctrl_in;
  wire [1:0]rxdfeagchold_in;
  wire [1:0]rxdfeagcovrden_in;
  wire [1:0]rxdfelfhold_in;
  wire [1:0]rxdfelfovrden_in;
  wire [1:0]rxdfelpmreset_in;
  wire [1:0]rxdfetap10hold_in;
  wire [1:0]rxdfetap10ovrden_in;
  wire [1:0]rxdfetap11hold_in;
  wire [1:0]rxdfetap11ovrden_in;
  wire [1:0]rxdfetap12hold_in;
  wire [1:0]rxdfetap12ovrden_in;
  wire [1:0]rxdfetap13hold_in;
  wire [1:0]rxdfetap13ovrden_in;
  wire [1:0]rxdfetap14hold_in;
  wire [1:0]rxdfetap14ovrden_in;
  wire [1:0]rxdfetap15hold_in;
  wire [1:0]rxdfetap15ovrden_in;
  wire [1:0]rxdfetap2hold_in;
  wire [1:0]rxdfetap2ovrden_in;
  wire [1:0]rxdfetap3hold_in;
  wire [1:0]rxdfetap3ovrden_in;
  wire [1:0]rxdfetap4hold_in;
  wire [1:0]rxdfetap4ovrden_in;
  wire [1:0]rxdfetap5hold_in;
  wire [1:0]rxdfetap5ovrden_in;
  wire [1:0]rxdfetap6hold_in;
  wire [1:0]rxdfetap6ovrden_in;
  wire [1:0]rxdfetap7hold_in;
  wire [1:0]rxdfetap7ovrden_in;
  wire [1:0]rxdfetap8hold_in;
  wire [1:0]rxdfetap8ovrden_in;
  wire [1:0]rxdfetap9hold_in;
  wire [1:0]rxdfetap9ovrden_in;
  wire [1:0]rxdfeuthold_in;
  wire [1:0]rxdfeutovrden_in;
  wire [1:0]rxdfevphold_in;
  wire [1:0]rxdfevpovrden_in;
  wire [1:0]rxdfevsen_in;
  wire [1:0]rxdfexyden_in;
  wire [1:0]rxdlybypass_in;
  wire [1:0]rxdlyen_in;
  wire [1:0]rxdlyovrden_in;
  wire [1:0]rxdlysreset_in;
  wire [1:0]rxdlysresetdone_out;
  wire [1:0]rxelecidle_out;
  wire [3:0]rxelecidlemode_in;
  wire [1:0]rxgearboxslip_in;
  wire [11:0]rxheader_out;
  wire [3:0]rxheadervalid_out;
  wire [1:0]rxlatclk_in;
  wire [1:0]rxlpmen_in;
  wire [1:0]rxlpmgchold_in;
  wire [1:0]rxlpmgcovrden_in;
  wire [1:0]rxlpmhfhold_in;
  wire [1:0]rxlpmhfovrden_in;
  wire [1:0]rxlpmlfhold_in;
  wire [1:0]rxlpmlfklovrden_in;
  wire [1:0]rxlpmoshold_in;
  wire [1:0]rxlpmosovrden_in;
  wire [1:0]rxmcommaalignen_in;
  wire [13:0]rxmonitorout_out;
  wire [3:0]rxmonitorsel_in;
  wire [1:0]rxoobreset_in;
  wire [1:0]rxoscalreset_in;
  wire [1:0]rxoshold_in;
  wire [7:0]rxosintcfg_in;
  wire [1:0]rxosintdone_out;
  wire [1:0]rxosinten_in;
  wire [1:0]rxosinthold_in;
  wire [1:0]rxosintovrden_in;
  wire [1:0]rxosintstarted_out;
  wire [1:0]rxosintstrobe_in;
  wire [1:0]rxosintstrobedone_out;
  wire [1:0]rxosintstrobestarted_out;
  wire [1:0]rxosinttestovrden_in;
  wire [1:0]rxosovrden_in;
  wire [1:0]rxoutclk_out;
  wire [1:0]rxoutclkfabric_out;
  wire [1:0]rxoutclkpcs_out;
  wire [5:0]rxoutclksel_in;
  wire [1:0]rxpcommaalignen_in;
  wire [1:0]rxpcsreset_in;
  wire [3:0]rxpd_in;
  wire [1:0]rxphalign_in;
  wire [1:0]rxphaligndone_out;
  wire [1:0]rxphalignen_in;
  wire [1:0]rxphalignerr_out;
  wire [1:0]rxphdlypd_in;
  wire [1:0]rxphdlyreset_in;
  wire [1:0]rxphovrden_in;
  wire [3:0]rxpllclksel_in;
  wire [1:0]rxpmareset_in;
  wire [1:0]rxpmaresetdone_out;
  wire [1:0]rxpolarity_in;
  wire [1:0]rxprbscntreset_in;
  wire [1:0]rxprbserr_out;
  wire [1:0]rxprbslocked_out;
  wire [7:0]rxprbssel_in;
  wire [1:0]rxprgdivresetdone_out;
  wire [1:0]rxqpien_in;
  wire [1:0]rxqpisenn_out;
  wire [1:0]rxqpisenp_out;
  wire [5:0]rxrate_in;
  wire [1:0]rxratedone_out;
  wire [1:0]rxratemode_in;
  wire [1:0]rxrecclkout_out;
  wire [1:0]rxresetdone_out;
  wire [1:0]rxslide_in;
  wire [1:0]rxsliderdy_out;
  wire [1:0]rxslipdone_out;
  wire [1:0]rxslipoutclk_in;
  wire [1:0]rxslipoutclkrdy_out;
  wire [1:0]rxslippma_in;
  wire [1:0]rxslippmardy_out;
  wire [3:0]rxstartofseq_out;
  wire [5:0]rxstatus_out;
  wire [1:0]rxsyncallin_in;
  wire [1:0]rxsyncdone_out;
  wire [1:0]rxsyncin_in;
  wire [1:0]rxsyncmode_in;
  wire [1:0]rxsyncout_out;
  wire [3:0]rxsysclksel_in;
  wire [1:0]rxusrclk2_in;
  wire [1:0]rxusrclk_in;
  wire [1:0]rxvalid_out;
  wire [1:0]sigvalidclk_in;
  wire [15:0]tx8b10bbypass_in;
  wire [1:0]tx8b10ben_in;
  wire [5:0]txbufdiffctrl_in;
  wire [3:0]txbufstatus_out;
  wire [1:0]txcomfinish_out;
  wire [1:0]txcominit_in;
  wire [1:0]txcomsas_in;
  wire [1:0]txcomwake_in;
  wire [31:0]txctrl0_in;
  wire [31:0]txctrl1_in;
  wire [15:0]txctrl2_in;
  wire [15:0]txdataextendrsvd_in;
  wire [1:0]txdeemph_in;
  wire [1:0]txdetectrx_in;
  wire [7:0]txdiffctrl_in;
  wire [1:0]txdiffpd_in;
  wire [1:0]txdlybypass_in;
  wire [1:0]txdlyen_in;
  wire [1:0]txdlyhold_in;
  wire [1:0]txdlyovrden_in;
  wire [1:0]txdlysreset_in;
  wire [1:0]txdlysresetdone_out;
  wire [1:0]txdlyupdown_in;
  wire [1:0]txelecidle_in;
  wire [11:0]txheader_in;
  wire [1:0]txinhibit_in;
  wire [1:0]txlatclk_in;
  wire [13:0]txmaincursor_in;
  wire [5:0]txmargin_in;
  wire [1:0]txoutclk_out;
  wire [1:0]txoutclkfabric_out;
  wire [1:0]txoutclkpcs_out;
  wire [5:0]txoutclksel_in;
  wire [1:0]txpcsreset_in;
  wire [3:0]txpd_in;
  wire [1:0]txpdelecidlemode_in;
  wire [1:0]txphalign_in;
  wire [1:0]txphaligndone_out;
  wire [1:0]txphalignen_in;
  wire [1:0]txphdlypd_in;
  wire [1:0]txphdlyreset_in;
  wire [1:0]txphdlytstclk_in;
  wire [1:0]txphinit_in;
  wire [1:0]txphinitdone_out;
  wire [1:0]txphovrden_in;
  wire [1:0]txpippmen_in;
  wire [1:0]txpippmovrden_in;
  wire [1:0]txpippmpd_in;
  wire [1:0]txpippmsel_in;
  wire [9:0]txpippmstepsize_in;
  wire [1:0]txpisopd_in;
  wire [3:0]txpllclksel_in;
  wire [1:0]txpmareset_in;
  wire [1:0]txpmaresetdone_out;
  wire [1:0]txpolarity_in;
  wire [9:0]txpostcursor_in;
  wire [1:0]txpostcursorinv_in;
  wire [1:0]txprbsforceerr_in;
  wire [7:0]txprbssel_in;
  wire [9:0]txprecursor_in;
  wire [1:0]txprecursorinv_in;
  wire [1:0]txprgdivresetdone_out;
  wire [1:0]txqpibiasen_in;
  wire [1:0]txqpisenn_out;
  wire [1:0]txqpisenp_out;
  wire [1:0]txqpistrongpdown_in;
  wire [1:0]txqpiweakpup_in;
  wire [5:0]txrate_in;
  wire [1:0]txratedone_out;
  wire [1:0]txratemode_in;
  wire [1:0]txresetdone_out;
  wire [13:0]txsequence_in;
  wire [1:0]txswing_in;
  wire [1:0]txsyncallin_in;
  wire [1:0]txsyncdone_out;
  wire [1:0]txsyncin_in;
  wire [1:0]txsyncmode_in;
  wire [1:0]txsyncout_out;
  wire [3:0]txsysclksel_in;
  wire [1:0]txusrclk2_in;
  wire [1:0]txusrclk_in;

GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_gthe3_channel channel_inst
       (.GTHE3_CHANNEL_GTRXRESET(GTHE3_CHANNEL_GTRXRESET),
        .GTHE3_CHANNEL_GTTXRESET(GTHE3_CHANNEL_GTTXRESET),
        .GTHE3_CHANNEL_RXPROGDIVRESET(GTHE3_CHANNEL_RXPROGDIVRESET),
        .GTHE3_CHANNEL_RXUSERRDY(GTHE3_CHANNEL_RXUSERRDY),
        .GTHE3_CHANNEL_TXPROGDIVRESET(GTHE3_CHANNEL_TXPROGDIVRESET),
        .GTHE3_CHANNEL_TXUSERRDY(GTHE3_CHANNEL_TXUSERRDY),
        .O1(O1),
        .O2(O2),
        .O3(O3),
        .O4(O4),
        .bufgtce_out(bufgtce_out),
        .bufgtcemask_out(bufgtcemask_out),
        .bufgtdiv_out(bufgtdiv_out),
        .bufgtreset_out(bufgtreset_out),
        .bufgtrstmask_out(bufgtrstmask_out),
        .cfgreset_in(cfgreset_in),
        .clkrsvd0_in(clkrsvd0_in),
        .clkrsvd1_in(clkrsvd1_in),
        .cpllfbclklost_out(cpllfbclklost_out),
        .cplllock_out(cplllock_out),
        .cplllockdetclk_in(cplllockdetclk_in),
        .cplllocken_in(cplllocken_in),
        .cpllpd_in(cpllpd_in),
        .cpllrefclklost_out(cpllrefclklost_out),
        .cpllrefclksel_in(cpllrefclksel_in),
        .cpllreset_in(cpllreset_in),
        .dmonfiforeset_in(dmonfiforeset_in),
        .dmonitorclk_in(dmonitorclk_in),
        .dmonitorout_out(dmonitorout_out),
        .drpaddr_in(drpaddr_in),
        .drpclk_in(drpclk_in),
        .drpdi_in(drpdi_in),
        .drpdo_out(drpdo_out),
        .drpen_in(drpen_in),
        .drprdy_out(drprdy_out),
        .drpwe_in(drpwe_in),
        .evoddphicaldone_in(evoddphicaldone_in),
        .evoddphicalstart_in(evoddphicalstart_in),
        .evoddphidrden_in(evoddphidrden_in),
        .evoddphidwren_in(evoddphidwren_in),
        .evoddphixrden_in(evoddphixrden_in),
        .evoddphixwren_in(evoddphixwren_in),
        .eyescandataerror_out(eyescandataerror_out),
        .eyescanmode_in(eyescanmode_in),
        .eyescanreset_in(eyescanreset_in),
        .eyescantrigger_in(eyescantrigger_in),
        .gtgrefclk_in(gtgrefclk_in),
        .gthrxn_in(gthrxn_in),
        .gthrxp_in(gthrxp_in),
        .gthtxn_out(gthtxn_out),
        .gthtxp_out(gthtxp_out),
        .gtnorthrefclk0_in(gtnorthrefclk0_in),
        .gtnorthrefclk1_in(gtnorthrefclk1_in),
        .gtpowergood_out(gtpowergood_out),
        .gtrefclk0_in(gtrefclk0_in),
        .gtrefclk1_in(gtrefclk1_in),
        .gtrefclkmonitor_out(gtrefclkmonitor_out),
        .gtresetsel_in(gtresetsel_in),
        .gtrsvd_in(gtrsvd_in),
        .gtsouthrefclk0_in(gtsouthrefclk0_in),
        .gtsouthrefclk1_in(gtsouthrefclk1_in),
        .gtwiz_userdata_tx_in(gtwiz_userdata_tx_in),
        .loopback_in(loopback_in),
        .lpbkrxtxseren_in(lpbkrxtxseren_in),
        .lpbktxrxseren_in(lpbktxrxseren_in),
        .pcieeqrxeqadaptdone_in(pcieeqrxeqadaptdone_in),
        .pcierategen3_out(pcierategen3_out),
        .pcierateidle_out(pcierateidle_out),
        .pcierateqpllpd_out(pcierateqpllpd_out),
        .pcierateqpllreset_out(pcierateqpllreset_out),
        .pcierstidle_in(pcierstidle_in),
        .pciersttxsyncstart_in(pciersttxsyncstart_in),
        .pciesynctxsyncdone_out(pciesynctxsyncdone_out),
        .pcieusergen3rdy_out(pcieusergen3rdy_out),
        .pcieuserphystatusrst_out(pcieuserphystatusrst_out),
        .pcieuserratedone_in(pcieuserratedone_in),
        .pcieuserratestart_out(pcieuserratestart_out),
        .pcsrsvdin2_in(pcsrsvdin2_in),
        .pcsrsvdin_in(pcsrsvdin_in),
        .pcsrsvdout_out(pcsrsvdout_out),
        .phystatus_out(phystatus_out),
        .pinrsrvdas_out(pinrsrvdas_out),
        .pmarsvdin_in(pmarsvdin_in),
        .qpll0outclk_out(qpll0outclk_out),
        .qpll0outrefclk_out(qpll0outrefclk_out),
        .qpll1outclk_out(qpll1outclk_out),
        .qpll1outrefclk_out(qpll1outrefclk_out),
        .resetexception_out(resetexception_out),
        .resetovrd_in(resetovrd_in),
        .rstclkentx_in(rstclkentx_in),
        .rx8b10ben_in(rx8b10ben_in),
        .rxbufreset_in(rxbufreset_in),
        .rxbufstatus_out(rxbufstatus_out),
        .rxbyteisaligned_out(rxbyteisaligned_out),
        .rxbyterealign_out(rxbyterealign_out),
        .rxcdrfreqreset_in(rxcdrfreqreset_in),
        .rxcdrhold_in(rxcdrhold_in),
        .rxcdrlock_out(rxcdrlock_out),
        .rxcdrovrden_in(rxcdrovrden_in),
        .rxcdrphdone_out(rxcdrphdone_out),
        .rxcdrreset_in(rxcdrreset_in),
        .rxcdrresetrsv_in(rxcdrresetrsv_in),
        .rxchanbondseq_out(rxchanbondseq_out),
        .rxchanisaligned_out(rxchanisaligned_out),
        .rxchanrealign_out(rxchanrealign_out),
        .rxchbonden_in(rxchbonden_in),
        .rxchbondi_in(rxchbondi_in),
        .rxchbondlevel_in(rxchbondlevel_in),
        .rxchbondmaster_in(rxchbondmaster_in),
        .rxchbondo_out(rxchbondo_out),
        .rxchbondslave_in(rxchbondslave_in),
        .rxclkcorcnt_out(rxclkcorcnt_out),
        .rxcominitdet_out(rxcominitdet_out),
        .rxcommadet_out(rxcommadet_out),
        .rxcommadeten_in(rxcommadeten_in),
        .rxcomsasdet_out(rxcomsasdet_out),
        .rxcomwakedet_out(rxcomwakedet_out),
        .rxctrl0_out(rxctrl0_out),
        .rxctrl1_out(rxctrl1_out),
        .rxctrl2_out(rxctrl2_out),
        .rxctrl3_out(rxctrl3_out),
        .rxdata_out(rxdata_out),
        .rxdataextendrsvd_out(rxdataextendrsvd_out),
        .rxdatavalid_out(rxdatavalid_out),
        .rxdfeagcctrl_in(rxdfeagcctrl_in),
        .rxdfeagchold_in(rxdfeagchold_in),
        .rxdfeagcovrden_in(rxdfeagcovrden_in),
        .rxdfelfhold_in(rxdfelfhold_in),
        .rxdfelfovrden_in(rxdfelfovrden_in),
        .rxdfelpmreset_in(rxdfelpmreset_in),
        .rxdfetap10hold_in(rxdfetap10hold_in),
        .rxdfetap10ovrden_in(rxdfetap10ovrden_in),
        .rxdfetap11hold_in(rxdfetap11hold_in),
        .rxdfetap11ovrden_in(rxdfetap11ovrden_in),
        .rxdfetap12hold_in(rxdfetap12hold_in),
        .rxdfetap12ovrden_in(rxdfetap12ovrden_in),
        .rxdfetap13hold_in(rxdfetap13hold_in),
        .rxdfetap13ovrden_in(rxdfetap13ovrden_in),
        .rxdfetap14hold_in(rxdfetap14hold_in),
        .rxdfetap14ovrden_in(rxdfetap14ovrden_in),
        .rxdfetap15hold_in(rxdfetap15hold_in),
        .rxdfetap15ovrden_in(rxdfetap15ovrden_in),
        .rxdfetap2hold_in(rxdfetap2hold_in),
        .rxdfetap2ovrden_in(rxdfetap2ovrden_in),
        .rxdfetap3hold_in(rxdfetap3hold_in),
        .rxdfetap3ovrden_in(rxdfetap3ovrden_in),
        .rxdfetap4hold_in(rxdfetap4hold_in),
        .rxdfetap4ovrden_in(rxdfetap4ovrden_in),
        .rxdfetap5hold_in(rxdfetap5hold_in),
        .rxdfetap5ovrden_in(rxdfetap5ovrden_in),
        .rxdfetap6hold_in(rxdfetap6hold_in),
        .rxdfetap6ovrden_in(rxdfetap6ovrden_in),
        .rxdfetap7hold_in(rxdfetap7hold_in),
        .rxdfetap7ovrden_in(rxdfetap7ovrden_in),
        .rxdfetap8hold_in(rxdfetap8hold_in),
        .rxdfetap8ovrden_in(rxdfetap8ovrden_in),
        .rxdfetap9hold_in(rxdfetap9hold_in),
        .rxdfetap9ovrden_in(rxdfetap9ovrden_in),
        .rxdfeuthold_in(rxdfeuthold_in),
        .rxdfeutovrden_in(rxdfeutovrden_in),
        .rxdfevphold_in(rxdfevphold_in),
        .rxdfevpovrden_in(rxdfevpovrden_in),
        .rxdfevsen_in(rxdfevsen_in),
        .rxdfexyden_in(rxdfexyden_in),
        .rxdlybypass_in(rxdlybypass_in),
        .rxdlyen_in(rxdlyen_in),
        .rxdlyovrden_in(rxdlyovrden_in),
        .rxdlysreset_in(rxdlysreset_in),
        .rxdlysresetdone_out(rxdlysresetdone_out),
        .rxelecidle_out(rxelecidle_out),
        .rxelecidlemode_in(rxelecidlemode_in),
        .rxgearboxslip_in(rxgearboxslip_in),
        .rxheader_out(rxheader_out),
        .rxheadervalid_out(rxheadervalid_out),
        .rxlatclk_in(rxlatclk_in),
        .rxlpmen_in(rxlpmen_in),
        .rxlpmgchold_in(rxlpmgchold_in),
        .rxlpmgcovrden_in(rxlpmgcovrden_in),
        .rxlpmhfhold_in(rxlpmhfhold_in),
        .rxlpmhfovrden_in(rxlpmhfovrden_in),
        .rxlpmlfhold_in(rxlpmlfhold_in),
        .rxlpmlfklovrden_in(rxlpmlfklovrden_in),
        .rxlpmoshold_in(rxlpmoshold_in),
        .rxlpmosovrden_in(rxlpmosovrden_in),
        .rxmcommaalignen_in(rxmcommaalignen_in),
        .rxmonitorout_out(rxmonitorout_out),
        .rxmonitorsel_in(rxmonitorsel_in),
        .rxoobreset_in(rxoobreset_in),
        .rxoscalreset_in(rxoscalreset_in),
        .rxoshold_in(rxoshold_in),
        .rxosintcfg_in(rxosintcfg_in),
        .rxosintdone_out(rxosintdone_out),
        .rxosinten_in(rxosinten_in),
        .rxosinthold_in(rxosinthold_in),
        .rxosintovrden_in(rxosintovrden_in),
        .rxosintstarted_out(rxosintstarted_out),
        .rxosintstrobe_in(rxosintstrobe_in),
        .rxosintstrobedone_out(rxosintstrobedone_out),
        .rxosintstrobestarted_out(rxosintstrobestarted_out),
        .rxosinttestovrden_in(rxosinttestovrden_in),
        .rxosovrden_in(rxosovrden_in),
        .rxoutclk_out(rxoutclk_out),
        .rxoutclkfabric_out(rxoutclkfabric_out),
        .rxoutclkpcs_out(rxoutclkpcs_out),
        .rxoutclksel_in(rxoutclksel_in),
        .rxpcommaalignen_in(rxpcommaalignen_in),
        .rxpcsreset_in(rxpcsreset_in),
        .rxpd_in(rxpd_in),
        .rxphalign_in(rxphalign_in),
        .rxphaligndone_out(rxphaligndone_out),
        .rxphalignen_in(rxphalignen_in),
        .rxphalignerr_out(rxphalignerr_out),
        .rxphdlypd_in(rxphdlypd_in),
        .rxphdlyreset_in(rxphdlyreset_in),
        .rxphovrden_in(rxphovrden_in),
        .rxpllclksel_in(rxpllclksel_in),
        .rxpmareset_in(rxpmareset_in),
        .rxpmaresetdone_out(rxpmaresetdone_out),
        .rxpolarity_in(rxpolarity_in),
        .rxprbscntreset_in(rxprbscntreset_in),
        .rxprbserr_out(rxprbserr_out),
        .rxprbslocked_out(rxprbslocked_out),
        .rxprbssel_in(rxprbssel_in),
        .rxprgdivresetdone_out(rxprgdivresetdone_out),
        .rxqpien_in(rxqpien_in),
        .rxqpisenn_out(rxqpisenn_out),
        .rxqpisenp_out(rxqpisenp_out),
        .rxrate_in(rxrate_in),
        .rxratedone_out(rxratedone_out),
        .rxratemode_in(rxratemode_in),
        .rxrecclkout_out(rxrecclkout_out),
        .rxresetdone_out(rxresetdone_out),
        .rxslide_in(rxslide_in),
        .rxsliderdy_out(rxsliderdy_out),
        .rxslipdone_out(rxslipdone_out),
        .rxslipoutclk_in(rxslipoutclk_in),
        .rxslipoutclkrdy_out(rxslipoutclkrdy_out),
        .rxslippma_in(rxslippma_in),
        .rxslippmardy_out(rxslippmardy_out),
        .rxstartofseq_out(rxstartofseq_out),
        .rxstatus_out(rxstatus_out),
        .rxsyncallin_in(rxsyncallin_in),
        .rxsyncdone_out(rxsyncdone_out),
        .rxsyncin_in(rxsyncin_in),
        .rxsyncmode_in(rxsyncmode_in),
        .rxsyncout_out(rxsyncout_out),
        .rxsysclksel_in(rxsysclksel_in),
        .rxusrclk2_in(rxusrclk2_in),
        .rxusrclk_in(rxusrclk_in),
        .rxvalid_out(rxvalid_out),
        .sigvalidclk_in(sigvalidclk_in),
        .tx8b10bbypass_in(tx8b10bbypass_in),
        .tx8b10ben_in(tx8b10ben_in),
        .txbufdiffctrl_in(txbufdiffctrl_in),
        .txbufstatus_out(txbufstatus_out),
        .txcomfinish_out(txcomfinish_out),
        .txcominit_in(txcominit_in),
        .txcomsas_in(txcomsas_in),
        .txcomwake_in(txcomwake_in),
        .txctrl0_in(txctrl0_in),
        .txctrl1_in(txctrl1_in),
        .txctrl2_in(txctrl2_in),
        .txdataextendrsvd_in(txdataextendrsvd_in),
        .txdeemph_in(txdeemph_in),
        .txdetectrx_in(txdetectrx_in),
        .txdiffctrl_in(txdiffctrl_in),
        .txdiffpd_in(txdiffpd_in),
        .txdlybypass_in(txdlybypass_in),
        .txdlyen_in(txdlyen_in),
        .txdlyhold_in(txdlyhold_in),
        .txdlyovrden_in(txdlyovrden_in),
        .txdlysreset_in(txdlysreset_in),
        .txdlysresetdone_out(txdlysresetdone_out),
        .txdlyupdown_in(txdlyupdown_in),
        .txelecidle_in(txelecidle_in),
        .txheader_in(txheader_in),
        .txinhibit_in(txinhibit_in),
        .txlatclk_in(txlatclk_in),
        .txmaincursor_in(txmaincursor_in),
        .txmargin_in(txmargin_in),
        .txoutclk_out(txoutclk_out),
        .txoutclkfabric_out(txoutclkfabric_out),
        .txoutclkpcs_out(txoutclkpcs_out),
        .txoutclksel_in(txoutclksel_in),
        .txpcsreset_in(txpcsreset_in),
        .txpd_in(txpd_in),
        .txpdelecidlemode_in(txpdelecidlemode_in),
        .txphalign_in(txphalign_in),
        .txphaligndone_out(txphaligndone_out),
        .txphalignen_in(txphalignen_in),
        .txphdlypd_in(txphdlypd_in),
        .txphdlyreset_in(txphdlyreset_in),
        .txphdlytstclk_in(txphdlytstclk_in),
        .txphinit_in(txphinit_in),
        .txphinitdone_out(txphinitdone_out),
        .txphovrden_in(txphovrden_in),
        .txpippmen_in(txpippmen_in),
        .txpippmovrden_in(txpippmovrden_in),
        .txpippmpd_in(txpippmpd_in),
        .txpippmsel_in(txpippmsel_in),
        .txpippmstepsize_in(txpippmstepsize_in),
        .txpisopd_in(txpisopd_in),
        .txpllclksel_in(txpllclksel_in),
        .txpmareset_in(txpmareset_in),
        .txpmaresetdone_out(txpmaresetdone_out),
        .txpolarity_in(txpolarity_in),
        .txpostcursor_in(txpostcursor_in),
        .txpostcursorinv_in(txpostcursorinv_in),
        .txprbsforceerr_in(txprbsforceerr_in),
        .txprbssel_in(txprbssel_in),
        .txprecursor_in(txprecursor_in),
        .txprecursorinv_in(txprecursorinv_in),
        .txprgdivresetdone_out(txprgdivresetdone_out),
        .txqpibiasen_in(txqpibiasen_in),
        .txqpisenn_out(txqpisenn_out),
        .txqpisenp_out(txqpisenp_out),
        .txqpistrongpdown_in(txqpistrongpdown_in),
        .txqpiweakpup_in(txqpiweakpup_in),
        .txrate_in(txrate_in),
        .txratedone_out(txratedone_out),
        .txratemode_in(txratemode_in),
        .txresetdone_out(txresetdone_out),
        .txsequence_in(txsequence_in),
        .txswing_in(txswing_in),
        .txsyncallin_in(txsyncallin_in),
        .txsyncdone_out(txsyncdone_out),
        .txsyncin_in(txsyncin_in),
        .txsyncmode_in(txsyncmode_in),
        .txsyncout_out(txsyncout_out),
        .txsysclksel_in(txsysclksel_in),
        .txusrclk2_in(txusrclk2_in),
        .txusrclk_in(txusrclk_in));
endmodule

(* ORIG_REF_NAME = "GthUltrascaleJesdCoregen_gthe3_common_wrapper" *) 
module GthUltrascaleJesdCoregen_GthUltrascaleJesdCoregen_gthe3_common_wrapper
   (drprdy_common_out,
    qpll0fbclklost_out,
    O1,
    qpll0outclk_out,
    qpll0outrefclk_out,
    qpll0refclklost_out,
    qpll1fbclklost_out,
    qpll1lock_out,
    qpll1outclk_out,
    qpll1outrefclk_out,
    qpll1refclklost_out,
    refclkoutmonitor0_out,
    refclkoutmonitor1_out,
    drpdo_common_out,
    rxrecclk0_sel_out,
    rxrecclk1_sel_out,
    pmarsvdout0_out,
    pmarsvdout1_out,
    qplldmonitor0_out,
    qplldmonitor1_out,
    rst_in0,
    drpclk_common_in,
    drpen_common_in,
    drpwe_common_in,
    gtgrefclk0_in,
    gtgrefclk1_in,
    gtnorthrefclk00_in,
    gtnorthrefclk01_in,
    gtnorthrefclk10_in,
    gtnorthrefclk11_in,
    gtrefclk00_in,
    gtrefclk01_in,
    gtrefclk10_in,
    gtrefclk11_in,
    gtsouthrefclk00_in,
    gtsouthrefclk01_in,
    gtsouthrefclk10_in,
    gtsouthrefclk11_in,
    qpll0clkrsvd0_in,
    qpll0clkrsvd1_in,
    qpll0lockdetclk_in,
    qpll0locken_in,
    qpll0pd_in,
    gtwiz_reset_qpll0reset_out,
    qpll1clkrsvd0_in,
    qpll1clkrsvd1_in,
    qpll1lockdetclk_in,
    qpll1locken_in,
    qpll1pd_in,
    qpll1reset_in,
    drpdi_common_in,
    qpll0refclksel_in,
    qpll1refclksel_in,
    qpllrsvd2_in,
    qpllrsvd3_in,
    qpllrsvd1_in,
    qpllrsvd4_in,
    drpaddr_common_in);
  output [0:0]drprdy_common_out;
  output [0:0]qpll0fbclklost_out;
  output O1;
  output [0:0]qpll0outclk_out;
  output [0:0]qpll0outrefclk_out;
  output [0:0]qpll0refclklost_out;
  output [0:0]qpll1fbclklost_out;
  output [0:0]qpll1lock_out;
  output [0:0]qpll1outclk_out;
  output [0:0]qpll1outrefclk_out;
  output [0:0]qpll1refclklost_out;
  output [0:0]refclkoutmonitor0_out;
  output [0:0]refclkoutmonitor1_out;
  output [15:0]drpdo_common_out;
  output [1:0]rxrecclk0_sel_out;
  output [1:0]rxrecclk1_sel_out;
  output [7:0]pmarsvdout0_out;
  output [7:0]pmarsvdout1_out;
  output [7:0]qplldmonitor0_out;
  output [7:0]qplldmonitor1_out;
  output rst_in0;
  input [0:0]drpclk_common_in;
  input [0:0]drpen_common_in;
  input [0:0]drpwe_common_in;
  input [0:0]gtgrefclk0_in;
  input [0:0]gtgrefclk1_in;
  input [0:0]gtnorthrefclk00_in;
  input [0:0]gtnorthrefclk01_in;
  input [0:0]gtnorthrefclk10_in;
  input [0:0]gtnorthrefclk11_in;
  input [0:0]gtrefclk00_in;
  input [0:0]gtrefclk01_in;
  input [0:0]gtrefclk10_in;
  input [0:0]gtrefclk11_in;
  input [0:0]gtsouthrefclk00_in;
  input [0:0]gtsouthrefclk01_in;
  input [0:0]gtsouthrefclk10_in;
  input [0:0]gtsouthrefclk11_in;
  input [0:0]qpll0clkrsvd0_in;
  input [0:0]qpll0clkrsvd1_in;
  input [0:0]qpll0lockdetclk_in;
  input [0:0]qpll0locken_in;
  input [0:0]qpll0pd_in;
  input [0:0]gtwiz_reset_qpll0reset_out;
  input [0:0]qpll1clkrsvd0_in;
  input [0:0]qpll1clkrsvd1_in;
  input [0:0]qpll1lockdetclk_in;
  input [0:0]qpll1locken_in;
  input [0:0]qpll1pd_in;
  input [0:0]qpll1reset_in;
  input [15:0]drpdi_common_in;
  input [2:0]qpll0refclksel_in;
  input [2:0]qpll1refclksel_in;
  input [4:0]qpllrsvd2_in;
  input [4:0]qpllrsvd3_in;
  input [7:0]qpllrsvd1_in;
  input [7:0]qpllrsvd4_in;
  input [8:0]drpaddr_common_in;

  wire O1;
  wire [8:0]drpaddr_common_in;
  wire [0:0]drpclk_common_in;
  wire [15:0]drpdi_common_in;
  wire [15:0]drpdo_common_out;
  wire [0:0]drpen_common_in;
  wire [0:0]drprdy_common_out;
  wire [0:0]drpwe_common_in;
  wire [0:0]gtgrefclk0_in;
  wire [0:0]gtgrefclk1_in;
  wire [0:0]gtnorthrefclk00_in;
  wire [0:0]gtnorthrefclk01_in;
  wire [0:0]gtnorthrefclk10_in;
  wire [0:0]gtnorthrefclk11_in;
  wire [0:0]gtrefclk00_in;
  wire [0:0]gtrefclk01_in;
  wire [0:0]gtrefclk10_in;
  wire [0:0]gtrefclk11_in;
  wire [0:0]gtsouthrefclk00_in;
  wire [0:0]gtsouthrefclk01_in;
  wire [0:0]gtsouthrefclk10_in;
  wire [0:0]gtsouthrefclk11_in;
  wire [0:0]gtwiz_reset_qpll0reset_out;
  wire [7:0]pmarsvdout0_out;
  wire [7:0]pmarsvdout1_out;
  wire [0:0]qpll0clkrsvd0_in;
  wire [0:0]qpll0clkrsvd1_in;
  wire [0:0]qpll0fbclklost_out;
  wire [0:0]qpll0lockdetclk_in;
  wire [0:0]qpll0locken_in;
  wire [0:0]qpll0outclk_out;
  wire [0:0]qpll0outrefclk_out;
  wire [0:0]qpll0pd_in;
  wire [0:0]qpll0refclklost_out;
  wire [2:0]qpll0refclksel_in;
  wire [0:0]qpll1clkrsvd0_in;
  wire [0:0]qpll1clkrsvd1_in;
  wire [0:0]qpll1fbclklost_out;
  wire [0:0]qpll1lock_out;
  wire [0:0]qpll1lockdetclk_in;
  wire [0:0]qpll1locken_in;
  wire [0:0]qpll1outclk_out;
  wire [0:0]qpll1outrefclk_out;
  wire [0:0]qpll1pd_in;
  wire [0:0]qpll1refclklost_out;
  wire [2:0]qpll1refclksel_in;
  wire [0:0]qpll1reset_in;
  wire [7:0]qplldmonitor0_out;
  wire [7:0]qplldmonitor1_out;
  wire [7:0]qpllrsvd1_in;
  wire [4:0]qpllrsvd2_in;
  wire [4:0]qpllrsvd3_in;
  wire [7:0]qpllrsvd4_in;
  wire [0:0]refclkoutmonitor0_out;
  wire [0:0]refclkoutmonitor1_out;
  wire rst_in0;
  wire [1:0]rxrecclk0_sel_out;
  wire [1:0]rxrecclk1_sel_out;

GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_gthe3_common common_inst
       (.O1(O1),
        .drpaddr_common_in(drpaddr_common_in),
        .drpclk_common_in(drpclk_common_in),
        .drpdi_common_in(drpdi_common_in),
        .drpdo_common_out(drpdo_common_out),
        .drpen_common_in(drpen_common_in),
        .drprdy_common_out(drprdy_common_out),
        .drpwe_common_in(drpwe_common_in),
        .gtgrefclk0_in(gtgrefclk0_in),
        .gtgrefclk1_in(gtgrefclk1_in),
        .gtnorthrefclk00_in(gtnorthrefclk00_in),
        .gtnorthrefclk01_in(gtnorthrefclk01_in),
        .gtnorthrefclk10_in(gtnorthrefclk10_in),
        .gtnorthrefclk11_in(gtnorthrefclk11_in),
        .gtrefclk00_in(gtrefclk00_in),
        .gtrefclk01_in(gtrefclk01_in),
        .gtrefclk10_in(gtrefclk10_in),
        .gtrefclk11_in(gtrefclk11_in),
        .gtsouthrefclk00_in(gtsouthrefclk00_in),
        .gtsouthrefclk01_in(gtsouthrefclk01_in),
        .gtsouthrefclk10_in(gtsouthrefclk10_in),
        .gtsouthrefclk11_in(gtsouthrefclk11_in),
        .gtwiz_reset_qpll0reset_out(gtwiz_reset_qpll0reset_out),
        .pmarsvdout0_out(pmarsvdout0_out),
        .pmarsvdout1_out(pmarsvdout1_out),
        .qpll0clkrsvd0_in(qpll0clkrsvd0_in),
        .qpll0clkrsvd1_in(qpll0clkrsvd1_in),
        .qpll0fbclklost_out(qpll0fbclklost_out),
        .qpll0lockdetclk_in(qpll0lockdetclk_in),
        .qpll0locken_in(qpll0locken_in),
        .qpll0outclk_out(qpll0outclk_out),
        .qpll0outrefclk_out(qpll0outrefclk_out),
        .qpll0pd_in(qpll0pd_in),
        .qpll0refclklost_out(qpll0refclklost_out),
        .qpll0refclksel_in(qpll0refclksel_in),
        .qpll1clkrsvd0_in(qpll1clkrsvd0_in),
        .qpll1clkrsvd1_in(qpll1clkrsvd1_in),
        .qpll1fbclklost_out(qpll1fbclklost_out),
        .qpll1lock_out(qpll1lock_out),
        .qpll1lockdetclk_in(qpll1lockdetclk_in),
        .qpll1locken_in(qpll1locken_in),
        .qpll1outclk_out(qpll1outclk_out),
        .qpll1outrefclk_out(qpll1outrefclk_out),
        .qpll1pd_in(qpll1pd_in),
        .qpll1refclklost_out(qpll1refclklost_out),
        .qpll1refclksel_in(qpll1refclksel_in),
        .qpll1reset_in(qpll1reset_in),
        .qplldmonitor0_out(qplldmonitor0_out),
        .qplldmonitor1_out(qplldmonitor1_out),
        .qpllrsvd1_in(qpllrsvd1_in),
        .qpllrsvd2_in(qpllrsvd2_in),
        .qpllrsvd3_in(qpllrsvd3_in),
        .qpllrsvd4_in(qpllrsvd4_in),
        .refclkoutmonitor0_out(refclkoutmonitor0_out),
        .refclkoutmonitor1_out(refclkoutmonitor1_out),
        .rst_in0(rst_in0),
        .rxrecclk0_sel_out(rxrecclk0_sel_out),
        .rxrecclk1_sel_out(rxrecclk1_sel_out));
endmodule

(* ORIG_REF_NAME = "GthUltrascaleJesdCoregen_gtwizard_gthe3" *) 
module GthUltrascaleJesdCoregen_GthUltrascaleJesdCoregen_gtwizard_gthe3
   (gtpowergood_out,
    txresetdone_out,
    rxcdrlock_out,
    rxresetdone_out,
    qpll0lock_out,
    gtwiz_reset_rx_cdr_stable_out,
    drprdy_common_out,
    qpll0fbclklost_out,
    qpll0outclk_out,
    qpll0outrefclk_out,
    qpll0refclklost_out,
    qpll1fbclklost_out,
    qpll1lock_out,
    qpll1outclk_out,
    qpll1outrefclk_out,
    qpll1refclklost_out,
    refclkoutmonitor0_out,
    refclkoutmonitor1_out,
    drpdo_common_out,
    rxrecclk0_sel_out,
    rxrecclk1_sel_out,
    pmarsvdout0_out,
    pmarsvdout1_out,
    qplldmonitor0_out,
    qplldmonitor1_out,
    gtwiz_reset_qpll0reset_out,
    cpllfbclklost_out,
    cplllock_out,
    cpllrefclklost_out,
    drprdy_out,
    eyescandataerror_out,
    gthtxn_out,
    gthtxp_out,
    gtrefclkmonitor_out,
    pcierategen3_out,
    pcierateidle_out,
    pciesynctxsyncdone_out,
    pcieusergen3rdy_out,
    pcieuserphystatusrst_out,
    pcieuserratestart_out,
    phystatus_out,
    resetexception_out,
    rxbyteisaligned_out,
    rxbyterealign_out,
    rxcdrphdone_out,
    rxchanbondseq_out,
    rxchanisaligned_out,
    rxchanrealign_out,
    rxcominitdet_out,
    rxcommadet_out,
    rxcomsasdet_out,
    rxcomwakedet_out,
    rxdlysresetdone_out,
    rxelecidle_out,
    rxosintdone_out,
    rxosintstarted_out,
    rxosintstrobedone_out,
    rxosintstrobestarted_out,
    rxoutclk_out,
    rxoutclkfabric_out,
    rxoutclkpcs_out,
    rxphaligndone_out,
    rxphalignerr_out,
    rxpmaresetdone_out,
    rxprbserr_out,
    rxprbslocked_out,
    rxprgdivresetdone_out,
    rxqpisenn_out,
    rxqpisenp_out,
    rxratedone_out,
    rxrecclkout_out,
    rxsliderdy_out,
    rxslipdone_out,
    rxslipoutclkrdy_out,
    rxslippmardy_out,
    rxsyncdone_out,
    rxsyncout_out,
    rxvalid_out,
    txcomfinish_out,
    txdlysresetdone_out,
    txoutclk_out,
    txoutclkfabric_out,
    txoutclkpcs_out,
    txphaligndone_out,
    txphinitdone_out,
    txpmaresetdone_out,
    txprgdivresetdone_out,
    txqpisenn_out,
    txqpisenp_out,
    txratedone_out,
    txsyncdone_out,
    txsyncout_out,
    pcsrsvdout_out,
    rxdata_out,
    drpdo_out,
    rxctrl0_out,
    rxctrl1_out,
    dmonitorout_out,
    pcierateqpllpd_out,
    pcierateqpllreset_out,
    rxclkcorcnt_out,
    rxdatavalid_out,
    rxheadervalid_out,
    rxstartofseq_out,
    txbufstatus_out,
    bufgtce_out,
    bufgtcemask_out,
    bufgtreset_out,
    bufgtrstmask_out,
    rxbufstatus_out,
    rxstatus_out,
    rxchbondo_out,
    rxheader_out,
    rxmonitorout_out,
    pinrsrvdas_out,
    rxctrl2_out,
    rxctrl3_out,
    rxdataextendrsvd_out,
    bufgtdiv_out,
    gtwiz_reset_tx_done_out,
    gtwiz_reset_rx_done_out,
    gtwiz_userclk_tx_active_in,
    gtwiz_userclk_rx_active_in,
    gtwiz_reset_clk_freerun_in,
    drpclk_common_in,
    drpen_common_in,
    drpwe_common_in,
    gtgrefclk0_in,
    gtgrefclk1_in,
    gtnorthrefclk00_in,
    gtnorthrefclk01_in,
    gtnorthrefclk10_in,
    gtnorthrefclk11_in,
    gtrefclk00_in,
    gtrefclk01_in,
    gtrefclk10_in,
    gtrefclk11_in,
    gtsouthrefclk00_in,
    gtsouthrefclk01_in,
    gtsouthrefclk10_in,
    gtsouthrefclk11_in,
    qpll0clkrsvd0_in,
    qpll0clkrsvd1_in,
    qpll0lockdetclk_in,
    qpll0locken_in,
    qpll0pd_in,
    qpll1clkrsvd0_in,
    qpll1clkrsvd1_in,
    qpll1lockdetclk_in,
    qpll1locken_in,
    qpll1pd_in,
    qpll1reset_in,
    drpdi_common_in,
    qpll0refclksel_in,
    qpll1refclksel_in,
    qpllrsvd2_in,
    qpllrsvd3_in,
    qpllrsvd1_in,
    qpllrsvd4_in,
    drpaddr_common_in,
    cfgreset_in,
    clkrsvd0_in,
    clkrsvd1_in,
    cplllockdetclk_in,
    cplllocken_in,
    cpllpd_in,
    cpllreset_in,
    dmonfiforeset_in,
    dmonitorclk_in,
    drpclk_in,
    drpen_in,
    drpwe_in,
    evoddphicaldone_in,
    evoddphicalstart_in,
    evoddphidrden_in,
    evoddphidwren_in,
    evoddphixrden_in,
    evoddphixwren_in,
    eyescanmode_in,
    eyescanreset_in,
    eyescantrigger_in,
    gtgrefclk_in,
    gthrxn_in,
    gthrxp_in,
    gtnorthrefclk0_in,
    gtnorthrefclk1_in,
    gtrefclk0_in,
    gtrefclk1_in,
    gtresetsel_in,
    gtsouthrefclk0_in,
    gtsouthrefclk1_in,
    lpbkrxtxseren_in,
    lpbktxrxseren_in,
    pcieeqrxeqadaptdone_in,
    pcierstidle_in,
    pciersttxsyncstart_in,
    pcieuserratedone_in,
    resetovrd_in,
    rstclkentx_in,
    rx8b10ben_in,
    rxbufreset_in,
    rxcdrfreqreset_in,
    rxcdrhold_in,
    rxcdrovrden_in,
    rxcdrreset_in,
    rxcdrresetrsv_in,
    rxchbonden_in,
    rxchbondmaster_in,
    rxchbondslave_in,
    rxcommadeten_in,
    rxdfeagchold_in,
    rxdfeagcovrden_in,
    rxdfelfhold_in,
    rxdfelfovrden_in,
    rxdfelpmreset_in,
    rxdfetap10hold_in,
    rxdfetap10ovrden_in,
    rxdfetap11hold_in,
    rxdfetap11ovrden_in,
    rxdfetap12hold_in,
    rxdfetap12ovrden_in,
    rxdfetap13hold_in,
    rxdfetap13ovrden_in,
    rxdfetap14hold_in,
    rxdfetap14ovrden_in,
    rxdfetap15hold_in,
    rxdfetap15ovrden_in,
    rxdfetap2hold_in,
    rxdfetap2ovrden_in,
    rxdfetap3hold_in,
    rxdfetap3ovrden_in,
    rxdfetap4hold_in,
    rxdfetap4ovrden_in,
    rxdfetap5hold_in,
    rxdfetap5ovrden_in,
    rxdfetap6hold_in,
    rxdfetap6ovrden_in,
    rxdfetap7hold_in,
    rxdfetap7ovrden_in,
    rxdfetap8hold_in,
    rxdfetap8ovrden_in,
    rxdfetap9hold_in,
    rxdfetap9ovrden_in,
    rxdfeuthold_in,
    rxdfeutovrden_in,
    rxdfevphold_in,
    rxdfevpovrden_in,
    rxdfevsen_in,
    rxdfexyden_in,
    rxdlybypass_in,
    rxdlyen_in,
    rxdlyovrden_in,
    rxdlysreset_in,
    rxgearboxslip_in,
    rxlatclk_in,
    rxlpmen_in,
    rxlpmgchold_in,
    rxlpmgcovrden_in,
    rxlpmhfhold_in,
    rxlpmhfovrden_in,
    rxlpmlfhold_in,
    rxlpmlfklovrden_in,
    rxlpmoshold_in,
    rxlpmosovrden_in,
    rxmcommaalignen_in,
    rxoobreset_in,
    rxoscalreset_in,
    rxoshold_in,
    rxosinten_in,
    rxosinthold_in,
    rxosintovrden_in,
    rxosintstrobe_in,
    rxosinttestovrden_in,
    rxosovrden_in,
    rxpcommaalignen_in,
    rxpcsreset_in,
    rxphalign_in,
    rxphalignen_in,
    rxphdlypd_in,
    rxphdlyreset_in,
    rxphovrden_in,
    rxpmareset_in,
    rxpolarity_in,
    rxprbscntreset_in,
    rxqpien_in,
    rxratemode_in,
    rxslide_in,
    rxslipoutclk_in,
    rxslippma_in,
    rxsyncallin_in,
    rxsyncin_in,
    rxsyncmode_in,
    rxusrclk_in,
    rxusrclk2_in,
    sigvalidclk_in,
    tx8b10ben_in,
    txcominit_in,
    txcomsas_in,
    txcomwake_in,
    txdeemph_in,
    txdetectrx_in,
    txdiffpd_in,
    txdlybypass_in,
    txdlyen_in,
    txdlyhold_in,
    txdlyovrden_in,
    txdlysreset_in,
    txdlyupdown_in,
    txelecidle_in,
    txinhibit_in,
    txlatclk_in,
    txpcsreset_in,
    txpdelecidlemode_in,
    txphalign_in,
    txphalignen_in,
    txphdlypd_in,
    txphdlyreset_in,
    txphdlytstclk_in,
    txphinit_in,
    txphovrden_in,
    txpippmen_in,
    txpippmovrden_in,
    txpippmpd_in,
    txpippmsel_in,
    txpisopd_in,
    txpmareset_in,
    txpolarity_in,
    txpostcursorinv_in,
    txprbsforceerr_in,
    txprecursorinv_in,
    txqpibiasen_in,
    txqpistrongpdown_in,
    txqpiweakpup_in,
    txratemode_in,
    txswing_in,
    txsyncallin_in,
    txsyncin_in,
    txsyncmode_in,
    txusrclk_in,
    txusrclk2_in,
    gtwiz_userdata_tx_in,
    drpdi_in,
    gtrsvd_in,
    pcsrsvdin_in,
    txctrl0_in,
    txctrl1_in,
    rxdfeagcctrl_in,
    rxelecidlemode_in,
    rxmonitorsel_in,
    rxpd_in,
    rxpllclksel_in,
    rxsysclksel_in,
    txpd_in,
    txpllclksel_in,
    txsysclksel_in,
    cpllrefclksel_in,
    loopback_in,
    rxchbondlevel_in,
    rxoutclksel_in,
    rxrate_in,
    txbufdiffctrl_in,
    txmargin_in,
    txoutclksel_in,
    txrate_in,
    rxosintcfg_in,
    rxprbssel_in,
    txdiffctrl_in,
    txprbssel_in,
    pcsrsvdin2_in,
    pmarsvdin_in,
    rxchbondi_in,
    txpippmstepsize_in,
    txpostcursor_in,
    txprecursor_in,
    txheader_in,
    txmaincursor_in,
    txsequence_in,
    tx8b10bbypass_in,
    txctrl2_in,
    txdataextendrsvd_in,
    drpaddr_in,
    gtwiz_reset_all_in,
    gtwiz_reset_tx_datapath_in,
    gtwiz_reset_tx_pll_and_datapath_in,
    gtwiz_reset_rx_datapath_in,
    gtwiz_reset_rx_pll_and_datapath_in);
  output [1:0]gtpowergood_out;
  output [1:0]txresetdone_out;
  output [1:0]rxcdrlock_out;
  output [1:0]rxresetdone_out;
  output [0:0]qpll0lock_out;
  output [0:0]gtwiz_reset_rx_cdr_stable_out;
  output [0:0]drprdy_common_out;
  output [0:0]qpll0fbclklost_out;
  output [0:0]qpll0outclk_out;
  output [0:0]qpll0outrefclk_out;
  output [0:0]qpll0refclklost_out;
  output [0:0]qpll1fbclklost_out;
  output [0:0]qpll1lock_out;
  output [0:0]qpll1outclk_out;
  output [0:0]qpll1outrefclk_out;
  output [0:0]qpll1refclklost_out;
  output [0:0]refclkoutmonitor0_out;
  output [0:0]refclkoutmonitor1_out;
  output [15:0]drpdo_common_out;
  output [1:0]rxrecclk0_sel_out;
  output [1:0]rxrecclk1_sel_out;
  output [7:0]pmarsvdout0_out;
  output [7:0]pmarsvdout1_out;
  output [7:0]qplldmonitor0_out;
  output [7:0]qplldmonitor1_out;
  output [0:0]gtwiz_reset_qpll0reset_out;
  output [1:0]cpllfbclklost_out;
  output [1:0]cplllock_out;
  output [1:0]cpllrefclklost_out;
  output [1:0]drprdy_out;
  output [1:0]eyescandataerror_out;
  output [1:0]gthtxn_out;
  output [1:0]gthtxp_out;
  output [1:0]gtrefclkmonitor_out;
  output [1:0]pcierategen3_out;
  output [1:0]pcierateidle_out;
  output [1:0]pciesynctxsyncdone_out;
  output [1:0]pcieusergen3rdy_out;
  output [1:0]pcieuserphystatusrst_out;
  output [1:0]pcieuserratestart_out;
  output [1:0]phystatus_out;
  output [1:0]resetexception_out;
  output [1:0]rxbyteisaligned_out;
  output [1:0]rxbyterealign_out;
  output [1:0]rxcdrphdone_out;
  output [1:0]rxchanbondseq_out;
  output [1:0]rxchanisaligned_out;
  output [1:0]rxchanrealign_out;
  output [1:0]rxcominitdet_out;
  output [1:0]rxcommadet_out;
  output [1:0]rxcomsasdet_out;
  output [1:0]rxcomwakedet_out;
  output [1:0]rxdlysresetdone_out;
  output [1:0]rxelecidle_out;
  output [1:0]rxosintdone_out;
  output [1:0]rxosintstarted_out;
  output [1:0]rxosintstrobedone_out;
  output [1:0]rxosintstrobestarted_out;
  output [1:0]rxoutclk_out;
  output [1:0]rxoutclkfabric_out;
  output [1:0]rxoutclkpcs_out;
  output [1:0]rxphaligndone_out;
  output [1:0]rxphalignerr_out;
  output [1:0]rxpmaresetdone_out;
  output [1:0]rxprbserr_out;
  output [1:0]rxprbslocked_out;
  output [1:0]rxprgdivresetdone_out;
  output [1:0]rxqpisenn_out;
  output [1:0]rxqpisenp_out;
  output [1:0]rxratedone_out;
  output [1:0]rxrecclkout_out;
  output [1:0]rxsliderdy_out;
  output [1:0]rxslipdone_out;
  output [1:0]rxslipoutclkrdy_out;
  output [1:0]rxslippmardy_out;
  output [1:0]rxsyncdone_out;
  output [1:0]rxsyncout_out;
  output [1:0]rxvalid_out;
  output [1:0]txcomfinish_out;
  output [1:0]txdlysresetdone_out;
  output [1:0]txoutclk_out;
  output [1:0]txoutclkfabric_out;
  output [1:0]txoutclkpcs_out;
  output [1:0]txphaligndone_out;
  output [1:0]txphinitdone_out;
  output [1:0]txpmaresetdone_out;
  output [1:0]txprgdivresetdone_out;
  output [1:0]txqpisenn_out;
  output [1:0]txqpisenp_out;
  output [1:0]txratedone_out;
  output [1:0]txsyncdone_out;
  output [1:0]txsyncout_out;
  output [23:0]pcsrsvdout_out;
  output [255:0]rxdata_out;
  output [31:0]drpdo_out;
  output [31:0]rxctrl0_out;
  output [31:0]rxctrl1_out;
  output [33:0]dmonitorout_out;
  output [3:0]pcierateqpllpd_out;
  output [3:0]pcierateqpllreset_out;
  output [3:0]rxclkcorcnt_out;
  output [3:0]rxdatavalid_out;
  output [3:0]rxheadervalid_out;
  output [3:0]rxstartofseq_out;
  output [3:0]txbufstatus_out;
  output [5:0]bufgtce_out;
  output [5:0]bufgtcemask_out;
  output [5:0]bufgtreset_out;
  output [5:0]bufgtrstmask_out;
  output [5:0]rxbufstatus_out;
  output [5:0]rxstatus_out;
  output [9:0]rxchbondo_out;
  output [11:0]rxheader_out;
  output [13:0]rxmonitorout_out;
  output [15:0]pinrsrvdas_out;
  output [15:0]rxctrl2_out;
  output [15:0]rxctrl3_out;
  output [15:0]rxdataextendrsvd_out;
  output [17:0]bufgtdiv_out;
  output [0:0]gtwiz_reset_tx_done_out;
  output [0:0]gtwiz_reset_rx_done_out;
  input [0:0]gtwiz_userclk_tx_active_in;
  input [0:0]gtwiz_userclk_rx_active_in;
  input [0:0]gtwiz_reset_clk_freerun_in;
  input [0:0]drpclk_common_in;
  input [0:0]drpen_common_in;
  input [0:0]drpwe_common_in;
  input [0:0]gtgrefclk0_in;
  input [0:0]gtgrefclk1_in;
  input [0:0]gtnorthrefclk00_in;
  input [0:0]gtnorthrefclk01_in;
  input [0:0]gtnorthrefclk10_in;
  input [0:0]gtnorthrefclk11_in;
  input [0:0]gtrefclk00_in;
  input [0:0]gtrefclk01_in;
  input [0:0]gtrefclk10_in;
  input [0:0]gtrefclk11_in;
  input [0:0]gtsouthrefclk00_in;
  input [0:0]gtsouthrefclk01_in;
  input [0:0]gtsouthrefclk10_in;
  input [0:0]gtsouthrefclk11_in;
  input [0:0]qpll0clkrsvd0_in;
  input [0:0]qpll0clkrsvd1_in;
  input [0:0]qpll0lockdetclk_in;
  input [0:0]qpll0locken_in;
  input [0:0]qpll0pd_in;
  input [0:0]qpll1clkrsvd0_in;
  input [0:0]qpll1clkrsvd1_in;
  input [0:0]qpll1lockdetclk_in;
  input [0:0]qpll1locken_in;
  input [0:0]qpll1pd_in;
  input [0:0]qpll1reset_in;
  input [15:0]drpdi_common_in;
  input [2:0]qpll0refclksel_in;
  input [2:0]qpll1refclksel_in;
  input [4:0]qpllrsvd2_in;
  input [4:0]qpllrsvd3_in;
  input [7:0]qpllrsvd1_in;
  input [7:0]qpllrsvd4_in;
  input [8:0]drpaddr_common_in;
  input [1:0]cfgreset_in;
  input [1:0]clkrsvd0_in;
  input [1:0]clkrsvd1_in;
  input [1:0]cplllockdetclk_in;
  input [1:0]cplllocken_in;
  input [1:0]cpllpd_in;
  input [1:0]cpllreset_in;
  input [1:0]dmonfiforeset_in;
  input [1:0]dmonitorclk_in;
  input [1:0]drpclk_in;
  input [1:0]drpen_in;
  input [1:0]drpwe_in;
  input [1:0]evoddphicaldone_in;
  input [1:0]evoddphicalstart_in;
  input [1:0]evoddphidrden_in;
  input [1:0]evoddphidwren_in;
  input [1:0]evoddphixrden_in;
  input [1:0]evoddphixwren_in;
  input [1:0]eyescanmode_in;
  input [1:0]eyescanreset_in;
  input [1:0]eyescantrigger_in;
  input [1:0]gtgrefclk_in;
  input [1:0]gthrxn_in;
  input [1:0]gthrxp_in;
  input [1:0]gtnorthrefclk0_in;
  input [1:0]gtnorthrefclk1_in;
  input [1:0]gtrefclk0_in;
  input [1:0]gtrefclk1_in;
  input [1:0]gtresetsel_in;
  input [1:0]gtsouthrefclk0_in;
  input [1:0]gtsouthrefclk1_in;
  input [1:0]lpbkrxtxseren_in;
  input [1:0]lpbktxrxseren_in;
  input [1:0]pcieeqrxeqadaptdone_in;
  input [1:0]pcierstidle_in;
  input [1:0]pciersttxsyncstart_in;
  input [1:0]pcieuserratedone_in;
  input [1:0]resetovrd_in;
  input [1:0]rstclkentx_in;
  input [1:0]rx8b10ben_in;
  input [1:0]rxbufreset_in;
  input [1:0]rxcdrfreqreset_in;
  input [1:0]rxcdrhold_in;
  input [1:0]rxcdrovrden_in;
  input [1:0]rxcdrreset_in;
  input [1:0]rxcdrresetrsv_in;
  input [1:0]rxchbonden_in;
  input [1:0]rxchbondmaster_in;
  input [1:0]rxchbondslave_in;
  input [1:0]rxcommadeten_in;
  input [1:0]rxdfeagchold_in;
  input [1:0]rxdfeagcovrden_in;
  input [1:0]rxdfelfhold_in;
  input [1:0]rxdfelfovrden_in;
  input [1:0]rxdfelpmreset_in;
  input [1:0]rxdfetap10hold_in;
  input [1:0]rxdfetap10ovrden_in;
  input [1:0]rxdfetap11hold_in;
  input [1:0]rxdfetap11ovrden_in;
  input [1:0]rxdfetap12hold_in;
  input [1:0]rxdfetap12ovrden_in;
  input [1:0]rxdfetap13hold_in;
  input [1:0]rxdfetap13ovrden_in;
  input [1:0]rxdfetap14hold_in;
  input [1:0]rxdfetap14ovrden_in;
  input [1:0]rxdfetap15hold_in;
  input [1:0]rxdfetap15ovrden_in;
  input [1:0]rxdfetap2hold_in;
  input [1:0]rxdfetap2ovrden_in;
  input [1:0]rxdfetap3hold_in;
  input [1:0]rxdfetap3ovrden_in;
  input [1:0]rxdfetap4hold_in;
  input [1:0]rxdfetap4ovrden_in;
  input [1:0]rxdfetap5hold_in;
  input [1:0]rxdfetap5ovrden_in;
  input [1:0]rxdfetap6hold_in;
  input [1:0]rxdfetap6ovrden_in;
  input [1:0]rxdfetap7hold_in;
  input [1:0]rxdfetap7ovrden_in;
  input [1:0]rxdfetap8hold_in;
  input [1:0]rxdfetap8ovrden_in;
  input [1:0]rxdfetap9hold_in;
  input [1:0]rxdfetap9ovrden_in;
  input [1:0]rxdfeuthold_in;
  input [1:0]rxdfeutovrden_in;
  input [1:0]rxdfevphold_in;
  input [1:0]rxdfevpovrden_in;
  input [1:0]rxdfevsen_in;
  input [1:0]rxdfexyden_in;
  input [1:0]rxdlybypass_in;
  input [1:0]rxdlyen_in;
  input [1:0]rxdlyovrden_in;
  input [1:0]rxdlysreset_in;
  input [1:0]rxgearboxslip_in;
  input [1:0]rxlatclk_in;
  input [1:0]rxlpmen_in;
  input [1:0]rxlpmgchold_in;
  input [1:0]rxlpmgcovrden_in;
  input [1:0]rxlpmhfhold_in;
  input [1:0]rxlpmhfovrden_in;
  input [1:0]rxlpmlfhold_in;
  input [1:0]rxlpmlfklovrden_in;
  input [1:0]rxlpmoshold_in;
  input [1:0]rxlpmosovrden_in;
  input [1:0]rxmcommaalignen_in;
  input [1:0]rxoobreset_in;
  input [1:0]rxoscalreset_in;
  input [1:0]rxoshold_in;
  input [1:0]rxosinten_in;
  input [1:0]rxosinthold_in;
  input [1:0]rxosintovrden_in;
  input [1:0]rxosintstrobe_in;
  input [1:0]rxosinttestovrden_in;
  input [1:0]rxosovrden_in;
  input [1:0]rxpcommaalignen_in;
  input [1:0]rxpcsreset_in;
  input [1:0]rxphalign_in;
  input [1:0]rxphalignen_in;
  input [1:0]rxphdlypd_in;
  input [1:0]rxphdlyreset_in;
  input [1:0]rxphovrden_in;
  input [1:0]rxpmareset_in;
  input [1:0]rxpolarity_in;
  input [1:0]rxprbscntreset_in;
  input [1:0]rxqpien_in;
  input [1:0]rxratemode_in;
  input [1:0]rxslide_in;
  input [1:0]rxslipoutclk_in;
  input [1:0]rxslippma_in;
  input [1:0]rxsyncallin_in;
  input [1:0]rxsyncin_in;
  input [1:0]rxsyncmode_in;
  input [1:0]rxusrclk_in;
  input [1:0]rxusrclk2_in;
  input [1:0]sigvalidclk_in;
  input [1:0]tx8b10ben_in;
  input [1:0]txcominit_in;
  input [1:0]txcomsas_in;
  input [1:0]txcomwake_in;
  input [1:0]txdeemph_in;
  input [1:0]txdetectrx_in;
  input [1:0]txdiffpd_in;
  input [1:0]txdlybypass_in;
  input [1:0]txdlyen_in;
  input [1:0]txdlyhold_in;
  input [1:0]txdlyovrden_in;
  input [1:0]txdlysreset_in;
  input [1:0]txdlyupdown_in;
  input [1:0]txelecidle_in;
  input [1:0]txinhibit_in;
  input [1:0]txlatclk_in;
  input [1:0]txpcsreset_in;
  input [1:0]txpdelecidlemode_in;
  input [1:0]txphalign_in;
  input [1:0]txphalignen_in;
  input [1:0]txphdlypd_in;
  input [1:0]txphdlyreset_in;
  input [1:0]txphdlytstclk_in;
  input [1:0]txphinit_in;
  input [1:0]txphovrden_in;
  input [1:0]txpippmen_in;
  input [1:0]txpippmovrden_in;
  input [1:0]txpippmpd_in;
  input [1:0]txpippmsel_in;
  input [1:0]txpisopd_in;
  input [1:0]txpmareset_in;
  input [1:0]txpolarity_in;
  input [1:0]txpostcursorinv_in;
  input [1:0]txprbsforceerr_in;
  input [1:0]txprecursorinv_in;
  input [1:0]txqpibiasen_in;
  input [1:0]txqpistrongpdown_in;
  input [1:0]txqpiweakpup_in;
  input [1:0]txratemode_in;
  input [1:0]txswing_in;
  input [1:0]txsyncallin_in;
  input [1:0]txsyncin_in;
  input [1:0]txsyncmode_in;
  input [1:0]txusrclk_in;
  input [1:0]txusrclk2_in;
  input [63:0]gtwiz_userdata_tx_in;
  input [31:0]drpdi_in;
  input [31:0]gtrsvd_in;
  input [31:0]pcsrsvdin_in;
  input [31:0]txctrl0_in;
  input [31:0]txctrl1_in;
  input [3:0]rxdfeagcctrl_in;
  input [3:0]rxelecidlemode_in;
  input [3:0]rxmonitorsel_in;
  input [3:0]rxpd_in;
  input [3:0]rxpllclksel_in;
  input [3:0]rxsysclksel_in;
  input [3:0]txpd_in;
  input [3:0]txpllclksel_in;
  input [3:0]txsysclksel_in;
  input [5:0]cpllrefclksel_in;
  input [5:0]loopback_in;
  input [5:0]rxchbondlevel_in;
  input [5:0]rxoutclksel_in;
  input [5:0]rxrate_in;
  input [5:0]txbufdiffctrl_in;
  input [5:0]txmargin_in;
  input [5:0]txoutclksel_in;
  input [5:0]txrate_in;
  input [7:0]rxosintcfg_in;
  input [7:0]rxprbssel_in;
  input [7:0]txdiffctrl_in;
  input [7:0]txprbssel_in;
  input [9:0]pcsrsvdin2_in;
  input [9:0]pmarsvdin_in;
  input [9:0]rxchbondi_in;
  input [9:0]txpippmstepsize_in;
  input [9:0]txpostcursor_in;
  input [9:0]txprecursor_in;
  input [11:0]txheader_in;
  input [13:0]txmaincursor_in;
  input [13:0]txsequence_in;
  input [15:0]tx8b10bbypass_in;
  input [15:0]txctrl2_in;
  input [15:0]txdataextendrsvd_in;
  input [17:0]drpaddr_in;
  input [0:0]gtwiz_reset_all_in;
  input [0:0]gtwiz_reset_tx_datapath_in;
  input [0:0]gtwiz_reset_tx_pll_and_datapath_in;
  input [0:0]gtwiz_reset_rx_datapath_in;
  input [0:0]gtwiz_reset_rx_pll_and_datapath_in;

  wire [5:0]bufgtce_out;
  wire [5:0]bufgtcemask_out;
  wire [17:0]bufgtdiv_out;
  wire [5:0]bufgtreset_out;
  wire [5:0]bufgtrstmask_out;
  wire [1:0]cfgreset_in;
  wire [1:0]clkrsvd0_in;
  wire [1:0]clkrsvd1_in;
  wire [1:0]cpllfbclklost_out;
  wire [1:0]cplllock_out;
  wire [1:0]cplllockdetclk_in;
  wire [1:0]cplllocken_in;
  wire [1:0]cpllpd_in;
  wire [1:0]cpllrefclklost_out;
  wire [5:0]cpllrefclksel_in;
  wire [1:0]cpllreset_in;
  wire [1:0]dmonfiforeset_in;
  wire [1:0]dmonitorclk_in;
  wire [33:0]dmonitorout_out;
  wire [8:0]drpaddr_common_in;
  wire [17:0]drpaddr_in;
  wire [0:0]drpclk_common_in;
  wire [1:0]drpclk_in;
  wire [15:0]drpdi_common_in;
  wire [31:0]drpdi_in;
  wire [15:0]drpdo_common_out;
  wire [31:0]drpdo_out;
  wire [0:0]drpen_common_in;
  wire [1:0]drpen_in;
  wire [0:0]drprdy_common_out;
  wire [1:0]drprdy_out;
  wire [0:0]drpwe_common_in;
  wire [1:0]drpwe_in;
  wire [1:0]evoddphicaldone_in;
  wire [1:0]evoddphicalstart_in;
  wire [1:0]evoddphidrden_in;
  wire [1:0]evoddphidwren_in;
  wire [1:0]evoddphixrden_in;
  wire [1:0]evoddphixwren_in;
  wire [1:0]eyescandataerror_out;
  wire [1:0]eyescanmode_in;
  wire [1:0]eyescanreset_in;
  wire [1:0]eyescantrigger_in;
  wire [0:0]gtgrefclk0_in;
  wire [0:0]gtgrefclk1_in;
  wire [1:0]gtgrefclk_in;
  wire [1:0]gthrxn_in;
  wire [1:0]gthrxp_in;
  wire [1:0]gthtxn_out;
  wire [1:0]gthtxp_out;
  wire [0:0]gtnorthrefclk00_in;
  wire [0:0]gtnorthrefclk01_in;
  wire [1:0]gtnorthrefclk0_in;
  wire [0:0]gtnorthrefclk10_in;
  wire [0:0]gtnorthrefclk11_in;
  wire [1:0]gtnorthrefclk1_in;
  wire [1:0]gtpowergood_out;
  wire [0:0]gtrefclk00_in;
  wire [0:0]gtrefclk01_in;
  wire [1:0]gtrefclk0_in;
  wire [0:0]gtrefclk10_in;
  wire [0:0]gtrefclk11_in;
  wire [1:0]gtrefclk1_in;
  wire [1:0]gtrefclkmonitor_out;
  wire [1:0]gtresetsel_in;
  wire [31:0]gtrsvd_in;
  wire [0:0]gtsouthrefclk00_in;
  wire [0:0]gtsouthrefclk01_in;
  wire [1:0]gtsouthrefclk0_in;
  wire [0:0]gtsouthrefclk10_in;
  wire [0:0]gtsouthrefclk11_in;
  wire [1:0]gtsouthrefclk1_in;
  wire [0:0]gtwiz_reset_all_in;
  wire [0:0]gtwiz_reset_clk_freerun_in;
  wire gtwiz_reset_gtrxreset_int;
  wire gtwiz_reset_gttxreset_int;
  wire [0:0]gtwiz_reset_qpll0reset_out;
  wire [0:0]gtwiz_reset_rx_cdr_stable_out;
  wire [0:0]gtwiz_reset_rx_datapath_in;
  wire [0:0]gtwiz_reset_rx_done_out;
  wire [0:0]gtwiz_reset_rx_pll_and_datapath_in;
  wire gtwiz_reset_rxprogdivreset_int;
  wire gtwiz_reset_rxuserrdy_int;
  wire [0:0]gtwiz_reset_tx_datapath_in;
  wire [0:0]gtwiz_reset_tx_done_out;
  wire [0:0]gtwiz_reset_tx_pll_and_datapath_in;
  wire gtwiz_reset_txprogdivreset_int;
  wire gtwiz_reset_txuserrdy_int;
  wire [0:0]gtwiz_userclk_rx_active_in;
  wire [0:0]gtwiz_userclk_tx_active_in;
  wire [63:0]gtwiz_userdata_tx_in;
  wire [5:0]loopback_in;
  wire [1:0]lpbkrxtxseren_in;
  wire [1:0]lpbktxrxseren_in;
  wire \n_0_gen_gtwizard_gthe3.gen_channel_container[4].gen_enabled_channel.gthe3_channel_wrapper_inst ;
  wire \n_3_gen_gtwizard_gthe3.gen_channel_container[4].gen_enabled_channel.gthe3_channel_wrapper_inst ;
  wire \n_6_gen_gtwizard_gthe3.gen_channel_container[4].gen_enabled_channel.gthe3_channel_wrapper_inst ;
  wire \n_9_gen_gtwizard_gthe3.gen_channel_container[4].gen_enabled_channel.gthe3_channel_wrapper_inst ;
  wire [1:0]pcieeqrxeqadaptdone_in;
  wire [1:0]pcierategen3_out;
  wire [1:0]pcierateidle_out;
  wire [3:0]pcierateqpllpd_out;
  wire [3:0]pcierateqpllreset_out;
  wire [1:0]pcierstidle_in;
  wire [1:0]pciersttxsyncstart_in;
  wire [1:0]pciesynctxsyncdone_out;
  wire [1:0]pcieusergen3rdy_out;
  wire [1:0]pcieuserphystatusrst_out;
  wire [1:0]pcieuserratedone_in;
  wire [1:0]pcieuserratestart_out;
  wire [9:0]pcsrsvdin2_in;
  wire [31:0]pcsrsvdin_in;
  wire [23:0]pcsrsvdout_out;
  wire [1:0]phystatus_out;
  wire [15:0]pinrsrvdas_out;
  wire [9:0]pmarsvdin_in;
  wire [7:0]pmarsvdout0_out;
  wire [7:0]pmarsvdout1_out;
  wire [0:0]qpll0clkrsvd0_in;
  wire [0:0]qpll0clkrsvd1_in;
  wire [0:0]qpll0fbclklost_out;
  wire [0:0]qpll0lock_out;
  wire [0:0]qpll0lockdetclk_in;
  wire [0:0]qpll0locken_in;
  wire [0:0]qpll0outclk_out;
  wire [0:0]qpll0outrefclk_out;
  wire [0:0]qpll0pd_in;
  wire [0:0]qpll0refclklost_out;
  wire [2:0]qpll0refclksel_in;
  wire [0:0]qpll1clkrsvd0_in;
  wire [0:0]qpll1clkrsvd1_in;
  wire [0:0]qpll1fbclklost_out;
  wire [0:0]qpll1lock_out;
  wire [0:0]qpll1lockdetclk_in;
  wire [0:0]qpll1locken_in;
  wire [0:0]qpll1outclk_out;
  wire [0:0]qpll1outrefclk_out;
  wire [0:0]qpll1pd_in;
  wire [0:0]qpll1refclklost_out;
  wire [2:0]qpll1refclksel_in;
  wire [0:0]qpll1reset_in;
  wire [7:0]qplldmonitor0_out;
  wire [7:0]qplldmonitor1_out;
  wire [7:0]qpllrsvd1_in;
  wire [4:0]qpllrsvd2_in;
  wire [4:0]qpllrsvd3_in;
  wire [7:0]qpllrsvd4_in;
  wire [0:0]refclkoutmonitor0_out;
  wire [0:0]refclkoutmonitor1_out;
  wire [1:0]resetexception_out;
  wire [1:0]resetovrd_in;
  wire rst_in0;
  wire [1:0]rstclkentx_in;
  wire [1:0]rx8b10ben_in;
  wire [1:0]rxbufreset_in;
  wire [5:0]rxbufstatus_out;
  wire [1:0]rxbyteisaligned_out;
  wire [1:0]rxbyterealign_out;
  wire [1:0]rxcdrfreqreset_in;
  wire [1:0]rxcdrhold_in;
  wire [1:0]rxcdrlock_out;
  wire [1:0]rxcdrovrden_in;
  wire [1:0]rxcdrphdone_out;
  wire [1:0]rxcdrreset_in;
  wire [1:0]rxcdrresetrsv_in;
  wire [1:0]rxchanbondseq_out;
  wire [1:0]rxchanisaligned_out;
  wire [1:0]rxchanrealign_out;
  wire [1:0]rxchbonden_in;
  wire [9:0]rxchbondi_in;
  wire [5:0]rxchbondlevel_in;
  wire [1:0]rxchbondmaster_in;
  wire [9:0]rxchbondo_out;
  wire [1:0]rxchbondslave_in;
  wire [3:0]rxclkcorcnt_out;
  wire [1:0]rxcominitdet_out;
  wire [1:0]rxcommadet_out;
  wire [1:0]rxcommadeten_in;
  wire [1:0]rxcomsasdet_out;
  wire [1:0]rxcomwakedet_out;
  wire [31:0]rxctrl0_out;
  wire [31:0]rxctrl1_out;
  wire [15:0]rxctrl2_out;
  wire [15:0]rxctrl3_out;
  wire [255:0]rxdata_out;
  wire [15:0]rxdataextendrsvd_out;
  wire [3:0]rxdatavalid_out;
  wire [3:0]rxdfeagcctrl_in;
  wire [1:0]rxdfeagchold_in;
  wire [1:0]rxdfeagcovrden_in;
  wire [1:0]rxdfelfhold_in;
  wire [1:0]rxdfelfovrden_in;
  wire [1:0]rxdfelpmreset_in;
  wire [1:0]rxdfetap10hold_in;
  wire [1:0]rxdfetap10ovrden_in;
  wire [1:0]rxdfetap11hold_in;
  wire [1:0]rxdfetap11ovrden_in;
  wire [1:0]rxdfetap12hold_in;
  wire [1:0]rxdfetap12ovrden_in;
  wire [1:0]rxdfetap13hold_in;
  wire [1:0]rxdfetap13ovrden_in;
  wire [1:0]rxdfetap14hold_in;
  wire [1:0]rxdfetap14ovrden_in;
  wire [1:0]rxdfetap15hold_in;
  wire [1:0]rxdfetap15ovrden_in;
  wire [1:0]rxdfetap2hold_in;
  wire [1:0]rxdfetap2ovrden_in;
  wire [1:0]rxdfetap3hold_in;
  wire [1:0]rxdfetap3ovrden_in;
  wire [1:0]rxdfetap4hold_in;
  wire [1:0]rxdfetap4ovrden_in;
  wire [1:0]rxdfetap5hold_in;
  wire [1:0]rxdfetap5ovrden_in;
  wire [1:0]rxdfetap6hold_in;
  wire [1:0]rxdfetap6ovrden_in;
  wire [1:0]rxdfetap7hold_in;
  wire [1:0]rxdfetap7ovrden_in;
  wire [1:0]rxdfetap8hold_in;
  wire [1:0]rxdfetap8ovrden_in;
  wire [1:0]rxdfetap9hold_in;
  wire [1:0]rxdfetap9ovrden_in;
  wire [1:0]rxdfeuthold_in;
  wire [1:0]rxdfeutovrden_in;
  wire [1:0]rxdfevphold_in;
  wire [1:0]rxdfevpovrden_in;
  wire [1:0]rxdfevsen_in;
  wire [1:0]rxdfexyden_in;
  wire [1:0]rxdlybypass_in;
  wire [1:0]rxdlyen_in;
  wire [1:0]rxdlyovrden_in;
  wire [1:0]rxdlysreset_in;
  wire [1:0]rxdlysresetdone_out;
  wire [1:0]rxelecidle_out;
  wire [3:0]rxelecidlemode_in;
  wire [1:0]rxgearboxslip_in;
  wire [11:0]rxheader_out;
  wire [3:0]rxheadervalid_out;
  wire [1:0]rxlatclk_in;
  wire [1:0]rxlpmen_in;
  wire [1:0]rxlpmgchold_in;
  wire [1:0]rxlpmgcovrden_in;
  wire [1:0]rxlpmhfhold_in;
  wire [1:0]rxlpmhfovrden_in;
  wire [1:0]rxlpmlfhold_in;
  wire [1:0]rxlpmlfklovrden_in;
  wire [1:0]rxlpmoshold_in;
  wire [1:0]rxlpmosovrden_in;
  wire [1:0]rxmcommaalignen_in;
  wire [13:0]rxmonitorout_out;
  wire [3:0]rxmonitorsel_in;
  wire [1:0]rxoobreset_in;
  wire [1:0]rxoscalreset_in;
  wire [1:0]rxoshold_in;
  wire [7:0]rxosintcfg_in;
  wire [1:0]rxosintdone_out;
  wire [1:0]rxosinten_in;
  wire [1:0]rxosinthold_in;
  wire [1:0]rxosintovrden_in;
  wire [1:0]rxosintstarted_out;
  wire [1:0]rxosintstrobe_in;
  wire [1:0]rxosintstrobedone_out;
  wire [1:0]rxosintstrobestarted_out;
  wire [1:0]rxosinttestovrden_in;
  wire [1:0]rxosovrden_in;
  wire [1:0]rxoutclk_out;
  wire [1:0]rxoutclkfabric_out;
  wire [1:0]rxoutclkpcs_out;
  wire [5:0]rxoutclksel_in;
  wire [1:0]rxpcommaalignen_in;
  wire [1:0]rxpcsreset_in;
  wire [3:0]rxpd_in;
  wire [1:0]rxphalign_in;
  wire [1:0]rxphaligndone_out;
  wire [1:0]rxphalignen_in;
  wire [1:0]rxphalignerr_out;
  wire [1:0]rxphdlypd_in;
  wire [1:0]rxphdlyreset_in;
  wire [1:0]rxphovrden_in;
  wire [3:0]rxpllclksel_in;
  wire [1:0]rxpmareset_in;
  wire [1:0]rxpmaresetdone_out;
  wire [1:0]rxpolarity_in;
  wire [1:0]rxprbscntreset_in;
  wire [1:0]rxprbserr_out;
  wire [1:0]rxprbslocked_out;
  wire [7:0]rxprbssel_in;
  wire [1:0]rxprgdivresetdone_out;
  wire [1:0]rxqpien_in;
  wire [1:0]rxqpisenn_out;
  wire [1:0]rxqpisenp_out;
  wire [5:0]rxrate_in;
  wire [1:0]rxratedone_out;
  wire [1:0]rxratemode_in;
  wire [1:0]rxrecclk0_sel_out;
  wire [1:0]rxrecclk1_sel_out;
  wire [1:0]rxrecclkout_out;
  wire [1:0]rxresetdone_out;
  wire [1:0]rxslide_in;
  wire [1:0]rxsliderdy_out;
  wire [1:0]rxslipdone_out;
  wire [1:0]rxslipoutclk_in;
  wire [1:0]rxslipoutclkrdy_out;
  wire [1:0]rxslippma_in;
  wire [1:0]rxslippmardy_out;
  wire [3:0]rxstartofseq_out;
  wire [5:0]rxstatus_out;
  wire [1:0]rxsyncallin_in;
  wire [1:0]rxsyncdone_out;
  wire [1:0]rxsyncin_in;
  wire [1:0]rxsyncmode_in;
  wire [1:0]rxsyncout_out;
  wire [3:0]rxsysclksel_in;
  wire [1:0]rxusrclk2_in;
  wire [1:0]rxusrclk_in;
  wire [1:0]rxvalid_out;
  wire [1:0]sigvalidclk_in;
  wire [15:0]tx8b10bbypass_in;
  wire [1:0]tx8b10ben_in;
  wire [5:0]txbufdiffctrl_in;
  wire [3:0]txbufstatus_out;
  wire [1:0]txcomfinish_out;
  wire [1:0]txcominit_in;
  wire [1:0]txcomsas_in;
  wire [1:0]txcomwake_in;
  wire [31:0]txctrl0_in;
  wire [31:0]txctrl1_in;
  wire [15:0]txctrl2_in;
  wire [15:0]txdataextendrsvd_in;
  wire [1:0]txdeemph_in;
  wire [1:0]txdetectrx_in;
  wire [7:0]txdiffctrl_in;
  wire [1:0]txdiffpd_in;
  wire [1:0]txdlybypass_in;
  wire [1:0]txdlyen_in;
  wire [1:0]txdlyhold_in;
  wire [1:0]txdlyovrden_in;
  wire [1:0]txdlysreset_in;
  wire [1:0]txdlysresetdone_out;
  wire [1:0]txdlyupdown_in;
  wire [1:0]txelecidle_in;
  wire [11:0]txheader_in;
  wire [1:0]txinhibit_in;
  wire [1:0]txlatclk_in;
  wire [13:0]txmaincursor_in;
  wire [5:0]txmargin_in;
  wire [1:0]txoutclk_out;
  wire [1:0]txoutclkfabric_out;
  wire [1:0]txoutclkpcs_out;
  wire [5:0]txoutclksel_in;
  wire [1:0]txpcsreset_in;
  wire [3:0]txpd_in;
  wire [1:0]txpdelecidlemode_in;
  wire [1:0]txphalign_in;
  wire [1:0]txphaligndone_out;
  wire [1:0]txphalignen_in;
  wire [1:0]txphdlypd_in;
  wire [1:0]txphdlyreset_in;
  wire [1:0]txphdlytstclk_in;
  wire [1:0]txphinit_in;
  wire [1:0]txphinitdone_out;
  wire [1:0]txphovrden_in;
  wire [1:0]txpippmen_in;
  wire [1:0]txpippmovrden_in;
  wire [1:0]txpippmpd_in;
  wire [1:0]txpippmsel_in;
  wire [9:0]txpippmstepsize_in;
  wire [1:0]txpisopd_in;
  wire [3:0]txpllclksel_in;
  wire [1:0]txpmareset_in;
  wire [1:0]txpmaresetdone_out;
  wire [1:0]txpolarity_in;
  wire [9:0]txpostcursor_in;
  wire [1:0]txpostcursorinv_in;
  wire [1:0]txprbsforceerr_in;
  wire [7:0]txprbssel_in;
  wire [9:0]txprecursor_in;
  wire [1:0]txprecursorinv_in;
  wire [1:0]txprgdivresetdone_out;
  wire [1:0]txqpibiasen_in;
  wire [1:0]txqpisenn_out;
  wire [1:0]txqpisenp_out;
  wire [1:0]txqpistrongpdown_in;
  wire [1:0]txqpiweakpup_in;
  wire [5:0]txrate_in;
  wire [1:0]txratedone_out;
  wire [1:0]txratemode_in;
  wire [1:0]txresetdone_out;
  wire [13:0]txsequence_in;
  wire [1:0]txswing_in;
  wire [1:0]txsyncallin_in;
  wire [1:0]txsyncdone_out;
  wire [1:0]txsyncin_in;
  wire [1:0]txsyncmode_in;
  wire [1:0]txsyncout_out;
  wire [3:0]txsysclksel_in;
  wire [1:0]txusrclk2_in;
  wire [1:0]txusrclk_in;

GthUltrascaleJesdCoregen_GthUltrascaleJesdCoregen_gthe3_channel_wrapper \gen_gtwizard_gthe3.gen_channel_container[4].gen_enabled_channel.gthe3_channel_wrapper_inst 
       (.GTHE3_CHANNEL_GTRXRESET(gtwiz_reset_gtrxreset_int),
        .GTHE3_CHANNEL_GTTXRESET(gtwiz_reset_gttxreset_int),
        .GTHE3_CHANNEL_RXPROGDIVRESET(gtwiz_reset_rxprogdivreset_int),
        .GTHE3_CHANNEL_RXUSERRDY(gtwiz_reset_rxuserrdy_int),
        .GTHE3_CHANNEL_TXPROGDIVRESET(gtwiz_reset_txprogdivreset_int),
        .GTHE3_CHANNEL_TXUSERRDY(gtwiz_reset_txuserrdy_int),
        .O1(\n_0_gen_gtwizard_gthe3.gen_channel_container[4].gen_enabled_channel.gthe3_channel_wrapper_inst ),
        .O2(\n_3_gen_gtwizard_gthe3.gen_channel_container[4].gen_enabled_channel.gthe3_channel_wrapper_inst ),
        .O3(\n_6_gen_gtwizard_gthe3.gen_channel_container[4].gen_enabled_channel.gthe3_channel_wrapper_inst ),
        .O4(\n_9_gen_gtwizard_gthe3.gen_channel_container[4].gen_enabled_channel.gthe3_channel_wrapper_inst ),
        .bufgtce_out(bufgtce_out),
        .bufgtcemask_out(bufgtcemask_out),
        .bufgtdiv_out(bufgtdiv_out),
        .bufgtreset_out(bufgtreset_out),
        .bufgtrstmask_out(bufgtrstmask_out),
        .cfgreset_in(cfgreset_in),
        .clkrsvd0_in(clkrsvd0_in),
        .clkrsvd1_in(clkrsvd1_in),
        .cpllfbclklost_out(cpllfbclklost_out),
        .cplllock_out(cplllock_out),
        .cplllockdetclk_in(cplllockdetclk_in),
        .cplllocken_in(cplllocken_in),
        .cpllpd_in(cpllpd_in),
        .cpllrefclklost_out(cpllrefclklost_out),
        .cpllrefclksel_in(cpllrefclksel_in),
        .cpllreset_in(cpllreset_in),
        .dmonfiforeset_in(dmonfiforeset_in),
        .dmonitorclk_in(dmonitorclk_in),
        .dmonitorout_out(dmonitorout_out),
        .drpaddr_in(drpaddr_in),
        .drpclk_in(drpclk_in),
        .drpdi_in(drpdi_in),
        .drpdo_out(drpdo_out),
        .drpen_in(drpen_in),
        .drprdy_out(drprdy_out),
        .drpwe_in(drpwe_in),
        .evoddphicaldone_in(evoddphicaldone_in),
        .evoddphicalstart_in(evoddphicalstart_in),
        .evoddphidrden_in(evoddphidrden_in),
        .evoddphidwren_in(evoddphidwren_in),
        .evoddphixrden_in(evoddphixrden_in),
        .evoddphixwren_in(evoddphixwren_in),
        .eyescandataerror_out(eyescandataerror_out),
        .eyescanmode_in(eyescanmode_in),
        .eyescanreset_in(eyescanreset_in),
        .eyescantrigger_in(eyescantrigger_in),
        .gtgrefclk_in(gtgrefclk_in),
        .gthrxn_in(gthrxn_in),
        .gthrxp_in(gthrxp_in),
        .gthtxn_out(gthtxn_out),
        .gthtxp_out(gthtxp_out),
        .gtnorthrefclk0_in(gtnorthrefclk0_in),
        .gtnorthrefclk1_in(gtnorthrefclk1_in),
        .gtpowergood_out(gtpowergood_out),
        .gtrefclk0_in(gtrefclk0_in),
        .gtrefclk1_in(gtrefclk1_in),
        .gtrefclkmonitor_out(gtrefclkmonitor_out),
        .gtresetsel_in(gtresetsel_in),
        .gtrsvd_in(gtrsvd_in),
        .gtsouthrefclk0_in(gtsouthrefclk0_in),
        .gtsouthrefclk1_in(gtsouthrefclk1_in),
        .gtwiz_userdata_tx_in(gtwiz_userdata_tx_in),
        .loopback_in(loopback_in),
        .lpbkrxtxseren_in(lpbkrxtxseren_in),
        .lpbktxrxseren_in(lpbktxrxseren_in),
        .pcieeqrxeqadaptdone_in(pcieeqrxeqadaptdone_in),
        .pcierategen3_out(pcierategen3_out),
        .pcierateidle_out(pcierateidle_out),
        .pcierateqpllpd_out(pcierateqpllpd_out),
        .pcierateqpllreset_out(pcierateqpllreset_out),
        .pcierstidle_in(pcierstidle_in),
        .pciersttxsyncstart_in(pciersttxsyncstart_in),
        .pciesynctxsyncdone_out(pciesynctxsyncdone_out),
        .pcieusergen3rdy_out(pcieusergen3rdy_out),
        .pcieuserphystatusrst_out(pcieuserphystatusrst_out),
        .pcieuserratedone_in(pcieuserratedone_in),
        .pcieuserratestart_out(pcieuserratestart_out),
        .pcsrsvdin2_in(pcsrsvdin2_in),
        .pcsrsvdin_in(pcsrsvdin_in),
        .pcsrsvdout_out(pcsrsvdout_out),
        .phystatus_out(phystatus_out),
        .pinrsrvdas_out(pinrsrvdas_out),
        .pmarsvdin_in(pmarsvdin_in),
        .qpll0outclk_out(qpll0outclk_out),
        .qpll0outrefclk_out(qpll0outrefclk_out),
        .qpll1outclk_out(qpll1outclk_out),
        .qpll1outrefclk_out(qpll1outrefclk_out),
        .resetexception_out(resetexception_out),
        .resetovrd_in(resetovrd_in),
        .rstclkentx_in(rstclkentx_in),
        .rx8b10ben_in(rx8b10ben_in),
        .rxbufreset_in(rxbufreset_in),
        .rxbufstatus_out(rxbufstatus_out),
        .rxbyteisaligned_out(rxbyteisaligned_out),
        .rxbyterealign_out(rxbyterealign_out),
        .rxcdrfreqreset_in(rxcdrfreqreset_in),
        .rxcdrhold_in(rxcdrhold_in),
        .rxcdrlock_out(rxcdrlock_out),
        .rxcdrovrden_in(rxcdrovrden_in),
        .rxcdrphdone_out(rxcdrphdone_out),
        .rxcdrreset_in(rxcdrreset_in),
        .rxcdrresetrsv_in(rxcdrresetrsv_in),
        .rxchanbondseq_out(rxchanbondseq_out),
        .rxchanisaligned_out(rxchanisaligned_out),
        .rxchanrealign_out(rxchanrealign_out),
        .rxchbonden_in(rxchbonden_in),
        .rxchbondi_in(rxchbondi_in),
        .rxchbondlevel_in(rxchbondlevel_in),
        .rxchbondmaster_in(rxchbondmaster_in),
        .rxchbondo_out(rxchbondo_out),
        .rxchbondslave_in(rxchbondslave_in),
        .rxclkcorcnt_out(rxclkcorcnt_out),
        .rxcominitdet_out(rxcominitdet_out),
        .rxcommadet_out(rxcommadet_out),
        .rxcommadeten_in(rxcommadeten_in),
        .rxcomsasdet_out(rxcomsasdet_out),
        .rxcomwakedet_out(rxcomwakedet_out),
        .rxctrl0_out(rxctrl0_out),
        .rxctrl1_out(rxctrl1_out),
        .rxctrl2_out(rxctrl2_out),
        .rxctrl3_out(rxctrl3_out),
        .rxdata_out(rxdata_out),
        .rxdataextendrsvd_out(rxdataextendrsvd_out),
        .rxdatavalid_out(rxdatavalid_out),
        .rxdfeagcctrl_in(rxdfeagcctrl_in),
        .rxdfeagchold_in(rxdfeagchold_in),
        .rxdfeagcovrden_in(rxdfeagcovrden_in),
        .rxdfelfhold_in(rxdfelfhold_in),
        .rxdfelfovrden_in(rxdfelfovrden_in),
        .rxdfelpmreset_in(rxdfelpmreset_in),
        .rxdfetap10hold_in(rxdfetap10hold_in),
        .rxdfetap10ovrden_in(rxdfetap10ovrden_in),
        .rxdfetap11hold_in(rxdfetap11hold_in),
        .rxdfetap11ovrden_in(rxdfetap11ovrden_in),
        .rxdfetap12hold_in(rxdfetap12hold_in),
        .rxdfetap12ovrden_in(rxdfetap12ovrden_in),
        .rxdfetap13hold_in(rxdfetap13hold_in),
        .rxdfetap13ovrden_in(rxdfetap13ovrden_in),
        .rxdfetap14hold_in(rxdfetap14hold_in),
        .rxdfetap14ovrden_in(rxdfetap14ovrden_in),
        .rxdfetap15hold_in(rxdfetap15hold_in),
        .rxdfetap15ovrden_in(rxdfetap15ovrden_in),
        .rxdfetap2hold_in(rxdfetap2hold_in),
        .rxdfetap2ovrden_in(rxdfetap2ovrden_in),
        .rxdfetap3hold_in(rxdfetap3hold_in),
        .rxdfetap3ovrden_in(rxdfetap3ovrden_in),
        .rxdfetap4hold_in(rxdfetap4hold_in),
        .rxdfetap4ovrden_in(rxdfetap4ovrden_in),
        .rxdfetap5hold_in(rxdfetap5hold_in),
        .rxdfetap5ovrden_in(rxdfetap5ovrden_in),
        .rxdfetap6hold_in(rxdfetap6hold_in),
        .rxdfetap6ovrden_in(rxdfetap6ovrden_in),
        .rxdfetap7hold_in(rxdfetap7hold_in),
        .rxdfetap7ovrden_in(rxdfetap7ovrden_in),
        .rxdfetap8hold_in(rxdfetap8hold_in),
        .rxdfetap8ovrden_in(rxdfetap8ovrden_in),
        .rxdfetap9hold_in(rxdfetap9hold_in),
        .rxdfetap9ovrden_in(rxdfetap9ovrden_in),
        .rxdfeuthold_in(rxdfeuthold_in),
        .rxdfeutovrden_in(rxdfeutovrden_in),
        .rxdfevphold_in(rxdfevphold_in),
        .rxdfevpovrden_in(rxdfevpovrden_in),
        .rxdfevsen_in(rxdfevsen_in),
        .rxdfexyden_in(rxdfexyden_in),
        .rxdlybypass_in(rxdlybypass_in),
        .rxdlyen_in(rxdlyen_in),
        .rxdlyovrden_in(rxdlyovrden_in),
        .rxdlysreset_in(rxdlysreset_in),
        .rxdlysresetdone_out(rxdlysresetdone_out),
        .rxelecidle_out(rxelecidle_out),
        .rxelecidlemode_in(rxelecidlemode_in),
        .rxgearboxslip_in(rxgearboxslip_in),
        .rxheader_out(rxheader_out),
        .rxheadervalid_out(rxheadervalid_out),
        .rxlatclk_in(rxlatclk_in),
        .rxlpmen_in(rxlpmen_in),
        .rxlpmgchold_in(rxlpmgchold_in),
        .rxlpmgcovrden_in(rxlpmgcovrden_in),
        .rxlpmhfhold_in(rxlpmhfhold_in),
        .rxlpmhfovrden_in(rxlpmhfovrden_in),
        .rxlpmlfhold_in(rxlpmlfhold_in),
        .rxlpmlfklovrden_in(rxlpmlfklovrden_in),
        .rxlpmoshold_in(rxlpmoshold_in),
        .rxlpmosovrden_in(rxlpmosovrden_in),
        .rxmcommaalignen_in(rxmcommaalignen_in),
        .rxmonitorout_out(rxmonitorout_out),
        .rxmonitorsel_in(rxmonitorsel_in),
        .rxoobreset_in(rxoobreset_in),
        .rxoscalreset_in(rxoscalreset_in),
        .rxoshold_in(rxoshold_in),
        .rxosintcfg_in(rxosintcfg_in),
        .rxosintdone_out(rxosintdone_out),
        .rxosinten_in(rxosinten_in),
        .rxosinthold_in(rxosinthold_in),
        .rxosintovrden_in(rxosintovrden_in),
        .rxosintstarted_out(rxosintstarted_out),
        .rxosintstrobe_in(rxosintstrobe_in),
        .rxosintstrobedone_out(rxosintstrobedone_out),
        .rxosintstrobestarted_out(rxosintstrobestarted_out),
        .rxosinttestovrden_in(rxosinttestovrden_in),
        .rxosovrden_in(rxosovrden_in),
        .rxoutclk_out(rxoutclk_out),
        .rxoutclkfabric_out(rxoutclkfabric_out),
        .rxoutclkpcs_out(rxoutclkpcs_out),
        .rxoutclksel_in(rxoutclksel_in),
        .rxpcommaalignen_in(rxpcommaalignen_in),
        .rxpcsreset_in(rxpcsreset_in),
        .rxpd_in(rxpd_in),
        .rxphalign_in(rxphalign_in),
        .rxphaligndone_out(rxphaligndone_out),
        .rxphalignen_in(rxphalignen_in),
        .rxphalignerr_out(rxphalignerr_out),
        .rxphdlypd_in(rxphdlypd_in),
        .rxphdlyreset_in(rxphdlyreset_in),
        .rxphovrden_in(rxphovrden_in),
        .rxpllclksel_in(rxpllclksel_in),
        .rxpmareset_in(rxpmareset_in),
        .rxpmaresetdone_out(rxpmaresetdone_out),
        .rxpolarity_in(rxpolarity_in),
        .rxprbscntreset_in(rxprbscntreset_in),
        .rxprbserr_out(rxprbserr_out),
        .rxprbslocked_out(rxprbslocked_out),
        .rxprbssel_in(rxprbssel_in),
        .rxprgdivresetdone_out(rxprgdivresetdone_out),
        .rxqpien_in(rxqpien_in),
        .rxqpisenn_out(rxqpisenn_out),
        .rxqpisenp_out(rxqpisenp_out),
        .rxrate_in(rxrate_in),
        .rxratedone_out(rxratedone_out),
        .rxratemode_in(rxratemode_in),
        .rxrecclkout_out(rxrecclkout_out),
        .rxresetdone_out(rxresetdone_out),
        .rxslide_in(rxslide_in),
        .rxsliderdy_out(rxsliderdy_out),
        .rxslipdone_out(rxslipdone_out),
        .rxslipoutclk_in(rxslipoutclk_in),
        .rxslipoutclkrdy_out(rxslipoutclkrdy_out),
        .rxslippma_in(rxslippma_in),
        .rxslippmardy_out(rxslippmardy_out),
        .rxstartofseq_out(rxstartofseq_out),
        .rxstatus_out(rxstatus_out),
        .rxsyncallin_in(rxsyncallin_in),
        .rxsyncdone_out(rxsyncdone_out),
        .rxsyncin_in(rxsyncin_in),
        .rxsyncmode_in(rxsyncmode_in),
        .rxsyncout_out(rxsyncout_out),
        .rxsysclksel_in(rxsysclksel_in),
        .rxusrclk2_in(rxusrclk2_in),
        .rxusrclk_in(rxusrclk_in),
        .rxvalid_out(rxvalid_out),
        .sigvalidclk_in(sigvalidclk_in),
        .tx8b10bbypass_in(tx8b10bbypass_in),
        .tx8b10ben_in(tx8b10ben_in),
        .txbufdiffctrl_in(txbufdiffctrl_in),
        .txbufstatus_out(txbufstatus_out),
        .txcomfinish_out(txcomfinish_out),
        .txcominit_in(txcominit_in),
        .txcomsas_in(txcomsas_in),
        .txcomwake_in(txcomwake_in),
        .txctrl0_in(txctrl0_in),
        .txctrl1_in(txctrl1_in),
        .txctrl2_in(txctrl2_in),
        .txdataextendrsvd_in(txdataextendrsvd_in),
        .txdeemph_in(txdeemph_in),
        .txdetectrx_in(txdetectrx_in),
        .txdiffctrl_in(txdiffctrl_in),
        .txdiffpd_in(txdiffpd_in),
        .txdlybypass_in(txdlybypass_in),
        .txdlyen_in(txdlyen_in),
        .txdlyhold_in(txdlyhold_in),
        .txdlyovrden_in(txdlyovrden_in),
        .txdlysreset_in(txdlysreset_in),
        .txdlysresetdone_out(txdlysresetdone_out),
        .txdlyupdown_in(txdlyupdown_in),
        .txelecidle_in(txelecidle_in),
        .txheader_in(txheader_in),
        .txinhibit_in(txinhibit_in),
        .txlatclk_in(txlatclk_in),
        .txmaincursor_in(txmaincursor_in),
        .txmargin_in(txmargin_in),
        .txoutclk_out(txoutclk_out),
        .txoutclkfabric_out(txoutclkfabric_out),
        .txoutclkpcs_out(txoutclkpcs_out),
        .txoutclksel_in(txoutclksel_in),
        .txpcsreset_in(txpcsreset_in),
        .txpd_in(txpd_in),
        .txpdelecidlemode_in(txpdelecidlemode_in),
        .txphalign_in(txphalign_in),
        .txphaligndone_out(txphaligndone_out),
        .txphalignen_in(txphalignen_in),
        .txphdlypd_in(txphdlypd_in),
        .txphdlyreset_in(txphdlyreset_in),
        .txphdlytstclk_in(txphdlytstclk_in),
        .txphinit_in(txphinit_in),
        .txphinitdone_out(txphinitdone_out),
        .txphovrden_in(txphovrden_in),
        .txpippmen_in(txpippmen_in),
        .txpippmovrden_in(txpippmovrden_in),
        .txpippmpd_in(txpippmpd_in),
        .txpippmsel_in(txpippmsel_in),
        .txpippmstepsize_in(txpippmstepsize_in),
        .txpisopd_in(txpisopd_in),
        .txpllclksel_in(txpllclksel_in),
        .txpmareset_in(txpmareset_in),
        .txpmaresetdone_out(txpmaresetdone_out),
        .txpolarity_in(txpolarity_in),
        .txpostcursor_in(txpostcursor_in),
        .txpostcursorinv_in(txpostcursorinv_in),
        .txprbsforceerr_in(txprbsforceerr_in),
        .txprbssel_in(txprbssel_in),
        .txprecursor_in(txprecursor_in),
        .txprecursorinv_in(txprecursorinv_in),
        .txprgdivresetdone_out(txprgdivresetdone_out),
        .txqpibiasen_in(txqpibiasen_in),
        .txqpisenn_out(txqpisenn_out),
        .txqpisenp_out(txqpisenp_out),
        .txqpistrongpdown_in(txqpistrongpdown_in),
        .txqpiweakpup_in(txqpiweakpup_in),
        .txrate_in(txrate_in),
        .txratedone_out(txratedone_out),
        .txratemode_in(txratemode_in),
        .txresetdone_out(txresetdone_out),
        .txsequence_in(txsequence_in),
        .txswing_in(txswing_in),
        .txsyncallin_in(txsyncallin_in),
        .txsyncdone_out(txsyncdone_out),
        .txsyncin_in(txsyncin_in),
        .txsyncmode_in(txsyncmode_in),
        .txsyncout_out(txsyncout_out),
        .txsysclksel_in(txsysclksel_in),
        .txusrclk2_in(txusrclk2_in),
        .txusrclk_in(txusrclk_in));
GthUltrascaleJesdCoregen_GthUltrascaleJesdCoregen_gthe3_common_wrapper \gen_gtwizard_gthe3.gen_common.gen_common_container[4].gen_enabled_common.gthe3_common_wrapper_inst 
       (.O1(qpll0lock_out),
        .drpaddr_common_in(drpaddr_common_in),
        .drpclk_common_in(drpclk_common_in),
        .drpdi_common_in(drpdi_common_in),
        .drpdo_common_out(drpdo_common_out),
        .drpen_common_in(drpen_common_in),
        .drprdy_common_out(drprdy_common_out),
        .drpwe_common_in(drpwe_common_in),
        .gtgrefclk0_in(gtgrefclk0_in),
        .gtgrefclk1_in(gtgrefclk1_in),
        .gtnorthrefclk00_in(gtnorthrefclk00_in),
        .gtnorthrefclk01_in(gtnorthrefclk01_in),
        .gtnorthrefclk10_in(gtnorthrefclk10_in),
        .gtnorthrefclk11_in(gtnorthrefclk11_in),
        .gtrefclk00_in(gtrefclk00_in),
        .gtrefclk01_in(gtrefclk01_in),
        .gtrefclk10_in(gtrefclk10_in),
        .gtrefclk11_in(gtrefclk11_in),
        .gtsouthrefclk00_in(gtsouthrefclk00_in),
        .gtsouthrefclk01_in(gtsouthrefclk01_in),
        .gtsouthrefclk10_in(gtsouthrefclk10_in),
        .gtsouthrefclk11_in(gtsouthrefclk11_in),
        .gtwiz_reset_qpll0reset_out(gtwiz_reset_qpll0reset_out),
        .pmarsvdout0_out(pmarsvdout0_out),
        .pmarsvdout1_out(pmarsvdout1_out),
        .qpll0clkrsvd0_in(qpll0clkrsvd0_in),
        .qpll0clkrsvd1_in(qpll0clkrsvd1_in),
        .qpll0fbclklost_out(qpll0fbclklost_out),
        .qpll0lockdetclk_in(qpll0lockdetclk_in),
        .qpll0locken_in(qpll0locken_in),
        .qpll0outclk_out(qpll0outclk_out),
        .qpll0outrefclk_out(qpll0outrefclk_out),
        .qpll0pd_in(qpll0pd_in),
        .qpll0refclklost_out(qpll0refclklost_out),
        .qpll0refclksel_in(qpll0refclksel_in),
        .qpll1clkrsvd0_in(qpll1clkrsvd0_in),
        .qpll1clkrsvd1_in(qpll1clkrsvd1_in),
        .qpll1fbclklost_out(qpll1fbclklost_out),
        .qpll1lock_out(qpll1lock_out),
        .qpll1lockdetclk_in(qpll1lockdetclk_in),
        .qpll1locken_in(qpll1locken_in),
        .qpll1outclk_out(qpll1outclk_out),
        .qpll1outrefclk_out(qpll1outrefclk_out),
        .qpll1pd_in(qpll1pd_in),
        .qpll1refclklost_out(qpll1refclklost_out),
        .qpll1refclksel_in(qpll1refclksel_in),
        .qpll1reset_in(qpll1reset_in),
        .qplldmonitor0_out(qplldmonitor0_out),
        .qplldmonitor1_out(qplldmonitor1_out),
        .qpllrsvd1_in(qpllrsvd1_in),
        .qpllrsvd2_in(qpllrsvd2_in),
        .qpllrsvd3_in(qpllrsvd3_in),
        .qpllrsvd4_in(qpllrsvd4_in),
        .refclkoutmonitor0_out(refclkoutmonitor0_out),
        .refclkoutmonitor1_out(refclkoutmonitor1_out),
        .rst_in0(rst_in0),
        .rxrecclk0_sel_out(rxrecclk0_sel_out),
        .rxrecclk1_sel_out(rxrecclk1_sel_out));
GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_gtwiz_reset \gen_gtwizard_gthe3.gen_reset_controller_internal.gen_single_instance.gtwiz_reset_inst 
       (.GTHE3_CHANNEL_GTRXRESET(gtwiz_reset_gtrxreset_int),
        .GTHE3_CHANNEL_GTTXRESET(gtwiz_reset_gttxreset_int),
        .GTHE3_CHANNEL_RXPROGDIVRESET(gtwiz_reset_rxprogdivreset_int),
        .GTHE3_CHANNEL_RXUSERRDY(gtwiz_reset_rxuserrdy_int),
        .GTHE3_CHANNEL_TXPROGDIVRESET(gtwiz_reset_txprogdivreset_int),
        .GTHE3_CHANNEL_TXUSERRDY(gtwiz_reset_txuserrdy_int),
        .I1(\n_0_gen_gtwizard_gthe3.gen_channel_container[4].gen_enabled_channel.gthe3_channel_wrapper_inst ),
        .I2(\n_3_gen_gtwizard_gthe3.gen_channel_container[4].gen_enabled_channel.gthe3_channel_wrapper_inst ),
        .I3(\n_6_gen_gtwizard_gthe3.gen_channel_container[4].gen_enabled_channel.gthe3_channel_wrapper_inst ),
        .I4(\n_9_gen_gtwizard_gthe3.gen_channel_container[4].gen_enabled_channel.gthe3_channel_wrapper_inst ),
        .gtwiz_reset_all_in(gtwiz_reset_all_in),
        .gtwiz_reset_clk_freerun_in(gtwiz_reset_clk_freerun_in),
        .gtwiz_reset_qpll0reset_out(gtwiz_reset_qpll0reset_out),
        .gtwiz_reset_rx_cdr_stable_out(gtwiz_reset_rx_cdr_stable_out),
        .gtwiz_reset_rx_datapath_in(gtwiz_reset_rx_datapath_in),
        .gtwiz_reset_rx_done_out(gtwiz_reset_rx_done_out),
        .gtwiz_reset_rx_pll_and_datapath_in(gtwiz_reset_rx_pll_and_datapath_in),
        .gtwiz_reset_tx_datapath_in(gtwiz_reset_tx_datapath_in),
        .gtwiz_reset_tx_done_out(gtwiz_reset_tx_done_out),
        .gtwiz_reset_tx_pll_and_datapath_in(gtwiz_reset_tx_pll_and_datapath_in),
        .gtwiz_userclk_rx_active_in(gtwiz_userclk_rx_active_in),
        .gtwiz_userclk_tx_active_in(gtwiz_userclk_tx_active_in),
        .qpll0lock_out(qpll0lock_out),
        .rst_in0(rst_in0),
        .rxusrclk2_in(rxusrclk2_in[0]),
        .txusrclk2_in(txusrclk2_in[0]));
endmodule

(* C_CHANNEL_ENABLE = "192'b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000" *) (* C_COMMON_SCALING_FACTOR = "1" *) (* C_CPLL_VCO_FREQUENCY = "2578.125000" *) 
(* C_FORCE_COMMONS = "0" *) (* C_FREERUN_FREQUENCY = "185.000000" *) (* C_GT_TYPE = "0" *) 
(* C_GT_REV = "0" *) (* C_INCLUDE_CPLL_CAL = "2" *) (* C_LOCATE_COMMON = "0" *) 
(* C_LOCATE_RESET_CONTROLLER = "0" *) (* C_LOCATE_USER_DATA_WIDTH_SIZING = "0" *) (* C_LOCATE_RX_BUFFER_BYPASS_CONTROLLER = "0" *) 
(* C_LOCATE_RX_USER_CLOCKING = "1" *) (* C_LOCATE_TX_BUFFER_BYPASS_CONTROLLER = "0" *) (* C_LOCATE_TX_USER_CLOCKING = "1" *) 
(* C_RESET_CONTROLLER_INSTANCE_CTRL = "0" *) (* C_RX_BUFFBYPASS_MODE = "0" *) (* C_RX_BUFFER_BYPASS_INSTANCE_CTRL = "0" *) 
(* C_RX_BUFFER_MODE = "1" *) (* C_RX_CB_DISP = "8'b00000000" *) (* C_RX_CB_K = "8'b00000000" *) 
(* C_RX_CB_MAX_LEVEL = "1" *) (* C_RX_CB_LEN_SEQ = "1" *) (* C_RX_CB_NUM_SEQ = "0" *) 
(* C_RX_CB_VAL = "80'b00000000000000000000000000000000000000000000000000000000000000000000000000000000" *) (* C_RX_CC_DISP = "8'b00000000" *) (* C_RX_CC_ENABLE = "0" *) 
(* C_RX_CC_K = "8'b00000000" *) (* C_RX_CC_LEN_SEQ = "1" *) (* C_RX_CC_NUM_SEQ = "0" *) 
(* C_RX_CC_PERIODICITY = "5000" *) (* C_RX_CC_VAL = "80'b00000000000000000000000000000000000000000000000000000000000000000000000000000000" *) (* C_RX_COMMA_M_ENABLE = "1" *) 
(* C_RX_COMMA_M_VAL = "10'b1010000011" *) (* C_RX_COMMA_P_ENABLE = "1" *) (* C_RX_COMMA_P_VAL = "10'b0101111100" *) 
(* C_RX_DATA_DECODING = "1" *) (* C_RX_ENABLE = "1" *) (* C_RX_INT_DATA_WIDTH = "40" *) 
(* C_RX_LINE_RATE = "7.400000" *) (* C_RX_MASTER_CHANNEL_IDX = "18" *) (* C_RX_OUTCLK_BUFG_GT_DIV = "1" *) 
(* C_RX_OUTCLK_FREQUENCY = "185.000000" *) (* C_RX_OUTCLK_SOURCE = "1" *) (* C_RX_PLL_TYPE = "0" *) 
(* C_RX_RECCLK_OUTPUT = "192'b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000" *) (* C_RX_REFCLK_FREQUENCY = "370.000000" *) (* C_RX_SLIDE_MODE = "0" *) 
(* C_RX_USER_CLOCKING_CONTENTS = "0" *) (* C_RX_USER_CLOCKING_INSTANCE_CTRL = "0" *) (* C_RX_USER_CLOCKING_RATIO_FSRC_FUSRCLK = "1" *) 
(* C_RX_USER_CLOCKING_RATIO_FUSRCLK_FUSRCLK2 = "1" *) (* C_RX_USER_CLOCKING_SOURCE = "0" *) (* C_RX_USER_DATA_WIDTH = "32" *) 
(* C_RX_USRCLK_FREQUENCY = "185.000000" *) (* C_RX_USRCLK2_FREQUENCY = "185.000000" *) (* C_SECONDARY_QPLL_ENABLE = "0" *) 
(* C_SECONDARY_QPLL_REFCLK_FREQUENCY = "257.812500" *) (* C_TOTAL_NUM_CHANNELS = "2" *) (* C_TOTAL_NUM_COMMONS = "1" *) 
(* C_TOTAL_NUM_COMMONS_EXAMPLE = "0" *) (* C_TXPROGDIV_FREQ_ENABLE = "0" *) (* C_TXPROGDIV_FREQ_SOURCE = "0" *) 
(* C_TXPROGDIV_FREQ_VAL = "185.000000" *) (* C_TX_BUFFBYPASS_MODE = "0" *) (* C_TX_BUFFER_BYPASS_INSTANCE_CTRL = "0" *) 
(* C_TX_BUFFER_MODE = "1" *) (* C_TX_DATA_ENCODING = "1" *) (* C_TX_ENABLE = "1" *) 
(* C_TX_INT_DATA_WIDTH = "40" *) (* C_TX_LINE_RATE = "7.400000" *) (* C_TX_MASTER_CHANNEL_IDX = "18" *) 
(* C_TX_OUTCLK_BUFG_GT_DIV = "1" *) (* C_TX_OUTCLK_FREQUENCY = "185.000000" *) (* C_TX_OUTCLK_SOURCE = "1" *) 
(* C_TX_PLL_TYPE = "0" *) (* C_TX_REFCLK_FREQUENCY = "370.000000" *) (* C_TX_USER_CLOCKING_CONTENTS = "0" *) 
(* C_TX_USER_CLOCKING_INSTANCE_CTRL = "0" *) (* C_TX_USER_CLOCKING_RATIO_FSRC_FUSRCLK = "1" *) (* C_TX_USER_CLOCKING_RATIO_FUSRCLK_FUSRCLK2 = "1" *) 
(* C_TX_USER_CLOCKING_SOURCE = "0" *) (* C_TX_USER_DATA_WIDTH = "32" *) (* C_TX_USRCLK_FREQUENCY = "185.000000" *) 
(* C_TX_USRCLK2_FREQUENCY = "185.000000" *) (* ORIG_REF_NAME = "GthUltrascaleJesdCoregen_gtwizard_top" *) 
module GthUltrascaleJesdCoregen_GthUltrascaleJesdCoregen_gtwizard_top
   (gtwiz_userclk_tx_reset_in,
    gtwiz_userclk_tx_active_in,
    gtwiz_userclk_tx_srcclk_out,
    gtwiz_userclk_tx_usrclk_out,
    gtwiz_userclk_tx_usrclk2_out,
    gtwiz_userclk_tx_active_out,
    gtwiz_userclk_rx_reset_in,
    gtwiz_userclk_rx_active_in,
    gtwiz_userclk_rx_srcclk_out,
    gtwiz_userclk_rx_usrclk_out,
    gtwiz_userclk_rx_usrclk2_out,
    gtwiz_userclk_rx_active_out,
    gtwiz_buffbypass_tx_reset_in,
    gtwiz_buffbypass_tx_start_user_in,
    gtwiz_buffbypass_tx_done_out,
    gtwiz_buffbypass_tx_error_out,
    gtwiz_buffbypass_rx_reset_in,
    gtwiz_buffbypass_rx_start_user_in,
    gtwiz_buffbypass_rx_done_out,
    gtwiz_buffbypass_rx_error_out,
    gtwiz_reset_clk_freerun_in,
    gtwiz_reset_all_in,
    gtwiz_reset_tx_pll_and_datapath_in,
    gtwiz_reset_tx_datapath_in,
    gtwiz_reset_rx_pll_and_datapath_in,
    gtwiz_reset_rx_datapath_in,
    gtwiz_reset_tx_done_in,
    gtwiz_reset_rx_done_in,
    gtwiz_reset_qpll0lock_in,
    gtwiz_reset_qpll1lock_in,
    gtwiz_reset_rx_cdr_stable_out,
    gtwiz_reset_tx_done_out,
    gtwiz_reset_rx_done_out,
    gtwiz_reset_qpll0reset_out,
    gtwiz_reset_qpll1reset_out,
    gtwiz_gthe3_cpll_cal_txoutclk_period_in,
    gtwiz_gthe3_cpll_cal_cnt_tol_in,
    gtwiz_gthe3_cpll_cal_bufg_ce_in,
    gtwiz_userdata_tx_in,
    gtwiz_userdata_rx_out,
    bgbypassb_in,
    bgmonitorenb_in,
    bgpdb_in,
    bgrcalovrd_in,
    bgrcalovrdenb_in,
    drpaddr_common_in,
    drpclk_common_in,
    drpdi_common_in,
    drpen_common_in,
    drpwe_common_in,
    gtgrefclk0_in,
    gtgrefclk1_in,
    gtnorthrefclk00_in,
    gtnorthrefclk01_in,
    gtnorthrefclk10_in,
    gtnorthrefclk11_in,
    gtrefclk00_in,
    gtrefclk01_in,
    gtrefclk10_in,
    gtrefclk11_in,
    gtsouthrefclk00_in,
    gtsouthrefclk01_in,
    gtsouthrefclk10_in,
    gtsouthrefclk11_in,
    pmarsvd0_in,
    pmarsvd1_in,
    qpll0clkrsvd0_in,
    qpll0clkrsvd1_in,
    qpll0lockdetclk_in,
    qpll0locken_in,
    qpll0pd_in,
    qpll0refclksel_in,
    qpll0reset_in,
    qpll1clkrsvd0_in,
    qpll1clkrsvd1_in,
    qpll1lockdetclk_in,
    qpll1locken_in,
    qpll1pd_in,
    qpll1refclksel_in,
    qpll1reset_in,
    qpllrsvd1_in,
    qpllrsvd2_in,
    qpllrsvd3_in,
    qpllrsvd4_in,
    rcalenb_in,
    sdm0data_in,
    sdm0reset_in,
    sdm0width_in,
    sdm1data_in,
    sdm1reset_in,
    sdm1width_in,
    drpdo_common_out,
    drprdy_common_out,
    pmarsvdout0_out,
    pmarsvdout1_out,
    qpll0fbclklost_out,
    qpll0lock_out,
    qpll0outclk_out,
    qpll0outrefclk_out,
    qpll0refclklost_out,
    qpll1fbclklost_out,
    qpll1lock_out,
    qpll1outclk_out,
    qpll1outrefclk_out,
    qpll1refclklost_out,
    qplldmonitor0_out,
    qplldmonitor1_out,
    refclkoutmonitor0_out,
    refclkoutmonitor1_out,
    rxrecclk0_sel_out,
    rxrecclk1_sel_out,
    sdm0finalout_out,
    sdm0testdata_out,
    sdm1finalout_out,
    sdm1testdata_out,
    cdrstepdir_in,
    cdrstepsq_in,
    cdrstepsx_in,
    cfgreset_in,
    clkrsvd0_in,
    clkrsvd1_in,
    cplllockdetclk_in,
    cplllocken_in,
    cpllpd_in,
    cpllrefclksel_in,
    cpllreset_in,
    dmonfiforeset_in,
    dmonitorclk_in,
    drpaddr_in,
    drpclk_in,
    drpdi_in,
    drpen_in,
    drpwe_in,
    elpcaldvorwren_in,
    elpcalpaorwren_in,
    evoddphicaldone_in,
    evoddphicalstart_in,
    evoddphidrden_in,
    evoddphidwren_in,
    evoddphixrden_in,
    evoddphixwren_in,
    eyescanmode_in,
    eyescanreset_in,
    eyescantrigger_in,
    gtgrefclk_in,
    gthrxn_in,
    gthrxp_in,
    gtnorthrefclk0_in,
    gtnorthrefclk1_in,
    gtrefclk0_in,
    gtrefclk1_in,
    gtresetsel_in,
    gtrsvd_in,
    gtrxreset_in,
    gtsouthrefclk0_in,
    gtsouthrefclk1_in,
    gttxreset_in,
    gtyrxn_in,
    gtyrxp_in,
    loopback_in,
    looprsvd_in,
    lpbkrxtxseren_in,
    lpbktxrxseren_in,
    pcieeqrxeqadaptdone_in,
    pcierstidle_in,
    pciersttxsyncstart_in,
    pcieuserratedone_in,
    pcsrsvdin_in,
    pcsrsvdin2_in,
    pmarsvdin_in,
    qpll0clk_in,
    qpll0refclk_in,
    qpll1clk_in,
    qpll1refclk_in,
    resetovrd_in,
    rstclkentx_in,
    rx8b10ben_in,
    rxbufreset_in,
    rxcdrfreqreset_in,
    rxcdrhold_in,
    rxcdrovrden_in,
    rxcdrreset_in,
    rxcdrresetrsv_in,
    rxchbonden_in,
    rxchbondi_in,
    rxchbondlevel_in,
    rxchbondmaster_in,
    rxchbondslave_in,
    rxckcalreset_in,
    rxcommadeten_in,
    rxdfeagcctrl_in,
    rxdccforcestart_in,
    rxdfeagchold_in,
    rxdfeagcovrden_in,
    rxdfelfhold_in,
    rxdfelfovrden_in,
    rxdfelpmreset_in,
    rxdfetap10hold_in,
    rxdfetap10ovrden_in,
    rxdfetap11hold_in,
    rxdfetap11ovrden_in,
    rxdfetap12hold_in,
    rxdfetap12ovrden_in,
    rxdfetap13hold_in,
    rxdfetap13ovrden_in,
    rxdfetap14hold_in,
    rxdfetap14ovrden_in,
    rxdfetap15hold_in,
    rxdfetap15ovrden_in,
    rxdfetap2hold_in,
    rxdfetap2ovrden_in,
    rxdfetap3hold_in,
    rxdfetap3ovrden_in,
    rxdfetap4hold_in,
    rxdfetap4ovrden_in,
    rxdfetap5hold_in,
    rxdfetap5ovrden_in,
    rxdfetap6hold_in,
    rxdfetap6ovrden_in,
    rxdfetap7hold_in,
    rxdfetap7ovrden_in,
    rxdfetap8hold_in,
    rxdfetap8ovrden_in,
    rxdfetap9hold_in,
    rxdfetap9ovrden_in,
    rxdfeuthold_in,
    rxdfeutovrden_in,
    rxdfevphold_in,
    rxdfevpovrden_in,
    rxdfevsen_in,
    rxdfexyden_in,
    rxdlybypass_in,
    rxdlyen_in,
    rxdlyovrden_in,
    rxdlysreset_in,
    rxelecidlemode_in,
    rxgearboxslip_in,
    rxlatclk_in,
    rxlpmen_in,
    rxlpmgchold_in,
    rxlpmgcovrden_in,
    rxlpmhfhold_in,
    rxlpmhfovrden_in,
    rxlpmlfhold_in,
    rxlpmlfklovrden_in,
    rxlpmoshold_in,
    rxlpmosovrden_in,
    rxmcommaalignen_in,
    rxmonitorsel_in,
    rxoobreset_in,
    rxoscalreset_in,
    rxoshold_in,
    rxosintcfg_in,
    rxosinten_in,
    rxosinthold_in,
    rxosintovrden_in,
    rxosintstrobe_in,
    rxosinttestovrden_in,
    rxosovrden_in,
    rxoutclksel_in,
    rxpcommaalignen_in,
    rxpcsreset_in,
    rxpd_in,
    rxphalign_in,
    rxphalignen_in,
    rxphdlypd_in,
    rxphdlyreset_in,
    rxphovrden_in,
    rxpllclksel_in,
    rxpmareset_in,
    rxpolarity_in,
    rxprbscntreset_in,
    rxprbssel_in,
    rxprogdivreset_in,
    rxqpien_in,
    rxrate_in,
    rxratemode_in,
    rxslide_in,
    rxslipoutclk_in,
    rxslippma_in,
    rxsyncallin_in,
    rxsyncin_in,
    rxsyncmode_in,
    rxsysclksel_in,
    rxuserrdy_in,
    rxusrclk_in,
    rxusrclk2_in,
    sigvalidclk_in,
    tstin_in,
    tx8b10bbypass_in,
    tx8b10ben_in,
    txbufdiffctrl_in,
    txcominit_in,
    txcomsas_in,
    txcomwake_in,
    txctrl0_in,
    txctrl1_in,
    txctrl2_in,
    txdata_in,
    txdataextendrsvd_in,
    txdccforcestart_in,
    txdccreset_in,
    txdeemph_in,
    txdetectrx_in,
    txdiffctrl_in,
    txdiffpd_in,
    txdlybypass_in,
    txdlyen_in,
    txdlyhold_in,
    txdlyovrden_in,
    txdlysreset_in,
    txdlyupdown_in,
    txelecidle_in,
    txelforcestart_in,
    txheader_in,
    txinhibit_in,
    txlatclk_in,
    txmaincursor_in,
    txmargin_in,
    txoutclksel_in,
    txpcsreset_in,
    txpd_in,
    txpdelecidlemode_in,
    txphalign_in,
    txphalignen_in,
    txphdlypd_in,
    txphdlyreset_in,
    txphdlytstclk_in,
    txphinit_in,
    txphovrden_in,
    txpippmen_in,
    txpippmovrden_in,
    txpippmpd_in,
    txpippmsel_in,
    txpippmstepsize_in,
    txpisopd_in,
    txpllclksel_in,
    txpmareset_in,
    txpolarity_in,
    txpostcursor_in,
    txpostcursorinv_in,
    txprbsforceerr_in,
    txprbssel_in,
    txprecursor_in,
    txprecursorinv_in,
    txprogdivreset_in,
    txqpibiasen_in,
    txqpistrongpdown_in,
    txqpiweakpup_in,
    txrate_in,
    txratemode_in,
    txsequence_in,
    txswing_in,
    txsyncallin_in,
    txsyncin_in,
    txsyncmode_in,
    txsysclksel_in,
    txuserrdy_in,
    txusrclk_in,
    txusrclk2_in,
    bufgtce_out,
    bufgtcemask_out,
    bufgtdiv_out,
    bufgtreset_out,
    bufgtrstmask_out,
    cpllfbclklost_out,
    cplllock_out,
    cpllrefclklost_out,
    dmonitorout_out,
    drpdo_out,
    drprdy_out,
    eyescandataerror_out,
    gthtxn_out,
    gthtxp_out,
    gtpowergood_out,
    gtrefclkmonitor_out,
    gtytxn_out,
    gtytxp_out,
    pcierategen3_out,
    pcierateidle_out,
    pcierateqpllpd_out,
    pcierateqpllreset_out,
    pciesynctxsyncdone_out,
    pcieusergen3rdy_out,
    pcieuserphystatusrst_out,
    pcieuserratestart_out,
    pcsrsvdout_out,
    phystatus_out,
    pinrsrvdas_out,
    resetexception_out,
    rxbufstatus_out,
    rxbyteisaligned_out,
    rxbyterealign_out,
    rxcdrlock_out,
    rxcdrphdone_out,
    rxchanbondseq_out,
    rxchanisaligned_out,
    rxchanrealign_out,
    rxchbondo_out,
    rxckcaldone_out,
    rxclkcorcnt_out,
    rxcominitdet_out,
    rxcommadet_out,
    rxcomsasdet_out,
    rxcomwakedet_out,
    rxctrl0_out,
    rxctrl1_out,
    rxctrl2_out,
    rxctrl3_out,
    rxdata_out,
    rxdataextendrsvd_out,
    rxdatavalid_out,
    rxdlysresetdone_out,
    rxelecidle_out,
    rxheader_out,
    rxheadervalid_out,
    rxmonitorout_out,
    rxosintdone_out,
    rxosintstarted_out,
    rxosintstrobedone_out,
    rxosintstrobestarted_out,
    rxoutclk_out,
    rxoutclkfabric_out,
    rxoutclkpcs_out,
    rxphaligndone_out,
    rxphalignerr_out,
    rxpmaresetdone_out,
    rxprbserr_out,
    rxprbslocked_out,
    rxprgdivresetdone_out,
    rxqpisenn_out,
    rxqpisenp_out,
    rxratedone_out,
    rxrecclkout_out,
    rxresetdone_out,
    rxsliderdy_out,
    rxslipdone_out,
    rxslipoutclkrdy_out,
    rxslippmardy_out,
    rxstartofseq_out,
    rxstatus_out,
    rxsyncdone_out,
    rxsyncout_out,
    rxvalid_out,
    txbufstatus_out,
    txcomfinish_out,
    txdccdone_out,
    txdlysresetdone_out,
    txoutclk_out,
    txoutclkfabric_out,
    txoutclkpcs_out,
    txphaligndone_out,
    txphinitdone_out,
    txpmaresetdone_out,
    txprgdivresetdone_out,
    txqpisenn_out,
    txqpisenp_out,
    txratedone_out,
    txresetdone_out,
    txsyncdone_out,
    txsyncout_out);
  input [0:0]gtwiz_userclk_tx_reset_in;
  input [0:0]gtwiz_userclk_tx_active_in;
  output [0:0]gtwiz_userclk_tx_srcclk_out;
  output [0:0]gtwiz_userclk_tx_usrclk_out;
  output [0:0]gtwiz_userclk_tx_usrclk2_out;
  output [0:0]gtwiz_userclk_tx_active_out;
  input [0:0]gtwiz_userclk_rx_reset_in;
  input [0:0]gtwiz_userclk_rx_active_in;
  output [0:0]gtwiz_userclk_rx_srcclk_out;
  output [0:0]gtwiz_userclk_rx_usrclk_out;
  output [0:0]gtwiz_userclk_rx_usrclk2_out;
  output [0:0]gtwiz_userclk_rx_active_out;
  input [0:0]gtwiz_buffbypass_tx_reset_in;
  input [0:0]gtwiz_buffbypass_tx_start_user_in;
  output [0:0]gtwiz_buffbypass_tx_done_out;
  output [0:0]gtwiz_buffbypass_tx_error_out;
  input [0:0]gtwiz_buffbypass_rx_reset_in;
  input [0:0]gtwiz_buffbypass_rx_start_user_in;
  output [0:0]gtwiz_buffbypass_rx_done_out;
  output [0:0]gtwiz_buffbypass_rx_error_out;
  input [0:0]gtwiz_reset_clk_freerun_in;
  input [0:0]gtwiz_reset_all_in;
  input [0:0]gtwiz_reset_tx_pll_and_datapath_in;
  input [0:0]gtwiz_reset_tx_datapath_in;
  input [0:0]gtwiz_reset_rx_pll_and_datapath_in;
  input [0:0]gtwiz_reset_rx_datapath_in;
  input [0:0]gtwiz_reset_tx_done_in;
  input [0:0]gtwiz_reset_rx_done_in;
  input [0:0]gtwiz_reset_qpll0lock_in;
  input [0:0]gtwiz_reset_qpll1lock_in;
  output [0:0]gtwiz_reset_rx_cdr_stable_out;
  output [0:0]gtwiz_reset_tx_done_out;
  output [0:0]gtwiz_reset_rx_done_out;
  output [0:0]gtwiz_reset_qpll0reset_out;
  output [0:0]gtwiz_reset_qpll1reset_out;
  input [35:0]gtwiz_gthe3_cpll_cal_txoutclk_period_in;
  input [35:0]gtwiz_gthe3_cpll_cal_cnt_tol_in;
  input [1:0]gtwiz_gthe3_cpll_cal_bufg_ce_in;
  input [63:0]gtwiz_userdata_tx_in;
  output [63:0]gtwiz_userdata_rx_out;
  input [0:0]bgbypassb_in;
  input [0:0]bgmonitorenb_in;
  input [0:0]bgpdb_in;
  input [4:0]bgrcalovrd_in;
  input [0:0]bgrcalovrdenb_in;
  input [8:0]drpaddr_common_in;
  input [0:0]drpclk_common_in;
  input [15:0]drpdi_common_in;
  input [0:0]drpen_common_in;
  input [0:0]drpwe_common_in;
  input [0:0]gtgrefclk0_in;
  input [0:0]gtgrefclk1_in;
  input [0:0]gtnorthrefclk00_in;
  input [0:0]gtnorthrefclk01_in;
  input [0:0]gtnorthrefclk10_in;
  input [0:0]gtnorthrefclk11_in;
  input [0:0]gtrefclk00_in;
  input [0:0]gtrefclk01_in;
  input [0:0]gtrefclk10_in;
  input [0:0]gtrefclk11_in;
  input [0:0]gtsouthrefclk00_in;
  input [0:0]gtsouthrefclk01_in;
  input [0:0]gtsouthrefclk10_in;
  input [0:0]gtsouthrefclk11_in;
  input [7:0]pmarsvd0_in;
  input [7:0]pmarsvd1_in;
  input [0:0]qpll0clkrsvd0_in;
  input [0:0]qpll0clkrsvd1_in;
  input [0:0]qpll0lockdetclk_in;
  input [0:0]qpll0locken_in;
  input [0:0]qpll0pd_in;
  input [2:0]qpll0refclksel_in;
  input [0:0]qpll0reset_in;
  input [0:0]qpll1clkrsvd0_in;
  input [0:0]qpll1clkrsvd1_in;
  input [0:0]qpll1lockdetclk_in;
  input [0:0]qpll1locken_in;
  input [0:0]qpll1pd_in;
  input [2:0]qpll1refclksel_in;
  input [0:0]qpll1reset_in;
  input [7:0]qpllrsvd1_in;
  input [4:0]qpllrsvd2_in;
  input [4:0]qpllrsvd3_in;
  input [7:0]qpllrsvd4_in;
  input [0:0]rcalenb_in;
  input [0:0]sdm0data_in;
  input [0:0]sdm0reset_in;
  input [0:0]sdm0width_in;
  input [0:0]sdm1data_in;
  input [0:0]sdm1reset_in;
  input [0:0]sdm1width_in;
  output [15:0]drpdo_common_out;
  output [0:0]drprdy_common_out;
  output [7:0]pmarsvdout0_out;
  output [7:0]pmarsvdout1_out;
  output [0:0]qpll0fbclklost_out;
  output [0:0]qpll0lock_out;
  output [0:0]qpll0outclk_out;
  output [0:0]qpll0outrefclk_out;
  output [0:0]qpll0refclklost_out;
  output [0:0]qpll1fbclklost_out;
  output [0:0]qpll1lock_out;
  output [0:0]qpll1outclk_out;
  output [0:0]qpll1outrefclk_out;
  output [0:0]qpll1refclklost_out;
  output [7:0]qplldmonitor0_out;
  output [7:0]qplldmonitor1_out;
  output [0:0]refclkoutmonitor0_out;
  output [0:0]refclkoutmonitor1_out;
  output [1:0]rxrecclk0_sel_out;
  output [1:0]rxrecclk1_sel_out;
  output [0:0]sdm0finalout_out;
  output [0:0]sdm0testdata_out;
  output [0:0]sdm1finalout_out;
  output [0:0]sdm1testdata_out;
  input [0:0]cdrstepdir_in;
  input [0:0]cdrstepsq_in;
  input [0:0]cdrstepsx_in;
  input [1:0]cfgreset_in;
  input [1:0]clkrsvd0_in;
  input [1:0]clkrsvd1_in;
  input [1:0]cplllockdetclk_in;
  input [1:0]cplllocken_in;
  input [1:0]cpllpd_in;
  input [5:0]cpllrefclksel_in;
  input [1:0]cpllreset_in;
  input [1:0]dmonfiforeset_in;
  input [1:0]dmonitorclk_in;
  input [17:0]drpaddr_in;
  input [1:0]drpclk_in;
  input [31:0]drpdi_in;
  input [1:0]drpen_in;
  input [1:0]drpwe_in;
  input [0:0]elpcaldvorwren_in;
  input [0:0]elpcalpaorwren_in;
  input [1:0]evoddphicaldone_in;
  input [1:0]evoddphicalstart_in;
  input [1:0]evoddphidrden_in;
  input [1:0]evoddphidwren_in;
  input [1:0]evoddphixrden_in;
  input [1:0]evoddphixwren_in;
  input [1:0]eyescanmode_in;
  input [1:0]eyescanreset_in;
  input [1:0]eyescantrigger_in;
  input [1:0]gtgrefclk_in;
  input [1:0]gthrxn_in;
  input [1:0]gthrxp_in;
  input [1:0]gtnorthrefclk0_in;
  input [1:0]gtnorthrefclk1_in;
  input [1:0]gtrefclk0_in;
  input [1:0]gtrefclk1_in;
  input [1:0]gtresetsel_in;
  input [31:0]gtrsvd_in;
  input [1:0]gtrxreset_in;
  input [1:0]gtsouthrefclk0_in;
  input [1:0]gtsouthrefclk1_in;
  input [1:0]gttxreset_in;
  input [0:0]gtyrxn_in;
  input [0:0]gtyrxp_in;
  input [5:0]loopback_in;
  input [0:0]looprsvd_in;
  input [1:0]lpbkrxtxseren_in;
  input [1:0]lpbktxrxseren_in;
  input [1:0]pcieeqrxeqadaptdone_in;
  input [1:0]pcierstidle_in;
  input [1:0]pciersttxsyncstart_in;
  input [1:0]pcieuserratedone_in;
  input [31:0]pcsrsvdin_in;
  input [9:0]pcsrsvdin2_in;
  input [9:0]pmarsvdin_in;
  input [1:0]qpll0clk_in;
  input [1:0]qpll0refclk_in;
  input [1:0]qpll1clk_in;
  input [1:0]qpll1refclk_in;
  input [1:0]resetovrd_in;
  input [1:0]rstclkentx_in;
  input [1:0]rx8b10ben_in;
  input [1:0]rxbufreset_in;
  input [1:0]rxcdrfreqreset_in;
  input [1:0]rxcdrhold_in;
  input [1:0]rxcdrovrden_in;
  input [1:0]rxcdrreset_in;
  input [1:0]rxcdrresetrsv_in;
  input [1:0]rxchbonden_in;
  input [9:0]rxchbondi_in;
  input [5:0]rxchbondlevel_in;
  input [1:0]rxchbondmaster_in;
  input [1:0]rxchbondslave_in;
  input [0:0]rxckcalreset_in;
  input [1:0]rxcommadeten_in;
  input [3:0]rxdfeagcctrl_in;
  input [0:0]rxdccforcestart_in;
  input [1:0]rxdfeagchold_in;
  input [1:0]rxdfeagcovrden_in;
  input [1:0]rxdfelfhold_in;
  input [1:0]rxdfelfovrden_in;
  input [1:0]rxdfelpmreset_in;
  input [1:0]rxdfetap10hold_in;
  input [1:0]rxdfetap10ovrden_in;
  input [1:0]rxdfetap11hold_in;
  input [1:0]rxdfetap11ovrden_in;
  input [1:0]rxdfetap12hold_in;
  input [1:0]rxdfetap12ovrden_in;
  input [1:0]rxdfetap13hold_in;
  input [1:0]rxdfetap13ovrden_in;
  input [1:0]rxdfetap14hold_in;
  input [1:0]rxdfetap14ovrden_in;
  input [1:0]rxdfetap15hold_in;
  input [1:0]rxdfetap15ovrden_in;
  input [1:0]rxdfetap2hold_in;
  input [1:0]rxdfetap2ovrden_in;
  input [1:0]rxdfetap3hold_in;
  input [1:0]rxdfetap3ovrden_in;
  input [1:0]rxdfetap4hold_in;
  input [1:0]rxdfetap4ovrden_in;
  input [1:0]rxdfetap5hold_in;
  input [1:0]rxdfetap5ovrden_in;
  input [1:0]rxdfetap6hold_in;
  input [1:0]rxdfetap6ovrden_in;
  input [1:0]rxdfetap7hold_in;
  input [1:0]rxdfetap7ovrden_in;
  input [1:0]rxdfetap8hold_in;
  input [1:0]rxdfetap8ovrden_in;
  input [1:0]rxdfetap9hold_in;
  input [1:0]rxdfetap9ovrden_in;
  input [1:0]rxdfeuthold_in;
  input [1:0]rxdfeutovrden_in;
  input [1:0]rxdfevphold_in;
  input [1:0]rxdfevpovrden_in;
  input [1:0]rxdfevsen_in;
  input [1:0]rxdfexyden_in;
  input [1:0]rxdlybypass_in;
  input [1:0]rxdlyen_in;
  input [1:0]rxdlyovrden_in;
  input [1:0]rxdlysreset_in;
  input [3:0]rxelecidlemode_in;
  input [1:0]rxgearboxslip_in;
  input [1:0]rxlatclk_in;
  input [1:0]rxlpmen_in;
  input [1:0]rxlpmgchold_in;
  input [1:0]rxlpmgcovrden_in;
  input [1:0]rxlpmhfhold_in;
  input [1:0]rxlpmhfovrden_in;
  input [1:0]rxlpmlfhold_in;
  input [1:0]rxlpmlfklovrden_in;
  input [1:0]rxlpmoshold_in;
  input [1:0]rxlpmosovrden_in;
  input [1:0]rxmcommaalignen_in;
  input [3:0]rxmonitorsel_in;
  input [1:0]rxoobreset_in;
  input [1:0]rxoscalreset_in;
  input [1:0]rxoshold_in;
  input [7:0]rxosintcfg_in;
  input [1:0]rxosinten_in;
  input [1:0]rxosinthold_in;
  input [1:0]rxosintovrden_in;
  input [1:0]rxosintstrobe_in;
  input [1:0]rxosinttestovrden_in;
  input [1:0]rxosovrden_in;
  input [5:0]rxoutclksel_in;
  input [1:0]rxpcommaalignen_in;
  input [1:0]rxpcsreset_in;
  input [3:0]rxpd_in;
  input [1:0]rxphalign_in;
  input [1:0]rxphalignen_in;
  input [1:0]rxphdlypd_in;
  input [1:0]rxphdlyreset_in;
  input [1:0]rxphovrden_in;
  input [3:0]rxpllclksel_in;
  input [1:0]rxpmareset_in;
  input [1:0]rxpolarity_in;
  input [1:0]rxprbscntreset_in;
  input [7:0]rxprbssel_in;
  input [1:0]rxprogdivreset_in;
  input [1:0]rxqpien_in;
  input [5:0]rxrate_in;
  input [1:0]rxratemode_in;
  input [1:0]rxslide_in;
  input [1:0]rxslipoutclk_in;
  input [1:0]rxslippma_in;
  input [1:0]rxsyncallin_in;
  input [1:0]rxsyncin_in;
  input [1:0]rxsyncmode_in;
  input [3:0]rxsysclksel_in;
  input [1:0]rxuserrdy_in;
  input [1:0]rxusrclk_in;
  input [1:0]rxusrclk2_in;
  input [1:0]sigvalidclk_in;
  input [39:0]tstin_in;
  input [15:0]tx8b10bbypass_in;
  input [1:0]tx8b10ben_in;
  input [5:0]txbufdiffctrl_in;
  input [1:0]txcominit_in;
  input [1:0]txcomsas_in;
  input [1:0]txcomwake_in;
  input [31:0]txctrl0_in;
  input [31:0]txctrl1_in;
  input [15:0]txctrl2_in;
  input [255:0]txdata_in;
  input [15:0]txdataextendrsvd_in;
  input [0:0]txdccforcestart_in;
  input [0:0]txdccreset_in;
  input [1:0]txdeemph_in;
  input [1:0]txdetectrx_in;
  input [7:0]txdiffctrl_in;
  input [1:0]txdiffpd_in;
  input [1:0]txdlybypass_in;
  input [1:0]txdlyen_in;
  input [1:0]txdlyhold_in;
  input [1:0]txdlyovrden_in;
  input [1:0]txdlysreset_in;
  input [1:0]txdlyupdown_in;
  input [1:0]txelecidle_in;
  input [0:0]txelforcestart_in;
  input [11:0]txheader_in;
  input [1:0]txinhibit_in;
  input [1:0]txlatclk_in;
  input [13:0]txmaincursor_in;
  input [5:0]txmargin_in;
  input [5:0]txoutclksel_in;
  input [1:0]txpcsreset_in;
  input [3:0]txpd_in;
  input [1:0]txpdelecidlemode_in;
  input [1:0]txphalign_in;
  input [1:0]txphalignen_in;
  input [1:0]txphdlypd_in;
  input [1:0]txphdlyreset_in;
  input [1:0]txphdlytstclk_in;
  input [1:0]txphinit_in;
  input [1:0]txphovrden_in;
  input [1:0]txpippmen_in;
  input [1:0]txpippmovrden_in;
  input [1:0]txpippmpd_in;
  input [1:0]txpippmsel_in;
  input [9:0]txpippmstepsize_in;
  input [1:0]txpisopd_in;
  input [3:0]txpllclksel_in;
  input [1:0]txpmareset_in;
  input [1:0]txpolarity_in;
  input [9:0]txpostcursor_in;
  input [1:0]txpostcursorinv_in;
  input [1:0]txprbsforceerr_in;
  input [7:0]txprbssel_in;
  input [9:0]txprecursor_in;
  input [1:0]txprecursorinv_in;
  input [1:0]txprogdivreset_in;
  input [1:0]txqpibiasen_in;
  input [1:0]txqpistrongpdown_in;
  input [1:0]txqpiweakpup_in;
  input [5:0]txrate_in;
  input [1:0]txratemode_in;
  input [13:0]txsequence_in;
  input [1:0]txswing_in;
  input [1:0]txsyncallin_in;
  input [1:0]txsyncin_in;
  input [1:0]txsyncmode_in;
  input [3:0]txsysclksel_in;
  input [1:0]txuserrdy_in;
  input [1:0]txusrclk_in;
  input [1:0]txusrclk2_in;
  output [5:0]bufgtce_out;
  output [5:0]bufgtcemask_out;
  output [17:0]bufgtdiv_out;
  output [5:0]bufgtreset_out;
  output [5:0]bufgtrstmask_out;
  output [1:0]cpllfbclklost_out;
  output [1:0]cplllock_out;
  output [1:0]cpllrefclklost_out;
  output [33:0]dmonitorout_out;
  output [31:0]drpdo_out;
  output [1:0]drprdy_out;
  output [1:0]eyescandataerror_out;
  output [1:0]gthtxn_out;
  output [1:0]gthtxp_out;
  output [1:0]gtpowergood_out;
  output [1:0]gtrefclkmonitor_out;
  output [0:0]gtytxn_out;
  output [0:0]gtytxp_out;
  output [1:0]pcierategen3_out;
  output [1:0]pcierateidle_out;
  output [3:0]pcierateqpllpd_out;
  output [3:0]pcierateqpllreset_out;
  output [1:0]pciesynctxsyncdone_out;
  output [1:0]pcieusergen3rdy_out;
  output [1:0]pcieuserphystatusrst_out;
  output [1:0]pcieuserratestart_out;
  output [23:0]pcsrsvdout_out;
  output [1:0]phystatus_out;
  output [15:0]pinrsrvdas_out;
  output [1:0]resetexception_out;
  output [5:0]rxbufstatus_out;
  output [1:0]rxbyteisaligned_out;
  output [1:0]rxbyterealign_out;
  output [1:0]rxcdrlock_out;
  output [1:0]rxcdrphdone_out;
  output [1:0]rxchanbondseq_out;
  output [1:0]rxchanisaligned_out;
  output [1:0]rxchanrealign_out;
  output [9:0]rxchbondo_out;
  output [0:0]rxckcaldone_out;
  output [3:0]rxclkcorcnt_out;
  output [1:0]rxcominitdet_out;
  output [1:0]rxcommadet_out;
  output [1:0]rxcomsasdet_out;
  output [1:0]rxcomwakedet_out;
  output [31:0]rxctrl0_out;
  output [31:0]rxctrl1_out;
  output [15:0]rxctrl2_out;
  output [15:0]rxctrl3_out;
  output [255:0]rxdata_out;
  output [15:0]rxdataextendrsvd_out;
  output [3:0]rxdatavalid_out;
  output [1:0]rxdlysresetdone_out;
  output [1:0]rxelecidle_out;
  output [11:0]rxheader_out;
  output [3:0]rxheadervalid_out;
  output [13:0]rxmonitorout_out;
  output [1:0]rxosintdone_out;
  output [1:0]rxosintstarted_out;
  output [1:0]rxosintstrobedone_out;
  output [1:0]rxosintstrobestarted_out;
  output [1:0]rxoutclk_out;
  output [1:0]rxoutclkfabric_out;
  output [1:0]rxoutclkpcs_out;
  output [1:0]rxphaligndone_out;
  output [1:0]rxphalignerr_out;
  output [1:0]rxpmaresetdone_out;
  output [1:0]rxprbserr_out;
  output [1:0]rxprbslocked_out;
  output [1:0]rxprgdivresetdone_out;
  output [1:0]rxqpisenn_out;
  output [1:0]rxqpisenp_out;
  output [1:0]rxratedone_out;
  output [1:0]rxrecclkout_out;
  output [1:0]rxresetdone_out;
  output [1:0]rxsliderdy_out;
  output [1:0]rxslipdone_out;
  output [1:0]rxslipoutclkrdy_out;
  output [1:0]rxslippmardy_out;
  output [3:0]rxstartofseq_out;
  output [5:0]rxstatus_out;
  output [1:0]rxsyncdone_out;
  output [1:0]rxsyncout_out;
  output [1:0]rxvalid_out;
  output [3:0]txbufstatus_out;
  output [1:0]txcomfinish_out;
  output [0:0]txdccdone_out;
  output [1:0]txdlysresetdone_out;
  output [1:0]txoutclk_out;
  output [1:0]txoutclkfabric_out;
  output [1:0]txoutclkpcs_out;
  output [1:0]txphaligndone_out;
  output [1:0]txphinitdone_out;
  output [1:0]txpmaresetdone_out;
  output [1:0]txprgdivresetdone_out;
  output [1:0]txqpisenn_out;
  output [1:0]txqpisenp_out;
  output [1:0]txratedone_out;
  output [1:0]txresetdone_out;
  output [1:0]txsyncdone_out;
  output [1:0]txsyncout_out;

  wire \<const0> ;
  wire [0:0]bgbypassb_in;
  wire [0:0]bgmonitorenb_in;
  wire [0:0]bgpdb_in;
  wire [4:0]bgrcalovrd_in;
  wire [0:0]bgrcalovrdenb_in;
  wire [5:0]bufgtce_out;
  wire [5:0]bufgtcemask_out;
  wire [17:0]bufgtdiv_out;
  wire [5:0]bufgtreset_out;
  wire [5:0]bufgtrstmask_out;
  wire [1:0]cfgreset_in;
  wire [1:0]clkrsvd0_in;
  wire [1:0]clkrsvd1_in;
  wire [1:0]cpllfbclklost_out;
  wire [1:0]cplllock_out;
  wire [1:0]cplllockdetclk_in;
  wire [1:0]cplllocken_in;
  wire [1:0]cpllpd_in;
  wire [1:0]cpllrefclklost_out;
  wire [5:0]cpllrefclksel_in;
  wire [1:0]cpllreset_in;
  wire [1:0]dmonfiforeset_in;
  wire [1:0]dmonitorclk_in;
  wire [33:0]dmonitorout_out;
  wire [8:0]drpaddr_common_in;
  wire [17:0]drpaddr_in;
  wire [0:0]drpclk_common_in;
  wire [1:0]drpclk_in;
  wire [15:0]drpdi_common_in;
  wire [31:0]drpdi_in;
  wire [15:0]drpdo_common_out;
  wire [31:0]drpdo_out;
  wire [0:0]drpen_common_in;
  wire [1:0]drpen_in;
  wire [0:0]drprdy_common_out;
  wire [1:0]drprdy_out;
  wire [0:0]drpwe_common_in;
  wire [1:0]drpwe_in;
  wire [1:0]evoddphicaldone_in;
  wire [1:0]evoddphicalstart_in;
  wire [1:0]evoddphidrden_in;
  wire [1:0]evoddphidwren_in;
  wire [1:0]evoddphixrden_in;
  wire [1:0]evoddphixwren_in;
  wire [1:0]eyescandataerror_out;
  wire [1:0]eyescanmode_in;
  wire [1:0]eyescanreset_in;
  wire [1:0]eyescantrigger_in;
  wire [0:0]gtgrefclk0_in;
  wire [0:0]gtgrefclk1_in;
  wire [1:0]gtgrefclk_in;
  wire [1:0]gthrxn_in;
  wire [1:0]gthrxp_in;
  wire [1:0]gthtxn_out;
  wire [1:0]gthtxp_out;
  wire [0:0]gtnorthrefclk00_in;
  wire [0:0]gtnorthrefclk01_in;
  wire [1:0]gtnorthrefclk0_in;
  wire [0:0]gtnorthrefclk10_in;
  wire [0:0]gtnorthrefclk11_in;
  wire [1:0]gtnorthrefclk1_in;
  wire [1:0]gtpowergood_out;
  wire [0:0]gtrefclk00_in;
  wire [0:0]gtrefclk01_in;
  wire [1:0]gtrefclk0_in;
  wire [0:0]gtrefclk10_in;
  wire [0:0]gtrefclk11_in;
  wire [1:0]gtrefclk1_in;
  wire [1:0]gtrefclkmonitor_out;
  wire [1:0]gtresetsel_in;
  wire [31:0]gtrsvd_in;
  wire [1:0]gtrxreset_in;
  wire [0:0]gtsouthrefclk00_in;
  wire [0:0]gtsouthrefclk01_in;
  wire [1:0]gtsouthrefclk0_in;
  wire [0:0]gtsouthrefclk10_in;
  wire [0:0]gtsouthrefclk11_in;
  wire [1:0]gtsouthrefclk1_in;
  wire [1:0]gttxreset_in;
  wire [0:0]gtwiz_buffbypass_rx_reset_in;
  wire [0:0]gtwiz_buffbypass_rx_start_user_in;
  wire [0:0]gtwiz_buffbypass_tx_reset_in;
  wire [0:0]gtwiz_buffbypass_tx_start_user_in;
  wire [1:0]gtwiz_gthe3_cpll_cal_bufg_ce_in;
  wire [35:0]gtwiz_gthe3_cpll_cal_cnt_tol_in;
  wire [35:0]gtwiz_gthe3_cpll_cal_txoutclk_period_in;
  wire [0:0]gtwiz_reset_all_in;
  wire [0:0]gtwiz_reset_clk_freerun_in;
  wire [0:0]gtwiz_reset_qpll0lock_in;
  wire [0:0]gtwiz_reset_qpll0reset_out;
  wire [0:0]gtwiz_reset_qpll1lock_in;
  wire [0:0]gtwiz_reset_rx_cdr_stable_out;
  wire [0:0]gtwiz_reset_rx_datapath_in;
  wire [0:0]gtwiz_reset_rx_done_in;
  wire [0:0]gtwiz_reset_rx_done_out;
  wire [0:0]gtwiz_reset_rx_pll_and_datapath_in;
  wire [0:0]gtwiz_reset_tx_datapath_in;
  wire [0:0]gtwiz_reset_tx_done_in;
  wire [0:0]gtwiz_reset_tx_done_out;
  wire [0:0]gtwiz_reset_tx_pll_and_datapath_in;
  wire [0:0]gtwiz_userclk_rx_active_in;
  wire [0:0]gtwiz_userclk_rx_reset_in;
  wire [0:0]gtwiz_userclk_tx_active_in;
  wire [0:0]gtwiz_userclk_tx_reset_in;
  wire [63:0]gtwiz_userdata_tx_in;
  wire [5:0]loopback_in;
  wire [1:0]lpbkrxtxseren_in;
  wire [1:0]lpbktxrxseren_in;
  wire [1:0]pcieeqrxeqadaptdone_in;
  wire [1:0]pcierategen3_out;
  wire [1:0]pcierateidle_out;
  wire [3:0]pcierateqpllpd_out;
  wire [3:0]pcierateqpllreset_out;
  wire [1:0]pcierstidle_in;
  wire [1:0]pciersttxsyncstart_in;
  wire [1:0]pciesynctxsyncdone_out;
  wire [1:0]pcieusergen3rdy_out;
  wire [1:0]pcieuserphystatusrst_out;
  wire [1:0]pcieuserratedone_in;
  wire [1:0]pcieuserratestart_out;
  wire [9:0]pcsrsvdin2_in;
  wire [31:0]pcsrsvdin_in;
  wire [23:0]pcsrsvdout_out;
  wire [1:0]phystatus_out;
  wire [15:0]pinrsrvdas_out;
  wire [7:0]pmarsvd0_in;
  wire [7:0]pmarsvd1_in;
  wire [9:0]pmarsvdin_in;
  wire [7:0]pmarsvdout0_out;
  wire [7:0]pmarsvdout1_out;
  wire [1:0]qpll0clk_in;
  wire [0:0]qpll0clkrsvd0_in;
  wire [0:0]qpll0clkrsvd1_in;
  wire [0:0]qpll0fbclklost_out;
  wire [0:0]qpll0lock_out;
  wire [0:0]qpll0lockdetclk_in;
  wire [0:0]qpll0locken_in;
  wire [0:0]qpll0outclk_out;
  wire [0:0]qpll0outrefclk_out;
  wire [0:0]qpll0pd_in;
  wire [1:0]qpll0refclk_in;
  wire [0:0]qpll0refclklost_out;
  wire [2:0]qpll0refclksel_in;
  wire [0:0]qpll0reset_in;
  wire [1:0]qpll1clk_in;
  wire [0:0]qpll1clkrsvd0_in;
  wire [0:0]qpll1clkrsvd1_in;
  wire [0:0]qpll1fbclklost_out;
  wire [0:0]qpll1lock_out;
  wire [0:0]qpll1lockdetclk_in;
  wire [0:0]qpll1locken_in;
  wire [0:0]qpll1outclk_out;
  wire [0:0]qpll1outrefclk_out;
  wire [0:0]qpll1pd_in;
  wire [1:0]qpll1refclk_in;
  wire [0:0]qpll1refclklost_out;
  wire [2:0]qpll1refclksel_in;
  wire [0:0]qpll1reset_in;
  wire [7:0]qplldmonitor0_out;
  wire [7:0]qplldmonitor1_out;
  wire [7:0]qpllrsvd1_in;
  wire [4:0]qpllrsvd2_in;
  wire [4:0]qpllrsvd3_in;
  wire [7:0]qpllrsvd4_in;
  wire [0:0]rcalenb_in;
  wire [0:0]refclkoutmonitor0_out;
  wire [0:0]refclkoutmonitor1_out;
  wire [1:0]resetexception_out;
  wire [1:0]resetovrd_in;
  wire [1:0]rstclkentx_in;
  wire [1:0]rx8b10ben_in;
  wire [1:0]rxbufreset_in;
  wire [5:0]rxbufstatus_out;
  wire [1:0]rxbyteisaligned_out;
  wire [1:0]rxbyterealign_out;
  wire [1:0]rxcdrfreqreset_in;
  wire [1:0]rxcdrhold_in;
  wire [1:0]rxcdrlock_out;
  wire [1:0]rxcdrovrden_in;
  wire [1:0]rxcdrphdone_out;
  wire [1:0]rxcdrreset_in;
  wire [1:0]rxcdrresetrsv_in;
  wire [1:0]rxchanbondseq_out;
  wire [1:0]rxchanisaligned_out;
  wire [1:0]rxchanrealign_out;
  wire [1:0]rxchbonden_in;
  wire [9:0]rxchbondi_in;
  wire [5:0]rxchbondlevel_in;
  wire [1:0]rxchbondmaster_in;
  wire [9:0]rxchbondo_out;
  wire [1:0]rxchbondslave_in;
  wire [3:0]rxclkcorcnt_out;
  wire [1:0]rxcominitdet_out;
  wire [1:0]rxcommadet_out;
  wire [1:0]rxcommadeten_in;
  wire [1:0]rxcomsasdet_out;
  wire [1:0]rxcomwakedet_out;
  wire [31:0]rxctrl0_out;
  wire [31:0]rxctrl1_out;
  wire [15:0]rxctrl2_out;
  wire [15:0]rxctrl3_out;
  wire [255:0]rxdata_out;
  wire [15:0]rxdataextendrsvd_out;
  wire [3:0]rxdatavalid_out;
  wire [3:0]rxdfeagcctrl_in;
  wire [1:0]rxdfeagchold_in;
  wire [1:0]rxdfeagcovrden_in;
  wire [1:0]rxdfelfhold_in;
  wire [1:0]rxdfelfovrden_in;
  wire [1:0]rxdfelpmreset_in;
  wire [1:0]rxdfetap10hold_in;
  wire [1:0]rxdfetap10ovrden_in;
  wire [1:0]rxdfetap11hold_in;
  wire [1:0]rxdfetap11ovrden_in;
  wire [1:0]rxdfetap12hold_in;
  wire [1:0]rxdfetap12ovrden_in;
  wire [1:0]rxdfetap13hold_in;
  wire [1:0]rxdfetap13ovrden_in;
  wire [1:0]rxdfetap14hold_in;
  wire [1:0]rxdfetap14ovrden_in;
  wire [1:0]rxdfetap15hold_in;
  wire [1:0]rxdfetap15ovrden_in;
  wire [1:0]rxdfetap2hold_in;
  wire [1:0]rxdfetap2ovrden_in;
  wire [1:0]rxdfetap3hold_in;
  wire [1:0]rxdfetap3ovrden_in;
  wire [1:0]rxdfetap4hold_in;
  wire [1:0]rxdfetap4ovrden_in;
  wire [1:0]rxdfetap5hold_in;
  wire [1:0]rxdfetap5ovrden_in;
  wire [1:0]rxdfetap6hold_in;
  wire [1:0]rxdfetap6ovrden_in;
  wire [1:0]rxdfetap7hold_in;
  wire [1:0]rxdfetap7ovrden_in;
  wire [1:0]rxdfetap8hold_in;
  wire [1:0]rxdfetap8ovrden_in;
  wire [1:0]rxdfetap9hold_in;
  wire [1:0]rxdfetap9ovrden_in;
  wire [1:0]rxdfeuthold_in;
  wire [1:0]rxdfeutovrden_in;
  wire [1:0]rxdfevphold_in;
  wire [1:0]rxdfevpovrden_in;
  wire [1:0]rxdfevsen_in;
  wire [1:0]rxdfexyden_in;
  wire [1:0]rxdlybypass_in;
  wire [1:0]rxdlyen_in;
  wire [1:0]rxdlyovrden_in;
  wire [1:0]rxdlysreset_in;
  wire [1:0]rxdlysresetdone_out;
  wire [1:0]rxelecidle_out;
  wire [3:0]rxelecidlemode_in;
  wire [1:0]rxgearboxslip_in;
  wire [11:0]rxheader_out;
  wire [3:0]rxheadervalid_out;
  wire [1:0]rxlatclk_in;
  wire [1:0]rxlpmen_in;
  wire [1:0]rxlpmgchold_in;
  wire [1:0]rxlpmgcovrden_in;
  wire [1:0]rxlpmhfhold_in;
  wire [1:0]rxlpmhfovrden_in;
  wire [1:0]rxlpmlfhold_in;
  wire [1:0]rxlpmlfklovrden_in;
  wire [1:0]rxlpmoshold_in;
  wire [1:0]rxlpmosovrden_in;
  wire [1:0]rxmcommaalignen_in;
  wire [13:0]rxmonitorout_out;
  wire [3:0]rxmonitorsel_in;
  wire [1:0]rxoobreset_in;
  wire [1:0]rxoscalreset_in;
  wire [1:0]rxoshold_in;
  wire [7:0]rxosintcfg_in;
  wire [1:0]rxosintdone_out;
  wire [1:0]rxosinten_in;
  wire [1:0]rxosinthold_in;
  wire [1:0]rxosintovrden_in;
  wire [1:0]rxosintstarted_out;
  wire [1:0]rxosintstrobe_in;
  wire [1:0]rxosintstrobedone_out;
  wire [1:0]rxosintstrobestarted_out;
  wire [1:0]rxosinttestovrden_in;
  wire [1:0]rxosovrden_in;
  wire [1:0]rxoutclk_out;
  wire [1:0]rxoutclkfabric_out;
  wire [1:0]rxoutclkpcs_out;
  wire [5:0]rxoutclksel_in;
  wire [1:0]rxpcommaalignen_in;
  wire [1:0]rxpcsreset_in;
  wire [3:0]rxpd_in;
  wire [1:0]rxphalign_in;
  wire [1:0]rxphaligndone_out;
  wire [1:0]rxphalignen_in;
  wire [1:0]rxphalignerr_out;
  wire [1:0]rxphdlypd_in;
  wire [1:0]rxphdlyreset_in;
  wire [1:0]rxphovrden_in;
  wire [3:0]rxpllclksel_in;
  wire [1:0]rxpmareset_in;
  wire [1:0]rxpmaresetdone_out;
  wire [1:0]rxpolarity_in;
  wire [1:0]rxprbscntreset_in;
  wire [1:0]rxprbserr_out;
  wire [1:0]rxprbslocked_out;
  wire [7:0]rxprbssel_in;
  wire [1:0]rxprgdivresetdone_out;
  wire [1:0]rxprogdivreset_in;
  wire [1:0]rxqpien_in;
  wire [1:0]rxqpisenn_out;
  wire [1:0]rxqpisenp_out;
  wire [5:0]rxrate_in;
  wire [1:0]rxratedone_out;
  wire [1:0]rxratemode_in;
  wire [1:0]rxrecclk0_sel_out;
  wire [1:0]rxrecclk1_sel_out;
  wire [1:0]rxrecclkout_out;
  wire [1:0]rxresetdone_out;
  wire [1:0]rxslide_in;
  wire [1:0]rxsliderdy_out;
  wire [1:0]rxslipdone_out;
  wire [1:0]rxslipoutclk_in;
  wire [1:0]rxslipoutclkrdy_out;
  wire [1:0]rxslippma_in;
  wire [1:0]rxslippmardy_out;
  wire [3:0]rxstartofseq_out;
  wire [5:0]rxstatus_out;
  wire [1:0]rxsyncallin_in;
  wire [1:0]rxsyncdone_out;
  wire [1:0]rxsyncin_in;
  wire [1:0]rxsyncmode_in;
  wire [1:0]rxsyncout_out;
  wire [3:0]rxsysclksel_in;
  wire [1:0]rxuserrdy_in;
  wire [1:0]rxusrclk2_in;
  wire [1:0]rxusrclk_in;
  wire [1:0]rxvalid_out;
  wire [1:0]sigvalidclk_in;
  wire [39:0]tstin_in;
  wire [15:0]tx8b10bbypass_in;
  wire [1:0]tx8b10ben_in;
  wire [5:0]txbufdiffctrl_in;
  wire [3:0]txbufstatus_out;
  wire [1:0]txcomfinish_out;
  wire [1:0]txcominit_in;
  wire [1:0]txcomsas_in;
  wire [1:0]txcomwake_in;
  wire [31:0]txctrl0_in;
  wire [31:0]txctrl1_in;
  wire [15:0]txctrl2_in;
  wire [255:0]txdata_in;
  wire [15:0]txdataextendrsvd_in;
  wire [1:0]txdeemph_in;
  wire [1:0]txdetectrx_in;
  wire [7:0]txdiffctrl_in;
  wire [1:0]txdiffpd_in;
  wire [1:0]txdlybypass_in;
  wire [1:0]txdlyen_in;
  wire [1:0]txdlyhold_in;
  wire [1:0]txdlyovrden_in;
  wire [1:0]txdlysreset_in;
  wire [1:0]txdlysresetdone_out;
  wire [1:0]txdlyupdown_in;
  wire [1:0]txelecidle_in;
  wire [11:0]txheader_in;
  wire [1:0]txinhibit_in;
  wire [1:0]txlatclk_in;
  wire [13:0]txmaincursor_in;
  wire [5:0]txmargin_in;
  wire [1:0]txoutclk_out;
  wire [1:0]txoutclkfabric_out;
  wire [1:0]txoutclkpcs_out;
  wire [5:0]txoutclksel_in;
  wire [1:0]txpcsreset_in;
  wire [3:0]txpd_in;
  wire [1:0]txpdelecidlemode_in;
  wire [1:0]txphalign_in;
  wire [1:0]txphaligndone_out;
  wire [1:0]txphalignen_in;
  wire [1:0]txphdlypd_in;
  wire [1:0]txphdlyreset_in;
  wire [1:0]txphdlytstclk_in;
  wire [1:0]txphinit_in;
  wire [1:0]txphinitdone_out;
  wire [1:0]txphovrden_in;
  wire [1:0]txpippmen_in;
  wire [1:0]txpippmovrden_in;
  wire [1:0]txpippmpd_in;
  wire [1:0]txpippmsel_in;
  wire [9:0]txpippmstepsize_in;
  wire [1:0]txpisopd_in;
  wire [3:0]txpllclksel_in;
  wire [1:0]txpmareset_in;
  wire [1:0]txpmaresetdone_out;
  wire [1:0]txpolarity_in;
  wire [9:0]txpostcursor_in;
  wire [1:0]txpostcursorinv_in;
  wire [1:0]txprbsforceerr_in;
  wire [7:0]txprbssel_in;
  wire [9:0]txprecursor_in;
  wire [1:0]txprecursorinv_in;
  wire [1:0]txprgdivresetdone_out;
  wire [1:0]txprogdivreset_in;
  wire [1:0]txqpibiasen_in;
  wire [1:0]txqpisenn_out;
  wire [1:0]txqpisenp_out;
  wire [1:0]txqpistrongpdown_in;
  wire [1:0]txqpiweakpup_in;
  wire [5:0]txrate_in;
  wire [1:0]txratedone_out;
  wire [1:0]txratemode_in;
  wire [1:0]txresetdone_out;
  wire [13:0]txsequence_in;
  wire [1:0]txswing_in;
  wire [1:0]txsyncallin_in;
  wire [1:0]txsyncdone_out;
  wire [1:0]txsyncin_in;
  wire [1:0]txsyncmode_in;
  wire [1:0]txsyncout_out;
  wire [3:0]txsysclksel_in;
  wire [1:0]txuserrdy_in;
  wire [1:0]txusrclk2_in;
  wire [1:0]txusrclk_in;

  assign gtwiz_buffbypass_rx_done_out[0] = \<const0> ;
  assign gtwiz_buffbypass_rx_error_out[0] = \<const0> ;
  assign gtwiz_buffbypass_tx_done_out[0] = \<const0> ;
  assign gtwiz_buffbypass_tx_error_out[0] = \<const0> ;
  assign gtwiz_reset_qpll1reset_out[0] = qpll1reset_in;
  assign gtwiz_userclk_rx_active_out[0] = gtwiz_userclk_rx_active_in;
  assign gtwiz_userclk_rx_srcclk_out[0] = \<const0> ;
  assign gtwiz_userclk_rx_usrclk2_out[0] = \<const0> ;
  assign gtwiz_userclk_rx_usrclk_out[0] = \<const0> ;
  assign gtwiz_userclk_tx_active_out[0] = gtwiz_userclk_tx_active_in;
  assign gtwiz_userclk_tx_srcclk_out[0] = \<const0> ;
  assign gtwiz_userclk_tx_usrclk2_out[0] = \<const0> ;
  assign gtwiz_userclk_tx_usrclk_out[0] = \<const0> ;
  assign gtwiz_userdata_rx_out[63:32] = rxdata_out[159:128];
  assign gtwiz_userdata_rx_out[31:0] = rxdata_out[31:0];
  assign gtytxn_out[0] = \<const0> ;
  assign gtytxp_out[0] = \<const0> ;
  assign rxckcaldone_out[0] = \<const0> ;
  assign sdm0finalout_out[0] = \<const0> ;
  assign sdm0testdata_out[0] = \<const0> ;
  assign sdm1finalout_out[0] = \<const0> ;
  assign sdm1testdata_out[0] = \<const0> ;
  assign txdccdone_out[0] = \<const0> ;
GND GND
       (.G(\<const0> ));
GthUltrascaleJesdCoregen_GthUltrascaleJesdCoregen_gtwizard_gthe3 \gen_gtwizard_gthe3_top.GthUltrascaleJesdCoregen_gtwizard_gthe3_inst 
       (.bufgtce_out(bufgtce_out),
        .bufgtcemask_out(bufgtcemask_out),
        .bufgtdiv_out(bufgtdiv_out),
        .bufgtreset_out(bufgtreset_out),
        .bufgtrstmask_out(bufgtrstmask_out),
        .cfgreset_in(cfgreset_in),
        .clkrsvd0_in(clkrsvd0_in),
        .clkrsvd1_in(clkrsvd1_in),
        .cpllfbclklost_out(cpllfbclklost_out),
        .cplllock_out(cplllock_out),
        .cplllockdetclk_in(cplllockdetclk_in),
        .cplllocken_in(cplllocken_in),
        .cpllpd_in(cpllpd_in),
        .cpllrefclklost_out(cpllrefclklost_out),
        .cpllrefclksel_in(cpllrefclksel_in),
        .cpllreset_in(cpllreset_in),
        .dmonfiforeset_in(dmonfiforeset_in),
        .dmonitorclk_in(dmonitorclk_in),
        .dmonitorout_out(dmonitorout_out),
        .drpaddr_common_in(drpaddr_common_in),
        .drpaddr_in(drpaddr_in),
        .drpclk_common_in(drpclk_common_in),
        .drpclk_in(drpclk_in),
        .drpdi_common_in(drpdi_common_in),
        .drpdi_in(drpdi_in),
        .drpdo_common_out(drpdo_common_out),
        .drpdo_out(drpdo_out),
        .drpen_common_in(drpen_common_in),
        .drpen_in(drpen_in),
        .drprdy_common_out(drprdy_common_out),
        .drprdy_out(drprdy_out),
        .drpwe_common_in(drpwe_common_in),
        .drpwe_in(drpwe_in),
        .evoddphicaldone_in(evoddphicaldone_in),
        .evoddphicalstart_in(evoddphicalstart_in),
        .evoddphidrden_in(evoddphidrden_in),
        .evoddphidwren_in(evoddphidwren_in),
        .evoddphixrden_in(evoddphixrden_in),
        .evoddphixwren_in(evoddphixwren_in),
        .eyescandataerror_out(eyescandataerror_out),
        .eyescanmode_in(eyescanmode_in),
        .eyescanreset_in(eyescanreset_in),
        .eyescantrigger_in(eyescantrigger_in),
        .gtgrefclk0_in(gtgrefclk0_in),
        .gtgrefclk1_in(gtgrefclk1_in),
        .gtgrefclk_in(gtgrefclk_in),
        .gthrxn_in(gthrxn_in),
        .gthrxp_in(gthrxp_in),
        .gthtxn_out(gthtxn_out),
        .gthtxp_out(gthtxp_out),
        .gtnorthrefclk00_in(gtnorthrefclk00_in),
        .gtnorthrefclk01_in(gtnorthrefclk01_in),
        .gtnorthrefclk0_in(gtnorthrefclk0_in),
        .gtnorthrefclk10_in(gtnorthrefclk10_in),
        .gtnorthrefclk11_in(gtnorthrefclk11_in),
        .gtnorthrefclk1_in(gtnorthrefclk1_in),
        .gtpowergood_out(gtpowergood_out),
        .gtrefclk00_in(gtrefclk00_in),
        .gtrefclk01_in(gtrefclk01_in),
        .gtrefclk0_in(gtrefclk0_in),
        .gtrefclk10_in(gtrefclk10_in),
        .gtrefclk11_in(gtrefclk11_in),
        .gtrefclk1_in(gtrefclk1_in),
        .gtrefclkmonitor_out(gtrefclkmonitor_out),
        .gtresetsel_in(gtresetsel_in),
        .gtrsvd_in(gtrsvd_in),
        .gtsouthrefclk00_in(gtsouthrefclk00_in),
        .gtsouthrefclk01_in(gtsouthrefclk01_in),
        .gtsouthrefclk0_in(gtsouthrefclk0_in),
        .gtsouthrefclk10_in(gtsouthrefclk10_in),
        .gtsouthrefclk11_in(gtsouthrefclk11_in),
        .gtsouthrefclk1_in(gtsouthrefclk1_in),
        .gtwiz_reset_all_in(gtwiz_reset_all_in),
        .gtwiz_reset_clk_freerun_in(gtwiz_reset_clk_freerun_in),
        .gtwiz_reset_qpll0reset_out(gtwiz_reset_qpll0reset_out),
        .gtwiz_reset_rx_cdr_stable_out(gtwiz_reset_rx_cdr_stable_out),
        .gtwiz_reset_rx_datapath_in(gtwiz_reset_rx_datapath_in),
        .gtwiz_reset_rx_done_out(gtwiz_reset_rx_done_out),
        .gtwiz_reset_rx_pll_and_datapath_in(gtwiz_reset_rx_pll_and_datapath_in),
        .gtwiz_reset_tx_datapath_in(gtwiz_reset_tx_datapath_in),
        .gtwiz_reset_tx_done_out(gtwiz_reset_tx_done_out),
        .gtwiz_reset_tx_pll_and_datapath_in(gtwiz_reset_tx_pll_and_datapath_in),
        .gtwiz_userclk_rx_active_in(gtwiz_userclk_rx_active_in),
        .gtwiz_userclk_tx_active_in(gtwiz_userclk_tx_active_in),
        .gtwiz_userdata_tx_in(gtwiz_userdata_tx_in),
        .loopback_in(loopback_in),
        .lpbkrxtxseren_in(lpbkrxtxseren_in),
        .lpbktxrxseren_in(lpbktxrxseren_in),
        .pcieeqrxeqadaptdone_in(pcieeqrxeqadaptdone_in),
        .pcierategen3_out(pcierategen3_out),
        .pcierateidle_out(pcierateidle_out),
        .pcierateqpllpd_out(pcierateqpllpd_out),
        .pcierateqpllreset_out(pcierateqpllreset_out),
        .pcierstidle_in(pcierstidle_in),
        .pciersttxsyncstart_in(pciersttxsyncstart_in),
        .pciesynctxsyncdone_out(pciesynctxsyncdone_out),
        .pcieusergen3rdy_out(pcieusergen3rdy_out),
        .pcieuserphystatusrst_out(pcieuserphystatusrst_out),
        .pcieuserratedone_in(pcieuserratedone_in),
        .pcieuserratestart_out(pcieuserratestart_out),
        .pcsrsvdin2_in(pcsrsvdin2_in),
        .pcsrsvdin_in(pcsrsvdin_in),
        .pcsrsvdout_out(pcsrsvdout_out),
        .phystatus_out(phystatus_out),
        .pinrsrvdas_out(pinrsrvdas_out),
        .pmarsvdin_in(pmarsvdin_in),
        .pmarsvdout0_out(pmarsvdout0_out),
        .pmarsvdout1_out(pmarsvdout1_out),
        .qpll0clkrsvd0_in(qpll0clkrsvd0_in),
        .qpll0clkrsvd1_in(qpll0clkrsvd1_in),
        .qpll0fbclklost_out(qpll0fbclklost_out),
        .qpll0lock_out(qpll0lock_out),
        .qpll0lockdetclk_in(qpll0lockdetclk_in),
        .qpll0locken_in(qpll0locken_in),
        .qpll0outclk_out(qpll0outclk_out),
        .qpll0outrefclk_out(qpll0outrefclk_out),
        .qpll0pd_in(qpll0pd_in),
        .qpll0refclklost_out(qpll0refclklost_out),
        .qpll0refclksel_in(qpll0refclksel_in),
        .qpll1clkrsvd0_in(qpll1clkrsvd0_in),
        .qpll1clkrsvd1_in(qpll1clkrsvd1_in),
        .qpll1fbclklost_out(qpll1fbclklost_out),
        .qpll1lock_out(qpll1lock_out),
        .qpll1lockdetclk_in(qpll1lockdetclk_in),
        .qpll1locken_in(qpll1locken_in),
        .qpll1outclk_out(qpll1outclk_out),
        .qpll1outrefclk_out(qpll1outrefclk_out),
        .qpll1pd_in(qpll1pd_in),
        .qpll1refclklost_out(qpll1refclklost_out),
        .qpll1refclksel_in(qpll1refclksel_in),
        .qpll1reset_in(qpll1reset_in),
        .qplldmonitor0_out(qplldmonitor0_out),
        .qplldmonitor1_out(qplldmonitor1_out),
        .qpllrsvd1_in(qpllrsvd1_in),
        .qpllrsvd2_in(qpllrsvd2_in),
        .qpllrsvd3_in(qpllrsvd3_in),
        .qpllrsvd4_in(qpllrsvd4_in),
        .refclkoutmonitor0_out(refclkoutmonitor0_out),
        .refclkoutmonitor1_out(refclkoutmonitor1_out),
        .resetexception_out(resetexception_out),
        .resetovrd_in(resetovrd_in),
        .rstclkentx_in(rstclkentx_in),
        .rx8b10ben_in(rx8b10ben_in),
        .rxbufreset_in(rxbufreset_in),
        .rxbufstatus_out(rxbufstatus_out),
        .rxbyteisaligned_out(rxbyteisaligned_out),
        .rxbyterealign_out(rxbyterealign_out),
        .rxcdrfreqreset_in(rxcdrfreqreset_in),
        .rxcdrhold_in(rxcdrhold_in),
        .rxcdrlock_out(rxcdrlock_out),
        .rxcdrovrden_in(rxcdrovrden_in),
        .rxcdrphdone_out(rxcdrphdone_out),
        .rxcdrreset_in(rxcdrreset_in),
        .rxcdrresetrsv_in(rxcdrresetrsv_in),
        .rxchanbondseq_out(rxchanbondseq_out),
        .rxchanisaligned_out(rxchanisaligned_out),
        .rxchanrealign_out(rxchanrealign_out),
        .rxchbonden_in(rxchbonden_in),
        .rxchbondi_in(rxchbondi_in),
        .rxchbondlevel_in(rxchbondlevel_in),
        .rxchbondmaster_in(rxchbondmaster_in),
        .rxchbondo_out(rxchbondo_out),
        .rxchbondslave_in(rxchbondslave_in),
        .rxclkcorcnt_out(rxclkcorcnt_out),
        .rxcominitdet_out(rxcominitdet_out),
        .rxcommadet_out(rxcommadet_out),
        .rxcommadeten_in(rxcommadeten_in),
        .rxcomsasdet_out(rxcomsasdet_out),
        .rxcomwakedet_out(rxcomwakedet_out),
        .rxctrl0_out(rxctrl0_out),
        .rxctrl1_out(rxctrl1_out),
        .rxctrl2_out(rxctrl2_out),
        .rxctrl3_out(rxctrl3_out),
        .rxdata_out(rxdata_out),
        .rxdataextendrsvd_out(rxdataextendrsvd_out),
        .rxdatavalid_out(rxdatavalid_out),
        .rxdfeagcctrl_in(rxdfeagcctrl_in),
        .rxdfeagchold_in(rxdfeagchold_in),
        .rxdfeagcovrden_in(rxdfeagcovrden_in),
        .rxdfelfhold_in(rxdfelfhold_in),
        .rxdfelfovrden_in(rxdfelfovrden_in),
        .rxdfelpmreset_in(rxdfelpmreset_in),
        .rxdfetap10hold_in(rxdfetap10hold_in),
        .rxdfetap10ovrden_in(rxdfetap10ovrden_in),
        .rxdfetap11hold_in(rxdfetap11hold_in),
        .rxdfetap11ovrden_in(rxdfetap11ovrden_in),
        .rxdfetap12hold_in(rxdfetap12hold_in),
        .rxdfetap12ovrden_in(rxdfetap12ovrden_in),
        .rxdfetap13hold_in(rxdfetap13hold_in),
        .rxdfetap13ovrden_in(rxdfetap13ovrden_in),
        .rxdfetap14hold_in(rxdfetap14hold_in),
        .rxdfetap14ovrden_in(rxdfetap14ovrden_in),
        .rxdfetap15hold_in(rxdfetap15hold_in),
        .rxdfetap15ovrden_in(rxdfetap15ovrden_in),
        .rxdfetap2hold_in(rxdfetap2hold_in),
        .rxdfetap2ovrden_in(rxdfetap2ovrden_in),
        .rxdfetap3hold_in(rxdfetap3hold_in),
        .rxdfetap3ovrden_in(rxdfetap3ovrden_in),
        .rxdfetap4hold_in(rxdfetap4hold_in),
        .rxdfetap4ovrden_in(rxdfetap4ovrden_in),
        .rxdfetap5hold_in(rxdfetap5hold_in),
        .rxdfetap5ovrden_in(rxdfetap5ovrden_in),
        .rxdfetap6hold_in(rxdfetap6hold_in),
        .rxdfetap6ovrden_in(rxdfetap6ovrden_in),
        .rxdfetap7hold_in(rxdfetap7hold_in),
        .rxdfetap7ovrden_in(rxdfetap7ovrden_in),
        .rxdfetap8hold_in(rxdfetap8hold_in),
        .rxdfetap8ovrden_in(rxdfetap8ovrden_in),
        .rxdfetap9hold_in(rxdfetap9hold_in),
        .rxdfetap9ovrden_in(rxdfetap9ovrden_in),
        .rxdfeuthold_in(rxdfeuthold_in),
        .rxdfeutovrden_in(rxdfeutovrden_in),
        .rxdfevphold_in(rxdfevphold_in),
        .rxdfevpovrden_in(rxdfevpovrden_in),
        .rxdfevsen_in(rxdfevsen_in),
        .rxdfexyden_in(rxdfexyden_in),
        .rxdlybypass_in(rxdlybypass_in),
        .rxdlyen_in(rxdlyen_in),
        .rxdlyovrden_in(rxdlyovrden_in),
        .rxdlysreset_in(rxdlysreset_in),
        .rxdlysresetdone_out(rxdlysresetdone_out),
        .rxelecidle_out(rxelecidle_out),
        .rxelecidlemode_in(rxelecidlemode_in),
        .rxgearboxslip_in(rxgearboxslip_in),
        .rxheader_out(rxheader_out),
        .rxheadervalid_out(rxheadervalid_out),
        .rxlatclk_in(rxlatclk_in),
        .rxlpmen_in(rxlpmen_in),
        .rxlpmgchold_in(rxlpmgchold_in),
        .rxlpmgcovrden_in(rxlpmgcovrden_in),
        .rxlpmhfhold_in(rxlpmhfhold_in),
        .rxlpmhfovrden_in(rxlpmhfovrden_in),
        .rxlpmlfhold_in(rxlpmlfhold_in),
        .rxlpmlfklovrden_in(rxlpmlfklovrden_in),
        .rxlpmoshold_in(rxlpmoshold_in),
        .rxlpmosovrden_in(rxlpmosovrden_in),
        .rxmcommaalignen_in(rxmcommaalignen_in),
        .rxmonitorout_out(rxmonitorout_out),
        .rxmonitorsel_in(rxmonitorsel_in),
        .rxoobreset_in(rxoobreset_in),
        .rxoscalreset_in(rxoscalreset_in),
        .rxoshold_in(rxoshold_in),
        .rxosintcfg_in(rxosintcfg_in),
        .rxosintdone_out(rxosintdone_out),
        .rxosinten_in(rxosinten_in),
        .rxosinthold_in(rxosinthold_in),
        .rxosintovrden_in(rxosintovrden_in),
        .rxosintstarted_out(rxosintstarted_out),
        .rxosintstrobe_in(rxosintstrobe_in),
        .rxosintstrobedone_out(rxosintstrobedone_out),
        .rxosintstrobestarted_out(rxosintstrobestarted_out),
        .rxosinttestovrden_in(rxosinttestovrden_in),
        .rxosovrden_in(rxosovrden_in),
        .rxoutclk_out(rxoutclk_out),
        .rxoutclkfabric_out(rxoutclkfabric_out),
        .rxoutclkpcs_out(rxoutclkpcs_out),
        .rxoutclksel_in(rxoutclksel_in),
        .rxpcommaalignen_in(rxpcommaalignen_in),
        .rxpcsreset_in(rxpcsreset_in),
        .rxpd_in(rxpd_in),
        .rxphalign_in(rxphalign_in),
        .rxphaligndone_out(rxphaligndone_out),
        .rxphalignen_in(rxphalignen_in),
        .rxphalignerr_out(rxphalignerr_out),
        .rxphdlypd_in(rxphdlypd_in),
        .rxphdlyreset_in(rxphdlyreset_in),
        .rxphovrden_in(rxphovrden_in),
        .rxpllclksel_in(rxpllclksel_in),
        .rxpmareset_in(rxpmareset_in),
        .rxpmaresetdone_out(rxpmaresetdone_out),
        .rxpolarity_in(rxpolarity_in),
        .rxprbscntreset_in(rxprbscntreset_in),
        .rxprbserr_out(rxprbserr_out),
        .rxprbslocked_out(rxprbslocked_out),
        .rxprbssel_in(rxprbssel_in),
        .rxprgdivresetdone_out(rxprgdivresetdone_out),
        .rxqpien_in(rxqpien_in),
        .rxqpisenn_out(rxqpisenn_out),
        .rxqpisenp_out(rxqpisenp_out),
        .rxrate_in(rxrate_in),
        .rxratedone_out(rxratedone_out),
        .rxratemode_in(rxratemode_in),
        .rxrecclk0_sel_out(rxrecclk0_sel_out),
        .rxrecclk1_sel_out(rxrecclk1_sel_out),
        .rxrecclkout_out(rxrecclkout_out),
        .rxresetdone_out(rxresetdone_out),
        .rxslide_in(rxslide_in),
        .rxsliderdy_out(rxsliderdy_out),
        .rxslipdone_out(rxslipdone_out),
        .rxslipoutclk_in(rxslipoutclk_in),
        .rxslipoutclkrdy_out(rxslipoutclkrdy_out),
        .rxslippma_in(rxslippma_in),
        .rxslippmardy_out(rxslippmardy_out),
        .rxstartofseq_out(rxstartofseq_out),
        .rxstatus_out(rxstatus_out),
        .rxsyncallin_in(rxsyncallin_in),
        .rxsyncdone_out(rxsyncdone_out),
        .rxsyncin_in(rxsyncin_in),
        .rxsyncmode_in(rxsyncmode_in),
        .rxsyncout_out(rxsyncout_out),
        .rxsysclksel_in(rxsysclksel_in),
        .rxusrclk2_in(rxusrclk2_in),
        .rxusrclk_in(rxusrclk_in),
        .rxvalid_out(rxvalid_out),
        .sigvalidclk_in(sigvalidclk_in),
        .tx8b10bbypass_in(tx8b10bbypass_in),
        .tx8b10ben_in(tx8b10ben_in),
        .txbufdiffctrl_in(txbufdiffctrl_in),
        .txbufstatus_out(txbufstatus_out),
        .txcomfinish_out(txcomfinish_out),
        .txcominit_in(txcominit_in),
        .txcomsas_in(txcomsas_in),
        .txcomwake_in(txcomwake_in),
        .txctrl0_in(txctrl0_in),
        .txctrl1_in(txctrl1_in),
        .txctrl2_in(txctrl2_in),
        .txdataextendrsvd_in(txdataextendrsvd_in),
        .txdeemph_in(txdeemph_in),
        .txdetectrx_in(txdetectrx_in),
        .txdiffctrl_in(txdiffctrl_in),
        .txdiffpd_in(txdiffpd_in),
        .txdlybypass_in(txdlybypass_in),
        .txdlyen_in(txdlyen_in),
        .txdlyhold_in(txdlyhold_in),
        .txdlyovrden_in(txdlyovrden_in),
        .txdlysreset_in(txdlysreset_in),
        .txdlysresetdone_out(txdlysresetdone_out),
        .txdlyupdown_in(txdlyupdown_in),
        .txelecidle_in(txelecidle_in),
        .txheader_in(txheader_in),
        .txinhibit_in(txinhibit_in),
        .txlatclk_in(txlatclk_in),
        .txmaincursor_in(txmaincursor_in),
        .txmargin_in(txmargin_in),
        .txoutclk_out(txoutclk_out),
        .txoutclkfabric_out(txoutclkfabric_out),
        .txoutclkpcs_out(txoutclkpcs_out),
        .txoutclksel_in(txoutclksel_in),
        .txpcsreset_in(txpcsreset_in),
        .txpd_in(txpd_in),
        .txpdelecidlemode_in(txpdelecidlemode_in),
        .txphalign_in(txphalign_in),
        .txphaligndone_out(txphaligndone_out),
        .txphalignen_in(txphalignen_in),
        .txphdlypd_in(txphdlypd_in),
        .txphdlyreset_in(txphdlyreset_in),
        .txphdlytstclk_in(txphdlytstclk_in),
        .txphinit_in(txphinit_in),
        .txphinitdone_out(txphinitdone_out),
        .txphovrden_in(txphovrden_in),
        .txpippmen_in(txpippmen_in),
        .txpippmovrden_in(txpippmovrden_in),
        .txpippmpd_in(txpippmpd_in),
        .txpippmsel_in(txpippmsel_in),
        .txpippmstepsize_in(txpippmstepsize_in),
        .txpisopd_in(txpisopd_in),
        .txpllclksel_in(txpllclksel_in),
        .txpmareset_in(txpmareset_in),
        .txpmaresetdone_out(txpmaresetdone_out),
        .txpolarity_in(txpolarity_in),
        .txpostcursor_in(txpostcursor_in),
        .txpostcursorinv_in(txpostcursorinv_in),
        .txprbsforceerr_in(txprbsforceerr_in),
        .txprbssel_in(txprbssel_in),
        .txprecursor_in(txprecursor_in),
        .txprecursorinv_in(txprecursorinv_in),
        .txprgdivresetdone_out(txprgdivresetdone_out),
        .txqpibiasen_in(txqpibiasen_in),
        .txqpisenn_out(txqpisenn_out),
        .txqpisenp_out(txqpisenp_out),
        .txqpistrongpdown_in(txqpistrongpdown_in),
        .txqpiweakpup_in(txqpiweakpup_in),
        .txrate_in(txrate_in),
        .txratedone_out(txratedone_out),
        .txratemode_in(txratemode_in),
        .txresetdone_out(txresetdone_out),
        .txsequence_in(txsequence_in),
        .txswing_in(txswing_in),
        .txsyncallin_in(txsyncallin_in),
        .txsyncdone_out(txsyncdone_out),
        .txsyncin_in(txsyncin_in),
        .txsyncmode_in(txsyncmode_in),
        .txsyncout_out(txsyncout_out),
        .txsysclksel_in(txsysclksel_in),
        .txusrclk2_in(txusrclk2_in),
        .txusrclk_in(txusrclk_in));
endmodule

(* ORIG_REF_NAME = "gtwizard_ultrascale_v1_4_bit_synchronizer" *) 
module GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_bit_synchronizer
   (E,
    I1,
    gtwiz_reset_clk_freerun_in,
    out,
    I2,
    I3,
    sm_reset_all_timer_sat,
    I4);
  output [0:0]E;
  input I1;
  input [0:0]gtwiz_reset_clk_freerun_in;
  input [3:0]out;
  input I2;
  input I3;
  input sm_reset_all_timer_sat;
  input I4;

  wire [0:0]E;
  wire I1;
  wire I2;
  wire I3;
  wire I4;
  wire gtpowergood_sync;
  wire [0:0]gtwiz_reset_clk_freerun_in;
  wire i_in_meta;
  wire i_in_sync1;
  wire i_in_sync2;
  wire i_in_sync3;
  wire \n_0_FSM_sequential_sm_reset_all[3]_i_2 ;
  wire [3:0]out;
  wire sm_reset_all_timer_sat;

LUT4 #(
    .INIT(16'h5444)) 
     \FSM_sequential_sm_reset_all[3]_i_1 
       (.I0(out[3]),
        .I1(\n_0_FSM_sequential_sm_reset_all[3]_i_2 ),
        .I2(out[1]),
        .I3(I2),
        .O(E));
LUT6 #(
    .INIT(64'h00FF08FF00FF0800)) 
     \FSM_sequential_sm_reset_all[3]_i_2 
       (.I0(I3),
        .I1(sm_reset_all_timer_sat),
        .I2(I4),
        .I3(out[2]),
        .I4(out[0]),
        .I5(gtpowergood_sync),
        .O(\n_0_FSM_sequential_sm_reset_all[3]_i_2 ));
(* ASYNC_REG *) 
   (* KEEP = "yes" *) 
   FDRE #(
    .INIT(1'b0)) 
     i_in_meta_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(I1),
        .Q(i_in_meta),
        .R(1'b0));
FDRE #(
    .INIT(1'b0)) 
     i_in_out_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(i_in_sync3),
        .Q(gtpowergood_sync),
        .R(1'b0));
(* ASYNC_REG *) 
   (* KEEP = "yes" *) 
   FDRE #(
    .INIT(1'b0)) 
     i_in_sync1_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(i_in_meta),
        .Q(i_in_sync1),
        .R(1'b0));
(* ASYNC_REG *) 
   (* KEEP = "yes" *) 
   FDRE #(
    .INIT(1'b0)) 
     i_in_sync2_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(i_in_sync1),
        .Q(i_in_sync2),
        .R(1'b0));
(* ASYNC_REG *) 
   (* KEEP = "yes" *) 
   FDRE #(
    .INIT(1'b0)) 
     i_in_sync3_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(i_in_sync2),
        .Q(i_in_sync3),
        .R(1'b0));
endmodule

(* ORIG_REF_NAME = "gtwizard_ultrascale_v1_4_bit_synchronizer" *) 
module GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_bit_synchronizer_0
   (gtwiz_reset_rx_datapath_dly,
    gtwiz_reset_rx_datapath_sync,
    gtwiz_reset_clk_freerun_in);
  output gtwiz_reset_rx_datapath_dly;
  input gtwiz_reset_rx_datapath_sync;
  input [0:0]gtwiz_reset_clk_freerun_in;

  wire [0:0]gtwiz_reset_clk_freerun_in;
  wire gtwiz_reset_rx_datapath_dly;
  wire gtwiz_reset_rx_datapath_sync;
  wire i_in_meta;
  wire i_in_sync1;
  wire i_in_sync2;
  wire i_in_sync3;

(* ASYNC_REG *) 
   (* KEEP = "yes" *) 
   FDRE #(
    .INIT(1'b0)) 
     i_in_meta_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(gtwiz_reset_rx_datapath_sync),
        .Q(i_in_meta),
        .R(1'b0));
FDRE #(
    .INIT(1'b0)) 
     i_in_out_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(i_in_sync3),
        .Q(gtwiz_reset_rx_datapath_dly),
        .R(1'b0));
(* ASYNC_REG *) 
   (* KEEP = "yes" *) 
   FDRE #(
    .INIT(1'b0)) 
     i_in_sync1_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(i_in_meta),
        .Q(i_in_sync1),
        .R(1'b0));
(* ASYNC_REG *) 
   (* KEEP = "yes" *) 
   FDRE #(
    .INIT(1'b0)) 
     i_in_sync2_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(i_in_sync1),
        .Q(i_in_sync2),
        .R(1'b0));
(* ASYNC_REG *) 
   (* KEEP = "yes" *) 
   FDRE #(
    .INIT(1'b0)) 
     i_in_sync3_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(i_in_sync2),
        .Q(i_in_sync3),
        .R(1'b0));
endmodule

(* ORIG_REF_NAME = "gtwizard_ultrascale_v1_4_bit_synchronizer" *) 
module GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_bit_synchronizer_1
   (gtwiz_reset_rx_pll_and_datapath_dly,
    gtwiz_reset_rx_pll_and_datapath_sync,
    gtwiz_reset_clk_freerun_in);
  output gtwiz_reset_rx_pll_and_datapath_dly;
  input gtwiz_reset_rx_pll_and_datapath_sync;
  input [0:0]gtwiz_reset_clk_freerun_in;

  wire [0:0]gtwiz_reset_clk_freerun_in;
  wire gtwiz_reset_rx_pll_and_datapath_dly;
  wire gtwiz_reset_rx_pll_and_datapath_sync;
  wire i_in_meta;
  wire i_in_sync1;
  wire i_in_sync2;
  wire i_in_sync3;

(* ASYNC_REG *) 
   (* KEEP = "yes" *) 
   FDRE #(
    .INIT(1'b0)) 
     i_in_meta_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(gtwiz_reset_rx_pll_and_datapath_sync),
        .Q(i_in_meta),
        .R(1'b0));
FDRE #(
    .INIT(1'b0)) 
     i_in_out_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(i_in_sync3),
        .Q(gtwiz_reset_rx_pll_and_datapath_dly),
        .R(1'b0));
(* ASYNC_REG *) 
   (* KEEP = "yes" *) 
   FDRE #(
    .INIT(1'b0)) 
     i_in_sync1_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(i_in_meta),
        .Q(i_in_sync1),
        .R(1'b0));
(* ASYNC_REG *) 
   (* KEEP = "yes" *) 
   FDRE #(
    .INIT(1'b0)) 
     i_in_sync2_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(i_in_sync1),
        .Q(i_in_sync2),
        .R(1'b0));
(* ASYNC_REG *) 
   (* KEEP = "yes" *) 
   FDRE #(
    .INIT(1'b0)) 
     i_in_sync3_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(i_in_sync2),
        .Q(i_in_sync3),
        .R(1'b0));
endmodule

(* ORIG_REF_NAME = "gtwizard_ultrascale_v1_4_bit_synchronizer" *) 
module GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_bit_synchronizer_10
   (p_0_in10_out,
    D,
    O1,
    I4,
    gtwiz_reset_clk_freerun_in,
    I1,
    sm_reset_rx_timer_sat,
    out,
    I2,
    gtwiz_reset_rx_pll_and_datapath_dly);
  output p_0_in10_out;
  output [2:0]D;
  output O1;
  input I4;
  input [0:0]gtwiz_reset_clk_freerun_in;
  input I1;
  input sm_reset_rx_timer_sat;
  input [2:0]out;
  input I2;
  input gtwiz_reset_rx_pll_and_datapath_dly;

  wire [2:0]D;
  wire I1;
  wire I2;
  wire I4;
  wire O1;
  wire [0:0]gtwiz_reset_clk_freerun_in;
  wire gtwiz_reset_rx_pll_and_datapath_dly;
  wire i_in_meta;
  wire i_in_sync1;
  wire i_in_sync2;
  wire i_in_sync3;
  wire [2:0]out;
  wire p_0_in10_out;
  wire rxresetdone_sync;
  wire sm_reset_rx_timer_sat;

LUT6 #(
    .INIT(64'h4055405555FF55AA)) 
     \FSM_sequential_sm_reset_rx[0]_i_1 
       (.I0(out[0]),
        .I1(rxresetdone_sync),
        .I2(I2),
        .I3(out[1]),
        .I4(gtwiz_reset_rx_pll_and_datapath_dly),
        .I5(out[2]),
        .O(D[0]));
LUT6 #(
    .INIT(64'h40AA40AA55AA55FF)) 
     \FSM_sequential_sm_reset_rx[1]_i_1 
       (.I0(out[0]),
        .I1(rxresetdone_sync),
        .I2(I2),
        .I3(out[1]),
        .I4(gtwiz_reset_rx_pll_and_datapath_dly),
        .I5(out[2]),
        .O(D[1]));
LUT6 #(
    .INIT(64'hAAEAFFFFAAAA0000)) 
     \FSM_sequential_sm_reset_rx[2]_i_2 
       (.I0(out[0]),
        .I1(rxresetdone_sync),
        .I2(sm_reset_rx_timer_sat),
        .I3(I1),
        .I4(out[1]),
        .I5(out[2]),
        .O(D[2]));
(* SOFT_HLUTNM = "soft_lutpair2" *) 
   LUT4 #(
    .INIT(16'h00B0)) 
     \FSM_sequential_sm_reset_rx[2]_i_5 
       (.I0(rxresetdone_sync),
        .I1(out[2]),
        .I2(sm_reset_rx_timer_sat),
        .I3(I1),
        .O(O1));
(* SOFT_HLUTNM = "soft_lutpair2" *) 
   LUT3 #(
    .INIT(8'h40)) 
     gtwiz_reset_rx_done_int_i_2
       (.I0(I1),
        .I1(sm_reset_rx_timer_sat),
        .I2(rxresetdone_sync),
        .O(p_0_in10_out));
(* ASYNC_REG *) 
   (* KEEP = "yes" *) 
   FDRE #(
    .INIT(1'b0)) 
     i_in_meta_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(I4),
        .Q(i_in_meta),
        .R(1'b0));
FDRE #(
    .INIT(1'b0)) 
     i_in_out_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(i_in_sync3),
        .Q(rxresetdone_sync),
        .R(1'b0));
(* ASYNC_REG *) 
   (* KEEP = "yes" *) 
   FDRE #(
    .INIT(1'b0)) 
     i_in_sync1_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(i_in_meta),
        .Q(i_in_sync1),
        .R(1'b0));
(* ASYNC_REG *) 
   (* KEEP = "yes" *) 
   FDRE #(
    .INIT(1'b0)) 
     i_in_sync2_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(i_in_sync1),
        .Q(i_in_sync2),
        .R(1'b0));
(* ASYNC_REG *) 
   (* KEEP = "yes" *) 
   FDRE #(
    .INIT(1'b0)) 
     i_in_sync3_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(i_in_sync2),
        .Q(i_in_sync3),
        .R(1'b0));
endmodule

(* ORIG_REF_NAME = "gtwizard_ultrascale_v1_4_bit_synchronizer" *) 
module GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_bit_synchronizer_11
   (gtwiz_reset_tx_done_out,
    I1,
    txusrclk2_in);
  output [0:0]gtwiz_reset_tx_done_out;
  input I1;
  input [0:0]txusrclk2_in;

  wire I1;
  wire [0:0]gtwiz_reset_tx_done_out;
  wire i_in_meta;
  wire i_in_sync1;
  wire i_in_sync2;
  wire i_in_sync3;
  wire [0:0]txusrclk2_in;

(* ASYNC_REG *) 
   (* KEEP = "yes" *) 
   FDRE #(
    .INIT(1'b0)) 
     i_in_meta_reg
       (.C(txusrclk2_in),
        .CE(1'b1),
        .D(I1),
        .Q(i_in_meta),
        .R(1'b0));
FDRE #(
    .INIT(1'b0)) 
     i_in_out_reg
       (.C(txusrclk2_in),
        .CE(1'b1),
        .D(i_in_sync3),
        .Q(gtwiz_reset_tx_done_out),
        .R(1'b0));
(* ASYNC_REG *) 
   (* KEEP = "yes" *) 
   FDRE #(
    .INIT(1'b0)) 
     i_in_sync1_reg
       (.C(txusrclk2_in),
        .CE(1'b1),
        .D(i_in_meta),
        .Q(i_in_sync1),
        .R(1'b0));
(* ASYNC_REG *) 
   (* KEEP = "yes" *) 
   FDRE #(
    .INIT(1'b0)) 
     i_in_sync2_reg
       (.C(txusrclk2_in),
        .CE(1'b1),
        .D(i_in_sync1),
        .Q(i_in_sync2),
        .R(1'b0));
(* ASYNC_REG *) 
   (* KEEP = "yes" *) 
   FDRE #(
    .INIT(1'b0)) 
     i_in_sync3_reg
       (.C(txusrclk2_in),
        .CE(1'b1),
        .D(i_in_sync2),
        .Q(i_in_sync3),
        .R(1'b0));
endmodule

(* ORIG_REF_NAME = "gtwizard_ultrascale_v1_4_bit_synchronizer" *) 
module GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_bit_synchronizer_12
   (txresetdone_sync,
    gtwiz_reset_tx_done_int0,
    E,
    I2,
    gtwiz_reset_clk_freerun_in,
    I1,
    sm_reset_tx_timer_sat,
    out,
    I3,
    sm_reset_tx_timer_clr0,
    plllock_tx_sync);
  output txresetdone_sync;
  output gtwiz_reset_tx_done_int0;
  output [0:0]E;
  input I2;
  input [0:0]gtwiz_reset_clk_freerun_in;
  input I1;
  input sm_reset_tx_timer_sat;
  input [2:0]out;
  input I3;
  input sm_reset_tx_timer_clr0;
  input plllock_tx_sync;

  wire [0:0]E;
  wire I1;
  wire I2;
  wire I3;
  wire [0:0]gtwiz_reset_clk_freerun_in;
  wire gtwiz_reset_tx_done_int0;
  wire i_in_meta;
  wire i_in_sync1;
  wire i_in_sync2;
  wire i_in_sync3;
  wire \n_0_FSM_sequential_sm_reset_tx[2]_i_3 ;
  wire [2:0]out;
  wire plllock_tx_sync;
  wire sm_reset_tx_timer_clr0;
  wire sm_reset_tx_timer_sat;
  wire txresetdone_sync;

LUT6 #(
    .INIT(64'hB8B8B8B8BBB8B8B8)) 
     \FSM_sequential_sm_reset_tx[2]_i_1 
       (.I0(\n_0_FSM_sequential_sm_reset_tx[2]_i_3 ),
        .I1(out[0]),
        .I2(I3),
        .I3(sm_reset_tx_timer_clr0),
        .I4(out[2]),
        .I5(out[1]),
        .O(E));
LUT6 #(
    .INIT(64'h0044404400004044)) 
     \FSM_sequential_sm_reset_tx[2]_i_3 
       (.I0(I1),
        .I1(sm_reset_tx_timer_sat),
        .I2(txresetdone_sync),
        .I3(out[2]),
        .I4(out[1]),
        .I5(plllock_tx_sync),
        .O(\n_0_FSM_sequential_sm_reset_tx[2]_i_3 ));
LUT3 #(
    .INIT(8'h40)) 
     gtwiz_reset_tx_done_int_i_2
       (.I0(I1),
        .I1(sm_reset_tx_timer_sat),
        .I2(txresetdone_sync),
        .O(gtwiz_reset_tx_done_int0));
(* ASYNC_REG *) 
   (* KEEP = "yes" *) 
   FDRE #(
    .INIT(1'b0)) 
     i_in_meta_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(I2),
        .Q(i_in_meta),
        .R(1'b0));
FDRE #(
    .INIT(1'b0)) 
     i_in_out_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(i_in_sync3),
        .Q(txresetdone_sync),
        .R(1'b0));
(* ASYNC_REG *) 
   (* KEEP = "yes" *) 
   FDRE #(
    .INIT(1'b0)) 
     i_in_sync1_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(i_in_meta),
        .Q(i_in_sync1),
        .R(1'b0));
(* ASYNC_REG *) 
   (* KEEP = "yes" *) 
   FDRE #(
    .INIT(1'b0)) 
     i_in_sync2_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(i_in_sync1),
        .Q(i_in_sync2),
        .R(1'b0));
(* ASYNC_REG *) 
   (* KEEP = "yes" *) 
   FDRE #(
    .INIT(1'b0)) 
     i_in_sync3_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(i_in_sync2),
        .Q(i_in_sync3),
        .R(1'b0));
endmodule

(* ORIG_REF_NAME = "gtwizard_ultrascale_v1_4_bit_synchronizer" *) 
module GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_bit_synchronizer_2
   (gtwiz_reset_tx_datapath_dly,
    gtwiz_reset_tx_datapath_sync,
    gtwiz_reset_clk_freerun_in);
  output gtwiz_reset_tx_datapath_dly;
  input gtwiz_reset_tx_datapath_sync;
  input [0:0]gtwiz_reset_clk_freerun_in;

  wire [0:0]gtwiz_reset_clk_freerun_in;
  wire gtwiz_reset_tx_datapath_dly;
  wire gtwiz_reset_tx_datapath_sync;
  wire i_in_meta;
  wire i_in_sync1;
  wire i_in_sync2;
  wire i_in_sync3;

(* ASYNC_REG *) 
   (* KEEP = "yes" *) 
   FDRE #(
    .INIT(1'b0)) 
     i_in_meta_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(gtwiz_reset_tx_datapath_sync),
        .Q(i_in_meta),
        .R(1'b0));
FDRE #(
    .INIT(1'b0)) 
     i_in_out_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(i_in_sync3),
        .Q(gtwiz_reset_tx_datapath_dly),
        .R(1'b0));
(* ASYNC_REG *) 
   (* KEEP = "yes" *) 
   FDRE #(
    .INIT(1'b0)) 
     i_in_sync1_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(i_in_meta),
        .Q(i_in_sync1),
        .R(1'b0));
(* ASYNC_REG *) 
   (* KEEP = "yes" *) 
   FDRE #(
    .INIT(1'b0)) 
     i_in_sync2_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(i_in_sync1),
        .Q(i_in_sync2),
        .R(1'b0));
(* ASYNC_REG *) 
   (* KEEP = "yes" *) 
   FDRE #(
    .INIT(1'b0)) 
     i_in_sync3_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(i_in_sync2),
        .Q(i_in_sync3),
        .R(1'b0));
endmodule

(* ORIG_REF_NAME = "gtwizard_ultrascale_v1_4_bit_synchronizer" *) 
module GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_bit_synchronizer_3
   (O1,
    D,
    gtwiz_reset_tx_pll_and_datapath_sync,
    gtwiz_reset_clk_freerun_in,
    sm_reset_tx_timer_sat,
    I1,
    out,
    gtwiz_reset_tx_datapath_dly);
  output O1;
  output [1:0]D;
  input gtwiz_reset_tx_pll_and_datapath_sync;
  input [0:0]gtwiz_reset_clk_freerun_in;
  input sm_reset_tx_timer_sat;
  input I1;
  input [2:0]out;
  input gtwiz_reset_tx_datapath_dly;

  wire [1:0]D;
  wire I1;
  wire O1;
  wire [0:0]gtwiz_reset_clk_freerun_in;
  wire gtwiz_reset_tx_datapath_dly;
  wire gtwiz_reset_tx_pll_and_datapath_dly;
  wire gtwiz_reset_tx_pll_and_datapath_sync;
  wire i_in_meta;
  wire i_in_sync1;
  wire i_in_sync2;
  wire i_in_sync3;
  wire [2:0]out;
  wire sm_reset_tx_timer_sat;

(* SOFT_HLUTNM = "soft_lutpair0" *) 
   LUT4 #(
    .INIT(16'h5756)) 
     \FSM_sequential_sm_reset_tx[0]_i_1 
       (.I0(out[0]),
        .I1(out[2]),
        .I2(out[1]),
        .I3(gtwiz_reset_tx_pll_and_datapath_dly),
        .O(D[0]));
(* SOFT_HLUTNM = "soft_lutpair0" *) 
   LUT4 #(
    .INIT(16'h4467)) 
     \FSM_sequential_sm_reset_tx[1]_i_1 
       (.I0(out[1]),
        .I1(out[0]),
        .I2(gtwiz_reset_tx_pll_and_datapath_dly),
        .I3(out[2]),
        .O(D[1]));
LUT6 #(
    .INIT(64'h020F020F020F0200)) 
     \FSM_sequential_sm_reset_tx[2]_i_4 
       (.I0(sm_reset_tx_timer_sat),
        .I1(I1),
        .I2(out[2]),
        .I3(out[1]),
        .I4(gtwiz_reset_tx_pll_and_datapath_dly),
        .I5(gtwiz_reset_tx_datapath_dly),
        .O(O1));
(* ASYNC_REG *) 
   (* KEEP = "yes" *) 
   FDRE #(
    .INIT(1'b0)) 
     i_in_meta_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(gtwiz_reset_tx_pll_and_datapath_sync),
        .Q(i_in_meta),
        .R(1'b0));
FDRE #(
    .INIT(1'b0)) 
     i_in_out_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(i_in_sync3),
        .Q(gtwiz_reset_tx_pll_and_datapath_dly),
        .R(1'b0));
(* ASYNC_REG *) 
   (* KEEP = "yes" *) 
   FDRE #(
    .INIT(1'b0)) 
     i_in_sync1_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(i_in_meta),
        .Q(i_in_sync1),
        .R(1'b0));
(* ASYNC_REG *) 
   (* KEEP = "yes" *) 
   FDRE #(
    .INIT(1'b0)) 
     i_in_sync2_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(i_in_sync1),
        .Q(i_in_sync2),
        .R(1'b0));
(* ASYNC_REG *) 
   (* KEEP = "yes" *) 
   FDRE #(
    .INIT(1'b0)) 
     i_in_sync3_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(i_in_sync2),
        .Q(i_in_sync3),
        .R(1'b0));
endmodule

(* ORIG_REF_NAME = "gtwizard_ultrascale_v1_4_bit_synchronizer" *) 
module GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_bit_synchronizer_4
   (gtwiz_reset_userclk_rx_active_sync,
    O1,
    O2,
    gtwiz_userclk_rx_active_in,
    gtwiz_reset_clk_freerun_in,
    out,
    gtwiz_reset_rx_any_sync,
    GTHE3_CHANNEL_RXUSERRDY,
    I1,
    sm_reset_rx_timer_sat);
  output gtwiz_reset_userclk_rx_active_sync;
  output O1;
  output O2;
  input [0:0]gtwiz_userclk_rx_active_in;
  input [0:0]gtwiz_reset_clk_freerun_in;
  input [2:0]out;
  input gtwiz_reset_rx_any_sync;
  input [0:0]GTHE3_CHANNEL_RXUSERRDY;
  input I1;
  input sm_reset_rx_timer_sat;

  wire [0:0]GTHE3_CHANNEL_RXUSERRDY;
  wire I1;
  wire O1;
  wire O2;
  wire [0:0]gtwiz_reset_clk_freerun_in;
  wire gtwiz_reset_rx_any_sync;
  wire gtwiz_reset_userclk_rx_active_sync;
  wire [0:0]gtwiz_userclk_rx_active_in;
  wire i_in_meta;
  wire i_in_sync1;
  wire i_in_sync2;
  wire i_in_sync3;
  wire [2:0]out;
  wire sm_reset_rx_timer_clr0;
  wire sm_reset_rx_timer_sat;

(* SOFT_HLUTNM = "soft_lutpair1" *) 
   LUT4 #(
    .INIT(16'h00B0)) 
     \FSM_sequential_sm_reset_rx[2]_i_4 
       (.I0(gtwiz_reset_userclk_rx_active_sync),
        .I1(out[2]),
        .I2(sm_reset_rx_timer_sat),
        .I3(I1),
        .O(O2));
(* ASYNC_REG *) 
   (* KEEP = "yes" *) 
   FDRE #(
    .INIT(1'b0)) 
     i_in_meta_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(gtwiz_userclk_rx_active_in),
        .Q(i_in_meta),
        .R(1'b0));
FDRE #(
    .INIT(1'b0)) 
     i_in_out_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(i_in_sync3),
        .Q(gtwiz_reset_userclk_rx_active_sync),
        .R(1'b0));
(* ASYNC_REG *) 
   (* KEEP = "yes" *) 
   FDRE #(
    .INIT(1'b0)) 
     i_in_sync1_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(i_in_meta),
        .Q(i_in_sync1),
        .R(1'b0));
(* ASYNC_REG *) 
   (* KEEP = "yes" *) 
   FDRE #(
    .INIT(1'b0)) 
     i_in_sync2_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(i_in_sync1),
        .Q(i_in_sync2),
        .R(1'b0));
(* ASYNC_REG *) 
   (* KEEP = "yes" *) 
   FDRE #(
    .INIT(1'b0)) 
     i_in_sync3_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(i_in_sync2),
        .Q(i_in_sync3),
        .R(1'b0));
LUT6 #(
    .INIT(64'hFFFFEBEB00002000)) 
     rxuserrdy_out_i_1
       (.I0(out[2]),
        .I1(out[1]),
        .I2(out[0]),
        .I3(sm_reset_rx_timer_clr0),
        .I4(gtwiz_reset_rx_any_sync),
        .I5(GTHE3_CHANNEL_RXUSERRDY),
        .O(O1));
(* SOFT_HLUTNM = "soft_lutpair1" *) 
   LUT3 #(
    .INIT(8'h40)) 
     rxuserrdy_out_i_2
       (.I0(I1),
        .I1(sm_reset_rx_timer_sat),
        .I2(gtwiz_reset_userclk_rx_active_sync),
        .O(sm_reset_rx_timer_clr0));
endmodule

(* ORIG_REF_NAME = "gtwizard_ultrascale_v1_4_bit_synchronizer" *) 
module GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_bit_synchronizer_5
   (O1,
    O2,
    sm_reset_tx_timer_clr0,
    gtwiz_userclk_tx_active_in,
    gtwiz_reset_clk_freerun_in,
    out,
    I1,
    I2,
    gtwiz_reset_tx_any_sync,
    GTHE3_CHANNEL_TXUSERRDY,
    sm_reset_tx_timer_sat);
  output O1;
  output O2;
  output sm_reset_tx_timer_clr0;
  input [0:0]gtwiz_userclk_tx_active_in;
  input [0:0]gtwiz_reset_clk_freerun_in;
  input [2:0]out;
  input I1;
  input I2;
  input gtwiz_reset_tx_any_sync;
  input [0:0]GTHE3_CHANNEL_TXUSERRDY;
  input sm_reset_tx_timer_sat;

  wire [0:0]GTHE3_CHANNEL_TXUSERRDY;
  wire I1;
  wire I2;
  wire O1;
  wire O2;
  wire [0:0]gtwiz_reset_clk_freerun_in;
  wire gtwiz_reset_tx_any_sync;
  wire gtwiz_reset_userclk_tx_active_sync;
  wire [0:0]gtwiz_userclk_tx_active_in;
  wire i_in_meta;
  wire i_in_sync1;
  wire i_in_sync2;
  wire i_in_sync3;
  wire n_0_sm_reset_tx_timer_clr_i_2;
  wire [2:0]out;
  wire sm_reset_tx_timer_clr0;
  wire sm_reset_tx_timer_sat;

LUT3 #(
    .INIT(8'h40)) 
     \FSM_sequential_sm_reset_tx[2]_i_5 
       (.I0(I2),
        .I1(sm_reset_tx_timer_sat),
        .I2(gtwiz_reset_userclk_tx_active_sync),
        .O(sm_reset_tx_timer_clr0));
(* ASYNC_REG *) 
   (* KEEP = "yes" *) 
   FDRE #(
    .INIT(1'b0)) 
     i_in_meta_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(gtwiz_userclk_tx_active_in),
        .Q(i_in_meta),
        .R(1'b0));
FDRE #(
    .INIT(1'b0)) 
     i_in_out_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(i_in_sync3),
        .Q(gtwiz_reset_userclk_tx_active_sync),
        .R(1'b0));
(* ASYNC_REG *) 
   (* KEEP = "yes" *) 
   FDRE #(
    .INIT(1'b0)) 
     i_in_sync1_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(i_in_meta),
        .Q(i_in_sync1),
        .R(1'b0));
(* ASYNC_REG *) 
   (* KEEP = "yes" *) 
   FDRE #(
    .INIT(1'b0)) 
     i_in_sync2_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(i_in_sync1),
        .Q(i_in_sync2),
        .R(1'b0));
(* ASYNC_REG *) 
   (* KEEP = "yes" *) 
   FDRE #(
    .INIT(1'b0)) 
     i_in_sync3_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(i_in_sync2),
        .Q(i_in_sync3),
        .R(1'b0));
LUT6 #(
    .INIT(64'hFFEAEAEA00EAEAEA)) 
     sm_reset_tx_timer_clr_i_1
       (.I0(n_0_sm_reset_tx_timer_clr_i_2),
        .I1(out[0]),
        .I2(I1),
        .I3(out[1]),
        .I4(out[2]),
        .I5(I2),
        .O(O1));
LUT6 #(
    .INIT(64'h0000000C080C08FF)) 
     sm_reset_tx_timer_clr_i_2
       (.I0(gtwiz_reset_userclk_tx_active_sync),
        .I1(sm_reset_tx_timer_sat),
        .I2(I2),
        .I3(out[2]),
        .I4(out[1]),
        .I5(out[0]),
        .O(n_0_sm_reset_tx_timer_clr_i_2));
LUT6 #(
    .INIT(64'hFFFFEBEB00000200)) 
     txuserrdy_out_i_1
       (.I0(out[2]),
        .I1(out[1]),
        .I2(out[0]),
        .I3(sm_reset_tx_timer_clr0),
        .I4(gtwiz_reset_tx_any_sync),
        .I5(GTHE3_CHANNEL_TXUSERRDY),
        .O(O2));
endmodule

(* ORIG_REF_NAME = "gtwizard_ultrascale_v1_4_bit_synchronizer" *) 
module GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_bit_synchronizer_6
   (O1,
    O2,
    O3,
    O4,
    E,
    qpll0lock_out,
    gtwiz_reset_clk_freerun_in,
    out,
    I1,
    sm_reset_rx_cdr_to_clr,
    p_0_in10_out,
    I2,
    gtwiz_reset_rx_any_sync,
    GTHE3_CHANNEL_GTRXRESET,
    I3,
    I4,
    I5,
    I6,
    sm_reset_rx_timer_sat,
    gtwiz_reset_userclk_rx_active_sync);
  output O1;
  output O2;
  output O3;
  output O4;
  output [0:0]E;
  input [0:0]qpll0lock_out;
  input [0:0]gtwiz_reset_clk_freerun_in;
  input [2:0]out;
  input I1;
  input sm_reset_rx_cdr_to_clr;
  input p_0_in10_out;
  input I2;
  input gtwiz_reset_rx_any_sync;
  input [0:0]GTHE3_CHANNEL_GTRXRESET;
  input I3;
  input I4;
  input I5;
  input I6;
  input sm_reset_rx_timer_sat;
  input gtwiz_reset_userclk_rx_active_sync;

  wire [0:0]E;
  wire [0:0]GTHE3_CHANNEL_GTRXRESET;
  wire I1;
  wire I2;
  wire I3;
  wire I4;
  wire I5;
  wire I6;
  wire O1;
  wire O2;
  wire O3;
  wire O4;
  wire [0:0]gtwiz_reset_clk_freerun_in;
  wire gtwiz_reset_rx_any_sync;
  wire gtwiz_reset_userclk_rx_active_sync;
  wire i_in_meta;
  wire i_in_sync1;
  wire i_in_sync2;
  wire i_in_sync3;
  wire \n_0_FSM_sequential_sm_reset_rx[2]_i_3 ;
  wire n_0_sm_reset_rx_timer_clr_i_2;
  wire [2:0]out;
  wire p_0_in10_out;
  wire plllock_rx_sync;
  wire [0:0]qpll0lock_out;
  wire sm_reset_rx_cdr_to_clr;
  wire sm_reset_rx_timer_sat;

LUT6 #(
    .INIT(64'hAFA0CFCFAFA0C0C0)) 
     \FSM_sequential_sm_reset_rx[2]_i_1 
       (.I0(\n_0_FSM_sequential_sm_reset_rx[2]_i_3 ),
        .I1(I5),
        .I2(out[0]),
        .I3(I3),
        .I4(out[1]),
        .I5(I6),
        .O(E));
LUT4 #(
    .INIT(16'h0008)) 
     \FSM_sequential_sm_reset_rx[2]_i_3 
       (.I0(plllock_rx_sync),
        .I1(sm_reset_rx_timer_sat),
        .I2(I4),
        .I3(out[2]),
        .O(\n_0_FSM_sequential_sm_reset_rx[2]_i_3 ));
LUT6 #(
    .INIT(64'hFFFF3FFF00001414)) 
     gtrxreset_out_i_1
       (.I0(out[2]),
        .I1(out[1]),
        .I2(out[0]),
        .I3(\n_0_FSM_sequential_sm_reset_rx[2]_i_3 ),
        .I4(gtwiz_reset_rx_any_sync),
        .I5(GTHE3_CHANNEL_GTRXRESET),
        .O(O3));
LUT6 #(
    .INIT(64'hBFBFFFFF30000000)) 
     gtwiz_reset_rx_done_int_i_1
       (.I0(plllock_rx_sync),
        .I1(out[0]),
        .I2(out[2]),
        .I3(p_0_in10_out),
        .I4(out[1]),
        .I5(I2),
        .O(O2));
(* ASYNC_REG *) 
   (* KEEP = "yes" *) 
   FDRE #(
    .INIT(1'b0)) 
     i_in_meta_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(qpll0lock_out),
        .Q(i_in_meta),
        .R(1'b0));
FDRE #(
    .INIT(1'b0)) 
     i_in_out_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(i_in_sync3),
        .Q(plllock_rx_sync),
        .R(1'b0));
(* ASYNC_REG *) 
   (* KEEP = "yes" *) 
   FDRE #(
    .INIT(1'b0)) 
     i_in_sync1_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(i_in_meta),
        .Q(i_in_sync1),
        .R(1'b0));
(* ASYNC_REG *) 
   (* KEEP = "yes" *) 
   FDRE #(
    .INIT(1'b0)) 
     i_in_sync2_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(i_in_sync1),
        .Q(i_in_sync2),
        .R(1'b0));
(* ASYNC_REG *) 
   (* KEEP = "yes" *) 
   FDRE #(
    .INIT(1'b0)) 
     i_in_sync3_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(i_in_sync2),
        .Q(i_in_sync3),
        .R(1'b0));
LUT5 #(
    .INIT(32'hFF7F8F00)) 
     sm_reset_rx_cdr_to_clr_i_1
       (.I0(\n_0_FSM_sequential_sm_reset_rx[2]_i_3 ),
        .I1(out[1]),
        .I2(out[0]),
        .I3(I1),
        .I4(sm_reset_rx_cdr_to_clr),
        .O(O1));
LUT6 #(
    .INIT(64'hFCAFACAF0CA0ACAF)) 
     sm_reset_rx_timer_clr_i_1
       (.I0(n_0_sm_reset_rx_timer_clr_i_2),
        .I1(I3),
        .I2(out[0]),
        .I3(out[1]),
        .I4(out[2]),
        .I5(I4),
        .O(O4));
LUT6 #(
    .INIT(64'h00000000B8BB0000)) 
     sm_reset_rx_timer_clr_i_2
       (.I0(plllock_rx_sync),
        .I1(out[1]),
        .I2(gtwiz_reset_userclk_rx_active_sync),
        .I3(out[2]),
        .I4(sm_reset_rx_timer_sat),
        .I5(I4),
        .O(n_0_sm_reset_rx_timer_clr_i_2));
endmodule

(* ORIG_REF_NAME = "gtwizard_ultrascale_v1_4_bit_synchronizer" *) 
module GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_bit_synchronizer_7
   (plllock_tx_sync,
    O1,
    O2,
    O3,
    qpll0lock_out,
    gtwiz_reset_clk_freerun_in,
    out,
    gtwiz_reset_tx_any_sync,
    GTHE3_CHANNEL_GTTXRESET,
    gtwiz_reset_tx_done_int0,
    I1,
    I2,
    sm_reset_tx_timer_sat,
    txresetdone_sync);
  output plllock_tx_sync;
  output O1;
  output O2;
  output O3;
  input [0:0]qpll0lock_out;
  input [0:0]gtwiz_reset_clk_freerun_in;
  input [2:0]out;
  input gtwiz_reset_tx_any_sync;
  input [0:0]GTHE3_CHANNEL_GTTXRESET;
  input gtwiz_reset_tx_done_int0;
  input I1;
  input I2;
  input sm_reset_tx_timer_sat;
  input txresetdone_sync;

  wire [0:0]GTHE3_CHANNEL_GTTXRESET;
  wire I1;
  wire I2;
  wire O1;
  wire O2;
  wire O3;
  wire [0:0]gtwiz_reset_clk_freerun_in;
  wire gtwiz_reset_tx_any_sync;
  wire gtwiz_reset_tx_done_int0;
  wire i_in_meta;
  wire i_in_sync1;
  wire i_in_sync2;
  wire i_in_sync3;
  wire [2:0]out;
  wire plllock_tx_sync;
  wire [0:0]qpll0lock_out;
  wire sm_reset_tx_timer_clr011_out;
  wire sm_reset_tx_timer_sat;
  wire txresetdone_sync;

LUT6 #(
    .INIT(64'hFFFFBFFF00001414)) 
     gttxreset_out_i_1
       (.I0(out[2]),
        .I1(out[1]),
        .I2(out[0]),
        .I3(sm_reset_tx_timer_clr011_out),
        .I4(gtwiz_reset_tx_any_sync),
        .I5(GTHE3_CHANNEL_GTTXRESET),
        .O(O1));
LUT3 #(
    .INIT(8'h40)) 
     gttxreset_out_i_2
       (.I0(I2),
        .I1(sm_reset_tx_timer_sat),
        .I2(plllock_tx_sync),
        .O(sm_reset_tx_timer_clr011_out));
LUT6 #(
    .INIT(64'hFFBFFFBF0C000000)) 
     gtwiz_reset_tx_done_int_i_1
       (.I0(plllock_tx_sync),
        .I1(out[2]),
        .I2(out[1]),
        .I3(out[0]),
        .I4(gtwiz_reset_tx_done_int0),
        .I5(I1),
        .O(O2));
(* ASYNC_REG *) 
   (* KEEP = "yes" *) 
   FDRE #(
    .INIT(1'b0)) 
     i_in_meta_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(qpll0lock_out),
        .Q(i_in_meta),
        .R(1'b0));
FDRE #(
    .INIT(1'b0)) 
     i_in_out_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(i_in_sync3),
        .Q(plllock_tx_sync),
        .R(1'b0));
(* ASYNC_REG *) 
   (* KEEP = "yes" *) 
   FDRE #(
    .INIT(1'b0)) 
     i_in_sync1_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(i_in_meta),
        .Q(i_in_sync1),
        .R(1'b0));
(* ASYNC_REG *) 
   (* KEEP = "yes" *) 
   FDRE #(
    .INIT(1'b0)) 
     i_in_sync2_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(i_in_sync1),
        .Q(i_in_sync2),
        .R(1'b0));
(* ASYNC_REG *) 
   (* KEEP = "yes" *) 
   FDRE #(
    .INIT(1'b0)) 
     i_in_sync3_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(i_in_sync2),
        .Q(i_in_sync3),
        .R(1'b0));
LUT6 #(
    .INIT(64'h0000000038080000)) 
     sm_reset_tx_timer_clr_i_3
       (.I0(plllock_tx_sync),
        .I1(out[1]),
        .I2(out[2]),
        .I3(txresetdone_sync),
        .I4(sm_reset_tx_timer_sat),
        .I5(I2),
        .O(O3));
endmodule

(* ORIG_REF_NAME = "gtwizard_ultrascale_v1_4_bit_synchronizer" *) 
module GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_bit_synchronizer_8
   (gtwiz_reset_rx_done_out,
    I1,
    rxusrclk2_in);
  output [0:0]gtwiz_reset_rx_done_out;
  input I1;
  input [0:0]rxusrclk2_in;

  wire I1;
  wire [0:0]gtwiz_reset_rx_done_out;
  wire i_in_meta;
  wire i_in_sync1;
  wire i_in_sync2;
  wire i_in_sync3;
  wire [0:0]rxusrclk2_in;

(* ASYNC_REG *) 
   (* KEEP = "yes" *) 
   FDRE #(
    .INIT(1'b0)) 
     i_in_meta_reg
       (.C(rxusrclk2_in),
        .CE(1'b1),
        .D(I1),
        .Q(i_in_meta),
        .R(1'b0));
FDRE #(
    .INIT(1'b0)) 
     i_in_out_reg
       (.C(rxusrclk2_in),
        .CE(1'b1),
        .D(i_in_sync3),
        .Q(gtwiz_reset_rx_done_out),
        .R(1'b0));
(* ASYNC_REG *) 
   (* KEEP = "yes" *) 
   FDRE #(
    .INIT(1'b0)) 
     i_in_sync1_reg
       (.C(rxusrclk2_in),
        .CE(1'b1),
        .D(i_in_meta),
        .Q(i_in_sync1),
        .R(1'b0));
(* ASYNC_REG *) 
   (* KEEP = "yes" *) 
   FDRE #(
    .INIT(1'b0)) 
     i_in_sync2_reg
       (.C(rxusrclk2_in),
        .CE(1'b1),
        .D(i_in_sync1),
        .Q(i_in_sync2),
        .R(1'b0));
(* ASYNC_REG *) 
   (* KEEP = "yes" *) 
   FDRE #(
    .INIT(1'b0)) 
     i_in_sync3_reg
       (.C(rxusrclk2_in),
        .CE(1'b1),
        .D(i_in_sync2),
        .Q(i_in_sync3),
        .R(1'b0));
endmodule

(* ORIG_REF_NAME = "gtwizard_ultrascale_v1_4_bit_synchronizer" *) 
module GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_bit_synchronizer_9
   (gtwiz_reset_rx_cdr_stable_out,
    O1,
    O2,
    I3,
    gtwiz_reset_clk_freerun_in,
    sm_reset_rx_cdr_to_sat,
    out,
    gtwiz_reset_rx_pll_and_datapath_dly,
    gtwiz_reset_rx_datapath_dly);
  output [0:0]gtwiz_reset_rx_cdr_stable_out;
  output O1;
  output O2;
  input I3;
  input [0:0]gtwiz_reset_clk_freerun_in;
  input sm_reset_rx_cdr_to_sat;
  input [1:0]out;
  input gtwiz_reset_rx_pll_and_datapath_dly;
  input gtwiz_reset_rx_datapath_dly;

  wire I3;
  wire O1;
  wire O2;
  wire [0:0]gtwiz_reset_clk_freerun_in;
  wire [0:0]gtwiz_reset_rx_cdr_stable_out;
  wire gtwiz_reset_rx_datapath_dly;
  wire gtwiz_reset_rx_pll_and_datapath_dly;
  wire i_in_meta;
  wire i_in_sync1;
  wire i_in_sync2;
  wire i_in_sync3;
  wire [1:0]out;
  wire sm_reset_rx_cdr_to_sat;

LUT5 #(
    .INIT(32'hEFEFEFE0)) 
     \FSM_sequential_sm_reset_rx[2]_i_6 
       (.I0(sm_reset_rx_cdr_to_sat),
        .I1(gtwiz_reset_rx_cdr_stable_out),
        .I2(out[1]),
        .I3(gtwiz_reset_rx_pll_and_datapath_dly),
        .I4(gtwiz_reset_rx_datapath_dly),
        .O(O1));
(* ASYNC_REG *) 
   (* KEEP = "yes" *) 
   FDRE #(
    .INIT(1'b0)) 
     i_in_meta_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(I3),
        .Q(i_in_meta),
        .R(1'b0));
FDRE #(
    .INIT(1'b0)) 
     i_in_out_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(i_in_sync3),
        .Q(gtwiz_reset_rx_cdr_stable_out),
        .R(1'b0));
(* ASYNC_REG *) 
   (* KEEP = "yes" *) 
   FDRE #(
    .INIT(1'b0)) 
     i_in_sync1_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(i_in_meta),
        .Q(i_in_sync1),
        .R(1'b0));
(* ASYNC_REG *) 
   (* KEEP = "yes" *) 
   FDRE #(
    .INIT(1'b0)) 
     i_in_sync2_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(i_in_sync1),
        .Q(i_in_sync2),
        .R(1'b0));
(* ASYNC_REG *) 
   (* KEEP = "yes" *) 
   FDRE #(
    .INIT(1'b0)) 
     i_in_sync3_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(i_in_sync2),
        .Q(i_in_sync3),
        .R(1'b0));
LUT4 #(
    .INIT(16'h00FD)) 
     sm_reset_rx_cdr_to_clr_i_2
       (.I0(out[1]),
        .I1(sm_reset_rx_cdr_to_sat),
        .I2(gtwiz_reset_rx_cdr_stable_out),
        .I3(out[0]),
        .O(O2));
endmodule

(* ORIG_REF_NAME = "gtwizard_ultrascale_v1_4_gthe3_channel" *) 
module GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_gthe3_channel
   (O1,
    gtpowergood_out,
    O2,
    txresetdone_out,
    O3,
    rxcdrlock_out,
    O4,
    rxresetdone_out,
    cpllfbclklost_out,
    cplllock_out,
    cpllrefclklost_out,
    drprdy_out,
    eyescandataerror_out,
    gthtxn_out,
    gthtxp_out,
    gtrefclkmonitor_out,
    pcierategen3_out,
    pcierateidle_out,
    pciesynctxsyncdone_out,
    pcieusergen3rdy_out,
    pcieuserphystatusrst_out,
    pcieuserratestart_out,
    phystatus_out,
    resetexception_out,
    rxbyteisaligned_out,
    rxbyterealign_out,
    rxcdrphdone_out,
    rxchanbondseq_out,
    rxchanisaligned_out,
    rxchanrealign_out,
    rxcominitdet_out,
    rxcommadet_out,
    rxcomsasdet_out,
    rxcomwakedet_out,
    rxdlysresetdone_out,
    rxelecidle_out,
    rxosintdone_out,
    rxosintstarted_out,
    rxosintstrobedone_out,
    rxosintstrobestarted_out,
    rxoutclk_out,
    rxoutclkfabric_out,
    rxoutclkpcs_out,
    rxphaligndone_out,
    rxphalignerr_out,
    rxpmaresetdone_out,
    rxprbserr_out,
    rxprbslocked_out,
    rxprgdivresetdone_out,
    rxqpisenn_out,
    rxqpisenp_out,
    rxratedone_out,
    rxrecclkout_out,
    rxsliderdy_out,
    rxslipdone_out,
    rxslipoutclkrdy_out,
    rxslippmardy_out,
    rxsyncdone_out,
    rxsyncout_out,
    rxvalid_out,
    txcomfinish_out,
    txdlysresetdone_out,
    txoutclk_out,
    txoutclkfabric_out,
    txoutclkpcs_out,
    txphaligndone_out,
    txphinitdone_out,
    txpmaresetdone_out,
    txprgdivresetdone_out,
    txqpisenn_out,
    txqpisenp_out,
    txratedone_out,
    txsyncdone_out,
    txsyncout_out,
    pcsrsvdout_out,
    rxdata_out,
    drpdo_out,
    rxctrl0_out,
    rxctrl1_out,
    dmonitorout_out,
    pcierateqpllpd_out,
    pcierateqpllreset_out,
    rxclkcorcnt_out,
    rxdatavalid_out,
    rxheadervalid_out,
    rxstartofseq_out,
    txbufstatus_out,
    bufgtce_out,
    bufgtcemask_out,
    bufgtreset_out,
    bufgtrstmask_out,
    rxbufstatus_out,
    rxstatus_out,
    rxchbondo_out,
    rxheader_out,
    rxmonitorout_out,
    pinrsrvdas_out,
    rxctrl2_out,
    rxctrl3_out,
    rxdataextendrsvd_out,
    bufgtdiv_out,
    cfgreset_in,
    clkrsvd0_in,
    clkrsvd1_in,
    cplllockdetclk_in,
    cplllocken_in,
    cpllpd_in,
    cpllreset_in,
    dmonfiforeset_in,
    dmonitorclk_in,
    drpclk_in,
    drpen_in,
    drpwe_in,
    evoddphicaldone_in,
    evoddphicalstart_in,
    evoddphidrden_in,
    evoddphidwren_in,
    evoddphixrden_in,
    evoddphixwren_in,
    eyescanmode_in,
    eyescanreset_in,
    eyescantrigger_in,
    gtgrefclk_in,
    gthrxn_in,
    gthrxp_in,
    gtnorthrefclk0_in,
    gtnorthrefclk1_in,
    gtrefclk0_in,
    gtrefclk1_in,
    gtresetsel_in,
    GTHE3_CHANNEL_GTRXRESET,
    gtsouthrefclk0_in,
    gtsouthrefclk1_in,
    GTHE3_CHANNEL_GTTXRESET,
    lpbkrxtxseren_in,
    lpbktxrxseren_in,
    pcieeqrxeqadaptdone_in,
    pcierstidle_in,
    pciersttxsyncstart_in,
    pcieuserratedone_in,
    qpll0outclk_out,
    qpll0outrefclk_out,
    qpll1outclk_out,
    qpll1outrefclk_out,
    resetovrd_in,
    rstclkentx_in,
    rx8b10ben_in,
    rxbufreset_in,
    rxcdrfreqreset_in,
    rxcdrhold_in,
    rxcdrovrden_in,
    rxcdrreset_in,
    rxcdrresetrsv_in,
    rxchbonden_in,
    rxchbondmaster_in,
    rxchbondslave_in,
    rxcommadeten_in,
    rxdfeagchold_in,
    rxdfeagcovrden_in,
    rxdfelfhold_in,
    rxdfelfovrden_in,
    rxdfelpmreset_in,
    rxdfetap10hold_in,
    rxdfetap10ovrden_in,
    rxdfetap11hold_in,
    rxdfetap11ovrden_in,
    rxdfetap12hold_in,
    rxdfetap12ovrden_in,
    rxdfetap13hold_in,
    rxdfetap13ovrden_in,
    rxdfetap14hold_in,
    rxdfetap14ovrden_in,
    rxdfetap15hold_in,
    rxdfetap15ovrden_in,
    rxdfetap2hold_in,
    rxdfetap2ovrden_in,
    rxdfetap3hold_in,
    rxdfetap3ovrden_in,
    rxdfetap4hold_in,
    rxdfetap4ovrden_in,
    rxdfetap5hold_in,
    rxdfetap5ovrden_in,
    rxdfetap6hold_in,
    rxdfetap6ovrden_in,
    rxdfetap7hold_in,
    rxdfetap7ovrden_in,
    rxdfetap8hold_in,
    rxdfetap8ovrden_in,
    rxdfetap9hold_in,
    rxdfetap9ovrden_in,
    rxdfeuthold_in,
    rxdfeutovrden_in,
    rxdfevphold_in,
    rxdfevpovrden_in,
    rxdfevsen_in,
    rxdfexyden_in,
    rxdlybypass_in,
    rxdlyen_in,
    rxdlyovrden_in,
    rxdlysreset_in,
    rxgearboxslip_in,
    rxlatclk_in,
    rxlpmen_in,
    rxlpmgchold_in,
    rxlpmgcovrden_in,
    rxlpmhfhold_in,
    rxlpmhfovrden_in,
    rxlpmlfhold_in,
    rxlpmlfklovrden_in,
    rxlpmoshold_in,
    rxlpmosovrden_in,
    rxmcommaalignen_in,
    rxoobreset_in,
    rxoscalreset_in,
    rxoshold_in,
    rxosinten_in,
    rxosinthold_in,
    rxosintovrden_in,
    rxosintstrobe_in,
    rxosinttestovrden_in,
    rxosovrden_in,
    rxpcommaalignen_in,
    rxpcsreset_in,
    rxphalign_in,
    rxphalignen_in,
    rxphdlypd_in,
    rxphdlyreset_in,
    rxphovrden_in,
    rxpmareset_in,
    rxpolarity_in,
    rxprbscntreset_in,
    GTHE3_CHANNEL_RXPROGDIVRESET,
    rxqpien_in,
    rxratemode_in,
    rxslide_in,
    rxslipoutclk_in,
    rxslippma_in,
    rxsyncallin_in,
    rxsyncin_in,
    rxsyncmode_in,
    GTHE3_CHANNEL_RXUSERRDY,
    rxusrclk_in,
    rxusrclk2_in,
    sigvalidclk_in,
    tx8b10ben_in,
    txcominit_in,
    txcomsas_in,
    txcomwake_in,
    txdeemph_in,
    txdetectrx_in,
    txdiffpd_in,
    txdlybypass_in,
    txdlyen_in,
    txdlyhold_in,
    txdlyovrden_in,
    txdlysreset_in,
    txdlyupdown_in,
    txelecidle_in,
    txinhibit_in,
    txlatclk_in,
    txpcsreset_in,
    txpdelecidlemode_in,
    txphalign_in,
    txphalignen_in,
    txphdlypd_in,
    txphdlyreset_in,
    txphdlytstclk_in,
    txphinit_in,
    txphovrden_in,
    txpippmen_in,
    txpippmovrden_in,
    txpippmpd_in,
    txpippmsel_in,
    txpisopd_in,
    txpmareset_in,
    txpolarity_in,
    txpostcursorinv_in,
    txprbsforceerr_in,
    txprecursorinv_in,
    GTHE3_CHANNEL_TXPROGDIVRESET,
    txqpibiasen_in,
    txqpistrongpdown_in,
    txqpiweakpup_in,
    txratemode_in,
    txswing_in,
    txsyncallin_in,
    txsyncin_in,
    txsyncmode_in,
    GTHE3_CHANNEL_TXUSERRDY,
    txusrclk_in,
    txusrclk2_in,
    gtwiz_userdata_tx_in,
    drpdi_in,
    gtrsvd_in,
    pcsrsvdin_in,
    txctrl0_in,
    txctrl1_in,
    rxdfeagcctrl_in,
    rxelecidlemode_in,
    rxmonitorsel_in,
    rxpd_in,
    rxpllclksel_in,
    rxsysclksel_in,
    txpd_in,
    txpllclksel_in,
    txsysclksel_in,
    cpllrefclksel_in,
    loopback_in,
    rxchbondlevel_in,
    rxoutclksel_in,
    rxrate_in,
    txbufdiffctrl_in,
    txmargin_in,
    txoutclksel_in,
    txrate_in,
    rxosintcfg_in,
    rxprbssel_in,
    txdiffctrl_in,
    txprbssel_in,
    pcsrsvdin2_in,
    pmarsvdin_in,
    rxchbondi_in,
    txpippmstepsize_in,
    txpostcursor_in,
    txprecursor_in,
    txheader_in,
    txmaincursor_in,
    txsequence_in,
    tx8b10bbypass_in,
    txctrl2_in,
    txdataextendrsvd_in,
    drpaddr_in);
  output O1;
  output [1:0]gtpowergood_out;
  output O2;
  output [1:0]txresetdone_out;
  output O3;
  output [1:0]rxcdrlock_out;
  output O4;
  output [1:0]rxresetdone_out;
  output [1:0]cpllfbclklost_out;
  output [1:0]cplllock_out;
  output [1:0]cpllrefclklost_out;
  output [1:0]drprdy_out;
  output [1:0]eyescandataerror_out;
  output [1:0]gthtxn_out;
  output [1:0]gthtxp_out;
  output [1:0]gtrefclkmonitor_out;
  output [1:0]pcierategen3_out;
  output [1:0]pcierateidle_out;
  output [1:0]pciesynctxsyncdone_out;
  output [1:0]pcieusergen3rdy_out;
  output [1:0]pcieuserphystatusrst_out;
  output [1:0]pcieuserratestart_out;
  output [1:0]phystatus_out;
  output [1:0]resetexception_out;
  output [1:0]rxbyteisaligned_out;
  output [1:0]rxbyterealign_out;
  output [1:0]rxcdrphdone_out;
  output [1:0]rxchanbondseq_out;
  output [1:0]rxchanisaligned_out;
  output [1:0]rxchanrealign_out;
  output [1:0]rxcominitdet_out;
  output [1:0]rxcommadet_out;
  output [1:0]rxcomsasdet_out;
  output [1:0]rxcomwakedet_out;
  output [1:0]rxdlysresetdone_out;
  output [1:0]rxelecidle_out;
  output [1:0]rxosintdone_out;
  output [1:0]rxosintstarted_out;
  output [1:0]rxosintstrobedone_out;
  output [1:0]rxosintstrobestarted_out;
  output [1:0]rxoutclk_out;
  output [1:0]rxoutclkfabric_out;
  output [1:0]rxoutclkpcs_out;
  output [1:0]rxphaligndone_out;
  output [1:0]rxphalignerr_out;
  output [1:0]rxpmaresetdone_out;
  output [1:0]rxprbserr_out;
  output [1:0]rxprbslocked_out;
  output [1:0]rxprgdivresetdone_out;
  output [1:0]rxqpisenn_out;
  output [1:0]rxqpisenp_out;
  output [1:0]rxratedone_out;
  output [1:0]rxrecclkout_out;
  output [1:0]rxsliderdy_out;
  output [1:0]rxslipdone_out;
  output [1:0]rxslipoutclkrdy_out;
  output [1:0]rxslippmardy_out;
  output [1:0]rxsyncdone_out;
  output [1:0]rxsyncout_out;
  output [1:0]rxvalid_out;
  output [1:0]txcomfinish_out;
  output [1:0]txdlysresetdone_out;
  output [1:0]txoutclk_out;
  output [1:0]txoutclkfabric_out;
  output [1:0]txoutclkpcs_out;
  output [1:0]txphaligndone_out;
  output [1:0]txphinitdone_out;
  output [1:0]txpmaresetdone_out;
  output [1:0]txprgdivresetdone_out;
  output [1:0]txqpisenn_out;
  output [1:0]txqpisenp_out;
  output [1:0]txratedone_out;
  output [1:0]txsyncdone_out;
  output [1:0]txsyncout_out;
  output [23:0]pcsrsvdout_out;
  output [255:0]rxdata_out;
  output [31:0]drpdo_out;
  output [31:0]rxctrl0_out;
  output [31:0]rxctrl1_out;
  output [33:0]dmonitorout_out;
  output [3:0]pcierateqpllpd_out;
  output [3:0]pcierateqpllreset_out;
  output [3:0]rxclkcorcnt_out;
  output [3:0]rxdatavalid_out;
  output [3:0]rxheadervalid_out;
  output [3:0]rxstartofseq_out;
  output [3:0]txbufstatus_out;
  output [5:0]bufgtce_out;
  output [5:0]bufgtcemask_out;
  output [5:0]bufgtreset_out;
  output [5:0]bufgtrstmask_out;
  output [5:0]rxbufstatus_out;
  output [5:0]rxstatus_out;
  output [9:0]rxchbondo_out;
  output [11:0]rxheader_out;
  output [13:0]rxmonitorout_out;
  output [15:0]pinrsrvdas_out;
  output [15:0]rxctrl2_out;
  output [15:0]rxctrl3_out;
  output [15:0]rxdataextendrsvd_out;
  output [17:0]bufgtdiv_out;
  input [1:0]cfgreset_in;
  input [1:0]clkrsvd0_in;
  input [1:0]clkrsvd1_in;
  input [1:0]cplllockdetclk_in;
  input [1:0]cplllocken_in;
  input [1:0]cpllpd_in;
  input [1:0]cpllreset_in;
  input [1:0]dmonfiforeset_in;
  input [1:0]dmonitorclk_in;
  input [1:0]drpclk_in;
  input [1:0]drpen_in;
  input [1:0]drpwe_in;
  input [1:0]evoddphicaldone_in;
  input [1:0]evoddphicalstart_in;
  input [1:0]evoddphidrden_in;
  input [1:0]evoddphidwren_in;
  input [1:0]evoddphixrden_in;
  input [1:0]evoddphixwren_in;
  input [1:0]eyescanmode_in;
  input [1:0]eyescanreset_in;
  input [1:0]eyescantrigger_in;
  input [1:0]gtgrefclk_in;
  input [1:0]gthrxn_in;
  input [1:0]gthrxp_in;
  input [1:0]gtnorthrefclk0_in;
  input [1:0]gtnorthrefclk1_in;
  input [1:0]gtrefclk0_in;
  input [1:0]gtrefclk1_in;
  input [1:0]gtresetsel_in;
  input [0:0]GTHE3_CHANNEL_GTRXRESET;
  input [1:0]gtsouthrefclk0_in;
  input [1:0]gtsouthrefclk1_in;
  input [0:0]GTHE3_CHANNEL_GTTXRESET;
  input [1:0]lpbkrxtxseren_in;
  input [1:0]lpbktxrxseren_in;
  input [1:0]pcieeqrxeqadaptdone_in;
  input [1:0]pcierstidle_in;
  input [1:0]pciersttxsyncstart_in;
  input [1:0]pcieuserratedone_in;
  input [0:0]qpll0outclk_out;
  input [0:0]qpll0outrefclk_out;
  input [0:0]qpll1outclk_out;
  input [0:0]qpll1outrefclk_out;
  input [1:0]resetovrd_in;
  input [1:0]rstclkentx_in;
  input [1:0]rx8b10ben_in;
  input [1:0]rxbufreset_in;
  input [1:0]rxcdrfreqreset_in;
  input [1:0]rxcdrhold_in;
  input [1:0]rxcdrovrden_in;
  input [1:0]rxcdrreset_in;
  input [1:0]rxcdrresetrsv_in;
  input [1:0]rxchbonden_in;
  input [1:0]rxchbondmaster_in;
  input [1:0]rxchbondslave_in;
  input [1:0]rxcommadeten_in;
  input [1:0]rxdfeagchold_in;
  input [1:0]rxdfeagcovrden_in;
  input [1:0]rxdfelfhold_in;
  input [1:0]rxdfelfovrden_in;
  input [1:0]rxdfelpmreset_in;
  input [1:0]rxdfetap10hold_in;
  input [1:0]rxdfetap10ovrden_in;
  input [1:0]rxdfetap11hold_in;
  input [1:0]rxdfetap11ovrden_in;
  input [1:0]rxdfetap12hold_in;
  input [1:0]rxdfetap12ovrden_in;
  input [1:0]rxdfetap13hold_in;
  input [1:0]rxdfetap13ovrden_in;
  input [1:0]rxdfetap14hold_in;
  input [1:0]rxdfetap14ovrden_in;
  input [1:0]rxdfetap15hold_in;
  input [1:0]rxdfetap15ovrden_in;
  input [1:0]rxdfetap2hold_in;
  input [1:0]rxdfetap2ovrden_in;
  input [1:0]rxdfetap3hold_in;
  input [1:0]rxdfetap3ovrden_in;
  input [1:0]rxdfetap4hold_in;
  input [1:0]rxdfetap4ovrden_in;
  input [1:0]rxdfetap5hold_in;
  input [1:0]rxdfetap5ovrden_in;
  input [1:0]rxdfetap6hold_in;
  input [1:0]rxdfetap6ovrden_in;
  input [1:0]rxdfetap7hold_in;
  input [1:0]rxdfetap7ovrden_in;
  input [1:0]rxdfetap8hold_in;
  input [1:0]rxdfetap8ovrden_in;
  input [1:0]rxdfetap9hold_in;
  input [1:0]rxdfetap9ovrden_in;
  input [1:0]rxdfeuthold_in;
  input [1:0]rxdfeutovrden_in;
  input [1:0]rxdfevphold_in;
  input [1:0]rxdfevpovrden_in;
  input [1:0]rxdfevsen_in;
  input [1:0]rxdfexyden_in;
  input [1:0]rxdlybypass_in;
  input [1:0]rxdlyen_in;
  input [1:0]rxdlyovrden_in;
  input [1:0]rxdlysreset_in;
  input [1:0]rxgearboxslip_in;
  input [1:0]rxlatclk_in;
  input [1:0]rxlpmen_in;
  input [1:0]rxlpmgchold_in;
  input [1:0]rxlpmgcovrden_in;
  input [1:0]rxlpmhfhold_in;
  input [1:0]rxlpmhfovrden_in;
  input [1:0]rxlpmlfhold_in;
  input [1:0]rxlpmlfklovrden_in;
  input [1:0]rxlpmoshold_in;
  input [1:0]rxlpmosovrden_in;
  input [1:0]rxmcommaalignen_in;
  input [1:0]rxoobreset_in;
  input [1:0]rxoscalreset_in;
  input [1:0]rxoshold_in;
  input [1:0]rxosinten_in;
  input [1:0]rxosinthold_in;
  input [1:0]rxosintovrden_in;
  input [1:0]rxosintstrobe_in;
  input [1:0]rxosinttestovrden_in;
  input [1:0]rxosovrden_in;
  input [1:0]rxpcommaalignen_in;
  input [1:0]rxpcsreset_in;
  input [1:0]rxphalign_in;
  input [1:0]rxphalignen_in;
  input [1:0]rxphdlypd_in;
  input [1:0]rxphdlyreset_in;
  input [1:0]rxphovrden_in;
  input [1:0]rxpmareset_in;
  input [1:0]rxpolarity_in;
  input [1:0]rxprbscntreset_in;
  input [0:0]GTHE3_CHANNEL_RXPROGDIVRESET;
  input [1:0]rxqpien_in;
  input [1:0]rxratemode_in;
  input [1:0]rxslide_in;
  input [1:0]rxslipoutclk_in;
  input [1:0]rxslippma_in;
  input [1:0]rxsyncallin_in;
  input [1:0]rxsyncin_in;
  input [1:0]rxsyncmode_in;
  input [0:0]GTHE3_CHANNEL_RXUSERRDY;
  input [1:0]rxusrclk_in;
  input [1:0]rxusrclk2_in;
  input [1:0]sigvalidclk_in;
  input [1:0]tx8b10ben_in;
  input [1:0]txcominit_in;
  input [1:0]txcomsas_in;
  input [1:0]txcomwake_in;
  input [1:0]txdeemph_in;
  input [1:0]txdetectrx_in;
  input [1:0]txdiffpd_in;
  input [1:0]txdlybypass_in;
  input [1:0]txdlyen_in;
  input [1:0]txdlyhold_in;
  input [1:0]txdlyovrden_in;
  input [1:0]txdlysreset_in;
  input [1:0]txdlyupdown_in;
  input [1:0]txelecidle_in;
  input [1:0]txinhibit_in;
  input [1:0]txlatclk_in;
  input [1:0]txpcsreset_in;
  input [1:0]txpdelecidlemode_in;
  input [1:0]txphalign_in;
  input [1:0]txphalignen_in;
  input [1:0]txphdlypd_in;
  input [1:0]txphdlyreset_in;
  input [1:0]txphdlytstclk_in;
  input [1:0]txphinit_in;
  input [1:0]txphovrden_in;
  input [1:0]txpippmen_in;
  input [1:0]txpippmovrden_in;
  input [1:0]txpippmpd_in;
  input [1:0]txpippmsel_in;
  input [1:0]txpisopd_in;
  input [1:0]txpmareset_in;
  input [1:0]txpolarity_in;
  input [1:0]txpostcursorinv_in;
  input [1:0]txprbsforceerr_in;
  input [1:0]txprecursorinv_in;
  input [0:0]GTHE3_CHANNEL_TXPROGDIVRESET;
  input [1:0]txqpibiasen_in;
  input [1:0]txqpistrongpdown_in;
  input [1:0]txqpiweakpup_in;
  input [1:0]txratemode_in;
  input [1:0]txswing_in;
  input [1:0]txsyncallin_in;
  input [1:0]txsyncin_in;
  input [1:0]txsyncmode_in;
  input [0:0]GTHE3_CHANNEL_TXUSERRDY;
  input [1:0]txusrclk_in;
  input [1:0]txusrclk2_in;
  input [63:0]gtwiz_userdata_tx_in;
  input [31:0]drpdi_in;
  input [31:0]gtrsvd_in;
  input [31:0]pcsrsvdin_in;
  input [31:0]txctrl0_in;
  input [31:0]txctrl1_in;
  input [3:0]rxdfeagcctrl_in;
  input [3:0]rxelecidlemode_in;
  input [3:0]rxmonitorsel_in;
  input [3:0]rxpd_in;
  input [3:0]rxpllclksel_in;
  input [3:0]rxsysclksel_in;
  input [3:0]txpd_in;
  input [3:0]txpllclksel_in;
  input [3:0]txsysclksel_in;
  input [5:0]cpllrefclksel_in;
  input [5:0]loopback_in;
  input [5:0]rxchbondlevel_in;
  input [5:0]rxoutclksel_in;
  input [5:0]rxrate_in;
  input [5:0]txbufdiffctrl_in;
  input [5:0]txmargin_in;
  input [5:0]txoutclksel_in;
  input [5:0]txrate_in;
  input [7:0]rxosintcfg_in;
  input [7:0]rxprbssel_in;
  input [7:0]txdiffctrl_in;
  input [7:0]txprbssel_in;
  input [9:0]pcsrsvdin2_in;
  input [9:0]pmarsvdin_in;
  input [9:0]rxchbondi_in;
  input [9:0]txpippmstepsize_in;
  input [9:0]txpostcursor_in;
  input [9:0]txprecursor_in;
  input [11:0]txheader_in;
  input [13:0]txmaincursor_in;
  input [13:0]txsequence_in;
  input [15:0]tx8b10bbypass_in;
  input [15:0]txctrl2_in;
  input [15:0]txdataextendrsvd_in;
  input [17:0]drpaddr_in;

  wire [0:0]GTHE3_CHANNEL_GTRXRESET;
  wire [0:0]GTHE3_CHANNEL_GTTXRESET;
  wire [0:0]GTHE3_CHANNEL_RXPROGDIVRESET;
  wire [0:0]GTHE3_CHANNEL_RXUSERRDY;
  wire [0:0]GTHE3_CHANNEL_TXPROGDIVRESET;
  wire [0:0]GTHE3_CHANNEL_TXUSERRDY;
  wire O1;
  wire O2;
  wire O3;
  wire O4;
  wire [5:0]bufgtce_out;
  wire [5:0]bufgtcemask_out;
  wire [17:0]bufgtdiv_out;
  wire [5:0]bufgtreset_out;
  wire [5:0]bufgtrstmask_out;
  wire [1:0]cfgreset_in;
  wire [1:0]clkrsvd0_in;
  wire [1:0]clkrsvd1_in;
  wire [1:0]cpllfbclklost_out;
  wire [1:0]cplllock_out;
  wire [1:0]cplllockdetclk_in;
  wire [1:0]cplllocken_in;
  wire [1:0]cpllpd_in;
  wire [1:0]cpllrefclklost_out;
  wire [5:0]cpllrefclksel_in;
  wire [1:0]cpllreset_in;
  wire [1:0]dmonfiforeset_in;
  wire [1:0]dmonitorclk_in;
  wire [33:0]dmonitorout_out;
  wire [17:0]drpaddr_in;
  wire [1:0]drpclk_in;
  wire [31:0]drpdi_in;
  wire [31:0]drpdo_out;
  wire [1:0]drpen_in;
  wire [1:0]drprdy_out;
  wire [1:0]drpwe_in;
  wire [1:0]evoddphicaldone_in;
  wire [1:0]evoddphicalstart_in;
  wire [1:0]evoddphidrden_in;
  wire [1:0]evoddphidwren_in;
  wire [1:0]evoddphixrden_in;
  wire [1:0]evoddphixwren_in;
  wire [1:0]eyescandataerror_out;
  wire [1:0]eyescanmode_in;
  wire [1:0]eyescanreset_in;
  wire [1:0]eyescantrigger_in;
  wire [1:0]gtgrefclk_in;
  wire [1:0]gthrxn_in;
  wire [1:0]gthrxp_in;
  wire [1:0]gthtxn_out;
  wire [1:0]gthtxp_out;
  wire [1:0]gtnorthrefclk0_in;
  wire [1:0]gtnorthrefclk1_in;
  wire [1:0]gtpowergood_out;
  wire [1:0]gtrefclk0_in;
  wire [1:0]gtrefclk1_in;
  wire [1:0]gtrefclkmonitor_out;
  wire [1:0]gtresetsel_in;
  wire [31:0]gtrsvd_in;
  wire [1:0]gtsouthrefclk0_in;
  wire [1:0]gtsouthrefclk1_in;
  wire [63:0]gtwiz_userdata_tx_in;
  wire [5:0]loopback_in;
  wire [1:0]lpbkrxtxseren_in;
  wire [1:0]lpbktxrxseren_in;
  wire [1:0]pcieeqrxeqadaptdone_in;
  wire [1:0]pcierategen3_out;
  wire [1:0]pcierateidle_out;
  wire [3:0]pcierateqpllpd_out;
  wire [3:0]pcierateqpllreset_out;
  wire [1:0]pcierstidle_in;
  wire [1:0]pciersttxsyncstart_in;
  wire [1:0]pciesynctxsyncdone_out;
  wire [1:0]pcieusergen3rdy_out;
  wire [1:0]pcieuserphystatusrst_out;
  wire [1:0]pcieuserratedone_in;
  wire [1:0]pcieuserratestart_out;
  wire [9:0]pcsrsvdin2_in;
  wire [31:0]pcsrsvdin_in;
  wire [23:0]pcsrsvdout_out;
  wire [1:0]phystatus_out;
  wire [15:0]pinrsrvdas_out;
  wire [9:0]pmarsvdin_in;
  wire [0:0]qpll0outclk_out;
  wire [0:0]qpll0outrefclk_out;
  wire [0:0]qpll1outclk_out;
  wire [0:0]qpll1outrefclk_out;
  wire [1:0]resetexception_out;
  wire [1:0]resetovrd_in;
  wire [1:0]rstclkentx_in;
  wire [1:0]rx8b10ben_in;
  wire [1:0]rxbufreset_in;
  wire [5:0]rxbufstatus_out;
  wire [1:0]rxbyteisaligned_out;
  wire [1:0]rxbyterealign_out;
  wire [1:0]rxcdrfreqreset_in;
  wire [1:0]rxcdrhold_in;
  wire [1:0]rxcdrlock_out;
  wire [1:0]rxcdrovrden_in;
  wire [1:0]rxcdrphdone_out;
  wire [1:0]rxcdrreset_in;
  wire [1:0]rxcdrresetrsv_in;
  wire [1:0]rxchanbondseq_out;
  wire [1:0]rxchanisaligned_out;
  wire [1:0]rxchanrealign_out;
  wire [1:0]rxchbonden_in;
  wire [9:0]rxchbondi_in;
  wire [5:0]rxchbondlevel_in;
  wire [1:0]rxchbondmaster_in;
  wire [9:0]rxchbondo_out;
  wire [1:0]rxchbondslave_in;
  wire [3:0]rxclkcorcnt_out;
  wire [1:0]rxcominitdet_out;
  wire [1:0]rxcommadet_out;
  wire [1:0]rxcommadeten_in;
  wire [1:0]rxcomsasdet_out;
  wire [1:0]rxcomwakedet_out;
  wire [31:0]rxctrl0_out;
  wire [31:0]rxctrl1_out;
  wire [15:0]rxctrl2_out;
  wire [15:0]rxctrl3_out;
  wire [255:0]rxdata_out;
  wire [15:0]rxdataextendrsvd_out;
  wire [3:0]rxdatavalid_out;
  wire [3:0]rxdfeagcctrl_in;
  wire [1:0]rxdfeagchold_in;
  wire [1:0]rxdfeagcovrden_in;
  wire [1:0]rxdfelfhold_in;
  wire [1:0]rxdfelfovrden_in;
  wire [1:0]rxdfelpmreset_in;
  wire [1:0]rxdfetap10hold_in;
  wire [1:0]rxdfetap10ovrden_in;
  wire [1:0]rxdfetap11hold_in;
  wire [1:0]rxdfetap11ovrden_in;
  wire [1:0]rxdfetap12hold_in;
  wire [1:0]rxdfetap12ovrden_in;
  wire [1:0]rxdfetap13hold_in;
  wire [1:0]rxdfetap13ovrden_in;
  wire [1:0]rxdfetap14hold_in;
  wire [1:0]rxdfetap14ovrden_in;
  wire [1:0]rxdfetap15hold_in;
  wire [1:0]rxdfetap15ovrden_in;
  wire [1:0]rxdfetap2hold_in;
  wire [1:0]rxdfetap2ovrden_in;
  wire [1:0]rxdfetap3hold_in;
  wire [1:0]rxdfetap3ovrden_in;
  wire [1:0]rxdfetap4hold_in;
  wire [1:0]rxdfetap4ovrden_in;
  wire [1:0]rxdfetap5hold_in;
  wire [1:0]rxdfetap5ovrden_in;
  wire [1:0]rxdfetap6hold_in;
  wire [1:0]rxdfetap6ovrden_in;
  wire [1:0]rxdfetap7hold_in;
  wire [1:0]rxdfetap7ovrden_in;
  wire [1:0]rxdfetap8hold_in;
  wire [1:0]rxdfetap8ovrden_in;
  wire [1:0]rxdfetap9hold_in;
  wire [1:0]rxdfetap9ovrden_in;
  wire [1:0]rxdfeuthold_in;
  wire [1:0]rxdfeutovrden_in;
  wire [1:0]rxdfevphold_in;
  wire [1:0]rxdfevpovrden_in;
  wire [1:0]rxdfevsen_in;
  wire [1:0]rxdfexyden_in;
  wire [1:0]rxdlybypass_in;
  wire [1:0]rxdlyen_in;
  wire [1:0]rxdlyovrden_in;
  wire [1:0]rxdlysreset_in;
  wire [1:0]rxdlysresetdone_out;
  wire [1:0]rxelecidle_out;
  wire [3:0]rxelecidlemode_in;
  wire [1:0]rxgearboxslip_in;
  wire [11:0]rxheader_out;
  wire [3:0]rxheadervalid_out;
  wire [1:0]rxlatclk_in;
  wire [1:0]rxlpmen_in;
  wire [1:0]rxlpmgchold_in;
  wire [1:0]rxlpmgcovrden_in;
  wire [1:0]rxlpmhfhold_in;
  wire [1:0]rxlpmhfovrden_in;
  wire [1:0]rxlpmlfhold_in;
  wire [1:0]rxlpmlfklovrden_in;
  wire [1:0]rxlpmoshold_in;
  wire [1:0]rxlpmosovrden_in;
  wire [1:0]rxmcommaalignen_in;
  wire [13:0]rxmonitorout_out;
  wire [3:0]rxmonitorsel_in;
  wire [1:0]rxoobreset_in;
  wire [1:0]rxoscalreset_in;
  wire [1:0]rxoshold_in;
  wire [7:0]rxosintcfg_in;
  wire [1:0]rxosintdone_out;
  wire [1:0]rxosinten_in;
  wire [1:0]rxosinthold_in;
  wire [1:0]rxosintovrden_in;
  wire [1:0]rxosintstarted_out;
  wire [1:0]rxosintstrobe_in;
  wire [1:0]rxosintstrobedone_out;
  wire [1:0]rxosintstrobestarted_out;
  wire [1:0]rxosinttestovrden_in;
  wire [1:0]rxosovrden_in;
  wire [1:0]rxoutclk_out;
  wire [1:0]rxoutclkfabric_out;
  wire [1:0]rxoutclkpcs_out;
  wire [5:0]rxoutclksel_in;
  wire [1:0]rxpcommaalignen_in;
  wire [1:0]rxpcsreset_in;
  wire [3:0]rxpd_in;
  wire [1:0]rxphalign_in;
  wire [1:0]rxphaligndone_out;
  wire [1:0]rxphalignen_in;
  wire [1:0]rxphalignerr_out;
  wire [1:0]rxphdlypd_in;
  wire [1:0]rxphdlyreset_in;
  wire [1:0]rxphovrden_in;
  wire [3:0]rxpllclksel_in;
  wire [1:0]rxpmareset_in;
  wire [1:0]rxpmaresetdone_out;
  wire [1:0]rxpolarity_in;
  wire [1:0]rxprbscntreset_in;
  wire [1:0]rxprbserr_out;
  wire [1:0]rxprbslocked_out;
  wire [7:0]rxprbssel_in;
  wire [1:0]rxprgdivresetdone_out;
  wire [1:0]rxqpien_in;
  wire [1:0]rxqpisenn_out;
  wire [1:0]rxqpisenp_out;
  wire [5:0]rxrate_in;
  wire [1:0]rxratedone_out;
  wire [1:0]rxratemode_in;
  wire [1:0]rxrecclkout_out;
  wire [1:0]rxresetdone_out;
  wire [1:0]rxslide_in;
  wire [1:0]rxsliderdy_out;
  wire [1:0]rxslipdone_out;
  wire [1:0]rxslipoutclk_in;
  wire [1:0]rxslipoutclkrdy_out;
  wire [1:0]rxslippma_in;
  wire [1:0]rxslippmardy_out;
  wire [3:0]rxstartofseq_out;
  wire [5:0]rxstatus_out;
  wire [1:0]rxsyncallin_in;
  wire [1:0]rxsyncdone_out;
  wire [1:0]rxsyncin_in;
  wire [1:0]rxsyncmode_in;
  wire [1:0]rxsyncout_out;
  wire [3:0]rxsysclksel_in;
  wire [1:0]rxusrclk2_in;
  wire [1:0]rxusrclk_in;
  wire [1:0]rxvalid_out;
  wire [1:0]sigvalidclk_in;
  wire [15:0]tx8b10bbypass_in;
  wire [1:0]tx8b10ben_in;
  wire [5:0]txbufdiffctrl_in;
  wire [3:0]txbufstatus_out;
  wire [1:0]txcomfinish_out;
  wire [1:0]txcominit_in;
  wire [1:0]txcomsas_in;
  wire [1:0]txcomwake_in;
  wire [31:0]txctrl0_in;
  wire [31:0]txctrl1_in;
  wire [15:0]txctrl2_in;
  wire [15:0]txdataextendrsvd_in;
  wire [1:0]txdeemph_in;
  wire [1:0]txdetectrx_in;
  wire [7:0]txdiffctrl_in;
  wire [1:0]txdiffpd_in;
  wire [1:0]txdlybypass_in;
  wire [1:0]txdlyen_in;
  wire [1:0]txdlyhold_in;
  wire [1:0]txdlyovrden_in;
  wire [1:0]txdlysreset_in;
  wire [1:0]txdlysresetdone_out;
  wire [1:0]txdlyupdown_in;
  wire [1:0]txelecidle_in;
  wire [11:0]txheader_in;
  wire [1:0]txinhibit_in;
  wire [1:0]txlatclk_in;
  wire [13:0]txmaincursor_in;
  wire [5:0]txmargin_in;
  wire [1:0]txoutclk_out;
  wire [1:0]txoutclkfabric_out;
  wire [1:0]txoutclkpcs_out;
  wire [5:0]txoutclksel_in;
  wire [1:0]txpcsreset_in;
  wire [3:0]txpd_in;
  wire [1:0]txpdelecidlemode_in;
  wire [1:0]txphalign_in;
  wire [1:0]txphaligndone_out;
  wire [1:0]txphalignen_in;
  wire [1:0]txphdlypd_in;
  wire [1:0]txphdlyreset_in;
  wire [1:0]txphdlytstclk_in;
  wire [1:0]txphinit_in;
  wire [1:0]txphinitdone_out;
  wire [1:0]txphovrden_in;
  wire [1:0]txpippmen_in;
  wire [1:0]txpippmovrden_in;
  wire [1:0]txpippmpd_in;
  wire [1:0]txpippmsel_in;
  wire [9:0]txpippmstepsize_in;
  wire [1:0]txpisopd_in;
  wire [3:0]txpllclksel_in;
  wire [1:0]txpmareset_in;
  wire [1:0]txpmaresetdone_out;
  wire [1:0]txpolarity_in;
  wire [9:0]txpostcursor_in;
  wire [1:0]txpostcursorinv_in;
  wire [1:0]txprbsforceerr_in;
  wire [7:0]txprbssel_in;
  wire [9:0]txprecursor_in;
  wire [1:0]txprecursorinv_in;
  wire [1:0]txprgdivresetdone_out;
  wire [1:0]txqpibiasen_in;
  wire [1:0]txqpisenn_out;
  wire [1:0]txqpisenp_out;
  wire [1:0]txqpistrongpdown_in;
  wire [1:0]txqpiweakpup_in;
  wire [5:0]txrate_in;
  wire [1:0]txratedone_out;
  wire [1:0]txratemode_in;
  wire [1:0]txresetdone_out;
  wire [13:0]txsequence_in;
  wire [1:0]txswing_in;
  wire [1:0]txsyncallin_in;
  wire [1:0]txsyncdone_out;
  wire [1:0]txsyncin_in;
  wire [1:0]txsyncmode_in;
  wire [1:0]txsyncout_out;
  wire [3:0]txsysclksel_in;
  wire [1:0]txusrclk2_in;
  wire [1:0]txusrclk_in;

(* BOX_TYPE = "PRIMITIVE" *) 
   GTHE3_CHANNEL #(
    .ACJTAG_DEBUG_MODE(1'b0),
    .ACJTAG_MODE(1'b0),
    .ACJTAG_RESET(1'b0),
    .ADAPT_CFG0(16'hF800),
    .ADAPT_CFG1(16'h0000),
    .ALIGN_COMMA_DOUBLE("FALSE"),
    .ALIGN_COMMA_ENABLE(10'b1111111111),
    .ALIGN_COMMA_WORD(1),
    .ALIGN_MCOMMA_DET("TRUE"),
    .ALIGN_MCOMMA_VALUE(10'b1010000011),
    .ALIGN_PCOMMA_DET("TRUE"),
    .ALIGN_PCOMMA_VALUE(10'b0101111100),
    .A_RXOSCALRESET(1'b0),
    .A_RXPROGDIVRESET(1'b0),
    .A_TXPROGDIVRESET(1'b0),
    .CBCC_DATA_SOURCE_SEL("DECODED"),
    .CDR_SWAP_MODE_EN(1'b0),
    .CHAN_BOND_KEEP_ALIGN("FALSE"),
    .CHAN_BOND_MAX_SKEW(1),
    .CHAN_BOND_SEQ_1_1(10'b0000000000),
    .CHAN_BOND_SEQ_1_2(10'b0000000000),
    .CHAN_BOND_SEQ_1_3(10'b0000000000),
    .CHAN_BOND_SEQ_1_4(10'b0000000000),
    .CHAN_BOND_SEQ_1_ENABLE(4'b1111),
    .CHAN_BOND_SEQ_2_1(10'b0000000000),
    .CHAN_BOND_SEQ_2_2(10'b0000000000),
    .CHAN_BOND_SEQ_2_3(10'b0000000000),
    .CHAN_BOND_SEQ_2_4(10'b0000000000),
    .CHAN_BOND_SEQ_2_ENABLE(4'b1111),
    .CHAN_BOND_SEQ_2_USE("FALSE"),
    .CHAN_BOND_SEQ_LEN(1),
    .CLK_CORRECT_USE("FALSE"),
    .CLK_COR_KEEP_IDLE("FALSE"),
    .CLK_COR_MAX_LAT(12),
    .CLK_COR_MIN_LAT(8),
    .CLK_COR_PRECEDENCE("TRUE"),
    .CLK_COR_REPEAT_WAIT(0),
    .CLK_COR_SEQ_1_1(10'b0100000000),
    .CLK_COR_SEQ_1_2(10'b0100000000),
    .CLK_COR_SEQ_1_3(10'b0100000000),
    .CLK_COR_SEQ_1_4(10'b0100000000),
    .CLK_COR_SEQ_1_ENABLE(4'b1111),
    .CLK_COR_SEQ_2_1(10'b0100000000),
    .CLK_COR_SEQ_2_2(10'b0100000000),
    .CLK_COR_SEQ_2_3(10'b0100000000),
    .CLK_COR_SEQ_2_4(10'b0100000000),
    .CLK_COR_SEQ_2_ENABLE(4'b1111),
    .CLK_COR_SEQ_2_USE("FALSE"),
    .CLK_COR_SEQ_LEN(1),
    .CPLL_CFG0(16'h67FA),
    .CPLL_CFG1(16'hA494),
    .CPLL_CFG2(16'hF007),
    .CPLL_CFG3(6'h00),
    .CPLL_FBDIV(2),
    .CPLL_FBDIV_45(5),
    .CPLL_INIT_CFG0(16'h001E),
    .CPLL_INIT_CFG1(8'h00),
    .CPLL_LOCK_CFG(16'h01E8),
    .CPLL_REFCLK_DIV(1),
    .DDI_CTRL(2'b00),
    .DDI_REALIGN_WAIT(15),
    .DEC_MCOMMA_DETECT("TRUE"),
    .DEC_PCOMMA_DETECT("TRUE"),
    .DEC_VALID_COMMA_ONLY("FALSE"),
    .DFE_D_X_REL_POS(1'b0),
    .DFE_VCM_COMP_EN(1'b0),
    .DMONITOR_CFG0(10'h000),
    .DMONITOR_CFG1(8'h00),
    .ES_CLK_PHASE_SEL(1'b0),
    .ES_CONTROL(6'b000000),
    .ES_ERRDET_EN("FALSE"),
    .ES_EYE_SCAN_EN("FALSE"),
    .ES_HORZ_OFFSET(12'h000),
    .ES_PMA_CFG(10'b0000000000),
    .ES_PRESCALE(5'b00000),
    .ES_QUALIFIER0(16'h0000),
    .ES_QUALIFIER1(16'h0000),
    .ES_QUALIFIER2(16'h0000),
    .ES_QUALIFIER3(16'h0000),
    .ES_QUALIFIER4(16'h0000),
    .ES_QUAL_MASK0(16'h0000),
    .ES_QUAL_MASK1(16'h0000),
    .ES_QUAL_MASK2(16'h0000),
    .ES_QUAL_MASK3(16'h0000),
    .ES_QUAL_MASK4(16'h0000),
    .ES_SDATA_MASK0(16'h0000),
    .ES_SDATA_MASK1(16'h0000),
    .ES_SDATA_MASK2(16'h0000),
    .ES_SDATA_MASK3(16'h0000),
    .ES_SDATA_MASK4(16'h0000),
    .EVODD_PHI_CFG(11'b00000000000),
    .EYE_SCAN_SWAP_EN(1'b0),
    .FTS_DESKEW_SEQ_ENABLE(4'b1111),
    .FTS_LANE_DESKEW_CFG(4'b1111),
    .FTS_LANE_DESKEW_EN("FALSE"),
    .GEARBOX_MODE(5'b00000),
    .GM_BIAS_SELECT(1'b0),
    .LOCAL_MASTER(1'b1),
    .OOBDIVCTL(2'b00),
    .OOB_PWRUP(1'b0),
    .PCI3_AUTO_REALIGN("OVR_1K_BLK"),
    .PCI3_PIPE_RX_ELECIDLE(1'b0),
    .PCI3_RX_ASYNC_EBUF_BYPASS(2'b00),
    .PCI3_RX_ELECIDLE_EI2_ENABLE(1'b0),
    .PCI3_RX_ELECIDLE_H2L_COUNT(6'b000000),
    .PCI3_RX_ELECIDLE_H2L_DISABLE(3'b000),
    .PCI3_RX_ELECIDLE_HI_COUNT(6'b000000),
    .PCI3_RX_ELECIDLE_LP4_DISABLE(1'b0),
    .PCI3_RX_FIFO_DISABLE(1'b0),
    .PCIE_BUFG_DIV_CTRL(16'h1000),
    .PCIE_RXPCS_CFG_GEN3(16'h02A4),
    .PCIE_RXPMA_CFG(16'h000A),
    .PCIE_TXPCS_CFG_GEN3(16'h24A0),
    .PCIE_TXPMA_CFG(16'h000A),
    .PCS_PCIE_EN("FALSE"),
    .PCS_RSVD0(16'b0000000000000000),
    .PCS_RSVD1(3'b000),
    .PD_TRANS_TIME_FROM_P2(12'h03C),
    .PD_TRANS_TIME_NONE_P2(8'h19),
    .PD_TRANS_TIME_TO_P2(8'h64),
    .PLL_SEL_MODE_GEN12(2'h0),
    .PLL_SEL_MODE_GEN3(2'h3),
    .PMA_RSV1(16'h1800),
    .PROCESS_PAR(3'b010),
    .RATE_SW_USE_DRP(1'b0),
    .RESET_POWERSAVE_DISABLE(1'b0),
    .RXBUFRESET_TIME(5'b00011),
    .RXBUF_ADDR_MODE("FAST"),
    .RXBUF_EIDLE_HI_CNT(4'b1000),
    .RXBUF_EIDLE_LO_CNT(4'b0000),
    .RXBUF_EN("TRUE"),
    .RXBUF_RESET_ON_CB_CHANGE("TRUE"),
    .RXBUF_RESET_ON_COMMAALIGN("FALSE"),
    .RXBUF_RESET_ON_EIDLE("FALSE"),
    .RXBUF_RESET_ON_RATE_CHANGE("TRUE"),
    .RXBUF_THRESH_OVFLW(57),
    .RXBUF_THRESH_OVRD("TRUE"),
    .RXBUF_THRESH_UNDFLW(3),
    .RXCDRFREQRESET_TIME(5'b00001),
    .RXCDRPHRESET_TIME(5'b00001),
    .RXCDR_CFG0(16'h0000),
    .RXCDR_CFG0_GEN3(16'h0000),
    .RXCDR_CFG1(16'h0000),
    .RXCDR_CFG1_GEN3(16'h0000),
    .RXCDR_CFG2(16'h0756),
    .RXCDR_CFG2_GEN3(16'h0756),
    .RXCDR_CFG3(16'h0000),
    .RXCDR_CFG3_GEN3(16'h0000),
    .RXCDR_CFG4(16'h0000),
    .RXCDR_CFG4_GEN3(16'h0000),
    .RXCDR_CFG5(16'h0000),
    .RXCDR_CFG5_GEN3(16'h0000),
    .RXCDR_FR_RESET_ON_EIDLE(1'b0),
    .RXCDR_HOLD_DURING_EIDLE(1'b0),
    .RXCDR_LOCK_CFG0(16'h4480),
    .RXCDR_LOCK_CFG1(16'h5FFF),
    .RXCDR_LOCK_CFG2(16'h77C3),
    .RXCDR_PH_RESET_ON_EIDLE(1'b0),
    .RXCFOK_CFG0(16'h4000),
    .RXCFOK_CFG1(16'h0065),
    .RXCFOK_CFG2(16'h002E),
    .RXDFELPMRESET_TIME(7'b0001111),
    .RXDFELPM_KL_CFG0(16'h0000),
    .RXDFELPM_KL_CFG1(16'h0002),
    .RXDFELPM_KL_CFG2(16'h0000),
    .RXDFE_CFG0(16'h0A00),
    .RXDFE_CFG1(16'h0000),
    .RXDFE_GC_CFG0(16'h0000),
    .RXDFE_GC_CFG1(16'h7870),
    .RXDFE_GC_CFG2(16'h0000),
    .RXDFE_H2_CFG0(16'h0000),
    .RXDFE_H2_CFG1(16'h0000),
    .RXDFE_H3_CFG0(16'h4000),
    .RXDFE_H3_CFG1(16'h0000),
    .RXDFE_H4_CFG0(16'h2000),
    .RXDFE_H4_CFG1(16'h0003),
    .RXDFE_H5_CFG0(16'h2000),
    .RXDFE_H5_CFG1(16'h0003),
    .RXDFE_H6_CFG0(16'h2000),
    .RXDFE_H6_CFG1(16'h0000),
    .RXDFE_H7_CFG0(16'h2000),
    .RXDFE_H7_CFG1(16'h0000),
    .RXDFE_H8_CFG0(16'h2000),
    .RXDFE_H8_CFG1(16'h0000),
    .RXDFE_H9_CFG0(16'h2000),
    .RXDFE_H9_CFG1(16'h0000),
    .RXDFE_HA_CFG0(16'h2000),
    .RXDFE_HA_CFG1(16'h0000),
    .RXDFE_HB_CFG0(16'h2000),
    .RXDFE_HB_CFG1(16'h0000),
    .RXDFE_HC_CFG0(16'h0000),
    .RXDFE_HC_CFG1(16'h0000),
    .RXDFE_HD_CFG0(16'h0000),
    .RXDFE_HD_CFG1(16'h0000),
    .RXDFE_HE_CFG0(16'h0000),
    .RXDFE_HE_CFG1(16'h0000),
    .RXDFE_HF_CFG0(16'h0000),
    .RXDFE_HF_CFG1(16'h0000),
    .RXDFE_OS_CFG0(16'h8000),
    .RXDFE_OS_CFG1(16'h0000),
    .RXDFE_UT_CFG0(16'h8000),
    .RXDFE_UT_CFG1(16'h0003),
    .RXDFE_VP_CFG0(16'hAA00),
    .RXDFE_VP_CFG1(16'h0033),
    .RXDLY_CFG(16'h001F),
    .RXDLY_LCFG(16'h0030),
    .RXELECIDLE_CFG("Sigcfg_4"),
    .RXGBOX_FIFO_INIT_RD_ADDR(4),
    .RXGEARBOX_EN("FALSE"),
    .RXISCANRESET_TIME(5'b00001),
    .RXLPM_CFG(16'h0000),
    .RXLPM_GC_CFG(16'h0000),
    .RXLPM_KH_CFG0(16'h0000),
    .RXLPM_KH_CFG1(16'h0002),
    .RXLPM_OS_CFG0(16'h8000),
    .RXLPM_OS_CFG1(16'h0002),
    .RXOOB_CFG(9'b000000110),
    .RXOOB_CLK_CFG("PMA"),
    .RXOSCALRESET_TIME(5'b00011),
    .RXOUT_DIV(2),
    .RXPCSRESET_TIME(5'b00011),
    .RXPHBEACON_CFG(16'h0000),
    .RXPHDLY_CFG(16'h2020),
    .RXPHSAMP_CFG(16'h2100),
    .RXPHSLIP_CFG(16'h6622),
    .RXPH_MONITOR_SEL(5'b00000),
    .RXPI_CFG0(2'b00),
    .RXPI_CFG1(2'b00),
    .RXPI_CFG2(2'b00),
    .RXPI_CFG3(2'b00),
    .RXPI_CFG4(1'b0),
    .RXPI_CFG5(1'b0),
    .RXPI_CFG6(3'b000),
    .RXPI_LPM(1'b0),
    .RXPI_VREFSEL(1'b0),
    .RXPMACLK_SEL("DATA"),
    .RXPMARESET_TIME(5'b00011),
    .RXPRBS_ERR_LOOPBACK(1'b0),
    .RXPRBS_LINKACQ_CNT(15),
    .RXSLIDE_AUTO_WAIT(7),
    .RXSLIDE_MODE("OFF"),
    .RXSYNC_MULTILANE(1'b1),
    .RXSYNC_OVRD(1'b0),
    .RXSYNC_SKIP_DA(1'b0),
    .RX_AFE_CM_EN(1'b0),
    .RX_BIAS_CFG0(16'h0AB4),
    .RX_BUFFER_CFG(6'b000000),
    .RX_CAPFF_SARC_ENB(1'b0),
    .RX_CLK25_DIV(15),
    .RX_CLKMUX_EN(1'b1),
    .RX_CLK_SLIP_OVRD(5'b00000),
    .RX_CM_BUF_CFG(4'b1010),
    .RX_CM_BUF_PD(1'b0),
    .RX_CM_SEL(2'b11),
    .RX_CM_TRIM(4'b1010),
    .RX_CTLE3_LPF(8'b00000001),
    .RX_DATA_WIDTH(40),
    .RX_DDI_SEL(6'b000000),
    .RX_DEFER_RESET_BUF_EN("TRUE"),
    .RX_DFELPM_CFG0(4'b0110),
    .RX_DFELPM_CFG1(1'b1),
    .RX_DFELPM_KLKH_AGC_STUP_EN(1'b1),
    .RX_DFE_AGC_CFG0(2'b10),
    .RX_DFE_AGC_CFG1(3'b100),
    .RX_DFE_KL_LPM_KH_CFG0(2'b01),
    .RX_DFE_KL_LPM_KH_CFG1(3'b100),
    .RX_DFE_KL_LPM_KL_CFG0(2'b01),
    .RX_DFE_KL_LPM_KL_CFG1(3'b100),
    .RX_DFE_LPM_HOLD_DURING_EIDLE(1'b0),
    .RX_DISPERR_SEQ_MATCH("TRUE"),
    .RX_DIVRESET_TIME(5'b00001),
    .RX_EN_HI_LR(1'b0),
    .RX_EYESCAN_VS_CODE(7'b0000000),
    .RX_EYESCAN_VS_NEG_DIR(1'b0),
    .RX_EYESCAN_VS_RANGE(2'b00),
    .RX_EYESCAN_VS_UT_SIGN(1'b0),
    .RX_FABINT_USRCLK_FLOP(1'b0),
    .RX_INT_DATAWIDTH(1),
    .RX_PMA_POWER_SAVE(1'b0),
    .RX_PROGDIV_CFG(40.000000),
    .RX_SAMPLE_PERIOD(3'b111),
    .RX_SIG_VALID_DLY(11),
    .RX_SUM_DFETAPREP_EN(1'b0),
    .RX_SUM_IREF_TUNE(4'b0000),
    .RX_SUM_RES_CTRL(2'b00),
    .RX_SUM_VCMTUNE(4'b0000),
    .RX_SUM_VCM_OVWR(1'b0),
    .RX_SUM_VREF_TUNE(3'b000),
    .RX_TUNE_AFE_OS(2'b10),
    .RX_WIDEMODE_CDR(1'b0),
    .RX_XCLK_SEL("RXDES"),
    .SAS_MAX_COM(64),
    .SAS_MIN_COM(36),
    .SATA_BURST_SEQ_LEN(4'b1111),
    .SATA_BURST_VAL(3'b100),
    .SATA_CPLL_CFG("VCO_3000MHZ"),
    .SATA_EIDLE_VAL(3'b100),
    .SATA_MAX_BURST(8),
    .SATA_MAX_INIT(21),
    .SATA_MAX_WAKE(7),
    .SATA_MIN_BURST(4),
    .SATA_MIN_INIT(12),
    .SATA_MIN_WAKE(4),
    .SHOW_REALIGN_COMMA("TRUE"),
    .SIM_RECEIVER_DETECT_PASS("TRUE"),
    .SIM_RESET_SPEEDUP("TRUE"),
    .SIM_TX_EIDLE_DRIVE_LEVEL(1'b0),
    .SIM_VERSION(2),
    .TAPDLY_SET_TX(2'h0),
    .TEMPERATUR_PAR(4'b0010),
    .TERM_RCAL_CFG(15'b100001000010000),
    .TERM_RCAL_OVRD(3'b000),
    .TRANS_TIME_RATE(8'h0E),
    .TST_RSV0(8'h00),
    .TST_RSV1(8'h00),
    .TXBUF_EN("TRUE"),
    .TXBUF_RESET_ON_RATE_CHANGE("TRUE"),
    .TXDLY_CFG(16'h0009),
    .TXDLY_LCFG(16'h0050),
    .TXDRVBIAS_N(4'b1010),
    .TXDRVBIAS_P(4'b1010),
    .TXFIFO_ADDR_CFG("LOW"),
    .TXGBOX_FIFO_INIT_RD_ADDR(4),
    .TXGEARBOX_EN("FALSE"),
    .TXOUT_DIV(2),
    .TXPCSRESET_TIME(5'b00011),
    .TXPHDLY_CFG0(16'h2020),
    .TXPHDLY_CFG1(16'h00D5),
    .TXPH_CFG(16'h0980),
    .TXPH_MONITOR_SEL(5'b00000),
    .TXPI_CFG0(2'b00),
    .TXPI_CFG1(2'b00),
    .TXPI_CFG2(2'b00),
    .TXPI_CFG3(1'b0),
    .TXPI_CFG4(1'b0),
    .TXPI_CFG5(3'b000),
    .TXPI_GRAY_SEL(1'b0),
    .TXPI_INVSTROBE_SEL(1'b0),
    .TXPI_LPM(1'b0),
    .TXPI_PPMCLK_SEL("TXUSRCLK2"),
    .TXPI_PPM_CFG(8'b00000000),
    .TXPI_SYNFREQ_PPM(3'b001),
    .TXPI_VREFSEL(1'b0),
    .TXPMARESET_TIME(5'b00011),
    .TXSYNC_MULTILANE(1'b1),
    .TXSYNC_OVRD(1'b0),
    .TXSYNC_SKIP_DA(1'b0),
    .TX_CLK25_DIV(15),
    .TX_CLKMUX_EN(1'b1),
    .TX_DATA_WIDTH(40),
    .TX_DCD_CFG(6'b000010),
    .TX_DCD_EN(1'b0),
    .TX_DEEMPH0(6'b000000),
    .TX_DEEMPH1(6'b000000),
    .TX_DIVRESET_TIME(5'b00001),
    .TX_DRIVE_MODE("DIRECT"),
    .TX_EIDLE_ASSERT_DELAY(3'b100),
    .TX_EIDLE_DEASSERT_DELAY(3'b011),
    .TX_EML_PHI_TUNE(1'b0),
    .TX_FABINT_USRCLK_FLOP(1'b0),
    .TX_IDLE_DATA_ZERO(1'b0),
    .TX_INT_DATAWIDTH(1),
    .TX_LOOPBACK_DRIVE_HIZ("FALSE"),
    .TX_MAINCURSOR_SEL(1'b0),
    .TX_MARGIN_FULL_0(7'b1001111),
    .TX_MARGIN_FULL_1(7'b1001110),
    .TX_MARGIN_FULL_2(7'b1001100),
    .TX_MARGIN_FULL_3(7'b1001010),
    .TX_MARGIN_FULL_4(7'b1001000),
    .TX_MARGIN_LOW_0(7'b1000110),
    .TX_MARGIN_LOW_1(7'b1000101),
    .TX_MARGIN_LOW_2(7'b1000011),
    .TX_MARGIN_LOW_3(7'b1000010),
    .TX_MARGIN_LOW_4(7'b1000000),
    .TX_MODE_SEL(3'b000),
    .TX_PMADATA_OPT(1'b0),
    .TX_PMA_POWER_SAVE(1'b0),
    .TX_PROGCLK_SEL("PREPI"),
    .TX_PROGDIV_CFG(40.000000),
    .TX_QPI_STATUS_EN(1'b0),
    .TX_RXDETECT_CFG(14'h0032),
    .TX_RXDETECT_REF(3'b100),
    .TX_SAMPLE_PERIOD(3'b111),
    .TX_SARC_LPBK_ENB(1'b0),
    .TX_XCLK_SEL("TXOUT"),
    .USE_PCS_CLK_PHASE_SEL(1'b0),
    .WB_MODE(2'b00)) 
     \gthe3_channel_gen.gen_gthe3_channel_inst[0].GTHE3_CHANNEL_PRIM_INST 
       (.BUFGTCE(bufgtce_out[2:0]),
        .BUFGTCEMASK(bufgtcemask_out[2:0]),
        .BUFGTDIV(bufgtdiv_out[8:0]),
        .BUFGTRESET(bufgtreset_out[2:0]),
        .BUFGTRSTMASK(bufgtrstmask_out[2:0]),
        .CFGRESET(cfgreset_in[0]),
        .CLKRSVD0(clkrsvd0_in[0]),
        .CLKRSVD1(clkrsvd1_in[0]),
        .CPLLFBCLKLOST(cpllfbclklost_out[0]),
        .CPLLLOCK(cplllock_out[0]),
        .CPLLLOCKDETCLK(cplllockdetclk_in[0]),
        .CPLLLOCKEN(cplllocken_in[0]),
        .CPLLPD(cpllpd_in[0]),
        .CPLLREFCLKLOST(cpllrefclklost_out[0]),
        .CPLLREFCLKSEL(cpllrefclksel_in[2:0]),
        .CPLLRESET(cpllreset_in[0]),
        .DMONFIFORESET(dmonfiforeset_in[0]),
        .DMONITORCLK(dmonitorclk_in[0]),
        .DMONITOROUT(dmonitorout_out[16:0]),
        .DRPADDR(drpaddr_in[8:0]),
        .DRPCLK(drpclk_in[0]),
        .DRPDI(drpdi_in[15:0]),
        .DRPDO(drpdo_out[15:0]),
        .DRPEN(drpen_in[0]),
        .DRPRDY(drprdy_out[0]),
        .DRPWE(drpwe_in[0]),
        .EVODDPHICALDONE(evoddphicaldone_in[0]),
        .EVODDPHICALSTART(evoddphicalstart_in[0]),
        .EVODDPHIDRDEN(evoddphidrden_in[0]),
        .EVODDPHIDWREN(evoddphidwren_in[0]),
        .EVODDPHIXRDEN(evoddphixrden_in[0]),
        .EVODDPHIXWREN(evoddphixwren_in[0]),
        .EYESCANDATAERROR(eyescandataerror_out[0]),
        .EYESCANMODE(eyescanmode_in[0]),
        .EYESCANRESET(eyescanreset_in[0]),
        .EYESCANTRIGGER(eyescantrigger_in[0]),
        .GTGREFCLK(gtgrefclk_in[0]),
        .GTHRXN(gthrxn_in[0]),
        .GTHRXP(gthrxp_in[0]),
        .GTHTXN(gthtxn_out[0]),
        .GTHTXP(gthtxp_out[0]),
        .GTNORTHREFCLK0(gtnorthrefclk0_in[0]),
        .GTNORTHREFCLK1(gtnorthrefclk1_in[0]),
        .GTPOWERGOOD(gtpowergood_out[0]),
        .GTREFCLK0(gtrefclk0_in[0]),
        .GTREFCLK1(gtrefclk1_in[0]),
        .GTREFCLKMONITOR(gtrefclkmonitor_out[0]),
        .GTRESETSEL(gtresetsel_in[0]),
        .GTRSVD(gtrsvd_in[15:0]),
        .GTRXRESET(GTHE3_CHANNEL_GTRXRESET),
        .GTSOUTHREFCLK0(gtsouthrefclk0_in[0]),
        .GTSOUTHREFCLK1(gtsouthrefclk1_in[0]),
        .GTTXRESET(GTHE3_CHANNEL_GTTXRESET),
        .LOOPBACK(loopback_in[2:0]),
        .LPBKRXTXSEREN(lpbkrxtxseren_in[0]),
        .LPBKTXRXSEREN(lpbktxrxseren_in[0]),
        .PCIEEQRXEQADAPTDONE(pcieeqrxeqadaptdone_in[0]),
        .PCIERATEGEN3(pcierategen3_out[0]),
        .PCIERATEIDLE(pcierateidle_out[0]),
        .PCIERATEQPLLPD(pcierateqpllpd_out[1:0]),
        .PCIERATEQPLLRESET(pcierateqpllreset_out[1:0]),
        .PCIERSTIDLE(pcierstidle_in[0]),
        .PCIERSTTXSYNCSTART(pciersttxsyncstart_in[0]),
        .PCIESYNCTXSYNCDONE(pciesynctxsyncdone_out[0]),
        .PCIEUSERGEN3RDY(pcieusergen3rdy_out[0]),
        .PCIEUSERPHYSTATUSRST(pcieuserphystatusrst_out[0]),
        .PCIEUSERRATEDONE(pcieuserratedone_in[0]),
        .PCIEUSERRATESTART(pcieuserratestart_out[0]),
        .PCSRSVDIN(pcsrsvdin_in[15:0]),
        .PCSRSVDIN2(pcsrsvdin2_in[4:0]),
        .PCSRSVDOUT(pcsrsvdout_out[11:0]),
        .PHYSTATUS(phystatus_out[0]),
        .PINRSRVDAS(pinrsrvdas_out[7:0]),
        .PMARSVDIN(pmarsvdin_in[4:0]),
        .QPLL0CLK(qpll0outclk_out),
        .QPLL0REFCLK(qpll0outrefclk_out),
        .QPLL1CLK(qpll1outclk_out),
        .QPLL1REFCLK(qpll1outrefclk_out),
        .RESETEXCEPTION(resetexception_out[0]),
        .RESETOVRD(resetovrd_in[0]),
        .RSTCLKENTX(rstclkentx_in[0]),
        .RX8B10BEN(rx8b10ben_in[0]),
        .RXBUFRESET(rxbufreset_in[0]),
        .RXBUFSTATUS(rxbufstatus_out[2:0]),
        .RXBYTEISALIGNED(rxbyteisaligned_out[0]),
        .RXBYTEREALIGN(rxbyterealign_out[0]),
        .RXCDRFREQRESET(rxcdrfreqreset_in[0]),
        .RXCDRHOLD(rxcdrhold_in[0]),
        .RXCDRLOCK(rxcdrlock_out[0]),
        .RXCDROVRDEN(rxcdrovrden_in[0]),
        .RXCDRPHDONE(rxcdrphdone_out[0]),
        .RXCDRRESET(rxcdrreset_in[0]),
        .RXCDRRESETRSV(rxcdrresetrsv_in[0]),
        .RXCHANBONDSEQ(rxchanbondseq_out[0]),
        .RXCHANISALIGNED(rxchanisaligned_out[0]),
        .RXCHANREALIGN(rxchanrealign_out[0]),
        .RXCHBONDEN(rxchbonden_in[0]),
        .RXCHBONDI(rxchbondi_in[4:0]),
        .RXCHBONDLEVEL(rxchbondlevel_in[2:0]),
        .RXCHBONDMASTER(rxchbondmaster_in[0]),
        .RXCHBONDO(rxchbondo_out[4:0]),
        .RXCHBONDSLAVE(rxchbondslave_in[0]),
        .RXCLKCORCNT(rxclkcorcnt_out[1:0]),
        .RXCOMINITDET(rxcominitdet_out[0]),
        .RXCOMMADET(rxcommadet_out[0]),
        .RXCOMMADETEN(rxcommadeten_in[0]),
        .RXCOMSASDET(rxcomsasdet_out[0]),
        .RXCOMWAKEDET(rxcomwakedet_out[0]),
        .RXCTRL0(rxctrl0_out[15:0]),
        .RXCTRL1(rxctrl1_out[15:0]),
        .RXCTRL2(rxctrl2_out[7:0]),
        .RXCTRL3(rxctrl3_out[7:0]),
        .RXDATA(rxdata_out[127:0]),
        .RXDATAEXTENDRSVD(rxdataextendrsvd_out[7:0]),
        .RXDATAVALID(rxdatavalid_out[1:0]),
        .RXDFEAGCCTRL(rxdfeagcctrl_in[1:0]),
        .RXDFEAGCHOLD(rxdfeagchold_in[0]),
        .RXDFEAGCOVRDEN(rxdfeagcovrden_in[0]),
        .RXDFELFHOLD(rxdfelfhold_in[0]),
        .RXDFELFOVRDEN(rxdfelfovrden_in[0]),
        .RXDFELPMRESET(rxdfelpmreset_in[0]),
        .RXDFETAP10HOLD(rxdfetap10hold_in[0]),
        .RXDFETAP10OVRDEN(rxdfetap10ovrden_in[0]),
        .RXDFETAP11HOLD(rxdfetap11hold_in[0]),
        .RXDFETAP11OVRDEN(rxdfetap11ovrden_in[0]),
        .RXDFETAP12HOLD(rxdfetap12hold_in[0]),
        .RXDFETAP12OVRDEN(rxdfetap12ovrden_in[0]),
        .RXDFETAP13HOLD(rxdfetap13hold_in[0]),
        .RXDFETAP13OVRDEN(rxdfetap13ovrden_in[0]),
        .RXDFETAP14HOLD(rxdfetap14hold_in[0]),
        .RXDFETAP14OVRDEN(rxdfetap14ovrden_in[0]),
        .RXDFETAP15HOLD(rxdfetap15hold_in[0]),
        .RXDFETAP15OVRDEN(rxdfetap15ovrden_in[0]),
        .RXDFETAP2HOLD(rxdfetap2hold_in[0]),
        .RXDFETAP2OVRDEN(rxdfetap2ovrden_in[0]),
        .RXDFETAP3HOLD(rxdfetap3hold_in[0]),
        .RXDFETAP3OVRDEN(rxdfetap3ovrden_in[0]),
        .RXDFETAP4HOLD(rxdfetap4hold_in[0]),
        .RXDFETAP4OVRDEN(rxdfetap4ovrden_in[0]),
        .RXDFETAP5HOLD(rxdfetap5hold_in[0]),
        .RXDFETAP5OVRDEN(rxdfetap5ovrden_in[0]),
        .RXDFETAP6HOLD(rxdfetap6hold_in[0]),
        .RXDFETAP6OVRDEN(rxdfetap6ovrden_in[0]),
        .RXDFETAP7HOLD(rxdfetap7hold_in[0]),
        .RXDFETAP7OVRDEN(rxdfetap7ovrden_in[0]),
        .RXDFETAP8HOLD(rxdfetap8hold_in[0]),
        .RXDFETAP8OVRDEN(rxdfetap8ovrden_in[0]),
        .RXDFETAP9HOLD(rxdfetap9hold_in[0]),
        .RXDFETAP9OVRDEN(rxdfetap9ovrden_in[0]),
        .RXDFEUTHOLD(rxdfeuthold_in[0]),
        .RXDFEUTOVRDEN(rxdfeutovrden_in[0]),
        .RXDFEVPHOLD(rxdfevphold_in[0]),
        .RXDFEVPOVRDEN(rxdfevpovrden_in[0]),
        .RXDFEVSEN(rxdfevsen_in[0]),
        .RXDFEXYDEN(rxdfexyden_in[0]),
        .RXDLYBYPASS(rxdlybypass_in[0]),
        .RXDLYEN(rxdlyen_in[0]),
        .RXDLYOVRDEN(rxdlyovrden_in[0]),
        .RXDLYSRESET(rxdlysreset_in[0]),
        .RXDLYSRESETDONE(rxdlysresetdone_out[0]),
        .RXELECIDLE(rxelecidle_out[0]),
        .RXELECIDLEMODE(rxelecidlemode_in[1:0]),
        .RXGEARBOXSLIP(rxgearboxslip_in[0]),
        .RXHEADER(rxheader_out[5:0]),
        .RXHEADERVALID(rxheadervalid_out[1:0]),
        .RXLATCLK(rxlatclk_in[0]),
        .RXLPMEN(rxlpmen_in[0]),
        .RXLPMGCHOLD(rxlpmgchold_in[0]),
        .RXLPMGCOVRDEN(rxlpmgcovrden_in[0]),
        .RXLPMHFHOLD(rxlpmhfhold_in[0]),
        .RXLPMHFOVRDEN(rxlpmhfovrden_in[0]),
        .RXLPMLFHOLD(rxlpmlfhold_in[0]),
        .RXLPMLFKLOVRDEN(rxlpmlfklovrden_in[0]),
        .RXLPMOSHOLD(rxlpmoshold_in[0]),
        .RXLPMOSOVRDEN(rxlpmosovrden_in[0]),
        .RXMCOMMAALIGNEN(rxmcommaalignen_in[0]),
        .RXMONITOROUT(rxmonitorout_out[6:0]),
        .RXMONITORSEL(rxmonitorsel_in[1:0]),
        .RXOOBRESET(rxoobreset_in[0]),
        .RXOSCALRESET(rxoscalreset_in[0]),
        .RXOSHOLD(rxoshold_in[0]),
        .RXOSINTCFG(rxosintcfg_in[3:0]),
        .RXOSINTDONE(rxosintdone_out[0]),
        .RXOSINTEN(rxosinten_in[0]),
        .RXOSINTHOLD(rxosinthold_in[0]),
        .RXOSINTOVRDEN(rxosintovrden_in[0]),
        .RXOSINTSTARTED(rxosintstarted_out[0]),
        .RXOSINTSTROBE(rxosintstrobe_in[0]),
        .RXOSINTSTROBEDONE(rxosintstrobedone_out[0]),
        .RXOSINTSTROBESTARTED(rxosintstrobestarted_out[0]),
        .RXOSINTTESTOVRDEN(rxosinttestovrden_in[0]),
        .RXOSOVRDEN(rxosovrden_in[0]),
        .RXOUTCLK(rxoutclk_out[0]),
        .RXOUTCLKFABRIC(rxoutclkfabric_out[0]),
        .RXOUTCLKPCS(rxoutclkpcs_out[0]),
        .RXOUTCLKSEL(rxoutclksel_in[2:0]),
        .RXPCOMMAALIGNEN(rxpcommaalignen_in[0]),
        .RXPCSRESET(rxpcsreset_in[0]),
        .RXPD(rxpd_in[1:0]),
        .RXPHALIGN(rxphalign_in[0]),
        .RXPHALIGNDONE(rxphaligndone_out[0]),
        .RXPHALIGNEN(rxphalignen_in[0]),
        .RXPHALIGNERR(rxphalignerr_out[0]),
        .RXPHDLYPD(rxphdlypd_in[0]),
        .RXPHDLYRESET(rxphdlyreset_in[0]),
        .RXPHOVRDEN(rxphovrden_in[0]),
        .RXPLLCLKSEL(rxpllclksel_in[1:0]),
        .RXPMARESET(rxpmareset_in[0]),
        .RXPMARESETDONE(rxpmaresetdone_out[0]),
        .RXPOLARITY(rxpolarity_in[0]),
        .RXPRBSCNTRESET(rxprbscntreset_in[0]),
        .RXPRBSERR(rxprbserr_out[0]),
        .RXPRBSLOCKED(rxprbslocked_out[0]),
        .RXPRBSSEL(rxprbssel_in[3:0]),
        .RXPRGDIVRESETDONE(rxprgdivresetdone_out[0]),
        .RXPROGDIVRESET(GTHE3_CHANNEL_RXPROGDIVRESET),
        .RXQPIEN(rxqpien_in[0]),
        .RXQPISENN(rxqpisenn_out[0]),
        .RXQPISENP(rxqpisenp_out[0]),
        .RXRATE(rxrate_in[2:0]),
        .RXRATEDONE(rxratedone_out[0]),
        .RXRATEMODE(rxratemode_in[0]),
        .RXRECCLKOUT(rxrecclkout_out[0]),
        .RXRESETDONE(rxresetdone_out[0]),
        .RXSLIDE(rxslide_in[0]),
        .RXSLIDERDY(rxsliderdy_out[0]),
        .RXSLIPDONE(rxslipdone_out[0]),
        .RXSLIPOUTCLK(rxslipoutclk_in[0]),
        .RXSLIPOUTCLKRDY(rxslipoutclkrdy_out[0]),
        .RXSLIPPMA(rxslippma_in[0]),
        .RXSLIPPMARDY(rxslippmardy_out[0]),
        .RXSTARTOFSEQ(rxstartofseq_out[1:0]),
        .RXSTATUS(rxstatus_out[2:0]),
        .RXSYNCALLIN(rxsyncallin_in[0]),
        .RXSYNCDONE(rxsyncdone_out[0]),
        .RXSYNCIN(rxsyncin_in[0]),
        .RXSYNCMODE(rxsyncmode_in[0]),
        .RXSYNCOUT(rxsyncout_out[0]),
        .RXSYSCLKSEL(rxsysclksel_in[1:0]),
        .RXUSERRDY(GTHE3_CHANNEL_RXUSERRDY),
        .RXUSRCLK(rxusrclk_in[0]),
        .RXUSRCLK2(rxusrclk2_in[0]),
        .RXVALID(rxvalid_out[0]),
        .SIGVALIDCLK(sigvalidclk_in[0]),
        .TSTIN({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .TX8B10BBYPASS(tx8b10bbypass_in[7:0]),
        .TX8B10BEN(tx8b10ben_in[0]),
        .TXBUFDIFFCTRL(txbufdiffctrl_in[2:0]),
        .TXBUFSTATUS(txbufstatus_out[1:0]),
        .TXCOMFINISH(txcomfinish_out[0]),
        .TXCOMINIT(txcominit_in[0]),
        .TXCOMSAS(txcomsas_in[0]),
        .TXCOMWAKE(txcomwake_in[0]),
        .TXCTRL0(txctrl0_in[15:0]),
        .TXCTRL1(txctrl1_in[15:0]),
        .TXCTRL2(txctrl2_in[7:0]),
        .TXDATA({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,gtwiz_userdata_tx_in[31:0]}),
        .TXDATAEXTENDRSVD(txdataextendrsvd_in[7:0]),
        .TXDEEMPH(txdeemph_in[0]),
        .TXDETECTRX(txdetectrx_in[0]),
        .TXDIFFCTRL(txdiffctrl_in[3:0]),
        .TXDIFFPD(txdiffpd_in[0]),
        .TXDLYBYPASS(txdlybypass_in[0]),
        .TXDLYEN(txdlyen_in[0]),
        .TXDLYHOLD(txdlyhold_in[0]),
        .TXDLYOVRDEN(txdlyovrden_in[0]),
        .TXDLYSRESET(txdlysreset_in[0]),
        .TXDLYSRESETDONE(txdlysresetdone_out[0]),
        .TXDLYUPDOWN(txdlyupdown_in[0]),
        .TXELECIDLE(txelecidle_in[0]),
        .TXHEADER(txheader_in[5:0]),
        .TXINHIBIT(txinhibit_in[0]),
        .TXLATCLK(txlatclk_in[0]),
        .TXMAINCURSOR(txmaincursor_in[6:0]),
        .TXMARGIN(txmargin_in[2:0]),
        .TXOUTCLK(txoutclk_out[0]),
        .TXOUTCLKFABRIC(txoutclkfabric_out[0]),
        .TXOUTCLKPCS(txoutclkpcs_out[0]),
        .TXOUTCLKSEL(txoutclksel_in[2:0]),
        .TXPCSRESET(txpcsreset_in[0]),
        .TXPD(txpd_in[1:0]),
        .TXPDELECIDLEMODE(txpdelecidlemode_in[0]),
        .TXPHALIGN(txphalign_in[0]),
        .TXPHALIGNDONE(txphaligndone_out[0]),
        .TXPHALIGNEN(txphalignen_in[0]),
        .TXPHDLYPD(txphdlypd_in[0]),
        .TXPHDLYRESET(txphdlyreset_in[0]),
        .TXPHDLYTSTCLK(txphdlytstclk_in[0]),
        .TXPHINIT(txphinit_in[0]),
        .TXPHINITDONE(txphinitdone_out[0]),
        .TXPHOVRDEN(txphovrden_in[0]),
        .TXPIPPMEN(txpippmen_in[0]),
        .TXPIPPMOVRDEN(txpippmovrden_in[0]),
        .TXPIPPMPD(txpippmpd_in[0]),
        .TXPIPPMSEL(txpippmsel_in[0]),
        .TXPIPPMSTEPSIZE(txpippmstepsize_in[4:0]),
        .TXPISOPD(txpisopd_in[0]),
        .TXPLLCLKSEL(txpllclksel_in[1:0]),
        .TXPMARESET(txpmareset_in[0]),
        .TXPMARESETDONE(txpmaresetdone_out[0]),
        .TXPOLARITY(txpolarity_in[0]),
        .TXPOSTCURSOR(txpostcursor_in[4:0]),
        .TXPOSTCURSORINV(txpostcursorinv_in[0]),
        .TXPRBSFORCEERR(txprbsforceerr_in[0]),
        .TXPRBSSEL(txprbssel_in[3:0]),
        .TXPRECURSOR(txprecursor_in[4:0]),
        .TXPRECURSORINV(txprecursorinv_in[0]),
        .TXPRGDIVRESETDONE(txprgdivresetdone_out[0]),
        .TXPROGDIVRESET(GTHE3_CHANNEL_TXPROGDIVRESET),
        .TXQPIBIASEN(txqpibiasen_in[0]),
        .TXQPISENN(txqpisenn_out[0]),
        .TXQPISENP(txqpisenp_out[0]),
        .TXQPISTRONGPDOWN(txqpistrongpdown_in[0]),
        .TXQPIWEAKPUP(txqpiweakpup_in[0]),
        .TXRATE(txrate_in[2:0]),
        .TXRATEDONE(txratedone_out[0]),
        .TXRATEMODE(txratemode_in[0]),
        .TXRESETDONE(txresetdone_out[0]),
        .TXSEQUENCE(txsequence_in[6:0]),
        .TXSWING(txswing_in[0]),
        .TXSYNCALLIN(txsyncallin_in[0]),
        .TXSYNCDONE(txsyncdone_out[0]),
        .TXSYNCIN(txsyncin_in[0]),
        .TXSYNCMODE(txsyncmode_in[0]),
        .TXSYNCOUT(txsyncout_out[0]),
        .TXSYSCLKSEL(txsysclksel_in[1:0]),
        .TXUSERRDY(GTHE3_CHANNEL_TXUSERRDY),
        .TXUSRCLK(txusrclk_in[0]),
        .TXUSRCLK2(txusrclk2_in[0]));
(* BOX_TYPE = "PRIMITIVE" *) 
   GTHE3_CHANNEL #(
    .ACJTAG_DEBUG_MODE(1'b0),
    .ACJTAG_MODE(1'b0),
    .ACJTAG_RESET(1'b0),
    .ADAPT_CFG0(16'hF800),
    .ADAPT_CFG1(16'h0000),
    .ALIGN_COMMA_DOUBLE("FALSE"),
    .ALIGN_COMMA_ENABLE(10'b1111111111),
    .ALIGN_COMMA_WORD(1),
    .ALIGN_MCOMMA_DET("TRUE"),
    .ALIGN_MCOMMA_VALUE(10'b1010000011),
    .ALIGN_PCOMMA_DET("TRUE"),
    .ALIGN_PCOMMA_VALUE(10'b0101111100),
    .A_RXOSCALRESET(1'b0),
    .A_RXPROGDIVRESET(1'b0),
    .A_TXPROGDIVRESET(1'b0),
    .CBCC_DATA_SOURCE_SEL("DECODED"),
    .CDR_SWAP_MODE_EN(1'b0),
    .CHAN_BOND_KEEP_ALIGN("FALSE"),
    .CHAN_BOND_MAX_SKEW(1),
    .CHAN_BOND_SEQ_1_1(10'b0000000000),
    .CHAN_BOND_SEQ_1_2(10'b0000000000),
    .CHAN_BOND_SEQ_1_3(10'b0000000000),
    .CHAN_BOND_SEQ_1_4(10'b0000000000),
    .CHAN_BOND_SEQ_1_ENABLE(4'b1111),
    .CHAN_BOND_SEQ_2_1(10'b0000000000),
    .CHAN_BOND_SEQ_2_2(10'b0000000000),
    .CHAN_BOND_SEQ_2_3(10'b0000000000),
    .CHAN_BOND_SEQ_2_4(10'b0000000000),
    .CHAN_BOND_SEQ_2_ENABLE(4'b1111),
    .CHAN_BOND_SEQ_2_USE("FALSE"),
    .CHAN_BOND_SEQ_LEN(1),
    .CLK_CORRECT_USE("FALSE"),
    .CLK_COR_KEEP_IDLE("FALSE"),
    .CLK_COR_MAX_LAT(12),
    .CLK_COR_MIN_LAT(8),
    .CLK_COR_PRECEDENCE("TRUE"),
    .CLK_COR_REPEAT_WAIT(0),
    .CLK_COR_SEQ_1_1(10'b0100000000),
    .CLK_COR_SEQ_1_2(10'b0100000000),
    .CLK_COR_SEQ_1_3(10'b0100000000),
    .CLK_COR_SEQ_1_4(10'b0100000000),
    .CLK_COR_SEQ_1_ENABLE(4'b1111),
    .CLK_COR_SEQ_2_1(10'b0100000000),
    .CLK_COR_SEQ_2_2(10'b0100000000),
    .CLK_COR_SEQ_2_3(10'b0100000000),
    .CLK_COR_SEQ_2_4(10'b0100000000),
    .CLK_COR_SEQ_2_ENABLE(4'b1111),
    .CLK_COR_SEQ_2_USE("FALSE"),
    .CLK_COR_SEQ_LEN(1),
    .CPLL_CFG0(16'h67FA),
    .CPLL_CFG1(16'hA494),
    .CPLL_CFG2(16'hF007),
    .CPLL_CFG3(6'h00),
    .CPLL_FBDIV(2),
    .CPLL_FBDIV_45(5),
    .CPLL_INIT_CFG0(16'h001E),
    .CPLL_INIT_CFG1(8'h00),
    .CPLL_LOCK_CFG(16'h01E8),
    .CPLL_REFCLK_DIV(1),
    .DDI_CTRL(2'b00),
    .DDI_REALIGN_WAIT(15),
    .DEC_MCOMMA_DETECT("TRUE"),
    .DEC_PCOMMA_DETECT("TRUE"),
    .DEC_VALID_COMMA_ONLY("FALSE"),
    .DFE_D_X_REL_POS(1'b0),
    .DFE_VCM_COMP_EN(1'b0),
    .DMONITOR_CFG0(10'h000),
    .DMONITOR_CFG1(8'h00),
    .ES_CLK_PHASE_SEL(1'b0),
    .ES_CONTROL(6'b000000),
    .ES_ERRDET_EN("FALSE"),
    .ES_EYE_SCAN_EN("FALSE"),
    .ES_HORZ_OFFSET(12'h000),
    .ES_PMA_CFG(10'b0000000000),
    .ES_PRESCALE(5'b00000),
    .ES_QUALIFIER0(16'h0000),
    .ES_QUALIFIER1(16'h0000),
    .ES_QUALIFIER2(16'h0000),
    .ES_QUALIFIER3(16'h0000),
    .ES_QUALIFIER4(16'h0000),
    .ES_QUAL_MASK0(16'h0000),
    .ES_QUAL_MASK1(16'h0000),
    .ES_QUAL_MASK2(16'h0000),
    .ES_QUAL_MASK3(16'h0000),
    .ES_QUAL_MASK4(16'h0000),
    .ES_SDATA_MASK0(16'h0000),
    .ES_SDATA_MASK1(16'h0000),
    .ES_SDATA_MASK2(16'h0000),
    .ES_SDATA_MASK3(16'h0000),
    .ES_SDATA_MASK4(16'h0000),
    .EVODD_PHI_CFG(11'b00000000000),
    .EYE_SCAN_SWAP_EN(1'b0),
    .FTS_DESKEW_SEQ_ENABLE(4'b1111),
    .FTS_LANE_DESKEW_CFG(4'b1111),
    .FTS_LANE_DESKEW_EN("FALSE"),
    .GEARBOX_MODE(5'b00000),
    .GM_BIAS_SELECT(1'b0),
    .LOCAL_MASTER(1'b1),
    .OOBDIVCTL(2'b00),
    .OOB_PWRUP(1'b0),
    .PCI3_AUTO_REALIGN("OVR_1K_BLK"),
    .PCI3_PIPE_RX_ELECIDLE(1'b0),
    .PCI3_RX_ASYNC_EBUF_BYPASS(2'b00),
    .PCI3_RX_ELECIDLE_EI2_ENABLE(1'b0),
    .PCI3_RX_ELECIDLE_H2L_COUNT(6'b000000),
    .PCI3_RX_ELECIDLE_H2L_DISABLE(3'b000),
    .PCI3_RX_ELECIDLE_HI_COUNT(6'b000000),
    .PCI3_RX_ELECIDLE_LP4_DISABLE(1'b0),
    .PCI3_RX_FIFO_DISABLE(1'b0),
    .PCIE_BUFG_DIV_CTRL(16'h1000),
    .PCIE_RXPCS_CFG_GEN3(16'h02A4),
    .PCIE_RXPMA_CFG(16'h000A),
    .PCIE_TXPCS_CFG_GEN3(16'h24A0),
    .PCIE_TXPMA_CFG(16'h000A),
    .PCS_PCIE_EN("FALSE"),
    .PCS_RSVD0(16'b0000000000000000),
    .PCS_RSVD1(3'b000),
    .PD_TRANS_TIME_FROM_P2(12'h03C),
    .PD_TRANS_TIME_NONE_P2(8'h19),
    .PD_TRANS_TIME_TO_P2(8'h64),
    .PLL_SEL_MODE_GEN12(2'h0),
    .PLL_SEL_MODE_GEN3(2'h3),
    .PMA_RSV1(16'h1800),
    .PROCESS_PAR(3'b010),
    .RATE_SW_USE_DRP(1'b0),
    .RESET_POWERSAVE_DISABLE(1'b0),
    .RXBUFRESET_TIME(5'b00011),
    .RXBUF_ADDR_MODE("FAST"),
    .RXBUF_EIDLE_HI_CNT(4'b1000),
    .RXBUF_EIDLE_LO_CNT(4'b0000),
    .RXBUF_EN("TRUE"),
    .RXBUF_RESET_ON_CB_CHANGE("TRUE"),
    .RXBUF_RESET_ON_COMMAALIGN("FALSE"),
    .RXBUF_RESET_ON_EIDLE("FALSE"),
    .RXBUF_RESET_ON_RATE_CHANGE("TRUE"),
    .RXBUF_THRESH_OVFLW(57),
    .RXBUF_THRESH_OVRD("TRUE"),
    .RXBUF_THRESH_UNDFLW(3),
    .RXCDRFREQRESET_TIME(5'b00001),
    .RXCDRPHRESET_TIME(5'b00001),
    .RXCDR_CFG0(16'h0000),
    .RXCDR_CFG0_GEN3(16'h0000),
    .RXCDR_CFG1(16'h0000),
    .RXCDR_CFG1_GEN3(16'h0000),
    .RXCDR_CFG2(16'h0756),
    .RXCDR_CFG2_GEN3(16'h0756),
    .RXCDR_CFG3(16'h0000),
    .RXCDR_CFG3_GEN3(16'h0000),
    .RXCDR_CFG4(16'h0000),
    .RXCDR_CFG4_GEN3(16'h0000),
    .RXCDR_CFG5(16'h0000),
    .RXCDR_CFG5_GEN3(16'h0000),
    .RXCDR_FR_RESET_ON_EIDLE(1'b0),
    .RXCDR_HOLD_DURING_EIDLE(1'b0),
    .RXCDR_LOCK_CFG0(16'h4480),
    .RXCDR_LOCK_CFG1(16'h5FFF),
    .RXCDR_LOCK_CFG2(16'h77C3),
    .RXCDR_PH_RESET_ON_EIDLE(1'b0),
    .RXCFOK_CFG0(16'h4000),
    .RXCFOK_CFG1(16'h0065),
    .RXCFOK_CFG2(16'h002E),
    .RXDFELPMRESET_TIME(7'b0001111),
    .RXDFELPM_KL_CFG0(16'h0000),
    .RXDFELPM_KL_CFG1(16'h0002),
    .RXDFELPM_KL_CFG2(16'h0000),
    .RXDFE_CFG0(16'h0A00),
    .RXDFE_CFG1(16'h0000),
    .RXDFE_GC_CFG0(16'h0000),
    .RXDFE_GC_CFG1(16'h7870),
    .RXDFE_GC_CFG2(16'h0000),
    .RXDFE_H2_CFG0(16'h0000),
    .RXDFE_H2_CFG1(16'h0000),
    .RXDFE_H3_CFG0(16'h4000),
    .RXDFE_H3_CFG1(16'h0000),
    .RXDFE_H4_CFG0(16'h2000),
    .RXDFE_H4_CFG1(16'h0003),
    .RXDFE_H5_CFG0(16'h2000),
    .RXDFE_H5_CFG1(16'h0003),
    .RXDFE_H6_CFG0(16'h2000),
    .RXDFE_H6_CFG1(16'h0000),
    .RXDFE_H7_CFG0(16'h2000),
    .RXDFE_H7_CFG1(16'h0000),
    .RXDFE_H8_CFG0(16'h2000),
    .RXDFE_H8_CFG1(16'h0000),
    .RXDFE_H9_CFG0(16'h2000),
    .RXDFE_H9_CFG1(16'h0000),
    .RXDFE_HA_CFG0(16'h2000),
    .RXDFE_HA_CFG1(16'h0000),
    .RXDFE_HB_CFG0(16'h2000),
    .RXDFE_HB_CFG1(16'h0000),
    .RXDFE_HC_CFG0(16'h0000),
    .RXDFE_HC_CFG1(16'h0000),
    .RXDFE_HD_CFG0(16'h0000),
    .RXDFE_HD_CFG1(16'h0000),
    .RXDFE_HE_CFG0(16'h0000),
    .RXDFE_HE_CFG1(16'h0000),
    .RXDFE_HF_CFG0(16'h0000),
    .RXDFE_HF_CFG1(16'h0000),
    .RXDFE_OS_CFG0(16'h8000),
    .RXDFE_OS_CFG1(16'h0000),
    .RXDFE_UT_CFG0(16'h8000),
    .RXDFE_UT_CFG1(16'h0003),
    .RXDFE_VP_CFG0(16'hAA00),
    .RXDFE_VP_CFG1(16'h0033),
    .RXDLY_CFG(16'h001F),
    .RXDLY_LCFG(16'h0030),
    .RXELECIDLE_CFG("Sigcfg_4"),
    .RXGBOX_FIFO_INIT_RD_ADDR(4),
    .RXGEARBOX_EN("FALSE"),
    .RXISCANRESET_TIME(5'b00001),
    .RXLPM_CFG(16'h0000),
    .RXLPM_GC_CFG(16'h0000),
    .RXLPM_KH_CFG0(16'h0000),
    .RXLPM_KH_CFG1(16'h0002),
    .RXLPM_OS_CFG0(16'h8000),
    .RXLPM_OS_CFG1(16'h0002),
    .RXOOB_CFG(9'b000000110),
    .RXOOB_CLK_CFG("PMA"),
    .RXOSCALRESET_TIME(5'b00011),
    .RXOUT_DIV(2),
    .RXPCSRESET_TIME(5'b00011),
    .RXPHBEACON_CFG(16'h0000),
    .RXPHDLY_CFG(16'h2020),
    .RXPHSAMP_CFG(16'h2100),
    .RXPHSLIP_CFG(16'h6622),
    .RXPH_MONITOR_SEL(5'b00000),
    .RXPI_CFG0(2'b00),
    .RXPI_CFG1(2'b00),
    .RXPI_CFG2(2'b00),
    .RXPI_CFG3(2'b00),
    .RXPI_CFG4(1'b0),
    .RXPI_CFG5(1'b0),
    .RXPI_CFG6(3'b000),
    .RXPI_LPM(1'b0),
    .RXPI_VREFSEL(1'b0),
    .RXPMACLK_SEL("DATA"),
    .RXPMARESET_TIME(5'b00011),
    .RXPRBS_ERR_LOOPBACK(1'b0),
    .RXPRBS_LINKACQ_CNT(15),
    .RXSLIDE_AUTO_WAIT(7),
    .RXSLIDE_MODE("OFF"),
    .RXSYNC_MULTILANE(1'b1),
    .RXSYNC_OVRD(1'b0),
    .RXSYNC_SKIP_DA(1'b0),
    .RX_AFE_CM_EN(1'b0),
    .RX_BIAS_CFG0(16'h0AB4),
    .RX_BUFFER_CFG(6'b000000),
    .RX_CAPFF_SARC_ENB(1'b0),
    .RX_CLK25_DIV(15),
    .RX_CLKMUX_EN(1'b1),
    .RX_CLK_SLIP_OVRD(5'b00000),
    .RX_CM_BUF_CFG(4'b1010),
    .RX_CM_BUF_PD(1'b0),
    .RX_CM_SEL(2'b11),
    .RX_CM_TRIM(4'b1010),
    .RX_CTLE3_LPF(8'b00000001),
    .RX_DATA_WIDTH(40),
    .RX_DDI_SEL(6'b000000),
    .RX_DEFER_RESET_BUF_EN("TRUE"),
    .RX_DFELPM_CFG0(4'b0110),
    .RX_DFELPM_CFG1(1'b1),
    .RX_DFELPM_KLKH_AGC_STUP_EN(1'b1),
    .RX_DFE_AGC_CFG0(2'b10),
    .RX_DFE_AGC_CFG1(3'b100),
    .RX_DFE_KL_LPM_KH_CFG0(2'b01),
    .RX_DFE_KL_LPM_KH_CFG1(3'b100),
    .RX_DFE_KL_LPM_KL_CFG0(2'b01),
    .RX_DFE_KL_LPM_KL_CFG1(3'b100),
    .RX_DFE_LPM_HOLD_DURING_EIDLE(1'b0),
    .RX_DISPERR_SEQ_MATCH("TRUE"),
    .RX_DIVRESET_TIME(5'b00001),
    .RX_EN_HI_LR(1'b0),
    .RX_EYESCAN_VS_CODE(7'b0000000),
    .RX_EYESCAN_VS_NEG_DIR(1'b0),
    .RX_EYESCAN_VS_RANGE(2'b00),
    .RX_EYESCAN_VS_UT_SIGN(1'b0),
    .RX_FABINT_USRCLK_FLOP(1'b0),
    .RX_INT_DATAWIDTH(1),
    .RX_PMA_POWER_SAVE(1'b0),
    .RX_PROGDIV_CFG(40.000000),
    .RX_SAMPLE_PERIOD(3'b111),
    .RX_SIG_VALID_DLY(11),
    .RX_SUM_DFETAPREP_EN(1'b0),
    .RX_SUM_IREF_TUNE(4'b0000),
    .RX_SUM_RES_CTRL(2'b00),
    .RX_SUM_VCMTUNE(4'b0000),
    .RX_SUM_VCM_OVWR(1'b0),
    .RX_SUM_VREF_TUNE(3'b000),
    .RX_TUNE_AFE_OS(2'b10),
    .RX_WIDEMODE_CDR(1'b0),
    .RX_XCLK_SEL("RXDES"),
    .SAS_MAX_COM(64),
    .SAS_MIN_COM(36),
    .SATA_BURST_SEQ_LEN(4'b1111),
    .SATA_BURST_VAL(3'b100),
    .SATA_CPLL_CFG("VCO_3000MHZ"),
    .SATA_EIDLE_VAL(3'b100),
    .SATA_MAX_BURST(8),
    .SATA_MAX_INIT(21),
    .SATA_MAX_WAKE(7),
    .SATA_MIN_BURST(4),
    .SATA_MIN_INIT(12),
    .SATA_MIN_WAKE(4),
    .SHOW_REALIGN_COMMA("TRUE"),
    .SIM_RECEIVER_DETECT_PASS("TRUE"),
    .SIM_RESET_SPEEDUP("TRUE"),
    .SIM_TX_EIDLE_DRIVE_LEVEL(1'b0),
    .SIM_VERSION(2),
    .TAPDLY_SET_TX(2'h0),
    .TEMPERATUR_PAR(4'b0010),
    .TERM_RCAL_CFG(15'b100001000010000),
    .TERM_RCAL_OVRD(3'b000),
    .TRANS_TIME_RATE(8'h0E),
    .TST_RSV0(8'h00),
    .TST_RSV1(8'h00),
    .TXBUF_EN("TRUE"),
    .TXBUF_RESET_ON_RATE_CHANGE("TRUE"),
    .TXDLY_CFG(16'h0009),
    .TXDLY_LCFG(16'h0050),
    .TXDRVBIAS_N(4'b1010),
    .TXDRVBIAS_P(4'b1010),
    .TXFIFO_ADDR_CFG("LOW"),
    .TXGBOX_FIFO_INIT_RD_ADDR(4),
    .TXGEARBOX_EN("FALSE"),
    .TXOUT_DIV(2),
    .TXPCSRESET_TIME(5'b00011),
    .TXPHDLY_CFG0(16'h2020),
    .TXPHDLY_CFG1(16'h00D5),
    .TXPH_CFG(16'h0980),
    .TXPH_MONITOR_SEL(5'b00000),
    .TXPI_CFG0(2'b00),
    .TXPI_CFG1(2'b00),
    .TXPI_CFG2(2'b00),
    .TXPI_CFG3(1'b0),
    .TXPI_CFG4(1'b0),
    .TXPI_CFG5(3'b000),
    .TXPI_GRAY_SEL(1'b0),
    .TXPI_INVSTROBE_SEL(1'b0),
    .TXPI_LPM(1'b0),
    .TXPI_PPMCLK_SEL("TXUSRCLK2"),
    .TXPI_PPM_CFG(8'b00000000),
    .TXPI_SYNFREQ_PPM(3'b001),
    .TXPI_VREFSEL(1'b0),
    .TXPMARESET_TIME(5'b00011),
    .TXSYNC_MULTILANE(1'b1),
    .TXSYNC_OVRD(1'b0),
    .TXSYNC_SKIP_DA(1'b0),
    .TX_CLK25_DIV(15),
    .TX_CLKMUX_EN(1'b1),
    .TX_DATA_WIDTH(40),
    .TX_DCD_CFG(6'b000010),
    .TX_DCD_EN(1'b0),
    .TX_DEEMPH0(6'b000000),
    .TX_DEEMPH1(6'b000000),
    .TX_DIVRESET_TIME(5'b00001),
    .TX_DRIVE_MODE("DIRECT"),
    .TX_EIDLE_ASSERT_DELAY(3'b100),
    .TX_EIDLE_DEASSERT_DELAY(3'b011),
    .TX_EML_PHI_TUNE(1'b0),
    .TX_FABINT_USRCLK_FLOP(1'b0),
    .TX_IDLE_DATA_ZERO(1'b0),
    .TX_INT_DATAWIDTH(1),
    .TX_LOOPBACK_DRIVE_HIZ("FALSE"),
    .TX_MAINCURSOR_SEL(1'b0),
    .TX_MARGIN_FULL_0(7'b1001111),
    .TX_MARGIN_FULL_1(7'b1001110),
    .TX_MARGIN_FULL_2(7'b1001100),
    .TX_MARGIN_FULL_3(7'b1001010),
    .TX_MARGIN_FULL_4(7'b1001000),
    .TX_MARGIN_LOW_0(7'b1000110),
    .TX_MARGIN_LOW_1(7'b1000101),
    .TX_MARGIN_LOW_2(7'b1000011),
    .TX_MARGIN_LOW_3(7'b1000010),
    .TX_MARGIN_LOW_4(7'b1000000),
    .TX_MODE_SEL(3'b000),
    .TX_PMADATA_OPT(1'b0),
    .TX_PMA_POWER_SAVE(1'b0),
    .TX_PROGCLK_SEL("PREPI"),
    .TX_PROGDIV_CFG(40.000000),
    .TX_QPI_STATUS_EN(1'b0),
    .TX_RXDETECT_CFG(14'h0032),
    .TX_RXDETECT_REF(3'b100),
    .TX_SAMPLE_PERIOD(3'b111),
    .TX_SARC_LPBK_ENB(1'b0),
    .TX_XCLK_SEL("TXOUT"),
    .USE_PCS_CLK_PHASE_SEL(1'b0),
    .WB_MODE(2'b00)) 
     \gthe3_channel_gen.gen_gthe3_channel_inst[1].GTHE3_CHANNEL_PRIM_INST 
       (.BUFGTCE(bufgtce_out[5:3]),
        .BUFGTCEMASK(bufgtcemask_out[5:3]),
        .BUFGTDIV(bufgtdiv_out[17:9]),
        .BUFGTRESET(bufgtreset_out[5:3]),
        .BUFGTRSTMASK(bufgtrstmask_out[5:3]),
        .CFGRESET(cfgreset_in[1]),
        .CLKRSVD0(clkrsvd0_in[1]),
        .CLKRSVD1(clkrsvd1_in[1]),
        .CPLLFBCLKLOST(cpllfbclklost_out[1]),
        .CPLLLOCK(cplllock_out[1]),
        .CPLLLOCKDETCLK(cplllockdetclk_in[1]),
        .CPLLLOCKEN(cplllocken_in[1]),
        .CPLLPD(cpllpd_in[1]),
        .CPLLREFCLKLOST(cpllrefclklost_out[1]),
        .CPLLREFCLKSEL(cpllrefclksel_in[5:3]),
        .CPLLRESET(cpllreset_in[1]),
        .DMONFIFORESET(dmonfiforeset_in[1]),
        .DMONITORCLK(dmonitorclk_in[1]),
        .DMONITOROUT(dmonitorout_out[33:17]),
        .DRPADDR(drpaddr_in[17:9]),
        .DRPCLK(drpclk_in[1]),
        .DRPDI(drpdi_in[31:16]),
        .DRPDO(drpdo_out[31:16]),
        .DRPEN(drpen_in[1]),
        .DRPRDY(drprdy_out[1]),
        .DRPWE(drpwe_in[1]),
        .EVODDPHICALDONE(evoddphicaldone_in[1]),
        .EVODDPHICALSTART(evoddphicalstart_in[1]),
        .EVODDPHIDRDEN(evoddphidrden_in[1]),
        .EVODDPHIDWREN(evoddphidwren_in[1]),
        .EVODDPHIXRDEN(evoddphixrden_in[1]),
        .EVODDPHIXWREN(evoddphixwren_in[1]),
        .EYESCANDATAERROR(eyescandataerror_out[1]),
        .EYESCANMODE(eyescanmode_in[1]),
        .EYESCANRESET(eyescanreset_in[1]),
        .EYESCANTRIGGER(eyescantrigger_in[1]),
        .GTGREFCLK(gtgrefclk_in[1]),
        .GTHRXN(gthrxn_in[1]),
        .GTHRXP(gthrxp_in[1]),
        .GTHTXN(gthtxn_out[1]),
        .GTHTXP(gthtxp_out[1]),
        .GTNORTHREFCLK0(gtnorthrefclk0_in[1]),
        .GTNORTHREFCLK1(gtnorthrefclk1_in[1]),
        .GTPOWERGOOD(gtpowergood_out[1]),
        .GTREFCLK0(gtrefclk0_in[1]),
        .GTREFCLK1(gtrefclk1_in[1]),
        .GTREFCLKMONITOR(gtrefclkmonitor_out[1]),
        .GTRESETSEL(gtresetsel_in[1]),
        .GTRSVD(gtrsvd_in[31:16]),
        .GTRXRESET(GTHE3_CHANNEL_GTRXRESET),
        .GTSOUTHREFCLK0(gtsouthrefclk0_in[1]),
        .GTSOUTHREFCLK1(gtsouthrefclk1_in[1]),
        .GTTXRESET(GTHE3_CHANNEL_GTTXRESET),
        .LOOPBACK(loopback_in[5:3]),
        .LPBKRXTXSEREN(lpbkrxtxseren_in[1]),
        .LPBKTXRXSEREN(lpbktxrxseren_in[1]),
        .PCIEEQRXEQADAPTDONE(pcieeqrxeqadaptdone_in[1]),
        .PCIERATEGEN3(pcierategen3_out[1]),
        .PCIERATEIDLE(pcierateidle_out[1]),
        .PCIERATEQPLLPD(pcierateqpllpd_out[3:2]),
        .PCIERATEQPLLRESET(pcierateqpllreset_out[3:2]),
        .PCIERSTIDLE(pcierstidle_in[1]),
        .PCIERSTTXSYNCSTART(pciersttxsyncstart_in[1]),
        .PCIESYNCTXSYNCDONE(pciesynctxsyncdone_out[1]),
        .PCIEUSERGEN3RDY(pcieusergen3rdy_out[1]),
        .PCIEUSERPHYSTATUSRST(pcieuserphystatusrst_out[1]),
        .PCIEUSERRATEDONE(pcieuserratedone_in[1]),
        .PCIEUSERRATESTART(pcieuserratestart_out[1]),
        .PCSRSVDIN(pcsrsvdin_in[31:16]),
        .PCSRSVDIN2(pcsrsvdin2_in[9:5]),
        .PCSRSVDOUT(pcsrsvdout_out[23:12]),
        .PHYSTATUS(phystatus_out[1]),
        .PINRSRVDAS(pinrsrvdas_out[15:8]),
        .PMARSVDIN(pmarsvdin_in[9:5]),
        .QPLL0CLK(qpll0outclk_out),
        .QPLL0REFCLK(qpll0outrefclk_out),
        .QPLL1CLK(qpll1outclk_out),
        .QPLL1REFCLK(qpll1outrefclk_out),
        .RESETEXCEPTION(resetexception_out[1]),
        .RESETOVRD(resetovrd_in[1]),
        .RSTCLKENTX(rstclkentx_in[1]),
        .RX8B10BEN(rx8b10ben_in[1]),
        .RXBUFRESET(rxbufreset_in[1]),
        .RXBUFSTATUS(rxbufstatus_out[5:3]),
        .RXBYTEISALIGNED(rxbyteisaligned_out[1]),
        .RXBYTEREALIGN(rxbyterealign_out[1]),
        .RXCDRFREQRESET(rxcdrfreqreset_in[1]),
        .RXCDRHOLD(rxcdrhold_in[1]),
        .RXCDRLOCK(rxcdrlock_out[1]),
        .RXCDROVRDEN(rxcdrovrden_in[1]),
        .RXCDRPHDONE(rxcdrphdone_out[1]),
        .RXCDRRESET(rxcdrreset_in[1]),
        .RXCDRRESETRSV(rxcdrresetrsv_in[1]),
        .RXCHANBONDSEQ(rxchanbondseq_out[1]),
        .RXCHANISALIGNED(rxchanisaligned_out[1]),
        .RXCHANREALIGN(rxchanrealign_out[1]),
        .RXCHBONDEN(rxchbonden_in[1]),
        .RXCHBONDI(rxchbondi_in[9:5]),
        .RXCHBONDLEVEL(rxchbondlevel_in[5:3]),
        .RXCHBONDMASTER(rxchbondmaster_in[1]),
        .RXCHBONDO(rxchbondo_out[9:5]),
        .RXCHBONDSLAVE(rxchbondslave_in[1]),
        .RXCLKCORCNT(rxclkcorcnt_out[3:2]),
        .RXCOMINITDET(rxcominitdet_out[1]),
        .RXCOMMADET(rxcommadet_out[1]),
        .RXCOMMADETEN(rxcommadeten_in[1]),
        .RXCOMSASDET(rxcomsasdet_out[1]),
        .RXCOMWAKEDET(rxcomwakedet_out[1]),
        .RXCTRL0(rxctrl0_out[31:16]),
        .RXCTRL1(rxctrl1_out[31:16]),
        .RXCTRL2(rxctrl2_out[15:8]),
        .RXCTRL3(rxctrl3_out[15:8]),
        .RXDATA(rxdata_out[255:128]),
        .RXDATAEXTENDRSVD(rxdataextendrsvd_out[15:8]),
        .RXDATAVALID(rxdatavalid_out[3:2]),
        .RXDFEAGCCTRL(rxdfeagcctrl_in[3:2]),
        .RXDFEAGCHOLD(rxdfeagchold_in[1]),
        .RXDFEAGCOVRDEN(rxdfeagcovrden_in[1]),
        .RXDFELFHOLD(rxdfelfhold_in[1]),
        .RXDFELFOVRDEN(rxdfelfovrden_in[1]),
        .RXDFELPMRESET(rxdfelpmreset_in[1]),
        .RXDFETAP10HOLD(rxdfetap10hold_in[1]),
        .RXDFETAP10OVRDEN(rxdfetap10ovrden_in[1]),
        .RXDFETAP11HOLD(rxdfetap11hold_in[1]),
        .RXDFETAP11OVRDEN(rxdfetap11ovrden_in[1]),
        .RXDFETAP12HOLD(rxdfetap12hold_in[1]),
        .RXDFETAP12OVRDEN(rxdfetap12ovrden_in[1]),
        .RXDFETAP13HOLD(rxdfetap13hold_in[1]),
        .RXDFETAP13OVRDEN(rxdfetap13ovrden_in[1]),
        .RXDFETAP14HOLD(rxdfetap14hold_in[1]),
        .RXDFETAP14OVRDEN(rxdfetap14ovrden_in[1]),
        .RXDFETAP15HOLD(rxdfetap15hold_in[1]),
        .RXDFETAP15OVRDEN(rxdfetap15ovrden_in[1]),
        .RXDFETAP2HOLD(rxdfetap2hold_in[1]),
        .RXDFETAP2OVRDEN(rxdfetap2ovrden_in[1]),
        .RXDFETAP3HOLD(rxdfetap3hold_in[1]),
        .RXDFETAP3OVRDEN(rxdfetap3ovrden_in[1]),
        .RXDFETAP4HOLD(rxdfetap4hold_in[1]),
        .RXDFETAP4OVRDEN(rxdfetap4ovrden_in[1]),
        .RXDFETAP5HOLD(rxdfetap5hold_in[1]),
        .RXDFETAP5OVRDEN(rxdfetap5ovrden_in[1]),
        .RXDFETAP6HOLD(rxdfetap6hold_in[1]),
        .RXDFETAP6OVRDEN(rxdfetap6ovrden_in[1]),
        .RXDFETAP7HOLD(rxdfetap7hold_in[1]),
        .RXDFETAP7OVRDEN(rxdfetap7ovrden_in[1]),
        .RXDFETAP8HOLD(rxdfetap8hold_in[1]),
        .RXDFETAP8OVRDEN(rxdfetap8ovrden_in[1]),
        .RXDFETAP9HOLD(rxdfetap9hold_in[1]),
        .RXDFETAP9OVRDEN(rxdfetap9ovrden_in[1]),
        .RXDFEUTHOLD(rxdfeuthold_in[1]),
        .RXDFEUTOVRDEN(rxdfeutovrden_in[1]),
        .RXDFEVPHOLD(rxdfevphold_in[1]),
        .RXDFEVPOVRDEN(rxdfevpovrden_in[1]),
        .RXDFEVSEN(rxdfevsen_in[1]),
        .RXDFEXYDEN(rxdfexyden_in[1]),
        .RXDLYBYPASS(rxdlybypass_in[1]),
        .RXDLYEN(rxdlyen_in[1]),
        .RXDLYOVRDEN(rxdlyovrden_in[1]),
        .RXDLYSRESET(rxdlysreset_in[1]),
        .RXDLYSRESETDONE(rxdlysresetdone_out[1]),
        .RXELECIDLE(rxelecidle_out[1]),
        .RXELECIDLEMODE(rxelecidlemode_in[3:2]),
        .RXGEARBOXSLIP(rxgearboxslip_in[1]),
        .RXHEADER(rxheader_out[11:6]),
        .RXHEADERVALID(rxheadervalid_out[3:2]),
        .RXLATCLK(rxlatclk_in[1]),
        .RXLPMEN(rxlpmen_in[1]),
        .RXLPMGCHOLD(rxlpmgchold_in[1]),
        .RXLPMGCOVRDEN(rxlpmgcovrden_in[1]),
        .RXLPMHFHOLD(rxlpmhfhold_in[1]),
        .RXLPMHFOVRDEN(rxlpmhfovrden_in[1]),
        .RXLPMLFHOLD(rxlpmlfhold_in[1]),
        .RXLPMLFKLOVRDEN(rxlpmlfklovrden_in[1]),
        .RXLPMOSHOLD(rxlpmoshold_in[1]),
        .RXLPMOSOVRDEN(rxlpmosovrden_in[1]),
        .RXMCOMMAALIGNEN(rxmcommaalignen_in[1]),
        .RXMONITOROUT(rxmonitorout_out[13:7]),
        .RXMONITORSEL(rxmonitorsel_in[3:2]),
        .RXOOBRESET(rxoobreset_in[1]),
        .RXOSCALRESET(rxoscalreset_in[1]),
        .RXOSHOLD(rxoshold_in[1]),
        .RXOSINTCFG(rxosintcfg_in[7:4]),
        .RXOSINTDONE(rxosintdone_out[1]),
        .RXOSINTEN(rxosinten_in[1]),
        .RXOSINTHOLD(rxosinthold_in[1]),
        .RXOSINTOVRDEN(rxosintovrden_in[1]),
        .RXOSINTSTARTED(rxosintstarted_out[1]),
        .RXOSINTSTROBE(rxosintstrobe_in[1]),
        .RXOSINTSTROBEDONE(rxosintstrobedone_out[1]),
        .RXOSINTSTROBESTARTED(rxosintstrobestarted_out[1]),
        .RXOSINTTESTOVRDEN(rxosinttestovrden_in[1]),
        .RXOSOVRDEN(rxosovrden_in[1]),
        .RXOUTCLK(rxoutclk_out[1]),
        .RXOUTCLKFABRIC(rxoutclkfabric_out[1]),
        .RXOUTCLKPCS(rxoutclkpcs_out[1]),
        .RXOUTCLKSEL(rxoutclksel_in[5:3]),
        .RXPCOMMAALIGNEN(rxpcommaalignen_in[1]),
        .RXPCSRESET(rxpcsreset_in[1]),
        .RXPD(rxpd_in[3:2]),
        .RXPHALIGN(rxphalign_in[1]),
        .RXPHALIGNDONE(rxphaligndone_out[1]),
        .RXPHALIGNEN(rxphalignen_in[1]),
        .RXPHALIGNERR(rxphalignerr_out[1]),
        .RXPHDLYPD(rxphdlypd_in[1]),
        .RXPHDLYRESET(rxphdlyreset_in[1]),
        .RXPHOVRDEN(rxphovrden_in[1]),
        .RXPLLCLKSEL(rxpllclksel_in[3:2]),
        .RXPMARESET(rxpmareset_in[1]),
        .RXPMARESETDONE(rxpmaresetdone_out[1]),
        .RXPOLARITY(rxpolarity_in[1]),
        .RXPRBSCNTRESET(rxprbscntreset_in[1]),
        .RXPRBSERR(rxprbserr_out[1]),
        .RXPRBSLOCKED(rxprbslocked_out[1]),
        .RXPRBSSEL(rxprbssel_in[7:4]),
        .RXPRGDIVRESETDONE(rxprgdivresetdone_out[1]),
        .RXPROGDIVRESET(GTHE3_CHANNEL_RXPROGDIVRESET),
        .RXQPIEN(rxqpien_in[1]),
        .RXQPISENN(rxqpisenn_out[1]),
        .RXQPISENP(rxqpisenp_out[1]),
        .RXRATE(rxrate_in[5:3]),
        .RXRATEDONE(rxratedone_out[1]),
        .RXRATEMODE(rxratemode_in[1]),
        .RXRECCLKOUT(rxrecclkout_out[1]),
        .RXRESETDONE(rxresetdone_out[1]),
        .RXSLIDE(rxslide_in[1]),
        .RXSLIDERDY(rxsliderdy_out[1]),
        .RXSLIPDONE(rxslipdone_out[1]),
        .RXSLIPOUTCLK(rxslipoutclk_in[1]),
        .RXSLIPOUTCLKRDY(rxslipoutclkrdy_out[1]),
        .RXSLIPPMA(rxslippma_in[1]),
        .RXSLIPPMARDY(rxslippmardy_out[1]),
        .RXSTARTOFSEQ(rxstartofseq_out[3:2]),
        .RXSTATUS(rxstatus_out[5:3]),
        .RXSYNCALLIN(rxsyncallin_in[1]),
        .RXSYNCDONE(rxsyncdone_out[1]),
        .RXSYNCIN(rxsyncin_in[1]),
        .RXSYNCMODE(rxsyncmode_in[1]),
        .RXSYNCOUT(rxsyncout_out[1]),
        .RXSYSCLKSEL(rxsysclksel_in[3:2]),
        .RXUSERRDY(GTHE3_CHANNEL_RXUSERRDY),
        .RXUSRCLK(rxusrclk_in[1]),
        .RXUSRCLK2(rxusrclk2_in[1]),
        .RXVALID(rxvalid_out[1]),
        .SIGVALIDCLK(sigvalidclk_in[1]),
        .TSTIN({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .TX8B10BBYPASS(tx8b10bbypass_in[15:8]),
        .TX8B10BEN(tx8b10ben_in[1]),
        .TXBUFDIFFCTRL(txbufdiffctrl_in[5:3]),
        .TXBUFSTATUS(txbufstatus_out[3:2]),
        .TXCOMFINISH(txcomfinish_out[1]),
        .TXCOMINIT(txcominit_in[1]),
        .TXCOMSAS(txcomsas_in[1]),
        .TXCOMWAKE(txcomwake_in[1]),
        .TXCTRL0(txctrl0_in[31:16]),
        .TXCTRL1(txctrl1_in[31:16]),
        .TXCTRL2(txctrl2_in[15:8]),
        .TXDATA({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,gtwiz_userdata_tx_in[63:32]}),
        .TXDATAEXTENDRSVD(txdataextendrsvd_in[15:8]),
        .TXDEEMPH(txdeemph_in[1]),
        .TXDETECTRX(txdetectrx_in[1]),
        .TXDIFFCTRL(txdiffctrl_in[7:4]),
        .TXDIFFPD(txdiffpd_in[1]),
        .TXDLYBYPASS(txdlybypass_in[1]),
        .TXDLYEN(txdlyen_in[1]),
        .TXDLYHOLD(txdlyhold_in[1]),
        .TXDLYOVRDEN(txdlyovrden_in[1]),
        .TXDLYSRESET(txdlysreset_in[1]),
        .TXDLYSRESETDONE(txdlysresetdone_out[1]),
        .TXDLYUPDOWN(txdlyupdown_in[1]),
        .TXELECIDLE(txelecidle_in[1]),
        .TXHEADER(txheader_in[11:6]),
        .TXINHIBIT(txinhibit_in[1]),
        .TXLATCLK(txlatclk_in[1]),
        .TXMAINCURSOR(txmaincursor_in[13:7]),
        .TXMARGIN(txmargin_in[5:3]),
        .TXOUTCLK(txoutclk_out[1]),
        .TXOUTCLKFABRIC(txoutclkfabric_out[1]),
        .TXOUTCLKPCS(txoutclkpcs_out[1]),
        .TXOUTCLKSEL(txoutclksel_in[5:3]),
        .TXPCSRESET(txpcsreset_in[1]),
        .TXPD(txpd_in[3:2]),
        .TXPDELECIDLEMODE(txpdelecidlemode_in[1]),
        .TXPHALIGN(txphalign_in[1]),
        .TXPHALIGNDONE(txphaligndone_out[1]),
        .TXPHALIGNEN(txphalignen_in[1]),
        .TXPHDLYPD(txphdlypd_in[1]),
        .TXPHDLYRESET(txphdlyreset_in[1]),
        .TXPHDLYTSTCLK(txphdlytstclk_in[1]),
        .TXPHINIT(txphinit_in[1]),
        .TXPHINITDONE(txphinitdone_out[1]),
        .TXPHOVRDEN(txphovrden_in[1]),
        .TXPIPPMEN(txpippmen_in[1]),
        .TXPIPPMOVRDEN(txpippmovrden_in[1]),
        .TXPIPPMPD(txpippmpd_in[1]),
        .TXPIPPMSEL(txpippmsel_in[1]),
        .TXPIPPMSTEPSIZE(txpippmstepsize_in[9:5]),
        .TXPISOPD(txpisopd_in[1]),
        .TXPLLCLKSEL(txpllclksel_in[3:2]),
        .TXPMARESET(txpmareset_in[1]),
        .TXPMARESETDONE(txpmaresetdone_out[1]),
        .TXPOLARITY(txpolarity_in[1]),
        .TXPOSTCURSOR(txpostcursor_in[9:5]),
        .TXPOSTCURSORINV(txpostcursorinv_in[1]),
        .TXPRBSFORCEERR(txprbsforceerr_in[1]),
        .TXPRBSSEL(txprbssel_in[7:4]),
        .TXPRECURSOR(txprecursor_in[9:5]),
        .TXPRECURSORINV(txprecursorinv_in[1]),
        .TXPRGDIVRESETDONE(txprgdivresetdone_out[1]),
        .TXPROGDIVRESET(GTHE3_CHANNEL_TXPROGDIVRESET),
        .TXQPIBIASEN(txqpibiasen_in[1]),
        .TXQPISENN(txqpisenn_out[1]),
        .TXQPISENP(txqpisenp_out[1]),
        .TXQPISTRONGPDOWN(txqpistrongpdown_in[1]),
        .TXQPIWEAKPUP(txqpiweakpup_in[1]),
        .TXRATE(txrate_in[5:3]),
        .TXRATEDONE(txratedone_out[1]),
        .TXRATEMODE(txratemode_in[1]),
        .TXRESETDONE(txresetdone_out[1]),
        .TXSEQUENCE(txsequence_in[13:7]),
        .TXSWING(txswing_in[1]),
        .TXSYNCALLIN(txsyncallin_in[1]),
        .TXSYNCDONE(txsyncdone_out[1]),
        .TXSYNCIN(txsyncin_in[1]),
        .TXSYNCMODE(txsyncmode_in[1]),
        .TXSYNCOUT(txsyncout_out[1]),
        .TXSYSCLKSEL(txsysclksel_in[3:2]),
        .TXUSERRDY(GTHE3_CHANNEL_TXUSERRDY),
        .TXUSRCLK(txusrclk_in[1]),
        .TXUSRCLK2(txusrclk2_in[1]));
LUT2 #(
    .INIT(4'h8)) 
     i_in_inferred_i_1
       (.I0(gtpowergood_out[0]),
        .I1(gtpowergood_out[1]),
        .O(O1));
LUT2 #(
    .INIT(4'h8)) 
     i_in_inferred_i_1__0
       (.I0(txresetdone_out[0]),
        .I1(txresetdone_out[1]),
        .O(O2));
LUT2 #(
    .INIT(4'h8)) 
     i_in_inferred_i_1__1
       (.I0(rxcdrlock_out[0]),
        .I1(rxcdrlock_out[1]),
        .O(O3));
LUT2 #(
    .INIT(4'h8)) 
     i_in_inferred_i_1__2
       (.I0(rxresetdone_out[0]),
        .I1(rxresetdone_out[1]),
        .O(O4));
endmodule

(* ORIG_REF_NAME = "gtwizard_ultrascale_v1_4_gthe3_common" *) 
module GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_gthe3_common
   (drprdy_common_out,
    qpll0fbclklost_out,
    O1,
    qpll0outclk_out,
    qpll0outrefclk_out,
    qpll0refclklost_out,
    qpll1fbclklost_out,
    qpll1lock_out,
    qpll1outclk_out,
    qpll1outrefclk_out,
    qpll1refclklost_out,
    refclkoutmonitor0_out,
    refclkoutmonitor1_out,
    drpdo_common_out,
    rxrecclk0_sel_out,
    rxrecclk1_sel_out,
    pmarsvdout0_out,
    pmarsvdout1_out,
    qplldmonitor0_out,
    qplldmonitor1_out,
    rst_in0,
    drpclk_common_in,
    drpen_common_in,
    drpwe_common_in,
    gtgrefclk0_in,
    gtgrefclk1_in,
    gtnorthrefclk00_in,
    gtnorthrefclk01_in,
    gtnorthrefclk10_in,
    gtnorthrefclk11_in,
    gtrefclk00_in,
    gtrefclk01_in,
    gtrefclk10_in,
    gtrefclk11_in,
    gtsouthrefclk00_in,
    gtsouthrefclk01_in,
    gtsouthrefclk10_in,
    gtsouthrefclk11_in,
    qpll0clkrsvd0_in,
    qpll0clkrsvd1_in,
    qpll0lockdetclk_in,
    qpll0locken_in,
    qpll0pd_in,
    gtwiz_reset_qpll0reset_out,
    qpll1clkrsvd0_in,
    qpll1clkrsvd1_in,
    qpll1lockdetclk_in,
    qpll1locken_in,
    qpll1pd_in,
    qpll1reset_in,
    drpdi_common_in,
    qpll0refclksel_in,
    qpll1refclksel_in,
    qpllrsvd2_in,
    qpllrsvd3_in,
    qpllrsvd1_in,
    qpllrsvd4_in,
    drpaddr_common_in);
  output [0:0]drprdy_common_out;
  output [0:0]qpll0fbclklost_out;
  output O1;
  output [0:0]qpll0outclk_out;
  output [0:0]qpll0outrefclk_out;
  output [0:0]qpll0refclklost_out;
  output [0:0]qpll1fbclklost_out;
  output [0:0]qpll1lock_out;
  output [0:0]qpll1outclk_out;
  output [0:0]qpll1outrefclk_out;
  output [0:0]qpll1refclklost_out;
  output [0:0]refclkoutmonitor0_out;
  output [0:0]refclkoutmonitor1_out;
  output [15:0]drpdo_common_out;
  output [1:0]rxrecclk0_sel_out;
  output [1:0]rxrecclk1_sel_out;
  output [7:0]pmarsvdout0_out;
  output [7:0]pmarsvdout1_out;
  output [7:0]qplldmonitor0_out;
  output [7:0]qplldmonitor1_out;
  output rst_in0;
  input [0:0]drpclk_common_in;
  input [0:0]drpen_common_in;
  input [0:0]drpwe_common_in;
  input [0:0]gtgrefclk0_in;
  input [0:0]gtgrefclk1_in;
  input [0:0]gtnorthrefclk00_in;
  input [0:0]gtnorthrefclk01_in;
  input [0:0]gtnorthrefclk10_in;
  input [0:0]gtnorthrefclk11_in;
  input [0:0]gtrefclk00_in;
  input [0:0]gtrefclk01_in;
  input [0:0]gtrefclk10_in;
  input [0:0]gtrefclk11_in;
  input [0:0]gtsouthrefclk00_in;
  input [0:0]gtsouthrefclk01_in;
  input [0:0]gtsouthrefclk10_in;
  input [0:0]gtsouthrefclk11_in;
  input [0:0]qpll0clkrsvd0_in;
  input [0:0]qpll0clkrsvd1_in;
  input [0:0]qpll0lockdetclk_in;
  input [0:0]qpll0locken_in;
  input [0:0]qpll0pd_in;
  input [0:0]gtwiz_reset_qpll0reset_out;
  input [0:0]qpll1clkrsvd0_in;
  input [0:0]qpll1clkrsvd1_in;
  input [0:0]qpll1lockdetclk_in;
  input [0:0]qpll1locken_in;
  input [0:0]qpll1pd_in;
  input [0:0]qpll1reset_in;
  input [15:0]drpdi_common_in;
  input [2:0]qpll0refclksel_in;
  input [2:0]qpll1refclksel_in;
  input [4:0]qpllrsvd2_in;
  input [4:0]qpllrsvd3_in;
  input [7:0]qpllrsvd1_in;
  input [7:0]qpllrsvd4_in;
  input [8:0]drpaddr_common_in;

  wire O1;
  wire [8:0]drpaddr_common_in;
  wire [0:0]drpclk_common_in;
  wire [15:0]drpdi_common_in;
  wire [15:0]drpdo_common_out;
  wire [0:0]drpen_common_in;
  wire [0:0]drprdy_common_out;
  wire [0:0]drpwe_common_in;
  wire [0:0]gtgrefclk0_in;
  wire [0:0]gtgrefclk1_in;
  wire [0:0]gtnorthrefclk00_in;
  wire [0:0]gtnorthrefclk01_in;
  wire [0:0]gtnorthrefclk10_in;
  wire [0:0]gtnorthrefclk11_in;
  wire [0:0]gtrefclk00_in;
  wire [0:0]gtrefclk01_in;
  wire [0:0]gtrefclk10_in;
  wire [0:0]gtrefclk11_in;
  wire [0:0]gtsouthrefclk00_in;
  wire [0:0]gtsouthrefclk01_in;
  wire [0:0]gtsouthrefclk10_in;
  wire [0:0]gtsouthrefclk11_in;
  wire [0:0]gtwiz_reset_qpll0reset_out;
  wire [7:0]pmarsvdout0_out;
  wire [7:0]pmarsvdout1_out;
  wire [0:0]qpll0clkrsvd0_in;
  wire [0:0]qpll0clkrsvd1_in;
  wire [0:0]qpll0fbclklost_out;
  wire [0:0]qpll0lockdetclk_in;
  wire [0:0]qpll0locken_in;
  wire [0:0]qpll0outclk_out;
  wire [0:0]qpll0outrefclk_out;
  wire [0:0]qpll0pd_in;
  wire [0:0]qpll0refclklost_out;
  wire [2:0]qpll0refclksel_in;
  wire [0:0]qpll1clkrsvd0_in;
  wire [0:0]qpll1clkrsvd1_in;
  wire [0:0]qpll1fbclklost_out;
  wire [0:0]qpll1lock_out;
  wire [0:0]qpll1lockdetclk_in;
  wire [0:0]qpll1locken_in;
  wire [0:0]qpll1outclk_out;
  wire [0:0]qpll1outrefclk_out;
  wire [0:0]qpll1pd_in;
  wire [0:0]qpll1refclklost_out;
  wire [2:0]qpll1refclksel_in;
  wire [0:0]qpll1reset_in;
  wire [7:0]qplldmonitor0_out;
  wire [7:0]qplldmonitor1_out;
  wire [7:0]qpllrsvd1_in;
  wire [4:0]qpllrsvd2_in;
  wire [4:0]qpllrsvd3_in;
  wire [7:0]qpllrsvd4_in;
  wire [0:0]refclkoutmonitor0_out;
  wire [0:0]refclkoutmonitor1_out;
  wire rst_in0;
  wire [1:0]rxrecclk0_sel_out;
  wire [1:0]rxrecclk1_sel_out;

(* BOX_TYPE = "PRIMITIVE" *) 
   GTHE3_COMMON #(
    .BIAS_CFG0(16'h0000),
    .BIAS_CFG1(16'h0000),
    .BIAS_CFG2(16'h0000),
    .BIAS_CFG3(16'h0040),
    .BIAS_CFG4(16'h0000),
    .BIAS_CFG_RSVD(10'b0000000000),
    .COMMON_CFG0(16'h0000),
    .COMMON_CFG1(16'h0000),
    .POR_CFG(16'h0004),
    .QPLL0_CFG0(16'h301C),
    .QPLL0_CFG1(16'h0018),
    .QPLL0_CFG1_G3(16'h0018),
    .QPLL0_CFG2(16'h0048),
    .QPLL0_CFG2_G3(16'h0048),
    .QPLL0_CFG3(16'h0120),
    .QPLL0_CFG4(16'h001B),
    .QPLL0_CP(10'b0000011111),
    .QPLL0_CP_G3(10'b1111111111),
    .QPLL0_FBDIV(40),
    .QPLL0_FBDIV_G3(80),
    .QPLL0_INIT_CFG0(16'h0000),
    .QPLL0_INIT_CFG1(8'h00),
    .QPLL0_LOCK_CFG(16'h25E8),
    .QPLL0_LOCK_CFG_G3(16'h25E8),
    .QPLL0_LPF(10'b1111111111),
    .QPLL0_LPF_G3(10'b0000010101),
    .QPLL0_REFCLK_DIV(1),
    .QPLL0_SDM_CFG0(16'b0000000000000000),
    .QPLL0_SDM_CFG1(16'b0000000000000000),
    .QPLL0_SDM_CFG2(16'b0000000000000000),
    .QPLL1_CFG0(16'h301C),
    .QPLL1_CFG1(16'h0018),
    .QPLL1_CFG1_G3(16'h0018),
    .QPLL1_CFG2(16'h0040),
    .QPLL1_CFG2_G3(16'h0040),
    .QPLL1_CFG3(16'h0120),
    .QPLL1_CFG4(16'h0009),
    .QPLL1_CP(10'b0000011111),
    .QPLL1_CP_G3(10'b1111111111),
    .QPLL1_FBDIV(66),
    .QPLL1_FBDIV_G3(80),
    .QPLL1_INIT_CFG0(16'h0000),
    .QPLL1_INIT_CFG1(8'h00),
    .QPLL1_LOCK_CFG(16'h25E8),
    .QPLL1_LOCK_CFG_G3(16'h25E8),
    .QPLL1_LPF(10'b1111111111),
    .QPLL1_LPF_G3(10'b0000010101),
    .QPLL1_REFCLK_DIV(1),
    .QPLL1_SDM_CFG0(16'b0000000000000000),
    .QPLL1_SDM_CFG1(16'b0000000000000000),
    .QPLL1_SDM_CFG2(16'b0000000000000000),
    .RSVD_ATTR0(16'h0000),
    .RSVD_ATTR1(16'h0000),
    .RSVD_ATTR2(16'h0000),
    .RSVD_ATTR3(16'h0000),
    .RXRECCLKOUT0_SEL(2'b00),
    .RXRECCLKOUT1_SEL(2'b00),
    .SARC_EN(1'b1),
    .SARC_SEL(1'b0),
    .SDM0DATA1_0(16'b0000000000000000),
    .SDM0DATA1_1(9'b000000000),
    .SDM0INITSEED0_0(16'b0000000000000000),
    .SDM0INITSEED0_1(9'b000000000),
    .SDM0_DATA_PIN_SEL(1'b0),
    .SDM0_WIDTH_PIN_SEL(1'b0),
    .SDM1DATA1_0(16'b0000000000000000),
    .SDM1DATA1_1(9'b000000000),
    .SDM1INITSEED0_0(16'b0000000000000000),
    .SDM1INITSEED0_1(9'b000000000),
    .SDM1_DATA_PIN_SEL(1'b0),
    .SDM1_WIDTH_PIN_SEL(1'b0),
    .SIM_RESET_SPEEDUP("TRUE"),
    .SIM_VERSION(2)) 
     \gthe3_common_gen.GTHE3_COMMON_PRIM_INST 
       (.BGBYPASSB(1'b1),
        .BGMONITORENB(1'b1),
        .BGPDB(1'b1),
        .BGRCALOVRD({1'b1,1'b1,1'b1,1'b1,1'b1}),
        .BGRCALOVRDENB(1'b1),
        .DRPADDR(drpaddr_common_in),
        .DRPCLK(drpclk_common_in),
        .DRPDI(drpdi_common_in),
        .DRPDO(drpdo_common_out),
        .DRPEN(drpen_common_in),
        .DRPRDY(drprdy_common_out),
        .DRPWE(drpwe_common_in),
        .GTGREFCLK0(gtgrefclk0_in),
        .GTGREFCLK1(gtgrefclk1_in),
        .GTNORTHREFCLK00(gtnorthrefclk00_in),
        .GTNORTHREFCLK01(gtnorthrefclk01_in),
        .GTNORTHREFCLK10(gtnorthrefclk10_in),
        .GTNORTHREFCLK11(gtnorthrefclk11_in),
        .GTREFCLK00(gtrefclk00_in),
        .GTREFCLK01(gtrefclk01_in),
        .GTREFCLK10(gtrefclk10_in),
        .GTREFCLK11(gtrefclk11_in),
        .GTSOUTHREFCLK00(gtsouthrefclk00_in),
        .GTSOUTHREFCLK01(gtsouthrefclk01_in),
        .GTSOUTHREFCLK10(gtsouthrefclk10_in),
        .GTSOUTHREFCLK11(gtsouthrefclk11_in),
        .PMARSVD0({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .PMARSVD1({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .PMARSVDOUT0(pmarsvdout0_out),
        .PMARSVDOUT1(pmarsvdout1_out),
        .QPLL0CLKRSVD0(qpll0clkrsvd0_in),
        .QPLL0CLKRSVD1(qpll0clkrsvd1_in),
        .QPLL0FBCLKLOST(qpll0fbclklost_out),
        .QPLL0LOCK(O1),
        .QPLL0LOCKDETCLK(qpll0lockdetclk_in),
        .QPLL0LOCKEN(qpll0locken_in),
        .QPLL0OUTCLK(qpll0outclk_out),
        .QPLL0OUTREFCLK(qpll0outrefclk_out),
        .QPLL0PD(qpll0pd_in),
        .QPLL0REFCLKLOST(qpll0refclklost_out),
        .QPLL0REFCLKSEL(qpll0refclksel_in),
        .QPLL0RESET(gtwiz_reset_qpll0reset_out),
        .QPLL1CLKRSVD0(qpll1clkrsvd0_in),
        .QPLL1CLKRSVD1(qpll1clkrsvd1_in),
        .QPLL1FBCLKLOST(qpll1fbclklost_out),
        .QPLL1LOCK(qpll1lock_out),
        .QPLL1LOCKDETCLK(qpll1lockdetclk_in),
        .QPLL1LOCKEN(qpll1locken_in),
        .QPLL1OUTCLK(qpll1outclk_out),
        .QPLL1OUTREFCLK(qpll1outrefclk_out),
        .QPLL1PD(qpll1pd_in),
        .QPLL1REFCLKLOST(qpll1refclklost_out),
        .QPLL1REFCLKSEL(qpll1refclksel_in),
        .QPLL1RESET(qpll1reset_in),
        .QPLLDMONITOR0(qplldmonitor0_out),
        .QPLLDMONITOR1(qplldmonitor1_out),
        .QPLLRSVD1(qpllrsvd1_in),
        .QPLLRSVD2(qpllrsvd2_in),
        .QPLLRSVD3(qpllrsvd3_in),
        .QPLLRSVD4(qpllrsvd4_in),
        .RCALENB(1'b1),
        .REFCLKOUTMONITOR0(refclkoutmonitor0_out),
        .REFCLKOUTMONITOR1(refclkoutmonitor1_out),
        .RXRECCLK0_SEL(rxrecclk0_sel_out),
        .RXRECCLK1_SEL(rxrecclk1_sel_out));
LUT1 #(
    .INIT(2'h1)) 
     rst_in_meta_i_1__4
       (.I0(O1),
        .O(rst_in0));
endmodule

(* ORIG_REF_NAME = "gtwizard_ultrascale_v1_4_gtwiz_reset" *) 
module GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_gtwiz_reset
   (GTHE3_CHANNEL_TXPROGDIVRESET,
    gtwiz_reset_tx_done_out,
    gtwiz_reset_rx_cdr_stable_out,
    GTHE3_CHANNEL_RXPROGDIVRESET,
    gtwiz_reset_rx_done_out,
    GTHE3_CHANNEL_TXUSERRDY,
    GTHE3_CHANNEL_RXUSERRDY,
    GTHE3_CHANNEL_GTTXRESET,
    GTHE3_CHANNEL_GTRXRESET,
    gtwiz_reset_qpll0reset_out,
    I1,
    gtwiz_userclk_tx_active_in,
    qpll0lock_out,
    I2,
    gtwiz_userclk_rx_active_in,
    I3,
    I4,
    gtwiz_reset_clk_freerun_in,
    gtwiz_reset_all_in,
    gtwiz_reset_tx_datapath_in,
    rst_in0,
    txusrclk2_in,
    rxusrclk2_in,
    gtwiz_reset_tx_pll_and_datapath_in,
    gtwiz_reset_rx_datapath_in,
    gtwiz_reset_rx_pll_and_datapath_in);
  output [0:0]GTHE3_CHANNEL_TXPROGDIVRESET;
  output [0:0]gtwiz_reset_tx_done_out;
  output [0:0]gtwiz_reset_rx_cdr_stable_out;
  output [0:0]GTHE3_CHANNEL_RXPROGDIVRESET;
  output [0:0]gtwiz_reset_rx_done_out;
  output [0:0]GTHE3_CHANNEL_TXUSERRDY;
  output [0:0]GTHE3_CHANNEL_RXUSERRDY;
  output [0:0]GTHE3_CHANNEL_GTTXRESET;
  output [0:0]GTHE3_CHANNEL_GTRXRESET;
  output [0:0]gtwiz_reset_qpll0reset_out;
  input I1;
  input [0:0]gtwiz_userclk_tx_active_in;
  input [0:0]qpll0lock_out;
  input I2;
  input [0:0]gtwiz_userclk_rx_active_in;
  input I3;
  input I4;
  input [0:0]gtwiz_reset_clk_freerun_in;
  input [0:0]gtwiz_reset_all_in;
  input [0:0]gtwiz_reset_tx_datapath_in;
  input rst_in0;
  input [0:0]txusrclk2_in;
  input [0:0]rxusrclk2_in;
  input [0:0]gtwiz_reset_tx_pll_and_datapath_in;
  input [0:0]gtwiz_reset_rx_datapath_in;
  input [0:0]gtwiz_reset_rx_pll_and_datapath_in;

  wire [0:0]GTHE3_CHANNEL_GTRXRESET;
  wire [0:0]GTHE3_CHANNEL_GTTXRESET;
  wire [0:0]GTHE3_CHANNEL_RXPROGDIVRESET;
  wire [0:0]GTHE3_CHANNEL_RXUSERRDY;
  wire [0:0]GTHE3_CHANNEL_TXPROGDIVRESET;
  wire [0:0]GTHE3_CHANNEL_TXUSERRDY;
  wire I1;
  wire I2;
  wire I3;
  wire I4;
  wire [0:0]gtwiz_reset_all_in;
  wire gtwiz_reset_all_sync;
  wire [0:0]gtwiz_reset_clk_freerun_in;
  wire gtwiz_reset_pllreset_rx_int;
  wire gtwiz_reset_pllreset_tx_int;
  wire [0:0]gtwiz_reset_qpll0reset_out;
  wire gtwiz_reset_rx_any_sync;
  wire [0:0]gtwiz_reset_rx_cdr_stable_out;
  wire gtwiz_reset_rx_datapath_dly;
  wire [0:0]gtwiz_reset_rx_datapath_in;
  wire gtwiz_reset_rx_datapath_sync;
  wire [0:0]gtwiz_reset_rx_done_out;
  wire gtwiz_reset_rx_pll_and_datapath_dly;
  wire [0:0]gtwiz_reset_rx_pll_and_datapath_in;
  wire gtwiz_reset_rx_pll_and_datapath_sync;
  wire gtwiz_reset_tx_any_sync;
  wire gtwiz_reset_tx_datapath_dly;
  wire [0:0]gtwiz_reset_tx_datapath_in;
  wire gtwiz_reset_tx_datapath_sync;
  wire gtwiz_reset_tx_done_int0;
  wire [0:0]gtwiz_reset_tx_done_out;
  wire [0:0]gtwiz_reset_tx_pll_and_datapath_in;
  wire gtwiz_reset_tx_pll_and_datapath_sync;
  wire gtwiz_reset_userclk_rx_active_sync;
  wire [0:0]gtwiz_userclk_rx_active_in;
  wire [0:0]gtwiz_userclk_tx_active_in;
  wire \n_0_FSM_sequential_sm_reset_all[0]_i_1 ;
  wire \n_0_FSM_sequential_sm_reset_all[1]_i_1 ;
  wire \n_0_FSM_sequential_sm_reset_all[2]_i_1 ;
  wire \n_0_FSM_sequential_sm_reset_all[2]_i_2 ;
  wire \n_0_FSM_sequential_sm_reset_all[3]_i_3 ;
(* RTL_KEEP = "yes" *)   wire \n_0_FSM_sequential_sm_reset_all_reg[0] ;
(* RTL_KEEP = "yes" *)   wire \n_0_FSM_sequential_sm_reset_all_reg[1] ;
(* RTL_KEEP = "yes" *)   wire \n_0_FSM_sequential_sm_reset_all_reg[2] ;
(* RTL_KEEP = "yes" *)   wire \n_0_FSM_sequential_sm_reset_all_reg[3] ;
  wire \n_0_FSM_sequential_sm_reset_rx[1]_i_2 ;
  wire \n_0_FSM_sequential_sm_reset_tx[2]_i_2 ;
  wire n_0_bit_synchronizer_gtpowergood_inst;
  wire n_0_bit_synchronizer_gtwiz_reset_tx_pll_and_datapath_dly_inst;
  wire n_0_bit_synchronizer_gtwiz_reset_userclk_tx_active_inst;
  wire n_0_bit_synchronizer_plllock_rx_inst;
  wire n_0_gtwiz_reset_rx_datapath_int_i_1;
  wire n_0_gtwiz_reset_rx_datapath_int_reg;
  wire n_0_gtwiz_reset_rx_done_int_reg;
  wire n_0_gtwiz_reset_rx_pll_and_datapath_int_i_1;
  wire n_0_gtwiz_reset_rx_pll_and_datapath_int_reg;
  wire n_0_gtwiz_reset_tx_done_int_reg;
  wire n_0_gtwiz_reset_tx_pll_and_datapath_int_i_1;
  wire n_0_gtwiz_reset_tx_pll_and_datapath_int_reg;
  wire n_0_sm_reset_all_timer_clr_i_1;
  wire n_0_sm_reset_all_timer_clr_i_2;
  wire n_0_sm_reset_all_timer_clr_reg;
  wire \n_0_sm_reset_all_timer_ctr[0]_i_1 ;
  wire \n_0_sm_reset_all_timer_ctr[1]_i_1 ;
  wire \n_0_sm_reset_all_timer_ctr[2]_i_1 ;
  wire \n_0_sm_reset_all_timer_ctr[2]_i_2 ;
  wire n_0_sm_reset_all_timer_sat_i_1;
  wire \n_0_sm_reset_rx_cdr_to_ctr[0]_i_3 ;
  wire \n_0_sm_reset_rx_cdr_to_ctr_reg[0]_i_2 ;
  wire \n_0_sm_reset_rx_cdr_to_ctr_reg[10]_i_1 ;
  wire \n_0_sm_reset_rx_cdr_to_ctr_reg[11]_i_1 ;
  wire \n_0_sm_reset_rx_cdr_to_ctr_reg[12]_i_1 ;
  wire \n_0_sm_reset_rx_cdr_to_ctr_reg[13]_i_1 ;
  wire \n_0_sm_reset_rx_cdr_to_ctr_reg[14]_i_1 ;
  wire \n_0_sm_reset_rx_cdr_to_ctr_reg[15]_i_1 ;
  wire \n_0_sm_reset_rx_cdr_to_ctr_reg[16]_i_1 ;
  wire \n_0_sm_reset_rx_cdr_to_ctr_reg[16]_i_2 ;
  wire \n_0_sm_reset_rx_cdr_to_ctr_reg[17]_i_1 ;
  wire \n_0_sm_reset_rx_cdr_to_ctr_reg[18]_i_1 ;
  wire \n_0_sm_reset_rx_cdr_to_ctr_reg[19]_i_1 ;
  wire \n_0_sm_reset_rx_cdr_to_ctr_reg[1]_i_1 ;
  wire \n_0_sm_reset_rx_cdr_to_ctr_reg[20]_i_1 ;
  wire \n_0_sm_reset_rx_cdr_to_ctr_reg[21]_i_1 ;
  wire \n_0_sm_reset_rx_cdr_to_ctr_reg[2]_i_1 ;
  wire \n_0_sm_reset_rx_cdr_to_ctr_reg[3]_i_1 ;
  wire \n_0_sm_reset_rx_cdr_to_ctr_reg[4]_i_1 ;
  wire \n_0_sm_reset_rx_cdr_to_ctr_reg[5]_i_1 ;
  wire \n_0_sm_reset_rx_cdr_to_ctr_reg[6]_i_1 ;
  wire \n_0_sm_reset_rx_cdr_to_ctr_reg[7]_i_1 ;
  wire \n_0_sm_reset_rx_cdr_to_ctr_reg[8]_i_1 ;
  wire \n_0_sm_reset_rx_cdr_to_ctr_reg[8]_i_2 ;
  wire \n_0_sm_reset_rx_cdr_to_ctr_reg[9]_i_1 ;
  wire n_0_sm_reset_rx_cdr_to_sat_i_1;
  wire n_0_sm_reset_rx_cdr_to_sat_i_2;
  wire n_0_sm_reset_rx_cdr_to_sat_i_3;
  wire n_0_sm_reset_rx_cdr_to_sat_i_4;
  wire n_0_sm_reset_rx_cdr_to_sat_i_5;
  wire n_0_sm_reset_rx_timer_clr_reg;
  wire \n_0_sm_reset_rx_timer_ctr[0]_i_1 ;
  wire \n_0_sm_reset_rx_timer_ctr[1]_i_1 ;
  wire \n_0_sm_reset_rx_timer_ctr[2]_i_1 ;
  wire \n_0_sm_reset_rx_timer_ctr[2]_i_2 ;
  wire n_0_sm_reset_rx_timer_sat_i_1;
  wire n_0_sm_reset_tx_timer_clr_reg;
  wire \n_0_sm_reset_tx_timer_ctr[2]_i_1 ;
  wire n_0_sm_reset_tx_timer_sat_i_1;
  wire n_1_bit_synchronizer_gtwiz_reset_tx_pll_and_datapath_dly_inst;
  wire n_1_bit_synchronizer_gtwiz_reset_userclk_rx_active_inst;
  wire n_1_bit_synchronizer_gtwiz_reset_userclk_tx_active_inst;
  wire n_1_bit_synchronizer_plllock_rx_inst;
  wire n_1_bit_synchronizer_plllock_tx_inst;
  wire n_1_bit_synchronizer_rxcdrlock_inst;
  wire n_1_bit_synchronizer_rxresetdone_inst;
  wire n_1_reset_synchronizer_gtwiz_reset_rx_any_inst;
  wire n_1_reset_synchronizer_gtwiz_reset_tx_any_inst;
  wire n_2_bit_synchronizer_gtwiz_reset_tx_pll_and_datapath_dly_inst;
  wire n_2_bit_synchronizer_gtwiz_reset_userclk_rx_active_inst;
  wire n_2_bit_synchronizer_plllock_rx_inst;
  wire n_2_bit_synchronizer_plllock_tx_inst;
  wire n_2_bit_synchronizer_rxcdrlock_inst;
  wire n_2_bit_synchronizer_rxresetdone_inst;
  wire n_2_bit_synchronizer_txresetdone_inst;
  wire n_3_bit_synchronizer_plllock_rx_inst;
  wire n_3_bit_synchronizer_plllock_tx_inst;
  wire n_3_bit_synchronizer_rxresetdone_inst;
  wire n_4_bit_synchronizer_plllock_rx_inst;
  wire n_4_bit_synchronizer_rxresetdone_inst;
  wire p_0_in10_out;
  wire [2:0]p_1_in;
  wire plllock_tx_sync;
  wire [0:0]qpll0lock_out;
  wire rst_in0;
  wire [0:0]rxusrclk2_in;
  wire sel;
  wire [2:0]sm_reset_all_timer_ctr;
  wire sm_reset_all_timer_sat;
(* RTL_KEEP = "yes" *)   wire [2:0]sm_reset_rx;
  wire sm_reset_rx_cdr_to_clr;
  wire [21:0]sm_reset_rx_cdr_to_ctr_reg;
  wire sm_reset_rx_cdr_to_sat;
  wire [2:0]sm_reset_rx_timer_ctr;
  wire sm_reset_rx_timer_sat;
(* RTL_KEEP = "yes" *)   wire [2:0]sm_reset_tx;
  wire sm_reset_tx_timer_clr0;
  wire [2:0]sm_reset_tx_timer_ctr;
  wire sm_reset_tx_timer_sat;
  wire txresetdone_sync;
  wire [0:0]txusrclk2_in;
  wire \NLW_sm_reset_rx_cdr_to_ctr_reg[17]_i_2_CARRY4_CARRY8_CI_TOP_UNCONNECTED ;
  wire [7:0]\NLW_sm_reset_rx_cdr_to_ctr_reg[17]_i_2_CARRY4_CARRY8_CO_UNCONNECTED ;
  wire [7:5]\NLW_sm_reset_rx_cdr_to_ctr_reg[17]_i_2_CARRY4_CARRY8_DI_UNCONNECTED ;
  wire [7:6]\NLW_sm_reset_rx_cdr_to_ctr_reg[17]_i_2_CARRY4_CARRY8_O_UNCONNECTED ;
  wire [7:6]\NLW_sm_reset_rx_cdr_to_ctr_reg[17]_i_2_CARRY4_CARRY8_S_UNCONNECTED ;
  wire \NLW_sm_reset_rx_cdr_to_ctr_reg[1]_i_2_CARRY4_CARRY8_CI_TOP_UNCONNECTED ;
  wire [6:0]\NLW_sm_reset_rx_cdr_to_ctr_reg[1]_i_2_CARRY4_CARRY8_CO_UNCONNECTED ;
  wire \NLW_sm_reset_rx_cdr_to_ctr_reg[9]_i_2_CARRY4_CARRY8_CI_TOP_UNCONNECTED ;
  wire [6:0]\NLW_sm_reset_rx_cdr_to_ctr_reg[9]_i_2_CARRY4_CARRY8_CO_UNCONNECTED ;

LUT5 #(
    .INIT(32'h0000A803)) 
     \FSM_sequential_sm_reset_all[0]_i_1 
       (.I0(\n_0_FSM_sequential_sm_reset_all[2]_i_2 ),
        .I1(\n_0_FSM_sequential_sm_reset_all_reg[0] ),
        .I2(\n_0_FSM_sequential_sm_reset_all_reg[2] ),
        .I3(\n_0_FSM_sequential_sm_reset_all_reg[1] ),
        .I4(\n_0_FSM_sequential_sm_reset_all_reg[3] ),
        .O(\n_0_FSM_sequential_sm_reset_all[0]_i_1 ));
LUT3 #(
    .INIT(8'h06)) 
     \FSM_sequential_sm_reset_all[1]_i_1 
       (.I0(\n_0_FSM_sequential_sm_reset_all_reg[2] ),
        .I1(\n_0_FSM_sequential_sm_reset_all_reg[0] ),
        .I2(\n_0_FSM_sequential_sm_reset_all_reg[3] ),
        .O(\n_0_FSM_sequential_sm_reset_all[1]_i_1 ));
LUT5 #(
    .INIT(32'h0000F200)) 
     \FSM_sequential_sm_reset_all[2]_i_1 
       (.I0(\n_0_FSM_sequential_sm_reset_all_reg[2] ),
        .I1(\n_0_FSM_sequential_sm_reset_all_reg[0] ),
        .I2(\n_0_FSM_sequential_sm_reset_all_reg[1] ),
        .I3(\n_0_FSM_sequential_sm_reset_all[2]_i_2 ),
        .I4(\n_0_FSM_sequential_sm_reset_all_reg[3] ),
        .O(\n_0_FSM_sequential_sm_reset_all[2]_i_1 ));
LUT5 #(
    .INIT(32'h7555FFFF)) 
     \FSM_sequential_sm_reset_all[2]_i_2 
       (.I0(\n_0_FSM_sequential_sm_reset_all_reg[0] ),
        .I1(n_0_sm_reset_all_timer_clr_reg),
        .I2(sm_reset_all_timer_sat),
        .I3(n_0_gtwiz_reset_rx_done_int_reg),
        .I4(\n_0_FSM_sequential_sm_reset_all_reg[2] ),
        .O(\n_0_FSM_sequential_sm_reset_all[2]_i_2 ));
LUT4 #(
    .INIT(16'h08FF)) 
     \FSM_sequential_sm_reset_all[3]_i_3 
       (.I0(n_0_gtwiz_reset_rx_done_int_reg),
        .I1(sm_reset_all_timer_sat),
        .I2(n_0_sm_reset_all_timer_clr_reg),
        .I3(\n_0_FSM_sequential_sm_reset_all_reg[0] ),
        .O(\n_0_FSM_sequential_sm_reset_all[3]_i_3 ));
(* KEEP = "yes" *) 
   FDSE #(
    .INIT(1'b0)) 
     \FSM_sequential_sm_reset_all_reg[0] 
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(n_0_bit_synchronizer_gtpowergood_inst),
        .D(\n_0_FSM_sequential_sm_reset_all[0]_i_1 ),
        .Q(\n_0_FSM_sequential_sm_reset_all_reg[0] ),
        .S(gtwiz_reset_all_sync));
(* KEEP = "yes" *) 
   FDRE #(
    .INIT(1'b0)) 
     \FSM_sequential_sm_reset_all_reg[1] 
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(n_0_bit_synchronizer_gtpowergood_inst),
        .D(\n_0_FSM_sequential_sm_reset_all[1]_i_1 ),
        .Q(\n_0_FSM_sequential_sm_reset_all_reg[1] ),
        .R(gtwiz_reset_all_sync));
(* KEEP = "yes" *) 
   FDRE #(
    .INIT(1'b0)) 
     \FSM_sequential_sm_reset_all_reg[2] 
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(n_0_bit_synchronizer_gtpowergood_inst),
        .D(\n_0_FSM_sequential_sm_reset_all[2]_i_1 ),
        .Q(\n_0_FSM_sequential_sm_reset_all_reg[2] ),
        .R(gtwiz_reset_all_sync));
(* KEEP = "yes" *) 
   FDRE #(
    .INIT(1'b0)) 
     \FSM_sequential_sm_reset_all_reg[3] 
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(n_0_bit_synchronizer_gtpowergood_inst),
        .D(1'b0),
        .Q(\n_0_FSM_sequential_sm_reset_all_reg[3] ),
        .R(gtwiz_reset_all_sync));
(* SOFT_HLUTNM = "soft_lutpair3" *) 
   LUT2 #(
    .INIT(4'h2)) 
     \FSM_sequential_sm_reset_rx[1]_i_2 
       (.I0(sm_reset_rx_timer_sat),
        .I1(n_0_sm_reset_rx_timer_clr_reg),
        .O(\n_0_FSM_sequential_sm_reset_rx[1]_i_2 ));
(* KEEP = "yes" *) 
   FDRE \FSM_sequential_sm_reset_rx_reg[0] 
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(n_4_bit_synchronizer_plllock_rx_inst),
        .D(n_3_bit_synchronizer_rxresetdone_inst),
        .Q(sm_reset_rx[0]),
        .R(gtwiz_reset_rx_any_sync));
(* KEEP = "yes" *) 
   FDRE \FSM_sequential_sm_reset_rx_reg[1] 
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(n_4_bit_synchronizer_plllock_rx_inst),
        .D(n_2_bit_synchronizer_rxresetdone_inst),
        .Q(sm_reset_rx[1]),
        .R(gtwiz_reset_rx_any_sync));
(* KEEP = "yes" *) 
   FDRE \FSM_sequential_sm_reset_rx_reg[2] 
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(n_4_bit_synchronizer_plllock_rx_inst),
        .D(n_1_bit_synchronizer_rxresetdone_inst),
        .Q(sm_reset_rx[2]),
        .R(gtwiz_reset_rx_any_sync));
LUT3 #(
    .INIT(8'h38)) 
     \FSM_sequential_sm_reset_tx[2]_i_2 
       (.I0(sm_reset_tx[0]),
        .I1(sm_reset_tx[1]),
        .I2(sm_reset_tx[2]),
        .O(\n_0_FSM_sequential_sm_reset_tx[2]_i_2 ));
(* KEEP = "yes" *) 
   FDRE \FSM_sequential_sm_reset_tx_reg[0] 
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(n_2_bit_synchronizer_txresetdone_inst),
        .D(n_2_bit_synchronizer_gtwiz_reset_tx_pll_and_datapath_dly_inst),
        .Q(sm_reset_tx[0]),
        .R(gtwiz_reset_tx_any_sync));
(* KEEP = "yes" *) 
   FDRE \FSM_sequential_sm_reset_tx_reg[1] 
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(n_2_bit_synchronizer_txresetdone_inst),
        .D(n_1_bit_synchronizer_gtwiz_reset_tx_pll_and_datapath_dly_inst),
        .Q(sm_reset_tx[1]),
        .R(gtwiz_reset_tx_any_sync));
(* KEEP = "yes" *) 
   FDRE \FSM_sequential_sm_reset_tx_reg[2] 
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(n_2_bit_synchronizer_txresetdone_inst),
        .D(\n_0_FSM_sequential_sm_reset_tx[2]_i_2 ),
        .Q(sm_reset_tx[2]),
        .R(gtwiz_reset_tx_any_sync));
GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_bit_synchronizer bit_synchronizer_gtpowergood_inst
       (.E(n_0_bit_synchronizer_gtpowergood_inst),
        .I1(I1),
        .I2(\n_0_FSM_sequential_sm_reset_all[3]_i_3 ),
        .I3(n_0_gtwiz_reset_tx_done_int_reg),
        .I4(n_0_sm_reset_all_timer_clr_reg),
        .gtwiz_reset_clk_freerun_in(gtwiz_reset_clk_freerun_in),
        .out({\n_0_FSM_sequential_sm_reset_all_reg[3] ,\n_0_FSM_sequential_sm_reset_all_reg[2] ,\n_0_FSM_sequential_sm_reset_all_reg[1] ,\n_0_FSM_sequential_sm_reset_all_reg[0] }),
        .sm_reset_all_timer_sat(sm_reset_all_timer_sat));
GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_bit_synchronizer_0 bit_synchronizer_gtwiz_reset_rx_datapath_dly_inst
       (.gtwiz_reset_clk_freerun_in(gtwiz_reset_clk_freerun_in),
        .gtwiz_reset_rx_datapath_dly(gtwiz_reset_rx_datapath_dly),
        .gtwiz_reset_rx_datapath_sync(gtwiz_reset_rx_datapath_sync));
GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_bit_synchronizer_1 bit_synchronizer_gtwiz_reset_rx_pll_and_datapath_dly_inst
       (.gtwiz_reset_clk_freerun_in(gtwiz_reset_clk_freerun_in),
        .gtwiz_reset_rx_pll_and_datapath_dly(gtwiz_reset_rx_pll_and_datapath_dly),
        .gtwiz_reset_rx_pll_and_datapath_sync(gtwiz_reset_rx_pll_and_datapath_sync));
GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_bit_synchronizer_2 bit_synchronizer_gtwiz_reset_tx_datapath_dly_inst
       (.gtwiz_reset_clk_freerun_in(gtwiz_reset_clk_freerun_in),
        .gtwiz_reset_tx_datapath_dly(gtwiz_reset_tx_datapath_dly),
        .gtwiz_reset_tx_datapath_sync(gtwiz_reset_tx_datapath_sync));
GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_bit_synchronizer_3 bit_synchronizer_gtwiz_reset_tx_pll_and_datapath_dly_inst
       (.D({n_1_bit_synchronizer_gtwiz_reset_tx_pll_and_datapath_dly_inst,n_2_bit_synchronizer_gtwiz_reset_tx_pll_and_datapath_dly_inst}),
        .I1(n_0_sm_reset_tx_timer_clr_reg),
        .O1(n_0_bit_synchronizer_gtwiz_reset_tx_pll_and_datapath_dly_inst),
        .gtwiz_reset_clk_freerun_in(gtwiz_reset_clk_freerun_in),
        .gtwiz_reset_tx_datapath_dly(gtwiz_reset_tx_datapath_dly),
        .gtwiz_reset_tx_pll_and_datapath_sync(gtwiz_reset_tx_pll_and_datapath_sync),
        .out(sm_reset_tx),
        .sm_reset_tx_timer_sat(sm_reset_tx_timer_sat));
GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_bit_synchronizer_4 bit_synchronizer_gtwiz_reset_userclk_rx_active_inst
       (.GTHE3_CHANNEL_RXUSERRDY(GTHE3_CHANNEL_RXUSERRDY),
        .I1(n_0_sm_reset_rx_timer_clr_reg),
        .O1(n_1_bit_synchronizer_gtwiz_reset_userclk_rx_active_inst),
        .O2(n_2_bit_synchronizer_gtwiz_reset_userclk_rx_active_inst),
        .gtwiz_reset_clk_freerun_in(gtwiz_reset_clk_freerun_in),
        .gtwiz_reset_rx_any_sync(gtwiz_reset_rx_any_sync),
        .gtwiz_reset_userclk_rx_active_sync(gtwiz_reset_userclk_rx_active_sync),
        .gtwiz_userclk_rx_active_in(gtwiz_userclk_rx_active_in),
        .out(sm_reset_rx),
        .sm_reset_rx_timer_sat(sm_reset_rx_timer_sat));
GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_bit_synchronizer_5 bit_synchronizer_gtwiz_reset_userclk_tx_active_inst
       (.GTHE3_CHANNEL_TXUSERRDY(GTHE3_CHANNEL_TXUSERRDY),
        .I1(n_3_bit_synchronizer_plllock_tx_inst),
        .I2(n_0_sm_reset_tx_timer_clr_reg),
        .O1(n_0_bit_synchronizer_gtwiz_reset_userclk_tx_active_inst),
        .O2(n_1_bit_synchronizer_gtwiz_reset_userclk_tx_active_inst),
        .gtwiz_reset_clk_freerun_in(gtwiz_reset_clk_freerun_in),
        .gtwiz_reset_tx_any_sync(gtwiz_reset_tx_any_sync),
        .gtwiz_userclk_tx_active_in(gtwiz_userclk_tx_active_in),
        .out(sm_reset_tx),
        .sm_reset_tx_timer_clr0(sm_reset_tx_timer_clr0),
        .sm_reset_tx_timer_sat(sm_reset_tx_timer_sat));
GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_bit_synchronizer_6 bit_synchronizer_plllock_rx_inst
       (.E(n_4_bit_synchronizer_plllock_rx_inst),
        .GTHE3_CHANNEL_GTRXRESET(GTHE3_CHANNEL_GTRXRESET),
        .I1(n_2_bit_synchronizer_rxcdrlock_inst),
        .I2(n_0_gtwiz_reset_rx_done_int_reg),
        .I3(n_4_bit_synchronizer_rxresetdone_inst),
        .I4(n_0_sm_reset_rx_timer_clr_reg),
        .I5(n_2_bit_synchronizer_gtwiz_reset_userclk_rx_active_inst),
        .I6(n_1_bit_synchronizer_rxcdrlock_inst),
        .O1(n_0_bit_synchronizer_plllock_rx_inst),
        .O2(n_1_bit_synchronizer_plllock_rx_inst),
        .O3(n_2_bit_synchronizer_plllock_rx_inst),
        .O4(n_3_bit_synchronizer_plllock_rx_inst),
        .gtwiz_reset_clk_freerun_in(gtwiz_reset_clk_freerun_in),
        .gtwiz_reset_rx_any_sync(gtwiz_reset_rx_any_sync),
        .gtwiz_reset_userclk_rx_active_sync(gtwiz_reset_userclk_rx_active_sync),
        .out(sm_reset_rx),
        .p_0_in10_out(p_0_in10_out),
        .qpll0lock_out(qpll0lock_out),
        .sm_reset_rx_cdr_to_clr(sm_reset_rx_cdr_to_clr),
        .sm_reset_rx_timer_sat(sm_reset_rx_timer_sat));
GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_bit_synchronizer_7 bit_synchronizer_plllock_tx_inst
       (.GTHE3_CHANNEL_GTTXRESET(GTHE3_CHANNEL_GTTXRESET),
        .I1(n_0_gtwiz_reset_tx_done_int_reg),
        .I2(n_0_sm_reset_tx_timer_clr_reg),
        .O1(n_1_bit_synchronizer_plllock_tx_inst),
        .O2(n_2_bit_synchronizer_plllock_tx_inst),
        .O3(n_3_bit_synchronizer_plllock_tx_inst),
        .gtwiz_reset_clk_freerun_in(gtwiz_reset_clk_freerun_in),
        .gtwiz_reset_tx_any_sync(gtwiz_reset_tx_any_sync),
        .gtwiz_reset_tx_done_int0(gtwiz_reset_tx_done_int0),
        .out(sm_reset_tx),
        .plllock_tx_sync(plllock_tx_sync),
        .qpll0lock_out(qpll0lock_out),
        .sm_reset_tx_timer_sat(sm_reset_tx_timer_sat),
        .txresetdone_sync(txresetdone_sync));
GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_bit_synchronizer_8 bit_synchronizer_rx_done_inst
       (.I1(n_0_gtwiz_reset_rx_done_int_reg),
        .gtwiz_reset_rx_done_out(gtwiz_reset_rx_done_out),
        .rxusrclk2_in(rxusrclk2_in));
GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_bit_synchronizer_9 bit_synchronizer_rxcdrlock_inst
       (.I3(I3),
        .O1(n_1_bit_synchronizer_rxcdrlock_inst),
        .O2(n_2_bit_synchronizer_rxcdrlock_inst),
        .gtwiz_reset_clk_freerun_in(gtwiz_reset_clk_freerun_in),
        .gtwiz_reset_rx_cdr_stable_out(gtwiz_reset_rx_cdr_stable_out),
        .gtwiz_reset_rx_datapath_dly(gtwiz_reset_rx_datapath_dly),
        .gtwiz_reset_rx_pll_and_datapath_dly(gtwiz_reset_rx_pll_and_datapath_dly),
        .out(sm_reset_rx[2:1]),
        .sm_reset_rx_cdr_to_sat(sm_reset_rx_cdr_to_sat));
GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_bit_synchronizer_10 bit_synchronizer_rxresetdone_inst
       (.D({n_1_bit_synchronizer_rxresetdone_inst,n_2_bit_synchronizer_rxresetdone_inst,n_3_bit_synchronizer_rxresetdone_inst}),
        .I1(n_0_sm_reset_rx_timer_clr_reg),
        .I2(\n_0_FSM_sequential_sm_reset_rx[1]_i_2 ),
        .I4(I4),
        .O1(n_4_bit_synchronizer_rxresetdone_inst),
        .gtwiz_reset_clk_freerun_in(gtwiz_reset_clk_freerun_in),
        .gtwiz_reset_rx_pll_and_datapath_dly(gtwiz_reset_rx_pll_and_datapath_dly),
        .out(sm_reset_rx),
        .p_0_in10_out(p_0_in10_out),
        .sm_reset_rx_timer_sat(sm_reset_rx_timer_sat));
GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_bit_synchronizer_11 bit_synchronizer_tx_done_inst
       (.I1(n_0_gtwiz_reset_tx_done_int_reg),
        .gtwiz_reset_tx_done_out(gtwiz_reset_tx_done_out),
        .txusrclk2_in(txusrclk2_in));
GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_bit_synchronizer_12 bit_synchronizer_txresetdone_inst
       (.E(n_2_bit_synchronizer_txresetdone_inst),
        .I1(n_0_sm_reset_tx_timer_clr_reg),
        .I2(I2),
        .I3(n_0_bit_synchronizer_gtwiz_reset_tx_pll_and_datapath_dly_inst),
        .gtwiz_reset_clk_freerun_in(gtwiz_reset_clk_freerun_in),
        .gtwiz_reset_tx_done_int0(gtwiz_reset_tx_done_int0),
        .out(sm_reset_tx),
        .plllock_tx_sync(plllock_tx_sync),
        .sm_reset_tx_timer_clr0(sm_reset_tx_timer_clr0),
        .sm_reset_tx_timer_sat(sm_reset_tx_timer_sat),
        .txresetdone_sync(txresetdone_sync));
FDRE #(
    .INIT(1'b1)) 
     gtrxreset_out_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(n_2_bit_synchronizer_plllock_rx_inst),
        .Q(GTHE3_CHANNEL_GTRXRESET),
        .R(1'b0));
FDRE #(
    .INIT(1'b1)) 
     gttxreset_out_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(n_1_bit_synchronizer_plllock_tx_inst),
        .Q(GTHE3_CHANNEL_GTTXRESET),
        .R(1'b0));
LUT2 #(
    .INIT(4'hE)) 
     \gtwiz_reset_qpll0reset_out[0]_INST_0 
       (.I0(gtwiz_reset_pllreset_tx_int),
        .I1(gtwiz_reset_pllreset_rx_int),
        .O(gtwiz_reset_qpll0reset_out));
LUT5 #(
    .INIT(32'hFF7F0040)) 
     gtwiz_reset_rx_datapath_int_i_1
       (.I0(\n_0_FSM_sequential_sm_reset_all_reg[0] ),
        .I1(\n_0_FSM_sequential_sm_reset_all_reg[1] ),
        .I2(\n_0_FSM_sequential_sm_reset_all_reg[2] ),
        .I3(\n_0_FSM_sequential_sm_reset_all_reg[3] ),
        .I4(n_0_gtwiz_reset_rx_datapath_int_reg),
        .O(n_0_gtwiz_reset_rx_datapath_int_i_1));
FDRE #(
    .INIT(1'b0)) 
     gtwiz_reset_rx_datapath_int_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(n_0_gtwiz_reset_rx_datapath_int_i_1),
        .Q(n_0_gtwiz_reset_rx_datapath_int_reg),
        .R(gtwiz_reset_all_sync));
FDRE #(
    .INIT(1'b0)) 
     gtwiz_reset_rx_done_int_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(n_1_bit_synchronizer_plllock_rx_inst),
        .Q(n_0_gtwiz_reset_rx_done_int_reg),
        .R(gtwiz_reset_rx_any_sync));
LUT5 #(
    .INIT(32'hFF7F0040)) 
     gtwiz_reset_rx_pll_and_datapath_int_i_1
       (.I0(\n_0_FSM_sequential_sm_reset_all_reg[2] ),
        .I1(\n_0_FSM_sequential_sm_reset_all_reg[1] ),
        .I2(\n_0_FSM_sequential_sm_reset_all_reg[0] ),
        .I3(\n_0_FSM_sequential_sm_reset_all_reg[3] ),
        .I4(n_0_gtwiz_reset_rx_pll_and_datapath_int_reg),
        .O(n_0_gtwiz_reset_rx_pll_and_datapath_int_i_1));
FDRE #(
    .INIT(1'b0)) 
     gtwiz_reset_rx_pll_and_datapath_int_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(n_0_gtwiz_reset_rx_pll_and_datapath_int_i_1),
        .Q(n_0_gtwiz_reset_rx_pll_and_datapath_int_reg),
        .R(gtwiz_reset_all_sync));
FDRE #(
    .INIT(1'b0)) 
     gtwiz_reset_tx_done_int_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(n_2_bit_synchronizer_plllock_tx_inst),
        .Q(n_0_gtwiz_reset_tx_done_int_reg),
        .R(gtwiz_reset_tx_any_sync));
LUT5 #(
    .INIT(32'hFFFB0002)) 
     gtwiz_reset_tx_pll_and_datapath_int_i_1
       (.I0(\n_0_FSM_sequential_sm_reset_all_reg[1] ),
        .I1(\n_0_FSM_sequential_sm_reset_all_reg[2] ),
        .I2(\n_0_FSM_sequential_sm_reset_all_reg[3] ),
        .I3(\n_0_FSM_sequential_sm_reset_all_reg[0] ),
        .I4(n_0_gtwiz_reset_tx_pll_and_datapath_int_reg),
        .O(n_0_gtwiz_reset_tx_pll_and_datapath_int_i_1));
FDRE #(
    .INIT(1'b0)) 
     gtwiz_reset_tx_pll_and_datapath_int_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(n_0_gtwiz_reset_tx_pll_and_datapath_int_i_1),
        .Q(n_0_gtwiz_reset_tx_pll_and_datapath_int_reg),
        .R(gtwiz_reset_all_sync));
(* XILINX_LEGACY_PRIM = "FDE" *) 
   FDRE #(
    .INIT(1'b0)) 
     pllreset_rx_out_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(n_1_reset_synchronizer_gtwiz_reset_rx_any_inst),
        .Q(gtwiz_reset_pllreset_rx_int),
        .R(1'b0));
FDRE #(
    .INIT(1'b1)) 
     pllreset_tx_out_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(n_1_reset_synchronizer_gtwiz_reset_tx_any_inst),
        .Q(gtwiz_reset_pllreset_tx_int),
        .R(1'b0));
GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_reset_synchronizer reset_synchronizer_gtwiz_reset_all_inst
       (.SR(gtwiz_reset_all_sync),
        .gtwiz_reset_all_in(gtwiz_reset_all_in),
        .gtwiz_reset_clk_freerun_in(gtwiz_reset_clk_freerun_in));
GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_reset_synchronizer_13 reset_synchronizer_gtwiz_reset_rx_any_inst
       (.I1(n_0_gtwiz_reset_rx_datapath_int_reg),
        .I2(n_0_gtwiz_reset_rx_pll_and_datapath_int_reg),
        .O1(n_1_reset_synchronizer_gtwiz_reset_rx_any_inst),
        .gtwiz_reset_clk_freerun_in(gtwiz_reset_clk_freerun_in),
        .gtwiz_reset_pllreset_rx_int(gtwiz_reset_pllreset_rx_int),
        .gtwiz_reset_rx_any_sync(gtwiz_reset_rx_any_sync),
        .gtwiz_reset_rx_datapath_in(gtwiz_reset_rx_datapath_in),
        .gtwiz_reset_rx_pll_and_datapath_in(gtwiz_reset_rx_pll_and_datapath_in),
        .out(sm_reset_rx));
GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_reset_synchronizer_14 reset_synchronizer_gtwiz_reset_rx_datapath_inst
       (.I1(n_0_gtwiz_reset_rx_datapath_int_reg),
        .gtwiz_reset_clk_freerun_in(gtwiz_reset_clk_freerun_in),
        .gtwiz_reset_rx_datapath_in(gtwiz_reset_rx_datapath_in),
        .gtwiz_reset_rx_datapath_sync(gtwiz_reset_rx_datapath_sync));
GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_reset_synchronizer_15 reset_synchronizer_gtwiz_reset_rx_pll_and_datapath_inst
       (.I1(n_0_gtwiz_reset_rx_pll_and_datapath_int_reg),
        .gtwiz_reset_clk_freerun_in(gtwiz_reset_clk_freerun_in),
        .gtwiz_reset_rx_pll_and_datapath_in(gtwiz_reset_rx_pll_and_datapath_in),
        .gtwiz_reset_rx_pll_and_datapath_sync(gtwiz_reset_rx_pll_and_datapath_sync));
GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_reset_synchronizer_16 reset_synchronizer_gtwiz_reset_tx_any_inst
       (.I1(n_0_gtwiz_reset_tx_pll_and_datapath_int_reg),
        .O1(n_1_reset_synchronizer_gtwiz_reset_tx_any_inst),
        .gtwiz_reset_clk_freerun_in(gtwiz_reset_clk_freerun_in),
        .gtwiz_reset_pllreset_tx_int(gtwiz_reset_pllreset_tx_int),
        .gtwiz_reset_tx_any_sync(gtwiz_reset_tx_any_sync),
        .gtwiz_reset_tx_datapath_in(gtwiz_reset_tx_datapath_in),
        .gtwiz_reset_tx_pll_and_datapath_in(gtwiz_reset_tx_pll_and_datapath_in),
        .out(sm_reset_tx));
GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_reset_synchronizer_17 reset_synchronizer_gtwiz_reset_tx_datapath_inst
       (.gtwiz_reset_clk_freerun_in(gtwiz_reset_clk_freerun_in),
        .gtwiz_reset_tx_datapath_in(gtwiz_reset_tx_datapath_in),
        .gtwiz_reset_tx_datapath_sync(gtwiz_reset_tx_datapath_sync));
GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_reset_synchronizer_18 reset_synchronizer_gtwiz_reset_tx_pll_and_datapath_inst
       (.I1(n_0_gtwiz_reset_tx_pll_and_datapath_int_reg),
        .gtwiz_reset_clk_freerun_in(gtwiz_reset_clk_freerun_in),
        .gtwiz_reset_tx_pll_and_datapath_in(gtwiz_reset_tx_pll_and_datapath_in),
        .gtwiz_reset_tx_pll_and_datapath_sync(gtwiz_reset_tx_pll_and_datapath_sync));
GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_reset_synchronizer_19 reset_synchronizer_rxprogdivreset_inst
       (.GTHE3_CHANNEL_RXPROGDIVRESET(GTHE3_CHANNEL_RXPROGDIVRESET),
        .gtwiz_reset_clk_freerun_in(gtwiz_reset_clk_freerun_in),
        .rst_in0(rst_in0));
GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_reset_synchronizer_20 reset_synchronizer_txprogdivreset_inst
       (.GTHE3_CHANNEL_TXPROGDIVRESET(GTHE3_CHANNEL_TXPROGDIVRESET),
        .gtwiz_reset_clk_freerun_in(gtwiz_reset_clk_freerun_in),
        .rst_in0(rst_in0));
(* XILINX_LEGACY_PRIM = "FDE" *) 
   FDRE #(
    .INIT(1'b0)) 
     rxuserrdy_out_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(n_1_bit_synchronizer_gtwiz_reset_userclk_rx_active_inst),
        .Q(GTHE3_CHANNEL_RXUSERRDY),
        .R(1'b0));
LUT6 #(
    .INIT(64'hEFFFFEEF20000220)) 
     sm_reset_all_timer_clr_i_1
       (.I0(n_0_sm_reset_all_timer_clr_i_2),
        .I1(\n_0_FSM_sequential_sm_reset_all_reg[3] ),
        .I2(\n_0_FSM_sequential_sm_reset_all_reg[0] ),
        .I3(\n_0_FSM_sequential_sm_reset_all_reg[2] ),
        .I4(\n_0_FSM_sequential_sm_reset_all_reg[1] ),
        .I5(n_0_sm_reset_all_timer_clr_reg),
        .O(n_0_sm_reset_all_timer_clr_i_1));
LUT6 #(
    .INIT(64'h30BF303030B03030)) 
     sm_reset_all_timer_clr_i_2
       (.I0(n_0_gtwiz_reset_rx_done_int_reg),
        .I1(\n_0_FSM_sequential_sm_reset_all_reg[1] ),
        .I2(\n_0_FSM_sequential_sm_reset_all_reg[0] ),
        .I3(n_0_sm_reset_all_timer_clr_reg),
        .I4(sm_reset_all_timer_sat),
        .I5(n_0_gtwiz_reset_tx_done_int_reg),
        .O(n_0_sm_reset_all_timer_clr_i_2));
FDSE #(
    .INIT(1'b1)) 
     sm_reset_all_timer_clr_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(n_0_sm_reset_all_timer_clr_i_1),
        .Q(n_0_sm_reset_all_timer_clr_reg),
        .S(gtwiz_reset_all_sync));
LUT1 #(
    .INIT(2'h1)) 
     \sm_reset_all_timer_ctr[0]_i_1 
       (.I0(sm_reset_all_timer_ctr[0]),
        .O(\n_0_sm_reset_all_timer_ctr[0]_i_1 ));
(* SOFT_HLUTNM = "soft_lutpair4" *) 
   LUT2 #(
    .INIT(4'h6)) 
     \sm_reset_all_timer_ctr[1]_i_1 
       (.I0(sm_reset_all_timer_ctr[0]),
        .I1(sm_reset_all_timer_ctr[1]),
        .O(\n_0_sm_reset_all_timer_ctr[1]_i_1 ));
LUT3 #(
    .INIT(8'h7F)) 
     \sm_reset_all_timer_ctr[2]_i_1 
       (.I0(sm_reset_all_timer_ctr[2]),
        .I1(sm_reset_all_timer_ctr[0]),
        .I2(sm_reset_all_timer_ctr[1]),
        .O(\n_0_sm_reset_all_timer_ctr[2]_i_1 ));
(* SOFT_HLUTNM = "soft_lutpair4" *) 
   LUT3 #(
    .INIT(8'h78)) 
     \sm_reset_all_timer_ctr[2]_i_2 
       (.I0(sm_reset_all_timer_ctr[0]),
        .I1(sm_reset_all_timer_ctr[1]),
        .I2(sm_reset_all_timer_ctr[2]),
        .O(\n_0_sm_reset_all_timer_ctr[2]_i_2 ));
FDRE #(
    .INIT(1'b0)) 
     \sm_reset_all_timer_ctr_reg[0] 
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(\n_0_sm_reset_all_timer_ctr[2]_i_1 ),
        .D(\n_0_sm_reset_all_timer_ctr[0]_i_1 ),
        .Q(sm_reset_all_timer_ctr[0]),
        .R(n_0_sm_reset_all_timer_clr_reg));
FDRE #(
    .INIT(1'b0)) 
     \sm_reset_all_timer_ctr_reg[1] 
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(\n_0_sm_reset_all_timer_ctr[2]_i_1 ),
        .D(\n_0_sm_reset_all_timer_ctr[1]_i_1 ),
        .Q(sm_reset_all_timer_ctr[1]),
        .R(n_0_sm_reset_all_timer_clr_reg));
FDRE #(
    .INIT(1'b0)) 
     \sm_reset_all_timer_ctr_reg[2] 
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(\n_0_sm_reset_all_timer_ctr[2]_i_1 ),
        .D(\n_0_sm_reset_all_timer_ctr[2]_i_2 ),
        .Q(sm_reset_all_timer_ctr[2]),
        .R(n_0_sm_reset_all_timer_clr_reg));
LUT5 #(
    .INIT(32'h0000FF80)) 
     sm_reset_all_timer_sat_i_1
       (.I0(sm_reset_all_timer_ctr[1]),
        .I1(sm_reset_all_timer_ctr[0]),
        .I2(sm_reset_all_timer_ctr[2]),
        .I3(sm_reset_all_timer_sat),
        .I4(n_0_sm_reset_all_timer_clr_reg),
        .O(n_0_sm_reset_all_timer_sat_i_1));
FDRE #(
    .INIT(1'b0)) 
     sm_reset_all_timer_sat_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(n_0_sm_reset_all_timer_sat_i_1),
        .Q(sm_reset_all_timer_sat),
        .R(1'b0));
FDSE #(
    .INIT(1'b1)) 
     sm_reset_rx_cdr_to_clr_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(n_0_bit_synchronizer_plllock_rx_inst),
        .Q(sm_reset_rx_cdr_to_clr),
        .S(gtwiz_reset_rx_any_sync));
LUT4 #(
    .INIT(16'hFFFE)) 
     \sm_reset_rx_cdr_to_ctr[0]_i_1 
       (.I0(n_0_sm_reset_rx_cdr_to_sat_i_5),
        .I1(n_0_sm_reset_rx_cdr_to_sat_i_4),
        .I2(n_0_sm_reset_rx_cdr_to_sat_i_3),
        .I3(n_0_sm_reset_rx_cdr_to_sat_i_2),
        .O(sel));
LUT1 #(
    .INIT(2'h1)) 
     \sm_reset_rx_cdr_to_ctr[0]_i_3 
       (.I0(sm_reset_rx_cdr_to_ctr_reg[0]),
        .O(\n_0_sm_reset_rx_cdr_to_ctr[0]_i_3 ));
FDRE #(
    .INIT(1'b0)) 
     \sm_reset_rx_cdr_to_ctr_reg[0] 
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(sel),
        .D(\n_0_sm_reset_rx_cdr_to_ctr_reg[0]_i_2 ),
        .Q(sm_reset_rx_cdr_to_ctr_reg[0]),
        .R(sm_reset_rx_cdr_to_clr));
FDRE #(
    .INIT(1'b0)) 
     \sm_reset_rx_cdr_to_ctr_reg[10] 
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(sel),
        .D(\n_0_sm_reset_rx_cdr_to_ctr_reg[10]_i_1 ),
        .Q(sm_reset_rx_cdr_to_ctr_reg[10]),
        .R(sm_reset_rx_cdr_to_clr));
FDRE #(
    .INIT(1'b0)) 
     \sm_reset_rx_cdr_to_ctr_reg[11] 
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(sel),
        .D(\n_0_sm_reset_rx_cdr_to_ctr_reg[11]_i_1 ),
        .Q(sm_reset_rx_cdr_to_ctr_reg[11]),
        .R(sm_reset_rx_cdr_to_clr));
FDRE #(
    .INIT(1'b0)) 
     \sm_reset_rx_cdr_to_ctr_reg[12] 
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(sel),
        .D(\n_0_sm_reset_rx_cdr_to_ctr_reg[12]_i_1 ),
        .Q(sm_reset_rx_cdr_to_ctr_reg[12]),
        .R(sm_reset_rx_cdr_to_clr));
FDRE #(
    .INIT(1'b0)) 
     \sm_reset_rx_cdr_to_ctr_reg[13] 
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(sel),
        .D(\n_0_sm_reset_rx_cdr_to_ctr_reg[13]_i_1 ),
        .Q(sm_reset_rx_cdr_to_ctr_reg[13]),
        .R(sm_reset_rx_cdr_to_clr));
FDRE #(
    .INIT(1'b0)) 
     \sm_reset_rx_cdr_to_ctr_reg[14] 
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(sel),
        .D(\n_0_sm_reset_rx_cdr_to_ctr_reg[14]_i_1 ),
        .Q(sm_reset_rx_cdr_to_ctr_reg[14]),
        .R(sm_reset_rx_cdr_to_clr));
FDRE #(
    .INIT(1'b0)) 
     \sm_reset_rx_cdr_to_ctr_reg[15] 
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(sel),
        .D(\n_0_sm_reset_rx_cdr_to_ctr_reg[15]_i_1 ),
        .Q(sm_reset_rx_cdr_to_ctr_reg[15]),
        .R(sm_reset_rx_cdr_to_clr));
FDRE #(
    .INIT(1'b0)) 
     \sm_reset_rx_cdr_to_ctr_reg[16] 
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(sel),
        .D(\n_0_sm_reset_rx_cdr_to_ctr_reg[16]_i_1 ),
        .Q(sm_reset_rx_cdr_to_ctr_reg[16]),
        .R(sm_reset_rx_cdr_to_clr));
FDRE #(
    .INIT(1'b0)) 
     \sm_reset_rx_cdr_to_ctr_reg[17] 
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(sel),
        .D(\n_0_sm_reset_rx_cdr_to_ctr_reg[17]_i_1 ),
        .Q(sm_reset_rx_cdr_to_ctr_reg[17]),
        .R(sm_reset_rx_cdr_to_clr));
(* XILINX_LEGACY_PRIM = "(CARRY4)" *) 
   (* XILINX_TRANSFORM_PINMAP = "LO:O" *) 
   CARRY8 \sm_reset_rx_cdr_to_ctr_reg[17]_i_2_CARRY4_CARRY8 
       (.CI(\n_0_sm_reset_rx_cdr_to_ctr_reg[16]_i_2 ),
        .CI_TOP(\NLW_sm_reset_rx_cdr_to_ctr_reg[17]_i_2_CARRY4_CARRY8_CI_TOP_UNCONNECTED ),
        .CO(\NLW_sm_reset_rx_cdr_to_ctr_reg[17]_i_2_CARRY4_CARRY8_CO_UNCONNECTED [7:0]),
        .DI({\NLW_sm_reset_rx_cdr_to_ctr_reg[17]_i_2_CARRY4_CARRY8_DI_UNCONNECTED [7:5],1'b0,1'b0,1'b0,1'b0,1'b0}),
        .O({\NLW_sm_reset_rx_cdr_to_ctr_reg[17]_i_2_CARRY4_CARRY8_O_UNCONNECTED [7:6],\n_0_sm_reset_rx_cdr_to_ctr_reg[21]_i_1 ,\n_0_sm_reset_rx_cdr_to_ctr_reg[20]_i_1 ,\n_0_sm_reset_rx_cdr_to_ctr_reg[19]_i_1 ,\n_0_sm_reset_rx_cdr_to_ctr_reg[18]_i_1 ,\n_0_sm_reset_rx_cdr_to_ctr_reg[17]_i_1 ,\n_0_sm_reset_rx_cdr_to_ctr_reg[16]_i_1 }),
        .S({\NLW_sm_reset_rx_cdr_to_ctr_reg[17]_i_2_CARRY4_CARRY8_S_UNCONNECTED [7:6],sm_reset_rx_cdr_to_ctr_reg[21:16]}));
FDRE #(
    .INIT(1'b0)) 
     \sm_reset_rx_cdr_to_ctr_reg[18] 
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(sel),
        .D(\n_0_sm_reset_rx_cdr_to_ctr_reg[18]_i_1 ),
        .Q(sm_reset_rx_cdr_to_ctr_reg[18]),
        .R(sm_reset_rx_cdr_to_clr));
FDRE #(
    .INIT(1'b0)) 
     \sm_reset_rx_cdr_to_ctr_reg[19] 
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(sel),
        .D(\n_0_sm_reset_rx_cdr_to_ctr_reg[19]_i_1 ),
        .Q(sm_reset_rx_cdr_to_ctr_reg[19]),
        .R(sm_reset_rx_cdr_to_clr));
FDRE #(
    .INIT(1'b0)) 
     \sm_reset_rx_cdr_to_ctr_reg[1] 
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(sel),
        .D(\n_0_sm_reset_rx_cdr_to_ctr_reg[1]_i_1 ),
        .Q(sm_reset_rx_cdr_to_ctr_reg[1]),
        .R(sm_reset_rx_cdr_to_clr));
(* XILINX_LEGACY_PRIM = "(CARRY4)" *) 
   (* XILINX_TRANSFORM_PINMAP = "LO:O" *) 
   CARRY8 \sm_reset_rx_cdr_to_ctr_reg[1]_i_2_CARRY4_CARRY8 
       (.CI(1'b0),
        .CI_TOP(\NLW_sm_reset_rx_cdr_to_ctr_reg[1]_i_2_CARRY4_CARRY8_CI_TOP_UNCONNECTED ),
        .CO({\n_0_sm_reset_rx_cdr_to_ctr_reg[8]_i_2 ,\NLW_sm_reset_rx_cdr_to_ctr_reg[1]_i_2_CARRY4_CARRY8_CO_UNCONNECTED [6:0]}),
        .DI({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b1}),
        .O({\n_0_sm_reset_rx_cdr_to_ctr_reg[7]_i_1 ,\n_0_sm_reset_rx_cdr_to_ctr_reg[6]_i_1 ,\n_0_sm_reset_rx_cdr_to_ctr_reg[5]_i_1 ,\n_0_sm_reset_rx_cdr_to_ctr_reg[4]_i_1 ,\n_0_sm_reset_rx_cdr_to_ctr_reg[3]_i_1 ,\n_0_sm_reset_rx_cdr_to_ctr_reg[2]_i_1 ,\n_0_sm_reset_rx_cdr_to_ctr_reg[1]_i_1 ,\n_0_sm_reset_rx_cdr_to_ctr_reg[0]_i_2 }),
        .S({sm_reset_rx_cdr_to_ctr_reg[7:1],\n_0_sm_reset_rx_cdr_to_ctr[0]_i_3 }));
FDRE #(
    .INIT(1'b0)) 
     \sm_reset_rx_cdr_to_ctr_reg[20] 
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(sel),
        .D(\n_0_sm_reset_rx_cdr_to_ctr_reg[20]_i_1 ),
        .Q(sm_reset_rx_cdr_to_ctr_reg[20]),
        .R(sm_reset_rx_cdr_to_clr));
FDRE #(
    .INIT(1'b0)) 
     \sm_reset_rx_cdr_to_ctr_reg[21] 
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(sel),
        .D(\n_0_sm_reset_rx_cdr_to_ctr_reg[21]_i_1 ),
        .Q(sm_reset_rx_cdr_to_ctr_reg[21]),
        .R(sm_reset_rx_cdr_to_clr));
FDRE #(
    .INIT(1'b0)) 
     \sm_reset_rx_cdr_to_ctr_reg[2] 
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(sel),
        .D(\n_0_sm_reset_rx_cdr_to_ctr_reg[2]_i_1 ),
        .Q(sm_reset_rx_cdr_to_ctr_reg[2]),
        .R(sm_reset_rx_cdr_to_clr));
FDRE #(
    .INIT(1'b0)) 
     \sm_reset_rx_cdr_to_ctr_reg[3] 
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(sel),
        .D(\n_0_sm_reset_rx_cdr_to_ctr_reg[3]_i_1 ),
        .Q(sm_reset_rx_cdr_to_ctr_reg[3]),
        .R(sm_reset_rx_cdr_to_clr));
FDRE #(
    .INIT(1'b0)) 
     \sm_reset_rx_cdr_to_ctr_reg[4] 
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(sel),
        .D(\n_0_sm_reset_rx_cdr_to_ctr_reg[4]_i_1 ),
        .Q(sm_reset_rx_cdr_to_ctr_reg[4]),
        .R(sm_reset_rx_cdr_to_clr));
FDRE #(
    .INIT(1'b0)) 
     \sm_reset_rx_cdr_to_ctr_reg[5] 
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(sel),
        .D(\n_0_sm_reset_rx_cdr_to_ctr_reg[5]_i_1 ),
        .Q(sm_reset_rx_cdr_to_ctr_reg[5]),
        .R(sm_reset_rx_cdr_to_clr));
FDRE #(
    .INIT(1'b0)) 
     \sm_reset_rx_cdr_to_ctr_reg[6] 
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(sel),
        .D(\n_0_sm_reset_rx_cdr_to_ctr_reg[6]_i_1 ),
        .Q(sm_reset_rx_cdr_to_ctr_reg[6]),
        .R(sm_reset_rx_cdr_to_clr));
FDRE #(
    .INIT(1'b0)) 
     \sm_reset_rx_cdr_to_ctr_reg[7] 
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(sel),
        .D(\n_0_sm_reset_rx_cdr_to_ctr_reg[7]_i_1 ),
        .Q(sm_reset_rx_cdr_to_ctr_reg[7]),
        .R(sm_reset_rx_cdr_to_clr));
FDRE #(
    .INIT(1'b0)) 
     \sm_reset_rx_cdr_to_ctr_reg[8] 
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(sel),
        .D(\n_0_sm_reset_rx_cdr_to_ctr_reg[8]_i_1 ),
        .Q(sm_reset_rx_cdr_to_ctr_reg[8]),
        .R(sm_reset_rx_cdr_to_clr));
FDRE #(
    .INIT(1'b0)) 
     \sm_reset_rx_cdr_to_ctr_reg[9] 
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(sel),
        .D(\n_0_sm_reset_rx_cdr_to_ctr_reg[9]_i_1 ),
        .Q(sm_reset_rx_cdr_to_ctr_reg[9]),
        .R(sm_reset_rx_cdr_to_clr));
(* XILINX_LEGACY_PRIM = "(CARRY4)" *) 
   (* XILINX_TRANSFORM_PINMAP = "LO:O" *) 
   CARRY8 \sm_reset_rx_cdr_to_ctr_reg[9]_i_2_CARRY4_CARRY8 
       (.CI(\n_0_sm_reset_rx_cdr_to_ctr_reg[8]_i_2 ),
        .CI_TOP(\NLW_sm_reset_rx_cdr_to_ctr_reg[9]_i_2_CARRY4_CARRY8_CI_TOP_UNCONNECTED ),
        .CO({\n_0_sm_reset_rx_cdr_to_ctr_reg[16]_i_2 ,\NLW_sm_reset_rx_cdr_to_ctr_reg[9]_i_2_CARRY4_CARRY8_CO_UNCONNECTED [6:0]}),
        .DI({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .O({\n_0_sm_reset_rx_cdr_to_ctr_reg[15]_i_1 ,\n_0_sm_reset_rx_cdr_to_ctr_reg[14]_i_1 ,\n_0_sm_reset_rx_cdr_to_ctr_reg[13]_i_1 ,\n_0_sm_reset_rx_cdr_to_ctr_reg[12]_i_1 ,\n_0_sm_reset_rx_cdr_to_ctr_reg[11]_i_1 ,\n_0_sm_reset_rx_cdr_to_ctr_reg[10]_i_1 ,\n_0_sm_reset_rx_cdr_to_ctr_reg[9]_i_1 ,\n_0_sm_reset_rx_cdr_to_ctr_reg[8]_i_1 }),
        .S(sm_reset_rx_cdr_to_ctr_reg[15:8]));
LUT6 #(
    .INIT(64'h00000000FFFF0001)) 
     sm_reset_rx_cdr_to_sat_i_1
       (.I0(n_0_sm_reset_rx_cdr_to_sat_i_2),
        .I1(n_0_sm_reset_rx_cdr_to_sat_i_3),
        .I2(n_0_sm_reset_rx_cdr_to_sat_i_4),
        .I3(n_0_sm_reset_rx_cdr_to_sat_i_5),
        .I4(sm_reset_rx_cdr_to_sat),
        .I5(sm_reset_rx_cdr_to_clr),
        .O(n_0_sm_reset_rx_cdr_to_sat_i_1));
LUT6 #(
    .INIT(64'hFFFFFFFFFFFFFFFD)) 
     sm_reset_rx_cdr_to_sat_i_2
       (.I0(sm_reset_rx_cdr_to_ctr_reg[11]),
        .I1(sm_reset_rx_cdr_to_ctr_reg[21]),
        .I2(sm_reset_rx_cdr_to_ctr_reg[14]),
        .I3(sm_reset_rx_cdr_to_ctr_reg[15]),
        .I4(sm_reset_rx_cdr_to_ctr_reg[20]),
        .I5(sm_reset_rx_cdr_to_ctr_reg[16]),
        .O(n_0_sm_reset_rx_cdr_to_sat_i_2));
LUT6 #(
    .INIT(64'hFFFFFFFFFFFFFFFE)) 
     sm_reset_rx_cdr_to_sat_i_3
       (.I0(sm_reset_rx_cdr_to_ctr_reg[4]),
        .I1(sm_reset_rx_cdr_to_ctr_reg[2]),
        .I2(sm_reset_rx_cdr_to_ctr_reg[9]),
        .I3(sm_reset_rx_cdr_to_ctr_reg[13]),
        .I4(sm_reset_rx_cdr_to_ctr_reg[5]),
        .I5(sm_reset_rx_cdr_to_ctr_reg[7]),
        .O(n_0_sm_reset_rx_cdr_to_sat_i_3));
LUT4 #(
    .INIT(16'hEFFF)) 
     sm_reset_rx_cdr_to_sat_i_4
       (.I0(sm_reset_rx_cdr_to_ctr_reg[1]),
        .I1(sm_reset_rx_cdr_to_ctr_reg[0]),
        .I2(sm_reset_rx_cdr_to_ctr_reg[18]),
        .I3(sm_reset_rx_cdr_to_ctr_reg[17]),
        .O(n_0_sm_reset_rx_cdr_to_sat_i_4));
LUT6 #(
    .INIT(64'h7FFFFFFFFFFFFFFF)) 
     sm_reset_rx_cdr_to_sat_i_5
       (.I0(sm_reset_rx_cdr_to_ctr_reg[8]),
        .I1(sm_reset_rx_cdr_to_ctr_reg[19]),
        .I2(sm_reset_rx_cdr_to_ctr_reg[12]),
        .I3(sm_reset_rx_cdr_to_ctr_reg[10]),
        .I4(sm_reset_rx_cdr_to_ctr_reg[3]),
        .I5(sm_reset_rx_cdr_to_ctr_reg[6]),
        .O(n_0_sm_reset_rx_cdr_to_sat_i_5));
FDRE #(
    .INIT(1'b0)) 
     sm_reset_rx_cdr_to_sat_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(n_0_sm_reset_rx_cdr_to_sat_i_1),
        .Q(sm_reset_rx_cdr_to_sat),
        .R(1'b0));
FDSE #(
    .INIT(1'b1)) 
     sm_reset_rx_timer_clr_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(n_3_bit_synchronizer_plllock_rx_inst),
        .Q(n_0_sm_reset_rx_timer_clr_reg),
        .S(gtwiz_reset_rx_any_sync));
LUT1 #(
    .INIT(2'h1)) 
     \sm_reset_rx_timer_ctr[0]_i_1 
       (.I0(sm_reset_rx_timer_ctr[0]),
        .O(\n_0_sm_reset_rx_timer_ctr[0]_i_1 ));
(* SOFT_HLUTNM = "soft_lutpair5" *) 
   LUT2 #(
    .INIT(4'h6)) 
     \sm_reset_rx_timer_ctr[1]_i_1 
       (.I0(sm_reset_rx_timer_ctr[0]),
        .I1(sm_reset_rx_timer_ctr[1]),
        .O(\n_0_sm_reset_rx_timer_ctr[1]_i_1 ));
LUT3 #(
    .INIT(8'h7F)) 
     \sm_reset_rx_timer_ctr[2]_i_1 
       (.I0(sm_reset_rx_timer_ctr[2]),
        .I1(sm_reset_rx_timer_ctr[0]),
        .I2(sm_reset_rx_timer_ctr[1]),
        .O(\n_0_sm_reset_rx_timer_ctr[2]_i_1 ));
(* SOFT_HLUTNM = "soft_lutpair5" *) 
   LUT3 #(
    .INIT(8'h78)) 
     \sm_reset_rx_timer_ctr[2]_i_2 
       (.I0(sm_reset_rx_timer_ctr[0]),
        .I1(sm_reset_rx_timer_ctr[1]),
        .I2(sm_reset_rx_timer_ctr[2]),
        .O(\n_0_sm_reset_rx_timer_ctr[2]_i_2 ));
FDRE #(
    .INIT(1'b0)) 
     \sm_reset_rx_timer_ctr_reg[0] 
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(\n_0_sm_reset_rx_timer_ctr[2]_i_1 ),
        .D(\n_0_sm_reset_rx_timer_ctr[0]_i_1 ),
        .Q(sm_reset_rx_timer_ctr[0]),
        .R(n_0_sm_reset_rx_timer_clr_reg));
FDRE #(
    .INIT(1'b0)) 
     \sm_reset_rx_timer_ctr_reg[1] 
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(\n_0_sm_reset_rx_timer_ctr[2]_i_1 ),
        .D(\n_0_sm_reset_rx_timer_ctr[1]_i_1 ),
        .Q(sm_reset_rx_timer_ctr[1]),
        .R(n_0_sm_reset_rx_timer_clr_reg));
FDRE #(
    .INIT(1'b0)) 
     \sm_reset_rx_timer_ctr_reg[2] 
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(\n_0_sm_reset_rx_timer_ctr[2]_i_1 ),
        .D(\n_0_sm_reset_rx_timer_ctr[2]_i_2 ),
        .Q(sm_reset_rx_timer_ctr[2]),
        .R(n_0_sm_reset_rx_timer_clr_reg));
(* SOFT_HLUTNM = "soft_lutpair3" *) 
   LUT5 #(
    .INIT(32'h0000FF80)) 
     sm_reset_rx_timer_sat_i_1
       (.I0(sm_reset_rx_timer_ctr[1]),
        .I1(sm_reset_rx_timer_ctr[0]),
        .I2(sm_reset_rx_timer_ctr[2]),
        .I3(sm_reset_rx_timer_sat),
        .I4(n_0_sm_reset_rx_timer_clr_reg),
        .O(n_0_sm_reset_rx_timer_sat_i_1));
FDRE #(
    .INIT(1'b0)) 
     sm_reset_rx_timer_sat_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(n_0_sm_reset_rx_timer_sat_i_1),
        .Q(sm_reset_rx_timer_sat),
        .R(1'b0));
FDSE #(
    .INIT(1'b1)) 
     sm_reset_tx_timer_clr_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(n_0_bit_synchronizer_gtwiz_reset_userclk_tx_active_inst),
        .Q(n_0_sm_reset_tx_timer_clr_reg),
        .S(gtwiz_reset_tx_any_sync));
LUT1 #(
    .INIT(2'h1)) 
     \sm_reset_tx_timer_ctr[0]_i_1 
       (.I0(sm_reset_tx_timer_ctr[0]),
        .O(p_1_in[0]));
(* SOFT_HLUTNM = "soft_lutpair6" *) 
   LUT2 #(
    .INIT(4'h6)) 
     \sm_reset_tx_timer_ctr[1]_i_1 
       (.I0(sm_reset_tx_timer_ctr[0]),
        .I1(sm_reset_tx_timer_ctr[1]),
        .O(p_1_in[1]));
LUT3 #(
    .INIT(8'h7F)) 
     \sm_reset_tx_timer_ctr[2]_i_1 
       (.I0(sm_reset_tx_timer_ctr[2]),
        .I1(sm_reset_tx_timer_ctr[0]),
        .I2(sm_reset_tx_timer_ctr[1]),
        .O(\n_0_sm_reset_tx_timer_ctr[2]_i_1 ));
(* SOFT_HLUTNM = "soft_lutpair6" *) 
   LUT3 #(
    .INIT(8'h78)) 
     \sm_reset_tx_timer_ctr[2]_i_2 
       (.I0(sm_reset_tx_timer_ctr[0]),
        .I1(sm_reset_tx_timer_ctr[1]),
        .I2(sm_reset_tx_timer_ctr[2]),
        .O(p_1_in[2]));
FDRE #(
    .INIT(1'b0)) 
     \sm_reset_tx_timer_ctr_reg[0] 
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(\n_0_sm_reset_tx_timer_ctr[2]_i_1 ),
        .D(p_1_in[0]),
        .Q(sm_reset_tx_timer_ctr[0]),
        .R(n_0_sm_reset_tx_timer_clr_reg));
FDRE #(
    .INIT(1'b0)) 
     \sm_reset_tx_timer_ctr_reg[1] 
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(\n_0_sm_reset_tx_timer_ctr[2]_i_1 ),
        .D(p_1_in[1]),
        .Q(sm_reset_tx_timer_ctr[1]),
        .R(n_0_sm_reset_tx_timer_clr_reg));
FDRE #(
    .INIT(1'b0)) 
     \sm_reset_tx_timer_ctr_reg[2] 
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(\n_0_sm_reset_tx_timer_ctr[2]_i_1 ),
        .D(p_1_in[2]),
        .Q(sm_reset_tx_timer_ctr[2]),
        .R(n_0_sm_reset_tx_timer_clr_reg));
LUT5 #(
    .INIT(32'h0000FF80)) 
     sm_reset_tx_timer_sat_i_1
       (.I0(sm_reset_tx_timer_ctr[1]),
        .I1(sm_reset_tx_timer_ctr[0]),
        .I2(sm_reset_tx_timer_ctr[2]),
        .I3(sm_reset_tx_timer_sat),
        .I4(n_0_sm_reset_tx_timer_clr_reg),
        .O(n_0_sm_reset_tx_timer_sat_i_1));
FDRE #(
    .INIT(1'b0)) 
     sm_reset_tx_timer_sat_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(n_0_sm_reset_tx_timer_sat_i_1),
        .Q(sm_reset_tx_timer_sat),
        .R(1'b0));
(* XILINX_LEGACY_PRIM = "FDE" *) 
   FDRE #(
    .INIT(1'b0)) 
     txuserrdy_out_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(n_1_bit_synchronizer_gtwiz_reset_userclk_tx_active_inst),
        .Q(GTHE3_CHANNEL_TXUSERRDY),
        .R(1'b0));
endmodule

(* ORIG_REF_NAME = "gtwizard_ultrascale_v1_4_reset_synchronizer" *) 
module GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_reset_synchronizer
   (SR,
    gtwiz_reset_clk_freerun_in,
    gtwiz_reset_all_in);
  output [0:0]SR;
  input [0:0]gtwiz_reset_clk_freerun_in;
  input [0:0]gtwiz_reset_all_in;

  wire [0:0]SR;
  wire [0:0]gtwiz_reset_all_in;
  wire [0:0]gtwiz_reset_clk_freerun_in;
  wire rst_in_meta;
  wire rst_in_sync1;
  wire rst_in_sync2;
  wire rst_in_sync3;

(* ASYNC_REG *) 
   (* KEEP = "yes" *) 
   FDPE #(
    .INIT(1'b0)) 
     rst_in_meta_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(1'b0),
        .PRE(gtwiz_reset_all_in),
        .Q(rst_in_meta));
FDPE #(
    .INIT(1'b0)) 
     rst_in_out_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(rst_in_sync3),
        .PRE(gtwiz_reset_all_in),
        .Q(SR));
(* ASYNC_REG *) 
   (* KEEP = "yes" *) 
   FDPE #(
    .INIT(1'b0)) 
     rst_in_sync1_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(rst_in_meta),
        .PRE(gtwiz_reset_all_in),
        .Q(rst_in_sync1));
(* ASYNC_REG *) 
   (* KEEP = "yes" *) 
   FDPE #(
    .INIT(1'b0)) 
     rst_in_sync2_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(rst_in_sync1),
        .PRE(gtwiz_reset_all_in),
        .Q(rst_in_sync2));
(* ASYNC_REG *) 
   (* KEEP = "yes" *) 
   FDPE #(
    .INIT(1'b0)) 
     rst_in_sync3_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(rst_in_sync2),
        .PRE(gtwiz_reset_all_in),
        .Q(rst_in_sync3));
endmodule

(* ORIG_REF_NAME = "gtwizard_ultrascale_v1_4_reset_synchronizer" *) 
module GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_reset_synchronizer_13
   (gtwiz_reset_rx_any_sync,
    O1,
    gtwiz_reset_clk_freerun_in,
    out,
    gtwiz_reset_pllreset_rx_int,
    I1,
    gtwiz_reset_rx_datapath_in,
    gtwiz_reset_rx_pll_and_datapath_in,
    I2);
  output gtwiz_reset_rx_any_sync;
  output O1;
  input [0:0]gtwiz_reset_clk_freerun_in;
  input [2:0]out;
  input gtwiz_reset_pllreset_rx_int;
  input I1;
  input [0:0]gtwiz_reset_rx_datapath_in;
  input [0:0]gtwiz_reset_rx_pll_and_datapath_in;
  input I2;

  wire I1;
  wire I2;
  wire O1;
  wire [0:0]gtwiz_reset_clk_freerun_in;
  wire gtwiz_reset_pllreset_rx_int;
  wire gtwiz_reset_rx_any;
  wire gtwiz_reset_rx_any_sync;
  wire [0:0]gtwiz_reset_rx_datapath_in;
  wire [0:0]gtwiz_reset_rx_pll_and_datapath_in;
  wire [2:0]out;
  wire rst_in_meta;
  wire rst_in_sync1;
  wire rst_in_sync2;
  wire rst_in_sync3;

LUT5 #(
    .INIT(32'hFFDF0010)) 
     pllreset_rx_out_i_1
       (.I0(out[1]),
        .I1(out[2]),
        .I2(out[0]),
        .I3(gtwiz_reset_rx_any_sync),
        .I4(gtwiz_reset_pllreset_rx_int),
        .O(O1));
LUT4 #(
    .INIT(16'hFFFE)) 
     rst_in_meta_i_1__1
       (.I0(I1),
        .I1(gtwiz_reset_rx_datapath_in),
        .I2(gtwiz_reset_rx_pll_and_datapath_in),
        .I3(I2),
        .O(gtwiz_reset_rx_any));
(* ASYNC_REG *) 
   (* KEEP = "yes" *) 
   FDPE #(
    .INIT(1'b0)) 
     rst_in_meta_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(1'b0),
        .PRE(gtwiz_reset_rx_any),
        .Q(rst_in_meta));
FDPE #(
    .INIT(1'b0)) 
     rst_in_out_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(rst_in_sync3),
        .PRE(gtwiz_reset_rx_any),
        .Q(gtwiz_reset_rx_any_sync));
(* ASYNC_REG *) 
   (* KEEP = "yes" *) 
   FDPE #(
    .INIT(1'b0)) 
     rst_in_sync1_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(rst_in_meta),
        .PRE(gtwiz_reset_rx_any),
        .Q(rst_in_sync1));
(* ASYNC_REG *) 
   (* KEEP = "yes" *) 
   FDPE #(
    .INIT(1'b0)) 
     rst_in_sync2_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(rst_in_sync1),
        .PRE(gtwiz_reset_rx_any),
        .Q(rst_in_sync2));
(* ASYNC_REG *) 
   (* KEEP = "yes" *) 
   FDPE #(
    .INIT(1'b0)) 
     rst_in_sync3_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(rst_in_sync2),
        .PRE(gtwiz_reset_rx_any),
        .Q(rst_in_sync3));
endmodule

(* ORIG_REF_NAME = "gtwizard_ultrascale_v1_4_reset_synchronizer" *) 
module GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_reset_synchronizer_14
   (gtwiz_reset_rx_datapath_sync,
    gtwiz_reset_clk_freerun_in,
    gtwiz_reset_rx_datapath_in,
    I1);
  output gtwiz_reset_rx_datapath_sync;
  input [0:0]gtwiz_reset_clk_freerun_in;
  input [0:0]gtwiz_reset_rx_datapath_in;
  input I1;

  wire I1;
  wire [0:0]gtwiz_reset_clk_freerun_in;
  wire [0:0]gtwiz_reset_rx_datapath_in;
  wire gtwiz_reset_rx_datapath_sync;
  wire rst_in0_1;
  wire rst_in_meta;
  wire rst_in_sync1;
  wire rst_in_sync2;
  wire rst_in_sync3;

LUT2 #(
    .INIT(4'hE)) 
     rst_in_meta_i_1__3
       (.I0(gtwiz_reset_rx_datapath_in),
        .I1(I1),
        .O(rst_in0_1));
(* ASYNC_REG *) 
   (* KEEP = "yes" *) 
   FDPE #(
    .INIT(1'b0)) 
     rst_in_meta_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(1'b0),
        .PRE(rst_in0_1),
        .Q(rst_in_meta));
FDPE #(
    .INIT(1'b0)) 
     rst_in_out_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(rst_in_sync3),
        .PRE(rst_in0_1),
        .Q(gtwiz_reset_rx_datapath_sync));
(* ASYNC_REG *) 
   (* KEEP = "yes" *) 
   FDPE #(
    .INIT(1'b0)) 
     rst_in_sync1_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(rst_in_meta),
        .PRE(rst_in0_1),
        .Q(rst_in_sync1));
(* ASYNC_REG *) 
   (* KEEP = "yes" *) 
   FDPE #(
    .INIT(1'b0)) 
     rst_in_sync2_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(rst_in_sync1),
        .PRE(rst_in0_1),
        .Q(rst_in_sync2));
(* ASYNC_REG *) 
   (* KEEP = "yes" *) 
   FDPE #(
    .INIT(1'b0)) 
     rst_in_sync3_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(rst_in_sync2),
        .PRE(rst_in0_1),
        .Q(rst_in_sync3));
endmodule

(* ORIG_REF_NAME = "gtwizard_ultrascale_v1_4_reset_synchronizer" *) 
module GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_reset_synchronizer_15
   (gtwiz_reset_rx_pll_and_datapath_sync,
    gtwiz_reset_clk_freerun_in,
    I1,
    gtwiz_reset_rx_pll_and_datapath_in);
  output gtwiz_reset_rx_pll_and_datapath_sync;
  input [0:0]gtwiz_reset_clk_freerun_in;
  input I1;
  input [0:0]gtwiz_reset_rx_pll_and_datapath_in;

  wire I1;
  wire [0:0]gtwiz_reset_clk_freerun_in;
  wire [0:0]gtwiz_reset_rx_pll_and_datapath_in;
  wire gtwiz_reset_rx_pll_and_datapath_sync;
  wire p_0_in;
  wire rst_in_meta;
  wire rst_in_sync1;
  wire rst_in_sync2;
  wire rst_in_sync3;

LUT2 #(
    .INIT(4'hE)) 
     rst_in_meta_i_1__2
       (.I0(I1),
        .I1(gtwiz_reset_rx_pll_and_datapath_in),
        .O(p_0_in));
(* ASYNC_REG *) 
   (* KEEP = "yes" *) 
   FDPE #(
    .INIT(1'b0)) 
     rst_in_meta_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(1'b0),
        .PRE(p_0_in),
        .Q(rst_in_meta));
FDPE #(
    .INIT(1'b0)) 
     rst_in_out_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(rst_in_sync3),
        .PRE(p_0_in),
        .Q(gtwiz_reset_rx_pll_and_datapath_sync));
(* ASYNC_REG *) 
   (* KEEP = "yes" *) 
   FDPE #(
    .INIT(1'b0)) 
     rst_in_sync1_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(rst_in_meta),
        .PRE(p_0_in),
        .Q(rst_in_sync1));
(* ASYNC_REG *) 
   (* KEEP = "yes" *) 
   FDPE #(
    .INIT(1'b0)) 
     rst_in_sync2_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(rst_in_sync1),
        .PRE(p_0_in),
        .Q(rst_in_sync2));
(* ASYNC_REG *) 
   (* KEEP = "yes" *) 
   FDPE #(
    .INIT(1'b0)) 
     rst_in_sync3_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(rst_in_sync2),
        .PRE(p_0_in),
        .Q(rst_in_sync3));
endmodule

(* ORIG_REF_NAME = "gtwizard_ultrascale_v1_4_reset_synchronizer" *) 
module GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_reset_synchronizer_16
   (gtwiz_reset_tx_any_sync,
    O1,
    gtwiz_reset_clk_freerun_in,
    out,
    gtwiz_reset_pllreset_tx_int,
    gtwiz_reset_tx_datapath_in,
    gtwiz_reset_tx_pll_and_datapath_in,
    I1);
  output gtwiz_reset_tx_any_sync;
  output O1;
  input [0:0]gtwiz_reset_clk_freerun_in;
  input [2:0]out;
  input gtwiz_reset_pllreset_tx_int;
  input [0:0]gtwiz_reset_tx_datapath_in;
  input [0:0]gtwiz_reset_tx_pll_and_datapath_in;
  input I1;

  wire I1;
  wire O1;
  wire [0:0]gtwiz_reset_clk_freerun_in;
  wire gtwiz_reset_pllreset_tx_int;
  wire gtwiz_reset_tx_any;
  wire gtwiz_reset_tx_any_sync;
  wire [0:0]gtwiz_reset_tx_datapath_in;
  wire [0:0]gtwiz_reset_tx_pll_and_datapath_in;
  wire [2:0]out;
  wire rst_in_meta;
  wire rst_in_sync1;
  wire rst_in_sync2;
  wire rst_in_sync3;

LUT5 #(
    .INIT(32'hFFDF0010)) 
     pllreset_tx_out_i_1
       (.I0(out[1]),
        .I1(out[2]),
        .I2(out[0]),
        .I3(gtwiz_reset_tx_any_sync),
        .I4(gtwiz_reset_pllreset_tx_int),
        .O(O1));
LUT3 #(
    .INIT(8'hFE)) 
     rst_in_meta_i_1
       (.I0(gtwiz_reset_tx_datapath_in),
        .I1(gtwiz_reset_tx_pll_and_datapath_in),
        .I2(I1),
        .O(gtwiz_reset_tx_any));
(* ASYNC_REG *) 
   (* KEEP = "yes" *) 
   FDPE #(
    .INIT(1'b0)) 
     rst_in_meta_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(1'b0),
        .PRE(gtwiz_reset_tx_any),
        .Q(rst_in_meta));
FDPE #(
    .INIT(1'b0)) 
     rst_in_out_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(rst_in_sync3),
        .PRE(gtwiz_reset_tx_any),
        .Q(gtwiz_reset_tx_any_sync));
(* ASYNC_REG *) 
   (* KEEP = "yes" *) 
   FDPE #(
    .INIT(1'b0)) 
     rst_in_sync1_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(rst_in_meta),
        .PRE(gtwiz_reset_tx_any),
        .Q(rst_in_sync1));
(* ASYNC_REG *) 
   (* KEEP = "yes" *) 
   FDPE #(
    .INIT(1'b0)) 
     rst_in_sync2_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(rst_in_sync1),
        .PRE(gtwiz_reset_tx_any),
        .Q(rst_in_sync2));
(* ASYNC_REG *) 
   (* KEEP = "yes" *) 
   FDPE #(
    .INIT(1'b0)) 
     rst_in_sync3_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(rst_in_sync2),
        .PRE(gtwiz_reset_tx_any),
        .Q(rst_in_sync3));
endmodule

(* ORIG_REF_NAME = "gtwizard_ultrascale_v1_4_reset_synchronizer" *) 
module GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_reset_synchronizer_17
   (gtwiz_reset_tx_datapath_sync,
    gtwiz_reset_clk_freerun_in,
    gtwiz_reset_tx_datapath_in);
  output gtwiz_reset_tx_datapath_sync;
  input [0:0]gtwiz_reset_clk_freerun_in;
  input [0:0]gtwiz_reset_tx_datapath_in;

  wire [0:0]gtwiz_reset_clk_freerun_in;
  wire [0:0]gtwiz_reset_tx_datapath_in;
  wire gtwiz_reset_tx_datapath_sync;
  wire rst_in_meta;
  wire rst_in_sync1;
  wire rst_in_sync2;
  wire rst_in_sync3;

(* ASYNC_REG *) 
   (* KEEP = "yes" *) 
   FDPE #(
    .INIT(1'b0)) 
     rst_in_meta_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(1'b0),
        .PRE(gtwiz_reset_tx_datapath_in),
        .Q(rst_in_meta));
FDPE #(
    .INIT(1'b0)) 
     rst_in_out_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(rst_in_sync3),
        .PRE(gtwiz_reset_tx_datapath_in),
        .Q(gtwiz_reset_tx_datapath_sync));
(* ASYNC_REG *) 
   (* KEEP = "yes" *) 
   FDPE #(
    .INIT(1'b0)) 
     rst_in_sync1_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(rst_in_meta),
        .PRE(gtwiz_reset_tx_datapath_in),
        .Q(rst_in_sync1));
(* ASYNC_REG *) 
   (* KEEP = "yes" *) 
   FDPE #(
    .INIT(1'b0)) 
     rst_in_sync2_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(rst_in_sync1),
        .PRE(gtwiz_reset_tx_datapath_in),
        .Q(rst_in_sync2));
(* ASYNC_REG *) 
   (* KEEP = "yes" *) 
   FDPE #(
    .INIT(1'b0)) 
     rst_in_sync3_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(rst_in_sync2),
        .PRE(gtwiz_reset_tx_datapath_in),
        .Q(rst_in_sync3));
endmodule

(* ORIG_REF_NAME = "gtwizard_ultrascale_v1_4_reset_synchronizer" *) 
module GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_reset_synchronizer_18
   (gtwiz_reset_tx_pll_and_datapath_sync,
    gtwiz_reset_clk_freerun_in,
    I1,
    gtwiz_reset_tx_pll_and_datapath_in);
  output gtwiz_reset_tx_pll_and_datapath_sync;
  input [0:0]gtwiz_reset_clk_freerun_in;
  input I1;
  input [0:0]gtwiz_reset_tx_pll_and_datapath_in;

  wire I1;
  wire [0:0]gtwiz_reset_clk_freerun_in;
  wire [0:0]gtwiz_reset_tx_pll_and_datapath_in;
  wire gtwiz_reset_tx_pll_and_datapath_sync;
  wire p_1_in_0;
  wire rst_in_meta;
  wire rst_in_sync1;
  wire rst_in_sync2;
  wire rst_in_sync3;

LUT2 #(
    .INIT(4'hE)) 
     rst_in_meta_i_1__0
       (.I0(I1),
        .I1(gtwiz_reset_tx_pll_and_datapath_in),
        .O(p_1_in_0));
(* ASYNC_REG *) 
   (* KEEP = "yes" *) 
   FDPE #(
    .INIT(1'b0)) 
     rst_in_meta_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(1'b0),
        .PRE(p_1_in_0),
        .Q(rst_in_meta));
FDPE #(
    .INIT(1'b0)) 
     rst_in_out_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(rst_in_sync3),
        .PRE(p_1_in_0),
        .Q(gtwiz_reset_tx_pll_and_datapath_sync));
(* ASYNC_REG *) 
   (* KEEP = "yes" *) 
   FDPE #(
    .INIT(1'b0)) 
     rst_in_sync1_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(rst_in_meta),
        .PRE(p_1_in_0),
        .Q(rst_in_sync1));
(* ASYNC_REG *) 
   (* KEEP = "yes" *) 
   FDPE #(
    .INIT(1'b0)) 
     rst_in_sync2_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(rst_in_sync1),
        .PRE(p_1_in_0),
        .Q(rst_in_sync2));
(* ASYNC_REG *) 
   (* KEEP = "yes" *) 
   FDPE #(
    .INIT(1'b0)) 
     rst_in_sync3_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(rst_in_sync2),
        .PRE(p_1_in_0),
        .Q(rst_in_sync3));
endmodule

(* ORIG_REF_NAME = "gtwizard_ultrascale_v1_4_reset_synchronizer" *) 
module GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_reset_synchronizer_19
   (GTHE3_CHANNEL_RXPROGDIVRESET,
    gtwiz_reset_clk_freerun_in,
    rst_in0);
  output [0:0]GTHE3_CHANNEL_RXPROGDIVRESET;
  input [0:0]gtwiz_reset_clk_freerun_in;
  input rst_in0;

  wire [0:0]GTHE3_CHANNEL_RXPROGDIVRESET;
  wire [0:0]gtwiz_reset_clk_freerun_in;
  wire rst_in0;
  wire rst_in_meta;
  wire rst_in_sync1;
  wire rst_in_sync2;
  wire rst_in_sync3;

(* ASYNC_REG *) 
   (* KEEP = "yes" *) 
   FDPE #(
    .INIT(1'b0)) 
     rst_in_meta_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(1'b0),
        .PRE(rst_in0),
        .Q(rst_in_meta));
FDPE #(
    .INIT(1'b0)) 
     rst_in_out_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(rst_in_sync3),
        .PRE(rst_in0),
        .Q(GTHE3_CHANNEL_RXPROGDIVRESET));
(* ASYNC_REG *) 
   (* KEEP = "yes" *) 
   FDPE #(
    .INIT(1'b0)) 
     rst_in_sync1_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(rst_in_meta),
        .PRE(rst_in0),
        .Q(rst_in_sync1));
(* ASYNC_REG *) 
   (* KEEP = "yes" *) 
   FDPE #(
    .INIT(1'b0)) 
     rst_in_sync2_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(rst_in_sync1),
        .PRE(rst_in0),
        .Q(rst_in_sync2));
(* ASYNC_REG *) 
   (* KEEP = "yes" *) 
   FDPE #(
    .INIT(1'b0)) 
     rst_in_sync3_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(rst_in_sync2),
        .PRE(rst_in0),
        .Q(rst_in_sync3));
endmodule

(* ORIG_REF_NAME = "gtwizard_ultrascale_v1_4_reset_synchronizer" *) 
module GthUltrascaleJesdCoregen_gtwizard_ultrascale_v1_4_reset_synchronizer_20
   (GTHE3_CHANNEL_TXPROGDIVRESET,
    gtwiz_reset_clk_freerun_in,
    rst_in0);
  output [0:0]GTHE3_CHANNEL_TXPROGDIVRESET;
  input [0:0]gtwiz_reset_clk_freerun_in;
  input rst_in0;

  wire [0:0]GTHE3_CHANNEL_TXPROGDIVRESET;
  wire [0:0]gtwiz_reset_clk_freerun_in;
  wire rst_in0;
  wire rst_in_meta;
  wire rst_in_sync1;
  wire rst_in_sync2;
  wire rst_in_sync3;

(* ASYNC_REG *) 
   (* KEEP = "yes" *) 
   FDPE #(
    .INIT(1'b0)) 
     rst_in_meta_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(1'b0),
        .PRE(rst_in0),
        .Q(rst_in_meta));
FDPE #(
    .INIT(1'b0)) 
     rst_in_out_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(rst_in_sync3),
        .PRE(rst_in0),
        .Q(GTHE3_CHANNEL_TXPROGDIVRESET));
(* ASYNC_REG *) 
   (* KEEP = "yes" *) 
   FDPE #(
    .INIT(1'b0)) 
     rst_in_sync1_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(rst_in_meta),
        .PRE(rst_in0),
        .Q(rst_in_sync1));
(* ASYNC_REG *) 
   (* KEEP = "yes" *) 
   FDPE #(
    .INIT(1'b0)) 
     rst_in_sync2_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(rst_in_sync1),
        .PRE(rst_in0),
        .Q(rst_in_sync2));
(* ASYNC_REG *) 
   (* KEEP = "yes" *) 
   FDPE #(
    .INIT(1'b0)) 
     rst_in_sync3_reg
       (.C(gtwiz_reset_clk_freerun_in),
        .CE(1'b1),
        .D(rst_in_sync2),
        .PRE(rst_in0),
        .Q(rst_in_sync3));
endmodule
`ifndef GLBL
`define GLBL
`timescale  1 ps / 1 ps

module glbl ();

    parameter ROC_WIDTH = 100000;
    parameter TOC_WIDTH = 0;

//--------   STARTUP Globals --------------
    wire GSR;
    wire GTS;
    wire GWE;
    wire PRLD;
    tri1 p_up_tmp;
    tri (weak1, strong0) PLL_LOCKG = p_up_tmp;

    wire PROGB_GLBL;
    wire CCLKO_GLBL;
    wire FCSBO_GLBL;
    wire [3:0] DO_GLBL;
    wire [3:0] DI_GLBL;
   
    reg GSR_int;
    reg GTS_int;
    reg PRLD_int;

//--------   JTAG Globals --------------
    wire JTAG_TDO_GLBL;
    wire JTAG_TCK_GLBL;
    wire JTAG_TDI_GLBL;
    wire JTAG_TMS_GLBL;
    wire JTAG_TRST_GLBL;

    reg JTAG_CAPTURE_GLBL;
    reg JTAG_RESET_GLBL;
    reg JTAG_SHIFT_GLBL;
    reg JTAG_UPDATE_GLBL;
    reg JTAG_RUNTEST_GLBL;

    reg JTAG_SEL1_GLBL = 0;
    reg JTAG_SEL2_GLBL = 0 ;
    reg JTAG_SEL3_GLBL = 0;
    reg JTAG_SEL4_GLBL = 0;

    reg JTAG_USER_TDO1_GLBL = 1'bz;
    reg JTAG_USER_TDO2_GLBL = 1'bz;
    reg JTAG_USER_TDO3_GLBL = 1'bz;
    reg JTAG_USER_TDO4_GLBL = 1'bz;

    assign (weak1, weak0) GSR = GSR_int;
    assign (weak1, weak0) GTS = GTS_int;
    assign (weak1, weak0) PRLD = PRLD_int;

    initial begin
	GSR_int = 1'b1;
	PRLD_int = 1'b1;
	#(ROC_WIDTH)
	GSR_int = 1'b0;
	PRLD_int = 1'b0;
    end

    initial begin
	GTS_int = 1'b1;
	#(TOC_WIDTH)
	GTS_int = 1'b0;
    end

endmodule
`endif
