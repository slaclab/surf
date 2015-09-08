//                              -*- Mode: Verilog -*-
// Filename        : i2cSlave.sv
// Description     : I2C Slave
// Author          : Benjamin Reese
// Created On      : Thu Apr 18 13:28:13 2013
// Last Modified By: Benjamin Reese
// Last Modified On: Thu Apr 18 13:28:13 2013
// Update Count    : 0
// Status          : Unknown, Use with caution!


interface i2cBusIntf;
   parameter OEN_POLARITY_P  = 1;
   
   logic sclIn;
   logic sclOut;
   logic sclOen;
   logic sdaIn;
   logic sdaOut;
   logic sdaOen;

//   logic sda;
//   logic scl;
   
   
   modport mp (input sclIn, sdaIn,
               output sclOut, sdaOut, sclOen, sdaOen);

//   modport top (inout sda, scl);

/* -----\/----- EXCLUDED -----\/-----
   task i2cTristateIO;
      sda    = (sdaOen == OEN_POLARITY_P) ? sdaOut : 1'bZ;
      sdaIn  = sda;
      scl    = (sclOen == OEN_POLARITY_P) ? sclOut : 1'bZ;
      sclIn  = scl;
   endtask
 -----/\----- EXCLUDED -----/\----- */
   
   
endinterface

interface i2cSlaveIntf;
   logic enable;
   logic txValid;
   logic [7:0] txData;
   logic       rxAck;

   logic       rxActive;
   logic       rxValid;
   logic [7:0] rxData;
   logic       txActive;
   logic       txAck;
   logic       nack;

   modport mp (input enable, txValid, txData, rxAck,
               output rxActive, rxValid, rxData, txActive, txAck, nack);
endinterface


module i2cSlave  #
  (
   time                   TPD_P = 1,
   logic                  TENBIT_P = 0,
   logic [7+TENBIT_P*3:0] I2C_ADDR_P = 0,
   logic                  OUTPUT_EN_POLARITY_P = 0,
   integer                FILTER_P = 4,
   logic                  RMODE_P = 0,
   logic                  TMODE_P = 0)
   
   (
    input logic clk,
    input logic sRst,
    //    input logic aRst,
    i2cBusIntf.mp i2cBusIO,
    i2cSlaveIntf.mp i2cSlaveIO) ;

   //Constants
   localparam logic I2C_READ_C  = 0;
   localparam logic I2C_WRITE_C  = 1;
   localparam logic I2C_LOW_C  = OUTPUT_EN_POLARITY_P;
   localparam logic I2C_HIZ_C  = !OUTPUT_EN_POLARITY_P;
   localparam logic I2C_ACK_C = 0;
   localparam logic [4:0] TENBIT_ADDR_START_C  = 5'b11110;
   

   typedef enum  logic[2:0]    { IDLE_S, CHECK_ADDR_S, CHECK_10B_ADDR_S, SCL_HOLD_S, MOVE_BYTE_S, HAND_SHAKE_S } StateType ;
   
   typedef struct    {
      StateType state;
      // Transfer Phase
      logic          active;
      logic          addr;
      // Shift Register
      logic [7:0]    shiftReg;
      logic [2:0]    counter;
      // Synchronizers for inputs scl and sda
      logic          scl;
      logic          sda;
      logic [FILTER_P:0] sclFilt;
      logic [FILTER_P:0] sdaFilt;
      // Output enables
      logic              sclOen;
      logic              sdaOen;

      // Outputs
      logic              rxActive;
      logic              rxValid;
      logic [7:0]        rxData;
      logic              txActive;
      logic              txAck;
      logic              nack;
      
   } RegType;
   
   RegType r, rin;

   // Functions

   // Compare the first byte of a rx'd address with the slave's address.
   // The TENBIT_P parameter determines if the slave is useing a ten bti address.
   function logic compaddr1stb(logic [7:0] ibyte);
      logic [7:1]        correct;
      if (TENBIT_P) begin
         correct[7:3] = TENBIT_ADDR_START_C;
         correct[2:1] = I2C_ADDR_P[9:8];
      end
      else begin
         correct[7:1] = I2C_ADDR_P[6:1];
      end
      return (ibyte[7:1] == correct[7:1]);
   endfunction // compaddr1stb

   function logic compaddr2ndb(logic [7:0] ibyte);
      parameter ADDR_LEN_C = 7+TENBIT_P*3;
      return ibyte[ADDR_LEN_C-3:0] == I2C_ADDR_P[ADDR_LEN_C-3:0];
   endfunction // compaddr2ndb
   

   always_comb begin
      rin = r;

      // Sample i2c bus input and shift in
      rin.sclFilt[0]                     = i2cBusIO.sclIn; 
      rin.sdaFilt[0]                     = i2cBusIO.sdaIn; 
      rin.sclFilt[FILTER_P:1] = r.sclFilt[FILTER_P-1:0];
      rin.sdaFilt[FILTER_P:1] = r.sdaFilt[FILTER_P-1:0];

      // Bus Filtering
      if (& r.sclFilt[FILTER_P:1]) rin.scl       = 1;
      if (~| r.sclFilt[FILTER_P:1]) rin.scl  = 0;
      if (& r.sdaFilt[FILTER_P:1]) rin.sda       = 1;
      if (~| r.sdaFilt[FILTER_P:1]) rin.sda  = 0;
      

      // Pulsed for 1 clock only when set by state machine below
      rin.txAck                                  = 0;

      // Reset rxValid when ack'd from IO
      if (r.rxValid && i2cSlaveIO.rxAck) begin
         rin.rxValid  = 0;
      end

      // I2C Slave Control FSM
      unique case (r.state)
        IDLE_S : begin
          // Release Bus
          if (r.scl && !rin.scl) begin
             rin.sdaOen = I2C_HIZ_C;
          end
        end

        CHECK_ADDR_S : begin
           if (compaddr1stb(r.shiftReg)) begin
              if (r.shiftReg[0] == I2C_READ_C) begin
                 if (!TENBIT_P || (TENBIT_P && r.active)) begin
                    if (i2cSlaveIO.txValid) begin
                       // Transmit Data
                       rin.txActive  = 1;
                       rin.state     = HAND_SHAKE_S;
                    end
                    else begin
                       // No data to transmit, NACK
                       rin.nack   = 1;
                       rin.state  = IDLE_S;
                    end
                 end // if (!TENBIT_P || (TENBIT_P && r.active))
                 else begin
                    // Ten bit address with R/Wn = 1 and slave not previously addressed
                    rin.state  = IDLE_S;
                 end // else: !if(!TENBIT_P || (TENBIT_P && r.active))
              end // if (r.shiftReg[0] == I2C_READ_C)
              else begin
                 rin.rxActive   = !TENBIT_P;
                 rin.state      = HAND_SHAKE_S;
              end // else: !if(r.shiftReg[0] == I2C_READ_C)
           end // if (compaddr1stb(r.shiftReg))
           else begin
              // Slave address did not match
              rin.active  = 0;
              rin.state   = IDLE_S;
           end // else: !if(compaddr1stb(r.shiftReg))
           rin.shiftReg = i2cSlaveIO.txData;
           
        end // case: CHECK_ADDR_S

        CHECK_10B_ADDR_S: begin
           if (compaddr2ndb(r.shiftReg)) begin
              // Slave has been addressed with a matching 10 bit address
              // If we receive a repeated start condition, matching address
              // and R/Wn = 1 we will transmit data. Without start condition we
              // will receive data.
              rin.addr = 1;
              rin.active = 1;
              rin.rxActive = 1;
              rin.state = HAND_SHAKE_S;
           end
           else begin
              rin.state = IDLE_S;
           end // else: !if(compaddr2ndb(r.shiftReg))
        end // case: CHECK_10B_ADDR_S

        SCL_HOLD_S : begin
           // This state is used when the device has been addressed to see if SCL
           // should be kept low until the receive register is free or the
           // transmit register is filled. It is also used when a data byte has
           // been transmitted or received to SCL low until software acknowledges
           // the transfer.
           if (r.scl && ~rin.scl) begin
              rin.sclOen = I2C_LOW_C;
              rin.sdaOen = I2C_HIZ_C;
           end
           // Ack has happened and rxValid set back to 0
           if ((r.rxActive && (!r.rxValid || !RMODE_P)) ||
               (r.txActive && (i2cSlaveIO.txValid || !TMODE_P))) begin
              rin.state = MOVE_BYTE_S;
              rin.sclOen = I2C_HIZ_C;
              // Falling edge that should be detected in movebye may have passed
              if (r.txActive && !rin.scl) begin
                 rin.sdaOen = r.shiftReg[7] ^ OUTPUT_EN_POLARITY_P;
              end
           end
           rin.shiftReg = i2cSlaveIO.txData;
        end // case: SCL_HOLD_S
        

        MOVE_BYTE_S : begin
           if (r.scl && !rin.scl) 
              if (r.txActive) 
                 rin.sdaOen = r.shiftReg[7] ^ OUTPUT_EN_POLARITY_P;
              else
                rin.sdaOen = I2C_HIZ_C;
           if (!r.scl && rin.scl) begin
              rin.shiftReg = {r.shiftReg[6:0], r.sda};
              if (&r.counter) begin
                 rin.counter = 0;
                 if (r.addr)
                   rin.state = CHECK_ADDR_S;
                 else if (!(r.rxActive | r.txActive))
                   rin.state = CHECK_10B_ADDR_S;
                 else
                   rin.state = HAND_SHAKE_S;
              end
              else
                rin.counter = r.counter + 1;
           end // if (!r.scl && rin.scl)
        end // case: MOVE_BYTE_S

        HAND_SHAKE_S : begin
           // Falling Edge
           if (r.scl && !rin.scl) begin
             if (r.addr) 
               rin.sdaOen = I2C_LOW_C;
             else if (r.rxActive) begin
                // Receive, send ACK/NAK
                // Acknowledge byte if core has room in receive register
                // This code assumes that the core's receive register is free if we are
                // in RMODE 1. This should always be the case unless software has
                // reconfigured the core during operation.
                if (!r.rxValid) begin
                   rin.sdaOen = I2C_LOW_C;
                   rin.rxData = r.shiftReg;
                   rin.rxValid = 1;
                end
                else begin
                   // NAK the byte, the master must abort the transfer
                   rin.sdaOen = I2C_HIZ_C;
                   rin.state = IDLE_S;
                end
             end // if (r.rxActive)
             else begin
                // transmit, release bus
                rin.sdaOen = I2C_HIZ_C;
                // Byte transmitted, ack it
                rin.txAck = 1;
             end // else: !if(r.rxActive)

             if (!r.addr && r.rxActive && rin.sdaOen == I2C_HIZ_C)
                rin.nack = 1;
           end // if (r.scl && !rin.scl)
           
           // Rising edge
           if (!r.scl && rin.scl) begin
              if (r.addr) begin
                 rin.state = MOVE_BYTE_S;
              end
              else begin
                if (r.rxActive) begin
                   // RMODE 0: Be ready to accept one more byte which will be NAK'd if
                   // software has not read the receive register
                   // RMODE 1: Keep SCL low until software has acknowledged received byte
                   if (!RMODE_P) begin
                      rin.state = MOVE_BYTE_S;
                   end
                   else begin
                     rin.state = SCL_HOLD_S;
                   end
                end // if (r.rxActive)
                else begin
                   // Transmit, check ACK/NAK from master
                   // If the master NAKs the transmitted byte the transfer has ended and
                   // we should wait for the master's next action. If the master ACKs the
                   // byte the core will act depending on tmode:
                   // TMODE 0:
                   // If the master ACKs the byte we must continue to transmit and will
                   // transmit the same byte on all requests.
                   // TMODE 1:
                   // IF the master ACKs the byte we will keep SCL low until software has
                   // put new transmit data into the transmit register.
                   if (r.sda == I2C_ACK_C) begin
                      if (!TMODE_P) begin
                         rin.state = MOVE_BYTE_S;
                      end
                      else begin
                         rin.state = SCL_HOLD_S;
                      end
                   end
                   else begin
                      rin.state = IDLE_S;
                   end // else: !if(r.sda == I2C_ACK_C)
                end // else: !if(r.rxActive)
              end // else: !if(r.addr)
              rin.addr = 0;
              rin.shiftReg = i2cSlaveIO.txData;
           end // if (!r.scl && rin.scl)
        end // case: HAND_SHAKE_S
                   
      endcase // unique case (r.state)

      if (i2cSlaveIO.enable) begin
         // STOP condition
         if (r.scl && rin.scl && !r.sda && rin.sda) begin
            rin.active = 0;
            rin.state = IDLE_S;
            rin.txActive = 0;
            rin.rxActive = 0;
         end

         // START or repeated START condition
         if (r.scl && rin.scl && r.sda && !rin.sda) begin
            rin.state = MOVE_BYTE_S;
            rin.counter = 0;
            rin.addr = 1;
            rin.txActive = 0;
            rin.rxActive = 0;
         end
      end // if (i2cSlaveIO.enable)
      
      // Reset and idle operation
      if (sRst) begin
         rin.state = IDLE_S;
         rin.scl = 0;
         rin.active = 0;
         rin.sclOen = I2C_HIZ_C;
         rin.sdaOen = I2C_HIZ_C;
         rin.rxActive = 0;
         rin.rxValid = 0;
         rin.rxData = 0;
         rin.txActive = 0;
         rin.txActive = 0;
         rin.nack = 0;
      end // if (sRst)
      
      // update outputs
      i2cSlaveIO.rxActive = r.rxActive;
      i2cSlaveIO.rxValid = r.rxValid;
      i2cSlaveIO.rxData = r.rxData;
      i2cSlaveIO.txActive = r.txActive;
      i2cSlaveIO.txAck = r.txAck;
      i2cSlaveIO.nack = r.nack;

      i2cBusIO.sclOut = 0;
      i2cBusIO.sclOen = r.sclOen;
      i2cBusIO.sdaOut = 0;
      i2cBusIO.sdaOen = r.sdaOen;
      
   end // always_comb

   always_ff @(posedge clk ) begin
      if (clk) begin
         r <= #TPD_P rin;
      end
/* -----\/----- EXCLUDED -----\/-----
      if (aRst) begin
         r.state <= #TPD_P IDLE_S;
         r.active <= #TPD_P 0;
//       r.addr <= #TPD_P 0;
//       r.shiftReg <= #TPD_P 0;
//       r.counter <= #TPD_P 0;
         r.scl <= #TPD_P 0;
//       r.sda <= #TPD_P 0;
//       r.sclFilt <= #TPD_P 0;
//       r.sdaFilt <= #TPD_P 0;
         r.sclOen <= #TPD_P I2C_HIZ_C;
         r.sdaOen <= #TPD_P I2C_HIZ_C;
         r.rxActive <= #TPD_P 0;
         r.rxValid <= #TPD_P 0;
         r.rxData <= #TPD_P 0;
         r.txActive <= #TPD_P 0;
         r.txAck <= #TPD_P 0;
         r.nack <= #TPD_P 0;
      end // if (aRst)
 -----/\----- EXCLUDED -----/\----- */

   end // always_ff @
   
   
endmodule // i2cSlave
