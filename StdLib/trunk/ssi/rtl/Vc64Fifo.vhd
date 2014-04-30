-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : Vc64Fifo.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-04-04
-- Last update: 2014-04-21
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
      VC_WIDTH_G         : natural range 8 to 64      := 64;
      -- Cascading FIFO Configurations
      CASCADE_SIZE_G     : integer range 1 to (2**24) := 1;  -- number of FIFOs to cascade (if set to 1, then no FIFO cascading)
      LAST_STAGE_ASYNC_G : boolean                    := true;  -- if set to true, the last stage will be the ASYNC FIFO      
      -- RX Configurations
      EN_FRAME_FILTER_G  : boolean                    := true;
      -- TX Configurations
      IGNORE_TX_READY_G  : boolean                    := false;
      PIPE_STAGES_G      : integer range 0 to 16      := 0;  -- Used to add pipeline stages to the output ports to help with meeting timing
      -- Xilinx Specific Configurations
      XIL_DEVICE_G       : string                     := "7SERIES";  --Xilinx only generic parameter    
      USE_BUILT_IN_G     : boolean                    := true;  --if set to true, this module is only Xilinx compatible only!!!
      -- Altera Specific Configurations
      ALTERA_SYN_G       : boolean                    := false;
      ALTERA_RAM_G       : string                     := "M9K";
      -- FIFO Configurations
      BRAM_EN_G          : boolean                    := true;
      GEN_SYNC_FIFO_G    : boolean                    := false;
      FIFO_SYNC_STAGES_G : integer range 3 to (2**24) := 3;
      FIFO_ADDR_WIDTH_G  : integer range 4 to 48      := 9;
      FIFO_FIXED_THES_G  : boolean                    := true;
      FIFO_AFULL_THRES_G : integer range 1 to (2**24) := 2**24);
   -- Note: If FIFO_FIXED_THES_G = true, then the fixed FIFO_AFULL_THRES_G is used.
   --       If FIFO_FIXED_THES_G = false, then the programmable threshold (vcRxThreshold) is used.      
   port (
      -- RX Frame Filter Status (vcRxClk domain) 
      vcRxDropWrite : out sl;
      vcRxTermFrame : out sl;
      -- Programmable RX Flow Control (vcRxClk domain)
      vcRxThreshold : in  slv(FIFO_ADDR_WIDTH_G-1 downto 0) := (others => '1');
      -- Streaming RX Data Interface (vcRxClk domain) 
      vcRxData      : in  Vc64DataType;
      vcRxCtrl      : out Vc64CtrlType;
      vcRxClk       : in  sl;
      vcRxRst       : in  sl                                := '0';
      -- Streaming TX Data Interface (vcTxClk domain) 
      vcTxCtrl      : in  Vc64CtrlType;
      vcTxData      : out Vc64DataType;
      vcTxClk       : in  sl;
      vcTxRst       : in  sl                                := '0');
end Vc64Fifo;

architecture mapping of Vc64Fifo is

   -- Set the maximum programmable FIFO almostFull threshold
   constant MAX_PROG_C     : integer                           := ((2**FIFO_ADDR_WIDTH_G)-6);
   constant MAX_PROG_SLV_C : slv(FIFO_ADDR_WIDTH_G-1 downto 0) := toSlv((MAX_PROG_C-1), FIFO_ADDR_WIDTH_G);  -- minus 1 for additional pipeline latency

   -- Limit the FIFO_AFULL_THRES_G generic
   constant AFULL_THRES_C : integer := ite((FIFO_AFULL_THRES_G < MAX_PROG_C), FIFO_AFULL_THRES_G, MAX_PROG_C);

   signal din  : slv(72 downto 0);
   signal dout : slv(71 downto 0) := (others => '0');
   signal rxReadyL,
      almostFull,
      progFull,
      overflow,
      fifoRdEn,
      fifoValid,
      txValid,
      ready : sl;
   
   signal wrCnt       : slv(FIFO_ADDR_WIDTH_G-1 downto 0);
   signal wrThreshold : slv(FIFO_ADDR_WIDTH_G-1 downto 0) := MAX_PROG_SLV_C;

   signal rxCtrl,
      txCtrl : Vc64CtrlType;
   signal rxData,
      txData : Vc64DataType;
   
begin

   -- Check VC_WIDTH_G value
   assert ((VC_WIDTH_G = 8) or (VC_WIDTH_G = 16) or (VC_WIDTH_G = 32) or (VC_WIDTH_G = 64))
      report "VC_WIDTH_G must be either: 8, 16, 32, or 64"
      severity failure;
   
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
   rxCtrl.ready      <= not(rxReadyL);
   rxCtrl.almostFull <= almostFull;
   rxCtrl.overflow   <= overflow;

   FIXED_THRESHOLD : if (FIFO_FIXED_THES_G = true) generate
      almostFull <= progFull;
   end generate;

   PROG_THRESHOLD : if (FIFO_FIXED_THES_G = false) generate
      process(vcRxClk)
      begin
         if rising_edge(vcRxClk) then
            if vcRxRst = '1' then
               almostFull  <= '1'            after TPD_G;
               wrThreshold <= MAX_PROG_SLV_C after TPD_G;
            else
               -- Check the threshold
               if wrCnt < wrThreshold then
                  almostFull <= rxReadyL after TPD_G;
               else
                  almostFull <= '1' after TPD_G;
               end if;
               -- Update the programmable threshold value
               if vcRxThreshold < MAX_PROG_SLV_C then
                  wrThreshold <= vcRxThreshold after TPD_G;
               else
                  wrThreshold <= MAX_PROG_SLV_C after TPD_G;
               end if;
            end if;
         end if;
      end process;
   end generate;

   -- Convert the input data into a input SLV bus
   din <= toSlv(rxData);

   FifoCascade_Inst : entity work.FifoCascade
      generic map (
         TPD_G              => TPD_G,
         CASCADE_SIZE_G     => CASCADE_SIZE_G,
         LAST_STAGE_ASYNC_G => LAST_STAGE_ASYNC_G,
         RST_ASYNC_G        => RST_ASYNC_G,
         RST_POLARITY_G     => RST_POLARITY_G,
         GEN_SYNC_FIFO_G    => GEN_SYNC_FIFO_G,
         BRAM_EN_G          => BRAM_EN_G,
         FWFT_EN_G          => true,
         ALTERA_SYN_G       => ALTERA_SYN_G,
         ALTERA_RAM_G       => ALTERA_RAM_G,
         USE_BUILT_IN_G     => USE_BUILT_IN_G,
         XIL_DEVICE_G       => XIL_DEVICE_G,
         SYNC_STAGES_G      => FIFO_SYNC_STAGES_G,
         DATA_WIDTH_G       => (VC_WIDTH_G+8),
         ADDR_WIDTH_G       => FIFO_ADDR_WIDTH_G,
         FULL_THRES_G       => AFULL_THRES_C)
      port map (
         -- Resets
         rst           => vcRxRst,
         --Write Ports (wr_clk domain)
         wr_clk        => vcRxClk,
         wr_en         => din(72),
         din           => din((VC_WIDTH_G+7) downto 0),
         almost_full   => rxReadyL,
         prog_full     => progFull,
         overflow      => overflow,
         wr_data_count => wrCnt,
         --Read Ports (rd_clk domain)
         rd_clk        => vcTxClk,
         rd_en         => fifoRdEn,
         dout          => dout((VC_WIDTH_G+7) downto 0),
         valid         => fifoValid);

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
