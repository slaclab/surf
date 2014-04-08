-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : Vc64Fifo.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-04-04
-- Last update: 2014-04-08
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
      IGNORE_TX_READY_G  : boolean                    := false;
      PIPE_STAGES_G      : integer range 0 to 16      := 0;  -- Used to add pipeline stages to the output ports to help with meeting timing
      FIFO_SYNC_STAGES_G : integer range 3 to (2**24) := 3;
      FIFO_ADDR_WIDTH_G  : integer range 4 to 48      := 9;
      FIFO_AFULL_THRES_G : integer range 1 to (2**24) := 256);
   port (
      -- Streaming RX Data Interface (vcRxClk domain) 
      vcRxData : in  Vc64DataType;
      vcRxCtrl : out Vc64CtrlType;
      vcRxClk  : in  sl;
      vcRxRst  : in  sl := '0';
      -- Streaming TX Data Interface (vcTxClk domain) 
      vcTxCtrl : in  Vc64CtrlType;
      vcTxData : out Vc64DataType;
      vcTxClk  : in  sl;
      vcTxRst  : in  sl := '0');
end Vc64Fifo;

architecture mapping of Vc64Fifo is

   signal din  : slv(72 downto 0);
   signal dout : slv(71 downto 0);
   signal fifoRdEn,
      fifoValid,
      txValid,
      ready : sl;
   
   signal txCtrl : Vc64CtrlType;
   signal txData : Vc64DataType;
   
begin

   -- Convert the input data into a input SLV bus
   din <= toSlv(vcRxData);

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
         rst       => vcRxRst,
         --Write Ports (wr_clk domain)
         wr_clk    => vcRxClk,
         wr_en     => din(72),
         din       => din(71 downto 0),
         not_full  => vcRxCtrl.ready,
         prog_full => vcRxCtrl.almostFull,
         overflow  => vcRxCtrl.overflow,
         --Read Ports (rd_clk domain)
         rd_clk    => vcTxClk,
         rd_en     => fifoRdEn,
         dout      => dout,
         valid     => fifoValid);

   -- Generate the ready signal 
   ready <= '1' when(IGNORE_TX_READY_G = true) else txCtrl.ready;

   -- Generate the TX valid signal
   txValid <= fifoValid and not txCtrl.almostFull;

   -- Check if we are ready to read the FIFO
   fifoRdEn <= txValid and ready;

   -- Convert the output SLV into the output data bus
   txData <= toVc64Data(txValid & dout);

   ZERO_LATENCY : if (PIPE_STAGES_G = 0) generate

      vcTxData <= txData;
      txCtrl   <= vcTxCtrl;
      
   end generate;

   PIPE_REG : if (PIPE_STAGES_G > 0) generate

      Vc64Sync_Inst : entity work.Vc64Sync
         generic map (
            TPD_G             => TPD_G,
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

   end generate;
   
end mapping;
