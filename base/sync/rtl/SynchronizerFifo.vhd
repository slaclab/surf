-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Synchronizing FIFO wrapper
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Firmware Standard Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'SLAC Firmware Standard Library', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;


library surf;
use surf.StdRtlPkg.all;

entity SynchronizerFifo is
   generic (
      TPD_G         : time                       := 1 ns;
      COMMON_CLK_G  : boolean                    := false;  -- Bypass FifoAsync module for synchronous data configuration
      MEMORY_TYPE_G : string                     := "distributed";
      SYNC_STAGES_G : integer range 3 to (2**24) := 3;
      PIPE_STAGES_G : natural range 0 to 16      := 0;
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

      FifoAsync_1 : entity surf.FifoAsync
         generic map (
            TPD_G         => TPD_G,
            MEMORY_TYPE_G => MEMORY_TYPE_G,
            FWFT_EN_G     => true,
            SYNC_STAGES_G => SYNC_STAGES_G,
            PIPE_STAGES_G => PIPE_STAGES_G,
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
      valid <= wr_en;
      
   end generate;
   
end architecture rtl;
