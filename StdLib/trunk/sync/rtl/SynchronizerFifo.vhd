-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : SynchronizerFifo.vhd
-- Author     : Ben Reese
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-07-10
-- Last update: 2014-04-14
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Synchronizing FIFO wrapper
--
-- Dependencies:  ^/StdLib/trunk/rtl/FifoAsync.vhd
-------------------------------------------------------------------------------
-- Copyright (c) 2014 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;

entity SynchronizerFifo is
   generic (
      TPD_G         : time                       := 1 ns;
      COMMON_CLK_G  : boolean                    := false;  -- Bypass FifoAsync module for synchronous data configuration
      BRAM_EN_G     : boolean                    := false;
      ALTERA_SYN_G  : boolean                    := false;
      ALTERA_RAM_G  : string                     := "M9K";
      SYNC_STAGES_G : integer range 3 to (2**24) := 3;
      DATA_WIDTH_G  : integer range 1 to (2**24) := 16;
      ADDR_WIDTH_G  : integer range 2 to 48      := 4;
      INIT_G        : slv                        := "0");
   port (
      -- Asynchronous Reset
      rst    : in  sl := '0';
      -- Write Ports (wr_clk domain)
      wr_clk : in  sl;
      wr_en  : in  sl := '1';
      din    : in  slv(DATA_WIDTH_G-1 downto 0);
      -- Read Ports (rd_clk domain)
      rd_clk : in  sl;
      rd_en  : in  sl := '1';
      valid  : out sl;
      dout   : out slv(DATA_WIDTH_G-1 downto 0));
end SynchronizerFifo;

architecture rtl of SynchronizerFifo is
   
   constant INIT_C : slv(DATA_WIDTH_G-1 downto 0) := ite(INIT_G = "0", slvZero(DATA_WIDTH_G), INIT_G);

begin

   assert (INIT_G = "0" or INIT_G'length = DATA_WIDTH_G) report
      "INIT_G must either be ""0"" or the same length as DATA_WIDTH_G" severity failure;

   GEN_ASYNC : if (COMMON_CLK_G = false) generate

      FifoAsync_1 : entity work.FifoAsync
         generic map (
            TPD_G         => TPD_G,
            BRAM_EN_G     => BRAM_EN_G,
            FWFT_EN_G     => true,
            ALTERA_SYN_G  => ALTERA_SYN_G,
            ALTERA_RAM_G  => ALTERA_RAM_G,
            SYNC_STAGES_G => SYNC_STAGES_G,
            DATA_WIDTH_G  => DATA_WIDTH_G,
            ADDR_WIDTH_G  => ADDR_WIDTH_G,
            INIT_G        => INIT_C)
         port map (
            rst           => rst,
            wr_clk        => wr_clk,
            wr_en         => wr_en,
            din           => din,
            wr_data_count => open,
            wr_ack        => open,
            overflow      => open,
            prog_full     => open,
            almost_full   => open,
            full          => open,
            rd_clk        => rd_clk,
            rd_en         => rd_en,
            dout          => dout,
            rd_data_count => open,
            valid         => valid,
            underflow     => open,
            prog_empty    => open,
            almost_empty  => open,
            empty         => open);

   end generate;

   GEN_SYNC : if (COMMON_CLK_G = true) generate

      dout  <= din;
      valid <= '1';
      
   end generate;
   
end architecture rtl;
