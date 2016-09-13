// Copyright 1986-2015 Xilinx, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2015.3 (lin64) Build 1368829 Mon Sep 28 20:06:39 MDT 2015
// Date        : Tue Feb  9 14:39:28 2016
// Host        : rdusr217.slac.stanford.edu running 64-bit Red Hat Enterprise Linux Server release 6.7 (Santiago)
// Command     : write_verilog -force -mode funcsim
//               /u1/ruckman/build/GigEthGth7Dcp/GigEthGth7Dcp_project.srcs/sources_1/ip/GigEthGth7Core/GigEthGth7Core_sim_netlist.v
// Design      : GigEthGth7Core
// Purpose     : This verilog netlist is a functional simulation representation of the design and should not be modified
//               or synthesized. This netlist cannot be used for SDF annotated simulation.
// Device      : xc7vx690tffg1761-3
// --------------------------------------------------------------------------------
`timescale 1 ps / 1 ps

(* core_generation_info = "GigEthGth7Core,gig_ethernet_pcs_pma_v15_1_0,{x_ipProduct=Vivado 2015.3,x_ipVendor=xilinx.com,x_ipLibrary=ip,x_ipName=gig_ethernet_pcs_pma,x_ipVersion=15.1,x_ipCoreRevision=0,x_ipLanguage=VHDL,x_ipSimLanguage=MIXED,c_elaboration_transient_dir=.,c_component_name=GigEthGth7Core,c_family=virtex7,c_is_sgmii=false,c_use_transceiver=true,c_use_tbi=false,c_is_2_5g=false,c_use_lvds=false,c_has_an=false,c_has_mdio=false,c_has_ext_mdio=false,c_sgmii_phy_mode=false,c_dynamic_switching=false,c_sgmii_fabric_buffer=true,c_1588=0,gt_rx_byte_width=1,C_EMAC_IF_TEMAC=true,C_PHYADDR=1,EXAMPLE_SIMULATION=0,c_support_level=false,c_sub_core_name=GigEthGth7Core_gt,c_transceiver_type=GTHE2,c_transceivercontrol=false,c_xdevicefamily=xc7vx690t,c_gt_dmonitorout_width=15,c_gt_drpaddr_width=9,c_gt_txdiffctrl_width=4,c_gt_rxmonitorout_width=7,c_num_of_lanes=1,c_refclkrate=125,c_drpclkrate=50.0}" *) (* downgradeipidentifiedwarnings = "yes" *) (* x_core_info = "gig_ethernet_pcs_pma_v15_1_0,Vivado 2015.3" *) 
(* NotValidForBitStream *)
module GigEthGth7Core
   (gtrefclk,
    gtrefclk_bufg,
    txp,
    txn,
    rxp,
    rxn,
    resetdone,
    cplllock,
    mmcm_reset,
    txoutclk,
    rxoutclk,
    userclk,
    userclk2,
    rxuserclk,
    rxuserclk2,
    pma_reset,
    mmcm_locked,
    independent_clock_bufg,
    gmii_txd,
    gmii_tx_en,
    gmii_tx_er,
    gmii_rxd,
    gmii_rx_dv,
    gmii_rx_er,
    gmii_isolate,
    configuration_vector,
    status_vector,
    reset,
    signal_detect,
    gt0_qplloutclk_in,
    gt0_qplloutrefclk_in);
  input gtrefclk;
  input gtrefclk_bufg;
  output txp;
  output txn;
  input rxp;
  input rxn;
  output resetdone;
  output cplllock;
  output mmcm_reset;
  output txoutclk;
  output rxoutclk;
  input userclk;
  input userclk2;
  input rxuserclk;
  input rxuserclk2;
  input pma_reset;
  input mmcm_locked;
  input independent_clock_bufg;
  input [7:0]gmii_txd;
  input gmii_tx_en;
  input gmii_tx_er;
  output [7:0]gmii_rxd;
  output gmii_rx_dv;
  output gmii_rx_er;
  output gmii_isolate;
  input [4:0]configuration_vector;
  output [15:0]status_vector;
  input reset;
  input signal_detect;
  input gt0_qplloutclk_in;
  input gt0_qplloutrefclk_in;

  wire [4:0]configuration_vector;
  wire cplllock;
  wire gmii_isolate;
  wire gmii_rx_dv;
  wire gmii_rx_er;
  wire [7:0]gmii_rxd;
  wire gmii_tx_en;
  wire gmii_tx_er;
  wire [7:0]gmii_txd;
  wire gt0_qplloutclk_in;
  wire gt0_qplloutrefclk_in;
  wire gtrefclk;
  wire gtrefclk_bufg;
  wire independent_clock_bufg;
  wire mmcm_locked;
  wire mmcm_reset;
  wire pma_reset;
  wire reset;
  wire resetdone;
  wire rxn;
  wire rxoutclk;
  wire rxp;
  wire signal_detect;
  wire [15:0]status_vector;
  wire txn;
  wire txoutclk;
  wire txp;
  wire userclk;
  wire userclk2;

  GigEthGth7Core_GigEthGth7Core_block U0
       (.configuration_vector(configuration_vector),
        .cplllock(cplllock),
        .gmii_isolate(gmii_isolate),
        .gmii_rx_dv(gmii_rx_dv),
        .gmii_rx_er(gmii_rx_er),
        .gmii_rxd(gmii_rxd),
        .gmii_tx_en(gmii_tx_en),
        .gmii_tx_er(gmii_tx_er),
        .gmii_txd(gmii_txd),
        .gt0_qplloutclk_in(gt0_qplloutclk_in),
        .gt0_qplloutrefclk_in(gt0_qplloutrefclk_in),
        .gtrefclk(gtrefclk),
        .gtrefclk_bufg(gtrefclk_bufg),
        .independent_clock_bufg(independent_clock_bufg),
        .mmcm_locked(mmcm_locked),
        .mmcm_reset(mmcm_reset),
        .pma_reset(pma_reset),
        .reset(reset),
        .resetdone(resetdone),
        .rxn(rxn),
        .rxoutclk(rxoutclk),
        .rxp(rxp),
        .signal_detect(signal_detect),
        .status_vector(status_vector),
        .txn(txn),
        .txoutclk(txoutclk),
        .txp(txp),
        .userclk(userclk),
        .userclk2(userclk2));
endmodule

(* ORIG_REF_NAME = "GPCS_PMA_GEN" *) 
module GigEthGth7Core_GPCS_PMA_GEN
   (status_vector,
    MGT_TX_RESET,
    gmii_isolate,
    rxpowerdown_reg_reg,
    MGT_RX_RESET,
    enablealign,
    gmii_rxd,
    gmii_rx_er,
    txchardispmode,
    txcharisk,
    txdata,
    gmii_rx_dv,
    txchardispval,
    userclk2,
    dcm_locked,
    signal_detect,
    userclk,
    reset,
    gmii_tx_en,
    gmii_tx_er,
    configuration_vector,
    gmii_txd,
    rxbufstatus,
    txbuferr,
    rxclkcorcnt,
    rxcharisk,
    rxchariscomma,
    reset_done,
    rxdata,
    rxdisperr,
    rxnotintable);
  output [6:0]status_vector;
  output MGT_TX_RESET;
  output gmii_isolate;
  output rxpowerdown_reg_reg;
  output MGT_RX_RESET;
  output enablealign;
  output [7:0]gmii_rxd;
  output gmii_rx_er;
  output txchardispmode;
  output txcharisk;
  output [7:0]txdata;
  output gmii_rx_dv;
  output txchardispval;
  input userclk2;
  input dcm_locked;
  input signal_detect;
  input userclk;
  input reset;
  input gmii_tx_en;
  input gmii_tx_er;
  input [2:0]configuration_vector;
  input [7:0]gmii_txd;
  input [0:0]rxbufstatus;
  input txbuferr;
  input [2:0]rxclkcorcnt;
  input [0:0]rxcharisk;
  input [0:0]rxchariscomma;
  input reset_done;
  input [7:0]rxdata;
  input [0:0]rxdisperr;
  input [0:0]rxnotintable;

  wire [1:1]CONFIGURATION_VECTOR_REG;
  wire D;
  wire \FSM_sequential_USE_ROCKET_IO.RX_RST_SM[0]_i_1_n_0 ;
  wire \FSM_sequential_USE_ROCKET_IO.RX_RST_SM[1]_i_1_n_0 ;
  wire \FSM_sequential_USE_ROCKET_IO.RX_RST_SM[2]_i_1_n_0 ;
  wire \FSM_sequential_USE_ROCKET_IO.RX_RST_SM[3]_i_1_n_0 ;
  wire \FSM_sequential_USE_ROCKET_IO.TX_RST_SM[0]_i_1_n_0 ;
  wire \FSM_sequential_USE_ROCKET_IO.TX_RST_SM[1]_i_1_n_0 ;
  wire \FSM_sequential_USE_ROCKET_IO.TX_RST_SM[2]_i_1_n_0 ;
  wire \FSM_sequential_USE_ROCKET_IO.TX_RST_SM[3]_i_1_n_0 ;
  wire \MGT_RESET.SYNC_ASYNC_RESET_n_0 ;
  wire MGT_RX_RESET;
  wire MGT_RX_RESET_INT;
  wire MGT_TX_RESET;
  wire MGT_TX_RESET_INT;
  wire \NO_MANAGEMENT.CONFIGURATION_VECTOR_REG[1]_i_1_n_0 ;
  wire \NO_MANAGEMENT.CONFIGURATION_VECTOR_REG[2]_i_1_n_0 ;
  wire \NO_MANAGEMENT.CONFIGURATION_VECTOR_REG[3]_i_1_n_0 ;
  (* async_reg = "true" *) wire RESET_INT;
  (* async_reg = "true" *) wire RESET_INT_PIPE;
  wire RXCLKCORCNT_INT;
  wire RXDISPERR_SRL;
  wire RXEVEN;
  wire RXNOTINTABLE_INT;
  wire RXNOTINTABLE_SRL;
  (* RTL_KEEP = "yes" *) wire [3:0]RX_RST_SM;
  wire SIGNAL_DETECT_MOD;
  (* async_reg = "true" *) wire SRESET;
  (* async_reg = "true" *) wire SRESET_PIPE;
  wire STATUS_VECTOR_0_PRE;
  wire STATUS_VECTOR_0_PRE0;
  wire SYNC_STATUS_REG;
  wire SYNC_STATUS_REG0;
  wire TRANSMITTER_n_0;
  wire TRANSMITTER_n_1;
  wire TRANSMITTER_n_10;
  wire TRANSMITTER_n_11;
  wire TRANSMITTER_n_12;
  wire TRANSMITTER_n_13;
  wire TRANSMITTER_n_14;
  wire TRANSMITTER_n_15;
  wire TRANSMITTER_n_16;
  wire TRANSMITTER_n_17;
  wire TRANSMITTER_n_18;
  wire TRANSMITTER_n_19;
  wire TRANSMITTER_n_2;
  wire TRANSMITTER_n_20;
  wire TRANSMITTER_n_21;
  wire TRANSMITTER_n_3;
  wire TRANSMITTER_n_4;
  wire TRANSMITTER_n_5;
  wire TRANSMITTER_n_6;
  wire TRANSMITTER_n_7;
  wire TRANSMITTER_n_8;
  wire TRANSMITTER_n_9;
  wire TXBUFERR_INT;
  (* RTL_KEEP = "yes" *) wire [3:0]TX_RST_SM;
  wire \USE_ROCKET_IO.NO_1588.RXBUFSTATUS_INT_reg_n_0_[1] ;
  wire \USE_ROCKET_IO.NO_1588.RXCHARISCOMMA_INT_reg_n_0 ;
  wire \USE_ROCKET_IO.NO_1588.RXCHARISK_INT_reg_n_0 ;
  wire \USE_ROCKET_IO.NO_1588.RXCLKCORCNT_INT_reg_n_0_[0] ;
  wire \USE_ROCKET_IO.NO_1588.RXCLKCORCNT_INT_reg_n_0_[1] ;
  wire \USE_ROCKET_IO.NO_1588.RXCLKCORCNT_INT_reg_n_0_[2] ;
  wire \USE_ROCKET_IO.NO_1588.RXDATA_INT_reg_n_0_[0] ;
  wire \USE_ROCKET_IO.NO_1588.RXDATA_INT_reg_n_0_[1] ;
  wire \USE_ROCKET_IO.NO_1588.RXDATA_INT_reg_n_0_[2] ;
  wire \USE_ROCKET_IO.NO_1588.RXDATA_INT_reg_n_0_[3] ;
  wire \USE_ROCKET_IO.NO_1588.RXDATA_INT_reg_n_0_[4] ;
  wire \USE_ROCKET_IO.NO_1588.RXDATA_INT_reg_n_0_[5] ;
  wire \USE_ROCKET_IO.NO_1588.RXDATA_INT_reg_n_0_[6] ;
  wire \USE_ROCKET_IO.NO_1588.RXDATA_INT_reg_n_0_[7] ;
  wire \USE_ROCKET_IO.NO_1588.RXDISPERR_INT_i_1_n_0 ;
  wire \USE_ROCKET_IO.NO_1588.RXNOTINTABLE_INT_i_1_n_0 ;
  wire [2:0]configuration_vector;
  wire dcm_locked;
  wire enablealign;
  wire gmii_isolate;
  wire gmii_rx_dv;
  wire gmii_rx_er;
  wire [7:0]gmii_rxd;
  wire gmii_tx_en;
  wire gmii_tx_er;
  wire [7:0]gmii_txd;
  wire p_0_out;
  wire p_1_out;
  wire p_40_in;
  wire reset;
  wire reset_done;
  wire [0:0]rxbufstatus;
  wire [0:0]rxchariscomma;
  wire [0:0]rxcharisk;
  wire [2:0]rxclkcorcnt;
  wire [7:0]rxdata;
  wire [0:0]rxdisperr;
  wire [0:0]rxnotintable;
  wire rxpowerdown_reg_reg;
  wire signal_detect;
  wire [6:0]status_vector;
  wire txbuferr;
  wire txchardispmode;
  wire txchardispval;
  wire txcharisk;
  wire [7:0]txdata;
  wire userclk;
  wire userclk2;

  (* XILINX_LEGACY_PRIM = "SRL16" *) 
  (* box_type = "PRIMITIVE" *) 
  (* srl_name = "\U0/GigEthGth7Core_core /\gpcs_pma_inst/DELAY_RXDISPERR " *) 
  SRL16E #(
    .INIT(16'h0000)) 
    DELAY_RXDISPERR
       (.A0(1'b0),
        .A1(1'b0),
        .A2(1'b1),
        .A3(1'b0),
        .CE(1'b1),
        .CLK(userclk2),
        .D(D),
        .Q(RXDISPERR_SRL));
  (* XILINX_LEGACY_PRIM = "SRL16" *) 
  (* box_type = "PRIMITIVE" *) 
  (* srl_name = "\U0/GigEthGth7Core_core /\gpcs_pma_inst/DELAY_RXNOTINTABLE " *) 
  SRL16E #(
    .INIT(16'h0000)) 
    DELAY_RXNOTINTABLE
       (.A0(1'b0),
        .A1(1'b0),
        .A2(1'b1),
        .A3(1'b0),
        .CE(1'b1),
        .CLK(userclk2),
        .D(RXNOTINTABLE_INT),
        .Q(RXNOTINTABLE_SRL));
  LUT4 #(
    .INIT(16'h1555)) 
    \FSM_sequential_USE_ROCKET_IO.RX_RST_SM[0]_i_1 
       (.I0(RX_RST_SM[0]),
        .I1(RX_RST_SM[3]),
        .I2(RX_RST_SM[1]),
        .I3(RX_RST_SM[2]),
        .O(\FSM_sequential_USE_ROCKET_IO.RX_RST_SM[0]_i_1_n_0 ));
  LUT4 #(
    .INIT(16'hDA5A)) 
    \FSM_sequential_USE_ROCKET_IO.RX_RST_SM[1]_i_1 
       (.I0(RX_RST_SM[0]),
        .I1(RX_RST_SM[3]),
        .I2(RX_RST_SM[1]),
        .I3(RX_RST_SM[2]),
        .O(\FSM_sequential_USE_ROCKET_IO.RX_RST_SM[1]_i_1_n_0 ));
  LUT4 #(
    .INIT(16'hBFC0)) 
    \FSM_sequential_USE_ROCKET_IO.RX_RST_SM[2]_i_1 
       (.I0(RX_RST_SM[3]),
        .I1(RX_RST_SM[0]),
        .I2(RX_RST_SM[1]),
        .I3(RX_RST_SM[2]),
        .O(\FSM_sequential_USE_ROCKET_IO.RX_RST_SM[2]_i_1_n_0 ));
  LUT4 #(
    .INIT(16'hEAAA)) 
    \FSM_sequential_USE_ROCKET_IO.RX_RST_SM[3]_i_1 
       (.I0(RX_RST_SM[3]),
        .I1(RX_RST_SM[2]),
        .I2(RX_RST_SM[0]),
        .I3(RX_RST_SM[1]),
        .O(\FSM_sequential_USE_ROCKET_IO.RX_RST_SM[3]_i_1_n_0 ));
  (* KEEP = "yes" *) 
  FDRE \FSM_sequential_USE_ROCKET_IO.RX_RST_SM_reg[0] 
       (.C(userclk2),
        .CE(1'b1),
        .D(\FSM_sequential_USE_ROCKET_IO.RX_RST_SM[0]_i_1_n_0 ),
        .Q(RX_RST_SM[0]),
        .R(p_0_out));
  (* KEEP = "yes" *) 
  FDRE \FSM_sequential_USE_ROCKET_IO.RX_RST_SM_reg[1] 
       (.C(userclk2),
        .CE(1'b1),
        .D(\FSM_sequential_USE_ROCKET_IO.RX_RST_SM[1]_i_1_n_0 ),
        .Q(RX_RST_SM[1]),
        .R(p_0_out));
  (* KEEP = "yes" *) 
  FDRE \FSM_sequential_USE_ROCKET_IO.RX_RST_SM_reg[2] 
       (.C(userclk2),
        .CE(1'b1),
        .D(\FSM_sequential_USE_ROCKET_IO.RX_RST_SM[2]_i_1_n_0 ),
        .Q(RX_RST_SM[2]),
        .R(p_0_out));
  (* KEEP = "yes" *) 
  FDRE \FSM_sequential_USE_ROCKET_IO.RX_RST_SM_reg[3] 
       (.C(userclk2),
        .CE(1'b1),
        .D(\FSM_sequential_USE_ROCKET_IO.RX_RST_SM[3]_i_1_n_0 ),
        .Q(RX_RST_SM[3]),
        .R(p_0_out));
  LUT4 #(
    .INIT(16'h1555)) 
    \FSM_sequential_USE_ROCKET_IO.TX_RST_SM[0]_i_1 
       (.I0(TX_RST_SM[0]),
        .I1(TX_RST_SM[3]),
        .I2(TX_RST_SM[1]),
        .I3(TX_RST_SM[2]),
        .O(\FSM_sequential_USE_ROCKET_IO.TX_RST_SM[0]_i_1_n_0 ));
  LUT4 #(
    .INIT(16'hDA5A)) 
    \FSM_sequential_USE_ROCKET_IO.TX_RST_SM[1]_i_1 
       (.I0(TX_RST_SM[0]),
        .I1(TX_RST_SM[3]),
        .I2(TX_RST_SM[1]),
        .I3(TX_RST_SM[2]),
        .O(\FSM_sequential_USE_ROCKET_IO.TX_RST_SM[1]_i_1_n_0 ));
  LUT4 #(
    .INIT(16'hBFC0)) 
    \FSM_sequential_USE_ROCKET_IO.TX_RST_SM[2]_i_1 
       (.I0(TX_RST_SM[3]),
        .I1(TX_RST_SM[0]),
        .I2(TX_RST_SM[1]),
        .I3(TX_RST_SM[2]),
        .O(\FSM_sequential_USE_ROCKET_IO.TX_RST_SM[2]_i_1_n_0 ));
  LUT4 #(
    .INIT(16'hEAAA)) 
    \FSM_sequential_USE_ROCKET_IO.TX_RST_SM[3]_i_1 
       (.I0(TX_RST_SM[3]),
        .I1(TX_RST_SM[2]),
        .I2(TX_RST_SM[0]),
        .I3(TX_RST_SM[1]),
        .O(\FSM_sequential_USE_ROCKET_IO.TX_RST_SM[3]_i_1_n_0 ));
  (* KEEP = "yes" *) 
  FDRE \FSM_sequential_USE_ROCKET_IO.TX_RST_SM_reg[0] 
       (.C(userclk2),
        .CE(1'b1),
        .D(\FSM_sequential_USE_ROCKET_IO.TX_RST_SM[0]_i_1_n_0 ),
        .Q(TX_RST_SM[0]),
        .R(p_1_out));
  (* KEEP = "yes" *) 
  FDRE \FSM_sequential_USE_ROCKET_IO.TX_RST_SM_reg[1] 
       (.C(userclk2),
        .CE(1'b1),
        .D(\FSM_sequential_USE_ROCKET_IO.TX_RST_SM[1]_i_1_n_0 ),
        .Q(TX_RST_SM[1]),
        .R(p_1_out));
  (* KEEP = "yes" *) 
  FDRE \FSM_sequential_USE_ROCKET_IO.TX_RST_SM_reg[2] 
       (.C(userclk2),
        .CE(1'b1),
        .D(\FSM_sequential_USE_ROCKET_IO.TX_RST_SM[2]_i_1_n_0 ),
        .Q(TX_RST_SM[2]),
        .R(p_1_out));
  (* KEEP = "yes" *) 
  FDRE \FSM_sequential_USE_ROCKET_IO.TX_RST_SM_reg[3] 
       (.C(userclk2),
        .CE(1'b1),
        .D(\FSM_sequential_USE_ROCKET_IO.TX_RST_SM[3]_i_1_n_0 ),
        .Q(TX_RST_SM[3]),
        .R(p_1_out));
  (* ASYNC_REG *) 
  (* KEEP = "yes" *) 
  FDPE #(
    .INIT(1'b0)) 
    \MGT_RESET.RESET_INT_PIPE_reg 
       (.C(userclk),
        .CE(1'b1),
        .D(1'b0),
        .PRE(\MGT_RESET.SYNC_ASYNC_RESET_n_0 ),
        .Q(RESET_INT_PIPE));
  (* ASYNC_REG *) 
  (* KEEP = "yes" *) 
  FDPE #(
    .INIT(1'b0)) 
    \MGT_RESET.RESET_INT_reg 
       (.C(userclk),
        .CE(1'b1),
        .D(RESET_INT_PIPE),
        .PRE(\MGT_RESET.SYNC_ASYNC_RESET_n_0 ),
        .Q(RESET_INT));
  (* ASYNC_REG *) 
  (* KEEP = "yes" *) 
  FDRE #(
    .INIT(1'b0)) 
    \MGT_RESET.SRESET_PIPE_reg 
       (.C(userclk2),
        .CE(1'b1),
        .D(RESET_INT),
        .Q(SRESET_PIPE),
        .R(1'b0));
  (* ASYNC_REG *) 
  (* KEEP = "yes" *) 
  FDSE #(
    .INIT(1'b0)) 
    \MGT_RESET.SRESET_reg 
       (.C(userclk2),
        .CE(1'b1),
        .D(SRESET_PIPE),
        .Q(SRESET),
        .S(RESET_INT));
  GigEthGth7Core_reset_sync_block \MGT_RESET.SYNC_ASYNC_RESET 
       (.\MGT_RESET.RESET_INT_PIPE_reg (\MGT_RESET.SYNC_ASYNC_RESET_n_0 ),
        .dcm_locked(dcm_locked),
        .reset(reset),
        .userclk(userclk));
  LUT2 #(
    .INIT(4'h2)) 
    \NO_MANAGEMENT.CONFIGURATION_VECTOR_REG[1]_i_1 
       (.I0(configuration_vector[0]),
        .I1(SRESET),
        .O(\NO_MANAGEMENT.CONFIGURATION_VECTOR_REG[1]_i_1_n_0 ));
  LUT2 #(
    .INIT(4'h2)) 
    \NO_MANAGEMENT.CONFIGURATION_VECTOR_REG[2]_i_1 
       (.I0(configuration_vector[1]),
        .I1(SRESET),
        .O(\NO_MANAGEMENT.CONFIGURATION_VECTOR_REG[2]_i_1_n_0 ));
  LUT2 #(
    .INIT(4'h2)) 
    \NO_MANAGEMENT.CONFIGURATION_VECTOR_REG[3]_i_1 
       (.I0(configuration_vector[2]),
        .I1(SRESET),
        .O(\NO_MANAGEMENT.CONFIGURATION_VECTOR_REG[3]_i_1_n_0 ));
  FDRE #(
    .INIT(1'b0)) 
    \NO_MANAGEMENT.CONFIGURATION_VECTOR_REG_reg[1] 
       (.C(userclk2),
        .CE(1'b1),
        .D(\NO_MANAGEMENT.CONFIGURATION_VECTOR_REG[1]_i_1_n_0 ),
        .Q(CONFIGURATION_VECTOR_REG),
        .R(1'b0));
  FDRE #(
    .INIT(1'b0)) 
    \NO_MANAGEMENT.CONFIGURATION_VECTOR_REG_reg[2] 
       (.C(userclk2),
        .CE(1'b1),
        .D(\NO_MANAGEMENT.CONFIGURATION_VECTOR_REG[2]_i_1_n_0 ),
        .Q(rxpowerdown_reg_reg),
        .R(1'b0));
  FDRE #(
    .INIT(1'b0)) 
    \NO_MANAGEMENT.CONFIGURATION_VECTOR_REG_reg[3] 
       (.C(userclk2),
        .CE(1'b1),
        .D(\NO_MANAGEMENT.CONFIGURATION_VECTOR_REG[3]_i_1_n_0 ),
        .Q(gmii_isolate),
        .R(1'b0));
  GigEthGth7Core_RX RECEIVER
       (.D(D),
        .\NO_MANAGEMENT.CONFIGURATION_VECTOR_REG_reg[2] (rxpowerdown_reg_reg),
        .\NO_MANAGEMENT.CONFIGURATION_VECTOR_REG_reg[3] (gmii_isolate),
        .Q({\USE_ROCKET_IO.NO_1588.RXDATA_INT_reg_n_0_[7] ,\USE_ROCKET_IO.NO_1588.RXDATA_INT_reg_n_0_[6] ,\USE_ROCKET_IO.NO_1588.RXDATA_INT_reg_n_0_[5] ,\USE_ROCKET_IO.NO_1588.RXDATA_INT_reg_n_0_[4] ,\USE_ROCKET_IO.NO_1588.RXDATA_INT_reg_n_0_[3] ,\USE_ROCKET_IO.NO_1588.RXDATA_INT_reg_n_0_[2] ,\USE_ROCKET_IO.NO_1588.RXDATA_INT_reg_n_0_[1] ,\USE_ROCKET_IO.NO_1588.RXDATA_INT_reg_n_0_[0] }),
        .RXEVEN(RXEVEN),
        .RXNOTINTABLE_INT(RXNOTINTABLE_INT),
        .SR(MGT_RX_RESET),
        .SYNC_STATUS_REG0(SYNC_STATUS_REG0),
        .\USE_ROCKET_IO.NO_1588.RXBUFSTATUS_INT_reg[1] (\USE_ROCKET_IO.NO_1588.RXBUFSTATUS_INT_reg_n_0_[1] ),
        .\USE_ROCKET_IO.NO_1588.RXCHARISK_INT_reg (\USE_ROCKET_IO.NO_1588.RXCHARISK_INT_reg_n_0 ),
        .\USE_ROCKET_IO.NO_1588.RXCLKCORCNT_INT_reg[2] ({\USE_ROCKET_IO.NO_1588.RXCLKCORCNT_INT_reg_n_0_[2] ,\USE_ROCKET_IO.NO_1588.RXCLKCORCNT_INT_reg_n_0_[1] ,\USE_ROCKET_IO.NO_1588.RXCLKCORCNT_INT_reg_n_0_[0] }),
        .gmii_rx_dv(gmii_rx_dv),
        .gmii_rx_er(gmii_rx_er),
        .gmii_rxd(gmii_rxd),
        .p_40_in(p_40_in),
        .status_vector(status_vector[4:2]),
        .userclk2(userclk2));
  FDRE #(
    .INIT(1'b0)) 
    RXDISPERR_REG_reg
       (.C(userclk2),
        .CE(1'b1),
        .D(RXDISPERR_SRL),
        .Q(status_vector[5]),
        .R(1'b0));
  FDRE #(
    .INIT(1'b0)) 
    RXNOTINTABLE_REG_reg
       (.C(userclk2),
        .CE(1'b1),
        .D(RXNOTINTABLE_SRL),
        .Q(status_vector[6]),
        .R(1'b0));
  FDRE #(
    .INIT(1'b0)) 
    STATUS_VECTOR_0_PRE_reg
       (.C(userclk2),
        .CE(1'b1),
        .D(STATUS_VECTOR_0_PRE0),
        .Q(STATUS_VECTOR_0_PRE),
        .R(1'b0));
  FDRE \STATUS_VECTOR_reg[0] 
       (.C(userclk2),
        .CE(1'b1),
        .D(STATUS_VECTOR_0_PRE),
        .Q(status_vector[0]),
        .R(1'b0));
  FDRE \STATUS_VECTOR_reg[1] 
       (.C(userclk2),
        .CE(1'b1),
        .D(SYNC_STATUS_REG),
        .Q(status_vector[1]),
        .R(1'b0));
  GigEthGth7Core_SYNCHRONISE SYNCHRONISATION
       (.CONFIGURATION_VECTOR_REG(CONFIGURATION_VECTOR_REG),
        .D(D),
        .RXEVEN(RXEVEN),
        .RXNOTINTABLE_INT(RXNOTINTABLE_INT),
        .SIGNAL_DETECT_MOD(SIGNAL_DETECT_MOD),
        .SR(MGT_RX_RESET),
        .STATUS_VECTOR_0_PRE0(STATUS_VECTOR_0_PRE0),
        .SYNC_STATUS_REG0(SYNC_STATUS_REG0),
        .\USE_ROCKET_IO.NO_1588.RXBUFSTATUS_INT_reg[1] (\USE_ROCKET_IO.NO_1588.RXBUFSTATUS_INT_reg_n_0_[1] ),
        .\USE_ROCKET_IO.NO_1588.RXCHARISCOMMA_INT_reg (\USE_ROCKET_IO.NO_1588.RXCHARISCOMMA_INT_reg_n_0 ),
        .\USE_ROCKET_IO.NO_1588.RXCHARISK_INT_reg (\USE_ROCKET_IO.NO_1588.RXCHARISK_INT_reg_n_0 ),
        .enablealign(enablealign),
        .p_40_in(p_40_in),
        .reset_done(reset_done),
        .userclk2(userclk2));
  GigEthGth7Core_sync_block SYNC_SIGNAL_DETECT
       (.\NO_MANAGEMENT.CONFIGURATION_VECTOR_REG_reg[2] (rxpowerdown_reg_reg),
        .SIGNAL_DETECT_MOD(SIGNAL_DETECT_MOD),
        .signal_detect(signal_detect),
        .userclk2(userclk2));
  FDRE #(
    .INIT(1'b0)) 
    SYNC_STATUS_REG_reg
       (.C(userclk2),
        .CE(1'b1),
        .D(p_40_in),
        .Q(SYNC_STATUS_REG),
        .R(1'b0));
  GigEthGth7Core_TX TRANSMITTER
       (.CONFIGURATION_VECTOR_REG(CONFIGURATION_VECTOR_REG),
        .D({TRANSMITTER_n_2,TRANSMITTER_n_3,TRANSMITTER_n_4,TRANSMITTER_n_5}),
        .\NO_MANAGEMENT.CONFIGURATION_VECTOR_REG_reg[3] (gmii_isolate),
        .\USE_ROCKET_IO.MGT_TX_RESET_INT_reg (MGT_TX_RESET),
        .\USE_ROCKET_IO.NO_1588.RXCHARISCOMMA_INT_reg (TRANSMITTER_n_11),
        .\USE_ROCKET_IO.NO_1588.RXCHARISK_INT_reg (TRANSMITTER_n_10),
        .\USE_ROCKET_IO.NO_1588.RXDATA_INT_reg[7] ({TRANSMITTER_n_12,TRANSMITTER_n_13,TRANSMITTER_n_14,TRANSMITTER_n_15,TRANSMITTER_n_16,TRANSMITTER_n_17,TRANSMITTER_n_18,TRANSMITTER_n_19}),
        .\USE_ROCKET_IO.TXCHARDISPMODE_reg (TRANSMITTER_n_0),
        .\USE_ROCKET_IO.TXCHARDISPVAL_reg (TRANSMITTER_n_21),
        .\USE_ROCKET_IO.TXCHARISK_reg (TRANSMITTER_n_9),
        .\USE_ROCKET_IO.TXDATA_reg[2] (TRANSMITTER_n_8),
        .\USE_ROCKET_IO.TXDATA_reg[2]_0 (TRANSMITTER_n_20),
        .\USE_ROCKET_IO.TXDATA_reg[3] (TRANSMITTER_n_7),
        .\USE_ROCKET_IO.TXDATA_reg[5] (TRANSMITTER_n_6),
        .\USE_ROCKET_IO.TXDATA_reg[7] (TRANSMITTER_n_1),
        .gmii_tx_en(gmii_tx_en),
        .gmii_tx_er(gmii_tx_er),
        .gmii_txd(gmii_txd),
        .rxchariscomma(rxchariscomma),
        .rxcharisk(rxcharisk),
        .rxdata(rxdata),
        .userclk2(userclk2));
  LUT2 #(
    .INIT(4'hE)) 
    \USE_ROCKET_IO.MGT_RX_RESET_INT_i_1 
       (.I0(RESET_INT),
        .I1(\USE_ROCKET_IO.NO_1588.RXBUFSTATUS_INT_reg_n_0_[1] ),
        .O(p_0_out));
  LUT3 #(
    .INIT(8'h7F)) 
    \USE_ROCKET_IO.MGT_RX_RESET_INT_i_2 
       (.I0(RX_RST_SM[2]),
        .I1(RX_RST_SM[1]),
        .I2(RX_RST_SM[3]),
        .O(MGT_RX_RESET_INT));
  FDSE #(
    .INIT(1'b0)) 
    \USE_ROCKET_IO.MGT_RX_RESET_INT_reg 
       (.C(userclk2),
        .CE(1'b1),
        .D(MGT_RX_RESET_INT),
        .Q(MGT_RX_RESET),
        .S(p_0_out));
  LUT2 #(
    .INIT(4'hE)) 
    \USE_ROCKET_IO.MGT_TX_RESET_INT_i_1 
       (.I0(RESET_INT),
        .I1(TXBUFERR_INT),
        .O(p_1_out));
  LUT3 #(
    .INIT(8'h7F)) 
    \USE_ROCKET_IO.MGT_TX_RESET_INT_i_2 
       (.I0(TX_RST_SM[2]),
        .I1(TX_RST_SM[1]),
        .I2(TX_RST_SM[3]),
        .O(MGT_TX_RESET_INT));
  FDSE #(
    .INIT(1'b0)) 
    \USE_ROCKET_IO.MGT_TX_RESET_INT_reg 
       (.C(userclk2),
        .CE(1'b1),
        .D(MGT_TX_RESET_INT),
        .Q(MGT_TX_RESET),
        .S(p_1_out));
  LUT2 #(
    .INIT(4'hE)) 
    \USE_ROCKET_IO.NO_1588.RXBUFSTATUS_INT[1]_i_1 
       (.I0(MGT_RX_RESET),
        .I1(CONFIGURATION_VECTOR_REG),
        .O(RXCLKCORCNT_INT));
  FDRE #(
    .INIT(1'b0)) 
    \USE_ROCKET_IO.NO_1588.RXBUFSTATUS_INT_reg[1] 
       (.C(userclk2),
        .CE(1'b1),
        .D(rxbufstatus),
        .Q(\USE_ROCKET_IO.NO_1588.RXBUFSTATUS_INT_reg_n_0_[1] ),
        .R(RXCLKCORCNT_INT));
  FDRE #(
    .INIT(1'b0)) 
    \USE_ROCKET_IO.NO_1588.RXCHARISCOMMA_INT_reg 
       (.C(userclk2),
        .CE(1'b1),
        .D(TRANSMITTER_n_11),
        .Q(\USE_ROCKET_IO.NO_1588.RXCHARISCOMMA_INT_reg_n_0 ),
        .R(MGT_RX_RESET));
  FDRE #(
    .INIT(1'b0)) 
    \USE_ROCKET_IO.NO_1588.RXCHARISK_INT_reg 
       (.C(userclk2),
        .CE(1'b1),
        .D(TRANSMITTER_n_10),
        .Q(\USE_ROCKET_IO.NO_1588.RXCHARISK_INT_reg_n_0 ),
        .R(MGT_RX_RESET));
  FDRE #(
    .INIT(1'b0)) 
    \USE_ROCKET_IO.NO_1588.RXCLKCORCNT_INT_reg[0] 
       (.C(userclk2),
        .CE(1'b1),
        .D(rxclkcorcnt[0]),
        .Q(\USE_ROCKET_IO.NO_1588.RXCLKCORCNT_INT_reg_n_0_[0] ),
        .R(RXCLKCORCNT_INT));
  FDRE #(
    .INIT(1'b0)) 
    \USE_ROCKET_IO.NO_1588.RXCLKCORCNT_INT_reg[1] 
       (.C(userclk2),
        .CE(1'b1),
        .D(rxclkcorcnt[1]),
        .Q(\USE_ROCKET_IO.NO_1588.RXCLKCORCNT_INT_reg_n_0_[1] ),
        .R(RXCLKCORCNT_INT));
  FDRE #(
    .INIT(1'b0)) 
    \USE_ROCKET_IO.NO_1588.RXCLKCORCNT_INT_reg[2] 
       (.C(userclk2),
        .CE(1'b1),
        .D(rxclkcorcnt[2]),
        .Q(\USE_ROCKET_IO.NO_1588.RXCLKCORCNT_INT_reg_n_0_[2] ),
        .R(RXCLKCORCNT_INT));
  FDRE #(
    .INIT(1'b0)) 
    \USE_ROCKET_IO.NO_1588.RXDATA_INT_reg[0] 
       (.C(userclk2),
        .CE(1'b1),
        .D(TRANSMITTER_n_19),
        .Q(\USE_ROCKET_IO.NO_1588.RXDATA_INT_reg_n_0_[0] ),
        .R(MGT_RX_RESET));
  FDRE #(
    .INIT(1'b0)) 
    \USE_ROCKET_IO.NO_1588.RXDATA_INT_reg[1] 
       (.C(userclk2),
        .CE(1'b1),
        .D(TRANSMITTER_n_18),
        .Q(\USE_ROCKET_IO.NO_1588.RXDATA_INT_reg_n_0_[1] ),
        .R(MGT_RX_RESET));
  FDRE #(
    .INIT(1'b0)) 
    \USE_ROCKET_IO.NO_1588.RXDATA_INT_reg[2] 
       (.C(userclk2),
        .CE(1'b1),
        .D(TRANSMITTER_n_17),
        .Q(\USE_ROCKET_IO.NO_1588.RXDATA_INT_reg_n_0_[2] ),
        .R(MGT_RX_RESET));
  FDRE #(
    .INIT(1'b0)) 
    \USE_ROCKET_IO.NO_1588.RXDATA_INT_reg[3] 
       (.C(userclk2),
        .CE(1'b1),
        .D(TRANSMITTER_n_16),
        .Q(\USE_ROCKET_IO.NO_1588.RXDATA_INT_reg_n_0_[3] ),
        .R(MGT_RX_RESET));
  FDRE #(
    .INIT(1'b0)) 
    \USE_ROCKET_IO.NO_1588.RXDATA_INT_reg[4] 
       (.C(userclk2),
        .CE(1'b1),
        .D(TRANSMITTER_n_15),
        .Q(\USE_ROCKET_IO.NO_1588.RXDATA_INT_reg_n_0_[4] ),
        .R(MGT_RX_RESET));
  FDRE #(
    .INIT(1'b0)) 
    \USE_ROCKET_IO.NO_1588.RXDATA_INT_reg[5] 
       (.C(userclk2),
        .CE(1'b1),
        .D(TRANSMITTER_n_14),
        .Q(\USE_ROCKET_IO.NO_1588.RXDATA_INT_reg_n_0_[5] ),
        .R(MGT_RX_RESET));
  FDRE #(
    .INIT(1'b0)) 
    \USE_ROCKET_IO.NO_1588.RXDATA_INT_reg[6] 
       (.C(userclk2),
        .CE(1'b1),
        .D(TRANSMITTER_n_13),
        .Q(\USE_ROCKET_IO.NO_1588.RXDATA_INT_reg_n_0_[6] ),
        .R(MGT_RX_RESET));
  FDRE #(
    .INIT(1'b0)) 
    \USE_ROCKET_IO.NO_1588.RXDATA_INT_reg[7] 
       (.C(userclk2),
        .CE(1'b1),
        .D(TRANSMITTER_n_12),
        .Q(\USE_ROCKET_IO.NO_1588.RXDATA_INT_reg_n_0_[7] ),
        .R(MGT_RX_RESET));
  (* SOFT_HLUTNM = "soft_lutpair37" *) 
  LUT3 #(
    .INIT(8'h02)) 
    \USE_ROCKET_IO.NO_1588.RXDISPERR_INT_i_1 
       (.I0(rxdisperr),
        .I1(CONFIGURATION_VECTOR_REG),
        .I2(MGT_RX_RESET),
        .O(\USE_ROCKET_IO.NO_1588.RXDISPERR_INT_i_1_n_0 ));
  FDRE #(
    .INIT(1'b0)) 
    \USE_ROCKET_IO.NO_1588.RXDISPERR_INT_reg 
       (.C(userclk2),
        .CE(1'b1),
        .D(\USE_ROCKET_IO.NO_1588.RXDISPERR_INT_i_1_n_0 ),
        .Q(D),
        .R(1'b0));
  (* SOFT_HLUTNM = "soft_lutpair37" *) 
  LUT3 #(
    .INIT(8'h02)) 
    \USE_ROCKET_IO.NO_1588.RXNOTINTABLE_INT_i_1 
       (.I0(rxnotintable),
        .I1(CONFIGURATION_VECTOR_REG),
        .I2(MGT_RX_RESET),
        .O(\USE_ROCKET_IO.NO_1588.RXNOTINTABLE_INT_i_1_n_0 ));
  FDRE #(
    .INIT(1'b0)) 
    \USE_ROCKET_IO.NO_1588.RXNOTINTABLE_INT_reg 
       (.C(userclk2),
        .CE(1'b1),
        .D(\USE_ROCKET_IO.NO_1588.RXNOTINTABLE_INT_i_1_n_0 ),
        .Q(RXNOTINTABLE_INT),
        .R(1'b0));
  FDRE #(
    .INIT(1'b0)) 
    \USE_ROCKET_IO.TXBUFERR_INT_reg 
       (.C(userclk2),
        .CE(1'b1),
        .D(txbuferr),
        .Q(TXBUFERR_INT),
        .R(MGT_TX_RESET));
  FDRE \USE_ROCKET_IO.TXCHARDISPMODE_reg 
       (.C(userclk2),
        .CE(1'b1),
        .D(TRANSMITTER_n_0),
        .Q(txchardispmode),
        .R(MGT_TX_RESET));
  FDRE \USE_ROCKET_IO.TXCHARDISPVAL_reg 
       (.C(userclk2),
        .CE(1'b1),
        .D(TRANSMITTER_n_21),
        .Q(txchardispval),
        .R(1'b0));
  FDRE \USE_ROCKET_IO.TXCHARISK_reg 
       (.C(userclk2),
        .CE(1'b1),
        .D(TRANSMITTER_n_9),
        .Q(txcharisk),
        .R(MGT_TX_RESET));
  FDRE \USE_ROCKET_IO.TXDATA_reg[0] 
       (.C(userclk2),
        .CE(1'b1),
        .D(TRANSMITTER_n_5),
        .Q(txdata[0]),
        .R(1'b0));
  FDRE \USE_ROCKET_IO.TXDATA_reg[1] 
       (.C(userclk2),
        .CE(1'b1),
        .D(TRANSMITTER_n_4),
        .Q(txdata[1]),
        .R(1'b0));
  FDSE \USE_ROCKET_IO.TXDATA_reg[2] 
       (.C(userclk2),
        .CE(1'b1),
        .D(TRANSMITTER_n_8),
        .Q(txdata[2]),
        .S(TRANSMITTER_n_20));
  FDSE \USE_ROCKET_IO.TXDATA_reg[3] 
       (.C(userclk2),
        .CE(1'b1),
        .D(TRANSMITTER_n_7),
        .Q(txdata[3]),
        .S(TRANSMITTER_n_20));
  FDRE \USE_ROCKET_IO.TXDATA_reg[4] 
       (.C(userclk2),
        .CE(1'b1),
        .D(TRANSMITTER_n_3),
        .Q(txdata[4]),
        .R(1'b0));
  FDSE \USE_ROCKET_IO.TXDATA_reg[5] 
       (.C(userclk2),
        .CE(1'b1),
        .D(TRANSMITTER_n_6),
        .Q(txdata[5]),
        .S(TRANSMITTER_n_20));
  FDRE \USE_ROCKET_IO.TXDATA_reg[6] 
       (.C(userclk2),
        .CE(1'b1),
        .D(TRANSMITTER_n_2),
        .Q(txdata[6]),
        .R(1'b0));
  FDSE \USE_ROCKET_IO.TXDATA_reg[7] 
       (.C(userclk2),
        .CE(1'b1),
        .D(TRANSMITTER_n_1),
        .Q(txdata[7]),
        .S(TRANSMITTER_n_20));
endmodule

(* ORIG_REF_NAME = "GigEthGth7Core_GTWIZARD" *) 
module GigEthGth7Core_GigEthGth7Core_GTWIZARD
   (cplllock,
    txn,
    txp,
    rxoutclk,
    txoutclk,
    D,
    TXBUFSTATUS,
    RXBUFSTATUS,
    \rxdata_reg_reg[15] ,
    \rxchariscomma_reg_reg[1] ,
    \rxcharisk_reg_reg[1] ,
    \rxdisperr_reg_reg[1] ,
    \rxnotintable_reg_reg[1] ,
    mmcm_reset,
    data_in,
    data_sync_reg1,
    gtrefclk_bufg,
    independent_clock_bufg,
    rxn,
    rxp,
    gtrefclk,
    gt0_qplloutclk_in,
    gt0_qplloutrefclk_in,
    reset_out,
    reset,
    userclk,
    TXPD,
    RXPD,
    Q,
    \txchardispmode_int_reg[1] ,
    \txchardispval_int_reg[1] ,
    \txcharisk_int_reg[1] ,
    pma_reset,
    reset_sync6,
    reset_sync6_0,
    mmcm_locked,
    data_out);
  output cplllock;
  output txn;
  output txp;
  output rxoutclk;
  output txoutclk;
  output [1:0]D;
  output [0:0]TXBUFSTATUS;
  output [0:0]RXBUFSTATUS;
  output [15:0]\rxdata_reg_reg[15] ;
  output [1:0]\rxchariscomma_reg_reg[1] ;
  output [1:0]\rxcharisk_reg_reg[1] ;
  output [1:0]\rxdisperr_reg_reg[1] ;
  output [1:0]\rxnotintable_reg_reg[1] ;
  output mmcm_reset;
  output data_in;
  output data_sync_reg1;
  input gtrefclk_bufg;
  input independent_clock_bufg;
  input rxn;
  input rxp;
  input gtrefclk;
  input gt0_qplloutclk_in;
  input gt0_qplloutrefclk_in;
  input reset_out;
  input reset;
  input userclk;
  input [0:0]TXPD;
  input [0:0]RXPD;
  input [15:0]Q;
  input [1:0]\txchardispmode_int_reg[1] ;
  input [1:0]\txchardispval_int_reg[1] ;
  input [1:0]\txcharisk_int_reg[1] ;
  input pma_reset;
  input reset_sync6;
  input reset_sync6_0;
  input mmcm_locked;
  input data_out;

  wire [1:0]D;
  wire [15:0]Q;
  wire [0:0]RXBUFSTATUS;
  wire [0:0]RXPD;
  wire [0:0]TXBUFSTATUS;
  wire [0:0]TXPD;
  wire cplllock;
  wire data_in;
  wire data_out;
  wire data_sync_reg1;
  wire gt0_qplloutclk_in;
  wire gt0_qplloutrefclk_in;
  wire gtrefclk;
  wire gtrefclk_bufg;
  wire independent_clock_bufg;
  wire mmcm_locked;
  wire mmcm_reset;
  wire pma_reset;
  wire reset;
  wire reset_out;
  wire reset_sync6;
  wire reset_sync6_0;
  wire [1:0]\rxchariscomma_reg_reg[1] ;
  wire [1:0]\rxcharisk_reg_reg[1] ;
  wire [15:0]\rxdata_reg_reg[15] ;
  wire [1:0]\rxdisperr_reg_reg[1] ;
  wire rxn;
  wire [1:0]\rxnotintable_reg_reg[1] ;
  wire rxoutclk;
  wire rxp;
  wire [1:0]\txchardispmode_int_reg[1] ;
  wire [1:0]\txchardispval_int_reg[1] ;
  wire [1:0]\txcharisk_int_reg[1] ;
  wire txn;
  wire txoutclk;
  wire txp;
  wire userclk;

  GigEthGth7Core_GigEthGth7Core_GTWIZARD_init U0
       (.D(D),
        .Q(Q),
        .RXBUFSTATUS(RXBUFSTATUS),
        .RXPD(RXPD),
        .TXBUFSTATUS(TXBUFSTATUS),
        .TXPD(TXPD),
        .cplllock(cplllock),
        .data_in(data_in),
        .data_out(data_out),
        .data_sync_reg1(data_sync_reg1),
        .gt0_qplloutclk_in(gt0_qplloutclk_in),
        .gt0_qplloutrefclk_in(gt0_qplloutrefclk_in),
        .gtrefclk(gtrefclk),
        .gtrefclk_bufg(gtrefclk_bufg),
        .independent_clock_bufg(independent_clock_bufg),
        .mmcm_locked(mmcm_locked),
        .mmcm_reset(mmcm_reset),
        .pma_reset(pma_reset),
        .reset(reset),
        .reset_out(reset_out),
        .reset_sync6(reset_sync6),
        .reset_sync6_0(reset_sync6_0),
        .\rxchariscomma_reg_reg[1] (\rxchariscomma_reg_reg[1] ),
        .\rxcharisk_reg_reg[1] (\rxcharisk_reg_reg[1] ),
        .\rxdata_reg_reg[15] (\rxdata_reg_reg[15] ),
        .\rxdisperr_reg_reg[1] (\rxdisperr_reg_reg[1] ),
        .rxn(rxn),
        .\rxnotintable_reg_reg[1] (\rxnotintable_reg_reg[1] ),
        .rxoutclk(rxoutclk),
        .rxp(rxp),
        .\txchardispmode_int_reg[1] (\txchardispmode_int_reg[1] ),
        .\txchardispval_int_reg[1] (\txchardispval_int_reg[1] ),
        .\txcharisk_int_reg[1] (\txcharisk_int_reg[1] ),
        .txn(txn),
        .txoutclk(txoutclk),
        .txp(txp),
        .userclk(userclk));
endmodule

(* ORIG_REF_NAME = "GigEthGth7Core_GTWIZARD_GT" *) 
module GigEthGth7Core_GigEthGth7Core_GTWIZARD_GT
   (cplllock,
    CPLLREFCLKLOST,
    txn,
    txp,
    rxoutclk,
    data_sync_reg1,
    txoutclk,
    data_sync_reg1_0,
    D,
    TXBUFSTATUS,
    RXBUFSTATUS,
    \rxdata_reg_reg[15] ,
    \rxchariscomma_reg_reg[1] ,
    \rxcharisk_reg_reg[1] ,
    \rxdisperr_reg_reg[1] ,
    \rxnotintable_reg_reg[1] ,
    independent_clock_bufg,
    cpll_pd_out,
    cpllreset_in,
    gtrefclk_bufg,
    rxn,
    rxp,
    gtrefclk,
    gt0_gttxreset_in0_out,
    gt0_qplloutclk_in,
    gt0_qplloutrefclk_in,
    reset_out,
    reset,
    RXUSERRDY,
    userclk,
    TXPD,
    TXUSERRDY,
    RXPD,
    Q,
    \txchardispmode_int_reg[1] ,
    \txchardispval_int_reg[1] ,
    \txcharisk_int_reg[1] ,
    SR,
    CPLL_RESET);
  output cplllock;
  output CPLLREFCLKLOST;
  output txn;
  output txp;
  output rxoutclk;
  output data_sync_reg1;
  output txoutclk;
  output data_sync_reg1_0;
  output [1:0]D;
  output [0:0]TXBUFSTATUS;
  output [0:0]RXBUFSTATUS;
  output [15:0]\rxdata_reg_reg[15] ;
  output [1:0]\rxchariscomma_reg_reg[1] ;
  output [1:0]\rxcharisk_reg_reg[1] ;
  output [1:0]\rxdisperr_reg_reg[1] ;
  output [1:0]\rxnotintable_reg_reg[1] ;
  input independent_clock_bufg;
  input cpll_pd_out;
  input cpllreset_in;
  input gtrefclk_bufg;
  input rxn;
  input rxp;
  input gtrefclk;
  input gt0_gttxreset_in0_out;
  input gt0_qplloutclk_in;
  input gt0_qplloutrefclk_in;
  input reset_out;
  input reset;
  input RXUSERRDY;
  input userclk;
  input [0:0]TXPD;
  input TXUSERRDY;
  input [0:0]RXPD;
  input [15:0]Q;
  input [1:0]\txchardispmode_int_reg[1] ;
  input [1:0]\txchardispval_int_reg[1] ;
  input [1:0]\txcharisk_int_reg[1] ;
  input [0:0]SR;
  input CPLL_RESET;

  wire CPLLREFCLKLOST;
  wire CPLL_RESET;
  wire [1:0]D;
  wire [15:0]DRPDI;
  wire DRPEN;
  wire DRPWE;
  wire DRP_OP_DONE;
  wire GTRXRESET;
  wire [15:0]Q;
  wire [0:0]RXBUFSTATUS;
  wire [0:0]RXPD;
  wire RXPMARESET;
  wire RXUSERRDY;
  wire [0:0]SR;
  wire [0:0]TXBUFSTATUS;
  wire [0:0]TXPD;
  wire TXUSERRDY;
  wire cpll_pd_out;
  wire cplllock;
  wire cpllreset_in;
  wire data_sync_reg1;
  wire data_sync_reg1_0;
  wire drp_busy_i1;
  wire gt0_gttxreset_in0_out;
  wire gt0_qplloutclk_in;
  wire gt0_qplloutrefclk_in;
  wire gthe2_i_n_0;
  wire gthe2_i_n_10;
  wire gthe2_i_n_11;
  wire gthe2_i_n_113;
  wire gthe2_i_n_115;
  wire gthe2_i_n_116;
  wire gthe2_i_n_17;
  wire gthe2_i_n_205;
  wire gthe2_i_n_206;
  wire gthe2_i_n_207;
  wire gthe2_i_n_208;
  wire gthe2_i_n_209;
  wire gthe2_i_n_210;
  wire gthe2_i_n_211;
  wire gthe2_i_n_3;
  wire gthe2_i_n_33;
  wire gthe2_i_n_34;
  wire gthe2_i_n_4;
  wire gthe2_i_n_46;
  wire gthe2_i_n_47;
  wire gthe2_i_n_50;
  wire gthe2_i_n_57;
  wire gthe2_i_n_58;
  wire gthe2_i_n_59;
  wire gthe2_i_n_60;
  wire gthe2_i_n_61;
  wire gthe2_i_n_62;
  wire gthe2_i_n_63;
  wire gthe2_i_n_64;
  wire gthe2_i_n_65;
  wire gthe2_i_n_66;
  wire gthe2_i_n_67;
  wire gthe2_i_n_68;
  wire gthe2_i_n_69;
  wire gthe2_i_n_70;
  wire gthe2_i_n_71;
  wire gthe2_i_n_72;
  wire gthe2_i_n_73;
  wire gthe2_i_n_74;
  wire gthe2_i_n_75;
  wire gthe2_i_n_76;
  wire gthe2_i_n_77;
  wire gthe2_i_n_78;
  wire gthe2_i_n_79;
  wire gthe2_i_n_80;
  wire gthe2_i_n_81;
  wire gthe2_i_n_82;
  wire gthe2_i_n_83;
  wire gthe2_i_n_84;
  wire gthe2_i_n_85;
  wire gthe2_i_n_86;
  wire gthe2_i_n_87;
  wire gtrefclk;
  wire gtrefclk_bufg;
  wire gtrxreset_seq_i_n_18;
  wire independent_clock_bufg;
  wire reset;
  wire reset_out;
  wire [1:0]\rxchariscomma_reg_reg[1] ;
  wire [1:0]\rxcharisk_reg_reg[1] ;
  wire [15:0]\rxdata_reg_reg[15] ;
  wire [1:0]\rxdisperr_reg_reg[1] ;
  wire rxn;
  wire [1:0]\rxnotintable_reg_reg[1] ;
  wire rxoutclk;
  wire rxp;
  wire rxpmarst_seq_i_n_1;
  wire rxpmarst_seq_i_n_10;
  wire rxpmarst_seq_i_n_11;
  wire rxpmarst_seq_i_n_12;
  wire rxpmarst_seq_i_n_13;
  wire rxpmarst_seq_i_n_14;
  wire rxpmarst_seq_i_n_15;
  wire rxpmarst_seq_i_n_16;
  wire rxpmarst_seq_i_n_17;
  wire rxpmarst_seq_i_n_18;
  wire rxpmarst_seq_i_n_19;
  wire rxpmarst_seq_i_n_2;
  wire rxpmarst_seq_i_n_3;
  wire rxpmarst_seq_i_n_4;
  wire rxpmarst_seq_i_n_5;
  wire rxpmarst_seq_i_n_6;
  wire rxpmarst_seq_i_n_7;
  wire rxpmarst_seq_i_n_8;
  wire rxpmarst_seq_i_n_9;
  wire [1:0]\txchardispmode_int_reg[1] ;
  wire [1:0]\txchardispval_int_reg[1] ;
  wire [1:0]\txcharisk_int_reg[1] ;
  wire txn;
  wire txoutclk;
  wire txp;
  wire userclk;
  wire NLW_gthe2_i_GTREFCLKMONITOR_UNCONNECTED;
  wire NLW_gthe2_i_PHYSTATUS_UNCONNECTED;
  wire NLW_gthe2_i_RSOSINTDONE_UNCONNECTED;
  wire NLW_gthe2_i_RXCDRLOCK_UNCONNECTED;
  wire NLW_gthe2_i_RXCHANBONDSEQ_UNCONNECTED;
  wire NLW_gthe2_i_RXCHANISALIGNED_UNCONNECTED;
  wire NLW_gthe2_i_RXCHANREALIGN_UNCONNECTED;
  wire NLW_gthe2_i_RXCOMINITDET_UNCONNECTED;
  wire NLW_gthe2_i_RXCOMSASDET_UNCONNECTED;
  wire NLW_gthe2_i_RXCOMWAKEDET_UNCONNECTED;
  wire NLW_gthe2_i_RXDFESLIDETAPSTARTED_UNCONNECTED;
  wire NLW_gthe2_i_RXDFESLIDETAPSTROBEDONE_UNCONNECTED;
  wire NLW_gthe2_i_RXDFESLIDETAPSTROBESTARTED_UNCONNECTED;
  wire NLW_gthe2_i_RXDFESTADAPTDONE_UNCONNECTED;
  wire NLW_gthe2_i_RXDLYSRESETDONE_UNCONNECTED;
  wire NLW_gthe2_i_RXELECIDLE_UNCONNECTED;
  wire NLW_gthe2_i_RXOSINTSTARTED_UNCONNECTED;
  wire NLW_gthe2_i_RXOSINTSTROBEDONE_UNCONNECTED;
  wire NLW_gthe2_i_RXOSINTSTROBESTARTED_UNCONNECTED;
  wire NLW_gthe2_i_RXOUTCLKFABRIC_UNCONNECTED;
  wire NLW_gthe2_i_RXOUTCLKPCS_UNCONNECTED;
  wire NLW_gthe2_i_RXPHALIGNDONE_UNCONNECTED;
  wire NLW_gthe2_i_RXQPISENN_UNCONNECTED;
  wire NLW_gthe2_i_RXQPISENP_UNCONNECTED;
  wire NLW_gthe2_i_RXRATEDONE_UNCONNECTED;
  wire NLW_gthe2_i_RXSYNCDONE_UNCONNECTED;
  wire NLW_gthe2_i_RXSYNCOUT_UNCONNECTED;
  wire NLW_gthe2_i_RXVALID_UNCONNECTED;
  wire NLW_gthe2_i_TXCOMFINISH_UNCONNECTED;
  wire NLW_gthe2_i_TXDLYSRESETDONE_UNCONNECTED;
  wire NLW_gthe2_i_TXGEARBOXREADY_UNCONNECTED;
  wire NLW_gthe2_i_TXPHALIGNDONE_UNCONNECTED;
  wire NLW_gthe2_i_TXPHINITDONE_UNCONNECTED;
  wire NLW_gthe2_i_TXQPISENN_UNCONNECTED;
  wire NLW_gthe2_i_TXQPISENP_UNCONNECTED;
  wire NLW_gthe2_i_TXRATEDONE_UNCONNECTED;
  wire NLW_gthe2_i_TXSYNCDONE_UNCONNECTED;
  wire NLW_gthe2_i_TXSYNCOUT_UNCONNECTED;
  wire [15:0]NLW_gthe2_i_PCSRSVDOUT_UNCONNECTED;
  wire [7:2]NLW_gthe2_i_RXCHARISCOMMA_UNCONNECTED;
  wire [7:2]NLW_gthe2_i_RXCHARISK_UNCONNECTED;
  wire [4:0]NLW_gthe2_i_RXCHBONDO_UNCONNECTED;
  wire [63:16]NLW_gthe2_i_RXDATA_UNCONNECTED;
  wire [1:0]NLW_gthe2_i_RXDATAVALID_UNCONNECTED;
  wire [7:2]NLW_gthe2_i_RXDISPERR_UNCONNECTED;
  wire [5:0]NLW_gthe2_i_RXHEADER_UNCONNECTED;
  wire [1:0]NLW_gthe2_i_RXHEADERVALID_UNCONNECTED;
  wire [7:2]NLW_gthe2_i_RXNOTINTABLE_UNCONNECTED;
  wire [4:0]NLW_gthe2_i_RXPHMONITOR_UNCONNECTED;
  wire [4:0]NLW_gthe2_i_RXPHSLIPMONITOR_UNCONNECTED;
  wire [1:0]NLW_gthe2_i_RXSTARTOFSEQ_UNCONNECTED;
  wire [2:0]NLW_gthe2_i_RXSTATUS_UNCONNECTED;

  FDRE #(
    .INIT(1'b0)) 
    drp_busy_i1_reg
       (.C(gtrefclk_bufg),
        .CE(1'b1),
        .D(gtrxreset_seq_i_n_18),
        .Q(drp_busy_i1),
        .R(1'b0));
  (* box_type = "PRIMITIVE" *) 
  GTHE2_CHANNEL #(
    .ACJTAG_DEBUG_MODE(1'b0),
    .ACJTAG_MODE(1'b0),
    .ACJTAG_RESET(1'b0),
    .ADAPT_CFG0(20'h00C10),
    .ALIGN_COMMA_DOUBLE("FALSE"),
    .ALIGN_COMMA_ENABLE(10'b0001111111),
    .ALIGN_COMMA_WORD(2),
    .ALIGN_MCOMMA_DET("TRUE"),
    .ALIGN_MCOMMA_VALUE(10'b1010000011),
    .ALIGN_PCOMMA_DET("TRUE"),
    .ALIGN_PCOMMA_VALUE(10'b0101111100),
    .A_RXOSCALRESET(1'b0),
    .CBCC_DATA_SOURCE_SEL("DECODED"),
    .CFOK_CFG(42'h24800040E80),
    .CFOK_CFG2(6'b100000),
    .CFOK_CFG3(6'b100000),
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
    .CLK_CORRECT_USE("TRUE"),
    .CLK_COR_KEEP_IDLE("FALSE"),
    .CLK_COR_MAX_LAT(36),
    .CLK_COR_MIN_LAT(33),
    .CLK_COR_PRECEDENCE("TRUE"),
    .CLK_COR_REPEAT_WAIT(0),
    .CLK_COR_SEQ_1_1(10'b0110111100),
    .CLK_COR_SEQ_1_2(10'b0001010000),
    .CLK_COR_SEQ_1_3(10'b0000000000),
    .CLK_COR_SEQ_1_4(10'b0000000000),
    .CLK_COR_SEQ_1_ENABLE(4'b1111),
    .CLK_COR_SEQ_2_1(10'b0110111100),
    .CLK_COR_SEQ_2_2(10'b0010110101),
    .CLK_COR_SEQ_2_3(10'b0000000000),
    .CLK_COR_SEQ_2_4(10'b0000000000),
    .CLK_COR_SEQ_2_ENABLE(4'b1111),
    .CLK_COR_SEQ_2_USE("TRUE"),
    .CLK_COR_SEQ_LEN(2),
    .CPLL_CFG(29'h00BC07DC),
    .CPLL_FBDIV(4),
    .CPLL_FBDIV_45(5),
    .CPLL_INIT_CFG(24'h00001E),
    .CPLL_LOCK_CFG(16'h01E8),
    .CPLL_REFCLK_DIV(1),
    .DEC_MCOMMA_DETECT("TRUE"),
    .DEC_PCOMMA_DETECT("TRUE"),
    .DEC_VALID_COMMA_ONLY("FALSE"),
    .DMONITOR_CFG(24'h000A00),
    .ES_CLK_PHASE_SEL(1'b0),
    .ES_CONTROL(6'b000000),
    .ES_ERRDET_EN("FALSE"),
    .ES_EYE_SCAN_EN("TRUE"),
    .ES_HORZ_OFFSET(12'h000),
    .ES_PMA_CFG(10'b0000000000),
    .ES_PRESCALE(5'b00000),
    .ES_QUALIFIER(80'h00000000000000000000),
    .ES_QUAL_MASK(80'h00000000000000000000),
    .ES_SDATA_MASK(80'h00000000000000000000),
    .ES_VERT_OFFSET(9'b000000000),
    .FTS_DESKEW_SEQ_ENABLE(4'b1111),
    .FTS_LANE_DESKEW_CFG(4'b1111),
    .FTS_LANE_DESKEW_EN("FALSE"),
    .GEARBOX_MODE(3'b000),
    .IS_CLKRSVD0_INVERTED(1'b0),
    .IS_CLKRSVD1_INVERTED(1'b0),
    .IS_CPLLLOCKDETCLK_INVERTED(1'b0),
    .IS_DMONITORCLK_INVERTED(1'b0),
    .IS_DRPCLK_INVERTED(1'b0),
    .IS_GTGREFCLK_INVERTED(1'b0),
    .IS_RXUSRCLK2_INVERTED(1'b0),
    .IS_RXUSRCLK_INVERTED(1'b0),
    .IS_SIGVALIDCLK_INVERTED(1'b0),
    .IS_TXPHDLYTSTCLK_INVERTED(1'b0),
    .IS_TXUSRCLK2_INVERTED(1'b0),
    .IS_TXUSRCLK_INVERTED(1'b0),
    .LOOPBACK_CFG(1'b0),
    .OUTREFCLK_SEL_INV(2'b11),
    .PCS_PCIE_EN("FALSE"),
    .PCS_RSVD_ATTR(48'h000000000000),
    .PD_TRANS_TIME_FROM_P2(12'h03C),
    .PD_TRANS_TIME_NONE_P2(8'h19),
    .PD_TRANS_TIME_TO_P2(8'h64),
    .PMA_RSV(32'b00000000000000000000000010000000),
    .PMA_RSV2(32'b00011100000000000000000000001010),
    .PMA_RSV3(2'b00),
    .PMA_RSV4(15'b000000000001000),
    .PMA_RSV5(4'b0000),
    .RESET_POWERSAVE_DISABLE(1'b0),
    .RXBUFRESET_TIME(5'b00001),
    .RXBUF_ADDR_MODE("FULL"),
    .RXBUF_EIDLE_HI_CNT(4'b1000),
    .RXBUF_EIDLE_LO_CNT(4'b0000),
    .RXBUF_EN("TRUE"),
    .RXBUF_RESET_ON_CB_CHANGE("TRUE"),
    .RXBUF_RESET_ON_COMMAALIGN("FALSE"),
    .RXBUF_RESET_ON_EIDLE("FALSE"),
    .RXBUF_RESET_ON_RATE_CHANGE("TRUE"),
    .RXBUF_THRESH_OVFLW(61),
    .RXBUF_THRESH_OVRD("FALSE"),
    .RXBUF_THRESH_UNDFLW(8),
    .RXCDRFREQRESET_TIME(5'b00001),
    .RXCDRPHRESET_TIME(5'b00001),
    .RXCDR_CFG(83'h0002007FE0800C2080018),
    .RXCDR_FR_RESET_ON_EIDLE(1'b0),
    .RXCDR_HOLD_DURING_EIDLE(1'b0),
    .RXCDR_LOCK_CFG(6'b010101),
    .RXCDR_PH_RESET_ON_EIDLE(1'b0),
    .RXDFELPMRESET_TIME(7'b0001111),
    .RXDLY_CFG(16'h001F),
    .RXDLY_LCFG(9'h030),
    .RXDLY_TAP_CFG(16'h0000),
    .RXGEARBOX_EN("FALSE"),
    .RXISCANRESET_TIME(5'b00001),
    .RXLPM_HF_CFG(14'b00001000000000),
    .RXLPM_LF_CFG(18'b001001000000000000),
    .RXOOB_CFG(7'b0000110),
    .RXOOB_CLK_CFG("PMA"),
    .RXOSCALRESET_TIME(5'b00011),
    .RXOSCALRESET_TIMEOUT(5'b00000),
    .RXOUT_DIV(4),
    .RXPCSRESET_TIME(5'b00001),
    .RXPHDLY_CFG(24'h084020),
    .RXPH_CFG(24'hC00002),
    .RXPH_MONITOR_SEL(5'b00000),
    .RXPI_CFG0(2'b00),
    .RXPI_CFG1(2'b00),
    .RXPI_CFG2(2'b00),
    .RXPI_CFG3(2'b11),
    .RXPI_CFG4(1'b1),
    .RXPI_CFG5(1'b1),
    .RXPI_CFG6(3'b001),
    .RXPMARESET_TIME(5'b00011),
    .RXPRBS_ERR_LOOPBACK(1'b0),
    .RXSLIDE_AUTO_WAIT(7),
    .RXSLIDE_MODE("OFF"),
    .RXSYNC_MULTILANE(1'b0),
    .RXSYNC_OVRD(1'b0),
    .RXSYNC_SKIP_DA(1'b0),
    .RX_BIAS_CFG(24'b000011000000000000010000),
    .RX_BUFFER_CFG(6'b000000),
    .RX_CLK25_DIV(5),
    .RX_CLKMUX_PD(1'b1),
    .RX_CM_SEL(2'b11),
    .RX_CM_TRIM(4'b1010),
    .RX_DATA_WIDTH(20),
    .RX_DDI_SEL(6'b000000),
    .RX_DEBUG_CFG(14'b00000000000000),
    .RX_DEFER_RESET_BUF_EN("TRUE"),
    .RX_DFELPM_CFG0(4'b0110),
    .RX_DFELPM_CFG1(1'b0),
    .RX_DFELPM_KLKH_AGC_STUP_EN(1'b1),
    .RX_DFE_AGC_CFG0(2'b00),
    .RX_DFE_AGC_CFG1(3'b010),
    .RX_DFE_AGC_CFG2(4'b0000),
    .RX_DFE_AGC_OVRDEN(1'b1),
    .RX_DFE_GAIN_CFG(23'h0020C0),
    .RX_DFE_H2_CFG(12'b000000000000),
    .RX_DFE_H3_CFG(12'b000001000000),
    .RX_DFE_H4_CFG(11'b00011100000),
    .RX_DFE_H5_CFG(11'b00011100000),
    .RX_DFE_H6_CFG(11'b00000100000),
    .RX_DFE_H7_CFG(11'b00000100000),
    .RX_DFE_KL_CFG(33'b001000001000000000000001100010000),
    .RX_DFE_KL_LPM_KH_CFG0(2'b01),
    .RX_DFE_KL_LPM_KH_CFG1(3'b010),
    .RX_DFE_KL_LPM_KH_CFG2(4'b0010),
    .RX_DFE_KL_LPM_KH_OVRDEN(1'b1),
    .RX_DFE_KL_LPM_KL_CFG0(2'b01),
    .RX_DFE_KL_LPM_KL_CFG1(3'b010),
    .RX_DFE_KL_LPM_KL_CFG2(4'b0010),
    .RX_DFE_KL_LPM_KL_OVRDEN(1'b1),
    .RX_DFE_LPM_CFG(16'h0080),
    .RX_DFE_LPM_HOLD_DURING_EIDLE(1'b0),
    .RX_DFE_ST_CFG(54'h00E100000C003F),
    .RX_DFE_UT_CFG(17'b00011100000000000),
    .RX_DFE_VP_CFG(17'b00011101010100011),
    .RX_DISPERR_SEQ_MATCH("TRUE"),
    .RX_INT_DATAWIDTH(0),
    .RX_OS_CFG(13'b0000010000000),
    .RX_SIG_VALID_DLY(10),
    .RX_XCLK_SEL("RXREC"),
    .SAS_MAX_COM(64),
    .SAS_MIN_COM(36),
    .SATA_BURST_SEQ_LEN(4'b0101),
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
    .SIM_CPLLREFCLK_SEL(3'b001),
    .SIM_RECEIVER_DETECT_PASS("TRUE"),
    .SIM_RESET_SPEEDUP("FALSE"),
    .SIM_TX_EIDLE_DRIVE_LEVEL("X"),
    .SIM_VERSION("2.0"),
    .TERM_RCAL_CFG(15'b100001000010000),
    .TERM_RCAL_OVRD(3'b000),
    .TRANS_TIME_RATE(8'h0E),
    .TST_RSV(32'h00000000),
    .TXBUF_EN("TRUE"),
    .TXBUF_RESET_ON_RATE_CHANGE("TRUE"),
    .TXDLY_CFG(16'h001F),
    .TXDLY_LCFG(9'h030),
    .TXDLY_TAP_CFG(16'h0000),
    .TXGEARBOX_EN("FALSE"),
    .TXOOB_CFG(1'b0),
    .TXOUT_DIV(4),
    .TXPCSRESET_TIME(5'b00001),
    .TXPHDLY_CFG(24'h084020),
    .TXPH_CFG(16'h0780),
    .TXPH_MONITOR_SEL(5'b00000),
    .TXPI_CFG0(2'b00),
    .TXPI_CFG1(2'b00),
    .TXPI_CFG2(2'b00),
    .TXPI_CFG3(1'b0),
    .TXPI_CFG4(1'b0),
    .TXPI_CFG5(3'b100),
    .TXPI_GREY_SEL(1'b0),
    .TXPI_INVSTROBE_SEL(1'b0),
    .TXPI_PPMCLK_SEL("TXUSRCLK2"),
    .TXPI_PPM_CFG(8'b00000000),
    .TXPI_SYNFREQ_PPM(3'b001),
    .TXPMARESET_TIME(5'b00001),
    .TXSYNC_MULTILANE(1'b0),
    .TXSYNC_OVRD(1'b0),
    .TXSYNC_SKIP_DA(1'b0),
    .TX_CLK25_DIV(5),
    .TX_CLKMUX_PD(1'b1),
    .TX_DATA_WIDTH(20),
    .TX_DEEMPH0(6'b000000),
    .TX_DEEMPH1(6'b000000),
    .TX_DRIVE_MODE("DIRECT"),
    .TX_EIDLE_ASSERT_DELAY(3'b110),
    .TX_EIDLE_DEASSERT_DELAY(3'b100),
    .TX_INT_DATAWIDTH(0),
    .TX_LOOPBACK_DRIVE_HIZ("FALSE"),
    .TX_MAINCURSOR_SEL(1'b0),
    .TX_MARGIN_FULL_0(7'b1001110),
    .TX_MARGIN_FULL_1(7'b1001001),
    .TX_MARGIN_FULL_2(7'b1000101),
    .TX_MARGIN_FULL_3(7'b1000010),
    .TX_MARGIN_FULL_4(7'b1000000),
    .TX_MARGIN_LOW_0(7'b1000110),
    .TX_MARGIN_LOW_1(7'b1000100),
    .TX_MARGIN_LOW_2(7'b1000010),
    .TX_MARGIN_LOW_3(7'b1000000),
    .TX_MARGIN_LOW_4(7'b1000000),
    .TX_QPI_STATUS_EN(1'b0),
    .TX_RXDETECT_CFG(14'h1832),
    .TX_RXDETECT_PRECHARGE_TIME(17'h155CC),
    .TX_RXDETECT_REF(3'b100),
    .TX_XCLK_SEL("TXOUT"),
    .UCODEER_CLR(1'b0),
    .USE_PCS_CLK_PHASE_SEL(1'b0)) 
    gthe2_i
       (.CFGRESET(1'b0),
        .CLKRSVD0(1'b0),
        .CLKRSVD1(1'b0),
        .CPLLFBCLKLOST(gthe2_i_n_0),
        .CPLLLOCK(cplllock),
        .CPLLLOCKDETCLK(independent_clock_bufg),
        .CPLLLOCKEN(1'b1),
        .CPLLPD(cpll_pd_out),
        .CPLLREFCLKLOST(CPLLREFCLKLOST),
        .CPLLREFCLKSEL({1'b0,1'b0,1'b1}),
        .CPLLRESET(cpllreset_in),
        .DMONFIFORESET(1'b0),
        .DMONITORCLK(1'b0),
        .DMONITOROUT({gthe2_i_n_57,gthe2_i_n_58,gthe2_i_n_59,gthe2_i_n_60,gthe2_i_n_61,gthe2_i_n_62,gthe2_i_n_63,gthe2_i_n_64,gthe2_i_n_65,gthe2_i_n_66,gthe2_i_n_67,gthe2_i_n_68,gthe2_i_n_69,gthe2_i_n_70,gthe2_i_n_71}),
        .DRPADDR({1'b0,1'b0,1'b0,1'b0,rxpmarst_seq_i_n_1,1'b0,1'b0,1'b0,rxpmarst_seq_i_n_1}),
        .DRPCLK(gtrefclk_bufg),
        .DRPDI(DRPDI),
        .DRPDO({gthe2_i_n_72,gthe2_i_n_73,gthe2_i_n_74,gthe2_i_n_75,gthe2_i_n_76,gthe2_i_n_77,gthe2_i_n_78,gthe2_i_n_79,gthe2_i_n_80,gthe2_i_n_81,gthe2_i_n_82,gthe2_i_n_83,gthe2_i_n_84,gthe2_i_n_85,gthe2_i_n_86,gthe2_i_n_87}),
        .DRPEN(DRPEN),
        .DRPRDY(gthe2_i_n_3),
        .DRPWE(DRPWE),
        .EYESCANDATAERROR(gthe2_i_n_4),
        .EYESCANMODE(1'b0),
        .EYESCANRESET(1'b0),
        .EYESCANTRIGGER(1'b0),
        .GTGREFCLK(1'b0),
        .GTHRXN(rxn),
        .GTHRXP(rxp),
        .GTHTXN(txn),
        .GTHTXP(txp),
        .GTNORTHREFCLK0(1'b0),
        .GTNORTHREFCLK1(1'b0),
        .GTREFCLK0(gtrefclk),
        .GTREFCLK1(1'b0),
        .GTREFCLKMONITOR(NLW_gthe2_i_GTREFCLKMONITOR_UNCONNECTED),
        .GTRESETSEL(1'b0),
        .GTRSVD({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .GTRXRESET(GTRXRESET),
        .GTSOUTHREFCLK0(1'b0),
        .GTSOUTHREFCLK1(1'b0),
        .GTTXRESET(gt0_gttxreset_in0_out),
        .LOOPBACK({1'b0,1'b0,1'b0}),
        .PCSRSVDIN({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .PCSRSVDIN2({1'b0,1'b0,1'b0,1'b0,1'b0}),
        .PCSRSVDOUT(NLW_gthe2_i_PCSRSVDOUT_UNCONNECTED[15:0]),
        .PHYSTATUS(NLW_gthe2_i_PHYSTATUS_UNCONNECTED),
        .PMARSVDIN({1'b0,1'b0,1'b0,1'b0,1'b0}),
        .QPLLCLK(gt0_qplloutclk_in),
        .QPLLREFCLK(gt0_qplloutrefclk_in),
        .RESETOVRD(1'b0),
        .RSOSINTDONE(NLW_gthe2_i_RSOSINTDONE_UNCONNECTED),
        .RX8B10BEN(1'b1),
        .RXADAPTSELTEST({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .RXBUFRESET(1'b0),
        .RXBUFSTATUS({RXBUFSTATUS,gthe2_i_n_115,gthe2_i_n_116}),
        .RXBYTEISALIGNED(gthe2_i_n_10),
        .RXBYTEREALIGN(gthe2_i_n_11),
        .RXCDRFREQRESET(1'b0),
        .RXCDRHOLD(1'b0),
        .RXCDRLOCK(NLW_gthe2_i_RXCDRLOCK_UNCONNECTED),
        .RXCDROVRDEN(1'b0),
        .RXCDRRESET(1'b0),
        .RXCDRRESETRSV(1'b0),
        .RXCHANBONDSEQ(NLW_gthe2_i_RXCHANBONDSEQ_UNCONNECTED),
        .RXCHANISALIGNED(NLW_gthe2_i_RXCHANISALIGNED_UNCONNECTED),
        .RXCHANREALIGN(NLW_gthe2_i_RXCHANREALIGN_UNCONNECTED),
        .RXCHARISCOMMA({NLW_gthe2_i_RXCHARISCOMMA_UNCONNECTED[7:2],\rxchariscomma_reg_reg[1] }),
        .RXCHARISK({NLW_gthe2_i_RXCHARISK_UNCONNECTED[7:2],\rxcharisk_reg_reg[1] }),
        .RXCHBONDEN(1'b0),
        .RXCHBONDI({1'b0,1'b0,1'b0,1'b0,1'b0}),
        .RXCHBONDLEVEL({1'b0,1'b0,1'b0}),
        .RXCHBONDMASTER(1'b0),
        .RXCHBONDO(NLW_gthe2_i_RXCHBONDO_UNCONNECTED[4:0]),
        .RXCHBONDSLAVE(1'b0),
        .RXCLKCORCNT(D),
        .RXCOMINITDET(NLW_gthe2_i_RXCOMINITDET_UNCONNECTED),
        .RXCOMMADET(gthe2_i_n_17),
        .RXCOMMADETEN(1'b1),
        .RXCOMSASDET(NLW_gthe2_i_RXCOMSASDET_UNCONNECTED),
        .RXCOMWAKEDET(NLW_gthe2_i_RXCOMWAKEDET_UNCONNECTED),
        .RXDATA({NLW_gthe2_i_RXDATA_UNCONNECTED[63:16],\rxdata_reg_reg[15] }),
        .RXDATAVALID(NLW_gthe2_i_RXDATAVALID_UNCONNECTED[1:0]),
        .RXDDIEN(1'b0),
        .RXDFEAGCHOLD(1'b0),
        .RXDFEAGCOVRDEN(1'b0),
        .RXDFEAGCTRL({1'b1,1'b0,1'b0,1'b0,1'b0}),
        .RXDFECM1EN(1'b0),
        .RXDFELFHOLD(1'b0),
        .RXDFELFOVRDEN(1'b0),
        .RXDFELPMRESET(1'b0),
        .RXDFESLIDETAP({1'b0,1'b0,1'b0,1'b0,1'b0}),
        .RXDFESLIDETAPADAPTEN(1'b0),
        .RXDFESLIDETAPHOLD(1'b0),
        .RXDFESLIDETAPID({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .RXDFESLIDETAPINITOVRDEN(1'b0),
        .RXDFESLIDETAPONLYADAPTEN(1'b0),
        .RXDFESLIDETAPOVRDEN(1'b0),
        .RXDFESLIDETAPSTARTED(NLW_gthe2_i_RXDFESLIDETAPSTARTED_UNCONNECTED),
        .RXDFESLIDETAPSTROBE(1'b0),
        .RXDFESLIDETAPSTROBEDONE(NLW_gthe2_i_RXDFESLIDETAPSTROBEDONE_UNCONNECTED),
        .RXDFESLIDETAPSTROBESTARTED(NLW_gthe2_i_RXDFESLIDETAPSTROBESTARTED_UNCONNECTED),
        .RXDFESTADAPTDONE(NLW_gthe2_i_RXDFESTADAPTDONE_UNCONNECTED),
        .RXDFETAP2HOLD(1'b0),
        .RXDFETAP2OVRDEN(1'b0),
        .RXDFETAP3HOLD(1'b0),
        .RXDFETAP3OVRDEN(1'b0),
        .RXDFETAP4HOLD(1'b0),
        .RXDFETAP4OVRDEN(1'b0),
        .RXDFETAP5HOLD(1'b0),
        .RXDFETAP5OVRDEN(1'b0),
        .RXDFETAP6HOLD(1'b0),
        .RXDFETAP6OVRDEN(1'b0),
        .RXDFETAP7HOLD(1'b0),
        .RXDFETAP7OVRDEN(1'b0),
        .RXDFEUTHOLD(1'b0),
        .RXDFEUTOVRDEN(1'b0),
        .RXDFEVPHOLD(1'b0),
        .RXDFEVPOVRDEN(1'b0),
        .RXDFEVSEN(1'b0),
        .RXDFEXYDEN(1'b1),
        .RXDISPERR({NLW_gthe2_i_RXDISPERR_UNCONNECTED[7:2],\rxdisperr_reg_reg[1] }),
        .RXDLYBYPASS(1'b1),
        .RXDLYEN(1'b0),
        .RXDLYOVRDEN(1'b0),
        .RXDLYSRESET(1'b0),
        .RXDLYSRESETDONE(NLW_gthe2_i_RXDLYSRESETDONE_UNCONNECTED),
        .RXELECIDLE(NLW_gthe2_i_RXELECIDLE_UNCONNECTED),
        .RXELECIDLEMODE({1'b1,1'b1}),
        .RXGEARBOXSLIP(1'b0),
        .RXHEADER(NLW_gthe2_i_RXHEADER_UNCONNECTED[5:0]),
        .RXHEADERVALID(NLW_gthe2_i_RXHEADERVALID_UNCONNECTED[1:0]),
        .RXLPMEN(1'b1),
        .RXLPMHFHOLD(1'b0),
        .RXLPMHFOVRDEN(1'b0),
        .RXLPMLFHOLD(1'b0),
        .RXLPMLFKLOVRDEN(1'b0),
        .RXMCOMMAALIGNEN(reset_out),
        .RXMONITOROUT({gthe2_i_n_205,gthe2_i_n_206,gthe2_i_n_207,gthe2_i_n_208,gthe2_i_n_209,gthe2_i_n_210,gthe2_i_n_211}),
        .RXMONITORSEL({1'b0,1'b0}),
        .RXNOTINTABLE({NLW_gthe2_i_RXNOTINTABLE_UNCONNECTED[7:2],\rxnotintable_reg_reg[1] }),
        .RXOOBRESET(1'b0),
        .RXOSCALRESET(1'b0),
        .RXOSHOLD(1'b0),
        .RXOSINTCFG({1'b0,1'b1,1'b1,1'b0}),
        .RXOSINTEN(1'b1),
        .RXOSINTHOLD(1'b0),
        .RXOSINTID0({1'b0,1'b0,1'b0,1'b0}),
        .RXOSINTNTRLEN(1'b0),
        .RXOSINTOVRDEN(1'b0),
        .RXOSINTSTARTED(NLW_gthe2_i_RXOSINTSTARTED_UNCONNECTED),
        .RXOSINTSTROBE(1'b0),
        .RXOSINTSTROBEDONE(NLW_gthe2_i_RXOSINTSTROBEDONE_UNCONNECTED),
        .RXOSINTSTROBESTARTED(NLW_gthe2_i_RXOSINTSTROBESTARTED_UNCONNECTED),
        .RXOSINTTESTOVRDEN(1'b0),
        .RXOSOVRDEN(1'b0),
        .RXOUTCLK(rxoutclk),
        .RXOUTCLKFABRIC(NLW_gthe2_i_RXOUTCLKFABRIC_UNCONNECTED),
        .RXOUTCLKPCS(NLW_gthe2_i_RXOUTCLKPCS_UNCONNECTED),
        .RXOUTCLKSEL({1'b0,1'b1,1'b0}),
        .RXPCOMMAALIGNEN(reset_out),
        .RXPCSRESET(reset),
        .RXPD({RXPD,RXPD}),
        .RXPHALIGN(1'b0),
        .RXPHALIGNDONE(NLW_gthe2_i_RXPHALIGNDONE_UNCONNECTED),
        .RXPHALIGNEN(1'b0),
        .RXPHDLYPD(1'b0),
        .RXPHDLYRESET(1'b0),
        .RXPHMONITOR(NLW_gthe2_i_RXPHMONITOR_UNCONNECTED[4:0]),
        .RXPHOVRDEN(1'b0),
        .RXPHSLIPMONITOR(NLW_gthe2_i_RXPHSLIPMONITOR_UNCONNECTED[4:0]),
        .RXPMARESET(RXPMARESET),
        .RXPMARESETDONE(gthe2_i_n_33),
        .RXPOLARITY(1'b0),
        .RXPRBSCNTRESET(1'b0),
        .RXPRBSERR(gthe2_i_n_34),
        .RXPRBSSEL({1'b0,1'b0,1'b0}),
        .RXQPIEN(1'b0),
        .RXQPISENN(NLW_gthe2_i_RXQPISENN_UNCONNECTED),
        .RXQPISENP(NLW_gthe2_i_RXQPISENP_UNCONNECTED),
        .RXRATE({1'b0,1'b0,1'b0}),
        .RXRATEDONE(NLW_gthe2_i_RXRATEDONE_UNCONNECTED),
        .RXRATEMODE(1'b0),
        .RXRESETDONE(data_sync_reg1),
        .RXSLIDE(1'b0),
        .RXSTARTOFSEQ(NLW_gthe2_i_RXSTARTOFSEQ_UNCONNECTED[1:0]),
        .RXSTATUS(NLW_gthe2_i_RXSTATUS_UNCONNECTED[2:0]),
        .RXSYNCALLIN(1'b0),
        .RXSYNCDONE(NLW_gthe2_i_RXSYNCDONE_UNCONNECTED),
        .RXSYNCIN(1'b0),
        .RXSYNCMODE(1'b0),
        .RXSYNCOUT(NLW_gthe2_i_RXSYNCOUT_UNCONNECTED),
        .RXSYSCLKSEL({1'b0,1'b0}),
        .RXUSERRDY(RXUSERRDY),
        .RXUSRCLK(userclk),
        .RXUSRCLK2(userclk),
        .RXVALID(NLW_gthe2_i_RXVALID_UNCONNECTED),
        .SETERRSTATUS(1'b0),
        .SIGVALIDCLK(1'b0),
        .TSTIN({1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1}),
        .TX8B10BBYPASS({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .TX8B10BEN(1'b1),
        .TXBUFDIFFCTRL({1'b1,1'b0,1'b0}),
        .TXBUFSTATUS({TXBUFSTATUS,gthe2_i_n_113}),
        .TXCHARDISPMODE({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,\txchardispmode_int_reg[1] }),
        .TXCHARDISPVAL({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,\txchardispval_int_reg[1] }),
        .TXCHARISK({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,\txcharisk_int_reg[1] }),
        .TXCOMFINISH(NLW_gthe2_i_TXCOMFINISH_UNCONNECTED),
        .TXCOMINIT(1'b0),
        .TXCOMSAS(1'b0),
        .TXCOMWAKE(1'b0),
        .TXDATA({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,Q}),
        .TXDEEMPH(1'b0),
        .TXDETECTRX(1'b0),
        .TXDIFFCTRL({1'b1,1'b0,1'b0,1'b0}),
        .TXDIFFPD(1'b0),
        .TXDLYBYPASS(1'b1),
        .TXDLYEN(1'b0),
        .TXDLYHOLD(1'b0),
        .TXDLYOVRDEN(1'b0),
        .TXDLYSRESET(1'b0),
        .TXDLYSRESETDONE(NLW_gthe2_i_TXDLYSRESETDONE_UNCONNECTED),
        .TXDLYUPDOWN(1'b0),
        .TXELECIDLE(TXPD),
        .TXGEARBOXREADY(NLW_gthe2_i_TXGEARBOXREADY_UNCONNECTED),
        .TXHEADER({1'b0,1'b0,1'b0}),
        .TXINHIBIT(1'b0),
        .TXMAINCURSOR({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .TXMARGIN({1'b0,1'b0,1'b0}),
        .TXOUTCLK(txoutclk),
        .TXOUTCLKFABRIC(gthe2_i_n_46),
        .TXOUTCLKPCS(gthe2_i_n_47),
        .TXOUTCLKSEL({1'b1,1'b0,1'b0}),
        .TXPCSRESET(1'b0),
        .TXPD({TXPD,TXPD}),
        .TXPDELECIDLEMODE(1'b0),
        .TXPHALIGN(1'b0),
        .TXPHALIGNDONE(NLW_gthe2_i_TXPHALIGNDONE_UNCONNECTED),
        .TXPHALIGNEN(1'b0),
        .TXPHDLYPD(1'b0),
        .TXPHDLYRESET(1'b0),
        .TXPHDLYTSTCLK(1'b0),
        .TXPHINIT(1'b0),
        .TXPHINITDONE(NLW_gthe2_i_TXPHINITDONE_UNCONNECTED),
        .TXPHOVRDEN(1'b0),
        .TXPIPPMEN(1'b0),
        .TXPIPPMOVRDEN(1'b0),
        .TXPIPPMPD(1'b0),
        .TXPIPPMSEL(1'b1),
        .TXPIPPMSTEPSIZE({1'b0,1'b0,1'b0,1'b0,1'b0}),
        .TXPISOPD(1'b0),
        .TXPMARESET(1'b0),
        .TXPMARESETDONE(gthe2_i_n_50),
        .TXPOLARITY(1'b0),
        .TXPOSTCURSOR({1'b0,1'b0,1'b0,1'b0,1'b0}),
        .TXPOSTCURSORINV(1'b0),
        .TXPRBSFORCEERR(1'b0),
        .TXPRBSSEL({1'b0,1'b0,1'b0}),
        .TXPRECURSOR({1'b0,1'b0,1'b0,1'b0,1'b0}),
        .TXPRECURSORINV(1'b0),
        .TXQPIBIASEN(1'b0),
        .TXQPISENN(NLW_gthe2_i_TXQPISENN_UNCONNECTED),
        .TXQPISENP(NLW_gthe2_i_TXQPISENP_UNCONNECTED),
        .TXQPISTRONGPDOWN(1'b0),
        .TXQPIWEAKPUP(1'b0),
        .TXRATE({1'b0,1'b0,1'b0}),
        .TXRATEDONE(NLW_gthe2_i_TXRATEDONE_UNCONNECTED),
        .TXRATEMODE(1'b0),
        .TXRESETDONE(data_sync_reg1_0),
        .TXSEQUENCE({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .TXSTARTSEQ(1'b0),
        .TXSWING(1'b0),
        .TXSYNCALLIN(1'b0),
        .TXSYNCDONE(NLW_gthe2_i_TXSYNCDONE_UNCONNECTED),
        .TXSYNCIN(1'b0),
        .TXSYNCMODE(1'b0),
        .TXSYNCOUT(NLW_gthe2_i_TXSYNCOUT_UNCONNECTED),
        .TXSYSCLKSEL({1'b0,1'b0}),
        .TXUSERRDY(TXUSERRDY),
        .TXUSRCLK(userclk),
        .TXUSRCLK2(userclk));
  GigEthGth7Core_GigEthGth7Core_gtwizard_gtrxreset_seq gtrxreset_seq_i
       (.CPLL_RESET(CPLL_RESET),
        .D({gthe2_i_n_72,gthe2_i_n_73,gthe2_i_n_74,gthe2_i_n_75,gthe2_i_n_76,gthe2_i_n_77,gthe2_i_n_78,gthe2_i_n_79,gthe2_i_n_80,gthe2_i_n_81,gthe2_i_n_82,gthe2_i_n_83,gthe2_i_n_84,gthe2_i_n_85,gthe2_i_n_86,gthe2_i_n_87}),
        .DRPDI(DRPDI),
        .DRPEN(DRPEN),
        .DRPWE(DRPWE),
        .DRP_OP_DONE(DRP_OP_DONE),
        .GTRXRESET(GTRXRESET),
        .Q({rxpmarst_seq_i_n_5,rxpmarst_seq_i_n_6,rxpmarst_seq_i_n_7,rxpmarst_seq_i_n_8,rxpmarst_seq_i_n_9,rxpmarst_seq_i_n_10,rxpmarst_seq_i_n_11,rxpmarst_seq_i_n_12,rxpmarst_seq_i_n_13,rxpmarst_seq_i_n_14,rxpmarst_seq_i_n_15,rxpmarst_seq_i_n_16,rxpmarst_seq_i_n_17,rxpmarst_seq_i_n_18,rxpmarst_seq_i_n_19}),
        .SR(SR),
        .\cpllpd_wait_reg[95] (gthe2_i_n_3),
        .data_in(gthe2_i_n_33),
        .drp_busy_i1_reg(gtrxreset_seq_i_n_18),
        .gtrefclk_bufg(gtrefclk_bufg),
        .\state_reg[0]_0 (rxpmarst_seq_i_n_2),
        .\state_reg[2]_0 (rxpmarst_seq_i_n_4),
        .\state_reg[3] (rxpmarst_seq_i_n_3));
  GigEthGth7Core_GigEthGth7Core_gtwizard_rxpmarst_seq rxpmarst_seq_i
       (.CPLL_RESET(CPLL_RESET),
        .D({gthe2_i_n_72,gthe2_i_n_73,gthe2_i_n_74,gthe2_i_n_75,gthe2_i_n_76,gthe2_i_n_77,gthe2_i_n_78,gthe2_i_n_79,gthe2_i_n_80,gthe2_i_n_81,gthe2_i_n_82,gthe2_i_n_83,gthe2_i_n_84,gthe2_i_n_85,gthe2_i_n_86,gthe2_i_n_87}),
        .DRPADDR(rxpmarst_seq_i_n_1),
        .DRP_OP_DONE(DRP_OP_DONE),
        .Q({rxpmarst_seq_i_n_5,rxpmarst_seq_i_n_6,rxpmarst_seq_i_n_7,rxpmarst_seq_i_n_8,rxpmarst_seq_i_n_9,rxpmarst_seq_i_n_10,rxpmarst_seq_i_n_11,rxpmarst_seq_i_n_12,rxpmarst_seq_i_n_13,rxpmarst_seq_i_n_14,rxpmarst_seq_i_n_15,rxpmarst_seq_i_n_16,rxpmarst_seq_i_n_17,rxpmarst_seq_i_n_18,rxpmarst_seq_i_n_19}),
        .RXPMARESET(RXPMARESET),
        .\cpllpd_wait_reg[95] (gthe2_i_n_3),
        .data_in(gthe2_i_n_33),
        .data_sync_reg1(rxpmarst_seq_i_n_2),
        .data_sync_reg1_0(rxpmarst_seq_i_n_3),
        .data_sync_reg1_1(rxpmarst_seq_i_n_4),
        .drp_busy_i1(drp_busy_i1),
        .gtrefclk_bufg(gtrefclk_bufg));
endmodule

(* ORIG_REF_NAME = "GigEthGth7Core_GTWIZARD_init" *) 
module GigEthGth7Core_GigEthGth7Core_GTWIZARD_init
   (cplllock,
    txn,
    txp,
    rxoutclk,
    txoutclk,
    D,
    TXBUFSTATUS,
    RXBUFSTATUS,
    \rxdata_reg_reg[15] ,
    \rxchariscomma_reg_reg[1] ,
    \rxcharisk_reg_reg[1] ,
    \rxdisperr_reg_reg[1] ,
    \rxnotintable_reg_reg[1] ,
    mmcm_reset,
    data_in,
    data_sync_reg1,
    gtrefclk_bufg,
    independent_clock_bufg,
    rxn,
    rxp,
    gtrefclk,
    gt0_qplloutclk_in,
    gt0_qplloutrefclk_in,
    reset_out,
    reset,
    userclk,
    TXPD,
    RXPD,
    Q,
    \txchardispmode_int_reg[1] ,
    \txchardispval_int_reg[1] ,
    \txcharisk_int_reg[1] ,
    pma_reset,
    reset_sync6,
    reset_sync6_0,
    mmcm_locked,
    data_out);
  output cplllock;
  output txn;
  output txp;
  output rxoutclk;
  output txoutclk;
  output [1:0]D;
  output [0:0]TXBUFSTATUS;
  output [0:0]RXBUFSTATUS;
  output [15:0]\rxdata_reg_reg[15] ;
  output [1:0]\rxchariscomma_reg_reg[1] ;
  output [1:0]\rxcharisk_reg_reg[1] ;
  output [1:0]\rxdisperr_reg_reg[1] ;
  output [1:0]\rxnotintable_reg_reg[1] ;
  output mmcm_reset;
  output data_in;
  output data_sync_reg1;
  input gtrefclk_bufg;
  input independent_clock_bufg;
  input rxn;
  input rxp;
  input gtrefclk;
  input gt0_qplloutclk_in;
  input gt0_qplloutrefclk_in;
  input reset_out;
  input reset;
  input userclk;
  input [0:0]TXPD;
  input [0:0]RXPD;
  input [15:0]Q;
  input [1:0]\txchardispmode_int_reg[1] ;
  input [1:0]\txchardispval_int_reg[1] ;
  input [1:0]\txcharisk_int_reg[1] ;
  input pma_reset;
  input reset_sync6;
  input reset_sync6_0;
  input mmcm_locked;
  input data_out;

  wire CPLLREFCLKLOST;
  wire CPLL_RESET;
  wire [1:0]D;
  wire [15:0]Q;
  wire [0:0]RXBUFSTATUS;
  wire [0:0]RXPD;
  wire RXUSERRDY;
  wire [0:0]TXBUFSTATUS;
  wire [0:0]TXPD;
  wire TXUSERRDY;
  wire cplllock;
  wire data_in;
  wire data_out;
  wire data_sync_reg1;
  wire gt0_gtrxreset_gt;
  wire gt0_gtrxreset_gt_d1;
  wire gt0_gttxreset_in0_out;
  wire gt0_qplloutclk_in;
  wire gt0_qplloutrefclk_in;
  wire \gt0_rx_cdrlock_counter[10]_i_1_n_0 ;
  wire \gt0_rx_cdrlock_counter[12]_i_1_n_0 ;
  wire \gt0_rx_cdrlock_counter[12]_i_3_n_0 ;
  wire \gt0_rx_cdrlock_counter[12]_i_4_n_0 ;
  wire \gt0_rx_cdrlock_counter[12]_i_5_n_0 ;
  wire \gt0_rx_cdrlock_counter[12]_i_6_n_0 ;
  wire \gt0_rx_cdrlock_counter[13]_i_10_n_0 ;
  wire \gt0_rx_cdrlock_counter[13]_i_1_n_0 ;
  wire \gt0_rx_cdrlock_counter[13]_i_4_n_0 ;
  wire \gt0_rx_cdrlock_counter[13]_i_6_n_0 ;
  wire \gt0_rx_cdrlock_counter[13]_i_7_n_0 ;
  wire \gt0_rx_cdrlock_counter[13]_i_8_n_0 ;
  wire \gt0_rx_cdrlock_counter[13]_i_9_n_0 ;
  wire \gt0_rx_cdrlock_counter[3]_i_2_n_0 ;
  wire \gt0_rx_cdrlock_counter[3]_i_3_n_0 ;
  wire \gt0_rx_cdrlock_counter[3]_i_4_n_0 ;
  wire \gt0_rx_cdrlock_counter[3]_i_5_n_0 ;
  wire \gt0_rx_cdrlock_counter[4]_i_1_n_0 ;
  wire \gt0_rx_cdrlock_counter[7]_i_2_n_0 ;
  wire \gt0_rx_cdrlock_counter[7]_i_3_n_0 ;
  wire \gt0_rx_cdrlock_counter[7]_i_4_n_0 ;
  wire \gt0_rx_cdrlock_counter[7]_i_5_n_0 ;
  wire \gt0_rx_cdrlock_counter[8]_i_1_n_0 ;
  wire \gt0_rx_cdrlock_counter[9]_i_1_n_0 ;
  wire \gt0_rx_cdrlock_counter_reg[12]_i_2_n_0 ;
  wire \gt0_rx_cdrlock_counter_reg[12]_i_2_n_1 ;
  wire \gt0_rx_cdrlock_counter_reg[12]_i_2_n_2 ;
  wire \gt0_rx_cdrlock_counter_reg[12]_i_2_n_3 ;
  wire \gt0_rx_cdrlock_counter_reg[13]_i_3_n_3 ;
  wire \gt0_rx_cdrlock_counter_reg[13]_i_5_n_0 ;
  wire \gt0_rx_cdrlock_counter_reg[13]_i_5_n_1 ;
  wire \gt0_rx_cdrlock_counter_reg[13]_i_5_n_2 ;
  wire \gt0_rx_cdrlock_counter_reg[13]_i_5_n_3 ;
  wire \gt0_rx_cdrlock_counter_reg[3]_i_1_n_0 ;
  wire \gt0_rx_cdrlock_counter_reg[3]_i_1_n_1 ;
  wire \gt0_rx_cdrlock_counter_reg[3]_i_1_n_2 ;
  wire \gt0_rx_cdrlock_counter_reg[3]_i_1_n_3 ;
  wire \gt0_rx_cdrlock_counter_reg[7]_i_1_n_0 ;
  wire \gt0_rx_cdrlock_counter_reg[7]_i_1_n_1 ;
  wire \gt0_rx_cdrlock_counter_reg[7]_i_1_n_2 ;
  wire \gt0_rx_cdrlock_counter_reg[7]_i_1_n_3 ;
  wire \gt0_rx_cdrlock_counter_reg_n_0_[0] ;
  wire \gt0_rx_cdrlock_counter_reg_n_0_[10] ;
  wire \gt0_rx_cdrlock_counter_reg_n_0_[11] ;
  wire \gt0_rx_cdrlock_counter_reg_n_0_[12] ;
  wire \gt0_rx_cdrlock_counter_reg_n_0_[13] ;
  wire \gt0_rx_cdrlock_counter_reg_n_0_[1] ;
  wire \gt0_rx_cdrlock_counter_reg_n_0_[2] ;
  wire \gt0_rx_cdrlock_counter_reg_n_0_[3] ;
  wire \gt0_rx_cdrlock_counter_reg_n_0_[4] ;
  wire \gt0_rx_cdrlock_counter_reg_n_0_[5] ;
  wire \gt0_rx_cdrlock_counter_reg_n_0_[6] ;
  wire \gt0_rx_cdrlock_counter_reg_n_0_[7] ;
  wire \gt0_rx_cdrlock_counter_reg_n_0_[8] ;
  wire \gt0_rx_cdrlock_counter_reg_n_0_[9] ;
  wire gt0_rx_cdrlocked;
  wire gt0_rx_cdrlocked_i_1_n_0;
  wire gtrefclk;
  wire gtrefclk_bufg;
  wire gtwizard_i_n_5;
  wire gtwizard_i_n_7;
  wire independent_clock_bufg;
  wire mmcm_locked;
  wire mmcm_reset;
  wire [13:0]p_2_in;
  wire pma_reset;
  wire reset;
  wire reset_out;
  wire reset_sync6;
  wire reset_sync6_0;
  wire [1:0]\rxchariscomma_reg_reg[1] ;
  wire [1:0]\rxcharisk_reg_reg[1] ;
  wire [15:0]\rxdata_reg_reg[15] ;
  wire [1:0]\rxdisperr_reg_reg[1] ;
  wire rxn;
  wire [1:0]\rxnotintable_reg_reg[1] ;
  wire rxoutclk;
  wire rxp;
  wire [1:0]\txchardispmode_int_reg[1] ;
  wire [1:0]\txchardispval_int_reg[1] ;
  wire [1:0]\txcharisk_int_reg[1] ;
  wire txn;
  wire txoutclk;
  wire txp;
  wire userclk;
  wire [3:0]\NLW_gt0_rx_cdrlock_counter_reg[13]_i_2_CO_UNCONNECTED ;
  wire [3:1]\NLW_gt0_rx_cdrlock_counter_reg[13]_i_2_O_UNCONNECTED ;
  wire [3:1]\NLW_gt0_rx_cdrlock_counter_reg[13]_i_3_CO_UNCONNECTED ;
  wire [3:0]\NLW_gt0_rx_cdrlock_counter_reg[13]_i_3_O_UNCONNECTED ;
  wire [3:0]\NLW_gt0_rx_cdrlock_counter_reg[13]_i_5_O_UNCONNECTED ;

  FDRE gt0_gtrxreset_gt_d1_reg
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(gt0_gtrxreset_gt),
        .Q(gt0_gtrxreset_gt_d1),
        .R(1'b0));
  LUT1 #(
    .INIT(2'h1)) 
    \gt0_rx_cdrlock_counter[0]_i_1 
       (.I0(\gt0_rx_cdrlock_counter_reg_n_0_[0] ),
        .O(p_2_in[0]));
  (* SOFT_HLUTNM = "soft_lutpair64" *) 
  LUT2 #(
    .INIT(4'hE)) 
    \gt0_rx_cdrlock_counter[10]_i_1 
       (.I0(p_2_in[10]),
        .I1(\gt0_rx_cdrlock_counter_reg[13]_i_3_n_3 ),
        .O(\gt0_rx_cdrlock_counter[10]_i_1_n_0 ));
  LUT2 #(
    .INIT(4'hE)) 
    \gt0_rx_cdrlock_counter[12]_i_1 
       (.I0(\gt0_rx_cdrlock_counter_reg[13]_i_3_n_3 ),
        .I1(gt0_gtrxreset_gt_d1),
        .O(\gt0_rx_cdrlock_counter[12]_i_1_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \gt0_rx_cdrlock_counter[12]_i_3 
       (.I0(\gt0_rx_cdrlock_counter_reg_n_0_[12] ),
        .O(\gt0_rx_cdrlock_counter[12]_i_3_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \gt0_rx_cdrlock_counter[12]_i_4 
       (.I0(\gt0_rx_cdrlock_counter_reg_n_0_[11] ),
        .O(\gt0_rx_cdrlock_counter[12]_i_4_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \gt0_rx_cdrlock_counter[12]_i_5 
       (.I0(\gt0_rx_cdrlock_counter_reg_n_0_[10] ),
        .O(\gt0_rx_cdrlock_counter[12]_i_5_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \gt0_rx_cdrlock_counter[12]_i_6 
       (.I0(\gt0_rx_cdrlock_counter_reg_n_0_[9] ),
        .O(\gt0_rx_cdrlock_counter[12]_i_6_n_0 ));
  (* SOFT_HLUTNM = "soft_lutpair63" *) 
  LUT2 #(
    .INIT(4'hE)) 
    \gt0_rx_cdrlock_counter[13]_i_1 
       (.I0(p_2_in[13]),
        .I1(\gt0_rx_cdrlock_counter_reg[13]_i_3_n_3 ),
        .O(\gt0_rx_cdrlock_counter[13]_i_1_n_0 ));
  LUT3 #(
    .INIT(8'h01)) 
    \gt0_rx_cdrlock_counter[13]_i_10 
       (.I0(\gt0_rx_cdrlock_counter_reg_n_0_[2] ),
        .I1(\gt0_rx_cdrlock_counter_reg_n_0_[1] ),
        .I2(\gt0_rx_cdrlock_counter_reg_n_0_[0] ),
        .O(\gt0_rx_cdrlock_counter[13]_i_10_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \gt0_rx_cdrlock_counter[13]_i_4 
       (.I0(\gt0_rx_cdrlock_counter_reg_n_0_[13] ),
        .O(\gt0_rx_cdrlock_counter[13]_i_4_n_0 ));
  LUT2 #(
    .INIT(4'h2)) 
    \gt0_rx_cdrlock_counter[13]_i_6 
       (.I0(\gt0_rx_cdrlock_counter_reg_n_0_[13] ),
        .I1(\gt0_rx_cdrlock_counter_reg_n_0_[12] ),
        .O(\gt0_rx_cdrlock_counter[13]_i_6_n_0 ));
  LUT3 #(
    .INIT(8'h20)) 
    \gt0_rx_cdrlock_counter[13]_i_7 
       (.I0(\gt0_rx_cdrlock_counter_reg_n_0_[9] ),
        .I1(\gt0_rx_cdrlock_counter_reg_n_0_[11] ),
        .I2(\gt0_rx_cdrlock_counter_reg_n_0_[10] ),
        .O(\gt0_rx_cdrlock_counter[13]_i_7_n_0 ));
  LUT3 #(
    .INIT(8'h04)) 
    \gt0_rx_cdrlock_counter[13]_i_8 
       (.I0(\gt0_rx_cdrlock_counter_reg_n_0_[7] ),
        .I1(\gt0_rx_cdrlock_counter_reg_n_0_[8] ),
        .I2(\gt0_rx_cdrlock_counter_reg_n_0_[6] ),
        .O(\gt0_rx_cdrlock_counter[13]_i_8_n_0 ));
  LUT3 #(
    .INIT(8'h04)) 
    \gt0_rx_cdrlock_counter[13]_i_9 
       (.I0(\gt0_rx_cdrlock_counter_reg_n_0_[5] ),
        .I1(\gt0_rx_cdrlock_counter_reg_n_0_[4] ),
        .I2(\gt0_rx_cdrlock_counter_reg_n_0_[3] ),
        .O(\gt0_rx_cdrlock_counter[13]_i_9_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \gt0_rx_cdrlock_counter[3]_i_2 
       (.I0(\gt0_rx_cdrlock_counter_reg_n_0_[4] ),
        .O(\gt0_rx_cdrlock_counter[3]_i_2_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \gt0_rx_cdrlock_counter[3]_i_3 
       (.I0(\gt0_rx_cdrlock_counter_reg_n_0_[3] ),
        .O(\gt0_rx_cdrlock_counter[3]_i_3_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \gt0_rx_cdrlock_counter[3]_i_4 
       (.I0(\gt0_rx_cdrlock_counter_reg_n_0_[2] ),
        .O(\gt0_rx_cdrlock_counter[3]_i_4_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \gt0_rx_cdrlock_counter[3]_i_5 
       (.I0(\gt0_rx_cdrlock_counter_reg_n_0_[1] ),
        .O(\gt0_rx_cdrlock_counter[3]_i_5_n_0 ));
  (* SOFT_HLUTNM = "soft_lutpair65" *) 
  LUT2 #(
    .INIT(4'hE)) 
    \gt0_rx_cdrlock_counter[4]_i_1 
       (.I0(p_2_in[4]),
        .I1(\gt0_rx_cdrlock_counter_reg[13]_i_3_n_3 ),
        .O(\gt0_rx_cdrlock_counter[4]_i_1_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \gt0_rx_cdrlock_counter[7]_i_2 
       (.I0(\gt0_rx_cdrlock_counter_reg_n_0_[8] ),
        .O(\gt0_rx_cdrlock_counter[7]_i_2_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \gt0_rx_cdrlock_counter[7]_i_3 
       (.I0(\gt0_rx_cdrlock_counter_reg_n_0_[7] ),
        .O(\gt0_rx_cdrlock_counter[7]_i_3_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \gt0_rx_cdrlock_counter[7]_i_4 
       (.I0(\gt0_rx_cdrlock_counter_reg_n_0_[6] ),
        .O(\gt0_rx_cdrlock_counter[7]_i_4_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \gt0_rx_cdrlock_counter[7]_i_5 
       (.I0(\gt0_rx_cdrlock_counter_reg_n_0_[5] ),
        .O(\gt0_rx_cdrlock_counter[7]_i_5_n_0 ));
  (* SOFT_HLUTNM = "soft_lutpair65" *) 
  LUT2 #(
    .INIT(4'hE)) 
    \gt0_rx_cdrlock_counter[8]_i_1 
       (.I0(p_2_in[8]),
        .I1(\gt0_rx_cdrlock_counter_reg[13]_i_3_n_3 ),
        .O(\gt0_rx_cdrlock_counter[8]_i_1_n_0 ));
  (* SOFT_HLUTNM = "soft_lutpair64" *) 
  LUT2 #(
    .INIT(4'hE)) 
    \gt0_rx_cdrlock_counter[9]_i_1 
       (.I0(p_2_in[9]),
        .I1(\gt0_rx_cdrlock_counter_reg[13]_i_3_n_3 ),
        .O(\gt0_rx_cdrlock_counter[9]_i_1_n_0 ));
  FDRE #(
    .INIT(1'b0)) 
    \gt0_rx_cdrlock_counter_reg[0] 
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(p_2_in[0]),
        .Q(\gt0_rx_cdrlock_counter_reg_n_0_[0] ),
        .R(\gt0_rx_cdrlock_counter[12]_i_1_n_0 ));
  FDRE #(
    .INIT(1'b0)) 
    \gt0_rx_cdrlock_counter_reg[10] 
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(\gt0_rx_cdrlock_counter[10]_i_1_n_0 ),
        .Q(\gt0_rx_cdrlock_counter_reg_n_0_[10] ),
        .R(gt0_gtrxreset_gt_d1));
  FDRE #(
    .INIT(1'b0)) 
    \gt0_rx_cdrlock_counter_reg[11] 
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(p_2_in[11]),
        .Q(\gt0_rx_cdrlock_counter_reg_n_0_[11] ),
        .R(\gt0_rx_cdrlock_counter[12]_i_1_n_0 ));
  FDRE #(
    .INIT(1'b0)) 
    \gt0_rx_cdrlock_counter_reg[12] 
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(p_2_in[12]),
        .Q(\gt0_rx_cdrlock_counter_reg_n_0_[12] ),
        .R(\gt0_rx_cdrlock_counter[12]_i_1_n_0 ));
  CARRY4 \gt0_rx_cdrlock_counter_reg[12]_i_2 
       (.CI(\gt0_rx_cdrlock_counter_reg[7]_i_1_n_0 ),
        .CO({\gt0_rx_cdrlock_counter_reg[12]_i_2_n_0 ,\gt0_rx_cdrlock_counter_reg[12]_i_2_n_1 ,\gt0_rx_cdrlock_counter_reg[12]_i_2_n_2 ,\gt0_rx_cdrlock_counter_reg[12]_i_2_n_3 }),
        .CYINIT(1'b0),
        .DI({1'b0,1'b0,1'b0,1'b0}),
        .O(p_2_in[12:9]),
        .S({\gt0_rx_cdrlock_counter[12]_i_3_n_0 ,\gt0_rx_cdrlock_counter[12]_i_4_n_0 ,\gt0_rx_cdrlock_counter[12]_i_5_n_0 ,\gt0_rx_cdrlock_counter[12]_i_6_n_0 }));
  FDRE #(
    .INIT(1'b0)) 
    \gt0_rx_cdrlock_counter_reg[13] 
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(\gt0_rx_cdrlock_counter[13]_i_1_n_0 ),
        .Q(\gt0_rx_cdrlock_counter_reg_n_0_[13] ),
        .R(gt0_gtrxreset_gt_d1));
  CARRY4 \gt0_rx_cdrlock_counter_reg[13]_i_2 
       (.CI(\gt0_rx_cdrlock_counter_reg[12]_i_2_n_0 ),
        .CO(\NLW_gt0_rx_cdrlock_counter_reg[13]_i_2_CO_UNCONNECTED [3:0]),
        .CYINIT(1'b0),
        .DI({1'b0,1'b0,1'b0,1'b0}),
        .O({\NLW_gt0_rx_cdrlock_counter_reg[13]_i_2_O_UNCONNECTED [3:1],p_2_in[13]}),
        .S({1'b0,1'b0,1'b0,\gt0_rx_cdrlock_counter[13]_i_4_n_0 }));
  CARRY4 \gt0_rx_cdrlock_counter_reg[13]_i_3 
       (.CI(\gt0_rx_cdrlock_counter_reg[13]_i_5_n_0 ),
        .CO({\NLW_gt0_rx_cdrlock_counter_reg[13]_i_3_CO_UNCONNECTED [3:1],\gt0_rx_cdrlock_counter_reg[13]_i_3_n_3 }),
        .CYINIT(1'b0),
        .DI({1'b0,1'b0,1'b0,1'b0}),
        .O(\NLW_gt0_rx_cdrlock_counter_reg[13]_i_3_O_UNCONNECTED [3:0]),
        .S({1'b0,1'b0,1'b0,\gt0_rx_cdrlock_counter[13]_i_6_n_0 }));
  CARRY4 \gt0_rx_cdrlock_counter_reg[13]_i_5 
       (.CI(1'b0),
        .CO({\gt0_rx_cdrlock_counter_reg[13]_i_5_n_0 ,\gt0_rx_cdrlock_counter_reg[13]_i_5_n_1 ,\gt0_rx_cdrlock_counter_reg[13]_i_5_n_2 ,\gt0_rx_cdrlock_counter_reg[13]_i_5_n_3 }),
        .CYINIT(1'b1),
        .DI({1'b0,1'b0,1'b0,1'b0}),
        .O(\NLW_gt0_rx_cdrlock_counter_reg[13]_i_5_O_UNCONNECTED [3:0]),
        .S({\gt0_rx_cdrlock_counter[13]_i_7_n_0 ,\gt0_rx_cdrlock_counter[13]_i_8_n_0 ,\gt0_rx_cdrlock_counter[13]_i_9_n_0 ,\gt0_rx_cdrlock_counter[13]_i_10_n_0 }));
  FDRE #(
    .INIT(1'b0)) 
    \gt0_rx_cdrlock_counter_reg[1] 
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(p_2_in[1]),
        .Q(\gt0_rx_cdrlock_counter_reg_n_0_[1] ),
        .R(\gt0_rx_cdrlock_counter[12]_i_1_n_0 ));
  FDRE #(
    .INIT(1'b0)) 
    \gt0_rx_cdrlock_counter_reg[2] 
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(p_2_in[2]),
        .Q(\gt0_rx_cdrlock_counter_reg_n_0_[2] ),
        .R(\gt0_rx_cdrlock_counter[12]_i_1_n_0 ));
  FDRE #(
    .INIT(1'b0)) 
    \gt0_rx_cdrlock_counter_reg[3] 
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(p_2_in[3]),
        .Q(\gt0_rx_cdrlock_counter_reg_n_0_[3] ),
        .R(\gt0_rx_cdrlock_counter[12]_i_1_n_0 ));
  CARRY4 \gt0_rx_cdrlock_counter_reg[3]_i_1 
       (.CI(1'b0),
        .CO({\gt0_rx_cdrlock_counter_reg[3]_i_1_n_0 ,\gt0_rx_cdrlock_counter_reg[3]_i_1_n_1 ,\gt0_rx_cdrlock_counter_reg[3]_i_1_n_2 ,\gt0_rx_cdrlock_counter_reg[3]_i_1_n_3 }),
        .CYINIT(\gt0_rx_cdrlock_counter_reg_n_0_[0] ),
        .DI({1'b0,1'b0,1'b0,1'b0}),
        .O(p_2_in[4:1]),
        .S({\gt0_rx_cdrlock_counter[3]_i_2_n_0 ,\gt0_rx_cdrlock_counter[3]_i_3_n_0 ,\gt0_rx_cdrlock_counter[3]_i_4_n_0 ,\gt0_rx_cdrlock_counter[3]_i_5_n_0 }));
  FDRE #(
    .INIT(1'b0)) 
    \gt0_rx_cdrlock_counter_reg[4] 
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(\gt0_rx_cdrlock_counter[4]_i_1_n_0 ),
        .Q(\gt0_rx_cdrlock_counter_reg_n_0_[4] ),
        .R(gt0_gtrxreset_gt_d1));
  FDRE #(
    .INIT(1'b0)) 
    \gt0_rx_cdrlock_counter_reg[5] 
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(p_2_in[5]),
        .Q(\gt0_rx_cdrlock_counter_reg_n_0_[5] ),
        .R(\gt0_rx_cdrlock_counter[12]_i_1_n_0 ));
  FDRE #(
    .INIT(1'b0)) 
    \gt0_rx_cdrlock_counter_reg[6] 
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(p_2_in[6]),
        .Q(\gt0_rx_cdrlock_counter_reg_n_0_[6] ),
        .R(\gt0_rx_cdrlock_counter[12]_i_1_n_0 ));
  FDRE #(
    .INIT(1'b0)) 
    \gt0_rx_cdrlock_counter_reg[7] 
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(p_2_in[7]),
        .Q(\gt0_rx_cdrlock_counter_reg_n_0_[7] ),
        .R(\gt0_rx_cdrlock_counter[12]_i_1_n_0 ));
  CARRY4 \gt0_rx_cdrlock_counter_reg[7]_i_1 
       (.CI(\gt0_rx_cdrlock_counter_reg[3]_i_1_n_0 ),
        .CO({\gt0_rx_cdrlock_counter_reg[7]_i_1_n_0 ,\gt0_rx_cdrlock_counter_reg[7]_i_1_n_1 ,\gt0_rx_cdrlock_counter_reg[7]_i_1_n_2 ,\gt0_rx_cdrlock_counter_reg[7]_i_1_n_3 }),
        .CYINIT(1'b0),
        .DI({1'b0,1'b0,1'b0,1'b0}),
        .O(p_2_in[8:5]),
        .S({\gt0_rx_cdrlock_counter[7]_i_2_n_0 ,\gt0_rx_cdrlock_counter[7]_i_3_n_0 ,\gt0_rx_cdrlock_counter[7]_i_4_n_0 ,\gt0_rx_cdrlock_counter[7]_i_5_n_0 }));
  FDRE #(
    .INIT(1'b0)) 
    \gt0_rx_cdrlock_counter_reg[8] 
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(\gt0_rx_cdrlock_counter[8]_i_1_n_0 ),
        .Q(\gt0_rx_cdrlock_counter_reg_n_0_[8] ),
        .R(gt0_gtrxreset_gt_d1));
  FDRE #(
    .INIT(1'b0)) 
    \gt0_rx_cdrlock_counter_reg[9] 
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(\gt0_rx_cdrlock_counter[9]_i_1_n_0 ),
        .Q(\gt0_rx_cdrlock_counter_reg_n_0_[9] ),
        .R(gt0_gtrxreset_gt_d1));
  (* SOFT_HLUTNM = "soft_lutpair63" *) 
  LUT2 #(
    .INIT(4'hE)) 
    gt0_rx_cdrlocked_i_1
       (.I0(\gt0_rx_cdrlock_counter_reg[13]_i_3_n_3 ),
        .I1(gt0_rx_cdrlocked),
        .O(gt0_rx_cdrlocked_i_1_n_0));
  FDRE gt0_rx_cdrlocked_reg
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(gt0_rx_cdrlocked_i_1_n_0),
        .Q(gt0_rx_cdrlocked),
        .R(gt0_gtrxreset_gt_d1));
  GigEthGth7Core_GigEthGth7Core_RX_STARTUP_FSM gt0_rxresetfsm_i
       (.RXUSERRDY(RXUSERRDY),
        .cplllock(cplllock),
        .\cpllpd_wait_reg[95] (gtwizard_i_n_5),
        .data_in(data_sync_reg1),
        .data_out(data_out),
        .gt0_gtrxreset_gt(gt0_gtrxreset_gt),
        .gt0_rx_cdrlocked(gt0_rx_cdrlocked),
        .independent_clock_bufg(independent_clock_bufg),
        .mmcm_locked(mmcm_locked),
        .pma_reset(pma_reset),
        .reset_sync6(reset_sync6),
        .userclk(userclk));
  GigEthGth7Core_GigEthGth7Core_TX_STARTUP_FSM gt0_txresetfsm_i
       (.CPLLREFCLKLOST(CPLLREFCLKLOST),
        .CPLL_RESET(CPLL_RESET),
        .TXUSERRDY(TXUSERRDY),
        .cplllock(cplllock),
        .\cpllpd_wait_reg[95] (gtwizard_i_n_7),
        .data_in(data_in),
        .gt0_gttxreset_in0_out(gt0_gttxreset_in0_out),
        .independent_clock_bufg(independent_clock_bufg),
        .mmcm_locked(mmcm_locked),
        .mmcm_reset(mmcm_reset),
        .pma_reset(pma_reset),
        .reset_sync6(reset_sync6_0),
        .userclk(userclk));
  GigEthGth7Core_GigEthGth7Core_GTWIZARD_multi_gt gtwizard_i
       (.CPLLREFCLKLOST(CPLLREFCLKLOST),
        .CPLL_RESET(CPLL_RESET),
        .D(D),
        .Q(Q),
        .RXBUFSTATUS(RXBUFSTATUS),
        .RXPD(RXPD),
        .RXUSERRDY(RXUSERRDY),
        .SR(gt0_gtrxreset_gt_d1),
        .TXBUFSTATUS(TXBUFSTATUS),
        .TXPD(TXPD),
        .TXUSERRDY(TXUSERRDY),
        .cplllock(cplllock),
        .data_sync_reg1(gtwizard_i_n_5),
        .data_sync_reg1_0(gtwizard_i_n_7),
        .gt0_gttxreset_in0_out(gt0_gttxreset_in0_out),
        .gt0_qplloutclk_in(gt0_qplloutclk_in),
        .gt0_qplloutrefclk_in(gt0_qplloutrefclk_in),
        .gtrefclk(gtrefclk),
        .gtrefclk_bufg(gtrefclk_bufg),
        .independent_clock_bufg(independent_clock_bufg),
        .reset(reset),
        .reset_out(reset_out),
        .\rxchariscomma_reg_reg[1] (\rxchariscomma_reg_reg[1] ),
        .\rxcharisk_reg_reg[1] (\rxcharisk_reg_reg[1] ),
        .\rxdata_reg_reg[15] (\rxdata_reg_reg[15] ),
        .\rxdisperr_reg_reg[1] (\rxdisperr_reg_reg[1] ),
        .rxn(rxn),
        .\rxnotintable_reg_reg[1] (\rxnotintable_reg_reg[1] ),
        .rxoutclk(rxoutclk),
        .rxp(rxp),
        .\txchardispmode_int_reg[1] (\txchardispmode_int_reg[1] ),
        .\txchardispval_int_reg[1] (\txchardispval_int_reg[1] ),
        .\txcharisk_int_reg[1] (\txcharisk_int_reg[1] ),
        .txn(txn),
        .txoutclk(txoutclk),
        .txp(txp),
        .userclk(userclk));
endmodule

(* ORIG_REF_NAME = "GigEthGth7Core_GTWIZARD_multi_gt" *) 
module GigEthGth7Core_GigEthGth7Core_GTWIZARD_multi_gt
   (cplllock,
    CPLLREFCLKLOST,
    txn,
    txp,
    rxoutclk,
    data_sync_reg1,
    txoutclk,
    data_sync_reg1_0,
    D,
    TXBUFSTATUS,
    RXBUFSTATUS,
    \rxdata_reg_reg[15] ,
    \rxchariscomma_reg_reg[1] ,
    \rxcharisk_reg_reg[1] ,
    \rxdisperr_reg_reg[1] ,
    \rxnotintable_reg_reg[1] ,
    gtrefclk_bufg,
    independent_clock_bufg,
    rxn,
    rxp,
    gtrefclk,
    gt0_gttxreset_in0_out,
    gt0_qplloutclk_in,
    gt0_qplloutrefclk_in,
    reset_out,
    reset,
    RXUSERRDY,
    userclk,
    TXPD,
    TXUSERRDY,
    RXPD,
    Q,
    \txchardispmode_int_reg[1] ,
    \txchardispval_int_reg[1] ,
    \txcharisk_int_reg[1] ,
    CPLL_RESET,
    SR);
  output cplllock;
  output CPLLREFCLKLOST;
  output txn;
  output txp;
  output rxoutclk;
  output data_sync_reg1;
  output txoutclk;
  output data_sync_reg1_0;
  output [1:0]D;
  output [0:0]TXBUFSTATUS;
  output [0:0]RXBUFSTATUS;
  output [15:0]\rxdata_reg_reg[15] ;
  output [1:0]\rxchariscomma_reg_reg[1] ;
  output [1:0]\rxcharisk_reg_reg[1] ;
  output [1:0]\rxdisperr_reg_reg[1] ;
  output [1:0]\rxnotintable_reg_reg[1] ;
  input gtrefclk_bufg;
  input independent_clock_bufg;
  input rxn;
  input rxp;
  input gtrefclk;
  input gt0_gttxreset_in0_out;
  input gt0_qplloutclk_in;
  input gt0_qplloutrefclk_in;
  input reset_out;
  input reset;
  input RXUSERRDY;
  input userclk;
  input [0:0]TXPD;
  input TXUSERRDY;
  input [0:0]RXPD;
  input [15:0]Q;
  input [1:0]\txchardispmode_int_reg[1] ;
  input [1:0]\txchardispval_int_reg[1] ;
  input [1:0]\txcharisk_int_reg[1] ;
  input CPLL_RESET;
  input [0:0]SR;

  wire CPLLREFCLKLOST;
  wire CPLL_RESET;
  wire [1:0]D;
  wire [15:0]Q;
  wire [0:0]RXBUFSTATUS;
  wire [0:0]RXPD;
  wire RXUSERRDY;
  wire [0:0]SR;
  wire [0:0]TXBUFSTATUS;
  wire [0:0]TXPD;
  wire TXUSERRDY;
  wire cpll_pd_out;
  wire cplllock;
  wire cpllreset_in;
  wire data_sync_reg1;
  wire data_sync_reg1_0;
  wire gt0_gttxreset_in0_out;
  wire gt0_qplloutclk_in;
  wire gt0_qplloutrefclk_in;
  wire gtrefclk;
  wire gtrefclk_bufg;
  wire independent_clock_bufg;
  wire reset;
  wire reset_out;
  wire [1:0]\rxchariscomma_reg_reg[1] ;
  wire [1:0]\rxcharisk_reg_reg[1] ;
  wire [15:0]\rxdata_reg_reg[15] ;
  wire [1:0]\rxdisperr_reg_reg[1] ;
  wire rxn;
  wire [1:0]\rxnotintable_reg_reg[1] ;
  wire rxoutclk;
  wire rxp;
  wire [1:0]\txchardispmode_int_reg[1] ;
  wire [1:0]\txchardispval_int_reg[1] ;
  wire [1:0]\txcharisk_int_reg[1] ;
  wire txn;
  wire txoutclk;
  wire txp;
  wire userclk;

  GigEthGth7Core_GigEthGth7Core_cpll_railing cpll_railing0_i
       (.CPLL_RESET(CPLL_RESET),
        .cpll_pd_out(cpll_pd_out),
        .cpllreset_in(cpllreset_in),
        .gtrefclk_bufg(gtrefclk_bufg));
  GigEthGth7Core_GigEthGth7Core_GTWIZARD_GT gt0_GTWIZARD_i
       (.CPLLREFCLKLOST(CPLLREFCLKLOST),
        .CPLL_RESET(CPLL_RESET),
        .D(D),
        .Q(Q),
        .RXBUFSTATUS(RXBUFSTATUS),
        .RXPD(RXPD),
        .RXUSERRDY(RXUSERRDY),
        .SR(SR),
        .TXBUFSTATUS(TXBUFSTATUS),
        .TXPD(TXPD),
        .TXUSERRDY(TXUSERRDY),
        .cpll_pd_out(cpll_pd_out),
        .cplllock(cplllock),
        .cpllreset_in(cpllreset_in),
        .data_sync_reg1(data_sync_reg1),
        .data_sync_reg1_0(data_sync_reg1_0),
        .gt0_gttxreset_in0_out(gt0_gttxreset_in0_out),
        .gt0_qplloutclk_in(gt0_qplloutclk_in),
        .gt0_qplloutrefclk_in(gt0_qplloutrefclk_in),
        .gtrefclk(gtrefclk),
        .gtrefclk_bufg(gtrefclk_bufg),
        .independent_clock_bufg(independent_clock_bufg),
        .reset(reset),
        .reset_out(reset_out),
        .\rxchariscomma_reg_reg[1] (\rxchariscomma_reg_reg[1] ),
        .\rxcharisk_reg_reg[1] (\rxcharisk_reg_reg[1] ),
        .\rxdata_reg_reg[15] (\rxdata_reg_reg[15] ),
        .\rxdisperr_reg_reg[1] (\rxdisperr_reg_reg[1] ),
        .rxn(rxn),
        .\rxnotintable_reg_reg[1] (\rxnotintable_reg_reg[1] ),
        .rxoutclk(rxoutclk),
        .rxp(rxp),
        .\txchardispmode_int_reg[1] (\txchardispmode_int_reg[1] ),
        .\txchardispval_int_reg[1] (\txchardispval_int_reg[1] ),
        .\txcharisk_int_reg[1] (\txcharisk_int_reg[1] ),
        .txn(txn),
        .txoutclk(txoutclk),
        .txp(txp),
        .userclk(userclk));
endmodule

(* ORIG_REF_NAME = "GigEthGth7Core_RX_STARTUP_FSM" *) 
module GigEthGth7Core_GigEthGth7Core_RX_STARTUP_FSM
   (data_in,
    RXUSERRDY,
    gt0_gtrxreset_gt,
    independent_clock_bufg,
    userclk,
    pma_reset,
    reset_sync6,
    \cpllpd_wait_reg[95] ,
    mmcm_locked,
    data_out,
    cplllock,
    gt0_rx_cdrlocked);
  output data_in;
  output RXUSERRDY;
  output gt0_gtrxreset_gt;
  input independent_clock_bufg;
  input userclk;
  input pma_reset;
  input reset_sync6;
  input \cpllpd_wait_reg[95] ;
  input mmcm_locked;
  input data_out;
  input cplllock;
  input gt0_rx_cdrlocked;

  wire \FSM_sequential_rx_state[0]_i_2_n_0 ;
  wire \FSM_sequential_rx_state[2]_i_1_n_0 ;
  wire \FSM_sequential_rx_state[3]_i_3_n_0 ;
  wire \FSM_sequential_rx_state[3]_i_6_n_0 ;
  wire \FSM_sequential_rx_state[3]_i_8_n_0 ;
  wire \FSM_sequential_rx_state[3]_i_9_n_0 ;
  wire GTRXRESET;
  wire RXUSERRDY;
  wire RXUSERRDY_i_1_n_0;
  wire check_tlock_max_i_1_n_0;
  wire check_tlock_max_reg_n_0;
  wire cplllock;
  wire cplllock_sync;
  wire \cpllpd_wait_reg[95] ;
  wire data_in;
  wire data_out;
  wire gt0_gtrxreset_gt;
  wire gt0_rx_cdrlocked;
  wire gtrxreset_i_i_1_n_0;
  wire independent_clock_bufg;
  wire init_wait_count;
  wire \init_wait_count[0]_i_1__0_n_0 ;
  wire \init_wait_count[6]_i_3__0_n_0 ;
  wire [6:0]init_wait_count_reg__0;
  wire init_wait_done_i_1__0_n_0;
  wire init_wait_done_reg_n_0;
  wire \mmcm_lock_count[7]_i_2__0_n_0 ;
  wire \mmcm_lock_count[7]_i_4__0_n_0 ;
  wire [7:0]mmcm_lock_count_reg__0;
  wire mmcm_lock_reclocked;
  wire mmcm_lock_reclocked_i_2__0_n_0;
  wire mmcm_locked;
  wire [6:1]p_0_in__1;
  wire [7:0]p_0_in__2;
  wire pma_reset;
  wire reset_sync6;
  wire reset_time_out_i_2__0_n_0;
  wire reset_time_out_i_4__0_n_0;
  wire reset_time_out_reg_n_0;
  wire run_phase_alignment_int_i_1__0_n_0;
  wire run_phase_alignment_int_reg_n_0;
  wire run_phase_alignment_int_s2;
  wire run_phase_alignment_int_s3_reg_n_0;
  wire rx_fsm_reset_done_int_i_5_n_0;
  wire rx_fsm_reset_done_int_s2;
  wire rx_fsm_reset_done_int_s3;
  (* RTL_KEEP = "yes" *) wire [3:0]rx_state;
  wire rx_state15_out;
  wire rxresetdone_s2;
  wire rxresetdone_s3;
  wire sync_cplllock_n_0;
  wire sync_data_valid_n_0;
  wire sync_data_valid_n_1;
  wire sync_data_valid_n_2;
  wire sync_data_valid_n_3;
  wire sync_data_valid_n_4;
  wire sync_data_valid_n_5;
  wire sync_mmcm_lock_reclocked_n_0;
  wire sync_mmcm_lock_reclocked_n_1;
  wire time_out_100us;
  wire time_out_100us_i_10_n_0;
  wire time_out_100us_i_1_n_0;
  wire time_out_100us_i_4_n_0;
  wire time_out_100us_i_5_n_0;
  wire time_out_100us_i_6_n_0;
  wire time_out_100us_i_7_n_0;
  wire time_out_100us_i_8_n_0;
  wire time_out_100us_i_9_n_0;
  wire time_out_100us_reg_i_2_n_1;
  wire time_out_100us_reg_i_2_n_2;
  wire time_out_100us_reg_i_2_n_3;
  wire time_out_100us_reg_i_3_n_0;
  wire time_out_100us_reg_i_3_n_1;
  wire time_out_100us_reg_i_3_n_2;
  wire time_out_100us_reg_i_3_n_3;
  wire time_out_1us;
  wire time_out_1us_i_10_n_0;
  wire time_out_1us_i_1_n_0;
  wire time_out_1us_i_4_n_0;
  wire time_out_1us_i_5_n_0;
  wire time_out_1us_i_6_n_0;
  wire time_out_1us_i_7_n_0;
  wire time_out_1us_i_8_n_0;
  wire time_out_1us_i_9_n_0;
  wire time_out_1us_reg_i_2_n_1;
  wire time_out_1us_reg_i_2_n_2;
  wire time_out_1us_reg_i_2_n_3;
  wire time_out_1us_reg_i_3_n_0;
  wire time_out_1us_reg_i_3_n_1;
  wire time_out_1us_reg_i_3_n_2;
  wire time_out_1us_reg_i_3_n_3;
  wire time_out_2ms;
  wire time_out_2ms_i_1__0_n_0;
  wire \time_out_counter[0]_i_10__0_n_0 ;
  wire \time_out_counter[0]_i_11__0_n_0 ;
  wire \time_out_counter[0]_i_12__0_n_0 ;
  wire \time_out_counter[0]_i_13_n_0 ;
  wire \time_out_counter[0]_i_14__0_n_0 ;
  wire \time_out_counter[0]_i_15__0_n_0 ;
  wire \time_out_counter[0]_i_1__0_n_0 ;
  wire \time_out_counter[0]_i_4__0_n_0 ;
  wire \time_out_counter[0]_i_5__0_n_0 ;
  wire \time_out_counter[0]_i_6__0_n_0 ;
  wire \time_out_counter[0]_i_7_n_0 ;
  wire \time_out_counter[0]_i_9_n_0 ;
  wire \time_out_counter[12]_i_2__0_n_0 ;
  wire \time_out_counter[12]_i_3__0_n_0 ;
  wire \time_out_counter[12]_i_4__0_n_0 ;
  wire \time_out_counter[12]_i_5__0_n_0 ;
  wire \time_out_counter[16]_i_2__0_n_0 ;
  wire \time_out_counter[16]_i_3__0_n_0 ;
  wire \time_out_counter[16]_i_4__0_n_0 ;
  wire \time_out_counter[16]_i_5_n_0 ;
  wire \time_out_counter[4]_i_2__0_n_0 ;
  wire \time_out_counter[4]_i_3__0_n_0 ;
  wire \time_out_counter[4]_i_4__0_n_0 ;
  wire \time_out_counter[4]_i_5__0_n_0 ;
  wire \time_out_counter[8]_i_2__0_n_0 ;
  wire \time_out_counter[8]_i_3__0_n_0 ;
  wire \time_out_counter[8]_i_4__0_n_0 ;
  wire \time_out_counter[8]_i_5__0_n_0 ;
  wire [19:0]time_out_counter_reg;
  wire \time_out_counter_reg[0]_i_2__0_n_0 ;
  wire \time_out_counter_reg[0]_i_2__0_n_1 ;
  wire \time_out_counter_reg[0]_i_2__0_n_2 ;
  wire \time_out_counter_reg[0]_i_2__0_n_3 ;
  wire \time_out_counter_reg[0]_i_2__0_n_4 ;
  wire \time_out_counter_reg[0]_i_2__0_n_5 ;
  wire \time_out_counter_reg[0]_i_2__0_n_6 ;
  wire \time_out_counter_reg[0]_i_2__0_n_7 ;
  wire \time_out_counter_reg[0]_i_3__0_n_1 ;
  wire \time_out_counter_reg[0]_i_3__0_n_2 ;
  wire \time_out_counter_reg[0]_i_3__0_n_3 ;
  wire \time_out_counter_reg[0]_i_8__0_n_0 ;
  wire \time_out_counter_reg[0]_i_8__0_n_1 ;
  wire \time_out_counter_reg[0]_i_8__0_n_2 ;
  wire \time_out_counter_reg[0]_i_8__0_n_3 ;
  wire \time_out_counter_reg[12]_i_1__0_n_0 ;
  wire \time_out_counter_reg[12]_i_1__0_n_1 ;
  wire \time_out_counter_reg[12]_i_1__0_n_2 ;
  wire \time_out_counter_reg[12]_i_1__0_n_3 ;
  wire \time_out_counter_reg[12]_i_1__0_n_4 ;
  wire \time_out_counter_reg[12]_i_1__0_n_5 ;
  wire \time_out_counter_reg[12]_i_1__0_n_6 ;
  wire \time_out_counter_reg[12]_i_1__0_n_7 ;
  wire \time_out_counter_reg[16]_i_1__0_n_1 ;
  wire \time_out_counter_reg[16]_i_1__0_n_2 ;
  wire \time_out_counter_reg[16]_i_1__0_n_3 ;
  wire \time_out_counter_reg[16]_i_1__0_n_4 ;
  wire \time_out_counter_reg[16]_i_1__0_n_5 ;
  wire \time_out_counter_reg[16]_i_1__0_n_6 ;
  wire \time_out_counter_reg[16]_i_1__0_n_7 ;
  wire \time_out_counter_reg[4]_i_1__0_n_0 ;
  wire \time_out_counter_reg[4]_i_1__0_n_1 ;
  wire \time_out_counter_reg[4]_i_1__0_n_2 ;
  wire \time_out_counter_reg[4]_i_1__0_n_3 ;
  wire \time_out_counter_reg[4]_i_1__0_n_4 ;
  wire \time_out_counter_reg[4]_i_1__0_n_5 ;
  wire \time_out_counter_reg[4]_i_1__0_n_6 ;
  wire \time_out_counter_reg[4]_i_1__0_n_7 ;
  wire \time_out_counter_reg[8]_i_1__0_n_0 ;
  wire \time_out_counter_reg[8]_i_1__0_n_1 ;
  wire \time_out_counter_reg[8]_i_1__0_n_2 ;
  wire \time_out_counter_reg[8]_i_1__0_n_3 ;
  wire \time_out_counter_reg[8]_i_1__0_n_4 ;
  wire \time_out_counter_reg[8]_i_1__0_n_5 ;
  wire \time_out_counter_reg[8]_i_1__0_n_6 ;
  wire \time_out_counter_reg[8]_i_1__0_n_7 ;
  wire time_out_wait_bypass_i_1__0_n_0;
  wire time_out_wait_bypass_reg_n_0;
  wire time_out_wait_bypass_s2;
  wire time_out_wait_bypass_s3;
  wire time_tlock_max;
  wire time_tlock_max1;
  wire time_tlock_max_i_10_n_0;
  wire time_tlock_max_i_11_n_0;
  wire time_tlock_max_i_12_n_0;
  wire time_tlock_max_i_13_n_0;
  wire time_tlock_max_i_14_n_0;
  wire time_tlock_max_i_15_n_0;
  wire time_tlock_max_i_16_n_0;
  wire time_tlock_max_i_17_n_0;
  wire time_tlock_max_i_18_n_0;
  wire time_tlock_max_i_19_n_0;
  wire time_tlock_max_i_1_n_0;
  wire time_tlock_max_i_20_n_0;
  wire time_tlock_max_i_21_n_0;
  wire time_tlock_max_i_22_n_0;
  wire time_tlock_max_i_4_n_0;
  wire time_tlock_max_i_5__0_n_0;
  wire time_tlock_max_i_6__0_n_0;
  wire time_tlock_max_i_7__0_n_0;
  wire time_tlock_max_i_9_n_0;
  wire time_tlock_max_reg_i_2__0_n_3;
  wire time_tlock_max_reg_i_3__0_n_0;
  wire time_tlock_max_reg_i_3__0_n_1;
  wire time_tlock_max_reg_i_3__0_n_2;
  wire time_tlock_max_reg_i_3__0_n_3;
  wire time_tlock_max_reg_i_8_n_0;
  wire time_tlock_max_reg_i_8_n_1;
  wire time_tlock_max_reg_i_8_n_2;
  wire time_tlock_max_reg_i_8_n_3;
  wire userclk;
  wire wait_bypass_count;
  wire wait_bypass_count1;
  wire \wait_bypass_count[0]_i_10__0_n_0 ;
  wire \wait_bypass_count[0]_i_1__0_n_0 ;
  wire \wait_bypass_count[0]_i_5__0_n_0 ;
  wire \wait_bypass_count[0]_i_6__0_n_0 ;
  wire \wait_bypass_count[0]_i_7__0_n_0 ;
  wire \wait_bypass_count[0]_i_8__0_n_0 ;
  wire \wait_bypass_count[0]_i_9__0_n_0 ;
  wire \wait_bypass_count[12]_i_2__0_n_0 ;
  wire \wait_bypass_count[4]_i_2__0_n_0 ;
  wire \wait_bypass_count[4]_i_3__0_n_0 ;
  wire \wait_bypass_count[4]_i_4__0_n_0 ;
  wire \wait_bypass_count[4]_i_5__0_n_0 ;
  wire \wait_bypass_count[8]_i_2__0_n_0 ;
  wire \wait_bypass_count[8]_i_3__0_n_0 ;
  wire \wait_bypass_count[8]_i_4__0_n_0 ;
  wire \wait_bypass_count[8]_i_5__0_n_0 ;
  wire [12:0]wait_bypass_count_reg;
  wire \wait_bypass_count_reg[0]_i_3__0_n_0 ;
  wire \wait_bypass_count_reg[0]_i_3__0_n_1 ;
  wire \wait_bypass_count_reg[0]_i_3__0_n_2 ;
  wire \wait_bypass_count_reg[0]_i_3__0_n_3 ;
  wire \wait_bypass_count_reg[0]_i_3__0_n_4 ;
  wire \wait_bypass_count_reg[0]_i_3__0_n_5 ;
  wire \wait_bypass_count_reg[0]_i_3__0_n_6 ;
  wire \wait_bypass_count_reg[0]_i_3__0_n_7 ;
  wire \wait_bypass_count_reg[12]_i_1__0_n_7 ;
  wire \wait_bypass_count_reg[4]_i_1__0_n_0 ;
  wire \wait_bypass_count_reg[4]_i_1__0_n_1 ;
  wire \wait_bypass_count_reg[4]_i_1__0_n_2 ;
  wire \wait_bypass_count_reg[4]_i_1__0_n_3 ;
  wire \wait_bypass_count_reg[4]_i_1__0_n_4 ;
  wire \wait_bypass_count_reg[4]_i_1__0_n_5 ;
  wire \wait_bypass_count_reg[4]_i_1__0_n_6 ;
  wire \wait_bypass_count_reg[4]_i_1__0_n_7 ;
  wire \wait_bypass_count_reg[8]_i_1__0_n_0 ;
  wire \wait_bypass_count_reg[8]_i_1__0_n_1 ;
  wire \wait_bypass_count_reg[8]_i_1__0_n_2 ;
  wire \wait_bypass_count_reg[8]_i_1__0_n_3 ;
  wire \wait_bypass_count_reg[8]_i_1__0_n_4 ;
  wire \wait_bypass_count_reg[8]_i_1__0_n_5 ;
  wire \wait_bypass_count_reg[8]_i_1__0_n_6 ;
  wire \wait_bypass_count_reg[8]_i_1__0_n_7 ;
  wire [6:0]wait_time_cnt0__0;
  wire \wait_time_cnt[6]_i_1__0_n_0 ;
  wire \wait_time_cnt[6]_i_2__0_n_0 ;
  wire \wait_time_cnt[6]_i_4__0_n_0 ;
  wire [6:0]wait_time_cnt_reg__0;
  wire [3:3]NLW_time_out_100us_reg_i_2_CO_UNCONNECTED;
  wire [3:0]NLW_time_out_100us_reg_i_2_O_UNCONNECTED;
  wire [3:0]NLW_time_out_100us_reg_i_3_O_UNCONNECTED;
  wire [3:3]NLW_time_out_1us_reg_i_2_CO_UNCONNECTED;
  wire [3:0]NLW_time_out_1us_reg_i_2_O_UNCONNECTED;
  wire [3:0]NLW_time_out_1us_reg_i_3_O_UNCONNECTED;
  wire [3:3]\NLW_time_out_counter_reg[0]_i_3__0_CO_UNCONNECTED ;
  wire [3:0]\NLW_time_out_counter_reg[0]_i_3__0_O_UNCONNECTED ;
  wire [3:0]\NLW_time_out_counter_reg[0]_i_8__0_O_UNCONNECTED ;
  wire [3:3]\NLW_time_out_counter_reg[16]_i_1__0_CO_UNCONNECTED ;
  wire [3:2]NLW_time_tlock_max_reg_i_2__0_CO_UNCONNECTED;
  wire [3:0]NLW_time_tlock_max_reg_i_2__0_O_UNCONNECTED;
  wire [3:0]NLW_time_tlock_max_reg_i_3__0_O_UNCONNECTED;
  wire [3:0]NLW_time_tlock_max_reg_i_8_O_UNCONNECTED;
  wire [3:0]\NLW_wait_bypass_count_reg[12]_i_1__0_CO_UNCONNECTED ;
  wire [3:1]\NLW_wait_bypass_count_reg[12]_i_1__0_O_UNCONNECTED ;

  LUT6 #(
    .INIT(64'hAA2A202AAA2A2A2A)) 
    \FSM_sequential_rx_state[0]_i_2 
       (.I0(rx_state[0]),
        .I1(time_out_2ms),
        .I2(rx_state[1]),
        .I3(rx_state[2]),
        .I4(reset_time_out_reg_n_0),
        .I5(time_tlock_max),
        .O(\FSM_sequential_rx_state[0]_i_2_n_0 ));
  LUT6 #(
    .INIT(64'h00000000110CFF00)) 
    \FSM_sequential_rx_state[2]_i_1 
       (.I0(rx_state15_out),
        .I1(rx_state[1]),
        .I2(time_out_2ms),
        .I3(rx_state[2]),
        .I4(rx_state[0]),
        .I5(rx_state[3]),
        .O(\FSM_sequential_rx_state[2]_i_1_n_0 ));
  (* SOFT_HLUTNM = "soft_lutpair43" *) 
  LUT2 #(
    .INIT(4'h2)) 
    \FSM_sequential_rx_state[2]_i_2 
       (.I0(time_tlock_max),
        .I1(reset_time_out_reg_n_0),
        .O(rx_state15_out));
  LUT6 #(
    .INIT(64'h00CA00CA00CAFFCA)) 
    \FSM_sequential_rx_state[3]_i_3 
       (.I0(init_wait_done_reg_n_0),
        .I1(gt0_rx_cdrlocked),
        .I2(rx_state[2]),
        .I3(rx_state[1]),
        .I4(wait_time_cnt_reg__0[6]),
        .I5(\wait_time_cnt[6]_i_4__0_n_0 ),
        .O(\FSM_sequential_rx_state[3]_i_3_n_0 ));
  LUT2 #(
    .INIT(4'hB)) 
    \FSM_sequential_rx_state[3]_i_6 
       (.I0(rx_state[3]),
        .I1(rx_state[0]),
        .O(\FSM_sequential_rx_state[3]_i_6_n_0 ));
  LUT6 #(
    .INIT(64'hCFEFCFEFC0EFC0E0)) 
    \FSM_sequential_rx_state[3]_i_8 
       (.I0(time_out_2ms),
        .I1(rxresetdone_s3),
        .I2(rx_state[1]),
        .I3(reset_time_out_reg_n_0),
        .I4(time_tlock_max),
        .I5(mmcm_lock_reclocked),
        .O(\FSM_sequential_rx_state[3]_i_8_n_0 ));
  (* SOFT_HLUTNM = "soft_lutpair47" *) 
  LUT2 #(
    .INIT(4'h2)) 
    \FSM_sequential_rx_state[3]_i_9 
       (.I0(time_out_100us),
        .I1(reset_time_out_reg_n_0),
        .O(\FSM_sequential_rx_state[3]_i_9_n_0 ));
  (* KEEP = "yes" *) 
  FDRE \FSM_sequential_rx_state_reg[0] 
       (.C(independent_clock_bufg),
        .CE(sync_cplllock_n_0),
        .D(sync_data_valid_n_4),
        .Q(rx_state[0]),
        .R(pma_reset));
  (* KEEP = "yes" *) 
  FDRE \FSM_sequential_rx_state_reg[1] 
       (.C(independent_clock_bufg),
        .CE(sync_cplllock_n_0),
        .D(sync_data_valid_n_3),
        .Q(rx_state[1]),
        .R(pma_reset));
  (* KEEP = "yes" *) 
  FDRE \FSM_sequential_rx_state_reg[2] 
       (.C(independent_clock_bufg),
        .CE(sync_cplllock_n_0),
        .D(\FSM_sequential_rx_state[2]_i_1_n_0 ),
        .Q(rx_state[2]),
        .R(pma_reset));
  (* KEEP = "yes" *) 
  FDRE \FSM_sequential_rx_state_reg[3] 
       (.C(independent_clock_bufg),
        .CE(sync_cplllock_n_0),
        .D(sync_data_valid_n_2),
        .Q(rx_state[3]),
        .R(pma_reset));
  LUT5 #(
    .INIT(32'hFFFB4000)) 
    RXUSERRDY_i_1
       (.I0(rx_state[3]),
        .I1(rx_state[0]),
        .I2(rx_state[2]),
        .I3(rx_state[1]),
        .I4(RXUSERRDY),
        .O(RXUSERRDY_i_1_n_0));
  FDRE #(
    .INIT(1'b0)) 
    RXUSERRDY_reg
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(RXUSERRDY_i_1_n_0),
        .Q(RXUSERRDY),
        .R(pma_reset));
  LUT5 #(
    .INIT(32'hFFEF0020)) 
    check_tlock_max_i_1
       (.I0(rx_state[2]),
        .I1(rx_state[1]),
        .I2(rx_state[0]),
        .I3(rx_state[3]),
        .I4(check_tlock_max_reg_n_0),
        .O(check_tlock_max_i_1_n_0));
  FDRE #(
    .INIT(1'b0)) 
    check_tlock_max_reg
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(check_tlock_max_i_1_n_0),
        .Q(check_tlock_max_reg_n_0),
        .R(pma_reset));
  LUT3 #(
    .INIT(8'hEA)) 
    gt0_gtrxreset_gt_d1_i_1
       (.I0(GTRXRESET),
        .I1(data_in),
        .I2(reset_sync6),
        .O(gt0_gtrxreset_gt));
  LUT5 #(
    .INIT(32'hFEFF0004)) 
    gtrxreset_i_i_1
       (.I0(rx_state[3]),
        .I1(rx_state[0]),
        .I2(rx_state[1]),
        .I3(rx_state[2]),
        .I4(GTRXRESET),
        .O(gtrxreset_i_i_1_n_0));
  FDRE #(
    .INIT(1'b0)) 
    gtrxreset_i_reg
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(gtrxreset_i_i_1_n_0),
        .Q(GTRXRESET),
        .R(pma_reset));
  (* SOFT_HLUTNM = "soft_lutpair38" *) 
  LUT1 #(
    .INIT(2'h1)) 
    \init_wait_count[0]_i_1__0 
       (.I0(init_wait_count_reg__0[0]),
        .O(\init_wait_count[0]_i_1__0_n_0 ));
  (* SOFT_HLUTNM = "soft_lutpair45" *) 
  LUT2 #(
    .INIT(4'h6)) 
    \init_wait_count[1]_i_1__0 
       (.I0(init_wait_count_reg__0[1]),
        .I1(init_wait_count_reg__0[0]),
        .O(p_0_in__1[1]));
  (* SOFT_HLUTNM = "soft_lutpair45" *) 
  LUT3 #(
    .INIT(8'h78)) 
    \init_wait_count[2]_i_1__0 
       (.I0(init_wait_count_reg__0[0]),
        .I1(init_wait_count_reg__0[1]),
        .I2(init_wait_count_reg__0[2]),
        .O(p_0_in__1[2]));
  (* SOFT_HLUTNM = "soft_lutpair39" *) 
  LUT4 #(
    .INIT(16'h6AAA)) 
    \init_wait_count[3]_i_1__0 
       (.I0(init_wait_count_reg__0[3]),
        .I1(init_wait_count_reg__0[2]),
        .I2(init_wait_count_reg__0[1]),
        .I3(init_wait_count_reg__0[0]),
        .O(p_0_in__1[3]));
  (* SOFT_HLUTNM = "soft_lutpair39" *) 
  LUT5 #(
    .INIT(32'h6AAAAAAA)) 
    \init_wait_count[4]_i_1__0 
       (.I0(init_wait_count_reg__0[4]),
        .I1(init_wait_count_reg__0[1]),
        .I2(init_wait_count_reg__0[2]),
        .I3(init_wait_count_reg__0[3]),
        .I4(init_wait_count_reg__0[0]),
        .O(p_0_in__1[4]));
  LUT6 #(
    .INIT(64'h7FFFFFFF80000000)) 
    \init_wait_count[5]_i_1__0 
       (.I0(init_wait_count_reg__0[0]),
        .I1(init_wait_count_reg__0[3]),
        .I2(init_wait_count_reg__0[2]),
        .I3(init_wait_count_reg__0[1]),
        .I4(init_wait_count_reg__0[4]),
        .I5(init_wait_count_reg__0[5]),
        .O(p_0_in__1[5]));
  LUT5 #(
    .INIT(32'hFFFFEFFF)) 
    \init_wait_count[6]_i_1__0 
       (.I0(\init_wait_count[6]_i_3__0_n_0 ),
        .I1(init_wait_count_reg__0[4]),
        .I2(init_wait_count_reg__0[6]),
        .I3(init_wait_count_reg__0[5]),
        .I4(init_wait_count_reg__0[0]),
        .O(init_wait_count));
  (* SOFT_HLUTNM = "soft_lutpair38" *) 
  LUT5 #(
    .INIT(32'hF7FF0800)) 
    \init_wait_count[6]_i_2__0 
       (.I0(init_wait_count_reg__0[5]),
        .I1(init_wait_count_reg__0[4]),
        .I2(\init_wait_count[6]_i_3__0_n_0 ),
        .I3(init_wait_count_reg__0[0]),
        .I4(init_wait_count_reg__0[6]),
        .O(p_0_in__1[6]));
  LUT3 #(
    .INIT(8'h7F)) 
    \init_wait_count[6]_i_3__0 
       (.I0(init_wait_count_reg__0[1]),
        .I1(init_wait_count_reg__0[2]),
        .I2(init_wait_count_reg__0[3]),
        .O(\init_wait_count[6]_i_3__0_n_0 ));
  FDCE #(
    .INIT(1'b0)) 
    \init_wait_count_reg[0] 
       (.C(independent_clock_bufg),
        .CE(init_wait_count),
        .CLR(pma_reset),
        .D(\init_wait_count[0]_i_1__0_n_0 ),
        .Q(init_wait_count_reg__0[0]));
  FDCE #(
    .INIT(1'b0)) 
    \init_wait_count_reg[1] 
       (.C(independent_clock_bufg),
        .CE(init_wait_count),
        .CLR(pma_reset),
        .D(p_0_in__1[1]),
        .Q(init_wait_count_reg__0[1]));
  FDCE #(
    .INIT(1'b0)) 
    \init_wait_count_reg[2] 
       (.C(independent_clock_bufg),
        .CE(init_wait_count),
        .CLR(pma_reset),
        .D(p_0_in__1[2]),
        .Q(init_wait_count_reg__0[2]));
  FDCE #(
    .INIT(1'b0)) 
    \init_wait_count_reg[3] 
       (.C(independent_clock_bufg),
        .CE(init_wait_count),
        .CLR(pma_reset),
        .D(p_0_in__1[3]),
        .Q(init_wait_count_reg__0[3]));
  FDCE #(
    .INIT(1'b0)) 
    \init_wait_count_reg[4] 
       (.C(independent_clock_bufg),
        .CE(init_wait_count),
        .CLR(pma_reset),
        .D(p_0_in__1[4]),
        .Q(init_wait_count_reg__0[4]));
  FDCE #(
    .INIT(1'b0)) 
    \init_wait_count_reg[5] 
       (.C(independent_clock_bufg),
        .CE(init_wait_count),
        .CLR(pma_reset),
        .D(p_0_in__1[5]),
        .Q(init_wait_count_reg__0[5]));
  FDCE #(
    .INIT(1'b0)) 
    \init_wait_count_reg[6] 
       (.C(independent_clock_bufg),
        .CE(init_wait_count),
        .CLR(pma_reset),
        .D(p_0_in__1[6]),
        .Q(init_wait_count_reg__0[6]));
  LUT6 #(
    .INIT(64'hFFFFFFFF01000000)) 
    init_wait_done_i_1__0
       (.I0(\init_wait_count[6]_i_3__0_n_0 ),
        .I1(init_wait_count_reg__0[4]),
        .I2(init_wait_count_reg__0[0]),
        .I3(init_wait_count_reg__0[6]),
        .I4(init_wait_count_reg__0[5]),
        .I5(init_wait_done_reg_n_0),
        .O(init_wait_done_i_1__0_n_0));
  FDCE #(
    .INIT(1'b0)) 
    init_wait_done_reg
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .CLR(pma_reset),
        .D(init_wait_done_i_1__0_n_0),
        .Q(init_wait_done_reg_n_0));
  LUT1 #(
    .INIT(2'h1)) 
    \mmcm_lock_count[0]_i_1__0 
       (.I0(mmcm_lock_count_reg__0[0]),
        .O(p_0_in__2[0]));
  (* SOFT_HLUTNM = "soft_lutpair44" *) 
  LUT2 #(
    .INIT(4'h6)) 
    \mmcm_lock_count[1]_i_1__0 
       (.I0(mmcm_lock_count_reg__0[0]),
        .I1(mmcm_lock_count_reg__0[1]),
        .O(p_0_in__2[1]));
  (* SOFT_HLUTNM = "soft_lutpair42" *) 
  LUT3 #(
    .INIT(8'h6A)) 
    \mmcm_lock_count[2]_i_1__0 
       (.I0(mmcm_lock_count_reg__0[2]),
        .I1(mmcm_lock_count_reg__0[1]),
        .I2(mmcm_lock_count_reg__0[0]),
        .O(p_0_in__2[2]));
  (* SOFT_HLUTNM = "soft_lutpair42" *) 
  LUT4 #(
    .INIT(16'h6AAA)) 
    \mmcm_lock_count[3]_i_1__0 
       (.I0(mmcm_lock_count_reg__0[3]),
        .I1(mmcm_lock_count_reg__0[0]),
        .I2(mmcm_lock_count_reg__0[1]),
        .I3(mmcm_lock_count_reg__0[2]),
        .O(p_0_in__2[3]));
  (* SOFT_HLUTNM = "soft_lutpair40" *) 
  LUT5 #(
    .INIT(32'h6AAAAAAA)) 
    \mmcm_lock_count[4]_i_1__0 
       (.I0(mmcm_lock_count_reg__0[4]),
        .I1(mmcm_lock_count_reg__0[3]),
        .I2(mmcm_lock_count_reg__0[0]),
        .I3(mmcm_lock_count_reg__0[1]),
        .I4(mmcm_lock_count_reg__0[2]),
        .O(p_0_in__2[4]));
  LUT6 #(
    .INIT(64'h6AAAAAAAAAAAAAAA)) 
    \mmcm_lock_count[5]_i_1__0 
       (.I0(mmcm_lock_count_reg__0[5]),
        .I1(mmcm_lock_count_reg__0[2]),
        .I2(mmcm_lock_count_reg__0[1]),
        .I3(mmcm_lock_count_reg__0[0]),
        .I4(mmcm_lock_count_reg__0[3]),
        .I5(mmcm_lock_count_reg__0[4]),
        .O(p_0_in__2[5]));
  LUT5 #(
    .INIT(32'h7FFF8000)) 
    \mmcm_lock_count[6]_i_1__0 
       (.I0(mmcm_lock_count_reg__0[4]),
        .I1(mmcm_lock_count_reg__0[3]),
        .I2(\mmcm_lock_count[7]_i_4__0_n_0 ),
        .I3(mmcm_lock_count_reg__0[5]),
        .I4(mmcm_lock_count_reg__0[6]),
        .O(p_0_in__2[6]));
  LUT6 #(
    .INIT(64'h7FFFFFFFFFFFFFFF)) 
    \mmcm_lock_count[7]_i_2__0 
       (.I0(mmcm_lock_count_reg__0[4]),
        .I1(mmcm_lock_count_reg__0[3]),
        .I2(\mmcm_lock_count[7]_i_4__0_n_0 ),
        .I3(mmcm_lock_count_reg__0[5]),
        .I4(mmcm_lock_count_reg__0[6]),
        .I5(mmcm_lock_count_reg__0[7]),
        .O(\mmcm_lock_count[7]_i_2__0_n_0 ));
  LUT6 #(
    .INIT(64'h7FFFFFFF80000000)) 
    \mmcm_lock_count[7]_i_3__0 
       (.I0(mmcm_lock_count_reg__0[6]),
        .I1(mmcm_lock_count_reg__0[5]),
        .I2(\mmcm_lock_count[7]_i_4__0_n_0 ),
        .I3(mmcm_lock_count_reg__0[3]),
        .I4(mmcm_lock_count_reg__0[4]),
        .I5(mmcm_lock_count_reg__0[7]),
        .O(p_0_in__2[7]));
  (* SOFT_HLUTNM = "soft_lutpair44" *) 
  LUT3 #(
    .INIT(8'h80)) 
    \mmcm_lock_count[7]_i_4__0 
       (.I0(mmcm_lock_count_reg__0[2]),
        .I1(mmcm_lock_count_reg__0[1]),
        .I2(mmcm_lock_count_reg__0[0]),
        .O(\mmcm_lock_count[7]_i_4__0_n_0 ));
  FDRE #(
    .INIT(1'b0)) 
    \mmcm_lock_count_reg[0] 
       (.C(independent_clock_bufg),
        .CE(\mmcm_lock_count[7]_i_2__0_n_0 ),
        .D(p_0_in__2[0]),
        .Q(mmcm_lock_count_reg__0[0]),
        .R(sync_mmcm_lock_reclocked_n_0));
  FDRE #(
    .INIT(1'b0)) 
    \mmcm_lock_count_reg[1] 
       (.C(independent_clock_bufg),
        .CE(\mmcm_lock_count[7]_i_2__0_n_0 ),
        .D(p_0_in__2[1]),
        .Q(mmcm_lock_count_reg__0[1]),
        .R(sync_mmcm_lock_reclocked_n_0));
  FDRE #(
    .INIT(1'b0)) 
    \mmcm_lock_count_reg[2] 
       (.C(independent_clock_bufg),
        .CE(\mmcm_lock_count[7]_i_2__0_n_0 ),
        .D(p_0_in__2[2]),
        .Q(mmcm_lock_count_reg__0[2]),
        .R(sync_mmcm_lock_reclocked_n_0));
  FDRE #(
    .INIT(1'b0)) 
    \mmcm_lock_count_reg[3] 
       (.C(independent_clock_bufg),
        .CE(\mmcm_lock_count[7]_i_2__0_n_0 ),
        .D(p_0_in__2[3]),
        .Q(mmcm_lock_count_reg__0[3]),
        .R(sync_mmcm_lock_reclocked_n_0));
  FDRE #(
    .INIT(1'b0)) 
    \mmcm_lock_count_reg[4] 
       (.C(independent_clock_bufg),
        .CE(\mmcm_lock_count[7]_i_2__0_n_0 ),
        .D(p_0_in__2[4]),
        .Q(mmcm_lock_count_reg__0[4]),
        .R(sync_mmcm_lock_reclocked_n_0));
  FDRE #(
    .INIT(1'b0)) 
    \mmcm_lock_count_reg[5] 
       (.C(independent_clock_bufg),
        .CE(\mmcm_lock_count[7]_i_2__0_n_0 ),
        .D(p_0_in__2[5]),
        .Q(mmcm_lock_count_reg__0[5]),
        .R(sync_mmcm_lock_reclocked_n_0));
  FDRE #(
    .INIT(1'b0)) 
    \mmcm_lock_count_reg[6] 
       (.C(independent_clock_bufg),
        .CE(\mmcm_lock_count[7]_i_2__0_n_0 ),
        .D(p_0_in__2[6]),
        .Q(mmcm_lock_count_reg__0[6]),
        .R(sync_mmcm_lock_reclocked_n_0));
  FDRE #(
    .INIT(1'b0)) 
    \mmcm_lock_count_reg[7] 
       (.C(independent_clock_bufg),
        .CE(\mmcm_lock_count[7]_i_2__0_n_0 ),
        .D(p_0_in__2[7]),
        .Q(mmcm_lock_count_reg__0[7]),
        .R(sync_mmcm_lock_reclocked_n_0));
  (* SOFT_HLUTNM = "soft_lutpair40" *) 
  LUT5 #(
    .INIT(32'h80000000)) 
    mmcm_lock_reclocked_i_2__0
       (.I0(mmcm_lock_count_reg__0[4]),
        .I1(mmcm_lock_count_reg__0[3]),
        .I2(mmcm_lock_count_reg__0[0]),
        .I3(mmcm_lock_count_reg__0[1]),
        .I4(mmcm_lock_count_reg__0[2]),
        .O(mmcm_lock_reclocked_i_2__0_n_0));
  FDRE #(
    .INIT(1'b0)) 
    mmcm_lock_reclocked_reg
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(sync_mmcm_lock_reclocked_n_1),
        .Q(mmcm_lock_reclocked),
        .R(1'b0));
  LUT6 #(
    .INIT(64'h707F7070707F7F7F)) 
    reset_time_out_i_2__0
       (.I0(rxresetdone_s3),
        .I1(rx_state[2]),
        .I2(rx_state[1]),
        .I3(mmcm_lock_reclocked),
        .I4(rx_state[0]),
        .I5(gt0_rx_cdrlocked),
        .O(reset_time_out_i_2__0_n_0));
  LUT5 #(
    .INIT(32'h030FCCEC)) 
    reset_time_out_i_4__0
       (.I0(gt0_rx_cdrlocked),
        .I1(rx_state[0]),
        .I2(rx_state[2]),
        .I3(rx_state[1]),
        .I4(rx_state[3]),
        .O(reset_time_out_i_4__0_n_0));
  FDSE #(
    .INIT(1'b0)) 
    reset_time_out_reg
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(sync_data_valid_n_0),
        .Q(reset_time_out_reg_n_0),
        .S(pma_reset));
  LUT5 #(
    .INIT(32'hFFFD0010)) 
    run_phase_alignment_int_i_1__0
       (.I0(rx_state[0]),
        .I1(rx_state[2]),
        .I2(rx_state[3]),
        .I3(rx_state[1]),
        .I4(run_phase_alignment_int_reg_n_0),
        .O(run_phase_alignment_int_i_1__0_n_0));
  FDRE #(
    .INIT(1'b0)) 
    run_phase_alignment_int_reg
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(run_phase_alignment_int_i_1__0_n_0),
        .Q(run_phase_alignment_int_reg_n_0),
        .R(pma_reset));
  FDRE #(
    .INIT(1'b0)) 
    run_phase_alignment_int_s3_reg
       (.C(userclk),
        .CE(1'b1),
        .D(run_phase_alignment_int_s2),
        .Q(run_phase_alignment_int_s3_reg_n_0),
        .R(1'b0));
  LUT3 #(
    .INIT(8'h02)) 
    rx_fsm_reset_done_int_i_5
       (.I0(rx_state[3]),
        .I1(rx_state[2]),
        .I2(rx_state[0]),
        .O(rx_fsm_reset_done_int_i_5_n_0));
  FDRE #(
    .INIT(1'b0)) 
    rx_fsm_reset_done_int_reg
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(sync_data_valid_n_1),
        .Q(data_in),
        .R(pma_reset));
  FDRE #(
    .INIT(1'b0)) 
    rx_fsm_reset_done_int_s3_reg
       (.C(userclk),
        .CE(1'b1),
        .D(rx_fsm_reset_done_int_s2),
        .Q(rx_fsm_reset_done_int_s3),
        .R(1'b0));
  FDRE #(
    .INIT(1'b0)) 
    rxresetdone_s3_reg
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(rxresetdone_s2),
        .Q(rxresetdone_s3),
        .R(1'b0));
  GigEthGth7Core_GigEthGth7Core_sync_block_14 sync_RXRESETDONE
       (.\cpllpd_wait_reg[95] (\cpllpd_wait_reg[95] ),
        .data_out(rxresetdone_s2),
        .independent_clock_bufg(independent_clock_bufg));
  GigEthGth7Core_GigEthGth7Core_sync_block_15 sync_cplllock
       (.E(sync_cplllock_n_0),
        .\FSM_sequential_rx_state_reg[0] (sync_data_valid_n_5),
        .cplllock(cplllock),
        .data_out(cplllock_sync),
        .independent_clock_bufg(independent_clock_bufg),
        .init_wait_done_reg(\FSM_sequential_rx_state[3]_i_3_n_0 ),
        .out(rx_state),
        .time_out_2ms(time_out_2ms),
        .time_out_2ms_reg(\FSM_sequential_rx_state[3]_i_8_n_0 ));
  GigEthGth7Core_GigEthGth7Core_sync_block_16 sync_data_valid
       (.D({sync_data_valid_n_2,sync_data_valid_n_3,sync_data_valid_n_4}),
        .\FSM_sequential_rx_state_reg[0] (sync_data_valid_n_5),
        .\FSM_sequential_rx_state_reg[0]_0 (\FSM_sequential_rx_state[0]_i_2_n_0 ),
        .\FSM_sequential_rx_state_reg[3] (\FSM_sequential_rx_state[3]_i_6_n_0 ),
        .\FSM_sequential_rx_state_reg[3]_0 (rx_fsm_reset_done_int_i_5_n_0),
        .cplllock_sync(cplllock_sync),
        .data_in(data_in),
        .data_out(data_out),
        .gt0_rx_cdrlocked_reg(reset_time_out_i_4__0_n_0),
        .independent_clock_bufg(independent_clock_bufg),
        .out(rx_state),
        .reset_time_out_reg(sync_data_valid_n_0),
        .reset_time_out_reg_0(reset_time_out_reg_n_0),
        .rx_fsm_reset_done_int_reg(sync_data_valid_n_1),
        .rx_state15_out(rx_state15_out),
        .rxresetdone_s3_reg(reset_time_out_i_2__0_n_0),
        .time_out_100us(time_out_100us),
        .time_out_100us_reg(\FSM_sequential_rx_state[3]_i_9_n_0 ),
        .time_out_1us(time_out_1us),
        .time_out_2ms(time_out_2ms),
        .time_out_wait_bypass_s3(time_out_wait_bypass_s3));
  GigEthGth7Core_GigEthGth7Core_sync_block_17 sync_mmcm_lock_reclocked
       (.Q(mmcm_lock_count_reg__0[7:5]),
        .SR(sync_mmcm_lock_reclocked_n_0),
        .independent_clock_bufg(independent_clock_bufg),
        .\mmcm_lock_count_reg[4] (mmcm_lock_reclocked_i_2__0_n_0),
        .mmcm_lock_reclocked(mmcm_lock_reclocked),
        .mmcm_lock_reclocked_reg(sync_mmcm_lock_reclocked_n_1),
        .mmcm_locked(mmcm_locked));
  GigEthGth7Core_GigEthGth7Core_sync_block_18 sync_run_phase_alignment_int
       (.data_in(run_phase_alignment_int_reg_n_0),
        .data_out(run_phase_alignment_int_s2),
        .userclk(userclk));
  GigEthGth7Core_GigEthGth7Core_sync_block_19 sync_rx_fsm_reset_done_int
       (.data_in(data_in),
        .data_out(rx_fsm_reset_done_int_s2),
        .userclk(userclk));
  GigEthGth7Core_GigEthGth7Core_sync_block_20 sync_time_out_wait_bypass
       (.data_in(time_out_wait_bypass_reg_n_0),
        .data_out(time_out_wait_bypass_s2),
        .independent_clock_bufg(independent_clock_bufg));
  (* SOFT_HLUTNM = "soft_lutpair47" *) 
  LUT2 #(
    .INIT(4'hE)) 
    time_out_100us_i_1
       (.I0(time_out_100us_reg_i_2_n_1),
        .I1(time_out_100us),
        .O(time_out_100us_i_1_n_0));
  LUT3 #(
    .INIT(8'h01)) 
    time_out_100us_i_10
       (.I0(time_out_counter_reg[1]),
        .I1(time_out_counter_reg[0]),
        .I2(time_out_counter_reg[2]),
        .O(time_out_100us_i_10_n_0));
  LUT2 #(
    .INIT(4'h1)) 
    time_out_100us_i_4
       (.I0(time_out_counter_reg[18]),
        .I1(time_out_counter_reg[19]),
        .O(time_out_100us_i_4_n_0));
  LUT3 #(
    .INIT(8'h01)) 
    time_out_100us_i_5
       (.I0(time_out_counter_reg[17]),
        .I1(time_out_counter_reg[16]),
        .I2(time_out_counter_reg[15]),
        .O(time_out_100us_i_5_n_0));
  LUT3 #(
    .INIT(8'h02)) 
    time_out_100us_i_6
       (.I0(time_out_counter_reg[14]),
        .I1(time_out_counter_reg[13]),
        .I2(time_out_counter_reg[12]),
        .O(time_out_100us_i_6_n_0));
  LUT3 #(
    .INIT(8'h80)) 
    time_out_100us_i_7
       (.I0(time_out_counter_reg[11]),
        .I1(time_out_counter_reg[10]),
        .I2(time_out_counter_reg[9]),
        .O(time_out_100us_i_7_n_0));
  LUT3 #(
    .INIT(8'h01)) 
    time_out_100us_i_8
       (.I0(time_out_counter_reg[6]),
        .I1(time_out_counter_reg[7]),
        .I2(time_out_counter_reg[8]),
        .O(time_out_100us_i_8_n_0));
  LUT3 #(
    .INIT(8'h04)) 
    time_out_100us_i_9
       (.I0(time_out_counter_reg[4]),
        .I1(time_out_counter_reg[5]),
        .I2(time_out_counter_reg[3]),
        .O(time_out_100us_i_9_n_0));
  FDRE #(
    .INIT(1'b0)) 
    time_out_100us_reg
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(time_out_100us_i_1_n_0),
        .Q(time_out_100us),
        .R(reset_time_out_reg_n_0));
  CARRY4 time_out_100us_reg_i_2
       (.CI(time_out_100us_reg_i_3_n_0),
        .CO({NLW_time_out_100us_reg_i_2_CO_UNCONNECTED[3],time_out_100us_reg_i_2_n_1,time_out_100us_reg_i_2_n_2,time_out_100us_reg_i_2_n_3}),
        .CYINIT(1'b0),
        .DI({1'b0,1'b0,1'b0,1'b0}),
        .O(NLW_time_out_100us_reg_i_2_O_UNCONNECTED[3:0]),
        .S({1'b0,time_out_100us_i_4_n_0,time_out_100us_i_5_n_0,time_out_100us_i_6_n_0}));
  CARRY4 time_out_100us_reg_i_3
       (.CI(1'b0),
        .CO({time_out_100us_reg_i_3_n_0,time_out_100us_reg_i_3_n_1,time_out_100us_reg_i_3_n_2,time_out_100us_reg_i_3_n_3}),
        .CYINIT(1'b1),
        .DI({1'b0,1'b0,1'b0,1'b0}),
        .O(NLW_time_out_100us_reg_i_3_O_UNCONNECTED[3:0]),
        .S({time_out_100us_i_7_n_0,time_out_100us_i_8_n_0,time_out_100us_i_9_n_0,time_out_100us_i_10_n_0}));
  LUT2 #(
    .INIT(4'hE)) 
    time_out_1us_i_1
       (.I0(time_out_1us_reg_i_2_n_1),
        .I1(time_out_1us),
        .O(time_out_1us_i_1_n_0));
  LUT3 #(
    .INIT(8'h01)) 
    time_out_1us_i_10
       (.I0(time_out_counter_reg[1]),
        .I1(time_out_counter_reg[0]),
        .I2(time_out_counter_reg[2]),
        .O(time_out_1us_i_10_n_0));
  LUT2 #(
    .INIT(4'h1)) 
    time_out_1us_i_4
       (.I0(time_out_counter_reg[18]),
        .I1(time_out_counter_reg[19]),
        .O(time_out_1us_i_4_n_0));
  LUT3 #(
    .INIT(8'h01)) 
    time_out_1us_i_5
       (.I0(time_out_counter_reg[17]),
        .I1(time_out_counter_reg[16]),
        .I2(time_out_counter_reg[15]),
        .O(time_out_1us_i_5_n_0));
  LUT3 #(
    .INIT(8'h01)) 
    time_out_1us_i_6
       (.I0(time_out_counter_reg[13]),
        .I1(time_out_counter_reg[12]),
        .I2(time_out_counter_reg[14]),
        .O(time_out_1us_i_6_n_0));
  LUT3 #(
    .INIT(8'h01)) 
    time_out_1us_i_7
       (.I0(time_out_counter_reg[11]),
        .I1(time_out_counter_reg[10]),
        .I2(time_out_counter_reg[9]),
        .O(time_out_1us_i_7_n_0));
  LUT3 #(
    .INIT(8'h40)) 
    time_out_1us_i_8
       (.I0(time_out_counter_reg[8]),
        .I1(time_out_counter_reg[7]),
        .I2(time_out_counter_reg[6]),
        .O(time_out_1us_i_8_n_0));
  LUT3 #(
    .INIT(8'h10)) 
    time_out_1us_i_9
       (.I0(time_out_counter_reg[5]),
        .I1(time_out_counter_reg[4]),
        .I2(time_out_counter_reg[3]),
        .O(time_out_1us_i_9_n_0));
  FDRE #(
    .INIT(1'b0)) 
    time_out_1us_reg
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(time_out_1us_i_1_n_0),
        .Q(time_out_1us),
        .R(reset_time_out_reg_n_0));
  CARRY4 time_out_1us_reg_i_2
       (.CI(time_out_1us_reg_i_3_n_0),
        .CO({NLW_time_out_1us_reg_i_2_CO_UNCONNECTED[3],time_out_1us_reg_i_2_n_1,time_out_1us_reg_i_2_n_2,time_out_1us_reg_i_2_n_3}),
        .CYINIT(1'b0),
        .DI({1'b0,1'b0,1'b0,1'b0}),
        .O(NLW_time_out_1us_reg_i_2_O_UNCONNECTED[3:0]),
        .S({1'b0,time_out_1us_i_4_n_0,time_out_1us_i_5_n_0,time_out_1us_i_6_n_0}));
  CARRY4 time_out_1us_reg_i_3
       (.CI(1'b0),
        .CO({time_out_1us_reg_i_3_n_0,time_out_1us_reg_i_3_n_1,time_out_1us_reg_i_3_n_2,time_out_1us_reg_i_3_n_3}),
        .CYINIT(1'b1),
        .DI({1'b0,1'b0,1'b0,1'b0}),
        .O(NLW_time_out_1us_reg_i_3_O_UNCONNECTED[3:0]),
        .S({time_out_1us_i_7_n_0,time_out_1us_i_8_n_0,time_out_1us_i_9_n_0,time_out_1us_i_10_n_0}));
  LUT2 #(
    .INIT(4'hE)) 
    time_out_2ms_i_1__0
       (.I0(\time_out_counter_reg[0]_i_3__0_n_1 ),
        .I1(time_out_2ms),
        .O(time_out_2ms_i_1__0_n_0));
  FDRE #(
    .INIT(1'b0)) 
    time_out_2ms_reg
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(time_out_2ms_i_1__0_n_0),
        .Q(time_out_2ms),
        .R(reset_time_out_reg_n_0));
  LUT3 #(
    .INIT(8'h04)) 
    \time_out_counter[0]_i_10__0 
       (.I0(time_out_counter_reg[17]),
        .I1(time_out_counter_reg[16]),
        .I2(time_out_counter_reg[15]),
        .O(\time_out_counter[0]_i_10__0_n_0 ));
  LUT3 #(
    .INIT(8'h04)) 
    \time_out_counter[0]_i_11__0 
       (.I0(time_out_counter_reg[14]),
        .I1(time_out_counter_reg[13]),
        .I2(time_out_counter_reg[12]),
        .O(\time_out_counter[0]_i_11__0_n_0 ));
  LUT3 #(
    .INIT(8'h40)) 
    \time_out_counter[0]_i_12__0 
       (.I0(time_out_counter_reg[11]),
        .I1(time_out_counter_reg[10]),
        .I2(time_out_counter_reg[9]),
        .O(\time_out_counter[0]_i_12__0_n_0 ));
  LUT3 #(
    .INIT(8'h80)) 
    \time_out_counter[0]_i_13 
       (.I0(time_out_counter_reg[8]),
        .I1(time_out_counter_reg[7]),
        .I2(time_out_counter_reg[6]),
        .O(\time_out_counter[0]_i_13_n_0 ));
  LUT3 #(
    .INIT(8'h01)) 
    \time_out_counter[0]_i_14__0 
       (.I0(time_out_counter_reg[5]),
        .I1(time_out_counter_reg[4]),
        .I2(time_out_counter_reg[3]),
        .O(\time_out_counter[0]_i_14__0_n_0 ));
  LUT3 #(
    .INIT(8'h01)) 
    \time_out_counter[0]_i_15__0 
       (.I0(time_out_counter_reg[1]),
        .I1(time_out_counter_reg[0]),
        .I2(time_out_counter_reg[2]),
        .O(\time_out_counter[0]_i_15__0_n_0 ));
  LUT1 #(
    .INIT(2'h1)) 
    \time_out_counter[0]_i_1__0 
       (.I0(\time_out_counter_reg[0]_i_3__0_n_1 ),
        .O(\time_out_counter[0]_i_1__0_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \time_out_counter[0]_i_4__0 
       (.I0(time_out_counter_reg[3]),
        .O(\time_out_counter[0]_i_4__0_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \time_out_counter[0]_i_5__0 
       (.I0(time_out_counter_reg[2]),
        .O(\time_out_counter[0]_i_5__0_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \time_out_counter[0]_i_6__0 
       (.I0(time_out_counter_reg[1]),
        .O(\time_out_counter[0]_i_6__0_n_0 ));
  LUT1 #(
    .INIT(2'h1)) 
    \time_out_counter[0]_i_7 
       (.I0(time_out_counter_reg[0]),
        .O(\time_out_counter[0]_i_7_n_0 ));
  LUT2 #(
    .INIT(4'h2)) 
    \time_out_counter[0]_i_9 
       (.I0(time_out_counter_reg[19]),
        .I1(time_out_counter_reg[18]),
        .O(\time_out_counter[0]_i_9_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \time_out_counter[12]_i_2__0 
       (.I0(time_out_counter_reg[15]),
        .O(\time_out_counter[12]_i_2__0_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \time_out_counter[12]_i_3__0 
       (.I0(time_out_counter_reg[14]),
        .O(\time_out_counter[12]_i_3__0_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \time_out_counter[12]_i_4__0 
       (.I0(time_out_counter_reg[13]),
        .O(\time_out_counter[12]_i_4__0_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \time_out_counter[12]_i_5__0 
       (.I0(time_out_counter_reg[12]),
        .O(\time_out_counter[12]_i_5__0_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \time_out_counter[16]_i_2__0 
       (.I0(time_out_counter_reg[19]),
        .O(\time_out_counter[16]_i_2__0_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \time_out_counter[16]_i_3__0 
       (.I0(time_out_counter_reg[18]),
        .O(\time_out_counter[16]_i_3__0_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \time_out_counter[16]_i_4__0 
       (.I0(time_out_counter_reg[17]),
        .O(\time_out_counter[16]_i_4__0_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \time_out_counter[16]_i_5 
       (.I0(time_out_counter_reg[16]),
        .O(\time_out_counter[16]_i_5_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \time_out_counter[4]_i_2__0 
       (.I0(time_out_counter_reg[7]),
        .O(\time_out_counter[4]_i_2__0_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \time_out_counter[4]_i_3__0 
       (.I0(time_out_counter_reg[6]),
        .O(\time_out_counter[4]_i_3__0_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \time_out_counter[4]_i_4__0 
       (.I0(time_out_counter_reg[5]),
        .O(\time_out_counter[4]_i_4__0_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \time_out_counter[4]_i_5__0 
       (.I0(time_out_counter_reg[4]),
        .O(\time_out_counter[4]_i_5__0_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \time_out_counter[8]_i_2__0 
       (.I0(time_out_counter_reg[11]),
        .O(\time_out_counter[8]_i_2__0_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \time_out_counter[8]_i_3__0 
       (.I0(time_out_counter_reg[10]),
        .O(\time_out_counter[8]_i_3__0_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \time_out_counter[8]_i_4__0 
       (.I0(time_out_counter_reg[9]),
        .O(\time_out_counter[8]_i_4__0_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \time_out_counter[8]_i_5__0 
       (.I0(time_out_counter_reg[8]),
        .O(\time_out_counter[8]_i_5__0_n_0 ));
  FDRE #(
    .INIT(1'b0)) 
    \time_out_counter_reg[0] 
       (.C(independent_clock_bufg),
        .CE(\time_out_counter[0]_i_1__0_n_0 ),
        .D(\time_out_counter_reg[0]_i_2__0_n_7 ),
        .Q(time_out_counter_reg[0]),
        .R(reset_time_out_reg_n_0));
  CARRY4 \time_out_counter_reg[0]_i_2__0 
       (.CI(1'b0),
        .CO({\time_out_counter_reg[0]_i_2__0_n_0 ,\time_out_counter_reg[0]_i_2__0_n_1 ,\time_out_counter_reg[0]_i_2__0_n_2 ,\time_out_counter_reg[0]_i_2__0_n_3 }),
        .CYINIT(1'b0),
        .DI({1'b0,1'b0,1'b0,1'b1}),
        .O({\time_out_counter_reg[0]_i_2__0_n_4 ,\time_out_counter_reg[0]_i_2__0_n_5 ,\time_out_counter_reg[0]_i_2__0_n_6 ,\time_out_counter_reg[0]_i_2__0_n_7 }),
        .S({\time_out_counter[0]_i_4__0_n_0 ,\time_out_counter[0]_i_5__0_n_0 ,\time_out_counter[0]_i_6__0_n_0 ,\time_out_counter[0]_i_7_n_0 }));
  CARRY4 \time_out_counter_reg[0]_i_3__0 
       (.CI(\time_out_counter_reg[0]_i_8__0_n_0 ),
        .CO({\NLW_time_out_counter_reg[0]_i_3__0_CO_UNCONNECTED [3],\time_out_counter_reg[0]_i_3__0_n_1 ,\time_out_counter_reg[0]_i_3__0_n_2 ,\time_out_counter_reg[0]_i_3__0_n_3 }),
        .CYINIT(1'b0),
        .DI({1'b0,1'b0,1'b0,1'b0}),
        .O(\NLW_time_out_counter_reg[0]_i_3__0_O_UNCONNECTED [3:0]),
        .S({1'b0,\time_out_counter[0]_i_9_n_0 ,\time_out_counter[0]_i_10__0_n_0 ,\time_out_counter[0]_i_11__0_n_0 }));
  CARRY4 \time_out_counter_reg[0]_i_8__0 
       (.CI(1'b0),
        .CO({\time_out_counter_reg[0]_i_8__0_n_0 ,\time_out_counter_reg[0]_i_8__0_n_1 ,\time_out_counter_reg[0]_i_8__0_n_2 ,\time_out_counter_reg[0]_i_8__0_n_3 }),
        .CYINIT(1'b1),
        .DI({1'b0,1'b0,1'b0,1'b0}),
        .O(\NLW_time_out_counter_reg[0]_i_8__0_O_UNCONNECTED [3:0]),
        .S({\time_out_counter[0]_i_12__0_n_0 ,\time_out_counter[0]_i_13_n_0 ,\time_out_counter[0]_i_14__0_n_0 ,\time_out_counter[0]_i_15__0_n_0 }));
  FDRE #(
    .INIT(1'b0)) 
    \time_out_counter_reg[10] 
       (.C(independent_clock_bufg),
        .CE(\time_out_counter[0]_i_1__0_n_0 ),
        .D(\time_out_counter_reg[8]_i_1__0_n_5 ),
        .Q(time_out_counter_reg[10]),
        .R(reset_time_out_reg_n_0));
  FDRE #(
    .INIT(1'b0)) 
    \time_out_counter_reg[11] 
       (.C(independent_clock_bufg),
        .CE(\time_out_counter[0]_i_1__0_n_0 ),
        .D(\time_out_counter_reg[8]_i_1__0_n_4 ),
        .Q(time_out_counter_reg[11]),
        .R(reset_time_out_reg_n_0));
  FDRE #(
    .INIT(1'b0)) 
    \time_out_counter_reg[12] 
       (.C(independent_clock_bufg),
        .CE(\time_out_counter[0]_i_1__0_n_0 ),
        .D(\time_out_counter_reg[12]_i_1__0_n_7 ),
        .Q(time_out_counter_reg[12]),
        .R(reset_time_out_reg_n_0));
  CARRY4 \time_out_counter_reg[12]_i_1__0 
       (.CI(\time_out_counter_reg[8]_i_1__0_n_0 ),
        .CO({\time_out_counter_reg[12]_i_1__0_n_0 ,\time_out_counter_reg[12]_i_1__0_n_1 ,\time_out_counter_reg[12]_i_1__0_n_2 ,\time_out_counter_reg[12]_i_1__0_n_3 }),
        .CYINIT(1'b0),
        .DI({1'b0,1'b0,1'b0,1'b0}),
        .O({\time_out_counter_reg[12]_i_1__0_n_4 ,\time_out_counter_reg[12]_i_1__0_n_5 ,\time_out_counter_reg[12]_i_1__0_n_6 ,\time_out_counter_reg[12]_i_1__0_n_7 }),
        .S({\time_out_counter[12]_i_2__0_n_0 ,\time_out_counter[12]_i_3__0_n_0 ,\time_out_counter[12]_i_4__0_n_0 ,\time_out_counter[12]_i_5__0_n_0 }));
  FDRE #(
    .INIT(1'b0)) 
    \time_out_counter_reg[13] 
       (.C(independent_clock_bufg),
        .CE(\time_out_counter[0]_i_1__0_n_0 ),
        .D(\time_out_counter_reg[12]_i_1__0_n_6 ),
        .Q(time_out_counter_reg[13]),
        .R(reset_time_out_reg_n_0));
  FDRE #(
    .INIT(1'b0)) 
    \time_out_counter_reg[14] 
       (.C(independent_clock_bufg),
        .CE(\time_out_counter[0]_i_1__0_n_0 ),
        .D(\time_out_counter_reg[12]_i_1__0_n_5 ),
        .Q(time_out_counter_reg[14]),
        .R(reset_time_out_reg_n_0));
  FDRE #(
    .INIT(1'b0)) 
    \time_out_counter_reg[15] 
       (.C(independent_clock_bufg),
        .CE(\time_out_counter[0]_i_1__0_n_0 ),
        .D(\time_out_counter_reg[12]_i_1__0_n_4 ),
        .Q(time_out_counter_reg[15]),
        .R(reset_time_out_reg_n_0));
  FDRE #(
    .INIT(1'b0)) 
    \time_out_counter_reg[16] 
       (.C(independent_clock_bufg),
        .CE(\time_out_counter[0]_i_1__0_n_0 ),
        .D(\time_out_counter_reg[16]_i_1__0_n_7 ),
        .Q(time_out_counter_reg[16]),
        .R(reset_time_out_reg_n_0));
  CARRY4 \time_out_counter_reg[16]_i_1__0 
       (.CI(\time_out_counter_reg[12]_i_1__0_n_0 ),
        .CO({\NLW_time_out_counter_reg[16]_i_1__0_CO_UNCONNECTED [3],\time_out_counter_reg[16]_i_1__0_n_1 ,\time_out_counter_reg[16]_i_1__0_n_2 ,\time_out_counter_reg[16]_i_1__0_n_3 }),
        .CYINIT(1'b0),
        .DI({1'b0,1'b0,1'b0,1'b0}),
        .O({\time_out_counter_reg[16]_i_1__0_n_4 ,\time_out_counter_reg[16]_i_1__0_n_5 ,\time_out_counter_reg[16]_i_1__0_n_6 ,\time_out_counter_reg[16]_i_1__0_n_7 }),
        .S({\time_out_counter[16]_i_2__0_n_0 ,\time_out_counter[16]_i_3__0_n_0 ,\time_out_counter[16]_i_4__0_n_0 ,\time_out_counter[16]_i_5_n_0 }));
  FDRE #(
    .INIT(1'b0)) 
    \time_out_counter_reg[17] 
       (.C(independent_clock_bufg),
        .CE(\time_out_counter[0]_i_1__0_n_0 ),
        .D(\time_out_counter_reg[16]_i_1__0_n_6 ),
        .Q(time_out_counter_reg[17]),
        .R(reset_time_out_reg_n_0));
  FDRE #(
    .INIT(1'b0)) 
    \time_out_counter_reg[18] 
       (.C(independent_clock_bufg),
        .CE(\time_out_counter[0]_i_1__0_n_0 ),
        .D(\time_out_counter_reg[16]_i_1__0_n_5 ),
        .Q(time_out_counter_reg[18]),
        .R(reset_time_out_reg_n_0));
  FDRE #(
    .INIT(1'b0)) 
    \time_out_counter_reg[19] 
       (.C(independent_clock_bufg),
        .CE(\time_out_counter[0]_i_1__0_n_0 ),
        .D(\time_out_counter_reg[16]_i_1__0_n_4 ),
        .Q(time_out_counter_reg[19]),
        .R(reset_time_out_reg_n_0));
  FDRE #(
    .INIT(1'b0)) 
    \time_out_counter_reg[1] 
       (.C(independent_clock_bufg),
        .CE(\time_out_counter[0]_i_1__0_n_0 ),
        .D(\time_out_counter_reg[0]_i_2__0_n_6 ),
        .Q(time_out_counter_reg[1]),
        .R(reset_time_out_reg_n_0));
  FDRE #(
    .INIT(1'b0)) 
    \time_out_counter_reg[2] 
       (.C(independent_clock_bufg),
        .CE(\time_out_counter[0]_i_1__0_n_0 ),
        .D(\time_out_counter_reg[0]_i_2__0_n_5 ),
        .Q(time_out_counter_reg[2]),
        .R(reset_time_out_reg_n_0));
  FDRE #(
    .INIT(1'b0)) 
    \time_out_counter_reg[3] 
       (.C(independent_clock_bufg),
        .CE(\time_out_counter[0]_i_1__0_n_0 ),
        .D(\time_out_counter_reg[0]_i_2__0_n_4 ),
        .Q(time_out_counter_reg[3]),
        .R(reset_time_out_reg_n_0));
  FDRE #(
    .INIT(1'b0)) 
    \time_out_counter_reg[4] 
       (.C(independent_clock_bufg),
        .CE(\time_out_counter[0]_i_1__0_n_0 ),
        .D(\time_out_counter_reg[4]_i_1__0_n_7 ),
        .Q(time_out_counter_reg[4]),
        .R(reset_time_out_reg_n_0));
  CARRY4 \time_out_counter_reg[4]_i_1__0 
       (.CI(\time_out_counter_reg[0]_i_2__0_n_0 ),
        .CO({\time_out_counter_reg[4]_i_1__0_n_0 ,\time_out_counter_reg[4]_i_1__0_n_1 ,\time_out_counter_reg[4]_i_1__0_n_2 ,\time_out_counter_reg[4]_i_1__0_n_3 }),
        .CYINIT(1'b0),
        .DI({1'b0,1'b0,1'b0,1'b0}),
        .O({\time_out_counter_reg[4]_i_1__0_n_4 ,\time_out_counter_reg[4]_i_1__0_n_5 ,\time_out_counter_reg[4]_i_1__0_n_6 ,\time_out_counter_reg[4]_i_1__0_n_7 }),
        .S({\time_out_counter[4]_i_2__0_n_0 ,\time_out_counter[4]_i_3__0_n_0 ,\time_out_counter[4]_i_4__0_n_0 ,\time_out_counter[4]_i_5__0_n_0 }));
  FDRE #(
    .INIT(1'b0)) 
    \time_out_counter_reg[5] 
       (.C(independent_clock_bufg),
        .CE(\time_out_counter[0]_i_1__0_n_0 ),
        .D(\time_out_counter_reg[4]_i_1__0_n_6 ),
        .Q(time_out_counter_reg[5]),
        .R(reset_time_out_reg_n_0));
  FDRE #(
    .INIT(1'b0)) 
    \time_out_counter_reg[6] 
       (.C(independent_clock_bufg),
        .CE(\time_out_counter[0]_i_1__0_n_0 ),
        .D(\time_out_counter_reg[4]_i_1__0_n_5 ),
        .Q(time_out_counter_reg[6]),
        .R(reset_time_out_reg_n_0));
  FDRE #(
    .INIT(1'b0)) 
    \time_out_counter_reg[7] 
       (.C(independent_clock_bufg),
        .CE(\time_out_counter[0]_i_1__0_n_0 ),
        .D(\time_out_counter_reg[4]_i_1__0_n_4 ),
        .Q(time_out_counter_reg[7]),
        .R(reset_time_out_reg_n_0));
  FDRE #(
    .INIT(1'b0)) 
    \time_out_counter_reg[8] 
       (.C(independent_clock_bufg),
        .CE(\time_out_counter[0]_i_1__0_n_0 ),
        .D(\time_out_counter_reg[8]_i_1__0_n_7 ),
        .Q(time_out_counter_reg[8]),
        .R(reset_time_out_reg_n_0));
  CARRY4 \time_out_counter_reg[8]_i_1__0 
       (.CI(\time_out_counter_reg[4]_i_1__0_n_0 ),
        .CO({\time_out_counter_reg[8]_i_1__0_n_0 ,\time_out_counter_reg[8]_i_1__0_n_1 ,\time_out_counter_reg[8]_i_1__0_n_2 ,\time_out_counter_reg[8]_i_1__0_n_3 }),
        .CYINIT(1'b0),
        .DI({1'b0,1'b0,1'b0,1'b0}),
        .O({\time_out_counter_reg[8]_i_1__0_n_4 ,\time_out_counter_reg[8]_i_1__0_n_5 ,\time_out_counter_reg[8]_i_1__0_n_6 ,\time_out_counter_reg[8]_i_1__0_n_7 }),
        .S({\time_out_counter[8]_i_2__0_n_0 ,\time_out_counter[8]_i_3__0_n_0 ,\time_out_counter[8]_i_4__0_n_0 ,\time_out_counter[8]_i_5__0_n_0 }));
  FDRE #(
    .INIT(1'b0)) 
    \time_out_counter_reg[9] 
       (.C(independent_clock_bufg),
        .CE(\time_out_counter[0]_i_1__0_n_0 ),
        .D(\time_out_counter_reg[8]_i_1__0_n_6 ),
        .Q(time_out_counter_reg[9]),
        .R(reset_time_out_reg_n_0));
  LUT4 #(
    .INIT(16'hAE00)) 
    time_out_wait_bypass_i_1__0
       (.I0(time_out_wait_bypass_reg_n_0),
        .I1(wait_bypass_count1),
        .I2(rx_fsm_reset_done_int_s3),
        .I3(run_phase_alignment_int_s3_reg_n_0),
        .O(time_out_wait_bypass_i_1__0_n_0));
  FDRE #(
    .INIT(1'b0)) 
    time_out_wait_bypass_reg
       (.C(userclk),
        .CE(1'b1),
        .D(time_out_wait_bypass_i_1__0_n_0),
        .Q(time_out_wait_bypass_reg_n_0),
        .R(1'b0));
  FDRE #(
    .INIT(1'b0)) 
    time_out_wait_bypass_s3_reg
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(time_out_wait_bypass_s2),
        .Q(time_out_wait_bypass_s3),
        .R(1'b0));
  (* SOFT_HLUTNM = "soft_lutpair43" *) 
  LUT3 #(
    .INIT(8'hF8)) 
    time_tlock_max_i_1
       (.I0(time_tlock_max1),
        .I1(check_tlock_max_reg_n_0),
        .I2(time_tlock_max),
        .O(time_tlock_max_i_1_n_0));
  LUT2 #(
    .INIT(4'h8)) 
    time_tlock_max_i_10
       (.I0(time_out_counter_reg[8]),
        .I1(time_out_counter_reg[9]),
        .O(time_tlock_max_i_10_n_0));
  LUT2 #(
    .INIT(4'h2)) 
    time_tlock_max_i_11
       (.I0(time_out_counter_reg[14]),
        .I1(time_out_counter_reg[15]),
        .O(time_tlock_max_i_11_n_0));
  LUT2 #(
    .INIT(4'h1)) 
    time_tlock_max_i_12
       (.I0(time_out_counter_reg[13]),
        .I1(time_out_counter_reg[12]),
        .O(time_tlock_max_i_12_n_0));
  LUT2 #(
    .INIT(4'h8)) 
    time_tlock_max_i_13
       (.I0(time_out_counter_reg[10]),
        .I1(time_out_counter_reg[11]),
        .O(time_tlock_max_i_13_n_0));
  LUT2 #(
    .INIT(4'h2)) 
    time_tlock_max_i_14
       (.I0(time_out_counter_reg[9]),
        .I1(time_out_counter_reg[8]),
        .O(time_tlock_max_i_14_n_0));
  LUT2 #(
    .INIT(4'hE)) 
    time_tlock_max_i_15
       (.I0(time_out_counter_reg[7]),
        .I1(time_out_counter_reg[6]),
        .O(time_tlock_max_i_15_n_0));
  LUT2 #(
    .INIT(4'h8)) 
    time_tlock_max_i_16
       (.I0(time_out_counter_reg[5]),
        .I1(time_out_counter_reg[4]),
        .O(time_tlock_max_i_16_n_0));
  LUT2 #(
    .INIT(4'hE)) 
    time_tlock_max_i_17
       (.I0(time_out_counter_reg[2]),
        .I1(time_out_counter_reg[3]),
        .O(time_tlock_max_i_17_n_0));
  LUT2 #(
    .INIT(4'hE)) 
    time_tlock_max_i_18
       (.I0(time_out_counter_reg[0]),
        .I1(time_out_counter_reg[1]),
        .O(time_tlock_max_i_18_n_0));
  LUT2 #(
    .INIT(4'h1)) 
    time_tlock_max_i_19
       (.I0(time_out_counter_reg[6]),
        .I1(time_out_counter_reg[7]),
        .O(time_tlock_max_i_19_n_0));
  LUT2 #(
    .INIT(4'h2)) 
    time_tlock_max_i_20
       (.I0(time_out_counter_reg[5]),
        .I1(time_out_counter_reg[4]),
        .O(time_tlock_max_i_20_n_0));
  LUT2 #(
    .INIT(4'h1)) 
    time_tlock_max_i_21
       (.I0(time_out_counter_reg[3]),
        .I1(time_out_counter_reg[2]),
        .O(time_tlock_max_i_21_n_0));
  LUT2 #(
    .INIT(4'h1)) 
    time_tlock_max_i_22
       (.I0(time_out_counter_reg[1]),
        .I1(time_out_counter_reg[0]),
        .O(time_tlock_max_i_22_n_0));
  LUT2 #(
    .INIT(4'hE)) 
    time_tlock_max_i_4
       (.I0(time_out_counter_reg[19]),
        .I1(time_out_counter_reg[18]),
        .O(time_tlock_max_i_4_n_0));
  LUT2 #(
    .INIT(4'hE)) 
    time_tlock_max_i_5__0
       (.I0(time_out_counter_reg[16]),
        .I1(time_out_counter_reg[17]),
        .O(time_tlock_max_i_5__0_n_0));
  LUT2 #(
    .INIT(4'h1)) 
    time_tlock_max_i_6__0
       (.I0(time_out_counter_reg[18]),
        .I1(time_out_counter_reg[19]),
        .O(time_tlock_max_i_6__0_n_0));
  LUT2 #(
    .INIT(4'h1)) 
    time_tlock_max_i_7__0
       (.I0(time_out_counter_reg[17]),
        .I1(time_out_counter_reg[16]),
        .O(time_tlock_max_i_7__0_n_0));
  LUT2 #(
    .INIT(4'hE)) 
    time_tlock_max_i_9
       (.I0(time_out_counter_reg[12]),
        .I1(time_out_counter_reg[13]),
        .O(time_tlock_max_i_9_n_0));
  FDRE #(
    .INIT(1'b0)) 
    time_tlock_max_reg
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(time_tlock_max_i_1_n_0),
        .Q(time_tlock_max),
        .R(reset_time_out_reg_n_0));
  CARRY4 time_tlock_max_reg_i_2__0
       (.CI(time_tlock_max_reg_i_3__0_n_0),
        .CO({NLW_time_tlock_max_reg_i_2__0_CO_UNCONNECTED[3:2],time_tlock_max1,time_tlock_max_reg_i_2__0_n_3}),
        .CYINIT(1'b0),
        .DI({1'b0,1'b0,time_tlock_max_i_4_n_0,time_tlock_max_i_5__0_n_0}),
        .O(NLW_time_tlock_max_reg_i_2__0_O_UNCONNECTED[3:0]),
        .S({1'b0,1'b0,time_tlock_max_i_6__0_n_0,time_tlock_max_i_7__0_n_0}));
  CARRY4 time_tlock_max_reg_i_3__0
       (.CI(time_tlock_max_reg_i_8_n_0),
        .CO({time_tlock_max_reg_i_3__0_n_0,time_tlock_max_reg_i_3__0_n_1,time_tlock_max_reg_i_3__0_n_2,time_tlock_max_reg_i_3__0_n_3}),
        .CYINIT(1'b0),
        .DI({time_out_counter_reg[15],time_tlock_max_i_9_n_0,1'b0,time_tlock_max_i_10_n_0}),
        .O(NLW_time_tlock_max_reg_i_3__0_O_UNCONNECTED[3:0]),
        .S({time_tlock_max_i_11_n_0,time_tlock_max_i_12_n_0,time_tlock_max_i_13_n_0,time_tlock_max_i_14_n_0}));
  CARRY4 time_tlock_max_reg_i_8
       (.CI(1'b0),
        .CO({time_tlock_max_reg_i_8_n_0,time_tlock_max_reg_i_8_n_1,time_tlock_max_reg_i_8_n_2,time_tlock_max_reg_i_8_n_3}),
        .CYINIT(1'b0),
        .DI({time_tlock_max_i_15_n_0,time_tlock_max_i_16_n_0,time_tlock_max_i_17_n_0,time_tlock_max_i_18_n_0}),
        .O(NLW_time_tlock_max_reg_i_8_O_UNCONNECTED[3:0]),
        .S({time_tlock_max_i_19_n_0,time_tlock_max_i_20_n_0,time_tlock_max_i_21_n_0,time_tlock_max_i_22_n_0}));
  LUT6 #(
    .INIT(64'h0000008000000000)) 
    \wait_bypass_count[0]_i_10__0 
       (.I0(wait_bypass_count_reg[7]),
        .I1(wait_bypass_count_reg[8]),
        .I2(wait_bypass_count_reg[9]),
        .I3(wait_bypass_count_reg[10]),
        .I4(wait_bypass_count_reg[11]),
        .I5(wait_bypass_count_reg[12]),
        .O(\wait_bypass_count[0]_i_10__0_n_0 ));
  LUT1 #(
    .INIT(2'h1)) 
    \wait_bypass_count[0]_i_1__0 
       (.I0(run_phase_alignment_int_s3_reg_n_0),
        .O(\wait_bypass_count[0]_i_1__0_n_0 ));
  LUT2 #(
    .INIT(4'h1)) 
    \wait_bypass_count[0]_i_2__0 
       (.I0(rx_fsm_reset_done_int_s3),
        .I1(wait_bypass_count1),
        .O(wait_bypass_count));
  LUT5 #(
    .INIT(32'h80000000)) 
    \wait_bypass_count[0]_i_4__0 
       (.I0(\wait_bypass_count[0]_i_9__0_n_0 ),
        .I1(wait_bypass_count_reg[2]),
        .I2(wait_bypass_count_reg[1]),
        .I3(wait_bypass_count_reg[0]),
        .I4(\wait_bypass_count[0]_i_10__0_n_0 ),
        .O(wait_bypass_count1));
  LUT1 #(
    .INIT(2'h2)) 
    \wait_bypass_count[0]_i_5__0 
       (.I0(wait_bypass_count_reg[3]),
        .O(\wait_bypass_count[0]_i_5__0_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \wait_bypass_count[0]_i_6__0 
       (.I0(wait_bypass_count_reg[2]),
        .O(\wait_bypass_count[0]_i_6__0_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \wait_bypass_count[0]_i_7__0 
       (.I0(wait_bypass_count_reg[1]),
        .O(\wait_bypass_count[0]_i_7__0_n_0 ));
  LUT1 #(
    .INIT(2'h1)) 
    \wait_bypass_count[0]_i_8__0 
       (.I0(wait_bypass_count_reg[0]),
        .O(\wait_bypass_count[0]_i_8__0_n_0 ));
  LUT4 #(
    .INIT(16'h0001)) 
    \wait_bypass_count[0]_i_9__0 
       (.I0(wait_bypass_count_reg[6]),
        .I1(wait_bypass_count_reg[5]),
        .I2(wait_bypass_count_reg[4]),
        .I3(wait_bypass_count_reg[3]),
        .O(\wait_bypass_count[0]_i_9__0_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \wait_bypass_count[12]_i_2__0 
       (.I0(wait_bypass_count_reg[12]),
        .O(\wait_bypass_count[12]_i_2__0_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \wait_bypass_count[4]_i_2__0 
       (.I0(wait_bypass_count_reg[7]),
        .O(\wait_bypass_count[4]_i_2__0_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \wait_bypass_count[4]_i_3__0 
       (.I0(wait_bypass_count_reg[6]),
        .O(\wait_bypass_count[4]_i_3__0_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \wait_bypass_count[4]_i_4__0 
       (.I0(wait_bypass_count_reg[5]),
        .O(\wait_bypass_count[4]_i_4__0_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \wait_bypass_count[4]_i_5__0 
       (.I0(wait_bypass_count_reg[4]),
        .O(\wait_bypass_count[4]_i_5__0_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \wait_bypass_count[8]_i_2__0 
       (.I0(wait_bypass_count_reg[11]),
        .O(\wait_bypass_count[8]_i_2__0_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \wait_bypass_count[8]_i_3__0 
       (.I0(wait_bypass_count_reg[10]),
        .O(\wait_bypass_count[8]_i_3__0_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \wait_bypass_count[8]_i_4__0 
       (.I0(wait_bypass_count_reg[9]),
        .O(\wait_bypass_count[8]_i_4__0_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \wait_bypass_count[8]_i_5__0 
       (.I0(wait_bypass_count_reg[8]),
        .O(\wait_bypass_count[8]_i_5__0_n_0 ));
  FDRE \wait_bypass_count_reg[0] 
       (.C(userclk),
        .CE(wait_bypass_count),
        .D(\wait_bypass_count_reg[0]_i_3__0_n_7 ),
        .Q(wait_bypass_count_reg[0]),
        .R(\wait_bypass_count[0]_i_1__0_n_0 ));
  CARRY4 \wait_bypass_count_reg[0]_i_3__0 
       (.CI(1'b0),
        .CO({\wait_bypass_count_reg[0]_i_3__0_n_0 ,\wait_bypass_count_reg[0]_i_3__0_n_1 ,\wait_bypass_count_reg[0]_i_3__0_n_2 ,\wait_bypass_count_reg[0]_i_3__0_n_3 }),
        .CYINIT(1'b0),
        .DI({1'b0,1'b0,1'b0,1'b1}),
        .O({\wait_bypass_count_reg[0]_i_3__0_n_4 ,\wait_bypass_count_reg[0]_i_3__0_n_5 ,\wait_bypass_count_reg[0]_i_3__0_n_6 ,\wait_bypass_count_reg[0]_i_3__0_n_7 }),
        .S({\wait_bypass_count[0]_i_5__0_n_0 ,\wait_bypass_count[0]_i_6__0_n_0 ,\wait_bypass_count[0]_i_7__0_n_0 ,\wait_bypass_count[0]_i_8__0_n_0 }));
  FDRE \wait_bypass_count_reg[10] 
       (.C(userclk),
        .CE(wait_bypass_count),
        .D(\wait_bypass_count_reg[8]_i_1__0_n_5 ),
        .Q(wait_bypass_count_reg[10]),
        .R(\wait_bypass_count[0]_i_1__0_n_0 ));
  FDRE \wait_bypass_count_reg[11] 
       (.C(userclk),
        .CE(wait_bypass_count),
        .D(\wait_bypass_count_reg[8]_i_1__0_n_4 ),
        .Q(wait_bypass_count_reg[11]),
        .R(\wait_bypass_count[0]_i_1__0_n_0 ));
  FDRE \wait_bypass_count_reg[12] 
       (.C(userclk),
        .CE(wait_bypass_count),
        .D(\wait_bypass_count_reg[12]_i_1__0_n_7 ),
        .Q(wait_bypass_count_reg[12]),
        .R(\wait_bypass_count[0]_i_1__0_n_0 ));
  CARRY4 \wait_bypass_count_reg[12]_i_1__0 
       (.CI(\wait_bypass_count_reg[8]_i_1__0_n_0 ),
        .CO(\NLW_wait_bypass_count_reg[12]_i_1__0_CO_UNCONNECTED [3:0]),
        .CYINIT(1'b0),
        .DI({1'b0,1'b0,1'b0,1'b0}),
        .O({\NLW_wait_bypass_count_reg[12]_i_1__0_O_UNCONNECTED [3:1],\wait_bypass_count_reg[12]_i_1__0_n_7 }),
        .S({1'b0,1'b0,1'b0,\wait_bypass_count[12]_i_2__0_n_0 }));
  FDRE \wait_bypass_count_reg[1] 
       (.C(userclk),
        .CE(wait_bypass_count),
        .D(\wait_bypass_count_reg[0]_i_3__0_n_6 ),
        .Q(wait_bypass_count_reg[1]),
        .R(\wait_bypass_count[0]_i_1__0_n_0 ));
  FDRE \wait_bypass_count_reg[2] 
       (.C(userclk),
        .CE(wait_bypass_count),
        .D(\wait_bypass_count_reg[0]_i_3__0_n_5 ),
        .Q(wait_bypass_count_reg[2]),
        .R(\wait_bypass_count[0]_i_1__0_n_0 ));
  FDRE \wait_bypass_count_reg[3] 
       (.C(userclk),
        .CE(wait_bypass_count),
        .D(\wait_bypass_count_reg[0]_i_3__0_n_4 ),
        .Q(wait_bypass_count_reg[3]),
        .R(\wait_bypass_count[0]_i_1__0_n_0 ));
  FDRE \wait_bypass_count_reg[4] 
       (.C(userclk),
        .CE(wait_bypass_count),
        .D(\wait_bypass_count_reg[4]_i_1__0_n_7 ),
        .Q(wait_bypass_count_reg[4]),
        .R(\wait_bypass_count[0]_i_1__0_n_0 ));
  CARRY4 \wait_bypass_count_reg[4]_i_1__0 
       (.CI(\wait_bypass_count_reg[0]_i_3__0_n_0 ),
        .CO({\wait_bypass_count_reg[4]_i_1__0_n_0 ,\wait_bypass_count_reg[4]_i_1__0_n_1 ,\wait_bypass_count_reg[4]_i_1__0_n_2 ,\wait_bypass_count_reg[4]_i_1__0_n_3 }),
        .CYINIT(1'b0),
        .DI({1'b0,1'b0,1'b0,1'b0}),
        .O({\wait_bypass_count_reg[4]_i_1__0_n_4 ,\wait_bypass_count_reg[4]_i_1__0_n_5 ,\wait_bypass_count_reg[4]_i_1__0_n_6 ,\wait_bypass_count_reg[4]_i_1__0_n_7 }),
        .S({\wait_bypass_count[4]_i_2__0_n_0 ,\wait_bypass_count[4]_i_3__0_n_0 ,\wait_bypass_count[4]_i_4__0_n_0 ,\wait_bypass_count[4]_i_5__0_n_0 }));
  FDRE \wait_bypass_count_reg[5] 
       (.C(userclk),
        .CE(wait_bypass_count),
        .D(\wait_bypass_count_reg[4]_i_1__0_n_6 ),
        .Q(wait_bypass_count_reg[5]),
        .R(\wait_bypass_count[0]_i_1__0_n_0 ));
  FDRE \wait_bypass_count_reg[6] 
       (.C(userclk),
        .CE(wait_bypass_count),
        .D(\wait_bypass_count_reg[4]_i_1__0_n_5 ),
        .Q(wait_bypass_count_reg[6]),
        .R(\wait_bypass_count[0]_i_1__0_n_0 ));
  FDRE \wait_bypass_count_reg[7] 
       (.C(userclk),
        .CE(wait_bypass_count),
        .D(\wait_bypass_count_reg[4]_i_1__0_n_4 ),
        .Q(wait_bypass_count_reg[7]),
        .R(\wait_bypass_count[0]_i_1__0_n_0 ));
  FDRE \wait_bypass_count_reg[8] 
       (.C(userclk),
        .CE(wait_bypass_count),
        .D(\wait_bypass_count_reg[8]_i_1__0_n_7 ),
        .Q(wait_bypass_count_reg[8]),
        .R(\wait_bypass_count[0]_i_1__0_n_0 ));
  CARRY4 \wait_bypass_count_reg[8]_i_1__0 
       (.CI(\wait_bypass_count_reg[4]_i_1__0_n_0 ),
        .CO({\wait_bypass_count_reg[8]_i_1__0_n_0 ,\wait_bypass_count_reg[8]_i_1__0_n_1 ,\wait_bypass_count_reg[8]_i_1__0_n_2 ,\wait_bypass_count_reg[8]_i_1__0_n_3 }),
        .CYINIT(1'b0),
        .DI({1'b0,1'b0,1'b0,1'b0}),
        .O({\wait_bypass_count_reg[8]_i_1__0_n_4 ,\wait_bypass_count_reg[8]_i_1__0_n_5 ,\wait_bypass_count_reg[8]_i_1__0_n_6 ,\wait_bypass_count_reg[8]_i_1__0_n_7 }),
        .S({\wait_bypass_count[8]_i_2__0_n_0 ,\wait_bypass_count[8]_i_3__0_n_0 ,\wait_bypass_count[8]_i_4__0_n_0 ,\wait_bypass_count[8]_i_5__0_n_0 }));
  FDRE \wait_bypass_count_reg[9] 
       (.C(userclk),
        .CE(wait_bypass_count),
        .D(\wait_bypass_count_reg[8]_i_1__0_n_6 ),
        .Q(wait_bypass_count_reg[9]),
        .R(\wait_bypass_count[0]_i_1__0_n_0 ));
  (* SOFT_HLUTNM = "soft_lutpair46" *) 
  LUT1 #(
    .INIT(2'h1)) 
    \wait_time_cnt[0]_i_1__0 
       (.I0(wait_time_cnt_reg__0[0]),
        .O(wait_time_cnt0__0[0]));
  (* SOFT_HLUTNM = "soft_lutpair46" *) 
  LUT2 #(
    .INIT(4'h9)) 
    \wait_time_cnt[1]_i_1__0 
       (.I0(wait_time_cnt_reg__0[1]),
        .I1(wait_time_cnt_reg__0[0]),
        .O(wait_time_cnt0__0[1]));
  LUT3 #(
    .INIT(8'hA9)) 
    \wait_time_cnt[2]_i_1__0 
       (.I0(wait_time_cnt_reg__0[2]),
        .I1(wait_time_cnt_reg__0[0]),
        .I2(wait_time_cnt_reg__0[1]),
        .O(wait_time_cnt0__0[2]));
  (* SOFT_HLUTNM = "soft_lutpair41" *) 
  LUT4 #(
    .INIT(16'hFE01)) 
    \wait_time_cnt[3]_i_1__0 
       (.I0(wait_time_cnt_reg__0[1]),
        .I1(wait_time_cnt_reg__0[0]),
        .I2(wait_time_cnt_reg__0[2]),
        .I3(wait_time_cnt_reg__0[3]),
        .O(wait_time_cnt0__0[3]));
  (* SOFT_HLUTNM = "soft_lutpair41" *) 
  LUT5 #(
    .INIT(32'hFFFE0001)) 
    \wait_time_cnt[4]_i_1__0 
       (.I0(wait_time_cnt_reg__0[1]),
        .I1(wait_time_cnt_reg__0[0]),
        .I2(wait_time_cnt_reg__0[2]),
        .I3(wait_time_cnt_reg__0[3]),
        .I4(wait_time_cnt_reg__0[4]),
        .O(wait_time_cnt0__0[4]));
  LUT6 #(
    .INIT(64'hFFFFFFFE00000001)) 
    \wait_time_cnt[5]_i_1__0 
       (.I0(wait_time_cnt_reg__0[1]),
        .I1(wait_time_cnt_reg__0[0]),
        .I2(wait_time_cnt_reg__0[2]),
        .I3(wait_time_cnt_reg__0[3]),
        .I4(wait_time_cnt_reg__0[4]),
        .I5(wait_time_cnt_reg__0[5]),
        .O(wait_time_cnt0__0[5]));
  LUT3 #(
    .INIT(8'h02)) 
    \wait_time_cnt[6]_i_1__0 
       (.I0(rx_state[0]),
        .I1(rx_state[1]),
        .I2(rx_state[3]),
        .O(\wait_time_cnt[6]_i_1__0_n_0 ));
  LUT2 #(
    .INIT(4'hE)) 
    \wait_time_cnt[6]_i_2__0 
       (.I0(\wait_time_cnt[6]_i_4__0_n_0 ),
        .I1(wait_time_cnt_reg__0[6]),
        .O(\wait_time_cnt[6]_i_2__0_n_0 ));
  LUT2 #(
    .INIT(4'h9)) 
    \wait_time_cnt[6]_i_3__0 
       (.I0(wait_time_cnt_reg__0[6]),
        .I1(\wait_time_cnt[6]_i_4__0_n_0 ),
        .O(wait_time_cnt0__0[6]));
  LUT6 #(
    .INIT(64'hFFFFFFFFFFFFFFFE)) 
    \wait_time_cnt[6]_i_4__0 
       (.I0(wait_time_cnt_reg__0[5]),
        .I1(wait_time_cnt_reg__0[4]),
        .I2(wait_time_cnt_reg__0[3]),
        .I3(wait_time_cnt_reg__0[2]),
        .I4(wait_time_cnt_reg__0[0]),
        .I5(wait_time_cnt_reg__0[1]),
        .O(\wait_time_cnt[6]_i_4__0_n_0 ));
  FDRE \wait_time_cnt_reg[0] 
       (.C(independent_clock_bufg),
        .CE(\wait_time_cnt[6]_i_2__0_n_0 ),
        .D(wait_time_cnt0__0[0]),
        .Q(wait_time_cnt_reg__0[0]),
        .R(\wait_time_cnt[6]_i_1__0_n_0 ));
  FDRE \wait_time_cnt_reg[1] 
       (.C(independent_clock_bufg),
        .CE(\wait_time_cnt[6]_i_2__0_n_0 ),
        .D(wait_time_cnt0__0[1]),
        .Q(wait_time_cnt_reg__0[1]),
        .R(\wait_time_cnt[6]_i_1__0_n_0 ));
  FDSE \wait_time_cnt_reg[2] 
       (.C(independent_clock_bufg),
        .CE(\wait_time_cnt[6]_i_2__0_n_0 ),
        .D(wait_time_cnt0__0[2]),
        .Q(wait_time_cnt_reg__0[2]),
        .S(\wait_time_cnt[6]_i_1__0_n_0 ));
  FDRE \wait_time_cnt_reg[3] 
       (.C(independent_clock_bufg),
        .CE(\wait_time_cnt[6]_i_2__0_n_0 ),
        .D(wait_time_cnt0__0[3]),
        .Q(wait_time_cnt_reg__0[3]),
        .R(\wait_time_cnt[6]_i_1__0_n_0 ));
  FDRE \wait_time_cnt_reg[4] 
       (.C(independent_clock_bufg),
        .CE(\wait_time_cnt[6]_i_2__0_n_0 ),
        .D(wait_time_cnt0__0[4]),
        .Q(wait_time_cnt_reg__0[4]),
        .R(\wait_time_cnt[6]_i_1__0_n_0 ));
  FDSE \wait_time_cnt_reg[5] 
       (.C(independent_clock_bufg),
        .CE(\wait_time_cnt[6]_i_2__0_n_0 ),
        .D(wait_time_cnt0__0[5]),
        .Q(wait_time_cnt_reg__0[5]),
        .S(\wait_time_cnt[6]_i_1__0_n_0 ));
  FDSE \wait_time_cnt_reg[6] 
       (.C(independent_clock_bufg),
        .CE(\wait_time_cnt[6]_i_2__0_n_0 ),
        .D(wait_time_cnt0__0[6]),
        .Q(wait_time_cnt_reg__0[6]),
        .S(\wait_time_cnt[6]_i_1__0_n_0 ));
endmodule

(* ORIG_REF_NAME = "GigEthGth7Core_TX_STARTUP_FSM" *) 
module GigEthGth7Core_GigEthGth7Core_TX_STARTUP_FSM
   (mmcm_reset,
    CPLL_RESET,
    data_in,
    TXUSERRDY,
    gt0_gttxreset_in0_out,
    independent_clock_bufg,
    userclk,
    pma_reset,
    reset_sync6,
    CPLLREFCLKLOST,
    \cpllpd_wait_reg[95] ,
    mmcm_locked,
    cplllock);
  output mmcm_reset;
  output CPLL_RESET;
  output data_in;
  output TXUSERRDY;
  output gt0_gttxreset_in0_out;
  input independent_clock_bufg;
  input userclk;
  input pma_reset;
  input reset_sync6;
  input CPLLREFCLKLOST;
  input \cpllpd_wait_reg[95] ;
  input mmcm_locked;
  input cplllock;

  wire CPLLREFCLKLOST;
  wire CPLL_RESET;
  wire CPLL_RESET0;
  wire CPLL_RESET_i_1_n_0;
  wire CPLL_RESET_i_2_n_0;
  wire \FSM_sequential_tx_state[0]_i_1_n_0 ;
  wire \FSM_sequential_tx_state[0]_i_2_n_0 ;
  wire \FSM_sequential_tx_state[1]_i_1_n_0 ;
  wire \FSM_sequential_tx_state[2]_i_1_n_0 ;
  wire \FSM_sequential_tx_state[2]_i_2_n_0 ;
  wire \FSM_sequential_tx_state[3]_i_2_n_0 ;
  wire \FSM_sequential_tx_state[3]_i_4_n_0 ;
  wire \FSM_sequential_tx_state[3]_i_5_n_0 ;
  wire \FSM_sequential_tx_state[3]_i_7_n_0 ;
  wire GTTXRESET;
  wire MMCM_RESET_i_1_n_0;
  wire TXUSERRDY;
  wire TXUSERRDY_i_1_n_0;
  wire clear;
  wire cplllock;
  wire \cpllpd_wait_reg[95] ;
  wire data_in;
  wire data_out;
  wire gt0_gttxreset_in0_out;
  wire gttxreset_i_i_1_n_0;
  wire independent_clock_bufg;
  wire init_wait_count;
  wire \init_wait_count[0]_i_1_n_0 ;
  wire \init_wait_count[6]_i_3_n_0 ;
  wire [6:0]init_wait_count_reg__0;
  wire init_wait_done_i_1_n_0;
  wire init_wait_done_reg_n_0;
  wire \mmcm_lock_count[7]_i_2_n_0 ;
  wire \mmcm_lock_count[7]_i_4_n_0 ;
  wire [7:0]mmcm_lock_count_reg__0;
  wire mmcm_lock_reclocked;
  wire mmcm_lock_reclocked_i_2_n_0;
  wire mmcm_locked;
  wire mmcm_reset;
  wire [6:1]p_0_in;
  wire [7:0]p_0_in__0;
  wire pll_reset_asserted_i_1_n_0;
  wire pll_reset_asserted_reg_n_0;
  wire pma_reset;
  wire refclk_stable;
  wire \refclk_stable_count[0]_i_1_n_0 ;
  wire \refclk_stable_count[0]_i_3_n_0 ;
  wire \refclk_stable_count[0]_i_4_n_0 ;
  wire \refclk_stable_count[0]_i_5_n_0 ;
  wire \refclk_stable_count[0]_i_6_n_0 ;
  wire \refclk_stable_count[12]_i_2_n_0 ;
  wire \refclk_stable_count[12]_i_3_n_0 ;
  wire \refclk_stable_count[12]_i_4_n_0 ;
  wire \refclk_stable_count[12]_i_5_n_0 ;
  wire \refclk_stable_count[16]_i_2_n_0 ;
  wire \refclk_stable_count[16]_i_3_n_0 ;
  wire \refclk_stable_count[16]_i_4_n_0 ;
  wire \refclk_stable_count[16]_i_5_n_0 ;
  wire \refclk_stable_count[20]_i_2_n_0 ;
  wire \refclk_stable_count[20]_i_3_n_0 ;
  wire \refclk_stable_count[20]_i_4_n_0 ;
  wire \refclk_stable_count[20]_i_5_n_0 ;
  wire \refclk_stable_count[24]_i_2_n_0 ;
  wire \refclk_stable_count[24]_i_3_n_0 ;
  wire \refclk_stable_count[24]_i_4_n_0 ;
  wire \refclk_stable_count[24]_i_5_n_0 ;
  wire \refclk_stable_count[28]_i_2_n_0 ;
  wire \refclk_stable_count[28]_i_3_n_0 ;
  wire \refclk_stable_count[28]_i_4_n_0 ;
  wire \refclk_stable_count[28]_i_5_n_0 ;
  wire \refclk_stable_count[4]_i_2_n_0 ;
  wire \refclk_stable_count[4]_i_3_n_0 ;
  wire \refclk_stable_count[4]_i_4_n_0 ;
  wire \refclk_stable_count[4]_i_5_n_0 ;
  wire \refclk_stable_count[8]_i_2_n_0 ;
  wire \refclk_stable_count[8]_i_3_n_0 ;
  wire \refclk_stable_count[8]_i_4_n_0 ;
  wire \refclk_stable_count[8]_i_5_n_0 ;
  wire [31:0]refclk_stable_count_reg;
  wire \refclk_stable_count_reg[0]_i_2_n_0 ;
  wire \refclk_stable_count_reg[0]_i_2_n_1 ;
  wire \refclk_stable_count_reg[0]_i_2_n_2 ;
  wire \refclk_stable_count_reg[0]_i_2_n_3 ;
  wire \refclk_stable_count_reg[0]_i_2_n_4 ;
  wire \refclk_stable_count_reg[0]_i_2_n_5 ;
  wire \refclk_stable_count_reg[0]_i_2_n_6 ;
  wire \refclk_stable_count_reg[0]_i_2_n_7 ;
  wire \refclk_stable_count_reg[12]_i_1_n_0 ;
  wire \refclk_stable_count_reg[12]_i_1_n_1 ;
  wire \refclk_stable_count_reg[12]_i_1_n_2 ;
  wire \refclk_stable_count_reg[12]_i_1_n_3 ;
  wire \refclk_stable_count_reg[12]_i_1_n_4 ;
  wire \refclk_stable_count_reg[12]_i_1_n_5 ;
  wire \refclk_stable_count_reg[12]_i_1_n_6 ;
  wire \refclk_stable_count_reg[12]_i_1_n_7 ;
  wire \refclk_stable_count_reg[16]_i_1_n_0 ;
  wire \refclk_stable_count_reg[16]_i_1_n_1 ;
  wire \refclk_stable_count_reg[16]_i_1_n_2 ;
  wire \refclk_stable_count_reg[16]_i_1_n_3 ;
  wire \refclk_stable_count_reg[16]_i_1_n_4 ;
  wire \refclk_stable_count_reg[16]_i_1_n_5 ;
  wire \refclk_stable_count_reg[16]_i_1_n_6 ;
  wire \refclk_stable_count_reg[16]_i_1_n_7 ;
  wire \refclk_stable_count_reg[20]_i_1_n_0 ;
  wire \refclk_stable_count_reg[20]_i_1_n_1 ;
  wire \refclk_stable_count_reg[20]_i_1_n_2 ;
  wire \refclk_stable_count_reg[20]_i_1_n_3 ;
  wire \refclk_stable_count_reg[20]_i_1_n_4 ;
  wire \refclk_stable_count_reg[20]_i_1_n_5 ;
  wire \refclk_stable_count_reg[20]_i_1_n_6 ;
  wire \refclk_stable_count_reg[20]_i_1_n_7 ;
  wire \refclk_stable_count_reg[24]_i_1_n_0 ;
  wire \refclk_stable_count_reg[24]_i_1_n_1 ;
  wire \refclk_stable_count_reg[24]_i_1_n_2 ;
  wire \refclk_stable_count_reg[24]_i_1_n_3 ;
  wire \refclk_stable_count_reg[24]_i_1_n_4 ;
  wire \refclk_stable_count_reg[24]_i_1_n_5 ;
  wire \refclk_stable_count_reg[24]_i_1_n_6 ;
  wire \refclk_stable_count_reg[24]_i_1_n_7 ;
  wire \refclk_stable_count_reg[28]_i_1_n_1 ;
  wire \refclk_stable_count_reg[28]_i_1_n_2 ;
  wire \refclk_stable_count_reg[28]_i_1_n_3 ;
  wire \refclk_stable_count_reg[28]_i_1_n_4 ;
  wire \refclk_stable_count_reg[28]_i_1_n_5 ;
  wire \refclk_stable_count_reg[28]_i_1_n_6 ;
  wire \refclk_stable_count_reg[28]_i_1_n_7 ;
  wire \refclk_stable_count_reg[4]_i_1_n_0 ;
  wire \refclk_stable_count_reg[4]_i_1_n_1 ;
  wire \refclk_stable_count_reg[4]_i_1_n_2 ;
  wire \refclk_stable_count_reg[4]_i_1_n_3 ;
  wire \refclk_stable_count_reg[4]_i_1_n_4 ;
  wire \refclk_stable_count_reg[4]_i_1_n_5 ;
  wire \refclk_stable_count_reg[4]_i_1_n_6 ;
  wire \refclk_stable_count_reg[4]_i_1_n_7 ;
  wire \refclk_stable_count_reg[8]_i_1_n_0 ;
  wire \refclk_stable_count_reg[8]_i_1_n_1 ;
  wire \refclk_stable_count_reg[8]_i_1_n_2 ;
  wire \refclk_stable_count_reg[8]_i_1_n_3 ;
  wire \refclk_stable_count_reg[8]_i_1_n_4 ;
  wire \refclk_stable_count_reg[8]_i_1_n_5 ;
  wire \refclk_stable_count_reg[8]_i_1_n_6 ;
  wire \refclk_stable_count_reg[8]_i_1_n_7 ;
  wire refclk_stable_i_10_n_0;
  wire refclk_stable_i_11_n_0;
  wire refclk_stable_i_12_n_0;
  wire refclk_stable_i_13_n_0;
  wire refclk_stable_i_14_n_0;
  wire refclk_stable_i_3_n_0;
  wire refclk_stable_i_4_n_0;
  wire refclk_stable_i_5_n_0;
  wire refclk_stable_i_7_n_0;
  wire refclk_stable_i_8_n_0;
  wire refclk_stable_i_9_n_0;
  wire refclk_stable_reg_i_1_n_1;
  wire refclk_stable_reg_i_1_n_2;
  wire refclk_stable_reg_i_1_n_3;
  wire refclk_stable_reg_i_2_n_0;
  wire refclk_stable_reg_i_2_n_1;
  wire refclk_stable_reg_i_2_n_2;
  wire refclk_stable_reg_i_2_n_3;
  wire refclk_stable_reg_i_6_n_0;
  wire refclk_stable_reg_i_6_n_1;
  wire refclk_stable_reg_i_6_n_2;
  wire refclk_stable_reg_i_6_n_3;
  wire reset_sync6;
  wire reset_time_out;
  wire reset_time_out_i_3_n_0;
  wire run_phase_alignment_int_i_1_n_0;
  wire run_phase_alignment_int_reg_n_0;
  wire run_phase_alignment_int_s3;
  wire sync_cplllock_n_0;
  wire sync_cplllock_n_1;
  wire sync_mmcm_lock_reclocked_n_0;
  wire sync_mmcm_lock_reclocked_n_1;
  wire time_out_2ms;
  wire time_out_2ms_i_1_n_0;
  wire time_out_500us;
  wire time_out_500us_i_10_n_0;
  wire time_out_500us_i_1_n_0;
  wire time_out_500us_i_4_n_0;
  wire time_out_500us_i_5_n_0;
  wire time_out_500us_i_6_n_0;
  wire time_out_500us_i_7_n_0;
  wire time_out_500us_i_8_n_0;
  wire time_out_500us_i_9_n_0;
  wire time_out_500us_reg_i_2_n_1;
  wire time_out_500us_reg_i_2_n_2;
  wire time_out_500us_reg_i_2_n_3;
  wire time_out_500us_reg_i_3_n_0;
  wire time_out_500us_reg_i_3_n_1;
  wire time_out_500us_reg_i_3_n_2;
  wire time_out_500us_reg_i_3_n_3;
  wire \time_out_counter[0]_i_10_n_0 ;
  wire \time_out_counter[0]_i_11_n_0 ;
  wire \time_out_counter[0]_i_12_n_0 ;
  wire \time_out_counter[0]_i_13__0_n_0 ;
  wire \time_out_counter[0]_i_14_n_0 ;
  wire \time_out_counter[0]_i_15_n_0 ;
  wire \time_out_counter[0]_i_1_n_0 ;
  wire \time_out_counter[0]_i_4_n_0 ;
  wire \time_out_counter[0]_i_5_n_0 ;
  wire \time_out_counter[0]_i_6_n_0 ;
  wire \time_out_counter[0]_i_7__0_n_0 ;
  wire \time_out_counter[0]_i_9__0_n_0 ;
  wire \time_out_counter[12]_i_2_n_0 ;
  wire \time_out_counter[12]_i_3_n_0 ;
  wire \time_out_counter[12]_i_4_n_0 ;
  wire \time_out_counter[12]_i_5_n_0 ;
  wire \time_out_counter[16]_i_2_n_0 ;
  wire \time_out_counter[16]_i_3_n_0 ;
  wire \time_out_counter[16]_i_4_n_0 ;
  wire \time_out_counter[4]_i_2_n_0 ;
  wire \time_out_counter[4]_i_3_n_0 ;
  wire \time_out_counter[4]_i_4_n_0 ;
  wire \time_out_counter[4]_i_5_n_0 ;
  wire \time_out_counter[8]_i_2_n_0 ;
  wire \time_out_counter[8]_i_3_n_0 ;
  wire \time_out_counter[8]_i_4_n_0 ;
  wire \time_out_counter[8]_i_5_n_0 ;
  wire [18:0]time_out_counter_reg;
  wire \time_out_counter_reg[0]_i_2_n_0 ;
  wire \time_out_counter_reg[0]_i_2_n_1 ;
  wire \time_out_counter_reg[0]_i_2_n_2 ;
  wire \time_out_counter_reg[0]_i_2_n_3 ;
  wire \time_out_counter_reg[0]_i_2_n_4 ;
  wire \time_out_counter_reg[0]_i_2_n_5 ;
  wire \time_out_counter_reg[0]_i_2_n_6 ;
  wire \time_out_counter_reg[0]_i_2_n_7 ;
  wire \time_out_counter_reg[0]_i_3_n_1 ;
  wire \time_out_counter_reg[0]_i_3_n_2 ;
  wire \time_out_counter_reg[0]_i_3_n_3 ;
  wire \time_out_counter_reg[0]_i_8_n_0 ;
  wire \time_out_counter_reg[0]_i_8_n_1 ;
  wire \time_out_counter_reg[0]_i_8_n_2 ;
  wire \time_out_counter_reg[0]_i_8_n_3 ;
  wire \time_out_counter_reg[12]_i_1_n_0 ;
  wire \time_out_counter_reg[12]_i_1_n_1 ;
  wire \time_out_counter_reg[12]_i_1_n_2 ;
  wire \time_out_counter_reg[12]_i_1_n_3 ;
  wire \time_out_counter_reg[12]_i_1_n_4 ;
  wire \time_out_counter_reg[12]_i_1_n_5 ;
  wire \time_out_counter_reg[12]_i_1_n_6 ;
  wire \time_out_counter_reg[12]_i_1_n_7 ;
  wire \time_out_counter_reg[16]_i_1_n_2 ;
  wire \time_out_counter_reg[16]_i_1_n_3 ;
  wire \time_out_counter_reg[16]_i_1_n_5 ;
  wire \time_out_counter_reg[16]_i_1_n_6 ;
  wire \time_out_counter_reg[16]_i_1_n_7 ;
  wire \time_out_counter_reg[4]_i_1_n_0 ;
  wire \time_out_counter_reg[4]_i_1_n_1 ;
  wire \time_out_counter_reg[4]_i_1_n_2 ;
  wire \time_out_counter_reg[4]_i_1_n_3 ;
  wire \time_out_counter_reg[4]_i_1_n_4 ;
  wire \time_out_counter_reg[4]_i_1_n_5 ;
  wire \time_out_counter_reg[4]_i_1_n_6 ;
  wire \time_out_counter_reg[4]_i_1_n_7 ;
  wire \time_out_counter_reg[8]_i_1_n_0 ;
  wire \time_out_counter_reg[8]_i_1_n_1 ;
  wire \time_out_counter_reg[8]_i_1_n_2 ;
  wire \time_out_counter_reg[8]_i_1_n_3 ;
  wire \time_out_counter_reg[8]_i_1_n_4 ;
  wire \time_out_counter_reg[8]_i_1_n_5 ;
  wire \time_out_counter_reg[8]_i_1_n_6 ;
  wire \time_out_counter_reg[8]_i_1_n_7 ;
  wire time_out_wait_bypass_i_1_n_0;
  wire time_out_wait_bypass_reg_n_0;
  wire time_out_wait_bypass_s2;
  wire time_out_wait_bypass_s3;
  wire time_tlock_max;
  wire time_tlock_max_i_10__0_n_0;
  wire time_tlock_max_i_1__0_n_0;
  wire time_tlock_max_i_4__0_n_0;
  wire time_tlock_max_i_5_n_0;
  wire time_tlock_max_i_6_n_0;
  wire time_tlock_max_i_7_n_0;
  wire time_tlock_max_i_8_n_0;
  wire time_tlock_max_i_9__0_n_0;
  wire time_tlock_max_reg_i_2_n_1;
  wire time_tlock_max_reg_i_2_n_2;
  wire time_tlock_max_reg_i_2_n_3;
  wire time_tlock_max_reg_i_3_n_0;
  wire time_tlock_max_reg_i_3_n_1;
  wire time_tlock_max_reg_i_3_n_2;
  wire time_tlock_max_reg_i_3_n_3;
  wire tx_fsm_reset_done_int_i_1_n_0;
  wire tx_fsm_reset_done_int_s2;
  wire tx_fsm_reset_done_int_s3;
  (* RTL_KEEP = "yes" *) wire [3:0]tx_state;
  wire tx_state13_out;
  wire txresetdone_s2;
  wire txresetdone_s3;
  wire userclk;
  wire wait_bypass_count;
  wire wait_bypass_count1;
  wire \wait_bypass_count[0]_i_10_n_0 ;
  wire \wait_bypass_count[0]_i_11_n_0 ;
  wire \wait_bypass_count[0]_i_5_n_0 ;
  wire \wait_bypass_count[0]_i_6_n_0 ;
  wire \wait_bypass_count[0]_i_7_n_0 ;
  wire \wait_bypass_count[0]_i_8_n_0 ;
  wire \wait_bypass_count[0]_i_9_n_0 ;
  wire \wait_bypass_count[12]_i_2_n_0 ;
  wire \wait_bypass_count[12]_i_3_n_0 ;
  wire \wait_bypass_count[12]_i_4_n_0 ;
  wire \wait_bypass_count[12]_i_5_n_0 ;
  wire \wait_bypass_count[16]_i_2_n_0 ;
  wire \wait_bypass_count[4]_i_2_n_0 ;
  wire \wait_bypass_count[4]_i_3_n_0 ;
  wire \wait_bypass_count[4]_i_4_n_0 ;
  wire \wait_bypass_count[4]_i_5_n_0 ;
  wire \wait_bypass_count[8]_i_2_n_0 ;
  wire \wait_bypass_count[8]_i_3_n_0 ;
  wire \wait_bypass_count[8]_i_4_n_0 ;
  wire \wait_bypass_count[8]_i_5_n_0 ;
  wire [16:0]wait_bypass_count_reg;
  wire \wait_bypass_count_reg[0]_i_3_n_0 ;
  wire \wait_bypass_count_reg[0]_i_3_n_1 ;
  wire \wait_bypass_count_reg[0]_i_3_n_2 ;
  wire \wait_bypass_count_reg[0]_i_3_n_3 ;
  wire \wait_bypass_count_reg[0]_i_3_n_4 ;
  wire \wait_bypass_count_reg[0]_i_3_n_5 ;
  wire \wait_bypass_count_reg[0]_i_3_n_6 ;
  wire \wait_bypass_count_reg[0]_i_3_n_7 ;
  wire \wait_bypass_count_reg[12]_i_1_n_0 ;
  wire \wait_bypass_count_reg[12]_i_1_n_1 ;
  wire \wait_bypass_count_reg[12]_i_1_n_2 ;
  wire \wait_bypass_count_reg[12]_i_1_n_3 ;
  wire \wait_bypass_count_reg[12]_i_1_n_4 ;
  wire \wait_bypass_count_reg[12]_i_1_n_5 ;
  wire \wait_bypass_count_reg[12]_i_1_n_6 ;
  wire \wait_bypass_count_reg[12]_i_1_n_7 ;
  wire \wait_bypass_count_reg[16]_i_1_n_7 ;
  wire \wait_bypass_count_reg[4]_i_1_n_0 ;
  wire \wait_bypass_count_reg[4]_i_1_n_1 ;
  wire \wait_bypass_count_reg[4]_i_1_n_2 ;
  wire \wait_bypass_count_reg[4]_i_1_n_3 ;
  wire \wait_bypass_count_reg[4]_i_1_n_4 ;
  wire \wait_bypass_count_reg[4]_i_1_n_5 ;
  wire \wait_bypass_count_reg[4]_i_1_n_6 ;
  wire \wait_bypass_count_reg[4]_i_1_n_7 ;
  wire \wait_bypass_count_reg[8]_i_1_n_0 ;
  wire \wait_bypass_count_reg[8]_i_1_n_1 ;
  wire \wait_bypass_count_reg[8]_i_1_n_2 ;
  wire \wait_bypass_count_reg[8]_i_1_n_3 ;
  wire \wait_bypass_count_reg[8]_i_1_n_4 ;
  wire \wait_bypass_count_reg[8]_i_1_n_5 ;
  wire \wait_bypass_count_reg[8]_i_1_n_6 ;
  wire \wait_bypass_count_reg[8]_i_1_n_7 ;
  wire [6:0]wait_time_cnt0;
  wire wait_time_cnt0_0;
  wire \wait_time_cnt[6]_i_2_n_0 ;
  wire \wait_time_cnt[6]_i_4_n_0 ;
  wire [6:0]wait_time_cnt_reg__0;
  wire [3:3]\NLW_refclk_stable_count_reg[28]_i_1_CO_UNCONNECTED ;
  wire [3:3]NLW_refclk_stable_reg_i_1_CO_UNCONNECTED;
  wire [3:0]NLW_refclk_stable_reg_i_1_O_UNCONNECTED;
  wire [3:0]NLW_refclk_stable_reg_i_2_O_UNCONNECTED;
  wire [3:0]NLW_refclk_stable_reg_i_6_O_UNCONNECTED;
  wire [3:3]NLW_time_out_500us_reg_i_2_CO_UNCONNECTED;
  wire [3:0]NLW_time_out_500us_reg_i_2_O_UNCONNECTED;
  wire [3:0]NLW_time_out_500us_reg_i_3_O_UNCONNECTED;
  wire [3:3]\NLW_time_out_counter_reg[0]_i_3_CO_UNCONNECTED ;
  wire [3:0]\NLW_time_out_counter_reg[0]_i_3_O_UNCONNECTED ;
  wire [3:0]\NLW_time_out_counter_reg[0]_i_8_O_UNCONNECTED ;
  wire [3:2]\NLW_time_out_counter_reg[16]_i_1_CO_UNCONNECTED ;
  wire [3:3]\NLW_time_out_counter_reg[16]_i_1_O_UNCONNECTED ;
  wire [3:3]NLW_time_tlock_max_reg_i_2_CO_UNCONNECTED;
  wire [3:0]NLW_time_tlock_max_reg_i_2_O_UNCONNECTED;
  wire [3:0]NLW_time_tlock_max_reg_i_3_O_UNCONNECTED;
  wire [3:0]\NLW_wait_bypass_count_reg[16]_i_1_CO_UNCONNECTED ;
  wire [3:1]\NLW_wait_bypass_count_reg[16]_i_1_O_UNCONNECTED ;

  LUT6 #(
    .INIT(64'hFFFF57FF00005700)) 
    CPLL_RESET_i_1
       (.I0(refclk_stable),
        .I1(CPLLREFCLKLOST),
        .I2(pll_reset_asserted_reg_n_0),
        .I3(CPLL_RESET_i_2_n_0),
        .I4(\FSM_sequential_tx_state[3]_i_4_n_0 ),
        .I5(CPLL_RESET),
        .O(CPLL_RESET_i_1_n_0));
  LUT2 #(
    .INIT(4'h2)) 
    CPLL_RESET_i_2
       (.I0(tx_state[0]),
        .I1(tx_state[3]),
        .O(CPLL_RESET_i_2_n_0));
  FDRE #(
    .INIT(1'b0)) 
    CPLL_RESET_reg
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(CPLL_RESET_i_1_n_0),
        .Q(CPLL_RESET),
        .R(pma_reset));
  LUT6 #(
    .INIT(64'h222A222A0000222A)) 
    \FSM_sequential_tx_state[0]_i_1 
       (.I0(\FSM_sequential_tx_state[0]_i_2_n_0 ),
        .I1(tx_state[3]),
        .I2(tx_state[1]),
        .I3(tx_state[2]),
        .I4(tx_state[0]),
        .I5(\FSM_sequential_tx_state[2]_i_2_n_0 ),
        .O(\FSM_sequential_tx_state[0]_i_1_n_0 ));
  LUT6 #(
    .INIT(64'h4F4FFFFFF000FFFF)) 
    \FSM_sequential_tx_state[0]_i_2 
       (.I0(reset_time_out),
        .I1(time_out_500us),
        .I2(tx_state[1]),
        .I3(time_out_2ms),
        .I4(tx_state[0]),
        .I5(tx_state[2]),
        .O(\FSM_sequential_tx_state[0]_i_2_n_0 ));
  LUT5 #(
    .INIT(32'h00002666)) 
    \FSM_sequential_tx_state[1]_i_1 
       (.I0(tx_state[1]),
        .I1(tx_state[0]),
        .I2(tx_state13_out),
        .I3(tx_state[2]),
        .I4(tx_state[3]),
        .O(\FSM_sequential_tx_state[1]_i_1_n_0 ));
  (* SOFT_HLUTNM = "soft_lutpair55" *) 
  LUT3 #(
    .INIT(8'h04)) 
    \FSM_sequential_tx_state[1]_i_2 
       (.I0(reset_time_out),
        .I1(time_tlock_max),
        .I2(mmcm_lock_reclocked),
        .O(tx_state13_out));
  LUT6 #(
    .INIT(64'h1100330011303300)) 
    \FSM_sequential_tx_state[2]_i_1 
       (.I0(\FSM_sequential_tx_state[2]_i_2_n_0 ),
        .I1(tx_state[3]),
        .I2(tx_state[1]),
        .I3(tx_state[2]),
        .I4(tx_state[0]),
        .I5(time_out_2ms),
        .O(\FSM_sequential_tx_state[2]_i_1_n_0 ));
  LUT4 #(
    .INIT(16'hAABA)) 
    \FSM_sequential_tx_state[2]_i_2 
       (.I0(tx_state[1]),
        .I1(mmcm_lock_reclocked),
        .I2(time_tlock_max),
        .I3(reset_time_out),
        .O(\FSM_sequential_tx_state[2]_i_2_n_0 ));
  LUT5 #(
    .INIT(32'h00073000)) 
    \FSM_sequential_tx_state[3]_i_2 
       (.I0(time_out_wait_bypass_s3),
        .I1(\FSM_sequential_tx_state[3]_i_5_n_0 ),
        .I2(tx_state[1]),
        .I3(tx_state[2]),
        .I4(tx_state[3]),
        .O(\FSM_sequential_tx_state[3]_i_2_n_0 ));
  LUT2 #(
    .INIT(4'hE)) 
    \FSM_sequential_tx_state[3]_i_4 
       (.I0(tx_state[2]),
        .I1(tx_state[1]),
        .O(\FSM_sequential_tx_state[3]_i_4_n_0 ));
  LUT3 #(
    .INIT(8'h4F)) 
    \FSM_sequential_tx_state[3]_i_5 
       (.I0(reset_time_out),
        .I1(time_out_500us),
        .I2(tx_state[0]),
        .O(\FSM_sequential_tx_state[3]_i_5_n_0 ));
  (* SOFT_HLUTNM = "soft_lutpair55" *) 
  LUT2 #(
    .INIT(4'h2)) 
    \FSM_sequential_tx_state[3]_i_7 
       (.I0(time_tlock_max),
        .I1(reset_time_out),
        .O(\FSM_sequential_tx_state[3]_i_7_n_0 ));
  (* KEEP = "yes" *) 
  FDRE \FSM_sequential_tx_state_reg[0] 
       (.C(independent_clock_bufg),
        .CE(sync_cplllock_n_1),
        .D(\FSM_sequential_tx_state[0]_i_1_n_0 ),
        .Q(tx_state[0]),
        .R(pma_reset));
  (* KEEP = "yes" *) 
  FDRE \FSM_sequential_tx_state_reg[1] 
       (.C(independent_clock_bufg),
        .CE(sync_cplllock_n_1),
        .D(\FSM_sequential_tx_state[1]_i_1_n_0 ),
        .Q(tx_state[1]),
        .R(pma_reset));
  (* KEEP = "yes" *) 
  FDRE \FSM_sequential_tx_state_reg[2] 
       (.C(independent_clock_bufg),
        .CE(sync_cplllock_n_1),
        .D(\FSM_sequential_tx_state[2]_i_1_n_0 ),
        .Q(tx_state[2]),
        .R(pma_reset));
  (* KEEP = "yes" *) 
  FDRE \FSM_sequential_tx_state_reg[3] 
       (.C(independent_clock_bufg),
        .CE(sync_cplllock_n_1),
        .D(\FSM_sequential_tx_state[3]_i_2_n_0 ),
        .Q(tx_state[3]),
        .R(pma_reset));
  LUT5 #(
    .INIT(32'hFFF70004)) 
    MMCM_RESET_i_1
       (.I0(tx_state[2]),
        .I1(tx_state[0]),
        .I2(tx_state[1]),
        .I3(tx_state[3]),
        .I4(mmcm_reset),
        .O(MMCM_RESET_i_1_n_0));
  FDRE #(
    .INIT(1'b1)) 
    MMCM_RESET_reg
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(MMCM_RESET_i_1_n_0),
        .Q(mmcm_reset),
        .R(pma_reset));
  LUT5 #(
    .INIT(32'hFFEF0080)) 
    TXUSERRDY_i_1
       (.I0(tx_state[2]),
        .I1(tx_state[1]),
        .I2(tx_state[0]),
        .I3(tx_state[3]),
        .I4(TXUSERRDY),
        .O(TXUSERRDY_i_1_n_0));
  FDRE #(
    .INIT(1'b0)) 
    TXUSERRDY_reg
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(TXUSERRDY_i_1_n_0),
        .Q(TXUSERRDY),
        .R(pma_reset));
  LUT3 #(
    .INIT(8'hEA)) 
    gthe2_i_i_4
       (.I0(GTTXRESET),
        .I1(data_in),
        .I2(reset_sync6),
        .O(gt0_gttxreset_in0_out));
  LUT5 #(
    .INIT(32'hFFFB0002)) 
    gttxreset_i_i_1
       (.I0(tx_state[0]),
        .I1(tx_state[2]),
        .I2(tx_state[1]),
        .I3(tx_state[3]),
        .I4(GTTXRESET),
        .O(gttxreset_i_i_1_n_0));
  FDRE #(
    .INIT(1'b0)) 
    gttxreset_i_reg
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(gttxreset_i_i_1_n_0),
        .Q(GTTXRESET),
        .R(pma_reset));
  (* SOFT_HLUTNM = "soft_lutpair49" *) 
  LUT1 #(
    .INIT(2'h1)) 
    \init_wait_count[0]_i_1 
       (.I0(init_wait_count_reg__0[0]),
        .O(\init_wait_count[0]_i_1_n_0 ));
  (* SOFT_HLUTNM = "soft_lutpair53" *) 
  LUT2 #(
    .INIT(4'h6)) 
    \init_wait_count[1]_i_1 
       (.I0(init_wait_count_reg__0[1]),
        .I1(init_wait_count_reg__0[0]),
        .O(p_0_in[1]));
  (* SOFT_HLUTNM = "soft_lutpair53" *) 
  LUT3 #(
    .INIT(8'h78)) 
    \init_wait_count[2]_i_1 
       (.I0(init_wait_count_reg__0[0]),
        .I1(init_wait_count_reg__0[1]),
        .I2(init_wait_count_reg__0[2]),
        .O(p_0_in[2]));
  (* SOFT_HLUTNM = "soft_lutpair48" *) 
  LUT4 #(
    .INIT(16'h6AAA)) 
    \init_wait_count[3]_i_1 
       (.I0(init_wait_count_reg__0[3]),
        .I1(init_wait_count_reg__0[2]),
        .I2(init_wait_count_reg__0[1]),
        .I3(init_wait_count_reg__0[0]),
        .O(p_0_in[3]));
  (* SOFT_HLUTNM = "soft_lutpair48" *) 
  LUT5 #(
    .INIT(32'h6AAAAAAA)) 
    \init_wait_count[4]_i_1 
       (.I0(init_wait_count_reg__0[4]),
        .I1(init_wait_count_reg__0[1]),
        .I2(init_wait_count_reg__0[2]),
        .I3(init_wait_count_reg__0[3]),
        .I4(init_wait_count_reg__0[0]),
        .O(p_0_in[4]));
  LUT6 #(
    .INIT(64'h7FFFFFFF80000000)) 
    \init_wait_count[5]_i_1 
       (.I0(init_wait_count_reg__0[0]),
        .I1(init_wait_count_reg__0[3]),
        .I2(init_wait_count_reg__0[2]),
        .I3(init_wait_count_reg__0[1]),
        .I4(init_wait_count_reg__0[4]),
        .I5(init_wait_count_reg__0[5]),
        .O(p_0_in[5]));
  LUT5 #(
    .INIT(32'hFFFFEFFF)) 
    \init_wait_count[6]_i_1 
       (.I0(\init_wait_count[6]_i_3_n_0 ),
        .I1(init_wait_count_reg__0[4]),
        .I2(init_wait_count_reg__0[6]),
        .I3(init_wait_count_reg__0[5]),
        .I4(init_wait_count_reg__0[0]),
        .O(init_wait_count));
  (* SOFT_HLUTNM = "soft_lutpair49" *) 
  LUT5 #(
    .INIT(32'hF7FF0800)) 
    \init_wait_count[6]_i_2 
       (.I0(init_wait_count_reg__0[5]),
        .I1(init_wait_count_reg__0[4]),
        .I2(\init_wait_count[6]_i_3_n_0 ),
        .I3(init_wait_count_reg__0[0]),
        .I4(init_wait_count_reg__0[6]),
        .O(p_0_in[6]));
  LUT3 #(
    .INIT(8'h7F)) 
    \init_wait_count[6]_i_3 
       (.I0(init_wait_count_reg__0[1]),
        .I1(init_wait_count_reg__0[2]),
        .I2(init_wait_count_reg__0[3]),
        .O(\init_wait_count[6]_i_3_n_0 ));
  FDCE #(
    .INIT(1'b0)) 
    \init_wait_count_reg[0] 
       (.C(independent_clock_bufg),
        .CE(init_wait_count),
        .CLR(pma_reset),
        .D(\init_wait_count[0]_i_1_n_0 ),
        .Q(init_wait_count_reg__0[0]));
  FDCE #(
    .INIT(1'b0)) 
    \init_wait_count_reg[1] 
       (.C(independent_clock_bufg),
        .CE(init_wait_count),
        .CLR(pma_reset),
        .D(p_0_in[1]),
        .Q(init_wait_count_reg__0[1]));
  FDCE #(
    .INIT(1'b0)) 
    \init_wait_count_reg[2] 
       (.C(independent_clock_bufg),
        .CE(init_wait_count),
        .CLR(pma_reset),
        .D(p_0_in[2]),
        .Q(init_wait_count_reg__0[2]));
  FDCE #(
    .INIT(1'b0)) 
    \init_wait_count_reg[3] 
       (.C(independent_clock_bufg),
        .CE(init_wait_count),
        .CLR(pma_reset),
        .D(p_0_in[3]),
        .Q(init_wait_count_reg__0[3]));
  FDCE #(
    .INIT(1'b0)) 
    \init_wait_count_reg[4] 
       (.C(independent_clock_bufg),
        .CE(init_wait_count),
        .CLR(pma_reset),
        .D(p_0_in[4]),
        .Q(init_wait_count_reg__0[4]));
  FDCE #(
    .INIT(1'b0)) 
    \init_wait_count_reg[5] 
       (.C(independent_clock_bufg),
        .CE(init_wait_count),
        .CLR(pma_reset),
        .D(p_0_in[5]),
        .Q(init_wait_count_reg__0[5]));
  FDCE #(
    .INIT(1'b0)) 
    \init_wait_count_reg[6] 
       (.C(independent_clock_bufg),
        .CE(init_wait_count),
        .CLR(pma_reset),
        .D(p_0_in[6]),
        .Q(init_wait_count_reg__0[6]));
  LUT6 #(
    .INIT(64'hFFFFFFFF01000000)) 
    init_wait_done_i_1
       (.I0(\init_wait_count[6]_i_3_n_0 ),
        .I1(init_wait_count_reg__0[4]),
        .I2(init_wait_count_reg__0[0]),
        .I3(init_wait_count_reg__0[6]),
        .I4(init_wait_count_reg__0[5]),
        .I5(init_wait_done_reg_n_0),
        .O(init_wait_done_i_1_n_0));
  FDCE #(
    .INIT(1'b0)) 
    init_wait_done_reg
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .CLR(pma_reset),
        .D(init_wait_done_i_1_n_0),
        .Q(init_wait_done_reg_n_0));
  LUT1 #(
    .INIT(2'h1)) 
    \mmcm_lock_count[0]_i_1 
       (.I0(mmcm_lock_count_reg__0[0]),
        .O(p_0_in__0[0]));
  (* SOFT_HLUTNM = "soft_lutpair54" *) 
  LUT2 #(
    .INIT(4'h6)) 
    \mmcm_lock_count[1]_i_1 
       (.I0(mmcm_lock_count_reg__0[0]),
        .I1(mmcm_lock_count_reg__0[1]),
        .O(p_0_in__0[1]));
  (* SOFT_HLUTNM = "soft_lutpair52" *) 
  LUT3 #(
    .INIT(8'h6A)) 
    \mmcm_lock_count[2]_i_1 
       (.I0(mmcm_lock_count_reg__0[2]),
        .I1(mmcm_lock_count_reg__0[1]),
        .I2(mmcm_lock_count_reg__0[0]),
        .O(p_0_in__0[2]));
  (* SOFT_HLUTNM = "soft_lutpair52" *) 
  LUT4 #(
    .INIT(16'h6AAA)) 
    \mmcm_lock_count[3]_i_1 
       (.I0(mmcm_lock_count_reg__0[3]),
        .I1(mmcm_lock_count_reg__0[0]),
        .I2(mmcm_lock_count_reg__0[1]),
        .I3(mmcm_lock_count_reg__0[2]),
        .O(p_0_in__0[3]));
  (* SOFT_HLUTNM = "soft_lutpair50" *) 
  LUT5 #(
    .INIT(32'h6AAAAAAA)) 
    \mmcm_lock_count[4]_i_1 
       (.I0(mmcm_lock_count_reg__0[4]),
        .I1(mmcm_lock_count_reg__0[3]),
        .I2(mmcm_lock_count_reg__0[0]),
        .I3(mmcm_lock_count_reg__0[1]),
        .I4(mmcm_lock_count_reg__0[2]),
        .O(p_0_in__0[4]));
  LUT6 #(
    .INIT(64'h6AAAAAAAAAAAAAAA)) 
    \mmcm_lock_count[5]_i_1 
       (.I0(mmcm_lock_count_reg__0[5]),
        .I1(mmcm_lock_count_reg__0[2]),
        .I2(mmcm_lock_count_reg__0[1]),
        .I3(mmcm_lock_count_reg__0[0]),
        .I4(mmcm_lock_count_reg__0[3]),
        .I5(mmcm_lock_count_reg__0[4]),
        .O(p_0_in__0[5]));
  LUT5 #(
    .INIT(32'h7FFF8000)) 
    \mmcm_lock_count[6]_i_1 
       (.I0(mmcm_lock_count_reg__0[4]),
        .I1(mmcm_lock_count_reg__0[3]),
        .I2(\mmcm_lock_count[7]_i_4_n_0 ),
        .I3(mmcm_lock_count_reg__0[5]),
        .I4(mmcm_lock_count_reg__0[6]),
        .O(p_0_in__0[6]));
  LUT6 #(
    .INIT(64'h7FFFFFFFFFFFFFFF)) 
    \mmcm_lock_count[7]_i_2 
       (.I0(mmcm_lock_count_reg__0[4]),
        .I1(mmcm_lock_count_reg__0[3]),
        .I2(\mmcm_lock_count[7]_i_4_n_0 ),
        .I3(mmcm_lock_count_reg__0[5]),
        .I4(mmcm_lock_count_reg__0[6]),
        .I5(mmcm_lock_count_reg__0[7]),
        .O(\mmcm_lock_count[7]_i_2_n_0 ));
  LUT6 #(
    .INIT(64'h7FFFFFFF80000000)) 
    \mmcm_lock_count[7]_i_3 
       (.I0(mmcm_lock_count_reg__0[6]),
        .I1(mmcm_lock_count_reg__0[5]),
        .I2(\mmcm_lock_count[7]_i_4_n_0 ),
        .I3(mmcm_lock_count_reg__0[3]),
        .I4(mmcm_lock_count_reg__0[4]),
        .I5(mmcm_lock_count_reg__0[7]),
        .O(p_0_in__0[7]));
  (* SOFT_HLUTNM = "soft_lutpair54" *) 
  LUT3 #(
    .INIT(8'h80)) 
    \mmcm_lock_count[7]_i_4 
       (.I0(mmcm_lock_count_reg__0[2]),
        .I1(mmcm_lock_count_reg__0[1]),
        .I2(mmcm_lock_count_reg__0[0]),
        .O(\mmcm_lock_count[7]_i_4_n_0 ));
  FDRE #(
    .INIT(1'b0)) 
    \mmcm_lock_count_reg[0] 
       (.C(independent_clock_bufg),
        .CE(\mmcm_lock_count[7]_i_2_n_0 ),
        .D(p_0_in__0[0]),
        .Q(mmcm_lock_count_reg__0[0]),
        .R(sync_mmcm_lock_reclocked_n_0));
  FDRE #(
    .INIT(1'b0)) 
    \mmcm_lock_count_reg[1] 
       (.C(independent_clock_bufg),
        .CE(\mmcm_lock_count[7]_i_2_n_0 ),
        .D(p_0_in__0[1]),
        .Q(mmcm_lock_count_reg__0[1]),
        .R(sync_mmcm_lock_reclocked_n_0));
  FDRE #(
    .INIT(1'b0)) 
    \mmcm_lock_count_reg[2] 
       (.C(independent_clock_bufg),
        .CE(\mmcm_lock_count[7]_i_2_n_0 ),
        .D(p_0_in__0[2]),
        .Q(mmcm_lock_count_reg__0[2]),
        .R(sync_mmcm_lock_reclocked_n_0));
  FDRE #(
    .INIT(1'b0)) 
    \mmcm_lock_count_reg[3] 
       (.C(independent_clock_bufg),
        .CE(\mmcm_lock_count[7]_i_2_n_0 ),
        .D(p_0_in__0[3]),
        .Q(mmcm_lock_count_reg__0[3]),
        .R(sync_mmcm_lock_reclocked_n_0));
  FDRE #(
    .INIT(1'b0)) 
    \mmcm_lock_count_reg[4] 
       (.C(independent_clock_bufg),
        .CE(\mmcm_lock_count[7]_i_2_n_0 ),
        .D(p_0_in__0[4]),
        .Q(mmcm_lock_count_reg__0[4]),
        .R(sync_mmcm_lock_reclocked_n_0));
  FDRE #(
    .INIT(1'b0)) 
    \mmcm_lock_count_reg[5] 
       (.C(independent_clock_bufg),
        .CE(\mmcm_lock_count[7]_i_2_n_0 ),
        .D(p_0_in__0[5]),
        .Q(mmcm_lock_count_reg__0[5]),
        .R(sync_mmcm_lock_reclocked_n_0));
  FDRE #(
    .INIT(1'b0)) 
    \mmcm_lock_count_reg[6] 
       (.C(independent_clock_bufg),
        .CE(\mmcm_lock_count[7]_i_2_n_0 ),
        .D(p_0_in__0[6]),
        .Q(mmcm_lock_count_reg__0[6]),
        .R(sync_mmcm_lock_reclocked_n_0));
  FDRE #(
    .INIT(1'b0)) 
    \mmcm_lock_count_reg[7] 
       (.C(independent_clock_bufg),
        .CE(\mmcm_lock_count[7]_i_2_n_0 ),
        .D(p_0_in__0[7]),
        .Q(mmcm_lock_count_reg__0[7]),
        .R(sync_mmcm_lock_reclocked_n_0));
  (* SOFT_HLUTNM = "soft_lutpair50" *) 
  LUT5 #(
    .INIT(32'h80000000)) 
    mmcm_lock_reclocked_i_2
       (.I0(mmcm_lock_count_reg__0[4]),
        .I1(mmcm_lock_count_reg__0[3]),
        .I2(mmcm_lock_count_reg__0[0]),
        .I3(mmcm_lock_count_reg__0[1]),
        .I4(mmcm_lock_count_reg__0[2]),
        .O(mmcm_lock_reclocked_i_2_n_0));
  FDRE #(
    .INIT(1'b0)) 
    mmcm_lock_reclocked_reg
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(sync_mmcm_lock_reclocked_n_1),
        .Q(mmcm_lock_reclocked),
        .R(1'b0));
  LUT6 #(
    .INIT(64'hEFFFEFFF00100000)) 
    pll_reset_asserted_i_1
       (.I0(tx_state[2]),
        .I1(tx_state[3]),
        .I2(tx_state[0]),
        .I3(tx_state[1]),
        .I4(CPLL_RESET0),
        .I5(pll_reset_asserted_reg_n_0),
        .O(pll_reset_asserted_i_1_n_0));
  LUT3 #(
    .INIT(8'h57)) 
    pll_reset_asserted_i_2
       (.I0(refclk_stable),
        .I1(CPLLREFCLKLOST),
        .I2(pll_reset_asserted_reg_n_0),
        .O(CPLL_RESET0));
  FDRE #(
    .INIT(1'b0)) 
    pll_reset_asserted_reg
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(pll_reset_asserted_i_1_n_0),
        .Q(pll_reset_asserted_reg_n_0),
        .R(pma_reset));
  LUT1 #(
    .INIT(2'h1)) 
    \refclk_stable_count[0]_i_1 
       (.I0(refclk_stable_reg_i_1_n_1),
        .O(\refclk_stable_count[0]_i_1_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \refclk_stable_count[0]_i_3 
       (.I0(refclk_stable_count_reg[3]),
        .O(\refclk_stable_count[0]_i_3_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \refclk_stable_count[0]_i_4 
       (.I0(refclk_stable_count_reg[2]),
        .O(\refclk_stable_count[0]_i_4_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \refclk_stable_count[0]_i_5 
       (.I0(refclk_stable_count_reg[1]),
        .O(\refclk_stable_count[0]_i_5_n_0 ));
  LUT1 #(
    .INIT(2'h1)) 
    \refclk_stable_count[0]_i_6 
       (.I0(refclk_stable_count_reg[0]),
        .O(\refclk_stable_count[0]_i_6_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \refclk_stable_count[12]_i_2 
       (.I0(refclk_stable_count_reg[15]),
        .O(\refclk_stable_count[12]_i_2_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \refclk_stable_count[12]_i_3 
       (.I0(refclk_stable_count_reg[14]),
        .O(\refclk_stable_count[12]_i_3_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \refclk_stable_count[12]_i_4 
       (.I0(refclk_stable_count_reg[13]),
        .O(\refclk_stable_count[12]_i_4_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \refclk_stable_count[12]_i_5 
       (.I0(refclk_stable_count_reg[12]),
        .O(\refclk_stable_count[12]_i_5_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \refclk_stable_count[16]_i_2 
       (.I0(refclk_stable_count_reg[19]),
        .O(\refclk_stable_count[16]_i_2_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \refclk_stable_count[16]_i_3 
       (.I0(refclk_stable_count_reg[18]),
        .O(\refclk_stable_count[16]_i_3_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \refclk_stable_count[16]_i_4 
       (.I0(refclk_stable_count_reg[17]),
        .O(\refclk_stable_count[16]_i_4_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \refclk_stable_count[16]_i_5 
       (.I0(refclk_stable_count_reg[16]),
        .O(\refclk_stable_count[16]_i_5_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \refclk_stable_count[20]_i_2 
       (.I0(refclk_stable_count_reg[23]),
        .O(\refclk_stable_count[20]_i_2_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \refclk_stable_count[20]_i_3 
       (.I0(refclk_stable_count_reg[22]),
        .O(\refclk_stable_count[20]_i_3_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \refclk_stable_count[20]_i_4 
       (.I0(refclk_stable_count_reg[21]),
        .O(\refclk_stable_count[20]_i_4_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \refclk_stable_count[20]_i_5 
       (.I0(refclk_stable_count_reg[20]),
        .O(\refclk_stable_count[20]_i_5_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \refclk_stable_count[24]_i_2 
       (.I0(refclk_stable_count_reg[27]),
        .O(\refclk_stable_count[24]_i_2_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \refclk_stable_count[24]_i_3 
       (.I0(refclk_stable_count_reg[26]),
        .O(\refclk_stable_count[24]_i_3_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \refclk_stable_count[24]_i_4 
       (.I0(refclk_stable_count_reg[25]),
        .O(\refclk_stable_count[24]_i_4_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \refclk_stable_count[24]_i_5 
       (.I0(refclk_stable_count_reg[24]),
        .O(\refclk_stable_count[24]_i_5_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \refclk_stable_count[28]_i_2 
       (.I0(refclk_stable_count_reg[31]),
        .O(\refclk_stable_count[28]_i_2_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \refclk_stable_count[28]_i_3 
       (.I0(refclk_stable_count_reg[30]),
        .O(\refclk_stable_count[28]_i_3_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \refclk_stable_count[28]_i_4 
       (.I0(refclk_stable_count_reg[29]),
        .O(\refclk_stable_count[28]_i_4_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \refclk_stable_count[28]_i_5 
       (.I0(refclk_stable_count_reg[28]),
        .O(\refclk_stable_count[28]_i_5_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \refclk_stable_count[4]_i_2 
       (.I0(refclk_stable_count_reg[7]),
        .O(\refclk_stable_count[4]_i_2_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \refclk_stable_count[4]_i_3 
       (.I0(refclk_stable_count_reg[6]),
        .O(\refclk_stable_count[4]_i_3_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \refclk_stable_count[4]_i_4 
       (.I0(refclk_stable_count_reg[5]),
        .O(\refclk_stable_count[4]_i_4_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \refclk_stable_count[4]_i_5 
       (.I0(refclk_stable_count_reg[4]),
        .O(\refclk_stable_count[4]_i_5_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \refclk_stable_count[8]_i_2 
       (.I0(refclk_stable_count_reg[11]),
        .O(\refclk_stable_count[8]_i_2_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \refclk_stable_count[8]_i_3 
       (.I0(refclk_stable_count_reg[10]),
        .O(\refclk_stable_count[8]_i_3_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \refclk_stable_count[8]_i_4 
       (.I0(refclk_stable_count_reg[9]),
        .O(\refclk_stable_count[8]_i_4_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \refclk_stable_count[8]_i_5 
       (.I0(refclk_stable_count_reg[8]),
        .O(\refclk_stable_count[8]_i_5_n_0 ));
  FDRE #(
    .INIT(1'b0)) 
    \refclk_stable_count_reg[0] 
       (.C(independent_clock_bufg),
        .CE(\refclk_stable_count[0]_i_1_n_0 ),
        .D(\refclk_stable_count_reg[0]_i_2_n_7 ),
        .Q(refclk_stable_count_reg[0]),
        .R(1'b0));
  CARRY4 \refclk_stable_count_reg[0]_i_2 
       (.CI(1'b0),
        .CO({\refclk_stable_count_reg[0]_i_2_n_0 ,\refclk_stable_count_reg[0]_i_2_n_1 ,\refclk_stable_count_reg[0]_i_2_n_2 ,\refclk_stable_count_reg[0]_i_2_n_3 }),
        .CYINIT(1'b0),
        .DI({1'b0,1'b0,1'b0,1'b1}),
        .O({\refclk_stable_count_reg[0]_i_2_n_4 ,\refclk_stable_count_reg[0]_i_2_n_5 ,\refclk_stable_count_reg[0]_i_2_n_6 ,\refclk_stable_count_reg[0]_i_2_n_7 }),
        .S({\refclk_stable_count[0]_i_3_n_0 ,\refclk_stable_count[0]_i_4_n_0 ,\refclk_stable_count[0]_i_5_n_0 ,\refclk_stable_count[0]_i_6_n_0 }));
  FDRE #(
    .INIT(1'b0)) 
    \refclk_stable_count_reg[10] 
       (.C(independent_clock_bufg),
        .CE(\refclk_stable_count[0]_i_1_n_0 ),
        .D(\refclk_stable_count_reg[8]_i_1_n_5 ),
        .Q(refclk_stable_count_reg[10]),
        .R(1'b0));
  FDRE #(
    .INIT(1'b0)) 
    \refclk_stable_count_reg[11] 
       (.C(independent_clock_bufg),
        .CE(\refclk_stable_count[0]_i_1_n_0 ),
        .D(\refclk_stable_count_reg[8]_i_1_n_4 ),
        .Q(refclk_stable_count_reg[11]),
        .R(1'b0));
  FDRE #(
    .INIT(1'b0)) 
    \refclk_stable_count_reg[12] 
       (.C(independent_clock_bufg),
        .CE(\refclk_stable_count[0]_i_1_n_0 ),
        .D(\refclk_stable_count_reg[12]_i_1_n_7 ),
        .Q(refclk_stable_count_reg[12]),
        .R(1'b0));
  CARRY4 \refclk_stable_count_reg[12]_i_1 
       (.CI(\refclk_stable_count_reg[8]_i_1_n_0 ),
        .CO({\refclk_stable_count_reg[12]_i_1_n_0 ,\refclk_stable_count_reg[12]_i_1_n_1 ,\refclk_stable_count_reg[12]_i_1_n_2 ,\refclk_stable_count_reg[12]_i_1_n_3 }),
        .CYINIT(1'b0),
        .DI({1'b0,1'b0,1'b0,1'b0}),
        .O({\refclk_stable_count_reg[12]_i_1_n_4 ,\refclk_stable_count_reg[12]_i_1_n_5 ,\refclk_stable_count_reg[12]_i_1_n_6 ,\refclk_stable_count_reg[12]_i_1_n_7 }),
        .S({\refclk_stable_count[12]_i_2_n_0 ,\refclk_stable_count[12]_i_3_n_0 ,\refclk_stable_count[12]_i_4_n_0 ,\refclk_stable_count[12]_i_5_n_0 }));
  FDRE #(
    .INIT(1'b0)) 
    \refclk_stable_count_reg[13] 
       (.C(independent_clock_bufg),
        .CE(\refclk_stable_count[0]_i_1_n_0 ),
        .D(\refclk_stable_count_reg[12]_i_1_n_6 ),
        .Q(refclk_stable_count_reg[13]),
        .R(1'b0));
  FDRE #(
    .INIT(1'b0)) 
    \refclk_stable_count_reg[14] 
       (.C(independent_clock_bufg),
        .CE(\refclk_stable_count[0]_i_1_n_0 ),
        .D(\refclk_stable_count_reg[12]_i_1_n_5 ),
        .Q(refclk_stable_count_reg[14]),
        .R(1'b0));
  FDRE #(
    .INIT(1'b0)) 
    \refclk_stable_count_reg[15] 
       (.C(independent_clock_bufg),
        .CE(\refclk_stable_count[0]_i_1_n_0 ),
        .D(\refclk_stable_count_reg[12]_i_1_n_4 ),
        .Q(refclk_stable_count_reg[15]),
        .R(1'b0));
  FDRE #(
    .INIT(1'b0)) 
    \refclk_stable_count_reg[16] 
       (.C(independent_clock_bufg),
        .CE(\refclk_stable_count[0]_i_1_n_0 ),
        .D(\refclk_stable_count_reg[16]_i_1_n_7 ),
        .Q(refclk_stable_count_reg[16]),
        .R(1'b0));
  CARRY4 \refclk_stable_count_reg[16]_i_1 
       (.CI(\refclk_stable_count_reg[12]_i_1_n_0 ),
        .CO({\refclk_stable_count_reg[16]_i_1_n_0 ,\refclk_stable_count_reg[16]_i_1_n_1 ,\refclk_stable_count_reg[16]_i_1_n_2 ,\refclk_stable_count_reg[16]_i_1_n_3 }),
        .CYINIT(1'b0),
        .DI({1'b0,1'b0,1'b0,1'b0}),
        .O({\refclk_stable_count_reg[16]_i_1_n_4 ,\refclk_stable_count_reg[16]_i_1_n_5 ,\refclk_stable_count_reg[16]_i_1_n_6 ,\refclk_stable_count_reg[16]_i_1_n_7 }),
        .S({\refclk_stable_count[16]_i_2_n_0 ,\refclk_stable_count[16]_i_3_n_0 ,\refclk_stable_count[16]_i_4_n_0 ,\refclk_stable_count[16]_i_5_n_0 }));
  FDRE #(
    .INIT(1'b0)) 
    \refclk_stable_count_reg[17] 
       (.C(independent_clock_bufg),
        .CE(\refclk_stable_count[0]_i_1_n_0 ),
        .D(\refclk_stable_count_reg[16]_i_1_n_6 ),
        .Q(refclk_stable_count_reg[17]),
        .R(1'b0));
  FDRE #(
    .INIT(1'b0)) 
    \refclk_stable_count_reg[18] 
       (.C(independent_clock_bufg),
        .CE(\refclk_stable_count[0]_i_1_n_0 ),
        .D(\refclk_stable_count_reg[16]_i_1_n_5 ),
        .Q(refclk_stable_count_reg[18]),
        .R(1'b0));
  FDRE #(
    .INIT(1'b0)) 
    \refclk_stable_count_reg[19] 
       (.C(independent_clock_bufg),
        .CE(\refclk_stable_count[0]_i_1_n_0 ),
        .D(\refclk_stable_count_reg[16]_i_1_n_4 ),
        .Q(refclk_stable_count_reg[19]),
        .R(1'b0));
  FDRE #(
    .INIT(1'b0)) 
    \refclk_stable_count_reg[1] 
       (.C(independent_clock_bufg),
        .CE(\refclk_stable_count[0]_i_1_n_0 ),
        .D(\refclk_stable_count_reg[0]_i_2_n_6 ),
        .Q(refclk_stable_count_reg[1]),
        .R(1'b0));
  FDRE #(
    .INIT(1'b0)) 
    \refclk_stable_count_reg[20] 
       (.C(independent_clock_bufg),
        .CE(\refclk_stable_count[0]_i_1_n_0 ),
        .D(\refclk_stable_count_reg[20]_i_1_n_7 ),
        .Q(refclk_stable_count_reg[20]),
        .R(1'b0));
  CARRY4 \refclk_stable_count_reg[20]_i_1 
       (.CI(\refclk_stable_count_reg[16]_i_1_n_0 ),
        .CO({\refclk_stable_count_reg[20]_i_1_n_0 ,\refclk_stable_count_reg[20]_i_1_n_1 ,\refclk_stable_count_reg[20]_i_1_n_2 ,\refclk_stable_count_reg[20]_i_1_n_3 }),
        .CYINIT(1'b0),
        .DI({1'b0,1'b0,1'b0,1'b0}),
        .O({\refclk_stable_count_reg[20]_i_1_n_4 ,\refclk_stable_count_reg[20]_i_1_n_5 ,\refclk_stable_count_reg[20]_i_1_n_6 ,\refclk_stable_count_reg[20]_i_1_n_7 }),
        .S({\refclk_stable_count[20]_i_2_n_0 ,\refclk_stable_count[20]_i_3_n_0 ,\refclk_stable_count[20]_i_4_n_0 ,\refclk_stable_count[20]_i_5_n_0 }));
  FDRE #(
    .INIT(1'b0)) 
    \refclk_stable_count_reg[21] 
       (.C(independent_clock_bufg),
        .CE(\refclk_stable_count[0]_i_1_n_0 ),
        .D(\refclk_stable_count_reg[20]_i_1_n_6 ),
        .Q(refclk_stable_count_reg[21]),
        .R(1'b0));
  FDRE #(
    .INIT(1'b0)) 
    \refclk_stable_count_reg[22] 
       (.C(independent_clock_bufg),
        .CE(\refclk_stable_count[0]_i_1_n_0 ),
        .D(\refclk_stable_count_reg[20]_i_1_n_5 ),
        .Q(refclk_stable_count_reg[22]),
        .R(1'b0));
  FDRE #(
    .INIT(1'b0)) 
    \refclk_stable_count_reg[23] 
       (.C(independent_clock_bufg),
        .CE(\refclk_stable_count[0]_i_1_n_0 ),
        .D(\refclk_stable_count_reg[20]_i_1_n_4 ),
        .Q(refclk_stable_count_reg[23]),
        .R(1'b0));
  FDRE #(
    .INIT(1'b0)) 
    \refclk_stable_count_reg[24] 
       (.C(independent_clock_bufg),
        .CE(\refclk_stable_count[0]_i_1_n_0 ),
        .D(\refclk_stable_count_reg[24]_i_1_n_7 ),
        .Q(refclk_stable_count_reg[24]),
        .R(1'b0));
  CARRY4 \refclk_stable_count_reg[24]_i_1 
       (.CI(\refclk_stable_count_reg[20]_i_1_n_0 ),
        .CO({\refclk_stable_count_reg[24]_i_1_n_0 ,\refclk_stable_count_reg[24]_i_1_n_1 ,\refclk_stable_count_reg[24]_i_1_n_2 ,\refclk_stable_count_reg[24]_i_1_n_3 }),
        .CYINIT(1'b0),
        .DI({1'b0,1'b0,1'b0,1'b0}),
        .O({\refclk_stable_count_reg[24]_i_1_n_4 ,\refclk_stable_count_reg[24]_i_1_n_5 ,\refclk_stable_count_reg[24]_i_1_n_6 ,\refclk_stable_count_reg[24]_i_1_n_7 }),
        .S({\refclk_stable_count[24]_i_2_n_0 ,\refclk_stable_count[24]_i_3_n_0 ,\refclk_stable_count[24]_i_4_n_0 ,\refclk_stable_count[24]_i_5_n_0 }));
  FDRE #(
    .INIT(1'b0)) 
    \refclk_stable_count_reg[25] 
       (.C(independent_clock_bufg),
        .CE(\refclk_stable_count[0]_i_1_n_0 ),
        .D(\refclk_stable_count_reg[24]_i_1_n_6 ),
        .Q(refclk_stable_count_reg[25]),
        .R(1'b0));
  FDRE #(
    .INIT(1'b0)) 
    \refclk_stable_count_reg[26] 
       (.C(independent_clock_bufg),
        .CE(\refclk_stable_count[0]_i_1_n_0 ),
        .D(\refclk_stable_count_reg[24]_i_1_n_5 ),
        .Q(refclk_stable_count_reg[26]),
        .R(1'b0));
  FDRE #(
    .INIT(1'b0)) 
    \refclk_stable_count_reg[27] 
       (.C(independent_clock_bufg),
        .CE(\refclk_stable_count[0]_i_1_n_0 ),
        .D(\refclk_stable_count_reg[24]_i_1_n_4 ),
        .Q(refclk_stable_count_reg[27]),
        .R(1'b0));
  FDRE #(
    .INIT(1'b0)) 
    \refclk_stable_count_reg[28] 
       (.C(independent_clock_bufg),
        .CE(\refclk_stable_count[0]_i_1_n_0 ),
        .D(\refclk_stable_count_reg[28]_i_1_n_7 ),
        .Q(refclk_stable_count_reg[28]),
        .R(1'b0));
  CARRY4 \refclk_stable_count_reg[28]_i_1 
       (.CI(\refclk_stable_count_reg[24]_i_1_n_0 ),
        .CO({\NLW_refclk_stable_count_reg[28]_i_1_CO_UNCONNECTED [3],\refclk_stable_count_reg[28]_i_1_n_1 ,\refclk_stable_count_reg[28]_i_1_n_2 ,\refclk_stable_count_reg[28]_i_1_n_3 }),
        .CYINIT(1'b0),
        .DI({1'b0,1'b0,1'b0,1'b0}),
        .O({\refclk_stable_count_reg[28]_i_1_n_4 ,\refclk_stable_count_reg[28]_i_1_n_5 ,\refclk_stable_count_reg[28]_i_1_n_6 ,\refclk_stable_count_reg[28]_i_1_n_7 }),
        .S({\refclk_stable_count[28]_i_2_n_0 ,\refclk_stable_count[28]_i_3_n_0 ,\refclk_stable_count[28]_i_4_n_0 ,\refclk_stable_count[28]_i_5_n_0 }));
  FDRE #(
    .INIT(1'b0)) 
    \refclk_stable_count_reg[29] 
       (.C(independent_clock_bufg),
        .CE(\refclk_stable_count[0]_i_1_n_0 ),
        .D(\refclk_stable_count_reg[28]_i_1_n_6 ),
        .Q(refclk_stable_count_reg[29]),
        .R(1'b0));
  FDRE #(
    .INIT(1'b0)) 
    \refclk_stable_count_reg[2] 
       (.C(independent_clock_bufg),
        .CE(\refclk_stable_count[0]_i_1_n_0 ),
        .D(\refclk_stable_count_reg[0]_i_2_n_5 ),
        .Q(refclk_stable_count_reg[2]),
        .R(1'b0));
  FDRE #(
    .INIT(1'b0)) 
    \refclk_stable_count_reg[30] 
       (.C(independent_clock_bufg),
        .CE(\refclk_stable_count[0]_i_1_n_0 ),
        .D(\refclk_stable_count_reg[28]_i_1_n_5 ),
        .Q(refclk_stable_count_reg[30]),
        .R(1'b0));
  FDRE #(
    .INIT(1'b0)) 
    \refclk_stable_count_reg[31] 
       (.C(independent_clock_bufg),
        .CE(\refclk_stable_count[0]_i_1_n_0 ),
        .D(\refclk_stable_count_reg[28]_i_1_n_4 ),
        .Q(refclk_stable_count_reg[31]),
        .R(1'b0));
  FDRE #(
    .INIT(1'b0)) 
    \refclk_stable_count_reg[3] 
       (.C(independent_clock_bufg),
        .CE(\refclk_stable_count[0]_i_1_n_0 ),
        .D(\refclk_stable_count_reg[0]_i_2_n_4 ),
        .Q(refclk_stable_count_reg[3]),
        .R(1'b0));
  FDRE #(
    .INIT(1'b0)) 
    \refclk_stable_count_reg[4] 
       (.C(independent_clock_bufg),
        .CE(\refclk_stable_count[0]_i_1_n_0 ),
        .D(\refclk_stable_count_reg[4]_i_1_n_7 ),
        .Q(refclk_stable_count_reg[4]),
        .R(1'b0));
  CARRY4 \refclk_stable_count_reg[4]_i_1 
       (.CI(\refclk_stable_count_reg[0]_i_2_n_0 ),
        .CO({\refclk_stable_count_reg[4]_i_1_n_0 ,\refclk_stable_count_reg[4]_i_1_n_1 ,\refclk_stable_count_reg[4]_i_1_n_2 ,\refclk_stable_count_reg[4]_i_1_n_3 }),
        .CYINIT(1'b0),
        .DI({1'b0,1'b0,1'b0,1'b0}),
        .O({\refclk_stable_count_reg[4]_i_1_n_4 ,\refclk_stable_count_reg[4]_i_1_n_5 ,\refclk_stable_count_reg[4]_i_1_n_6 ,\refclk_stable_count_reg[4]_i_1_n_7 }),
        .S({\refclk_stable_count[4]_i_2_n_0 ,\refclk_stable_count[4]_i_3_n_0 ,\refclk_stable_count[4]_i_4_n_0 ,\refclk_stable_count[4]_i_5_n_0 }));
  FDRE #(
    .INIT(1'b0)) 
    \refclk_stable_count_reg[5] 
       (.C(independent_clock_bufg),
        .CE(\refclk_stable_count[0]_i_1_n_0 ),
        .D(\refclk_stable_count_reg[4]_i_1_n_6 ),
        .Q(refclk_stable_count_reg[5]),
        .R(1'b0));
  FDRE #(
    .INIT(1'b0)) 
    \refclk_stable_count_reg[6] 
       (.C(independent_clock_bufg),
        .CE(\refclk_stable_count[0]_i_1_n_0 ),
        .D(\refclk_stable_count_reg[4]_i_1_n_5 ),
        .Q(refclk_stable_count_reg[6]),
        .R(1'b0));
  FDRE #(
    .INIT(1'b0)) 
    \refclk_stable_count_reg[7] 
       (.C(independent_clock_bufg),
        .CE(\refclk_stable_count[0]_i_1_n_0 ),
        .D(\refclk_stable_count_reg[4]_i_1_n_4 ),
        .Q(refclk_stable_count_reg[7]),
        .R(1'b0));
  FDRE #(
    .INIT(1'b0)) 
    \refclk_stable_count_reg[8] 
       (.C(independent_clock_bufg),
        .CE(\refclk_stable_count[0]_i_1_n_0 ),
        .D(\refclk_stable_count_reg[8]_i_1_n_7 ),
        .Q(refclk_stable_count_reg[8]),
        .R(1'b0));
  CARRY4 \refclk_stable_count_reg[8]_i_1 
       (.CI(\refclk_stable_count_reg[4]_i_1_n_0 ),
        .CO({\refclk_stable_count_reg[8]_i_1_n_0 ,\refclk_stable_count_reg[8]_i_1_n_1 ,\refclk_stable_count_reg[8]_i_1_n_2 ,\refclk_stable_count_reg[8]_i_1_n_3 }),
        .CYINIT(1'b0),
        .DI({1'b0,1'b0,1'b0,1'b0}),
        .O({\refclk_stable_count_reg[8]_i_1_n_4 ,\refclk_stable_count_reg[8]_i_1_n_5 ,\refclk_stable_count_reg[8]_i_1_n_6 ,\refclk_stable_count_reg[8]_i_1_n_7 }),
        .S({\refclk_stable_count[8]_i_2_n_0 ,\refclk_stable_count[8]_i_3_n_0 ,\refclk_stable_count[8]_i_4_n_0 ,\refclk_stable_count[8]_i_5_n_0 }));
  FDRE #(
    .INIT(1'b0)) 
    \refclk_stable_count_reg[9] 
       (.C(independent_clock_bufg),
        .CE(\refclk_stable_count[0]_i_1_n_0 ),
        .D(\refclk_stable_count_reg[8]_i_1_n_6 ),
        .Q(refclk_stable_count_reg[9]),
        .R(1'b0));
  LUT3 #(
    .INIT(8'h04)) 
    refclk_stable_i_10
       (.I0(refclk_stable_count_reg[14]),
        .I1(refclk_stable_count_reg[13]),
        .I2(refclk_stable_count_reg[12]),
        .O(refclk_stable_i_10_n_0));
  LUT3 #(
    .INIT(8'h40)) 
    refclk_stable_i_11
       (.I0(refclk_stable_count_reg[11]),
        .I1(refclk_stable_count_reg[10]),
        .I2(refclk_stable_count_reg[9]),
        .O(refclk_stable_i_11_n_0));
  LUT3 #(
    .INIT(8'h80)) 
    refclk_stable_i_12
       (.I0(refclk_stable_count_reg[8]),
        .I1(refclk_stable_count_reg[7]),
        .I2(refclk_stable_count_reg[6]),
        .O(refclk_stable_i_12_n_0));
  LUT3 #(
    .INIT(8'h01)) 
    refclk_stable_i_13
       (.I0(refclk_stable_count_reg[5]),
        .I1(refclk_stable_count_reg[4]),
        .I2(refclk_stable_count_reg[3]),
        .O(refclk_stable_i_13_n_0));
  LUT3 #(
    .INIT(8'h01)) 
    refclk_stable_i_14
       (.I0(refclk_stable_count_reg[2]),
        .I1(refclk_stable_count_reg[1]),
        .I2(refclk_stable_count_reg[0]),
        .O(refclk_stable_i_14_n_0));
  LUT2 #(
    .INIT(4'h1)) 
    refclk_stable_i_3
       (.I0(refclk_stable_count_reg[31]),
        .I1(refclk_stable_count_reg[30]),
        .O(refclk_stable_i_3_n_0));
  LUT3 #(
    .INIT(8'h01)) 
    refclk_stable_i_4
       (.I0(refclk_stable_count_reg[29]),
        .I1(refclk_stable_count_reg[28]),
        .I2(refclk_stable_count_reg[27]),
        .O(refclk_stable_i_4_n_0));
  LUT3 #(
    .INIT(8'h01)) 
    refclk_stable_i_5
       (.I0(refclk_stable_count_reg[26]),
        .I1(refclk_stable_count_reg[25]),
        .I2(refclk_stable_count_reg[24]),
        .O(refclk_stable_i_5_n_0));
  LUT3 #(
    .INIT(8'h01)) 
    refclk_stable_i_7
       (.I0(refclk_stable_count_reg[23]),
        .I1(refclk_stable_count_reg[22]),
        .I2(refclk_stable_count_reg[21]),
        .O(refclk_stable_i_7_n_0));
  LUT3 #(
    .INIT(8'h04)) 
    refclk_stable_i_8
       (.I0(refclk_stable_count_reg[20]),
        .I1(refclk_stable_count_reg[19]),
        .I2(refclk_stable_count_reg[18]),
        .O(refclk_stable_i_8_n_0));
  LUT3 #(
    .INIT(8'h04)) 
    refclk_stable_i_9
       (.I0(refclk_stable_count_reg[17]),
        .I1(refclk_stable_count_reg[16]),
        .I2(refclk_stable_count_reg[15]),
        .O(refclk_stable_i_9_n_0));
  FDRE #(
    .INIT(1'b0)) 
    refclk_stable_reg
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(refclk_stable_reg_i_1_n_1),
        .Q(refclk_stable),
        .R(1'b0));
  CARRY4 refclk_stable_reg_i_1
       (.CI(refclk_stable_reg_i_2_n_0),
        .CO({NLW_refclk_stable_reg_i_1_CO_UNCONNECTED[3],refclk_stable_reg_i_1_n_1,refclk_stable_reg_i_1_n_2,refclk_stable_reg_i_1_n_3}),
        .CYINIT(1'b0),
        .DI({1'b0,1'b0,1'b0,1'b0}),
        .O(NLW_refclk_stable_reg_i_1_O_UNCONNECTED[3:0]),
        .S({1'b0,refclk_stable_i_3_n_0,refclk_stable_i_4_n_0,refclk_stable_i_5_n_0}));
  CARRY4 refclk_stable_reg_i_2
       (.CI(refclk_stable_reg_i_6_n_0),
        .CO({refclk_stable_reg_i_2_n_0,refclk_stable_reg_i_2_n_1,refclk_stable_reg_i_2_n_2,refclk_stable_reg_i_2_n_3}),
        .CYINIT(1'b0),
        .DI({1'b0,1'b0,1'b0,1'b0}),
        .O(NLW_refclk_stable_reg_i_2_O_UNCONNECTED[3:0]),
        .S({refclk_stable_i_7_n_0,refclk_stable_i_8_n_0,refclk_stable_i_9_n_0,refclk_stable_i_10_n_0}));
  CARRY4 refclk_stable_reg_i_6
       (.CI(1'b0),
        .CO({refclk_stable_reg_i_6_n_0,refclk_stable_reg_i_6_n_1,refclk_stable_reg_i_6_n_2,refclk_stable_reg_i_6_n_3}),
        .CYINIT(1'b1),
        .DI({1'b0,1'b0,1'b0,1'b0}),
        .O(NLW_refclk_stable_reg_i_6_O_UNCONNECTED[3:0]),
        .S({refclk_stable_i_11_n_0,refclk_stable_i_12_n_0,refclk_stable_i_13_n_0,refclk_stable_i_14_n_0}));
  LUT3 #(
    .INIT(8'h70)) 
    reset_time_out_i_3
       (.I0(tx_state[3]),
        .I1(tx_state[2]),
        .I2(tx_state[0]),
        .O(reset_time_out_i_3_n_0));
  FDRE #(
    .INIT(1'b0)) 
    reset_time_out_reg
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(sync_cplllock_n_0),
        .Q(reset_time_out),
        .R(pma_reset));
  LUT5 #(
    .INIT(32'hFFFD0004)) 
    run_phase_alignment_int_i_1
       (.I0(tx_state[0]),
        .I1(tx_state[3]),
        .I2(tx_state[1]),
        .I3(tx_state[2]),
        .I4(run_phase_alignment_int_reg_n_0),
        .O(run_phase_alignment_int_i_1_n_0));
  FDRE #(
    .INIT(1'b0)) 
    run_phase_alignment_int_reg
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(run_phase_alignment_int_i_1_n_0),
        .Q(run_phase_alignment_int_reg_n_0),
        .R(pma_reset));
  FDRE #(
    .INIT(1'b0)) 
    run_phase_alignment_int_s3_reg
       (.C(userclk),
        .CE(1'b1),
        .D(data_out),
        .Q(run_phase_alignment_int_s3),
        .R(1'b0));
  GigEthGth7Core_GigEthGth7Core_sync_block_8 sync_TXRESETDONE
       (.\cpllpd_wait_reg[95] (\cpllpd_wait_reg[95] ),
        .data_out(txresetdone_s2),
        .independent_clock_bufg(independent_clock_bufg));
  GigEthGth7Core_GigEthGth7Core_sync_block_9 sync_cplllock
       (.E(sync_cplllock_n_1),
        .\FSM_sequential_tx_state_reg[2] (\FSM_sequential_tx_state[3]_i_4_n_0 ),
        .\FSM_sequential_tx_state_reg[3] (reset_time_out_i_3_n_0),
        .cplllock(cplllock),
        .independent_clock_bufg(independent_clock_bufg),
        .init_wait_done_reg(init_wait_done_reg_n_0),
        .mmcm_lock_reclocked(mmcm_lock_reclocked),
        .out(tx_state),
        .pll_reset_asserted_reg(pll_reset_asserted_reg_n_0),
        .refclk_stable(refclk_stable),
        .reset_time_out(reset_time_out),
        .reset_time_out_reg(sync_cplllock_n_0),
        .time_out_2ms(time_out_2ms),
        .time_out_500us(time_out_500us),
        .time_tlock_max_reg(\FSM_sequential_tx_state[3]_i_7_n_0 ),
        .txresetdone_s3(txresetdone_s3),
        .\wait_time_cnt_reg[6] (\wait_time_cnt[6]_i_2_n_0 ));
  GigEthGth7Core_GigEthGth7Core_sync_block_10 sync_mmcm_lock_reclocked
       (.Q(mmcm_lock_count_reg__0[7:5]),
        .SR(sync_mmcm_lock_reclocked_n_0),
        .independent_clock_bufg(independent_clock_bufg),
        .\mmcm_lock_count_reg[4] (mmcm_lock_reclocked_i_2_n_0),
        .mmcm_lock_reclocked(mmcm_lock_reclocked),
        .mmcm_lock_reclocked_reg(sync_mmcm_lock_reclocked_n_1),
        .mmcm_locked(mmcm_locked));
  GigEthGth7Core_GigEthGth7Core_sync_block_11 sync_run_phase_alignment_int
       (.data_in(run_phase_alignment_int_reg_n_0),
        .data_out(data_out),
        .userclk(userclk));
  GigEthGth7Core_GigEthGth7Core_sync_block_12 sync_time_out_wait_bypass
       (.data_in(time_out_wait_bypass_reg_n_0),
        .data_out(time_out_wait_bypass_s2),
        .independent_clock_bufg(independent_clock_bufg));
  GigEthGth7Core_GigEthGth7Core_sync_block_13 sync_tx_fsm_reset_done_int
       (.data_in(data_in),
        .data_out(tx_fsm_reset_done_int_s2),
        .userclk(userclk));
  (* SOFT_HLUTNM = "soft_lutpair56" *) 
  LUT3 #(
    .INIT(8'h0E)) 
    time_out_2ms_i_1
       (.I0(time_out_2ms),
        .I1(\time_out_counter_reg[0]_i_3_n_1 ),
        .I2(reset_time_out),
        .O(time_out_2ms_i_1_n_0));
  FDRE #(
    .INIT(1'b0)) 
    time_out_2ms_reg
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(time_out_2ms_i_1_n_0),
        .Q(time_out_2ms),
        .R(1'b0));
  LUT3 #(
    .INIT(8'h0E)) 
    time_out_500us_i_1
       (.I0(time_out_500us),
        .I1(time_out_500us_reg_i_2_n_1),
        .I2(reset_time_out),
        .O(time_out_500us_i_1_n_0));
  LUT3 #(
    .INIT(8'h01)) 
    time_out_500us_i_10
       (.I0(time_out_counter_reg[2]),
        .I1(time_out_counter_reg[1]),
        .I2(time_out_counter_reg[0]),
        .O(time_out_500us_i_10_n_0));
  LUT1 #(
    .INIT(2'h1)) 
    time_out_500us_i_4
       (.I0(time_out_counter_reg[18]),
        .O(time_out_500us_i_4_n_0));
  LUT3 #(
    .INIT(8'h40)) 
    time_out_500us_i_5
       (.I0(time_out_counter_reg[17]),
        .I1(time_out_counter_reg[16]),
        .I2(time_out_counter_reg[15]),
        .O(time_out_500us_i_5_n_0));
  LUT3 #(
    .INIT(8'h01)) 
    time_out_500us_i_6
       (.I0(time_out_counter_reg[14]),
        .I1(time_out_counter_reg[13]),
        .I2(time_out_counter_reg[12]),
        .O(time_out_500us_i_6_n_0));
  LUT3 #(
    .INIT(8'h40)) 
    time_out_500us_i_7
       (.I0(time_out_counter_reg[11]),
        .I1(time_out_counter_reg[10]),
        .I2(time_out_counter_reg[9]),
        .O(time_out_500us_i_7_n_0));
  LUT3 #(
    .INIT(8'h04)) 
    time_out_500us_i_8
       (.I0(time_out_counter_reg[8]),
        .I1(time_out_counter_reg[7]),
        .I2(time_out_counter_reg[6]),
        .O(time_out_500us_i_8_n_0));
  LUT3 #(
    .INIT(8'h04)) 
    time_out_500us_i_9
       (.I0(time_out_counter_reg[4]),
        .I1(time_out_counter_reg[5]),
        .I2(time_out_counter_reg[3]),
        .O(time_out_500us_i_9_n_0));
  FDRE #(
    .INIT(1'b0)) 
    time_out_500us_reg
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(time_out_500us_i_1_n_0),
        .Q(time_out_500us),
        .R(1'b0));
  CARRY4 time_out_500us_reg_i_2
       (.CI(time_out_500us_reg_i_3_n_0),
        .CO({NLW_time_out_500us_reg_i_2_CO_UNCONNECTED[3],time_out_500us_reg_i_2_n_1,time_out_500us_reg_i_2_n_2,time_out_500us_reg_i_2_n_3}),
        .CYINIT(1'b0),
        .DI({1'b0,1'b0,1'b0,1'b0}),
        .O(NLW_time_out_500us_reg_i_2_O_UNCONNECTED[3:0]),
        .S({1'b0,time_out_500us_i_4_n_0,time_out_500us_i_5_n_0,time_out_500us_i_6_n_0}));
  CARRY4 time_out_500us_reg_i_3
       (.CI(1'b0),
        .CO({time_out_500us_reg_i_3_n_0,time_out_500us_reg_i_3_n_1,time_out_500us_reg_i_3_n_2,time_out_500us_reg_i_3_n_3}),
        .CYINIT(1'b1),
        .DI({1'b0,1'b0,1'b0,1'b0}),
        .O(NLW_time_out_500us_reg_i_3_O_UNCONNECTED[3:0]),
        .S({time_out_500us_i_7_n_0,time_out_500us_i_8_n_0,time_out_500us_i_9_n_0,time_out_500us_i_10_n_0}));
  LUT1 #(
    .INIT(2'h1)) 
    \time_out_counter[0]_i_1 
       (.I0(\time_out_counter_reg[0]_i_3_n_1 ),
        .O(\time_out_counter[0]_i_1_n_0 ));
  LUT3 #(
    .INIT(8'h04)) 
    \time_out_counter[0]_i_10 
       (.I0(time_out_counter_reg[16]),
        .I1(time_out_counter_reg[17]),
        .I2(time_out_counter_reg[15]),
        .O(\time_out_counter[0]_i_10_n_0 ));
  LUT3 #(
    .INIT(8'h10)) 
    \time_out_counter[0]_i_11 
       (.I0(time_out_counter_reg[14]),
        .I1(time_out_counter_reg[13]),
        .I2(time_out_counter_reg[12]),
        .O(\time_out_counter[0]_i_11_n_0 ));
  LUT3 #(
    .INIT(8'h40)) 
    \time_out_counter[0]_i_12 
       (.I0(time_out_counter_reg[10]),
        .I1(time_out_counter_reg[11]),
        .I2(time_out_counter_reg[9]),
        .O(\time_out_counter[0]_i_12_n_0 ));
  LUT3 #(
    .INIT(8'h04)) 
    \time_out_counter[0]_i_13__0 
       (.I0(time_out_counter_reg[8]),
        .I1(time_out_counter_reg[7]),
        .I2(time_out_counter_reg[6]),
        .O(\time_out_counter[0]_i_13__0_n_0 ));
  LUT3 #(
    .INIT(8'h01)) 
    \time_out_counter[0]_i_14 
       (.I0(time_out_counter_reg[5]),
        .I1(time_out_counter_reg[4]),
        .I2(time_out_counter_reg[3]),
        .O(\time_out_counter[0]_i_14_n_0 ));
  LUT3 #(
    .INIT(8'h01)) 
    \time_out_counter[0]_i_15 
       (.I0(time_out_counter_reg[2]),
        .I1(time_out_counter_reg[1]),
        .I2(time_out_counter_reg[0]),
        .O(\time_out_counter[0]_i_15_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \time_out_counter[0]_i_4 
       (.I0(time_out_counter_reg[3]),
        .O(\time_out_counter[0]_i_4_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \time_out_counter[0]_i_5 
       (.I0(time_out_counter_reg[2]),
        .O(\time_out_counter[0]_i_5_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \time_out_counter[0]_i_6 
       (.I0(time_out_counter_reg[1]),
        .O(\time_out_counter[0]_i_6_n_0 ));
  LUT1 #(
    .INIT(2'h1)) 
    \time_out_counter[0]_i_7__0 
       (.I0(time_out_counter_reg[0]),
        .O(\time_out_counter[0]_i_7__0_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \time_out_counter[0]_i_9__0 
       (.I0(time_out_counter_reg[18]),
        .O(\time_out_counter[0]_i_9__0_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \time_out_counter[12]_i_2 
       (.I0(time_out_counter_reg[15]),
        .O(\time_out_counter[12]_i_2_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \time_out_counter[12]_i_3 
       (.I0(time_out_counter_reg[14]),
        .O(\time_out_counter[12]_i_3_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \time_out_counter[12]_i_4 
       (.I0(time_out_counter_reg[13]),
        .O(\time_out_counter[12]_i_4_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \time_out_counter[12]_i_5 
       (.I0(time_out_counter_reg[12]),
        .O(\time_out_counter[12]_i_5_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \time_out_counter[16]_i_2 
       (.I0(time_out_counter_reg[18]),
        .O(\time_out_counter[16]_i_2_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \time_out_counter[16]_i_3 
       (.I0(time_out_counter_reg[17]),
        .O(\time_out_counter[16]_i_3_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \time_out_counter[16]_i_4 
       (.I0(time_out_counter_reg[16]),
        .O(\time_out_counter[16]_i_4_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \time_out_counter[4]_i_2 
       (.I0(time_out_counter_reg[7]),
        .O(\time_out_counter[4]_i_2_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \time_out_counter[4]_i_3 
       (.I0(time_out_counter_reg[6]),
        .O(\time_out_counter[4]_i_3_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \time_out_counter[4]_i_4 
       (.I0(time_out_counter_reg[5]),
        .O(\time_out_counter[4]_i_4_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \time_out_counter[4]_i_5 
       (.I0(time_out_counter_reg[4]),
        .O(\time_out_counter[4]_i_5_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \time_out_counter[8]_i_2 
       (.I0(time_out_counter_reg[11]),
        .O(\time_out_counter[8]_i_2_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \time_out_counter[8]_i_3 
       (.I0(time_out_counter_reg[10]),
        .O(\time_out_counter[8]_i_3_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \time_out_counter[8]_i_4 
       (.I0(time_out_counter_reg[9]),
        .O(\time_out_counter[8]_i_4_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \time_out_counter[8]_i_5 
       (.I0(time_out_counter_reg[8]),
        .O(\time_out_counter[8]_i_5_n_0 ));
  FDRE #(
    .INIT(1'b0)) 
    \time_out_counter_reg[0] 
       (.C(independent_clock_bufg),
        .CE(\time_out_counter[0]_i_1_n_0 ),
        .D(\time_out_counter_reg[0]_i_2_n_7 ),
        .Q(time_out_counter_reg[0]),
        .R(reset_time_out));
  CARRY4 \time_out_counter_reg[0]_i_2 
       (.CI(1'b0),
        .CO({\time_out_counter_reg[0]_i_2_n_0 ,\time_out_counter_reg[0]_i_2_n_1 ,\time_out_counter_reg[0]_i_2_n_2 ,\time_out_counter_reg[0]_i_2_n_3 }),
        .CYINIT(1'b0),
        .DI({1'b0,1'b0,1'b0,1'b1}),
        .O({\time_out_counter_reg[0]_i_2_n_4 ,\time_out_counter_reg[0]_i_2_n_5 ,\time_out_counter_reg[0]_i_2_n_6 ,\time_out_counter_reg[0]_i_2_n_7 }),
        .S({\time_out_counter[0]_i_4_n_0 ,\time_out_counter[0]_i_5_n_0 ,\time_out_counter[0]_i_6_n_0 ,\time_out_counter[0]_i_7__0_n_0 }));
  CARRY4 \time_out_counter_reg[0]_i_3 
       (.CI(\time_out_counter_reg[0]_i_8_n_0 ),
        .CO({\NLW_time_out_counter_reg[0]_i_3_CO_UNCONNECTED [3],\time_out_counter_reg[0]_i_3_n_1 ,\time_out_counter_reg[0]_i_3_n_2 ,\time_out_counter_reg[0]_i_3_n_3 }),
        .CYINIT(1'b0),
        .DI({1'b0,1'b0,1'b0,1'b0}),
        .O(\NLW_time_out_counter_reg[0]_i_3_O_UNCONNECTED [3:0]),
        .S({1'b0,\time_out_counter[0]_i_9__0_n_0 ,\time_out_counter[0]_i_10_n_0 ,\time_out_counter[0]_i_11_n_0 }));
  CARRY4 \time_out_counter_reg[0]_i_8 
       (.CI(1'b0),
        .CO({\time_out_counter_reg[0]_i_8_n_0 ,\time_out_counter_reg[0]_i_8_n_1 ,\time_out_counter_reg[0]_i_8_n_2 ,\time_out_counter_reg[0]_i_8_n_3 }),
        .CYINIT(1'b1),
        .DI({1'b0,1'b0,1'b0,1'b0}),
        .O(\NLW_time_out_counter_reg[0]_i_8_O_UNCONNECTED [3:0]),
        .S({\time_out_counter[0]_i_12_n_0 ,\time_out_counter[0]_i_13__0_n_0 ,\time_out_counter[0]_i_14_n_0 ,\time_out_counter[0]_i_15_n_0 }));
  FDRE #(
    .INIT(1'b0)) 
    \time_out_counter_reg[10] 
       (.C(independent_clock_bufg),
        .CE(\time_out_counter[0]_i_1_n_0 ),
        .D(\time_out_counter_reg[8]_i_1_n_5 ),
        .Q(time_out_counter_reg[10]),
        .R(reset_time_out));
  FDRE #(
    .INIT(1'b0)) 
    \time_out_counter_reg[11] 
       (.C(independent_clock_bufg),
        .CE(\time_out_counter[0]_i_1_n_0 ),
        .D(\time_out_counter_reg[8]_i_1_n_4 ),
        .Q(time_out_counter_reg[11]),
        .R(reset_time_out));
  FDRE #(
    .INIT(1'b0)) 
    \time_out_counter_reg[12] 
       (.C(independent_clock_bufg),
        .CE(\time_out_counter[0]_i_1_n_0 ),
        .D(\time_out_counter_reg[12]_i_1_n_7 ),
        .Q(time_out_counter_reg[12]),
        .R(reset_time_out));
  CARRY4 \time_out_counter_reg[12]_i_1 
       (.CI(\time_out_counter_reg[8]_i_1_n_0 ),
        .CO({\time_out_counter_reg[12]_i_1_n_0 ,\time_out_counter_reg[12]_i_1_n_1 ,\time_out_counter_reg[12]_i_1_n_2 ,\time_out_counter_reg[12]_i_1_n_3 }),
        .CYINIT(1'b0),
        .DI({1'b0,1'b0,1'b0,1'b0}),
        .O({\time_out_counter_reg[12]_i_1_n_4 ,\time_out_counter_reg[12]_i_1_n_5 ,\time_out_counter_reg[12]_i_1_n_6 ,\time_out_counter_reg[12]_i_1_n_7 }),
        .S({\time_out_counter[12]_i_2_n_0 ,\time_out_counter[12]_i_3_n_0 ,\time_out_counter[12]_i_4_n_0 ,\time_out_counter[12]_i_5_n_0 }));
  FDRE #(
    .INIT(1'b0)) 
    \time_out_counter_reg[13] 
       (.C(independent_clock_bufg),
        .CE(\time_out_counter[0]_i_1_n_0 ),
        .D(\time_out_counter_reg[12]_i_1_n_6 ),
        .Q(time_out_counter_reg[13]),
        .R(reset_time_out));
  FDRE #(
    .INIT(1'b0)) 
    \time_out_counter_reg[14] 
       (.C(independent_clock_bufg),
        .CE(\time_out_counter[0]_i_1_n_0 ),
        .D(\time_out_counter_reg[12]_i_1_n_5 ),
        .Q(time_out_counter_reg[14]),
        .R(reset_time_out));
  FDRE #(
    .INIT(1'b0)) 
    \time_out_counter_reg[15] 
       (.C(independent_clock_bufg),
        .CE(\time_out_counter[0]_i_1_n_0 ),
        .D(\time_out_counter_reg[12]_i_1_n_4 ),
        .Q(time_out_counter_reg[15]),
        .R(reset_time_out));
  FDRE #(
    .INIT(1'b0)) 
    \time_out_counter_reg[16] 
       (.C(independent_clock_bufg),
        .CE(\time_out_counter[0]_i_1_n_0 ),
        .D(\time_out_counter_reg[16]_i_1_n_7 ),
        .Q(time_out_counter_reg[16]),
        .R(reset_time_out));
  CARRY4 \time_out_counter_reg[16]_i_1 
       (.CI(\time_out_counter_reg[12]_i_1_n_0 ),
        .CO({\NLW_time_out_counter_reg[16]_i_1_CO_UNCONNECTED [3:2],\time_out_counter_reg[16]_i_1_n_2 ,\time_out_counter_reg[16]_i_1_n_3 }),
        .CYINIT(1'b0),
        .DI({1'b0,1'b0,1'b0,1'b0}),
        .O({\NLW_time_out_counter_reg[16]_i_1_O_UNCONNECTED [3],\time_out_counter_reg[16]_i_1_n_5 ,\time_out_counter_reg[16]_i_1_n_6 ,\time_out_counter_reg[16]_i_1_n_7 }),
        .S({1'b0,\time_out_counter[16]_i_2_n_0 ,\time_out_counter[16]_i_3_n_0 ,\time_out_counter[16]_i_4_n_0 }));
  FDRE #(
    .INIT(1'b0)) 
    \time_out_counter_reg[17] 
       (.C(independent_clock_bufg),
        .CE(\time_out_counter[0]_i_1_n_0 ),
        .D(\time_out_counter_reg[16]_i_1_n_6 ),
        .Q(time_out_counter_reg[17]),
        .R(reset_time_out));
  FDRE #(
    .INIT(1'b0)) 
    \time_out_counter_reg[18] 
       (.C(independent_clock_bufg),
        .CE(\time_out_counter[0]_i_1_n_0 ),
        .D(\time_out_counter_reg[16]_i_1_n_5 ),
        .Q(time_out_counter_reg[18]),
        .R(reset_time_out));
  FDRE #(
    .INIT(1'b0)) 
    \time_out_counter_reg[1] 
       (.C(independent_clock_bufg),
        .CE(\time_out_counter[0]_i_1_n_0 ),
        .D(\time_out_counter_reg[0]_i_2_n_6 ),
        .Q(time_out_counter_reg[1]),
        .R(reset_time_out));
  FDRE #(
    .INIT(1'b0)) 
    \time_out_counter_reg[2] 
       (.C(independent_clock_bufg),
        .CE(\time_out_counter[0]_i_1_n_0 ),
        .D(\time_out_counter_reg[0]_i_2_n_5 ),
        .Q(time_out_counter_reg[2]),
        .R(reset_time_out));
  FDRE #(
    .INIT(1'b0)) 
    \time_out_counter_reg[3] 
       (.C(independent_clock_bufg),
        .CE(\time_out_counter[0]_i_1_n_0 ),
        .D(\time_out_counter_reg[0]_i_2_n_4 ),
        .Q(time_out_counter_reg[3]),
        .R(reset_time_out));
  FDRE #(
    .INIT(1'b0)) 
    \time_out_counter_reg[4] 
       (.C(independent_clock_bufg),
        .CE(\time_out_counter[0]_i_1_n_0 ),
        .D(\time_out_counter_reg[4]_i_1_n_7 ),
        .Q(time_out_counter_reg[4]),
        .R(reset_time_out));
  CARRY4 \time_out_counter_reg[4]_i_1 
       (.CI(\time_out_counter_reg[0]_i_2_n_0 ),
        .CO({\time_out_counter_reg[4]_i_1_n_0 ,\time_out_counter_reg[4]_i_1_n_1 ,\time_out_counter_reg[4]_i_1_n_2 ,\time_out_counter_reg[4]_i_1_n_3 }),
        .CYINIT(1'b0),
        .DI({1'b0,1'b0,1'b0,1'b0}),
        .O({\time_out_counter_reg[4]_i_1_n_4 ,\time_out_counter_reg[4]_i_1_n_5 ,\time_out_counter_reg[4]_i_1_n_6 ,\time_out_counter_reg[4]_i_1_n_7 }),
        .S({\time_out_counter[4]_i_2_n_0 ,\time_out_counter[4]_i_3_n_0 ,\time_out_counter[4]_i_4_n_0 ,\time_out_counter[4]_i_5_n_0 }));
  FDRE #(
    .INIT(1'b0)) 
    \time_out_counter_reg[5] 
       (.C(independent_clock_bufg),
        .CE(\time_out_counter[0]_i_1_n_0 ),
        .D(\time_out_counter_reg[4]_i_1_n_6 ),
        .Q(time_out_counter_reg[5]),
        .R(reset_time_out));
  FDRE #(
    .INIT(1'b0)) 
    \time_out_counter_reg[6] 
       (.C(independent_clock_bufg),
        .CE(\time_out_counter[0]_i_1_n_0 ),
        .D(\time_out_counter_reg[4]_i_1_n_5 ),
        .Q(time_out_counter_reg[6]),
        .R(reset_time_out));
  FDRE #(
    .INIT(1'b0)) 
    \time_out_counter_reg[7] 
       (.C(independent_clock_bufg),
        .CE(\time_out_counter[0]_i_1_n_0 ),
        .D(\time_out_counter_reg[4]_i_1_n_4 ),
        .Q(time_out_counter_reg[7]),
        .R(reset_time_out));
  FDRE #(
    .INIT(1'b0)) 
    \time_out_counter_reg[8] 
       (.C(independent_clock_bufg),
        .CE(\time_out_counter[0]_i_1_n_0 ),
        .D(\time_out_counter_reg[8]_i_1_n_7 ),
        .Q(time_out_counter_reg[8]),
        .R(reset_time_out));
  CARRY4 \time_out_counter_reg[8]_i_1 
       (.CI(\time_out_counter_reg[4]_i_1_n_0 ),
        .CO({\time_out_counter_reg[8]_i_1_n_0 ,\time_out_counter_reg[8]_i_1_n_1 ,\time_out_counter_reg[8]_i_1_n_2 ,\time_out_counter_reg[8]_i_1_n_3 }),
        .CYINIT(1'b0),
        .DI({1'b0,1'b0,1'b0,1'b0}),
        .O({\time_out_counter_reg[8]_i_1_n_4 ,\time_out_counter_reg[8]_i_1_n_5 ,\time_out_counter_reg[8]_i_1_n_6 ,\time_out_counter_reg[8]_i_1_n_7 }),
        .S({\time_out_counter[8]_i_2_n_0 ,\time_out_counter[8]_i_3_n_0 ,\time_out_counter[8]_i_4_n_0 ,\time_out_counter[8]_i_5_n_0 }));
  FDRE #(
    .INIT(1'b0)) 
    \time_out_counter_reg[9] 
       (.C(independent_clock_bufg),
        .CE(\time_out_counter[0]_i_1_n_0 ),
        .D(\time_out_counter_reg[8]_i_1_n_6 ),
        .Q(time_out_counter_reg[9]),
        .R(reset_time_out));
  LUT4 #(
    .INIT(16'hAE00)) 
    time_out_wait_bypass_i_1
       (.I0(time_out_wait_bypass_reg_n_0),
        .I1(wait_bypass_count1),
        .I2(tx_fsm_reset_done_int_s3),
        .I3(run_phase_alignment_int_s3),
        .O(time_out_wait_bypass_i_1_n_0));
  FDRE #(
    .INIT(1'b0)) 
    time_out_wait_bypass_reg
       (.C(userclk),
        .CE(1'b1),
        .D(time_out_wait_bypass_i_1_n_0),
        .Q(time_out_wait_bypass_reg_n_0),
        .R(1'b0));
  FDRE #(
    .INIT(1'b0)) 
    time_out_wait_bypass_s3_reg
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(time_out_wait_bypass_s2),
        .Q(time_out_wait_bypass_s3),
        .R(1'b0));
  LUT3 #(
    .INIT(8'h01)) 
    time_tlock_max_i_10__0
       (.I0(time_out_counter_reg[2]),
        .I1(time_out_counter_reg[1]),
        .I2(time_out_counter_reg[0]),
        .O(time_tlock_max_i_10__0_n_0));
  (* SOFT_HLUTNM = "soft_lutpair56" *) 
  LUT3 #(
    .INIT(8'h0E)) 
    time_tlock_max_i_1__0
       (.I0(time_tlock_max),
        .I1(time_tlock_max_reg_i_2_n_1),
        .I2(reset_time_out),
        .O(time_tlock_max_i_1__0_n_0));
  LUT1 #(
    .INIT(2'h1)) 
    time_tlock_max_i_4__0
       (.I0(time_out_counter_reg[18]),
        .O(time_tlock_max_i_4__0_n_0));
  LUT3 #(
    .INIT(8'h01)) 
    time_tlock_max_i_5
       (.I0(time_out_counter_reg[17]),
        .I1(time_out_counter_reg[16]),
        .I2(time_out_counter_reg[15]),
        .O(time_tlock_max_i_5_n_0));
  LUT3 #(
    .INIT(8'h04)) 
    time_tlock_max_i_6
       (.I0(time_out_counter_reg[13]),
        .I1(time_out_counter_reg[14]),
        .I2(time_out_counter_reg[12]),
        .O(time_tlock_max_i_6_n_0));
  LUT3 #(
    .INIT(8'h80)) 
    time_tlock_max_i_7
       (.I0(time_out_counter_reg[11]),
        .I1(time_out_counter_reg[10]),
        .I2(time_out_counter_reg[9]),
        .O(time_tlock_max_i_7_n_0));
  LUT3 #(
    .INIT(8'h01)) 
    time_tlock_max_i_8
       (.I0(time_out_counter_reg[8]),
        .I1(time_out_counter_reg[7]),
        .I2(time_out_counter_reg[6]),
        .O(time_tlock_max_i_8_n_0));
  LUT3 #(
    .INIT(8'h04)) 
    time_tlock_max_i_9__0
       (.I0(time_out_counter_reg[4]),
        .I1(time_out_counter_reg[5]),
        .I2(time_out_counter_reg[3]),
        .O(time_tlock_max_i_9__0_n_0));
  FDRE #(
    .INIT(1'b0)) 
    time_tlock_max_reg
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(time_tlock_max_i_1__0_n_0),
        .Q(time_tlock_max),
        .R(1'b0));
  CARRY4 time_tlock_max_reg_i_2
       (.CI(time_tlock_max_reg_i_3_n_0),
        .CO({NLW_time_tlock_max_reg_i_2_CO_UNCONNECTED[3],time_tlock_max_reg_i_2_n_1,time_tlock_max_reg_i_2_n_2,time_tlock_max_reg_i_2_n_3}),
        .CYINIT(1'b0),
        .DI({1'b0,1'b0,1'b0,1'b0}),
        .O(NLW_time_tlock_max_reg_i_2_O_UNCONNECTED[3:0]),
        .S({1'b0,time_tlock_max_i_4__0_n_0,time_tlock_max_i_5_n_0,time_tlock_max_i_6_n_0}));
  CARRY4 time_tlock_max_reg_i_3
       (.CI(1'b0),
        .CO({time_tlock_max_reg_i_3_n_0,time_tlock_max_reg_i_3_n_1,time_tlock_max_reg_i_3_n_2,time_tlock_max_reg_i_3_n_3}),
        .CYINIT(1'b1),
        .DI({1'b0,1'b0,1'b0,1'b0}),
        .O(NLW_time_tlock_max_reg_i_3_O_UNCONNECTED[3:0]),
        .S({time_tlock_max_i_7_n_0,time_tlock_max_i_8_n_0,time_tlock_max_i_9__0_n_0,time_tlock_max_i_10__0_n_0}));
  LUT5 #(
    .INIT(32'hFFFF0008)) 
    tx_fsm_reset_done_int_i_1
       (.I0(tx_state[0]),
        .I1(tx_state[3]),
        .I2(tx_state[1]),
        .I3(tx_state[2]),
        .I4(data_in),
        .O(tx_fsm_reset_done_int_i_1_n_0));
  FDRE #(
    .INIT(1'b0)) 
    tx_fsm_reset_done_int_reg
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(tx_fsm_reset_done_int_i_1_n_0),
        .Q(data_in),
        .R(pma_reset));
  FDRE #(
    .INIT(1'b0)) 
    tx_fsm_reset_done_int_s3_reg
       (.C(userclk),
        .CE(1'b1),
        .D(tx_fsm_reset_done_int_s2),
        .Q(tx_fsm_reset_done_int_s3),
        .R(1'b0));
  FDRE #(
    .INIT(1'b0)) 
    txresetdone_s3_reg
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(txresetdone_s2),
        .Q(txresetdone_s3),
        .R(1'b0));
  LUT1 #(
    .INIT(2'h1)) 
    \wait_bypass_count[0]_i_1 
       (.I0(run_phase_alignment_int_s3),
        .O(clear));
  LUT4 #(
    .INIT(16'h0400)) 
    \wait_bypass_count[0]_i_10 
       (.I0(wait_bypass_count_reg[10]),
        .I1(wait_bypass_count_reg[9]),
        .I2(wait_bypass_count_reg[8]),
        .I3(wait_bypass_count_reg[7]),
        .O(\wait_bypass_count[0]_i_10_n_0 ));
  LUT6 #(
    .INIT(64'h0000002000000000)) 
    \wait_bypass_count[0]_i_11 
       (.I0(wait_bypass_count_reg[12]),
        .I1(wait_bypass_count_reg[11]),
        .I2(wait_bypass_count_reg[14]),
        .I3(wait_bypass_count_reg[13]),
        .I4(wait_bypass_count_reg[15]),
        .I5(wait_bypass_count_reg[16]),
        .O(\wait_bypass_count[0]_i_11_n_0 ));
  LUT2 #(
    .INIT(4'h1)) 
    \wait_bypass_count[0]_i_2 
       (.I0(tx_fsm_reset_done_int_s3),
        .I1(wait_bypass_count1),
        .O(wait_bypass_count));
  LUT6 #(
    .INIT(64'h8000000000000000)) 
    \wait_bypass_count[0]_i_4 
       (.I0(wait_bypass_count_reg[2]),
        .I1(wait_bypass_count_reg[1]),
        .I2(wait_bypass_count_reg[0]),
        .I3(\wait_bypass_count[0]_i_9_n_0 ),
        .I4(\wait_bypass_count[0]_i_10_n_0 ),
        .I5(\wait_bypass_count[0]_i_11_n_0 ),
        .O(wait_bypass_count1));
  LUT1 #(
    .INIT(2'h2)) 
    \wait_bypass_count[0]_i_5 
       (.I0(wait_bypass_count_reg[3]),
        .O(\wait_bypass_count[0]_i_5_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \wait_bypass_count[0]_i_6 
       (.I0(wait_bypass_count_reg[2]),
        .O(\wait_bypass_count[0]_i_6_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \wait_bypass_count[0]_i_7 
       (.I0(wait_bypass_count_reg[1]),
        .O(\wait_bypass_count[0]_i_7_n_0 ));
  LUT1 #(
    .INIT(2'h1)) 
    \wait_bypass_count[0]_i_8 
       (.I0(wait_bypass_count_reg[0]),
        .O(\wait_bypass_count[0]_i_8_n_0 ));
  LUT4 #(
    .INIT(16'h8000)) 
    \wait_bypass_count[0]_i_9 
       (.I0(wait_bypass_count_reg[6]),
        .I1(wait_bypass_count_reg[5]),
        .I2(wait_bypass_count_reg[4]),
        .I3(wait_bypass_count_reg[3]),
        .O(\wait_bypass_count[0]_i_9_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \wait_bypass_count[12]_i_2 
       (.I0(wait_bypass_count_reg[15]),
        .O(\wait_bypass_count[12]_i_2_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \wait_bypass_count[12]_i_3 
       (.I0(wait_bypass_count_reg[14]),
        .O(\wait_bypass_count[12]_i_3_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \wait_bypass_count[12]_i_4 
       (.I0(wait_bypass_count_reg[13]),
        .O(\wait_bypass_count[12]_i_4_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \wait_bypass_count[12]_i_5 
       (.I0(wait_bypass_count_reg[12]),
        .O(\wait_bypass_count[12]_i_5_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \wait_bypass_count[16]_i_2 
       (.I0(wait_bypass_count_reg[16]),
        .O(\wait_bypass_count[16]_i_2_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \wait_bypass_count[4]_i_2 
       (.I0(wait_bypass_count_reg[7]),
        .O(\wait_bypass_count[4]_i_2_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \wait_bypass_count[4]_i_3 
       (.I0(wait_bypass_count_reg[6]),
        .O(\wait_bypass_count[4]_i_3_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \wait_bypass_count[4]_i_4 
       (.I0(wait_bypass_count_reg[5]),
        .O(\wait_bypass_count[4]_i_4_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \wait_bypass_count[4]_i_5 
       (.I0(wait_bypass_count_reg[4]),
        .O(\wait_bypass_count[4]_i_5_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \wait_bypass_count[8]_i_2 
       (.I0(wait_bypass_count_reg[11]),
        .O(\wait_bypass_count[8]_i_2_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \wait_bypass_count[8]_i_3 
       (.I0(wait_bypass_count_reg[10]),
        .O(\wait_bypass_count[8]_i_3_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \wait_bypass_count[8]_i_4 
       (.I0(wait_bypass_count_reg[9]),
        .O(\wait_bypass_count[8]_i_4_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \wait_bypass_count[8]_i_5 
       (.I0(wait_bypass_count_reg[8]),
        .O(\wait_bypass_count[8]_i_5_n_0 ));
  FDRE \wait_bypass_count_reg[0] 
       (.C(userclk),
        .CE(wait_bypass_count),
        .D(\wait_bypass_count_reg[0]_i_3_n_7 ),
        .Q(wait_bypass_count_reg[0]),
        .R(clear));
  CARRY4 \wait_bypass_count_reg[0]_i_3 
       (.CI(1'b0),
        .CO({\wait_bypass_count_reg[0]_i_3_n_0 ,\wait_bypass_count_reg[0]_i_3_n_1 ,\wait_bypass_count_reg[0]_i_3_n_2 ,\wait_bypass_count_reg[0]_i_3_n_3 }),
        .CYINIT(1'b0),
        .DI({1'b0,1'b0,1'b0,1'b1}),
        .O({\wait_bypass_count_reg[0]_i_3_n_4 ,\wait_bypass_count_reg[0]_i_3_n_5 ,\wait_bypass_count_reg[0]_i_3_n_6 ,\wait_bypass_count_reg[0]_i_3_n_7 }),
        .S({\wait_bypass_count[0]_i_5_n_0 ,\wait_bypass_count[0]_i_6_n_0 ,\wait_bypass_count[0]_i_7_n_0 ,\wait_bypass_count[0]_i_8_n_0 }));
  FDRE \wait_bypass_count_reg[10] 
       (.C(userclk),
        .CE(wait_bypass_count),
        .D(\wait_bypass_count_reg[8]_i_1_n_5 ),
        .Q(wait_bypass_count_reg[10]),
        .R(clear));
  FDRE \wait_bypass_count_reg[11] 
       (.C(userclk),
        .CE(wait_bypass_count),
        .D(\wait_bypass_count_reg[8]_i_1_n_4 ),
        .Q(wait_bypass_count_reg[11]),
        .R(clear));
  FDRE \wait_bypass_count_reg[12] 
       (.C(userclk),
        .CE(wait_bypass_count),
        .D(\wait_bypass_count_reg[12]_i_1_n_7 ),
        .Q(wait_bypass_count_reg[12]),
        .R(clear));
  CARRY4 \wait_bypass_count_reg[12]_i_1 
       (.CI(\wait_bypass_count_reg[8]_i_1_n_0 ),
        .CO({\wait_bypass_count_reg[12]_i_1_n_0 ,\wait_bypass_count_reg[12]_i_1_n_1 ,\wait_bypass_count_reg[12]_i_1_n_2 ,\wait_bypass_count_reg[12]_i_1_n_3 }),
        .CYINIT(1'b0),
        .DI({1'b0,1'b0,1'b0,1'b0}),
        .O({\wait_bypass_count_reg[12]_i_1_n_4 ,\wait_bypass_count_reg[12]_i_1_n_5 ,\wait_bypass_count_reg[12]_i_1_n_6 ,\wait_bypass_count_reg[12]_i_1_n_7 }),
        .S({\wait_bypass_count[12]_i_2_n_0 ,\wait_bypass_count[12]_i_3_n_0 ,\wait_bypass_count[12]_i_4_n_0 ,\wait_bypass_count[12]_i_5_n_0 }));
  FDRE \wait_bypass_count_reg[13] 
       (.C(userclk),
        .CE(wait_bypass_count),
        .D(\wait_bypass_count_reg[12]_i_1_n_6 ),
        .Q(wait_bypass_count_reg[13]),
        .R(clear));
  FDRE \wait_bypass_count_reg[14] 
       (.C(userclk),
        .CE(wait_bypass_count),
        .D(\wait_bypass_count_reg[12]_i_1_n_5 ),
        .Q(wait_bypass_count_reg[14]),
        .R(clear));
  FDRE \wait_bypass_count_reg[15] 
       (.C(userclk),
        .CE(wait_bypass_count),
        .D(\wait_bypass_count_reg[12]_i_1_n_4 ),
        .Q(wait_bypass_count_reg[15]),
        .R(clear));
  FDRE \wait_bypass_count_reg[16] 
       (.C(userclk),
        .CE(wait_bypass_count),
        .D(\wait_bypass_count_reg[16]_i_1_n_7 ),
        .Q(wait_bypass_count_reg[16]),
        .R(clear));
  CARRY4 \wait_bypass_count_reg[16]_i_1 
       (.CI(\wait_bypass_count_reg[12]_i_1_n_0 ),
        .CO(\NLW_wait_bypass_count_reg[16]_i_1_CO_UNCONNECTED [3:0]),
        .CYINIT(1'b0),
        .DI({1'b0,1'b0,1'b0,1'b0}),
        .O({\NLW_wait_bypass_count_reg[16]_i_1_O_UNCONNECTED [3:1],\wait_bypass_count_reg[16]_i_1_n_7 }),
        .S({1'b0,1'b0,1'b0,\wait_bypass_count[16]_i_2_n_0 }));
  FDRE \wait_bypass_count_reg[1] 
       (.C(userclk),
        .CE(wait_bypass_count),
        .D(\wait_bypass_count_reg[0]_i_3_n_6 ),
        .Q(wait_bypass_count_reg[1]),
        .R(clear));
  FDRE \wait_bypass_count_reg[2] 
       (.C(userclk),
        .CE(wait_bypass_count),
        .D(\wait_bypass_count_reg[0]_i_3_n_5 ),
        .Q(wait_bypass_count_reg[2]),
        .R(clear));
  FDRE \wait_bypass_count_reg[3] 
       (.C(userclk),
        .CE(wait_bypass_count),
        .D(\wait_bypass_count_reg[0]_i_3_n_4 ),
        .Q(wait_bypass_count_reg[3]),
        .R(clear));
  FDRE \wait_bypass_count_reg[4] 
       (.C(userclk),
        .CE(wait_bypass_count),
        .D(\wait_bypass_count_reg[4]_i_1_n_7 ),
        .Q(wait_bypass_count_reg[4]),
        .R(clear));
  CARRY4 \wait_bypass_count_reg[4]_i_1 
       (.CI(\wait_bypass_count_reg[0]_i_3_n_0 ),
        .CO({\wait_bypass_count_reg[4]_i_1_n_0 ,\wait_bypass_count_reg[4]_i_1_n_1 ,\wait_bypass_count_reg[4]_i_1_n_2 ,\wait_bypass_count_reg[4]_i_1_n_3 }),
        .CYINIT(1'b0),
        .DI({1'b0,1'b0,1'b0,1'b0}),
        .O({\wait_bypass_count_reg[4]_i_1_n_4 ,\wait_bypass_count_reg[4]_i_1_n_5 ,\wait_bypass_count_reg[4]_i_1_n_6 ,\wait_bypass_count_reg[4]_i_1_n_7 }),
        .S({\wait_bypass_count[4]_i_2_n_0 ,\wait_bypass_count[4]_i_3_n_0 ,\wait_bypass_count[4]_i_4_n_0 ,\wait_bypass_count[4]_i_5_n_0 }));
  FDRE \wait_bypass_count_reg[5] 
       (.C(userclk),
        .CE(wait_bypass_count),
        .D(\wait_bypass_count_reg[4]_i_1_n_6 ),
        .Q(wait_bypass_count_reg[5]),
        .R(clear));
  FDRE \wait_bypass_count_reg[6] 
       (.C(userclk),
        .CE(wait_bypass_count),
        .D(\wait_bypass_count_reg[4]_i_1_n_5 ),
        .Q(wait_bypass_count_reg[6]),
        .R(clear));
  FDRE \wait_bypass_count_reg[7] 
       (.C(userclk),
        .CE(wait_bypass_count),
        .D(\wait_bypass_count_reg[4]_i_1_n_4 ),
        .Q(wait_bypass_count_reg[7]),
        .R(clear));
  FDRE \wait_bypass_count_reg[8] 
       (.C(userclk),
        .CE(wait_bypass_count),
        .D(\wait_bypass_count_reg[8]_i_1_n_7 ),
        .Q(wait_bypass_count_reg[8]),
        .R(clear));
  CARRY4 \wait_bypass_count_reg[8]_i_1 
       (.CI(\wait_bypass_count_reg[4]_i_1_n_0 ),
        .CO({\wait_bypass_count_reg[8]_i_1_n_0 ,\wait_bypass_count_reg[8]_i_1_n_1 ,\wait_bypass_count_reg[8]_i_1_n_2 ,\wait_bypass_count_reg[8]_i_1_n_3 }),
        .CYINIT(1'b0),
        .DI({1'b0,1'b0,1'b0,1'b0}),
        .O({\wait_bypass_count_reg[8]_i_1_n_4 ,\wait_bypass_count_reg[8]_i_1_n_5 ,\wait_bypass_count_reg[8]_i_1_n_6 ,\wait_bypass_count_reg[8]_i_1_n_7 }),
        .S({\wait_bypass_count[8]_i_2_n_0 ,\wait_bypass_count[8]_i_3_n_0 ,\wait_bypass_count[8]_i_4_n_0 ,\wait_bypass_count[8]_i_5_n_0 }));
  FDRE \wait_bypass_count_reg[9] 
       (.C(userclk),
        .CE(wait_bypass_count),
        .D(\wait_bypass_count_reg[8]_i_1_n_6 ),
        .Q(wait_bypass_count_reg[9]),
        .R(clear));
  (* SOFT_HLUTNM = "soft_lutpair57" *) 
  LUT1 #(
    .INIT(2'h1)) 
    \wait_time_cnt[0]_i_1 
       (.I0(wait_time_cnt_reg__0[0]),
        .O(wait_time_cnt0[0]));
  (* SOFT_HLUTNM = "soft_lutpair57" *) 
  LUT2 #(
    .INIT(4'h9)) 
    \wait_time_cnt[1]_i_1 
       (.I0(wait_time_cnt_reg__0[1]),
        .I1(wait_time_cnt_reg__0[0]),
        .O(wait_time_cnt0[1]));
  LUT3 #(
    .INIT(8'hA9)) 
    \wait_time_cnt[2]_i_1 
       (.I0(wait_time_cnt_reg__0[2]),
        .I1(wait_time_cnt_reg__0[0]),
        .I2(wait_time_cnt_reg__0[1]),
        .O(wait_time_cnt0[2]));
  (* SOFT_HLUTNM = "soft_lutpair51" *) 
  LUT4 #(
    .INIT(16'hFE01)) 
    \wait_time_cnt[3]_i_1 
       (.I0(wait_time_cnt_reg__0[1]),
        .I1(wait_time_cnt_reg__0[0]),
        .I2(wait_time_cnt_reg__0[2]),
        .I3(wait_time_cnt_reg__0[3]),
        .O(wait_time_cnt0[3]));
  (* SOFT_HLUTNM = "soft_lutpair51" *) 
  LUT5 #(
    .INIT(32'hFFFE0001)) 
    \wait_time_cnt[4]_i_1 
       (.I0(wait_time_cnt_reg__0[1]),
        .I1(wait_time_cnt_reg__0[0]),
        .I2(wait_time_cnt_reg__0[2]),
        .I3(wait_time_cnt_reg__0[3]),
        .I4(wait_time_cnt_reg__0[4]),
        .O(wait_time_cnt0[4]));
  LUT6 #(
    .INIT(64'hFFFFFFFE00000001)) 
    \wait_time_cnt[5]_i_1 
       (.I0(wait_time_cnt_reg__0[1]),
        .I1(wait_time_cnt_reg__0[0]),
        .I2(wait_time_cnt_reg__0[2]),
        .I3(wait_time_cnt_reg__0[3]),
        .I4(wait_time_cnt_reg__0[4]),
        .I5(wait_time_cnt_reg__0[5]),
        .O(wait_time_cnt0[5]));
  LUT4 #(
    .INIT(16'h1500)) 
    \wait_time_cnt[6]_i_1 
       (.I0(tx_state[3]),
        .I1(tx_state[1]),
        .I2(tx_state[2]),
        .I3(tx_state[0]),
        .O(wait_time_cnt0_0));
  LUT2 #(
    .INIT(4'hE)) 
    \wait_time_cnt[6]_i_2 
       (.I0(\wait_time_cnt[6]_i_4_n_0 ),
        .I1(wait_time_cnt_reg__0[6]),
        .O(\wait_time_cnt[6]_i_2_n_0 ));
  LUT2 #(
    .INIT(4'h9)) 
    \wait_time_cnt[6]_i_3 
       (.I0(wait_time_cnt_reg__0[6]),
        .I1(\wait_time_cnt[6]_i_4_n_0 ),
        .O(wait_time_cnt0[6]));
  LUT6 #(
    .INIT(64'hFFFFFFFFFFFFFFFE)) 
    \wait_time_cnt[6]_i_4 
       (.I0(wait_time_cnt_reg__0[5]),
        .I1(wait_time_cnt_reg__0[4]),
        .I2(wait_time_cnt_reg__0[3]),
        .I3(wait_time_cnt_reg__0[2]),
        .I4(wait_time_cnt_reg__0[0]),
        .I5(wait_time_cnt_reg__0[1]),
        .O(\wait_time_cnt[6]_i_4_n_0 ));
  FDRE \wait_time_cnt_reg[0] 
       (.C(independent_clock_bufg),
        .CE(\wait_time_cnt[6]_i_2_n_0 ),
        .D(wait_time_cnt0[0]),
        .Q(wait_time_cnt_reg__0[0]),
        .R(wait_time_cnt0_0));
  FDRE \wait_time_cnt_reg[1] 
       (.C(independent_clock_bufg),
        .CE(\wait_time_cnt[6]_i_2_n_0 ),
        .D(wait_time_cnt0[1]),
        .Q(wait_time_cnt_reg__0[1]),
        .R(wait_time_cnt0_0));
  FDSE \wait_time_cnt_reg[2] 
       (.C(independent_clock_bufg),
        .CE(\wait_time_cnt[6]_i_2_n_0 ),
        .D(wait_time_cnt0[2]),
        .Q(wait_time_cnt_reg__0[2]),
        .S(wait_time_cnt0_0));
  FDRE \wait_time_cnt_reg[3] 
       (.C(independent_clock_bufg),
        .CE(\wait_time_cnt[6]_i_2_n_0 ),
        .D(wait_time_cnt0[3]),
        .Q(wait_time_cnt_reg__0[3]),
        .R(wait_time_cnt0_0));
  FDRE \wait_time_cnt_reg[4] 
       (.C(independent_clock_bufg),
        .CE(\wait_time_cnt[6]_i_2_n_0 ),
        .D(wait_time_cnt0[4]),
        .Q(wait_time_cnt_reg__0[4]),
        .R(wait_time_cnt0_0));
  FDSE \wait_time_cnt_reg[5] 
       (.C(independent_clock_bufg),
        .CE(\wait_time_cnt[6]_i_2_n_0 ),
        .D(wait_time_cnt0[5]),
        .Q(wait_time_cnt_reg__0[5]),
        .S(wait_time_cnt0_0));
  FDSE \wait_time_cnt_reg[6] 
       (.C(independent_clock_bufg),
        .CE(\wait_time_cnt[6]_i_2_n_0 ),
        .D(wait_time_cnt0[6]),
        .Q(wait_time_cnt_reg__0[6]),
        .S(wait_time_cnt0_0));
endmodule

(* ORIG_REF_NAME = "GigEthGth7Core_block" *) 
module GigEthGth7Core_GigEthGth7Core_block
   (gmii_rxd,
    gmii_rx_dv,
    gmii_rx_er,
    gmii_isolate,
    status_vector,
    resetdone,
    cplllock,
    txn,
    txp,
    rxoutclk,
    txoutclk,
    mmcm_reset,
    gtrefclk_bufg,
    reset,
    signal_detect,
    userclk2,
    mmcm_locked,
    gmii_txd,
    gmii_tx_en,
    gmii_tx_er,
    configuration_vector,
    independent_clock_bufg,
    userclk,
    rxn,
    rxp,
    gtrefclk,
    gt0_qplloutclk_in,
    gt0_qplloutrefclk_in,
    pma_reset);
  output [7:0]gmii_rxd;
  output gmii_rx_dv;
  output gmii_rx_er;
  output gmii_isolate;
  output [15:0]status_vector;
  output resetdone;
  output cplllock;
  output txn;
  output txp;
  output rxoutclk;
  output txoutclk;
  output mmcm_reset;
  input gtrefclk_bufg;
  input reset;
  input signal_detect;
  input userclk2;
  input mmcm_locked;
  input [7:0]gmii_txd;
  input gmii_tx_en;
  input gmii_tx_er;
  input [4:0]configuration_vector;
  input independent_clock_bufg;
  input userclk;
  input rxn;
  input rxp;
  input gtrefclk;
  input gt0_qplloutclk_in;
  input gt0_qplloutrefclk_in;
  input pma_reset;

  wire [4:0]configuration_vector;
  wire cplllock;
  wire data_in;
  wire data_out;
  wire encommaalign;
  wire gmii_isolate;
  wire gmii_rx_dv;
  wire gmii_rx_er;
  wire [7:0]gmii_rxd;
  wire gmii_tx_en;
  wire gmii_tx_er;
  wire [7:0]gmii_txd;
  wire gt0_qplloutclk_in;
  wire gt0_qplloutrefclk_in;
  wire gtrefclk;
  wire gtrefclk_bufg;
  wire independent_clock_bufg;
  wire mmcm_locked;
  wire mmcm_reset;
  wire pma_reset;
  wire powerdown;
  wire reset;
  wire resetdone;
  wire rxbuferr;
  wire rxchariscomma;
  wire rxcharisk;
  wire [1:0]rxclkcorcnt;
  wire [7:0]rxdata;
  wire rxdisperr;
  wire rxn;
  wire rxnotintable;
  wire rxoutclk;
  wire rxp;
  wire rxreset;
  wire signal_detect;
  wire [15:0]status_vector;
  wire transceiver_inst_n_6;
  wire txbuferr;
  wire txchardispmode;
  wire txchardispval;
  wire txcharisk;
  wire [7:0]txdata;
  wire txn;
  wire txoutclk;
  wire txp;
  wire txreset;
  wire userclk;
  wire userclk2;
  wire NLW_GigEthGth7Core_core_an_enable_UNCONNECTED;
  wire NLW_GigEthGth7Core_core_an_interrupt_UNCONNECTED;
  wire NLW_GigEthGth7Core_core_drp_den_UNCONNECTED;
  wire NLW_GigEthGth7Core_core_drp_dwe_UNCONNECTED;
  wire NLW_GigEthGth7Core_core_drp_req_UNCONNECTED;
  wire NLW_GigEthGth7Core_core_en_cdet_UNCONNECTED;
  wire NLW_GigEthGth7Core_core_ewrap_UNCONNECTED;
  wire NLW_GigEthGth7Core_core_loc_ref_UNCONNECTED;
  wire NLW_GigEthGth7Core_core_mdio_out_UNCONNECTED;
  wire NLW_GigEthGth7Core_core_mdio_tri_UNCONNECTED;
  wire [8:0]NLW_GigEthGth7Core_core_drp_daddr_UNCONNECTED;
  wire [15:0]NLW_GigEthGth7Core_core_drp_di_UNCONNECTED;
  wire [63:0]NLW_GigEthGth7Core_core_rxphy_correction_timer_UNCONNECTED;
  wire [31:0]NLW_GigEthGth7Core_core_rxphy_ns_field_UNCONNECTED;
  wire [47:0]NLW_GigEthGth7Core_core_rxphy_s_field_UNCONNECTED;
  wire [1:0]NLW_GigEthGth7Core_core_speed_selection_UNCONNECTED;
  wire [9:0]NLW_GigEthGth7Core_core_tx_code_group_UNCONNECTED;

  (* B_SHIFTER_ADDR = "8'b01010000" *) 
  (* C_1588 = "0" *) 
  (* C_COMPONENT_NAME = "GigEthGth7Core" *) 
  (* C_DYNAMIC_SWITCHING = "FALSE" *) 
  (* C_ELABORATION_TRANSIENT_DIR = "BlankString" *) 
  (* C_FAMILY = "virtex7" *) 
  (* C_HAS_AN = "FALSE" *) 
  (* C_HAS_MDIO = "FALSE" *) 
  (* C_HAS_TEMAC = "TRUE" *) 
  (* C_IS_SGMII = "FALSE" *) 
  (* C_SGMII_FABRIC_BUFFER = "TRUE" *) 
  (* C_SGMII_PHY_MODE = "FALSE" *) 
  (* C_USE_LVDS = "FALSE" *) 
  (* C_USE_TBI = "FALSE" *) 
  (* C_USE_TRANSCEIVER = "TRUE" *) 
  (* DONT_TOUCH *) 
  (* GT_RX_BYTE_WIDTH = "1" *) 
  (* RX_GT_NOMINAL_LATENCY = "16'b0000000011010010" *) 
  (* downgradeipidentifiedwarnings = "yes" *) 
  GigEthGth7Core_gig_ethernet_pcs_pma_v15_1_0 GigEthGth7Core_core
       (.an_adv_config_val(1'b0),
        .an_adv_config_vector({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .an_enable(NLW_GigEthGth7Core_core_an_enable_UNCONNECTED),
        .an_interrupt(NLW_GigEthGth7Core_core_an_interrupt_UNCONNECTED),
        .an_restart_config(1'b0),
        .basex_or_sgmii(1'b0),
        .configuration_valid(1'b0),
        .configuration_vector(configuration_vector),
        .correction_timer({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .dcm_locked(mmcm_locked),
        .drp_daddr(NLW_GigEthGth7Core_core_drp_daddr_UNCONNECTED[8:0]),
        .drp_dclk(1'b0),
        .drp_den(NLW_GigEthGth7Core_core_drp_den_UNCONNECTED),
        .drp_di(NLW_GigEthGth7Core_core_drp_di_UNCONNECTED[15:0]),
        .drp_do({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .drp_drdy(1'b0),
        .drp_dwe(NLW_GigEthGth7Core_core_drp_dwe_UNCONNECTED),
        .drp_gnt(1'b0),
        .drp_req(NLW_GigEthGth7Core_core_drp_req_UNCONNECTED),
        .en_cdet(NLW_GigEthGth7Core_core_en_cdet_UNCONNECTED),
        .enablealign(encommaalign),
        .ewrap(NLW_GigEthGth7Core_core_ewrap_UNCONNECTED),
        .gmii_isolate(gmii_isolate),
        .gmii_rx_dv(gmii_rx_dv),
        .gmii_rx_er(gmii_rx_er),
        .gmii_rxd(gmii_rxd),
        .gmii_tx_en(gmii_tx_en),
        .gmii_tx_er(gmii_tx_er),
        .gmii_txd(gmii_txd),
        .gtx_clk(1'b0),
        .link_timer_basex({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .link_timer_sgmii({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .link_timer_value({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .loc_ref(NLW_GigEthGth7Core_core_loc_ref_UNCONNECTED),
        .mdc(1'b0),
        .mdio_in(1'b0),
        .mdio_out(NLW_GigEthGth7Core_core_mdio_out_UNCONNECTED),
        .mdio_tri(NLW_GigEthGth7Core_core_mdio_tri_UNCONNECTED),
        .mgt_rx_reset(rxreset),
        .mgt_tx_reset(txreset),
        .phyad({1'b0,1'b0,1'b0,1'b0,1'b0}),
        .pma_rx_clk0(1'b0),
        .pma_rx_clk1(1'b0),
        .powerdown(powerdown),
        .reset(reset),
        .reset_done(resetdone),
        .rx_code_group0({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .rx_code_group1({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .rxbufstatus({rxbuferr,1'b0}),
        .rxchariscomma(rxchariscomma),
        .rxcharisk(rxcharisk),
        .rxclkcorcnt({1'b0,rxclkcorcnt}),
        .rxdata(rxdata),
        .rxdisperr(rxdisperr),
        .rxnotintable(rxnotintable),
        .rxphy_correction_timer(NLW_GigEthGth7Core_core_rxphy_correction_timer_UNCONNECTED[63:0]),
        .rxphy_ns_field(NLW_GigEthGth7Core_core_rxphy_ns_field_UNCONNECTED[31:0]),
        .rxphy_s_field(NLW_GigEthGth7Core_core_rxphy_s_field_UNCONNECTED[47:0]),
        .rxrecclk(1'b0),
        .rxrundisp(1'b0),
        .signal_detect(signal_detect),
        .speed_selection(NLW_GigEthGth7Core_core_speed_selection_UNCONNECTED[1:0]),
        .status_vector(status_vector),
        .systemtimer_ns_field({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .systemtimer_s_field({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .tx_code_group(NLW_GigEthGth7Core_core_tx_code_group_UNCONNECTED[9:0]),
        .txbuferr(txbuferr),
        .txchardispmode(txchardispmode),
        .txchardispval(txchardispval),
        .txcharisk(txcharisk),
        .txdata(txdata),
        .userclk(userclk2),
        .userclk2(userclk2));
  GigEthGth7Core_GigEthGth7Core_sync_block sync_block_rx_reset_done
       (.data_in(transceiver_inst_n_6),
        .data_out(data_out),
        .userclk2(userclk2));
  GigEthGth7Core_GigEthGth7Core_sync_block_0 sync_block_tx_reset_done
       (.data_in(data_in),
        .data_out(data_out),
        .resetdone(resetdone),
        .userclk2(userclk2));
  GigEthGth7Core_GigEthGth7Core_transceiver transceiver_inst
       (.SR(txreset),
        .\USE_ROCKET_IO.MGT_RX_RESET_INT_reg (rxreset),
        .cplllock(cplllock),
        .data_in(data_in),
        .data_sync_reg1(transceiver_inst_n_6),
        .encommaalign(encommaalign),
        .gt0_qplloutclk_in(gt0_qplloutclk_in),
        .gt0_qplloutrefclk_in(gt0_qplloutrefclk_in),
        .gtrefclk(gtrefclk),
        .gtrefclk_bufg(gtrefclk_bufg),
        .independent_clock_bufg(independent_clock_bufg),
        .mmcm_locked(mmcm_locked),
        .mmcm_reset(mmcm_reset),
        .pma_reset(pma_reset),
        .powerdown(powerdown),
        .rxbuferr(rxbuferr),
        .rxchariscomma(rxchariscomma),
        .rxcharisk(rxcharisk),
        .rxclkcorcnt(rxclkcorcnt),
        .rxdata(rxdata),
        .rxdisperr(rxdisperr),
        .rxn(rxn),
        .rxnotintable(rxnotintable),
        .rxoutclk(rxoutclk),
        .rxp(rxp),
        .status_vector(status_vector[1]),
        .txbuferr(txbuferr),
        .txchardispmode(txchardispmode),
        .txchardispval(txchardispval),
        .txcharisk(txcharisk),
        .txdata(txdata),
        .txn(txn),
        .txoutclk(txoutclk),
        .txp(txp),
        .userclk(userclk),
        .userclk2(userclk2));
endmodule

(* ORIG_REF_NAME = "GigEthGth7Core_cpll_railing" *) 
module GigEthGth7Core_GigEthGth7Core_cpll_railing
   (cpll_pd_out,
    cpllreset_in,
    gtrefclk_bufg,
    CPLL_RESET);
  output cpll_pd_out;
  output cpllreset_in;
  input gtrefclk_bufg;
  input CPLL_RESET;

  wire CPLL_RESET;
  wire cpll_pd_out;
  wire cpll_reset_out;
  wire \cpllpd_wait_reg[31]_srl32_n_1 ;
  wire \cpllpd_wait_reg[63]_srl32_n_1 ;
  wire \cpllpd_wait_reg[94]_srl31_n_0 ;
  wire cpllreset_in;
  wire \cpllreset_wait_reg[126]_srl31_n_0 ;
  wire \cpllreset_wait_reg[31]_srl32_n_1 ;
  wire \cpllreset_wait_reg[63]_srl32_n_1 ;
  wire \cpllreset_wait_reg[95]_srl32_n_1 ;
  wire gtrefclk_bufg;
  wire \NLW_cpllpd_wait_reg[31]_srl32_Q_UNCONNECTED ;
  wire \NLW_cpllpd_wait_reg[63]_srl32_Q_UNCONNECTED ;
  wire \NLW_cpllpd_wait_reg[94]_srl31_Q31_UNCONNECTED ;
  wire \NLW_cpllreset_wait_reg[126]_srl31_Q31_UNCONNECTED ;
  wire \NLW_cpllreset_wait_reg[31]_srl32_Q_UNCONNECTED ;
  wire \NLW_cpllreset_wait_reg[63]_srl32_Q_UNCONNECTED ;
  wire \NLW_cpllreset_wait_reg[95]_srl32_Q_UNCONNECTED ;

  (* srl_bus_name = "\U0/transceiver_inst/gtwizard_inst/U0/gtwizard_i/cpll_railing0_i/cpllpd_wait_reg " *) 
  (* srl_name = "\U0/transceiver_inst/gtwizard_inst/U0/gtwizard_i/cpll_railing0_i/cpllpd_wait_reg[31]_srl32 " *) 
  SRLC32E #(
    .INIT(32'hFFFFFFFF)) 
    \cpllpd_wait_reg[31]_srl32 
       (.A({1'b1,1'b1,1'b1,1'b1,1'b1}),
        .CE(1'b1),
        .CLK(gtrefclk_bufg),
        .D(1'b0),
        .Q(\NLW_cpllpd_wait_reg[31]_srl32_Q_UNCONNECTED ),
        .Q31(\cpllpd_wait_reg[31]_srl32_n_1 ));
  (* srl_bus_name = "\U0/transceiver_inst/gtwizard_inst/U0/gtwizard_i/cpll_railing0_i/cpllpd_wait_reg " *) 
  (* srl_name = "\U0/transceiver_inst/gtwizard_inst/U0/gtwizard_i/cpll_railing0_i/cpllpd_wait_reg[63]_srl32 " *) 
  SRLC32E #(
    .INIT(32'hFFFFFFFF)) 
    \cpllpd_wait_reg[63]_srl32 
       (.A({1'b1,1'b1,1'b1,1'b1,1'b1}),
        .CE(1'b1),
        .CLK(gtrefclk_bufg),
        .D(\cpllpd_wait_reg[31]_srl32_n_1 ),
        .Q(\NLW_cpllpd_wait_reg[63]_srl32_Q_UNCONNECTED ),
        .Q31(\cpllpd_wait_reg[63]_srl32_n_1 ));
  (* srl_bus_name = "\U0/transceiver_inst/gtwizard_inst/U0/gtwizard_i/cpll_railing0_i/cpllpd_wait_reg " *) 
  (* srl_name = "\U0/transceiver_inst/gtwizard_inst/U0/gtwizard_i/cpll_railing0_i/cpllpd_wait_reg[94]_srl31 " *) 
  SRLC32E #(
    .INIT(32'h7FFFFFFF)) 
    \cpllpd_wait_reg[94]_srl31 
       (.A({1'b1,1'b1,1'b1,1'b1,1'b0}),
        .CE(1'b1),
        .CLK(gtrefclk_bufg),
        .D(\cpllpd_wait_reg[63]_srl32_n_1 ),
        .Q(\cpllpd_wait_reg[94]_srl31_n_0 ),
        .Q31(\NLW_cpllpd_wait_reg[94]_srl31_Q31_UNCONNECTED ));
  (* equivalent_register_removal = "no" *) 
  FDRE #(
    .INIT(1'b1)) 
    \cpllpd_wait_reg[95] 
       (.C(gtrefclk_bufg),
        .CE(1'b1),
        .D(\cpllpd_wait_reg[94]_srl31_n_0 ),
        .Q(cpll_pd_out),
        .R(1'b0));
  (* srl_bus_name = "\U0/transceiver_inst/gtwizard_inst/U0/gtwizard_i/cpll_railing0_i/cpllreset_wait_reg " *) 
  (* srl_name = "\U0/transceiver_inst/gtwizard_inst/U0/gtwizard_i/cpll_railing0_i/cpllreset_wait_reg[126]_srl31 " *) 
  SRLC32E #(
    .INIT(32'h00000000)) 
    \cpllreset_wait_reg[126]_srl31 
       (.A({1'b1,1'b1,1'b1,1'b1,1'b0}),
        .CE(1'b1),
        .CLK(gtrefclk_bufg),
        .D(\cpllreset_wait_reg[95]_srl32_n_1 ),
        .Q(\cpllreset_wait_reg[126]_srl31_n_0 ),
        .Q31(\NLW_cpllreset_wait_reg[126]_srl31_Q31_UNCONNECTED ));
  (* equivalent_register_removal = "no" *) 
  FDRE #(
    .INIT(1'b0)) 
    \cpllreset_wait_reg[127] 
       (.C(gtrefclk_bufg),
        .CE(1'b1),
        .D(\cpllreset_wait_reg[126]_srl31_n_0 ),
        .Q(cpll_reset_out),
        .R(1'b0));
  (* srl_bus_name = "\U0/transceiver_inst/gtwizard_inst/U0/gtwizard_i/cpll_railing0_i/cpllreset_wait_reg " *) 
  (* srl_name = "\U0/transceiver_inst/gtwizard_inst/U0/gtwizard_i/cpll_railing0_i/cpllreset_wait_reg[31]_srl32 " *) 
  SRLC32E #(
    .INIT(32'h000000FF)) 
    \cpllreset_wait_reg[31]_srl32 
       (.A({1'b1,1'b1,1'b1,1'b1,1'b1}),
        .CE(1'b1),
        .CLK(gtrefclk_bufg),
        .D(1'b0),
        .Q(\NLW_cpllreset_wait_reg[31]_srl32_Q_UNCONNECTED ),
        .Q31(\cpllreset_wait_reg[31]_srl32_n_1 ));
  (* srl_bus_name = "\U0/transceiver_inst/gtwizard_inst/U0/gtwizard_i/cpll_railing0_i/cpllreset_wait_reg " *) 
  (* srl_name = "\U0/transceiver_inst/gtwizard_inst/U0/gtwizard_i/cpll_railing0_i/cpllreset_wait_reg[63]_srl32 " *) 
  SRLC32E #(
    .INIT(32'h00000000)) 
    \cpllreset_wait_reg[63]_srl32 
       (.A({1'b1,1'b1,1'b1,1'b1,1'b1}),
        .CE(1'b1),
        .CLK(gtrefclk_bufg),
        .D(\cpllreset_wait_reg[31]_srl32_n_1 ),
        .Q(\NLW_cpllreset_wait_reg[63]_srl32_Q_UNCONNECTED ),
        .Q31(\cpllreset_wait_reg[63]_srl32_n_1 ));
  (* srl_bus_name = "\U0/transceiver_inst/gtwizard_inst/U0/gtwizard_i/cpll_railing0_i/cpllreset_wait_reg " *) 
  (* srl_name = "\U0/transceiver_inst/gtwizard_inst/U0/gtwizard_i/cpll_railing0_i/cpllreset_wait_reg[95]_srl32 " *) 
  SRLC32E #(
    .INIT(32'h00000000)) 
    \cpllreset_wait_reg[95]_srl32 
       (.A({1'b1,1'b1,1'b1,1'b1,1'b1}),
        .CE(1'b1),
        .CLK(gtrefclk_bufg),
        .D(\cpllreset_wait_reg[63]_srl32_n_1 ),
        .Q(\NLW_cpllreset_wait_reg[95]_srl32_Q_UNCONNECTED ),
        .Q31(\cpllreset_wait_reg[95]_srl32_n_1 ));
  LUT2 #(
    .INIT(4'hE)) 
    gthe2_i_i_1
       (.I0(cpll_reset_out),
        .I1(CPLL_RESET),
        .O(cpllreset_in));
endmodule

(* ORIG_REF_NAME = "GigEthGth7Core_gtwizard_gtrxreset_seq" *) 
module GigEthGth7Core_GigEthGth7Core_gtwizard_gtrxreset_seq
   (GTRXRESET,
    DRP_OP_DONE,
    DRPDI,
    drp_busy_i1_reg,
    DRPEN,
    DRPWE,
    gtrefclk_bufg,
    \cpllpd_wait_reg[95] ,
    \state_reg[0]_0 ,
    \state_reg[3] ,
    \state_reg[2]_0 ,
    Q,
    D,
    SR,
    data_in,
    CPLL_RESET);
  output GTRXRESET;
  output DRP_OP_DONE;
  output [15:0]DRPDI;
  output drp_busy_i1_reg;
  output DRPEN;
  output DRPWE;
  input gtrefclk_bufg;
  input \cpllpd_wait_reg[95] ;
  input \state_reg[0]_0 ;
  input \state_reg[3] ;
  input \state_reg[2]_0 ;
  input [14:0]Q;
  input [15:0]D;
  input [0:0]SR;
  input data_in;
  input CPLL_RESET;

  wire CPLL_RESET;
  wire [15:0]D;
  wire [15:0]DRPDI;
  wire DRPEN;
  wire DRPWE;
  wire DRP_OP_DONE;
  wire GTRXRESET;
  wire [14:0]Q;
  wire [0:0]SR;
  wire \cpllpd_wait_reg[95] ;
  wire data_in;
  wire data_out;
  wire drp_busy_i1_reg;
  wire drp_op_done_o_i_1_n_0;
  wire flag;
  wire flag_i_1_n_0;
  wire gthe2_i_i_24_n_0;
  wire gtrefclk_bufg;
  wire gtrxreset_i;
  wire gtrxreset_s;
  wire gtrxreset_ss;
  wire [2:0]next_state;
  wire [15:0]original_rd_data;
  wire original_rd_data0;
  wire [15:0]rd_data;
  wire \rd_data[0]_i_1__0_n_0 ;
  wire \rd_data[10]_i_1__0_n_0 ;
  wire \rd_data[11]_i_1__0_n_0 ;
  wire \rd_data[12]_i_1__0_n_0 ;
  wire \rd_data[13]_i_1__0_n_0 ;
  wire \rd_data[14]_i_1__0_n_0 ;
  wire \rd_data[15]_i_1_n_0 ;
  wire \rd_data[15]_i_2__0_n_0 ;
  wire \rd_data[1]_i_1__0_n_0 ;
  wire \rd_data[2]_i_1__0_n_0 ;
  wire \rd_data[3]_i_1__0_n_0 ;
  wire \rd_data[4]_i_1__0_n_0 ;
  wire \rd_data[5]_i_1__0_n_0 ;
  wire \rd_data[6]_i_1__0_n_0 ;
  wire \rd_data[7]_i_1__0_n_0 ;
  wire \rd_data[8]_i_1__0_n_0 ;
  wire \rd_data[9]_i_1__0_n_0 ;
  wire reset_out;
  wire rxpmaresetdone_s;
  wire rxpmaresetdone_ss;
  wire rxpmaresetdone_sss;
  wire \state[0]_i_2_n_0 ;
  wire \state_reg[0]_0 ;
  wire \state_reg[2]_0 ;
  wire \state_reg[3] ;
  wire \state_reg_n_0_[0] ;
  wire \state_reg_n_0_[1] ;
  wire \state_reg_n_0_[2] ;
  wire sync_rst_sync_n_0;

  (* SOFT_HLUTNM = "soft_lutpair59" *) 
  LUT1 #(
    .INIT(2'h1)) 
    drp_busy_i1_i_1
       (.I0(DRP_OP_DONE),
        .O(drp_busy_i1_reg));
  (* SOFT_HLUTNM = "soft_lutpair58" *) 
  LUT5 #(
    .INIT(32'hFFFF8000)) 
    drp_op_done_o_i_1
       (.I0(\state_reg_n_0_[1] ),
        .I1(\state_reg_n_0_[0] ),
        .I2(\cpllpd_wait_reg[95] ),
        .I3(\state_reg_n_0_[2] ),
        .I4(DRP_OP_DONE),
        .O(drp_op_done_o_i_1_n_0));
  FDCE drp_op_done_o_reg
       (.C(gtrefclk_bufg),
        .CE(1'b1),
        .CLR(gtrxreset_ss),
        .D(drp_op_done_o_i_1_n_0),
        .Q(DRP_OP_DONE));
  LUT4 #(
    .INIT(16'h3FEA)) 
    flag_i_1
       (.I0(flag),
        .I1(\state_reg_n_0_[1] ),
        .I2(\state_reg_n_0_[0] ),
        .I3(\state_reg_n_0_[2] ),
        .O(flag_i_1_n_0));
  FDRE #(
    .INIT(1'b0)) 
    flag_reg
       (.C(gtrefclk_bufg),
        .CE(1'b1),
        .D(flag_i_1_n_0),
        .Q(flag),
        .R(1'b0));
  LUT4 #(
    .INIT(16'h4F44)) 
    gthe2_i_i_10
       (.I0(gthe2_i_i_24_n_0),
        .I1(rd_data[10]),
        .I2(\state_reg[2]_0 ),
        .I3(Q[10]),
        .O(DRPDI[10]));
  LUT4 #(
    .INIT(16'h4F44)) 
    gthe2_i_i_11
       (.I0(gthe2_i_i_24_n_0),
        .I1(rd_data[9]),
        .I2(\state_reg[2]_0 ),
        .I3(Q[9]),
        .O(DRPDI[9]));
  LUT4 #(
    .INIT(16'h4F44)) 
    gthe2_i_i_12
       (.I0(gthe2_i_i_24_n_0),
        .I1(rd_data[8]),
        .I2(\state_reg[2]_0 ),
        .I3(Q[8]),
        .O(DRPDI[8]));
  LUT4 #(
    .INIT(16'h4F44)) 
    gthe2_i_i_13
       (.I0(gthe2_i_i_24_n_0),
        .I1(rd_data[7]),
        .I2(\state_reg[2]_0 ),
        .I3(Q[7]),
        .O(DRPDI[7]));
  LUT4 #(
    .INIT(16'h4F44)) 
    gthe2_i_i_14
       (.I0(gthe2_i_i_24_n_0),
        .I1(rd_data[6]),
        .I2(\state_reg[2]_0 ),
        .I3(Q[6]),
        .O(DRPDI[6]));
  LUT4 #(
    .INIT(16'h4F44)) 
    gthe2_i_i_15
       (.I0(gthe2_i_i_24_n_0),
        .I1(rd_data[5]),
        .I2(\state_reg[2]_0 ),
        .I3(Q[5]),
        .O(DRPDI[5]));
  LUT4 #(
    .INIT(16'h4F44)) 
    gthe2_i_i_16
       (.I0(gthe2_i_i_24_n_0),
        .I1(rd_data[4]),
        .I2(\state_reg[2]_0 ),
        .I3(Q[4]),
        .O(DRPDI[4]));
  LUT4 #(
    .INIT(16'h4F44)) 
    gthe2_i_i_17
       (.I0(gthe2_i_i_24_n_0),
        .I1(rd_data[3]),
        .I2(\state_reg[2]_0 ),
        .I3(Q[3]),
        .O(DRPDI[3]));
  LUT4 #(
    .INIT(16'h4F44)) 
    gthe2_i_i_18
       (.I0(gthe2_i_i_24_n_0),
        .I1(rd_data[2]),
        .I2(\state_reg[2]_0 ),
        .I3(Q[2]),
        .O(DRPDI[2]));
  LUT4 #(
    .INIT(16'h4F44)) 
    gthe2_i_i_19
       (.I0(gthe2_i_i_24_n_0),
        .I1(rd_data[1]),
        .I2(\state_reg[2]_0 ),
        .I3(Q[1]),
        .O(DRPDI[1]));
  LUT5 #(
    .INIT(32'hAABBBAAA)) 
    gthe2_i_i_2
       (.I0(\state_reg[3] ),
        .I1(DRP_OP_DONE),
        .I2(\state_reg_n_0_[1] ),
        .I3(\state_reg_n_0_[2] ),
        .I4(\state_reg_n_0_[0] ),
        .O(DRPEN));
  LUT4 #(
    .INIT(16'h4F44)) 
    gthe2_i_i_20
       (.I0(gthe2_i_i_24_n_0),
        .I1(rd_data[0]),
        .I2(\state_reg[2]_0 ),
        .I3(Q[0]),
        .O(DRPDI[0]));
  (* SOFT_HLUTNM = "soft_lutpair58" *) 
  LUT4 #(
    .INIT(16'hEBFF)) 
    gthe2_i_i_24
       (.I0(DRP_OP_DONE),
        .I1(\state_reg_n_0_[2] ),
        .I2(\state_reg_n_0_[0] ),
        .I3(\state_reg_n_0_[1] ),
        .O(gthe2_i_i_24_n_0));
  (* SOFT_HLUTNM = "soft_lutpair59" *) 
  LUT5 #(
    .INIT(32'h0028FFFF)) 
    gthe2_i_i_3
       (.I0(\state_reg_n_0_[1] ),
        .I1(\state_reg_n_0_[0] ),
        .I2(\state_reg_n_0_[2] ),
        .I3(DRP_OP_DONE),
        .I4(\state_reg[2]_0 ),
        .O(DRPWE));
  LUT4 #(
    .INIT(16'h4F44)) 
    gthe2_i_i_5
       (.I0(gthe2_i_i_24_n_0),
        .I1(rd_data[15]),
        .I2(\state_reg[2]_0 ),
        .I3(Q[14]),
        .O(DRPDI[15]));
  LUT4 #(
    .INIT(16'h4F44)) 
    gthe2_i_i_6
       (.I0(gthe2_i_i_24_n_0),
        .I1(rd_data[14]),
        .I2(\state_reg[2]_0 ),
        .I3(Q[13]),
        .O(DRPDI[14]));
  LUT4 #(
    .INIT(16'h4F44)) 
    gthe2_i_i_7
       (.I0(gthe2_i_i_24_n_0),
        .I1(rd_data[13]),
        .I2(\state_reg[2]_0 ),
        .I3(Q[12]),
        .O(DRPDI[13]));
  LUT4 #(
    .INIT(16'h4F44)) 
    gthe2_i_i_8
       (.I0(gthe2_i_i_24_n_0),
        .I1(rd_data[12]),
        .I2(\state_reg[2]_0 ),
        .I3(Q[11]),
        .O(DRPDI[12]));
  LUT6 #(
    .INIT(64'hAAAAAAAABAAAAAAA)) 
    gthe2_i_i_9
       (.I0(\state_reg[0]_0 ),
        .I1(DRP_OP_DONE),
        .I2(rd_data[11]),
        .I3(\state_reg_n_0_[1] ),
        .I4(\state_reg_n_0_[2] ),
        .I5(\state_reg_n_0_[0] ),
        .O(DRPDI[11]));
  (* SOFT_HLUTNM = "soft_lutpair60" *) 
  LUT4 #(
    .INIT(16'h2F3C)) 
    gtrxreset_o_i_1
       (.I0(gtrxreset_ss),
        .I1(\state_reg_n_0_[1] ),
        .I2(\state_reg_n_0_[2] ),
        .I3(\state_reg_n_0_[0] ),
        .O(gtrxreset_i));
  FDCE gtrxreset_o_reg
       (.C(gtrefclk_bufg),
        .CE(1'b1),
        .CLR(sync_rst_sync_n_0),
        .D(gtrxreset_i),
        .Q(GTRXRESET));
  FDCE gtrxreset_s_reg
       (.C(gtrefclk_bufg),
        .CE(1'b1),
        .CLR(sync_rst_sync_n_0),
        .D(reset_out),
        .Q(gtrxreset_s));
  FDCE gtrxreset_ss_reg
       (.C(gtrefclk_bufg),
        .CE(1'b1),
        .CLR(sync_rst_sync_n_0),
        .D(gtrxreset_s),
        .Q(gtrxreset_ss));
  LUT5 #(
    .INIT(32'h00000020)) 
    \original_rd_data[15]_i_1 
       (.I0(\cpllpd_wait_reg[95] ),
        .I1(\state_reg_n_0_[0] ),
        .I2(\state_reg_n_0_[1] ),
        .I3(\state_reg_n_0_[2] ),
        .I4(flag),
        .O(original_rd_data0));
  FDRE \original_rd_data_reg[0] 
       (.C(gtrefclk_bufg),
        .CE(original_rd_data0),
        .D(D[0]),
        .Q(original_rd_data[0]),
        .R(1'b0));
  FDRE \original_rd_data_reg[10] 
       (.C(gtrefclk_bufg),
        .CE(original_rd_data0),
        .D(D[10]),
        .Q(original_rd_data[10]),
        .R(1'b0));
  FDRE \original_rd_data_reg[11] 
       (.C(gtrefclk_bufg),
        .CE(original_rd_data0),
        .D(D[11]),
        .Q(original_rd_data[11]),
        .R(1'b0));
  FDRE \original_rd_data_reg[12] 
       (.C(gtrefclk_bufg),
        .CE(original_rd_data0),
        .D(D[12]),
        .Q(original_rd_data[12]),
        .R(1'b0));
  FDRE \original_rd_data_reg[13] 
       (.C(gtrefclk_bufg),
        .CE(original_rd_data0),
        .D(D[13]),
        .Q(original_rd_data[13]),
        .R(1'b0));
  FDRE \original_rd_data_reg[14] 
       (.C(gtrefclk_bufg),
        .CE(original_rd_data0),
        .D(D[14]),
        .Q(original_rd_data[14]),
        .R(1'b0));
  FDRE \original_rd_data_reg[15] 
       (.C(gtrefclk_bufg),
        .CE(original_rd_data0),
        .D(D[15]),
        .Q(original_rd_data[15]),
        .R(1'b0));
  FDRE \original_rd_data_reg[1] 
       (.C(gtrefclk_bufg),
        .CE(original_rd_data0),
        .D(D[1]),
        .Q(original_rd_data[1]),
        .R(1'b0));
  FDRE \original_rd_data_reg[2] 
       (.C(gtrefclk_bufg),
        .CE(original_rd_data0),
        .D(D[2]),
        .Q(original_rd_data[2]),
        .R(1'b0));
  FDRE \original_rd_data_reg[3] 
       (.C(gtrefclk_bufg),
        .CE(original_rd_data0),
        .D(D[3]),
        .Q(original_rd_data[3]),
        .R(1'b0));
  FDRE \original_rd_data_reg[4] 
       (.C(gtrefclk_bufg),
        .CE(original_rd_data0),
        .D(D[4]),
        .Q(original_rd_data[4]),
        .R(1'b0));
  FDRE \original_rd_data_reg[5] 
       (.C(gtrefclk_bufg),
        .CE(original_rd_data0),
        .D(D[5]),
        .Q(original_rd_data[5]),
        .R(1'b0));
  FDRE \original_rd_data_reg[6] 
       (.C(gtrefclk_bufg),
        .CE(original_rd_data0),
        .D(D[6]),
        .Q(original_rd_data[6]),
        .R(1'b0));
  FDRE \original_rd_data_reg[7] 
       (.C(gtrefclk_bufg),
        .CE(original_rd_data0),
        .D(D[7]),
        .Q(original_rd_data[7]),
        .R(1'b0));
  FDRE \original_rd_data_reg[8] 
       (.C(gtrefclk_bufg),
        .CE(original_rd_data0),
        .D(D[8]),
        .Q(original_rd_data[8]),
        .R(1'b0));
  FDRE \original_rd_data_reg[9] 
       (.C(gtrefclk_bufg),
        .CE(original_rd_data0),
        .D(D[9]),
        .Q(original_rd_data[9]),
        .R(1'b0));
  LUT4 #(
    .INIT(16'hFB08)) 
    \rd_data[0]_i_1__0 
       (.I0(D[0]),
        .I1(\cpllpd_wait_reg[95] ),
        .I2(flag),
        .I3(original_rd_data[0]),
        .O(\rd_data[0]_i_1__0_n_0 ));
  LUT4 #(
    .INIT(16'hFB08)) 
    \rd_data[10]_i_1__0 
       (.I0(D[10]),
        .I1(\cpllpd_wait_reg[95] ),
        .I2(flag),
        .I3(original_rd_data[10]),
        .O(\rd_data[10]_i_1__0_n_0 ));
  LUT4 #(
    .INIT(16'hFB08)) 
    \rd_data[11]_i_1__0 
       (.I0(D[11]),
        .I1(\cpllpd_wait_reg[95] ),
        .I2(flag),
        .I3(original_rd_data[11]),
        .O(\rd_data[11]_i_1__0_n_0 ));
  LUT4 #(
    .INIT(16'hFB08)) 
    \rd_data[12]_i_1__0 
       (.I0(D[12]),
        .I1(\cpllpd_wait_reg[95] ),
        .I2(flag),
        .I3(original_rd_data[12]),
        .O(\rd_data[12]_i_1__0_n_0 ));
  LUT4 #(
    .INIT(16'hFB08)) 
    \rd_data[13]_i_1__0 
       (.I0(D[13]),
        .I1(\cpllpd_wait_reg[95] ),
        .I2(flag),
        .I3(original_rd_data[13]),
        .O(\rd_data[13]_i_1__0_n_0 ));
  LUT4 #(
    .INIT(16'hFB08)) 
    \rd_data[14]_i_1__0 
       (.I0(D[14]),
        .I1(\cpllpd_wait_reg[95] ),
        .I2(flag),
        .I3(original_rd_data[14]),
        .O(\rd_data[14]_i_1__0_n_0 ));
  LUT4 #(
    .INIT(16'h0400)) 
    \rd_data[15]_i_1 
       (.I0(\state_reg_n_0_[2] ),
        .I1(\state_reg_n_0_[1] ),
        .I2(\state_reg_n_0_[0] ),
        .I3(\cpllpd_wait_reg[95] ),
        .O(\rd_data[15]_i_1_n_0 ));
  LUT4 #(
    .INIT(16'hFB08)) 
    \rd_data[15]_i_2__0 
       (.I0(D[15]),
        .I1(\cpllpd_wait_reg[95] ),
        .I2(flag),
        .I3(original_rd_data[15]),
        .O(\rd_data[15]_i_2__0_n_0 ));
  LUT4 #(
    .INIT(16'hFB08)) 
    \rd_data[1]_i_1__0 
       (.I0(D[1]),
        .I1(\cpllpd_wait_reg[95] ),
        .I2(flag),
        .I3(original_rd_data[1]),
        .O(\rd_data[1]_i_1__0_n_0 ));
  LUT4 #(
    .INIT(16'hFB08)) 
    \rd_data[2]_i_1__0 
       (.I0(D[2]),
        .I1(\cpllpd_wait_reg[95] ),
        .I2(flag),
        .I3(original_rd_data[2]),
        .O(\rd_data[2]_i_1__0_n_0 ));
  LUT4 #(
    .INIT(16'hFB08)) 
    \rd_data[3]_i_1__0 
       (.I0(D[3]),
        .I1(\cpllpd_wait_reg[95] ),
        .I2(flag),
        .I3(original_rd_data[3]),
        .O(\rd_data[3]_i_1__0_n_0 ));
  LUT4 #(
    .INIT(16'hFB08)) 
    \rd_data[4]_i_1__0 
       (.I0(D[4]),
        .I1(\cpllpd_wait_reg[95] ),
        .I2(flag),
        .I3(original_rd_data[4]),
        .O(\rd_data[4]_i_1__0_n_0 ));
  LUT4 #(
    .INIT(16'hFB08)) 
    \rd_data[5]_i_1__0 
       (.I0(D[5]),
        .I1(\cpllpd_wait_reg[95] ),
        .I2(flag),
        .I3(original_rd_data[5]),
        .O(\rd_data[5]_i_1__0_n_0 ));
  LUT4 #(
    .INIT(16'hFB08)) 
    \rd_data[6]_i_1__0 
       (.I0(D[6]),
        .I1(\cpllpd_wait_reg[95] ),
        .I2(flag),
        .I3(original_rd_data[6]),
        .O(\rd_data[6]_i_1__0_n_0 ));
  LUT4 #(
    .INIT(16'hFB08)) 
    \rd_data[7]_i_1__0 
       (.I0(D[7]),
        .I1(\cpllpd_wait_reg[95] ),
        .I2(flag),
        .I3(original_rd_data[7]),
        .O(\rd_data[7]_i_1__0_n_0 ));
  LUT4 #(
    .INIT(16'hFB08)) 
    \rd_data[8]_i_1__0 
       (.I0(D[8]),
        .I1(\cpllpd_wait_reg[95] ),
        .I2(flag),
        .I3(original_rd_data[8]),
        .O(\rd_data[8]_i_1__0_n_0 ));
  LUT4 #(
    .INIT(16'hFB08)) 
    \rd_data[9]_i_1__0 
       (.I0(D[9]),
        .I1(\cpllpd_wait_reg[95] ),
        .I2(flag),
        .I3(original_rd_data[9]),
        .O(\rd_data[9]_i_1__0_n_0 ));
  FDCE \rd_data_reg[0] 
       (.C(gtrefclk_bufg),
        .CE(\rd_data[15]_i_1_n_0 ),
        .CLR(sync_rst_sync_n_0),
        .D(\rd_data[0]_i_1__0_n_0 ),
        .Q(rd_data[0]));
  FDCE \rd_data_reg[10] 
       (.C(gtrefclk_bufg),
        .CE(\rd_data[15]_i_1_n_0 ),
        .CLR(sync_rst_sync_n_0),
        .D(\rd_data[10]_i_1__0_n_0 ),
        .Q(rd_data[10]));
  FDCE \rd_data_reg[11] 
       (.C(gtrefclk_bufg),
        .CE(\rd_data[15]_i_1_n_0 ),
        .CLR(sync_rst_sync_n_0),
        .D(\rd_data[11]_i_1__0_n_0 ),
        .Q(rd_data[11]));
  FDCE \rd_data_reg[12] 
       (.C(gtrefclk_bufg),
        .CE(\rd_data[15]_i_1_n_0 ),
        .CLR(sync_rst_sync_n_0),
        .D(\rd_data[12]_i_1__0_n_0 ),
        .Q(rd_data[12]));
  FDCE \rd_data_reg[13] 
       (.C(gtrefclk_bufg),
        .CE(\rd_data[15]_i_1_n_0 ),
        .CLR(sync_rst_sync_n_0),
        .D(\rd_data[13]_i_1__0_n_0 ),
        .Q(rd_data[13]));
  FDCE \rd_data_reg[14] 
       (.C(gtrefclk_bufg),
        .CE(\rd_data[15]_i_1_n_0 ),
        .CLR(sync_rst_sync_n_0),
        .D(\rd_data[14]_i_1__0_n_0 ),
        .Q(rd_data[14]));
  FDCE \rd_data_reg[15] 
       (.C(gtrefclk_bufg),
        .CE(\rd_data[15]_i_1_n_0 ),
        .CLR(sync_rst_sync_n_0),
        .D(\rd_data[15]_i_2__0_n_0 ),
        .Q(rd_data[15]));
  FDCE \rd_data_reg[1] 
       (.C(gtrefclk_bufg),
        .CE(\rd_data[15]_i_1_n_0 ),
        .CLR(sync_rst_sync_n_0),
        .D(\rd_data[1]_i_1__0_n_0 ),
        .Q(rd_data[1]));
  FDCE \rd_data_reg[2] 
       (.C(gtrefclk_bufg),
        .CE(\rd_data[15]_i_1_n_0 ),
        .CLR(sync_rst_sync_n_0),
        .D(\rd_data[2]_i_1__0_n_0 ),
        .Q(rd_data[2]));
  FDCE \rd_data_reg[3] 
       (.C(gtrefclk_bufg),
        .CE(\rd_data[15]_i_1_n_0 ),
        .CLR(sync_rst_sync_n_0),
        .D(\rd_data[3]_i_1__0_n_0 ),
        .Q(rd_data[3]));
  FDCE \rd_data_reg[4] 
       (.C(gtrefclk_bufg),
        .CE(\rd_data[15]_i_1_n_0 ),
        .CLR(sync_rst_sync_n_0),
        .D(\rd_data[4]_i_1__0_n_0 ),
        .Q(rd_data[4]));
  FDCE \rd_data_reg[5] 
       (.C(gtrefclk_bufg),
        .CE(\rd_data[15]_i_1_n_0 ),
        .CLR(sync_rst_sync_n_0),
        .D(\rd_data[5]_i_1__0_n_0 ),
        .Q(rd_data[5]));
  FDCE \rd_data_reg[6] 
       (.C(gtrefclk_bufg),
        .CE(\rd_data[15]_i_1_n_0 ),
        .CLR(sync_rst_sync_n_0),
        .D(\rd_data[6]_i_1__0_n_0 ),
        .Q(rd_data[6]));
  FDCE \rd_data_reg[7] 
       (.C(gtrefclk_bufg),
        .CE(\rd_data[15]_i_1_n_0 ),
        .CLR(sync_rst_sync_n_0),
        .D(\rd_data[7]_i_1__0_n_0 ),
        .Q(rd_data[7]));
  FDCE \rd_data_reg[8] 
       (.C(gtrefclk_bufg),
        .CE(\rd_data[15]_i_1_n_0 ),
        .CLR(sync_rst_sync_n_0),
        .D(\rd_data[8]_i_1__0_n_0 ),
        .Q(rd_data[8]));
  FDCE \rd_data_reg[9] 
       (.C(gtrefclk_bufg),
        .CE(\rd_data[15]_i_1_n_0 ),
        .CLR(sync_rst_sync_n_0),
        .D(\rd_data[9]_i_1__0_n_0 ),
        .Q(rd_data[9]));
  FDCE rxpmaresetdone_s_reg
       (.C(gtrefclk_bufg),
        .CE(1'b1),
        .CLR(sync_rst_sync_n_0),
        .D(data_out),
        .Q(rxpmaresetdone_s));
  FDCE rxpmaresetdone_ss_reg
       (.C(gtrefclk_bufg),
        .CE(1'b1),
        .CLR(sync_rst_sync_n_0),
        .D(rxpmaresetdone_s),
        .Q(rxpmaresetdone_ss));
  FDCE rxpmaresetdone_sss_reg
       (.C(gtrefclk_bufg),
        .CE(1'b1),
        .CLR(sync_rst_sync_n_0),
        .D(rxpmaresetdone_ss),
        .Q(rxpmaresetdone_sss));
  LUT6 #(
    .INIT(64'h0C880C88FCF3FCC0)) 
    \state[0]_i_1 
       (.I0(\state[0]_i_2_n_0 ),
        .I1(\state_reg_n_0_[2] ),
        .I2(\cpllpd_wait_reg[95] ),
        .I3(\state_reg_n_0_[1] ),
        .I4(gtrxreset_ss),
        .I5(\state_reg_n_0_[0] ),
        .O(next_state[0]));
  LUT2 #(
    .INIT(4'hB)) 
    \state[0]_i_2 
       (.I0(rxpmaresetdone_ss),
        .I1(rxpmaresetdone_sss),
        .O(\state[0]_i_2_n_0 ));
  LUT6 #(
    .INIT(64'h550030FFFFFF0000)) 
    \state[1]_i_1 
       (.I0(\cpllpd_wait_reg[95] ),
        .I1(rxpmaresetdone_ss),
        .I2(rxpmaresetdone_sss),
        .I3(\state_reg_n_0_[2] ),
        .I4(\state_reg_n_0_[1] ),
        .I5(\state_reg_n_0_[0] ),
        .O(next_state[1]));
  (* SOFT_HLUTNM = "soft_lutpair60" *) 
  LUT4 #(
    .INIT(16'h7CCC)) 
    \state[2]_i_1 
       (.I0(\cpllpd_wait_reg[95] ),
        .I1(\state_reg_n_0_[2] ),
        .I2(\state_reg_n_0_[1] ),
        .I3(\state_reg_n_0_[0] ),
        .O(next_state[2]));
  FDCE #(
    .INIT(1'b0)) 
    \state_reg[0] 
       (.C(gtrefclk_bufg),
        .CE(1'b1),
        .CLR(sync_rst_sync_n_0),
        .D(next_state[0]),
        .Q(\state_reg_n_0_[0] ));
  FDCE #(
    .INIT(1'b0)) 
    \state_reg[1] 
       (.C(gtrefclk_bufg),
        .CE(1'b1),
        .CLR(sync_rst_sync_n_0),
        .D(next_state[1]),
        .Q(\state_reg_n_0_[1] ));
  FDCE #(
    .INIT(1'b0)) 
    \state_reg[2] 
       (.C(gtrefclk_bufg),
        .CE(1'b1),
        .CLR(sync_rst_sync_n_0),
        .D(next_state[2]),
        .Q(\state_reg_n_0_[2] ));
  GigEthGth7Core_GigEthGth7Core_reset_sync_5 sync_gtrxreset_in
       (.SR(SR),
        .gtrefclk_bufg(gtrefclk_bufg),
        .reset_out(reset_out));
  GigEthGth7Core_GigEthGth7Core_reset_sync_6 sync_rst_sync
       (.CPLL_RESET(CPLL_RESET),
        .gtrefclk_bufg(gtrefclk_bufg),
        .reset_out(sync_rst_sync_n_0));
  GigEthGth7Core_GigEthGth7Core_sync_block_7 sync_rxpmaresetdone
       (.data_in(data_in),
        .data_out(data_out),
        .gtrefclk_bufg(gtrefclk_bufg));
endmodule

(* ORIG_REF_NAME = "GigEthGth7Core_gtwizard_rxpmarst_seq" *) 
module GigEthGth7Core_GigEthGth7Core_gtwizard_rxpmarst_seq
   (RXPMARESET,
    DRPADDR,
    data_sync_reg1,
    data_sync_reg1_0,
    data_sync_reg1_1,
    Q,
    gtrefclk_bufg,
    drp_busy_i1,
    DRP_OP_DONE,
    \cpllpd_wait_reg[95] ,
    D,
    data_in,
    CPLL_RESET);
  output RXPMARESET;
  output [0:0]DRPADDR;
  output data_sync_reg1;
  output data_sync_reg1_0;
  output data_sync_reg1_1;
  output [14:0]Q;
  input gtrefclk_bufg;
  input drp_busy_i1;
  input DRP_OP_DONE;
  input \cpllpd_wait_reg[95] ;
  input [15:0]D;
  input data_in;
  input CPLL_RESET;

  wire CPLL_RESET;
  wire [15:0]D;
  wire [0:0]DRPADDR;
  wire DRP_OP_DONE;
  wire [14:0]Q;
  wire RXPMARESET;
  wire \cpllpd_wait_reg[95] ;
  wire data_in;
  wire data_sync_reg1;
  wire data_sync_reg1_0;
  wire data_sync_reg1_1;
  wire drp_busy_i1;
  wire flag;
  wire flag_i_1__0_n_0;
  wire gtrefclk_bufg;
  wire [3:0]next_state;
  wire original_rd_data0;
  wire \original_rd_data_reg_n_0_[0] ;
  wire \original_rd_data_reg_n_0_[10] ;
  wire \original_rd_data_reg_n_0_[11] ;
  wire \original_rd_data_reg_n_0_[12] ;
  wire \original_rd_data_reg_n_0_[13] ;
  wire \original_rd_data_reg_n_0_[14] ;
  wire \original_rd_data_reg_n_0_[15] ;
  wire \original_rd_data_reg_n_0_[1] ;
  wire \original_rd_data_reg_n_0_[2] ;
  wire \original_rd_data_reg_n_0_[3] ;
  wire \original_rd_data_reg_n_0_[4] ;
  wire \original_rd_data_reg_n_0_[5] ;
  wire \original_rd_data_reg_n_0_[6] ;
  wire \original_rd_data_reg_n_0_[7] ;
  wire \original_rd_data_reg_n_0_[8] ;
  wire \original_rd_data_reg_n_0_[9] ;
  wire \rd_data[0]_i_1_n_0 ;
  wire \rd_data[10]_i_1_n_0 ;
  wire \rd_data[11]_i_1_n_0 ;
  wire \rd_data[12]_i_1_n_0 ;
  wire \rd_data[13]_i_1_n_0 ;
  wire \rd_data[14]_i_1_n_0 ;
  wire \rd_data[15]_i_1__0_n_0 ;
  wire \rd_data[15]_i_2_n_0 ;
  wire \rd_data[1]_i_1_n_0 ;
  wire \rd_data[2]_i_1_n_0 ;
  wire \rd_data[3]_i_1_n_0 ;
  wire \rd_data[4]_i_1_n_0 ;
  wire \rd_data[5]_i_1_n_0 ;
  wire \rd_data[6]_i_1_n_0 ;
  wire \rd_data[7]_i_1_n_0 ;
  wire \rd_data[8]_i_1_n_0 ;
  wire \rd_data[9]_i_1_n_0 ;
  wire \rd_data_reg_n_0_[11] ;
  wire rxpmareset_i;
  wire [3:0]state;
  wire sync_rst_sync_n_0;

  LUT5 #(
    .INIT(32'h8BBABABA)) 
    flag_i_1__0
       (.I0(flag),
        .I1(state[3]),
        .I2(state[2]),
        .I3(state[0]),
        .I4(state[1]),
        .O(flag_i_1__0_n_0));
  FDRE #(
    .INIT(1'b0)) 
    flag_reg
       (.C(gtrefclk_bufg),
        .CE(1'b1),
        .D(flag_i_1__0_n_0),
        .Q(flag),
        .R(1'b0));
  LUT6 #(
    .INIT(64'h55554544FFFFFFFF)) 
    gthe2_i_i_21
       (.I0(state[3]),
        .I1(state[2]),
        .I2(drp_busy_i1),
        .I3(state[0]),
        .I4(state[1]),
        .I5(DRP_OP_DONE),
        .O(DRPADDR));
  LUT6 #(
    .INIT(64'h0045440000000000)) 
    gthe2_i_i_22
       (.I0(state[3]),
        .I1(state[1]),
        .I2(drp_busy_i1),
        .I3(state[2]),
        .I4(state[0]),
        .I5(DRP_OP_DONE),
        .O(data_sync_reg1_0));
  (* SOFT_HLUTNM = "soft_lutpair62" *) 
  LUT5 #(
    .INIT(32'hFF9FFFFF)) 
    gthe2_i_i_23
       (.I0(state[2]),
        .I1(state[0]),
        .I2(DRP_OP_DONE),
        .I3(state[3]),
        .I4(state[1]),
        .O(data_sync_reg1_1));
  LUT6 #(
    .INIT(64'h0000400000000000)) 
    gthe2_i_i_25
       (.I0(state[0]),
        .I1(state[1]),
        .I2(DRP_OP_DONE),
        .I3(\rd_data_reg_n_0_[11] ),
        .I4(state[3]),
        .I5(state[2]),
        .O(data_sync_reg1));
  LUT6 #(
    .INIT(64'h0000000000000020)) 
    \original_rd_data[15]_i_1__0 
       (.I0(\cpllpd_wait_reg[95] ),
        .I1(state[0]),
        .I2(state[1]),
        .I3(state[2]),
        .I4(state[3]),
        .I5(flag),
        .O(original_rd_data0));
  FDRE \original_rd_data_reg[0] 
       (.C(gtrefclk_bufg),
        .CE(original_rd_data0),
        .D(D[0]),
        .Q(\original_rd_data_reg_n_0_[0] ),
        .R(1'b0));
  FDRE \original_rd_data_reg[10] 
       (.C(gtrefclk_bufg),
        .CE(original_rd_data0),
        .D(D[10]),
        .Q(\original_rd_data_reg_n_0_[10] ),
        .R(1'b0));
  FDRE \original_rd_data_reg[11] 
       (.C(gtrefclk_bufg),
        .CE(original_rd_data0),
        .D(D[11]),
        .Q(\original_rd_data_reg_n_0_[11] ),
        .R(1'b0));
  FDRE \original_rd_data_reg[12] 
       (.C(gtrefclk_bufg),
        .CE(original_rd_data0),
        .D(D[12]),
        .Q(\original_rd_data_reg_n_0_[12] ),
        .R(1'b0));
  FDRE \original_rd_data_reg[13] 
       (.C(gtrefclk_bufg),
        .CE(original_rd_data0),
        .D(D[13]),
        .Q(\original_rd_data_reg_n_0_[13] ),
        .R(1'b0));
  FDRE \original_rd_data_reg[14] 
       (.C(gtrefclk_bufg),
        .CE(original_rd_data0),
        .D(D[14]),
        .Q(\original_rd_data_reg_n_0_[14] ),
        .R(1'b0));
  FDRE \original_rd_data_reg[15] 
       (.C(gtrefclk_bufg),
        .CE(original_rd_data0),
        .D(D[15]),
        .Q(\original_rd_data_reg_n_0_[15] ),
        .R(1'b0));
  FDRE \original_rd_data_reg[1] 
       (.C(gtrefclk_bufg),
        .CE(original_rd_data0),
        .D(D[1]),
        .Q(\original_rd_data_reg_n_0_[1] ),
        .R(1'b0));
  FDRE \original_rd_data_reg[2] 
       (.C(gtrefclk_bufg),
        .CE(original_rd_data0),
        .D(D[2]),
        .Q(\original_rd_data_reg_n_0_[2] ),
        .R(1'b0));
  FDRE \original_rd_data_reg[3] 
       (.C(gtrefclk_bufg),
        .CE(original_rd_data0),
        .D(D[3]),
        .Q(\original_rd_data_reg_n_0_[3] ),
        .R(1'b0));
  FDRE \original_rd_data_reg[4] 
       (.C(gtrefclk_bufg),
        .CE(original_rd_data0),
        .D(D[4]),
        .Q(\original_rd_data_reg_n_0_[4] ),
        .R(1'b0));
  FDRE \original_rd_data_reg[5] 
       (.C(gtrefclk_bufg),
        .CE(original_rd_data0),
        .D(D[5]),
        .Q(\original_rd_data_reg_n_0_[5] ),
        .R(1'b0));
  FDRE \original_rd_data_reg[6] 
       (.C(gtrefclk_bufg),
        .CE(original_rd_data0),
        .D(D[6]),
        .Q(\original_rd_data_reg_n_0_[6] ),
        .R(1'b0));
  FDRE \original_rd_data_reg[7] 
       (.C(gtrefclk_bufg),
        .CE(original_rd_data0),
        .D(D[7]),
        .Q(\original_rd_data_reg_n_0_[7] ),
        .R(1'b0));
  FDRE \original_rd_data_reg[8] 
       (.C(gtrefclk_bufg),
        .CE(original_rd_data0),
        .D(D[8]),
        .Q(\original_rd_data_reg_n_0_[8] ),
        .R(1'b0));
  FDRE \original_rd_data_reg[9] 
       (.C(gtrefclk_bufg),
        .CE(original_rd_data0),
        .D(D[9]),
        .Q(\original_rd_data_reg_n_0_[9] ),
        .R(1'b0));
  LUT4 #(
    .INIT(16'hBA8A)) 
    \rd_data[0]_i_1 
       (.I0(\original_rd_data_reg_n_0_[0] ),
        .I1(flag),
        .I2(\cpllpd_wait_reg[95] ),
        .I3(D[0]),
        .O(\rd_data[0]_i_1_n_0 ));
  LUT4 #(
    .INIT(16'hBA8A)) 
    \rd_data[10]_i_1 
       (.I0(\original_rd_data_reg_n_0_[10] ),
        .I1(flag),
        .I2(\cpllpd_wait_reg[95] ),
        .I3(D[10]),
        .O(\rd_data[10]_i_1_n_0 ));
  LUT4 #(
    .INIT(16'hBA8A)) 
    \rd_data[11]_i_1 
       (.I0(\original_rd_data_reg_n_0_[11] ),
        .I1(flag),
        .I2(\cpllpd_wait_reg[95] ),
        .I3(D[11]),
        .O(\rd_data[11]_i_1_n_0 ));
  LUT4 #(
    .INIT(16'hBA8A)) 
    \rd_data[12]_i_1 
       (.I0(\original_rd_data_reg_n_0_[12] ),
        .I1(flag),
        .I2(\cpllpd_wait_reg[95] ),
        .I3(D[12]),
        .O(\rd_data[12]_i_1_n_0 ));
  LUT4 #(
    .INIT(16'hBA8A)) 
    \rd_data[13]_i_1 
       (.I0(\original_rd_data_reg_n_0_[13] ),
        .I1(flag),
        .I2(\cpllpd_wait_reg[95] ),
        .I3(D[13]),
        .O(\rd_data[13]_i_1_n_0 ));
  LUT4 #(
    .INIT(16'hBA8A)) 
    \rd_data[14]_i_1 
       (.I0(\original_rd_data_reg_n_0_[14] ),
        .I1(flag),
        .I2(\cpllpd_wait_reg[95] ),
        .I3(D[14]),
        .O(\rd_data[14]_i_1_n_0 ));
  LUT5 #(
    .INIT(32'h00100000)) 
    \rd_data[15]_i_1__0 
       (.I0(state[3]),
        .I1(state[2]),
        .I2(state[1]),
        .I3(state[0]),
        .I4(\cpllpd_wait_reg[95] ),
        .O(\rd_data[15]_i_1__0_n_0 ));
  LUT4 #(
    .INIT(16'hBA8A)) 
    \rd_data[15]_i_2 
       (.I0(\original_rd_data_reg_n_0_[15] ),
        .I1(flag),
        .I2(\cpllpd_wait_reg[95] ),
        .I3(D[15]),
        .O(\rd_data[15]_i_2_n_0 ));
  LUT4 #(
    .INIT(16'hBA8A)) 
    \rd_data[1]_i_1 
       (.I0(\original_rd_data_reg_n_0_[1] ),
        .I1(flag),
        .I2(\cpllpd_wait_reg[95] ),
        .I3(D[1]),
        .O(\rd_data[1]_i_1_n_0 ));
  LUT4 #(
    .INIT(16'hBA8A)) 
    \rd_data[2]_i_1 
       (.I0(\original_rd_data_reg_n_0_[2] ),
        .I1(flag),
        .I2(\cpllpd_wait_reg[95] ),
        .I3(D[2]),
        .O(\rd_data[2]_i_1_n_0 ));
  LUT4 #(
    .INIT(16'hBA8A)) 
    \rd_data[3]_i_1 
       (.I0(\original_rd_data_reg_n_0_[3] ),
        .I1(flag),
        .I2(\cpllpd_wait_reg[95] ),
        .I3(D[3]),
        .O(\rd_data[3]_i_1_n_0 ));
  LUT4 #(
    .INIT(16'hBA8A)) 
    \rd_data[4]_i_1 
       (.I0(\original_rd_data_reg_n_0_[4] ),
        .I1(flag),
        .I2(\cpllpd_wait_reg[95] ),
        .I3(D[4]),
        .O(\rd_data[4]_i_1_n_0 ));
  LUT4 #(
    .INIT(16'hBA8A)) 
    \rd_data[5]_i_1 
       (.I0(\original_rd_data_reg_n_0_[5] ),
        .I1(flag),
        .I2(\cpllpd_wait_reg[95] ),
        .I3(D[5]),
        .O(\rd_data[5]_i_1_n_0 ));
  LUT4 #(
    .INIT(16'hBA8A)) 
    \rd_data[6]_i_1 
       (.I0(\original_rd_data_reg_n_0_[6] ),
        .I1(flag),
        .I2(\cpllpd_wait_reg[95] ),
        .I3(D[6]),
        .O(\rd_data[6]_i_1_n_0 ));
  LUT4 #(
    .INIT(16'hBA8A)) 
    \rd_data[7]_i_1 
       (.I0(\original_rd_data_reg_n_0_[7] ),
        .I1(flag),
        .I2(\cpllpd_wait_reg[95] ),
        .I3(D[7]),
        .O(\rd_data[7]_i_1_n_0 ));
  LUT4 #(
    .INIT(16'hBA8A)) 
    \rd_data[8]_i_1 
       (.I0(\original_rd_data_reg_n_0_[8] ),
        .I1(flag),
        .I2(\cpllpd_wait_reg[95] ),
        .I3(D[8]),
        .O(\rd_data[8]_i_1_n_0 ));
  LUT4 #(
    .INIT(16'hBA8A)) 
    \rd_data[9]_i_1 
       (.I0(\original_rd_data_reg_n_0_[9] ),
        .I1(flag),
        .I2(\cpllpd_wait_reg[95] ),
        .I3(D[9]),
        .O(\rd_data[9]_i_1_n_0 ));
  FDCE \rd_data_reg[0] 
       (.C(gtrefclk_bufg),
        .CE(\rd_data[15]_i_1__0_n_0 ),
        .CLR(sync_rst_sync_n_0),
        .D(\rd_data[0]_i_1_n_0 ),
        .Q(Q[0]));
  FDCE \rd_data_reg[10] 
       (.C(gtrefclk_bufg),
        .CE(\rd_data[15]_i_1__0_n_0 ),
        .CLR(sync_rst_sync_n_0),
        .D(\rd_data[10]_i_1_n_0 ),
        .Q(Q[10]));
  FDCE \rd_data_reg[11] 
       (.C(gtrefclk_bufg),
        .CE(\rd_data[15]_i_1__0_n_0 ),
        .CLR(sync_rst_sync_n_0),
        .D(\rd_data[11]_i_1_n_0 ),
        .Q(\rd_data_reg_n_0_[11] ));
  FDCE \rd_data_reg[12] 
       (.C(gtrefclk_bufg),
        .CE(\rd_data[15]_i_1__0_n_0 ),
        .CLR(sync_rst_sync_n_0),
        .D(\rd_data[12]_i_1_n_0 ),
        .Q(Q[11]));
  FDCE \rd_data_reg[13] 
       (.C(gtrefclk_bufg),
        .CE(\rd_data[15]_i_1__0_n_0 ),
        .CLR(sync_rst_sync_n_0),
        .D(\rd_data[13]_i_1_n_0 ),
        .Q(Q[12]));
  FDCE \rd_data_reg[14] 
       (.C(gtrefclk_bufg),
        .CE(\rd_data[15]_i_1__0_n_0 ),
        .CLR(sync_rst_sync_n_0),
        .D(\rd_data[14]_i_1_n_0 ),
        .Q(Q[13]));
  FDCE \rd_data_reg[15] 
       (.C(gtrefclk_bufg),
        .CE(\rd_data[15]_i_1__0_n_0 ),
        .CLR(sync_rst_sync_n_0),
        .D(\rd_data[15]_i_2_n_0 ),
        .Q(Q[14]));
  FDCE \rd_data_reg[1] 
       (.C(gtrefclk_bufg),
        .CE(\rd_data[15]_i_1__0_n_0 ),
        .CLR(sync_rst_sync_n_0),
        .D(\rd_data[1]_i_1_n_0 ),
        .Q(Q[1]));
  FDCE \rd_data_reg[2] 
       (.C(gtrefclk_bufg),
        .CE(\rd_data[15]_i_1__0_n_0 ),
        .CLR(sync_rst_sync_n_0),
        .D(\rd_data[2]_i_1_n_0 ),
        .Q(Q[2]));
  FDCE \rd_data_reg[3] 
       (.C(gtrefclk_bufg),
        .CE(\rd_data[15]_i_1__0_n_0 ),
        .CLR(sync_rst_sync_n_0),
        .D(\rd_data[3]_i_1_n_0 ),
        .Q(Q[3]));
  FDCE \rd_data_reg[4] 
       (.C(gtrefclk_bufg),
        .CE(\rd_data[15]_i_1__0_n_0 ),
        .CLR(sync_rst_sync_n_0),
        .D(\rd_data[4]_i_1_n_0 ),
        .Q(Q[4]));
  FDCE \rd_data_reg[5] 
       (.C(gtrefclk_bufg),
        .CE(\rd_data[15]_i_1__0_n_0 ),
        .CLR(sync_rst_sync_n_0),
        .D(\rd_data[5]_i_1_n_0 ),
        .Q(Q[5]));
  FDCE \rd_data_reg[6] 
       (.C(gtrefclk_bufg),
        .CE(\rd_data[15]_i_1__0_n_0 ),
        .CLR(sync_rst_sync_n_0),
        .D(\rd_data[6]_i_1_n_0 ),
        .Q(Q[6]));
  FDCE \rd_data_reg[7] 
       (.C(gtrefclk_bufg),
        .CE(\rd_data[15]_i_1__0_n_0 ),
        .CLR(sync_rst_sync_n_0),
        .D(\rd_data[7]_i_1_n_0 ),
        .Q(Q[7]));
  FDCE \rd_data_reg[8] 
       (.C(gtrefclk_bufg),
        .CE(\rd_data[15]_i_1__0_n_0 ),
        .CLR(sync_rst_sync_n_0),
        .D(\rd_data[8]_i_1_n_0 ),
        .Q(Q[8]));
  FDCE \rd_data_reg[9] 
       (.C(gtrefclk_bufg),
        .CE(\rd_data[15]_i_1__0_n_0 ),
        .CLR(sync_rst_sync_n_0),
        .D(\rd_data[9]_i_1_n_0 ),
        .Q(Q[9]));
  (* SOFT_HLUTNM = "soft_lutpair62" *) 
  LUT3 #(
    .INIT(8'h08)) 
    rxpmareset_o_i_1
       (.I0(state[0]),
        .I1(state[2]),
        .I2(state[3]),
        .O(rxpmareset_i));
  FDCE rxpmareset_o_reg
       (.C(gtrefclk_bufg),
        .CE(1'b1),
        .CLR(sync_rst_sync_n_0),
        .D(rxpmareset_i),
        .Q(RXPMARESET));
  (* SOFT_HLUTNM = "soft_lutpair61" *) 
  LUT5 #(
    .INIT(32'h07080F08)) 
    \state[2]_i_1__0 
       (.I0(state[0]),
        .I1(state[1]),
        .I2(state[3]),
        .I3(state[2]),
        .I4(\cpllpd_wait_reg[95] ),
        .O(next_state[2]));
  (* SOFT_HLUTNM = "soft_lutpair61" *) 
  LUT5 #(
    .INIT(32'h00800000)) 
    \state[3]_i_1 
       (.I0(\cpllpd_wait_reg[95] ),
        .I1(state[0]),
        .I2(state[1]),
        .I3(state[3]),
        .I4(state[2]),
        .O(next_state[3]));
  FDCE #(
    .INIT(1'b0)) 
    \state_reg[0] 
       (.C(gtrefclk_bufg),
        .CE(1'b1),
        .CLR(sync_rst_sync_n_0),
        .D(next_state[0]),
        .Q(state[0]));
  FDCE #(
    .INIT(1'b0)) 
    \state_reg[1] 
       (.C(gtrefclk_bufg),
        .CE(1'b1),
        .CLR(sync_rst_sync_n_0),
        .D(next_state[1]),
        .Q(state[1]));
  FDCE #(
    .INIT(1'b0)) 
    \state_reg[2] 
       (.C(gtrefclk_bufg),
        .CE(1'b1),
        .CLR(sync_rst_sync_n_0),
        .D(next_state[2]),
        .Q(state[2]));
  FDCE #(
    .INIT(1'b0)) 
    \state_reg[3] 
       (.C(gtrefclk_bufg),
        .CE(1'b1),
        .CLR(sync_rst_sync_n_0),
        .D(next_state[3]),
        .Q(state[3]));
  GigEthGth7Core_GigEthGth7Core_sync_block_4 sync_RXPMARESETDONE
       (.D(next_state[1:0]),
        .Q(state),
        .\cpllpd_wait_reg[95] (\cpllpd_wait_reg[95] ),
        .data_in(data_in),
        .gtrefclk_bufg(gtrefclk_bufg));
  GigEthGth7Core_GigEthGth7Core_reset_sync__parameterized7 sync_rst_sync
       (.CPLL_RESET(CPLL_RESET),
        .gtrefclk_bufg(gtrefclk_bufg),
        .reset_out(sync_rst_sync_n_0));
endmodule

(* ORIG_REF_NAME = "GigEthGth7Core_reset_sync" *) 
module GigEthGth7Core_GigEthGth7Core_reset_sync
   (reset_out,
    userclk,
    encommaalign);
  output reset_out;
  input userclk;
  input encommaalign;

  wire encommaalign;
  wire reset_out;
  wire reset_sync_reg1;
  wire reset_sync_reg2;
  wire reset_sync_reg3;
  wire reset_sync_reg4;
  wire reset_sync_reg5;
  wire userclk;

  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FDP" *) 
  (* box_type = "PRIMITIVE" *) 
  FDPE #(
    .INIT(1'b1)) 
    reset_sync1
       (.C(userclk),
        .CE(1'b1),
        .D(1'b0),
        .PRE(encommaalign),
        .Q(reset_sync_reg1));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FDP" *) 
  (* box_type = "PRIMITIVE" *) 
  FDPE #(
    .INIT(1'b1)) 
    reset_sync2
       (.C(userclk),
        .CE(1'b1),
        .D(reset_sync_reg1),
        .PRE(encommaalign),
        .Q(reset_sync_reg2));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FDP" *) 
  (* box_type = "PRIMITIVE" *) 
  FDPE #(
    .INIT(1'b1)) 
    reset_sync3
       (.C(userclk),
        .CE(1'b1),
        .D(reset_sync_reg2),
        .PRE(encommaalign),
        .Q(reset_sync_reg3));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FDP" *) 
  (* box_type = "PRIMITIVE" *) 
  FDPE #(
    .INIT(1'b1)) 
    reset_sync4
       (.C(userclk),
        .CE(1'b1),
        .D(reset_sync_reg3),
        .PRE(encommaalign),
        .Q(reset_sync_reg4));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FDP" *) 
  (* box_type = "PRIMITIVE" *) 
  FDPE #(
    .INIT(1'b1)) 
    reset_sync5
       (.C(userclk),
        .CE(1'b1),
        .D(reset_sync_reg4),
        .PRE(encommaalign),
        .Q(reset_sync_reg5));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FDP" *) 
  (* box_type = "PRIMITIVE" *) 
  FDPE #(
    .INIT(1'b1)) 
    reset_sync6
       (.C(userclk),
        .CE(1'b1),
        .D(reset_sync_reg5),
        .PRE(1'b0),
        .Q(reset_out));
endmodule

(* ORIG_REF_NAME = "GigEthGth7Core_reset_sync" *) 
module GigEthGth7Core_GigEthGth7Core_reset_sync_1
   (reset_out,
    independent_clock_bufg,
    \USE_ROCKET_IO.MGT_RX_RESET_INT_reg );
  output reset_out;
  input independent_clock_bufg;
  input [0:0]\USE_ROCKET_IO.MGT_RX_RESET_INT_reg ;

  wire [0:0]\USE_ROCKET_IO.MGT_RX_RESET_INT_reg ;
  wire independent_clock_bufg;
  wire reset_out;
  wire reset_sync_reg1;
  wire reset_sync_reg2;
  wire reset_sync_reg3;
  wire reset_sync_reg4;
  wire reset_sync_reg5;

  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FDP" *) 
  (* box_type = "PRIMITIVE" *) 
  FDPE #(
    .INIT(1'b1)) 
    reset_sync1
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(1'b0),
        .PRE(\USE_ROCKET_IO.MGT_RX_RESET_INT_reg ),
        .Q(reset_sync_reg1));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FDP" *) 
  (* box_type = "PRIMITIVE" *) 
  FDPE #(
    .INIT(1'b1)) 
    reset_sync2
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(reset_sync_reg1),
        .PRE(\USE_ROCKET_IO.MGT_RX_RESET_INT_reg ),
        .Q(reset_sync_reg2));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FDP" *) 
  (* box_type = "PRIMITIVE" *) 
  FDPE #(
    .INIT(1'b1)) 
    reset_sync3
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(reset_sync_reg2),
        .PRE(\USE_ROCKET_IO.MGT_RX_RESET_INT_reg ),
        .Q(reset_sync_reg3));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FDP" *) 
  (* box_type = "PRIMITIVE" *) 
  FDPE #(
    .INIT(1'b1)) 
    reset_sync4
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(reset_sync_reg3),
        .PRE(\USE_ROCKET_IO.MGT_RX_RESET_INT_reg ),
        .Q(reset_sync_reg4));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FDP" *) 
  (* box_type = "PRIMITIVE" *) 
  FDPE #(
    .INIT(1'b1)) 
    reset_sync5
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(reset_sync_reg4),
        .PRE(\USE_ROCKET_IO.MGT_RX_RESET_INT_reg ),
        .Q(reset_sync_reg5));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FDP" *) 
  (* box_type = "PRIMITIVE" *) 
  FDPE #(
    .INIT(1'b1)) 
    reset_sync6
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(reset_sync_reg5),
        .PRE(1'b0),
        .Q(reset_out));
endmodule

(* ORIG_REF_NAME = "GigEthGth7Core_reset_sync" *) 
module GigEthGth7Core_GigEthGth7Core_reset_sync_2
   (reset_out,
    independent_clock_bufg,
    SR);
  output reset_out;
  input independent_clock_bufg;
  input [0:0]SR;

  wire [0:0]SR;
  wire independent_clock_bufg;
  wire reset_out;
  wire reset_sync_reg1;
  wire reset_sync_reg2;
  wire reset_sync_reg3;
  wire reset_sync_reg4;
  wire reset_sync_reg5;

  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FDP" *) 
  (* box_type = "PRIMITIVE" *) 
  FDPE #(
    .INIT(1'b1)) 
    reset_sync1
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(1'b0),
        .PRE(SR),
        .Q(reset_sync_reg1));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FDP" *) 
  (* box_type = "PRIMITIVE" *) 
  FDPE #(
    .INIT(1'b1)) 
    reset_sync2
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(reset_sync_reg1),
        .PRE(SR),
        .Q(reset_sync_reg2));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FDP" *) 
  (* box_type = "PRIMITIVE" *) 
  FDPE #(
    .INIT(1'b1)) 
    reset_sync3
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(reset_sync_reg2),
        .PRE(SR),
        .Q(reset_sync_reg3));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FDP" *) 
  (* box_type = "PRIMITIVE" *) 
  FDPE #(
    .INIT(1'b1)) 
    reset_sync4
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(reset_sync_reg3),
        .PRE(SR),
        .Q(reset_sync_reg4));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FDP" *) 
  (* box_type = "PRIMITIVE" *) 
  FDPE #(
    .INIT(1'b1)) 
    reset_sync5
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(reset_sync_reg4),
        .PRE(SR),
        .Q(reset_sync_reg5));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FDP" *) 
  (* box_type = "PRIMITIVE" *) 
  FDPE #(
    .INIT(1'b1)) 
    reset_sync6
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(reset_sync_reg5),
        .PRE(1'b0),
        .Q(reset_out));
endmodule

(* ORIG_REF_NAME = "GigEthGth7Core_reset_sync" *) 
module GigEthGth7Core_GigEthGth7Core_reset_sync_5
   (reset_out,
    gtrefclk_bufg,
    SR);
  output reset_out;
  input gtrefclk_bufg;
  input [0:0]SR;

  wire [0:0]SR;
  wire gtrefclk_bufg;
  wire reset_out;
  wire reset_sync_reg1;
  wire reset_sync_reg2;
  wire reset_sync_reg3;
  wire reset_sync_reg4;
  wire reset_sync_reg5;

  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FDP" *) 
  (* box_type = "PRIMITIVE" *) 
  FDPE #(
    .INIT(1'b1)) 
    reset_sync1
       (.C(gtrefclk_bufg),
        .CE(1'b1),
        .D(1'b0),
        .PRE(SR),
        .Q(reset_sync_reg1));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FDP" *) 
  (* box_type = "PRIMITIVE" *) 
  FDPE #(
    .INIT(1'b1)) 
    reset_sync2
       (.C(gtrefclk_bufg),
        .CE(1'b1),
        .D(reset_sync_reg1),
        .PRE(SR),
        .Q(reset_sync_reg2));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FDP" *) 
  (* box_type = "PRIMITIVE" *) 
  FDPE #(
    .INIT(1'b1)) 
    reset_sync3
       (.C(gtrefclk_bufg),
        .CE(1'b1),
        .D(reset_sync_reg2),
        .PRE(SR),
        .Q(reset_sync_reg3));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FDP" *) 
  (* box_type = "PRIMITIVE" *) 
  FDPE #(
    .INIT(1'b1)) 
    reset_sync4
       (.C(gtrefclk_bufg),
        .CE(1'b1),
        .D(reset_sync_reg3),
        .PRE(SR),
        .Q(reset_sync_reg4));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FDP" *) 
  (* box_type = "PRIMITIVE" *) 
  FDPE #(
    .INIT(1'b1)) 
    reset_sync5
       (.C(gtrefclk_bufg),
        .CE(1'b1),
        .D(reset_sync_reg4),
        .PRE(SR),
        .Q(reset_sync_reg5));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FDP" *) 
  (* box_type = "PRIMITIVE" *) 
  FDPE #(
    .INIT(1'b1)) 
    reset_sync6
       (.C(gtrefclk_bufg),
        .CE(1'b1),
        .D(reset_sync_reg5),
        .PRE(1'b0),
        .Q(reset_out));
endmodule

(* ORIG_REF_NAME = "GigEthGth7Core_reset_sync" *) 
module GigEthGth7Core_GigEthGth7Core_reset_sync_6
   (reset_out,
    gtrefclk_bufg,
    CPLL_RESET);
  output reset_out;
  input gtrefclk_bufg;
  input CPLL_RESET;

  wire CPLL_RESET;
  wire gtrefclk_bufg;
  wire reset_out;
  wire reset_sync_reg1;
  wire reset_sync_reg2;
  wire reset_sync_reg3;
  wire reset_sync_reg4;
  wire reset_sync_reg5;

  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FDP" *) 
  (* box_type = "PRIMITIVE" *) 
  FDPE #(
    .INIT(1'b1)) 
    reset_sync1
       (.C(gtrefclk_bufg),
        .CE(1'b1),
        .D(1'b0),
        .PRE(CPLL_RESET),
        .Q(reset_sync_reg1));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FDP" *) 
  (* box_type = "PRIMITIVE" *) 
  FDPE #(
    .INIT(1'b1)) 
    reset_sync2
       (.C(gtrefclk_bufg),
        .CE(1'b1),
        .D(reset_sync_reg1),
        .PRE(CPLL_RESET),
        .Q(reset_sync_reg2));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FDP" *) 
  (* box_type = "PRIMITIVE" *) 
  FDPE #(
    .INIT(1'b1)) 
    reset_sync3
       (.C(gtrefclk_bufg),
        .CE(1'b1),
        .D(reset_sync_reg2),
        .PRE(CPLL_RESET),
        .Q(reset_sync_reg3));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FDP" *) 
  (* box_type = "PRIMITIVE" *) 
  FDPE #(
    .INIT(1'b1)) 
    reset_sync4
       (.C(gtrefclk_bufg),
        .CE(1'b1),
        .D(reset_sync_reg3),
        .PRE(CPLL_RESET),
        .Q(reset_sync_reg4));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FDP" *) 
  (* box_type = "PRIMITIVE" *) 
  FDPE #(
    .INIT(1'b1)) 
    reset_sync5
       (.C(gtrefclk_bufg),
        .CE(1'b1),
        .D(reset_sync_reg4),
        .PRE(CPLL_RESET),
        .Q(reset_sync_reg5));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FDP" *) 
  (* box_type = "PRIMITIVE" *) 
  FDPE #(
    .INIT(1'b1)) 
    reset_sync6
       (.C(gtrefclk_bufg),
        .CE(1'b1),
        .D(reset_sync_reg5),
        .PRE(1'b0),
        .Q(reset_out));
endmodule

(* ORIG_REF_NAME = "GigEthGth7Core_reset_sync" *) 
module GigEthGth7Core_GigEthGth7Core_reset_sync__parameterized7
   (reset_out,
    gtrefclk_bufg,
    CPLL_RESET);
  output reset_out;
  input gtrefclk_bufg;
  input CPLL_RESET;

  wire CPLL_RESET;
  wire gtrefclk_bufg;
  wire reset_out;
  wire reset_sync_reg1;
  wire reset_sync_reg2;
  wire reset_sync_reg3;
  wire reset_sync_reg4;
  wire reset_sync_reg5;

  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FDP" *) 
  (* box_type = "PRIMITIVE" *) 
  FDPE #(
    .INIT(1'b0)) 
    reset_sync1
       (.C(gtrefclk_bufg),
        .CE(1'b1),
        .D(1'b0),
        .PRE(CPLL_RESET),
        .Q(reset_sync_reg1));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FDP" *) 
  (* box_type = "PRIMITIVE" *) 
  FDPE #(
    .INIT(1'b0)) 
    reset_sync2
       (.C(gtrefclk_bufg),
        .CE(1'b1),
        .D(reset_sync_reg1),
        .PRE(CPLL_RESET),
        .Q(reset_sync_reg2));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FDP" *) 
  (* box_type = "PRIMITIVE" *) 
  FDPE #(
    .INIT(1'b0)) 
    reset_sync3
       (.C(gtrefclk_bufg),
        .CE(1'b1),
        .D(reset_sync_reg2),
        .PRE(CPLL_RESET),
        .Q(reset_sync_reg3));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FDP" *) 
  (* box_type = "PRIMITIVE" *) 
  FDPE #(
    .INIT(1'b0)) 
    reset_sync4
       (.C(gtrefclk_bufg),
        .CE(1'b1),
        .D(reset_sync_reg3),
        .PRE(CPLL_RESET),
        .Q(reset_sync_reg4));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FDP" *) 
  (* box_type = "PRIMITIVE" *) 
  FDPE #(
    .INIT(1'b0)) 
    reset_sync5
       (.C(gtrefclk_bufg),
        .CE(1'b1),
        .D(reset_sync_reg4),
        .PRE(CPLL_RESET),
        .Q(reset_sync_reg5));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FDP" *) 
  (* box_type = "PRIMITIVE" *) 
  FDPE #(
    .INIT(1'b0)) 
    reset_sync6
       (.C(gtrefclk_bufg),
        .CE(1'b1),
        .D(reset_sync_reg5),
        .PRE(1'b0),
        .Q(reset_out));
endmodule

(* ORIG_REF_NAME = "GigEthGth7Core_reset_wtd_timer" *) 
module GigEthGth7Core_GigEthGth7Core_reset_wtd_timer
   (reset,
    independent_clock_bufg,
    data_out);
  output reset;
  input independent_clock_bufg;
  input data_out;

  wire \counter_stg1[5]_i_1_n_0 ;
  wire [5:5]counter_stg1_reg__0;
  wire [4:0]counter_stg1_reg__1;
  wire \counter_stg2[0]_i_1_n_0 ;
  wire \counter_stg2[0]_i_3_n_0 ;
  wire \counter_stg2[0]_i_4_n_0 ;
  wire \counter_stg2[0]_i_5_n_0 ;
  wire \counter_stg2[0]_i_6_n_0 ;
  wire \counter_stg2[4]_i_2_n_0 ;
  wire \counter_stg2[4]_i_3_n_0 ;
  wire \counter_stg2[4]_i_4_n_0 ;
  wire \counter_stg2[4]_i_5_n_0 ;
  wire \counter_stg2[8]_i_2_n_0 ;
  wire \counter_stg2[8]_i_3_n_0 ;
  wire \counter_stg2[8]_i_4_n_0 ;
  wire \counter_stg2[8]_i_5_n_0 ;
  wire [11:0]counter_stg2_reg;
  wire \counter_stg2_reg[0]_i_2_n_0 ;
  wire \counter_stg2_reg[0]_i_2_n_1 ;
  wire \counter_stg2_reg[0]_i_2_n_2 ;
  wire \counter_stg2_reg[0]_i_2_n_3 ;
  wire \counter_stg2_reg[0]_i_2_n_4 ;
  wire \counter_stg2_reg[0]_i_2_n_5 ;
  wire \counter_stg2_reg[0]_i_2_n_6 ;
  wire \counter_stg2_reg[0]_i_2_n_7 ;
  wire \counter_stg2_reg[4]_i_1_n_0 ;
  wire \counter_stg2_reg[4]_i_1_n_1 ;
  wire \counter_stg2_reg[4]_i_1_n_2 ;
  wire \counter_stg2_reg[4]_i_1_n_3 ;
  wire \counter_stg2_reg[4]_i_1_n_4 ;
  wire \counter_stg2_reg[4]_i_1_n_5 ;
  wire \counter_stg2_reg[4]_i_1_n_6 ;
  wire \counter_stg2_reg[4]_i_1_n_7 ;
  wire \counter_stg2_reg[8]_i_1_n_1 ;
  wire \counter_stg2_reg[8]_i_1_n_2 ;
  wire \counter_stg2_reg[8]_i_1_n_3 ;
  wire \counter_stg2_reg[8]_i_1_n_4 ;
  wire \counter_stg2_reg[8]_i_1_n_5 ;
  wire \counter_stg2_reg[8]_i_1_n_6 ;
  wire \counter_stg2_reg[8]_i_1_n_7 ;
  wire counter_stg30;
  wire \counter_stg3[0]_i_3_n_0 ;
  wire \counter_stg3[0]_i_4_n_0 ;
  wire \counter_stg3[0]_i_5_n_0 ;
  wire \counter_stg3[0]_i_6_n_0 ;
  wire \counter_stg3[0]_i_7_n_0 ;
  wire \counter_stg3[0]_i_8_n_0 ;
  wire \counter_stg3[0]_i_9_n_0 ;
  wire \counter_stg3[4]_i_2_n_0 ;
  wire \counter_stg3[4]_i_3_n_0 ;
  wire \counter_stg3[4]_i_4_n_0 ;
  wire \counter_stg3[4]_i_5_n_0 ;
  wire \counter_stg3[8]_i_2_n_0 ;
  wire \counter_stg3[8]_i_3_n_0 ;
  wire \counter_stg3[8]_i_4_n_0 ;
  wire \counter_stg3[8]_i_5_n_0 ;
  wire [11:0]counter_stg3_reg;
  wire \counter_stg3_reg[0]_i_2_n_0 ;
  wire \counter_stg3_reg[0]_i_2_n_1 ;
  wire \counter_stg3_reg[0]_i_2_n_2 ;
  wire \counter_stg3_reg[0]_i_2_n_3 ;
  wire \counter_stg3_reg[0]_i_2_n_4 ;
  wire \counter_stg3_reg[0]_i_2_n_5 ;
  wire \counter_stg3_reg[0]_i_2_n_6 ;
  wire \counter_stg3_reg[0]_i_2_n_7 ;
  wire \counter_stg3_reg[4]_i_1_n_0 ;
  wire \counter_stg3_reg[4]_i_1_n_1 ;
  wire \counter_stg3_reg[4]_i_1_n_2 ;
  wire \counter_stg3_reg[4]_i_1_n_3 ;
  wire \counter_stg3_reg[4]_i_1_n_4 ;
  wire \counter_stg3_reg[4]_i_1_n_5 ;
  wire \counter_stg3_reg[4]_i_1_n_6 ;
  wire \counter_stg3_reg[4]_i_1_n_7 ;
  wire \counter_stg3_reg[8]_i_1_n_1 ;
  wire \counter_stg3_reg[8]_i_1_n_2 ;
  wire \counter_stg3_reg[8]_i_1_n_3 ;
  wire \counter_stg3_reg[8]_i_1_n_4 ;
  wire \counter_stg3_reg[8]_i_1_n_5 ;
  wire \counter_stg3_reg[8]_i_1_n_6 ;
  wire \counter_stg3_reg[8]_i_1_n_7 ;
  wire data_out;
  wire independent_clock_bufg;
  wire [5:0]plusOp;
  wire reset;
  wire reset0;
  wire reset_i_2_n_0;
  wire reset_i_3_n_0;
  wire reset_i_4_n_0;
  wire reset_i_5_n_0;
  wire reset_i_6_n_0;
  wire reset_i_7_n_0;
  wire reset_i_8_n_0;
  wire [3:3]\NLW_counter_stg2_reg[8]_i_1_CO_UNCONNECTED ;
  wire [3:3]\NLW_counter_stg3_reg[8]_i_1_CO_UNCONNECTED ;

  (* SOFT_HLUTNM = "soft_lutpair69" *) 
  LUT1 #(
    .INIT(2'h1)) 
    \counter_stg1[0]_i_1 
       (.I0(counter_stg1_reg__1[0]),
        .O(plusOp[0]));
  (* SOFT_HLUTNM = "soft_lutpair69" *) 
  LUT2 #(
    .INIT(4'h6)) 
    \counter_stg1[1]_i_1 
       (.I0(counter_stg1_reg__1[0]),
        .I1(counter_stg1_reg__1[1]),
        .O(plusOp[1]));
  (* SOFT_HLUTNM = "soft_lutpair67" *) 
  LUT3 #(
    .INIT(8'h6A)) 
    \counter_stg1[2]_i_1 
       (.I0(counter_stg1_reg__1[2]),
        .I1(counter_stg1_reg__1[1]),
        .I2(counter_stg1_reg__1[0]),
        .O(plusOp[2]));
  (* SOFT_HLUTNM = "soft_lutpair67" *) 
  LUT4 #(
    .INIT(16'h6AAA)) 
    \counter_stg1[3]_i_1 
       (.I0(counter_stg1_reg__1[3]),
        .I1(counter_stg1_reg__1[0]),
        .I2(counter_stg1_reg__1[1]),
        .I3(counter_stg1_reg__1[2]),
        .O(plusOp[3]));
  (* SOFT_HLUTNM = "soft_lutpair66" *) 
  LUT5 #(
    .INIT(32'h7FFF8000)) 
    \counter_stg1[4]_i_1 
       (.I0(counter_stg1_reg__1[2]),
        .I1(counter_stg1_reg__1[1]),
        .I2(counter_stg1_reg__1[0]),
        .I3(counter_stg1_reg__1[3]),
        .I4(counter_stg1_reg__1[4]),
        .O(plusOp[4]));
  LUT3 #(
    .INIT(8'hF4)) 
    \counter_stg1[5]_i_1 
       (.I0(reset_i_2_n_0),
        .I1(\counter_stg2[0]_i_1_n_0 ),
        .I2(data_out),
        .O(\counter_stg1[5]_i_1_n_0 ));
  LUT6 #(
    .INIT(64'h7FFFFFFF80000000)) 
    \counter_stg1[5]_i_2 
       (.I0(counter_stg1_reg__1[4]),
        .I1(counter_stg1_reg__1[3]),
        .I2(counter_stg1_reg__1[0]),
        .I3(counter_stg1_reg__1[1]),
        .I4(counter_stg1_reg__1[2]),
        .I5(counter_stg1_reg__0),
        .O(plusOp[5]));
  FDRE #(
    .INIT(1'b0)) 
    \counter_stg1_reg[0] 
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(plusOp[0]),
        .Q(counter_stg1_reg__1[0]),
        .R(\counter_stg1[5]_i_1_n_0 ));
  FDRE #(
    .INIT(1'b0)) 
    \counter_stg1_reg[1] 
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(plusOp[1]),
        .Q(counter_stg1_reg__1[1]),
        .R(\counter_stg1[5]_i_1_n_0 ));
  FDRE #(
    .INIT(1'b0)) 
    \counter_stg1_reg[2] 
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(plusOp[2]),
        .Q(counter_stg1_reg__1[2]),
        .R(\counter_stg1[5]_i_1_n_0 ));
  FDRE #(
    .INIT(1'b0)) 
    \counter_stg1_reg[3] 
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(plusOp[3]),
        .Q(counter_stg1_reg__1[3]),
        .R(\counter_stg1[5]_i_1_n_0 ));
  FDRE #(
    .INIT(1'b0)) 
    \counter_stg1_reg[4] 
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(plusOp[4]),
        .Q(counter_stg1_reg__1[4]),
        .R(\counter_stg1[5]_i_1_n_0 ));
  FDRE #(
    .INIT(1'b0)) 
    \counter_stg1_reg[5] 
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(plusOp[5]),
        .Q(counter_stg1_reg__0),
        .R(\counter_stg1[5]_i_1_n_0 ));
  LUT6 #(
    .INIT(64'h8000000000000000)) 
    \counter_stg2[0]_i_1 
       (.I0(counter_stg1_reg__0),
        .I1(counter_stg1_reg__1[4]),
        .I2(counter_stg1_reg__1[3]),
        .I3(counter_stg1_reg__1[0]),
        .I4(counter_stg1_reg__1[1]),
        .I5(counter_stg1_reg__1[2]),
        .O(\counter_stg2[0]_i_1_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \counter_stg2[0]_i_3 
       (.I0(counter_stg2_reg[3]),
        .O(\counter_stg2[0]_i_3_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \counter_stg2[0]_i_4 
       (.I0(counter_stg2_reg[2]),
        .O(\counter_stg2[0]_i_4_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \counter_stg2[0]_i_5 
       (.I0(counter_stg2_reg[1]),
        .O(\counter_stg2[0]_i_5_n_0 ));
  LUT1 #(
    .INIT(2'h1)) 
    \counter_stg2[0]_i_6 
       (.I0(counter_stg2_reg[0]),
        .O(\counter_stg2[0]_i_6_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \counter_stg2[4]_i_2 
       (.I0(counter_stg2_reg[7]),
        .O(\counter_stg2[4]_i_2_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \counter_stg2[4]_i_3 
       (.I0(counter_stg2_reg[6]),
        .O(\counter_stg2[4]_i_3_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \counter_stg2[4]_i_4 
       (.I0(counter_stg2_reg[5]),
        .O(\counter_stg2[4]_i_4_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \counter_stg2[4]_i_5 
       (.I0(counter_stg2_reg[4]),
        .O(\counter_stg2[4]_i_5_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \counter_stg2[8]_i_2 
       (.I0(counter_stg2_reg[11]),
        .O(\counter_stg2[8]_i_2_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \counter_stg2[8]_i_3 
       (.I0(counter_stg2_reg[10]),
        .O(\counter_stg2[8]_i_3_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \counter_stg2[8]_i_4 
       (.I0(counter_stg2_reg[9]),
        .O(\counter_stg2[8]_i_4_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \counter_stg2[8]_i_5 
       (.I0(counter_stg2_reg[8]),
        .O(\counter_stg2[8]_i_5_n_0 ));
  FDRE #(
    .INIT(1'b0)) 
    \counter_stg2_reg[0] 
       (.C(independent_clock_bufg),
        .CE(\counter_stg2[0]_i_1_n_0 ),
        .D(\counter_stg2_reg[0]_i_2_n_7 ),
        .Q(counter_stg2_reg[0]),
        .R(\counter_stg1[5]_i_1_n_0 ));
  CARRY4 \counter_stg2_reg[0]_i_2 
       (.CI(1'b0),
        .CO({\counter_stg2_reg[0]_i_2_n_0 ,\counter_stg2_reg[0]_i_2_n_1 ,\counter_stg2_reg[0]_i_2_n_2 ,\counter_stg2_reg[0]_i_2_n_3 }),
        .CYINIT(1'b0),
        .DI({1'b0,1'b0,1'b0,1'b1}),
        .O({\counter_stg2_reg[0]_i_2_n_4 ,\counter_stg2_reg[0]_i_2_n_5 ,\counter_stg2_reg[0]_i_2_n_6 ,\counter_stg2_reg[0]_i_2_n_7 }),
        .S({\counter_stg2[0]_i_3_n_0 ,\counter_stg2[0]_i_4_n_0 ,\counter_stg2[0]_i_5_n_0 ,\counter_stg2[0]_i_6_n_0 }));
  FDRE #(
    .INIT(1'b0)) 
    \counter_stg2_reg[10] 
       (.C(independent_clock_bufg),
        .CE(\counter_stg2[0]_i_1_n_0 ),
        .D(\counter_stg2_reg[8]_i_1_n_5 ),
        .Q(counter_stg2_reg[10]),
        .R(\counter_stg1[5]_i_1_n_0 ));
  FDRE #(
    .INIT(1'b0)) 
    \counter_stg2_reg[11] 
       (.C(independent_clock_bufg),
        .CE(\counter_stg2[0]_i_1_n_0 ),
        .D(\counter_stg2_reg[8]_i_1_n_4 ),
        .Q(counter_stg2_reg[11]),
        .R(\counter_stg1[5]_i_1_n_0 ));
  FDRE #(
    .INIT(1'b0)) 
    \counter_stg2_reg[1] 
       (.C(independent_clock_bufg),
        .CE(\counter_stg2[0]_i_1_n_0 ),
        .D(\counter_stg2_reg[0]_i_2_n_6 ),
        .Q(counter_stg2_reg[1]),
        .R(\counter_stg1[5]_i_1_n_0 ));
  FDRE #(
    .INIT(1'b0)) 
    \counter_stg2_reg[2] 
       (.C(independent_clock_bufg),
        .CE(\counter_stg2[0]_i_1_n_0 ),
        .D(\counter_stg2_reg[0]_i_2_n_5 ),
        .Q(counter_stg2_reg[2]),
        .R(\counter_stg1[5]_i_1_n_0 ));
  FDRE #(
    .INIT(1'b0)) 
    \counter_stg2_reg[3] 
       (.C(independent_clock_bufg),
        .CE(\counter_stg2[0]_i_1_n_0 ),
        .D(\counter_stg2_reg[0]_i_2_n_4 ),
        .Q(counter_stg2_reg[3]),
        .R(\counter_stg1[5]_i_1_n_0 ));
  FDRE #(
    .INIT(1'b0)) 
    \counter_stg2_reg[4] 
       (.C(independent_clock_bufg),
        .CE(\counter_stg2[0]_i_1_n_0 ),
        .D(\counter_stg2_reg[4]_i_1_n_7 ),
        .Q(counter_stg2_reg[4]),
        .R(\counter_stg1[5]_i_1_n_0 ));
  CARRY4 \counter_stg2_reg[4]_i_1 
       (.CI(\counter_stg2_reg[0]_i_2_n_0 ),
        .CO({\counter_stg2_reg[4]_i_1_n_0 ,\counter_stg2_reg[4]_i_1_n_1 ,\counter_stg2_reg[4]_i_1_n_2 ,\counter_stg2_reg[4]_i_1_n_3 }),
        .CYINIT(1'b0),
        .DI({1'b0,1'b0,1'b0,1'b0}),
        .O({\counter_stg2_reg[4]_i_1_n_4 ,\counter_stg2_reg[4]_i_1_n_5 ,\counter_stg2_reg[4]_i_1_n_6 ,\counter_stg2_reg[4]_i_1_n_7 }),
        .S({\counter_stg2[4]_i_2_n_0 ,\counter_stg2[4]_i_3_n_0 ,\counter_stg2[4]_i_4_n_0 ,\counter_stg2[4]_i_5_n_0 }));
  FDRE #(
    .INIT(1'b0)) 
    \counter_stg2_reg[5] 
       (.C(independent_clock_bufg),
        .CE(\counter_stg2[0]_i_1_n_0 ),
        .D(\counter_stg2_reg[4]_i_1_n_6 ),
        .Q(counter_stg2_reg[5]),
        .R(\counter_stg1[5]_i_1_n_0 ));
  FDRE #(
    .INIT(1'b0)) 
    \counter_stg2_reg[6] 
       (.C(independent_clock_bufg),
        .CE(\counter_stg2[0]_i_1_n_0 ),
        .D(\counter_stg2_reg[4]_i_1_n_5 ),
        .Q(counter_stg2_reg[6]),
        .R(\counter_stg1[5]_i_1_n_0 ));
  FDRE #(
    .INIT(1'b0)) 
    \counter_stg2_reg[7] 
       (.C(independent_clock_bufg),
        .CE(\counter_stg2[0]_i_1_n_0 ),
        .D(\counter_stg2_reg[4]_i_1_n_4 ),
        .Q(counter_stg2_reg[7]),
        .R(\counter_stg1[5]_i_1_n_0 ));
  FDRE #(
    .INIT(1'b0)) 
    \counter_stg2_reg[8] 
       (.C(independent_clock_bufg),
        .CE(\counter_stg2[0]_i_1_n_0 ),
        .D(\counter_stg2_reg[8]_i_1_n_7 ),
        .Q(counter_stg2_reg[8]),
        .R(\counter_stg1[5]_i_1_n_0 ));
  CARRY4 \counter_stg2_reg[8]_i_1 
       (.CI(\counter_stg2_reg[4]_i_1_n_0 ),
        .CO({\NLW_counter_stg2_reg[8]_i_1_CO_UNCONNECTED [3],\counter_stg2_reg[8]_i_1_n_1 ,\counter_stg2_reg[8]_i_1_n_2 ,\counter_stg2_reg[8]_i_1_n_3 }),
        .CYINIT(1'b0),
        .DI({1'b0,1'b0,1'b0,1'b0}),
        .O({\counter_stg2_reg[8]_i_1_n_4 ,\counter_stg2_reg[8]_i_1_n_5 ,\counter_stg2_reg[8]_i_1_n_6 ,\counter_stg2_reg[8]_i_1_n_7 }),
        .S({\counter_stg2[8]_i_2_n_0 ,\counter_stg2[8]_i_3_n_0 ,\counter_stg2[8]_i_4_n_0 ,\counter_stg2[8]_i_5_n_0 }));
  FDRE #(
    .INIT(1'b0)) 
    \counter_stg2_reg[9] 
       (.C(independent_clock_bufg),
        .CE(\counter_stg2[0]_i_1_n_0 ),
        .D(\counter_stg2_reg[8]_i_1_n_6 ),
        .Q(counter_stg2_reg[9]),
        .R(\counter_stg1[5]_i_1_n_0 ));
  LUT6 #(
    .INIT(64'h0000000080000000)) 
    \counter_stg3[0]_i_1 
       (.I0(\counter_stg3[0]_i_3_n_0 ),
        .I1(counter_stg1_reg__0),
        .I2(counter_stg2_reg[0]),
        .I3(counter_stg2_reg[1]),
        .I4(\counter_stg3[0]_i_4_n_0 ),
        .I5(\counter_stg3[0]_i_5_n_0 ),
        .O(counter_stg30));
  LUT6 #(
    .INIT(64'h8000000000000000)) 
    \counter_stg3[0]_i_3 
       (.I0(counter_stg2_reg[6]),
        .I1(counter_stg2_reg[7]),
        .I2(counter_stg2_reg[8]),
        .I3(counter_stg2_reg[9]),
        .I4(counter_stg2_reg[11]),
        .I5(counter_stg2_reg[10]),
        .O(\counter_stg3[0]_i_3_n_0 ));
  (* SOFT_HLUTNM = "soft_lutpair68" *) 
  LUT4 #(
    .INIT(16'h8000)) 
    \counter_stg3[0]_i_4 
       (.I0(counter_stg2_reg[5]),
        .I1(counter_stg2_reg[4]),
        .I2(counter_stg2_reg[3]),
        .I3(counter_stg2_reg[2]),
        .O(\counter_stg3[0]_i_4_n_0 ));
  (* SOFT_HLUTNM = "soft_lutpair66" *) 
  LUT5 #(
    .INIT(32'h7FFFFFFF)) 
    \counter_stg3[0]_i_5 
       (.I0(counter_stg1_reg__1[2]),
        .I1(counter_stg1_reg__1[1]),
        .I2(counter_stg1_reg__1[0]),
        .I3(counter_stg1_reg__1[3]),
        .I4(counter_stg1_reg__1[4]),
        .O(\counter_stg3[0]_i_5_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \counter_stg3[0]_i_6 
       (.I0(counter_stg3_reg[3]),
        .O(\counter_stg3[0]_i_6_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \counter_stg3[0]_i_7 
       (.I0(counter_stg3_reg[2]),
        .O(\counter_stg3[0]_i_7_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \counter_stg3[0]_i_8 
       (.I0(counter_stg3_reg[1]),
        .O(\counter_stg3[0]_i_8_n_0 ));
  LUT1 #(
    .INIT(2'h1)) 
    \counter_stg3[0]_i_9 
       (.I0(counter_stg3_reg[0]),
        .O(\counter_stg3[0]_i_9_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \counter_stg3[4]_i_2 
       (.I0(counter_stg3_reg[7]),
        .O(\counter_stg3[4]_i_2_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \counter_stg3[4]_i_3 
       (.I0(counter_stg3_reg[6]),
        .O(\counter_stg3[4]_i_3_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \counter_stg3[4]_i_4 
       (.I0(counter_stg3_reg[5]),
        .O(\counter_stg3[4]_i_4_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \counter_stg3[4]_i_5 
       (.I0(counter_stg3_reg[4]),
        .O(\counter_stg3[4]_i_5_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \counter_stg3[8]_i_2 
       (.I0(counter_stg3_reg[11]),
        .O(\counter_stg3[8]_i_2_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \counter_stg3[8]_i_3 
       (.I0(counter_stg3_reg[10]),
        .O(\counter_stg3[8]_i_3_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \counter_stg3[8]_i_4 
       (.I0(counter_stg3_reg[9]),
        .O(\counter_stg3[8]_i_4_n_0 ));
  LUT1 #(
    .INIT(2'h2)) 
    \counter_stg3[8]_i_5 
       (.I0(counter_stg3_reg[8]),
        .O(\counter_stg3[8]_i_5_n_0 ));
  FDRE #(
    .INIT(1'b0)) 
    \counter_stg3_reg[0] 
       (.C(independent_clock_bufg),
        .CE(counter_stg30),
        .D(\counter_stg3_reg[0]_i_2_n_7 ),
        .Q(counter_stg3_reg[0]),
        .R(\counter_stg1[5]_i_1_n_0 ));
  CARRY4 \counter_stg3_reg[0]_i_2 
       (.CI(1'b0),
        .CO({\counter_stg3_reg[0]_i_2_n_0 ,\counter_stg3_reg[0]_i_2_n_1 ,\counter_stg3_reg[0]_i_2_n_2 ,\counter_stg3_reg[0]_i_2_n_3 }),
        .CYINIT(1'b0),
        .DI({1'b0,1'b0,1'b0,1'b1}),
        .O({\counter_stg3_reg[0]_i_2_n_4 ,\counter_stg3_reg[0]_i_2_n_5 ,\counter_stg3_reg[0]_i_2_n_6 ,\counter_stg3_reg[0]_i_2_n_7 }),
        .S({\counter_stg3[0]_i_6_n_0 ,\counter_stg3[0]_i_7_n_0 ,\counter_stg3[0]_i_8_n_0 ,\counter_stg3[0]_i_9_n_0 }));
  FDRE #(
    .INIT(1'b0)) 
    \counter_stg3_reg[10] 
       (.C(independent_clock_bufg),
        .CE(counter_stg30),
        .D(\counter_stg3_reg[8]_i_1_n_5 ),
        .Q(counter_stg3_reg[10]),
        .R(\counter_stg1[5]_i_1_n_0 ));
  FDRE #(
    .INIT(1'b0)) 
    \counter_stg3_reg[11] 
       (.C(independent_clock_bufg),
        .CE(counter_stg30),
        .D(\counter_stg3_reg[8]_i_1_n_4 ),
        .Q(counter_stg3_reg[11]),
        .R(\counter_stg1[5]_i_1_n_0 ));
  FDRE #(
    .INIT(1'b0)) 
    \counter_stg3_reg[1] 
       (.C(independent_clock_bufg),
        .CE(counter_stg30),
        .D(\counter_stg3_reg[0]_i_2_n_6 ),
        .Q(counter_stg3_reg[1]),
        .R(\counter_stg1[5]_i_1_n_0 ));
  FDRE #(
    .INIT(1'b0)) 
    \counter_stg3_reg[2] 
       (.C(independent_clock_bufg),
        .CE(counter_stg30),
        .D(\counter_stg3_reg[0]_i_2_n_5 ),
        .Q(counter_stg3_reg[2]),
        .R(\counter_stg1[5]_i_1_n_0 ));
  FDRE #(
    .INIT(1'b0)) 
    \counter_stg3_reg[3] 
       (.C(independent_clock_bufg),
        .CE(counter_stg30),
        .D(\counter_stg3_reg[0]_i_2_n_4 ),
        .Q(counter_stg3_reg[3]),
        .R(\counter_stg1[5]_i_1_n_0 ));
  FDRE #(
    .INIT(1'b0)) 
    \counter_stg3_reg[4] 
       (.C(independent_clock_bufg),
        .CE(counter_stg30),
        .D(\counter_stg3_reg[4]_i_1_n_7 ),
        .Q(counter_stg3_reg[4]),
        .R(\counter_stg1[5]_i_1_n_0 ));
  CARRY4 \counter_stg3_reg[4]_i_1 
       (.CI(\counter_stg3_reg[0]_i_2_n_0 ),
        .CO({\counter_stg3_reg[4]_i_1_n_0 ,\counter_stg3_reg[4]_i_1_n_1 ,\counter_stg3_reg[4]_i_1_n_2 ,\counter_stg3_reg[4]_i_1_n_3 }),
        .CYINIT(1'b0),
        .DI({1'b0,1'b0,1'b0,1'b0}),
        .O({\counter_stg3_reg[4]_i_1_n_4 ,\counter_stg3_reg[4]_i_1_n_5 ,\counter_stg3_reg[4]_i_1_n_6 ,\counter_stg3_reg[4]_i_1_n_7 }),
        .S({\counter_stg3[4]_i_2_n_0 ,\counter_stg3[4]_i_3_n_0 ,\counter_stg3[4]_i_4_n_0 ,\counter_stg3[4]_i_5_n_0 }));
  FDRE #(
    .INIT(1'b0)) 
    \counter_stg3_reg[5] 
       (.C(independent_clock_bufg),
        .CE(counter_stg30),
        .D(\counter_stg3_reg[4]_i_1_n_6 ),
        .Q(counter_stg3_reg[5]),
        .R(\counter_stg1[5]_i_1_n_0 ));
  FDRE #(
    .INIT(1'b0)) 
    \counter_stg3_reg[6] 
       (.C(independent_clock_bufg),
        .CE(counter_stg30),
        .D(\counter_stg3_reg[4]_i_1_n_5 ),
        .Q(counter_stg3_reg[6]),
        .R(\counter_stg1[5]_i_1_n_0 ));
  FDRE #(
    .INIT(1'b0)) 
    \counter_stg3_reg[7] 
       (.C(independent_clock_bufg),
        .CE(counter_stg30),
        .D(\counter_stg3_reg[4]_i_1_n_4 ),
        .Q(counter_stg3_reg[7]),
        .R(\counter_stg1[5]_i_1_n_0 ));
  FDRE #(
    .INIT(1'b0)) 
    \counter_stg3_reg[8] 
       (.C(independent_clock_bufg),
        .CE(counter_stg30),
        .D(\counter_stg3_reg[8]_i_1_n_7 ),
        .Q(counter_stg3_reg[8]),
        .R(\counter_stg1[5]_i_1_n_0 ));
  CARRY4 \counter_stg3_reg[8]_i_1 
       (.CI(\counter_stg3_reg[4]_i_1_n_0 ),
        .CO({\NLW_counter_stg3_reg[8]_i_1_CO_UNCONNECTED [3],\counter_stg3_reg[8]_i_1_n_1 ,\counter_stg3_reg[8]_i_1_n_2 ,\counter_stg3_reg[8]_i_1_n_3 }),
        .CYINIT(1'b0),
        .DI({1'b0,1'b0,1'b0,1'b0}),
        .O({\counter_stg3_reg[8]_i_1_n_4 ,\counter_stg3_reg[8]_i_1_n_5 ,\counter_stg3_reg[8]_i_1_n_6 ,\counter_stg3_reg[8]_i_1_n_7 }),
        .S({\counter_stg3[8]_i_2_n_0 ,\counter_stg3[8]_i_3_n_0 ,\counter_stg3[8]_i_4_n_0 ,\counter_stg3[8]_i_5_n_0 }));
  FDRE #(
    .INIT(1'b0)) 
    \counter_stg3_reg[9] 
       (.C(independent_clock_bufg),
        .CE(counter_stg30),
        .D(\counter_stg3_reg[8]_i_1_n_6 ),
        .Q(counter_stg3_reg[9]),
        .R(\counter_stg1[5]_i_1_n_0 ));
  LUT2 #(
    .INIT(4'h2)) 
    reset_i_1
       (.I0(counter_stg1_reg__0),
        .I1(reset_i_2_n_0),
        .O(reset0));
  LUT6 #(
    .INIT(64'hFFFFFFFFFFFFFFFE)) 
    reset_i_2
       (.I0(reset_i_3_n_0),
        .I1(reset_i_4_n_0),
        .I2(reset_i_5_n_0),
        .I3(reset_i_6_n_0),
        .I4(reset_i_7_n_0),
        .I5(reset_i_8_n_0),
        .O(reset_i_2_n_0));
  LUT4 #(
    .INIT(16'hFFF7)) 
    reset_i_3
       (.I0(counter_stg3_reg[4]),
        .I1(counter_stg3_reg[11]),
        .I2(counter_stg3_reg[9]),
        .I3(counter_stg2_reg[2]),
        .O(reset_i_3_n_0));
  LUT6 #(
    .INIT(64'hFFF7FFFFFFFFFFFF)) 
    reset_i_4
       (.I0(counter_stg2_reg[4]),
        .I1(counter_stg2_reg[8]),
        .I2(counter_stg3_reg[0]),
        .I3(counter_stg2_reg[7]),
        .I4(counter_stg3_reg[5]),
        .I5(counter_stg2_reg[10]),
        .O(reset_i_4_n_0));
  (* SOFT_HLUTNM = "soft_lutpair68" *) 
  LUT2 #(
    .INIT(4'h7)) 
    reset_i_5
       (.I0(counter_stg2_reg[3]),
        .I1(counter_stg2_reg[11]),
        .O(reset_i_5_n_0));
  LUT4 #(
    .INIT(16'hFFFE)) 
    reset_i_6
       (.I0(counter_stg2_reg[1]),
        .I1(counter_stg2_reg[0]),
        .I2(counter_stg3_reg[2]),
        .I3(counter_stg3_reg[8]),
        .O(reset_i_6_n_0));
  LUT4 #(
    .INIT(16'hFFDF)) 
    reset_i_7
       (.I0(counter_stg3_reg[7]),
        .I1(counter_stg3_reg[3]),
        .I2(counter_stg3_reg[6]),
        .I3(counter_stg3_reg[10]),
        .O(reset_i_7_n_0));
  LUT4 #(
    .INIT(16'hFFFE)) 
    reset_i_8
       (.I0(counter_stg2_reg[9]),
        .I1(counter_stg2_reg[5]),
        .I2(counter_stg3_reg[1]),
        .I3(counter_stg2_reg[6]),
        .O(reset_i_8_n_0));
  FDRE reset_reg
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(reset0),
        .Q(reset),
        .R(1'b0));
endmodule

(* ORIG_REF_NAME = "GigEthGth7Core_sync_block" *) 
module GigEthGth7Core_GigEthGth7Core_sync_block
   (data_out,
    data_in,
    userclk2);
  output data_out;
  input data_in;
  input userclk2;

  wire data_in;
  wire data_out;
  wire data_sync1;
  wire data_sync2;
  wire data_sync3;
  wire data_sync4;
  wire data_sync5;
  wire userclk2;

  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FD" *) 
  (* box_type = "PRIMITIVE" *) 
  FDRE #(
    .INIT(1'b0)) 
    data_sync_reg1
       (.C(userclk2),
        .CE(1'b1),
        .D(data_in),
        .Q(data_sync1),
        .R(1'b0));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FD" *) 
  (* box_type = "PRIMITIVE" *) 
  FDRE #(
    .INIT(1'b0)) 
    data_sync_reg2
       (.C(userclk2),
        .CE(1'b1),
        .D(data_sync1),
        .Q(data_sync2),
        .R(1'b0));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FD" *) 
  (* box_type = "PRIMITIVE" *) 
  FDRE #(
    .INIT(1'b0)) 
    data_sync_reg3
       (.C(userclk2),
        .CE(1'b1),
        .D(data_sync2),
        .Q(data_sync3),
        .R(1'b0));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FD" *) 
  (* box_type = "PRIMITIVE" *) 
  FDRE #(
    .INIT(1'b0)) 
    data_sync_reg4
       (.C(userclk2),
        .CE(1'b1),
        .D(data_sync3),
        .Q(data_sync4),
        .R(1'b0));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FD" *) 
  (* box_type = "PRIMITIVE" *) 
  FDRE #(
    .INIT(1'b0)) 
    data_sync_reg5
       (.C(userclk2),
        .CE(1'b1),
        .D(data_sync4),
        .Q(data_sync5),
        .R(1'b0));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FD" *) 
  (* box_type = "PRIMITIVE" *) 
  FDRE #(
    .INIT(1'b0)) 
    data_sync_reg6
       (.C(userclk2),
        .CE(1'b1),
        .D(data_sync5),
        .Q(data_out),
        .R(1'b0));
endmodule

(* ORIG_REF_NAME = "GigEthGth7Core_sync_block" *) 
module GigEthGth7Core_GigEthGth7Core_sync_block_0
   (resetdone,
    data_out,
    data_in,
    userclk2);
  output resetdone;
  input data_out;
  input data_in;
  input userclk2;

  wire data_in;
  wire data_out;
  wire data_out0_in;
  wire data_sync1;
  wire data_sync2;
  wire data_sync3;
  wire data_sync4;
  wire data_sync5;
  wire resetdone;
  wire userclk2;

  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FD" *) 
  (* box_type = "PRIMITIVE" *) 
  FDRE #(
    .INIT(1'b0)) 
    data_sync_reg1
       (.C(userclk2),
        .CE(1'b1),
        .D(data_in),
        .Q(data_sync1),
        .R(1'b0));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FD" *) 
  (* box_type = "PRIMITIVE" *) 
  FDRE #(
    .INIT(1'b0)) 
    data_sync_reg2
       (.C(userclk2),
        .CE(1'b1),
        .D(data_sync1),
        .Q(data_sync2),
        .R(1'b0));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FD" *) 
  (* box_type = "PRIMITIVE" *) 
  FDRE #(
    .INIT(1'b0)) 
    data_sync_reg3
       (.C(userclk2),
        .CE(1'b1),
        .D(data_sync2),
        .Q(data_sync3),
        .R(1'b0));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FD" *) 
  (* box_type = "PRIMITIVE" *) 
  FDRE #(
    .INIT(1'b0)) 
    data_sync_reg4
       (.C(userclk2),
        .CE(1'b1),
        .D(data_sync3),
        .Q(data_sync4),
        .R(1'b0));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FD" *) 
  (* box_type = "PRIMITIVE" *) 
  FDRE #(
    .INIT(1'b0)) 
    data_sync_reg5
       (.C(userclk2),
        .CE(1'b1),
        .D(data_sync4),
        .Q(data_sync5),
        .R(1'b0));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FD" *) 
  (* box_type = "PRIMITIVE" *) 
  FDRE #(
    .INIT(1'b0)) 
    data_sync_reg6
       (.C(userclk2),
        .CE(1'b1),
        .D(data_sync5),
        .Q(data_out0_in),
        .R(1'b0));
  LUT2 #(
    .INIT(4'h8)) 
    resetdone_INST_0
       (.I0(data_out0_in),
        .I1(data_out),
        .O(resetdone));
endmodule

(* ORIG_REF_NAME = "GigEthGth7Core_sync_block" *) 
module GigEthGth7Core_GigEthGth7Core_sync_block_10
   (SR,
    mmcm_lock_reclocked_reg,
    mmcm_lock_reclocked,
    Q,
    \mmcm_lock_count_reg[4] ,
    mmcm_locked,
    independent_clock_bufg);
  output [0:0]SR;
  output mmcm_lock_reclocked_reg;
  input mmcm_lock_reclocked;
  input [2:0]Q;
  input \mmcm_lock_count_reg[4] ;
  input mmcm_locked;
  input independent_clock_bufg;

  wire [2:0]Q;
  wire [0:0]SR;
  wire data_sync1;
  wire data_sync2;
  wire data_sync3;
  wire data_sync4;
  wire data_sync5;
  wire independent_clock_bufg;
  wire \mmcm_lock_count_reg[4] ;
  wire mmcm_lock_i;
  wire mmcm_lock_reclocked;
  wire mmcm_lock_reclocked_reg;
  wire mmcm_locked;

  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FD" *) 
  (* box_type = "PRIMITIVE" *) 
  FDRE #(
    .INIT(1'b0)) 
    data_sync_reg1
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(mmcm_locked),
        .Q(data_sync1),
        .R(1'b0));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FD" *) 
  (* box_type = "PRIMITIVE" *) 
  FDRE #(
    .INIT(1'b0)) 
    data_sync_reg2
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(data_sync1),
        .Q(data_sync2),
        .R(1'b0));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FD" *) 
  (* box_type = "PRIMITIVE" *) 
  FDRE #(
    .INIT(1'b0)) 
    data_sync_reg3
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(data_sync2),
        .Q(data_sync3),
        .R(1'b0));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FD" *) 
  (* box_type = "PRIMITIVE" *) 
  FDRE #(
    .INIT(1'b0)) 
    data_sync_reg4
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(data_sync3),
        .Q(data_sync4),
        .R(1'b0));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FD" *) 
  (* box_type = "PRIMITIVE" *) 
  FDRE #(
    .INIT(1'b0)) 
    data_sync_reg5
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(data_sync4),
        .Q(data_sync5),
        .R(1'b0));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FD" *) 
  (* box_type = "PRIMITIVE" *) 
  FDRE #(
    .INIT(1'b0)) 
    data_sync_reg6
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(data_sync5),
        .Q(mmcm_lock_i),
        .R(1'b0));
  LUT1 #(
    .INIT(2'h1)) 
    \mmcm_lock_count[7]_i_1 
       (.I0(mmcm_lock_i),
        .O(SR));
  LUT6 #(
    .INIT(64'hEAAAAAAA00000000)) 
    mmcm_lock_reclocked_i_1
       (.I0(mmcm_lock_reclocked),
        .I1(Q[2]),
        .I2(Q[1]),
        .I3(Q[0]),
        .I4(\mmcm_lock_count_reg[4] ),
        .I5(mmcm_lock_i),
        .O(mmcm_lock_reclocked_reg));
endmodule

(* ORIG_REF_NAME = "GigEthGth7Core_sync_block" *) 
module GigEthGth7Core_GigEthGth7Core_sync_block_11
   (data_out,
    data_in,
    userclk);
  output data_out;
  input data_in;
  input userclk;

  wire data_in;
  wire data_out;
  wire data_sync1;
  wire data_sync2;
  wire data_sync3;
  wire data_sync4;
  wire data_sync5;
  wire userclk;

  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FD" *) 
  (* box_type = "PRIMITIVE" *) 
  FDRE #(
    .INIT(1'b0)) 
    data_sync_reg1
       (.C(userclk),
        .CE(1'b1),
        .D(data_in),
        .Q(data_sync1),
        .R(1'b0));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FD" *) 
  (* box_type = "PRIMITIVE" *) 
  FDRE #(
    .INIT(1'b0)) 
    data_sync_reg2
       (.C(userclk),
        .CE(1'b1),
        .D(data_sync1),
        .Q(data_sync2),
        .R(1'b0));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FD" *) 
  (* box_type = "PRIMITIVE" *) 
  FDRE #(
    .INIT(1'b0)) 
    data_sync_reg3
       (.C(userclk),
        .CE(1'b1),
        .D(data_sync2),
        .Q(data_sync3),
        .R(1'b0));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FD" *) 
  (* box_type = "PRIMITIVE" *) 
  FDRE #(
    .INIT(1'b0)) 
    data_sync_reg4
       (.C(userclk),
        .CE(1'b1),
        .D(data_sync3),
        .Q(data_sync4),
        .R(1'b0));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FD" *) 
  (* box_type = "PRIMITIVE" *) 
  FDRE #(
    .INIT(1'b0)) 
    data_sync_reg5
       (.C(userclk),
        .CE(1'b1),
        .D(data_sync4),
        .Q(data_sync5),
        .R(1'b0));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FD" *) 
  (* box_type = "PRIMITIVE" *) 
  FDRE #(
    .INIT(1'b0)) 
    data_sync_reg6
       (.C(userclk),
        .CE(1'b1),
        .D(data_sync5),
        .Q(data_out),
        .R(1'b0));
endmodule

(* ORIG_REF_NAME = "GigEthGth7Core_sync_block" *) 
module GigEthGth7Core_GigEthGth7Core_sync_block_12
   (data_out,
    data_in,
    independent_clock_bufg);
  output data_out;
  input data_in;
  input independent_clock_bufg;

  wire data_in;
  wire data_out;
  wire data_sync1;
  wire data_sync2;
  wire data_sync3;
  wire data_sync4;
  wire data_sync5;
  wire independent_clock_bufg;

  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FD" *) 
  (* box_type = "PRIMITIVE" *) 
  FDRE #(
    .INIT(1'b0)) 
    data_sync_reg1
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(data_in),
        .Q(data_sync1),
        .R(1'b0));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FD" *) 
  (* box_type = "PRIMITIVE" *) 
  FDRE #(
    .INIT(1'b0)) 
    data_sync_reg2
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(data_sync1),
        .Q(data_sync2),
        .R(1'b0));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FD" *) 
  (* box_type = "PRIMITIVE" *) 
  FDRE #(
    .INIT(1'b0)) 
    data_sync_reg3
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(data_sync2),
        .Q(data_sync3),
        .R(1'b0));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FD" *) 
  (* box_type = "PRIMITIVE" *) 
  FDRE #(
    .INIT(1'b0)) 
    data_sync_reg4
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(data_sync3),
        .Q(data_sync4),
        .R(1'b0));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FD" *) 
  (* box_type = "PRIMITIVE" *) 
  FDRE #(
    .INIT(1'b0)) 
    data_sync_reg5
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(data_sync4),
        .Q(data_sync5),
        .R(1'b0));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FD" *) 
  (* box_type = "PRIMITIVE" *) 
  FDRE #(
    .INIT(1'b0)) 
    data_sync_reg6
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(data_sync5),
        .Q(data_out),
        .R(1'b0));
endmodule

(* ORIG_REF_NAME = "GigEthGth7Core_sync_block" *) 
module GigEthGth7Core_GigEthGth7Core_sync_block_13
   (data_out,
    data_in,
    userclk);
  output data_out;
  input data_in;
  input userclk;

  wire data_in;
  wire data_out;
  wire data_sync1;
  wire data_sync2;
  wire data_sync3;
  wire data_sync4;
  wire data_sync5;
  wire userclk;

  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FD" *) 
  (* box_type = "PRIMITIVE" *) 
  FDRE #(
    .INIT(1'b0)) 
    data_sync_reg1
       (.C(userclk),
        .CE(1'b1),
        .D(data_in),
        .Q(data_sync1),
        .R(1'b0));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FD" *) 
  (* box_type = "PRIMITIVE" *) 
  FDRE #(
    .INIT(1'b0)) 
    data_sync_reg2
       (.C(userclk),
        .CE(1'b1),
        .D(data_sync1),
        .Q(data_sync2),
        .R(1'b0));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FD" *) 
  (* box_type = "PRIMITIVE" *) 
  FDRE #(
    .INIT(1'b0)) 
    data_sync_reg3
       (.C(userclk),
        .CE(1'b1),
        .D(data_sync2),
        .Q(data_sync3),
        .R(1'b0));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FD" *) 
  (* box_type = "PRIMITIVE" *) 
  FDRE #(
    .INIT(1'b0)) 
    data_sync_reg4
       (.C(userclk),
        .CE(1'b1),
        .D(data_sync3),
        .Q(data_sync4),
        .R(1'b0));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FD" *) 
  (* box_type = "PRIMITIVE" *) 
  FDRE #(
    .INIT(1'b0)) 
    data_sync_reg5
       (.C(userclk),
        .CE(1'b1),
        .D(data_sync4),
        .Q(data_sync5),
        .R(1'b0));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FD" *) 
  (* box_type = "PRIMITIVE" *) 
  FDRE #(
    .INIT(1'b0)) 
    data_sync_reg6
       (.C(userclk),
        .CE(1'b1),
        .D(data_sync5),
        .Q(data_out),
        .R(1'b0));
endmodule

(* ORIG_REF_NAME = "GigEthGth7Core_sync_block" *) 
module GigEthGth7Core_GigEthGth7Core_sync_block_14
   (data_out,
    \cpllpd_wait_reg[95] ,
    independent_clock_bufg);
  output data_out;
  input \cpllpd_wait_reg[95] ;
  input independent_clock_bufg;

  wire \cpllpd_wait_reg[95] ;
  wire data_out;
  wire data_sync1;
  wire data_sync2;
  wire data_sync3;
  wire data_sync4;
  wire data_sync5;
  wire independent_clock_bufg;

  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FD" *) 
  (* box_type = "PRIMITIVE" *) 
  FDRE #(
    .INIT(1'b0)) 
    data_sync_reg1
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(\cpllpd_wait_reg[95] ),
        .Q(data_sync1),
        .R(1'b0));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FD" *) 
  (* box_type = "PRIMITIVE" *) 
  FDRE #(
    .INIT(1'b0)) 
    data_sync_reg2
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(data_sync1),
        .Q(data_sync2),
        .R(1'b0));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FD" *) 
  (* box_type = "PRIMITIVE" *) 
  FDRE #(
    .INIT(1'b0)) 
    data_sync_reg3
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(data_sync2),
        .Q(data_sync3),
        .R(1'b0));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FD" *) 
  (* box_type = "PRIMITIVE" *) 
  FDRE #(
    .INIT(1'b0)) 
    data_sync_reg4
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(data_sync3),
        .Q(data_sync4),
        .R(1'b0));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FD" *) 
  (* box_type = "PRIMITIVE" *) 
  FDRE #(
    .INIT(1'b0)) 
    data_sync_reg5
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(data_sync4),
        .Q(data_sync5),
        .R(1'b0));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FD" *) 
  (* box_type = "PRIMITIVE" *) 
  FDRE #(
    .INIT(1'b0)) 
    data_sync_reg6
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(data_sync5),
        .Q(data_out),
        .R(1'b0));
endmodule

(* ORIG_REF_NAME = "GigEthGth7Core_sync_block" *) 
module GigEthGth7Core_GigEthGth7Core_sync_block_15
   (E,
    data_out,
    init_wait_done_reg,
    out,
    \FSM_sequential_rx_state_reg[0] ,
    time_out_2ms_reg,
    time_out_2ms,
    cplllock,
    independent_clock_bufg);
  output [0:0]E;
  output data_out;
  input init_wait_done_reg;
  input [3:0]out;
  input \FSM_sequential_rx_state_reg[0] ;
  input time_out_2ms_reg;
  input time_out_2ms;
  input cplllock;
  input independent_clock_bufg;

  wire [0:0]E;
  wire \FSM_sequential_rx_state[3]_i_4_n_0 ;
  wire \FSM_sequential_rx_state_reg[0] ;
  wire cplllock;
  wire data_out;
  wire data_sync1;
  wire data_sync2;
  wire data_sync3;
  wire data_sync4;
  wire data_sync5;
  wire independent_clock_bufg;
  wire init_wait_done_reg;
  wire [3:0]out;
  wire time_out_2ms;
  wire time_out_2ms_reg;

  LUT5 #(
    .INIT(32'hFFFF00CA)) 
    \FSM_sequential_rx_state[3]_i_1 
       (.I0(init_wait_done_reg),
        .I1(\FSM_sequential_rx_state[3]_i_4_n_0 ),
        .I2(out[0]),
        .I3(out[3]),
        .I4(\FSM_sequential_rx_state_reg[0] ),
        .O(E));
  LUT5 #(
    .INIT(32'hBBB8BBBB)) 
    \FSM_sequential_rx_state[3]_i_4 
       (.I0(time_out_2ms_reg),
        .I1(out[2]),
        .I2(time_out_2ms),
        .I3(data_out),
        .I4(out[1]),
        .O(\FSM_sequential_rx_state[3]_i_4_n_0 ));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FD" *) 
  (* box_type = "PRIMITIVE" *) 
  FDRE #(
    .INIT(1'b0)) 
    data_sync_reg1
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(cplllock),
        .Q(data_sync1),
        .R(1'b0));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FD" *) 
  (* box_type = "PRIMITIVE" *) 
  FDRE #(
    .INIT(1'b0)) 
    data_sync_reg2
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(data_sync1),
        .Q(data_sync2),
        .R(1'b0));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FD" *) 
  (* box_type = "PRIMITIVE" *) 
  FDRE #(
    .INIT(1'b0)) 
    data_sync_reg3
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(data_sync2),
        .Q(data_sync3),
        .R(1'b0));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FD" *) 
  (* box_type = "PRIMITIVE" *) 
  FDRE #(
    .INIT(1'b0)) 
    data_sync_reg4
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(data_sync3),
        .Q(data_sync4),
        .R(1'b0));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FD" *) 
  (* box_type = "PRIMITIVE" *) 
  FDRE #(
    .INIT(1'b0)) 
    data_sync_reg5
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(data_sync4),
        .Q(data_sync5),
        .R(1'b0));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FD" *) 
  (* box_type = "PRIMITIVE" *) 
  FDRE #(
    .INIT(1'b0)) 
    data_sync_reg6
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(data_sync5),
        .Q(data_out),
        .R(1'b0));
endmodule

(* ORIG_REF_NAME = "GigEthGth7Core_sync_block" *) 
module GigEthGth7Core_GigEthGth7Core_sync_block_16
   (reset_time_out_reg,
    rx_fsm_reset_done_int_reg,
    D,
    \FSM_sequential_rx_state_reg[0] ,
    reset_time_out_reg_0,
    time_out_100us,
    rxresetdone_s3_reg,
    out,
    gt0_rx_cdrlocked_reg,
    data_in,
    cplllock_sync,
    \FSM_sequential_rx_state_reg[3] ,
    time_out_2ms,
    \FSM_sequential_rx_state_reg[3]_0 ,
    time_out_1us,
    time_out_wait_bypass_s3,
    \FSM_sequential_rx_state_reg[0]_0 ,
    time_out_100us_reg,
    rx_state15_out,
    data_out,
    independent_clock_bufg);
  output reset_time_out_reg;
  output rx_fsm_reset_done_int_reg;
  output [2:0]D;
  output \FSM_sequential_rx_state_reg[0] ;
  input reset_time_out_reg_0;
  input time_out_100us;
  input rxresetdone_s3_reg;
  input [3:0]out;
  input gt0_rx_cdrlocked_reg;
  input data_in;
  input cplllock_sync;
  input \FSM_sequential_rx_state_reg[3] ;
  input time_out_2ms;
  input \FSM_sequential_rx_state_reg[3]_0 ;
  input time_out_1us;
  input time_out_wait_bypass_s3;
  input \FSM_sequential_rx_state_reg[0]_0 ;
  input time_out_100us_reg;
  input rx_state15_out;
  input data_out;
  input independent_clock_bufg;

  wire [2:0]D;
  wire \FSM_sequential_rx_state[3]_i_7_n_0 ;
  wire \FSM_sequential_rx_state_reg[0] ;
  wire \FSM_sequential_rx_state_reg[0]_0 ;
  wire \FSM_sequential_rx_state_reg[3] ;
  wire \FSM_sequential_rx_state_reg[3]_0 ;
  wire cplllock_sync;
  wire data_in;
  wire data_out;
  wire data_sync1;
  wire data_sync2;
  wire data_sync3;
  wire data_sync4;
  wire data_sync5;
  wire data_valid_sync;
  wire gt0_rx_cdrlocked_reg;
  wire independent_clock_bufg;
  wire [3:0]out;
  wire reset_time_out_i_3__0_n_0;
  wire reset_time_out_reg;
  wire reset_time_out_reg_0;
  wire rx_fsm_reset_done_int;
  wire rx_fsm_reset_done_int_i_3_n_0;
  wire rx_fsm_reset_done_int_i_4_n_0;
  wire rx_fsm_reset_done_int_reg;
  wire rx_state1;
  wire rx_state15_out;
  wire rxresetdone_s3_reg;
  wire time_out_100us;
  wire time_out_100us_reg;
  wire time_out_1us;
  wire time_out_2ms;
  wire time_out_wait_bypass_s3;

  LUT6 #(
    .INIT(64'h000C55550F0F5555)) 
    \FSM_sequential_rx_state[0]_i_1 
       (.I0(\FSM_sequential_rx_state_reg[0]_0 ),
        .I1(rx_state1),
        .I2(out[2]),
        .I3(out[1]),
        .I4(out[3]),
        .I5(out[0]),
        .O(D[0]));
  LUT6 #(
    .INIT(64'h00050000003FFF00)) 
    \FSM_sequential_rx_state[1]_i_1 
       (.I0(rx_state1),
        .I1(rx_state15_out),
        .I2(out[2]),
        .I3(out[1]),
        .I4(out[0]),
        .I5(out[3]),
        .O(D[1]));
  LUT3 #(
    .INIT(8'h04)) 
    \FSM_sequential_rx_state[1]_i_2 
       (.I0(reset_time_out_reg_0),
        .I1(time_out_100us),
        .I2(data_valid_sync),
        .O(rx_state1));
  LUT6 #(
    .INIT(64'hFFFFFFFF08080008)) 
    \FSM_sequential_rx_state[3]_i_2 
       (.I0(out[1]),
        .I1(out[2]),
        .I2(\FSM_sequential_rx_state_reg[3] ),
        .I3(time_out_2ms),
        .I4(reset_time_out_reg_0),
        .I5(\FSM_sequential_rx_state[3]_i_7_n_0 ),
        .O(D[2]));
  LUT6 #(
    .INIT(64'h000003000F000B00)) 
    \FSM_sequential_rx_state[3]_i_5 
       (.I0(time_out_100us_reg),
        .I1(out[0]),
        .I2(out[2]),
        .I3(out[3]),
        .I4(data_valid_sync),
        .I5(out[1]),
        .O(\FSM_sequential_rx_state_reg[0] ));
  LUT6 #(
    .INIT(64'h000005000000F300)) 
    \FSM_sequential_rx_state[3]_i_7 
       (.I0(rx_state1),
        .I1(time_out_wait_bypass_s3),
        .I2(out[1]),
        .I3(out[3]),
        .I4(out[2]),
        .I5(out[0]),
        .O(\FSM_sequential_rx_state[3]_i_7_n_0 ));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FD" *) 
  (* box_type = "PRIMITIVE" *) 
  FDRE #(
    .INIT(1'b0)) 
    data_sync_reg1
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(data_out),
        .Q(data_sync1),
        .R(1'b0));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FD" *) 
  (* box_type = "PRIMITIVE" *) 
  FDRE #(
    .INIT(1'b0)) 
    data_sync_reg2
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(data_sync1),
        .Q(data_sync2),
        .R(1'b0));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FD" *) 
  (* box_type = "PRIMITIVE" *) 
  FDRE #(
    .INIT(1'b0)) 
    data_sync_reg3
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(data_sync2),
        .Q(data_sync3),
        .R(1'b0));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FD" *) 
  (* box_type = "PRIMITIVE" *) 
  FDRE #(
    .INIT(1'b0)) 
    data_sync_reg4
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(data_sync3),
        .Q(data_sync4),
        .R(1'b0));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FD" *) 
  (* box_type = "PRIMITIVE" *) 
  FDRE #(
    .INIT(1'b0)) 
    data_sync_reg5
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(data_sync4),
        .Q(data_sync5),
        .R(1'b0));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FD" *) 
  (* box_type = "PRIMITIVE" *) 
  FDRE #(
    .INIT(1'b0)) 
    data_sync_reg6
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(data_sync5),
        .Q(data_valid_sync),
        .R(1'b0));
  LUT5 #(
    .INIT(32'hF1FFF100)) 
    reset_time_out_i_1__0
       (.I0(rxresetdone_s3_reg),
        .I1(out[3]),
        .I2(reset_time_out_i_3__0_n_0),
        .I3(gt0_rx_cdrlocked_reg),
        .I4(reset_time_out_reg_0),
        .O(reset_time_out_reg));
  LUT6 #(
    .INIT(64'h00001B1B0000FF1F)) 
    reset_time_out_i_3__0
       (.I0(data_valid_sync),
        .I1(out[0]),
        .I2(out[1]),
        .I3(cplllock_sync),
        .I4(out[2]),
        .I5(out[3]),
        .O(reset_time_out_i_3__0_n_0));
  LUT4 #(
    .INIT(16'hABA8)) 
    rx_fsm_reset_done_int_i_1
       (.I0(rx_fsm_reset_done_int),
        .I1(rx_fsm_reset_done_int_i_3_n_0),
        .I2(rx_fsm_reset_done_int_i_4_n_0),
        .I3(data_in),
        .O(rx_fsm_reset_done_int_reg));
  LUT5 #(
    .INIT(32'h00000008)) 
    rx_fsm_reset_done_int_i_2
       (.I0(time_out_1us),
        .I1(data_valid_sync),
        .I2(reset_time_out_reg_0),
        .I3(out[0]),
        .I4(out[2]),
        .O(rx_fsm_reset_done_int));
  LUT6 #(
    .INIT(64'h0000000040404000)) 
    rx_fsm_reset_done_int_i_3
       (.I0(out[1]),
        .I1(out[0]),
        .I2(out[3]),
        .I3(data_valid_sync),
        .I4(time_out_100us_reg),
        .I5(out[2]),
        .O(rx_fsm_reset_done_int_i_3_n_0));
  LUT5 #(
    .INIT(32'h20AA0000)) 
    rx_fsm_reset_done_int_i_4
       (.I0(\FSM_sequential_rx_state_reg[3]_0 ),
        .I1(reset_time_out_reg_0),
        .I2(time_out_1us),
        .I3(data_valid_sync),
        .I4(out[1]),
        .O(rx_fsm_reset_done_int_i_4_n_0));
endmodule

(* ORIG_REF_NAME = "GigEthGth7Core_sync_block" *) 
module GigEthGth7Core_GigEthGth7Core_sync_block_17
   (SR,
    mmcm_lock_reclocked_reg,
    mmcm_lock_reclocked,
    Q,
    \mmcm_lock_count_reg[4] ,
    mmcm_locked,
    independent_clock_bufg);
  output [0:0]SR;
  output mmcm_lock_reclocked_reg;
  input mmcm_lock_reclocked;
  input [2:0]Q;
  input \mmcm_lock_count_reg[4] ;
  input mmcm_locked;
  input independent_clock_bufg;

  wire [2:0]Q;
  wire [0:0]SR;
  wire data_sync1;
  wire data_sync2;
  wire data_sync3;
  wire data_sync4;
  wire data_sync5;
  wire independent_clock_bufg;
  wire \mmcm_lock_count_reg[4] ;
  wire mmcm_lock_i;
  wire mmcm_lock_reclocked;
  wire mmcm_lock_reclocked_reg;
  wire mmcm_locked;

  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FD" *) 
  (* box_type = "PRIMITIVE" *) 
  FDRE #(
    .INIT(1'b0)) 
    data_sync_reg1
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(mmcm_locked),
        .Q(data_sync1),
        .R(1'b0));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FD" *) 
  (* box_type = "PRIMITIVE" *) 
  FDRE #(
    .INIT(1'b0)) 
    data_sync_reg2
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(data_sync1),
        .Q(data_sync2),
        .R(1'b0));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FD" *) 
  (* box_type = "PRIMITIVE" *) 
  FDRE #(
    .INIT(1'b0)) 
    data_sync_reg3
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(data_sync2),
        .Q(data_sync3),
        .R(1'b0));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FD" *) 
  (* box_type = "PRIMITIVE" *) 
  FDRE #(
    .INIT(1'b0)) 
    data_sync_reg4
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(data_sync3),
        .Q(data_sync4),
        .R(1'b0));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FD" *) 
  (* box_type = "PRIMITIVE" *) 
  FDRE #(
    .INIT(1'b0)) 
    data_sync_reg5
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(data_sync4),
        .Q(data_sync5),
        .R(1'b0));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FD" *) 
  (* box_type = "PRIMITIVE" *) 
  FDRE #(
    .INIT(1'b0)) 
    data_sync_reg6
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(data_sync5),
        .Q(mmcm_lock_i),
        .R(1'b0));
  LUT1 #(
    .INIT(2'h1)) 
    \mmcm_lock_count[7]_i_1__0 
       (.I0(mmcm_lock_i),
        .O(SR));
  LUT6 #(
    .INIT(64'hEAAAAAAA00000000)) 
    mmcm_lock_reclocked_i_1__0
       (.I0(mmcm_lock_reclocked),
        .I1(Q[2]),
        .I2(Q[1]),
        .I3(Q[0]),
        .I4(\mmcm_lock_count_reg[4] ),
        .I5(mmcm_lock_i),
        .O(mmcm_lock_reclocked_reg));
endmodule

(* ORIG_REF_NAME = "GigEthGth7Core_sync_block" *) 
module GigEthGth7Core_GigEthGth7Core_sync_block_18
   (data_out,
    data_in,
    userclk);
  output data_out;
  input data_in;
  input userclk;

  wire data_in;
  wire data_out;
  wire data_sync1;
  wire data_sync2;
  wire data_sync3;
  wire data_sync4;
  wire data_sync5;
  wire userclk;

  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FD" *) 
  (* box_type = "PRIMITIVE" *) 
  FDRE #(
    .INIT(1'b0)) 
    data_sync_reg1
       (.C(userclk),
        .CE(1'b1),
        .D(data_in),
        .Q(data_sync1),
        .R(1'b0));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FD" *) 
  (* box_type = "PRIMITIVE" *) 
  FDRE #(
    .INIT(1'b0)) 
    data_sync_reg2
       (.C(userclk),
        .CE(1'b1),
        .D(data_sync1),
        .Q(data_sync2),
        .R(1'b0));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FD" *) 
  (* box_type = "PRIMITIVE" *) 
  FDRE #(
    .INIT(1'b0)) 
    data_sync_reg3
       (.C(userclk),
        .CE(1'b1),
        .D(data_sync2),
        .Q(data_sync3),
        .R(1'b0));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FD" *) 
  (* box_type = "PRIMITIVE" *) 
  FDRE #(
    .INIT(1'b0)) 
    data_sync_reg4
       (.C(userclk),
        .CE(1'b1),
        .D(data_sync3),
        .Q(data_sync4),
        .R(1'b0));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FD" *) 
  (* box_type = "PRIMITIVE" *) 
  FDRE #(
    .INIT(1'b0)) 
    data_sync_reg5
       (.C(userclk),
        .CE(1'b1),
        .D(data_sync4),
        .Q(data_sync5),
        .R(1'b0));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FD" *) 
  (* box_type = "PRIMITIVE" *) 
  FDRE #(
    .INIT(1'b0)) 
    data_sync_reg6
       (.C(userclk),
        .CE(1'b1),
        .D(data_sync5),
        .Q(data_out),
        .R(1'b0));
endmodule

(* ORIG_REF_NAME = "GigEthGth7Core_sync_block" *) 
module GigEthGth7Core_GigEthGth7Core_sync_block_19
   (data_out,
    data_in,
    userclk);
  output data_out;
  input data_in;
  input userclk;

  wire data_in;
  wire data_out;
  wire data_sync1;
  wire data_sync2;
  wire data_sync3;
  wire data_sync4;
  wire data_sync5;
  wire userclk;

  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FD" *) 
  (* box_type = "PRIMITIVE" *) 
  FDRE #(
    .INIT(1'b0)) 
    data_sync_reg1
       (.C(userclk),
        .CE(1'b1),
        .D(data_in),
        .Q(data_sync1),
        .R(1'b0));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FD" *) 
  (* box_type = "PRIMITIVE" *) 
  FDRE #(
    .INIT(1'b0)) 
    data_sync_reg2
       (.C(userclk),
        .CE(1'b1),
        .D(data_sync1),
        .Q(data_sync2),
        .R(1'b0));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FD" *) 
  (* box_type = "PRIMITIVE" *) 
  FDRE #(
    .INIT(1'b0)) 
    data_sync_reg3
       (.C(userclk),
        .CE(1'b1),
        .D(data_sync2),
        .Q(data_sync3),
        .R(1'b0));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FD" *) 
  (* box_type = "PRIMITIVE" *) 
  FDRE #(
    .INIT(1'b0)) 
    data_sync_reg4
       (.C(userclk),
        .CE(1'b1),
        .D(data_sync3),
        .Q(data_sync4),
        .R(1'b0));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FD" *) 
  (* box_type = "PRIMITIVE" *) 
  FDRE #(
    .INIT(1'b0)) 
    data_sync_reg5
       (.C(userclk),
        .CE(1'b1),
        .D(data_sync4),
        .Q(data_sync5),
        .R(1'b0));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FD" *) 
  (* box_type = "PRIMITIVE" *) 
  FDRE #(
    .INIT(1'b0)) 
    data_sync_reg6
       (.C(userclk),
        .CE(1'b1),
        .D(data_sync5),
        .Q(data_out),
        .R(1'b0));
endmodule

(* ORIG_REF_NAME = "GigEthGth7Core_sync_block" *) 
module GigEthGth7Core_GigEthGth7Core_sync_block_20
   (data_out,
    data_in,
    independent_clock_bufg);
  output data_out;
  input data_in;
  input independent_clock_bufg;

  wire data_in;
  wire data_out;
  wire data_sync1;
  wire data_sync2;
  wire data_sync3;
  wire data_sync4;
  wire data_sync5;
  wire independent_clock_bufg;

  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FD" *) 
  (* box_type = "PRIMITIVE" *) 
  FDRE #(
    .INIT(1'b0)) 
    data_sync_reg1
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(data_in),
        .Q(data_sync1),
        .R(1'b0));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FD" *) 
  (* box_type = "PRIMITIVE" *) 
  FDRE #(
    .INIT(1'b0)) 
    data_sync_reg2
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(data_sync1),
        .Q(data_sync2),
        .R(1'b0));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FD" *) 
  (* box_type = "PRIMITIVE" *) 
  FDRE #(
    .INIT(1'b0)) 
    data_sync_reg3
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(data_sync2),
        .Q(data_sync3),
        .R(1'b0));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FD" *) 
  (* box_type = "PRIMITIVE" *) 
  FDRE #(
    .INIT(1'b0)) 
    data_sync_reg4
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(data_sync3),
        .Q(data_sync4),
        .R(1'b0));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FD" *) 
  (* box_type = "PRIMITIVE" *) 
  FDRE #(
    .INIT(1'b0)) 
    data_sync_reg5
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(data_sync4),
        .Q(data_sync5),
        .R(1'b0));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FD" *) 
  (* box_type = "PRIMITIVE" *) 
  FDRE #(
    .INIT(1'b0)) 
    data_sync_reg6
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(data_sync5),
        .Q(data_out),
        .R(1'b0));
endmodule

(* ORIG_REF_NAME = "GigEthGth7Core_sync_block" *) 
module GigEthGth7Core_GigEthGth7Core_sync_block_3
   (data_out,
    status_vector,
    independent_clock_bufg);
  output data_out;
  input [0:0]status_vector;
  input independent_clock_bufg;

  wire data_out;
  wire data_sync1;
  wire data_sync2;
  wire data_sync3;
  wire data_sync4;
  wire data_sync5;
  wire independent_clock_bufg;
  wire [0:0]status_vector;

  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FD" *) 
  (* box_type = "PRIMITIVE" *) 
  FDRE #(
    .INIT(1'b0)) 
    data_sync_reg1
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(status_vector),
        .Q(data_sync1),
        .R(1'b0));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FD" *) 
  (* box_type = "PRIMITIVE" *) 
  FDRE #(
    .INIT(1'b0)) 
    data_sync_reg2
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(data_sync1),
        .Q(data_sync2),
        .R(1'b0));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FD" *) 
  (* box_type = "PRIMITIVE" *) 
  FDRE #(
    .INIT(1'b0)) 
    data_sync_reg3
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(data_sync2),
        .Q(data_sync3),
        .R(1'b0));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FD" *) 
  (* box_type = "PRIMITIVE" *) 
  FDRE #(
    .INIT(1'b0)) 
    data_sync_reg4
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(data_sync3),
        .Q(data_sync4),
        .R(1'b0));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FD" *) 
  (* box_type = "PRIMITIVE" *) 
  FDRE #(
    .INIT(1'b0)) 
    data_sync_reg5
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(data_sync4),
        .Q(data_sync5),
        .R(1'b0));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FD" *) 
  (* box_type = "PRIMITIVE" *) 
  FDRE #(
    .INIT(1'b0)) 
    data_sync_reg6
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(data_sync5),
        .Q(data_out),
        .R(1'b0));
endmodule

(* ORIG_REF_NAME = "GigEthGth7Core_sync_block" *) 
module GigEthGth7Core_GigEthGth7Core_sync_block_4
   (D,
    \cpllpd_wait_reg[95] ,
    Q,
    data_in,
    gtrefclk_bufg);
  output [1:0]D;
  input \cpllpd_wait_reg[95] ;
  input [3:0]Q;
  input data_in;
  input gtrefclk_bufg;

  wire [1:0]D;
  wire [3:0]Q;
  wire \cpllpd_wait_reg[95] ;
  wire data_in;
  wire data_out;
  wire data_sync1;
  wire data_sync2;
  wire data_sync3;
  wire data_sync4;
  wire data_sync5;
  wire gtrefclk_bufg;

  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FD" *) 
  (* box_type = "PRIMITIVE" *) 
  FDRE #(
    .INIT(1'b0)) 
    data_sync_reg1
       (.C(gtrefclk_bufg),
        .CE(1'b1),
        .D(data_in),
        .Q(data_sync1),
        .R(1'b0));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FD" *) 
  (* box_type = "PRIMITIVE" *) 
  FDRE #(
    .INIT(1'b0)) 
    data_sync_reg2
       (.C(gtrefclk_bufg),
        .CE(1'b1),
        .D(data_sync1),
        .Q(data_sync2),
        .R(1'b0));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FD" *) 
  (* box_type = "PRIMITIVE" *) 
  FDRE #(
    .INIT(1'b0)) 
    data_sync_reg3
       (.C(gtrefclk_bufg),
        .CE(1'b1),
        .D(data_sync2),
        .Q(data_sync3),
        .R(1'b0));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FD" *) 
  (* box_type = "PRIMITIVE" *) 
  FDRE #(
    .INIT(1'b0)) 
    data_sync_reg4
       (.C(gtrefclk_bufg),
        .CE(1'b1),
        .D(data_sync3),
        .Q(data_sync4),
        .R(1'b0));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FD" *) 
  (* box_type = "PRIMITIVE" *) 
  FDRE #(
    .INIT(1'b0)) 
    data_sync_reg5
       (.C(gtrefclk_bufg),
        .CE(1'b1),
        .D(data_sync4),
        .Q(data_sync5),
        .R(1'b0));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FD" *) 
  (* box_type = "PRIMITIVE" *) 
  FDRE #(
    .INIT(1'b0)) 
    data_sync_reg6
       (.C(gtrefclk_bufg),
        .CE(1'b1),
        .D(data_sync5),
        .Q(data_out),
        .R(1'b0));
  LUT6 #(
    .INIT(64'h00002EFC000000C0)) 
    \state[0]_i_1__0 
       (.I0(data_out),
        .I1(Q[1]),
        .I2(\cpllpd_wait_reg[95] ),
        .I3(Q[0]),
        .I4(Q[3]),
        .I5(Q[2]),
        .O(D[0]));
  LUT6 #(
    .INIT(64'h00004C7C00003C3C)) 
    \state[1]_i_1__0 
       (.I0(\cpllpd_wait_reg[95] ),
        .I1(Q[1]),
        .I2(Q[0]),
        .I3(data_out),
        .I4(Q[3]),
        .I5(Q[2]),
        .O(D[1]));
endmodule

(* ORIG_REF_NAME = "GigEthGth7Core_sync_block" *) 
module GigEthGth7Core_GigEthGth7Core_sync_block_7
   (data_out,
    data_in,
    gtrefclk_bufg);
  output data_out;
  input data_in;
  input gtrefclk_bufg;

  wire data_in;
  wire data_out;
  wire data_sync1;
  wire data_sync2;
  wire data_sync3;
  wire data_sync4;
  wire data_sync5;
  wire gtrefclk_bufg;

  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FD" *) 
  (* box_type = "PRIMITIVE" *) 
  FDRE #(
    .INIT(1'b0)) 
    data_sync_reg1
       (.C(gtrefclk_bufg),
        .CE(1'b1),
        .D(data_in),
        .Q(data_sync1),
        .R(1'b0));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FD" *) 
  (* box_type = "PRIMITIVE" *) 
  FDRE #(
    .INIT(1'b0)) 
    data_sync_reg2
       (.C(gtrefclk_bufg),
        .CE(1'b1),
        .D(data_sync1),
        .Q(data_sync2),
        .R(1'b0));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FD" *) 
  (* box_type = "PRIMITIVE" *) 
  FDRE #(
    .INIT(1'b0)) 
    data_sync_reg3
       (.C(gtrefclk_bufg),
        .CE(1'b1),
        .D(data_sync2),
        .Q(data_sync3),
        .R(1'b0));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FD" *) 
  (* box_type = "PRIMITIVE" *) 
  FDRE #(
    .INIT(1'b0)) 
    data_sync_reg4
       (.C(gtrefclk_bufg),
        .CE(1'b1),
        .D(data_sync3),
        .Q(data_sync4),
        .R(1'b0));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FD" *) 
  (* box_type = "PRIMITIVE" *) 
  FDRE #(
    .INIT(1'b0)) 
    data_sync_reg5
       (.C(gtrefclk_bufg),
        .CE(1'b1),
        .D(data_sync4),
        .Q(data_sync5),
        .R(1'b0));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FD" *) 
  (* box_type = "PRIMITIVE" *) 
  FDRE #(
    .INIT(1'b0)) 
    data_sync_reg6
       (.C(gtrefclk_bufg),
        .CE(1'b1),
        .D(data_sync5),
        .Q(data_out),
        .R(1'b0));
endmodule

(* ORIG_REF_NAME = "GigEthGth7Core_sync_block" *) 
module GigEthGth7Core_GigEthGth7Core_sync_block_8
   (data_out,
    \cpllpd_wait_reg[95] ,
    independent_clock_bufg);
  output data_out;
  input \cpllpd_wait_reg[95] ;
  input independent_clock_bufg;

  wire \cpllpd_wait_reg[95] ;
  wire data_out;
  wire data_sync1;
  wire data_sync2;
  wire data_sync3;
  wire data_sync4;
  wire data_sync5;
  wire independent_clock_bufg;

  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FD" *) 
  (* box_type = "PRIMITIVE" *) 
  FDRE #(
    .INIT(1'b0)) 
    data_sync_reg1
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(\cpllpd_wait_reg[95] ),
        .Q(data_sync1),
        .R(1'b0));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FD" *) 
  (* box_type = "PRIMITIVE" *) 
  FDRE #(
    .INIT(1'b0)) 
    data_sync_reg2
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(data_sync1),
        .Q(data_sync2),
        .R(1'b0));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FD" *) 
  (* box_type = "PRIMITIVE" *) 
  FDRE #(
    .INIT(1'b0)) 
    data_sync_reg3
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(data_sync2),
        .Q(data_sync3),
        .R(1'b0));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FD" *) 
  (* box_type = "PRIMITIVE" *) 
  FDRE #(
    .INIT(1'b0)) 
    data_sync_reg4
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(data_sync3),
        .Q(data_sync4),
        .R(1'b0));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FD" *) 
  (* box_type = "PRIMITIVE" *) 
  FDRE #(
    .INIT(1'b0)) 
    data_sync_reg5
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(data_sync4),
        .Q(data_sync5),
        .R(1'b0));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FD" *) 
  (* box_type = "PRIMITIVE" *) 
  FDRE #(
    .INIT(1'b0)) 
    data_sync_reg6
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(data_sync5),
        .Q(data_out),
        .R(1'b0));
endmodule

(* ORIG_REF_NAME = "GigEthGth7Core_sync_block" *) 
module GigEthGth7Core_GigEthGth7Core_sync_block_9
   (reset_time_out_reg,
    E,
    \FSM_sequential_tx_state_reg[3] ,
    init_wait_done_reg,
    out,
    reset_time_out,
    pll_reset_asserted_reg,
    refclk_stable,
    mmcm_lock_reclocked,
    txresetdone_s3,
    \wait_time_cnt_reg[6] ,
    \FSM_sequential_tx_state_reg[2] ,
    time_tlock_max_reg,
    time_out_500us,
    time_out_2ms,
    cplllock,
    independent_clock_bufg);
  output reset_time_out_reg;
  output [0:0]E;
  input \FSM_sequential_tx_state_reg[3] ;
  input init_wait_done_reg;
  input [3:0]out;
  input reset_time_out;
  input pll_reset_asserted_reg;
  input refclk_stable;
  input mmcm_lock_reclocked;
  input txresetdone_s3;
  input [0:0]\wait_time_cnt_reg[6] ;
  input \FSM_sequential_tx_state_reg[2] ;
  input time_tlock_max_reg;
  input time_out_500us;
  input time_out_2ms;
  input cplllock;
  input independent_clock_bufg;

  wire [0:0]E;
  wire \FSM_sequential_tx_state[3]_i_3_n_0 ;
  wire \FSM_sequential_tx_state[3]_i_6_n_0 ;
  wire \FSM_sequential_tx_state_reg[2] ;
  wire \FSM_sequential_tx_state_reg[3] ;
  wire cplllock;
  wire cplllock_sync;
  wire data_sync1;
  wire data_sync2;
  wire data_sync3;
  wire data_sync4;
  wire data_sync5;
  wire independent_clock_bufg;
  wire init_wait_done_reg;
  wire mmcm_lock_reclocked;
  wire [3:0]out;
  wire pll_reset_asserted_reg;
  wire refclk_stable;
  wire reset_time_out;
  wire reset_time_out_i_2_n_0;
  wire reset_time_out_i_4_n_0;
  wire reset_time_out_reg;
  wire time_out_2ms;
  wire time_out_500us;
  wire time_tlock_max_reg;
  wire tx_state0;
  wire txresetdone_s3;
  wire [0:0]\wait_time_cnt_reg[6] ;

  LUT6 #(
    .INIT(64'h00338BBB00338B88)) 
    \FSM_sequential_tx_state[3]_i_1 
       (.I0(\FSM_sequential_tx_state[3]_i_3_n_0 ),
        .I1(out[0]),
        .I2(\wait_time_cnt_reg[6] ),
        .I3(\FSM_sequential_tx_state_reg[2] ),
        .I4(out[3]),
        .I5(init_wait_done_reg),
        .O(E));
  LUT6 #(
    .INIT(64'hBBB8BBBBBBB88888)) 
    \FSM_sequential_tx_state[3]_i_3 
       (.I0(\FSM_sequential_tx_state[3]_i_6_n_0 ),
        .I1(out[1]),
        .I2(time_tlock_max_reg),
        .I3(mmcm_lock_reclocked),
        .I4(out[2]),
        .I5(tx_state0),
        .O(\FSM_sequential_tx_state[3]_i_3_n_0 ));
  LUT6 #(
    .INIT(64'hF4FFF4FFF4FFF400)) 
    \FSM_sequential_tx_state[3]_i_6 
       (.I0(reset_time_out),
        .I1(time_out_500us),
        .I2(txresetdone_s3),
        .I3(out[2]),
        .I4(time_out_2ms),
        .I5(cplllock_sync),
        .O(\FSM_sequential_tx_state[3]_i_6_n_0 ));
  LUT3 #(
    .INIT(8'h40)) 
    \FSM_sequential_tx_state[3]_i_8 
       (.I0(cplllock_sync),
        .I1(pll_reset_asserted_reg),
        .I2(refclk_stable),
        .O(tx_state0));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FD" *) 
  (* box_type = "PRIMITIVE" *) 
  FDRE #(
    .INIT(1'b0)) 
    data_sync_reg1
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(cplllock),
        .Q(data_sync1),
        .R(1'b0));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FD" *) 
  (* box_type = "PRIMITIVE" *) 
  FDRE #(
    .INIT(1'b0)) 
    data_sync_reg2
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(data_sync1),
        .Q(data_sync2),
        .R(1'b0));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FD" *) 
  (* box_type = "PRIMITIVE" *) 
  FDRE #(
    .INIT(1'b0)) 
    data_sync_reg3
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(data_sync2),
        .Q(data_sync3),
        .R(1'b0));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FD" *) 
  (* box_type = "PRIMITIVE" *) 
  FDRE #(
    .INIT(1'b0)) 
    data_sync_reg4
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(data_sync3),
        .Q(data_sync4),
        .R(1'b0));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FD" *) 
  (* box_type = "PRIMITIVE" *) 
  FDRE #(
    .INIT(1'b0)) 
    data_sync_reg5
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(data_sync4),
        .Q(data_sync5),
        .R(1'b0));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FD" *) 
  (* box_type = "PRIMITIVE" *) 
  FDRE #(
    .INIT(1'b0)) 
    data_sync_reg6
       (.C(independent_clock_bufg),
        .CE(1'b1),
        .D(data_sync5),
        .Q(cplllock_sync),
        .R(1'b0));
  LUT6 #(
    .INIT(64'h88B8FFFF88B80000)) 
    reset_time_out_i_1
       (.I0(reset_time_out_i_2_n_0),
        .I1(\FSM_sequential_tx_state_reg[3] ),
        .I2(init_wait_done_reg),
        .I3(out[3]),
        .I4(reset_time_out_i_4_n_0),
        .I5(reset_time_out),
        .O(reset_time_out_reg));
  LUT6 #(
    .INIT(64'hF4F4FF0F0404FF0F)) 
    reset_time_out_i_2
       (.I0(out[3]),
        .I1(cplllock_sync),
        .I2(out[2]),
        .I3(mmcm_lock_reclocked),
        .I4(out[1]),
        .I5(txresetdone_s3),
        .O(reset_time_out_i_2_n_0));
  LUT6 #(
    .INIT(64'h03030303FFF30202)) 
    reset_time_out_i_4
       (.I0(init_wait_done_reg),
        .I1(out[1]),
        .I2(out[2]),
        .I3(cplllock_sync),
        .I4(out[0]),
        .I5(out[3]),
        .O(reset_time_out_i_4_n_0));
endmodule

(* ORIG_REF_NAME = "GigEthGth7Core_transceiver" *) 
module GigEthGth7Core_GigEthGth7Core_transceiver
   (cplllock,
    txn,
    txp,
    rxoutclk,
    txoutclk,
    data_in,
    data_sync_reg1,
    rxchariscomma,
    rxcharisk,
    rxclkcorcnt,
    rxdata,
    rxdisperr,
    rxnotintable,
    rxbuferr,
    txbuferr,
    mmcm_reset,
    gtrefclk_bufg,
    status_vector,
    independent_clock_bufg,
    userclk,
    encommaalign,
    SR,
    \USE_ROCKET_IO.MGT_RX_RESET_INT_reg ,
    rxn,
    rxp,
    gtrefclk,
    gt0_qplloutclk_in,
    gt0_qplloutrefclk_in,
    mmcm_locked,
    pma_reset,
    userclk2,
    powerdown,
    txchardispmode,
    txchardispval,
    txdata,
    txcharisk);
  output cplllock;
  output txn;
  output txp;
  output rxoutclk;
  output txoutclk;
  output data_in;
  output data_sync_reg1;
  output rxchariscomma;
  output rxcharisk;
  output [1:0]rxclkcorcnt;
  output [7:0]rxdata;
  output rxdisperr;
  output rxnotintable;
  output rxbuferr;
  output txbuferr;
  output mmcm_reset;
  input gtrefclk_bufg;
  input [0:0]status_vector;
  input independent_clock_bufg;
  input userclk;
  input encommaalign;
  input [0:0]SR;
  input [0:0]\USE_ROCKET_IO.MGT_RX_RESET_INT_reg ;
  input rxn;
  input rxp;
  input gtrefclk;
  input gt0_qplloutclk_in;
  input gt0_qplloutrefclk_in;
  input mmcm_locked;
  input pma_reset;
  input userclk2;
  input powerdown;
  input txchardispmode;
  input txchardispval;
  input [7:0]txdata;
  input txcharisk;

  wire [0:0]SR;
  wire [0:0]\USE_ROCKET_IO.MGT_RX_RESET_INT_reg ;
  wire cplllock;
  wire data_in;
  wire data_sync_reg1;
  wire encommaalign;
  wire gt0_qplloutclk_in;
  wire gt0_qplloutrefclk_in;
  wire [1:0]gt0_rxchariscomma_out;
  wire [1:0]gt0_rxcharisk_out;
  wire [1:0]gt0_rxclkcorcnt_out;
  wire [15:0]gt0_rxdata_out;
  wire [1:0]gt0_rxdisperr_out;
  wire gt0_rxmcommaalignen_in;
  wire [1:0]gt0_rxnotintable_out;
  wire gtrefclk;
  wire gtrefclk_bufg;
  wire gtwizard_inst_n_7;
  wire gtwizard_inst_n_8;
  wire independent_clock_bufg;
  wire mmcm_locked;
  wire mmcm_reset;
  wire pma_reset;
  wire powerdown;
  wire reset;
  wire reset_out;
  wire reset_out1_in;
  wire rxbuferr;
  wire [2:2]rxbufstatus_reg;
  wire rxchariscomma;
  wire [1:0]rxchariscomma_double;
  wire rxchariscomma_i_1_n_0;
  wire [1:0]rxchariscomma_reg__0;
  wire rxcharisk;
  wire [1:0]rxcharisk_double;
  wire rxcharisk_i_1_n_0;
  wire [1:0]rxcharisk_reg__0;
  wire [1:0]rxclkcorcnt;
  wire [1:0]rxclkcorcnt_double;
  wire [1:0]rxclkcorcnt_reg;
  wire [7:0]rxdata;
  wire \rxdata[0]_i_1_n_0 ;
  wire \rxdata[1]_i_1_n_0 ;
  wire \rxdata[2]_i_1_n_0 ;
  wire \rxdata[3]_i_1_n_0 ;
  wire \rxdata[4]_i_1_n_0 ;
  wire \rxdata[5]_i_1_n_0 ;
  wire \rxdata[6]_i_1_n_0 ;
  wire \rxdata[7]_i_1_n_0 ;
  wire [15:0]rxdata_double;
  wire [15:0]rxdata_reg;
  wire rxdisperr;
  wire [1:0]rxdisperr_double;
  wire rxdisperr_i_1_n_0;
  wire [1:0]rxdisperr_reg__0;
  wire rxn;
  wire rxnotintable;
  wire [1:0]rxnotintable_double;
  wire rxnotintable_i_1_n_0;
  wire [1:0]rxnotintable_reg__0;
  wire rxoutclk;
  wire rxp;
  wire rxpowerdown;
  wire rxpowerdown_double;
  wire rxpowerdown_reg__0;
  wire [0:0]status_vector;
  wire sync_block_data_valid_n_0;
  wire toggle;
  wire toggle_i_1_n_0;
  wire txbuferr;
  wire [1:1]txbufstatus_reg;
  wire txchardispmode;
  wire [1:0]txchardispmode_double;
  wire [1:0]txchardispmode_int;
  wire txchardispmode_reg;
  wire txchardispval;
  wire [1:0]txchardispval_double;
  wire [1:0]txchardispval_int;
  wire txchardispval_reg;
  wire txcharisk;
  wire [1:0]txcharisk_double;
  wire [1:0]txcharisk_int;
  wire txcharisk_reg;
  wire [7:0]txdata;
  wire [15:0]txdata_double;
  wire [15:0]txdata_int;
  wire [7:0]txdata_reg;
  wire txn;
  wire txoutclk;
  wire txp;
  wire txpowerdown;
  wire txpowerdown_double;
  wire txpowerdown_reg__0;
  wire userclk;
  wire userclk2;

  GigEthGth7Core_GigEthGth7Core_GTWIZARD gtwizard_inst
       (.D(gt0_rxclkcorcnt_out),
        .Q(txdata_int),
        .RXBUFSTATUS(gtwizard_inst_n_8),
        .RXPD(rxpowerdown),
        .TXBUFSTATUS(gtwizard_inst_n_7),
        .TXPD(txpowerdown),
        .cplllock(cplllock),
        .data_in(data_in),
        .data_out(sync_block_data_valid_n_0),
        .data_sync_reg1(data_sync_reg1),
        .gt0_qplloutclk_in(gt0_qplloutclk_in),
        .gt0_qplloutrefclk_in(gt0_qplloutrefclk_in),
        .gtrefclk(gtrefclk),
        .gtrefclk_bufg(gtrefclk_bufg),
        .independent_clock_bufg(independent_clock_bufg),
        .mmcm_locked(mmcm_locked),
        .mmcm_reset(mmcm_reset),
        .pma_reset(pma_reset),
        .reset(reset),
        .reset_out(gt0_rxmcommaalignen_in),
        .reset_sync6(reset_out1_in),
        .reset_sync6_0(reset_out),
        .\rxchariscomma_reg_reg[1] (gt0_rxchariscomma_out),
        .\rxcharisk_reg_reg[1] (gt0_rxcharisk_out),
        .\rxdata_reg_reg[15] (gt0_rxdata_out),
        .\rxdisperr_reg_reg[1] (gt0_rxdisperr_out),
        .rxn(rxn),
        .\rxnotintable_reg_reg[1] (gt0_rxnotintable_out),
        .rxoutclk(rxoutclk),
        .rxp(rxp),
        .\txchardispmode_int_reg[1] (txchardispmode_int),
        .\txchardispval_int_reg[1] (txchardispval_int),
        .\txcharisk_int_reg[1] (txcharisk_int),
        .txn(txn),
        .txoutclk(txoutclk),
        .txp(txp),
        .userclk(userclk));
  GigEthGth7Core_GigEthGth7Core_reset_sync reclock_encommaalign
       (.encommaalign(encommaalign),
        .reset_out(gt0_rxmcommaalignen_in),
        .userclk(userclk));
  GigEthGth7Core_GigEthGth7Core_reset_sync_1 reclock_rxreset
       (.\USE_ROCKET_IO.MGT_RX_RESET_INT_reg (\USE_ROCKET_IO.MGT_RX_RESET_INT_reg ),
        .independent_clock_bufg(independent_clock_bufg),
        .reset_out(reset_out1_in));
  GigEthGth7Core_GigEthGth7Core_reset_sync_2 reclock_txreset
       (.SR(SR),
        .independent_clock_bufg(independent_clock_bufg),
        .reset_out(reset_out));
  GigEthGth7Core_GigEthGth7Core_reset_wtd_timer reset_wtd_timer
       (.data_out(sync_block_data_valid_n_0),
        .independent_clock_bufg(independent_clock_bufg),
        .reset(reset));
  FDRE rxbuferr_reg
       (.C(userclk2),
        .CE(1'b1),
        .D(rxbufstatus_reg),
        .Q(rxbuferr),
        .R(1'b0));
  FDRE \rxbufstatus_reg_reg[2] 
       (.C(userclk),
        .CE(1'b1),
        .D(gtwizard_inst_n_8),
        .Q(rxbufstatus_reg),
        .R(1'b0));
  FDRE \rxchariscomma_double_reg[0] 
       (.C(userclk2),
        .CE(toggle),
        .D(rxchariscomma_reg__0[0]),
        .Q(rxchariscomma_double[0]),
        .R(\USE_ROCKET_IO.MGT_RX_RESET_INT_reg ));
  FDRE \rxchariscomma_double_reg[1] 
       (.C(userclk2),
        .CE(toggle),
        .D(rxchariscomma_reg__0[1]),
        .Q(rxchariscomma_double[1]),
        .R(\USE_ROCKET_IO.MGT_RX_RESET_INT_reg ));
  (* SOFT_HLUTNM = "soft_lutpair74" *) 
  LUT3 #(
    .INIT(8'hB8)) 
    rxchariscomma_i_1
       (.I0(rxchariscomma_double[1]),
        .I1(toggle),
        .I2(rxchariscomma_double[0]),
        .O(rxchariscomma_i_1_n_0));
  FDRE rxchariscomma_reg
       (.C(userclk2),
        .CE(1'b1),
        .D(rxchariscomma_i_1_n_0),
        .Q(rxchariscomma),
        .R(\USE_ROCKET_IO.MGT_RX_RESET_INT_reg ));
  FDRE \rxchariscomma_reg_reg[0] 
       (.C(userclk),
        .CE(1'b1),
        .D(gt0_rxchariscomma_out[0]),
        .Q(rxchariscomma_reg__0[0]),
        .R(1'b0));
  FDRE \rxchariscomma_reg_reg[1] 
       (.C(userclk),
        .CE(1'b1),
        .D(gt0_rxchariscomma_out[1]),
        .Q(rxchariscomma_reg__0[1]),
        .R(1'b0));
  FDRE \rxcharisk_double_reg[0] 
       (.C(userclk2),
        .CE(toggle),
        .D(rxcharisk_reg__0[0]),
        .Q(rxcharisk_double[0]),
        .R(\USE_ROCKET_IO.MGT_RX_RESET_INT_reg ));
  FDRE \rxcharisk_double_reg[1] 
       (.C(userclk2),
        .CE(toggle),
        .D(rxcharisk_reg__0[1]),
        .Q(rxcharisk_double[1]),
        .R(\USE_ROCKET_IO.MGT_RX_RESET_INT_reg ));
  (* SOFT_HLUTNM = "soft_lutpair74" *) 
  LUT3 #(
    .INIT(8'hB8)) 
    rxcharisk_i_1
       (.I0(rxcharisk_double[1]),
        .I1(toggle),
        .I2(rxcharisk_double[0]),
        .O(rxcharisk_i_1_n_0));
  FDRE rxcharisk_reg
       (.C(userclk2),
        .CE(1'b1),
        .D(rxcharisk_i_1_n_0),
        .Q(rxcharisk),
        .R(\USE_ROCKET_IO.MGT_RX_RESET_INT_reg ));
  FDRE \rxcharisk_reg_reg[0] 
       (.C(userclk),
        .CE(1'b1),
        .D(gt0_rxcharisk_out[0]),
        .Q(rxcharisk_reg__0[0]),
        .R(1'b0));
  FDRE \rxcharisk_reg_reg[1] 
       (.C(userclk),
        .CE(1'b1),
        .D(gt0_rxcharisk_out[1]),
        .Q(rxcharisk_reg__0[1]),
        .R(1'b0));
  FDRE \rxclkcorcnt_double_reg[0] 
       (.C(userclk2),
        .CE(toggle),
        .D(rxclkcorcnt_reg[0]),
        .Q(rxclkcorcnt_double[0]),
        .R(\USE_ROCKET_IO.MGT_RX_RESET_INT_reg ));
  FDRE \rxclkcorcnt_double_reg[1] 
       (.C(userclk2),
        .CE(toggle),
        .D(rxclkcorcnt_reg[1]),
        .Q(rxclkcorcnt_double[1]),
        .R(\USE_ROCKET_IO.MGT_RX_RESET_INT_reg ));
  FDRE \rxclkcorcnt_reg[0] 
       (.C(userclk2),
        .CE(1'b1),
        .D(rxclkcorcnt_double[0]),
        .Q(rxclkcorcnt[0]),
        .R(\USE_ROCKET_IO.MGT_RX_RESET_INT_reg ));
  FDRE \rxclkcorcnt_reg[1] 
       (.C(userclk2),
        .CE(1'b1),
        .D(rxclkcorcnt_double[1]),
        .Q(rxclkcorcnt[1]),
        .R(\USE_ROCKET_IO.MGT_RX_RESET_INT_reg ));
  FDRE \rxclkcorcnt_reg_reg[0] 
       (.C(userclk),
        .CE(1'b1),
        .D(gt0_rxclkcorcnt_out[0]),
        .Q(rxclkcorcnt_reg[0]),
        .R(1'b0));
  FDRE \rxclkcorcnt_reg_reg[1] 
       (.C(userclk),
        .CE(1'b1),
        .D(gt0_rxclkcorcnt_out[1]),
        .Q(rxclkcorcnt_reg[1]),
        .R(1'b0));
  (* SOFT_HLUTNM = "soft_lutpair70" *) 
  LUT3 #(
    .INIT(8'hAC)) 
    \rxdata[0]_i_1 
       (.I0(rxdata_double[8]),
        .I1(rxdata_double[0]),
        .I2(toggle),
        .O(\rxdata[0]_i_1_n_0 ));
  (* SOFT_HLUTNM = "soft_lutpair70" *) 
  LUT3 #(
    .INIT(8'hAC)) 
    \rxdata[1]_i_1 
       (.I0(rxdata_double[9]),
        .I1(rxdata_double[1]),
        .I2(toggle),
        .O(\rxdata[1]_i_1_n_0 ));
  (* SOFT_HLUTNM = "soft_lutpair71" *) 
  LUT3 #(
    .INIT(8'hAC)) 
    \rxdata[2]_i_1 
       (.I0(rxdata_double[10]),
        .I1(rxdata_double[2]),
        .I2(toggle),
        .O(\rxdata[2]_i_1_n_0 ));
  (* SOFT_HLUTNM = "soft_lutpair71" *) 
  LUT3 #(
    .INIT(8'hAC)) 
    \rxdata[3]_i_1 
       (.I0(rxdata_double[11]),
        .I1(rxdata_double[3]),
        .I2(toggle),
        .O(\rxdata[3]_i_1_n_0 ));
  (* SOFT_HLUTNM = "soft_lutpair72" *) 
  LUT3 #(
    .INIT(8'hAC)) 
    \rxdata[4]_i_1 
       (.I0(rxdata_double[12]),
        .I1(rxdata_double[4]),
        .I2(toggle),
        .O(\rxdata[4]_i_1_n_0 ));
  (* SOFT_HLUTNM = "soft_lutpair72" *) 
  LUT3 #(
    .INIT(8'hAC)) 
    \rxdata[5]_i_1 
       (.I0(rxdata_double[13]),
        .I1(rxdata_double[5]),
        .I2(toggle),
        .O(\rxdata[5]_i_1_n_0 ));
  (* SOFT_HLUTNM = "soft_lutpair73" *) 
  LUT3 #(
    .INIT(8'hAC)) 
    \rxdata[6]_i_1 
       (.I0(rxdata_double[14]),
        .I1(rxdata_double[6]),
        .I2(toggle),
        .O(\rxdata[6]_i_1_n_0 ));
  (* SOFT_HLUTNM = "soft_lutpair73" *) 
  LUT3 #(
    .INIT(8'hAC)) 
    \rxdata[7]_i_1 
       (.I0(rxdata_double[15]),
        .I1(rxdata_double[7]),
        .I2(toggle),
        .O(\rxdata[7]_i_1_n_0 ));
  FDRE \rxdata_double_reg[0] 
       (.C(userclk2),
        .CE(toggle),
        .D(rxdata_reg[0]),
        .Q(rxdata_double[0]),
        .R(\USE_ROCKET_IO.MGT_RX_RESET_INT_reg ));
  FDRE \rxdata_double_reg[10] 
       (.C(userclk2),
        .CE(toggle),
        .D(rxdata_reg[10]),
        .Q(rxdata_double[10]),
        .R(\USE_ROCKET_IO.MGT_RX_RESET_INT_reg ));
  FDRE \rxdata_double_reg[11] 
       (.C(userclk2),
        .CE(toggle),
        .D(rxdata_reg[11]),
        .Q(rxdata_double[11]),
        .R(\USE_ROCKET_IO.MGT_RX_RESET_INT_reg ));
  FDRE \rxdata_double_reg[12] 
       (.C(userclk2),
        .CE(toggle),
        .D(rxdata_reg[12]),
        .Q(rxdata_double[12]),
        .R(\USE_ROCKET_IO.MGT_RX_RESET_INT_reg ));
  FDRE \rxdata_double_reg[13] 
       (.C(userclk2),
        .CE(toggle),
        .D(rxdata_reg[13]),
        .Q(rxdata_double[13]),
        .R(\USE_ROCKET_IO.MGT_RX_RESET_INT_reg ));
  FDRE \rxdata_double_reg[14] 
       (.C(userclk2),
        .CE(toggle),
        .D(rxdata_reg[14]),
        .Q(rxdata_double[14]),
        .R(\USE_ROCKET_IO.MGT_RX_RESET_INT_reg ));
  FDRE \rxdata_double_reg[15] 
       (.C(userclk2),
        .CE(toggle),
        .D(rxdata_reg[15]),
        .Q(rxdata_double[15]),
        .R(\USE_ROCKET_IO.MGT_RX_RESET_INT_reg ));
  FDRE \rxdata_double_reg[1] 
       (.C(userclk2),
        .CE(toggle),
        .D(rxdata_reg[1]),
        .Q(rxdata_double[1]),
        .R(\USE_ROCKET_IO.MGT_RX_RESET_INT_reg ));
  FDRE \rxdata_double_reg[2] 
       (.C(userclk2),
        .CE(toggle),
        .D(rxdata_reg[2]),
        .Q(rxdata_double[2]),
        .R(\USE_ROCKET_IO.MGT_RX_RESET_INT_reg ));
  FDRE \rxdata_double_reg[3] 
       (.C(userclk2),
        .CE(toggle),
        .D(rxdata_reg[3]),
        .Q(rxdata_double[3]),
        .R(\USE_ROCKET_IO.MGT_RX_RESET_INT_reg ));
  FDRE \rxdata_double_reg[4] 
       (.C(userclk2),
        .CE(toggle),
        .D(rxdata_reg[4]),
        .Q(rxdata_double[4]),
        .R(\USE_ROCKET_IO.MGT_RX_RESET_INT_reg ));
  FDRE \rxdata_double_reg[5] 
       (.C(userclk2),
        .CE(toggle),
        .D(rxdata_reg[5]),
        .Q(rxdata_double[5]),
        .R(\USE_ROCKET_IO.MGT_RX_RESET_INT_reg ));
  FDRE \rxdata_double_reg[6] 
       (.C(userclk2),
        .CE(toggle),
        .D(rxdata_reg[6]),
        .Q(rxdata_double[6]),
        .R(\USE_ROCKET_IO.MGT_RX_RESET_INT_reg ));
  FDRE \rxdata_double_reg[7] 
       (.C(userclk2),
        .CE(toggle),
        .D(rxdata_reg[7]),
        .Q(rxdata_double[7]),
        .R(\USE_ROCKET_IO.MGT_RX_RESET_INT_reg ));
  FDRE \rxdata_double_reg[8] 
       (.C(userclk2),
        .CE(toggle),
        .D(rxdata_reg[8]),
        .Q(rxdata_double[8]),
        .R(\USE_ROCKET_IO.MGT_RX_RESET_INT_reg ));
  FDRE \rxdata_double_reg[9] 
       (.C(userclk2),
        .CE(toggle),
        .D(rxdata_reg[9]),
        .Q(rxdata_double[9]),
        .R(\USE_ROCKET_IO.MGT_RX_RESET_INT_reg ));
  FDRE \rxdata_reg[0] 
       (.C(userclk2),
        .CE(1'b1),
        .D(\rxdata[0]_i_1_n_0 ),
        .Q(rxdata[0]),
        .R(\USE_ROCKET_IO.MGT_RX_RESET_INT_reg ));
  FDRE \rxdata_reg[1] 
       (.C(userclk2),
        .CE(1'b1),
        .D(\rxdata[1]_i_1_n_0 ),
        .Q(rxdata[1]),
        .R(\USE_ROCKET_IO.MGT_RX_RESET_INT_reg ));
  FDRE \rxdata_reg[2] 
       (.C(userclk2),
        .CE(1'b1),
        .D(\rxdata[2]_i_1_n_0 ),
        .Q(rxdata[2]),
        .R(\USE_ROCKET_IO.MGT_RX_RESET_INT_reg ));
  FDRE \rxdata_reg[3] 
       (.C(userclk2),
        .CE(1'b1),
        .D(\rxdata[3]_i_1_n_0 ),
        .Q(rxdata[3]),
        .R(\USE_ROCKET_IO.MGT_RX_RESET_INT_reg ));
  FDRE \rxdata_reg[4] 
       (.C(userclk2),
        .CE(1'b1),
        .D(\rxdata[4]_i_1_n_0 ),
        .Q(rxdata[4]),
        .R(\USE_ROCKET_IO.MGT_RX_RESET_INT_reg ));
  FDRE \rxdata_reg[5] 
       (.C(userclk2),
        .CE(1'b1),
        .D(\rxdata[5]_i_1_n_0 ),
        .Q(rxdata[5]),
        .R(\USE_ROCKET_IO.MGT_RX_RESET_INT_reg ));
  FDRE \rxdata_reg[6] 
       (.C(userclk2),
        .CE(1'b1),
        .D(\rxdata[6]_i_1_n_0 ),
        .Q(rxdata[6]),
        .R(\USE_ROCKET_IO.MGT_RX_RESET_INT_reg ));
  FDRE \rxdata_reg[7] 
       (.C(userclk2),
        .CE(1'b1),
        .D(\rxdata[7]_i_1_n_0 ),
        .Q(rxdata[7]),
        .R(\USE_ROCKET_IO.MGT_RX_RESET_INT_reg ));
  FDRE \rxdata_reg_reg[0] 
       (.C(userclk),
        .CE(1'b1),
        .D(gt0_rxdata_out[0]),
        .Q(rxdata_reg[0]),
        .R(1'b0));
  FDRE \rxdata_reg_reg[10] 
       (.C(userclk),
        .CE(1'b1),
        .D(gt0_rxdata_out[10]),
        .Q(rxdata_reg[10]),
        .R(1'b0));
  FDRE \rxdata_reg_reg[11] 
       (.C(userclk),
        .CE(1'b1),
        .D(gt0_rxdata_out[11]),
        .Q(rxdata_reg[11]),
        .R(1'b0));
  FDRE \rxdata_reg_reg[12] 
       (.C(userclk),
        .CE(1'b1),
        .D(gt0_rxdata_out[12]),
        .Q(rxdata_reg[12]),
        .R(1'b0));
  FDRE \rxdata_reg_reg[13] 
       (.C(userclk),
        .CE(1'b1),
        .D(gt0_rxdata_out[13]),
        .Q(rxdata_reg[13]),
        .R(1'b0));
  FDRE \rxdata_reg_reg[14] 
       (.C(userclk),
        .CE(1'b1),
        .D(gt0_rxdata_out[14]),
        .Q(rxdata_reg[14]),
        .R(1'b0));
  FDRE \rxdata_reg_reg[15] 
       (.C(userclk),
        .CE(1'b1),
        .D(gt0_rxdata_out[15]),
        .Q(rxdata_reg[15]),
        .R(1'b0));
  FDRE \rxdata_reg_reg[1] 
       (.C(userclk),
        .CE(1'b1),
        .D(gt0_rxdata_out[1]),
        .Q(rxdata_reg[1]),
        .R(1'b0));
  FDRE \rxdata_reg_reg[2] 
       (.C(userclk),
        .CE(1'b1),
        .D(gt0_rxdata_out[2]),
        .Q(rxdata_reg[2]),
        .R(1'b0));
  FDRE \rxdata_reg_reg[3] 
       (.C(userclk),
        .CE(1'b1),
        .D(gt0_rxdata_out[3]),
        .Q(rxdata_reg[3]),
        .R(1'b0));
  FDRE \rxdata_reg_reg[4] 
       (.C(userclk),
        .CE(1'b1),
        .D(gt0_rxdata_out[4]),
        .Q(rxdata_reg[4]),
        .R(1'b0));
  FDRE \rxdata_reg_reg[5] 
       (.C(userclk),
        .CE(1'b1),
        .D(gt0_rxdata_out[5]),
        .Q(rxdata_reg[5]),
        .R(1'b0));
  FDRE \rxdata_reg_reg[6] 
       (.C(userclk),
        .CE(1'b1),
        .D(gt0_rxdata_out[6]),
        .Q(rxdata_reg[6]),
        .R(1'b0));
  FDRE \rxdata_reg_reg[7] 
       (.C(userclk),
        .CE(1'b1),
        .D(gt0_rxdata_out[7]),
        .Q(rxdata_reg[7]),
        .R(1'b0));
  FDRE \rxdata_reg_reg[8] 
       (.C(userclk),
        .CE(1'b1),
        .D(gt0_rxdata_out[8]),
        .Q(rxdata_reg[8]),
        .R(1'b0));
  FDRE \rxdata_reg_reg[9] 
       (.C(userclk),
        .CE(1'b1),
        .D(gt0_rxdata_out[9]),
        .Q(rxdata_reg[9]),
        .R(1'b0));
  FDRE \rxdisperr_double_reg[0] 
       (.C(userclk2),
        .CE(toggle),
        .D(rxdisperr_reg__0[0]),
        .Q(rxdisperr_double[0]),
        .R(\USE_ROCKET_IO.MGT_RX_RESET_INT_reg ));
  FDRE \rxdisperr_double_reg[1] 
       (.C(userclk2),
        .CE(toggle),
        .D(rxdisperr_reg__0[1]),
        .Q(rxdisperr_double[1]),
        .R(\USE_ROCKET_IO.MGT_RX_RESET_INT_reg ));
  (* SOFT_HLUTNM = "soft_lutpair75" *) 
  LUT3 #(
    .INIT(8'hB8)) 
    rxdisperr_i_1
       (.I0(rxdisperr_double[1]),
        .I1(toggle),
        .I2(rxdisperr_double[0]),
        .O(rxdisperr_i_1_n_0));
  FDRE rxdisperr_reg
       (.C(userclk2),
        .CE(1'b1),
        .D(rxdisperr_i_1_n_0),
        .Q(rxdisperr),
        .R(\USE_ROCKET_IO.MGT_RX_RESET_INT_reg ));
  FDRE \rxdisperr_reg_reg[0] 
       (.C(userclk),
        .CE(1'b1),
        .D(gt0_rxdisperr_out[0]),
        .Q(rxdisperr_reg__0[0]),
        .R(1'b0));
  FDRE \rxdisperr_reg_reg[1] 
       (.C(userclk),
        .CE(1'b1),
        .D(gt0_rxdisperr_out[1]),
        .Q(rxdisperr_reg__0[1]),
        .R(1'b0));
  FDRE \rxnotintable_double_reg[0] 
       (.C(userclk2),
        .CE(toggle),
        .D(rxnotintable_reg__0[0]),
        .Q(rxnotintable_double[0]),
        .R(\USE_ROCKET_IO.MGT_RX_RESET_INT_reg ));
  FDRE \rxnotintable_double_reg[1] 
       (.C(userclk2),
        .CE(toggle),
        .D(rxnotintable_reg__0[1]),
        .Q(rxnotintable_double[1]),
        .R(\USE_ROCKET_IO.MGT_RX_RESET_INT_reg ));
  (* SOFT_HLUTNM = "soft_lutpair75" *) 
  LUT3 #(
    .INIT(8'hB8)) 
    rxnotintable_i_1
       (.I0(rxnotintable_double[1]),
        .I1(toggle),
        .I2(rxnotintable_double[0]),
        .O(rxnotintable_i_1_n_0));
  FDRE rxnotintable_reg
       (.C(userclk2),
        .CE(1'b1),
        .D(rxnotintable_i_1_n_0),
        .Q(rxnotintable),
        .R(\USE_ROCKET_IO.MGT_RX_RESET_INT_reg ));
  FDRE \rxnotintable_reg_reg[0] 
       (.C(userclk),
        .CE(1'b1),
        .D(gt0_rxnotintable_out[0]),
        .Q(rxnotintable_reg__0[0]),
        .R(1'b0));
  FDRE \rxnotintable_reg_reg[1] 
       (.C(userclk),
        .CE(1'b1),
        .D(gt0_rxnotintable_out[1]),
        .Q(rxnotintable_reg__0[1]),
        .R(1'b0));
  FDRE #(
    .INIT(1'b0)) 
    rxpowerdown_double_reg
       (.C(userclk2),
        .CE(toggle),
        .D(rxpowerdown_reg__0),
        .Q(rxpowerdown_double),
        .R(\USE_ROCKET_IO.MGT_RX_RESET_INT_reg ));
  FDRE #(
    .INIT(1'b0)) 
    rxpowerdown_reg
       (.C(userclk),
        .CE(1'b1),
        .D(rxpowerdown_double),
        .Q(rxpowerdown),
        .R(1'b0));
  FDRE #(
    .INIT(1'b0)) 
    rxpowerdown_reg_reg
       (.C(userclk2),
        .CE(1'b1),
        .D(powerdown),
        .Q(rxpowerdown_reg__0),
        .R(\USE_ROCKET_IO.MGT_RX_RESET_INT_reg ));
  GigEthGth7Core_GigEthGth7Core_sync_block_3 sync_block_data_valid
       (.data_out(sync_block_data_valid_n_0),
        .independent_clock_bufg(independent_clock_bufg),
        .status_vector(status_vector));
  LUT1 #(
    .INIT(2'h1)) 
    toggle_i_1
       (.I0(toggle),
        .O(toggle_i_1_n_0));
  FDRE toggle_reg
       (.C(userclk2),
        .CE(1'b1),
        .D(toggle_i_1_n_0),
        .Q(toggle),
        .R(SR));
  FDRE txbuferr_reg
       (.C(userclk2),
        .CE(1'b1),
        .D(txbufstatus_reg),
        .Q(txbuferr),
        .R(1'b0));
  FDRE \txbufstatus_reg_reg[1] 
       (.C(userclk),
        .CE(1'b1),
        .D(gtwizard_inst_n_7),
        .Q(txbufstatus_reg),
        .R(1'b0));
  FDRE \txchardispmode_double_reg[0] 
       (.C(userclk2),
        .CE(toggle_i_1_n_0),
        .D(txchardispmode_reg),
        .Q(txchardispmode_double[0]),
        .R(SR));
  FDRE \txchardispmode_double_reg[1] 
       (.C(userclk2),
        .CE(toggle_i_1_n_0),
        .D(txchardispmode),
        .Q(txchardispmode_double[1]),
        .R(SR));
  FDRE \txchardispmode_int_reg[0] 
       (.C(userclk),
        .CE(1'b1),
        .D(txchardispmode_double[0]),
        .Q(txchardispmode_int[0]),
        .R(1'b0));
  FDRE \txchardispmode_int_reg[1] 
       (.C(userclk),
        .CE(1'b1),
        .D(txchardispmode_double[1]),
        .Q(txchardispmode_int[1]),
        .R(1'b0));
  FDRE txchardispmode_reg_reg
       (.C(userclk2),
        .CE(1'b1),
        .D(txchardispmode),
        .Q(txchardispmode_reg),
        .R(SR));
  FDRE \txchardispval_double_reg[0] 
       (.C(userclk2),
        .CE(toggle_i_1_n_0),
        .D(txchardispval_reg),
        .Q(txchardispval_double[0]),
        .R(SR));
  FDRE \txchardispval_double_reg[1] 
       (.C(userclk2),
        .CE(toggle_i_1_n_0),
        .D(txchardispval),
        .Q(txchardispval_double[1]),
        .R(SR));
  FDRE \txchardispval_int_reg[0] 
       (.C(userclk),
        .CE(1'b1),
        .D(txchardispval_double[0]),
        .Q(txchardispval_int[0]),
        .R(1'b0));
  FDRE \txchardispval_int_reg[1] 
       (.C(userclk),
        .CE(1'b1),
        .D(txchardispval_double[1]),
        .Q(txchardispval_int[1]),
        .R(1'b0));
  FDRE txchardispval_reg_reg
       (.C(userclk2),
        .CE(1'b1),
        .D(txchardispval),
        .Q(txchardispval_reg),
        .R(SR));
  FDRE \txcharisk_double_reg[0] 
       (.C(userclk2),
        .CE(toggle_i_1_n_0),
        .D(txcharisk_reg),
        .Q(txcharisk_double[0]),
        .R(SR));
  FDRE \txcharisk_double_reg[1] 
       (.C(userclk2),
        .CE(toggle_i_1_n_0),
        .D(txcharisk),
        .Q(txcharisk_double[1]),
        .R(SR));
  FDRE \txcharisk_int_reg[0] 
       (.C(userclk),
        .CE(1'b1),
        .D(txcharisk_double[0]),
        .Q(txcharisk_int[0]),
        .R(1'b0));
  FDRE \txcharisk_int_reg[1] 
       (.C(userclk),
        .CE(1'b1),
        .D(txcharisk_double[1]),
        .Q(txcharisk_int[1]),
        .R(1'b0));
  FDRE txcharisk_reg_reg
       (.C(userclk2),
        .CE(1'b1),
        .D(txcharisk),
        .Q(txcharisk_reg),
        .R(SR));
  FDRE \txdata_double_reg[0] 
       (.C(userclk2),
        .CE(toggle_i_1_n_0),
        .D(txdata_reg[0]),
        .Q(txdata_double[0]),
        .R(SR));
  FDRE \txdata_double_reg[10] 
       (.C(userclk2),
        .CE(toggle_i_1_n_0),
        .D(txdata[2]),
        .Q(txdata_double[10]),
        .R(SR));
  FDRE \txdata_double_reg[11] 
       (.C(userclk2),
        .CE(toggle_i_1_n_0),
        .D(txdata[3]),
        .Q(txdata_double[11]),
        .R(SR));
  FDRE \txdata_double_reg[12] 
       (.C(userclk2),
        .CE(toggle_i_1_n_0),
        .D(txdata[4]),
        .Q(txdata_double[12]),
        .R(SR));
  FDRE \txdata_double_reg[13] 
       (.C(userclk2),
        .CE(toggle_i_1_n_0),
        .D(txdata[5]),
        .Q(txdata_double[13]),
        .R(SR));
  FDRE \txdata_double_reg[14] 
       (.C(userclk2),
        .CE(toggle_i_1_n_0),
        .D(txdata[6]),
        .Q(txdata_double[14]),
        .R(SR));
  FDRE \txdata_double_reg[15] 
       (.C(userclk2),
        .CE(toggle_i_1_n_0),
        .D(txdata[7]),
        .Q(txdata_double[15]),
        .R(SR));
  FDRE \txdata_double_reg[1] 
       (.C(userclk2),
        .CE(toggle_i_1_n_0),
        .D(txdata_reg[1]),
        .Q(txdata_double[1]),
        .R(SR));
  FDRE \txdata_double_reg[2] 
       (.C(userclk2),
        .CE(toggle_i_1_n_0),
        .D(txdata_reg[2]),
        .Q(txdata_double[2]),
        .R(SR));
  FDRE \txdata_double_reg[3] 
       (.C(userclk2),
        .CE(toggle_i_1_n_0),
        .D(txdata_reg[3]),
        .Q(txdata_double[3]),
        .R(SR));
  FDRE \txdata_double_reg[4] 
       (.C(userclk2),
        .CE(toggle_i_1_n_0),
        .D(txdata_reg[4]),
        .Q(txdata_double[4]),
        .R(SR));
  FDRE \txdata_double_reg[5] 
       (.C(userclk2),
        .CE(toggle_i_1_n_0),
        .D(txdata_reg[5]),
        .Q(txdata_double[5]),
        .R(SR));
  FDRE \txdata_double_reg[6] 
       (.C(userclk2),
        .CE(toggle_i_1_n_0),
        .D(txdata_reg[6]),
        .Q(txdata_double[6]),
        .R(SR));
  FDRE \txdata_double_reg[7] 
       (.C(userclk2),
        .CE(toggle_i_1_n_0),
        .D(txdata_reg[7]),
        .Q(txdata_double[7]),
        .R(SR));
  FDRE \txdata_double_reg[8] 
       (.C(userclk2),
        .CE(toggle_i_1_n_0),
        .D(txdata[0]),
        .Q(txdata_double[8]),
        .R(SR));
  FDRE \txdata_double_reg[9] 
       (.C(userclk2),
        .CE(toggle_i_1_n_0),
        .D(txdata[1]),
        .Q(txdata_double[9]),
        .R(SR));
  FDRE \txdata_int_reg[0] 
       (.C(userclk),
        .CE(1'b1),
        .D(txdata_double[0]),
        .Q(txdata_int[0]),
        .R(1'b0));
  FDRE \txdata_int_reg[10] 
       (.C(userclk),
        .CE(1'b1),
        .D(txdata_double[10]),
        .Q(txdata_int[10]),
        .R(1'b0));
  FDRE \txdata_int_reg[11] 
       (.C(userclk),
        .CE(1'b1),
        .D(txdata_double[11]),
        .Q(txdata_int[11]),
        .R(1'b0));
  FDRE \txdata_int_reg[12] 
       (.C(userclk),
        .CE(1'b1),
        .D(txdata_double[12]),
        .Q(txdata_int[12]),
        .R(1'b0));
  FDRE \txdata_int_reg[13] 
       (.C(userclk),
        .CE(1'b1),
        .D(txdata_double[13]),
        .Q(txdata_int[13]),
        .R(1'b0));
  FDRE \txdata_int_reg[14] 
       (.C(userclk),
        .CE(1'b1),
        .D(txdata_double[14]),
        .Q(txdata_int[14]),
        .R(1'b0));
  FDRE \txdata_int_reg[15] 
       (.C(userclk),
        .CE(1'b1),
        .D(txdata_double[15]),
        .Q(txdata_int[15]),
        .R(1'b0));
  FDRE \txdata_int_reg[1] 
       (.C(userclk),
        .CE(1'b1),
        .D(txdata_double[1]),
        .Q(txdata_int[1]),
        .R(1'b0));
  FDRE \txdata_int_reg[2] 
       (.C(userclk),
        .CE(1'b1),
        .D(txdata_double[2]),
        .Q(txdata_int[2]),
        .R(1'b0));
  FDRE \txdata_int_reg[3] 
       (.C(userclk),
        .CE(1'b1),
        .D(txdata_double[3]),
        .Q(txdata_int[3]),
        .R(1'b0));
  FDRE \txdata_int_reg[4] 
       (.C(userclk),
        .CE(1'b1),
        .D(txdata_double[4]),
        .Q(txdata_int[4]),
        .R(1'b0));
  FDRE \txdata_int_reg[5] 
       (.C(userclk),
        .CE(1'b1),
        .D(txdata_double[5]),
        .Q(txdata_int[5]),
        .R(1'b0));
  FDRE \txdata_int_reg[6] 
       (.C(userclk),
        .CE(1'b1),
        .D(txdata_double[6]),
        .Q(txdata_int[6]),
        .R(1'b0));
  FDRE \txdata_int_reg[7] 
       (.C(userclk),
        .CE(1'b1),
        .D(txdata_double[7]),
        .Q(txdata_int[7]),
        .R(1'b0));
  FDRE \txdata_int_reg[8] 
       (.C(userclk),
        .CE(1'b1),
        .D(txdata_double[8]),
        .Q(txdata_int[8]),
        .R(1'b0));
  FDRE \txdata_int_reg[9] 
       (.C(userclk),
        .CE(1'b1),
        .D(txdata_double[9]),
        .Q(txdata_int[9]),
        .R(1'b0));
  FDRE \txdata_reg_reg[0] 
       (.C(userclk2),
        .CE(1'b1),
        .D(txdata[0]),
        .Q(txdata_reg[0]),
        .R(SR));
  FDRE \txdata_reg_reg[1] 
       (.C(userclk2),
        .CE(1'b1),
        .D(txdata[1]),
        .Q(txdata_reg[1]),
        .R(SR));
  FDRE \txdata_reg_reg[2] 
       (.C(userclk2),
        .CE(1'b1),
        .D(txdata[2]),
        .Q(txdata_reg[2]),
        .R(SR));
  FDRE \txdata_reg_reg[3] 
       (.C(userclk2),
        .CE(1'b1),
        .D(txdata[3]),
        .Q(txdata_reg[3]),
        .R(SR));
  FDRE \txdata_reg_reg[4] 
       (.C(userclk2),
        .CE(1'b1),
        .D(txdata[4]),
        .Q(txdata_reg[4]),
        .R(SR));
  FDRE \txdata_reg_reg[5] 
       (.C(userclk2),
        .CE(1'b1),
        .D(txdata[5]),
        .Q(txdata_reg[5]),
        .R(SR));
  FDRE \txdata_reg_reg[6] 
       (.C(userclk2),
        .CE(1'b1),
        .D(txdata[6]),
        .Q(txdata_reg[6]),
        .R(SR));
  FDRE \txdata_reg_reg[7] 
       (.C(userclk2),
        .CE(1'b1),
        .D(txdata[7]),
        .Q(txdata_reg[7]),
        .R(SR));
  FDRE #(
    .INIT(1'b0)) 
    txpowerdown_double_reg
       (.C(userclk2),
        .CE(1'b1),
        .D(txpowerdown_reg__0),
        .Q(txpowerdown_double),
        .R(SR));
  FDRE #(
    .INIT(1'b0)) 
    txpowerdown_reg
       (.C(userclk),
        .CE(1'b1),
        .D(txpowerdown_double),
        .Q(txpowerdown),
        .R(1'b0));
  FDRE #(
    .INIT(1'b0)) 
    txpowerdown_reg_reg
       (.C(userclk2),
        .CE(1'b1),
        .D(powerdown),
        .Q(txpowerdown_reg__0),
        .R(SR));
endmodule

(* ORIG_REF_NAME = "RX" *) 
module GigEthGth7Core_RX
   (gmii_rx_er,
    status_vector,
    gmii_rx_dv,
    gmii_rxd,
    Q,
    userclk2,
    SR,
    SYNC_STATUS_REG0,
    \USE_ROCKET_IO.NO_1588.RXCHARISK_INT_reg ,
    D,
    \USE_ROCKET_IO.NO_1588.RXBUFSTATUS_INT_reg[1] ,
    RXNOTINTABLE_INT,
    p_40_in,
    RXEVEN,
    \NO_MANAGEMENT.CONFIGURATION_VECTOR_REG_reg[2] ,
    \NO_MANAGEMENT.CONFIGURATION_VECTOR_REG_reg[3] ,
    \USE_ROCKET_IO.NO_1588.RXCLKCORCNT_INT_reg[2] );
  output gmii_rx_er;
  output [2:0]status_vector;
  output gmii_rx_dv;
  output [7:0]gmii_rxd;
  input [7:0]Q;
  input userclk2;
  input [0:0]SR;
  input SYNC_STATUS_REG0;
  input \USE_ROCKET_IO.NO_1588.RXCHARISK_INT_reg ;
  input D;
  input \USE_ROCKET_IO.NO_1588.RXBUFSTATUS_INT_reg[1] ;
  input RXNOTINTABLE_INT;
  input p_40_in;
  input RXEVEN;
  input \NO_MANAGEMENT.CONFIGURATION_VECTOR_REG_reg[2] ;
  input [0:0]\NO_MANAGEMENT.CONFIGURATION_VECTOR_REG_reg[3] ;
  input [2:0]\USE_ROCKET_IO.NO_1588.RXCLKCORCNT_INT_reg[2] ;

  wire C;
  wire C0;
  wire CGBAD;
  wire CGBAD_REG1;
  wire CGBAD_REG2;
  wire CGBAD_REG3;
  wire C_HDR_REMOVED;
  wire C_HDR_REMOVED_REG;
  wire C_REG1;
  wire C_REG2;
  wire C_REG3;
  wire D;
  wire D0p0;
  wire D0p0_REG;
  wire D0p0_REG_i_2_n_0;
  wire EOP;
  wire EOP0;
  wire EOP_REG1;
  wire EOP_REG10;
  wire EOP_i_2_n_0;
  wire EXTEND;
  wire EXTEND_ERR;
  wire EXTEND_ERR0;
  wire EXTEND_REG1;
  wire EXTEND_REG2;
  wire EXTEND_REG3;
  wire EXTEND_i_1_n_0;
  wire EXT_ILLEGAL_K;
  wire EXT_ILLEGAL_K0;
  wire EXT_ILLEGAL_K_REG1;
  wire EXT_ILLEGAL_K_REG2;
  wire FALSE_CARRIER;
  wire FALSE_CARRIER_REG1;
  wire FALSE_CARRIER_REG2;
  wire FALSE_CARRIER_REG3;
  wire FALSE_CARRIER_i_1_n_0;
  wire FALSE_CARRIER_i_2_n_0;
  wire FALSE_CARRIER_i_3_n_0;
  wire FALSE_CARRIER_i_4_n_0;
  wire FALSE_DATA;
  wire FALSE_DATA0;
  wire FALSE_DATA_i_2_n_0;
  wire FALSE_DATA_i_3_n_0;
  wire FALSE_DATA_i_4_n_0;
  wire FALSE_K;
  wire FALSE_K0;
  wire FALSE_K_i_2_n_0;
  wire FALSE_K_i_3_n_0;
  wire FALSE_NIT;
  wire FALSE_NIT0;
  wire FALSE_NIT_i_2_n_0;
  wire FALSE_NIT_i_3_n_0;
  wire FALSE_NIT_i_4_n_0;
  wire FROM_IDLE_D;
  wire FROM_IDLE_D0;
  wire FROM_RX_CX;
  wire FROM_RX_CX0;
  wire FROM_RX_CX_i_2_n_0;
  wire FROM_RX_K;
  wire FROM_RX_K0;
  wire I;
  wire I0;
  wire I335_in;
  wire \IDLE_REG_reg_n_0_[0] ;
  wire \IDLE_REG_reg_n_0_[2] ;
  wire ILLEGAL_K;
  wire ILLEGAL_K0;
  wire ILLEGAL_K_REG1;
  wire ILLEGAL_K_REG2;
  wire I_REG_reg_n_0;
  wire I_i_2_n_0;
  wire I_i_4_n_0;
  wire K23p7;
  wire K28p5;
  wire K28p5_REG1;
  wire K28p5_REG2;
  wire K29p7;
  wire \NO_MANAGEMENT.CONFIGURATION_VECTOR_REG_reg[2] ;
  wire [0:0]\NO_MANAGEMENT.CONFIGURATION_VECTOR_REG_reg[3] ;
  wire [7:0]Q;
  wire R;
  wire RECEIVE;
  wire RECEIVE_i_1_n_0;
  wire RUDI_C0;
  wire RUDI_I0;
  wire RXCHARISK_REG1;
  wire \RXDATA_REG4_reg[0]_srl4_n_0 ;
  wire \RXDATA_REG4_reg[1]_srl4_n_0 ;
  wire \RXDATA_REG4_reg[2]_srl4_n_0 ;
  wire \RXDATA_REG4_reg[3]_srl4_n_0 ;
  wire \RXDATA_REG4_reg[4]_srl4_n_0 ;
  wire \RXDATA_REG4_reg[5]_srl4_n_0 ;
  wire \RXDATA_REG4_reg[6]_srl4_n_0 ;
  wire \RXDATA_REG4_reg[7]_srl4_n_0 ;
  wire [7:0]RXDATA_REG5;
  wire \RXD[0]_i_1_n_0 ;
  wire \RXD[1]_i_1_n_0 ;
  wire \RXD[2]_i_1_n_0 ;
  wire \RXD[3]_i_1_n_0 ;
  wire \RXD[4]_i_1_n_0 ;
  wire \RXD[5]_i_1_n_0 ;
  wire \RXD[6]_i_1_n_0 ;
  wire \RXD[7]_i_1_n_0 ;
  wire RXEVEN;
  wire RXNOTINTABLE_INT;
  wire RX_CONFIG_VALID_INT;
  wire RX_CONFIG_VALID_INT0;
  wire RX_CONFIG_VALID_INT_i_2_n_0;
  wire \RX_CONFIG_VALID_REG_reg_n_0_[0] ;
  wire \RX_CONFIG_VALID_REG_reg_n_0_[3] ;
  wire RX_DATA_ERROR;
  wire RX_DATA_ERROR0;
  wire RX_DATA_ERROR_i_2_n_0;
  wire RX_DATA_ERROR_i_3_n_0;
  wire RX_DV_i_1_n_0;
  wire RX_DV_i_2_n_0;
  wire RX_ER0;
  wire RX_ER_i_2_n_0;
  wire RX_INVALID_i_2_n_0;
  wire R_REG1;
  wire R_i_2_n_0;
  wire R_i_3_n_0;
  wire R_i_4_n_0;
  wire S;
  wire S0;
  wire S2;
  wire SOP;
  wire SOP0;
  wire SOP_REG1;
  wire SOP_REG2;
  wire SOP_REG3;
  wire [0:0]SR;
  wire SYNC_STATUS_REG;
  wire SYNC_STATUS_REG0;
  wire S_i_2_n_0;
  wire T;
  wire T_REG1;
  wire T_REG2;
  wire \USE_ROCKET_IO.NO_1588.RXBUFSTATUS_INT_reg[1] ;
  wire \USE_ROCKET_IO.NO_1588.RXCHARISK_INT_reg ;
  wire [2:0]\USE_ROCKET_IO.NO_1588.RXCLKCORCNT_INT_reg[2] ;
  wire WAIT_FOR_K;
  wire WAIT_FOR_K_i_1_n_0;
  wire gmii_rx_dv;
  wire gmii_rx_er;
  wire [7:0]gmii_rxd;
  wire p_0_in1_in;
  wire p_0_in2_in;
  wire p_1_in;
  wire p_40_in;
  wire [2:0]status_vector;
  wire userclk2;

  FDRE CGBAD_REG1_reg
       (.C(userclk2),
        .CE(1'b1),
        .D(CGBAD),
        .Q(CGBAD_REG1),
        .R(1'b0));
  FDRE CGBAD_REG2_reg
       (.C(userclk2),
        .CE(1'b1),
        .D(CGBAD_REG1),
        .Q(CGBAD_REG2),
        .R(1'b0));
  FDRE CGBAD_REG3_reg
       (.C(userclk2),
        .CE(1'b1),
        .D(CGBAD_REG2),
        .Q(CGBAD_REG3),
        .R(SR));
  LUT3 #(
    .INIT(8'hFE)) 
    CGBAD_i_1
       (.I0(RXNOTINTABLE_INT),
        .I1(\USE_ROCKET_IO.NO_1588.RXBUFSTATUS_INT_reg[1] ),
        .I2(D),
        .O(S2));
  FDRE CGBAD_reg
       (.C(userclk2),
        .CE(1'b1),
        .D(S2),
        .Q(CGBAD),
        .R(SR));
  LUT4 #(
    .INIT(16'h0400)) 
    C_HDR_REMOVED_REG_i_1
       (.I0(\USE_ROCKET_IO.NO_1588.RXCLKCORCNT_INT_reg[2] [1]),
        .I1(\USE_ROCKET_IO.NO_1588.RXCLKCORCNT_INT_reg[2] [0]),
        .I2(\USE_ROCKET_IO.NO_1588.RXCLKCORCNT_INT_reg[2] [2]),
        .I3(C_REG2),
        .O(C_HDR_REMOVED));
  FDRE C_HDR_REMOVED_REG_reg
       (.C(userclk2),
        .CE(1'b1),
        .D(C_HDR_REMOVED),
        .Q(C_HDR_REMOVED_REG),
        .R(1'b0));
  FDRE C_REG1_reg
       (.C(userclk2),
        .CE(1'b1),
        .D(C),
        .Q(C_REG1),
        .R(1'b0));
  FDRE C_REG2_reg
       (.C(userclk2),
        .CE(1'b1),
        .D(C_REG1),
        .Q(C_REG2),
        .R(1'b0));
  FDRE C_REG3_reg
       (.C(userclk2),
        .CE(1'b1),
        .D(C_REG2),
        .Q(C_REG3),
        .R(1'b0));
  LUT2 #(
    .INIT(4'h8)) 
    C_i_1
       (.I0(I335_in),
        .I1(K28p5_REG1),
        .O(C0));
  FDRE C_reg
       (.C(userclk2),
        .CE(1'b1),
        .D(C0),
        .Q(C),
        .R(1'b0));
  (* SOFT_HLUTNM = "soft_lutpair1" *) 
  LUT5 #(
    .INIT(32'h00010000)) 
    D0p0_REG_i_1
       (.I0(Q[0]),
        .I1(Q[1]),
        .I2(Q[6]),
        .I3(Q[7]),
        .I4(D0p0_REG_i_2_n_0),
        .O(D0p0));
  (* SOFT_HLUTNM = "soft_lutpair3" *) 
  LUT5 #(
    .INIT(32'h00000001)) 
    D0p0_REG_i_2
       (.I0(Q[5]),
        .I1(Q[2]),
        .I2(Q[4]),
        .I3(Q[3]),
        .I4(\USE_ROCKET_IO.NO_1588.RXCHARISK_INT_reg ),
        .O(D0p0_REG_i_2_n_0));
  FDRE D0p0_REG_reg
       (.C(userclk2),
        .CE(1'b1),
        .D(D0p0),
        .Q(D0p0_REG),
        .R(1'b0));
  LUT3 #(
    .INIT(8'hF8)) 
    EOP_REG1_i_1
       (.I0(EXTEND_REG1),
        .I1(EXTEND),
        .I2(EOP),
        .O(EOP_REG10));
  FDRE EOP_REG1_reg
       (.C(userclk2),
        .CE(1'b1),
        .D(EOP_REG10),
        .Q(EOP_REG1),
        .R(SR));
  LUT6 #(
    .INIT(64'hFFFFFFFFF8888888)) 
    EOP_i_1
       (.I0(I_REG_reg_n_0),
        .I1(K28p5_REG1),
        .I2(RXEVEN),
        .I3(C_REG1),
        .I4(D0p0_REG),
        .I5(EOP_i_2_n_0),
        .O(EOP0));
  LUT5 #(
    .INIT(32'h88888000)) 
    EOP_i_2
       (.I0(T_REG2),
        .I1(R_REG1),
        .I2(K28p5_REG1),
        .I3(RXEVEN),
        .I4(R),
        .O(EOP_i_2_n_0));
  FDRE EOP_reg
       (.C(userclk2),
        .CE(1'b1),
        .D(EOP0),
        .Q(EOP),
        .R(SR));
  LUT3 #(
    .INIT(8'hF8)) 
    EXTEND_ERR_i_1
       (.I0(EXTEND_REG3),
        .I1(CGBAD_REG3),
        .I2(EXT_ILLEGAL_K_REG2),
        .O(EXTEND_ERR0));
  FDRE EXTEND_ERR_reg
       (.C(userclk2),
        .CE(1'b1),
        .D(EXTEND_ERR0),
        .Q(EXTEND_ERR),
        .R(SYNC_STATUS_REG0));
  FDRE EXTEND_REG1_reg
       (.C(userclk2),
        .CE(1'b1),
        .D(EXTEND),
        .Q(EXTEND_REG1),
        .R(1'b0));
  FDRE EXTEND_REG2_reg
       (.C(userclk2),
        .CE(1'b1),
        .D(EXTEND_REG1),
        .Q(EXTEND_REG2),
        .R(1'b0));
  FDRE EXTEND_REG3_reg
       (.C(userclk2),
        .CE(1'b1),
        .D(EXTEND_REG2),
        .Q(EXTEND_REG3),
        .R(1'b0));
  LUT6 #(
    .INIT(64'hF2222222F0000000)) 
    EXTEND_i_1
       (.I0(FROM_RX_CX_i_2_n_0),
        .I1(S),
        .I2(R),
        .I3(RECEIVE),
        .I4(R_REG1),
        .I5(EXTEND),
        .O(EXTEND_i_1_n_0));
  FDRE EXTEND_reg
       (.C(userclk2),
        .CE(1'b1),
        .D(EXTEND_i_1_n_0),
        .Q(EXTEND),
        .R(SYNC_STATUS_REG0));
  FDRE EXT_ILLEGAL_K_REG1_reg
       (.C(userclk2),
        .CE(1'b1),
        .D(EXT_ILLEGAL_K),
        .Q(EXT_ILLEGAL_K_REG1),
        .R(SYNC_STATUS_REG0));
  FDRE EXT_ILLEGAL_K_REG2_reg
       (.C(userclk2),
        .CE(1'b1),
        .D(EXT_ILLEGAL_K_REG1),
        .Q(EXT_ILLEGAL_K_REG2),
        .R(SYNC_STATUS_REG0));
  (* SOFT_HLUTNM = "soft_lutpair2" *) 
  LUT5 #(
    .INIT(32'h00000444)) 
    EXT_ILLEGAL_K_i_1
       (.I0(S),
        .I1(EXTEND_REG1),
        .I2(K28p5_REG1),
        .I3(RXEVEN),
        .I4(R),
        .O(EXT_ILLEGAL_K0));
  FDRE EXT_ILLEGAL_K_reg
       (.C(userclk2),
        .CE(1'b1),
        .D(EXT_ILLEGAL_K0),
        .Q(EXT_ILLEGAL_K),
        .R(SYNC_STATUS_REG0));
  FDRE FALSE_CARRIER_REG1_reg
       (.C(userclk2),
        .CE(1'b1),
        .D(FALSE_CARRIER),
        .Q(FALSE_CARRIER_REG1),
        .R(1'b0));
  FDRE FALSE_CARRIER_REG2_reg
       (.C(userclk2),
        .CE(1'b1),
        .D(FALSE_CARRIER_REG1),
        .Q(FALSE_CARRIER_REG2),
        .R(1'b0));
  FDRE FALSE_CARRIER_REG3_reg
       (.C(userclk2),
        .CE(1'b1),
        .D(FALSE_CARRIER_REG2),
        .Q(FALSE_CARRIER_REG3),
        .R(SYNC_STATUS_REG0));
  LUT6 #(
    .INIT(64'h22EFEFEF22202020)) 
    FALSE_CARRIER_i_1
       (.I0(FALSE_CARRIER_i_2_n_0),
        .I1(FALSE_CARRIER_i_3_n_0),
        .I2(FALSE_CARRIER_i_4_n_0),
        .I3(RXEVEN),
        .I4(K28p5_REG1),
        .I5(FALSE_CARRIER),
        .O(FALSE_CARRIER_i_1_n_0));
  (* SOFT_HLUTNM = "soft_lutpair6" *) 
  LUT4 #(
    .INIT(16'h0008)) 
    FALSE_CARRIER_i_2
       (.I0(p_40_in),
        .I1(I_REG_reg_n_0),
        .I2(K28p5_REG1),
        .I3(S),
        .O(FALSE_CARRIER_i_2_n_0));
  LUT3 #(
    .INIT(8'hFE)) 
    FALSE_CARRIER_i_3
       (.I0(FALSE_NIT),
        .I1(FALSE_DATA),
        .I2(FALSE_K),
        .O(FALSE_CARRIER_i_3_n_0));
  (* SOFT_HLUTNM = "soft_lutpair6" *) 
  LUT4 #(
    .INIT(16'h0008)) 
    FALSE_CARRIER_i_4
       (.I0(p_40_in),
        .I1(I_REG_reg_n_0),
        .I2(K28p5_REG1),
        .I3(S),
        .O(FALSE_CARRIER_i_4_n_0));
  FDRE FALSE_CARRIER_reg
       (.C(userclk2),
        .CE(1'b1),
        .D(FALSE_CARRIER_i_1_n_0),
        .Q(FALSE_CARRIER),
        .R(SYNC_STATUS_REG0));
  (* SOFT_HLUTNM = "soft_lutpair4" *) 
  LUT5 #(
    .INIT(32'hABBFAAAA)) 
    FALSE_DATA_i_1
       (.I0(FALSE_DATA_i_2_n_0),
        .I1(Q[3]),
        .I2(Q[2]),
        .I3(Q[4]),
        .I4(FALSE_DATA_i_3_n_0),
        .O(FALSE_DATA0));
  (* SOFT_HLUTNM = "soft_lutpair0" *) 
  LUT5 #(
    .INIT(32'h00080000)) 
    FALSE_DATA_i_2
       (.I0(Q[5]),
        .I1(Q[7]),
        .I2(RXNOTINTABLE_INT),
        .I3(Q[6]),
        .I4(FALSE_DATA_i_4_n_0),
        .O(FALSE_DATA_i_2_n_0));
  LUT6 #(
    .INIT(64'h0000000000100000)) 
    FALSE_DATA_i_3
       (.I0(Q[7]),
        .I1(\USE_ROCKET_IO.NO_1588.RXCHARISK_INT_reg ),
        .I2(R_i_2_n_0),
        .I3(RXNOTINTABLE_INT),
        .I4(Q[6]),
        .I5(Q[5]),
        .O(FALSE_DATA_i_3_n_0));
  LUT6 #(
    .INIT(64'h00000000040000C8)) 
    FALSE_DATA_i_4
       (.I0(Q[3]),
        .I1(Q[2]),
        .I2(Q[4]),
        .I3(Q[1]),
        .I4(Q[0]),
        .I5(\USE_ROCKET_IO.NO_1588.RXCHARISK_INT_reg ),
        .O(FALSE_DATA_i_4_n_0));
  FDRE FALSE_DATA_reg
       (.C(userclk2),
        .CE(1'b1),
        .D(FALSE_DATA0),
        .Q(FALSE_DATA),
        .R(SR));
  LUT6 #(
    .INIT(64'h0800000000000800)) 
    FALSE_K_i_1
       (.I0(FALSE_K_i_2_n_0),
        .I1(FALSE_K_i_3_n_0),
        .I2(RXNOTINTABLE_INT),
        .I3(Q[7]),
        .I4(Q[5]),
        .I5(Q[6]),
        .O(FALSE_K0));
  (* SOFT_HLUTNM = "soft_lutpair3" *) 
  LUT4 #(
    .INIT(16'h8000)) 
    FALSE_K_i_2
       (.I0(\USE_ROCKET_IO.NO_1588.RXCHARISK_INT_reg ),
        .I1(Q[3]),
        .I2(Q[2]),
        .I3(Q[4]),
        .O(FALSE_K_i_2_n_0));
  (* SOFT_HLUTNM = "soft_lutpair11" *) 
  LUT2 #(
    .INIT(4'h1)) 
    FALSE_K_i_3
       (.I0(Q[0]),
        .I1(Q[1]),
        .O(FALSE_K_i_3_n_0));
  FDRE FALSE_K_reg
       (.C(userclk2),
        .CE(1'b1),
        .D(FALSE_K0),
        .Q(FALSE_K),
        .R(SR));
  LUT6 #(
    .INIT(64'hFFFF280028002800)) 
    FALSE_NIT_i_1
       (.I0(FALSE_NIT_i_2_n_0),
        .I1(D),
        .I2(Q[7]),
        .I3(RXNOTINTABLE_INT),
        .I4(FALSE_NIT_i_3_n_0),
        .I5(FALSE_NIT_i_4_n_0),
        .O(FALSE_NIT0));
  LUT6 #(
    .INIT(64'h00000088F0000000)) 
    FALSE_NIT_i_2
       (.I0(FALSE_K_i_2_n_0),
        .I1(Q[5]),
        .I2(D0p0_REG_i_2_n_0),
        .I3(Q[1]),
        .I4(Q[0]),
        .I5(Q[6]),
        .O(FALSE_NIT_i_2_n_0));
  LUT6 #(
    .INIT(64'h00F0000000008800)) 
    FALSE_NIT_i_3
       (.I0(FALSE_K_i_2_n_0),
        .I1(Q[5]),
        .I2(D0p0_REG_i_2_n_0),
        .I3(Q[6]),
        .I4(Q[7]),
        .I5(D),
        .O(FALSE_NIT_i_3_n_0));
  (* SOFT_HLUTNM = "soft_lutpair11" *) 
  LUT3 #(
    .INIT(8'h60)) 
    FALSE_NIT_i_4
       (.I0(Q[1]),
        .I1(Q[0]),
        .I2(RXNOTINTABLE_INT),
        .O(FALSE_NIT_i_4_n_0));
  FDRE FALSE_NIT_reg
       (.C(userclk2),
        .CE(1'b1),
        .D(FALSE_NIT0),
        .Q(FALSE_NIT),
        .R(SR));
  LUT4 #(
    .INIT(16'h0004)) 
    FROM_IDLE_D_i_1
       (.I0(p_40_in),
        .I1(I_REG_reg_n_0),
        .I2(K28p5_REG1),
        .I3(WAIT_FOR_K),
        .O(FROM_IDLE_D0));
  FDRE FROM_IDLE_D_reg
       (.C(userclk2),
        .CE(1'b1),
        .D(FROM_IDLE_D0),
        .Q(FROM_IDLE_D),
        .R(SYNC_STATUS_REG0));
  LUT6 #(
    .INIT(64'hFFECFFECFFECA8A8)) 
    FROM_RX_CX_i_1
       (.I0(C_REG3),
        .I1(CGBAD),
        .I2(FROM_RX_CX_i_2_n_0),
        .I3(RXCHARISK_REG1),
        .I4(C_REG2),
        .I5(C_REG1),
        .O(FROM_RX_CX0));
  (* SOFT_HLUTNM = "soft_lutpair2" *) 
  LUT2 #(
    .INIT(4'h7)) 
    FROM_RX_CX_i_2
       (.I0(K28p5_REG1),
        .I1(RXEVEN),
        .O(FROM_RX_CX_i_2_n_0));
  FDRE FROM_RX_CX_reg
       (.C(userclk2),
        .CE(1'b1),
        .D(FROM_RX_CX0),
        .Q(FROM_RX_CX),
        .R(SYNC_STATUS_REG0));
  (* SOFT_HLUTNM = "soft_lutpair10" *) 
  LUT4 #(
    .INIT(16'h4440)) 
    FROM_RX_K_i_1
       (.I0(p_40_in),
        .I1(K28p5_REG2),
        .I2(RXCHARISK_REG1),
        .I3(CGBAD),
        .O(FROM_RX_K0));
  FDRE FROM_RX_K_reg
       (.C(userclk2),
        .CE(1'b1),
        .D(FROM_RX_K0),
        .Q(FROM_RX_K),
        .R(SYNC_STATUS_REG0));
  FDRE \IDLE_REG_reg[0] 
       (.C(userclk2),
        .CE(1'b1),
        .D(I_REG_reg_n_0),
        .Q(\IDLE_REG_reg_n_0_[0] ),
        .R(SR));
  FDRE \IDLE_REG_reg[1] 
       (.C(userclk2),
        .CE(1'b1),
        .D(\IDLE_REG_reg_n_0_[0] ),
        .Q(p_0_in1_in),
        .R(SR));
  FDRE \IDLE_REG_reg[2] 
       (.C(userclk2),
        .CE(1'b1),
        .D(p_0_in1_in),
        .Q(\IDLE_REG_reg_n_0_[2] ),
        .R(SR));
  FDRE ILLEGAL_K_REG1_reg
       (.C(userclk2),
        .CE(1'b1),
        .D(ILLEGAL_K),
        .Q(ILLEGAL_K_REG1),
        .R(SYNC_STATUS_REG0));
  FDRE ILLEGAL_K_REG2_reg
       (.C(userclk2),
        .CE(1'b1),
        .D(ILLEGAL_K_REG1),
        .Q(ILLEGAL_K_REG2),
        .R(SYNC_STATUS_REG0));
  LUT4 #(
    .INIT(16'h0100)) 
    ILLEGAL_K_i_1
       (.I0(R),
        .I1(T),
        .I2(K28p5_REG1),
        .I3(RXCHARISK_REG1),
        .O(ILLEGAL_K0));
  FDRE ILLEGAL_K_reg
       (.C(userclk2),
        .CE(1'b1),
        .D(ILLEGAL_K0),
        .Q(ILLEGAL_K),
        .R(SYNC_STATUS_REG0));
  FDRE I_REG_reg
       (.C(userclk2),
        .CE(1'b1),
        .D(I),
        .Q(I_REG_reg_n_0),
        .R(1'b0));
  LUT6 #(
    .INIT(64'h3323222222222222)) 
    I_i_1
       (.I0(I_i_2_n_0),
        .I1(I335_in),
        .I2(\USE_ROCKET_IO.NO_1588.RXCHARISK_INT_reg ),
        .I3(p_40_in),
        .I4(RXEVEN),
        .I5(K28p5_REG1),
        .O(I0));
  LUT6 #(
    .INIT(64'h8080808080808000)) 
    I_i_2
       (.I0(I_REG_reg_n_0),
        .I1(p_40_in),
        .I2(RXEVEN),
        .I3(FALSE_K),
        .I4(FALSE_DATA),
        .I5(FALSE_NIT),
        .O(I_i_2_n_0));
  LUT6 #(
    .INIT(64'h00000C0000A000A0)) 
    I_i_3
       (.I0(I_i_4_n_0),
        .I1(D0p0_REG_i_2_n_0),
        .I2(Q[0]),
        .I3(Q[1]),
        .I4(Q[7]),
        .I5(Q[6]),
        .O(I335_in));
  LUT6 #(
    .INIT(64'h0000000000008000)) 
    I_i_4
       (.I0(Q[4]),
        .I1(Q[2]),
        .I2(Q[5]),
        .I3(Q[7]),
        .I4(\USE_ROCKET_IO.NO_1588.RXCHARISK_INT_reg ),
        .I5(Q[3]),
        .O(I_i_4_n_0));
  FDRE I_reg
       (.C(userclk2),
        .CE(1'b1),
        .D(I0),
        .Q(I),
        .R(1'b0));
  LUT6 #(
    .INIT(64'h0000100000000000)) 
    K28p5_REG1_i_1
       (.I0(Q[0]),
        .I1(Q[1]),
        .I2(Q[7]),
        .I3(Q[5]),
        .I4(Q[6]),
        .I5(FALSE_K_i_2_n_0),
        .O(K28p5));
  FDRE K28p5_REG1_reg
       (.C(userclk2),
        .CE(1'b1),
        .D(K28p5),
        .Q(K28p5_REG1),
        .R(1'b0));
  FDRE K28p5_REG2_reg
       (.C(userclk2),
        .CE(1'b1),
        .D(K28p5_REG1),
        .Q(K28p5_REG2),
        .R(1'b0));
  LUT3 #(
    .INIT(8'hBA)) 
    RECEIVE_i_1
       (.I0(SOP_REG2),
        .I1(EOP),
        .I2(RECEIVE),
        .O(RECEIVE_i_1_n_0));
  FDRE RECEIVE_reg
       (.C(userclk2),
        .CE(1'b1),
        .D(RECEIVE_i_1_n_0),
        .Q(RECEIVE),
        .R(SYNC_STATUS_REG0));
  LUT4 #(
    .INIT(16'hFFFE)) 
    RUDI_C_i_1
       (.I0(p_1_in),
        .I1(\RX_CONFIG_VALID_REG_reg_n_0_[0] ),
        .I2(\RX_CONFIG_VALID_REG_reg_n_0_[3] ),
        .I3(p_0_in2_in),
        .O(RUDI_C0));
  FDRE RUDI_C_reg
       (.C(userclk2),
        .CE(1'b1),
        .D(RUDI_C0),
        .Q(status_vector[0]),
        .R(SR));
  LUT2 #(
    .INIT(4'hE)) 
    RUDI_I_i_1
       (.I0(\IDLE_REG_reg_n_0_[2] ),
        .I1(p_0_in1_in),
        .O(RUDI_I0));
  FDRE RUDI_I_reg
       (.C(userclk2),
        .CE(1'b1),
        .D(RUDI_I0),
        .Q(status_vector[1]),
        .R(SR));
  FDRE RXCHARISK_REG1_reg
       (.C(userclk2),
        .CE(1'b1),
        .D(\USE_ROCKET_IO.NO_1588.RXCHARISK_INT_reg ),
        .Q(RXCHARISK_REG1),
        .R(1'b0));
  (* srl_bus_name = "\U0/GigEthGth7Core_core /\gpcs_pma_inst/RECEIVER/RXDATA_REG4_reg " *) 
  (* srl_name = "\U0/GigEthGth7Core_core /\gpcs_pma_inst/RECEIVER/RXDATA_REG4_reg[0]_srl4 " *) 
  SRL16E \RXDATA_REG4_reg[0]_srl4 
       (.A0(1'b1),
        .A1(1'b1),
        .A2(1'b0),
        .A3(1'b0),
        .CE(1'b1),
        .CLK(userclk2),
        .D(Q[0]),
        .Q(\RXDATA_REG4_reg[0]_srl4_n_0 ));
  (* srl_bus_name = "\U0/GigEthGth7Core_core /\gpcs_pma_inst/RECEIVER/RXDATA_REG4_reg " *) 
  (* srl_name = "\U0/GigEthGth7Core_core /\gpcs_pma_inst/RECEIVER/RXDATA_REG4_reg[1]_srl4 " *) 
  SRL16E \RXDATA_REG4_reg[1]_srl4 
       (.A0(1'b1),
        .A1(1'b1),
        .A2(1'b0),
        .A3(1'b0),
        .CE(1'b1),
        .CLK(userclk2),
        .D(Q[1]),
        .Q(\RXDATA_REG4_reg[1]_srl4_n_0 ));
  (* srl_bus_name = "\U0/GigEthGth7Core_core /\gpcs_pma_inst/RECEIVER/RXDATA_REG4_reg " *) 
  (* srl_name = "\U0/GigEthGth7Core_core /\gpcs_pma_inst/RECEIVER/RXDATA_REG4_reg[2]_srl4 " *) 
  SRL16E \RXDATA_REG4_reg[2]_srl4 
       (.A0(1'b1),
        .A1(1'b1),
        .A2(1'b0),
        .A3(1'b0),
        .CE(1'b1),
        .CLK(userclk2),
        .D(Q[2]),
        .Q(\RXDATA_REG4_reg[2]_srl4_n_0 ));
  (* srl_bus_name = "\U0/GigEthGth7Core_core /\gpcs_pma_inst/RECEIVER/RXDATA_REG4_reg " *) 
  (* srl_name = "\U0/GigEthGth7Core_core /\gpcs_pma_inst/RECEIVER/RXDATA_REG4_reg[3]_srl4 " *) 
  SRL16E \RXDATA_REG4_reg[3]_srl4 
       (.A0(1'b1),
        .A1(1'b1),
        .A2(1'b0),
        .A3(1'b0),
        .CE(1'b1),
        .CLK(userclk2),
        .D(Q[3]),
        .Q(\RXDATA_REG4_reg[3]_srl4_n_0 ));
  (* srl_bus_name = "\U0/GigEthGth7Core_core /\gpcs_pma_inst/RECEIVER/RXDATA_REG4_reg " *) 
  (* srl_name = "\U0/GigEthGth7Core_core /\gpcs_pma_inst/RECEIVER/RXDATA_REG4_reg[4]_srl4 " *) 
  SRL16E \RXDATA_REG4_reg[4]_srl4 
       (.A0(1'b1),
        .A1(1'b1),
        .A2(1'b0),
        .A3(1'b0),
        .CE(1'b1),
        .CLK(userclk2),
        .D(Q[4]),
        .Q(\RXDATA_REG4_reg[4]_srl4_n_0 ));
  (* srl_bus_name = "\U0/GigEthGth7Core_core /\gpcs_pma_inst/RECEIVER/RXDATA_REG4_reg " *) 
  (* srl_name = "\U0/GigEthGth7Core_core /\gpcs_pma_inst/RECEIVER/RXDATA_REG4_reg[5]_srl4 " *) 
  SRL16E \RXDATA_REG4_reg[5]_srl4 
       (.A0(1'b1),
        .A1(1'b1),
        .A2(1'b0),
        .A3(1'b0),
        .CE(1'b1),
        .CLK(userclk2),
        .D(Q[5]),
        .Q(\RXDATA_REG4_reg[5]_srl4_n_0 ));
  (* srl_bus_name = "\U0/GigEthGth7Core_core /\gpcs_pma_inst/RECEIVER/RXDATA_REG4_reg " *) 
  (* srl_name = "\U0/GigEthGth7Core_core /\gpcs_pma_inst/RECEIVER/RXDATA_REG4_reg[6]_srl4 " *) 
  SRL16E \RXDATA_REG4_reg[6]_srl4 
       (.A0(1'b1),
        .A1(1'b1),
        .A2(1'b0),
        .A3(1'b0),
        .CE(1'b1),
        .CLK(userclk2),
        .D(Q[6]),
        .Q(\RXDATA_REG4_reg[6]_srl4_n_0 ));
  (* srl_bus_name = "\U0/GigEthGth7Core_core /\gpcs_pma_inst/RECEIVER/RXDATA_REG4_reg " *) 
  (* srl_name = "\U0/GigEthGth7Core_core /\gpcs_pma_inst/RECEIVER/RXDATA_REG4_reg[7]_srl4 " *) 
  SRL16E \RXDATA_REG4_reg[7]_srl4 
       (.A0(1'b1),
        .A1(1'b1),
        .A2(1'b0),
        .A3(1'b0),
        .CE(1'b1),
        .CLK(userclk2),
        .D(Q[7]),
        .Q(\RXDATA_REG4_reg[7]_srl4_n_0 ));
  FDRE \RXDATA_REG5_reg[0] 
       (.C(userclk2),
        .CE(1'b1),
        .D(\RXDATA_REG4_reg[0]_srl4_n_0 ),
        .Q(RXDATA_REG5[0]),
        .R(1'b0));
  FDRE \RXDATA_REG5_reg[1] 
       (.C(userclk2),
        .CE(1'b1),
        .D(\RXDATA_REG4_reg[1]_srl4_n_0 ),
        .Q(RXDATA_REG5[1]),
        .R(1'b0));
  FDRE \RXDATA_REG5_reg[2] 
       (.C(userclk2),
        .CE(1'b1),
        .D(\RXDATA_REG4_reg[2]_srl4_n_0 ),
        .Q(RXDATA_REG5[2]),
        .R(1'b0));
  FDRE \RXDATA_REG5_reg[3] 
       (.C(userclk2),
        .CE(1'b1),
        .D(\RXDATA_REG4_reg[3]_srl4_n_0 ),
        .Q(RXDATA_REG5[3]),
        .R(1'b0));
  FDRE \RXDATA_REG5_reg[4] 
       (.C(userclk2),
        .CE(1'b1),
        .D(\RXDATA_REG4_reg[4]_srl4_n_0 ),
        .Q(RXDATA_REG5[4]),
        .R(1'b0));
  FDRE \RXDATA_REG5_reg[5] 
       (.C(userclk2),
        .CE(1'b1),
        .D(\RXDATA_REG4_reg[5]_srl4_n_0 ),
        .Q(RXDATA_REG5[5]),
        .R(1'b0));
  FDRE \RXDATA_REG5_reg[6] 
       (.C(userclk2),
        .CE(1'b1),
        .D(\RXDATA_REG4_reg[6]_srl4_n_0 ),
        .Q(RXDATA_REG5[6]),
        .R(1'b0));
  FDRE \RXDATA_REG5_reg[7] 
       (.C(userclk2),
        .CE(1'b1),
        .D(\RXDATA_REG4_reg[7]_srl4_n_0 ),
        .Q(RXDATA_REG5[7]),
        .R(1'b0));
  LUT4 #(
    .INIT(16'hAFAE)) 
    \RXD[0]_i_1 
       (.I0(SOP_REG3),
        .I1(EXTEND_REG1),
        .I2(FALSE_CARRIER_REG3),
        .I3(RXDATA_REG5[0]),
        .O(\RXD[0]_i_1_n_0 ));
  (* SOFT_HLUTNM = "soft_lutpair7" *) 
  LUT4 #(
    .INIT(16'h0F0E)) 
    \RXD[1]_i_1 
       (.I0(EXTEND_REG1),
        .I1(FALSE_CARRIER_REG3),
        .I2(SOP_REG3),
        .I3(RXDATA_REG5[1]),
        .O(\RXD[1]_i_1_n_0 ));
  (* SOFT_HLUTNM = "soft_lutpair8" *) 
  LUT4 #(
    .INIT(16'hFFFE)) 
    \RXD[2]_i_1 
       (.I0(SOP_REG3),
        .I1(EXTEND_REG1),
        .I2(FALSE_CARRIER_REG3),
        .I3(RXDATA_REG5[2]),
        .O(\RXD[2]_i_1_n_0 ));
  (* SOFT_HLUTNM = "soft_lutpair7" *) 
  LUT4 #(
    .INIT(16'h0F0E)) 
    \RXD[3]_i_1 
       (.I0(EXTEND_REG1),
        .I1(FALSE_CARRIER_REG3),
        .I2(SOP_REG3),
        .I3(RXDATA_REG5[3]),
        .O(\RXD[3]_i_1_n_0 ));
  (* SOFT_HLUTNM = "soft_lutpair5" *) 
  LUT5 #(
    .INIT(32'hAAAAFAEE)) 
    \RXD[4]_i_1 
       (.I0(SOP_REG3),
        .I1(RXDATA_REG5[4]),
        .I2(EXTEND_ERR),
        .I3(EXTEND_REG1),
        .I4(FALSE_CARRIER_REG3),
        .O(\RXD[4]_i_1_n_0 ));
  (* SOFT_HLUTNM = "soft_lutpair9" *) 
  LUT4 #(
    .INIT(16'h0002)) 
    \RXD[5]_i_1 
       (.I0(RXDATA_REG5[5]),
        .I1(SOP_REG3),
        .I2(EXTEND_REG1),
        .I3(FALSE_CARRIER_REG3),
        .O(\RXD[5]_i_1_n_0 ));
  (* SOFT_HLUTNM = "soft_lutpair8" *) 
  LUT4 #(
    .INIT(16'hFF10)) 
    \RXD[6]_i_1 
       (.I0(EXTEND_REG1),
        .I1(FALSE_CARRIER_REG3),
        .I2(RXDATA_REG5[6]),
        .I3(SOP_REG3),
        .O(\RXD[6]_i_1_n_0 ));
  (* SOFT_HLUTNM = "soft_lutpair9" *) 
  LUT4 #(
    .INIT(16'h0002)) 
    \RXD[7]_i_1 
       (.I0(RXDATA_REG5[7]),
        .I1(SOP_REG3),
        .I2(EXTEND_REG1),
        .I3(FALSE_CARRIER_REG3),
        .O(\RXD[7]_i_1_n_0 ));
  FDRE \RXD_reg[0] 
       (.C(userclk2),
        .CE(1'b1),
        .D(\RXD[0]_i_1_n_0 ),
        .Q(gmii_rxd[0]),
        .R(\NO_MANAGEMENT.CONFIGURATION_VECTOR_REG_reg[3] ));
  FDRE \RXD_reg[1] 
       (.C(userclk2),
        .CE(1'b1),
        .D(\RXD[1]_i_1_n_0 ),
        .Q(gmii_rxd[1]),
        .R(\NO_MANAGEMENT.CONFIGURATION_VECTOR_REG_reg[3] ));
  FDRE \RXD_reg[2] 
       (.C(userclk2),
        .CE(1'b1),
        .D(\RXD[2]_i_1_n_0 ),
        .Q(gmii_rxd[2]),
        .R(\NO_MANAGEMENT.CONFIGURATION_VECTOR_REG_reg[3] ));
  FDRE \RXD_reg[3] 
       (.C(userclk2),
        .CE(1'b1),
        .D(\RXD[3]_i_1_n_0 ),
        .Q(gmii_rxd[3]),
        .R(\NO_MANAGEMENT.CONFIGURATION_VECTOR_REG_reg[3] ));
  FDRE \RXD_reg[4] 
       (.C(userclk2),
        .CE(1'b1),
        .D(\RXD[4]_i_1_n_0 ),
        .Q(gmii_rxd[4]),
        .R(\NO_MANAGEMENT.CONFIGURATION_VECTOR_REG_reg[3] ));
  FDRE \RXD_reg[5] 
       (.C(userclk2),
        .CE(1'b1),
        .D(\RXD[5]_i_1_n_0 ),
        .Q(gmii_rxd[5]),
        .R(\NO_MANAGEMENT.CONFIGURATION_VECTOR_REG_reg[3] ));
  FDRE \RXD_reg[6] 
       (.C(userclk2),
        .CE(1'b1),
        .D(\RXD[6]_i_1_n_0 ),
        .Q(gmii_rxd[6]),
        .R(\NO_MANAGEMENT.CONFIGURATION_VECTOR_REG_reg[3] ));
  FDRE \RXD_reg[7] 
       (.C(userclk2),
        .CE(1'b1),
        .D(\RXD[7]_i_1_n_0 ),
        .Q(gmii_rxd[7]),
        .R(\NO_MANAGEMENT.CONFIGURATION_VECTOR_REG_reg[3] ));
  LUT6 #(
    .INIT(64'h0000000000000E00)) 
    RX_CONFIG_VALID_INT_i_1
       (.I0(C_HDR_REMOVED_REG),
        .I1(C_REG1),
        .I2(\USE_ROCKET_IO.NO_1588.RXCHARISK_INT_reg ),
        .I3(p_40_in),
        .I4(RX_CONFIG_VALID_INT_i_2_n_0),
        .I5(S2),
        .O(RX_CONFIG_VALID_INT0));
  (* SOFT_HLUTNM = "soft_lutpair10" *) 
  LUT2 #(
    .INIT(4'hE)) 
    RX_CONFIG_VALID_INT_i_2
       (.I0(CGBAD),
        .I1(RXCHARISK_REG1),
        .O(RX_CONFIG_VALID_INT_i_2_n_0));
  FDRE RX_CONFIG_VALID_INT_reg
       (.C(userclk2),
        .CE(1'b1),
        .D(RX_CONFIG_VALID_INT0),
        .Q(RX_CONFIG_VALID_INT),
        .R(SR));
  FDRE \RX_CONFIG_VALID_REG_reg[0] 
       (.C(userclk2),
        .CE(1'b1),
        .D(RX_CONFIG_VALID_INT),
        .Q(\RX_CONFIG_VALID_REG_reg_n_0_[0] ),
        .R(SR));
  FDRE \RX_CONFIG_VALID_REG_reg[1] 
       (.C(userclk2),
        .CE(1'b1),
        .D(\RX_CONFIG_VALID_REG_reg_n_0_[0] ),
        .Q(p_0_in2_in),
        .R(SR));
  FDRE \RX_CONFIG_VALID_REG_reg[2] 
       (.C(userclk2),
        .CE(1'b1),
        .D(p_0_in2_in),
        .Q(p_1_in),
        .R(SR));
  FDRE \RX_CONFIG_VALID_REG_reg[3] 
       (.C(userclk2),
        .CE(1'b1),
        .D(p_1_in),
        .Q(\RX_CONFIG_VALID_REG_reg_n_0_[3] ),
        .R(SR));
  LUT6 #(
    .INIT(64'hFF00FF00FF00BA00)) 
    RX_DATA_ERROR_i_1
       (.I0(RX_DATA_ERROR_i_2_n_0),
        .I1(T_REG1),
        .I2(R),
        .I3(RX_DATA_ERROR_i_3_n_0),
        .I4(T_REG2),
        .I5(K28p5_REG1),
        .O(RX_DATA_ERROR0));
  LUT4 #(
    .INIT(16'hFFFE)) 
    RX_DATA_ERROR_i_2
       (.I0(CGBAD_REG3),
        .I1(ILLEGAL_K_REG2),
        .I2(I_REG_reg_n_0),
        .I3(C_REG1),
        .O(RX_DATA_ERROR_i_2_n_0));
  LUT6 #(
    .INIT(64'hFF08FFFF00000000)) 
    RX_DATA_ERROR_i_3
       (.I0(T_REG2),
        .I1(FROM_RX_CX_i_2_n_0),
        .I2(R),
        .I3(RX_DATA_ERROR_i_2_n_0),
        .I4(R_REG1),
        .I5(RECEIVE),
        .O(RX_DATA_ERROR_i_3_n_0));
  FDRE RX_DATA_ERROR_reg
       (.C(userclk2),
        .CE(1'b1),
        .D(RX_DATA_ERROR0),
        .Q(RX_DATA_ERROR),
        .R(SYNC_STATUS_REG0));
  LUT6 #(
    .INIT(64'h88FF00F088880000)) 
    RX_DV_i_1
       (.I0(RX_DV_i_2_n_0),
        .I1(SOP_REG3),
        .I2(RECEIVE),
        .I3(EOP_REG1),
        .I4(p_40_in),
        .I5(gmii_rx_dv),
        .O(RX_DV_i_1_n_0));
  LUT2 #(
    .INIT(4'h1)) 
    RX_DV_i_2
       (.I0(\NO_MANAGEMENT.CONFIGURATION_VECTOR_REG_reg[2] ),
        .I1(\NO_MANAGEMENT.CONFIGURATION_VECTOR_REG_reg[3] ),
        .O(RX_DV_i_2_n_0));
  FDRE #(
    .INIT(1'b0)) 
    RX_DV_reg
       (.C(userclk2),
        .CE(1'b1),
        .D(RX_DV_i_1_n_0),
        .Q(gmii_rx_dv),
        .R(SR));
  LUT6 #(
    .INIT(64'h000E000E000F0000)) 
    RX_ER_i_1
       (.I0(RX_ER_i_2_n_0),
        .I1(RX_DATA_ERROR),
        .I2(\NO_MANAGEMENT.CONFIGURATION_VECTOR_REG_reg[2] ),
        .I3(\NO_MANAGEMENT.CONFIGURATION_VECTOR_REG_reg[3] ),
        .I4(RECEIVE),
        .I5(p_40_in),
        .O(RX_ER0));
  (* SOFT_HLUTNM = "soft_lutpair5" *) 
  LUT2 #(
    .INIT(4'hE)) 
    RX_ER_i_2
       (.I0(EXTEND_REG1),
        .I1(FALSE_CARRIER_REG3),
        .O(RX_ER_i_2_n_0));
  FDRE #(
    .INIT(1'b0)) 
    RX_ER_reg
       (.C(userclk2),
        .CE(1'b1),
        .D(RX_ER0),
        .Q(gmii_rx_er),
        .R(SR));
  LUT6 #(
    .INIT(64'hAAFEFFFFAAFEAAFE)) 
    RX_INVALID_i_2
       (.I0(FROM_RX_CX),
        .I1(FROM_RX_K),
        .I2(FROM_IDLE_D),
        .I3(p_40_in),
        .I4(K28p5_REG1),
        .I5(status_vector[2]),
        .O(RX_INVALID_i_2_n_0));
  FDRE RX_INVALID_reg
       (.C(userclk2),
        .CE(1'b1),
        .D(RX_INVALID_i_2_n_0),
        .Q(status_vector[2]),
        .R(SYNC_STATUS_REG0));
  FDRE R_REG1_reg
       (.C(userclk2),
        .CE(1'b1),
        .D(R),
        .Q(R_REG1),
        .R(1'b0));
  LUT6 #(
    .INIT(64'h0008000000000000)) 
    R_i_1
       (.I0(R_i_2_n_0),
        .I1(R_i_3_n_0),
        .I2(R_i_4_n_0),
        .I3(Q[3]),
        .I4(Q[6]),
        .I5(\USE_ROCKET_IO.NO_1588.RXCHARISK_INT_reg ),
        .O(K23p7));
  (* SOFT_HLUTNM = "soft_lutpair1" *) 
  LUT2 #(
    .INIT(4'h8)) 
    R_i_2
       (.I0(Q[0]),
        .I1(Q[1]),
        .O(R_i_2_n_0));
  (* SOFT_HLUTNM = "soft_lutpair0" *) 
  LUT2 #(
    .INIT(4'h8)) 
    R_i_3
       (.I0(Q[5]),
        .I1(Q[7]),
        .O(R_i_3_n_0));
  (* SOFT_HLUTNM = "soft_lutpair4" *) 
  LUT2 #(
    .INIT(4'h7)) 
    R_i_4
       (.I0(Q[4]),
        .I1(Q[2]),
        .O(R_i_4_n_0));
  FDRE R_reg
       (.C(userclk2),
        .CE(1'b1),
        .D(K23p7),
        .Q(R),
        .R(1'b0));
  FDRE SOP_REG1_reg
       (.C(userclk2),
        .CE(1'b1),
        .D(SOP),
        .Q(SOP_REG1),
        .R(1'b0));
  FDRE SOP_REG2_reg
       (.C(userclk2),
        .CE(1'b1),
        .D(SOP_REG1),
        .Q(SOP_REG2),
        .R(1'b0));
  FDRE SOP_REG3_reg
       (.C(userclk2),
        .CE(1'b1),
        .D(SOP_REG2),
        .Q(SOP_REG3),
        .R(1'b0));
  LUT5 #(
    .INIT(32'h08080800)) 
    SOP_i_1
       (.I0(p_40_in),
        .I1(S),
        .I2(WAIT_FOR_K),
        .I3(I_REG_reg_n_0),
        .I4(EXTEND),
        .O(SOP0));
  FDRE SOP_reg
       (.C(userclk2),
        .CE(1'b1),
        .D(SOP0),
        .Q(SOP),
        .R(SR));
  FDRE SYNC_STATUS_REG_reg
       (.C(userclk2),
        .CE(1'b1),
        .D(1'b1),
        .Q(SYNC_STATUS_REG),
        .R(SYNC_STATUS_REG0));
  LUT6 #(
    .INIT(64'h8000000000000000)) 
    S_i_1
       (.I0(S_i_2_n_0),
        .I1(Q[3]),
        .I2(\USE_ROCKET_IO.NO_1588.RXCHARISK_INT_reg ),
        .I3(Q[1]),
        .I4(Q[0]),
        .I5(R_i_3_n_0),
        .O(S0));
  LUT6 #(
    .INIT(64'h0000000000000040)) 
    S_i_2
       (.I0(Q[2]),
        .I1(Q[4]),
        .I2(Q[6]),
        .I3(D),
        .I4(\USE_ROCKET_IO.NO_1588.RXBUFSTATUS_INT_reg[1] ),
        .I5(RXNOTINTABLE_INT),
        .O(S_i_2_n_0));
  FDRE S_reg
       (.C(userclk2),
        .CE(1'b1),
        .D(S0),
        .Q(S),
        .R(1'b0));
  FDRE T_REG1_reg
       (.C(userclk2),
        .CE(1'b1),
        .D(T),
        .Q(T_REG1),
        .R(1'b0));
  FDRE T_REG2_reg
       (.C(userclk2),
        .CE(1'b1),
        .D(T_REG1),
        .Q(T_REG2),
        .R(1'b0));
  LUT6 #(
    .INIT(64'h0800000000000000)) 
    T_i_1
       (.I0(Q[5]),
        .I1(Q[7]),
        .I2(Q[1]),
        .I3(Q[6]),
        .I4(Q[0]),
        .I5(FALSE_K_i_2_n_0),
        .O(K29p7));
  FDRE T_reg
       (.C(userclk2),
        .CE(1'b1),
        .D(K29p7),
        .Q(T),
        .R(1'b0));
  LUT4 #(
    .INIT(16'h7F0F)) 
    WAIT_FOR_K_i_1
       (.I0(RXEVEN),
        .I1(K28p5_REG1),
        .I2(SYNC_STATUS_REG),
        .I3(WAIT_FOR_K),
        .O(WAIT_FOR_K_i_1_n_0));
  FDRE WAIT_FOR_K_reg
       (.C(userclk2),
        .CE(1'b1),
        .D(WAIT_FOR_K_i_1_n_0),
        .Q(WAIT_FOR_K),
        .R(SYNC_STATUS_REG0));
endmodule

(* ORIG_REF_NAME = "SYNCHRONISE" *) 
module GigEthGth7Core_SYNCHRONISE
   (RXEVEN,
    p_40_in,
    SYNC_STATUS_REG0,
    STATUS_VECTOR_0_PRE0,
    enablealign,
    SIGNAL_DETECT_MOD,
    userclk2,
    SR,
    \USE_ROCKET_IO.NO_1588.RXCHARISCOMMA_INT_reg ,
    \USE_ROCKET_IO.NO_1588.RXCHARISK_INT_reg ,
    CONFIGURATION_VECTOR_REG,
    D,
    \USE_ROCKET_IO.NO_1588.RXBUFSTATUS_INT_reg[1] ,
    RXNOTINTABLE_INT,
    reset_done);
  output RXEVEN;
  output p_40_in;
  output SYNC_STATUS_REG0;
  output STATUS_VECTOR_0_PRE0;
  output enablealign;
  input SIGNAL_DETECT_MOD;
  input userclk2;
  input [0:0]SR;
  input \USE_ROCKET_IO.NO_1588.RXCHARISCOMMA_INT_reg ;
  input \USE_ROCKET_IO.NO_1588.RXCHARISK_INT_reg ;
  input [0:0]CONFIGURATION_VECTOR_REG;
  input D;
  input \USE_ROCKET_IO.NO_1588.RXBUFSTATUS_INT_reg[1] ;
  input RXNOTINTABLE_INT;
  input reset_done;

  wire CGBAD;
  wire [0:0]CONFIGURATION_VECTOR_REG;
  wire D;
  wire ENCOMMAALIGN_i_1_n_0;
  wire ENCOMMAALIGN_i_2_n_0;
  wire EVEN_i_1_n_0;
  wire \FSM_sequential_STATE[0]_i_2_n_0 ;
  wire \FSM_sequential_STATE[0]_i_3_n_0 ;
  wire \FSM_sequential_STATE[1]_i_2_n_0 ;
  wire \FSM_sequential_STATE[1]_i_3_n_0 ;
  wire \FSM_sequential_STATE[2]_i_2_n_0 ;
  wire \FSM_sequential_STATE[2]_i_3_n_0 ;
  wire \FSM_sequential_STATE[3]_i_1_n_0 ;
  wire \FSM_sequential_STATE[3]_i_2_n_0 ;
  wire \FSM_sequential_STATE[3]_i_3_n_0 ;
  wire \FSM_sequential_STATE_reg[0]_i_1_n_0 ;
  wire \FSM_sequential_STATE_reg[1]_i_1_n_0 ;
  wire \FSM_sequential_STATE_reg[2]_i_1_n_0 ;
  wire [1:0]GOOD_CGS;
  wire \GOOD_CGS[0]_i_1_n_0 ;
  wire \GOOD_CGS[1]_i_1_n_0 ;
  wire \GOOD_CGS[1]_i_2_n_0 ;
  wire RXEVEN;
  wire RXNOTINTABLE_INT;
  wire SIGNAL_DETECT_MOD;
  wire SIGNAL_DETECT_REG;
  wire [0:0]SR;
  (* RTL_KEEP = "yes" *) wire [3:0]STATE;
  wire STATUS_VECTOR_0_PRE0;
  wire SYNC_STATUS0;
  wire SYNC_STATUS_REG0;
  wire SYNC_STATUS_i_1_n_0;
  wire \USE_ROCKET_IO.NO_1588.RXBUFSTATUS_INT_reg[1] ;
  wire \USE_ROCKET_IO.NO_1588.RXCHARISCOMMA_INT_reg ;
  wire \USE_ROCKET_IO.NO_1588.RXCHARISK_INT_reg ;
  wire enablealign;
  wire p_40_in;
  wire reset_done;
  wire userclk2;

  (* SOFT_HLUTNM = "soft_lutpair14" *) 
  LUT3 #(
    .INIT(8'h0E)) 
    ENCOMMAALIGN_i_1
       (.I0(enablealign),
        .I1(ENCOMMAALIGN_i_2_n_0),
        .I2(SYNC_STATUS0),
        .O(ENCOMMAALIGN_i_1_n_0));
  LUT5 #(
    .INIT(32'h14010001)) 
    ENCOMMAALIGN_i_2
       (.I0(STATE[0]),
        .I1(STATE[1]),
        .I2(STATE[2]),
        .I3(STATE[3]),
        .I4(CGBAD),
        .O(ENCOMMAALIGN_i_2_n_0));
  LUT6 #(
    .INIT(64'h0000000000000040)) 
    ENCOMMAALIGN_i_3
       (.I0(\USE_ROCKET_IO.NO_1588.RXCHARISK_INT_reg ),
        .I1(STATE[0]),
        .I2(STATE[2]),
        .I3(STATE[1]),
        .I4(STATE[3]),
        .I5(CGBAD),
        .O(SYNC_STATUS0));
  FDRE ENCOMMAALIGN_reg
       (.C(userclk2),
        .CE(1'b1),
        .D(ENCOMMAALIGN_i_1_n_0),
        .Q(enablealign),
        .R(1'b0));
  (* SOFT_HLUTNM = "soft_lutpair13" *) 
  LUT3 #(
    .INIT(8'h4F)) 
    EVEN_i_1
       (.I0(p_40_in),
        .I1(\USE_ROCKET_IO.NO_1588.RXCHARISCOMMA_INT_reg ),
        .I2(RXEVEN),
        .O(EVEN_i_1_n_0));
  FDRE EVEN_reg
       (.C(userclk2),
        .CE(1'b1),
        .D(EVEN_i_1_n_0),
        .Q(RXEVEN),
        .R(SR));
  LUT5 #(
    .INIT(32'h61156000)) 
    \FSM_sequential_STATE[0]_i_2 
       (.I0(STATE[0]),
        .I1(CGBAD),
        .I2(STATE[2]),
        .I3(STATE[1]),
        .I4(\USE_ROCKET_IO.NO_1588.RXCHARISCOMMA_INT_reg ),
        .O(\FSM_sequential_STATE[0]_i_2_n_0 ));
  LUT6 #(
    .INIT(64'h0000000000F000DF)) 
    \FSM_sequential_STATE[0]_i_3 
       (.I0(GOOD_CGS[1]),
        .I1(GOOD_CGS[0]),
        .I2(STATE[0]),
        .I3(STATE[2]),
        .I4(STATE[1]),
        .I5(CGBAD),
        .O(\FSM_sequential_STATE[0]_i_3_n_0 ));
  LUT5 #(
    .INIT(32'h30330044)) 
    \FSM_sequential_STATE[1]_i_2 
       (.I0(\USE_ROCKET_IO.NO_1588.RXCHARISK_INT_reg ),
        .I1(STATE[0]),
        .I2(STATE[2]),
        .I3(CGBAD),
        .I4(STATE[1]),
        .O(\FSM_sequential_STATE[1]_i_2_n_0 ));
  LUT6 #(
    .INIT(64'h00000000FF0004FF)) 
    \FSM_sequential_STATE[1]_i_3 
       (.I0(CGBAD),
        .I1(GOOD_CGS[1]),
        .I2(GOOD_CGS[0]),
        .I3(STATE[0]),
        .I4(STATE[1]),
        .I5(STATE[2]),
        .O(\FSM_sequential_STATE[1]_i_3_n_0 ));
  LUT5 #(
    .INIT(32'h30370040)) 
    \FSM_sequential_STATE[2]_i_2 
       (.I0(\USE_ROCKET_IO.NO_1588.RXCHARISK_INT_reg ),
        .I1(STATE[0]),
        .I2(STATE[1]),
        .I3(CGBAD),
        .I4(STATE[2]),
        .O(\FSM_sequential_STATE[2]_i_2_n_0 ));
  LUT6 #(
    .INIT(64'h00000000140E1414)) 
    \FSM_sequential_STATE[2]_i_3 
       (.I0(STATE[0]),
        .I1(STATE[1]),
        .I2(STATE[2]),
        .I3(GOOD_CGS[0]),
        .I4(GOOD_CGS[1]),
        .I5(CGBAD),
        .O(\FSM_sequential_STATE[2]_i_3_n_0 ));
  LUT3 #(
    .INIT(8'hF1)) 
    \FSM_sequential_STATE[3]_i_1 
       (.I0(CONFIGURATION_VECTOR_REG),
        .I1(SIGNAL_DETECT_REG),
        .I2(SR),
        .O(\FSM_sequential_STATE[3]_i_1_n_0 ));
  LUT6 #(
    .INIT(64'h0FE000E0003030F0)) 
    \FSM_sequential_STATE[3]_i_2 
       (.I0(\FSM_sequential_STATE[3]_i_3_n_0 ),
        .I1(CGBAD),
        .I2(STATE[3]),
        .I3(STATE[2]),
        .I4(STATE[1]),
        .I5(STATE[0]),
        .O(\FSM_sequential_STATE[3]_i_2_n_0 ));
  LUT2 #(
    .INIT(4'hB)) 
    \FSM_sequential_STATE[3]_i_3 
       (.I0(GOOD_CGS[0]),
        .I1(GOOD_CGS[1]),
        .O(\FSM_sequential_STATE[3]_i_3_n_0 ));
  LUT5 #(
    .INIT(32'hFFFFFFF8)) 
    \FSM_sequential_STATE[3]_i_4 
       (.I0(RXEVEN),
        .I1(\USE_ROCKET_IO.NO_1588.RXCHARISCOMMA_INT_reg ),
        .I2(D),
        .I3(\USE_ROCKET_IO.NO_1588.RXBUFSTATUS_INT_reg[1] ),
        .I4(RXNOTINTABLE_INT),
        .O(CGBAD));
  (* KEEP = "yes" *) 
  FDRE \FSM_sequential_STATE_reg[0] 
       (.C(userclk2),
        .CE(1'b1),
        .D(\FSM_sequential_STATE_reg[0]_i_1_n_0 ),
        .Q(STATE[0]),
        .R(\FSM_sequential_STATE[3]_i_1_n_0 ));
  MUXF7 \FSM_sequential_STATE_reg[0]_i_1 
       (.I0(\FSM_sequential_STATE[0]_i_2_n_0 ),
        .I1(\FSM_sequential_STATE[0]_i_3_n_0 ),
        .O(\FSM_sequential_STATE_reg[0]_i_1_n_0 ),
        .S(STATE[3]));
  (* KEEP = "yes" *) 
  FDRE \FSM_sequential_STATE_reg[1] 
       (.C(userclk2),
        .CE(1'b1),
        .D(\FSM_sequential_STATE_reg[1]_i_1_n_0 ),
        .Q(STATE[1]),
        .R(\FSM_sequential_STATE[3]_i_1_n_0 ));
  MUXF7 \FSM_sequential_STATE_reg[1]_i_1 
       (.I0(\FSM_sequential_STATE[1]_i_2_n_0 ),
        .I1(\FSM_sequential_STATE[1]_i_3_n_0 ),
        .O(\FSM_sequential_STATE_reg[1]_i_1_n_0 ),
        .S(STATE[3]));
  (* KEEP = "yes" *) 
  FDRE \FSM_sequential_STATE_reg[2] 
       (.C(userclk2),
        .CE(1'b1),
        .D(\FSM_sequential_STATE_reg[2]_i_1_n_0 ),
        .Q(STATE[2]),
        .R(\FSM_sequential_STATE[3]_i_1_n_0 ));
  MUXF7 \FSM_sequential_STATE_reg[2]_i_1 
       (.I0(\FSM_sequential_STATE[2]_i_2_n_0 ),
        .I1(\FSM_sequential_STATE[2]_i_3_n_0 ),
        .O(\FSM_sequential_STATE_reg[2]_i_1_n_0 ),
        .S(STATE[3]));
  (* KEEP = "yes" *) 
  FDRE \FSM_sequential_STATE_reg[3] 
       (.C(userclk2),
        .CE(1'b1),
        .D(\FSM_sequential_STATE[3]_i_2_n_0 ),
        .Q(STATE[3]),
        .R(\FSM_sequential_STATE[3]_i_1_n_0 ));
  (* SOFT_HLUTNM = "soft_lutpair12" *) 
  LUT3 #(
    .INIT(8'h09)) 
    \GOOD_CGS[0]_i_1 
       (.I0(GOOD_CGS[0]),
        .I1(CGBAD),
        .I2(\GOOD_CGS[1]_i_2_n_0 ),
        .O(\GOOD_CGS[0]_i_1_n_0 ));
  (* SOFT_HLUTNM = "soft_lutpair12" *) 
  LUT4 #(
    .INIT(16'h009A)) 
    \GOOD_CGS[1]_i_1 
       (.I0(GOOD_CGS[1]),
        .I1(CGBAD),
        .I2(GOOD_CGS[0]),
        .I3(\GOOD_CGS[1]_i_2_n_0 ),
        .O(\GOOD_CGS[1]_i_1_n_0 ));
  LUT5 #(
    .INIT(32'hAABBEAAA)) 
    \GOOD_CGS[1]_i_2 
       (.I0(SR),
        .I1(STATE[0]),
        .I2(STATE[1]),
        .I3(STATE[2]),
        .I4(STATE[3]),
        .O(\GOOD_CGS[1]_i_2_n_0 ));
  FDRE \GOOD_CGS_reg[0] 
       (.C(userclk2),
        .CE(1'b1),
        .D(\GOOD_CGS[0]_i_1_n_0 ),
        .Q(GOOD_CGS[0]),
        .R(1'b0));
  FDRE \GOOD_CGS_reg[1] 
       (.C(userclk2),
        .CE(1'b1),
        .D(\GOOD_CGS[1]_i_1_n_0 ),
        .Q(GOOD_CGS[1]),
        .R(1'b0));
  (* SOFT_HLUTNM = "soft_lutpair13" *) 
  LUT2 #(
    .INIT(4'hB)) 
    RX_INVALID_i_1
       (.I0(SR),
        .I1(p_40_in),
        .O(SYNC_STATUS_REG0));
  FDRE SIGNAL_DETECT_REG_reg
       (.C(userclk2),
        .CE(1'b1),
        .D(SIGNAL_DETECT_MOD),
        .Q(SIGNAL_DETECT_REG),
        .R(1'b0));
  LUT2 #(
    .INIT(4'h8)) 
    STATUS_VECTOR_0_PRE_i_1
       (.I0(p_40_in),
        .I1(reset_done),
        .O(STATUS_VECTOR_0_PRE0));
  (* SOFT_HLUTNM = "soft_lutpair14" *) 
  LUT3 #(
    .INIT(8'hF4)) 
    SYNC_STATUS_i_1
       (.I0(ENCOMMAALIGN_i_2_n_0),
        .I1(p_40_in),
        .I2(SYNC_STATUS0),
        .O(SYNC_STATUS_i_1_n_0));
  FDRE #(
    .INIT(1'b0)) 
    SYNC_STATUS_reg
       (.C(userclk2),
        .CE(1'b1),
        .D(SYNC_STATUS_i_1_n_0),
        .Q(p_40_in),
        .R(1'b0));
endmodule

(* ORIG_REF_NAME = "TX" *) 
module GigEthGth7Core_TX
   (\USE_ROCKET_IO.TXCHARDISPMODE_reg ,
    \USE_ROCKET_IO.TXDATA_reg[7] ,
    D,
    \USE_ROCKET_IO.TXDATA_reg[5] ,
    \USE_ROCKET_IO.TXDATA_reg[3] ,
    \USE_ROCKET_IO.TXDATA_reg[2] ,
    \USE_ROCKET_IO.TXCHARISK_reg ,
    \USE_ROCKET_IO.NO_1588.RXCHARISK_INT_reg ,
    \USE_ROCKET_IO.NO_1588.RXCHARISCOMMA_INT_reg ,
    \USE_ROCKET_IO.NO_1588.RXDATA_INT_reg[7] ,
    \USE_ROCKET_IO.TXDATA_reg[2]_0 ,
    \USE_ROCKET_IO.TXCHARDISPVAL_reg ,
    gmii_tx_en,
    userclk2,
    \USE_ROCKET_IO.MGT_TX_RESET_INT_reg ,
    gmii_tx_er,
    \NO_MANAGEMENT.CONFIGURATION_VECTOR_REG_reg[3] ,
    gmii_txd,
    CONFIGURATION_VECTOR_REG,
    rxcharisk,
    rxchariscomma,
    rxdata);
  output \USE_ROCKET_IO.TXCHARDISPMODE_reg ;
  output \USE_ROCKET_IO.TXDATA_reg[7] ;
  output [3:0]D;
  output \USE_ROCKET_IO.TXDATA_reg[5] ;
  output \USE_ROCKET_IO.TXDATA_reg[3] ;
  output \USE_ROCKET_IO.TXDATA_reg[2] ;
  output \USE_ROCKET_IO.TXCHARISK_reg ;
  output \USE_ROCKET_IO.NO_1588.RXCHARISK_INT_reg ;
  output \USE_ROCKET_IO.NO_1588.RXCHARISCOMMA_INT_reg ;
  output [7:0]\USE_ROCKET_IO.NO_1588.RXDATA_INT_reg[7] ;
  output \USE_ROCKET_IO.TXDATA_reg[2]_0 ;
  output \USE_ROCKET_IO.TXCHARDISPVAL_reg ;
  input gmii_tx_en;
  input userclk2;
  input \USE_ROCKET_IO.MGT_TX_RESET_INT_reg ;
  input gmii_tx_er;
  input [0:0]\NO_MANAGEMENT.CONFIGURATION_VECTOR_REG_reg[3] ;
  input [7:0]gmii_txd;
  input [0:0]CONFIGURATION_VECTOR_REG;
  input [0:0]rxcharisk;
  input [0:0]rxchariscomma;
  input [7:0]rxdata;

  wire C1_OR_C2_i_1_n_0;
  wire C1_OR_C2_reg_n_0;
  wire CODE_GRPISK;
  wire CODE_GRPISK_i_1_n_0;
  wire \CODE_GRP[0]_i_1_n_0 ;
  wire \CODE_GRP[0]_i_2_n_0 ;
  wire \CODE_GRP[1]_i_1_n_0 ;
  wire \CODE_GRP[1]_i_2_n_0 ;
  wire \CODE_GRP[2]_i_1_n_0 ;
  wire \CODE_GRP[2]_i_2_n_0 ;
  wire \CODE_GRP[3]_i_1_n_0 ;
  wire \CODE_GRP[3]_i_2_n_0 ;
  wire \CODE_GRP[4]_i_1_n_0 ;
  wire \CODE_GRP[5]_i_1_n_0 ;
  wire \CODE_GRP[6]_i_1_n_0 ;
  wire \CODE_GRP[7]_i_1_n_0 ;
  wire \CODE_GRP[7]_i_2_n_0 ;
  wire \CODE_GRP_CNT_reg_n_0_[1] ;
  wire \CODE_GRP_reg_n_0_[0] ;
  wire [0:0]CONFIGURATION_VECTOR_REG;
  wire [6:0]CONFIG_DATA;
  wire \CONFIG_DATA_reg_n_0_[0] ;
  wire \CONFIG_DATA_reg_n_0_[1] ;
  wire \CONFIG_DATA_reg_n_0_[2] ;
  wire \CONFIG_DATA_reg_n_0_[3] ;
  wire \CONFIG_DATA_reg_n_0_[4] ;
  wire \CONFIG_DATA_reg_n_0_[5] ;
  wire \CONFIG_DATA_reg_n_0_[6] ;
  wire \CONFIG_DATA_reg_n_0_[7] ;
  wire CONFIG_K28p5;
  wire CONFIG_K28p5_0;
  wire [3:0]D;
  wire DISPARITY;
  wire INSERT_IDLE_i_1_n_0;
  wire INSERT_IDLE_reg_n_0;
  wire K28p5;
  wire K28p5_i_1_n_0;
  wire [0:0]\NO_MANAGEMENT.CONFIGURATION_VECTOR_REG_reg[3] ;
  wire \NO_QSGMII_DATA.TXCHARISK_i_1_n_0 ;
  wire \NO_QSGMII_DATA.TXDATA[0]_i_1_n_0 ;
  wire \NO_QSGMII_DATA.TXDATA[1]_i_1_n_0 ;
  wire \NO_QSGMII_DATA.TXDATA[2]_i_1_n_0 ;
  wire \NO_QSGMII_DATA.TXDATA[3]_i_1_n_0 ;
  wire \NO_QSGMII_DATA.TXDATA[4]_i_1_n_0 ;
  wire \NO_QSGMII_DATA.TXDATA[5]_i_1_n_0 ;
  wire \NO_QSGMII_DATA.TXDATA[6]_i_1_n_0 ;
  wire \NO_QSGMII_DATA.TXDATA[7]_i_1_n_0 ;
  wire \NO_QSGMII_DISP.DISPARITY_i_1_n_0 ;
  wire \NO_QSGMII_DISP.DISPARITY_i_2_n_0 ;
  wire \NO_QSGMII_DISP.DISPARITY_i_3_n_0 ;
  wire R;
  wire R_i_1__0_n_0;
  wire S;
  wire S0;
  wire SYNC_DISPARITY_i_1_n_0;
  wire SYNC_DISPARITY_reg_n_0;
  wire T;
  wire T0;
  wire TRIGGER_S;
  wire TRIGGER_S0;
  wire TRIGGER_T;
  wire TXCHARDISPMODE_INT;
  wire TXCHARDISPVAL;
  wire TXCHARISK_INT;
  wire [7:0]TXDATA;
  wire [7:0]TXD_REG1;
  wire TX_EN_REG1;
  wire TX_ER_REG1;
  wire TX_EVEN;
  wire TX_PACKET;
  wire TX_PACKET_i_1_n_0;
  wire \USE_ROCKET_IO.MGT_TX_RESET_INT_reg ;
  wire \USE_ROCKET_IO.NO_1588.RXCHARISCOMMA_INT_reg ;
  wire \USE_ROCKET_IO.NO_1588.RXCHARISK_INT_reg ;
  wire [7:0]\USE_ROCKET_IO.NO_1588.RXDATA_INT_reg[7] ;
  wire \USE_ROCKET_IO.TXCHARDISPMODE_reg ;
  wire \USE_ROCKET_IO.TXCHARDISPVAL_reg ;
  wire \USE_ROCKET_IO.TXCHARISK_reg ;
  wire \USE_ROCKET_IO.TXDATA_reg[2] ;
  wire \USE_ROCKET_IO.TXDATA_reg[2]_0 ;
  wire \USE_ROCKET_IO.TXDATA_reg[3] ;
  wire \USE_ROCKET_IO.TXDATA_reg[5] ;
  wire \USE_ROCKET_IO.TXDATA_reg[7] ;
  wire V;
  wire V_i_1_n_0;
  wire V_i_2_n_0;
  wire V_i_3_n_0;
  wire V_i_4_n_0;
  wire V_i_5_n_0;
  wire XMIT_CONFIG_INT;
  wire XMIT_CONFIG_INT_i_1_n_0;
  wire XMIT_DATA_INT_i_1_n_0;
  wire XMIT_DATA_INT_reg_n_0;
  wire gmii_tx_en;
  wire gmii_tx_er;
  wire [7:0]gmii_txd;
  wire p_0_in;
  wire p_0_in16_in;
  wire p_0_in35_in;
  wire p_10_out;
  wire p_1_in;
  wire p_1_in1_in;
  wire p_1_in34_in;
  wire p_33_in;
  wire p_45_in;
  wire p_8_out;
  wire [1:0]plusOp;
  wire [0:0]rxchariscomma;
  wire [0:0]rxcharisk;
  wire [7:0]rxdata;
  wire userclk2;

  (* SOFT_HLUTNM = "soft_lutpair20" *) 
  LUT4 #(
    .INIT(16'h3F80)) 
    C1_OR_C2_i_1
       (.I0(XMIT_CONFIG_INT),
        .I1(TX_EVEN),
        .I2(\CODE_GRP_CNT_reg_n_0_[1] ),
        .I3(C1_OR_C2_reg_n_0),
        .O(C1_OR_C2_i_1_n_0));
  FDRE C1_OR_C2_reg
       (.C(userclk2),
        .CE(1'b1),
        .D(C1_OR_C2_i_1_n_0),
        .Q(C1_OR_C2_reg_n_0),
        .R(\USE_ROCKET_IO.MGT_TX_RESET_INT_reg ));
  LUT6 #(
    .INIT(64'h3030FFFF3030FF55)) 
    CODE_GRPISK_i_1
       (.I0(TX_PACKET),
        .I1(\CODE_GRP_CNT_reg_n_0_[1] ),
        .I2(TX_EVEN),
        .I3(\NO_MANAGEMENT.CONFIGURATION_VECTOR_REG_reg[3] ),
        .I4(XMIT_CONFIG_INT),
        .I5(\CODE_GRP[7]_i_2_n_0 ),
        .O(CODE_GRPISK_i_1_n_0));
  FDRE CODE_GRPISK_reg
       (.C(userclk2),
        .CE(1'b1),
        .D(CODE_GRPISK_i_1_n_0),
        .Q(CODE_GRPISK),
        .R(1'b0));
  LUT5 #(
    .INIT(32'hFA00FAFC)) 
    \CODE_GRP[0]_i_1 
       (.I0(\CONFIG_DATA_reg_n_0_[0] ),
        .I1(S),
        .I2(\CODE_GRP[0]_i_2_n_0 ),
        .I3(XMIT_CONFIG_INT),
        .I4(\NO_MANAGEMENT.CONFIGURATION_VECTOR_REG_reg[3] ),
        .O(\CODE_GRP[0]_i_1_n_0 ));
  LUT6 #(
    .INIT(64'h000000000000FFF8)) 
    \CODE_GRP[0]_i_2 
       (.I0(TX_PACKET),
        .I1(TXD_REG1[0]),
        .I2(R),
        .I3(T),
        .I4(XMIT_CONFIG_INT),
        .I5(V),
        .O(\CODE_GRP[0]_i_2_n_0 ));
  LUT6 #(
    .INIT(64'hFFAA0000FFAAFEFE)) 
    \CODE_GRP[1]_i_1 
       (.I0(\CODE_GRP[1]_i_2_n_0 ),
        .I1(S),
        .I2(V),
        .I3(\CONFIG_DATA_reg_n_0_[1] ),
        .I4(XMIT_CONFIG_INT),
        .I5(\NO_MANAGEMENT.CONFIGURATION_VECTOR_REG_reg[3] ),
        .O(\CODE_GRP[1]_i_1_n_0 ));
  LUT5 #(
    .INIT(32'h00000F08)) 
    \CODE_GRP[1]_i_2 
       (.I0(TX_PACKET),
        .I1(TXD_REG1[1]),
        .I2(XMIT_CONFIG_INT),
        .I3(R),
        .I4(T),
        .O(\CODE_GRP[1]_i_2_n_0 ));
  LUT5 #(
    .INIT(32'hC0FFC044)) 
    \CODE_GRP[2]_i_1 
       (.I0(S),
        .I1(\CODE_GRP[2]_i_2_n_0 ),
        .I2(\CONFIG_DATA_reg_n_0_[2] ),
        .I3(XMIT_CONFIG_INT),
        .I4(\NO_MANAGEMENT.CONFIGURATION_VECTOR_REG_reg[3] ),
        .O(\CODE_GRP[2]_i_1_n_0 ));
  LUT6 #(
    .INIT(64'hFFFFFFFFFFFEFFFF)) 
    \CODE_GRP[2]_i_2 
       (.I0(R),
        .I1(T),
        .I2(V),
        .I3(XMIT_CONFIG_INT),
        .I4(TX_PACKET),
        .I5(TXD_REG1[2]),
        .O(\CODE_GRP[2]_i_2_n_0 ));
  LUT6 #(
    .INIT(64'hFFFFFFFF88BB888B)) 
    \CODE_GRP[3]_i_1 
       (.I0(\CONFIG_DATA_reg_n_0_[3] ),
        .I1(XMIT_CONFIG_INT),
        .I2(TX_PACKET),
        .I3(R),
        .I4(TXD_REG1[3]),
        .I5(\CODE_GRP[3]_i_2_n_0 ),
        .O(\CODE_GRP[3]_i_1_n_0 ));
  LUT5 #(
    .INIT(32'h00FF00FE)) 
    \CODE_GRP[3]_i_2 
       (.I0(T),
        .I1(S),
        .I2(V),
        .I3(XMIT_CONFIG_INT),
        .I4(\NO_MANAGEMENT.CONFIGURATION_VECTOR_REG_reg[3] ),
        .O(\CODE_GRP[3]_i_2_n_0 ));
  LUT6 #(
    .INIT(64'hCFCFCFCFCFCFCACF)) 
    \CODE_GRP[4]_i_1 
       (.I0(TXD_REG1[4]),
        .I1(\CONFIG_DATA_reg_n_0_[4] ),
        .I2(XMIT_CONFIG_INT),
        .I3(TX_PACKET),
        .I4(\CODE_GRP[7]_i_2_n_0 ),
        .I5(\NO_MANAGEMENT.CONFIGURATION_VECTOR_REG_reg[3] ),
        .O(\CODE_GRP[4]_i_1_n_0 ));
  LUT6 #(
    .INIT(64'hCFCFCFCFCFCFCACF)) 
    \CODE_GRP[5]_i_1 
       (.I0(TXD_REG1[5]),
        .I1(\CONFIG_DATA_reg_n_0_[5] ),
        .I2(XMIT_CONFIG_INT),
        .I3(TX_PACKET),
        .I4(\CODE_GRP[7]_i_2_n_0 ),
        .I5(\NO_MANAGEMENT.CONFIGURATION_VECTOR_REG_reg[3] ),
        .O(\CODE_GRP[5]_i_1_n_0 ));
  LUT6 #(
    .INIT(64'hAAAA0000AAAAFFC0)) 
    \CODE_GRP[6]_i_1 
       (.I0(\CONFIG_DATA_reg_n_0_[6] ),
        .I1(TX_PACKET),
        .I2(TXD_REG1[6]),
        .I3(\CODE_GRP[7]_i_2_n_0 ),
        .I4(XMIT_CONFIG_INT),
        .I5(\NO_MANAGEMENT.CONFIGURATION_VECTOR_REG_reg[3] ),
        .O(\CODE_GRP[6]_i_1_n_0 ));
  LUT6 #(
    .INIT(64'hCFCFCFCFCFCFCACF)) 
    \CODE_GRP[7]_i_1 
       (.I0(TXD_REG1[7]),
        .I1(\CONFIG_DATA_reg_n_0_[7] ),
        .I2(XMIT_CONFIG_INT),
        .I3(TX_PACKET),
        .I4(\CODE_GRP[7]_i_2_n_0 ),
        .I5(\NO_MANAGEMENT.CONFIGURATION_VECTOR_REG_reg[3] ),
        .O(\CODE_GRP[7]_i_1_n_0 ));
  (* SOFT_HLUTNM = "soft_lutpair18" *) 
  LUT4 #(
    .INIT(16'hFFFE)) 
    \CODE_GRP[7]_i_2 
       (.I0(V),
        .I1(S),
        .I2(T),
        .I3(R),
        .O(\CODE_GRP[7]_i_2_n_0 ));
  (* SOFT_HLUTNM = "soft_lutpair36" *) 
  LUT1 #(
    .INIT(2'h1)) 
    \CODE_GRP_CNT[0]_i_1 
       (.I0(TX_EVEN),
        .O(plusOp[0]));
  (* SOFT_HLUTNM = "soft_lutpair35" *) 
  LUT2 #(
    .INIT(4'h6)) 
    \CODE_GRP_CNT[1]_i_1 
       (.I0(TX_EVEN),
        .I1(\CODE_GRP_CNT_reg_n_0_[1] ),
        .O(plusOp[1]));
  FDSE \CODE_GRP_CNT_reg[0] 
       (.C(userclk2),
        .CE(1'b1),
        .D(plusOp[0]),
        .Q(TX_EVEN),
        .S(\USE_ROCKET_IO.MGT_TX_RESET_INT_reg ));
  FDSE \CODE_GRP_CNT_reg[1] 
       (.C(userclk2),
        .CE(1'b1),
        .D(plusOp[1]),
        .Q(\CODE_GRP_CNT_reg_n_0_[1] ),
        .S(\USE_ROCKET_IO.MGT_TX_RESET_INT_reg ));
  FDRE \CODE_GRP_reg[0] 
       (.C(userclk2),
        .CE(1'b1),
        .D(\CODE_GRP[0]_i_1_n_0 ),
        .Q(\CODE_GRP_reg_n_0_[0] ),
        .R(1'b0));
  FDRE \CODE_GRP_reg[1] 
       (.C(userclk2),
        .CE(1'b1),
        .D(\CODE_GRP[1]_i_1_n_0 ),
        .Q(p_1_in),
        .R(1'b0));
  FDRE \CODE_GRP_reg[2] 
       (.C(userclk2),
        .CE(1'b1),
        .D(\CODE_GRP[2]_i_1_n_0 ),
        .Q(p_0_in16_in),
        .R(1'b0));
  FDRE \CODE_GRP_reg[3] 
       (.C(userclk2),
        .CE(1'b1),
        .D(\CODE_GRP[3]_i_1_n_0 ),
        .Q(p_0_in),
        .R(1'b0));
  FDRE \CODE_GRP_reg[4] 
       (.C(userclk2),
        .CE(1'b1),
        .D(\CODE_GRP[4]_i_1_n_0 ),
        .Q(p_1_in1_in),
        .R(1'b0));
  FDRE \CODE_GRP_reg[5] 
       (.C(userclk2),
        .CE(1'b1),
        .D(\CODE_GRP[5]_i_1_n_0 ),
        .Q(p_1_in34_in),
        .R(1'b0));
  FDRE \CODE_GRP_reg[6] 
       (.C(userclk2),
        .CE(1'b1),
        .D(\CODE_GRP[6]_i_1_n_0 ),
        .Q(p_33_in),
        .R(1'b0));
  FDRE \CODE_GRP_reg[7] 
       (.C(userclk2),
        .CE(1'b1),
        .D(\CODE_GRP[7]_i_1_n_0 ),
        .Q(p_0_in35_in),
        .R(1'b0));
  (* SOFT_HLUTNM = "soft_lutpair20" *) 
  LUT3 #(
    .INIT(8'h04)) 
    \CONFIG_DATA[0]_i_1 
       (.I0(\CODE_GRP_CNT_reg_n_0_[1] ),
        .I1(TX_EVEN),
        .I2(C1_OR_C2_reg_n_0),
        .O(CONFIG_DATA[0]));
  (* SOFT_HLUTNM = "soft_lutpair28" *) 
  LUT3 #(
    .INIT(8'h08)) 
    \CONFIG_DATA[1]_i_1 
       (.I0(TX_EVEN),
        .I1(C1_OR_C2_reg_n_0),
        .I2(\CODE_GRP_CNT_reg_n_0_[1] ),
        .O(CONFIG_DATA[1]));
  (* SOFT_HLUTNM = "soft_lutpair34" *) 
  LUT2 #(
    .INIT(4'h1)) 
    \CONFIG_DATA[3]_i_1 
       (.I0(TX_EVEN),
        .I1(\CODE_GRP_CNT_reg_n_0_[1] ),
        .O(CONFIG_DATA[3]));
  (* SOFT_HLUTNM = "soft_lutpair34" *) 
  LUT3 #(
    .INIT(8'h08)) 
    \CONFIG_DATA[6]_i_1 
       (.I0(TX_EVEN),
        .I1(C1_OR_C2_reg_n_0),
        .I2(\CODE_GRP_CNT_reg_n_0_[1] ),
        .O(CONFIG_DATA[6]));
  (* SOFT_HLUTNM = "soft_lutpair28" *) 
  LUT3 #(
    .INIT(8'h07)) 
    \CONFIG_DATA[7]_i_1 
       (.I0(TX_EVEN),
        .I1(C1_OR_C2_reg_n_0),
        .I2(\CODE_GRP_CNT_reg_n_0_[1] ),
        .O(CONFIG_DATA[2]));
  FDRE \CONFIG_DATA_reg[0] 
       (.C(userclk2),
        .CE(1'b1),
        .D(CONFIG_DATA[0]),
        .Q(\CONFIG_DATA_reg_n_0_[0] ),
        .R(\USE_ROCKET_IO.MGT_TX_RESET_INT_reg ));
  FDRE \CONFIG_DATA_reg[1] 
       (.C(userclk2),
        .CE(1'b1),
        .D(CONFIG_DATA[1]),
        .Q(\CONFIG_DATA_reg_n_0_[1] ),
        .R(\USE_ROCKET_IO.MGT_TX_RESET_INT_reg ));
  FDRE \CONFIG_DATA_reg[2] 
       (.C(userclk2),
        .CE(1'b1),
        .D(CONFIG_DATA[2]),
        .Q(\CONFIG_DATA_reg_n_0_[2] ),
        .R(\USE_ROCKET_IO.MGT_TX_RESET_INT_reg ));
  FDRE \CONFIG_DATA_reg[3] 
       (.C(userclk2),
        .CE(1'b1),
        .D(CONFIG_DATA[3]),
        .Q(\CONFIG_DATA_reg_n_0_[3] ),
        .R(\USE_ROCKET_IO.MGT_TX_RESET_INT_reg ));
  FDRE \CONFIG_DATA_reg[4] 
       (.C(userclk2),
        .CE(1'b1),
        .D(CONFIG_DATA[2]),
        .Q(\CONFIG_DATA_reg_n_0_[4] ),
        .R(\USE_ROCKET_IO.MGT_TX_RESET_INT_reg ));
  FDRE \CONFIG_DATA_reg[5] 
       (.C(userclk2),
        .CE(1'b1),
        .D(CONFIG_DATA[2]),
        .Q(\CONFIG_DATA_reg_n_0_[5] ),
        .R(\USE_ROCKET_IO.MGT_TX_RESET_INT_reg ));
  FDRE \CONFIG_DATA_reg[6] 
       (.C(userclk2),
        .CE(1'b1),
        .D(CONFIG_DATA[6]),
        .Q(\CONFIG_DATA_reg_n_0_[6] ),
        .R(\USE_ROCKET_IO.MGT_TX_RESET_INT_reg ));
  FDRE \CONFIG_DATA_reg[7] 
       (.C(userclk2),
        .CE(1'b1),
        .D(CONFIG_DATA[2]),
        .Q(\CONFIG_DATA_reg_n_0_[7] ),
        .R(\USE_ROCKET_IO.MGT_TX_RESET_INT_reg ));
  (* SOFT_HLUTNM = "soft_lutpair27" *) 
  LUT2 #(
    .INIT(4'h1)) 
    CONFIG_K28p5_i_1
       (.I0(TX_EVEN),
        .I1(\CODE_GRP_CNT_reg_n_0_[1] ),
        .O(CONFIG_K28p5_0));
  FDRE CONFIG_K28p5_reg
       (.C(userclk2),
        .CE(1'b1),
        .D(CONFIG_K28p5_0),
        .Q(CONFIG_K28p5),
        .R(\USE_ROCKET_IO.MGT_TX_RESET_INT_reg ));
  (* SOFT_HLUTNM = "soft_lutpair21" *) 
  LUT4 #(
    .INIT(16'h00AB)) 
    INSERT_IDLE_i_1
       (.I0(\NO_MANAGEMENT.CONFIGURATION_VECTOR_REG_reg[3] ),
        .I1(\CODE_GRP[7]_i_2_n_0 ),
        .I2(TX_PACKET),
        .I3(XMIT_CONFIG_INT),
        .O(INSERT_IDLE_i_1_n_0));
  FDRE INSERT_IDLE_reg
       (.C(userclk2),
        .CE(1'b1),
        .D(INSERT_IDLE_i_1_n_0),
        .Q(INSERT_IDLE_reg_n_0),
        .R(1'b0));
  (* SOFT_HLUTNM = "soft_lutpair21" *) 
  LUT2 #(
    .INIT(4'h8)) 
    K28p5_i_1
       (.I0(XMIT_CONFIG_INT),
        .I1(CONFIG_K28p5),
        .O(K28p5_i_1_n_0));
  FDRE K28p5_reg
       (.C(userclk2),
        .CE(1'b1),
        .D(K28p5_i_1_n_0),
        .Q(K28p5),
        .R(1'b0));
  (* SOFT_HLUTNM = "soft_lutpair36" *) 
  LUT2 #(
    .INIT(4'h2)) 
    \NO_QSGMII_CHAR.TXCHARDISPMODE_i_1 
       (.I0(SYNC_DISPARITY_reg_n_0),
        .I1(TX_EVEN),
        .O(p_10_out));
  FDSE \NO_QSGMII_CHAR.TXCHARDISPMODE_reg 
       (.C(userclk2),
        .CE(1'b1),
        .D(p_10_out),
        .Q(TXCHARDISPMODE_INT),
        .S(\USE_ROCKET_IO.MGT_TX_RESET_INT_reg ));
  (* SOFT_HLUTNM = "soft_lutpair27" *) 
  LUT3 #(
    .INIT(8'h40)) 
    \NO_QSGMII_CHAR.TXCHARDISPVAL_i_1 
       (.I0(TX_EVEN),
        .I1(SYNC_DISPARITY_reg_n_0),
        .I2(DISPARITY),
        .O(p_8_out));
  FDRE \NO_QSGMII_CHAR.TXCHARDISPVAL_reg 
       (.C(userclk2),
        .CE(1'b1),
        .D(p_8_out),
        .Q(TXCHARDISPVAL),
        .R(\USE_ROCKET_IO.MGT_TX_RESET_INT_reg ));
  LUT4 #(
    .INIT(16'h002A)) 
    \NO_QSGMII_DATA.TXCHARISK_i_1 
       (.I0(CODE_GRPISK),
        .I1(TX_EVEN),
        .I2(INSERT_IDLE_reg_n_0),
        .I3(\USE_ROCKET_IO.MGT_TX_RESET_INT_reg ),
        .O(\NO_QSGMII_DATA.TXCHARISK_i_1_n_0 ));
  FDRE \NO_QSGMII_DATA.TXCHARISK_reg 
       (.C(userclk2),
        .CE(1'b1),
        .D(\NO_QSGMII_DATA.TXCHARISK_i_1_n_0 ),
        .Q(TXCHARISK_INT),
        .R(1'b0));
  LUT5 #(
    .INIT(32'h23332000)) 
    \NO_QSGMII_DATA.TXDATA[0]_i_1 
       (.I0(DISPARITY),
        .I1(\USE_ROCKET_IO.MGT_TX_RESET_INT_reg ),
        .I2(INSERT_IDLE_reg_n_0),
        .I3(TX_EVEN),
        .I4(\CODE_GRP_reg_n_0_[0] ),
        .O(\NO_QSGMII_DATA.TXDATA[0]_i_1_n_0 ));
  (* SOFT_HLUTNM = "soft_lutpair15" *) 
  LUT4 #(
    .INIT(16'h002A)) 
    \NO_QSGMII_DATA.TXDATA[1]_i_1 
       (.I0(p_1_in),
        .I1(TX_EVEN),
        .I2(INSERT_IDLE_reg_n_0),
        .I3(\USE_ROCKET_IO.MGT_TX_RESET_INT_reg ),
        .O(\NO_QSGMII_DATA.TXDATA[1]_i_1_n_0 ));
  LUT5 #(
    .INIT(32'h23332000)) 
    \NO_QSGMII_DATA.TXDATA[2]_i_1 
       (.I0(DISPARITY),
        .I1(\USE_ROCKET_IO.MGT_TX_RESET_INT_reg ),
        .I2(INSERT_IDLE_reg_n_0),
        .I3(TX_EVEN),
        .I4(p_0_in16_in),
        .O(\NO_QSGMII_DATA.TXDATA[2]_i_1_n_0 ));
  (* SOFT_HLUTNM = "soft_lutpair17" *) 
  LUT4 #(
    .INIT(16'h002A)) 
    \NO_QSGMII_DATA.TXDATA[3]_i_1 
       (.I0(p_0_in),
        .I1(TX_EVEN),
        .I2(INSERT_IDLE_reg_n_0),
        .I3(\USE_ROCKET_IO.MGT_TX_RESET_INT_reg ),
        .O(\NO_QSGMII_DATA.TXDATA[3]_i_1_n_0 ));
  LUT5 #(
    .INIT(32'h13331000)) 
    \NO_QSGMII_DATA.TXDATA[4]_i_1 
       (.I0(DISPARITY),
        .I1(\USE_ROCKET_IO.MGT_TX_RESET_INT_reg ),
        .I2(INSERT_IDLE_reg_n_0),
        .I3(TX_EVEN),
        .I4(p_1_in1_in),
        .O(\NO_QSGMII_DATA.TXDATA[4]_i_1_n_0 ));
  (* SOFT_HLUTNM = "soft_lutpair15" *) 
  LUT4 #(
    .INIT(16'h002A)) 
    \NO_QSGMII_DATA.TXDATA[5]_i_1 
       (.I0(p_1_in34_in),
        .I1(TX_EVEN),
        .I2(INSERT_IDLE_reg_n_0),
        .I3(\USE_ROCKET_IO.MGT_TX_RESET_INT_reg ),
        .O(\NO_QSGMII_DATA.TXDATA[5]_i_1_n_0 ));
  (* SOFT_HLUTNM = "soft_lutpair17" *) 
  LUT4 #(
    .INIT(16'h3222)) 
    \NO_QSGMII_DATA.TXDATA[6]_i_1 
       (.I0(p_33_in),
        .I1(\USE_ROCKET_IO.MGT_TX_RESET_INT_reg ),
        .I2(TX_EVEN),
        .I3(INSERT_IDLE_reg_n_0),
        .O(\NO_QSGMII_DATA.TXDATA[6]_i_1_n_0 ));
  LUT5 #(
    .INIT(32'h23332000)) 
    \NO_QSGMII_DATA.TXDATA[7]_i_1 
       (.I0(DISPARITY),
        .I1(\USE_ROCKET_IO.MGT_TX_RESET_INT_reg ),
        .I2(INSERT_IDLE_reg_n_0),
        .I3(TX_EVEN),
        .I4(p_0_in35_in),
        .O(\NO_QSGMII_DATA.TXDATA[7]_i_1_n_0 ));
  FDRE \NO_QSGMII_DATA.TXDATA_reg[0] 
       (.C(userclk2),
        .CE(1'b1),
        .D(\NO_QSGMII_DATA.TXDATA[0]_i_1_n_0 ),
        .Q(TXDATA[0]),
        .R(1'b0));
  FDRE \NO_QSGMII_DATA.TXDATA_reg[1] 
       (.C(userclk2),
        .CE(1'b1),
        .D(\NO_QSGMII_DATA.TXDATA[1]_i_1_n_0 ),
        .Q(TXDATA[1]),
        .R(1'b0));
  FDRE \NO_QSGMII_DATA.TXDATA_reg[2] 
       (.C(userclk2),
        .CE(1'b1),
        .D(\NO_QSGMII_DATA.TXDATA[2]_i_1_n_0 ),
        .Q(TXDATA[2]),
        .R(1'b0));
  FDRE \NO_QSGMII_DATA.TXDATA_reg[3] 
       (.C(userclk2),
        .CE(1'b1),
        .D(\NO_QSGMII_DATA.TXDATA[3]_i_1_n_0 ),
        .Q(TXDATA[3]),
        .R(1'b0));
  FDRE \NO_QSGMII_DATA.TXDATA_reg[4] 
       (.C(userclk2),
        .CE(1'b1),
        .D(\NO_QSGMII_DATA.TXDATA[4]_i_1_n_0 ),
        .Q(TXDATA[4]),
        .R(1'b0));
  FDRE \NO_QSGMII_DATA.TXDATA_reg[5] 
       (.C(userclk2),
        .CE(1'b1),
        .D(\NO_QSGMII_DATA.TXDATA[5]_i_1_n_0 ),
        .Q(TXDATA[5]),
        .R(1'b0));
  FDRE \NO_QSGMII_DATA.TXDATA_reg[6] 
       (.C(userclk2),
        .CE(1'b1),
        .D(\NO_QSGMII_DATA.TXDATA[6]_i_1_n_0 ),
        .Q(TXDATA[6]),
        .R(1'b0));
  FDRE \NO_QSGMII_DATA.TXDATA_reg[7] 
       (.C(userclk2),
        .CE(1'b1),
        .D(\NO_QSGMII_DATA.TXDATA[7]_i_1_n_0 ),
        .Q(TXDATA[7]),
        .R(1'b0));
  LUT6 #(
    .INIT(64'h0041414100BEBEBE)) 
    \NO_QSGMII_DISP.DISPARITY_i_1 
       (.I0(K28p5),
        .I1(\NO_QSGMII_DISP.DISPARITY_i_2_n_0 ),
        .I2(\NO_QSGMII_DISP.DISPARITY_i_3_n_0 ),
        .I3(INSERT_IDLE_reg_n_0),
        .I4(TX_EVEN),
        .I5(DISPARITY),
        .O(\NO_QSGMII_DISP.DISPARITY_i_1_n_0 ));
  LUT3 #(
    .INIT(8'h7C)) 
    \NO_QSGMII_DISP.DISPARITY_i_2 
       (.I0(p_0_in35_in),
        .I1(p_33_in),
        .I2(p_1_in34_in),
        .O(\NO_QSGMII_DISP.DISPARITY_i_2_n_0 ));
  LUT5 #(
    .INIT(32'h177E7EA8)) 
    \NO_QSGMII_DISP.DISPARITY_i_3 
       (.I0(p_0_in16_in),
        .I1(p_1_in1_in),
        .I2(p_0_in),
        .I3(\CODE_GRP_reg_n_0_[0] ),
        .I4(p_1_in),
        .O(\NO_QSGMII_DISP.DISPARITY_i_3_n_0 ));
  FDSE \NO_QSGMII_DISP.DISPARITY_reg 
       (.C(userclk2),
        .CE(1'b1),
        .D(\NO_QSGMII_DISP.DISPARITY_i_1_n_0 ),
        .Q(DISPARITY),
        .S(\USE_ROCKET_IO.MGT_TX_RESET_INT_reg ));
  LUT5 #(
    .INIT(32'hF0FEF0F0)) 
    R_i_1__0
       (.I0(TX_EVEN),
        .I1(TX_ER_REG1),
        .I2(T),
        .I3(S),
        .I4(R),
        .O(R_i_1__0_n_0));
  FDRE R_reg
       (.C(userclk2),
        .CE(1'b1),
        .D(R_i_1__0_n_0),
        .Q(R),
        .R(\USE_ROCKET_IO.MGT_TX_RESET_INT_reg ));
  LUT6 #(
    .INIT(64'h3030AAAA3030AAFF)) 
    SYNC_DISPARITY_i_1
       (.I0(\NO_MANAGEMENT.CONFIGURATION_VECTOR_REG_reg[3] ),
        .I1(\CODE_GRP_CNT_reg_n_0_[1] ),
        .I2(TX_EVEN),
        .I3(\CODE_GRP[7]_i_2_n_0 ),
        .I4(XMIT_CONFIG_INT),
        .I5(TX_PACKET),
        .O(SYNC_DISPARITY_i_1_n_0));
  FDRE SYNC_DISPARITY_reg
       (.C(userclk2),
        .CE(1'b1),
        .D(SYNC_DISPARITY_i_1_n_0),
        .Q(SYNC_DISPARITY_reg_n_0),
        .R(1'b0));
  LUT6 #(
    .INIT(64'hFFFF00000B000000)) 
    S_i_1__0
       (.I0(TX_ER_REG1),
        .I1(TX_EVEN),
        .I2(TX_EN_REG1),
        .I3(gmii_tx_en),
        .I4(XMIT_DATA_INT_reg_n_0),
        .I5(TRIGGER_S),
        .O(S0));
  FDRE S_reg
       (.C(userclk2),
        .CE(1'b1),
        .D(S0),
        .Q(S),
        .R(\USE_ROCKET_IO.MGT_TX_RESET_INT_reg ));
  (* SOFT_HLUTNM = "soft_lutpair19" *) 
  LUT4 #(
    .INIT(16'h0040)) 
    TRIGGER_S_i_1
       (.I0(TX_EN_REG1),
        .I1(gmii_tx_en),
        .I2(TX_EVEN),
        .I3(TX_ER_REG1),
        .O(TRIGGER_S0));
  FDRE TRIGGER_S_reg
       (.C(userclk2),
        .CE(1'b1),
        .D(TRIGGER_S0),
        .Q(TRIGGER_S),
        .R(\USE_ROCKET_IO.MGT_TX_RESET_INT_reg ));
  (* SOFT_HLUTNM = "soft_lutpair19" *) 
  LUT2 #(
    .INIT(4'h2)) 
    TRIGGER_T_i_1
       (.I0(TX_EN_REG1),
        .I1(gmii_tx_en),
        .O(p_45_in));
  FDRE TRIGGER_T_reg
       (.C(userclk2),
        .CE(1'b1),
        .D(p_45_in),
        .Q(TRIGGER_T),
        .R(\USE_ROCKET_IO.MGT_TX_RESET_INT_reg ));
  FDRE \TXD_REG1_reg[0] 
       (.C(userclk2),
        .CE(1'b1),
        .D(gmii_txd[0]),
        .Q(TXD_REG1[0]),
        .R(1'b0));
  FDRE \TXD_REG1_reg[1] 
       (.C(userclk2),
        .CE(1'b1),
        .D(gmii_txd[1]),
        .Q(TXD_REG1[1]),
        .R(1'b0));
  FDRE \TXD_REG1_reg[2] 
       (.C(userclk2),
        .CE(1'b1),
        .D(gmii_txd[2]),
        .Q(TXD_REG1[2]),
        .R(1'b0));
  FDRE \TXD_REG1_reg[3] 
       (.C(userclk2),
        .CE(1'b1),
        .D(gmii_txd[3]),
        .Q(TXD_REG1[3]),
        .R(1'b0));
  FDRE \TXD_REG1_reg[4] 
       (.C(userclk2),
        .CE(1'b1),
        .D(gmii_txd[4]),
        .Q(TXD_REG1[4]),
        .R(1'b0));
  FDRE \TXD_REG1_reg[5] 
       (.C(userclk2),
        .CE(1'b1),
        .D(gmii_txd[5]),
        .Q(TXD_REG1[5]),
        .R(1'b0));
  FDRE \TXD_REG1_reg[6] 
       (.C(userclk2),
        .CE(1'b1),
        .D(gmii_txd[6]),
        .Q(TXD_REG1[6]),
        .R(1'b0));
  FDRE \TXD_REG1_reg[7] 
       (.C(userclk2),
        .CE(1'b1),
        .D(gmii_txd[7]),
        .Q(TXD_REG1[7]),
        .R(1'b0));
  FDRE TX_EN_REG1_reg
       (.C(userclk2),
        .CE(1'b1),
        .D(gmii_tx_en),
        .Q(TX_EN_REG1),
        .R(1'b0));
  FDRE TX_ER_REG1_reg
       (.C(userclk2),
        .CE(1'b1),
        .D(gmii_tx_er),
        .Q(TX_ER_REG1),
        .R(1'b0));
  (* SOFT_HLUTNM = "soft_lutpair18" *) 
  LUT3 #(
    .INIT(8'hBA)) 
    TX_PACKET_i_1
       (.I0(S),
        .I1(T),
        .I2(TX_PACKET),
        .O(TX_PACKET_i_1_n_0));
  FDRE TX_PACKET_reg
       (.C(userclk2),
        .CE(1'b1),
        .D(TX_PACKET_i_1_n_0),
        .Q(TX_PACKET),
        .R(\USE_ROCKET_IO.MGT_TX_RESET_INT_reg ));
  LUT6 #(
    .INIT(64'hFFFF00E000E000E0)) 
    T_i_1__0
       (.I0(TX_PACKET),
        .I1(S),
        .I2(TX_EN_REG1),
        .I3(gmii_tx_en),
        .I4(V),
        .I5(TRIGGER_T),
        .O(T0));
  FDRE T_reg
       (.C(userclk2),
        .CE(1'b1),
        .D(T0),
        .Q(T),
        .R(\USE_ROCKET_IO.MGT_TX_RESET_INT_reg ));
  (* SOFT_HLUTNM = "soft_lutpair22" *) 
  LUT3 #(
    .INIT(8'hB8)) 
    \USE_ROCKET_IO.NO_1588.RXCHARISCOMMA_INT_i_1 
       (.I0(TXCHARISK_INT),
        .I1(CONFIGURATION_VECTOR_REG),
        .I2(rxchariscomma),
        .O(\USE_ROCKET_IO.NO_1588.RXCHARISCOMMA_INT_reg ));
  (* SOFT_HLUTNM = "soft_lutpair25" *) 
  LUT3 #(
    .INIT(8'hB8)) 
    \USE_ROCKET_IO.NO_1588.RXCHARISK_INT_i_1 
       (.I0(TXCHARISK_INT),
        .I1(CONFIGURATION_VECTOR_REG),
        .I2(rxcharisk),
        .O(\USE_ROCKET_IO.NO_1588.RXCHARISK_INT_reg ));
  (* SOFT_HLUTNM = "soft_lutpair33" *) 
  LUT3 #(
    .INIT(8'hB8)) 
    \USE_ROCKET_IO.NO_1588.RXDATA_INT[0]_i_1 
       (.I0(TXDATA[0]),
        .I1(CONFIGURATION_VECTOR_REG),
        .I2(rxdata[0]),
        .O(\USE_ROCKET_IO.NO_1588.RXDATA_INT_reg[7] [0]));
  (* SOFT_HLUTNM = "soft_lutpair33" *) 
  LUT3 #(
    .INIT(8'hB8)) 
    \USE_ROCKET_IO.NO_1588.RXDATA_INT[1]_i_1 
       (.I0(TXDATA[1]),
        .I1(CONFIGURATION_VECTOR_REG),
        .I2(rxdata[1]),
        .O(\USE_ROCKET_IO.NO_1588.RXDATA_INT_reg[7] [1]));
  (* SOFT_HLUTNM = "soft_lutpair32" *) 
  LUT3 #(
    .INIT(8'hB8)) 
    \USE_ROCKET_IO.NO_1588.RXDATA_INT[2]_i_1 
       (.I0(TXDATA[2]),
        .I1(CONFIGURATION_VECTOR_REG),
        .I2(rxdata[2]),
        .O(\USE_ROCKET_IO.NO_1588.RXDATA_INT_reg[7] [2]));
  (* SOFT_HLUTNM = "soft_lutpair32" *) 
  LUT3 #(
    .INIT(8'hB8)) 
    \USE_ROCKET_IO.NO_1588.RXDATA_INT[3]_i_1 
       (.I0(TXDATA[3]),
        .I1(CONFIGURATION_VECTOR_REG),
        .I2(rxdata[3]),
        .O(\USE_ROCKET_IO.NO_1588.RXDATA_INT_reg[7] [3]));
  (* SOFT_HLUTNM = "soft_lutpair31" *) 
  LUT3 #(
    .INIT(8'hB8)) 
    \USE_ROCKET_IO.NO_1588.RXDATA_INT[4]_i_1 
       (.I0(TXDATA[4]),
        .I1(CONFIGURATION_VECTOR_REG),
        .I2(rxdata[4]),
        .O(\USE_ROCKET_IO.NO_1588.RXDATA_INT_reg[7] [4]));
  (* SOFT_HLUTNM = "soft_lutpair30" *) 
  LUT3 #(
    .INIT(8'hB8)) 
    \USE_ROCKET_IO.NO_1588.RXDATA_INT[5]_i_1 
       (.I0(TXDATA[5]),
        .I1(CONFIGURATION_VECTOR_REG),
        .I2(rxdata[5]),
        .O(\USE_ROCKET_IO.NO_1588.RXDATA_INT_reg[7] [5]));
  (* SOFT_HLUTNM = "soft_lutpair30" *) 
  LUT3 #(
    .INIT(8'hB8)) 
    \USE_ROCKET_IO.NO_1588.RXDATA_INT[6]_i_1 
       (.I0(TXDATA[6]),
        .I1(CONFIGURATION_VECTOR_REG),
        .I2(rxdata[6]),
        .O(\USE_ROCKET_IO.NO_1588.RXDATA_INT_reg[7] [6]));
  (* SOFT_HLUTNM = "soft_lutpair29" *) 
  LUT3 #(
    .INIT(8'hB8)) 
    \USE_ROCKET_IO.NO_1588.RXDATA_INT[7]_i_1 
       (.I0(TXDATA[7]),
        .I1(CONFIGURATION_VECTOR_REG),
        .I2(rxdata[7]),
        .O(\USE_ROCKET_IO.NO_1588.RXDATA_INT_reg[7] [7]));
  (* SOFT_HLUTNM = "soft_lutpair24" *) 
  LUT3 #(
    .INIT(8'hB8)) 
    \USE_ROCKET_IO.TXCHARDISPMODE_i_1 
       (.I0(TX_EVEN),
        .I1(CONFIGURATION_VECTOR_REG),
        .I2(TXCHARDISPMODE_INT),
        .O(\USE_ROCKET_IO.TXCHARDISPMODE_reg ));
  LUT3 #(
    .INIT(8'h02)) 
    \USE_ROCKET_IO.TXCHARDISPVAL_i_1 
       (.I0(TXCHARDISPVAL),
        .I1(\USE_ROCKET_IO.MGT_TX_RESET_INT_reg ),
        .I2(CONFIGURATION_VECTOR_REG),
        .O(\USE_ROCKET_IO.TXCHARDISPVAL_reg ));
  (* SOFT_HLUTNM = "soft_lutpair22" *) 
  LUT3 #(
    .INIT(8'hB8)) 
    \USE_ROCKET_IO.TXCHARISK_i_1 
       (.I0(TX_EVEN),
        .I1(CONFIGURATION_VECTOR_REG),
        .I2(TXCHARISK_INT),
        .O(\USE_ROCKET_IO.TXCHARISK_reg ));
  (* SOFT_HLUTNM = "soft_lutpair26" *) 
  LUT3 #(
    .INIT(8'h02)) 
    \USE_ROCKET_IO.TXDATA[0]_i_1 
       (.I0(TXDATA[0]),
        .I1(\USE_ROCKET_IO.MGT_TX_RESET_INT_reg ),
        .I2(CONFIGURATION_VECTOR_REG),
        .O(D[0]));
  (* SOFT_HLUTNM = "soft_lutpair29" *) 
  LUT3 #(
    .INIT(8'h02)) 
    \USE_ROCKET_IO.TXDATA[1]_i_1 
       (.I0(TXDATA[1]),
        .I1(\USE_ROCKET_IO.MGT_TX_RESET_INT_reg ),
        .I2(CONFIGURATION_VECTOR_REG),
        .O(D[1]));
  (* SOFT_HLUTNM = "soft_lutpair26" *) 
  LUT3 #(
    .INIT(8'h02)) 
    \USE_ROCKET_IO.TXDATA[2]_i_1 
       (.I0(TXDATA[2]),
        .I1(\USE_ROCKET_IO.MGT_TX_RESET_INT_reg ),
        .I2(CONFIGURATION_VECTOR_REG),
        .O(\USE_ROCKET_IO.TXDATA_reg[2] ));
  (* SOFT_HLUTNM = "soft_lutpair25" *) 
  LUT3 #(
    .INIT(8'h02)) 
    \USE_ROCKET_IO.TXDATA[3]_i_1 
       (.I0(TXDATA[3]),
        .I1(\USE_ROCKET_IO.MGT_TX_RESET_INT_reg ),
        .I2(CONFIGURATION_VECTOR_REG),
        .O(\USE_ROCKET_IO.TXDATA_reg[3] ));
  (* SOFT_HLUTNM = "soft_lutpair31" *) 
  LUT3 #(
    .INIT(8'h32)) 
    \USE_ROCKET_IO.TXDATA[4]_i_1 
       (.I0(TXDATA[4]),
        .I1(\USE_ROCKET_IO.MGT_TX_RESET_INT_reg ),
        .I2(CONFIGURATION_VECTOR_REG),
        .O(D[2]));
  (* SOFT_HLUTNM = "soft_lutpair23" *) 
  LUT3 #(
    .INIT(8'h02)) 
    \USE_ROCKET_IO.TXDATA[5]_i_1 
       (.I0(TXDATA[5]),
        .I1(\USE_ROCKET_IO.MGT_TX_RESET_INT_reg ),
        .I2(CONFIGURATION_VECTOR_REG),
        .O(\USE_ROCKET_IO.TXDATA_reg[5] ));
  (* SOFT_HLUTNM = "soft_lutpair16" *) 
  LUT4 #(
    .INIT(16'h0704)) 
    \USE_ROCKET_IO.TXDATA[6]_i_1 
       (.I0(TX_EVEN),
        .I1(CONFIGURATION_VECTOR_REG),
        .I2(\USE_ROCKET_IO.MGT_TX_RESET_INT_reg ),
        .I3(TXDATA[6]),
        .O(D[3]));
  (* SOFT_HLUTNM = "soft_lutpair16" *) 
  LUT3 #(
    .INIT(8'h40)) 
    \USE_ROCKET_IO.TXDATA[7]_i_1 
       (.I0(\USE_ROCKET_IO.MGT_TX_RESET_INT_reg ),
        .I1(CONFIGURATION_VECTOR_REG),
        .I2(TX_EVEN),
        .O(\USE_ROCKET_IO.TXDATA_reg[2]_0 ));
  (* SOFT_HLUTNM = "soft_lutpair23" *) 
  LUT3 #(
    .INIT(8'h02)) 
    \USE_ROCKET_IO.TXDATA[7]_i_2 
       (.I0(TXDATA[7]),
        .I1(\USE_ROCKET_IO.MGT_TX_RESET_INT_reg ),
        .I2(CONFIGURATION_VECTOR_REG),
        .O(\USE_ROCKET_IO.TXDATA_reg[7] ));
  LUT4 #(
    .INIT(16'hF888)) 
    V_i_1
       (.I0(XMIT_DATA_INT_reg_n_0),
        .I1(V_i_2_n_0),
        .I2(S),
        .I3(V),
        .O(V_i_1_n_0));
  LUT6 #(
    .INIT(64'hEAEEEAEEEAEEEAAA)) 
    V_i_2
       (.I0(V_i_3_n_0),
        .I1(gmii_tx_er),
        .I2(TX_PACKET),
        .I3(gmii_tx_en),
        .I4(V_i_4_n_0),
        .I5(V_i_5_n_0),
        .O(V_i_2_n_0));
  LUT3 #(
    .INIT(8'h40)) 
    V_i_3
       (.I0(TX_PACKET),
        .I1(TX_EN_REG1),
        .I2(TX_ER_REG1),
        .O(V_i_3_n_0));
  LUT4 #(
    .INIT(16'hFFFE)) 
    V_i_4
       (.I0(gmii_txd[5]),
        .I1(gmii_txd[7]),
        .I2(gmii_txd[6]),
        .I3(gmii_txd[4]),
        .O(V_i_4_n_0));
  LUT4 #(
    .INIT(16'h7FFF)) 
    V_i_5
       (.I0(gmii_txd[2]),
        .I1(gmii_txd[1]),
        .I2(gmii_txd[0]),
        .I3(gmii_txd[3]),
        .O(V_i_5_n_0));
  FDRE V_reg
       (.C(userclk2),
        .CE(1'b1),
        .D(V_i_1_n_0),
        .Q(V),
        .R(\USE_ROCKET_IO.MGT_TX_RESET_INT_reg ));
  (* SOFT_HLUTNM = "soft_lutpair35" *) 
  LUT3 #(
    .INIT(8'hE0)) 
    XMIT_CONFIG_INT_i_1
       (.I0(TX_EVEN),
        .I1(\CODE_GRP_CNT_reg_n_0_[1] ),
        .I2(XMIT_CONFIG_INT),
        .O(XMIT_CONFIG_INT_i_1_n_0));
  FDSE XMIT_CONFIG_INT_reg
       (.C(userclk2),
        .CE(1'b1),
        .D(XMIT_CONFIG_INT_i_1_n_0),
        .Q(XMIT_CONFIG_INT),
        .S(\USE_ROCKET_IO.MGT_TX_RESET_INT_reg ));
  (* SOFT_HLUTNM = "soft_lutpair24" *) 
  LUT3 #(
    .INIT(8'hF1)) 
    XMIT_DATA_INT_i_1
       (.I0(TX_EVEN),
        .I1(\CODE_GRP_CNT_reg_n_0_[1] ),
        .I2(XMIT_DATA_INT_reg_n_0),
        .O(XMIT_DATA_INT_i_1_n_0));
  FDRE XMIT_DATA_INT_reg
       (.C(userclk2),
        .CE(1'b1),
        .D(XMIT_DATA_INT_i_1_n_0),
        .Q(XMIT_DATA_INT_reg_n_0),
        .R(\USE_ROCKET_IO.MGT_TX_RESET_INT_reg ));
endmodule

(* B_SHIFTER_ADDR = "8'b01010000" *) (* C_1588 = "0" *) (* C_COMPONENT_NAME = "GigEthGth7Core" *) 
(* C_DYNAMIC_SWITCHING = "FALSE" *) (* C_ELABORATION_TRANSIENT_DIR = "BlankString" *) (* C_FAMILY = "virtex7" *) 
(* C_HAS_AN = "FALSE" *) (* C_HAS_MDIO = "FALSE" *) (* C_HAS_TEMAC = "TRUE" *) 
(* C_IS_SGMII = "FALSE" *) (* C_SGMII_FABRIC_BUFFER = "TRUE" *) (* C_SGMII_PHY_MODE = "FALSE" *) 
(* C_USE_LVDS = "FALSE" *) (* C_USE_TBI = "FALSE" *) (* C_USE_TRANSCEIVER = "TRUE" *) 
(* GT_RX_BYTE_WIDTH = "1" *) (* ORIG_REF_NAME = "gig_ethernet_pcs_pma_v15_1_0" *) (* RX_GT_NOMINAL_LATENCY = "16'b0000000011010010" *) 
(* downgradeipidentifiedwarnings = "yes" *) 
module GigEthGth7Core_gig_ethernet_pcs_pma_v15_1_0
   (reset,
    signal_detect,
    link_timer_value,
    link_timer_basex,
    link_timer_sgmii,
    mgt_rx_reset,
    mgt_tx_reset,
    userclk,
    userclk2,
    dcm_locked,
    rxbufstatus,
    rxchariscomma,
    rxcharisk,
    rxclkcorcnt,
    rxdata,
    rxdisperr,
    rxnotintable,
    rxrundisp,
    txbuferr,
    powerdown,
    txchardispmode,
    txchardispval,
    txcharisk,
    txdata,
    enablealign,
    gtx_clk,
    tx_code_group,
    loc_ref,
    ewrap,
    rx_code_group0,
    rx_code_group1,
    pma_rx_clk0,
    pma_rx_clk1,
    en_cdet,
    gmii_txd,
    gmii_tx_en,
    gmii_tx_er,
    gmii_rxd,
    gmii_rx_dv,
    gmii_rx_er,
    gmii_isolate,
    an_interrupt,
    an_enable,
    speed_selection,
    phyad,
    mdc,
    mdio_in,
    mdio_out,
    mdio_tri,
    an_adv_config_vector,
    an_adv_config_val,
    an_restart_config,
    configuration_vector,
    configuration_valid,
    status_vector,
    basex_or_sgmii,
    drp_dclk,
    drp_req,
    drp_gnt,
    drp_den,
    drp_dwe,
    drp_drdy,
    drp_daddr,
    drp_di,
    drp_do,
    systemtimer_s_field,
    systemtimer_ns_field,
    correction_timer,
    rxrecclk,
    rxphy_s_field,
    rxphy_ns_field,
    rxphy_correction_timer,
    reset_done);
  input reset;
  input signal_detect;
  input [9:0]link_timer_value;
  input [9:0]link_timer_basex;
  input [9:0]link_timer_sgmii;
  output mgt_rx_reset;
  output mgt_tx_reset;
  input userclk;
  input userclk2;
  input dcm_locked;
  input [1:0]rxbufstatus;
  input [0:0]rxchariscomma;
  input [0:0]rxcharisk;
  input [2:0]rxclkcorcnt;
  input [7:0]rxdata;
  input [0:0]rxdisperr;
  input [0:0]rxnotintable;
  input [0:0]rxrundisp;
  input txbuferr;
  output powerdown;
  output txchardispmode;
  output txchardispval;
  output txcharisk;
  output [7:0]txdata;
  output enablealign;
  input gtx_clk;
  output [9:0]tx_code_group;
  output loc_ref;
  output ewrap;
  input [9:0]rx_code_group0;
  input [9:0]rx_code_group1;
  input pma_rx_clk0;
  input pma_rx_clk1;
  output en_cdet;
  input [7:0]gmii_txd;
  input gmii_tx_en;
  input gmii_tx_er;
  output [7:0]gmii_rxd;
  output gmii_rx_dv;
  output gmii_rx_er;
  output gmii_isolate;
  output an_interrupt;
  output an_enable;
  output [1:0]speed_selection;
  input [4:0]phyad;
  input mdc;
  input mdio_in;
  output mdio_out;
  output mdio_tri;
  input [15:0]an_adv_config_vector;
  input an_adv_config_val;
  input an_restart_config;
  input [4:0]configuration_vector;
  input configuration_valid;
  output [15:0]status_vector;
  input basex_or_sgmii;
  input drp_dclk;
  output drp_req;
  input drp_gnt;
  output drp_den;
  output drp_dwe;
  input drp_drdy;
  output [8:0]drp_daddr;
  output [15:0]drp_di;
  input [15:0]drp_do;
  input [47:0]systemtimer_s_field;
  input [31:0]systemtimer_ns_field;
  input [63:0]correction_timer;
  input rxrecclk;
  output [47:0]rxphy_s_field;
  output [31:0]rxphy_ns_field;
  output [63:0]rxphy_correction_timer;
  input reset_done;

  wire \<const0> ;
  wire \<const1> ;
  wire [4:0]configuration_vector;
  wire dcm_locked;
  wire enablealign;
  wire gmii_isolate;
  wire gmii_rx_dv;
  wire gmii_rx_er;
  wire [7:0]gmii_rxd;
  wire gmii_tx_en;
  wire gmii_tx_er;
  wire [7:0]gmii_txd;
  wire mgt_rx_reset;
  wire mgt_tx_reset;
  wire powerdown;
  wire reset;
  wire reset_done;
  wire [1:0]rxbufstatus;
  wire [0:0]rxchariscomma;
  wire [0:0]rxcharisk;
  wire [2:0]rxclkcorcnt;
  wire [7:0]rxdata;
  wire [0:0]rxdisperr;
  wire [0:0]rxnotintable;
  wire [0:0]rxrundisp;
  wire signal_detect;
  wire [6:0]\^status_vector ;
  wire txbuferr;
  wire txchardispmode;
  wire txchardispval;
  wire txcharisk;
  wire [7:0]txdata;
  wire userclk;
  wire userclk2;

  assign an_enable = \<const0> ;
  assign an_interrupt = \<const0> ;
  assign drp_daddr[8] = \<const0> ;
  assign drp_daddr[7] = \<const0> ;
  assign drp_daddr[6] = \<const0> ;
  assign drp_daddr[5] = \<const0> ;
  assign drp_daddr[4] = \<const0> ;
  assign drp_daddr[3] = \<const0> ;
  assign drp_daddr[2] = \<const0> ;
  assign drp_daddr[1] = \<const0> ;
  assign drp_daddr[0] = \<const0> ;
  assign drp_den = \<const0> ;
  assign drp_di[15] = \<const0> ;
  assign drp_di[14] = \<const0> ;
  assign drp_di[13] = \<const0> ;
  assign drp_di[12] = \<const0> ;
  assign drp_di[11] = \<const0> ;
  assign drp_di[10] = \<const0> ;
  assign drp_di[9] = \<const0> ;
  assign drp_di[8] = \<const0> ;
  assign drp_di[7] = \<const0> ;
  assign drp_di[6] = \<const0> ;
  assign drp_di[5] = \<const0> ;
  assign drp_di[4] = \<const0> ;
  assign drp_di[3] = \<const0> ;
  assign drp_di[2] = \<const0> ;
  assign drp_di[1] = \<const0> ;
  assign drp_di[0] = \<const0> ;
  assign drp_dwe = \<const0> ;
  assign drp_req = \<const0> ;
  assign en_cdet = \<const0> ;
  assign ewrap = \<const0> ;
  assign loc_ref = \<const0> ;
  assign mdio_out = \<const1> ;
  assign mdio_tri = \<const1> ;
  assign rxphy_correction_timer[63] = \<const0> ;
  assign rxphy_correction_timer[62] = \<const0> ;
  assign rxphy_correction_timer[61] = \<const0> ;
  assign rxphy_correction_timer[60] = \<const0> ;
  assign rxphy_correction_timer[59] = \<const0> ;
  assign rxphy_correction_timer[58] = \<const0> ;
  assign rxphy_correction_timer[57] = \<const0> ;
  assign rxphy_correction_timer[56] = \<const0> ;
  assign rxphy_correction_timer[55] = \<const0> ;
  assign rxphy_correction_timer[54] = \<const0> ;
  assign rxphy_correction_timer[53] = \<const0> ;
  assign rxphy_correction_timer[52] = \<const0> ;
  assign rxphy_correction_timer[51] = \<const0> ;
  assign rxphy_correction_timer[50] = \<const0> ;
  assign rxphy_correction_timer[49] = \<const0> ;
  assign rxphy_correction_timer[48] = \<const0> ;
  assign rxphy_correction_timer[47] = \<const0> ;
  assign rxphy_correction_timer[46] = \<const0> ;
  assign rxphy_correction_timer[45] = \<const0> ;
  assign rxphy_correction_timer[44] = \<const0> ;
  assign rxphy_correction_timer[43] = \<const0> ;
  assign rxphy_correction_timer[42] = \<const0> ;
  assign rxphy_correction_timer[41] = \<const0> ;
  assign rxphy_correction_timer[40] = \<const0> ;
  assign rxphy_correction_timer[39] = \<const0> ;
  assign rxphy_correction_timer[38] = \<const0> ;
  assign rxphy_correction_timer[37] = \<const0> ;
  assign rxphy_correction_timer[36] = \<const0> ;
  assign rxphy_correction_timer[35] = \<const0> ;
  assign rxphy_correction_timer[34] = \<const0> ;
  assign rxphy_correction_timer[33] = \<const0> ;
  assign rxphy_correction_timer[32] = \<const0> ;
  assign rxphy_correction_timer[31] = \<const0> ;
  assign rxphy_correction_timer[30] = \<const0> ;
  assign rxphy_correction_timer[29] = \<const0> ;
  assign rxphy_correction_timer[28] = \<const0> ;
  assign rxphy_correction_timer[27] = \<const0> ;
  assign rxphy_correction_timer[26] = \<const0> ;
  assign rxphy_correction_timer[25] = \<const0> ;
  assign rxphy_correction_timer[24] = \<const0> ;
  assign rxphy_correction_timer[23] = \<const0> ;
  assign rxphy_correction_timer[22] = \<const0> ;
  assign rxphy_correction_timer[21] = \<const0> ;
  assign rxphy_correction_timer[20] = \<const0> ;
  assign rxphy_correction_timer[19] = \<const0> ;
  assign rxphy_correction_timer[18] = \<const0> ;
  assign rxphy_correction_timer[17] = \<const0> ;
  assign rxphy_correction_timer[16] = \<const0> ;
  assign rxphy_correction_timer[15] = \<const0> ;
  assign rxphy_correction_timer[14] = \<const0> ;
  assign rxphy_correction_timer[13] = \<const0> ;
  assign rxphy_correction_timer[12] = \<const0> ;
  assign rxphy_correction_timer[11] = \<const0> ;
  assign rxphy_correction_timer[10] = \<const0> ;
  assign rxphy_correction_timer[9] = \<const0> ;
  assign rxphy_correction_timer[8] = \<const0> ;
  assign rxphy_correction_timer[7] = \<const0> ;
  assign rxphy_correction_timer[6] = \<const0> ;
  assign rxphy_correction_timer[5] = \<const0> ;
  assign rxphy_correction_timer[4] = \<const0> ;
  assign rxphy_correction_timer[3] = \<const0> ;
  assign rxphy_correction_timer[2] = \<const0> ;
  assign rxphy_correction_timer[1] = \<const0> ;
  assign rxphy_correction_timer[0] = \<const0> ;
  assign rxphy_ns_field[31] = \<const0> ;
  assign rxphy_ns_field[30] = \<const0> ;
  assign rxphy_ns_field[29] = \<const0> ;
  assign rxphy_ns_field[28] = \<const0> ;
  assign rxphy_ns_field[27] = \<const0> ;
  assign rxphy_ns_field[26] = \<const0> ;
  assign rxphy_ns_field[25] = \<const0> ;
  assign rxphy_ns_field[24] = \<const0> ;
  assign rxphy_ns_field[23] = \<const0> ;
  assign rxphy_ns_field[22] = \<const0> ;
  assign rxphy_ns_field[21] = \<const0> ;
  assign rxphy_ns_field[20] = \<const0> ;
  assign rxphy_ns_field[19] = \<const0> ;
  assign rxphy_ns_field[18] = \<const0> ;
  assign rxphy_ns_field[17] = \<const0> ;
  assign rxphy_ns_field[16] = \<const0> ;
  assign rxphy_ns_field[15] = \<const0> ;
  assign rxphy_ns_field[14] = \<const0> ;
  assign rxphy_ns_field[13] = \<const0> ;
  assign rxphy_ns_field[12] = \<const0> ;
  assign rxphy_ns_field[11] = \<const0> ;
  assign rxphy_ns_field[10] = \<const0> ;
  assign rxphy_ns_field[9] = \<const0> ;
  assign rxphy_ns_field[8] = \<const0> ;
  assign rxphy_ns_field[7] = \<const0> ;
  assign rxphy_ns_field[6] = \<const0> ;
  assign rxphy_ns_field[5] = \<const0> ;
  assign rxphy_ns_field[4] = \<const0> ;
  assign rxphy_ns_field[3] = \<const0> ;
  assign rxphy_ns_field[2] = \<const0> ;
  assign rxphy_ns_field[1] = \<const0> ;
  assign rxphy_ns_field[0] = \<const0> ;
  assign rxphy_s_field[47] = \<const0> ;
  assign rxphy_s_field[46] = \<const0> ;
  assign rxphy_s_field[45] = \<const0> ;
  assign rxphy_s_field[44] = \<const0> ;
  assign rxphy_s_field[43] = \<const0> ;
  assign rxphy_s_field[42] = \<const0> ;
  assign rxphy_s_field[41] = \<const0> ;
  assign rxphy_s_field[40] = \<const0> ;
  assign rxphy_s_field[39] = \<const0> ;
  assign rxphy_s_field[38] = \<const0> ;
  assign rxphy_s_field[37] = \<const0> ;
  assign rxphy_s_field[36] = \<const0> ;
  assign rxphy_s_field[35] = \<const0> ;
  assign rxphy_s_field[34] = \<const0> ;
  assign rxphy_s_field[33] = \<const0> ;
  assign rxphy_s_field[32] = \<const0> ;
  assign rxphy_s_field[31] = \<const0> ;
  assign rxphy_s_field[30] = \<const0> ;
  assign rxphy_s_field[29] = \<const0> ;
  assign rxphy_s_field[28] = \<const0> ;
  assign rxphy_s_field[27] = \<const0> ;
  assign rxphy_s_field[26] = \<const0> ;
  assign rxphy_s_field[25] = \<const0> ;
  assign rxphy_s_field[24] = \<const0> ;
  assign rxphy_s_field[23] = \<const0> ;
  assign rxphy_s_field[22] = \<const0> ;
  assign rxphy_s_field[21] = \<const0> ;
  assign rxphy_s_field[20] = \<const0> ;
  assign rxphy_s_field[19] = \<const0> ;
  assign rxphy_s_field[18] = \<const0> ;
  assign rxphy_s_field[17] = \<const0> ;
  assign rxphy_s_field[16] = \<const0> ;
  assign rxphy_s_field[15] = \<const0> ;
  assign rxphy_s_field[14] = \<const0> ;
  assign rxphy_s_field[13] = \<const0> ;
  assign rxphy_s_field[12] = \<const0> ;
  assign rxphy_s_field[11] = \<const0> ;
  assign rxphy_s_field[10] = \<const0> ;
  assign rxphy_s_field[9] = \<const0> ;
  assign rxphy_s_field[8] = \<const0> ;
  assign rxphy_s_field[7] = \<const0> ;
  assign rxphy_s_field[6] = \<const0> ;
  assign rxphy_s_field[5] = \<const0> ;
  assign rxphy_s_field[4] = \<const0> ;
  assign rxphy_s_field[3] = \<const0> ;
  assign rxphy_s_field[2] = \<const0> ;
  assign rxphy_s_field[1] = \<const0> ;
  assign rxphy_s_field[0] = \<const0> ;
  assign speed_selection[1] = \<const1> ;
  assign speed_selection[0] = \<const0> ;
  assign status_vector[15] = \<const0> ;
  assign status_vector[14] = \<const0> ;
  assign status_vector[13] = \<const0> ;
  assign status_vector[12] = \<const0> ;
  assign status_vector[11] = \<const0> ;
  assign status_vector[10] = \<const0> ;
  assign status_vector[9] = \<const0> ;
  assign status_vector[8] = \<const0> ;
  assign status_vector[7] = \<const0> ;
  assign status_vector[6:0] = \^status_vector [6:0];
  assign tx_code_group[9] = \<const0> ;
  assign tx_code_group[8] = \<const0> ;
  assign tx_code_group[7] = \<const0> ;
  assign tx_code_group[6] = \<const0> ;
  assign tx_code_group[5] = \<const0> ;
  assign tx_code_group[4] = \<const0> ;
  assign tx_code_group[3] = \<const0> ;
  assign tx_code_group[2] = \<const0> ;
  assign tx_code_group[1] = \<const0> ;
  assign tx_code_group[0] = \<const0> ;
  GND GND
       (.G(\<const0> ));
  VCC VCC
       (.P(\<const1> ));
  GigEthGth7Core_GPCS_PMA_GEN gpcs_pma_inst
       (.MGT_RX_RESET(mgt_rx_reset),
        .MGT_TX_RESET(mgt_tx_reset),
        .configuration_vector(configuration_vector[3:1]),
        .dcm_locked(dcm_locked),
        .enablealign(enablealign),
        .gmii_isolate(gmii_isolate),
        .gmii_rx_dv(gmii_rx_dv),
        .gmii_rx_er(gmii_rx_er),
        .gmii_rxd(gmii_rxd),
        .gmii_tx_en(gmii_tx_en),
        .gmii_tx_er(gmii_tx_er),
        .gmii_txd(gmii_txd),
        .reset(reset),
        .reset_done(reset_done),
        .rxbufstatus(rxbufstatus[1]),
        .rxchariscomma(rxchariscomma),
        .rxcharisk(rxcharisk),
        .rxclkcorcnt(rxclkcorcnt),
        .rxdata(rxdata),
        .rxdisperr(rxdisperr),
        .rxnotintable(rxnotintable),
        .rxpowerdown_reg_reg(powerdown),
        .signal_detect(signal_detect),
        .status_vector(\^status_vector ),
        .txbuferr(txbuferr),
        .txchardispmode(txchardispmode),
        .txchardispval(txchardispval),
        .txcharisk(txcharisk),
        .txdata(txdata),
        .userclk(userclk),
        .userclk2(userclk2));
endmodule

(* ORIG_REF_NAME = "reset_sync_block" *) 
module GigEthGth7Core_reset_sync_block
   (\MGT_RESET.RESET_INT_PIPE_reg ,
    dcm_locked,
    userclk,
    reset);
  output \MGT_RESET.RESET_INT_PIPE_reg ;
  input dcm_locked;
  input userclk;
  input reset;

  wire \MGT_RESET.RESET_INT_PIPE_reg ;
  wire dcm_locked;
  wire reset;
  wire reset_out;
  wire reset_sync_reg1;
  wire reset_sync_reg2;
  wire reset_sync_reg3;
  wire reset_sync_reg4;
  wire reset_sync_reg5;
  wire userclk;

  LUT2 #(
    .INIT(4'hB)) 
    \MGT_RESET.RESET_INT_PIPE_i_1 
       (.I0(reset_out),
        .I1(dcm_locked),
        .O(\MGT_RESET.RESET_INT_PIPE_reg ));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FDP" *) 
  (* box_type = "PRIMITIVE" *) 
  FDPE #(
    .INIT(1'b1)) 
    reset_sync1
       (.C(userclk),
        .CE(1'b1),
        .D(1'b0),
        .PRE(reset),
        .Q(reset_sync_reg1));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FDP" *) 
  (* box_type = "PRIMITIVE" *) 
  FDPE #(
    .INIT(1'b1)) 
    reset_sync2
       (.C(userclk),
        .CE(1'b1),
        .D(reset_sync_reg1),
        .PRE(reset),
        .Q(reset_sync_reg2));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FDP" *) 
  (* box_type = "PRIMITIVE" *) 
  FDPE #(
    .INIT(1'b1)) 
    reset_sync3
       (.C(userclk),
        .CE(1'b1),
        .D(reset_sync_reg2),
        .PRE(reset),
        .Q(reset_sync_reg3));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FDP" *) 
  (* box_type = "PRIMITIVE" *) 
  FDPE #(
    .INIT(1'b1)) 
    reset_sync4
       (.C(userclk),
        .CE(1'b1),
        .D(reset_sync_reg3),
        .PRE(reset),
        .Q(reset_sync_reg4));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FDP" *) 
  (* box_type = "PRIMITIVE" *) 
  FDPE #(
    .INIT(1'b1)) 
    reset_sync5
       (.C(userclk),
        .CE(1'b1),
        .D(reset_sync_reg4),
        .PRE(reset),
        .Q(reset_sync_reg5));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FDP" *) 
  (* box_type = "PRIMITIVE" *) 
  FDPE #(
    .INIT(1'b1)) 
    reset_sync6
       (.C(userclk),
        .CE(1'b1),
        .D(reset_sync_reg5),
        .PRE(1'b0),
        .Q(reset_out));
endmodule

(* ORIG_REF_NAME = "sync_block" *) 
module GigEthGth7Core_sync_block
   (SIGNAL_DETECT_MOD,
    \NO_MANAGEMENT.CONFIGURATION_VECTOR_REG_reg[2] ,
    signal_detect,
    userclk2);
  output SIGNAL_DETECT_MOD;
  input \NO_MANAGEMENT.CONFIGURATION_VECTOR_REG_reg[2] ;
  input signal_detect;
  input userclk2;

  wire \NO_MANAGEMENT.CONFIGURATION_VECTOR_REG_reg[2] ;
  wire SIGNAL_DETECT_MOD;
  wire data_out;
  wire data_sync1;
  wire data_sync2;
  wire data_sync3;
  wire data_sync4;
  wire data_sync5;
  wire signal_detect;
  wire userclk2;

  LUT2 #(
    .INIT(4'h2)) 
    SIGNAL_DETECT_REG_i_1
       (.I0(data_out),
        .I1(\NO_MANAGEMENT.CONFIGURATION_VECTOR_REG_reg[2] ),
        .O(SIGNAL_DETECT_MOD));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FD" *) 
  (* box_type = "PRIMITIVE" *) 
  FDRE #(
    .INIT(1'b0)) 
    data_sync_reg1
       (.C(userclk2),
        .CE(1'b1),
        .D(signal_detect),
        .Q(data_sync1),
        .R(1'b0));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FD" *) 
  (* box_type = "PRIMITIVE" *) 
  FDRE #(
    .INIT(1'b0)) 
    data_sync_reg2
       (.C(userclk2),
        .CE(1'b1),
        .D(data_sync1),
        .Q(data_sync2),
        .R(1'b0));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FD" *) 
  (* box_type = "PRIMITIVE" *) 
  FDRE #(
    .INIT(1'b0)) 
    data_sync_reg3
       (.C(userclk2),
        .CE(1'b1),
        .D(data_sync2),
        .Q(data_sync3),
        .R(1'b0));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FD" *) 
  (* box_type = "PRIMITIVE" *) 
  FDRE #(
    .INIT(1'b0)) 
    data_sync_reg4
       (.C(userclk2),
        .CE(1'b1),
        .D(data_sync3),
        .Q(data_sync4),
        .R(1'b0));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FD" *) 
  (* box_type = "PRIMITIVE" *) 
  FDRE #(
    .INIT(1'b0)) 
    data_sync_reg5
       (.C(userclk2),
        .CE(1'b1),
        .D(data_sync4),
        .Q(data_sync5),
        .R(1'b0));
  (* ASYNC_REG *) 
  (* SHREG_EXTRACT = "no" *) 
  (* XILINX_LEGACY_PRIM = "FD" *) 
  (* box_type = "PRIMITIVE" *) 
  FDRE #(
    .INIT(1'b0)) 
    data_sync_reg6
       (.C(userclk2),
        .CE(1'b1),
        .D(data_sync5),
        .Q(data_out),
        .R(1'b0));
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
