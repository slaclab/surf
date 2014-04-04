-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : Vc64Fifo.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-04-04
-- Last update: 2014-04-04
-- Platform   : Vivado 2013.3
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2014 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;
use work.Vc64Pkg.all;

entity Vc64Fifo is
   generic (
      TPD_G              : time                       := 1 ns;
      RST_ASYNC_G        : boolean                    := false;
      ALTERA_SYN_G       : boolean                    := false;
      ALTERA_RAM_G       : string                     := "M9K";
      XIL_DEVICE_G       : string                     := "7SERIES";  --Xilinx only generic parameter    
      BRAM_EN_G          : boolean                    := true;
      USE_BUILT_IN_G     : boolean                    := true;  --if set to true, this module is only Xilinx compatible only!!!
      GEN_SYNC_FIFO_G    : boolean                    := false;
      BYPASS_FIFO_G      : boolean                    := false;-- If GEN_SYNC_FIFO_G = true, BYPASS_FIFO_G = true will reduce FPGA resources
      FIFO_SYNC_STAGES_G : integer range 3 to (2**24) := 3;
      FIFO_ADDR_WIDTH_G  : integer range 4 to 48      := 9;
      USE_PROG_FULL      : boolean                    := false;
      FIFO_AFULL_THRES_G : integer range 1 to (2**24) := 256);
   port (
      -- Streaming Write Data Interface (vcWrClk domain)
      vcWrIn  : in  Vc64DataType;
      vcWrOut : out Vc64CtrlType;
      -- Streaming Read Data Interface (vcRdClk domain)
      vcRdIn  : in  Vc64CtrlType;
      vcRdOut : out Vc64DataType;
      -- Clocks and resets
      vcWrClk : in  sl;
      vcWrRst : in  sl := '0';
      vcRdClk : in  sl);      
end Vc64Fifo;

architecture mapping of Vc64Fifo is

   signal din  : slv(72 downto 0);
   signal dout : slv(71 downto 0);
   signal rdEn,
      valid,
      almostFull,
      progFull : sl;
   
begin

   GEN_FIFO : if ((GEN_SYNC_FIFO_G = false) or ((GEN_SYNC_FIFO_G = true) and (BYPASS_FIFO_G = false)))  generate
   
      -- Convert the input data into a input SLV bus
      din <= toSlv(vcWrIn);

      -- Select either the progFull or almostFull for flow control
      vcWrOut.almostFull <= progFull when (USE_PROG_FULL = true) else almostFull;

      Fifo_Inst : entity work.Fifo
         generic map (
            TPD_G           => TPD_G,
            RST_ASYNC_G     => RST_ASYNC_G,
            GEN_SYNC_FIFO_G => GEN_SYNC_FIFO_G,
            BRAM_EN_G       => BRAM_EN_G,
            FWFT_EN_G       => true,
            ALTERA_SYN_G    => ALTERA_SYN_G,
            ALTERA_RAM_G    => ALTERA_RAM_G,
            USE_BUILT_IN_G  => USE_BUILT_IN_G,
            XIL_DEVICE_G    => XIL_DEVICE_G,
            SYNC_STAGES_G   => FIFO_SYNC_STAGES_G,
            DATA_WIDTH_G    => 72,
            ADDR_WIDTH_G    => FIFO_ADDR_WIDTH_G,
            FULL_THRES_G    => FIFO_AFULL_THRES_G)
         port map (
            -- Resets
            rst         => vcWrRst,
            --Write Ports (wr_clk domain)
            wr_clk      => vcWrClk,
            wr_en       => din(72),
            din         => din(71 downto 0),
            prog_full   => progFull,
            almost_full => almostFull,
            full        => vcWrOut.full,
            --Read Ports (rd_clk domain)
            rd_clk      => vcRdClk,
            rd_en       => rdEn,
            dout        => dout,
            valid       => valid);

      -- Check if we are ready to read the FIFO
      -- Note: vcRdIn.ready not used in direct FIFO applications
      rdEn <= valid and not(vcRdIn.full) and not(vcRdIn.almostFull);

      -- Convert the output SLV into the output data bus
      vcRdOut <= toVc64Data(rdEn & dout);

      -- Unused Signals set logic high
      vcWrOut.ready <= '1';
      
   end generate;
   
   BYPASS_FIFO : if ((GEN_SYNC_FIFO_G = true) and (BYPASS_FIFO_G = true))  generate

      vcRdOut <= vcWrIn;
      vcWrOut <= vcRdIn;
      
   end generate;
   
end mapping;
