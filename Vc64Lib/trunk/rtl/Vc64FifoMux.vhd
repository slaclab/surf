-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : Vc64FifoMux.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-04-04
-- Last update: 2014-04-09
-- Platform   : Vivado 2013.3
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:   This module is used as a mux'd FIFO interface 
--                for a VC64 channel.
--
-- Note: If EN_FRAME_FILTER_G = true, then this module DOES NOT support 
--       interleaving of virtual channels during the middle of a frame transfer.
-------------------------------------------------------------------------------
-- Copyright (c) 2014 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.Vc64Pkg.all;

entity Vc64FifoMux is
   generic (
      -- General Configurations
      TPD_G              : time                       := 1 ns;
      RST_ASYNC_G        : boolean                    := false;
      RST_POLARITY_G     : sl                         := '1';  -- '1' for active HIGH reset, '0' for active LOW reset   
      LITTLE_ENDIAN_G    : boolean                    := false;
      -- Cascading FIFO Configurations
      CASCADE_SIZE_G     : integer range 1 to (2**24) := 1;-- number of FIFOs to cascade (if set to 1, then no FIFO cascading)
      LAST_STAGE_ASYNC_G : boolean                    := true;-- if set to true, the last stage will be the ASYNC FIFO            
      -- RX Configurations
      RX_LANES_G         : integer range 1 to 4       := 4;  -- 16 bits of data per lane
      EN_FRAME_FILTER_G  : boolean                    := true;
      -- TX Configurations
      TX_LANES_G         : integer range 1 to 4       := 4;  -- 16 bits of data per lane
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
      vcRxData : in  Vc64DataType;
      vcRxCtrl : out Vc64CtrlType;
      vcRxClk  : in  sl;
      vcRxRst  : in  sl := '0';
      -- Streaming TX Data Interface (vcTxClk domain) 
      vcTxCtrl : in  Vc64CtrlType;
      vcTxData : out Vc64DataType;
      vcTxClk  : in  sl;
      vcTxRst  : in  sl := '0');
end Vc64FifoMux;

architecture mapping of Vc64FifoMux is

   -- Set the maximum programmable FIFO full threshold to one less than FIFO's almost full threshold
   constant MAX_PROG_C : integer := ((2**FIFO_ADDR_WIDTH_G)-3);

   -- Limit the FIFO_AFULL_THRES_G generic
   constant AFULL_THRES_C : integer := ite((FIFO_AFULL_THRES_G < MAX_PROG_C), FIFO_AFULL_THRES_G, MAX_PROG_C);

   constant WR_DATA_WIDTH_C : integer := 24*RX_LANES_G;
   constant RD_DATA_WIDTH_C : integer := 24*TX_LANES_G;

   signal din  : slv(WR_DATA_WIDTH_C-1 downto 0);
   signal dout : slv(RD_DATA_WIDTH_C-1 downto 0);
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

   -- Assign data based on lane generics
   STATUS_HDR : process (rxData) is
      variable i : integer;
   begin
      din <= (others => '0');           -- Default everything to zero
      for i in (RX_LANES_G-1) downto 0 loop
         -- Map the upper word flags
         if (i = (RX_LANES_G-1)) then
            din(i*24+23)                    <= rxData.size;
            din((i*24+22) downto (i*24+19)) <= rxData.vc;
            din(i*24+18)                    <= rxData.sof;
         end if;
         -- Map the lower word flags
         if (i = 0) then
            din(i*24+17) <= rxData.eof;
            din(i*24+16) <= rxData.eofe;
         end if;
         -- Map the data bus
         din(i*24+15 downto i*24) <= rxData.data(i*16+15 downto i*16);
      end loop;
   end process STATUS_HDR;

   FifoMux_Inst : entity work.FifoMux
      generic map (
         TPD_G           => TPD_G,
         CASCADE_SIZE_G     => CASCADE_SIZE_G,
         LAST_STAGE_ASYNC_G => LAST_STAGE_ASYNC_G,
         RST_ASYNC_G     => RST_ASYNC_G,
         RST_POLARITY_G  => RST_POLARITY_G,
         WR_DATA_WIDTH_G => WR_DATA_WIDTH_C,
         RD_DATA_WIDTH_G => RD_DATA_WIDTH_C,
         LITTLE_ENDIAN_G => LITTLE_ENDIAN_G,
         GEN_SYNC_FIFO_G => GEN_SYNC_FIFO_G,
         BRAM_EN_G       => BRAM_EN_G,
         FWFT_EN_G       => true,
         ALTERA_SYN_G    => ALTERA_SYN_G,
         ALTERA_RAM_G    => ALTERA_RAM_G,
         USE_BUILT_IN_G  => USE_BUILT_IN_G,
         SYNC_STAGES_G   => FIFO_SYNC_STAGES_G,
         ADDR_WIDTH_G    => FIFO_ADDR_WIDTH_G,
         FULL_THRES_G    => AFULL_THRES_C)
      port map (
         -- Resets
         rst         => vcRxRst,
         --Write Ports (wr_clk domain)
         wr_clk      => vcRxClk,
         wr_en       => vcRxData.valid,
         din         => din,
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

   -- Pass the FIFO's valid signal
   txData.valid <= txValid;

   -- Upper word flags
   txData.size <= dout((TX_LANES_G-1)*24+23);
   txData.vc   <= dout(((TX_LANES_G-1)*24+22) downto ((TX_LANES_G-1)*24+19));
   txData.sof  <= dout((TX_LANES_G-1)*24+18);

   -- Lower word flags
   txData.eof  <= dout(17);
   txData.eofe <= dout(16);

   -- Assign data based on lane generics
   dataLoop : for i in (TX_LANES_G-1) downto 0 generate
      txData.data(i*16+15 downto i*16) <= dout(i*24+15 downto i*24);
   end generate dataLoop;

   maxLaneCheck : if (TX_LANES_G /= 4) generate
      zeroLoop : for i in 3 downto TX_LANES_G generate
         txData.data(i*16+15 downto i*16) <= (others => '0');
      end generate zeroLoop;
   end generate;

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
