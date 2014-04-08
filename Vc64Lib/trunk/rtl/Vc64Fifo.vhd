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
      BYPASS_FIFO_G      : boolean                    := false;  -- If GEN_SYNC_FIFO_G = true, BYPASS_FIFO_G = true will reduce FPGA resources
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
   
   constant BYPASS_FIFO_C : boolean := ((GEN_SYNC_FIFO_G = true) and (BYPASS_FIFO_G = true));
   constant GEN_FIFO_C    : boolean := ((GEN_SYNC_FIFO_G = false) or (BYPASS_FIFO_C = false));

   constant BYPASS_STAGES_C : integer := ite((PIPE_STAGES_G = 0), 1, PIPE_STAGES_G);
   constant PIPE_STAGES_C   : integer := ite((BYPASS_FIFO_C = true), BYPASS_STAGES_C, PIPE_STAGES_G);

   signal din  : slv(72 downto 0);
   signal dout : slv(71 downto 0);
   signal fifoRdEn,
      fifoValid,
      fifoReady,
      progFull,
      overflow : sl;

   signal writeOut : Vc64CtrlType;
   signal fifoData : Vc64DataType;
   
begin

   -- Outputs
   vcRxCtrl <= writeOut;

   GEN_FIFO : if (GEN_FIFO_C = true) generate

      -- Convert the input data into a input SLV bus
      din <= toSlv(vcRxData);

      -- Update the writing status flags
      writeOut.ready      <= not(progFull);
      writeOut.almostFull <= progFull;
      writeOut.overflow   <= overflow;

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
            prog_full => progFull,
            overflow  => overflow,
            --Read Ports (rd_clk domain)
            rd_clk    => vcTxClk,
            rd_en     => fifoRdEn,
            dout      => dout,
            valid     => fifoValid);

      -- Check if we are ready to read the FIFO
      fifoRdEn <= fifoValid and fifoReady;

      -- Convert the output SLV into the output data bus
      fifoData <= toVc64Data(fifoRdEn & dout);
      
   end generate;

   BYPASS_FIFO : if (BYPASS_FIFO_C = true) generate
      fifoValid           <= vcRxData.valid;
      fifoData            <= vcRxData;
      writeOut.ready      <= vcTxCtrl.ready;
      writeOut.almostFull <= not(vcTxCtrl.ready);
      writeOut.overflow   <= '0';
      
   end generate;

   Vc64FifoRdCtrl_Inst : entity work.Vc64FifoRdCtrl
      generic map (
         TPD_G         => TPD_G,
         PIPE_STAGES_G => PIPE_STAGES_C)
      port map (
         -- FIFO Read Interface
         fifoValid => fifoValid,
         fifoReady => fifoReady,
         fifoData  => fifoData,
         -- Streaming TX Data Interface
         vcTxCtrl  => vcTxCtrl,
         vcTxData  => vcTxData,
         vcTxClk   => vcTxClk,
         vcTxRst   => vcTxRst);          
end mapping;
