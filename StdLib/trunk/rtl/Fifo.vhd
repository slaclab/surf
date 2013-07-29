-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : Fifo.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-07-14
-- Last update: 2013-07-29
-- Platform   : ISE 14.5
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2013 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.StdRtlPkg.all;

entity Fifo is
   generic (
      TPD_G           : time                       := 1 ns;
      GEN_SYNC_FIFO_G : boolean                    := false;
      BRAM_EN_G       : boolean                    := true;
      FWFT_EN_G       : boolean                    := false;
      USE_DSP48_G     : string                     := "no";
      ALTERA_RAM_G    : string                     := "M-RAM";
      USE_BUILT_IN_G  : boolean                    := false;  --if set to true, this module is only xilinx compatible only!!!
      XIL_DEVICE_G    : string                     := "7SERIES";  --xilinx only generic parameter    
      SYNC_STAGES_G   : integer range 2 to (2**24) := 2;
      DATA_WIDTH_G    : integer range 1 to (2**24) := 16;
      ADDR_WIDTH_G    : integer range 4 to 48      := 4;
      INIT_G          : slv                        := "0";
      FULL_THRES_G    : integer range 1 to (2**24) := 1;
      EMPTY_THRES_G   : integer range 0 to (2**24) := 0);
   port (
      -- Resets
      rst           : in  sl := '0';    -- Asynchronous Reset
      srst          : in  sl := '0';    -- Synchronous Reset 
      --Write Ports (wr_clk domain)
      wr_clk        : in  sl;
      wr_en         : in  sl := '0';
      din           : in  slv(DATA_WIDTH_G-1 downto 0);
      wr_data_count : out slv(ADDR_WIDTH_G-1 downto 0);
      wr_ack        : out sl;
      overflow      : out sl;
      prog_full     : out sl;
      almost_full   : out sl;
      full          : out sl;
      not_full      : out sl;
      --Read Ports (rd_clk domain)
      rd_clk        : in  sl;           --unused if GEN_SYNC_FIFO_G = true
      rd_en         : in  sl := '0';
      dout          : out slv(DATA_WIDTH_G-1 downto 0);
      rd_data_count : out slv(ADDR_WIDTH_G-1 downto 0);
      valid         : out sl;
      underflow     : out sl;
      prog_empty    : out sl;
      almost_empty  : out sl;
      empty         : out sl);
begin
   -- check for FIFO support
   assert ((USE_BUILT_IN_G = false)
           or ((USE_BUILT_IN_G = true) and (GEN_SYNC_FIFO_G = true)))
      report "ERROR: This FIFO wrapper doesn't support built-in Asynchronous FIFO"
      severity failure;
end Fifo;

architecture rtl of Fifo is
   constant INIT_C       : slv(DATA_WIDTH_G-1 downto 0) := ite(INIT_G = "0", slvZero(DATA_WIDTH_G), INIT_G);
   signal   rstAsyncFifo : sl                           := '0';
   signal   data_count   : slv(ADDR_WIDTH_G-1 downto 0) := (others => '0');
begin
   rstAsyncFifo <= rst or srst;

   NON_BUILT_IN_GEN : if (USE_BUILT_IN_G = false) generate
      FIFO_ASYNC_Gen : if (GEN_SYNC_FIFO_G = false) generate
         FifoAsync_Inst : entity work.FifoAsync
            generic map (
               TPD_G         => TPD_G,
               BRAM_EN_G     => BRAM_EN_G,
               FWFT_EN_G     => FWFT_EN_G,
               USE_DSP48_G   => USE_DSP48_G,
               ALTERA_RAM_G  => ALTERA_RAM_G,
               SYNC_STAGES_G => SYNC_STAGES_G,
               DATA_WIDTH_G  => DATA_WIDTH_G,
               ADDR_WIDTH_G  => ADDR_WIDTH_G,
               INIT_G        => INIT_C,
               FULL_THRES_G  => FULL_THRES_G,
               EMPTY_THRES_G => EMPTY_THRES_G)
            port map (
               rst           => rstAsyncFifo,
               wr_clk        => wr_clk,
               wr_en         => wr_en,
               din           => din,
               wr_data_count => wr_data_count,
               wr_ack        => wr_ack,
               overflow      => overflow,
               prog_full     => prog_full,
               almost_full   => almost_full,
               full          => full,
               not_full      => not_full,
               rd_clk        => rd_clk,
               rd_en         => rd_en,
               dout          => dout,
               rd_data_count => rd_data_count,
               valid         => valid,
               underflow     => underflow,
               prog_empty    => prog_empty,
               almost_empty  => almost_empty,
               empty         => empty);   
      end generate;

      FIFO_SYNC_Gen : if (GEN_SYNC_FIFO_G = true) generate
         wr_data_count <= data_count;
         rd_data_count <= data_count;

         FifoSync_Inst : entity work.FifoSync
            generic map (
               TPD_G         => TPD_G,
               BRAM_EN_G     => BRAM_EN_G,
               FWFT_EN_G     => FWFT_EN_G,
               USE_DSP48_G   => USE_DSP48_G,
               ALTERA_RAM_G  => ALTERA_RAM_G,
               DATA_WIDTH_G  => DATA_WIDTH_G,
               ADDR_WIDTH_G  => ADDR_WIDTH_G,
               INIT_G        => INIT_C,
               FULL_THRES_G  => FULL_THRES_G,
               EMPTY_THRES_G => EMPTY_THRES_G)
            port map (
               rst          => rst,
               srst         => srst,
               clk          => wr_clk,
               wr_en        => wr_en,
               rd_en        => rd_en,
               din          => din,
               dout         => dout,
               data_count   => data_count,
               wr_ack       => wr_ack,
               valid        => valid,
               overflow     => overflow,
               underflow    => underflow,
               prog_full    => prog_full,
               prog_empty   => prog_empty,
               almost_full  => almost_full,
               almost_empty => almost_empty,
               full         => full,
               not_full     => not_full,
               empty        => empty);   
         --NOTE: 
         --    When mapping the FifoSync, I am assuming that
         --    wr_clk = rd_clk (both in frequency and in phase)
         --    and I only pass wr_clk into the FifoSync_Inst
      end generate;
   end generate;

   BUILT_IN_GEN : if (USE_BUILT_IN_G = true) generate
      FIFO_SYNC_BUILT_IN_GEN : if (GEN_SYNC_FIFO_G = true) generate
         wr_data_count <= data_count;
         rd_data_count <= data_count;

         FifoSyncBuiltIn_Inst : entity work.FifoSyncBuiltIn
            generic map (
               TPD_G         => TPD_G,
               XIL_DEVICE_G  => XIL_DEVICE_G,
               USE_DSP48_G   => USE_DSP48_G,
               FWFT_EN_G     => FWFT_EN_G,
               DATA_WIDTH_G  => DATA_WIDTH_G,
               ADDR_WIDTH_G  => ADDR_WIDTH_G,
               FULL_THRES_G  => FULL_THRES_G,
               EMPTY_THRES_G => EMPTY_THRES_G)
            port map (
               rst          => rstAsyncFifo,
               clk          => wr_clk,
               wr_en        => wr_en,
               rd_en        => rd_en,
               din          => din,
               dout         => dout,
               data_count   => data_count,
               wr_ack       => wr_ack,
               valid        => valid,
               overflow     => overflow,
               underflow    => underflow,
               prog_full    => prog_full,
               prog_empty   => prog_empty,
               almost_full  => almost_full,
               almost_empty => almost_empty,
               full         => full,
               not_full     => not_full,
               empty        => empty);   
         --NOTE: 
         --    When mapping the FifoSync, I am assuming that
         --    wr_clk = rd_clk (both in frequency and in phase)
         --    and I only pass wr_clk into the FifoSyncBuiltIn_Inst
      end generate;
   end generate;
   
end architecture rtl;
