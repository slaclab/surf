`timescale 1ns/100ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    15:00:41 03/12/2010 
// Design Name: 
// Module Name:    EventReceiverChannel 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module EvrV1EventReceiverChannel(Clock, Reset, myEvent, myDelay, myWidth, myPolarity,
                            trigger, myPreScale, setPulse, resetPulse, channelDebug);
   input          Clock;
   input          Reset;     // combo signal of reset and Event Code 0x7B
   input          myEvent;
   input [31:0]   myDelay;
   input [31:0]   myWidth;
   input [31:0]   myPreScale;
   input          myPolarity;
   output         trigger;
   input          setPulse;
   input          resetPulse;
   output [102:0] channelDebug;
   
   parameter[1:0]   // State Machine State
     delayIdle = 2'b00,
     delayWait = 2'b01,
     delayOut  = 2'b10;

   reg [1:0]  delayState;
   reg [31:0] counter;
   reg [31:0] preScaler;
   reg        delayPulse;
   reg        trigD;
   reg        trigLe;
   reg [31:0] myPreScaleInt;

   always @ (myPreScale)
   begin
      if (myPreScale == 32'h0) myPreScaleInt <= myPreScale;
      else myPreScaleInt <= myPreScale - 1;
   end

   assign trigger = setPulse ? 1'b1 : resetPulse ? 1'b0 : myPolarity ? delayPulse : ~delayPulse;

   assign channelDebug[31:0]   = counter;
   assign channelDebug[63:32]  = preScaler;
   assign channelDebug[64]     = delayPulse;
   assign channelDebug[65]     = trigD;
   assign channelDebug[66]     = trigLe;
   assign channelDebug[67]     = Reset;
   assign channelDebug[68]     = myEvent;
   assign channelDebug[70:69]  = delayState;
   assign channelDebug[102:71] = myPreScaleInt;

   always @ (posedge Clock) begin
      trigD <= myEvent;
      if (~trigD & myEvent) trigLe <= 1'b1;
      else trigLe <= 1'b0;
   end

   always @ (posedge Reset or posedge Clock) begin
      if (Reset) preScaler <= 32'b0;
      else if ((trigLe) | (preScaler == myPreScaleInt)) preScaler <= 32'b0;
      else preScaler <= preScaler + 1;
   end

   always @ (posedge Reset or posedge Clock) begin
      if (Reset) begin
         delayPulse <= 1'b0;
         counter <= 32'b0;
         delayState <= delayIdle;
      end
      else begin
         case (delayState)

            delayIdle: begin
               if (trigLe) begin
                  if (myWidth == 32'h0) begin
                     delayPulse <= 1'b0;
                     counter <= 32'h0;
                     delayState <= delayIdle;
                  end
                  else if (myDelay == 32'h0 & myPreScaleInt == 32'h0) begin
                     delayPulse <= 1'b1;
                     counter <= myWidth -1;
                     delayState <= delayOut;
                  end
                  else if (myDelay == 32'h0 & myPreScaleInt > 32'h0) begin
                     counter <= myWidth - 1;
                     delayPulse <= 1'b1;
                     delayState <= delayOut;
                  end                
                  else if (myDelay == 32'h0) begin
                     counter <= 32'h0;
                     delayState <= delayWait;
                  end
                  else begin
                     counter    <= myDelay - 1;
                     delayState <= delayWait;
                  end
               end
               else delayState <= delayIdle;
            end

            delayWait: begin
               if (preScaler == myPreScaleInt) begin
                  if (counter == 32'h0) begin
                     delayPulse <= 1'b1;
                     counter <= myWidth - 1;
                     delayState <= delayOut;
                  end
                  else begin
                     counter <= counter - 1;
                     delayState <= delayWait;
                  end
               end
            end

            delayOut: begin
               if (preScaler == myPreScaleInt) begin
                  if (counter == 32'h0) begin
                     delayPulse <= 1'b0;
                     delayState <= delayIdle;
                  end
                  else begin
                     counter <= counter - 1;
                     delayState <= delayOut;
                  end
               end
            end

            default : delayState <= delayIdle;

         endcase // case (delayState)
      end
   end
endmodule

