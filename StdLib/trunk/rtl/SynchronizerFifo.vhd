-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : SynchronizerFifo.vhd
-- Author     : Ben Reese
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-07-10
-- Last update: 2013-07-11
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
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;

entity SynchronizerFifo is
   generic (
      TPD_G         : time                       := 1 ns;
      BRAM_EN_G     : boolean                    := false;
      SYNC_STAGES_G : integer range 2 to (2**24) := 2;
      DATA_WIDTH_G  : integer range 1 to (2**24) := 73);
   port ( 
      -- Asynchronous Reset
      rst    : in  sl;
      --Write Ports (wr_clk domain)
      wr_clk : in  sl;
      din    : in  slv(DATA_WIDTH_G-1 downto 0);
      --Read Ports (rd_clk domain)
      rd_clk : in  sl;
      valid  : out sl;
      dout   : out slv(DATA_WIDTH_G-1 downto 0));
      -------------------------------------------------------------------------
      -- Note: rd_clk frequency must be greater than or equal to wr_clk!!!!!!!!
      -------------------------------------------------------------------------
end SynchronizerFifo;

architecture rtl of SynchronizerFifo is
   signal empty : sl;
   signal notEmpty : sl;
begin
   FifoAsync_1 : entity work.FifoAsync
      generic map (
         TPD_G        => TPD_G,
         BRAM_EN_G    => BRAM_EN_G, 
         DATA_WIDTH_G => DATA_WIDTH_G,
         ADDR_WIDTH_G => 4)
      port map (
         rst           => rst,
         wr_clk        => wr_clk,
         wr_en         => '1',
         din           => din,
         wr_data_count => open,
         wr_ack        => open,
         overflow      => open,
         prog_full     => open,
         almost_full   => open,
         full          => open,
         rd_clk        => rd_clk,
         rd_en         => notEmpty,
         dout          => dout,
         rd_data_count => open,
         valid         => valid,
         underflow     => open,
         prog_empty    => open,
         almost_empty  => open,
         empty         => empty);
   notEmpty <= not empty;
end architecture rtl;
