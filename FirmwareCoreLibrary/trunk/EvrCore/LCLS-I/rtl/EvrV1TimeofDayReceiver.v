`timescale 1ns/100ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 			BNL
// Engineer: 			J. DeLong
// 
// Create Date:    	09:49:15 03/16/2010 
// Design Name: 
// Module Name:    	timeofDayReceiver 
// Project Name: 		embedded event receiver
// Target Devices: 	FX70T
// Tool versions: 	ISE 12.1
// Description: 		This subdesign receives time stamp control events to set the
//							time of day from the GPS locked NTP server. The offset to the
//							time of day is incremented at the system clock rate.
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module EvrV1TimeofDayReceiver(Clock, Reset, EventStream, TimeStamp, timeDebug);
    input 		Clock;
    input 		Reset;
    input 	[7:0] 	EventStream;
    output 	[63:0] 	TimeStamp;
    output      [36:0]  timeDebug;


	reg [31:0] Seconds;
	reg [4:0]  Position;
        reg [63:0] TimeStamp;
	
	// the time of day is updated by a serial stream of 0 events (0x70) and 1 events
	// (0x71). This code implements a pointer into the time of day register and writes
	// the data into that position. On receibt of the latch event (0x7d) the data is
	// moved to the output register and the pointer is cleared. The offset is cleared
	// on event 0x7d then incremented on the input clock edge.
	always @ (posedge Clock)
	begin
		if (Reset || (EventStream == 8'h7d))  Position <= 5'd0;
		else if ((EventStream == 8'h70) || (EventStream == 8'h71)) Position <= (Position + 1);
		else Position <= Position;
	end
	
	always @ (posedge Clock)
	begin
		if (Reset) Seconds <= 32'd0;		
		else if (EventStream == 8'h70) Seconds[31-Position] <= 1'b0;
		else if (EventStream == 8'h71) Seconds[31-Position] <= 1'b1;
		else Seconds <= Seconds;
	end
	
	always @ (posedge Clock)
	begin
		if (Reset) TimeStamp <= 64'd0;
		else if (EventStream == 8'h7d) TimeStamp <= {Seconds, 32'b0};
		else  TimeStamp <= (TimeStamp + 1);
	end
        assign timeDebug = {Position, Seconds};

endmodule
