-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : Vc64FifoMux.vhd
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
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.Vc64Pkg.all;

entity Vc64FifoMux is
   generic (
      TPD_G              : time                       := 1 ns;
      RX_LANES_G         : integer range 1 to 4       := 4;  -- 16 bits of data per lane
      TX_LANES_G         : integer range 1 to 4       := 4;  -- 16 bits of data per lane
      LITTLE_ENDIAN_G    : boolean                    := false;
      RST_ASYNC_G        : boolean                    := false;
      ALTERA_SYN_G       : boolean                    := false;
      ALTERA_RAM_G       : string                     := "M9K";
      BRAM_EN_G          : boolean                    := true;
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
end Vc64FifoMux;

architecture mapping of Vc64FifoMux is

   constant WR_DATA_WIDTH_C : integer := 24*RX_LANES_G;
   constant RD_DATA_WIDTH_C : integer := 24*TX_LANES_G;

   signal din  : slv(WR_DATA_WIDTH_C-1 downto 0);
   signal dout : slv(RD_DATA_WIDTH_C-1 downto 0);
   signal fifoRdEn,
      fifoValid,
      txValid,
      ready : sl;
   
   signal txCtrl : Vc64CtrlType;
   signal txData : Vc64DataType;
   
begin

   -- Assign data based on lane generics
   STATUS_HDR : process (vcRxData) is
      variable i : integer;
   begin
      din <= (others => '0');           -- Default everything to zero
      for i in (RX_LANES_G-1) downto 0 loop
         -- Map the upper word flags
         if (i = (RX_LANES_G-1)) then
            din(i*24+23)                    <= vcRxData.size;
            din((i*24+22) downto (i*24+19)) <= vcRxData.vc;
            din(i*24+18)                    <= vcRxData.sof;
         end if;
         -- Map the lower word flags
         if (i = 0) then
            din(i*24+17) <= vcRxData.eof;
            din(i*24+16) <= vcRxData.eofe;
         end if;
         -- Map the data bus
         din(i*24+15 downto i*24) <= vcRxData.data(i*16+15 downto i*16);
      end loop;
   end process STATUS_HDR;

   FifoMux_Inst : entity work.FifoMux
      generic map (
         TPD_G           => TPD_G,
         WR_DATA_WIDTH_G => WR_DATA_WIDTH_C,
         RD_DATA_WIDTH_G => RD_DATA_WIDTH_C,
         LITTLE_ENDIAN_G => LITTLE_ENDIAN_G,
         RST_ASYNC_G     => RST_ASYNC_G,
         GEN_SYNC_FIFO_G => GEN_SYNC_FIFO_G,
         BRAM_EN_G       => BRAM_EN_G,
         FWFT_EN_G       => true,
         ALTERA_SYN_G    => ALTERA_SYN_G,
         ALTERA_RAM_G    => ALTERA_RAM_G,
         USE_BUILT_IN_G  => false,
         SYNC_STAGES_G   => FIFO_SYNC_STAGES_G,
         ADDR_WIDTH_G    => FIFO_ADDR_WIDTH_G,
         FULL_THRES_G    => FIFO_AFULL_THRES_G)
      port map (
         -- Resets
         rst       => vcRxRst,
         --Write Ports (wr_clk domain)
         wr_clk    => vcRxClk,
         wr_en     => vcRxData.valid,
         din       => din,
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

   -- Pass the FIFO's valid signal
   vcTxData.valid <= txValid;

   -- upper word flags
   vcTxData.size <= dout((TX_LANES_G-1)*24+23);
   vcTxData.vc   <= dout(((TX_LANES_G-1)*24+22) downto ((TX_LANES_G-1)*24+19));
   vcTxData.sof  <= dout((TX_LANES_G-1)*24+18);

   -- lower word flags
   vcTxData.eof  <= dout(17);
   vcTxData.eofe <= dout(16);

   -- Assign data based on lane generics
   dataLoop : for i in (TX_LANES_G-1) downto 0 generate
      vcTxData.data(i*16+15 downto i*16) <= dout(i*24+15 downto i*24);
   end generate dataLoop;

   maxLaneCheck : if (TX_LANES_G /= 4) generate
      zeroLoop : for i in 3 downto TX_LANES_G generate
         vcTxData.data(i*16+15 downto i*16) <= (others => '0');
      end generate zeroLoop;
   end generate;

   ZERO_LATENCY : if (PIPE_STAGES_G = 0) generate

      vcTxData <= txData;
      txCtrl   <= vcTxCtrl;
      
   end generate;

   PIPE_REG : if (PIPE_STAGES_G > 0) generate

      Vc64Sync_Inst : entity work.Vc64Sync
         generic map (
            TPD_G         => TPD_G,
            PIPE_STAGES_G => PIPE_STAGES_G)
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
