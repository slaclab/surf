//                              -*- Mode: Verilog -*-
// Filename        : i2cRegSlave.sv
// Description     : Implements an I2C slave attached to a generic RAM interface.
// Author          : Benjamin Reese
// Created On      : Mon Apr 22 10:04:49 2013
// Last Modified By: Benjamin Reese
// Last Modified On: Mon Apr 22 10:04:49 2013
// Update Count    : 0
// Status          : Unknown, Use with caution!

interface i2cRegSlaveIntf #
  (integer ADDR_SIZE_P = 2,
   integer DATA_SIZE_P = 2);
   
   logic [ADDR_SIZE_P-1:0][7:0] addr;
   logic [DATA_SIZE_P-1:0][7:0] wrData;
   logic [DATA_SIZE_P-1:0][7:0] rdData;
   logic 			wrEn;
   logic 			rdEn;

   modport mp (output addr, wrEn, wrData, rdEn,
	       input rdData);
   

endinterface // i2cRegSlaveIntf

   

module i2cRegSlave #
  (
   time 		TPD_P = 1,
   logic 		TENBIT_P = 0,
   logic [7+TENBIT_P*3] I2C_ADDR_P = 111,
   logic 		OUTPUT_EN_POLARITY_P = 0,
   integer 		FILTER_P = 4,
   integer 		ADDR_SIZE_P = 2, // in bytes
   integer 		DATA_SIZE_P = 2, // in bytes
   logic 		ENDIANNESS_P = 0
   )
   (input logic clk,
    input logic sRst,
    i2cRegSlaveIntf.mp i2cRegSlaveIO,
    i2cBusIntf.mp i2cBusIO);

   typedef enum logic[1:0] { IDLE_S, ADDR_S, WRITE_DATA_S, READ_DATA_S } StateType;

   typedef struct {
      StateType state;
      logic [3:0] 		   byteCount;
      logic 			   enable;
      logic [ADDR_SIZE_P-1:0][7:0] addr ;
      logic [DATA_SIZE_P-1:0][7:0] wrData;
      logic 			   wrEn;
      logic 			   rdEn;

      // Outputs
      logic 			   txValid;
      logic [7:0] 		   txData;
//      logic 			   rxAck;
    } RegType;
   RegType r, rin;

   i2cSlaveIntf i2cSlaveIO ();

   // Instantiate I2C Slave
   i2cSlave # 
     (.TPD_P(TPD_P),
      .TENBIT_P(TENBIT_P),
      .I2C_ADDR_P(I2C_ADDR_P),
      .OUTPUT_EN_POLARITY_P(OUTPUT_EN_POLARITY_P),
      .FILTER_P(FILTER_P),
      .RMODE_P(0), 
      .TMODE_P(0)) 
   i2cSlaveInst (.*);
//(.clk(clk), .sRst(sRst), .i2cBus(i2cBus), .i2cSlave(i2cSlave));

   always_comb begin
      rin 	  = r;

      // Enable after reset
      rin.enable  = 1;

      // Read and write enables are pulsed, default to 0
      rin.wrEn 	  = 0;
      rin.rdEn 	  = 0;
      
      // Pulse rxAck or wait until rxValid drops?
      // Can get away with pulsing.
//      rin.rxAck  = 0;

      // Auto increment the address after ead read or write.
      // This enables bursts.
      if (r.wrEn || r.rdEn)
	rin.addr  = r.addr + 1;

      // Tx Data always valid, assigned based on byteCount.
      rin.txValid   = 1;

      unique case (r.state)
	 IDLE_S : begin
	    rin.byteCount  = 0;
	    // Get txData ready in case a read occurs
	    rin.txData 	   = i2cRegSlaveIO.rdData[r.byteCount];

	    // Wait here for slave to be addressed
	    if (i2cSlaveIO.rxActive) begin
	       // Slave has been addressed for write on the i2c bus
	       // Thsi write will consist of the ram address
	       rin.state  = ADDR_S;
	       rin.addr   = 0;
	    end
	    else if (i2cSlaveIO.txActive) begin
	       rin.state  = READ_DATA_S;
	    end
	 end // case: IDLE_S

	 ADDR_S : begin
	    if (i2cSlaveIO.rxValid) begin
	       // Received a byte of the address
	       rin.addr[r.byteCount]  = i2cSlaveIO.rxData;
	       rin.byteCount 	      = r.byteCount + 1;
	       if (r.byteCount == ADDR_SIZE_P-1) begin
		  rin.byteCount  = 0;
		  rin.state 	 = WRITE_DATA_S;
	       end
	    end

	    if (!i2cSlaveIO.rxActive) begin
	       // Didn't get enough bytes, go back to idle
	       rin.state  = IDLE_S;
	    end
	      
	 end // case: ADDR_S

	 WRITE_DATA_S : begin
	    if (i2cSlaveIO.rxValid) begin
	       // Received another byte
	       rin.wrData[r.byteCount] 	= i2cSlaveIO.rxData;
	       rin.byteCount 		= r.byteCount + 1;
	       if (r.byteCount == DATA_SIZE_P-1) begin
		  // Received a whole word. Increment addr, reset byteCount
		  rin.wrEn 	 = 1;
		  rin.byteCount  = 0;
	       end
	    end

	    if (!i2cSlaveIO.rxActive)
	      rin.state  = IDLE_S;

	 end // case: WRITE_DATA_S

	 READ_DATA_S : begin
	    rin.txData  = i2cRegSlaveIO.rdData[r.byteCount]; // Need to transform based on ENDIANNESS_P
	    if (i2cSlaveIO.txAck) begin
	       // Byte was sent
	       rin.byteCount 	= r.byteCount + 1;
	       if (r.byteCount == DATA_SIZE_P - 1) begin
		  // Word was sent. Increment addr to next word, reset byteCount
		  rin.rdEn 	 = 1;
		  rin.byteCount  = 0;
	       end
	    end

	    if (!i2cSlaveIO.txActive)
	      rin.state  = IDLE_S;

	 end // case: READ_DATA_S
	 
      endcase // unique case (r.state)

      // Synchronous Reset
      if (sRst) begin
	 rin.state 	= IDLE_S;
	 rin.byteCount 	= 0;
	 rin.enable 	= 0;
	 rin.addr 	= 0;
	 rin.wrEn 	= 0;
	 rin.wrData 	= 0;
	 rin.rdEn 	= 0;
	 rin.txValid 	= 0;
	 rin.txData 	= 0;
      end // if (sRst)

      // Signal assignments
      i2cSlaveIO.txValid    = r.txValid;
      i2cSlaveIO.txData     = r.txData;
      i2cSlaveIO.rxAck 	    = i2cSlaveIO.rxValid; // Always ack
      i2cSlaveIO.enable     = r.enable;

      //Outputs
      i2cRegSlaveIO.addr    = r.addr;
      i2cRegSlaveIO.wrData  = r.wrData;
      i2cRegSlaveIO.wrEn    = r.wrEn;
      i2cRegSlaveIO.rdEn    = r.rdEn;

   end // always_comb

   always_ff @(posedge clk) begin
      if (clk) begin
	 r <= #TPD_P rin;
      end
   end
   

endmodule // i2cRegSlave

      
      
			  
			   
	
		  
	      
