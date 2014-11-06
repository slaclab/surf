-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : EthGtx7.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-06-29
-- Last update: 2014-05-02
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Gtx7 Wrapper
--
-- Dependencies:  ^/pgp2_core/trunk/rtl/core/Pgp2RxWrapper.vhd
--                ^/pgp2_core/trunk/rtl/core/Pgp2TxWrapper.vhd
--                ^/StdLib/trunk/rtl/CRC32Rtl.vhd
-------------------------------------------------------------------------------
--                ^/MgtLib/trunk/rtl/gtx7/Gtx7Core.vhd
-- Copyright (c) 2014 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.StdRtlPkg.all;
use work.GigEthPkg.all;
--use work.AxiStreamPkg.all;
--use work.Pgp2bPkg.all;

library UNISIM;
use UNISIM.VCOMPONENTS.all;

entity GigEth16To8Mux is
   generic (
      TPD_G             : time       := 1 ns;
      ----------------------------------------------------------------------------------------------
      -- FIFO MUX settings
      ----------------------------------------------------------------------------------------------
      CASCADE_SIZE_G     : integer range 1 to (2**24) := 1;  -- number of FIFOs to cascade (if set to 1, then no FIFO cascading)
      RST_ASYNC_G        : boolean                    := false;
      BRAM_EN_G          : boolean                    := true;
      USE_DSP48_G        : string                     := "no";
      ALTERA_SYN_G       : boolean                    := false;
      ALTERA_RAM_G       : string                     := "M9K";
      USE_BUILT_IN_G     : boolean                    := false;  -- If set to true, this module is only Xilinx compatible only!!!
      XIL_DEVICE_G       : string                     := "7SERIES";  -- Xilinx only generic parameter    
      SYNC_STAGES_G      : integer range 3 to (2**24) := 3;
      PIPE_STAGES_G      : natural range 0 to 16      := 0;
      LITTLE_ENDIAN_G    : boolean                    := true;
      ADDR_WIDTH_G       : integer range 4 to 48      := 4;
      INIT_G             : slv                        := "0";
      FULL_THRES_G       : integer range 1 to (2**24) := 2**4-1;
      EMPTY_THRES_G      : integer range 1 to (2**24) := 1
   );
   port (
      -- Input clocking to deal with the GTX interface
      ethPhy62MHzClk   : in  sl;
      ethPhy62MHzRst   : in  sl;
      ethLinkReady     : in  sl;
      -- 125 MHz clock for 8 bit outputs
      eth125MHzClk     : in  sl;
      -- PHY (16 bit) data interface in
      ethPhyDataIn     : in  EthRxPhyLaneInType;
      -- MAC (8 bit) data interface out
      ethMacDataOut    : out EthMacDataType
   );
end GigEth16To8Mux;

-- Define architecture
architecture rtl of GigEth16To8Mux is
   
   signal fifoRdValid : sl;
   signal wrData : slv(17 downto 0);
   signal rdData : slv(8 downto 0);
      
begin

   wrData <= ethPhyDataIn.dataK(0) & ethPhyDataIn.data( 7 downto 0) &
             ethPhyDataIn.dataK(1) & ethPhyDataIn.data(15 downto 8);

   ethMacDataOut.data      <= rdData(7 downto 0);
   ethMacDataOut.dataK     <= rdData(8);
   ethMacDataOut.dataValid <= fifoRdValid;

             
   -- A small 16-to-8 bit FIFO to pass data to the MAC layer
   U_FifoMux16to8 : entity work.FifoMux
      generic map (
         TPD_G              => TPD_G,
         CASCADE_SIZE_G     => CASCADE_SIZE_G,
         LAST_STAGE_ASYNC_G => true,
         RST_POLARITY_G     => '1',
         RST_ASYNC_G        => RST_ASYNC_G,
         GEN_SYNC_FIFO_G    => false,
         BRAM_EN_G          => BRAM_EN_G,
         FWFT_EN_G          => true,
         USE_DSP48_G        => USE_DSP48_G,
         ALTERA_SYN_G       => ALTERA_SYN_G,
         ALTERA_RAM_G       => ALTERA_RAM_G,
         USE_BUILT_IN_G     => USE_BUILT_IN_G,
         XIL_DEVICE_G       => XIL_DEVICE_G,
         SYNC_STAGES_G      => SYNC_STAGES_G,
         PIPE_STAGES_G      => PIPE_STAGES_G,
         WR_DATA_WIDTH_G    => 18,
         RD_DATA_WIDTH_G    => 9,
         LITTLE_ENDIAN_G    => LITTLE_ENDIAN_G,
         ADDR_WIDTH_G       => ADDR_WIDTH_G,
         INIT_G             => INIT_G,
         FULL_THRES_G       => FULL_THRES_G,
         EMPTY_THRES_G      => EMPTY_THRES_G
      )
      port map (
         -- Resets
         rst           => ethPhy62MHzRst,
         --Write Ports (wr_clk domain)
         wr_clk        => ethPhy62MHzClk,
         wr_en         => ethLinkReady,  --Write whenever link is fully up
         din           => wrData,
         wr_data_count => open,
         wr_ack        => open,
         overflow      => open,
         prog_full     => open,
         almost_full   => open,
         full          => open,
         not_full      => open,
         --Read Ports (rd_clk domain)
         rd_clk        => eth125MHzClk,
         rd_en         => fifoRdValid,
         dout          => rdData,
         rd_data_count => open,
         valid         => fifoRdValid,
         underflow     => open,
         prog_empty    => open,
         almost_empty  => open,
         empty         => open
      );      
      
end rtl;
