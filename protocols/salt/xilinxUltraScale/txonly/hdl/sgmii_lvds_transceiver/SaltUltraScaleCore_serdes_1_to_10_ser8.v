
//////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2013 Xilinx, Inc.
// This design is confidential and proprietary of Xilinx, All Rights Reserved.
//////////////////////////////////////////////////////////////////////////////
//   ____  ____
//  /   /\/   /
// /___/  \  /   Vendor: Xilinx
// \   \   \/    Version: 1.0
//  \   \        Filename: SaltUltraScaleCore_serdes_1_to_10_ser8.v
//  /   /        Date Last Modified:  February 11th 2014
// /___/   /\    Date Created : November 5th 2013
// \   \  /  \
//  \___\/\___\
// 
//Device: 	Ultrascale
//Purpose:  	1 to 10 synchronous receiver 
//
//Reference:
//    
//Revision History:
//    Rev 1.0 - First created (nicks)
//
//////////////////////////////////////////////////////////////////////////////
//
//  Disclaimer: 
//
//		This disclaimer is not a license and does not grant any rights to the materials 
//              distributed herewith. Except as otherwise provided in a valid license issued to you 
//              by Xilinx, and to the maximum extent permitted by applicable law: 
//              [1] THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND WITH ALL FAULTS, 
//              AND XILINX HEREBY DISCLAIMS ALL WARRANTIES AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, 
//              INCLUDING BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-INFRINGEMENT, OR 
//              FITNESS FOR ANY PARTICULAR PURPOSE; and [2] Xilinx shall not be liable (whether in contract 
//              or tort, including negligence, or under any other theory of liability) for any loss or damage 
//              of any kind or nature related to, arising under or in connection with these materials, 
//              including for any direct, or any indirect, special, incidental, or consequential loss 
//              or damage (including loss of data, profits, goodwill, or any type of loss or damage suffered 
//              as a result of any action brought by a third party) even if such damage or loss was 
//              reasonably foreseeable or Xilinx had been advised of the possibility of the same.
//
//  Critical Applications:
//
//		Xilinx products are not designed or intended to be fail-safe, or for use in any application 
//		requiring fail-safe performance, such as life-support or safety devices or systems, 
//		Class III medical devices, nuclear facilities, applications related to the deployment of airbags,
//		or any other applications that could lead to death, personal injury, or severe property or 
//		environmental damage (individually and collectively, "Critical Applications"). Customer assumes 
//		the sole risk and liability of any use of Xilinx products in Critical Applications, subject only 
//		to applicable laws and regulations governing limitations on product liability.
//
//  THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS PART OF THIS FILE AT ALL TIMES.
//
//////////////////////////////////////////////////////////////////////////////
`timescale 1 ps/1 ps
module SaltUltraScaleCore_serdes_1_to_10_ser8 (datain_p, datain_n, rxclk, rxclk_div4, rxclk_div10, idelay_rdy, reset, rx_data, al_rx_data, comma, debug_in, debug, dummy_out, results, m_delay_1hot) ;

parameter real      	REF_FREQ = 625 ;   		// Parameter to set reference frequency in MHz used by idelay controller
parameter       	BIT_TIME = 800 ;   		// Parameter to set the input bit time in pS
                                  	                                   
input			datain_p ;			// Input from LVDS receiver pin
input			datain_n ;			// Input from LVDS receiver pin
input			rxclk ;				// Sampling clock = 625 MHz for SGMII
input			rxclk_div4 ;			// Sampling clock divided by 2 = 312.5 MHz for SGMII
input			rxclk_div10 ;			// Sampling clock divided by 5 = 125 MHz for SGMII
input			idelay_rdy ;			// High when input delays are ready
input			reset ;				// Asynchrnous reset line
output		[9:0]	rx_data ;			// Output data synchronous to rxclk_div10
output 	reg	[9:0]	al_rx_data ;			// Aligned output data synchronous to rxclk_div10
output	reg		comma ; 			// comma received
input		[6:0]	debug_in ;			// debug input bus, default to 7'b0010000	
output		[45:0]	debug ;				// Debug output bus
output			dummy_out ;
output		[127:0]	results ;			// eye monitor result data	
output		[127:0]	m_delay_1hot ;			// Master delay control value as a one-hot vector
  		
wire	[7:0]		serdesm ;
wire	[7:0]		serdess ;
wire	[8:0]		m_delay_val_in ;
wire	[8:0]		s_delay_val_in ;
wire	[8:0]		m_delay_val_out ;
wire	[8:0]		s_delay_val_out ;
wire			rx_data_in_p ;
wire			rx_data_in_n ;
wire			rx_data_in_m ;
wire			rx_data_in_s ;
wire			rx_data_in_md ;
wire			rx_data_in_sd ;
wire	[3:0]		mdataout ;
wire	[3:0]		mdataoutd ;		
wire	[3:0]		sdataout ;
wire			not_rxclk ;
wire	[6:0]		bt_val ;
wire	[1:0]		hreg ;
wire			local_reset ;
wire			reset_sync ;
reg	[3:0]		mpx ;
reg	[19:0]		rxdh ;
wire	[9:0]		hdataout ;
wire			rxclk_d ;
wire	[8:0]		bt_val_raw ;
reg	[8:0]		bt_val_rawa ;
wire			mload ;
wire			sload ;
reg	[8:0]		count_in ;
wire			rxclk_int ;
reg			rxclk_r ;
reg			rxclk_rd ;
reg	[3:0]		small_count ;
reg			phase ;
reg	[8:0]		temp ;
wire reset_n_idelay_rdy;
assign debug = {rxclk_r, ~serdess, serdesm, sload, mload, s_delay_val_out, m_delay_val_out, bt_val_rawa} ;
//                45       44:37    36:29    28      27        26:18             17:9           8:0
//bit_time_value <= bt_val ;
assign not_rxclk = ~rxclk ;
assign reset_n_idelay_rdy = reset || (~idelay_rdy);

  SaltUltraScaleCore_reset_sync reset_sync_rxclk_div4 (
     .clk       (rxclk_div4),
     .reset_in  (reset_n_idelay_rdy),
     .reset_out (local_reset)
  );
  SaltUltraScaleCore_reset_sync reset_rxclk_div4 (
     .clk       (rxclk_div4),
     .reset_in  (reset),
     .reset_out (reset_sync)
  );

//always @ (posedge rxclk_div4 or posedge reset) begin				// generate local reset
//if (reset == 1'b1) begin
//	local_reset <= 1'b1 ;
//end
//else begin
//	local_reset <= ~idelay_rdy ;
//end
//end

assign rx_data = hdataout ;

always @ (posedge rxclk_div10) begin                                                                                       // Look for a K28.1 or K28.5 comma character to setup the mux for aligned output
	rxdh <= {hdataout, rxdh[19:10]} ;
	if      ((rxdh[9:0]  == 10'b1001111100) || (rxdh[9:0]  == 10'b0110000011) || (rxdh[9:0]  == 10'b0101111100) || (rxdh[9:0]  == 10'b1010000011)) begin mpx <= 4'h0 ; comma <= 1'b1 ; end
	else if ((rxdh[10:1] == 10'b1001111100) || (rxdh[10:1] == 10'b0110000011) || (rxdh[10:1] == 10'b0101111100) || (rxdh[10:1] == 10'b1010000011)) begin mpx <= 4'h1 ; comma <= 1'b1 ; end
	else if ((rxdh[11:2] == 10'b1001111100) || (rxdh[11:2] == 10'b0110000011) || (rxdh[11:2] == 10'b0101111100) || (rxdh[11:2] == 10'b1010000011)) begin mpx <= 4'h2 ; comma <= 1'b1 ; end
	else if ((rxdh[12:3] == 10'b1001111100) || (rxdh[12:3] == 10'b0110000011) || (rxdh[12:3] == 10'b0101111100) || (rxdh[12:3] == 10'b1010000011)) begin mpx <= 4'h3 ; comma <= 1'b1 ; end
	else if ((rxdh[13:4] == 10'b1001111100) || (rxdh[13:4] == 10'b0110000011) || (rxdh[13:4] == 10'b0101111100) || (rxdh[13:4] == 10'b1010000011)) begin mpx <= 4'h4 ; comma <= 1'b1 ; end
	else if ((rxdh[14:5] == 10'b1001111100) || (rxdh[14:5] == 10'b0110000011) || (rxdh[14:5] == 10'b0101111100) || (rxdh[14:5] == 10'b1010000011)) begin mpx <= 4'h5 ; comma <= 1'b1 ; end
	else if ((rxdh[15:6] == 10'b1001111100) || (rxdh[15:6] == 10'b0110000011) || (rxdh[15:6] == 10'b0101111100) || (rxdh[15:6] == 10'b1010000011)) begin mpx <= 4'h6 ; comma <= 1'b1 ; end
	else if ((rxdh[16:7] == 10'b1001111100) || (rxdh[16:7] == 10'b0110000011) || (rxdh[16:7] == 10'b0101111100) || (rxdh[16:7] == 10'b1010000011)) begin mpx <= 4'h7 ; comma <= 1'b1 ; end
	else if ((rxdh[17:8] == 10'b1001111100) || (rxdh[17:8] == 10'b0110000011) || (rxdh[17:8] == 10'b0101111100) || (rxdh[17:8] == 10'b1010000011)) begin mpx <= 4'h8 ; comma <= 1'b1 ; end
	else if ((rxdh[18:9] == 10'b1001111100) || (rxdh[18:9] == 10'b0110000011) || (rxdh[18:9] == 10'b0101111100) || (rxdh[18:9] == 10'b1010000011)) begin mpx <= 4'h9 ; comma <= 1'b1 ; end
	else begin comma <= 1'b0 ; end
	case (mpx) 									// route data through the mux
		4'h0 :   begin al_rx_data <= rxdh[9:0]  ; end
		4'h1 :   begin al_rx_data <= rxdh[10:1] ; end
		4'h2 :   begin al_rx_data <= rxdh[11:2] ; end
		4'h3 :   begin al_rx_data <= rxdh[12:3] ; end
		4'h4 :   begin al_rx_data <= rxdh[13:4] ; end
		4'h5 :   begin al_rx_data <= rxdh[14:5] ; end
		4'h6 :   begin al_rx_data <= rxdh[15:6] ; end
		4'h7 :   begin al_rx_data <= rxdh[16:7] ; end
		4'h8 :   begin al_rx_data <= rxdh[17:8] ; end
		default: begin al_rx_data <= rxdh[18:9] ; end
	endcase
end

SaltUltraScaleCore_delay_controller_wrap # (
	.S 			(4))
dc_inst (                       
	.m_datain		(mdataout),
	.s_datain		(sdataout),
	.enable_phase_detector	(1'b1),
	.enable_monitor		(1'b0),
	.reset			(local_reset),
	.clk			(rxclk_div4),
	.c_delay_in		({1'b0, bt_val[6:1], 2'h0}),
	.m_delay_out		(m_delay_val_in),
	.mload			(mload),
	.s_delay_out		(s_delay_val_in),
	.sload			(sload),
	.data_out		(mdataoutd),
	.bt_val			(bt_val),
	.results		(results),
	.m_delay_1hot		(m_delay_1hot)) ;

SaltUltraScaleCore_gearbox_4_to_10 # (
	.D			(1))
gb0 (                   	
	.input_clock		(rxclk_div4),
	.output_clock		(rxclk_div10),
	.datain			(mdataoutd),
	.reset			(local_reset),
	.slip_bits 		(4'h0),
	.dataout		(hdataout)) ;
	
IBUFDS_DIFF_OUT #(
	.IBUF_LOW_PWR 		("FALSE")) 
data_in (                       
	.I    			(datain_p),
	.IB       		(datain_n),
	.O         		(rx_data_in_p),
	.OB         		(rx_data_in_n));

assign rx_data_in_m = rx_data_in_p ;
assign rx_data_in_s = rx_data_in_n ;

IDELAYE3 #(
      	.DELAY_FORMAT		("COUNT"),    
      	.SIM_DEVICE		("ULTRASCALE"),    
      	.DELAY_VALUE		(0),
      	.REFCLK_FREQUENCY	(REF_FREQ/2),
      	.CASCADE 		("NONE"),
      	.DELAY_SRC		("IDATAIN"),
      	.DELAY_TYPE		("VAR_LOAD"))
idelay_m(                       
	.DATAOUT		(rx_data_in_md),
	.CLK			(rxclk_div4),
	.CE			(1'b0),
	.INC			(1'b0),
	.DATAIN			(1'b0),
	.IDATAIN		(rx_data_in_m),
	.LOAD			(mload),
	.RST			(reset_sync),
	.EN_VTC			(1'b0),
	.CASC_IN		(1'b0),
	.CASC_RETURN		(1'b0),
	.CASC_OUT		(),
	.CNTVALUEIN		(m_delay_val_in),
	.CNTVALUEOUT		(m_delay_val_out));
    		
ISERDESE3 #(
	.DATA_WIDTH     	(4), 			
	.FIFO_ENABLE    	("FALSE"), 		
	.FIFO_SYNC_MODE 	("FALSE")) 	
iserdes_m (                     
	.D       		(rx_data_in_md),
	.CLK	   		(rxclk),
	.CLK_B    		(not_rxclk),
	.RST     		(local_reset),
	.FIFO_RD_CLK		(1'b0),
	.FIFO_RD_EN		(1'b0),
	.FIFO_EMPTY		(),
	.CLKDIV  		(rxclk_div4),
	.Q  			(serdesm));

assign mdataout = serdesm[3:0] ;

IDELAYE3 #(
      	.DELAY_FORMAT		("COUNT"),    
      	.SIM_DEVICE		("ULTRASCALE"),    
      	.DELAY_VALUE		(0),
	      .REFCLK_FREQUENCY	(REF_FREQ/2),
      	.CASCADE 		("NONE"),
      	.DELAY_SRC		("IDATAIN"),
      	.DELAY_TYPE		("VAR_LOAD"))
idelay_s(                
	.DATAOUT		(rx_data_in_sd),
	.CLK			(rxclk_div4),
	.CE			(1'b0),
	.INC			(1'b0),
	.DATAIN			(1'b0),
	.IDATAIN		(rx_data_in_s),
	.LOAD			(sload),
	.RST			(reset_sync),
	.EN_VTC			(1'b0),
	.CASC_IN		(1'b0),
	.CASC_RETURN		(1'b0),
	.CASC_OUT		(),
	.CNTVALUEIN		(s_delay_val_in),
	.CNTVALUEOUT		(s_delay_val_out));
	
ISERDESE3 #(
	.DATA_WIDTH     	(4), 			
	.FIFO_ENABLE    	("FALSE"),      		
	.FIFO_SYNC_MODE 	("FALSE"))      	
iserdes_s (                      
	.D       		(rx_data_in_sd),
	.CLK	   		(rxclk),
	.CLK_B    		(not_rxclk),
	.RST     		(local_reset),
	.CLKDIV  		(rxclk_div4),
	.FIFO_RD_CLK		(1'b0),
	.FIFO_RD_EN		(1'b0),
	.FIFO_EMPTY		(),
	.Q  			(serdess));

assign sdataout = ~serdess[3:0] ;

ODELAYE3  #(					// reference delay block set for 800 pS
      	.DELAY_VALUE		(BIT_TIME),
      	.DELAY_FORMAT		("TIME"),
	.REFCLK_FREQUENCY	(REF_FREQ/2),
	.CASCADE 		("NONE"),
      	.DELAY_TYPE		("FIXED"))
odelay_cal(                       
	.DATAOUT		(dummy_out),
	.CLK			(rxclk_div4),
	.CE			(1'b0),
	.INC			(1'b0),
	.ODATAIN		(local_reset),
	.LOAD			(1'b0),
	.RST			(1'b0), //local_reset),
	.EN_VTC			(1'b1),
	.CASC_IN		(1'b0),
	.CASC_RETURN		(1'b0),
	.CASC_OUT		(),
	.CNTVALUEIN		(9'h000),
	.CNTVALUEOUT		(bt_val_raw));
	
assign bt_val = bt_val_rawa[8:2] ;
//assign bt_val_raw = 9'h0A0 ;

IDELAYE3 #(
      	.DELAY_FORMAT		("COUNT"),
      	.SIM_DEVICE		("ULTRASCALE"),    
      	.DELAY_VALUE		(0),
      	.REFCLK_FREQUENCY	(REF_FREQ/2),
	      .CASCADE 		("NONE"),
      	.DELAY_SRC		("DATAIN"),
      	.DELAY_TYPE		("VAR_LOAD"))
idelay_cal(                
	.DATAOUT		(rxclk_int),
	.CLK			(rxclk_div4),
	.CE			(1'b0),
	.INC			(1'b0),
	.DATAIN			(rxclk),
	.IDATAIN		(1'b0),
	.LOAD			(1'b1),
	.RST			(reset_sync),
	.EN_VTC			(1'b0),
	.CASC_IN		(1'b0),
	.CASC_RETURN		(1'b0),
	.CASC_OUT		(),
	.CNTVALUEIN		(count_in),
	.CNTVALUEOUT		());

always @ (posedge rxclk_div4) begin	
	if (local_reset == 1'b1) begin
		count_in <= 9'h000 ;
		small_count <= 4'h0 ;
		phase <= 1'b0 ;
		bt_val_rawa <= 9'h0A0 ;
		phase <= 1'b0 ;
	end
	else begin
		rxclk_r <= rxclk_int ;
		small_count <= small_count + 4'h1 ;
		if (small_count == 4'hF) begin
			rxclk_rd <= rxclk_r ;
			if (phase == 1'b0) begin
				if ((count_in > 9'h008) && (rxclk_rd != rxclk_r)) begin 
					phase <= 1'b1 ; temp <= count_in ; count_in <= count_in + 9'h010 ; 
				end
				else begin
					count_in <= count_in + 9'h001 ; 
				end
			end
			else begin
			 	if (rxclk_rd != rxclk_r) begin 
					phase <= 1'b0 ; bt_val_rawa <= count_in - temp ; count_in <= 9'h000 ; 
				end
				else begin
					count_in <= count_in + 9'h001 ; 
				end
			end
		end
	end
end
						
endmodule
