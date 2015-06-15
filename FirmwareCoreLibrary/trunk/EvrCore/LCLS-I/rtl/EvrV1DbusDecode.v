`timescale 1ns/100ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    09/06/2011
// Design Name: 
// Module Name:    dbusDecode
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: This is dbusdecode.vhd converted to verilog
//     
//
//////////////////////////////////////////////////////////////////////////////////
module EvrV1DbusDecode(Clock, EventClock, Reset, dbus, isK, dbRdAddr, dbena, dbdis, dben,
                  rxSize, dbrx, dbrdy, dbcs, disBus, dataBuffOut, dbDebug);
   input	 Clock;
   input         EventClock;
   input 	 Reset;
   input [7:0]   dbus;
   input         isK;
   input [8:0]	 dbRdAddr;
   input         dbena;
   input	 dbdis;
   input 	 dben;
   output [11:0] rxSize;
   output        dbrx;
   output        dbrdy;
   output        dbcs;
   output [7:0]  disBus;
   output [31:0] dataBuffOut;
   output [73:0] dbDebug;


   reg [11:0]    rxSize;
   reg           dbrx;
   reg           dbrdy;
   reg [7:0]     disBus;
   reg [10:0]    iRxSize;
   reg           iBusy;
   reg           iDone;
   reg           wrMem;
   reg           chkSumErr;
   reg           iDbEn;
   reg           iDbDis;
   reg [1:0]     iDbEnaSr;
   reg [1:0]     iDbEnSr;
   reg [1:0]     iDbDisSr;
   reg [1:0]     iBusySr;
   reg           disBusEn;
   reg           disBusSync;
   reg           dBuffEn;
   reg [7:0]     delData;
   reg           delWrMem;
   reg [10:0]    delAddr;
   reg [15:0]    chkSum;
   reg [7:0]     rcvChkSum;
   reg [3:0]     chkSumSr;
   reg           dbcs;

   assign dbDebug = {iDbDis, // 1 255
      iDbDisSr,   // 2   254:253
      iRxSize,    // 11  252:242
      iBusy,      // 1   241
      iDone,      // 1   240
      wrMem,      // 1   239
      chkSumErr,  // 1   238
      iDbEnaSr,   // 2   237:236
      iDbEnSr,    // 2   235:234
      iBusySr,    // 2   233:232
      dBuffEn,    // 1   231
      delData,    // 8   230:223
      delWrMem,   // 1   222
      delAddr,    // 11  221:211
      chkSum,     // 16  210:195
      rcvChkSum,  // 8   194:187
      chkSumSr,   // 4   186:183
      iDbEn};     // 1   182

   always @ (posedge EventClock)
   begin
      if (Reset) disBus <= 8'h0;
      else if ((disBusEn) && (disBusSync)) disBus <= dbus;
   end

   always @ (posedge Clock)
   begin
      if (Reset) 
      begin
         dbrx <= 1'b0;
         dbcs <= 1'b0;
         dbrdy <= 1'b0;
         iBusySr <= 2'b0;
      end
      else 
      begin
         dbrx <= iBusy && dBuffEn;
         dbcs <= chkSumErr;
         iBusySr <= {iBusySr[0], iBusy};
         if (iBusySr == 2'b10) 
         begin
            dbrdy <= 1'b1;
	 end
         else if ((dbena) | (dbdis) | ~(dben)) 
         begin
            dbrdy <= 1'b0;
	 end
      end 
   end

   always @ (posedge EventClock)
   begin
      if (Reset)
      begin
         iDbEn <= 1'b0;
         dBuffEn <= 1'b0;
         iDbDis <= 1'b0;
         iDbEnSr <= 2'b0;
         iDbEnaSr <= 2'b0;
         iDbDisSr <= 2'b0;
      end
      else
      begin
         iDbEnSr <= {iDbEnSr[0], dben};
         iDbEnaSr <= {iDbEnaSr[0], dbena};
         iDbDisSr <= {iDbDisSr[0], dbdis};
         iDbEn <= iDbEnSr[1];
//         iDbDis <= ~(iDbDisSr[1]) && iDbDisSr[0];
         iDbDis <= ~iDbDisSr[1] & iDbDisSr[0] & ~iDbEnaSr;      
         if (iDbEnaSr == 2'b01) dBuffEn <= 1'b1;
         else if ((chkSumSr[3]) | (iDbDis)) dBuffEn <= 1'b0;
      end
   end
   always @ (posedge EventClock)
   begin
      if (Reset)
      begin
         chkSumErr <= 1'b0;
	 chkSum <= 16'b0;
	 rcvChkSum <= 8'b0;
	 chkSumSr <= 4'b0; 
      end
      else
      begin
         if (iDbEnaSr == 2'b01)
	 begin
   	    chkSum <= 16'b0;
	    chkSumErr <= 1'b0;
         end
	 if (delWrMem && iBusy) chkSum <= chkSum + delData;
	 if (dBuffEn) 
         begin
            chkSumSr <= {chkSumSr[2:0] , iDone};
  	    if (chkSumSr[0]) rcvChkSum <= dbus;
	    if (chkSumSr[2])
	       if (~(chkSum) != {rcvChkSum, dbus}) chkSumErr <= 1'b1;
	 end
      end
   end
   always @(posedge EventClock)
   begin
      if (Reset)
      begin
         iBusy <= 1'b0;
	 iRxSize <= 11'b0;
	 wrMem <= 1'b0;
	 iDone <= 1'b0;
	 disBusEn <= 1'b0;
	 delData <= 8'b0;
	 delAddr <= 11'b0;
	 rxSize <= 12'b0;
	 delWrMem <= 1'b0;
	 disBusSync <= 1'b0;
      end
      else
      begin
	 delData <= dbus;
	 delAddr <= iRxSize;
         delWrMem <= (((wrMem && ~isK) | chkSumSr[0] | chkSumSr[2]) && dBuffEn);
	 if (iDbEnaSr == 2'b01) 
         begin
            iRxSize <= 11'b0;
	 end
      
	 if (iDone) 
         begin
            iDone <= 1'b0;
	 end
      
	 if (~iDbEn)
	 begin
	    wrMem <= 1'b0;
	    iBusy <= 1'b0;
	    iRxSize <= 11'b0;
	    iDone <= 1'b0;
	    disBusEn <= 1'b1;
         end
	 else
	 begin
	    if (chkSumSr[1]) 
            begin
               iRxSize <= iRxSize + 1;
	    end
	 
	    if (isK && dbus == 8'h1C)
	    begin
	       disBusSync <= 1'b1;
	       disBusEn <= 1'b1;
	       wrMem <= 1'b0;
	       iBusy <= 1'b1;
	       iRxSize <= 11'b0;
	    end

    	    else if (isK && (dbus == 8'h3C | dbus == 8'hbc))
	    begin
	       disBusEn <= ~disBusEn;
	       iBusy <= 1'b0;
	       iDone <= 1'b1;
	       wrMem <= ~wrMem;
	       rxSize <= {0, iRxSize};
	    end
	 
	    else if (iBusy)
	    begin
	       disBusEn <= ~disBusEn;
	       wrMem <= ~wrMem;
	       if (wrMem) 
               begin
                  iRxSize <= iRxSize + 1;
	       end
	    end
	 
	    else
	    begin
	       wrMem <= 1'b0;
	       disBusEn <= ~disBusEn;
	    end
	 end
      end
   end


   EvrV1Databuff databuff0(
      .addra(delAddr),
      .addrb(dbRdAddr),
      .clka(EventClock),
      .clkb(Clock),
      .dina(delData),
      .doutb(dataBuffOut),
      .wea(delWrMem));

endmodule
