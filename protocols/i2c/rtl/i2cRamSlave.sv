/*-------------------------------------------------------------------------------
-- File       : i2cRamSlave.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2017-03-28
-- Last update: 2017-03-28
-------------------------------------------------------------------------------
-- Description: I2C SLAVE using BRAM module
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Firmware Standard Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'SLAC Firmware Standard Library', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------*/

module i2cRamSlave #
  (time TPD_P = 2,
			
   integer I2C_ADDR_P = 111,
   integer TENBIT_P = 0,
   integer FILTER_P = 4,
   integer RAM_WIDTH_P = 32,
   integer RAM_DEPTH_P = 1024,
   integer ENDIANNESS_P = 0
   )
   (input logic clk,
    input logic sRst,
    inout 	sda,
    inout 	scl);

   (* ram_style = "block" *)
   logic [RAM_WIDTH_P-1:0] ram [0:RAM_DEPTH_P-1];

   localparam integer DATA_SIZE_P  = RAM_WIDTH_P/8;
   localparam integer ADDR_WIDTH_P  = $clog2(RAM_DEPTH_P);
   localparam integer ADDR_SIZE_P  = ADDR_WIDTH_P/8+1;
   
   logic [ADDR_WIDTH_P-1:0] ramAddr;
   logic [RAM_WIDTH_P-1:0]  ramWrData;
   logic [RAM_WIDTH_P-1:0]  ramRdData;
   logic 		    ramWrEn;
   logic 		    ramRdEn;
   
   i2cBusIntf #
     (.OEN_POLARITY_P(1))
   i2cBusIO ();
   
   
   i2cRegSlaveIntf #
     (.ADDR_SIZE_P(ADDR_SIZE_P),
      .DATA_SIZE_P(DATA_SIZE_P))
   i2cRegSlaveIO ();

   i2cRegSlave # 
     (.TPD_P(TPD_P),
      .TENBIT_P(TENBIT_P),
      .I2C_ADDR_P(I2C_ADDR_P),
      .OUTPUT_EN_POLARITY_P(1),
      .FILTER_P(FILTER_P),
      .ADDR_SIZE_P(ADDR_SIZE_P),
      .DATA_SIZE_P(DATA_SIZE_P),
      .ENDIANNESS_P(ENDIANNESS_P))
   i2cRegSlave_1 (.*);

/* -----\/----- EXCLUDED -----\/-----
   always_ff @(posedge clk) begin
      if (i2cRegSlaveIO.rdEn) begin
	 i2cRegSlaveIO.rdData <= #TPD_P ram[i2cRegSlaveIO.addr];
      end
   end
 -----/\----- EXCLUDED -----/\----- */
   always_ff @(posedge clk) begin
      ramRdData = ram[ramAddr];
      if (ramWrEn) begin
	 ram[ramAddr] <= ramWrData;
      end
   end

   assign ramWrEn  = i2cRegSlaveIO.wrEn;
   assign ramRdEn  = i2cRegSlaveIO.rdEn;
   assign ramAddr  = i2cRegSlaveIO.addr;
   assign ramWrData  = i2cRegSlaveIO.wrData;
   assign i2cRegSlaveIO.rdData  = ramRdData;

   
   assign  sda = (i2cBusIO.sdaOen == i2cBusIO.OEN_POLARITY_P) ? i2cBusIO.sdaOut : 1'bZ;
   assign  i2cBusIO.sdaIn = sda;
   assign  scl = (i2cBusIO.sclOen == i2cBusIO.OEN_POLARITY_P) ? i2cBusIO.sclOut : 1'bZ;
   assign  i2cBusIO.sclIn = scl;
   

endmodule // i2cRamSlave

   

   
   
   
