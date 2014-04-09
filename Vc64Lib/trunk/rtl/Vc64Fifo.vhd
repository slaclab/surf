-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : Vc64Fifo.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-04-04
-- Last update: 2014-04-09
-- Platform   : Vivado 2013.3
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:   This module is used as a generic FIFO interface 
--                for a VC64 channel.
--
-- Note: If EN_FRAME_FILTER_G = true, then this module DOES NOT support 
--       interleaving of virtual channels during the middle of a frame transfer.
-------------------------------------------------------------------------------
-- Copyright (c) 2014 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;
use work.Vc64Pkg.all;

entity Vc64Fifo is
   generic (
      -- General Configurations
      TPD_G              : time                       := 1 ns;
      RST_ASYNC_G        : boolean                    := false;
      RST_POLARITY_G     : sl                         := '1';  -- '1' for active HIGH reset, '0' for active LOW reset      
      -- RX Configurations
      EN_FRAME_FILTER_G  : boolean                    := true;
      -- TX Configurations
      IGNORE_TX_READY_G  : boolean                    := false;
      PIPE_STAGES_G      : integer range 0 to 16      := 0;  -- Used to add pipeline stages to the output ports to help with meeting timing
      -- Xilinx Specific Configurations
      XIL_DEVICE_G       : string                     := "7SERIES";  --Xilinx only generic parameter    
      USE_BUILT_IN_G     : boolean                    := false;  --if set to true, this module is only Xilinx compatible only!!!
      -- Altera Specific Configurations
      ALTERA_SYN_G       : boolean                    := false;
      ALTERA_RAM_G       : string                     := "M9K";
      -- FIFO Configurations
      BRAM_EN_G          : boolean                    := true;
      GEN_SYNC_FIFO_G    : boolean                    := false;
      FIFO_SYNC_STAGES_G : integer range 3 to (2**24) := 3;
      FIFO_ADDR_WIDTH_G  : integer range 4 to 48      := 9;
      FIFO_AFULL_THRES_G : integer range 1 to (2**24) := 2**24);
   port (
      -- RX Frame Filter Status (vcRxClk domain) 
      vcRxDropWrite : out sl;
      vcRxTermFrame : out sl;
      -- Streaming RX Data Interface (vcRxClk domain) 
      vcRxData      : in  Vc64DataType;
      vcRxCtrl      : out Vc64CtrlType;
      vcRxClk       : in  sl;
      vcRxRst       : in  sl := '0';
      -- Streaming TX Data Interface (vcTxClk domain) 
      vcTxCtrl      : in  Vc64CtrlType;
      vcTxData      : out Vc64DataType;
      vcTxClk       : in  sl;
      vcTxRst       : in  sl := '0');
end Vc64Fifo;

architecture mapping of Vc64Fifo is

   -- Set the maximum programmable FIFO almostFull threshold
   constant MAX_PROG_C : integer := ((2**FIFO_ADDR_WIDTH_G)-6);

   -- Limit the FIFO_AFULL_THRES_G generic
   constant AFULL_THRES_C : integer := ite((FIFO_AFULL_THRES_G < MAX_PROG_C), FIFO_AFULL_THRES_G, MAX_PROG_C);

   signal din  : slv(72 downto 0);
   signal dout : slv(71 downto 0);
   signal almostFull,
      progFull,
      overflow,
      fifoRdEn,
      fifoValid,
      txValid,
      ready : sl;
   
   signal rxCtrl,
      txCtrl : Vc64CtrlType;
   signal rxData,
      txData : Vc64DataType;
   
begin
   
   Vc64FrameFilter_Inst : entity work.Vc64FrameFilter
      generic map (
         TPD_G             => TPD_G,
         RST_ASYNC_G       => RST_ASYNC_G,
         RST_POLARITY_G    => RST_POLARITY_G,
         EN_FRAME_FILTER_G => EN_FRAME_FILTER_G)
      port map (
         -- RX Frame Filter Status
         vcRxDropWrite => vcRxDropWrite,
         vcRxTermFrame => vcRxTermFrame,
         -- Streaming RX Data Interface
         vcRxData      => vcRxData,
         vcRxCtrl      => vcRxCtrl,
         -- Streaming TX Data Interface
         vcTxCtrl      => rxCtrl,
         vcTxData      => rxData,
         -- Clock and Reset
         vcClk         => vcRxClk,
         vcRst         => vcRxRst);

   -- Map the RX flow control signals
   rxCtrl.ready      <= not(almostFull);
   rxCtrl.almostFull <= progFull;
   rxCtrl.overflow   <= overflow;

   -- Convert the input data into a input SLV bus
   din <= toSlv(rxData);

   Fifo_Inst : entity work.Fifo
      generic map (
         TPD_G           => TPD_G,
         RST_ASYNC_G     => RST_ASYNC_G,
         RST_POLARITY_G  => RST_POLARITY_G,
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
         FULL_THRES_G    => AFULL_THRES_C)
      port map (
         -- Resets
         rst         => vcRxRst,
         --Write Ports (wr_clk domain)
         wr_clk      => vcRxClk,
         wr_en       => din(72),
         din         => din(71 downto 0),
         almost_full => almostFull,
         prog_full   => progFull,
         overflow    => overflow,
         --Read Ports (rd_clk domain)
         rd_clk      => vcTxClk,
         rd_en       => fifoRdEn,
         dout        => dout,
         valid       => fifoValid);

   -- Generate the ready signal 
   ready <= '1' when(IGNORE_TX_READY_G = true) else txCtrl.ready;

   -- Generate the TX valid signal
   txValid <= fifoValid and not txCtrl.almostFull;

   -- Check if we are ready to read the FIFO
   fifoRdEn <= txValid and ready;

   -- Convert the output SLV into the output data bus
   txData <= toVc64Data(txValid & dout);

   Vc64Sync_Inst : entity work.Vc64Sync
      generic map (
         TPD_G             => TPD_G,
         RST_ASYNC_G       => RST_ASYNC_G,
         RST_POLARITY_G    => RST_POLARITY_G,
         IGNORE_TX_READY_G => IGNORE_TX_READY_G,
         PIPE_STAGES_G     => PIPE_STAGES_G)
      port map (
         -- Streaming RX Data Interface
         vcRxData => txData,
         vcRxCtrl => txCtrl,
         -- Streaming TX Data Interface
         vcTxCtrl => vcTxCtrl,
         vcTxData => vcTxData,
         -- Clock and Reset
         vcClk    => vcTxClk,
         vcRst    => vcTxRst);       

end mapping;
