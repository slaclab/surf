`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 			SLAC
// Engineer: 			M. Weaver
// 
// Create Date:    	09:49:15 03/04/2015
// Design Name: 
// Module Name:    	timeStampGenerator 
// Project Name: 		embedded event receiver
// Target Devices: 	FX70T
// Tool versions: 	ISE 12.1
// Description: 		This subdesign generates time stamps at a programmable rate
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module EvrV1TimeStampGenerator(Clock, Reset, TimeStamp);
    input 		Clock;
    input 		Reset;
    output 	[63:0] 	TimeStamp;


	reg [31:0] Seconds;
	reg [31:0] Count;
        reg [63:0] TimeStamp;
	
	always @ (posedge Clock)
	begin
		if (Reset) Count <= 32'b0;
		else if (Count == 32'b0) Count <= 32'd330555;
		else Count <= Count-1;
	end
	
	always @ (posedge Clock)
	begin
		if (Reset) Seconds <= 32'd0;		
		else if (Count == 32'b0) Seconds <= Seconds+1;
		else Seconds <= Seconds;
	end
	
	always @ (posedge Clock)
	begin
		if (Reset) TimeStamp <= 64'd0;
		else if (Count == 32'b0) TimeStamp <= {Seconds, 32'b0};
		else  TimeStamp <= (TimeStamp + 1);
	end

endmodule
